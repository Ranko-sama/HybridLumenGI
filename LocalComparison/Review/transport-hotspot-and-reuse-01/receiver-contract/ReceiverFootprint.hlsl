#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
#include "HybridLumenGIRayFootprint.hlsl"
#include "HybridLumenGIScreenSampling.hlsl"
struct RayFootprintInput { column_major float4x4 worldToCard;float4 p,pX,pY,direction,normal,auxiliary,parameters;uint4 control; };
struct RayFootprintOutput { float4 values,comparison;uint4 predicates; };
StructuredBuffer<RayFootprintInput> _Inputs : register(t0);
RWStructuredBuffer<RayFootprintOutput> _Outputs : register(u0);
cbuffer TestCounts : register(b0) { uint _Count; }
// Substitutes only immutable texture loads; input order is x-1,x-2,x+1,x+2, then y.
struct DepthInput {
    float4 x,y;int2 center;
    float Load(int3 pixel) {
        int2 delta=pixel.xy-center;int distance=delta.x!=0?delta.x:delta.y;
        int index=distance<0?-distance-1:distance+1;
        return delta.x!=0?x[index]:y[index];
    }
};
static DepthInput _HLGI_Depth;
static float4 _HLGI_FullSize;
static float4x4 _HLGI_InvVP,_HLGI_View;
bool ValidDepth(float d)
{
#if UNITY_REVERSED_Z
    return d > 1e-6;
#else
    return d < 1-1e-6;
#endif
}

float3 WorldPosition(float2 uv,float depth,float4x4 invVP)
{
    // uv is already the exact center of the full-resolution depth sample.
    // GI/history callers use HLGIGiSampleUv; do not snap a second time here.
#if !UNITY_REVERSED_Z
    depth=lerp(UNITY_NEAR_CLIP_VALUE,1,depth);
#endif
    // ComputeWorldSpacePosition includes the UV-origin transform needed by Unity GPU matrices.
    return ComputeWorldSpacePosition(uv,depth,invVP);
}

bool HLGIScreenDepthDelta(int2 pixel,int2 axis,float depth,float3 position,out float3 derivative)
{
    derivative=0;
    int2 size=(int2)_HLGI_FullSize.xy;
    float bestError=1e20,bestDepth=0,bestPrediction=0;int bestSide=0;
    // The raw-depth slope selection follows URP's ReconstructNormalTap9 at
    // Graphics feb4de2d9a93a4ae10d287d3a6d7003d08ea3e53. Unlike that shading
    // helper, reject missing/ambiguous support instead of clamping edge samples.
    [unroll] for(int side=-1;side<=1;side+=2)
    {
        int2 nearPixel=pixel+axis*side,farPixel=pixel+axis*(side*2);
        if(any(nearPixel<0)||any(nearPixel>=size)||any(farPixel<0)||any(farPixel>=size)) continue;
        float nearDepth=_HLGI_Depth.Load(int3(nearPixel,0)),farDepth=_HLGI_Depth.Load(int3(farPixel,0));
        if(!isfinite(nearDepth)||!isfinite(farDepth)||nearDepth<0||nearDepth>1||farDepth<0||farDepth>1||
            !ValidDepth(nearDepth)||!ValidDepth(farDepth)) continue;
        float predictedDepth=2*nearDepth-farDepth;
        float error=abs(predictedDepth-depth);
        if(predictedDepth<0||predictedDepth>1||error>=bestError) continue;
        bestError=error;bestSide=side;bestDepth=nearDepth;bestPrediction=predictedDepth;
    }
    if(bestSide==0) return false;
    float2 uv=HLGIFullPixelCenterUv((uint2)pixel,(uint2)_HLGI_FullSize.xy);
    float3 predictedPosition=WorldPosition(uv,bestPrediction,_HLGI_InvVP);
    float tolerance=max(0.002,abs(mul(_HLGI_View,float4(position,1)).z)*1e-4);
    if(!all(isfinite(predictedPosition))||distance(predictedPosition,position)>tolerance) return false;
    float2 neighborUv=HLGIFullPixelCenterUv((uint2)(pixel+axis*bestSide),(uint2)_HLGI_FullSize.xy);
    derivative=(WorldPosition(neighborUv,bestDepth,_HLGI_InvVP)-position)*bestSide;
    float lengthSquared=dot(derivative,derivative);
    if(!all(isfinite(derivative))||!isfinite(lengthSquared)||lengthSquared<1e-16) return false;
    return true;
}

