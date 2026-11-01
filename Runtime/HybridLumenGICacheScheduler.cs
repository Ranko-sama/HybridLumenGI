using System;
using System.Collections.Generic;
using UnityEngine;

namespace HybridLumenGI
{
    /// <summary>Hard-budget patch scheduler with persistent dirty priorities and an oldest-service fairness quota.</summary>
    public sealed class HybridLumenGICacheScheduler : IDisposable
    {
        private struct Candidate { public int index; public float priority; public long lastService; }
        private sealed class OldestComparer : IComparer<Candidate>
        {
            public int Compare(Candidate a, Candidate b)
            { int age = a.lastService.CompareTo(b.lastService); return age != 0 ? age : a.index.CompareTo(b.index); }
        }
        private sealed class PriorityComparer : IComparer<Candidate>
        {
            public int Compare(Candidate a, Candidate b)
            {
                int priority = b.priority.CompareTo(a.priority);
                if (priority != 0) return priority;
                int age = a.lastService.CompareTo(b.lastService);
                return age != 0 ? age : a.index.CompareTo(b.index);
            }
        }
        private static readonly OldestComparer Oldest = new OldestComparer();
        private static readonly PriorityComparer Priority = new PriorityComparer();
        private const float GlobalLightingPriority = 750f;
        // Rank affected neighbours before the global backlog but after changed source cards (1000).
        private const float NearbySurfacePriority = GlobalLightingPriority + 1f;
        public ComputeBuffer UpdateMask { get; private set; }
        public uint[] Mask { get; private set; } = Array.Empty<uint>();
        public int EntryCount => Mask.Length;
        public int PatchesPerCard { get; private set; }
        public int SelectedCount { get; private set; }
        public int FairnessSelectedCount { get; private set; }
        public int ValidEntryCount { get; private set; }
        public int UnscheduledEntryCount { get; private set; }
        public float ScheduledCoverage => ValidEntryCount > 0 ? 1f - (float)UnscheduledEntryCount / ValidEntryCount : 0f;
        public long MaxFramesSinceUpdate { get; private set; }
        private Candidate[] candidates = Array.Empty<Candidate>();
        private long[] lastService = Array.Empty<long>();
        private int[] lastScheduledFrame = Array.Empty<int>();
        private float[] pendingPriority = Array.Empty<float>();
        private bool[] coveredRevision = Array.Empty<bool>();
        private int[] owners = Array.Empty<int>(), stableIds = Array.Empty<int>(), revisions = Array.Empty<int>();
        private uint[] generations = Array.Empty<uint>(), layouts = Array.Empty<uint>();
        private float[] ownerPriorities = Array.Empty<float>();
        private static readonly uint[] EmptyMask = new uint[1];
        private long tick;
        private int lastFrame = int.MinValue;
        private uint lastAtlasGeneration;

        public int LastScheduledFrame(int entry) => entry >= 0 && entry < lastScheduledFrame.Length ? lastScheduledFrame[entry] : -1;

        public void Prepare(HybridLumenGIScene scene, HybridLumenGISurfaceCache surface, int grid, int frame, int budget, bool lightingChanged,
            float influenceRadius = 50f, bool upload = true, IReadOnlyList<Bounds> localLightChanges = null)
            => Prepare(scene, surface, grid, frame, budget, lightingChanged, influenceRadius, upload, localLightChanges, null, 0f);

