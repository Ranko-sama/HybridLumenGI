// Fixed inputs around actual TraceScreen and CSTrace estimator body.
// No actual scene queries, depth reconstruction, lighting or PDFs are claimed.
#include "HybridLumenGIHit.hlsl"
#include "HybridLumenGIRayFootprint.hlsl"
#include "HybridLumenGIScreenMaterial.hlsl"
#include "HybridLumenGIRadianceValidity.hlsl"
static RadianceInput active;
static int _HLGI_Rays=2,_HLGI_AreaEmitterCount=1,_HLGI_ScreenSteps=1,_HLGI_NativeComposition=0;
static float _HLGI_RayBias=.03125,_HLGI_MaxDistance=4,_HLGI_Thickness=.15,_HLGI_BounceFeedback=1;
static float4 _HLGI_Environment=float4(.125,.25,.5,1),_HLGI_MaterialView=float4(0,0,0,1);
static float4x4 _HLGI_InvVP;
static float3 screenP,screenDirection;
static uint directionDraws,areaDraws,directCalls,unknownDirectCalls;
struct HLGICacheEntry { float4 guide; };
struct HLGIAreaSample { float3 direction;float distance; };
#define HLGI_AREA_NONE 0u
#define HLGI_AREA_SAMPLE 1u
#define HLGI_AREA_UNKNOWN 2u
SamplerState sampler_PointClamp;
struct ScalarTexture { float SampleLevel(SamplerState s,float2 uv,float mip) { return .5; } };
struct ColorTexture { float4 SampleLevel(SamplerState s,float2 uv,float mip) { return float4(.125,.25,.5,1); } };
struct PolicyTexture {
    void GetDimensions(out uint width,out uint height) { width=height=1u; }
    uint2 Load(int3 p) { return uint2(1,1); }
};
static ScalarTexture _HLGI_Depth,_HLGI_CaptureDepth;
static ColorTexture _HLGI_Emission,_HLGI_Diffuse;
static PolicyTexture _HLGI_ReceiverPolicy;
bool ScreenPoint(float3 origin,float3 dir,float t,out float2 uv,out float delta,out float3 p)
{
    screenDirection=dir;screenP=origin+dir;uv=.5;delta=t-1;p=screenP;
    return dir.x==0 ? active.control.x!=0 : active.control.y!=0;
}
float3 NormalAt(float2 uv) { return -screenDirection; }
bool ValidDepth(float d) { return true; }
float3 WorldPosition(float2 uv,float d,float4x4 transform) { return screenP; }
bool HLGITryScreenGeometricNormal(float2 uv,float d,float3 p,out float3 n) { n=-screenDirection;return false; }
bool HLGITryScreenWorldMatch(float2 uv,float d,float3 p,float3 n,uint2 screenPolicy,out HLGIHit hit) { hit=HLGIEmptyHit(4);return false; }
bool HLGITryScreenRayFootprint(float2 uv,float depth,float3 p,float3 dir,out HLGIRayFootprint footprint)
{ return HLGITryMakeRayFootprint(0,0,footprint); }
float3 DirectIrradiance(float3 p,float3 n,float3 ng,uint2 layers,bool shadows,float3 ray,HLGIRayFootprint footprint,out bool known)
{
    directCalls++;known=screenDirection.x==0 ? active.control.z!=0 : active.control.w!=0;
    if(!known)unknownDirectCalls++;
    return 0;
}
float3 CachedIrradiance(HLGIHit hit,float3 n,out bool known) { known=false;return 0; }
float3 HLGISampleTransportDirection(float3 o,float3 n,float4 guide,inout uint rng,out float weight)
{ directionDraws++;weight=1;return float3(0,0,1); }
bool HLGIAreaMatchedDirectionWeight(float3 o,float3 n,float4 guide,float3 dir,inout float weight) { return true; }
bool TraceSceneHit(float3 o,float3 d,float maxT,HLGIRayFootprint f,float4 view,out HLGIHit hit)
{ hit=HLGIEmptyHit(maxT);return false; }
bool HLGIAreaDirectionEmissionWeight(float3 o,float3 n,float4 g,float3 d,HLGIHit hit,out float weight) { weight=1;return true; }
float3 ProxyRadiance(HLGIHit hit,float3 d,HLGIRayFootprint f,float ew,out float confidence) { confidence=0;return 0; }
float3 LimitRadiance(float3 value) { return value; }
float Random(inout uint rng) { rng++;return .5; }
uint HLGISampleAreaEmitter(float3 o,float3 random,out HLGIAreaSample sample)
{ areaDraws++;sample.direction=float3(1,0,0);sample.distance=3;return HLGI_AREA_SAMPLE; }
bool HLGIAreaLightContribution(float3 o,float3 n,float4 g,HLGIAreaSample s,HLGIRayFootprint f,float4 view,
    out float3 value,out bool worldHit,out HLGIHit hit)
{
    value=active.irradiance.xyz;worldHit=true;hit=HLGIEmptyHit(active.initialSum.y);
    hit.flags=active.initialSum.z!=0 ? HLGI_HIT_QUERY_UNRESOLVED : HLGI_HIT_VALID;
    return active.initialSum.x!=0;
}
