// Test-project-only recorder. No transport query or random draw is made here.
#ifndef GC_TRACE_WRITER
#define GC_TRACE_WRITER
#if defined(HLGI_GATHER_AUDIT)
#include "HybridLumenGIHit.hlsl"
struct GCRecord { uint4 meta; float4 a,b,c,d,e,f,g; };
RWStructuredBuffer<GCRecord> _GC_Records;
int _GC_Enabled, _GC_Logical, _GC_GiFrame;
static uint gcLane=0xffffffffu,gcCursor=1u,gcContext=0u,gcCall=0u,gcOverflow=0u;
void GCWrite(uint code,float4 a,float4 b,float4 c,float4 d,float4 e,float4 f,float4 g)
{
    if(gcLane==0xffffffffu)return;
    if(gcCursor>=256u){gcOverflow=1u;return;}
    GCRecord v;v.meta=uint4(code,gcCursor,gcContext,gcCall);v.a=a;v.b=b;v.c=c;v.d=d;v.e=e;v.f=f;v.g=g;
    _GC_Records[gcLane*256u+gcCursor]=v;gcCursor++;
}
void GCStart(uint2 p)
{
    gcLane=0xffffffffu;gcCursor=1u;gcContext=0u;gcCall=0u;gcOverflow=0u;
    if(_GC_Enabled==0)return;
    if(all(p==uint2(160,45)))gcLane=0u;
    else if(all(p==uint2(100,90)))gcLane=1u;
    else if(all(p==uint2(220,90)))gcLane=2u;
    else if(all(p==uint2(100,30)))gcLane=3u;
    if(gcLane!=0xffffffffu){GCRecord v=(GCRecord)0;v.meta=uint4(0,0,0,0);_GC_Records[gcLane*256u]=v;}
}
void GCFinish(float4 raw,uint reason)
{
    GCWrite(1u,raw,asfloat(uint4(reason,0,0,0)),0,0,0,0,0);
    if(gcLane==0xffffffffu)return;
    GCRecord v=(GCRecord)0;v.meta=uint4(0,gcCursor,1,gcOverflow);
    v.a=asfloat(uint4(_GC_Logical,_GC_GiFrame,gcLane,0x47434131u));_GC_Records[gcLane*256u]=v;
}
void GCHit(uint code,bool found,HLGIHit h)
{
    if(!found){GCWrite(code,asfloat(uint4(0,0,0,0)),0,0,0,0,0,0);return;}
    GCWrite(code,asfloat(uint4(1,h.ownerSlot,h.stableId,h.ownerRevision)),
        asfloat(uint4(h.geometryRevision,h.submesh,h.primitive,h.hardwareInstance)),
        asfloat(uint4(h.representation,h.flags,h.surfaceBinding.x,h.surfaceBinding.y)),
        float4(h.position,h.t),float4(h.rawNg,0),float4(h.shadingNormal,0),float4(h.uv,h.barycentrics));
}
#define GCV(code,a,b,c,d,e,f,g) GCWrite(code,a,b,c,d,e,f,g)
#define GCU(code,data) GCWrite(code,asfloat(data),0,0,0,0,0,0)
#define GCH(code,found,hit) GCHit(code,found,hit)
#define GCCTX(context) gcContext=context
#define GCCALL() gcCall++
#define GCSTART(pixel) GCStart(pixel)
#define GCFINISH(raw,reason) GCFinish(raw,reason)
#else
#define GCV(code,a,b,c,d,e,f,g)
#define GCU(code,data)
#define GCH(code,found,hit)
#define GCCTX(context)
#define GCCALL()
#define GCSTART(pixel)
#define GCFINISH(raw,reason)
#endif
#endif
