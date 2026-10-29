using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using UnityEngine;
using UnityEngine.Rendering;

namespace HybridLumenGI
{
    /// <summary>
    /// Per-camera residency for already-loaded analytic proxies. This owns GPU residency, not scene/asset IO.
    /// Removal and dirty geometry invalidate immediately; replacements consume the upload budget.
    /// </summary>
    public sealed class HybridLumenGIScene : IDisposable
    {
        [Flags]
        public enum ChangeKind { Added = 1, Removed = 2, Transform = 4, Material = 8, Topology = 16, Manual = 32, Representation = 64, Lighting = 128 }
        public struct DirtyRegion
        {
            public Bounds PreviousBounds, CurrentBounds;
            public bool HasPrevious, HasCurrent;
            public int Slot, StableId, PreviousRevision, Revision;
            public ChangeKind Kind;
        }
        private struct Signature
        {
            public Matrix4x4 matrix;
            public int meshId, vertexCount, sdfId, textureId, geometryContentRevision;
            public LightingPolicyData lighting;
        }
        [StructLayout(LayoutKind.Sequential)]
        public struct ProxyGpuData
        {
            public Vector4 centerShape;
            public Vector4 extentsRoughness;
            public Vector4 albedo;
            public Vector4 emission;
            public Vector4 identity; // stable ID, revision, field (0 near / 1 far), phase (0 absent / 1 published / 2 warming)
        }

        /// <summary>Exact uint policy for the same scene slot as ProxyGpuData.
        /// An absent/pending slot is zeroed; consumers must also validate scene identity/phase.</summary>
        [StructLayout(LayoutKind.Sequential)]
        public struct LightingPolicyData
        {
            public uint objectLayerBit, renderingLayerMask, shadowCastingMode, reserved;
        }

        public const int Stride = 80;
        public const int LightingPolicyStride = 16;
        public ComputeBuffer Buffer { get; private set; }
        public ComputeBuffer LightingPolicyBuffer { get; private set; }
        public ProxyGpuData[] Data { get; private set; } = Array.Empty<ProxyGpuData>();
        public LightingPolicyData[] LightingPolicies { get; private set; } = Array.Empty<LightingPolicyData>();
        public int Capacity => Data.Length;
        public int ValidCount { get; private set; }
        public int PendingUploadCount { get; private set; }
        public int ResidentChunkCount { get; private set; }
        public int Revision { get; private set; }
        public int WarmingCount { get; private set; }
        public int PublishedCount => ValidCount - WarmingCount;
        public int PendingCapacity { get; private set; }
        public readonly HybridLumenGISceneBvh Bvh = new HybridLumenGISceneBvh();
        public IReadOnlyList<DirtyRegion> DirtyRegions => dirtyRegions;
        public bool RequiresFullInvalidation { get; private set; }
        private readonly List<DirtyRegion> dirtyRegions = new List<DirtyRegion>();
        private Bounds[] traversalBounds = Array.Empty<Bounds>();
        private bool[] traversalActive = Array.Empty<bool>();
        private Signature[] signatures = Array.Empty<Signature>();

        private struct Candidate
        {
            public HybridLumenGIProxy proxy;
            public Bounds bounds;
            public Vector3Int chunk;
            public float distanceSquared;
            public int field;
            public int slot, age;
            public int phase;
        }

        private sealed class HlodGroup
        {
            public HybridLumenGIProxy root;
            public readonly List<HybridLumenGIProxy> details = new List<HybridLumenGIProxy>();
            public readonly HashSet<int> published = new HashSet<int>();
            public readonly HashSet<int> target = new HashSet<int>();
            public float distance;
            public bool seen, initialized;
            public bool capacityFallback; // Derived again from this Prepare's requested target.
        }

