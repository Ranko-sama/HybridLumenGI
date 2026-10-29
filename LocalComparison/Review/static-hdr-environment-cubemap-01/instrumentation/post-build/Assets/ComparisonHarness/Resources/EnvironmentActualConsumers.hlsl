bool HLGIHitOwnerCurrent(HLGIHit hit)
{
    if(!HLGIHitHas(hit.flags,HLGI_HIT_VALID) || hit.ownerSlot>=(uint)_HLGI_ProxyCount) return false;
    HLGIProxy proxy=_HLGI_Proxies[hit.ownerSlot];
    return proxy.identity.w>0.5 && proxy.identity.w<1.5 &&
        hit.stableId==(uint)proxy.identity.x && hit.ownerRevision==(uint)proxy.identity.y;
}

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
    if(!HLGIHasRadianceMeasurement(float4(value,confidence))) { confidence=0;return 0; }
    return value;
}

bool HLGIAreaMatchedDirectionWeight(float3 origin,float3 n,float4 guide,float3 direction,inout float weight)
{
    if(_HLGI_AreaEmitterCount<=0)return isfinite(weight) && weight>=0;
    float cosine=max(0,dot(n,direction));
    if(cosine==0) { weight=0;return true; }
    float pdf=HLGITransportDirectionPdf(origin,n,guide,direction);
    if(!isfinite(pdf) || pdf<=0)return false;
    // No grazing-angle denominator clamp: both MIS techniques must integrate
    // the same cosine/PDF, including very small but representable densities.
    weight=(cosine/pdf)/PI;
    return isfinite(weight) && weight>=0;
}

float LuminanceGI(float3 c) { return dot(c,float3(0.2126,0.7152,0.0722)); }

float3 LimitRadiance(float3 c)
{
    c=max(c,0);
    // Optional biased firefly clamp; 0 means unbounded transport.
    return _HLGI_RadianceClamp>0 ? c*min(1,_HLGI_RadianceClamp/max(LuminanceGI(c),1e-5)) : c;
}

[numthreads(64,1,1)]
void CSUpdateCacheLegacy(uint3 id:SV_DispatchThreadID)
{
    if(_HLGI_CacheGrid<1 || _HLGI_CacheGrid>4 || _HLGI_SurfaceCardCount<=0) return;
    uint patches=(uint)(_HLGI_CacheGrid*_HLGI_CacheGrid);
    uint count=(uint)_HLGI_SurfaceCardCount*patches;
    if(id.x>=count) return;
    uint card=id.x/patches,local=id.x%patches;
    HLGISurfaceSample surface;
    bool covered=HLGITrySurfacePatch(card,uint2(local%_HLGI_CacheGrid,local/_HLGI_CacheGrid),_HLGI_CacheGrid,surface);
    if(!covered) { _HLGI_CacheWrite[id.x]=(HLGICacheEntry)0;return; }
    // Patch validation rejects unused/invalid owners before reading the proxy buffer.
    HLGIProxy p=_HLGI_Proxies[surface.ownerSlot];
    HLGICacheEntry e=_HLGI_CacheRead[id.x];
    float3 tag=float3(p.identity.xy,_HLGI_Epoch);
    float2 change=HLGIChangeAt(surface.position);
    if(any(e.tag.xyz!=tag) || e.tag.w!=(float)surface.generation || change.x>0.5 || !HLGIHasCacheMeasurement(e.irradiance,e.guide))
        e=(HLGICacheEntry)0;
    // Nearby changes retain an estimate but shorten its history, even if this patch awaits budget.
    if(change.y>0.5) e.irradiance.a=min(e.irradiance.a,1);
    e.tag=float4(tag,surface.generation);
    float2 geometricOct=PackNormalOctQuadEncode(surface.geometricNormal);
    e.anchor=float4(surface.position,geometricOct.x);e.normal=float4(surface.normal,geometricOct.y);
    if(_HLGI_CacheUpdateMask[id.x]!=0)
    {
        float3 position=surface.position,n=surface.normal;
        // Separate cache-update and camera-gather domains: an equal physical
        // patch/pixel index must not reuse the guide-producing random stream.
        uint rng=HLGIHash((id.x+HLGIHash((uint)_HLGI_FrameIndex+1))^0xA511E9B3u);
        float3 sum=0,guide=0;float guidePower=0;bool estimateKnown=true;
        [loop] for(int r=0;r<_HLGI_CacheRays;r++)
        {
            float3 origin=position+HLGIOffsetNormal(surface.geometricNormal,n)*_HLGI_RayBias;
            float weight;float3 direction=HLGISampleTransportDirection(origin,n,e.guide,rng,weight);
            if(!HLGIAreaMatchedDirectionWeight(origin,n,e.guide,direction,weight)) { estimateKnown=false;break; }
            if(!all(isfinite(direction))) { estimateKnown=false;break; }
            HLGIHit hit;
            float3 incoming=0;float materialConfidence=1;
            HLGIRayFootprint footprint;
            HLGITrySurfacePatchRayFootprint(surface,uint2(local%_HLGI_CacheGrid,local/_HLGI_CacheGrid),direction,footprint);
            if(weight>0 && TraceSceneHit(origin,direction,_HLGI_MaxDistance,footprint,float4(position,1),hit))
            {
                HLGIRayFootprint hitFootprint;HLGIAdvanceRayFootprint(footprint,hit.t,hitFootprint);
                float emissionWeight;
                if(!HLGIAreaDirectionEmissionWeight(origin,n,e.guide,direction,hit,emissionWeight)) { estimateKnown=false;break; }
                incoming=ProxyRadiance(hit,direction,hitFootprint,emissionWeight,materialConfidence);
            }
            else if(weight>0) incoming=_HLGI_Environment.rgb;
            if(!HLGIAccumulateRadianceSample(incoming,materialConfidence,weight,sum)) { estimateKnown=false;break; }
            float power=dot(max(incoming,0),float3(0.2126,0.7152,0.0722))*weight;
            guide+=direction*power;guidePower+=power;
            HLGIAreaSample lightSample;
            uint lightStatus=HLGI_AREA_NONE;
            if(_HLGI_AreaEmitterCount>0)lightStatus=HLGISampleAreaEmitter(origin,float3(Random(rng),Random(rng),Random(rng)),lightSample);
            if(lightStatus==HLGI_AREA_UNKNOWN) { estimateKnown=false;break; }
            if(lightStatus==HLGI_AREA_SAMPLE)
            {
                HLGITrySurfacePatchRayFootprint(surface,uint2(local%_HLGI_CacheGrid,local/_HLGI_CacheGrid),lightSample.direction,footprint);
                float3 lightValue;bool lightWorldHit;HLGIHit lightHit;
                if(!HLGIAreaLightContribution(origin,n,e.guide,lightSample,footprint,float4(position,1),lightValue,lightWorldHit,lightHit) ||
                    !HLGIAccumulateRadianceSample(lightValue,1,1,sum)) { estimateKnown=false;break; }
                float lightPower=dot(lightValue,float3(0.2126,0.7152,0.0722));
                guide+=lightSample.direction*lightPower;guidePower+=lightPower;
            }
        }
        HLGICommitCacheEstimate(estimateKnown,sum,guide,guidePower,_HLGI_CacheRays,n,e.irradiance,e.guide);
    }
    _HLGI_CacheWrite[id.x]=e;
}

