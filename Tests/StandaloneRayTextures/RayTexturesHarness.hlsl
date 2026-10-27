#include "HybridLumenGIRayTextures.hlsl"
struct RayTextureInput { uint2 handle;float2 uv;float lod;float3 reserved; };
struct RayTextureOutput { float4 rgba;uint4 predicates; };
StructuredBuffer<RayTextureInput> _Inputs : register(t2);
RWStructuredBuffer<RayTextureOutput> _Outputs : register(u0);
cbuffer TestCounts : register(b0) { uint _Count; }
[numthreads(64,1,1)]
void CSRayTexturesTest(uint3 id:SV_DispatchThreadID)
{
    if(id.x>=_Count)return;
    RayTextureInput input=_Inputs[id.x];
    RayTextureOutput result=(RayTextureOutput)0;
    float4 rgba;
    bool known=HLGISampleRayTexture(input.handle,input.uv,input.lod,rgba);
    result.rgba=rgba;result.predicates.x=known?1u:0u;
    _Outputs[id.x]=result;
}