        private readonly List<Candidate> candidates = new List<Candidate>();
        private readonly List<Candidate> uploadQueue = new List<Candidate>();
        private readonly List<Candidate> selectedCandidates = new List<Candidate>();
        private readonly List<Candidate> ordinaryCandidates = new List<Candidate>();
        private readonly Dictionary<int, Candidate> available = new Dictionary<int, Candidate>();
        private readonly Dictionary<int, HybridLumenGIProxy> activeById = new Dictionary<int, HybridLumenGIProxy>();
        private readonly Dictionary<int, HlodGroup> groups = new Dictionary<int, HlodGroup>();
        private readonly List<HlodGroup> orderedGroups = new List<HlodGroup>();
        private readonly HashSet<int> grouped = new HashSet<int>();
        private readonly HybridLumenGIHlodReadiness readiness = new HybridLumenGIHlodReadiness();
        private readonly HashSet<int> representationAdds = new HashSet<int>(), representationRemoves = new HashSet<int>();
        private readonly Dictionary<int, int> slots = new Dictionary<int, int>();
        private readonly HashSet<int> desired = new HashSet<int>();
        private readonly HashSet<int> aggregates = new HashSet<int>();
        private readonly HashSet<int> liveIds = new HashSet<int>();
        private readonly List<int> retiredIds = new List<int>();
        private readonly Dictionary<int, bool> farStates = new Dictionary<int, bool>();
        private readonly HashSet<Vector3Int> residentChunks = new HashSet<Vector3Int>();
        private HybridLumenGIProxy[] owners = Array.Empty<HybridLumenGIProxy>();
        private bool[] dirty = Array.Empty<bool>();
        private Vector3Int[] slotChunks = Array.Empty<Vector3Int>();
        private int[] pendingAge = Array.Empty<int>();

        public HybridLumenGIProxy GetProxy(int slot) => slot >= 0 && slot < owners.Length ? owners[slot] : null;
        public Renderer GetRenderer(int slot) => GetProxy(slot) != null ? GetProxy(slot).SourceRenderer : null;
        public bool IsPublished(int slot) => slot >= 0 && slot < Capacity && Data[slot].identity.w == 1f;
        public bool IsWarming(int slot) => slot >= 0 && slot < Capacity && Data[slot].identity.w == 2f;
        /// <summary>Frozen bounds from the latest Prepare, including warming representations.</summary>
        public bool TryGetPreparedTraversalBounds(int slot,out Bounds bounds)
        {
            bounds=default;
            if(!IsPublished(slot) && !IsWarming(slot)) return false;
            bounds=traversalBounds[slot];return true;
        }
        public void InvalidateReadiness() => readiness.Clear();

        /// <summary>
        /// Report current-generation preparation after capture/cache commands have been recorded on the
        /// same ordered graphics queue. This is a receipt, not a GPU fence or a convergence guarantee.
        /// </summary>
        public bool ReportReadiness(int stableId, int revision, bool geometryReady, bool materialReady, bool lightingReady)
        {
            if (!slots.TryGetValue(stableId, out int slot) || Data[slot].identity.w < 0.5f ||
                (int)Data[slot].identity.y != revision) return false;
            readiness.Report(stableId, revision, geometryReady, materialReady, lightingReady);
            return true;
        }

