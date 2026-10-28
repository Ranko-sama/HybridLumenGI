#include "HybridLumenGIRadianceValidity.hlsl"
#include "HybridLumenGIHit.hlsl"
#include "HybridLumenGIRayFootprint.hlsl"
struct RadianceInput
{
    float4 incoming,control,initialSum,irradiance,guide,history,moments;
    uint4 hitSpec;
    float4 guideSumPower,normal;
    uint4 purpose; // shadow, resolveMaterial, coverageKnown/covered/fullKnown bits, footprint case
    float4 footprint,connection; // incoming direction/radius; light position-or-direction/type
};
struct RadianceOutput
{
    float4 sum,irradiance,guide,history,moments,screen,proxy,direct;
    uint4 predicates,validity;
    float4 propagatedIrradiance,propagatedGuide;
    float4 unshadowedDirect;
    uint4 coverage;
    uint4 resolved;float4 resolvedMaterial;
    float4 forwardedOrigin,forwardedDirection,forwardedFootprint,forwardedView;
    float4 footprintDirect,wrappers,proxyPrimary;
};
StructuredBuffer<RadianceInput> _Inputs:register(t0);
RWStructuredBuffer<RadianceOutput> _Outputs:register(u0);
cbuffer TestCounts:register(b0) { uint _Count; }

// Explicit dependency adapter: these frozen inputs model a nearest hit and
// one captured surface, not DXR traversal, texture sampling or Unity rendering.
static RadianceInput active;
struct HLGIProxy { float4 centerShape,extentsRoughness,albedo,emission,identity; };
struct HLGILight { float4 positionType,directionRange,color,spot;uint4 masks; };
struct HLGICacheEntry { float4 irradiance,tag,anchor,normal,guide; };
struct HLGISurfaceSample { float3 diffuse,emission,normal,geometricNormal;float occlusion,confidence; };
static HLGIProxy _HLGI_Proxies[1];
static HLGILight _HLGI_Lights[1];
static uint4 _HLGI_LightingPolicies[1];
static int _HLGI_ProxyCount=1,_HLGI_LightCount=1,_HLGI_ScreenSteps=1,_HLGI_NativeComposition=0;
static float _HLGI_ShadowDistance=2,_HLGI_RayBias=0.03,_HLGI_Thickness=0.15,_HLGI_BounceFeedback=1;
static float4x4 _HLGI_InvVP;
static float4 _HLGI_MaterialView=float4(0,0,0,1);
static float4 queryOrigin,queryDirection,queryFootprint,queryView;
static uint queryCalls;
bool TraceSceneQuery(float3 o,float3 d,float maxT,bool shadow,bool resolveMaterial,uint culling,uint layers,bool useLayers,
    HLGIRayFootprint footprint,float4 materialView,out HLGIHit hit)
{
    queryCalls++;queryOrigin=float4(o,maxT);queryDirection=float4(d,shadow?1:0);
    queryFootprint=float4(footprint.radius,footprint.slope,footprint.valid,queryCalls);queryView=materialView;
    hit=HLGIEmptyHit(maxT);hit.flags=active.hitSpec.x;hit.t=1;return HLGIHitHas(hit.flags,HLGI_HIT_VALID);
}
bool HLGILightAffectsReceiver(uint2 receiver,uint culling,uint layers,bool enabled) { return (active.hitSpec.w&4u)==0u; }
bool HLGITrySurfaceMaterialHit(HLGIHit hit,out HLGISurfaceSample sample)
{ sample=(HLGISurfaceSample)0;sample.diffuse=.5;sample.normal=sample.geometricNormal=float3(0,0,1);sample.occlusion=1;sample.confidence=.8;
  if(HLGIHitHas(hit.flags,HLGI_HIT_TRIANGLE)) {sample.diffuse=float3(.9,.1,.7);sample.emission=10;sample.normal=float3(0,0,-1);sample.occlusion=.9;}
  return active.hitSpec.z!=0u; }
