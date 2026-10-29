// Data/scene-list, absent material-cache and screen adapters surround actual source functions.
// Neither SDF sampling/marching nor query/visibility/radiance classification is adapted.
#include "HybridLumenGIHit.hlsl"
#include "HybridLumenGIRayFootprint.hlsl"
#include "HybridLumenGIRadianceValidity.hlsl"
struct QueryInput { float4 originMax,directionDetail;uint4 control; };
struct QueryOutput { uint4 query;float4 distancePosition;uint4 consumers;float4 radiance;uint4 extra;float4 cache; };
StructuredBuffer<QueryInput> _Inputs:register(t0);
RWStructuredBuffer<QueryOutput> _Outputs:register(u0);
cbuffer Counts:register(b0) { uint _Count; }
static QueryInput active;
// ACTUAL_PROXY_DECLARATION
StructuredBuffer<HLGIProxy> _HLGI_Proxies:register(t1);
static int _HLGI_ProxyCount,_HLGI_SceneBvhCount,_HLGI_GlobalSdfEnabled;
static float _HLGI_DetailTraceDistance,_HLGI_MaxDistance,_HLGI_BounceFeedback;
static int _HLGI_AreaEmitterCount;
static float4 _HLGI_Environment;
static uint4 _HLGI_LightingPolicies[3];
// Actual header, with only resource register annotations and uniform storage adapted.
#include "ActualSdfTrace.hlsl"
#include "ActualBvhBounds.hlsl"
bool HLGIShadowOwnerAllowed(uint slot,uint mask,uint layers,bool useLayers) { return true; }
bool HLGISurfaceOwnerRange(int slot,out uint4 range) { range=0;return false; }
bool HLGIGlobalSdfEmptyDistance(float3 position,out float distance) { distance=0;return false; }
// A fixed one/two-leaf scene list. Actual production bounds rejection and all
// narrow-phase/SDF queries execute; no adapter fabricates a hit or exhaustion.
int HLGIBvhNextLeaf(inout uint cursor,float3 o,float3 d,float limit)
{
    while(cursor<(uint)_HLGI_SceneBvhCount)
    {
        uint mode=active.control.y,index=cursor++;
        int other=(mode==1u || mode==3u)?1:2;
        int slot=mode==0u?0:(mode<3u?(index==0u?0:other):(index==0u?other:0));
        HLGIProxy p=_HLGI_Proxies[slot];
        if(HLGIBvhBounds(o,d,p.centerShape.xyz-p.extentsRoughness.xyz,p.centerShape.xyz+p.extentsRoughness.xyz,limit))return slot;
    }
    return -1;
}
#include "ActualSceneQueries.hlsl"
// Unrelated material/lighting boundary: no resident charts, zero direct lighting.
struct HLGISurfaceSample { float3 diffuse,emission,normal,geometricNormal;float occlusion,confidence;uint cardIndex,generation; };
struct HLGICacheEntry { float4 irradiance,tag,anchor,normal,guide; };
static HLGICacheEntry _HLGI_CacheRead[4];
static int _HLGI_CacheGrid,_HLGI_Epoch;static float _HLGI_RayBias;static bool testingCache;
bool HLGISurfaceCardUv(uint card,float3 position,out float2 uv) { uv=0.5;return true; }
float3 UnpackNormalOctQuadEncode(float2 value) { return float3(0,1,0); }
bool HLGITrySurfaceMaterialHit(HLGIHit hit,out HLGISurfaceSample surface)
{
    surface=(HLGISurfaceSample)0;surface.diffuse=0.5;surface.emission=1;
    surface.normal=surface.geometricNormal=float3(0,1,0);surface.occlusion=surface.confidence=1;surface.generation=1;
    return testingCache;
}
#include "ActualCacheQueries.hlsl"
float3 DirectIrradiance(float3 p,float3 n,float3 bias,uint2 layers,bool receives,float3 direction,HLGIRayFootprint f,out bool known) { known=true;return 0; }
#include "ActualProxyRadiance.hlsl"
bool HLGIAreaDirectionEmissionWeight(float3 o,float3 n,float4 guide,float3 d,HLGIHit h,out float weight) { weight=1;return true; }
void HLGITryScreenRayFootprint(float2 uv,float depth,float3 p,float3 d,out HLGIRayFootprint f) { HLGITryMakeRayFootprint(0,0,f); }
bool TraceScreen(float3 o,float3 d,float limit,out float3 value,out float distance,out bool known,bool resolveRadiance=true)
{
    distance=asfloat(active.control.w);known=true;value=float3(7,8,9);
    if(active.control.w==0xffffffffu)
    {
        float end;HLGISdfBounds(o-float3(2,0,0),d,float3(-1,-1,-1),float3(1,1,1),active.originMax.w,distance,end);
    }
    return distance>0 && distance<=limit;
}
float3 LimitRadiance(float3 value) { return value; }
void GatherDecision(out bool known,out float3 gathered)
{
    float3 origin=active.originMax.xyz,dir=active.directionDetail.xyz,p=origin,n=float3(0,0,1);
    float2 uv=0;float depth=0,sampleWeight=1;HLGICacheEntry receiverCache=(HLGICacheEntry)0;
    float3 sum=0;bool estimateKnown=true;
    for(int sample=0;sample<1;sample++)
    {
        // ACTUAL_GATHER_DECISION
    }
    known=estimateKnown;gathered=sum;
}
[numthreads(64,1,1)]
void CSSdfQueryCompletion(uint3 id:SV_DispatchThreadID)
{
    if(id.x>=_Count)return;
    active=_Inputs[id.x];_HLGI_ProxyCount=3;_HLGI_SdfSlotCount=3;_HLGI_SdfVoxelCount=4096;
    _HLGI_SdfTraceSteps=(int)active.control.x;_HLGI_SceneBvhCount=active.control.y==0u?1:2;
    _HLGI_GlobalSdfEnabled=(int)active.control.z;_HLGI_DetailTraceDistance=active.directionDetail.w;
    _HLGI_MaxDistance=active.originMax.w;_HLGI_BounceFeedback=0;_HLGI_AreaEmitterCount=0;_HLGI_Environment=float4(2,3,4,1);testingCache=false;
    HLGIRayFootprint footprint=HLGIPointQueryFootprint();HLGIHit hit,direct,visibility;
    bool found=TraceSceneQuery(active.originMax.xyz,active.directionDetail.xyz,active.originMax.w,false,true,0xffffffffu,0xffffffffu,false,footprint,float4(active.originMax.xyz,1),hit);
    bool shadowKnown;bool shadow=TraceShadow(active.originMax.xyz,active.directionDetail.xyz,active.originMax.w,0xffffffffu,0xffffffffu,false,footprint,float4(active.originMax.xyz,1),shadowKnown);
    bool visibleBlocked=TraceSceneVisibilityHit(active.originMax.xyz,active.directionDetail.xyz,active.originMax.w,visibility);
    bool directFound=HLGITraceMeshSdfHit(active.originMax.xyz,active.directionDetail.xyz,active.originMax.w,0,direct);
    bool gatherKnown;float3 gathered;GatherDecision(gatherKnown,gathered);
    float4 irradiance=0,guide=0;
    bool committed=HLGICommitCacheEstimate(gatherKnown,gathered,0,0,1,float3(0,0,1),irradiance,guide);
    QueryOutput output;
    output.query=uint4(found,hit.flags,hit.ownerSlot,HLGIHitMaterialKnown(hit));
    output.distancePosition=float4(hit.t,hit.position);
    output.consumers=uint4(shadow,shadowKnown,visibleBlocked,gatherKnown);
    output.radiance=float4(gathered,gatherKnown?1:-1);
    output.extra=uint4(directFound,direct.flags,hit.representation,committed);
    output.cache=0;
    if(id.x==0u)
    {
        // Four positive-weight taps: two definitely before the SDF interval,
        // two beyond it. This distinguishes unknown from dropping/reweighting taps.
        testingCache=true;_HLGI_CacheGrid=2;_HLGI_Epoch=1;_HLGI_RayBias=0;_HLGI_BounceFeedback=1;
        for(int i=0;i<4;i++)
        {
            HLGICacheEntry e=(HLGICacheEntry)0;e.irradiance=float4(4,4,4,1);e.guide=float4(0,1,0,1);
            e.tag=float4(18,3,1,1);e.normal=float4(0,1,0,0);
            float distance=i<2?0.5:3.5;e.anchor=float4(distance,0,0.28-0.015*distance,0);_HLGI_CacheRead[i]=e;
        }
        HLGIHit cacheHit=HLGIEmptyHit(0);cacheHit.flags=HLGI_HIT_VALID|HLGI_HIT_GEOMETRIC_NORMAL|HLGI_HIT_ORIENTED_NG;
        cacheHit.ownerSlot=1;cacheHit.stableId=18;cacheHit.ownerRevision=3;cacheHit.position=float3(0,0,0.28);cacheHit.rawNg=cacheHit.shadingNormal=float3(0,1,0);
        HLGISurfaceSample surface;HLGITrySurfaceMaterialHit(cacheHit,surface);HLGICacheEntry entry;bool cacheKnown=true;
        #if defined(HLGI_HIT_QUERY_UNRESOLVED)
        bool accepted=HLGICachedSurface(1,cacheHit.position,cacheHit.rawNg,cacheHit.shadingNormal,surface,entry,cacheKnown);
        #else
        bool accepted=HLGICachedSurface(1,cacheHit.position,cacheHit.rawNg,cacheHit.shadingNormal,surface,entry);
        #endif
        float confidence;float3 value=ProxyRadiance(cacheHit,active.directionDetail.xyz,footprint,1,confidence);
        output.cache=float4(accepted?1:0,cacheKnown?1:0,confidence,entry.irradiance.x);
    }
    _Outputs[id.x]=output;
}
