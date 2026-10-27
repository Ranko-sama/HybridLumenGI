#include "HybridLumenGIAreaEmission.hlsl"
struct AreaEmissionInput { HLGIAreaEmitter emitter;float4 origin,targetPosition,parameters;uint4 control,identity,geometry; };
struct AreaEmissionOutput { float4 direction,sample,balance;uint4 predicates; };
StructuredBuffer<AreaEmissionInput> _Inputs:register(t0);
RWStructuredBuffer<AreaEmissionOutput> _Outputs:register(u0);
cbuffer TestCounts:register(b1) { uint _Count; }
[numthreads(64,1,1)]
void CSAreaEmissionTest(uint3 id:SV_DispatchThreadID)
{
    if(id.x>=_Count)return;
    AreaEmissionInput i=_Inputs[id.x];AreaEmissionOutput o=(AreaEmissionOutput)0;
    HLGIAreaSample sample=(HLGIAreaSample)0;uint status=0;bool match=false;
    HLGIHit hit=HLGIEmptyHit(i.targetPosition.w);hit.position=i.targetPosition.xyz;hit.flags=i.control.z;
    hit.ownerSlot=i.identity.x;hit.stableId=i.identity.y;hit.ownerRevision=i.identity.z;hit.geometryRevision=i.identity.w;
    hit.hardwareInstance=i.geometry.x;hit.submesh=i.geometry.y;hit.primitive=i.geometry.z;
    if(i.control.x==0u)
        status=HLGIAreaSolidAnglePdf(i.emitter,i.origin.xyz,i.targetPosition.xyz,sample.direction,sample.distance,sample.pdf);
    else if(i.control.x==1u || i.control.x==3u)
    {
        status=HLGISampleAreaEmitter(i.origin.xyz,i.parameters.xyz,sample);
        if(i.control.x==3u)
        {
            hit.position=sample.position+i.targetPosition.xyz;hit.t=sample.distance+i.targetPosition.w;
            match=HLGIAreaSampleMatchesHit(sample,hit,i.control.y);
        }
    }
    else if(i.control.x==2u)
        status=HLGIAreaHitPdf(i.origin.xyz,hit,i.control.y,sample.pdf);
    else if(i.control.x==4u)
    {
        float directionWeight,inverseSum;
        match=HLGIAreaBalance(i.parameters.x,i.parameters.y,directionWeight,inverseSum);
        o.balance=float4(directionWeight,inverseSum,0,0);
    }
    o.direction=float4(sample.direction,sample.distance);o.sample=float4(sample.position,sample.pdf);
    o.predicates=uint4(status,sample.index,match?1u:0u,0u);_Outputs[id.x]=o;
}
