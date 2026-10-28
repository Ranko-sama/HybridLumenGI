struct RadianceInput
{
    float4 incoming,control,initialSum,irradiance,guide,history,moments;
    uint4 hitSpec;
    float4 guideSumPower,normal;
    uint4 purpose; // shadow, resolveMaterial, coverageKnown/covered/fullKnown bits, footprint case
    float4 footprint,connection; // incoming direction/radius; light position-or-direction/type
};
struct RadianceOutput
{
    float4 sum,irradiance,guide,history,moments,screen,proxy,direct;
    uint4 predicates,validity;
    float4 propagatedIrradiance,propagatedGuide;
    float4 unshadowedDirect;
    uint4 coverage;
    uint4 resolved;float4 resolvedMaterial;
    float4 forwardedOrigin,forwardedDirection,forwardedFootprint,forwardedView;
    float4 footprintDirect,wrappers,proxyPrimary;
};
StructuredBuffer<RadianceInput> _Inputs:register(t0);
RWStructuredBuffer<RadianceOutput> _Outputs:register(u0);
cbuffer TestCounts:register(b0) { uint _Count; }


#include "ScreenExcludedAreaAdapters.hlsl"
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
                    if(worldMatch && _HLGI_BounceFeedback>0)
                    {
                        float materialAO=HLGIScreenMaterialAO(emission.a,_HLGI_NativeComposition!=0,diffuse.a);
                        bool cacheKnown;float3 cached=CachedIrradiance(match,n,cacheKnown);
                        if(!cacheKnown) { known=false;return true; }
                        radiance+=diffuse.rgb*materialAO*_HLGI_BounceFeedback*cached;
                    }
                    known=all(isfinite(radiance));return true;
                }
            }
        }
        lastT=t; lastDelta=delta;
    }
    return false;
}
float4 ActualEstimator() { float3 p=0,n=normalize(float3(1,0,1)),geometricNormal=float3(0,0,1); bool hasGeometry=true; float2 uv=.5; float depth=.5; uint rng=0; HLGICacheEntry receiverCache=(HLGICacheEntry)0;
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
        if(sampleWeight>0 && TraceScreen(origin,dir,worldHit?hit.t:_HLGI_MaxDistance,incoming,screenT,screenKnown) &&
            (!worldHit || (HLGIHitQueryUnresolved(hit)?screenT<hit.t:screenT<=hit.t)))
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
                screenValue,lightScreenT,lightScreenKnown) &&
                (!lightWorldHit || (HLGIHitQueryUnresolved(lightHit)?lightScreenT<lightHit.t:lightScreenT<=lightHit.t)))
            {
                // The matching direction estimator uses the screen endpoint at
                // weight one. Suppress area NEE on exactly that same support.
                // The excluded contribution is known zero regardless of endpoint radiance.
                lightValue=0;lightKnown=true;
            }
            if(!lightKnown || !HLGIAccumulateRadianceSample(lightValue,1,1,sum)) { estimateKnown=false;break; }
        }
        confidence+=sampleConfidence;
    }
    return estimateKnown?float4(sum/max(_HLGI_Rays,1),confidence/max(_HLGI_Rays,1)):float4(0,0,0,-1);
}

[numthreads(64,1,1)] void CSScreenExcludedArea(uint3 id:SV_DispatchThreadID)
{
    if(id.x>=_Count)return;
    active=_Inputs[id.x];RadianceOutput result=(RadianceOutput)0;
    float3 value;float distanceHit;bool known;
    bool hit=TraceScreen(float3(0,0,.03125),float3(1,0,0),active.initialSum.y,value,distanceHit,known);
    result.screen=float4(value,known?1:-1);result.validity=uint4(hit?1:0,known?1:0,0,0);
    result.proxy=float4(distanceHit,0,0,0);
    directionDraws=areaDraws=directCalls=unknownDirectCalls=0;
    result.sum=ActualEstimator();
    result.predicates=uint4(directionDraws,areaDraws,directCalls,unknownDirectCalls);
    _Outputs[id.x]=result;
}
