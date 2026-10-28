void HLGIHardwareResolveCommittedMaterial(uint instanceIndex,uint primitive,
    HLGIHardwareInstance instance,HLGITriangleNormals attributes,float3x4 objectToWorld,float2 barycentric,
    float4 materialView,float3 direction,float coneRadiusAtOrigin,float coneSlope,
    bool shadowQuery,bool resolveMaterial,inout HLGIHit hit)
{
    float hitRadius=coneRadiusAtOrigin+coneSlope*hit.t;
    bool footprintKnown=isfinite(coneRadiusAtOrigin) && coneRadiusAtOrigin>=0 && isfinite(coneSlope) &&
        isfinite(hit.t) && hit.t>=0 && isfinite(hitRadius) && hitRadius>=0;
    bool covered=true;HLGIHitMaterialSurface material;float3 materialNormal;
    bool coverageKnown=false;
    if(footprintKnown)
        coverageKnown=HLGIHardwareEvaluateHit(instanceIndex,primitive,instance,attributes,objectToWorld,barycentric,
            materialView,direction,hitRadius,true,shadowQuery,covered,material,materialNormal);
    // Recheck the committed identity against the frozen material/texture batch.
    // An unexpected transparent or stale result is unknown, never a miss that
    // would silently expose geometry beyond this committed nearest triangle.
    if(!coverageKnown || !covered) hit.flags|=HLGI_HIT_MATERIAL_UNKNOWN;
    else if(resolveMaterial && !shadowQuery)
    {
        bool materialKnown=HLGIHardwareEvaluateHit(instanceIndex,primitive,instance,attributes,objectToWorld,barycentric,
            materialView,direction,hitRadius,false,false,covered,material,materialNormal);
        if(!materialKnown) hit.flags|=HLGI_HIT_MATERIAL_UNKNOWN;
        else
        {
            hit.materialDiffuse=material.diffuseReflectance;hit.materialEmission=material.emission;
            hit.materialOcclusion=material.occlusion;hit.materialReceivesShadows=material.receivesShadows?1u:0u;
            hit.shadingNormal=materialNormal;hit.flags|=HLGI_HIT_UV_MATERIAL|HLGI_HIT_SHADING_NORMAL;
        }
    }
}

HLGIRayFootprint HLGIPointQueryFootprint()
{ HLGIRayFootprint value;HLGITryMakeRayFootprint(0,0,value);return value; }

bool TraceShadow(float3 o,float3 d,float maxT,uint cullingMask,uint shadowRenderingLayers,bool useRenderingLayers,
    HLGIRayFootprint footprint,float4 materialView,out bool known)
{
    HLGIHit result;
    bool blocked=TraceSceneQuery(o,d,maxT,true,false,cullingMask,shadowRenderingLayers,useRenderingLayers,footprint,materialView,result);
    known=!blocked || HLGIHitMaterialKnown(result);
    return blocked;
}

bool TraceShadow(float3 o,float3 d,float maxT,uint cullingMask,uint shadowRenderingLayers,bool useRenderingLayers,out bool known)
{ return TraceShadow(o,d,maxT,cullingMask,shadowRenderingLayers,useRenderingLayers,HLGIPointQueryFootprint(),float4(o,1),known); }

bool TraceShadow(float3 o,float3 d,float maxT,uint cullingMask,uint shadowRenderingLayers,bool useRenderingLayers)
{ bool known;return TraceShadow(o,d,maxT,cullingMask,shadowRenderingLayers,useRenderingLayers,known); }

bool HLGIHitOwnerCurrent(HLGIHit hit)
{
    if(!HLGIHitHas(hit.flags,HLGI_HIT_VALID) || hit.ownerSlot>=(uint)_HLGI_ProxyCount) return false;
    HLGIProxy proxy=_HLGI_Proxies[hit.ownerSlot];
    return proxy.identity.w>0.5 && proxy.identity.w<1.5 &&
        hit.stableId==(uint)proxy.identity.x && hit.ownerRevision==(uint)proxy.identity.y;
}

