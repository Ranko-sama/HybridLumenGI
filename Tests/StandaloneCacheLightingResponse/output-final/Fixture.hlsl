#include "HybridLumenGIRadianceValidity.hlsl"
struct HLGICacheEntry { float4 irradiance,tag,anchor,normal,guide; };
struct Proxy { float4 identity; };
struct Surface { float3 position; uint generation; };
struct Input { float4 initial,guide,tag,steps[4],estimates,config,reserved0,reserved1; };
struct Output { float4 finalValue,guide,ages,red; };
StructuredBuffer<Input> Inputs : register(t0);
RWStructuredBuffer<Output> Outputs : register(u0);
cbuffer Counts : register(b0) { uint Count; }
static float2 activeChange;
static float _HLGI_GlobalReactive;
static float _HLGI_Epoch=3;
static int _HLGI_CacheRays=1;
float2 HLGIChangeAt(float3 position) { return activeChange; }
void Step(inout HLGICacheEntry e,Proxy p,Surface surface,float4 control,float measurement)
{
    _HLGI_GlobalReactive=control.x;
    activeChange=float2(control.z==1?1:0,control.y);
    float3 tag=float3(p.identity.xy,_HLGI_Epoch);
    float2 change=HLGIChangeAt(surface.position);
    if(any(e.tag.xyz!=tag) || e.tag.w!=(float)surface.generation || change.x>0.5 || !HLGIHasCacheMeasurement(e.irradiance,e.guide))
        e=(HLGICacheEntry)0;
    // Positive age below one keeps a valid old measurement available, but marks
    // it for replacement after a global light change. Persist across budget
    // waits and unknown updates; only a committed known estimate consumes it.
    if(_HLGI_GlobalReactive>0.5) e.irradiance.a=min(e.irradiance.a,0.5);
    // Nearby changes retain an estimate but shorten its history, even if this patch awaits budget.
    if(change.y>0.5) e.irradiance.a=min(e.irradiance.a,1);
    e.tag=float4(tag,surface.generation);

    if(control.w!=0)
    {
        bool estimateKnown=control.w==1;
        float3 sum=measurement*float3(1,.5,.25),guide=0,n=float3(0,1,0);
        float guidePower=0;
        HLGICommitCacheEstimate(estimateKnown,sum,guide,guidePower,_HLGI_CacheRays,n,e.irradiance,e.guide);
    }
}
[numthreads(64,1,1)]
void CSCacheLightingResponse(uint3 id:SV_DispatchThreadID)
{
    if(id.x>=Count)return;
    Input input=Inputs[id.x];
    HLGICacheEntry buffers[2]; buffers[0]=(HLGICacheEntry)0; buffers[1]=(HLGICacheEntry)0;
    buffers[0].irradiance=input.initial;buffers[0].guide=input.guide;buffers[0].tag=input.tag;
    Proxy p;p.identity=float4(1,2,0,1);
    Surface surface;surface.position=0;surface.generation=4;
    Output result=(Output)0;uint read=0;
    [loop] for(uint step=0;step<(uint)input.config.x;step++)
    {
        if(input.steps[step].z==2)p.identity.x+=1;
        HLGICacheEntry e=buffers[read];
        Step(e,p,surface,input.steps[step],input.estimates[step]);
        buffers[1-read]=e;read=1-read;
        result.ages[step]=e.irradiance.a;result.red[step]=e.irradiance.r;
    }
    result.finalValue=buffers[read].irradiance;result.guide=buffers[read].guide;
    Outputs[id.x]=result;
}
