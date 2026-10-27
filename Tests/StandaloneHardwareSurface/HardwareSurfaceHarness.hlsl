#include "HybridLumenGIHardwareSurface.hlsl"
struct SurfaceInput
{
    float4 object0,object1,object2,normal0,normal1,normal2;
    float4 n0,n1,n2,t0,t1,t2,weights,direction,normalTS,p0,p1,p2,uv01,uv2Scale;
    uint4 textureSize;
    float4 cone;
    float4 view0,view1,view2;
};
struct SurfaceOutput { float4 n,t,b,view,normal,lod; };
StructuredBuffer<SurfaceInput> _Inputs : register(t0);
RWStructuredBuffer<SurfaceOutput> _Outputs : register(u0);
cbuffer Counts : register(b0) { uint _Count; }
[numthreads(64,1,1)]
void CSHardwareSurfaceTest(uint3 id:SV_DispatchThreadID)
{
    if(id.x>=_Count)return;
    SurfaceInput i=_Inputs[id.x];SurfaceOutput o=(SurfaceOutput)0;
    HLGIHardwareMaterialFrame frame;
    bool known=HLGITryHardwareMaterialFrame(float3x3(i.object0.xyz,i.object1.xyz,i.object2.xyz),
        float3x3(i.normal0.xyz,i.normal1.xyz,i.normal2.xyz),i.n0.xyz,i.n1.xyz,i.n2.xyz,i.t0,i.t1,i.t2,
        i.weights.xyz,i.view0.xyz,i.view1.xyz,i.view2.xyz,frame);
    if(known)
    {
        o.n=float4(frame.normal,1);o.t=float4(frame.tangent,1);o.b=float4(frame.bitangent,1);o.view=float4(frame.viewDirTS,1);
        float3 normal;bool normalKnown=HLGIApplyHardwareNormal(frame,i.normalTS.xyz,normal);
        o.normal=normalKnown?float4(normal,1):0;
    }
    float lod;bool lodKnown=HLGITryHardwareTextureLod(i.p0.xyz,i.p1.xyz,i.p2.xyz,i.uv01.xy,i.uv01.zw,i.uv2Scale.xy,
        i.uv2Scale.zw,i.textureSize.xy,i.direction.xyz,i.cone.x,lod);
    o.lod=float4(lod,0,0,lodKnown?1:0);_Outputs[id.x]=o;
}