bool HLGICachedSurface(int slot,float3 p,float3 ng,float3 ns,HLGISurfaceSample s,out HLGICacheEntry cache)
{ cache=(HLGICacheEntry)0;if((active.hitSpec.x&HLGI_HIT_TRIANGLE)!=0u && active.hitSpec.z!=0u) {cache.irradiance=float4(.8,.4,.2,1);return true;} return false; }
float3 CachedIrradiance(HLGIHit hit,float3 n) { return 0; }
bool ScreenPoint(float3 o,float3 d,float t,out float2 uv,out float delta,out float3 p)
{ uv=.5;delta=t-1;p=float3(0,0,-1);return true; }
float3 NormalAt(float2 uv) { return float3(0,0,1); }
bool ValidDepth(float d) { return true; }
float3 WorldPosition(float2 uv,float d,float4x4 m) { return float3(0,0,-1); }
bool HLGITryScreenGeometricNormal(float2 uv,float d,float3 p,out float3 normal)
{ normal=float3(0,0,1);return true; }
bool HLGITryScreenWorldMatch(float2 uv,float depth,float3 p,float3 n,out HLGIHit hit) { hit=HLGIEmptyHit(2);return false; }
// Explicit same-plane footprint adapter; no real depth reconstruction is claimed.
bool HLGITryScreenRayFootprint(float2 uv,float depth,float3 p,float3 ray,out HLGIRayFootprint footprint)
{ return HLGITryScreenFootprint(p,p+float3(.01,0,0),p+float3(0,.01,0),1,1,ray,footprint); }
struct ScalarTexture { float SampleLevel(SamplerState s,float2 uv,float mip) { return .5; } };
struct ColorTexture { float4 value;float4 SampleLevel(SamplerState s,float2 uv,float mip) { return value; } };
struct PolicyTexture {
    void GetDimensions(out uint width,out uint height) { width=height=1u; }
    uint2 Load(int3 p) { return uint2(1u,1u); }
};
SamplerState sampler_PointClamp;
static ScalarTexture _HLGI_Depth,_HLGI_CaptureDepth;
static ColorTexture _HLGI_Emission,_HLGI_Diffuse;
static PolicyTexture _HLGI_ReceiverPolicy;
// Dependency spy for the ORIGINAL committed-material helper extracted below.
// It proves call selection/publication only, not real texture sampling or RayQuery.
struct HLGIHardwareInstance { uint unused; };
struct HLGITriangleNormals { uint unused; };
struct HLGIHitMaterialSurface { float3 diffuseReflectance,emission;float occlusion;bool receivesShadows; };
static uint coverageCalls,fullCalls,shadowCoverageCalls;
bool HLGIHardwareEvaluateHit(uint instanceIndex,uint primitive,HLGIHardwareInstance instance,HLGITriangleNormals attributes,
    float3x4 objectToWorld,float2 barycentric,float4 view,float3 direction,float radius,bool coverageOnly,bool shadowCoverage,
    out bool covered,out HLGIHitMaterialSurface material,out float3 normal)
{
    covered=(active.purpose.z&2u)!=0u;material=(HLGIHitMaterialSurface)0;
    material.diffuseReflectance=float3(.2,.4,.6);material.emission=float3(.1,.2,.3);material.occlusion=.25;material.receivesShadows=true;normal=float3(0,1,0);
    if(coverageOnly){coverageCalls++;if(shadowCoverage)shadowCoverageCalls++;return (active.purpose.z&1u)!=0u;}
    fullCalls++;return (active.purpose.z&4u)!=0u;
}
#define HLGI_INLINE_RT 1
// Generated from original function bodies without rewriting their logic.
#include "ActualTransportFunctions.hlsl"

