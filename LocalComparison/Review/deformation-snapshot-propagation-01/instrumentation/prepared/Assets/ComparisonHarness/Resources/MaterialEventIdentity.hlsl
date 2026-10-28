// Test observer ABI; status is independent of the product's history-reusable flag.
#ifndef MATERIAL_EVENT_IDENTITY_INCLUDED
#define MATERIAL_EVENT_IDENTITY_INCLUDED
// status: active1, identity-known2, candidate-in-range4, unambiguous8,
// primitive-matches16, object-loaded32, object-key-matches64. Inactive is0.
bool MEObjectIndex(uint4 identity,uint3 candidate,uint count,out uint index,out uint status)
{
    index=0;status=1u;
    if(identity.w==1u && identity.z>0u && any(identity.xy!=0u))status|=2u;
    if(candidate.y==0u)status|=8u;
    if(identity.z>0u && candidate.z==identity.z)status|=16u;
    if(candidate.x==0u || candidate.x>count)return false;
    status|=4u;index=candidate.x-1u;return true;
}
uint MEObjectLoadedStatus(uint status,uint2 identityKey,uint2 actualRowKey)
{
    status|=32u;
    if(all(identityKey==actualRowKey))status|=64u;
    return status;
}
#endif
