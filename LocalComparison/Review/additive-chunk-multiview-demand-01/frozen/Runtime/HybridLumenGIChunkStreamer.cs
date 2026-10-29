using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.SceneManagement;

namespace HybridLumenGI
{
    /// <summary>Optional additive IO driver. Application orchestration must explicitly report safe chunk unloads.</summary>
    [DisallowMultipleComponent]
    public sealed class HybridLumenGIChunkStreamer : MonoBehaviour
    {
        [SerializeField] private HybridLumenGIStreamingManifest manifest;
        [SerializeField] private Transform observer;
        [SerializeField, Tooltip("Additional distance-demand viewpoints, sharing the existing scene IO budgets.")]
        private Transform[] additionalObservers = Array.Empty<Transform>();
        [SerializeField, Min(0f)] private float loadDistance = 60f;
        [SerializeField, Min(0f)] private float unloadDistance = 90f;
        [SerializeField, Range(1, 512)] private int maxResidentScenes = 8;
        [SerializeField, Range(1, 8)] private int maxConcurrentOperations = 1;
        [SerializeField, Range(0, 8)] private int startsPerFrame = 1;
        public HybridLumenGIChunkStreaming State { get; private set; }
        private bool initializationFailed;
        private readonly List<Vector3> observerPositions = new List<Vector3>();

        /// <summary>Copies additional viewpoints. Null/empty retains only the legacy observer/main-camera fallback.</summary>
        public void SetAdditionalObservers(params Transform[] value)
        { additionalObservers = value == null || value.Length == 0 ? Array.Empty<Transform>() : (Transform[])value.Clone(); }

        private void Update()
        {
            if (manifest == null || initializationFailed) return;
            if (State == null)
            {
                try { State = new HybridLumenGIChunkStreaming(manifest.Chunks, new SceneBackend()); }
                catch (Exception error) { initializationFailed = true; Debug.LogException(error, this); return; }
            }
            Transform target = observer != null ? observer : Camera.main != null ? Camera.main.transform : null;
            observerPositions.Clear();
            if (target != null) observerPositions.Add(target.position);
            for (int i = 0; i < (additionalObservers?.Length ?? 0); i++)
                if (additionalObservers[i] != null) observerPositions.Add(additionalObservers[i].position);
            if (observerPositions.Count == 0) return;
            State.Step(observerPositions, loadDistance, unloadDistance, maxResidentScenes, maxConcurrentOperations, startsPerFrame);
        }
        public bool ReportUnloadSafe(string id, int generation, bool safe) => State != null && State.ReportUnloadSafe(id, generation, safe);

        // Disabling/destroying the driver never silently deletes application scenes. Outstanding
        // operations cannot be cancelled; the application retains loaded scenes and may resume control.
        private sealed class Operation : HybridLumenGIChunkStreaming.IOperation
        {
            private readonly AsyncOperation operation;
            public Operation(AsyncOperation operation) { this.operation = operation; }
            public bool IsDone => operation.isDone;
        }
        private sealed class SceneBackend : HybridLumenGIChunkStreaming.IBackend
        {
            public int LoadedHandle(string path)
            {
                Scene scene = SceneManager.GetSceneByPath(path);
                return scene.IsValid() && scene.isLoaded ? scene.handle : 0;
            }
            public HybridLumenGIChunkStreaming.IOperation BeginLoad(string path)
            {
                AsyncOperation operation = SceneManager.LoadSceneAsync(path, LoadSceneMode.Additive);
                return operation != null ? new Operation(operation) : null;
            }
            public HybridLumenGIChunkStreaming.IOperation BeginUnload(string path, int ownedHandle)
            {
                Scene scene = SceneManager.GetSceneByPath(path);
                if (!scene.IsValid() || !scene.isLoaded || scene.handle != ownedHandle)
                    throw new InvalidOperationException("The scene no longer matches the instance owned by this streamer.");
                AsyncOperation operation = SceneManager.UnloadSceneAsync(scene);
                return operation != null ? new Operation(operation) : null;
            }
        }
    }
}
