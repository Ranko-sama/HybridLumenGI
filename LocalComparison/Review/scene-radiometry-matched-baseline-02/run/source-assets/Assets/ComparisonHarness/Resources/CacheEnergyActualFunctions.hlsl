bool HLGISurfaceAtlasRect(float4 rect,out int2 minimum,out int2 count)
{
    minimum=0;count=0;
    if(!all(isfinite(rect)) || any(rect<0) || any(rect>1) ||
        !all(isfinite(_HLGI_SurfaceAtlasSize.xy)) || any(_HLGI_SurfaceAtlasSize.xy<1) ||
        any(_HLGI_SurfaceAtlasSize.xy>32768)) return false;
    int2 dimensions=(int2)round(_HLGI_SurfaceAtlasSize.xy);
    minimum=(int2)round(rect.xy*dimensions);
    count=(int2)round(rect.zw*dimensions);
    return all(count>0) && all(minimum>=0) && all(minimum+count<=dimensions);
}

bool HLGISurfaceOwnerRange(int slot,out uint4 range)
{
    range=0;
    if(slot<0 || slot>=_HLGI_ProxyCount || _HLGI_SurfaceCardCount<=0) return false;
    range=_HLGI_SurfaceOwnerRanges[slot];
    if(range.y==0u || range.z==0u || range.x>=(uint)_HLGI_SurfaceCardCount) return false;
    return range.y<=(uint)_HLGI_SurfaceCardCount-range.x;
}

bool HLGISurfaceCardValid(uint cardIndex)
{
    if(_HLGI_SurfaceCardCount<=0 || cardIndex>=(uint)_HLGI_SurfaceCardCount) return false;
    HLGISurfaceCard card=_HLGI_SurfaceCards[cardIndex];
    if(card.ownerSlot>=(uint)_HLGI_ProxyCount ||
        card.ready==0u || card.generation==0u || card.layoutGeneration==0u) return false;
    uint4 range;
    if(!HLGISurfaceOwnerRange((int)card.ownerSlot,range) || range.z!=card.layoutGeneration) return false;
    // Owner must be validated before any _Proxies access; unused physical pool entries are legal.
    HLGIProxy proxy=_HLGI_Proxies[card.ownerSlot];
    return proxy.identity.w>0.5 && card.stableId==(uint)proxy.identity.x && card.revision==(uint)proxy.identity.y;
}

bool HLGISurfaceCardUv(uint cardIndex,float3 position,out float2 uv)
{
    uv=0;
    if(!HLGISurfaceCardValid(cardIndex)) return false;
    float3 projected=mul(_HLGI_SurfaceCards[cardIndex].worldToCard,float4(position,1)).xyz;
    uv=projected.xy;
    return all(isfinite(projected)) && all(projected>=0) && all(projected<=1);
}

HLGIRayFootprint HLGIPointQueryFootprint()
{ HLGIRayFootprint value;HLGITryMakeRayFootprint(0,0,value);return value; }

bool HLGIHitOwnerCurrent(HLGIHit hit)
{
    if(!HLGIHitHas(hit.flags,HLGI_HIT_VALID) || hit.ownerSlot>=(uint)_HLGI_ProxyCount) return false;
    HLGIProxy proxy=_HLGI_Proxies[hit.ownerSlot];
    return proxy.identity.w>0.5 && proxy.identity.w<1.5 &&
        hit.stableId==(uint)proxy.identity.x && hit.ownerRevision==(uint)proxy.identity.y;
}

