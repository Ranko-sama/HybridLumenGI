using System;
using System.IO;
using System.Linq;
using HybridLumenGI;
using UnityEngine;
using UnityEngine.Rendering;

[DefaultExecutionOrder(1000)]
public sealed class RoomsCaptureRequest : MonoBehaviour
{
    public bool open;
    public string output;
    ComparisonCapture capture;
    HybridLumenGIUnifiedSampleInteraction controls;
    int requests;
    [Serializable] sealed class Receipt
    {
        public bool roomsEnabled, doorOpen;
        public int enabledLights;
        public Vector3 cameraPosition, doorPosition;
        public string[] published;
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
        RenderPipeline.SubmitRenderRequest(capture.camera, req);
        if (++requests != capture.totalFrames) return;
        var group = GameObject.Find("Connected rooms");
        var feature = (HybridLumenGIRendererFeature)capture.feature;
        var names = group.GetComponentsInChildren<HybridLumenGIProxy>()
            .Where(p => feature.TryGetPublication(capture.camera, p, out var s) && s.phase == HybridLumenGIScene.PublicationPhase.Published)
            .Select(p => p.name).ToArray();
        var receipt = new Receipt { roomsEnabled = controls.RoomsEnabled, doorOpen = controls.PortalOpen,
            cameraPosition = capture.camera.transform.position, doorPosition = group.transform.Find("Sliding partition door").localPosition,
            enabledLights = FindObjectsByType<Light>(FindObjectsSortMode.None).Count(l => l.isActiveAndEnabled),
            published = names };
        File.WriteAllText(Path.Combine(output, "room-state.json"), JsonUtility.ToJson(receipt, true));
    }
}
