#ifndef HLGI_AREA_EMISSION_INCLUDED
#define HLGI_AREA_EMISSION_INCLUDED
#include "HybridLumenGIHit.hlsl"

// Uniform area sampling of prepared triangles. These are actual endpoints, not
// the vMF directional proposals. The matching trace still evaluates source UV,
// alpha, Cull, parallax, textures and the nearest blocker; this table contains no Le.
struct HLGIAreaEmitter
{
    float4 p0,p1,p2,rawNg;
    uint4 identity; // owner, stable ID, owner revision, geometry revision
    uint4 geometry; // instance, submesh, primitive, material generation
};
StructuredBuffer<HLGIAreaEmitter> _HLGI_AreaEmitters;
int _HLGI_AreaEmitterCount;
#define HLGI_AREA_NONE 0u
#define HLGI_AREA_SAMPLE 1u
#define HLGI_AREA_UNKNOWN 2u
struct HLGIAreaSample
{
    HLGIAreaEmitter emitter;
    float3 position,direction;
    float distance,pdf;
    uint index;
};

uint HLGIAreaEmitterCount()
{
    if(_HLGI_AreaEmitterCount<=0)return 0u;
    uint count,stride;_HLGI_AreaEmitters.GetDimensions(count,stride);
    return stride==96u && (uint)_HLGI_AreaEmitterCount<=count && _HLGI_AreaEmitterCount<=262144?
        (uint)_HLGI_AreaEmitterCount:0u;
}

bool HLGIAreaEmitterValid(HLGIAreaEmitter e)
{
    float normalSquared=dot(e.rawNg.xyz,e.rawNg.xyz);
    return all(isfinite(e.p0)) && all(isfinite(e.p1)) && all(isfinite(e.p2)) && all(isfinite(e.rawNg)) &&
        e.p0.w>0 && e.p1.w>=0 && e.p2.w<=1 && e.p2.w>e.p1.w &&
        normalSquared>0.5 && normalSquared<1.5 && e.identity.x!=0xffffffffu &&
        all(e.identity.yzw!=0u) && e.geometry.w!=0u;
}

// Area density PMF/A transformed to solid angle at the SAME biased ray origin.
// Finite representation failures are unknown, not transparent or discarded draws.
uint HLGIAreaSolidAnglePdf(HLGIAreaEmitter e,float3 origin,float3 targetPosition,
    out float3 direction,out float distance,out float pdf)
{
    direction=0;distance=0;pdf=0;
    if(!HLGIAreaEmitterValid(e) || !all(isfinite(origin)) || !all(isfinite(targetPosition)))return HLGI_AREA_UNKNOWN;
    float3 delta=targetPosition-origin;
    if(!all(isfinite(delta)))return HLGI_AREA_UNKNOWN;
    float scale=max(abs(delta.x),max(abs(delta.y),abs(delta.z)));
    if(scale==0)return HLGI_AREA_NONE;
    float3 scaled=delta/scale;float scaledLength=length(scaled);
    direction=scaled/scaledLength;distance=scale*scaledLength;
    if(!isfinite(distance) || distance<=0 || !all(isfinite(direction)))return HLGI_AREA_UNKNOWN;
    float projectedCosine=abs(dot(normalize(e.rawNg.xyz),-direction));
    if(projectedCosine==0)return HLGI_AREA_NONE;
    float pmf=e.p2.w-e.p1.w;
    pdf=((pmf/e.p0.w)*distance)*distance/projectedCosine;
    // Rescale only when an intermediate product over/underflowed. This preserves
    // finite extreme PDFs without interpreting a numerical failure as zero support.
    if(!isfinite(pdf) || pdf<=0)
        pdf=exp2(log2(pmf)-log2(e.p0.w)+2*log2(distance)-log2(projectedCosine));
    return isfinite(pdf) && pdf>0?HLGI_AREA_SAMPLE:HLGI_AREA_UNKNOWN;
}

uint HLGISampleAreaEmitter(float3 origin,float3 xi,out HLGIAreaSample sample)
{
    sample=(HLGIAreaSample)0;
    if(_HLGI_AreaEmitterCount<=0)return HLGI_AREA_NONE;
    uint count=HLGIAreaEmitterCount();
    if(count==0u || !all(isfinite(xi)) || any(xi<0) || any(xi>=1))return HLGI_AREA_UNKNOWN;
    uint lo=0u,hi=count;
    // Sorted, contiguous CDF. Empty intervals were removed by the CPU builder.
    [loop] while(lo<hi)
    {
        uint mid=lo+(hi-lo)/2u;
        if(xi.x<_HLGI_AreaEmitters[mid].p2.w)hi=mid;else lo=mid+1u;
    }
    if(lo>=count)return HLGI_AREA_UNKNOWN;
    HLGIAreaEmitter e=_HLGI_AreaEmitters[lo];
    if(!HLGIAreaEmitterValid(e) || xi.x<e.p1.w || xi.x>=e.p2.w)return HLGI_AREA_UNKNOWN;
    float root=sqrt(xi.y);
    float3 bary=float3(1-root,root*(1-xi.z),root*xi.z);
    sample.emitter=e;sample.index=lo;
    sample.position=e.p0.xyz*bary.x+e.p1.xyz*bary.y+e.p2.xyz*bary.z;
    return HLGIAreaSolidAnglePdf(e,origin,sample.position,sample.direction,sample.distance,sample.pdf);
}

