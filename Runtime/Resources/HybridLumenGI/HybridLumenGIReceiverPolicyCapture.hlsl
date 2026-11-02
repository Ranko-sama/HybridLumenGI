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

// The renderer list supplies the static lightmap and its ST per draw. Never take
// unity_ProbesOcclusion for an unlightmapped pixel. RG stores the original masks;
// the optional BA lanes store four half-float visibility channels (or -1 for unknown).
int _HLGI_CaptureStaticShadowmask;
uint2 HLGIPackStaticShadowmask(float4 v)
{
    uint4 h = f32tof16(float4(v.x>=0 && v.x<=1 ? v.x : -1, v.y>=0 && v.y<=1 ? v.y : -1,
                              v.z>=0 && v.z<=1 ? v.z : -1, v.w>=0 && v.w<=1 ? v.w : -1)) & 0xffffu;
    return uint2(h.x | (h.y<<16), h.z | (h.w<<16));
}

uint2 HLGICaptureStaticShadowmask(float2 lightmapUV)
{
#if defined(LIGHTMAP_ON)
    if (_HLGI_CaptureStaticShadowmask != 0)
    {
        // URP can disable SHADOWS_SHADOWMASK when the only mixed light lies
        // outside the camera culling result. The secondary light table is world-space.
        #if defined(UNITY_DOTS_INSTANCING_ENABLED) && !defined(USE_LEGACY_LIGHTMAPS)
            float4 mask = SAMPLE_TEXTURE2D_ARRAY(unity_ShadowMasks, samplerunity_ShadowMasks, lightmapUV, unity_LightmapIndex.x);
        #else
            float4 mask = SAMPLE_TEXTURE2D(unity_ShadowMask, samplerunity_ShadowMask, lightmapUV);
        #endif
        return HLGIPackStaticShadowmask(mask);
    }
#endif
    return uint2(0x3c003c00u,0x3c003c00u); // four half-float ones
}
#endif
