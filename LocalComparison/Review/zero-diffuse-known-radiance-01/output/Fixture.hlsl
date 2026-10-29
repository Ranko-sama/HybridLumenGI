
#include "HybridLumenGIHit.hlsl"
#include "HybridLumenGIRadianceValidity.hlsl"
#include "HybridLumenGIScreenMaterial.hlsl"
struct HLGIProxy { float4 centerShape, extentsRoughness, albedo, emission, identity; };
struct HLGICacheEntry { float4 irradiance; float4 tag; float4 anchor; float4 normal; float4 guide; float4 nonAnalyticIrradiance; };
struct HLGIRayFootprint { float unused; };
struct HLGISurfaceSample {
    float3 diffuse,emission,normal,geometricNormal;
    float occlusion,confidence;
};
struct Input {
    float4 control,emission,diffuse,direct,cached,nonAnalyticCached,options;
    float4 reserved0,reserved1,reserved2,reserved3;
};
struct Output { float4 oldValue,newValue,detail,calls; };
StructuredBuffer<Input> Inputs:register(t0);
RWStructuredBuffer<Output> Outputs:register(u0);
cbuffer Counts:register(b0) { uint Count; }
static Input active;
static uint dependencyMask;
static HLGIProxy _HLGI_Proxies[1];
static uint4 _HLGI_LightingPolicies[1];
static int _HLGI_ScreenSteps=1,_HLGI_NativeComposition=0;
static float _HLGI_RayBias=.03125,_HLGI_Thickness=.15,_HLGI_BounceFeedback=1;
static float4 _HLGI_MaterialView=float4(0,0,0,1);
static float4x4 _HLGI_InvVP;
static float3 screenP;
SamplerState sampler_PointClamp;
struct ScalarTexture {
    float SampleLevel(SamplerState s,float2 uv,float mip) { return .5; }
};
struct EmissionTexture {
    float4 SampleLevel(SamplerState s,float2 uv,float mip) { return active.emission; }
};
struct DiffuseTexture {
    float4 SampleLevel(SamplerState s,float2 uv,float mip) { return active.diffuse; }
};
struct PolicyTexture {
    void GetDimensions(out uint width,out uint height) { width=height=1; }
    uint2 Load(int3 pixel) { return uint2(1,1); }
};
static ScalarTexture _HLGI_Depth,_HLGI_CaptureDepth;
static EmissionTexture _HLGI_Emission;
static DiffuseTexture _HLGI_Diffuse;
static PolicyTexture _HLGI_ReceiverPolicy;

