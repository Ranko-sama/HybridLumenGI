using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using UnityEngine;
using UnityEngine.Rendering;

namespace HybridLumenGI
{
    /// <summary>
    /// Per-camera, bounded residency of baked object-space mesh SDFs. Assets share
    /// voxel storage across instances; rigid motion only changes instance metadata.
    /// Missing, invalid, pending and over-budget assets use the analytic fallback.
    /// </summary>
    public sealed class HybridLumenGISdfAtlas : IDisposable
    {
        public const int DefaultVoxelBudget = 2 * 1024 * 1024; // 8 MiB, excluding metadata and source assets.
        public const int MetadataStride = 128;

        public readonly struct TransformChange
        {
            public readonly Bounds Bounds;
            public readonly Renderer SourceRenderer;
            internal TransformChange(Bounds bounds,Renderer sourceRenderer) { Bounds=bounds;SourceRenderer=sourceRenderer; }
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct SdfMetadata
        {
            public Matrix4x4 worldToLocal;
            public Vector4 boundsMinResolution;
            public Vector4 boundsSizeMinScale;
            public Vector4 voxelSizeError;
            public uint distanceOffset, stableId, revision, valid;
        }

        private sealed class Allocation
        {
            public int offset, count, textureId;
            public uint textureVersion;
            public bool ready, failed;
        }

        private struct FreeRange
        {
            public int begin, count;
            public FreeRange(int start, int length) { begin = start; count = length; }
        }

        private struct Candidate
        {
            public int slot;
            public HybridLumenGIMeshSdf asset;
            public SdfMetadata metadata;
        }

        private struct Representation
        {
            public bool present, ready, published;
            public uint stableId, revision;
            public HybridLumenGIProxy proxy;
            public Renderer sourceRenderer;
            public HybridLumenGIMeshSdf asset;
            public int textureId;
            public uint textureVersion;
            public SdfMetadata metadata;
            public Bounds worldBounds;
        }

        private static readonly int MetadataId = Shader.PropertyToID("_HLGI_SdfMetadata");
        private static readonly int DistancesId = Shader.PropertyToID("_HLGI_SdfDistances");
        private static readonly int SlotCountId = Shader.PropertyToID("_HLGI_SdfSlotCount");
        private static readonly int VoxelCountId = Shader.PropertyToID("_HLGI_SdfVoxelCount");
        private static readonly int StepsId = Shader.PropertyToID("_HLGI_SdfTraceSteps");
        private readonly Dictionary<HybridLumenGIMeshSdf, Allocation> allocations = new Dictionary<HybridLumenGIMeshSdf, Allocation>();
        private readonly HashSet<HybridLumenGIMeshSdf> desired = new HashSet<HybridLumenGIMeshSdf>();
        private readonly HashSet<HybridLumenGIMeshSdf> visited = new HashSet<HybridLumenGIMeshSdf>();
        private readonly List<HybridLumenGIMeshSdf> removals = new List<HybridLumenGIMeshSdf>();
        private readonly List<FreeRange> freeRanges = new List<FreeRange>();
        private readonly List<Candidate> candidates = new List<Candidate>();
        private readonly List<Bounds> representationChangedBounds = new List<Bounds>();
        private readonly List<Bounds> geometryChangedBounds = new List<Bounds>();
        private readonly List<Bounds> transformChangedBounds = new List<Bounds>();
        private readonly List<TransformChange> transformChanges = new List<TransformChange>();
        private ComputeBuffer metadataBuffer, distancesBuffer;
        private SdfMetadata[] metadata = Array.Empty<SdfMetadata>();
        private SdfMetadata[] nextMetadata = Array.Empty<SdfMetadata>();
        private Representation[] representations = Array.Empty<Representation>();
        private Representation[] nextRepresentations = Array.Empty<Representation>();
        private int uploadCursor;

        /// <summary>Hard voxel upload cap per Prepare. A single volume must fit this cap.</summary>
        public int UploadVoxelBudget { get; set; } = 64 * 64 * 64;
        public int TraceSteps { get; set; } = 64;
        public int ResidentMeshCount { get; private set; }
        public int ResidentAssetCount { get; private set; }
        public int PendingUploadCount { get; private set; }
        public int FallbackCount { get; private set; }
        public int RejectedSourceCount { get; private set; }
        public int UploadedVoxels { get; private set; }
        public int UsedVoxels { get; private set; }
        /// <summary>
        /// Published old and new world bounds of actual SDF/fallback representation transitions
        /// in the last Prepare. Warming endpoints and material-only revisions add no regions.
        /// Includes asynchronous budget completion even when the scene revision is unchanged.
        /// </summary>
        public IReadOnlyList<Bounds> RepresentationChangedBounds => representationChangedBounds;
        /// <summary>
        /// Strong source/representation changes, which cannot be exempted by receiver
        /// pose history. TransformChangedBounds also invalidate world lighting caches.
        /// Pure prepared HLOD publication/unchanged retirement remains reactive-only.
        /// </summary>
        public IReadOnlyList<Bounds> GeometryChangedBounds => geometryChangedBounds;
        /// <summary>
        /// Published old/new domains with an exact scene receipt proving only pose
        /// (optionally lighting policy) changed. World caches still invalidate these;
        /// only a receiver with separately proven object history may exempt its pose.
        /// </summary>
        public IReadOnlyList<Bounds> TransformChangedBounds => transformChangedBounds;
        /// <summary>Same pose domains with the frozen Renderer owner for receiver-local exemptions.</summary>
        public IReadOnlyList<TransformChange> TransformChanges => transformChanges;
        /// <summary>
        /// Metadata and voxel upload readiness from the last Prepare, including warming slots.
        /// Pure CPU query, not a GPU completion fence and not proof that the scene has published it.
        /// </summary>
        public bool IsReady(int slot, uint stableId, uint revision) => slot >= 0 && slot < metadata.Length &&
            (metadata[slot].valid & 1u) != 0 && metadata[slot].stableId == stableId && metadata[slot].revision == revision;
        public bool IsReady(int slot, int stableId, int revision) => IsReady(slot, (uint)stableId, (uint)revision);
        /// <summary>Read-only pre-publication check; does not consume this frame's change events.</summary>
        public bool IsSourceCurrent(int slot,HybridLumenGIProxy proxy,int stableId,int revision)
        {
            if(proxy==null || proxy.Revision!=revision || !IsReady(slot,stableId,revision) || slot>=representations.Length) return false;
            return MatchesCurrentSource(representations[slot],proxy);
        }
        private static bool MatchesCurrentSource(Representation previous,HybridLumenGIProxy proxy)
        {
            if(proxy==null || proxy.Revision!=(int)previous.revision) return false;
            var asset=proxy.MeshSdf;
            if(asset==null || !ReferenceEquals(asset,previous.asset) || !TryMetadata(proxy,asset,out SdfMetadata current)) return false;
            Texture3D texture=asset.DistanceTexture;
            SdfMetadata old=previous.metadata;
            return texture.GetInstanceID()==previous.textureId && texture.updateCount==previous.textureVersion &&
                old.valid==(asset.Watertight?3u:1u) && old.worldToLocal==current.worldToLocal &&
                old.boundsMinResolution==current.boundsMinResolution && old.boundsSizeMinScale==current.boundsSizeMinScale &&
                old.voxelSizeError==current.voxelSizeError;
        }
        public long AllocatedBytes => (distancesBuffer != null ? distancesBuffer.count * 4L : 0L) +
            (metadataBuffer != null ? metadataBuffer.count * (long)MetadataStride : 0L);

        public bool Prepare(HybridLumenGIScene scene, int maxVoxels = DefaultVoxelBudget)
        {
            representationChangedBounds.Clear();
            geometryChangedBounds.Clear();
            transformChangedBounds.Clear();
            transformChanges.Clear();
            if (scene == null) throw new ArgumentNullException(nameof(scene));
            maxVoxels = Mathf.Clamp(maxVoxels, 0, 16 * 1024 * 1024);
            bool changed = EnsureMetadata(scene.Capacity);
            desired.Clear();
            candidates.Clear();
            FallbackCount = ResidentMeshCount = ResidentAssetCount = PendingUploadCount = UploadedVoxels = RejectedSourceCount = 0;
            Array.Clear(nextMetadata, 0, nextMetadata.Length);
            Array.Clear(nextRepresentations, 0, nextRepresentations.Length);

            for (int slot = 0; slot < scene.Capacity; slot++)
            {
                if (scene.Data[slot].identity.w < 0.5f) continue;
                var data = scene.Data[slot];
                HybridLumenGIProxy proxy = scene.GetProxy(slot);
                nextRepresentations[slot] = new Representation
                {
                    present = true,
                    published = data.identity.w > 0.5f && data.identity.w < 1.5f,
                    stableId = (uint)data.identity.x, revision = (uint)data.identity.y,
                    proxy = proxy,
                    sourceRenderer = proxy!=null?proxy.SourceRenderer:null,
                    worldBounds = new Bounds(new Vector3(data.centerShape.x, data.centerShape.y, data.centerShape.z),
                        new Vector3(data.extentsRoughness.x, data.extentsRoughness.y, data.extentsRoughness.z) * 2f)
                };
                if (proxy == null) continue;
                if (proxy.TryGetColliderBox(out _, out Matrix4x4 worldToAxes, out Vector3 halfSize))
                {
                    // Keep the oriented fallback until an authored mesh volume becomes resident.
                    nextMetadata[slot] = new SdfMetadata
                    {
                        worldToLocal = worldToAxes, boundsSizeMinScale = halfSize,
                        stableId = (uint)data.identity.x, revision = (uint)data.identity.y, valid = 4u
                    };
                }
                HybridLumenGIMeshSdf asset = proxy.MeshSdf;
                if (asset == null) continue;
                FallbackCount++;
                if (!asset.MatchesSource(asset.SourceMesh)) { RejectedSourceCount++; continue; }
                if (!TryMetadata(proxy, asset, out SdfMetadata value)) continue;
                int count = asset.Resolution * asset.Resolution * asset.Resolution;
                if (count > maxVoxels) continue;
                value.stableId = (uint)scene.Data[slot].identity.x;
                value.revision = (uint)scene.Data[slot].identity.y;
                candidates.Add(new Candidate { slot = slot, asset = asset, metadata = value });
                desired.Add(asset);
            }

            // Do not reserve 8 MiB for cameras with no usable mesh SDF assets.
            int capacity = desired.Count == 0 ? 1 : Mathf.Max(1, maxVoxels);
            changed |= EnsureDistances(capacity);
            removals.Clear();
            foreach (var pair in allocations)
                if (!desired.Contains(pair.Key)) removals.Add(pair.Key);
            foreach (HybridLumenGIMeshSdf asset in removals)
            {
                Allocation allocation = allocations[asset];
                Free(allocation.offset, allocation.count);
                allocations.Remove(asset);
                changed = true;
            }

            int uploadRemaining = Mathf.Max(0, UploadVoxelBudget);
            visited.Clear();
            // Rotate the first candidate so a repeatedly edited asset cannot
            // monopolize the upload budget and starve later stable slots forever.
            int firstUpload = candidates.Count > 0 ? uploadCursor % candidates.Count : 0;
            for (int rank = 0; rank < candidates.Count; rank++)
            {
                Candidate candidate = candidates[(firstUpload + rank) % candidates.Count];
                HybridLumenGIMeshSdf asset = candidate.asset;
                if (!visited.Add(asset)) continue;
                Texture3D texture = asset.DistanceTexture;
                int count = asset.Resolution * asset.Resolution * asset.Resolution;
                if (allocations.TryGetValue(asset, out Allocation allocation) && allocation.count != count)
                {
                    Free(allocation.offset, allocation.count);
                    allocations.Remove(asset);
                    allocation = null;
                    changed = true;
                }
                if (allocation == null)
                {
                    if (!Allocate(count, out int offset)) continue;
                    allocation = new Allocation { offset = offset, count = count };
                    allocations.Add(asset, allocation);
                }
                int textureId = texture.GetInstanceID();
                uint textureVersion = texture.updateCount;
                if (allocation.textureId != textureId || allocation.textureVersion != textureVersion)
                {
                    changed |= allocation.ready;
                    allocation.textureId = textureId;
                    allocation.textureVersion = textureVersion;
                    allocation.ready = allocation.failed = false;
                }
                if (!allocation.ready && !allocation.failed)
                {
                    if (count <= uploadRemaining)
                    {
                        try
                        {
                            // This NativeArray aliases the readable texture. Do not dispose it or
                            // create a managed float[] copy; SetData copies only this upload range.
                            var voxels = texture.GetPixelData<float>(0);
                            if (voxels.Length != count) throw new InvalidOperationException("Unexpected RFloat SDF voxel count.");
                            distancesBuffer.SetData(voxels, 0, allocation.offset, count);
                            allocation.ready = true;
                            uploadRemaining -= count;
                            UploadedVoxels += count;
                            changed = true;
                        }
                        catch (Exception exception)
                        {
                            allocation.failed = true;
                            Debug.LogWarning($"HybridLumenGI mesh SDF '{asset.name}' uses its analytic fallback: {exception.Message}", asset);
                        }
                    }
                    else PendingUploadCount++;
                }
                if (allocation.ready) ResidentAssetCount++;
            }
            uploadCursor = candidates.Count > 0 ? (firstUpload + 1) % candidates.Count : 0;

            foreach (Candidate candidate in candidates)
            {
                if (!allocations.TryGetValue(candidate.asset, out Allocation allocation) || !allocation.ready) continue;
                SdfMetadata value = candidate.metadata;
                value.distanceOffset = (uint)allocation.offset;
                value.valid = candidate.asset.Watertight ? 3u : 1u;
                nextMetadata[candidate.slot] = value;
                Representation representation = nextRepresentations[candidate.slot];
                representation.ready = true;
                representation.asset = candidate.asset;
                representation.textureId = allocation.textureId;
                representation.textureVersion = allocation.textureVersion;
                representation.metadata = value;
                // Include padded SDF coverage as well as the analytic fallback bounds. Transform
                // all corners, so non-uniform scale, reflection and shear stay conservative.
                Bounds localBounds = candidate.asset.LocalBounds;
                Vector3 minimum = localBounds.min, maximum = localBounds.max;
                Matrix4x4 localToWorld = value.worldToLocal.inverse;
                for (int corner = 0; corner < 8; corner++)
                    representation.worldBounds.Encapsulate(localToWorld.MultiplyPoint3x4(new Vector3(
                        (corner & 1) == 0 ? minimum.x : maximum.x,
                        (corner & 2) == 0 ? minimum.y : maximum.y,
                        (corner & 4) == 0 ? minimum.z : maximum.z)));
                nextRepresentations[candidate.slot] = representation;
                ResidentMeshCount++;
                FallbackCount--;
            }

            // Small metadata arrays are retained across frames; upload changed contiguous spans.
            for (int begin = 0; begin < metadata.Length;)
            {
                if (Equal(metadata[begin], nextMetadata[begin])) { begin++; continue; }
                int end = begin + 1;
                while (end < metadata.Length && !Equal(metadata[end], nextMetadata[end])) end++;
                Array.Copy(nextMetadata, begin, metadata, begin, end - begin);
                metadataBuffer.SetData(metadata, begin, begin, end - begin);
                begin = end;
                changed = true;
            }
            UsedVoxels = 0;
            foreach (Allocation allocation in allocations.Values) UsedVoxels += allocation.count;
            RecordRepresentationChanges(scene);
            return changed || representationChangedBounds.Count > 0;
        }

        private void RecordRepresentationChanges(HybridLumenGIScene scene)
        {
            int count = Math.Max(representations.Length, nextRepresentations.Length);
            for (int slot = 0; slot < count; slot++)
            {
                Representation before = slot < representations.Length ? representations[slot] : default;
                Representation after = slot < nextRepresentations.Length ? nextRepresentations[slot] : default;
                // Analytic-only changes are already reported by the scene. A queued SDF which
                // never became ready has not changed the traced representation yet.
                if (!before.ready && !after.ready) continue;
                if (!before.published && !after.published) continue;
                bool same = before.ready && after.ready && SameRepresentation(before, after);
                if (same && before.published == after.published) continue;
                bool purePublication = same && !before.published && after.published;
                // A disappearing slot alone cannot establish HLOD retirement: it may be a real
                // deletion, slot reuse or an edit. Require the exact old identity/revision receipt
                // and recheck the live old source because texture edits need not bump proxy revision.
                bool pureRetirement = before.published && !after.published && before.ready &&
                    (!after.present || (after.stableId == before.stableId && same)) &&
                    IsPureRepresentationRemoval(scene,slot,before) && MatchesCurrentSource(before,before.proxy);
                bool pose = IsPureTransform(scene,slot,before,after);
                bool hard = !purePublication && !pureRetirement && !pose;
                if (before.present && before.published)
                {
                    representationChangedBounds.Add(before.worldBounds);
                    if(hard) geometryChangedBounds.Add(before.worldBounds);
                    if(pose)
                    { transformChangedBounds.Add(before.worldBounds);transformChanges.Add(new TransformChange(before.worldBounds,before.sourceRenderer)); }
                }
                if (after.present && after.published)
                {
                    representationChangedBounds.Add(after.worldBounds);
                    if(hard) geometryChangedBounds.Add(after.worldBounds);
                    if(pose)
                    { transformChangedBounds.Add(after.worldBounds);transformChanges.Add(new TransformChange(after.worldBounds,after.sourceRenderer)); }
                }
            }
            // Keep the prior slot layout until after comparison, including slots removed by resize.
            Representation[] previous = representations;
            representations = nextRepresentations;
            nextRepresentations = previous.Length == representations.Length ? previous : new Representation[representations.Length];
        }

        private static bool IsPureRepresentationRemoval(HybridLumenGIScene scene,int slot,Representation previous)
        {
            bool found=false;
            var expected=HybridLumenGIScene.ChangeKind.Removed|HybridLumenGIScene.ChangeKind.Representation;
            foreach(var change in scene.DirtyRegions)
            {
                if((uint)change.StableId!=previous.stableId) continue;
                if(change.Slot!=slot || change.Kind!=expected || !change.HasPrevious || change.HasCurrent ||
                    (uint)change.PreviousRevision!=previous.revision) return false;
                found=true;
            }
            return found;
        }

        private static bool IsPureTransform(HybridLumenGIScene scene,int slot,Representation before,Representation after)
        {
            if(!before.present || !after.present || !before.ready || !after.ready || !before.published || !after.published ||
                before.proxy==null || !ReferenceEquals(before.proxy,after.proxy) || !ReferenceEquals(before.sourceRenderer,after.sourceRenderer) ||
                after.proxy.Revision!=(int)after.revision || before.stableId!=after.stableId ||
                !ReferenceEquals(before.asset,after.asset) || before.textureId!=after.textureId || before.textureVersion!=after.textureVersion)
                return false;
            SdfMetadata x=before.metadata,y=after.metadata;
            // worldToLocal and the derived world-space distance scale may change with
            // pose. Local volume shape, resolution, signedness and error may not.
            if(x.stableId!=y.stableId || x.valid!=y.valid || !x.boundsMinResolution.Equals(y.boundsMinResolution) ||
                x.boundsSizeMinScale.x!=y.boundsSizeMinScale.x || x.boundsSizeMinScale.y!=y.boundsSizeMinScale.y ||
                x.boundsSizeMinScale.z!=y.boundsSizeMinScale.z || !x.voxelSizeError.Equals(y.voxelSizeError)) return false;
            bool found=false;
            const HybridLumenGIScene.ChangeKind allowed=HybridLumenGIScene.ChangeKind.Transform|HybridLumenGIScene.ChangeKind.Lighting;
            foreach(var change in scene.DirtyRegions)
            {
                if((uint)change.StableId!=before.stableId) continue;
                if(change.Slot!=slot || !change.HasPrevious || !change.HasCurrent ||
                    (uint)change.PreviousRevision!=before.revision || (uint)change.Revision!=after.revision ||
                    (change.Kind&HybridLumenGIScene.ChangeKind.Transform)==0 || (change.Kind&~allowed)!=0) return false;
                found=true;
            }
            return found;
        }

        private static bool SameRepresentation(Representation a, Representation b)
        {
            SdfMetadata x = a.metadata, y = b.metadata;
            // Revision also changes for material edits. Distance offsets are allocator addresses,
            // not geometry. Neither should invalidate an unchanged traced distance field.
            return ReferenceEquals(a.asset, b.asset) && a.textureId == b.textureId && a.textureVersion == b.textureVersion &&
                a.worldBounds.Equals(b.worldBounds) && x.stableId == y.stableId && x.valid == y.valid &&
                x.worldToLocal == y.worldToLocal && x.boundsMinResolution == y.boundsMinResolution &&
                x.boundsSizeMinScale == y.boundsSizeMinScale && x.voxelSizeError == y.voxelSizeError;
        }

        private static bool TryMetadata(HybridLumenGIProxy proxy, HybridLumenGIMeshSdf asset, out SdfMetadata value)
        {
            value = default;
            Texture3D texture = asset.DistanceTexture;
            int size = asset.Resolution;
            if (!asset.IsValid || size < 16 || size > 64 || texture == null || !texture.isReadable ||
                texture.format != TextureFormat.RFloat || texture.width != size || texture.height != size || texture.depth != size) return false;
            // Identity alone does not prove that baked voxels still represent an edited Mesh.
            if (!asset.MatchesSource(asset.SourceMesh)) return false;
            Renderer renderer = proxy.SourceRenderer;
            if (renderer != null)
            {
                if (!(renderer is MeshRenderer) && !HybridLumenGIDeformedMesh.HasSnapshot(renderer)) return false;
                if (HybridLumenGIDeformedMesh.GetSourceMesh(renderer) != asset.SourceMesh) return false;
            }
            Bounds bounds = asset.LocalBounds;
            Vector3 extent = bounds.size;
            if (!Finite(bounds.min) || !Finite(extent) || Mathf.Min(extent.x, extent.y, extent.z) <= 1e-6f ||
                !Finite(asset.InterpolationError) || asset.InterpolationError < 0) return false;
            Matrix4x4 localToWorld = proxy.SdfLocalToWorld;
            float determinant = localToWorld.determinant;
            if (!Finite(determinant) || Mathf.Abs(determinant) <= 1e-12f) return false;
            Matrix4x4 worldToLocal = localToWorld.inverse;
            for (int i = 0; i < 16; i++) if (!Finite(worldToLocal[i])) return false;

            // ||worldToLocal||_F bounds its spectral norm. Its reciprocal is a
            // conservative distance scale even under nonuniform scale and shear.
            float square = 0f;
            for (int row = 0; row < 3; row++)
                for (int column = 0; column < 3; column++) square += worldToLocal[row, column] * worldToLocal[row, column];
            float minScale = 1f / Mathf.Sqrt(square);
            if (!Finite(minScale) || minScale <= 1e-8f) return false;
            Vector3 voxel = extent / size;
            value = new SdfMetadata
            {
                worldToLocal = worldToLocal,
                boundsMinResolution = new Vector4(bounds.min.x, bounds.min.y, bounds.min.z, size),
                boundsSizeMinScale = new Vector4(extent.x, extent.y, extent.z, minScale),
                voxelSizeError = new Vector4(voxel.x, voxel.y, voxel.z, Mathf.Max(asset.InterpolationError, voxel.magnitude))
            };
            return true;
        }

        private bool EnsureMetadata(int count)
        {
            count = Mathf.Max(1, count);
            if (metadataBuffer != null && metadata.Length == count) return false;
            metadataBuffer?.Release();
            metadata = new SdfMetadata[count];
            nextMetadata = new SdfMetadata[count];
            nextRepresentations = new Representation[count];
            metadataBuffer = new ComputeBuffer(count, MetadataStride, ComputeBufferType.Structured) { name = "Hybrid GI SDF Metadata" };
            metadataBuffer.SetData(metadata);
            return true;
        }

        private bool EnsureDistances(int count)
        {
            if (distancesBuffer != null && distancesBuffer.count == count) return false;
            distancesBuffer?.Release();
            distancesBuffer = new ComputeBuffer(count, sizeof(float), ComputeBufferType.Structured) { name = "Hybrid GI SDF Voxels" };
            allocations.Clear();
            freeRanges.Clear();
            freeRanges.Add(new FreeRange(0, count));
            return true;
        }

        private bool Allocate(int count, out int offset)
        {
            // Best fit reduces fragmentation without a surprise full-atlas copy.
            int best = -1;
            for (int i = 0; i < freeRanges.Count; i++)
                if (freeRanges[i].count >= count && (best < 0 || freeRanges[i].count < freeRanges[best].count)) best = i;
            offset = 0;
            if (best < 0) return false;
            FreeRange range = freeRanges[best];
            offset = range.begin;
            if (range.count == count) freeRanges.RemoveAt(best);
            else freeRanges[best] = new FreeRange(range.begin + count, range.count - count);
            return true;
        }

        private void Free(int offset, int count)
        {
            int position = 0;
            while (position < freeRanges.Count && freeRanges[position].begin < offset) position++;
            freeRanges.Insert(position, new FreeRange(offset, count));
            for (int i = Math.Max(0, position - 1); i + 1 < freeRanges.Count;)
            {
                FreeRange a = freeRanges[i], b = freeRanges[i + 1];
                if (a.begin + a.count == b.begin)
                {
                    freeRanges[i] = new FreeRange(a.begin, a.count + b.count);
                    freeRanges.RemoveAt(i + 1);
                }
                else i++;
            }
        }

        private static bool Equal(SdfMetadata a, SdfMetadata b) => a.worldToLocal == b.worldToLocal &&
            a.boundsMinResolution == b.boundsMinResolution && a.boundsSizeMinScale == b.boundsSizeMinScale &&
            a.voxelSizeError == b.voxelSizeError && a.distanceOffset == b.distanceOffset && a.stableId == b.stableId &&
            a.revision == b.revision && a.valid == b.valid;
        private static bool Finite(float value) => !float.IsNaN(value) && !float.IsInfinity(value);
        private static bool Finite(Vector3 value) => Finite(value.x) && Finite(value.y) && Finite(value.z);

        /// <summary>Bind inside the dispatch callback after Prepare, on the owning camera's queue.</summary>
        public void Bind(CommandBuffer command, ComputeShader compute, int kernel)
        {
            if (metadataBuffer == null || distancesBuffer == null) throw new InvalidOperationException("Prepare the SDF atlas before binding.");
            command.SetComputeBufferParam(compute, kernel, MetadataId, metadataBuffer);
            command.SetComputeBufferParam(compute, kernel, DistancesId, distancesBuffer);
            command.SetComputeIntParam(compute, SlotCountId, metadata.Length);
            command.SetComputeIntParam(compute, VoxelCountId, distancesBuffer.count);
            command.SetComputeIntParam(compute, StepsId, Mathf.Clamp(TraceSteps, 8, 128));
        }

        public void Dispose()
        {
            metadataBuffer?.Release();
            distancesBuffer?.Release();
            metadataBuffer = distancesBuffer = null;
            metadata = nextMetadata = Array.Empty<SdfMetadata>();
            allocations.Clear();
            freeRanges.Clear();
            desired.Clear();
            visited.Clear();
            candidates.Clear();
            removals.Clear();
            representations = nextRepresentations = Array.Empty<Representation>();
            representationChangedBounds.Clear();
            geometryChangedBounds.Clear();
            transformChangedBounds.Clear();
            transformChanges.Clear();
            uploadCursor = 0;
            UsedVoxels = UploadedVoxels = ResidentMeshCount = ResidentAssetCount = PendingUploadCount = FallbackCount = RejectedSourceCount = 0;
        }
    }
}
