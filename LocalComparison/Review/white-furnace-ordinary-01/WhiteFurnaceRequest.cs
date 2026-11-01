using UnityEngine;
using UnityEngine.Rendering;

// The batch Editor has no Game view. Request the same camera/target that
// ComparisonCapture prepared; its ordinary HDR readback and exit logic own the result.
[DefaultExecutionOrder(1000)]
public sealed class WhiteFurnaceRequest : MonoBehaviour
{
    private Camera target;
    private bool sent;

    private void Start()
    {
        target = GetComponent<Camera>();
        target.enabled = false;
    }

    private void LateUpdate()
    {
        if (sent || !target.targetTexture) return;
        var request = new RenderPipeline.StandardRequest { destination = target.targetTexture };
        if (!RenderPipeline.SupportsRenderRequest(target, request)) return;
        sent = true;
        RenderPipeline.SubmitRenderRequest(target, request);
    }
}
