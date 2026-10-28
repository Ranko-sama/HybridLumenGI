HLGIRayFootprint HLGIPointQueryFootprint()
{ HLGIRayFootprint value;HLGITryMakeRayFootprint(0,0,value);return value; }

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
    observedWeight=observedTotal=0;observedAccepted=observedExit=observedQueries=0;observedCellFraction=0;
    result=(HLGICacheEntry)0;
    HLGIProxy p=_HLGI_Proxies[index];
    float2 uv;
    if(!HLGISurfaceCardUv(surface.cardIndex,position,uv)) { observedExit=1;return false; }
    float2 patchPosition=uv*_HLGI_CacheGrid-0.5;
    int2 baseCell=(int2)floor(patchPosition);
    float2 fraction=frac(patchPosition); float totalWeight=0;
    observedCellFraction=float4(baseCell,fraction);
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
        observedWeight=weight;observedTotal=totalWeight;observedAccepted++;
    }
    if(totalWeight<=1e-5) { observedExit=2;return false; }
    result.irradiance/=totalWeight;result.guide/=totalWeight;
    if(dot(result.guide.xyz,result.guide.xyz)>1e-6) result.guide.xyz=normalize(result.guide.xyz);
    observedExit=3;return true;
}

bool HLGICachedSample(HLGIHit hit,float3 shadingNormal,out HLGICacheEntry result)
{
    result=(HLGICacheEntry)0;
    if(!HLGIHitOwnerCurrent(hit) || !HLGIHitMaterialKnown(hit)) return false;
    HLGISurfaceSample surface;
    if(!HLGITrySurfaceMaterialHit(hit,surface)) return false;
    // Unsigned SDF gradients have no stable source orientation. Once material is
    // approximately resolved, use that sample's recorded Ng for its cache plane.
    float3 geometricNormal=HLGIHitHas(hit.flags,HLGI_HIT_ORIENTED_NG)?hit.rawNg:surface.geometricNormal;
    return HLGICachedSurface((int)hit.ownerSlot,hit.position,geometricNormal,shadingNormal,surface,result);
}

float3 CachedIrradiance(HLGIHit hit,float3 shadingNormal)
{
    HLGICacheEntry entry;
    return HLGICachedSample(hit,shadingNormal,entry)?max(entry.irradiance.rgb,0):0;
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

uint HLGIEmissiveProposalCount()
{
    float count=_HLGI_EmissiveProposals[0].data.x;
    return isfinite(count) && count>=1 && count<=32 && count==floor(count) ? (uint)count:0u;
}

float HLGITransportDirectionPdf(float3 origin,float3 normal,float4 guide,float3 direction)
{
    uint count=HLGIEmissiveProposalCount();
    float emissive=count>0u && isfinite(_HLGI_EmissiveWeight)?clamp(_HLGI_EmissiveWeight,0,0.8):0;
    if(emissive<=0)
    {
        // Match HLGISampleDirection's original branch exactly. Config constrains
        // guide weight to [0,.8]; do not silently use a different selection PMF.
        float mixture=guide.w>1e-6 && dot(guide.xyz,guide.xyz)>0.5?_HLGI_GuideWeight:0;
        float3 axis=mixture>0?normalize(guide.xyz):normal;
        return ((1-mixture)*saturate(dot(normal,direction))+mixture*saturate(dot(axis,direction)))/PI;
    }
    bool validGuide=all(isfinite(guide)) && guide.w>1e-6 && dot(guide.xyz,guide.xyz)>0.5 && isfinite(dot(guide.xyz,guide.xyz));
    float guideFraction=validGuide && isfinite(_HLGI_GuideWeight)?clamp(_HLGI_GuideWeight,0,0.8):0;
    float3 guideAxis=guideFraction>0?normalize(guide.xyz):normal;
    return (1-emissive)*((1-guideFraction)*saturate(dot(normal,direction))+
        guideFraction*saturate(dot(guideAxis,direction)))/PI+
        emissive*HLGIEmissiveDirectionalPdf(origin,direction,count);
}