        public bool Prepare(Vector3 position, int capacity, float nearDistance, float farDistance,
            float chunkSize, int uploadBudget)
        {
            capacity = Mathf.Clamp(capacity, 32, 256);
            nearDistance = Mathf.Max(0.1f, nearDistance);
            farDistance = Mathf.Max(nearDistance, farDistance);
            chunkSize = Mathf.Max(1f, chunkSize);
            uploadBudget = Mathf.Clamp(uploadBudget, 1, capacity);
            dirtyRegions.Clear();
            bool changed = EnsureCapacity(capacity);
            RequiresFullInvalidation = changed;
            Array.Clear(dirty, 0, dirty.Length);
            candidates.Clear();
            desired.Clear();
            aggregates.Clear();
            liveIds.Clear();
            activeById.Clear();
            float nearSquared = nearDistance * nearDistance;
            float farSquared = farDistance * farDistance;
            var active = HybridLumenGIProxy.ActiveProxies;
            for (int i = 0; i < active.Count; i++)
            {
                HybridLumenGIProxy proxy = active[i];
                if (proxy == null || !proxy.isActiveAndEnabled) continue;
                // Rendering may follow another LateUpdate or an explicit camera render.
                // Refresh before the revision gate so all representations see one current snapshot.
                proxy.RefreshSignatureForRender();
                liveIds.Add(proxy.StableId);
                activeById[proxy.StableId] = proxy;
                HybridLumenGIProxy parent = proxy.HLODParent;
                if (parent != null && parent.isActiveAndEnabled) aggregates.Add(parent.StableId);
            }
            retiredIds.Clear();
            foreach (int id in farStates.Keys) if (!liveIds.Contains(id)) retiredIds.Add(id);
            for (int i = 0; i < retiredIds.Count; i++) farStates.Remove(retiredIds[i]);
            for (int i = 0; i < active.Count; i++)
            {
                HybridLumenGIProxy proxy = active[i];
                if (proxy == null || !proxy.isActiveAndEnabled) continue;
                Bounds bounds = proxy.GetWorldBounds();
                float distance = bounds.SqrDistance(position);
                if (!Finite(bounds.center) || !Finite(bounds.extents)) continue;
                bool aggregate = proxy.FarFieldOnly || aggregates.Contains(proxy.StableId);
                candidates.Add(new Candidate
                {
                    proxy = proxy,
                    bounds = bounds,
                    distanceSquared = distance,
                    chunk = Chunk(bounds.center, chunkSize),
                    field = aggregate || distance > nearSquared ? 1 : 0,
                    phase = 1
                });
            }
            // Conservative bounds distance keeps large walls that surround the camera resident.
            // Stable ID breaks ties deterministically instead of changing slots with registry sort order.
            candidates.Sort(CompareCandidates);
            SelectAtomicGroups(position, nearDistance, farSquared, capacity);
            int desiredCount = selectedCandidates.Count;

            // Never keep an old occluder/material alive while its replacement waits for budget.
            for (int slot = 0; slot < capacity; slot++)
            {
                HybridLumenGIProxy owner = owners[slot];
                if (owner == null || !owner.isActiveAndEnabled || !desired.Contains(owner.StableId))
                {
                    if (Data[slot].identity.w > 0f)
                    {
                        if (Data[slot].identity.w == 1f)
                            RecordDirty(slot, (int)Data[slot].identity.x, true, traversalBounds[slot], false, default,
                                ChangeKind.Removed | (representationRemoves.Contains((int)Data[slot].identity.x) ? ChangeKind.Representation : 0), (int)Data[slot].identity.y, 0);
                        Clear(slot); changed = true;
                    }
                    if (!ReferenceEquals(owner, null)) slots.Remove((int)Data[slot].identity.x);
                    readiness.Invalidate((int)Data[slot].identity.x);
                    owners[slot] = null;
                    continue;
                }
                if (Data[slot].identity.w > 0f && (int)Data[slot].identity.y != owner.Revision)
                {
                    Bounds newBounds = GetTraversalBounds(owner);
                    Signature next = GetSignature(owner);
                    ChangeKind kind = ClassifyChange(Data[slot], signatures[slot], owner, next, traversalBounds[slot], newBounds);
                    if (Data[slot].identity.w == 1f)
                        RecordDirty(slot, owner.StableId, true, traversalBounds[slot], true, newBounds,
                            kind, (int)Data[slot].identity.y, owner.Revision);
                    readiness.Invalidate(owner.StableId);
                    if ((kind & ~(ChangeKind.Material | ChangeKind.Lighting)) == 0)
                    {
                        // Material/policy edits invalidate transport, but unchanged geometry stays resident.
                        Candidate value = available[owner.StableId];
                        float phase = Data[slot].identity.w;
                        Data[slot] = MakeData(value); Data[slot].identity.w = phase;
                        LightingPolicies[slot] = next.lighting;
                        signatures[slot] = next; dirty[slot] = true;
                    }
                    else Clear(slot);
                    changed = true;
                }
            }

            PendingUploadCount = 0;
            uploadQueue.Clear();
            for (int i = 0; i < desiredCount; i++)
            {
                Candidate candidate = selectedCandidates[i];
                int id = candidate.proxy.StableId;
                if (!slots.TryGetValue(id, out int slot))
                {
                    slot = FindFreeSlot();
                    if (slot < 0) { PendingUploadCount++; continue; }
                    slots.Add(id, slot);
                    readiness.Invalidate(id);
                    owners[slot] = candidate.proxy;
                    pendingAge[slot] = 0;
                    Data[slot] = new ProxyGpuData { identity = new Vector4(id, candidate.proxy.Revision, candidate.field, 0f) };
                    LightingPolicies[slot] = default;
                    dirty[slot] = true;
                }
                if (Data[slot].identity.w > 0f)
                {
                    if ((int)Data[slot].identity.w != candidate.phase)
                    {
                        ProxyGpuData value = Data[slot]; value.identity.w = candidate.phase; Data[slot] = value;
                        traversalActive[slot] = candidate.phase == 1; dirty[slot] = true; changed = true;
                        RecordDirty(slot, id, false, default, true, traversalBounds[slot],
                            ChangeKind.Added | (representationAdds.Contains(id) ? ChangeKind.Representation : 0), 0, candidate.proxy.Revision);
                    }
                    // Field/chunk movement can occur without a geometry change when the camera moves.
                    if ((int)Data[slot].identity.z != candidate.field)
                    {
                        ProxyGpuData value = Data[slot];
                        value.identity.z = candidate.field;
                        Data[slot] = value;
                        dirty[slot] = true;
                    }
                    slotChunks[slot] = candidate.chunk;
                    continue;
                }
                pendingAge[slot] = Mathf.Min(pendingAge[slot] + 1, 1000000);
                candidate.age = pendingAge[slot];
                candidate.slot = slot;
                uploadQueue.Add(candidate);
            }
            // Old pending uploads outrank newly dirty near objects, so continuously moving geometry
            // cannot consume every update and starve the rest of the resident scene indefinitely.
            uploadQueue.Sort(CompareUploads);
            int uploaded = Mathf.Min(uploadBudget, uploadQueue.Count);
            PendingUploadCount += uploadQueue.Count - uploaded;
            for (int i = 0; i < uploaded; i++)
            {
                Candidate candidate = uploadQueue[i];
                int slot = candidate.slot;
                Data[slot] = MakeData(candidate);
                LightingPolicies[slot] = MakeLightingPolicy(candidate.proxy);
                traversalBounds[slot] = GetTraversalBounds(candidate.proxy);
                traversalActive[slot] = candidate.phase == 1;
                signatures[slot] = GetSignature(candidate.proxy);
                if (candidate.phase == 1)
                    RecordDirty(slot, candidate.proxy.StableId, false, default, true, traversalBounds[slot],
                        ChangeKind.Added, 0, candidate.proxy.Revision);
                slotChunks[slot] = candidate.chunk;
                dirty[slot] = true;
                pendingAge[slot] = 0;
                changed = true;
            }

            // Upload contiguous dirty spans; immediate invalidations are never charged to replacement budget.
            for (int begin = 0; begin < capacity;)
            {
                if (!dirty[begin]) { begin++; continue; }
                int end = begin + 1;
                while (end < capacity && dirty[end]) end++;
                Buffer.SetData(Data, begin, begin, end - begin);
                LightingPolicyBuffer.SetData(LightingPolicies, begin, begin, end - begin);
                begin = end;
            }
            ValidCount = 0;
            WarmingCount = 0;
            residentChunks.Clear();
            for (int i = 0; i < capacity; i++)
            {
                if (Data[i].identity.w <= 0f) continue;
                ValidCount++;
                if (Data[i].identity.w == 2f) WarmingCount++;
                residentChunks.Add(slotChunks[i]);
            }
            ResidentChunkCount = residentChunks.Count;
            Bvh.Update(traversalBounds, traversalActive, capacity);
            if (changed) unchecked { Revision++; }
            return changed;
        }

