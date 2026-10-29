// Actual cache interpolation / consumers with explicit scene and material dependencies.
// The existing WARP host binds 208-byte input rows and 368-byte output rows.
#include "HybridLumenGIHit.hlsl"
#include "HybridLumenGIRayFootprint.hlsl"
#include "HybridLumenGIRadianceValidity.hlsl"
struct CacheInput { uint4 mode;float4 unused[12]; };
struct CacheOutput { float4 values[23]; };
StructuredBuffer<CacheInput> _Inputs:register(t0);
RWStructuredBuffer<CacheOutput> _Outputs:register(u0);
cbuffer Counts:register(b0) { uint _Count; }
static CacheInput active;
struct HLGIProxy { float4 centerShape,extentsRoughness,albedo,emission,identity; };
struct HLGICacheEntry { float4 irradiance,tag,anchor,normal,guide; };
struct HLGISurfaceSample { float3 diffuse,emission,normal,geometricNormal;float occlusion,confidence;uint cardIndex,generation; };
static HLGIProxy _HLGI_Proxies[1];
static HLGICacheEntry _HLGI_CacheRead[4];
static uint4 _HLGI_LightingPolicies[1];
static int _HLGI_ProxyCount=1,_HLGI_CacheGrid=2,_HLGI_Epoch=1;
static float _HLGI_RayBias=0,_HLGI_BounceFeedback=1;
static uint queries,unknownFlags;

// Card addressing/normal decoding are fixed dependency inputs, not tested here.
bool HLGISurfaceCardUv(uint card,float3 position,out float2 uv)
{ uv=active.mode.z!=0u?0.25:0.5;return true; }
float3 UnpackNormalOctQuadEncode(float2 oct) { return float3(0,1,0); }
bool HLGITrySurfaceMaterialHit(HLGIHit hit,out HLGISurfaceSample surface)
{
    surface=(HLGISurfaceSample)0;surface.diffuse=0.5;surface.emission=float3(.125,.25,.5);
    surface.normal=surface.geometricNormal=float3(0,1,0);
    surface.occlusion=surface.confidence=1;surface.generation=1;return true;
}
float3 DirectIrradiance(float3 p,float3 n,float3 ng,uint2 layers,bool receives,
    float3 direction,HLGIRayFootprint footprint,out bool known)
{ known=true;return float3(.25,.5,.75); }

// Only the bridge evaluation is a spy. The exact source's committed-material
// classifier produces MATERIAL_UNKNOWN for failed coverage; no fabricated
// material flag substitutes for that production function.
struct HLGIHardwareInstance { uint unused; };
struct HLGITriangleNormals { uint unused; };
struct HLGIHitMaterialSurface { float3 diffuseReflectance,emission;float occlusion;bool receivesShadows; };
bool HLGIHardwareEvaluateHit(uint instanceIndex,uint primitive,HLGIHardwareInstance instance,
    HLGITriangleNormals attributes,float3x4 objectToWorld,float2 barycentric,float4 view,
    float3 direction,float radius,bool coverageOnly,bool shadowCoverage,
    out bool covered,out HLGIHitMaterialSurface material,out float3 normal)
{
    covered=true;material=(HLGIHitMaterialSurface)0;normal=float3(0,1,0);
    return active.mode.x!=2u;
}
#include "ActualCommittedMaterial.hlsl"

// Controlled connectivity: left or right anchors encounter a nearest candidate.
// This is deliberately not a claim about full DXR/software triangle traversal.
bool TraceSceneVisibilityHit(float3 origin,float3 direction,float distance,
    HLGIRayFootprint footprint,float4 materialView,out HLGIHit hit)
{
    queries++;hit=HLGIEmptyHit(distance);
    bool selected=active.mode.y==2u || (active.mode.y==0u?direction.x<0:direction.x>0);
    if(active.mode.x==0u || !selected)return false;
    hit.flags=HLGI_HIT_VALID|HLGI_HIT_TRIANGLE;hit.t=distance*0.5;
    if(active.mode.x==3u)hit.flags=HLGI_HIT_VALID|HLGI_HIT_QUERY_UNRESOLVED;
    else
    {
        HLGIHardwareInstance instance=(HLGIHardwareInstance)0;
        HLGITriangleNormals attributes=(HLGITriangleNormals)0;
        HLGIHardwareResolveCommittedMaterial(0,0,instance,attributes,(float3x4)0,0,
            materialView,direction,0,0,false,false,hit);
    }
    unknownFlags|=hit.flags&(HLGI_HIT_MATERIAL_UNKNOWN|HLGI_HIT_QUERY_UNRESOLVED);
    return true;
}
#include "ActualCacheConsumers.hlsl"

[numthreads(64,1,1)]
void CSCacheVisibilityMaterial(uint3 id:SV_DispatchThreadID)
{
    if(id.x>=_Count)return;
    active=_Inputs[id.x];queries=unknownFlags=0;
    _HLGI_Proxies[0]=(HLGIProxy)0;_HLGI_Proxies[0].identity=float4(17,3,0,1);
    _HLGI_LightingPolicies[0]=1;
    for(int i=0;i<4;i++)
    {
        HLGICacheEntry entry=(HLGICacheEntry)0;
        entry.irradiance=float4((i&1)==0?float3(4,0,0):float3(0,0,2),1);
        entry.guide=float4(0,1,0,1);entry.tag=float4(17,3,1,1);
        entry.anchor=float4((i&1)==0?-1:1,0,i<2?-1:1,0);
        entry.normal=float4(0,1,0,0);_HLGI_CacheRead[i]=entry;
    }
    HLGIHit receiver=HLGIEmptyHit(0);
    receiver.flags=HLGI_HIT_VALID|HLGI_HIT_GEOMETRIC_NORMAL|HLGI_HIT_ORIENTED_NG;
    receiver.ownerSlot=0;receiver.stableId=17;receiver.ownerRevision=3;
    receiver.rawNg=receiver.shadingNormal=float3(0,1,0);
    HLGISurfaceSample surface;HLGITrySurfaceMaterialHit(receiver,surface);
    HLGICacheEntry cache;bool known;
    bool accepted=HLGICachedSurface(0,0,receiver.rawNg,receiver.shadingNormal,surface,cache,known);
    CacheOutput output=(CacheOutput)0;
    output.values[0]=float4(accepted?1:0,known?1:0,queries,unknownFlags);
    output.values[1]=cache.irradiance;output.values[2]=cache.tag;
    output.values[3]=cache.anchor;output.values[4]=cache.normal;output.values[5]=cache.guide;
    float3 cached=CachedIrradiance(receiver,receiver.shadingNormal,known);
    output.values[6]=float4(cached,known?1:0);
    float confidence;
    float3 radiance=ProxyRadiance(receiver,receiver.shadingNormal,HLGIPointQueryFootprint(),1,confidence);
    output.values[7]=float4(radiance,confidence);
    _Outputs[id.x]=output;
}
