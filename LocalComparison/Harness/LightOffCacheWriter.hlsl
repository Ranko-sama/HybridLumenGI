// Test-project-only observation of four predeclared geometric patch rules.
// Include after the original cache structs/globals; never changes product buffers.
#ifndef HLGI_LIGHTOFF_WRITER
#define HLGI_LIGHTOFF_WRITER
#if defined(HLGI_LIGHTOFF_AUDIT)
struct LOCacheRecord
{
    HLGICacheEntry before,after;
    float4 prepared,surfacePoint,change,estimate,guideEstimate,direct,status,sourceParameters;
    uint4 meta,patch;
}; // 320 bytes: 18 float4 plus 2 uint4
RWStructuredBuffer<LOCacheRecord> _LO_Records;
int4 _LO_Entries;
int _LO_Logical,_LO_GiFrame;
static int loLane=-1;
static LOCacheRecord loRecord;
void LOBegin(uint entry)
{
    loLane=-1;loRecord=(LOCacheRecord)0;
    // CPU supplies unique identities/addresses; unused capacity is -1.
    for(int lane=0;lane<4;lane++)if(_LO_Entries[lane]==(int)entry){loLane=lane;break;}
    if(loLane<0)return;
    loRecord.before=_HLGI_CacheRead[entry];
    loRecord.meta=uint4(entry,_LO_Logical,_LO_GiFrame,0x4C4F3031u);loRecord.patch.w=(uint)_HLGI_FrameIndex;
    loRecord.sourceParameters=float4(_HLGI_LightCount,_HLGI_Epoch,_HLGI_BounceFeedback,_HLGI_CacheRays);
}
void LOPatch(HLGISurfaceSample surface,HLGICacheEntry prepared,float2 change,uint mask)
{
    if(loLane<0)return;
    loRecord.prepared=prepared.irradiance;loRecord.surfacePoint=float4(surface.position,surface.confidence);
    loRecord.change=float4(change,mask,mask!=0);loRecord.status.x=1;
    loRecord.patch=uint4(surface.cardIndex,surface.generation,surface.ownerSlot,_HLGI_FrameIndex);
}
void LODirect(float3 direct,bool known)
{
    if(loLane<0)return;
    if(known){loRecord.direct.xyz=max(loRecord.direct.xyz,abs(direct));loRecord.direct.w++;}
    else loRecord.status.w++;
}
void LOEstimate(float3 sum,float3 guide,float power,bool known)
{
    if(loLane<0)return;
    loRecord.estimate=float4(sum,known);loRecord.guideEstimate=float4(guide,power);
}
void LOEnd(HLGICacheEntry value)
{
    if(loLane<0)return;
    loRecord.after=value;loRecord.status.z=HLGIHasCacheMeasurement(value.irradiance,value.guide);
    _LO_Records[loLane]=loRecord;
}
#define LO_BEGIN(entry) LOBegin(entry)
#define LO_PATCH(surface,e,change,mask) LOPatch(surface,e,change,mask)
#define LO_DIRECT(value,known) LODirect(value,known)
#define LO_ESTIMATE(sum,guide,power,known) LOEstimate(sum,guide,power,known)
#define LO_COMMIT(value) if(loLane>=0)loRecord.status.y=value
#define LO_END(value) LOEnd(value)
#else
#define LO_BEGIN(entry)
#define LO_PATCH(surface,e,change,mask)
#define LO_DIRECT(value,known)
#define LO_ESTIMATE(sum,guide,power,known)
#define LO_COMMIT(value)
#define LO_END(value)
#endif
#endif
