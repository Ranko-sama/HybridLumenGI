// Fixed 1x1 dependencies around the extracted actual temporal body.
// These adapters do not validate geometry decoding, motion, resource binding or
// real half-float textures. No temporal acceptance/blend formula is reproduced.
#define UNITY_REVERSED_Z 1
#define UNITY_UV_STARTS_AT_TOP 0
#include "HybridLumenGIRadianceValidity.hlsl"
#include "HybridLumenGIScreenSampling.hlsl"
#include "HybridLumenGIReceiverTemporal.hlsl"

struct TemporalReactionInput
{
    float4 history, moments, eventCurrent, recoveryCurrent, control;
    float4 reserved0, reserved1, reserved2, reserved3, reserved4, reserved5;
};
struct TemporalReactionOutput { float4 eventHistory,eventMoments,recoveryHistory,recoveryMoments; };
StructuredBuffer<TemporalReactionInput> _Inputs : register(t0);
RWStructuredBuffer<TemporalReactionOutput> _Outputs : register(u0);
cbuffer TestCounts : register(b0) { uint _Count; }

static float4 activeHistory,activeMoments,activeCurrent,adapterOutput,adapterMoments;
static float2 activeChange;
static float _HLGI_GlobalReactive;
static float4 _HLGI_Size=float4(1,1,1,1),_HLGI_FullSize=float4(1,1,1,1),_HLGI_JitterDelta=0;
static float4x4 _HLGI_InvVP,_HLGI_PreviousVP,_HLGI_PreviousInvVP,_HLGI_View;
static int _HLGI_HistoryValid=1,_HLGI_HasMotion=0,_HLGI_MaxHistory=32;
static float _HLGI_DepthThreshold=.015,_HLGI_NormalThreshold=.9,_HLGI_CurrentWeight=.08;
static uint _HLGI_IdentityObjectCount=1;
static uint3 _HLGI_IdentityCandidates[1];
static HLGIReceiverIdentityObject _HLGI_IdentityObjects[1];

struct InputTexture { float4 Load(int3 p) { return activeCurrent; } };
struct HistoryTexture { float4 Load(int3 p) { return activeHistory; } };
struct MomentsTexture { float4 Load(int3 p) { return activeMoments; } };
struct GeometryTexture { float4 Load(int3 p) { return float4(0,0,8390657,.5); } };
struct MaterialTexture { float4 Load(int3 p) { return float4(.5,.5,.5,1); } };
struct MotionTexture { float2 Load(int3 p) { return 0; } };
struct IdentityTexture { uint4 Load(int3 p) { return uint4(7,11,3,1); } };
static InputTexture _HLGI_Input;
static HistoryTexture _HLGI_History;
static MomentsTexture _HLGI_PreviousMoments;
static GeometryTexture _HLGI_Geometry,_HLGI_PreviousGeometry;
static MaterialTexture _HLGI_Material,_HLGI_PreviousMaterial;
static MotionTexture _HLGI_Motion;
static IdentityTexture _HLGI_IdentityCurrent,_HLGI_IdentityPrevious;

// Fixture: one stationary, reliable +Z plane at the exact center of an identity
// projection. Production temporal predicates still consume these fixed values.
bool HLGIDecodeScreenGeometry(float4 packed,out float3 ns,out float3 ng,out bool known)
{ ns=ng=float3(0,0,1);known=true;return true; }
float3 ComputeWorldSpacePosition(float2 uv,float depth,float4x4 inverseProjection)
{ return float3(uv*2-1,depth); }
float2 HLGIChangeAt(float3 position) { return activeChange; }
float2 HLGIChangeAtReceiver(float3 position,uint group) { return activeChange; }

#include "ActualTemporalBody.hlsl"

float4 RoundRadiance(float4 value)
{ return f16tof32(f32tof16(value)); }
void InvokeActualTemporal()
{
    adapterOutput=0;adapterMoments=0;
#if defined(HLGI_RECEIVER_IDENTITY)
    CSTemporalIdentity(uint3(0,0,0));
#else
    CSTemporal(uint3(0,0,0));
#endif
}
[numthreads(64,1,1)]
void CSTemporalReactionTest(uint3 id:SV_DispatchThreadID)
{
    if(id.x>=_Count)return;
    TemporalReactionInput input=_Inputs[id.x];
    float4x4 unit=float4x4(1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1);
    _HLGI_InvVP=_HLGI_PreviousVP=_HLGI_PreviousInvVP=_HLGI_View=unit;
    _HLGI_IdentityCandidates[0]=uint3(1,0,3);
    HLGIReceiverIdentityObject owner;
    owner.currentToPrevious=unit;owner.key=uint2(7,11);owner.flags=1;owner.reserved=1;
    _HLGI_IdentityObjects[0]=owner;
    activeHistory=RoundRadiance(input.history);activeMoments=input.moments;
    activeCurrent=RoundRadiance(input.eventCurrent);
    activeChange=float2(input.control.y,input.control.x);
    _HLGI_GlobalReactive=input.reserved0.x;
    _HLGI_HistoryValid=(int)input.control.z;
    _HLGI_MaxHistory=(int)input.control.w;
    InvokeActualTemporal();
    TemporalReactionOutput output;
    output.eventHistory=RoundRadiance(adapterOutput);output.eventMoments=adapterMoments;

    // The recovery call consumes the event result, including its stored length.
    activeHistory=output.eventHistory;activeMoments=output.eventMoments;
    activeCurrent=RoundRadiance(input.recoveryCurrent);activeChange=0;_HLGI_GlobalReactive=0;_HLGI_HistoryValid=1;
    InvokeActualTemporal();
    output.recoveryHistory=RoundRadiance(adapterOutput);output.recoveryMoments=adapterMoments;
    _Outputs[id.x]=output;
}
