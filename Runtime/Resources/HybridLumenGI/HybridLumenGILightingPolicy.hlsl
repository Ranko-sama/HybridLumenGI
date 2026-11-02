#ifndef HLGI_LIGHTING_POLICY_INCLUDED
#define HLGI_LIGHTING_POLICY_INCLUDED
// Same slot/snapshot as _HLGI_Proxies. Integer fields retain all 32 mask bits.
// x: GameObject layer bit; y: rendering layers; z: ShadowCastingMode.
// w bits 0/1/2: uniform Lit disables realtime shadows / static mask assigned / card UVs usable.
StructuredBuffer<uint4> _HLGI_LightingPolicies;
bool HLGILightAffectsReceiver(uint2 receiver,uint cullingMask,uint renderingLayers,bool useRenderingLayers)
{
    return (receiver.x&cullingMask)!=0 && (!useRenderingLayers || (receiver.y&renderingLayers)!=0);
}
bool HLGIShadowOwnerAllowed(uint slot,uint cullingMask,uint shadowRenderingLayers,bool useRenderingLayers)
{
    if(slot>=(uint)_HLGI_ProxyCount) return false;
    if(_HLGI_Proxies[slot].identity.w<0.5 || _HLGI_Proxies[slot].identity.w>=1.5) return false;
    uint4 policy=_HLGI_LightingPolicies[slot];
    return policy.z!=0 && (policy.x&cullingMask)!=0 && (!useRenderingLayers || (policy.y&shadowRenderingLayers)!=0);
}
bool HLGIShadowTwoSided(uint slot) { return _HLGI_LightingPolicies[slot].z==2; }
#endif
