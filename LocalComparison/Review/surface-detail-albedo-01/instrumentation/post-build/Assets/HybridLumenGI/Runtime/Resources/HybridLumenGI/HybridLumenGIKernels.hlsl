#include "HybridLumenGITransport.hlsl"
#include "HybridLumenGIScreenGeometry.hlsl"
#include "HybridLumenGIScreenSampling.hlsl"
#include "HybridLumenGIScreenMaterial.hlsl"
#if defined(HLGI_RECEIVER_IDENTITY)
#include "HybridLumenGIReceiverTemporal.hlsl"
Texture2D<uint4> _HLGI_IdentityCurrent, _HLGI_IdentityPrevious;
StructuredBuffer<uint3> _HLGI_IdentityCandidates;
StructuredBuffer<HLGIReceiverIdentityObject> _HLGI_IdentityObjects;
uint _HLGI_IdentityObjectCount;
#endif
Texture2D<float> _HLGI_Depth;
Texture2D<float> _HLGI_CaptureDepth;
Texture2D<float4> _HLGI_Normals, _HLGI_Diffuse, _HLGI_Emission;
Texture2D<uint2> _HLGI_ReceiverPolicy;
Texture2D<float2> _HLGI_Motion;
Texture2D<float4> _HLGI_History, _HLGI_PreviousGeometry, _HLGI_PreviousMaterial, _HLGI_PreviousMoments;
Texture2D<float4> _HLGI_Input, _HLGI_Geometry, _HLGI_Material, _HLGI_Moments;
RWTexture2D<float4> _HLGI_Output, _HLGI_GeometryOut, _HLGI_MaterialOut, _HLGI_MomentsOut;
float4 _HLGI_Size, _HLGI_FullSize;
float4x4 _HLGI_VP, _HLGI_InvVP, _HLGI_PreviousVP, _HLGI_PreviousInvVP, _HLGI_View;
float4 _HLGI_JitterDelta;
float4 _HLGI_MaterialView; // point w=1 or constant direction toward viewer w=0
int _HLGI_Rays, _HLGI_ScreenSteps, _HLGI_HistoryValid, _HLGI_HasMotion, _HLGI_NormalsOct;
int _HLGI_NativeComposition;
int _HLGI_FilterStep, _HLGI_MaxHistory;
float _HLGI_Thickness, _HLGI_DepthThreshold, _HLGI_NormalThreshold, _HLGI_CurrentWeight, _HLGI_RadianceClamp;

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
float2 ProjectUV(float3 p,float4x4 vp,out float w)
{
    float4 clip=mul(vp,float4(p,1)); w=clip.w;
    float2 uv=clip.xy/max(clip.w,1e-7)*0.5+0.5;
#if UNITY_UV_STARTS_AT_TOP
    uv.y=1-uv.y;
#endif
    return uv;
}
float3 NormalAt(float2 uv)
{
    float3 n=_HLGI_Normals.SampleLevel(sampler_PointClamp,uv,0).xyz;
    if(_HLGI_NormalsOct!=0) n=UnpackNormalOctQuadEncode(Unpack888ToFloat2(n)*2-1);
    return dot(n,n)>0.01 ? normalize(n) : float3(0,1,0);
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
bool HLGIScreenDepthDerivative(int2 pixel,int2 axis,float depth,float3 position,out float3 derivative)
{
    if(!HLGIScreenDepthDelta(pixel,axis,depth,position,derivative)) return false;
    derivative*=rsqrt(dot(derivative,derivative));return true;
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
bool HLGITryScreenGeometricNormal(float2 uv,float depth,float3 position,out float3 geometricNormal)
{
    geometricNormal=0;
    if(!isfinite(depth)||depth<0||depth>1||!ValidDepth(depth)||!all(isfinite(position))) return false;
    int2 pixel=(int2)floor(uv*_HLGI_FullSize.xy);
    if(any(pixel<0)||any(pixel>=(int2)_HLGI_FullSize.xy)) return false;
    float3 horizontal,vertical;
    if(!HLGIScreenDepthDerivative(pixel,int2(1,0),depth,position,horizontal)||
        !HLGIScreenDepthDerivative(pixel,int2(0,1),depth,position,vertical)) return false;
    float3 crossNormal=cross(horizontal,vertical);
    float lengthSquared=dot(crossNormal,crossNormal);
    if(!all(isfinite(crossNormal))||!isfinite(lengthSquared)||lengthSquared<1e-6) return false;
    geometricNormal=crossNormal*rsqrt(lengthSquared);
    // An inverse-projected near point supplies the camera-facing orientation for
    // perspective/orthographic matrices and either UV origin. Ns is never used
    // to infer geometric orientation. This remains a depth estimate, not mesh Ng.
#if UNITY_REVERSED_Z
    const float nearDepth=1;
#else
    const float nearDepth=0;
#endif
    float3 towardCamera=WorldPosition(HLGIFullPixelCenterUv((uint2)pixel,(uint2)_HLGI_FullSize.xy),nearDepth,_HLGI_InvVP)-position;
    float facing=dot(geometricNormal,towardCamera);
    if(!all(isfinite(towardCamera))||!isfinite(facing)||abs(facing)<1e-8) { geometricNormal=0;return false; }
    if(facing<0) geometricNormal=-geometricNormal;
    return true;
}
bool HLGITryScreenWorldMatch(float2 uv,float depth,float3 position,float3 estimatedGeometricNormal,out HLGIHit hit)
{
    float probeDistance=max(_HLGI_RayBias*2,0.03);
    HLGIRayFootprint footprint;
    HLGITryScreenRayFootprint(uv,depth,position,-estimatedGeometricNormal,footprint);
    if(!TraceSceneVisibilityHit(position+estimatedGeometricNormal*probeDistance,-estimatedGeometricNormal,probeDistance*2,
        footprint,_HLGI_MaterialView,hit)) return false;
    if(!HLGIHitMaterialKnown(hit) || !HLGIHitHas(hit.flags,HLGI_HIT_GEOMETRIC_NORMAL) ||
        abs(hit.t-probeDistance)>max(0.002,min(_HLGI_RayBias,0.03)) ||
        abs(dot(hit.rawNg,estimatedGeometricNormal))<0.85) return false;
    // The screen estimate faces the camera. A CullOff/CullFront triangle's raw
    // source winding may face away; preserve it in hit for exact card lookup.
    return true;
}
float LuminanceGI(float3 c) { return dot(c,float3(0.2126,0.7152,0.0722)); }
float3 LimitRadiance(float3 c)
{
    c=max(c,0);
    // Optional biased firefly clamp; 0 means unbounded transport.
    return _HLGI_RadianceClamp>0 ? c*min(1,_HLGI_RadianceClamp/max(LuminanceGI(c),1e-5)) : c;
}

bool ScreenPoint(float3 origin,float3 dir,float t,out float2 uv,out float delta,out float3 p)
{
    float3 q=origin+dir*t; float w;
    uv=ProjectUV(q,_HLGI_VP,w); delta=-1e10; p=0;
    if(w<=0 || any(uv<=0) || any(uv>=1)) return false;
    uint width,height; _HLGI_Depth.GetDimensions(width,height);
    uint2 fullPixel=HLGIFullPixelForUv(uv,uint2(width,height));
    uv=HLGIFullPixelCenterUv(fullPixel,uint2(width,height));
    float raw=_HLGI_Depth.Load(int3(fullPixel,0));
    if(!ValidDepth(raw)) return true;
    p=WorldPosition(uv,raw,_HLGI_InvVP);
    delta=mul(_HLGI_View,float4(p-q,0)).z;
    return true;
}
// Read-only material capture probe; no additional transport queries.
RWStructuredBuffer<float4> _SDA_Records;
float4 _SDA_Centers[2];int _SDA_Enabled;
bool TraceScreen(float3 origin,float3 dir,float maxT,out float3 radiance,out float distanceHit,out bool known)
{
    radiance=0; distanceHit=maxT;known=true;
    float lastT=_HLGI_RayBias*2, lastDelta=-1e10;
    [loop] for(int i=0;i<_HLGI_ScreenSteps;i++)
    {
        float u=(i+1.0)/max(_HLGI_ScreenSteps,1);
        float t=lerp(_HLGI_RayBias*2,maxT,u*u);
        float2 uv; float delta; float3 p;
        if(!ScreenPoint(origin,dir,t,uv,delta,p)) return false;
        if(delta>=0 && lastDelta<0)
        {
            float lo=lastT,hi=t;
            [unroll] for(int refine=0;refine<5;refine++)
            {
                float mid=(lo+hi)*0.5; float2 mu; float md; float3 mp;
                if(ScreenPoint(origin,dir,mid,mu,md,mp) && md>=0) hi=mid; else lo=mid;
            }
            if(ScreenPoint(origin,dir,hi,uv,delta,p) && delta>=0 && delta<_HLGI_Thickness &&
                length(origin+dir*hi-p)<_HLGI_Thickness*2)
            {
                float3 n=NormalAt(uv);
                float4 emission=_HLGI_Emission.SampleLevel(sampler_PointClamp,uv,0);
                float captureRaw=_HLGI_CaptureDepth.SampleLevel(sampler_PointClamp,uv,0);
                bool captured=ValidDepth(captureRaw) && distance(p,WorldPosition(uv,captureRaw,_HLGI_InvVP))<0.03;
                float surfaceT=dot(p-origin,dir);
                if(HLGIHasScreenMaterial(emission.a) && captured && surfaceT>0 && surfaceT<=maxT)
                {
                    float raw=_HLGI_Depth.SampleLevel(sampler_PointClamp,uv,0);
                    float3 geometricNormal;
                    bool hasGeometry=HLGITryScreenGeometricNormal(uv,raw,p,geometricNormal);
                    // No reliable depth neighborhood: retain the existing single-bounce
                    // shading fallback, but never use Ns to locate a world-cache layer.
                    float3 biasNormal=hasGeometry?geometricNormal:n;
                    if(dot(biasNormal,-dir)<=0.05) { lastT=t;lastDelta=delta;continue; }
                    HLGIHit match;
                    bool worldMatch=false;
                    if(hasGeometry) worldMatch=HLGITryScreenWorldMatch(uv,raw,p,geometricNormal,match);
                    if(worldMatch) biasNormal=match.rawNg;
                    float4 diffuse=_HLGI_Diffuse.SampleLevel(sampler_PointClamp,uv,0);
                    // No lit camera color or screen-history feedback enters the transport equation.
                    uint policyWidth,policyHeight;_HLGI_ReceiverPolicy.GetDimensions(policyWidth,policyHeight);
                    uint2 policyPixel=min((uint2)(uv*float2(policyWidth,policyHeight)),uint2(policyWidth-1,policyHeight-1));
                    uint2 receiverLayers=_HLGI_ReceiverPolicy.Load(int3(policyPixel,0));
                    // Captured material represents this camera pixel. Express
                    // its spatial support perpendicular to the camera ray before
                    // projecting it onto each light connection in DirectIrradiance.
                    float3 cameraRay=p*_HLGI_MaterialView.w-_HLGI_MaterialView.xyz;
                    HLGIRayFootprint screenFootprint;
                    HLGITryScreenRayFootprint(uv,raw,p,cameraRay,screenFootprint);
                    bool directKnown;
                    float3 direct=DirectIrradiance(p,n,biasNormal,receiverLayers,HLGIScreenReceivesShadows(emission.a),cameraRay,screenFootprint,directKnown);
                    // A captured surface with unknown incident light is still a
                    // hit. Never continue behind it or reinterpret it as a miss.
                    distanceHit=surfaceT;
                    if(!directKnown) { known=false;return true; }
                    radiance=emission.rgb+diffuse.rgb*direct;
                    // Only registered spatially matching surfaces can contribute higher-order cache light.
                    if(worldMatch)
                    {
                        float materialAO=HLGIScreenMaterialAO(emission.a,_HLGI_NativeComposition!=0,diffuse.a);
                        radiance+=diffuse.rgb*materialAO*_HLGI_BounceFeedback*CachedIrradiance(match,n);
                    }
                    known=all(isfinite(radiance));return true;
                }
            }
        }
        lastT=t; lastDelta=delta;
    }
    return false;
}
[numthreads(8,8,1)]
void CSTrace(uint3 id:SV_DispatchThreadID)
{
    if(any(id.xy>=(uint2)_HLGI_Size.xy)) return;
    uint2 fullPixel=HLGIFullPixelForGiPixel(id.xy,(uint2)_HLGI_Size.xy,(uint2)_HLGI_FullSize.xy);
    float2 uv=HLGIFullPixelCenterUv(fullPixel,(uint2)_HLGI_FullSize.xy);
    float depth=_HLGI_Depth.Load(int3(fullPixel,0));
    float4 material=_HLGI_Diffuse.Load(int3(fullPixel,0));
    float capturedDepth=_HLGI_CaptureDepth.Load(int3(fullPixel,0));
    bool sameSurface=ValidDepth(capturedDepth) && distance(WorldPosition(uv,depth,_HLGI_InvVP),WorldPosition(uv,capturedDepth,_HLGI_InvVP))<0.03;
    if(_SDA_Enabled!=0)
    {
        [unroll] for(uint lane=0;lane<2;lane++)
        {
            float clipW;float2 probeUV=ProjectUV(_SDA_Centers[lane].xyz,_HLGI_VP,clipW);
            if(all(id.xy==HLGIClosestGiPixel(probeUV,(uint2)_HLGI_Size.xy,(uint2)_HLGI_FullSize.xy)))
            {
                float4 capturedDiffuse=_HLGI_Diffuse.Load(int3(fullPixel,0));
                float4 capturedEmission=_HLGI_Emission.Load(int3(fullPixel,0));
                _SDA_Records[lane*4]=float4(12345,sameSurface?1:0,_HLGI_NativeComposition,lane);
                _SDA_Records[lane*4+1]=capturedDiffuse;
                _SDA_Records[lane*4+2]=capturedEmission;
                _SDA_Records[lane*4+3]=float4(fullPixel,HLGIScreenMaterialAO(capturedEmission.a,_HLGI_NativeComposition!=0,capturedDiffuse.a),HLGIHasScreenMaterial(capturedEmission.a)?1:0);
            }
        }
    }
    if(!ValidDepth(depth) || !sameSurface || !HLGIHasScreenMaterial(_HLGI_Emission.Load(int3(fullPixel,0)).a))
    {
        _HLGI_Output[id.xy]=0; _HLGI_GeometryOut[id.xy]=0; _HLGI_MaterialOut[id.xy]=0; return;
    }
    float3 p=WorldPosition(uv,depth,_HLGI_InvVP), n=NormalAt(uv);
    _HLGI_MaterialOut[id.xy]=material;
    uint rng=HLGIHash((id.x+id.y*(uint)_HLGI_Size.x+HLGIHash((uint)_HLGI_FrameIndex+1))^0x63D83595u);
    HLGICacheEntry receiverCache=(HLGICacheEntry)0;
    float3 geometricNormal;
    bool hasGeometry=HLGITryScreenGeometricNormal(uv,depth,p,geometricNormal);
    if(hasGeometry && _HLGI_GuideWeight>0)
    {
        HLGIHit receiverHit;
        if(HLGITryScreenWorldMatch(uv,depth,p,geometricNormal,receiverHit))
        {
            geometricNormal=HLGIOffsetNormal(receiverHit.rawNg,geometricNormal);
            HLGICachedSample(receiverHit,n,receiverCache);
        }
    }
    _HLGI_GeometryOut[id.xy]=HLGIPackScreenGeometry(n,geometricNormal,hasGeometry,depth);
    float3 sum=0; float confidence=0;bool estimateKnown=true;
    [loop] for(int r=0;r<_HLGI_Rays;r++)
    {
        float sampleWeight;
        // History Ng faces the camera, while stock Lit Ns retains its authored
        // direction on a visible back face. Bias toward the sampled hemisphere
        // without changing either normal; otherwise every ray hits its own plane.
        float3 origin=p+(hasGeometry?HLGIOffsetNormal(geometricNormal,n):n)*_HLGI_RayBias;
        float3 dir=HLGISampleTransportDirection(origin,n,receiverCache.guide,rng,sampleWeight);
        if(!HLGIAreaMatchedDirectionWeight(origin,n,receiverCache.guide,dir,sampleWeight)) { estimateKnown=false;break; }
        if(!all(isfinite(dir))) { estimateKnown=false;break; }
        HLGIHit hit;
        HLGIRayFootprint footprint;
        HLGITryScreenRayFootprint(uv,depth,p,dir,footprint);
        bool worldHit=sampleWeight>0 && TraceSceneHit(origin,dir,_HLGI_MaxDistance,footprint,float4(p,1),hit);
        float3 incoming=0; float screenT;bool screenKnown;
        // World occluders bound the screen ray, so a visible hit behind an off-screen wall cannot win.
        float sampleConfidence=1;
        if(sampleWeight>0 && TraceScreen(origin,dir,worldHit?hit.t:_HLGI_MaxDistance,incoming,screenT,screenKnown) && (!worldHit || screenT<=hit.t))
            sampleConfidence=screenKnown?1:0;
        else if(worldHit)
        {
            HLGIRayFootprint hitFootprint;HLGIAdvanceRayFootprint(footprint,hit.t,hitFootprint);
            float emissionWeight;
            if(!HLGIAreaDirectionEmissionWeight(origin,n,receiverCache.guide,dir,hit,emissionWeight)) { estimateKnown=false;break; }
            float materialConfidence;incoming=ProxyRadiance(hit,dir,hitFootprint,emissionWeight,materialConfidence);sampleConfidence=0.65*materialConfidence;
        }
        else if(sampleWeight>0) { incoming=_HLGI_Environment.rgb;sampleConfidence=0.25; }
        // Check before a clamp can conceal a NaN/infinity. Reject the complete
        // estimate, without dividing by a smaller known-sample population.
        if(!HLGIHasRadianceMeasurement(float4(incoming,sampleConfidence)) ||
            !HLGIAccumulateRadianceSample(_HLGI_AreaEmitterCount>0?incoming:LimitRadiance(incoming),sampleConfidence,sampleWeight,sum))
        { estimateKnown=false;break; }
        // One independent area draw is required even when the direction draw
        // lies below the receiver hemisphere. Do not conditionally omit it.
        HLGIAreaSample lightSample;
        uint lightStatus=HLGI_AREA_NONE;
        if(_HLGI_AreaEmitterCount>0)lightStatus=HLGISampleAreaEmitter(origin,float3(Random(rng),Random(rng),Random(rng)),lightSample);
        if(lightStatus==HLGI_AREA_UNKNOWN) { estimateKnown=false;break; }
        if(lightStatus==HLGI_AREA_SAMPLE && dot(n,lightSample.direction)>0 && lightSample.distance<_HLGI_MaxDistance)
        {
            HLGITryScreenRayFootprint(uv,depth,p,lightSample.direction,footprint);
            float3 lightValue;bool lightWorldHit;HLGIHit lightHit;
            bool lightKnown=HLGIAreaLightContribution(origin,n,receiverCache.guide,lightSample,footprint,float4(p,1),lightValue,lightWorldHit,lightHit);
            float3 screenValue;float lightScreenT;bool lightScreenKnown;
            if(TraceScreen(origin,lightSample.direction,lightWorldHit?lightHit.t:lightSample.distance,
                screenValue,lightScreenT,lightScreenKnown) && (!lightWorldHit || lightScreenT<=lightHit.t))
            {
                // The matching direction estimator uses the screen endpoint at
                // weight one. Suppress area NEE on exactly that same support.
                lightValue=0;lightKnown=lightScreenKnown;
            }
            if(!lightKnown || !HLGIAccumulateRadianceSample(lightValue,1,1,sum)) { estimateKnown=false;break; }
        }
        confidence+=sampleConfidence;
    }
    _HLGI_Output[id.xy]=estimateKnown?float4(sum/max(_HLGI_Rays,1),confidence/max(_HLGI_Rays,1)):float4(0,0,0,-1);
}
// The nearest sample and every prospective reconstruction tap use the same
// existing receiver gates. Encoded geometry/material/identity are never blended.
bool HLGITemporalTapMatches(int2 pixel,float3 expectedP,float3 expectedNs,float3 expectedNg,float3 rho,float tolerance)
{
    float4 oldGeometry=_HLGI_PreviousGeometry.Load(int3(pixel,0));
    float3 oldRho=_HLGI_PreviousMaterial.Load(int3(pixel,0)).rgb;
    float3 oldShadingNormal,oldGeometricNormal;bool oldHasGeometry;
    bool oldReceiver=HLGIDecodeScreenGeometry(oldGeometry,oldShadingNormal,oldGeometricNormal,oldHasGeometry);
    float3 oldP=WorldPosition(HLGIGiSampleUv((uint2)pixel,(uint2)_HLGI_Size.xy,(uint2)_HLGI_FullSize.xy),oldGeometry.w,_HLGI_PreviousInvVP);
    float geometricAgreement=dot(expectedNg,oldGeometricNormal);
#if defined(HLGI_RECEIVER_IDENTITY)
    // Screen Ng faces its own camera; its sign may differ between rigid poses.
    geometricAgreement=abs(geometricAgreement);
#endif
    return oldReceiver && oldHasGeometry && dot(expectedNs,oldShadingNormal)>_HLGI_NormalThreshold &&
        geometricAgreement>0.85 &&
        abs(dot(expectedP-oldP,expectedNg))<tolerance && abs(dot(expectedP-oldP,oldGeometricNormal))<tolerance &&
        distance(expectedP,oldP)<tolerance && max(abs(rho.x-oldRho.x),max(abs(rho.y-oldRho.y),abs(rho.z-oldRho.z)))<0.1;
}
bool HLGITrySubpixelHistory(float2 uv,int2 nearestPixel,uint4 identity,
    float3 expectedP,float3 expectedNs,float3 expectedNg,float3 rho,float tolerance,
    float4 nearestHistory,float4 nearestMoments,out float4 history,out float4 moments)
{
    history=nearestHistory;moments=nearestMoments;
    uint2 lower,upper;float2 fraction;
    HLGIGiBilinearFootprint(uv,(uint2)_HLGI_Size.xy,(uint2)_HLGI_FullSize.xy,lower,upper,fraction);
    float4 sumHistory=0;float3 sumMoments=0;float weightSum=0,minimumLength=0;
    [unroll] for(int y=0;y<2;y++) [unroll] for(int x=0;x<2;x++)
    {
        float weight=(x==0?1-fraction.x:fraction.x)*(y==0?1-fraction.y:fraction.y);
        // The footprint gives zero weight to duplicate upper edge indices.
        if(weight<=0) continue;
        int2 q=int2(x==0?lower.x:upper.x,y==0?lower.y:upper.y);
        float4 h=nearestHistory,m=nearestMoments;
        if(any(q!=nearestPixel))
        {
#if defined(HLGI_RECEIVER_IDENTITY)
            if(!HLGISameReceiverPrimitive(identity,_HLGI_IdentityPrevious.Load(int3(q,0)))) return false;
#endif
            if(!HLGITemporalTapMatches(q,expectedP,expectedNs,expectedNg,rho,tolerance)) return false;
            h=_HLGI_History.Load(int3(q,0));m=_HLGI_PreviousMoments.Load(int3(q,0));
            if(!HLGIHasTemporalHistory(h,m)) return false;
        }
        minimumLength=weightSum==0?m.z:min(minimumLength,m.z);
        sumHistory+=weight*h;sumMoments+=weight*float3(m.xy,m.w);weightSum+=weight;
    }
    if(!isfinite(weightSum) || weightSum<=0) return false;
    float4 reconstructed=sumHistory/weightSum;
    float3 reconstructedMoments=sumMoments/weightSum;
    float4 nextMoments=float4(reconstructedMoments.xy,minimumLength,reconstructedMoments.z);
    if(!HLGIHasTemporalHistory(reconstructed,nextMoments)) return false;
    history=reconstructed;moments=nextMoments;return true;
}
[numthreads(8,8,1)]
#if defined(HLGI_RECEIVER_IDENTITY)
void CSTemporalIdentity(uint3 id:SV_DispatchThreadID)
#else
void CSTemporal(uint3 id:SV_DispatchThreadID)
#endif
{
    if(any(id.xy>=(uint2)_HLGI_Size.xy)) return;
    int2 pixel=id.xy;
    uint2 fullPixel=HLGIFullPixelForGiPixel(id.xy,(uint2)_HLGI_Size.xy,(uint2)_HLGI_FullSize.xy);
    float2 uv=HLGIFullPixelCenterUv(fullPixel,(uint2)_HLGI_FullSize.xy);
    float4 current=_HLGI_Input.Load(int3(pixel,0));
    float4 geometry=_HLGI_Geometry.Load(int3(pixel,0));
    float3 rho=_HLGI_Material.Load(int3(pixel,0)).rgb;
    float3 shadingNormal,geometricNormal;bool hasGeometry;
    if(!HLGIDecodeScreenGeometry(geometry,shadingNormal,geometricNormal,hasGeometry))
    { _HLGI_Output[pixel]=0; _HLGI_MomentsOut[pixel]=0; return; }
    bool currentKnown=HLGIHasRadianceMeasurement(current);
    float lum=currentKnown?LuminanceGI(current.rgb):0;
    currentKnown=currentKnown && isfinite(lum) && isfinite(lum*lum) && all(isfinite(current.rgb*current.rgb));
    // A valid receiver with unknown Ng still owns a useful single-frame GI
    // estimate. Preserve it, but do not blend across pixels or engine frames.
    if(!hasGeometry)
    { _HLGI_Output[pixel]=currentKnown?current:0; _HLGI_MomentsOut[pixel]=currentKnown?float4(lum,lum*lum,1,0):0; return; }
    float3 p=WorldPosition(uv,geometry.w,_HLGI_InvVP); float w;
    float3 expectedP=p,expectedNs=shadingNormal,expectedNg=geometricNormal;
    bool identityValid=true;
#if defined(HLGI_RECEIVER_IDENTITY)
    uint4 identity=_HLGI_IdentityCurrent.Load(int3(pixel,0));
    uint receiverGroup=0u;
    uint3 candidate=_HLGI_IdentityCandidates[fullPixel.y*(uint)_HLGI_FullSize.x+fullPixel.x];
    identityValid=false;
    // Explicit bounds guard before reading a transient object row.
    if(candidate.x>0u && candidate.x<=_HLGI_IdentityObjectCount)
    {
        HLGIReceiverIdentityObject row=_HLGI_IdentityObjects[candidate.x-1u];
        identityValid=HLGITryReceiverMotion(identity,candidate,row,
            p,shadingNormal,geometricNormal,expectedP,expectedNs,expectedNg);
        if(identityValid) receiverGroup=row.reserved;
    }
#endif
    float2 prevUV=ProjectUV(expectedP,_HLGI_PreviousVP,w);
    if(_HLGI_HasMotion!=0)
    {
        // URP's non-jittered current-minus-previous UV velocity, sampled at the
        // same full-resolution point as depth. Graphics feb4de2d9a93a4ae10d287d3a6d7003d08ea3e53:
        // ObjectMotionVectors.hlsl / MotionVectorsCommon.hlsl. JitterDelta is
        // previousJitter-currentJitter in GPU UV space; do not apply it twice.
        float2 motionUV=uv-_HLGI_Motion.Load(int3(fullPixel,0))+_HLGI_JitterDelta.xy;
#if defined(HLGI_RECEIVER_IDENTITY)
        // A missing/forced-zero object velocity must not override the verified
        // rigid pose. Accept motion only when it agrees within one full texel.
        if(all(isfinite(motionUV)) && all(abs(motionUV-prevUV)*_HLGI_FullSize.xy<=1)) prevUV=motionUV;
#else
        prevUV=motionUV;
#endif
    }
    bool valid=_HLGI_HistoryValid!=0 && identityValid && isfinite(w) && w>0 && all(isfinite(prevUV)) && all(prevUV>0) && all(prevUV<1);
    // Never cast a nonfinite UV to an integer, including on an invalid history.
    int2 previousPixel=0;
    if(valid) previousPixel=(int2)HLGIClosestGiPixel(prevUV,(uint2)_HLGI_Size.xy,(uint2)_HLGI_FullSize.xy);
#if defined(HLGI_RECEIVER_IDENTITY)
    valid=valid && HLGISameReceiverPrimitive(identity,_HLGI_IdentityPrevious.Load(int3(previousPixel,0)));
#endif
    // Previous raw depth belongs to this GI texel's stored full-resolution
    // sample. Frame-context validation must reject a changed full/low size.
    float tolerance=_HLGI_DepthThreshold*max(1,abs(mul(_HLGI_View,float4(p,1)).z));
    valid=valid && HLGITemporalTapMatches(previousPixel,expectedP,expectedNs,expectedNg,rho,tolerance);
#if defined(HLGI_RECEIVER_IDENTITY)
    float2 change=HLGIChangeAtReceiver(p,valid?receiverGroup:0u);
#else
    float2 change=HLGIChangeAt(p);
#endif
    valid=valid && change.x<0.5;
    float4 history=_HLGI_History.Load(int3(previousPixel,0));
    float4 moments=_HLGI_PreviousMoments.Load(int3(previousPixel,0));
    valid=valid && HLGIHasTemporalHistory(history,moments);
    if(!currentKnown)
    {
        float4 retained,retainedMoments;
        HLGIResolveUnknownHistory(valid,history,moments,retained,retainedMoments);
        _HLGI_Output[pixel]=retained;_HLGI_MomentsOut[pixel]=retainedMoments;return;
    }
    // Reconstruction may improve an already accepted known measurement only.
    // Any incomplete support retains the exact original nearest history pair.
    if(valid)
    {
        uint4 expectedIdentity=0;
#if defined(HLGI_RECEIVER_IDENTITY)
        expectedIdentity=identity;
#endif
        float4 reconstructed,reconstructedMoments;
        if(HLGITrySubpixelHistory(prevUV,previousPixel,expectedIdentity,expectedP,expectedNs,expectedNg,rho,tolerance,
            history,moments,reconstructed,reconstructedMoments))
        { history=reconstructed;moments=reconstructedMoments; }
    }
    // Invalid/uninitialized textures may contain NaNs; lerp(old,current,1) does not remove NaNs.
    if(!valid) { history=current; moments=float4(lum,lum*lum,0,0); }
    float3 mean=current.rgb, second=current.rgb*current.rgb; float count=1;
    // A rejected history has E[L^2]-E[L]^2 == 0 even for a noisy ray estimate.
    // Keep a spatial luminance estimate for short histories, independently of
    // history acceptance. Do not use radiance similarity to reject its taps:
    // that would classify the very noise we need to measure as an edge.
    float2 spatialMoments=float2(lum,lum*lum);float spatialCount=1;
    [unroll] for(int y=-1;y<=1;y++) [unroll] for(int x=-1;x<=1;x++)
    {
        int2 q=clamp(pixel+int2(x,y),0,(int2)_HLGI_Size.xy-1);
        if(all(q==pixel)) continue;
        float4 g=_HLGI_Geometry.Load(int3(q,0));
        float3 neighborShadingNormal,neighborGeometricNormal;bool neighborHasGeometry;
        if(!HLGIDecodeScreenGeometry(g,neighborShadingNormal,neighborGeometricNormal,neighborHasGeometry) || !neighborHasGeometry) continue;
        if(dot(neighborShadingNormal,shadingNormal)<_HLGI_NormalThreshold || dot(neighborGeometricNormal,geometricNormal)<0.85) continue;
        float3 qp=WorldPosition(HLGIGiSampleUv((uint2)q,(uint2)_HLGI_Size.xy,(uint2)_HLGI_FullSize.xy),g.w,_HLGI_InvVP);
        if(max(abs(dot(qp-p,geometricNormal)),abs(dot(qp-p,neighborGeometricNormal)))>tolerance) continue;
        if(length(_HLGI_Material.Load(int3(q,0)).rgb-rho)>0.15) continue;
        float4 neighbor=_HLGI_Input.Load(int3(q,0));
        if(!HLGIHasRadianceMeasurement(neighbor) || !all(isfinite(neighbor.rgb*neighbor.rgb))) continue;
        float3 c=neighbor.rgb; mean+=c; second+=c*c; count++;
        // Use an absolute plane gate for the spatial variance estimate;
        // the filter itself uses a soft plane weight, not this hard gate.
        if(max(abs(dot(qp-p,geometricNormal)),abs(dot(qp-p,neighborGeometricNormal)))<=max(_HLGI_DepthThreshold,0.001))
        {
            float neighborLum=LuminanceGI(c);
            spatialMoments+=float2(neighborLum,neighborLum*neighborLum);spatialCount++;
        }
    }
    mean/=max(count,1); second/=max(count,1);
    if(!all(isfinite(mean)) || !all(isfinite(second)))
    {
        float4 retained,retainedMoments;
        HLGIResolveUnknownHistory(valid,history,moments,retained,retainedMoments);
        _HLGI_Output[pixel]=retained;_HLGI_MomentsOut[pixel]=retainedMoments;return;
    }
    float3 sigma=sqrt(max(second-mean*mean,0))+0.02;
    history.rgb=clamp(history.rgb,mean-2*sigma,mean+2*sigma);
    float samples=valid?min(moments.z+1,change.y>0.5?2:(float)_HLGI_MaxHistory):1;
    float alpha=valid?max(_HLGI_CurrentWeight,1/samples):1;
    alpha=max(alpha,valid?0.25*abs(current.a-history.a):1);
    float2 newMoments=lerp(moments.xy,float2(lum,lum*lum),alpha);
    spatialMoments/=spatialCount;
    // Retain the existing spatial filter scale limit. Temporal moments use
    // RGBA32F and must preserve HDR second moments without this spatial cap.
    float spatialVariance=min(max(spatialMoments.y-spatialMoments.x*spatialMoments.x,0),65504);
    // xy = temporal luminance moments, z = history length, w = spatial variance.
    // Spatial variance never grants history validity or replaces current GI.
    float4 resolved=lerp(history,current,alpha),resolvedMoments=float4(newMoments,samples,spatialVariance);
    if(!HLGIHasTemporalHistory(resolved,resolvedMoments))
    { _HLGI_Output[pixel]=0;_HLGI_MomentsOut[pixel]=0;return; }
    _HLGI_Output[pixel]=resolved;
    _HLGI_MomentsOut[pixel]=resolvedMoments;
}
[numthreads(8,8,1)]
void CSFilter(uint3 id:SV_DispatchThreadID)
{
    if(any(id.xy>=(uint2)_HLGI_Size.xy)) return;
    int2 pixel=id.xy; float4 center=_HLGI_Input.Load(int3(pixel,0));
    // An invalid center is not filled from neighbors: that would manufacture a
    // valid measurement and let native replacement subtract real lighting.
    if(!HLGIHasRadianceMeasurement(center)) { _HLGI_Output[pixel]=0;return; }
    float4 g=_HLGI_Geometry.Load(int3(pixel,0));
    float3 shadingNormal,geometricNormal;bool hasGeometry;
    if(!HLGIDecodeScreenGeometry(g,shadingNormal,geometricNormal,hasGeometry)) { _HLGI_Output[pixel]=0; return; }
    if(!hasGeometry) { _HLGI_Output[pixel]=center; return; }
    float3 p=WorldPosition(HLGIGiSampleUv((uint2)pixel,(uint2)_HLGI_Size.xy,(uint2)_HLGI_FullSize.xy),g.w,_HLGI_InvVP);
    float3 rho=_HLGI_Material.Load(int3(pixel,0)).rgb;
    float4 moments=_HLGI_Moments.Load(int3(pixel,0));
    float variance=max(moments.y-moments.x*moments.x,0);
    float sigma=max(sqrt(variance)*4,0.05);
    // Preserve first-frame spatial support and mature temporal filtering, while
    // tapering their sigma difference across the existing four-frame window.
    if(moments.z<4)
    {
        float spatialSigma=max(sqrt(max(variance,moments.w*(4/max(moments.z,1))))*4,0.05);
        sigma=lerp(sigma,spatialSigma,saturate((4-moments.z)/3));
    }
    float3 sum=center.rgb*4; float weight=4;
    [unroll] for(int y=-1;y<=1;y++) [unroll] for(int x=-1;x<=1;x++)
    {
        int2 q=pixel+int2(x,y)*_HLGI_FilterStep;
        if(any(q<0)||any(q>=(int2)_HLGI_Size.xy)||all(q==pixel)) continue;
        float4 ng=_HLGI_Geometry.Load(int3(q,0));
        float3 neighborShadingNormal,neighborGeometricNormal;bool neighborHasGeometry;
        if(!HLGIDecodeScreenGeometry(ng,neighborShadingNormal,neighborGeometricNormal,neighborHasGeometry) || !neighborHasGeometry) continue;
        if(dot(neighborGeometricNormal,geometricNormal)<0.85) continue;
        float3 qp=WorldPosition(HLGIGiSampleUv((uint2)q,(uint2)_HLGI_Size.xy,(uint2)_HLGI_FullSize.xy),ng.w,_HLGI_InvVP);
        float4 sampleGI=_HLGI_Input.Load(int3(q,0));
        if(!HLGIHasRadianceMeasurement(sampleGI)) continue;
        float3 qrho=_HLGI_Material.Load(int3(q,0)).rgb;
        float normalWeight=pow(saturate(dot(shadingNormal,neighborShadingNormal)),32);
        float planeDistance=max(abs(dot(qp-p,geometricNormal)),abs(dot(qp-p,neighborGeometricNormal)));
        float w=exp(-planeDistance/max(_HLGI_DepthThreshold,0.001)-length(qrho-rho)*8-
            abs(LuminanceGI(sampleGI.rgb)-LuminanceGI(center.rgb))/sigma)*normalWeight;
        w*= (x==0?2:1)*(y==0?2:1);
        sum+=sampleGI.rgb*w; weight+=w;
    }
    float4 filtered=float4(sum/max(weight,1e-6),center.a);
    _HLGI_Output[pixel]=HLGIHasRadianceMeasurement(filtered)?filtered:0;
}
