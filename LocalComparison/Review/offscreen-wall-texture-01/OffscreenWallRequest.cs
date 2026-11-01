using UnityEngine;
using UnityEngine.Rendering;

// ComparisonCapture owns the target, Readback and completion. Batch Editor has no Game view.
[DefaultExecutionOrder(1000)]
public sealed class OffscreenWallRequest : MonoBehaviour
{
    Camera target;
    void Start() { target = GetComponent<Camera>(); target.enabled = false; }
    void LateUpdate()
    {
        if (!target.targetTexture) return;
        var request = new RenderPipeline.StandardRequest { destination = target.targetTexture };
        if (RenderPipeline.SupportsRenderRequest(target, request)) RenderPipeline.SubmitRenderRequest(target, request);
    }
}