float3 DirectIrradiance(float3 p,float3 n,float3 biasNormal,uint2 receiverLayers,bool receivesShadows,
    float3 footprintDirection,HLGIRayFootprint footprint,out bool known)
{
    known=all(isfinite(p)) && all(isfinite(n)) && all(isfinite(biasNormal));
    if(!known) return 0;
    float3 sum=0;
    [loop] for(int i=0;i<_HLGI_LightCount;i++)
    {
        HLGILight light=_HLGI_Lights[i];
        bool useRenderingLayers=(light.masks.w&1u)!=0;
        if(!HLGILightAffectsReceiver(receiverLayers,light.masks.x,light.masks.y,useRenderingLayers)) continue;
        float3 toLight=light.directionRange.xyz;
        float maxT=_HLGI_ShadowDistance, attenuation=1;
        if(light.positionType.w>0.5)
        {
            float3 offset=light.positionType.xyz-p;
            float d2=max(dot(offset,offset),0.0001);
            maxT=sqrt(d2); toLight=offset/maxT;
            float factor=d2/max(light.directionRange.w*light.directionRange.w,0.0001);
            float smooth=saturate(1-factor*factor);
            attenuation=smooth*smooth/d2;
            if(light.positionType.w>1.5)
            {
                float spot=saturate((dot(-toLight,light.directionRange.xyz)-light.spot.x)*light.spot.y);
                attenuation*=spot*spot;
            }
        }
        float rawNdl=dot(n,toLight);
        if(!all(isfinite(toLight)) || !isfinite(rawNdl) || !isfinite(attenuation) || !all(isfinite(light.color.rgb))) { known=false;return 0; }
        float ndl=saturate(rawNdl);
        if(ndl*attenuation<=0 || !any(light.color.rgb>0)) continue;
        float visibility=1;
        if(receivesShadows)
        {
            float strength=saturate(light.spot.z);
            if(!isfinite(light.spot.z) || !isfinite(maxT)) { known=false;return 0; }
            if(strength>0)
            {
                float3 shadowOrigin=p+HLGIOffsetNormal(biasNormal,toLight)*_HLGI_RayBias;
                float3 shadowDirection=toLight;
                float shadowDistance=maxT;
                if(light.positionType.w>0.5)
                {
                    // The biased ray must still focus at the actual point light.
                    // Lighting N.L/attenuation above remain evaluated at p.
                    float3 connection=light.positionType.xyz-shadowOrigin;
                    if(!HLGIFootprintLength(connection,shadowDistance) || !(shadowDistance>0) ||
                        !HLGIFootprintUnit(connection,shadowDirection)) { known=false;return 0; }
                }
                HLGIRayFootprint projected,shadowFootprint=(HLGIRayFootprint)0;
                if(HLGITryRetargetFootprint(footprint,footprintDirection,biasNormal,shadowDirection,projected))
                {
                    if(light.positionType.w>0.5) HLGITryPointShadowFootprint(projected,shadowDistance,shadowFootprint);
                    else HLGITryDirectionalShadowFootprint(projected,shadowFootprint);
                }
                bool shadowKnown;
                bool blocked=TraceShadow(shadowOrigin,shadowDirection,max(0,shadowDistance-_HLGI_RayBias),
                    light.masks.x,light.masks.z,useRenderingLayers,shadowFootprint,float4(p,1),shadowKnown);
                if(!shadowKnown) { known=false;return 0; }
                if(blocked) visibility=1-strength;
            }
        }
        sum+=light.color.rgb*(ndl*attenuation*visibility);
    }
    known=all(isfinite(sum));return known?sum:0;
}

float3 DirectIrradiance(float3 p,float3 n,float3 biasNormal,uint2 receiverLayers,bool receivesShadows,out bool known)
{ return DirectIrradiance(p,n,biasNormal,receiverLayers,receivesShadows,biasNormal,HLGIPointQueryFootprint(),known); }

float3 DirectIrradiance(float3 p,float3 n,float3 biasNormal,uint2 receiverLayers,out bool known)
{ return DirectIrradiance(p,n,biasNormal,receiverLayers,true,known); }

float3 DirectIrradiance(float3 p,float3 n,float3 biasNormal,uint2 receiverLayers)
{ bool known;return DirectIrradiance(p,n,biasNormal,receiverLayers,known); }

float3 ProxyRadiance(HLGIHit hit,float3 incomingDirection,HLGIRayFootprint hitFootprint,float emissionWeight,out float confidence)
{
    confidence=0;
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
    if(materialResolved)
    {
        float3 queryNg=HLGIHitHas(hit.flags,HLGI_HIT_ORIENTED_NG)?hit.rawNg:surface.geometricNormal;
        HLGICachedSurface((int)hit.ownerSlot,hit.position,queryNg,shadingNormal,surface,cached);
    }
    bool directKnown;
    float3 direct=DirectIrradiance(hit.position,shadingNormal,biasNormal,_HLGI_LightingPolicies[hit.ownerSlot].xy,
        receivesShadows,incomingDirection,hitFootprint,directKnown);
    if(!directKnown || !all(isfinite(diffuse)) || !all(isfinite(emission)) || !isfinite(ao)) { confidence=0;return 0; }
    float3 value=max(emission,0)*emissionWeight+clamp(diffuse,0,0.98)*(direct+ao*_HLGI_BounceFeedback*max(cached.irradiance.rgb,0));
    if(!HLGIHasRadianceMeasurement(float4(value,confidence))) { confidence=0;return 0; }
    return value;
}

float3 ProxyRadiance(HLGIHit hit,float3 incomingDirection,HLGIRayFootprint hitFootprint,out float confidence)
{ return ProxyRadiance(hit,incomingDirection,hitFootprint,1,confidence); }

float3 ProxyRadiance(HLGIHit hit,out float confidence)
{ return ProxyRadiance(hit,hit.rawNg,HLGIPointQueryFootprint(),confidence); }

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