        private bool UseFarProxy(HybridLumenGIProxy proxy, Vector3 position, float nearDistance)
        {
            float distance = Mathf.Sqrt(proxy.GetWorldBounds().SqrDistance(position));
            if (!farStates.TryGetValue(proxy.StableId, out bool far)) far = distance > nearDistance;
            // Group-level hysteresis prevents repeated detail/aggregate replacement at the boundary.
            if (far && distance < nearDistance * 0.9f) far = false;
            else if (!far && distance > nearDistance * 1.1f) far = true;
            farStates[proxy.StableId] = far;
            return far;
        }

        private void SelectAtomicGroups(Vector3 position, float nearDistance, float farSquared, int capacity)
        {
            available.Clear(); grouped.Clear(); orderedGroups.Clear(); selectedCandidates.Clear(); ordinaryCandidates.Clear();
            representationAdds.Clear(); representationRemoves.Clear();
            PendingCapacity = 0;
            foreach (HlodGroup group in groups.Values) { group.seen = false; group.details.Clear(); group.target.Clear(); }
            for (int i = 0; i < candidates.Count; i++) available[candidates[i].proxy.StableId] = candidates[i];
            for (int i = 0; i < candidates.Count; i++)
            {
                HybridLumenGIProxy proxy = candidates[i].proxy, root = TopLevelRoot(proxy);
                if (root == null || !available.ContainsKey(root.StableId)) continue;
                if (!groups.TryGetValue(root.StableId, out HlodGroup group))
                { group = new HlodGroup { root = root }; groups.Add(root.StableId, group); }
                group.root = root; group.seen = true;
                grouped.Add(proxy.StableId); grouped.Add(root.StableId);
                if (proxy != root && !aggregates.Contains(proxy.StableId)) group.details.Add(proxy);
            }
            retiredIds.Clear();
            foreach (var pair in groups)
            {
                HlodGroup group = pair.Value;
                if (!group.seen) { retiredIds.Add(pair.Key); continue; }
                group.distance = available[group.root.StableId].distanceSquared;
                for (int i = 0; i < group.details.Count; i++)
                    group.distance = Mathf.Min(group.distance, available[group.details[i].StableId].distanceSquared);
                if (group.distance > farSquared)
                { group.published.Clear(); group.initialized = false; continue; }
                bool far = UseFarProxy(group.root, position, nearDistance);
                if (far || group.details.Count == 0) group.target.Add(group.root.StableId);
                else for (int i = 0; i < group.details.Count; i++) group.target.Add(group.details[i].StableId);
                group.capacityFallback = group.published.Count == 0 && group.target.Count > capacity;
                if (group.capacityFallback)
                {
                    group.target.Clear();
                    group.target.Add(group.root.StableId);
                }
                if ((!group.initialized || !group.published.SetEquals(group.target)) && ReadyToPublish(group))
                {
                    foreach (int id in group.published) if (!group.target.Contains(id)) representationRemoves.Add(id);
                    foreach (int id in group.target) if (!group.published.Contains(id)) representationAdds.Add(id);
                    group.published.Clear();
                    foreach (int id in group.target) group.published.Add(id);
                    group.initialized = true;
                }
                orderedGroups.Add(group);
            }
            for (int i = 0; i < retiredIds.Count; i++) groups.Remove(retiredIds[i]);
            orderedGroups.Sort(CompareGroups);
            // Protect the complete currently published representation before reserving any warm-up slots.
            for (int i = 0; i < orderedGroups.Count; i++)
                foreach (int id in orderedGroups[i].published) AddSelected(id, 1, capacity);
            for (int i = 0; i < orderedGroups.Count; i++)
            {
                HlodGroup group = orderedGroups[i];
                int extra = 0;
                foreach (int id in group.target) if (!desired.Contains(id)) extra++;
                bool targetFits = selectedCandidates.Count + extra <= capacity;
                if (group.capacityFallback || !targetFits) PendingCapacity++;
                if (!targetFits) continue;
                foreach (int id in group.target) AddSelected(id, group.published.Contains(id) ? 1 : 2, capacity);
            }
            for (int i = 0; i < candidates.Count; i++)
            {
                Candidate candidate = candidates[i];
                if (grouped.Contains(candidate.proxy.StableId) || candidate.distanceSquared > farSquared) continue;
                if (candidate.proxy.FarFieldOnly && !UseFarProxy(candidate.proxy, position, nearDistance)) continue;
                ordinaryCandidates.Add(candidate);
            }
            ordinaryCandidates.Sort(CompareCandidates);
            for (int i = 0; i < ordinaryCandidates.Count && selectedCandidates.Count < capacity; i++)
                AddSelected(ordinaryCandidates[i].proxy.StableId, 1, capacity);
        }