bool HLGIHitOwnerCurrent(HLGIHit hit) { dependencyMask|=16u;return true; }
bool HLGITrySurfaceMaterialHit(HLGIHit hit,out HLGISurfaceSample surface) {
    dependencyMask|=1u;surface=(HLGISurfaceSample)0;
    surface.diffuse=active.diffuse.rgb;surface.emission=active.emission.rgb;
    surface.normal=surface.geometricNormal=float3(0,0,-1);
    surface.occlusion=active.diffuse.a;surface.confidence=1;return true;
}
bool HLGICachedSurface(int owner,float3 p,float3 ng,float3 ns,HLGISurfaceSample surface,
                      out HLGICacheEntry cached,out bool known) {
    dependencyMask|=8u;cached=(HLGICacheEntry)0;
    cached.irradiance=float4(active.cached.rgb,2);
    cached.nonAnalyticIrradiance=float4(active.nonAnalyticCached.rgb,0);
    known=active.control.z!=0;return true;
}
float3 DirectIrradiance(float3 p,float3 n,float3 ng,uint2 layers,bool shadows,
                        float3 ray,HLGIRayFootprint footprint,out bool known) {
    dependencyMask|=4u;known=active.control.y!=0;return active.direct.rgb;
}
float3 CachedIrradiance(HLGIHit hit,float3 n,out bool known) {
    dependencyMask|=8u;known=active.control.z!=0;return active.cached.rgb;
}
// Same ScreenPoint/texture adapter as StandaloneScreenEndpoint: one captured
// plane at t=1, identical marching and binary refinement for both functions.
bool ScreenPoint(float3 origin,float3 dir,float t,out float2 uv,out float delta,out float3 p) {
    screenP=origin+dir;uv=.5;delta=t-1;p=screenP;return true;
}
float3 NormalAt(float2 uv) { return float3(0,0,-1); }
bool ValidDepth(float d) { return d>0&&d<1; }
float3 WorldPosition(float2 uv,float depth,float4x4 matrix) { return screenP; }
bool HLGITryScreenGeometricNormal(float2 uv,float raw,float3 p,out float3 n) {
    n=NormalAt(uv);return true;
}
bool HLGITryScreenWorldMatch(float2 uv,float raw,float3 p,float3 n,out HLGIHit hit) {
    dependencyMask|=2u;hit=(HLGIHit)0;hit.rawNg=n;return true;
}
bool HLGITryScreenRayFootprint(float2 uv,float raw,float3 p,float3 ray,out HLGIRayFootprint footprint) {
    footprint.unused=0;return true;
}
float3 ProxyRadianceOld(HLGIHit hit,float3 incomingDirection,HLGIRayFootprint hitFootprint,float emissionWeight,out float confidence,out float3 nonAnalytic)
{
    confidence=0;nonAnalytic=0;
    if(!HLGIHitOwnerCurrent(hit) || !HLGIHitMaterialKnown(hit)) return 0;
    HLGIProxy proxy=_HLGI_Proxies[hit.ownerSlot];
    HLGISurfaceSample surface;
    float3 diffuse=proxy.albedo.rgb,emission=proxy.emission.rgb;
    float3 shadingNormal=HLGIHitHas(hit.flags,HLGI_HIT_SHADING_NORMAL)?hit.shadingNormal:hit.rawNg;
    float3 biasNormal=hit.rawNg;float ao=1;bool receivesShadows=true;
    bool materialResolved=HLGITrySurfaceMaterialHit(hit,surface);
    if(HLGIHitHas(hit.flags,HLGI_HIT_TRIANGLE))
    {
        // A real triangle's committed UV material owns Ns/rho/Le/AO. Card data
        // may locate an incoming-irradiance patch, but must not replace those
        // physical material values or act as a fallback for unknown coverage.
        if(!HLGIHitHas(hit.flags,HLGI_HIT_UV_MATERIAL|HLGI_HIT_SHADING_NORMAL) || hit.materialReceivesShadows>1u) return 0;
        diffuse=hit.materialDiffuse;emission=hit.materialEmission;ao=hit.materialOcclusion;
        receivesShadows=hit.materialReceivesShadows!=0u;confidence=1;
    }
    else if(materialResolved)
    {
        diffuse=surface.diffuse;emission=surface.emission;shadingNormal=surface.normal;
        biasNormal=surface.geometricNormal;ao=surface.occlusion;
        confidence=saturate(surface.confidence);
    }
    else confidence=0.1; // Uncharted analytic/SDF owner-level approximation.
    HLGICacheEntry cached=(HLGICacheEntry)0;
    if(materialResolved && _HLGI_BounceFeedback>0)
    {
        float3 queryNg=HLGIHitHas(hit.flags,HLGI_HIT_ORIENTED_NG)?hit.rawNg:surface.geometricNormal;
        bool cacheKnown;
        HLGICachedSurface((int)hit.ownerSlot,hit.position,queryNg,shadingNormal,surface,cached,cacheKnown);
        if(!cacheKnown) { confidence=0;return 0; }
    }
    bool directKnown;
    float3 direct=DirectIrradiance(hit.position,shadingNormal,biasNormal,_HLGI_LightingPolicies[hit.ownerSlot].xy,
        receivesShadows,incomingDirection,hitFootprint,directKnown);
    if(!directKnown || !all(isfinite(diffuse)) || !all(isfinite(emission)) || !isfinite(ao)) { confidence=0;return 0; }
    float3 value=max(emission,0)*emissionWeight+clamp(diffuse,0,0.98)*(direct+ao*_HLGI_BounceFeedback*max(cached.irradiance.rgb,0));
    nonAnalytic=max(emission,0)*emissionWeight+clamp(diffuse,0,0.98)*(ao*_HLGI_BounceFeedback*max(cached.nonAnalyticIrradiance.rgb,0));
    if(!HLGIHasRadianceMeasurement(float4(value,confidence))) { confidence=0;return 0; }
    return value;
}