[numthreads(64,1,1)]
void CSRadianceValidityTest(uint3 id:SV_DispatchThreadID)
{
    if(id.x>=_Count)return;
    active=_Inputs[id.x];
    _HLGI_Proxies[0]=(HLGIProxy)0;
    _HLGI_Proxies[0].identity=float4(active.hitSpec.y!=0u?1:2,1,0,1);
    _HLGI_Proxies[0].albedo=.5;
    _HLGI_Lights[0]=(HLGILight)0;
    _HLGI_Lights[0].directionRange=float4(0,0,1,2);
    _HLGI_Lights[0].color=1;_HLGI_Lights[0].spot.z=active.normal.w;
    _HLGI_LightingPolicies[0]=1;
    _HLGI_Emission.value=float4(0,0,0,1);_HLGI_Diffuse.value=.5;
    RadianceOutput output=(RadianceOutput)0;
    float3 sum=active.initialSum.xyz;
    bool accepted=HLGIAccumulateRadianceSample(active.incoming.xyz,active.incoming.w,active.control.x,sum);
    output.sum=float4(sum,accepted?1:0);
    output.irradiance=active.irradiance;output.guide=active.guide;
    bool committed=HLGICommitCacheEstimate(accepted && active.control.z>0,sum,active.guideSumPower.xyz,
        active.guideSumPower.w,(int)active.control.y,active.normal.xyz,output.irradiance,output.guide);
    HLGIResolveUnknownHistory(active.control.w>0,active.history,active.moments,output.history,output.moments);
    bool shadowKnown,directKnown,screenKnown;float distanceHit;float3 screenRadiance;
    bool blocked=TraceShadow(0,float3(0,0,-1),2,0xffffffffu,0xffffffffu,false,shadowKnown);
    output.direct.xyz=DirectIrradiance(0,float3(0,0,1),float3(0,0,1),uint2(1,1),directKnown);
    output.direct.w=directKnown?1:0;
    HLGIHit hit=HLGIEmptyHit(2);hit.flags=active.hitSpec.x;hit.ownerSlot=0;hit.stableId=hit.ownerRevision=1;
    hit.rawNg=hit.shadingNormal=float3(0,0,1);
    if((active.hitSpec.w&1u)!=0u)
    {
        hit.flags|=HLGI_HIT_UV_MATERIAL|HLGI_HIT_SHADING_NORMAL;
        hit.materialDiffuse=float3(.2,.4,.6);hit.materialEmission=float3(.1,.2,.3);hit.materialOcclusion=.25;
        hit.materialReceivesShadows=(active.hitSpec.w&2u)==0u?1u:0u;
    }
    output.proxy.xyz=ProxyRadiance(hit,output.proxy.w);
    HLGIRayFootprint supplied;HLGITryMakeRayFootprint(active.footprint.w,0,supplied);
    output.proxyPrimary.xyz=ProxyRadiance(hit,active.footprint.xyz,supplied,output.proxyPrimary.w);
    output.wrappers.xyz=DirectIrradiance(0,float3(0,0,1),float3(0,0,1),uint2(1,1));
    output.wrappers.w=TraceShadow(0,float3(0,0,-1),2,0xffffffffu,0xffffffffu,false)?1:0;
    float3 propagatedSum=0;
    bool propagatedKnown=HLGIAccumulateRadianceSample(output.proxy.xyz,output.proxy.w,active.control.x,propagatedSum);
    output.propagatedIrradiance=active.irradiance;output.propagatedGuide=active.guide;
    HLGICommitCacheEstimate(propagatedKnown,propagatedSum,0,0,(int)active.control.y,active.normal.xyz,
        output.propagatedIrradiance,output.propagatedGuide);
    bool screenHit=TraceScreen(0,float3(0,0,-1),2,screenRadiance,distanceHit,screenKnown);
    output.screen=float4(screenHit?1:0,screenKnown?1:0,distanceHit,screenRadiance.x);
    output.predicates=uint4(HLGIHitHas(hit.flags,HLGI_HIT_VALID)?1u:0u,HLGIHitMaterialKnown(hit)?1u:0u,blocked?1u:0u,shadowKnown?1u:0u);
    output.validity=uint4(committed?1u:0u,HLGIHasRadianceMeasurement(active.incoming)?1u:0u,
        HLGIHasTemporalHistory(active.history,active.moments)?1u:0u,HLGIHasRadianceMeasurement(output.history)?1u:0u);
    bool unshadowedKnown;
    output.unshadowedDirect.xyz=DirectIrradiance(0,float3(0,0,1),float3(0,0,1),uint2(1,1),false,unshadowedKnown);
    output.unshadowedDirect.w=unshadowedKnown?1:0;
    output.coverage=uint4(HLGIHitCoverageBlocks(HLGIHitMaterialKnown(hit),active.hitSpec.z!=0u)?1u:0u,
        HLGIHitCoverageBlocks(false,false)?1u:0u,HLGIHitCoverageBlocks(true,false)?1u:0u,HLGIHitCoverageBlocks(true,true)?1u:0u);
    coverageCalls=fullCalls=shadowCoverageCalls=0u;
    HLGIHit resolved=HLGIEmptyHit(2);resolved.flags=HLGI_HIT_VALID|HLGI_HIT_TRIANGLE;resolved.t=1;
    float radius=active.purpose.w==1u?-1:1;
    float slope=active.purpose.w==2u?-.5:(active.purpose.w==3u?-2:0);
    float4 view=active.purpose.w==4u?float4(asfloat(0x7fc00000u).xxx,1):float4(0,0,0,1);
    HLGIHardwareResolveCommittedMaterial(0,0,(HLGIHardwareInstance)0,(HLGITriangleNormals)0,(float3x4)0,0,
        view,float3(0,0,-1),radius,slope,active.purpose.x!=0u,active.purpose.y!=0u,resolved);
    output.resolved=uint4(resolved.flags,coverageCalls,fullCalls,shadowCoverageCalls);
    output.resolvedMaterial=float4(resolved.materialDiffuse,HLGIHitMaterialKnown(resolved)?1:0);
    // The original DirectIrradiance primary retargets the supplied spatial disk,
    // then the original TraceShadow primary forwards it to this query spy.
    // Other tests above retain all original hit/unknown cases; this narrow probe
    // independently observes an unoccluded connection at a nonzero surface point.
    active.hitSpec.x=active.hitSpec.w=0u;
    float3 p=float3(.25,-.5,.75);
    _HLGI_Lights[0].positionType=float4(active.connection.xyz,active.connection.w);
    _HLGI_Lights[0].directionRange=float4(normalize(active.connection.xyz),10);
    _HLGI_Lights[0].spot.z=1;
    queryCalls=0;queryOrigin=queryDirection=queryFootprint=queryView=0;
    bool footprintKnown;
    output.footprintDirect.xyz=DirectIrradiance(p,float3(0,0,1),float3(0,0,1),uint2(1,1),true,
        active.footprint.xyz,supplied,footprintKnown);
    output.footprintDirect.w=footprintKnown?1:0;
    output.forwardedOrigin=queryOrigin;output.forwardedDirection=queryDirection;
    output.forwardedFootprint=queryFootprint;output.forwardedView=queryView;
    _Outputs[id.x]=output;
}