        private HybridLumenGIProxy TopLevelRoot(HybridLumenGIProxy proxy)
        {
            HybridLumenGIProxy parent = proxy.HLODParent;
            if (parent == null || !parent.isActiveAndEnabled)
            {
                // Unloading the last detail disables its proxy. Keep an existing
                // group's live root and publication receipt through that interval;
                // otherwise returning near recreates an empty group and drops the
                // old aggregate while the reloaded detail warms up.
                bool retainedRoot=groups.TryGetValue(proxy.StableId,out var group) && ReferenceEquals(group.root,proxy);
                return aggregates.Contains(proxy.StableId) || retainedRoot ? proxy : null;
            }
            HybridLumenGIProxy root = parent;
            for (int depth = 0; depth < 64; depth++)
            {
                parent = root.HLODParent;
                if (parent == null || !parent.isActiveAndEnabled) return root;
                if (parent == proxy) return null;
                root = parent;
            }
            return null;
        }

        private bool ReadyToPublish(HlodGroup group)
        {
            if (group.target.Count == 0) return false;
            foreach (int id in group.target)
            {
                if (!activeById.TryGetValue(id, out HybridLumenGIProxy proxy) || !slots.TryGetValue(id, out int slot) ||
                    Data[slot].identity.w < 0.5f || (int)Data[slot].identity.y != proxy.Revision || !readiness.IsReady(id, proxy.Revision)) return false;
            }
            return true;
        }
        private void AddSelected(int id, int phase, int capacity)
        {
            if (selectedCandidates.Count >= capacity || desired.Contains(id) || !available.TryGetValue(id, out Candidate candidate)) return;
            candidate.phase = phase; selectedCandidates.Add(candidate); desired.Add(id);
        }
        private static int CompareGroups(HlodGroup a, HlodGroup b)
        { int distance = a.distance.CompareTo(b.distance); return distance != 0 ? distance : a.root.StableId.CompareTo(b.root.StableId); }