float3 ProxyRadianceNew(HLGIHit hit,float3 incomingDirection,HLGIRayFootprint hitFootprint,float emissionWeight,out float confidence,out float3 nonAnalytic)
{
    confidence=0;nonAnalytic=0;
    if(!HLGIHitOwnerCurrent(hit) || !HLGIHitMaterialKnown(hit)) return 0;
    HLGIProxy proxy=_HLGI_Proxies[hit.ownerSlot];
    HLGISurfaceSample surface;
    float3 diffuse=proxy.albedo.rgb,emission=proxy.emission.rgb;
    float3 shadingNormal=HLGIHitHas(hit.flags,HLGI_HIT_SHADING_NORMAL)?hit.shadingNormal:hit.rawNg;
    float3 biasNormal=hit.rawNg;float ao=1;bool receivesShadows=true;
    bool materialResolved=HLGITrySurfaceMaterialHit(hit,surface);
    if(HLGIHitHas(hit.flags,HLGI_HIT_TRIANGLE))
    {
        // A real triangle's committed UV material owns Ns/rho/Le/AO. Card data
        // may locate an incoming-irradiance patch, but must not replace those
        // physical material values or act as a fallback for unknown coverage.
        if(!HLGIHitHas(hit.flags,HLGI_HIT_UV_MATERIAL|HLGI_HIT_SHADING_NORMAL) || hit.materialReceivesShadows>1u) return 0;
        diffuse=hit.materialDiffuse;emission=hit.materialEmission;ao=hit.materialOcclusion;
        receivesShadows=hit.materialReceivesShadows!=0u;confidence=1;
    }
    else if(materialResolved)
    {
        diffuse=surface.diffuse;emission=surface.emission;shadingNormal=surface.normal;
        biasNormal=surface.geometricNormal;ao=surface.occlusion;
        confidence=saturate(surface.confidence);
    }
    else confidence=0.1; // Uncharted analytic/SDF owner-level approximation.
    if(all(isfinite(diffuse)) && all(clamp(diffuse,0,0.98)==0))
    {
        // Incident light has zero weight, but source validity still matters.
        // Keep the finite-input gates normally supplied by DirectIrradiance.
        if(!all(isfinite(emission)) || !isfinite(ao) || !all(isfinite(hit.position)) ||
            !all(isfinite(shadingNormal)) || !all(isfinite(biasNormal))) { confidence=0;return 0; }
        float3 emissionOnly=max(emission,0)*emissionWeight;
        if(!HLGIHasRadianceMeasurement(float4(emissionOnly,confidence))) { confidence=0;return 0; }
        nonAnalytic=emissionOnly;
        return emissionOnly;
    }
    HLGICacheEntry cached=(HLGICacheEntry)0;
    if(materialResolved && _HLGI_BounceFeedback>0)
    {
        float3 queryNg=HLGIHitHas(hit.flags,HLGI_HIT_ORIENTED_NG)?hit.rawNg:surface.geometricNormal;
        bool cacheKnown;
        HLGICachedSurface((int)hit.ownerSlot,hit.position,queryNg,shadingNormal,surface,cached,cacheKnown);
        if(!cacheKnown) { confidence=0;return 0; }
    }
    bool directKnown;
    float3 direct=DirectIrradiance(hit.position,shadingNormal,biasNormal,_HLGI_LightingPolicies[hit.ownerSlot].xy,
        receivesShadows,incomingDirection,hitFootprint,directKnown);
    if(!directKnown || !all(isfinite(diffuse)) || !all(isfinite(emission)) || !isfinite(ao)) { confidence=0;return 0; }
    float3 value=max(emission,0)*emissionWeight+clamp(diffuse,0,0.98)*(direct+ao*_HLGI_BounceFeedback*max(cached.irradiance.rgb,0));
    nonAnalytic=max(emission,0)*emissionWeight+clamp(diffuse,0,0.98)*(ao*_HLGI_BounceFeedback*max(cached.nonAnalyticIrradiance.rgb,0));
    if(!HLGIHasRadianceMeasurement(float4(value,confidence))) { confidence=0;return 0; }
    return value;
}

bool TraceScreenOld(float3 origin,float3 dir,float maxT,out float3 radiance,out float distanceHit,out bool known,bool resolveRadiance=true)
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
                    // Area NEE only needs this same endpoint to exclude screen
                    // support. Its radiance/known outputs are deliberately unused.
                    if(!resolveRadiance) { distanceHit=surfaceT;return true; }
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

