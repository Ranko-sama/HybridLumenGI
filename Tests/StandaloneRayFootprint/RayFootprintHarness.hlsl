#include "HybridLumenGIRayFootprint.hlsl"
struct RayFootprintInput
{
    column_major float4x4 worldToCard;
    float4 p,pX,pY,direction,normal,auxiliary,parameters;
    uint4 control;
};
struct RayFootprintOutput { float4 values,comparison;uint4 predicates; };
StructuredBuffer<RayFootprintInput> _Inputs : register(t0);
RWStructuredBuffer<RayFootprintOutput> _Outputs : register(u0);
cbuffer TestCounts : register(b0) { uint _Count; }
[numthreads(64,1,1)]
void CSRayFootprintTest(uint3 id:SV_DispatchThreadID)
{
    if(id.x>=_Count)return;
    RayFootprintInput i=_Inputs[id.x];RayFootprintOutput o=(RayFootprintOutput)0;
    HLGIRayFootprint a=(HLGIRayFootprint)0,b=(HLGIRayFootprint)0,c=(HLGIRayFootprint)0;
    a.radius=i.p.x;a.slope=i.p.y;a.valid=i.control.y;
    bool known=false,other=false;
    if(i.control.x==0u)
    {
        known=HLGIAdvanceRayFootprint(a,i.parameters.x+i.parameters.y,b);
        if(HLGIAdvanceRayFootprint(a,i.parameters.x,c)) other=HLGIAdvanceRayFootprint(c,i.parameters.y,c);
    }
    else if(i.control.x==1u)
    {
        float slope;known=HLGITryAngleSpread(i.parameters.x,slope);
        if(known)HLGITryMakeRayFootprint(0,slope,b);
    }
    else if(i.control.x==2u)
        known=HLGITryScreenFootprint(i.p.xyz,i.pX.xyz,i.pY.xyz,i.parameters.xy,i.parameters.zw,i.direction.xyz,b);
    else if(i.control.x==3u)
        known=HLGITryCardPatchFootprint(i.worldToCard,i.p.xyz,i.normal.xyz,(uint2)i.auxiliary.xy,
            i.control.zw,i.control.y,i.direction.xyz,b);
    else if(i.control.x==4u)
        known=HLGITryRetargetFootprint(a,i.direction.xyz,i.normal.xyz,i.auxiliary.xyz,b);
    else if(i.control.x==5u)
    {
        known=HLGITryPointShadowFootprint(a,i.parameters.x,b);
        if(known)other=HLGIAdvanceRayFootprint(b,i.parameters.y,c);
    }
    else if(i.control.x==6u)
    {
        known=HLGITryDirectionalShadowFootprint(a,b);
        if(known)other=HLGIAdvanceRayFootprint(b,i.parameters.y,c);
    }
    if(!known)b=(HLGIRayFootprint)0;if(!other)c=(HLGIRayFootprint)0;
    o.values=float4(b.radius,b.slope,0,0);o.comparison=float4(c.radius,c.slope,0,0);
    o.predicates=uint4(known?1u:0u,other?1u:0u,b.valid,c.valid);_Outputs[id.x]=o;
}
