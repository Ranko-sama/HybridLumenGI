// Reuses the existing transport dependency adapters and unchanged WARP buffer ABI.
#if defined(HLGI_TEST_SCREEN_MATERIAL)
#include "HybridLumenGIScreenMaterial.hlsl"
#endif
#include "RadianceValidityHarness.hlsl"

[numthreads(64,1,1)]
void CSScreenReceiveShadowsTest(uint3 id:SV_DispatchThreadID)
{
    if(id.x>=_Count)return;
    active=_Inputs[id.x];
    bool receives=active.control.x>0,blocked=active.control.y>0,valid=active.control.w>0;
    _HLGI_NativeComposition=active.control.z>0?1:0;_HLGI_BounceFeedback=0;
    active.hitSpec=uint4(blocked?HLGI_HIT_VALID|HLGI_HIT_TRIANGLE:0u,1,0,0);
    _HLGI_Proxies[0]=(HLGIProxy)0;_HLGI_Proxies[0].identity=float4(1,1,0,1);
    _HLGI_LightingPolicies[0]=1;_HLGI_Lights[0]=(HLGILight)0;
    _HLGI_Lights[0].directionRange=float4(0,0,1,2);_HLGI_Lights[0].color=1;_HLGI_Lights[0].spot.z=1;
    float magnitude=valid?(_HLGI_NativeComposition!=0?1+saturate(active.incoming.w):1):0;
    float encoded=magnitude;
#if defined(HLGI_TEST_SCREEN_MATERIAL)
    encoded=HLGIEncodeScreenMaterial(magnitude,receives);
#endif
    float stored=f16tof32(f32tof16(encoded));
    _HLGI_Emission.value=float4(active.incoming.rgb,stored);_HLGI_Diffuse.value=float4(active.normal.xyz,.75);
    float3 p=float3(0,0,-1),n=float3(0,0,1),cameraRay=p;
    HLGIRayFootprint footprint;HLGITryScreenRayFootprint(.5,.5,p,cameraRay,footprint);
    HLGIHit hit=HLGIEmptyHit(2);hit.position=p;hit.rawNg=hit.shadingNormal=n;hit.ownerSlot=0;hit.stableId=hit.ownerRevision=1;
    hit.flags=HLGI_HIT_VALID|HLGI_HIT_TRIANGLE|HLGI_HIT_UV_MATERIAL|HLGI_HIT_SHADING_NORMAL;
    hit.materialDiffuse=active.normal.xyz;hit.materialEmission=active.incoming.rgb;hit.materialOcclusion=active.incoming.w;
    hit.materialReceivesShadows=receives?1u:0u;
    RadianceOutput output=(RadianceOutput)0;queryCalls=0;
    output.proxy.xyz=ProxyRadiance(hit,cameraRay,footprint,output.proxy.w);uint worldQueries=queryCalls;
    queryCalls=0;bool known;float distanceHit;float3 radiance;
    bool screenHit=TraceScreen(0,cameraRay,2,radiance,distanceHit,known);
    output.screen=float4(radiance,known?1:0);
    output.predicates=uint4(screenHit?1u:0u,worldQueries,queryCalls,valid?1u:0u);
    bool directKnown;output.unshadowedDirect.xyz=DirectIrradiance(p,n,n,uint2(1,1),false,cameraRay,footprint,directKnown);
    output.unshadowedDirect.w=directKnown?1:0;
    output.moments.xy=float2(stored,f16tof32(f32tof16(magnitude)));
#if defined(HLGI_TEST_SCREEN_MATERIAL)
    output.moments.z=HLGIScreenMaterialAO(stored,_HLGI_NativeComposition!=0,.75);
    output.validity=uint4(HLGIHasScreenMaterial(stored)?1u:0u,HLGIScreenReceivesShadows(stored)?1u:0u,
        asuint(abs(stored))==asuint(output.moments.y)?1u:0u,0u);
#endif
    _Outputs[id.x]=output;
}