        internal void Prepare(HybridLumenGIScene scene, HybridLumenGISurfaceCache surface, int grid, int frame, int budget, bool lightingChanged,
            float influenceRadius, bool upload, IReadOnlyList<Bounds> localLightChanges, IList<Bounds> changedSurfaces, float surfaceInfluenceRadius)
        {
            if (scene == null) throw new ArgumentNullException(nameof(scene));
            if (surface == null) throw new ArgumentNullException(nameof(surface));
            grid = Mathf.Clamp(grid, 1, 4);
            EnsureCapacity(surface.CardCount, grid * grid);
            bool atlasChanged = surface.AtlasGeneration != lastAtlasGeneration;
            lastAtlasGeneration = surface.AtlasGeneration;
            if (ownerPriorities.Length != scene.Capacity) ownerPriorities = new float[scene.Capacity];
            if (frame != lastFrame) { tick++; lastFrame = frame; }
            Array.Clear(Mask, 0, Mask.Length);
            SelectedCount = FairnessSelectedCount = ValidEntryCount = UnscheduledEntryCount = 0;
            MaxFramesSinceUpdate = 0;
            influenceRadius = Mathf.Max(0f, influenceRadius);
            surfaceInfluenceRadius = Mathf.Max(0f, surfaceInfluenceRadius);
            float surfaceRadiusSquared = surfaceInfluenceRadius * surfaceInfluenceRadius;
            for (int slot = 0; slot < scene.Capacity; slot++)
            {
                int id = scene.Data[slot].identity.w > 0.5f ? (int)scene.Data[slot].identity.x : 0;
                ownerPriorities[slot] = id == 0 ? 0f : DirtyPriority(scene, slot, id, influenceRadius, localLightChanges,
                    changedSurfaces, surfaceRadiusSquared);
            }
            int candidateCount = 0;
            int[] cardOwners = surface.CardOwners;
            bool[] readyCards = surface.ReadyMask;
            for (int card = 0; card < surface.CardCount; card++)
            {
                int slot = cardOwners != null && card < cardOwners.Length ? cardOwners[card] : -1;
                bool validOwner = slot >= 0 && slot < scene.Capacity && scene.Data[slot].identity.w > 0.5f;
                int id = validOwner ? (int)scene.Data[slot].identity.x : 0;
                int revision = validOwner ? (int)scene.Data[slot].identity.y : 0;
                uint generation = surface.GetGeneration(card);
                uint layout = validOwner ? surface.GetLayoutGeneration(slot) : 0;
                if (generation == 0 || layout == 0) id = 0;
                bool identityChanged = id != stableIds[card] || slot != owners[card];
                bool contentChanged = identityChanged || atlasChanged || revision != revisions[card] || generation != generations[card] || layout != layouts[card];
                owners[card] = slot; stableIds[card] = id; revisions[card] = revision;
                generations[card] = generation; layouts[card] = layout;
                float changePriority = id == 0 ? 0f : ownerPriorities[slot];
                for (int patch = 0; patch < PatchesPerCard; patch++)
                {
                    int entry = card * PatchesPerCard + patch;
                    if (identityChanged)
                    {
                        // A new object must not inherit another object's samples or scheduling age.
                        lastService[entry] = tick - 1;
                        lastScheduledFrame[entry] = -1;
                        coveredRevision[entry] = false;
                        pendingPriority[entry] = 0f;
                    }
                    if (id == 0) { coveredRevision[entry] = false; pendingPriority[entry] = 0f; continue; }
                    if (contentChanged)
                    {
                        // Generation/layout changes invalidate coverage, but retain the service
                        // clock for the same owner. Continually recaptured cards must not starve.
                        coveredRevision[entry] = false;
                        lastScheduledFrame[entry] = -1;
                        pendingPriority[entry] = Mathf.Max(pendingPriority[entry], 1000f);
                    }
                    // Keep dirtiness until this particular patch is serviced, not merely for one frame.
                    pendingPriority[entry] = Mathf.Max(pendingPriority[entry], changePriority);
                    if (changePriority > 0f) coveredRevision[entry] = false;
                    if (lightingChanged) { pendingPriority[entry] = Mathf.Max(pendingPriority[entry], GlobalLightingPriority); coveredRevision[entry] = false; }
                    if (readyCards == null || card >= readyCards.Length || !readyCards[card])
                    {
                        // Page misses consume no update work. Preserve dirtiness until capture makes
                        // the card available; a short readiness array treats missing entries as absent.
                        coveredRevision[entry] = false;
                        pendingPriority[entry] = Mathf.Max(pendingPriority[entry], 500f);
                        continue;
                    }
                    candidates[candidateCount++] = new Candidate { index = entry, priority = pendingPriority[entry], lastService = lastService[entry] };
                }
            }
            ValidEntryCount = candidateCount;
            budget = Mathf.Clamp(budget, 0, candidateCount);
            if (budget > 0)
            {
                // Revision changes retain the fairness service clock. Otherwise continuously moving
                // instances could repeatedly reset their age and starve stable distant patches.
                Array.Sort(candidates, 0, candidateCount, Oldest);
                int quota = Mathf.Min(budget, (budget + 3) / 4);
                for (int i = 0; i < quota; i++) Select(candidates[i].index, frame);
                FairnessSelectedCount = SelectedCount;
                Array.Sort(candidates, 0, candidateCount, Priority);
                for (int i = 0; i < candidateCount && SelectedCount < budget; i++)
                    if (Mask[candidates[i].index] == 0) Select(candidates[i].index, frame);
            }
            for (int i = 0; i < candidateCount; i++)
            {
                int entry = candidates[i].index;
                if (!coveredRevision[entry]) UnscheduledEntryCount++;
                MaxFramesSinceUpdate = Math.Max(MaxFramesSinceUpdate, tick - lastService[entry]);
            }
            if (upload)
            {
                if (UpdateMask == null) UpdateMask = new ComputeBuffer(Mathf.Max(1, Mask.Length), sizeof(uint), ComputeBufferType.Structured) { name = "Hybrid GI Cache Update Mask" };
                if (Mask.Length > 0) UpdateMask.SetData(Mask);
                else UpdateMask.SetData(EmptyMask);
            }
        }

