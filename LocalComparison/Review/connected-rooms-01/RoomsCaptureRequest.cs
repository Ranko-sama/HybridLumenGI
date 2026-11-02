using System;
using System.IO;
using System.Linq;
using HybridLumenGI;
using UnityEngine;
using UnityEngine.Rendering;

[DefaultExecutionOrder(1000)]
public sealed class RoomsCaptureRequest : MonoBehaviour
{
    public bool open, closeDuringRun;
    public string output;
    ComparisonCapture capture;
    HybridLumenGIUnifiedSampleInteraction controls;
    int requests;
    double closeTime;
    [Serializable] sealed class Receipt
    {
        public bool roomsEnabled, doorOpen;
        public int enabledLights;
        public int logicalFrame, engineFrame;
        public double secondsSinceClose;
        public Vector3 cameraPosition, doorPosition;
        public string[] published, emissiveProxies;
    }
    void Start()
    {
        capture = GetComponent<ComparisonCapture>();
        controls = FindFirstObjectByType<HybridLumenGIUnifiedSampleInteraction>();
        controls.SetConnectedRooms(true);
        controls.SetPortalOpen(open);
        controls.SetLightsEnabled(false);
        capture.camera.transform.SetPositionAndRotation(capture.colorView.position, capture.colorView.rotation);
        capture.camera.enabled = false;
    }
    void LateUpdate()
    {
        if (!capture.camera.targetTexture) return;
        var req = new RenderPipeline.StandardRequest { destination = capture.camera.targetTexture };
        if (!RenderPipeline.SupportsRenderRequest(capture.camera, req)) return;
        int frame = requests++;
        if (closeDuringRun && frame == 120)
        {
            controls.SetPortalOpen(false);
            closeTime = Time.realtimeSinceStartupAsDouble;
        }
        double requestedAt = Time.realtimeSinceStartupAsDouble;
        RenderPipeline.SubmitRenderRequest(capture.camera, req);
        bool eventFrame = closeDuringRun && (frame == 119 || frame == 120 || frame == 127 || frame == 150 || frame == 179 || frame == 239);
        if (!eventFrame && requests != capture.totalFrames) return;
        var group = GameObject.Find("Connected rooms");
        var feature = (HybridLumenGIRendererFeature)capture.feature;
        var names = group.GetComponentsInChildren<HybridLumenGIProxy>()
            .Where(p => feature.TryGetPublication(capture.camera, p, out var s) && s.phase == HybridLumenGIScene.PublicationPhase.Published)
            .Select(p => p.name).ToArray();
        var receipt = new Receipt { logicalFrame = frame, engineFrame = Time.frameCount,
            secondsSinceClose = closeDuringRun && frame >= 120 ? requestedAt - closeTime : -1,
            roomsEnabled = controls.RoomsEnabled, doorOpen = controls.PortalOpen,
            cameraPosition = capture.camera.transform.position, doorPosition = group.transform.Find("Sliding partition door").localPosition,
            enabledLights = FindObjectsByType<Light>(FindObjectsSortMode.None).Count(l => l.isActiveAndEnabled),
            published = names,
            emissiveProxies = FindObjectsByType<HybridLumenGIProxy>(FindObjectsSortMode.None)
                .Where(p => feature.TryGetPublication(capture.camera, p, out var s) && s.phase == HybridLumenGIScene.PublicationPhase.Published &&
                    (p.GetEmissionLinear().maxColorComponent > 0 || (p.SourceRenderer && p.SourceRenderer.sharedMaterials.Any(m => m &&
                        m.IsKeywordEnabled("_EMISSION") && m.HasProperty("_EmissionColor") && m.GetColor("_EmissionColor").maxColorComponent > 0))))
                .Select(p => p.name).ToArray() };
        if (eventFrame) File.AppendAllText(Path.Combine(output, "events.jsonl"), JsonUtility.ToJson(receipt) + "\n");
        if (requests == capture.totalFrames) File.WriteAllText(Path.Combine(output, "room-state.json"), JsonUtility.ToJson(receipt, true));
    }
}
