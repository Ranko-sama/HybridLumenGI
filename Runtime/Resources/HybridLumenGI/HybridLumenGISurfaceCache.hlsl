#ifndef HLGI_WORLD_SURFACE_CACHE_INCLUDED
#define HLGI_WORLD_SURFACE_CACHE_INCLUDED
#include "HybridLumenGIHit.hlsl"

// 128 bytes; the final uint4 identifies an explicit owner/chart/layout, not card / 6.
struct HLGISurfaceCard
{
    column_major float4x4 worldToCard;
    float4 atlasRect;
    float4 directionTolerance;
    uint stableId, revision, generation, ready;
    uint ownerSlot, chartId, layoutGeneration, flags; // bit 0: real chart; bits 1..2: chart material Cull
};
struct HLGISurfaceSample
{
    float3 position, normal, geometricNormal, diffuse, emission;
    float occlusion, roughness, confidence;
    uint cardIndex, generation, ownerSlot;
    uint2 atlasPixel;
};
Texture2D<float4> _HLGI_SurfaceDiffuse;
Texture2D<float4> _HLGI_SurfaceEmission;
Texture2D<float4> _HLGI_SurfacePosition;
Texture2D<float4> _HLGI_SurfaceNormal;
Texture2D<float4> _HLGI_SurfaceShadowmask;
float4 _HLGI_SurfaceAtlasSize;

// Shared by capture-time anchor selection and all later material/patch loads.
// No scene buffers are needed by the anchor-build kernel.
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
float3 HLGIDecodeSurfaceGeometricNormal(float packed)
{
    uint code=(uint)round(packed)-1u;
    float2 oct=float2(code&31u,(code>>5)&31u)*(2.0/31.0)-1;
    float3 normal=float3(oct,1-abs(oct.x)-abs(oct.y));
    if(normal.z<0) normal.xy=(1-abs(normal.yx))*float2(normal.x>=0?1:-1,normal.y>=0?1:-1);
    return normalize(normal);
}
bool HLGILoadSurfaceTexel(int2 pixel,out HLGISurfaceSample sample)
{
    sample=(HLGISurfaceSample)0;
    if(any(pixel<0) || any(pixel>=(int2)_HLGI_SurfaceAtlasSize.xy)) return false;
    float4 emission=_HLGI_SurfaceEmission.Load(int3(pixel,0));
    if(!all(isfinite(emission)) || emission.a<1 || emission.a>1024 || emission.a!=round(emission.a)) return false;
    float4 position=_HLGI_SurfacePosition.Load(int3(pixel,0));
    float4 normal=_HLGI_SurfaceNormal.Load(int3(pixel,0));
    float4 diffuse=_HLGI_SurfaceDiffuse.Load(int3(pixel,0));
    float normalLengthSquared=dot(normal.xyz,normal.xyz);
    if(!all(isfinite(position)) || !all(isfinite(normal)) || !all(isfinite(diffuse)) ||
        !isfinite(normalLengthSquared) || normalLengthSquared<0.25 || position.w<0 || position.w>1) return false;
    sample.position=position.xyz;
    sample.normal=normal.xyz*rsqrt(normalLengthSquared);
    sample.geometricNormal=HLGIDecodeSurfaceGeometricNormal(emission.a);
    sample.diffuse=saturate(diffuse.rgb);
    sample.emission=max(emission.rgb,0);
    sample.occlusion=saturate(diffuse.a);
    sample.roughness=saturate(normal.a);
    sample.confidence=1;
    sample.atlasPixel=(uint2)pixel;
    return true;
}

#ifndef HLGI_SURFACE_ANCHOR_SCAN
// Include the query section after HLGIProxy, _HLGI_Proxies and _HLGI_ProxyCount.
StructuredBuffer<HLGISurfaceCard> _HLGI_SurfaceCards;
StructuredBuffer<uint4> _HLGI_SurfaceOwnerRanges; // first index, count, layout generation, current geometry revision
StructuredBuffer<uint> _HLGI_SurfaceCardIndices;
StructuredBuffer<int2> _HLGI_SurfaceAnchors;
int _HLGI_SurfaceCardCount; // physical pool capacity, also the indirect index-buffer capacity

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
bool HLGILoadSurfaceSamplePixel(uint cardIndex,int2 pixel,out HLGISurfaceSample sample)
{
    sample=(HLGISurfaceSample)0;
    if(!HLGISurfaceCardValid(cardIndex)) return false;
    HLGISurfaceCard card=_HLGI_SurfaceCards[cardIndex];
    int2 minimum,count;
    if(!HLGISurfaceAtlasRect(card.atlasRect,minimum,count) || any(pixel<minimum) || any(pixel>=minimum+count)) return false;
    if(!HLGILoadSurfaceTexel(pixel,sample)) return false;
    sample.cardIndex=cardIndex;sample.generation=card.generation;sample.ownerSlot=card.ownerSlot;
    return true;
}
bool HLGILoadSurfaceSample(uint cardIndex,float2 uv,out HLGISurfaceSample sample)
{
    sample=(HLGISurfaceSample)0;
    if(!HLGISurfaceCardValid(cardIndex) || !all(isfinite(uv)) || any(uv<0) || any(uv>1)) return false;
    int2 minimum,count;
    if(!HLGISurfaceAtlasRect(_HLGI_SurfaceCards[cardIndex].atlasRect,minimum,count)) return false;
    int2 pixel=minimum+clamp((int2)floor(uv*count),0,count-1);
    return HLGILoadSurfaceSamplePixel(cardIndex,pixel,sample);
}