bool HLGICachedSurface(int index,float3 position,float3 geometricNormal,float3 shadingNormal,
    HLGISurfaceSample surface,out HLGICacheEntry result)
{
    result=(HLGICacheEntry)0;
    HLGIProxy p=_HLGI_Proxies[index];
    float2 uv;
    if(!HLGISurfaceCardUv(surface.cardIndex,position,uv)) return false;
    float2 patchPosition=uv*_HLGI_CacheGrid-0.5;
    int2 baseCell=(int2)floor(patchPosition);
    float2 fraction=frac(patchPosition); float totalWeight=0;
    // Geometry selects the card; its capture axis is never inferred from the dominant hit normal.
    // Each tap includes a full visibility query. Preserve the four taps in a
    // loop instead of cloning four complete software traversals in the shader.
    [loop] for(int tap=0;tap<4;tap++)
    {
        int x=tap&1,y=tap>>1;
        int2 cell=baseCell+int2(x,y);
        if(any(cell<0)||any(cell>=_HLGI_CacheGrid)) continue;
        uint entry=surface.cardIndex*_HLGI_CacheGrid*_HLGI_CacheGrid+cell.y*_HLGI_CacheGrid+cell.x;
        HLGICacheEntry e=_HLGI_CacheRead[entry];
        if(any(e.tag.xyz != float3(p.identity.xy,_HLGI_Epoch)) || !HLGIHasCacheMeasurement(e.irradiance,e.guide)) continue;
        if(e.tag.w!=(float)surface.generation) continue;
        float3 delta=position-e.anchor.xyz;
        float3 anchorGeometricNormal=UnpackNormalOctQuadEncode(float2(e.anchor.w,e.normal.w));
        // Shading normals compare lighting orientation; geometry normals compare the
        // actual layer. A normal map must not tilt this plane test into the surface.
        if(dot(shadingNormal,e.normal.xyz)<0.85 || dot(geometricNormal,anchorGeometricNormal)<0.85 ||
            abs(dot(delta,anchorGeometricNormal))>max(_HLGI_RayBias*2,0.03)) continue;
        // Isolated card captures can contain anchors buried in intersecting
        // geometry. Start visibility at the queried surface, not at the anchor:
        // an anchor inside another opaque object would otherwise leave through
        // its culled back face and leak exterior cached light into the room.
        // Offset BOTH endpoints and test the complete resulting segment. A
        // RayBias-sized endpoint gap can hide a thin wall next to the anchor.
        float3 visibilityOrigin=position+HLGIOffsetNormal(geometricNormal,shadingNormal)*_HLGI_RayBias;
        float3 visibilityTarget=e.anchor.xyz+HLGIOffsetNormal(anchorGeometricNormal,shadingNormal)*_HLGI_RayBias;
        float3 connection=visibilityTarget-visibilityOrigin;
        float separation=length(connection);
        if(separation>0.0002)
        {
            HLGIHit blocker;
            if(TraceSceneVisibilityHit(visibilityOrigin,connection/separation,separation-0.0001,
                HLGIPointQueryFootprint(),float4(position,1),blocker)) continue;
        }
        float weight=(x==0?1-fraction.x:fraction.x)*(y==0?1-fraction.y:fraction.y);
        totalWeight+=weight;result.irradiance+=e.irradiance*weight;result.guide+=e.guide*weight;
    }
    if(totalWeight<=1e-5) { result=(HLGICacheEntry)0;return false; }
    result.irradiance/=totalWeight;result.guide/=totalWeight;
    if(dot(result.guide.xyz,result.guide.xyz)>1e-6) result.guide.xyz=normalize(result.guide.xyz);
    return true;
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
        bool lookupKnown=HLGICachedSurface((int)hit.ownerSlot,hit.position,queryNg,shadingNormal,surface,cached);
        observed.lookupIrradiance=cached.irradiance;observed.lookupGuide=cached.guide;
        observed.lookupState=float4(lookupKnown,hit.ownerSlot,hit.stableId,surface.generation);
    }
    bool directKnown;
    float3 direct=DirectIrradiance(hit.position,shadingNormal,biasNormal,_HLGI_LightingPolicies[hit.ownerSlot].xy,
        receivesShadows,incomingDirection,hitFootprint,directKnown);
    observed.direct=float4(direct,directKnown);
    if(!directKnown || !all(isfinite(diffuse)) || !all(isfinite(emission)) || !isfinite(ao)) { confidence=0;return 0; }
    float3 value=max(emission,0)*emissionWeight+clamp(diffuse,0,0.98)*(direct+ao*_HLGI_BounceFeedback*max(cached.irradiance.rgb,0));
    if(!HLGIHasRadianceMeasurement(float4(value,confidence))) { confidence=0;return 0; }
    return value;
}

