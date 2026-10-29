using System;
using System.Collections.Generic;
using UnityEngine;

namespace HybridLumenGI
{
    /// <summary>Bounded additive-scene IO policy. Scene activation and GI readiness are separate states.</summary>
    public sealed class HybridLumenGIChunkStreaming
    {
        [Serializable]
        public sealed class Definition
        {
            public string id;
            public string scenePath; // Exact Assets/.../*.unity path included in Build Settings.
            public Bounds worldBounds;
            public int priority;
        }
        public interface IOperation { bool IsDone { get; } }
        public interface IBackend
        {
            int LoadedHandle(string scenePath); // 0 means not loaded.
            IOperation BeginLoad(string scenePath);
            IOperation BeginUnload(string scenePath, int ownedHandle);
        }
        public sealed class State
        {
            public string Id { get; internal set; }
            public string ScenePath { get; internal set; }
            public int Generation { get; internal set; }
            public bool Wanted { get; internal set; }
            public bool Loaded { get; internal set; }
            public bool Owned { get; internal set; }
            public bool Loading { get; internal set; }
            public bool Unloading { get; internal set; }
            public bool UnloadSafe { get; internal set; }
            public string LastError { get; internal set; }
            internal Definition definition;
            internal IOperation operation;
            internal int ownedHandle, retryAfter;
            internal float distanceSquared;
        }
        private sealed class DistanceComparer : IComparer<State>
        {
            public int Compare(State a, State b)
            {
                int priority = b.definition.priority.CompareTo(a.definition.priority);
                if (priority != 0) return priority;
                int distance = a.distanceSquared.CompareTo(b.distanceSquared);
                return distance != 0 ? distance : string.CompareOrdinal(a.Id, b.Id);
            }
        }
        private static readonly DistanceComparer Ordering = new DistanceComparer();
        private readonly IBackend backend;
        private readonly State[] states;
        private readonly State[] candidates;
        private readonly Vector3[] singleObserver = new Vector3[1];
        private readonly Dictionary<string, State> byId = new Dictionary<string, State>(StringComparer.Ordinal);
        private int tick;
        public IReadOnlyList<State> States => states;
        public int ActiveOperations { get; private set; }
        public int PendingLoads { get; private set; }
        public int BlockedUnloads { get; private set; }
        public int OwnedScenes { get; private set; }
        public int OperationsStarted { get; private set; }

        public HybridLumenGIChunkStreaming(IReadOnlyList<Definition> definitions, IBackend backend)
        {
            this.backend = backend ?? throw new ArgumentNullException(nameof(backend));
            if (definitions == null) throw new ArgumentNullException(nameof(definitions));
            states = new State[definitions.Count]; candidates = new State[definitions.Count];
            var paths = new HashSet<string>(StringComparer.Ordinal);
            for (int i = 0; i < definitions.Count; i++)
            {
                Definition definition = definitions[i];
                if (definition == null || string.IsNullOrWhiteSpace(definition.id) || string.IsNullOrWhiteSpace(definition.scenePath) ||
                    !definition.scenePath.StartsWith("Assets/", StringComparison.Ordinal) || !definition.scenePath.EndsWith(".unity", StringComparison.OrdinalIgnoreCase))
                    throw new ArgumentException("Each chunk requires a unique ID and an Assets/.../*.unity scene path.");
                if (byId.ContainsKey(definition.id) || !paths.Add(definition.scenePath)) throw new ArgumentException("Duplicate chunk ID or scene path.");
                var state = new State { Id = definition.id, ScenePath = definition.scenePath, definition = definition };
                states[i] = state; byId.Add(state.Id, state);
            }
        }

        /// <summary>Authorize unload only after a fallback is published and no camera needs this scene's representation.</summary>
        public bool ReportUnloadSafe(string id, int generation, bool safe)
        {
            if (!byId.TryGetValue(id, out State state) || state.Generation != generation || !state.Owned || !state.Loaded || state.Loading || state.Unloading) return false;
            state.UnloadSafe = safe;
            return true;
        }

        public void Step(Vector3 position, float loadDistance, float unloadDistance, int maxResidentScenes,
            int maxConcurrentOperations, int maxStartsPerStep)
        {
            singleObserver[0] = position;
            Step(singleObserver, loadDistance, unloadDistance, maxResidentScenes, maxConcurrentOperations, maxStartsPerStep);
        }