        private static ProxyGpuData MakeData(Candidate candidate)
        {
            HybridLumenGIProxy proxy = candidate.proxy;
            Vector3 extents = candidate.bounds.extents;
            if (proxy.ProxyShape == HybridLumenGIProxy.Shape.Sphere)
                extents = Vector3.one * Mathf.Max(extents.x, extents.y, extents.z);
            Color albedo = proxy.GetDiffuseReflectanceLinear();
            Color emission = proxy.GetEmissionLinear();
            return new ProxyGpuData
            {
                centerShape = new Vector4(candidate.bounds.center.x, candidate.bounds.center.y, candidate.bounds.center.z, (float)proxy.ProxyShape),
                extentsRoughness = new Vector4(Mathf.Max(extents.x, 0.001f), Mathf.Max(extents.y, 0.001f), Mathf.Max(extents.z, 0.001f), proxy.Roughness),
                albedo = new Vector4(albedo.r, albedo.g, albedo.b, 1f),
                emission = new Vector4(emission.r, emission.g, emission.b, 1f),
                identity = new Vector4(proxy.StableId, proxy.Revision, candidate.field, candidate.phase)
            };
        }

        private bool EnsureCapacity(int capacity)
        {
            if (Buffer != null && LightingPolicyBuffer != null && Capacity == capacity) return false;
            for (int i = 0; i < Capacity; i++)
                if (Data[i].identity.w == 1f)
                    RecordDirty(i, (int)Data[i].identity.x, true, traversalBounds[i], false, default,
                        ChangeKind.Removed, (int)Data[i].identity.y, 0);
            ReleaseResources();
            Data = new ProxyGpuData[capacity];
            LightingPolicies = new LightingPolicyData[capacity];
            owners = new HybridLumenGIProxy[capacity];
            dirty = new bool[capacity];
            slotChunks = new Vector3Int[capacity];
            pendingAge = new int[capacity];
            traversalBounds = new Bounds[capacity];
            traversalActive = new bool[capacity];
            signatures = new Signature[capacity];
            Buffer = new ComputeBuffer(capacity, Stride, ComputeBufferType.Structured) { name = "Hybrid GI Scene" };
            Buffer.SetData(Data);
            LightingPolicyBuffer = new ComputeBuffer(capacity, LightingPolicyStride, ComputeBufferType.Structured) { name = "Hybrid GI Lighting Policies" };
            LightingPolicyBuffer.SetData(LightingPolicies);
            return true;
        }

