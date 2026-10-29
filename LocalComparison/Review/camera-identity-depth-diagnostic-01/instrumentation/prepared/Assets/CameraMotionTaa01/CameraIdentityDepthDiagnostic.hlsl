// Temporary diagnosis only: no changes to identity vertex or acceptance logic.
StructuredBuffer<uint> _HLGI_IdentityProbeMap;
RWStructuredBuffer<uint4> _HLGI_IdentityProbeRows : register(u2);
float _HLGI_IdentityProbeEnabled;

uint HLGIIdentityProbeAddress(float4 positionCS, out uint2 pixel)
{
    pixel=0;
    if(_HLGI_IdentityProbeEnabled==0 || !all(isfinite(positionCS.xy)) ||
        any(positionCS.xy<0) || any(positionCS.xy>=_HLGI_IdentityFullSize.xy) ||
        _HLGI_IdentityOwnerIndexPlusOne<1u || _HLGI_IdentityOwnerIndexPlusOne>3u) return 0xffffffffu;
    pixel=(uint2)positionCS.xy;
    uint canonical=_HLGI_IdentityProbeMap[pixel.y*(uint)_HLGI_IdentityFullSize.x+pixel.x];
    if(canonical==0u || canonical>264u) return 0xffffffffu;
    return 57u+((canonical-1u)*3u+_HLGI_IdentityOwnerIndexPlusOne-1u)*3u;
}

void HLGIIdentityProbeEntry(float4 positionCS)
{
    uint2 pixel;uint address=HLGIIdentityProbeAddress(positionCS,pixel);
    if(address==0xffffffffu)return;
    uint ignored;
    InterlockedAdd(_HLGI_IdentityProbeRows[address].x,1u,ignored);
    uint header=(_HLGI_IdentityOwnerIndexPlusOne-1u)*19u;
    uint previous;
    InterlockedCompareExchange(_HLGI_IdentityProbeRows[header].x,0u,1u,previous);
    if(previous!=0u)return;
    _HLGI_IdentityProbeRows[header].y=asuint(_AlphaToMaskAvailable);
    _HLGI_IdentityProbeRows[header].z=asuint(_HLGI_IdentityHasBaseMap);
    _HLGI_IdentityProbeRows[header].w=_HLGI_IdentityOwnerIndexPlusOne;
    [unroll]for(uint r=0;r<4;r++)
    {
        _HLGI_IdentityProbeRows[header+1u+r]=asuint(UNITY_MATRIX_VP[r]);
        _HLGI_IdentityProbeRows[header+5u+r]=asuint(_HLGI_IdentityViewProjection[r]);
        _HLGI_IdentityProbeRows[header+11u+r]=asuint(UNITY_MATRIX_M[r]);
        _HLGI_IdentityProbeRows[header+15u+r]=asuint(_HLGI_IdentityObjectToWorld[r]);
    }
    _HLGI_IdentityProbeRows[header+9u]=asuint(_HLGI_IdentityAlphaParams);
    uint debugVariant=0u;
    #if defined(DEBUG_DISPLAY)
        debugVariant=1u;
    #endif
    _HLGI_IdentityProbeRows[header+10u]=uint4(debugVariant,0u,0u,0u);
}

void HLGIIdentityProbeDepth(float4 positionCS,uint primitive,float cameraDepth,float captureDepth)
{
    uint2 pixel;uint address=HLGIIdentityProbeAddress(positionCS,pixel);
    if(address==0xffffffffu)return;
    uint ignored,previous;
    InterlockedAdd(_HLGI_IdentityProbeRows[address].y,1u,ignored);
    InterlockedCompareExchange(_HLGI_IdentityProbeRows[address].z,0u,1u,previous);
    if(previous!=0u)return;
    uint gate=0u;
    if(isfinite(cameraDepth)&&isfinite(captureDepth)&&cameraDepth>=0&&cameraDepth<=1&&captureDepth>=0&&captureDepth<=1)gate|=1u;
    if(positionCS.z==cameraDepth)gate|=2u;
    if(cameraDepth==captureDepth)gate|=4u;
    _HLGI_IdentityProbeRows[address+1u]=uint4(primitive+1u,asuint(positionCS.z),asuint(cameraDepth),asuint(captureDepth));
    _HLGI_IdentityProbeRows[address+2u]=uint4(gate,_HLGI_IdentityOwnerIndexPlusOne,pixel);
}
