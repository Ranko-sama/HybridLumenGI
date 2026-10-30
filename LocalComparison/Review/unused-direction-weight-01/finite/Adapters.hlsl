// Existing 176-byte input / 64-byte output WARP host. No texture or Unity adapter.
// Only the proposal StructuredBuffer declaration becomes a three-record local
// array populated from these fixed inputs. Extracted sampler/helper arithmetic
// is unchanged. Caller-local declaration hoisting and observation assignments
// expose the original two short sample/Matched/finite sequences after rejection.
#define PI 3.14159265358979323846
#define TWO_PI 6.28318530717958647693
struct Input
{
    float4 originArea,normalGuide,guide,control;
    float4 sphere1,data1,sphere2,data2,reserved0,reserved1,reserved2;
};
struct Output { float4 screen; uint4 screenState; float4 cache; uint4 cacheState; };
StructuredBuffer<Input> _Inputs : register(t0);
RWStructuredBuffer<Output> _Outputs : register(u0);
cbuffer Counts : register(b0) { uint _Count; }
static float _HLGI_GuideWeight;
static int _HLGI_AreaEmitterCount;
#include "ActualTransportHelpers.hlsl"
#include "ActualEmissiveSampling.hlsl"
#include "ActualMatchedWeight.hlsl"
struct AdapterCache { float4 guide; };
#include "ActualCallers.hlsl"
[numthreads(64,1,1)]
void CSUnusedDirectionWeight(uint3 id : SV_DispatchThreadID)
{
    if(id.x>=_Count)return;
    Input value=_Inputs[id.x];
    _HLGI_AreaEmitterCount=(int)value.originArea.w;
    _HLGI_GuideWeight=value.normalGuide.w;
    _HLGI_EmissiveWeight=value.control.x;
    _HLGI_EmissiveProposals[0].sphere=0;
    _HLGI_EmissiveProposals[0].data=float4(value.control.y,0,0,0);
    _HLGI_EmissiveProposals[1].sphere=value.sphere1;
    _HLGI_EmissiveProposals[1].data=value.data1;
    _HLGI_EmissiveProposals[2].sphere=value.sphere2;
    _HLGI_EmissiveProposals[2].data=value.data2;
    Output result;
    AdapterScreen(value.originArea.xyz,value.normalGuide.xyz,value.guide,(uint)value.control.z,result.screen,result.screenState);
    AdapterCacheUpdate(value.originArea.xyz,value.normalGuide.xyz,value.guide,(uint)value.control.z,result.cache,result.cacheState);
    _Outputs[id.x]=result;
}
