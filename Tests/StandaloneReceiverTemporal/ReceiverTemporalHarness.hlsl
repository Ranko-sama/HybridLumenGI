#include "HybridLumenGIReceiverTemporal.hlsl"
struct ReceiverTemporalInput
{
    HLGIReceiverIdentityObject row;
    uint4 identity;
    uint4 candidate;
    float4 position;
    float4 shadingNormal;
    float4 geometricNormal;
    uint4 previousIdentity;
};
struct ReceiverTemporalOutput
{
    float4 previousPosition;
    float4 previousShadingNormal;
    float4 previousGeometricNormal;
    uint4 predicates;
};
StructuredBuffer<ReceiverTemporalInput> _Inputs : register(t0);
RWStructuredBuffer<ReceiverTemporalOutput> _Outputs : register(u0);
cbuffer TestCounts : register(b0) { uint _Count; }
[numthreads(64,1,1)]
void CSReceiverTemporalTest(uint3 id:SV_DispatchThreadID)
{
    if(id.x>=_Count)return;
    ReceiverTemporalInput input=_Inputs[id.x];
    ReceiverTemporalOutput output;
    float3 p,ns,ng;
    bool eligible=HLGITryReceiverMotion(input.identity,input.candidate.xyz,input.row,
        input.position.xyz,input.shadingNormal.xyz,input.geometricNormal.xyz,p,ns,ng);
    output.previousPosition=float4(p,0);
    output.previousShadingNormal=float4(ns,0);
    output.previousGeometricNormal=float4(ng,0);
    output.predicates=uint4(eligible?1u:0u,HLGISameReceiverPrimitive(input.identity,input.previousIdentity)?1u:0u,0,0);
    _Outputs[id.x]=output;
}