[numthreads(64,1,1)]
void CSUpdateCache(uint3 id:SV_DispatchThreadID)
{
    if(_HLGI_CacheGrid<1 || _HLGI_CacheGrid>4 || _HLGI_SurfaceCardCount<=0) return;
    uint patches=(uint)(_HLGI_CacheGrid*_HLGI_CacheGrid);
    uint count=(uint)_HLGI_SurfaceCardCount*patches;
    if(id.x>=count) return;
    uint card=id.x/patches,local=id.x%patches;
    HLGISurfaceSample surface;
    bool covered=HLGITrySurfacePatch(card,uint2(local%_HLGI_CacheGrid,local/_HLGI_CacheGrid),_HLGI_CacheGrid,surface);
    if(!covered) { _HLGI_CacheWrite[id.x]=(HLGICacheEntry)0;return; }
    // Patch validation rejects unused/invalid owners before reading the proxy buffer.
    HLGIProxy p=_HLGI_Proxies[surface.ownerSlot];
    HLGICacheEntry e=_HLGI_CacheRead[id.x];
    float3 tag=float3(p.identity.xy,_HLGI_Epoch);
    float2 change=HLGIChangeAt(surface.position);
    if(any(e.tag.xyz!=tag) || e.tag.w!=(float)surface.generation || change.x>0.5 || !HLGIHasCacheMeasurement(e.irradiance,e.guide))
        e=(HLGICacheEntry)0;
    // Nearby changes retain an estimate but shorten its history, even if this patch awaits budget.
    if(change.y>0.5) e.irradiance.a=min(e.irradiance.a,1);
    e.tag=float4(tag,surface.generation);
    float2 geometricOct=PackNormalOctQuadEncode(surface.geometricNormal);
    e.anchor=float4(surface.position,geometricOct.x);e.normal=float4(surface.normal,geometricOct.y);
    if(_HLGI_CacheUpdateMask[id.x]!=0)
    {
        float3 position=surface.position,n=surface.normal;
        // Separate cache-update and camera-gather domains: an equal physical
        // patch/pixel index must not reuse the guide-producing random stream.
        uint rng=HLGIHash((id.x+HLGIHash((uint)_HLGI_FrameIndex+1))^0xA511E9B3u);
        float3 sum=0,guide=0;float guidePower=0;bool estimateKnown=true;
        [loop] for(int r=0;r<_HLGI_CacheRays;r++)
        {
            float3 origin=position+HLGIOffsetNormal(surface.geometricNormal,n)*_HLGI_RayBias;
            float weight;float3 direction=HLGISampleTransportDirection(origin,n,e.guide,rng,weight);
            if(!HLGIAreaMatchedDirectionWeight(origin,n,e.guide,direction,weight)) { estimateKnown=false;break; }
            if(!all(isfinite(direction))) { estimateKnown=false;break; }
            HLGIHit hit;
            float3 incoming=0;float materialConfidence=1;
            HLGIRayFootprint footprint;
            HLGITrySurfacePatchRayFootprint(surface,uint2(local%_HLGI_CacheGrid,local/_HLGI_CacheGrid),direction,footprint);
            if(weight>0 && TraceSceneHit(origin,direction,_HLGI_MaxDistance,footprint,float4(position,1),hit))
            {
                HLGIRayFootprint hitFootprint;HLGIAdvanceRayFootprint(footprint,hit.t,hitFootprint);
                float emissionWeight;
                if(!HLGIAreaDirectionEmissionWeight(origin,n,e.guide,direction,hit,emissionWeight)) { estimateKnown=false;break; }
                incoming=ProxyRadiance(hit,direction,hitFootprint,emissionWeight,materialConfidence);
            }
            else if(weight>0) incoming=HLGIEnvironmentRadiance(direction);
            if(!HLGIAccumulateRadianceSample(incoming,materialConfidence,weight,sum)) { estimateKnown=false;break; }
            float power=dot(max(incoming,0),float3(0.2126,0.7152,0.0722))*weight;
            guide+=direction*power;guidePower+=power;
            HLGIAreaSample lightSample;
            uint lightStatus=HLGI_AREA_NONE;
            if(_HLGI_AreaEmitterCount>0)lightStatus=HLGISampleAreaEmitter(origin,float3(Random(rng),Random(rng),Random(rng)),lightSample);
            if(lightStatus==HLGI_AREA_UNKNOWN) { estimateKnown=false;break; }
            if(lightStatus==HLGI_AREA_SAMPLE)
            {
                HLGITrySurfacePatchRayFootprint(surface,uint2(local%_HLGI_CacheGrid,local/_HLGI_CacheGrid),lightSample.direction,footprint);
                float3 lightValue;bool lightWorldHit;HLGIHit lightHit;
                if(!HLGIAreaLightContribution(origin,n,e.guide,lightSample,footprint,float4(position,1),lightValue,lightWorldHit,lightHit) ||
                    !HLGIAccumulateRadianceSample(lightValue,1,1,sum)) { estimateKnown=false;break; }
                float lightPower=dot(lightValue,float3(0.2126,0.7152,0.0722));
                guide+=lightSample.direction*lightPower;guidePower+=lightPower;
            }
        }
        HLGICommitCacheEstimate(estimateKnown,sum,guide,guidePower,_HLGI_CacheRays,n,e.irradiance,e.guide);
    }
    _HLGI_CacheWrite[id.x]=e;
}

