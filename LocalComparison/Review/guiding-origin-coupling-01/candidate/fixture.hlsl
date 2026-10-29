// Actual CSTrace receiver prelude and sampler. Only resource storage, an
// independent finite plane query, and absent cache are dependency adapters.
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "HybridLumenGIHit.hlsl"
#include "HybridLumenGIRayFootprint.hlsl"
#include "HybridLumenGIScreenSampling.hlsl"
#include "HybridLumenGIScreenGeometry.hlsl"
#include "HybridLumenGIScreenMaterial.hlsl"
struct InputRow { float4 parameters;float4 values[12]; };
struct OutputRow { float4 rows[23]; };
StructuredBuffer<InputRow> _Inputs:register(t0);
RWStructuredBuffer<OutputRow> _Outputs:register(u0);
cbuffer Counts:register(b0) { uint _Count; }
static InputRow active;
static uint planeQueries,cacheQueries,planeAccepted;
static float4 queryOrigin,queryDirection,queryHit;
static float4 _HLGI_Size,_HLGI_FullSize,_HLGI_MaterialView;
static float4x4 _HLGI_InvVP,_HLGI_View;
static int _HLGI_NormalsOct,_HLGI_FrameIndex;
static float _HLGI_RayBias,_HLGI_GuideWeight;
struct HLGICacheEntry {float4 irradiance,tag,anchor,normal,guide;};
struct DepthInput
{
    float Load(int3 p) { uint i=(uint)p.y*5u+(uint)p.x;return active.values[i/4][i%4]; }
};
struct NormalInput
{
    float4 SampleLevel(SamplerState s,float2 uv,float mip) {return float4(0,1,0,0);}
};
struct MaterialInput
{
    float4 Load(int3 p) {return float4(.5,.5,.5,1);}
};
struct EmissionInput
{
    float4 Load(int3 p) {return float4(0,0,0,1);}
};
static DepthInput _HLGI_Depth,_HLGI_CaptureDepth;
static NormalInput _HLGI_Normals;
static MaterialInput _HLGI_Diffuse;
static EmissionInput _HLGI_Emission;

// An independent analytic finite plane, not a preset hit/known result.
// The footprint is accepted as an input but is irrelevant to this constant
// opaque material. No hardware traversal, alpha material, or atlas is claimed.
bool TraceSceneVisibilityHit(float3 origin,float3 direction,float maximum,
    HLGIRayFootprint footprint,float4 view,out HLGIHit hit)
{
    planeQueries++;queryOrigin=float4(origin,maximum);queryDirection=float4(direction,footprint.valid);
    hit=HLGIEmptyHit(maximum);
    if(active.parameters.y==0 || direction.y>=0)return false;
    float t=-origin.y/direction.y;
    float3 p=origin+t*direction;
    if(!(t>0 && t<=maximum) || abs(p.x)>.01 || abs(p.z)>.05)return false;
    hit.t=t;hit.position=p;hit.rawNg=hit.shadingNormal=float3(0,1,0);
    hit.ownerSlot=0;hit.stableId=hit.ownerRevision=hit.geometryRevision=1;
    hit.flags=HLGI_HIT_VALID|HLGI_HIT_GEOMETRIC_NORMAL|HLGI_HIT_ORIENTED_NG|HLGI_HIT_SHADING_NORMAL;
    planeAccepted++;queryHit=float4(p,t);return true;
}
bool HLGICachedSample(HLGIHit hit,float3 shadingNormal,out HLGICacheEntry cache)
{
    cacheQueries++;cache=(HLGICacheEntry)0;return false;
}
#include "ActualScreenInputs.hlsl"
#include "ActualSamplerFunctions.hlsl"
#include "ActualEmissiveSampling.hlsl"

