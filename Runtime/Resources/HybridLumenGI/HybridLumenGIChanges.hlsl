#ifndef HLGI_CHANGES_INCLUDED
#define HLGI_CHANGES_INCLUDED
struct HLGIChangeRegion { float4 minimum, maximum, receiver; };
StructuredBuffer<HLGIChangeRegion> _HLGI_ChangeRegions;
int _HLGI_ChangeCount;
int _HLGI_HasLocalGeometryChange, _HLGI_HasDisjointPoseChange;
float _HLGI_GlobalReactive, _HLGI_GlobalGeometryChange;

float HLGIChangeDistanceSquared(float3 position, HLGIChangeRegion region)
{
    float3 outside=max(max(region.minimum.xyz-position,position-region.maximum.xyz),0);
    return dot(outside,outside);
}

// x: a changed surface crossed this point; y: transport may be affected by a nearby change.
float2 HLGIChangeAtReceiver(float3 position,uint provenReceiverGroup)
{
    if(_HLGI_GlobalGeometryChange>0.5) return float2(1,1);
    float2 result=float2(0,_HLGI_GlobalReactive);
    [loop] for(int i=0;i<_HLGI_ChangeCount;i++)
    {
        HLGIChangeRegion region=_HLGI_ChangeRegions[i];
        float distanceSquared=HLGIChangeDistanceSquared(position,region);
        // 0: lighting; 1: pose only; 2: topology/material/manual/unknown.
        // Identity/primitive/pose checks authorize only THIS receiver's pose
        // exemption. An unknown owner or another moving occluder remains hard.
        bool ownPose=provenReceiverGroup>0u && region.receiver.x==(float)provenReceiverGroup;
        bool reject=region.minimum.w>(ownPose?1.5:0.5);
        result.x=max(result.x,reject && distanceSquared<=1e-8 ? 1:0);
        result.y=max(result.y,distanceSquared<=region.maximum.w*region.maximum.w ? 1:0);
    }
    return result;
}
float2 HLGIChangeAt(float3 position) { return HLGIChangeAtReceiver(position,0u); }

#if defined(HLGI_CACHE_UPDATE_ITERATION)
bool HLGIRejectOldCacheInputAt(float3 position)
{
    if(_HLGI_GlobalGeometryChange>0.5) return true;
    if(_HLGI_HasLocalGeometryChange==0) return false;
    [loop] for(int i=0;i<_HLGI_ChangeCount;i++)
    {
        HLGIChangeRegion region=_HLGI_ChangeRegions[i];
        if(region.minimum.w<=0.5) continue;
        float distanceSquared=HLGIChangeDistanceSquared(position,region);
        if(distanceSquared<=1e-8) return true;
        if(_HLGI_HasDisjointPoseChange!=0 && region.receiver.y>=0.5 &&
            distanceSquared<=region.maximum.w*region.maximum.w) return true;
    }
    return false;
}

bool HLGIDisjointPoseInfluenceAt(float3 position)
{
    if(_HLGI_HasDisjointPoseChange==0) return false;
    [loop] for(int i=0;i<_HLGI_ChangeCount;i++)
    {
        HLGIChangeRegion region=_HLGI_ChangeRegions[i];
        if(region.receiver.y<0.5) continue;
        if(HLGIChangeDistanceSquared(position,region)<=region.maximum.w*region.maximum.w) return true;
    }
    return false;
}
#endif
#endif
