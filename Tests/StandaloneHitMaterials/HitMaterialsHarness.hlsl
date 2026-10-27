#include "HybridLumenGIHitMaterials.hlsl"
struct HitMaterialInput
{
    HLGIHitMaterialRecord material;
    float4 uvViewXY, viewZReserved;
    float4 lod0, lod1, lod2;
};
struct HitMaterialOutput
{
    float4 diffuseAlpha, emissionOcclusion, normalSmoothness, specularCoverage, albedoReserved;
    uint4 predicates;
};
StructuredBuffer<HitMaterialInput> _Inputs : register(t2);
RWStructuredBuffer<HitMaterialOutput> _Outputs : register(u0);
cbuffer TestCounts : register(b0) { uint _Count; }
[numthreads(64,1,1)]
void CSHitMaterialsTest(uint3 id:SV_DispatchThreadID)
{
    if(id.x>=_Count) return;
    HitMaterialInput i=_Inputs[id.x];HLGIHitMaterialLods lods;
    [unroll] for(uint m=0;m<10;m++) lods.values[m]=m<4?i.lod0[m]:m<8?i.lod1[m-4]:i.lod2[m-8];
    float3 view=float3(i.uvViewXY.zw,i.viewZReserved.x);
    HLGIHitMaterialSurface surface;bool covered;
    bool known=HLGIEvaluateHitMaterial(i.material,i.uvViewXY.xy,view,lods,surface);
    bool coverageKnown=HLGIEvaluateHitCoverage(i.material,i.uvViewXY.xy,view,lods,covered);
    HitMaterialOutput r=(HitMaterialOutput)0;
    r.diffuseAlpha=float4(surface.diffuseReflectance,surface.alpha);
    r.emissionOcclusion=float4(surface.emission,surface.occlusion);
    r.normalSmoothness=float4(surface.normalTS,surface.smoothness);
    r.specularCoverage=float4(surface.specular,covered?1:0);
    r.albedoReserved=float4(surface.albedo,0);
    r.predicates=uint4(known?1u:0u,coverageKnown?1u:0u,surface.receivesShadows?1u:0u,0u);
    _Outputs[id.x]=r;
}
