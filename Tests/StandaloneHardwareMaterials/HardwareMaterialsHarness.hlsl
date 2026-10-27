// These exact declarations are extracted from the current HardwareTrace source
// by the runner. No UnityRayQuery include or replacement bridge implementation.
#include "HardwareTraceTypes.hlsl"
#include "HybridLumenGIHardwareMaterials.hlsl"
struct HardwareMaterialInput
{
    HLGIHardwareInstance instance;
    HLGITriangleNormals attributes;
    float4 objectRow0,objectRow1,objectRow2;
    float4 baryRadius,materialView,rayDirection;
    uint4 controls; // instance index, primitive, coverage-only, reserved
};
struct HardwareMaterialOutput
{
    float4 diffuseAlpha,emissionOcclusion,normalSmoothness,specularCoverage,albedoReserved,shadingNormal;
    uint4 predicates;
};
StructuredBuffer<HardwareMaterialInput> _Inputs : register(t5);
RWStructuredBuffer<HardwareMaterialOutput> _Outputs : register(u0);
cbuffer TestCounts : register(b0) { uint _Count; }
// Production uses constant coverageOnly at its candidate and committed-hit
// call sites. Keep two separately optimized entry points with that contract.
void HLGIProcessHardwareMaterial(uint3 id,bool coverageOnly,bool shadowCoverage)
{
    if(id.x>=_Count) return;
    HardwareMaterialInput i=_Inputs[id.x];
    float3x4 matrix=float3x4(i.objectRow0,i.objectRow1,i.objectRow2);
    bool covered;HLGIHitMaterialSurface s;float3 ns;
    bool known=HLGIHardwareEvaluateHit(i.controls.x,i.controls.y,i.instance,i.attributes,matrix,
        i.baryRadius.xy,i.materialView,i.rayDirection.xyz,i.baryRadius.z,coverageOnly,shadowCoverage,covered,s,ns);
    HardwareMaterialOutput r=(HardwareMaterialOutput)0;
    r.diffuseAlpha=float4(s.diffuseReflectance,s.alpha);
    r.emissionOcclusion=float4(s.emission,s.occlusion);
    r.normalSmoothness=float4(s.normalTS,s.smoothness);
    r.specularCoverage=float4(s.specular,covered?1:0);
    r.albedoReserved=float4(s.albedo,0);
    r.shadingNormal=float4(ns,0);
    r.predicates=uint4(known?1u:0u,covered?1u:0u,s.receivesShadows?1u:0u,0);
    _Outputs[id.x]=r;
}
[numthreads(64,1,1)]
void CSHardwareMaterialsFull(uint3 id:SV_DispatchThreadID) { HLGIProcessHardwareMaterial(id,false,false); }
[numthreads(64,1,1)]
void CSHardwareMaterialsCoverage(uint3 id:SV_DispatchThreadID) { HLGIProcessHardwareMaterial(id,true,false); }
[numthreads(64,1,1)]
void CSHardwareMaterialsShadow(uint3 id:SV_DispatchThreadID) { HLGIProcessHardwareMaterial(id,true,true); }