bool HLGIAreaEmitterMatchesHit(HLGIAreaEmitter e,HLGIHit hit,uint materialGeneration)
{
    return (hit.flags&(HLGI_HIT_VALID|HLGI_HIT_TRIANGLE))==(HLGI_HIT_VALID|HLGI_HIT_TRIANGLE) &&
        all(e.identity==uint4(hit.ownerSlot,hit.stableId,hit.ownerRevision,hit.geometryRevision)) &&
        all(e.geometry==uint4(hit.hardwareInstance,hit.submesh,hit.primitive,materialGeneration));
}

bool HLGIAreaSampleMatchesHit(HLGIAreaSample sample,HLGIHit hit,uint materialGeneration)
{
    if(!HLGIAreaEmitterMatchesHit(sample.emitter,hit,materialGeneration) ||
        !all(isfinite(hit.position)) || !isfinite(hit.t))return false;
    // Same primitive is essential: a closer opaque layer, even of the same owner,
    // must not evaluate the selected emitter. Tolerance only absorbs float32 transforms.
    float scale=max(sample.distance,max(abs(sample.position.x),max(abs(sample.position.y),abs(sample.position.z))));
    float tolerance=max(1e-5,16*1.192092896e-7*scale);
    return abs(hit.t-sample.distance)<=tolerance && all(abs(hit.position-sample.position)<=tolerance);
}

// Return NONE for an unlisted endpoint (the direction estimate keeps weight one),
// UNKNOWN for a stale matching key or invalid numeric conversion. Never guess an
// SDF/analytic/screen endpoint's primitive from a nearby targetPosition or a matching owner.
uint HLGIAreaHitPdf(float3 origin,HLGIHit hit,uint materialGeneration,out float pdf)
{
    pdf=0;
    if(_HLGI_AreaEmitterCount<=0 || (hit.flags&HLGI_HIT_TRIANGLE)==0u)return HLGI_AREA_NONE;
    uint count=HLGIAreaEmitterCount();if(count==0u)return HLGI_AREA_UNKNOWN;
    uint lo=0u,hi=count;
    [loop] while(lo<hi)
    {
        uint mid=lo+(hi-lo)/2u;uint4 key=_HLGI_AreaEmitters[mid].geometry;
        bool less=key.x<hit.hardwareInstance || (key.x==hit.hardwareInstance && key.z<hit.primitive);
        if(less)lo=mid+1u;else hi=mid;
    }
    if(lo>=count)return HLGI_AREA_NONE;
    HLGIAreaEmitter e=_HLGI_AreaEmitters[lo];
    if(e.geometry.x!=hit.hardwareInstance || e.geometry.z!=hit.primitive)return HLGI_AREA_NONE;
    if(!HLGIAreaEmitterMatchesHit(e,hit,materialGeneration))return HLGI_AREA_UNKNOWN;
    float3 direction;float distance;
    return HLGIAreaSolidAnglePdf(e,origin,hit.position,direction,distance,pdf);
}

// One direction sample AND one area sample per loop. Only emitted radiance is
// paired. All reflected/direct/cache radiance retains its original direction weight.
// The light estimate is Le * receiverCosine / PI * inversePdfSum. Do not add Le again.
bool HLGIAreaBalance(float directionPdf,float areaPdf,out float directionWeight,out float inversePdfSum)
{
    directionWeight=1;inversePdfSum=0;
    if(!isfinite(directionPdf)||!isfinite(areaPdf)||directionPdf<0||areaPdf<0)return false;
    float scale=max(directionPdf,areaPdf);if(scale<=0)return false;
    // Shader division can become multiplication by a reciprocal which flushes
    // subnormal 1/scale to zero. Bring both densities into a normal intermediate
    // range first, preserving their ratio even near float32's largest finite value.
    float factor=scale>1e20?1e-20:(scale<1e-20?1e20:1);
    precise float a=directionPdf*factor,b=areaPdf*factor;
    precise float denominator=a+b;
    directionWeight=a/denominator;
    inversePdfSum=factor/denominator;
    return isfinite(inversePdfSum) && inversePdfSum>=0;
}
#endif
