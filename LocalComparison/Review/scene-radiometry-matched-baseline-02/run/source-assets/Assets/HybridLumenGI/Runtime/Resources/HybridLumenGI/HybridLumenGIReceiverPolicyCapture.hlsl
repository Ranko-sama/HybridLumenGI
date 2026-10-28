#ifndef HLGI_RECEIVER_POLICY_CAPTURE_INCLUDED
#define HLGI_RECEIVER_POLICY_CAPTURE_INCLUDED

// Set immediately before each renderer list filtered to one GameObject layer.
// Only the small index is a numeric float; both masks remain uint through MRT.
float _HLGI_ReceiverLayerIndex;

uint2 HLGICaptureReceiverPolicy()
{
    if(!isfinite(_HLGI_ReceiverLayerIndex) || _HLGI_ReceiverLayerIndex<0 ||
        _HLGI_ReceiverLayerIndex>31 || _HLGI_ReceiverLayerIndex!=floor(_HLGI_ReceiverLayerIndex)) return uint2(0u,0u);
    // URP 17 reads the full 32-bit unity_RenderingLayer.x payload using asuint.
    // Keep UNITY_SETUP_INSTANCE_ID before this call, and renderinglayer in the
    // instancing options. Zero rendering-layer bits are a valid empty mask,
    // never an invitation to substitute all layers or infer missing draw data.
    return uint2(1u<<(uint)_HLGI_ReceiverLayerIndex,GetMeshRenderingLayer());
}
#endif
