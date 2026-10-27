#include "HybridLumenGIRayFootprint.hlsl"
#include "HybridLumenGIHit.hlsl"
struct RayQueryPropagationInput
{
    float4 originMax,directionLimit,footprint,view;
    uint4 policy,control;
    float4 hitT,global0,global1;
    uint4 metadata; // global valid mask, footprint valid, identity seed, unused
};
struct RayQueryPropagationOutput
{
    uint4 stats;float4 hit;
    uint4 identity,binding;
    float4 nearOrigin,farOrigin,nearDirection,farDirection,nearFootprint,farFootprint,nearView,farView;
    uint4 nearPolicy,farPolicy,modes;
    float4 globalPositions[8];
};
StructuredBuffer<RayQueryPropagationInput> _Inputs:register(t0);
RWStructuredBuffer<RayQueryPropagationOutput> _Outputs:register(u0);
cbuffer Counts:register(b0) { uint _Count; }
static RayQueryPropagationInput active;
static RayQueryPropagationOutput recorded;
static uint detailCalls,globalCalls;
static int _HLGI_GlobalSdfEnabled;
static float _HLGI_DetailTraceDistance;
// Explicit recording dependencies, not real BVH/SDF/RayQuery traversal. They
// supply controlled geometry while preserving an invalid-footprint occluder.
bool TraceSceneDetailQuery(float3 o,float3 d,float maxT,bool shadowQuery,bool resolveMaterial,uint cullingMask,uint shadowRenderingLayers,bool useRenderingLayers,
    HLGIRayFootprint footprint,float4 materialView,out HLGIHit result)
{
    uint call=detailCalls++;
    uint4 policy=uint4(shadowQuery?1u:0u,resolveMaterial?1u:0u,cullingMask,shadowRenderingLayers);
    if(call==0u)
    {
        recorded.nearOrigin=float4(o,maxT);recorded.nearDirection=float4(d,0);recorded.nearFootprint=float4(footprint.radius,footprint.slope,0,0);
        recorded.nearView=materialView;recorded.nearPolicy=policy;recorded.modes.x=useRenderingLayers?1u:0u;recorded.modes.z=footprint.valid;
    }
    else
    {
        recorded.farOrigin=float4(o,maxT);recorded.farDirection=float4(d,0);recorded.farFootprint=float4(footprint.radius,footprint.slope,0,0);
        recorded.farView=materialView;recorded.farPolicy=policy;recorded.modes.y=useRenderingLayers?1u:0u;recorded.modes.w=footprint.valid;
    }
    result=HLGIEmptyHit(maxT);
    uint flags=call==0u?active.control.z:active.control.w;float t=call==0u?active.hitT.x:active.hitT.y;
    if((flags&HLGI_HIT_VALID)==0u || t<=0 || t>=maxT) return false;
    result.t=t;result.position=o+d*t;result.flags=flags;
    HLGIRayFootprint atHit;
    if(!HLGIAdvanceRayFootprint(footprint,t,atHit)) result.flags|=HLGI_HIT_MATERIAL_UNKNOWN;
    result.ownerSlot=3u;result.stableId=active.metadata.z;result.ownerRevision=41u;result.geometryRevision=43u;
    result.surfaceBinding=uint4(7u,11u,13u,43u);return true;
}
bool HLGIGlobalSdfEmptyDistance(float3 p,out float distance)
{
    uint index=globalCalls++;
    distance=index<4u?active.global0[min(index,3u)]:active.global1[min(index-4u,3u)];
    if(index<8u) recorded.globalPositions[index]=float4(p,distance);
    return index<8u && ((active.metadata.x>>index)&1u)!=0u;
}
// Original production body copied byte-for-byte, without logic rewriting.
#include "ActualTraceSceneQuery.hlsl"
[numthreads(64,1,1)]
void CSRayQueryPropagationTest(uint3 id:SV_DispatchThreadID)
{
    if(id.x>=_Count)return;
    active=_Inputs[id.x];recorded=(RayQueryPropagationOutput)0;detailCalls=globalCalls=0u;
    _HLGI_GlobalSdfEnabled=(int)active.control.x;_HLGI_DetailTraceDistance=active.directionLimit.w;
    HLGIRayFootprint footprint;footprint.radius=active.footprint.x;footprint.slope=active.footprint.y;footprint.valid=active.metadata.y;
    HLGIHit hit;
    bool found=TraceSceneQuery(active.originMax.xyz,active.directionLimit.xyz,active.originMax.w,
        active.policy.x!=0u,active.policy.y!=0u,active.policy.z,active.policy.w,active.control.y!=0u,footprint,active.view,hit);
    recorded.stats=uint4(found?1u:0u,detailCalls,globalCalls,hit.flags);
    recorded.hit=float4(hit.position,hit.t);recorded.identity=uint4(hit.ownerSlot,hit.stableId,hit.ownerRevision,hit.geometryRevision);
    recorded.binding=hit.surfaceBinding;_Outputs[id.x]=recorded;
}