bool TraceScreenNew(float3 origin,float3 dir,float maxT,out float3 radiance,out float distanceHit,out bool known,bool resolveRadiance=true)
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
                    // Area NEE only needs this same endpoint to exclude screen
                    // support. Its radiance/known outputs are deliberately unused.
                    if(!resolveRadiance) { distanceHit=surfaceT;return true; }
                    float4 diffuse=_HLGI_Diffuse.SampleLevel(sampler_PointClamp,uv,0);
                    if(all(diffuse.rgb==0))
                    {
                        // Zero diffuse reflectance needs no incident-light query,
                        // but cannot turn invalid captured inputs into known emission.
                        distanceHit=surfaceT;
                        known=all(isfinite(emission)) && all(isfinite(diffuse)) &&
                            all(isfinite(p)) && all(isfinite(n)) && all(isfinite(biasNormal));
                        if(known) radiance=emission.rgb;
                        return true;
                    }
                    HLGIHit match;
                    bool worldMatch=false;
                    if(hasGeometry) worldMatch=HLGITryScreenWorldMatch(uv,raw,p,geometricNormal,match);
                    if(worldMatch) biasNormal=match.rawNg;
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
[numthreads(64,1,1)]
void CSZeroDiffuse(uint3 id:SV_DispatchThreadID) {
    if(id.x>=Count)return;
    active=Inputs[id.x];Output o=(Output)0;
    _HLGI_Proxies[0]=(HLGIProxy)0;
    _HLGI_Proxies[0].albedo=active.diffuse;
    _HLGI_Proxies[0].emission=active.emission;
    _HLGI_LightingPolicies[0]=uint4(1,1,0,0);
    if(active.control.x==0) {
        HLGIHit hit=(HLGIHit)0;
        hit.t=1;hit.position=float3(0,0,1);hit.rawNg=hit.shadingNormal=float3(0,0,-1);
        hit.ownerSlot=0;hit.stableId=hit.ownerRevision=hit.geometryRevision=1;
        hit.representation=HLGI_REPRESENTATION_TRIANGLE;
        hit.flags=HLGI_HIT_VALID|HLGI_HIT_TRIANGLE|HLGI_HIT_UV_MATERIAL|
                  HLGI_HIT_SHADING_NORMAL|HLGI_HIT_ORIENTED_NG;
        if(active.control.w==0)hit.flags|=HLGI_HIT_MATERIAL_UNKNOWN;
        hit.materialDiffuse=active.diffuse.rgb;hit.materialEmission=active.emission.rgb;
        hit.materialOcclusion=active.diffuse.a;hit.materialReceivesShadows=1;
        HLGIRayFootprint footprint;footprint.unused=0;
        float oldConfidence,newConfidence;float3 oldN,newN;
        dependencyMask=0;
        float3 oldRGB=ProxyRadianceOld(hit,float3(0,0,1),footprint,active.options.y,oldConfidence,oldN);
        uint oldMask=dependencyMask;dependencyMask=0;
        float3 newRGB=ProxyRadianceNew(hit,float3(0,0,1),footprint,active.options.y,newConfidence,newN);
        // Unknown RGB is explicitly outside the product's numerical contract.
        if(!(oldConfidence>0))oldRGB=0;
        if(!(newConfidence>0)) { newRGB=0;newN=0; }
        o.oldValue=float4(oldRGB,oldConfidence);o.newValue=float4(newRGB,newConfidence);
        o.detail=float4(newN,0);o.calls=float4(oldMask,dependencyMask,0,0);
    } else {
        float3 oldRGB,newRGB;float oldT,newT;bool oldKnown,newKnown;
        dependencyMask=0;
        bool oldHit=TraceScreenOld(0,float3(0,0,1),4,oldRGB,oldT,oldKnown,active.options.x!=0);
        uint oldMask=dependencyMask;dependencyMask=0;
        bool newHit=TraceScreenNew(0,float3(0,0,1),4,newRGB,newT,newKnown,active.options.x!=0);
        if(!oldKnown||!oldHit)oldRGB=0;
        if(!newKnown||!newHit)newRGB=0;
        o.oldValue=float4(oldRGB,oldHit&&oldKnown?1:0);
        o.newValue=float4(newRGB,newHit&&newKnown?1:0);
        o.detail=float4(oldT,newT,oldHit?1:0,newHit?1:0);
        o.calls=float4(oldMask,dependencyMask,0,0);
    }
    Outputs[id.x]=o;
}
