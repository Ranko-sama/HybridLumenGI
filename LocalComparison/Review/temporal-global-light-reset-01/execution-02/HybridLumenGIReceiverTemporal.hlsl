#ifndef HLGI_RECEIVER_TEMPORAL_INCLUDED
#define HLGI_RECEIVER_TEMPORAL_INCLUDED
#include "HybridLumenGIReceiverIdentity.hlsl"

// Kept separate from textures so the exact shader predicate can be exercised by
// a small compute harness. Row flags are established from the same f-1 receipt.
bool HLGITryReceiverMotion(uint4 identity,uint3 candidate,HLGIReceiverIdentityObject row,
    float3 position,float3 shadingNormal,float3 geometricNormal,
    out float3 previousPosition,out float3 previousShadingNormal,out float3 previousGeometricNormal)
{
    previousPosition=position;previousShadingNormal=shadingNormal;previousGeometricNormal=geometricNormal;
    if(identity.w!=1u || identity.z==0u || !any(identity.xy!=0u) || candidate.x==0u ||
        candidate.y!=0u || candidate.z!=identity.z || any(row.key!=identity.xy) || (row.flags&1u)==0u) return false;
    float4 p=mul(row.currentToPrevious,float4(position,1));
    float3 ns=mul((float3x3)row.currentToPrevious,shadingNormal);
    float3 ng=mul((float3x3)row.currentToPrevious,geometricNormal);
    float ns2=dot(ns,ns),ng2=dot(ng,ng);
    if(!all(isfinite(p)) || abs(p.w-1)>1e-5 || !all(isfinite(ns)) || !all(isfinite(ng)) ||
        !isfinite(ns2) || !isfinite(ng2) || ns2<1e-16 || ng2<1e-16) return false;
    previousPosition=p.xyz;previousShadingNormal=ns*rsqrt(ns2);previousGeometricNormal=ng*rsqrt(ng2);
    return true;
}
bool HLGISameReceiverPrimitive(uint4 current,uint4 previous)
{
    return current.w==1u && previous.w==1u && current.z>0u && any(current.xy!=0u) && all(current.xyz==previous.xyz);
}
#endif
