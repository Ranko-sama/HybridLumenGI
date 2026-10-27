#include "HybridLumenGIHardwareNormals.hlsl"
struct HardwareNormalInput
{
    column_major float4x4 normalToWorld;
    float4 normalA,normalB,normalC,weights;
    uint4 flags;
};
struct HardwareNormalOutput
{
    float4 shadingNormal;
    uint4 predicates;
    float4 legacyNormal;
};
StructuredBuffer<HardwareNormalInput> _Inputs : register(t0);
RWStructuredBuffer<HardwareNormalOutput> _Outputs : register(u0);
cbuffer TestCounts : register(b0) { uint _Count; }
[numthreads(64,1,1)]
void CSHardwareNormalsTest(uint3 id:SV_DispatchThreadID)
{
    if(id.x>=_Count)return;
    HardwareNormalInput input=_Inputs[id.x];
    HardwareNormalOutput output=(HardwareNormalOutput)0;
    float3 normal=0;
    bool valid=input.flags.x!=0 && HLGITryHardwareShadingNormal((float3x3)input.normalToWorld,
        input.normalA.xyz,input.normalB.xyz,input.normalC.xyz,input.weights.xyz,normal);
    // Match the runtime's explicit fallback: HLSL logical operators may evaluate
    // the helper even when sourcePresent is false. No false Ns is published.
    if(!valid) normal=0;
    output.shadingNormal=float4(normal,0);
    output.predicates.x=valid?1u:0u;
    // Execute the previous operation order too, to demonstrate the regression
    // on the same uploaded data. This reference is not the correctness oracle.
    float3 oldNormal=mul((float3x3)input.normalToWorld,
        input.normalA.xyz*input.weights.x+input.normalB.xyz*input.weights.y+input.normalC.xyz*input.weights.z);
    float3 oldUnit=0;HLGIHardwareUnitNormal(oldNormal,oldUnit);
    output.legacyNormal=float4(oldUnit,0);
    _Outputs[id.x]=output;
}