bool HLGIAreaDirectionEmissionWeight(float3 origin,float3 n,float4 guide,float3 direction,HLGIHit hit,out float weight)
{
    weight=1;float lightPdf;
    uint status=HLGIAreaHitPdf(origin,hit,_HLGI_AreaMaterialGeneration,lightPdf);
    if(status==HLGI_AREA_NONE)return true;
    if(status==HLGI_AREA_UNKNOWN)return false;
    float inverseSum;
    return HLGIAreaBalance(HLGITransportDirectionPdf(origin,n,guide,direction),lightPdf,weight,inverseSum);
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

bool HLGIAreaLightContribution(float3 origin,float3 n,float4 guide,HLGIAreaSample sample,
    HLGIRayFootprint footprint,float4 materialView,out float3 value,out bool worldHit,out HLGIHit hit)
{
    value=0;worldHit=false;hit=HLGIEmptyHit(_HLGI_MaxDistance);
    float cosine=max(0,dot(n,sample.direction));
    if(cosine==0 || sample.distance>=_HLGI_MaxDistance)return true;
    float scale=max(sample.distance,max(abs(sample.position.x),max(abs(sample.position.y),abs(sample.position.z))));
    float limit=min(_HLGI_MaxDistance,sample.distance+max(1e-5,16*1.192092896e-7*scale));
    worldHit=TraceSceneHit(origin,sample.direction,limit,footprint,materialView,hit);
    if(!worldHit)return true; // Alpha hole/back side has zero contribution; never resample.
    if(!HLGIHitMaterialKnown(hit))return false;
    if(!HLGIAreaSampleMatchesHit(sample,hit,_HLGI_AreaMaterialGeneration))return true;
    if(!HLGIHitHas(hit.flags,HLGI_HIT_UV_MATERIAL) || !all(isfinite(hit.materialEmission)))return false;
    float directionWeight,inverseSum;
    if(!HLGIAreaBalance(HLGITransportDirectionPdf(origin,n,guide,sample.direction),sample.pdf,directionWeight,inverseSum))return false;
    value=max(hit.materialEmission,0)*(cosine/PI)*inverseSum;
    return all(isfinite(value));
}

bool HLGITrySurfacePatchRayFootprint(HLGISurfaceSample surface,uint2 cell,float3 direction,out HLGIRayFootprint footprint)
{
    footprint=(HLGIRayFootprint)0;
    if(!HLGISurfaceCardValid(surface.cardIndex)) return false;
    HLGISurfaceCard card=_HLGI_SurfaceCards[surface.cardIndex];
    int2 minimum,count;
    if(!HLGISurfaceAtlasRect(card.atlasRect,minimum,count)) return false;
    return HLGITryCardPatchFootprint(card.worldToCard,surface.position,surface.geometricNormal,
        (uint2)count,cell,(uint)_HLGI_CacheGrid,direction,footprint);
}

[numthreads(64,1,1)]
void CSUpdateCache(uint3 id:SV_DispatchThreadID)
{
    if(_HLGI_CacheGrid<1 || _HLGI_CacheGrid>4 || _HLGI_SurfaceCardCount<=0) return;
    uint patches=(uint)(_HLGI_CacheGrid*_HLGI_CacheGrid);
    uint count=(uint)_HLGI_SurfaceCardCount*patches;
    if(id.x>=count) return;
    observed=(EnergyObservation)0;activeNode=id.x;
    observed.dispatch=float4(_HLGI_FrameIndex,id.x,_ReadIdentity,_WriteIdentity);
    observed.source=_HLGI_Lights[0].color;observed.configuration.xyz=float3(_HLGI_GuideWeight,_HLGI_EmissiveWeight,_HLGI_AreaEmitterCount);
    uint card=id.x/patches,local=id.x%patches;
    HLGISurfaceSample surface;
    bool covered=HLGITrySurfacePatch(card,uint2(local%_HLGI_CacheGrid,local/_HLGI_CacheGrid),_HLGI_CacheGrid,surface);
    observed.status.w=covered;
    if(!covered) { _HLGI_CacheWrite[id.x]=(HLGICacheEntry)0;_EnergyOutput[id.x]=observed;return; }
    // Patch validation rejects unused/invalid owners before reading the proxy buffer.
    HLGIProxy p=_HLGI_Proxies[surface.ownerSlot];
    HLGICacheEntry e=_HLGI_CacheRead[id.x];observed.oldEntry=e;
    float3 tag=float3(p.identity.xy,_HLGI_Epoch);
    float2 change=HLGIChangeAt(surface.position);observed.change=float4(change,_HLGI_GlobalGeometryChange,_HLGI_ChangeCount);
    if(any(e.tag.xyz!=tag) || e.tag.w!=(float)surface.generation || change.x>0.5 || !HLGIHasCacheMeasurement(e.irradiance,e.guide))
        e=(HLGICacheEntry)0;
    // Nearby changes retain an estimate but shorten its history, even if this patch awaits budget.
    if(change.y>0.5) e.irradiance.a=min(e.irradiance.a,1);
    e.tag=float4(tag,surface.generation);
    float2 geometricOct=PackNormalOctQuadEncode(surface.geometricNormal);
    e.anchor=float4(surface.position,geometricOct.x);e.normal=float4(surface.normal,geometricOct.y);
    observed.preparedIrradiance=e.irradiance;observed.preparedGuide=e.guide;observed.status.z=_HLGI_CacheUpdateMask[id.x];
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
            observed.directionWeight=float4(direction,weight);
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
            observed.incoming=float4(incoming,materialConfidence);
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
        observed.status.x=estimateKnown;observed.estimate=float4(sum,guidePower);
        HLGICommitCacheEstimate(estimateKnown,sum,guide,guidePower,_HLGI_CacheRays,n,e.irradiance,e.guide);
    }
    _HLGI_CacheWrite[id.x]=e;observed.newEntry=e;observed.status.y=HLGIHasCacheMeasurement(e.irradiance,e.guide);_EnergyOutput[id.x]=observed;
}