// The capture-time scan selects one real covered texel per cell. Lookup is O(1),
// including sparse/edge coverage whose cell center itself is not rasterized.
bool HLGITrySurfacePatch(uint cardIndex,uint2 cell,uint gridSize,out HLGISurfaceSample sample)
{
    sample=(HLGISurfaceSample)0;
    if(gridSize==0u || gridSize>4u || any(cell>=gridSize) || !HLGISurfaceCardValid(cardIndex)) return false;
    int2 minimum,count;
    if(!HLGISurfaceAtlasRect(_HLGI_SurfaceCards[cardIndex].atlasRect,minimum,count)) return false;
    int2 begin=minimum+(int2)cell*count/(int)gridSize;
    int2 end=minimum+((int2)cell+1)*count/(int)gridSize;
    int2 pixel=_HLGI_SurfaceAnchors[cardIndex*gridSize*gridSize+cell.y*gridSize+cell.x];
    if(any(pixel<begin) || any(pixel>=end)) return false;
    return HLGILoadSurfaceSamplePixel(cardIndex,pixel,sample);
}
float HLGISurfaceCullFacing(uint flags,float rawFacing)
{
    // A real chart records its original submesh Cull mode. CullFront changes
    // the capture side, never the source winding normal stored in the atlas.
    // Legacy six-view cards can contain several submeshes/Cull modes; their
    // orientation remains approximate and candidate Ng still has to agree.
    if((flags&1u)==0u) return abs(rawFacing);
    uint cull=(flags>>1u)&3u;
    return cull==1u?-rawFacing:cull==0u?abs(rawFacing):rawFacing;
}
// The lookup normal is geometric identity, never a normal-map shading normal.
// Return sample.normal (Ns) separately from sample.geometricNormal (Ng): callers
// use Ns for lighting and Ng for card selection, depth checks, and ray offsets.
bool HLGITrySurfaceMaterial(int slot,float3 position,float3 geometricNormal,out HLGISurfaceSample sample)
{
    sample=(HLGISurfaceSample)0;
    float geometricLengthSquared=dot(geometricNormal,geometricNormal);
    if(!all(isfinite(position)) || !all(isfinite(geometricNormal)) ||
        !isfinite(geometricLengthSquared) || geometricLengthSquared<1e-10) return false;
    geometricNormal*=rsqrt(geometricLengthSquared);
    uint4 range;
    if(!HLGISurfaceOwnerRange(slot,range)) return false;
    float best=0;
    [loop] for(uint ordinal=0u;ordinal<range.y;ordinal++)
    {
        uint cardIndex=_HLGI_SurfaceCardIndices[range.x+ordinal];
        if(cardIndex>=(uint)_HLGI_SurfaceCardCount) continue;
        HLGISurfaceCard card=_HLGI_SurfaceCards[cardIndex];
        // chartId is a stable chart identity, not an ordinal into the indirect array.
        if(card.ownerSlot!=(uint)slot || card.layoutGeneration!=range.z || !HLGISurfaceCardValid(cardIndex)) continue;
        float facing=dot(card.directionTolerance.xyz,geometricNormal);
        facing=HLGISurfaceCullFacing(card.flags,facing);
        if(facing<=0.05) continue;
        float3 projected=mul(card.worldToCard,float4(position,1)).xyz;
        if(!all(isfinite(projected)) || any(projected<0) || any(projected>1)) continue;
        HLGISurfaceSample candidate;
        if(!HLGILoadSurfaceSample(cardIndex,projected.xy,candidate)) continue;
        float3 delta=candidate.position-position;
        float tolerance=max(card.directionTolerance.w,0.002);
        float distanceSquared=dot(delta,delta);
        float agreement=dot(candidate.geometricNormal,geometricNormal);
        // Reject another depth layer or disconnected surface of the same owner.
        if(distanceSquared>tolerance*tolerance || agreement<0.2 ||
            abs(dot(delta,geometricNormal))>max(0.002,tolerance*0.3)) continue;
        float depthScale=max(length(card.worldToCard[2].xyz),1e-8);
        float capturedDepth=_HLGI_SurfacePosition.Load(int3(candidate.atlasPixel,0)).w;
        float depthError=abs(capturedDepth-projected.z)/depthScale;
        if(depthError>tolerance) continue;
        float score=facing*agreement*saturate(1-distanceSquared/(tolerance*tolerance));
        if(score>best){candidate.confidence=score;sample=candidate;best=score;}
    }
    return best>0;
}
// A triangle hit has an explicit geometry/chart binding. Its material lookup
// must never resolve a different chart merely because that texel is closer.
// Failure leaves fallback material policy to the hit's original submesh caller.
bool HLGITrySurfaceMaterialHit(HLGIHit hit,out HLGISurfaceSample sample)
{
    sample=(HLGISurfaceSample)0;
    if(!HLGIHitHas(hit.flags,HLGI_HIT_VALID|HLGI_HIT_GEOMETRIC_NORMAL) ||
        hit.ownerSlot>=(uint)_HLGI_ProxyCount || !all(isfinite(hit.position)) || !all(isfinite(hit.rawNg))) return false;
    float normalLengthSquared=dot(hit.rawNg,hit.rawNg);
    if(!isfinite(normalLengthSquared)||normalLengthSquared<1e-10) return false;
    float3 rawNg=hit.rawNg*rsqrt(normalLengthSquared);
    HLGIProxy proxy=_HLGI_Proxies[hit.ownerSlot];
    if(proxy.identity.w<0.5 || proxy.identity.w>=1.5 ||
        (uint)proxy.identity.x!=hit.stableId || (uint)proxy.identity.y!=hit.ownerRevision) return false;
    uint4 range;
    if(!HLGISurfaceOwnerRange((int)hit.ownerSlot,range)||range.w==0u||range.w!=hit.geometryRevision) return false;
    bool isTriangle=hit.representation==HLGI_REPRESENTATION_TRIANGLE || HLGIHitHas(hit.flags,HLGI_HIT_TRIANGLE);
    if(!isTriangle)
    {
        if(hit.representation==HLGI_REPRESENTATION_UNSIGNED_SDF)
        {
            // A shell gradient has no stable authored side. Two explicit
            // approximate searches do not manufacture triangle/front-face flags.
            HLGISurfaceSample positive,negative;
            bool hasPositive=HLGITrySurfaceMaterial((int)hit.ownerSlot,hit.position,rawNg,positive);
            bool hasNegative=HLGITrySurfaceMaterial((int)hit.ownerSlot,hit.position,-rawNg,negative);
            if(!hasPositive&&!hasNegative) return false;
            if(hasPositive) sample=positive;else sample=negative;
            if(hasNegative && (!hasPositive || negative.confidence>positive.confidence)) sample=negative;
            sample.confidence*=0.25;return true;
        }
        if(hit.representation!=HLGI_REPRESENTATION_SIGNED_SDF && hit.representation!=HLGI_REPRESENTATION_ANALYTIC) return false;
        if(!HLGIHitHas(hit.flags,HLGI_HIT_ORIENTED_NG)) return false;
        // Signed-SDF/analytic identity remains explicitly approximate.
        bool approximate=HLGITrySurfaceMaterial((int)hit.ownerSlot,hit.position,rawNg,sample);
        if(approximate) sample.confidence*=0.5;
        return approximate;
    }
    if(hit.representation!=HLGI_REPRESENTATION_TRIANGLE ||
        !HLGIHitHas(hit.flags,HLGI_HIT_TRIANGLE|HLGI_HIT_SURFACE_BINDING|HLGI_HIT_ORIENTED_NG) ||
        hit.submesh==0xffffffffu || hit.primitive==0xffffffffu || hit.hardwareInstance==0xffffffffu ||
        hit.surfaceBinding.w!=hit.geometryRevision || hit.surfaceBinding.z!=range.z) return false;
    uint cardIndex=hit.surfaceBinding.x;
    if(!HLGISurfaceCardValid(cardIndex)) return false;
    HLGISurfaceCard card=_HLGI_SurfaceCards[cardIndex];
    if(card.ready!=1u || (card.flags&1u)==0u || card.ownerSlot!=hit.ownerSlot ||
        card.stableId!=hit.stableId || card.revision!=hit.ownerRevision ||
        card.chartId!=hit.surfaceBinding.y || card.layoutGeneration!=hit.surfaceBinding.z) return false;
    float facing=HLGISurfaceCullFacing(card.flags,dot(card.directionTolerance.xyz,rawNg));
    if(facing<=0.05) return false;
    float3 projected=mul(card.worldToCard,float4(hit.position,1)).xyz;
    if(!all(isfinite(projected))||any(projected<0)||any(projected>1)) return false;
    HLGISurfaceSample candidate;
    if(!HLGILoadSurfaceSample(cardIndex,projected.xy,candidate)) return false;
    float3 delta=candidate.position-hit.position;
    float tolerance=max(card.directionTolerance.w,0.002);
    float distanceSquared=dot(delta,delta),agreement=dot(candidate.geometricNormal,rawNg);
    if(distanceSquared>tolerance*tolerance || agreement<0.2 ||
        abs(dot(delta,rawNg))>max(0.002,tolerance*0.3)) return false;
    float depthScale=max(length(card.worldToCard[2].xyz),1e-8);
    float capturedDepth=_HLGI_SurfacePosition.Load(int3(candidate.atlasPixel,0)).w;
    if(abs(capturedDepth-projected.z)/depthScale>tolerance) return false;
    candidate.confidence=facing*agreement*saturate(1-distanceSquared/(tolerance*tolerance));
    sample=candidate;return true;
}
#endif
#endif
