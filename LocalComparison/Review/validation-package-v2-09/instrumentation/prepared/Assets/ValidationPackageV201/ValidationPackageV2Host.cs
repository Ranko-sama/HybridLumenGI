using System;
using System.IO;
using System.Reflection;
using System.Runtime.CompilerServices;
using HybridLumenGI;
using UnityEngine;
using UnityEngine.Rendering;

/// <summary>Runs the existing validation sequence once after URP is ready.</summary>
[DefaultExecutionOrder(1000)]
public sealed class ValidationPackageV2Host : MonoBehaviour
{
    public HybridLumenGIValidationSequence sequence;
    public Camera targetCamera;
    public string receiptDirectory;
    private float started;
    private bool began, finished;
    private HybridLumenGIRendererFeature observedFeature;
    private object readyPipeline;
    private int stablePipelineFrames;
    private string observationError;
    [Serializable] private sealed class Lifecycle
    {
        public string stage;
        public int engineFrame, pipelineIdentity, passIdentity, featureIdentity;
        public HybridLumenGIRendererFeature.CameraDiagnostics[] cameras;
    }
    private void Observe(string stage)
    {
        try { ObserveCore(stage); }
        catch (Exception error) { observationError = error.ToString(); }
    }
    private void ObserveCore(string stage)
    {
        if (observedFeature == null) return;
        object pass = typeof(HybridLumenGIRendererFeature).GetField("pass", BindingFlags.NonPublic | BindingFlags.Instance).GetValue(observedFeature);
        object pipeline = RenderPipelineManager.currentPipeline;
        var row = new Lifecycle { stage = stage, engineFrame = Time.frameCount,
            pipelineIdentity = pipeline == null ? 0 : RuntimeHelpers.GetHashCode(pipeline),
            passIdentity = pass == null ? 0 : RuntimeHelpers.GetHashCode(pass), featureIdentity = observedFeature.GetInstanceID(),
            cameras = observedFeature.GetDiagnostics() };
        File.AppendAllText(Path.Combine(receiptDirectory, "lifecycle.jsonl"), JsonUtility.ToJson(row) + "\n");
    }
    private void BeginCamera(ScriptableRenderContext context, Camera camera) { if (ReferenceEquals(camera, targetCamera)) Observe("begin-camera"); }
    private void EndCamera(ScriptableRenderContext context, Camera camera) { if (ReferenceEquals(camera, targetCamera)) Observe("end-camera-before-sequence-receipt"); }
    private void OnDestroy()
    { RenderPipelineManager.beginCameraRendering -= BeginCamera; RenderPipelineManager.endCameraRendering -= EndCamera; }
    [Serializable] public sealed class Receipt
    {
        public string status, error, captureDirectory, legacyStatus;
        public int renderedFrames;
        public bool referenceDrained;
        public float elapsedSeconds;
    }
    private void Start()
    {
        started = Time.realtimeSinceStartup; Application.runInBackground = true;
        observedFeature = (HybridLumenGIRendererFeature)typeof(HybridLumenGIValidationSequence).GetField("feature", BindingFlags.NonPublic | BindingFlags.Instance).GetValue(sequence);
        RenderPipelineManager.beginCameraRendering += BeginCamera;
        RenderPipelineManager.endCameraRendering += EndCamera;
        Observe("host-start");
    }
    private void Update()
    {
        if (finished) return;
        if (Time.realtimeSinceStartup - started > 1800) { Finish("failed", "Whole-sequence watchdog expired."); return; }
        try
        {
            if (!string.IsNullOrEmpty(observationError)) { Finish("failed", "Lifecycle observer: " + observationError); return; }
            if (!began)
            {
                // SupportsRenderRequest prepares the current pipeline when needed.
                if (!RenderPipeline.SupportsRenderRequest(targetCamera, new RenderPipeline.StandardRequest())) return;
                // Editor can replace its initially requested pipeline while entering Play.
                // Admit the cold GI sequence only after two complete Update intervals with
                // the same pipeline. No camera render or GI warmup is submitted here.
                object current = RenderPipelineManager.currentPipeline;
                if (!ReferenceEquals(readyPipeline, current))
                { readyPipeline = current; stablePipelineFrames = 0; Observe("pipeline-ready-candidate"); return; }
                if (++stablePipelineFrames < 2) return;
                Observe("before-begin-capture");
                began = true; sequence.BeginCapture();
                Observe("after-begin-capture");
            }
            string status = sequence.CaptureStatus;
            if (status == "running" || status == "not-started") return;
            if (!sequence.ReferenceCaptureDrained) return;
            Finish(status == "completed" ? "collected" : "failed", status == "completed" ? "" : "Sequence status: " + status);
        }
        catch (Exception error) { Finish("failed", error.ToString()); }
    }
    private void Finish(string status, string error)
    {
        if (finished) return; finished = true;
        Observe("host-finish");
        if (!string.IsNullOrEmpty(observationError)) { status = "failed"; error += "\nLifecycle observer: " + observationError; }
        if (targetCamera != null) targetCamera.enabled = false;
        var receipt = new Receipt { status = status, error = error, captureDirectory = sequence.OutputDirectory,
            legacyStatus = sequence.CaptureStatus, renderedFrames = sequence.RenderedFrames,
            referenceDrained = sequence.ReferenceCaptureDrained, elapsedSeconds = Time.realtimeSinceStartup - started };
        File.WriteAllText(Path.Combine(receiptDirectory, "host-result.json"), JsonUtility.ToJson(receipt, true));
#if UNITY_EDITOR
        UnityEditor.EditorApplication.isPlaying = false;
#else
        Application.Quit(status == "collected" ? 0 : 1);
#endif
    }
}