bool HLGITryScreenRayFootprint(float2 uv,float depth,float3 position,float3 direction,out HLGIRayFootprint footprint)
{
    footprint=(HLGIRayFootprint)0;
    if(!isfinite(depth)||depth<0||depth>1||!ValidDepth(depth)||!all(isfinite(position))||!all(isfinite(uv))) return false;
    int2 pixel=(int2)floor(uv*_HLGI_FullSize.xy);
    if(any(pixel<0)||any(pixel>=(int2)_HLGI_FullSize.xy)) return false;
    float3 dx,dy;
    if(!HLGIScreenDepthDelta(pixel,int2(1,0),depth,position,dx)||
        !HLGIScreenDepthDelta(pixel,int2(0,1),depth,position,dy)) return false;
    // Delta retains world units per full pixel. The GI grid selects a full-pixel
    // center; it does not represent a larger pixel footprint at lower GI scales.
    return HLGITryScreenFootprint(position,position+dx,position+dy,float2(1,1),float2(1,1),direction,footprint);
}
struct HLGIReceiverFootprintInput { float3 dx,dy;bool valid; };
HLGIReceiverFootprintInput HLGIPrepareReceiverFootprint(float2 uv,float depth,float3 position)
{
    HLGIReceiverFootprintInput input=(HLGIReceiverFootprintInput)0;
    if(!isfinite(depth)||depth<0||depth>1||!ValidDepth(depth)||!all(isfinite(position))||!all(isfinite(uv))) return input;
    int2 pixel=(int2)floor(uv*_HLGI_FullSize.xy);
    if(any(pixel<0)||any(pixel>=(int2)_HLGI_FullSize.xy)) return input;
    input.valid=HLGIScreenDepthDelta(pixel,int2(1,0),depth,position,input.dx)&&
        HLGIScreenDepthDelta(pixel,int2(0,1),depth,position,input.dy);
    return input;
}
bool HLGITryReceiverFootprint(HLGIReceiverFootprintInput input,float3 position,float3 direction,out HLGIRayFootprint footprint)
{
    footprint=(HLGIRayFootprint)0;
    if(!input.valid) return false;
    // Only the receiver neighborhood is invariant. Preserve the original
    // position addition/subtraction and project separately for every direction.
    return HLGITryScreenFootprint(position,position+input.dx,position+input.dy,float2(1,1),float2(1,1),direction,footprint);
}

[numthreads(64,1,1)]
void CSRayFootprintTest(uint3 id:SV_DispatchThreadID)
{
    if(id.x>=_Count || (id.x&1u)!=0u)return;
    RayFootprintInput i=_Inputs[id.x],j=_Inputs[id.x+1];
    _HLGI_InvVP=i.worldToCard;_HLGI_View=j.worldToCard;_HLGI_FullSize=i.auxiliary;
    _HLGI_Depth.x=i.pX;_HLGI_Depth.y=i.pY;_HLGI_Depth.center=(int2)i.control.zw;
    float2 uv=i.p.xy;float depth=i.p.z;
    float3 p=i.control.x!=0?i.normal.xyz:WorldPosition(uv,depth,_HLGI_InvVP);
#if CANDIDATE
    HLGIReceiverFootprintInput prepared=HLGIPrepareReceiverFootprint(uv,depth,p);
#endif
    [unroll]for(uint k=0;k<2;k++)
    {
        float3 direction=k==0?i.direction.xyz:j.direction.xyz;
        HLGIRayFootprint f;bool valid;
#if CANDIDATE
        valid=HLGITryReceiverFootprint(prepared,p,direction,f);
#else
        valid=HLGITryScreenRayFootprint(uv,depth,p,direction,f);
#endif
        RayFootprintOutput o=(RayFootprintOutput)0;
        o.values=float4(f.radius,f.slope,0,0);o.predicates=uint4(valid?1u:0u,f.valid,0,0);
        _Outputs[id.x+k]=o;
    }
}