        private int FindFreeSlot()
        {
            for (int i = 0; i < owners.Length; i++) if (owners[i] == null) return i;
            return -1;
        }

        private void Clear(int slot)
        {
            ProxyGpuData value = Data[slot];
            value.identity.w = 0f;
            Data[slot] = value;
            LightingPolicies[slot] = default;
            dirty[slot] = true;
            traversalActive[slot] = false;
        }

        private static Signature GetSignature(HybridLumenGIProxy proxy)
        {
            Mesh mesh = proxy.SourceMesh;
            HybridLumenGIMeshSdf sdf = proxy.MeshSdf;
            return new Signature
            {
                matrix = proxy.SdfLocalToWorld, meshId = mesh != null ? mesh.GetInstanceID() : 0,
                vertexCount = mesh != null ? mesh.vertexCount : 0, sdfId = sdf != null ? sdf.GetInstanceID() : 0,
                textureId = sdf != null && sdf.DistanceTexture != null ? sdf.DistanceTexture.GetInstanceID() : 0,
                geometryContentRevision = proxy.GeometryContentRevision,
                lighting = MakeLightingPolicy(proxy)
            };
        }
        private static ChangeKind ClassifyChange(ProxyGpuData old, Signature before, HybridLumenGIProxy proxy,
            Signature after, Bounds previousBounds, Bounds currentBounds)
        {
            ChangeKind kind = 0;
            // A same-size mesh edit can arrive together with motion/material changes.
            // Preserve it independently so RTAS/triangle attributes rebuild instead of refitting old geometry.
            if (before.geometryContentRevision != after.geometryContentRevision) kind |= ChangeKind.Manual;
            if (before.lighting.objectLayerBit != after.lighting.objectLayerBit ||
                before.lighting.renderingLayerMask != after.lighting.renderingLayerMask ||
                before.lighting.shadowCastingMode != after.lighting.shadowCastingMode) kind |= ChangeKind.Lighting;
            if (before.matrix != after.matrix || !previousBounds.Equals(currentBounds)) kind |= ChangeKind.Transform;
            if (before.meshId != after.meshId || before.vertexCount != after.vertexCount || before.sdfId != after.sdfId ||
                before.textureId != after.textureId || (int)old.centerShape.w != (int)proxy.ProxyShape) kind |= ChangeKind.Topology;
            Color diffuse = proxy.GetDiffuseReflectanceLinear(), emission = proxy.GetEmissionLinear();
            if (old.albedo.x != diffuse.r || old.albedo.y != diffuse.g || old.albedo.z != diffuse.b ||
                old.emission.x != emission.r || old.emission.y != emission.g || old.emission.z != emission.b ||
                old.extentsRoughness.w != proxy.Roughness) kind |= ChangeKind.Material;
            // MarkDirty also covers in-place vertex edits and unknown external dependencies.
            return kind == 0 ? ChangeKind.Manual : kind;
        }

        private static LightingPolicyData MakeLightingPolicy(HybridLumenGIProxy proxy)
        {
            Renderer renderer = proxy.SourceRenderer;
            int layer = renderer != null ? renderer.gameObject.layer : proxy.gameObject.layer;
            return new LightingPolicyData
            {
                objectLayerBit = 1u << layer,
                renderingLayerMask = renderer != null ? renderer.renderingLayerMask : 1u,
                shadowCastingMode = (uint)(renderer != null ? renderer.shadowCastingMode : ShadowCastingMode.On),
                reserved = 0u
            };
        }

