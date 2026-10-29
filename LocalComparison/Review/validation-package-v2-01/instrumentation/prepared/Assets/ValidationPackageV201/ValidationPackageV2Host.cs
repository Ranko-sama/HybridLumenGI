using System;
using System.IO;
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
    [Serializable] public sealed class Receipt
    {
        public string status, error, captureDirectory, legacyStatus;
        public int renderedFrames;
        public bool referenceDrained;
        public float elapsedSeconds;
    }
    private void Start() { started = Time.realtimeSinceStartup; }
    private void Update()
    {
        if (finished) return;
        if (Time.realtimeSinceStartup - started > 1800) { Finish("failed", "Whole-sequence watchdog expired."); return; }
        try
        {
            if (!began)
            {
                if (RenderPipelineManager.currentPipeline == null ||
                    !RenderPipeline.SupportsRenderRequest(targetCamera, new RenderPipeline.StandardRequest())) return;
                began = true; sequence.BeginCapture();
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
