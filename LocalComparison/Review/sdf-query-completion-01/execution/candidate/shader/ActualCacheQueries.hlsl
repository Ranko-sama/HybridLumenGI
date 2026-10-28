bool HLGIHitOwnerCurrent(HLGIHit hit)
{
    if(!HLGIHitHas(hit.flags,HLGI_HIT_VALID) || hit.ownerSlot>=(uint)_HLGI_ProxyCount) return false;
    HLGIProxy proxy=_HLGI_Proxies[hit.ownerSlot];
    return proxy.identity.w>0.5 && proxy.identity.w<1.5 &&
        hit.stableId==(uint)proxy.identity.x && hit.ownerRevision==(uint)proxy.identity.y;
}
bool HLGICachedSurface(int index,float3 position,float3 geometricNormal,float3 shadingNormal,
    HLGISurfaceSample surface,out HLGICacheEntry result,out bool known)
{
    known=true;
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
        float weight=(x==0?1-fraction.x:fraction.x)*(y==0?1-fraction.y:fraction.y);
        if(weight<=0)continue;
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
                HLGIPointQueryFootprint(),float4(position,1),blocker))
            {
                // An unfinished connection is not a proven occluded tap. Do
                // not discard it and renormalize the remaining interpolation.
                if(HLGIHitQueryUnresolved(blocker)) { known=false;result=(HLGICacheEntry)0;return false; }
                continue;
            }
        }
        totalWeight+=weight;result.irradiance+=e.irradiance*weight;result.guide+=e.guide*weight;
    }
    if(totalWeight<=1e-5) { result=(HLGICacheEntry)0;return false; }
    result.irradiance/=totalWeight;result.guide/=totalWeight;
    if(dot(result.guide.xyz,result.guide.xyz)>1e-6) result.guide.xyz=normalize(result.guide.xyz);
    return true;
}
bool HLGICachedSample(HLGIHit hit,float3 shadingNormal,out HLGICacheEntry result,out bool known)
{
    known=!HLGIHitQueryUnresolved(hit);
    result=(HLGICacheEntry)0;
    if(!HLGIHitOwnerCurrent(hit) || !HLGIHitMaterialKnown(hit)) return false;
    HLGISurfaceSample surface;
    if(!HLGITrySurfaceMaterialHit(hit,surface)) return false;
    // Unsigned SDF gradients have no stable source orientation. Once material is
    // approximately resolved, use that sample's recorded Ng for its cache plane.
    float3 geometricNormal=HLGIHitHas(hit.flags,HLGI_HIT_ORIENTED_NG)?hit.rawNg:surface.geometricNormal;
    return HLGICachedSurface((int)hit.ownerSlot,hit.position,geometricNormal,shadingNormal,surface,result,known);
}
bool HLGICachedSample(HLGIHit hit,float3 shadingNormal,out HLGICacheEntry result)
{ bool known;return HLGICachedSample(hit,shadingNormal,result,known); }
float3 CachedIrradiance(HLGIHit hit,float3 shadingNormal,out bool known)
{
    HLGICacheEntry entry;
    return HLGICachedSample(hit,shadingNormal,entry,known)?max(entry.irradiance.rgb,0):0;
}