        private static Bounds GetTraversalBounds(HybridLumenGIProxy proxy)
        {
            Bounds result = proxy.GetWorldBounds();
            if (proxy.ProxyShape == HybridLumenGIProxy.Shape.Sphere)
                result.extents = Vector3.one * Mathf.Max(result.extents.x, result.extents.y, result.extents.z);
            HybridLumenGIMeshSdf sdf = proxy.MeshSdf;
            if (sdf != null && sdf.IsValid)
            {
                Bounds local = sdf.LocalBounds;
                Matrix4x4 matrix = proxy.SdfLocalToWorld;
                Vector3 minimum = local.min, maximum = local.max;
                for (int corner = 0; corner < 8; corner++)
                    result.Encapsulate(matrix.MultiplyPoint3x4(new Vector3((corner & 1) == 0 ? minimum.x : maximum.x,
                        (corner & 2) == 0 ? minimum.y : maximum.y, (corner & 4) == 0 ? minimum.z : maximum.z)));
            }
            // Include the analytic minimum extent and a small floating-point broad-phase margin.
            Vector3 extent = result.extents;
            result.extents = new Vector3(Mathf.Max(extent.x, 0.001f), Mathf.Max(extent.y, 0.001f), Mathf.Max(extent.z, 0.001f));
            result.Expand(0.0002f);
            return result;
        }

        private void RecordDirty(int slot, int id, bool hasPrevious, Bounds previous, bool hasCurrent,
            Bounds current, ChangeKind kind, int previousRevision, int revision)
        {
            // Merge same-frame invalidation/reupload for the same object. Slot reuse with a different
            // stable ID remains two events, preserving the old object's region as well as the new one.
            for (int i = dirtyRegions.Count - 1; i >= 0; i--)
            {
                DirtyRegion existing = dirtyRegions[i];
                if (existing.Slot != slot || existing.StableId != id) continue;
                if (hasPrevious && !existing.HasPrevious)
                { existing.PreviousBounds = previous; existing.PreviousRevision = previousRevision; existing.HasPrevious = true; }
                if (hasCurrent) { existing.CurrentBounds = current; existing.Revision = revision; existing.HasCurrent = true; }
                existing.Kind |= kind;
                dirtyRegions[i] = existing;
                return;
            }
            dirtyRegions.Add(new DirtyRegion { Slot = slot, StableId = id, HasPrevious = hasPrevious, HasCurrent = hasCurrent,
                PreviousBounds = previous, CurrentBounds = current, PreviousRevision = previousRevision, Revision = revision, Kind = kind });
        }

        private static Vector3Int Chunk(Vector3 center, float size) => new Vector3Int(
            Mathf.FloorToInt(center.x / size), Mathf.FloorToInt(center.y / size), Mathf.FloorToInt(center.z / size));
        private static bool Finite(Vector3 value) => !float.IsNaN(value.x) && !float.IsNaN(value.y) && !float.IsNaN(value.z) &&
            !float.IsInfinity(value.x) && !float.IsInfinity(value.y) && !float.IsInfinity(value.z);
        private static int CompareCandidates(Candidate a, Candidate b)
        {
            int distance = a.distanceSquared.CompareTo(b.distanceSquared);
            return distance != 0 ? distance : a.proxy.StableId.CompareTo(b.proxy.StableId);
        }
        private static int CompareUploads(Candidate a, Candidate b)
        {
            int age = b.age.CompareTo(a.age);
            return age != 0 ? age : CompareCandidates(a, b);
        }

        private void ReleaseResources()
        {
            Buffer?.Release();
            Buffer = null;
            LightingPolicyBuffer?.Release();
            LightingPolicyBuffer = null;
            Data = Array.Empty<ProxyGpuData>();
            LightingPolicies = Array.Empty<LightingPolicyData>();
            owners = Array.Empty<HybridLumenGIProxy>();
            dirty = Array.Empty<bool>();
            slotChunks = Array.Empty<Vector3Int>();
            pendingAge = Array.Empty<int>();
            traversalBounds = Array.Empty<Bounds>(); traversalActive = Array.Empty<bool>(); signatures = Array.Empty<Signature>();
            Bvh.Dispose();
            readiness.Clear(); groups.Clear();
            slots.Clear();
            farStates.Clear();
            ValidCount = WarmingCount = PendingCapacity = PendingUploadCount = ResidentChunkCount = 0;
        }
        public void Dispose() { ReleaseResources(); dirtyRegions.Clear(); RequiresFullInvalidation = false; }
    }
}
