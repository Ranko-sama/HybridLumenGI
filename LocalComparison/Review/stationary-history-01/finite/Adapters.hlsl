// Same fixed-texture adaptation as the existing temporal body WARP check.
// Actual projection, receiver motion, sampling, validity and temporal bodies run.
// Geometry decoding is a declared reliable +Z plane; no real textures or Unity.
#define UNITY_REVERSED_Z 1
#define UNITY_UV_STARTS_AT_TOP 0
#include "HybridLumenGIRadianceValidity.hlsl"
#include "HybridLumenGIScreenSampling.hlsl"
#include "HybridLumenGIReceiverTemporal.hlsl"
struct Input
{
    float4 history,moments,eventCurrent,recoveryCurrent,control;
    float4 reserved0,reserved1,reserved2,reserved3,reserved4,reserved5;
};
struct Output { float4 rawHistory,rawMoments,storedHistory,storedMoments; };
StructuredBuffer<Input> _Inputs : register(t0);
RWStructuredBuffer<Output> _Outputs : register(u0);
cbuffer Counts : register(b0) { uint _Count; }
static float4 activeHistory,activeMoments,activeCurrent,adapterOutput,adapterMoments;
static float2 activeChange,activeMotion;
static float previousDepth;
static float4 _HLGI_Size=float4(1,1,1,1),_HLGI_FullSize=float4(1,1,1,1),_HLGI_JitterDelta=0;
static float4x4 _HLGI_VP,_HLGI_InvVP,_HLGI_PreviousVP,_HLGI_PreviousInvVP,_HLGI_View;
static int _HLGI_HistoryValid=1,_HLGI_HasMotion=0,_HLGI_MaxHistory=32;
static float _HLGI_DepthThreshold=.015,_HLGI_NormalThreshold=.9,_HLGI_CurrentWeight=.08,_HLGI_GlobalReactive=0;
static uint _HLGI_IdentityObjectCount=1;
static uint3 _HLGI_IdentityCandidates[1];
static HLGIReceiverIdentityObject _HLGI_IdentityObjects[1];
struct InputTexture { float4 Load(int3 p) { return activeCurrent; } };
struct HistoryTexture { float4 Load(int3 p) { return activeHistory; } };
struct MomentsTexture { float4 Load(int3 p) { return activeMoments; } };
struct GeometryTexture { float4 Load(int3 p) { return float4(0,0,8390657,.5); } };
struct PreviousGeometryTexture { float4 Load(int3 p) { return float4(0,0,8390657,previousDepth); } };
struct MaterialTexture { float4 Load(int3 p) { return float4(.5,.5,.5,1); } };
struct MotionTexture { float2 Load(int3 p) { return activeMotion; } };
struct IdentityTexture { uint4 Load(int3 p) { return uint4(7,11,3,1); } };
static InputTexture _HLGI_Input;
static HistoryTexture _HLGI_History;
static MomentsTexture _HLGI_PreviousMoments;
static GeometryTexture _HLGI_Geometry;
static PreviousGeometryTexture _HLGI_PreviousGeometry;
static MaterialTexture _HLGI_Material,_HLGI_PreviousMaterial;
static MotionTexture _HLGI_Motion;
static IdentityTexture _HLGI_IdentityCurrent,_HLGI_IdentityPrevious;
bool HLGIDecodeScreenGeometry(float4 packed,out float3 ns,out float3 ng,out bool known)
{ ns=ng=float3(0,0,1);known=true;return true; }
float3 ComputeWorldSpacePosition(float2 uv,float depth,float4x4 inverseProjection)
{ float4 p=mul(inverseProjection,float4(uv*2-1,depth,1));return p.xyz/p.w; }
float2 HLGIChangeAt(float3 position) { return activeChange; }
float2 HLGIChangeAtReceiver(float3 position,uint group) { return activeChange; }
#include "ActualTemporalBody.hlsl"
float4 Stored(float4 value) { return f16tof32(f32tof16(value)); }
void Initialize(Input input)
{
    float4x4 unit=float4x4(1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1);
    _HLGI_VP=_HLGI_InvVP=_HLGI_PreviousVP=_HLGI_PreviousInvVP=_HLGI_View=unit;
    _HLGI_VP[0][3]=input.reserved0.z;
    _HLGI_InvVP[0][3]=-input.reserved0.z;
    _HLGI_View[0][3]=input.reserved0.z;
    _HLGI_IdentityCandidates[0]=uint3(1,0,3);
    HLGIReceiverIdentityObject owner;
    owner.currentToPrevious=unit;owner.key=uint2(7,11);owner.flags=1;owner.reserved=1;
    _HLGI_IdentityObjects[0]=owner;
    activeHistory=Stored(input.history);activeMoments=input.moments;activeCurrent=Stored(input.eventCurrent);
    activeChange=float2(input.control.y,input.control.x);
    _HLGI_GlobalReactive=input.control.z;_HLGI_HasMotion=(int)input.control.w;
    activeMotion=input.reserved0.xy;previousDepth=input.reserved0.w;
    _HLGI_HistoryValid=(int)input.reserved1.x;_HLGI_MaxHistory=(int)input.reserved1.y;_HLGI_CurrentWeight=input.reserved1.z;
}
Output Invoke()
{
    adapterOutput=0;adapterMoments=0;
#if defined(HLGI_RECEIVER_IDENTITY)
    CSTemporalIdentity(uint3(0,0,0));
#else
    CSTemporal(uint3(0,0,0));
#endif
    Output output;
    output.rawHistory=adapterOutput;output.rawMoments=adapterMoments;
    output.storedHistory=Stored(adapterOutput);output.storedMoments=adapterMoments;
    activeHistory=output.storedHistory;activeMoments=output.storedMoments;
    return output;
}
[numthreads(64,1,1)]
void CSStationaryHistory(uint3 id:SV_DispatchThreadID)
{
    if(id.x>=_Count || (id.x>0 && id.x<32))return;
    Initialize(_Inputs[id.x]);
    if(id.x==0)
    {
        // One thread carries the actual stored output/moments into each next
        // invocation. Thirty-two rows retain the entire one-case trajectory.
        [loop] for(uint step=0;step<32;step++) _Outputs[step]=Invoke();
    }
    else _Outputs[id.x]=Invoke();
}