        /// <summary>Union distance demand, with one shared operation budget. No viewpoints preserves the prior state.</summary>
        public void Step(IReadOnlyList<Vector3> positions, float loadDistance, float unloadDistance, int maxResidentScenes,
            int maxConcurrentOperations, int maxStartsPerStep)
        {
            if (positions == null || positions.Count == 0) return;
            tick++;
            loadDistance = Mathf.Max(0f, loadDistance); unloadDistance = Mathf.Max(loadDistance, unloadDistance);
            maxResidentScenes = Mathf.Clamp(maxResidentScenes, 1, 512);
            maxConcurrentOperations = Mathf.Clamp(maxConcurrentOperations, 1, 8);
            maxStartsPerStep = Mathf.Clamp(maxStartsPerStep, 0, 8);
            ActiveOperations = PendingLoads = BlockedUnloads = OwnedScenes = OperationsStarted = 0;
            int reserved = 0, candidateCount = 0;
            for (int i = 0; i < states.Length; i++)
            {
                State state = states[i];
                int handle = backend.LoadedHandle(state.ScenePath);
                if (state.operation != null && state.operation.IsDone)
                {
                    if (state.Loading)
                    {
                        if (handle != 0) { state.Owned = true; state.ownedHandle = handle; state.LastError = null; }
                        else Fail(state, "Load operation completed without an active scene.");
                    }
                    else if (state.Unloading)
                    {
                        if (handle == state.ownedHandle) Fail(state, "Unload operation completed but the owned scene is still loaded.");
                        else { state.Owned = false; state.ownedHandle = 0; state.LastError = null; }
                    }
                    state.operation = null; state.Loading = state.Unloading = false;
                }
                if (state.Owned && !state.Loading && !state.Unloading && handle != state.ownedHandle)
                {
                    // Another system replaced/unloaded the scene. Never adopt or unload its replacement.
                    state.Owned = state.UnloadSafe = false; state.ownedHandle = 0;
                }
                state.Loaded = handle != 0;
                state.distanceSquared = float.PositiveInfinity;
                for (int view = 0; view < positions.Count; view++)
                    state.distanceSquared = Mathf.Min(state.distanceSquared, state.definition.worldBounds.SqrDistance(positions[view]));
                if (state.distanceSquared <= loadDistance * loadDistance) state.Wanted = true;
                else if (state.distanceSquared > unloadDistance * unloadDistance) state.Wanted = false;
                if (state.Wanted) state.UnloadSafe = false;
                if (state.Owned) { OwnedScenes++; reserved++; }
                else if (state.Loading) reserved++;
                if (state.operation != null) ActiveOperations++;
                if (!state.Wanted && state.Owned && state.Loaded && !state.UnloadSafe && state.operation == null) BlockedUnloads++;
                if (state.Wanted && !state.Loaded && state.operation == null)
                { PendingLoads++; candidates[candidateCount++] = state; }
            }
            // Reclaim only explicitly safe owned scenes. Unity AsyncOperation cannot be cancelled;
            // loads that become unwanted finish, then wait for the same safety receipt as any unload.
            for (int i = 0; i < states.Length && CanStart(maxConcurrentOperations, maxStartsPerStep); i++)
            {
                State state = states[i];
                if (state.Wanted || !state.Owned || !state.Loaded || !state.UnloadSafe || state.operation != null || tick < state.retryAfter) continue;
                OperationsStarted++;
                state.UnloadSafe = false;
                try
                {
                    state.operation = backend.BeginUnload(state.ScenePath, state.ownedHandle);
                    if (state.operation == null) throw new InvalidOperationException("Scene unload returned no operation.");
                    state.Unloading = true; ActiveOperations++;
                }
                catch (Exception error) { Fail(state, error.Message); }
            }
            Array.Sort(candidates, 0, candidateCount, Ordering);
            for (int i = 0; i < candidateCount && reserved < maxResidentScenes && CanStart(maxConcurrentOperations, maxStartsPerStep); i++)
            {
                State state = candidates[i];
                if (tick < state.retryAfter) continue;
                OperationsStarted++;
                try
                {
                    state.operation = backend.BeginLoad(state.ScenePath);
                    if (state.operation == null) throw new InvalidOperationException("Scene load returned no operation.");
                    state.Generation = state.Generation == int.MaxValue ? 1 : state.Generation + 1;
                    state.Loading = true; state.UnloadSafe = false; state.LastError = null;
                    reserved++; ActiveOperations++; PendingLoads--;
                }
                catch (Exception error) { Fail(state, error.Message); }
            }
        }
        private bool CanStart(int concurrent, int starts) => ActiveOperations < concurrent && OperationsStarted < starts;
        private void Fail(State state, string message) { state.LastError = message; state.retryAfter = tick + 60; }
    }
}