[numthreads(64,1,1)]
void CSGuideOrigin(uint3 thread:SV_DispatchThreadID)
{
    if(thread.x>=_Count)return;
    active=_Inputs[thread.x];planeQueries=cacheQueries=planeAccepted=0;
    queryOrigin=queryDirection=queryHit=0;
    _HLGI_Size=_HLGI_FullSize=float4(5,5,.2,.2);
    _HLGI_MaterialView=float4(0,.5,0,1);
    _HLGI_InvVP=float4x4(.05,0,0,0, 0,0,1,-.5, 0,.05,0,0, 0,0,0,1);
    _HLGI_View=float4x4(1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1);
    _HLGI_NormalsOct=0;_HLGI_FrameIndex=5;_HLGI_RayBias=.03;_HLGI_GuideWeight=active.parameters.x;
    _HLGI_EmissiveWeight=0;_HLGI_EmissiveProposals[0]=(HLGIEmissiveRecord)0;
    OutputRow result=(OutputRow)0;
    float4 capturedGeometry=0,capturedMaterial=0,capturedOutput=0;
    uint3 id=uint3(2,2,0);
    
    if(any(id.xy>=(uint2)_HLGI_Size.xy)) return;
    uint2 fullPixel=HLGIFullPixelForGiPixel(id.xy,(uint2)_HLGI_Size.xy,(uint2)_HLGI_FullSize.xy);
    float2 uv=HLGIFullPixelCenterUv(fullPixel,(uint2)_HLGI_FullSize.xy);
    float depth=_HLGI_Depth.Load(int3(fullPixel,0));
    float4 material=_HLGI_Diffuse.Load(int3(fullPixel,0));
    float capturedDepth=_HLGI_CaptureDepth.Load(int3(fullPixel,0));
    bool sameSurface=ValidDepth(capturedDepth) && distance(WorldPosition(uv,depth,_HLGI_InvVP),WorldPosition(uv,capturedDepth,_HLGI_InvVP))<0.03;
    if(!ValidDepth(depth) || !sameSurface || !HLGIHasScreenMaterial(_HLGI_Emission.Load(int3(fullPixel,0)).a))
    {
        capturedOutput=0; capturedGeometry=0; capturedMaterial=0; return;
    }
    float3 p=WorldPosition(uv,depth,_HLGI_InvVP), n=NormalAt(uv);
    capturedMaterial=material;
    uint rng=HLGIHash((id.x+id.y*(uint)_HLGI_Size.x+HLGIHash((uint)_HLGI_FrameIndex+1))^0x63D83595u);
    HLGICacheEntry receiverCache=(HLGICacheEntry)0;
    float3 geometricNormal;
    bool hasGeometry=HLGITryScreenGeometricNormal(uv,depth,p,geometricNormal);
    if(hasGeometry)
    {
        HLGIHit receiverHit;
        if(HLGITryScreenWorldMatch(uv,depth,p,geometricNormal,receiverHit))
        {
            geometricNormal=HLGIOffsetNormal(receiverHit.rawNg,geometricNormal);
            if(_HLGI_GuideWeight>0) HLGICachedSample(receiverHit,n,receiverCache);
        }
    }
    capturedGeometry=HLGIPackScreenGeometry(n,geometricNormal,hasGeometry,depth);

    float sampleWeight;
            float3 origin=p+(hasGeometry?HLGIOffsetNormal(geometricNormal,n):n)*_HLGI_RayBias;
        float3 dir=HLGISampleTransportDirection(origin,n,receiverCache.guide,rng,sampleWeight);
    float3 originalScreenNg;bool originalHasGeometry=HLGITryScreenGeometricNormal(uv,depth,p,originalScreenNg);
    result.rows[0]=float4(origin,sampleWeight);
    result.rows[1]=float4(dir,asfloat(rng));
    result.rows[2]=capturedGeometry;
    result.rows[3]=float4(p,depth);
    result.rows[4]=float4(n,hasGeometry?1:0);
    result.rows[5]=float4(geometricNormal,0);
    result.rows[6]=float4(originalScreenNg,originalHasGeometry?1:0);
    result.rows[7]=queryOrigin;result.rows[8]=queryDirection;result.rows[9]=queryHit;
    result.rows[10]=float4(planeQueries,cacheQueries,planeAccepted,0);
    result.rows[11]=receiverCache.guide;
    _Outputs[thread.x]=result;
}
