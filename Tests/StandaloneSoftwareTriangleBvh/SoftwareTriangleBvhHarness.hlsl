#define HLGI_SOFTWARE_GEOMETRY_ONLY 1
#include "HybridLumenGISoftwareTriangleBvh.hlsl"
struct SoftwareTriangleBvhInput { HLGISoftwareTriangleLeaf leaf;float4 origin,direction,parameters;uint4 control; };
struct SoftwareTriangleBvhOutput { float4 values;uint4 identity; };
StructuredBuffer<SoftwareTriangleBvhInput> _Inputs:register(t0);
RWStructuredBuffer<SoftwareTriangleBvhOutput> _Outputs:register(u0);
cbuffer TestCounts:register(b1) { uint _Count; }
[numthreads(64,1,1)]
void CSSoftwareTriangleBvhTest(uint3 id:SV_DispatchThreadID)
{
    if(id.x>=_Count)return;
    SoftwareTriangleBvhInput i=_Inputs[id.x];SoftwareTriangleBvhOutput o=(SoftwareTriangleBvhOutput)0;
    float closest=i.parameters.x;float2 bary=0;uint status=0u,visits=0u;
    if(i.control.x==0u)status=HLGISoftwareTriangleIntersection(i.origin.xyz,i.direction.xyz,closest,i.leaf,closest,bary);
    else
    {
        uint cursor=0u;HLGISoftwareTriangleLeaf leaf;float entry;
        [loop]while(HLGISoftwareNextTriangle(i.origin.xyz,i.direction.xyz,closest,cursor,leaf,entry))
        {
            visits++;float t;float2 b;uint candidate=HLGISoftwareTriangleIntersection(i.origin.xyz,i.direction.xyz,closest,leaf,t,b);
            if(candidate==1u && (status==0u || t<closest || (t==closest && leaf.identity.y<o.identity.y)))
            {closest=t;bary=b;status=1u;o.identity.xy=leaf.identity.xy;}
            else if(candidate==2u){status=2u;break;}
        }
    }
    o.values=float4(closest,bary,(float)status);o.identity.z=visits;_Outputs[id.x]=o;
}