        private void Select(int entry, int frame)
        {
            Mask[entry] = 1; SelectedCount++; lastService[entry] = tick;
            lastScheduledFrame[entry] = frame; pendingPriority[entry] = 0f; coveredRevision[entry] = true;
        }
        private static float DirtyPriority(HybridLumenGIScene scene, int slot, int id, float radius, IReadOnlyList<Bounds> localLightChanges,
            IList<Bounds> changedSurfaces, float surfaceRadiusSquared)
        {
            HybridLumenGIScene.ProxyGpuData data = scene.Data[slot];
            var center = new Vector3(data.centerShape.x, data.centerShape.y, data.centerShape.z);
            var extent = new Vector3(data.extentsRoughness.x, data.extentsRoughness.y, data.extentsRoughness.z);
            var bounds = new Bounds(center, extent * 2f);
            float value = 0f;
            for (int i = 0; i < scene.DirtyRegions.Count; i++)
            {
                HybridLumenGIScene.DirtyRegion region = scene.DirtyRegions[i];
                if (region.StableId == id) return 1000f;
                float distanceSquared = float.PositiveInfinity;
                if (region.HasPrevious) distanceSquared = BoundsDistanceSquared(bounds, region.PreviousBounds);
                if (region.HasCurrent) distanceSquared = Mathf.Min(distanceSquared, BoundsDistanceSquared(bounds, region.CurrentBounds));
                if (distanceSquared > radius * radius) continue;
                float weight = radius > 0f ? 1f - Mathf.Sqrt(distanceSquared) / radius : 1f;
                value = Mathf.Max(value, 250f + 250f * weight);
            }
            // Local lights only compete for the priority quota. Retain global
            // lighting dirtiness and the separate oldest-service fairness clock.
            if (localLightChanges != null)
                for (int i = 0; i < localLightChanges.Count; i++)
                    if (BoundsDistanceSquared(bounds, localLightChanges[i]) <= 0f)
                        return 1000f;
            // Surface capture already supplies the published old/new bounds. Use the GI trace
            // radius for these sources, independently of the larger shadow/geometry radius.
            if (changedSurfaces != null)
                for (int i = 0; i < changedSurfaces.Count; i++)
                    if (BoundsDistanceSquared(bounds, changedSurfaces[i]) <= surfaceRadiusSquared)
                        return NearbySurfacePriority;
            return value;
        }
        private static float BoundsDistanceSquared(Bounds a, Bounds b)
        {
            Vector3 gap = Vector3.Max(Vector3.Max(a.min - b.max, b.min - a.max), Vector3.zero);
            return gap.sqrMagnitude;
        }
        private void EnsureCapacity(int cards, int patchesPerCard)
        {
            int count = checked(cards * patchesPerCard);
            if (stableIds.Length == cards && PatchesPerCard == patchesPerCard && Mask.Length == count) return;
            UpdateMask?.Release(); UpdateMask = null;
            PatchesPerCard = patchesPerCard;
            Mask = new uint[count]; candidates = new Candidate[count]; lastService = new long[count];
            lastScheduledFrame = new int[count]; pendingPriority = new float[count]; coveredRevision = new bool[count];
            owners = new int[cards]; stableIds = new int[cards]; revisions = new int[cards];
            generations = new uint[cards]; layouts = new uint[cards];
            for (int i = 0; i < cards; i++) owners[i] = -1;
            for (int i = 0; i < count; i++) lastScheduledFrame[i] = -1;
        }
        public void Dispose()
        {
            UpdateMask?.Release(); UpdateMask = null; Mask = Array.Empty<uint>(); candidates = Array.Empty<Candidate>();
            lastService = Array.Empty<long>(); lastScheduledFrame = Array.Empty<int>(); pendingPriority = Array.Empty<float>();
            coveredRevision = Array.Empty<bool>(); owners = stableIds = revisions = Array.Empty<int>();
            generations = layouts = Array.Empty<uint>(); ownerPriorities = Array.Empty<float>();
            PatchesPerCard = SelectedCount = FairnessSelectedCount = ValidEntryCount = UnscheduledEntryCount = 0;
            tick = MaxFramesSinceUpdate = 0; lastFrame = int.MinValue;
            lastAtlasGeneration = 0;
        }
    }
}