[numthreads(8,8,1)]
void CSTraceLegacy(uint3 id:SV_DispatchThreadID)
{
    if(any(id.xy>=(uint2)_HLGI_Size.xy)) return;
    uint2 fullPixel=HLGIFullPixelForGiPixel(id.xy,(uint2)_HLGI_Size.xy,(uint2)_HLGI_FullSize.xy);
    float2 uv=HLGIFullPixelCenterUv(fullPixel,(uint2)_HLGI_FullSize.xy);
    float depth=_HLGI_Depth.Load(int3(fullPixel,0));
    float4 material=_HLGI_Diffuse.Load(int3(fullPixel,0));
    float capturedDepth=_HLGI_CaptureDepth.Load(int3(fullPixel,0));
    bool sameSurface=ValidDepth(capturedDepth) && distance(WorldPosition(uv,depth,_HLGI_InvVP),WorldPosition(uv,capturedDepth,_HLGI_InvVP))<0.03;
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
    _HLGI_Output[id.xy]=estimateKnown?float4(sum/max(_HLGI_Rays,1),confidence/max(_HLGI_Rays,1)):float4(0,0,0,-1);
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
        else if(sampleWeight>0) { incoming=HLGIEnvironmentRadiance(dir);sampleConfidence=0.25; }
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
    _HLGI_Output[id.xy]=estimateKnown?float4(sum/max(_HLGI_Rays,1),confidence/max(_HLGI_Rays,1)):float4(0,0,0,-1);
}
