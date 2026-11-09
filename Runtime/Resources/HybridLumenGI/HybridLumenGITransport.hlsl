#ifndef HLGI_TRANSPORT_INCLUDED
#define HLGI_TRANSPORT_INCLUDED
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "HybridLumenGIRadianceValidity.hlsl"
#include "HybridLumenGIRayFootprint.hlsl"

// Cached quantity D = irradiance / pi in linear URP units. Cosine sampling has unit weight.
struct HLGIProxy { float4 centerShape, extentsRoughness, albedo, emission, identity; };
struct HLGILight
{
    float4 positionType; // 0 directional, 1 point, 2 spot
    float4 directionRange;
    float4 color;
    float4 spot; // cos outer, reciprocal(cos inner - cos outer), shadow strength, reserved
    uint4 masks; // GameObject culling, illumination layers, shadow layers, flags(bit0: layers enabled)
};
// Irradiance alpha: zero is unknown, 0.5 is a valid measurement awaiting a
// global-light replacement, and values >=1 hold the history/readiness weight.
// Total D and the emission/environment-origin subset share one measurement age.
// The second RGB is carried directly through the same rays, never subtracted.
// Its alpha marks a visibility refresh pending on a retained measurement.
struct HLGICacheEntry { float4 irradiance; float4 tag; float4 anchor; float4 normal; float4 guide; float4 nonAnalyticIrradiance; };
StructuredBuffer<HLGIProxy> _HLGI_Proxies;
StructuredBuffer<HLGILight> _HLGI_Lights;
StructuredBuffer<HLGICacheEntry> _HLGI_CacheRead;
RWStructuredBuffer<HLGICacheEntry> _HLGI_CacheWrite;
int _HLGI_ProxyCount, _HLGI_LightCount, _HLGI_Epoch, _HLGI_FrameIndex;
int _HLGI_NonAnalyticOnlyChannels;
#if defined(HLGI_CACHE_UPDATE_ITERATION)
float _HLGI_PointLightDimScale;
#endif
int _HLGI_CacheGrid, _HLGI_CacheRays;
StructuredBuffer<uint> _HLGI_CacheUpdateMask;
float _HLGI_GuideWeight;
float _HLGI_MaxDistance, _HLGI_ShadowDistance, _HLGI_RayBias, _HLGI_BounceFeedback;
float4 _HLGI_Environment;
TextureCube<float4> _HLGI_EnvironmentCube;
SamplerState sampler_HLGIEnvironment_LinearClamp;
int _HLGI_EnvironmentCubeEnabled;
float3 HLGIEnvironmentRadiance(float3 direction)
{
    // Li along the escaping world ray; existing sampling weights produce D=E/pi.
    // Leave nonfinite samples intact for the existing measurement guards.
    return _HLGI_EnvironmentCubeEnabled!=0 ?
        _HLGI_EnvironmentCube.SampleLevel(sampler_HLGIEnvironment_LinearClamp,direction,0).rgb : _HLGI_Environment.rgb;
}
float3 HLGIActiveCacheIrradiance(float3 total,float3 nonAnalytic)
{
    if(_HLGI_LightCount==0) return nonAnalytic;
#if defined(HLGI_CACHE_UPDATE_ITERATION)
    // Both inputs are old-pool estimates. Only the analytic share responds to
    // the dimming. Gather reads the already adjusted current pool.
    if(_HLGI_PointLightDimScale>0) total=lerp(nonAnalytic,total,_HLGI_PointLightDimScale);
#endif
    return float3((_HLGI_NonAnalyticOnlyChannels&1)!=0?nonAnalytic.r:total.r,
                  (_HLGI_NonAnalyticOnlyChannels&2)!=0?nonAnalytic.g:total.g,
                  (_HLGI_NonAnalyticOnlyChannels&4)!=0?nonAnalytic.b:total.b);
}
#include "HybridLumenGILightingPolicy.hlsl"
#include "HybridLumenGISdfTrace.hlsl"
#include "HybridLumenGISceneBvh.hlsl"
#include "HybridLumenGIChanges.hlsl"
#include "HybridLumenGISurfaceCache.hlsl"
#include "HybridLumenGIGlobalSdf.hlsl"
int _HLGI_GlobalSdfEnabled;
float _HLGI_DetailTraceDistance;

uint HLGIHash(uint x)
{
    x ^= x >> 16; x *= 0x7feb352du; x ^= x >> 15; x *= 0x846ca68bu; return x ^ (x >> 16);
}
float Random(inout uint s) { s = HLGIHash(s); return (s >> 8) * (1.0 / 16777216.0); }
float3 CosineHemisphere(float3 n, float2 xi)
{
    float r = sqrt(xi.x), phi = TWO_PI * xi.y;
    float3 t = normalize(cross(abs(n.z) < 0.999 ? float3(0,0,1) : float3(0,1,0), n));
    return t * (r * cos(phi)) + cross(n,t) * (r * sin(phi)) + n * sqrt(1-xi.x);
}
float3 HLGISampleDirection(float3 n,float4 guide,inout uint rng,out float weight)
{
    float mixture=guide.w>1e-6 && dot(guide.xyz,guide.xyz)>0.5 ? _HLGI_GuideWeight:0;
    float3 axis=mixture>0 ? normalize(guide.xyz):n;
    float branch=Random(rng);
    float2 xi=float2(Random(rng),Random(rng));
    float3 direction=CosineHemisphere(branch<mixture?axis:n,xi);
    float cosine=saturate(dot(n,direction)), guidedCosine=saturate(dot(axis,direction));
    // One-sample mixture estimator: full mixture PDF, including the branch not chosen.
    // Samples below the receiver hemisphere have zero contribution, never get resampled.
    weight=cosine/max((1-mixture)*cosine+mixture*guidedCosine,1e-8);
    return direction;
}
#include "HybridLumenGIEmissiveSampling.hlsl"
#include "HybridLumenGIAreaEmission.hlsl"
uint _HLGI_AreaMaterialGeneration;
bool IntersectProxy(float3 o, float3 d, int slot, float limit, out float t, out float3 n)
{
    HLGIProxy p = _HLGI_Proxies[slot];
    t = limit; n = 0;
    float3 local = o - p.centerShape.xyz;
    if (p.centerShape.w > 0.5)
    {
        float radius = max(p.extentsRoughness.x, max(p.extentsRoughness.y,p.extentsRoughness.z));
        float b = dot(local,d), c = dot(local,local) - radius*radius;
        float disc = b*b-c;
        if (disc < 0) return false;
        float root = sqrt(disc); t = -b-root;
        if (t <= 1e-4) t = -b+root;
        if (t <= 1e-4 || t >= limit) return false;
        n = normalize(local + d*t); return true;
    }
    float3x3 worldToAxes;
    float3 halfSize;
    bool oriented = HLGIColliderBoxFrame(slot, p, worldToAxes, halfSize);
    if (oriented)
    {
        local = mul(worldToAxes, local);
        d = mul(worldToAxes, d);
    }
    float enter = -1e20, leave = 1e20;
    float3 enterN = 0, leaveN = 0;
    [unroll] for (int axis=0; axis<3; axis++)
    {
        if (abs(d[axis]) < 1e-7)
        {
            if (abs(local[axis]) > halfSize[axis]) return false;
            continue;
        }
        float a = (-halfSize[axis]-local[axis])/d[axis];
        float b = ( halfSize[axis]-local[axis])/d[axis];
        float3 axisN = 0; axisN[axis] = d[axis]>0 ? -1 : 1;
        if (min(a,b)>enter) { enter=min(a,b); enterN=axisN; }
        if (max(a,b)<leave) { leave=max(a,b); leaveN=-axisN; }
    }
    if (leave < max(enter,0)) return false;
    bool inside = enter <= 1e-4;
    t = inside ? leave : enter; n = inside ? leaveN : enterN;
    if (oriented) n = mul(n, worldToAxes);
    return t > 1e-4 && t < limit;
}
#if defined(HLGI_INLINE_RT)
#include "HybridLumenGIHardwareTrace.hlsl"
#elif defined(HLGI_SOFTWARE_TRIANGLES)
#include "HybridLumenGISoftwareTriangleBvh.hlsl"
#endif
// A deliberate point query, for geometric visibility/legacy callers. An unknown
// filtered footprint must remain invalid instead of passing through this helper.
HLGIRayFootprint HLGIPointQueryFootprint()
{ HLGIRayFootprint value;HLGITryMakeRayFootprint(0,0,value);return value; }
bool TraceSceneDetailQuery(float3 o,float3 d,float maxT,bool shadowQuery,bool resolveMaterial,uint cullingMask,uint shadowRenderingLayers,bool useRenderingLayers,
    HLGIRayFootprint footprint,float4 materialView,out HLGIHit result)
{
    result=HLGIEmptyHit(maxT);
#if defined(HLGI_INLINE_RT)
    HLGIHardwareTraceQuery(o,d,maxT,shadowQuery,resolveMaterial,cullingMask,shadowRenderingLayers,useRenderingLayers,
        footprint.valid==1u?footprint.radius:-1,footprint.slope,materialView,result);
#elif defined(HLGI_SOFTWARE_TRIANGLES)
    HLGISoftwareTraceQuery(o,d,maxT,shadowQuery,resolveMaterial,cullingMask,shadowRenderingLayers,useRenderingLayers,
        footprint.valid==1u?footprint.radius:-1,footprint.slope,materialView,result);
#endif
#if defined(HLGI_INLINE_RT) || defined(HLGI_SOFTWARE_TRIANGLES)
    // Bound with this dispatch's mesh flags. With no published fallback owner,
    // every leaf below would be skipped; retain the exact query's hit/miss/unknown.
    if(_HLGI_ExactCoversPublished!=0) return HLGIHitHas(result.flags,HLGI_HIT_VALID);
#endif
    uint cursor=0;
    [loop] while(cursor<(uint)_HLGI_SceneBvhCount)
    {
        int i=HLGIBvhNextLeaf(cursor,o,d,result.t);
        if(i<0) break;
        if(_HLGI_Proxies[i].identity.w < 0.5 || _HLGI_Proxies[i].identity.w >= 1.5) continue;
        if(shadowQuery && !HLGIShadowOwnerAllowed((uint)i,cullingMask,shadowRenderingLayers,useRenderingLayers)) continue;
#if defined(HLGI_INLINE_RT) || defined(HLGI_SOFTWARE_TRIANGLES)
        if (HLGIHardwareHasMesh(i)) continue;
#endif
        HLGIHit candidate=HLGIEmptyHit(result.t);
        bool found;
        if(HLGIHasMeshSdf(i)) found=HLGITraceMeshSdfHit(o,d,result.t,i,candidate);
        else
        {
            float distanceHit;float3 normal;
            found=IntersectProxy(o,d,i,result.t,distanceHit,normal);
            if(found)
            {
                candidate.t=distanceHit;candidate.position=o+d*distanceHit;
                candidate.rawNg=candidate.shadingNormal=normal;
                candidate.ownerSlot=(uint)i;
                candidate.stableId=(uint)_HLGI_Proxies[i].identity.x;
                candidate.ownerRevision=(uint)_HLGI_Proxies[i].identity.y;
                candidate.representation=HLGI_REPRESENTATION_ANALYTIC;
                candidate.flags=HLGI_HIT_VALID|HLGI_HIT_GEOMETRIC_NORMAL|HLGI_HIT_ORIENTED_NG|HLGI_HIT_FRONT_FACE_KNOWN;
                if(dot(normal,d)<0) candidate.flags|=HLGI_HIT_FRONT_FACE;
            }
        }
        if(found)
        {
            // Software geometry already matched the current scene owner/revision.
            // Carry that owner's current surface geometry version if resident;
            // this version is not a primitive/front-face/material identity.
            uint4 surfaceRange;
            if(!HLGIHitQueryUnresolved(candidate) && HLGISurfaceOwnerRange(i,surfaceRange)) candidate.geometryRevision=surfaceRange.w;
            result=candidate;
        }
    }
    return HLGIHitHas(result.flags,HLGI_HIT_VALID);
}
bool TraceSceneQuery(float3 o,float3 d,float maxT,bool shadowQuery,bool resolveMaterial,uint cullingMask,uint shadowRenderingLayers,bool useRenderingLayers,
    HLGIRayFootprint footprint,float4 materialView,out HLGIHit result)
{
    float detailLimit=_HLGI_GlobalSdfEnabled!=0?min(maxT,_HLGI_DetailTraceDistance):maxT;
    float advance=0;
    HLGIRayFootprint queryFootprint=footprint;
    // Keep one detailed traversal call site. DXC inlines this entire geometry /
    // material query; separate fast/near/far call sites multiplied it at every
    // visibility and radiance caller, exceeding Unity's compiler timeout.
    [loop] for(int segment=0;segment<2;segment++)
    {
        float limit=segment==0?detailLimit:maxT-advance;
        if(TraceSceneDetailQuery(o+d*advance,d,limit,shadowQuery,resolveMaterial,cullingMask,shadowRenderingLayers,useRenderingLayers,queryFootprint,materialView,result))
        { result.t+=advance;if(!HLGIHitQueryUnresolved(result))result.position=o+d*result.t;return true; }
        if(segment==1 || detailLimit>=maxT) break;
        // Retain the near/far overlap and conservative empty-space guards.
        advance=max(0,detailLimit-0.001);
        [loop] for(int step=0;step<8 && advance<maxT;step++)
        {
            float emptyDistance;
            if(!HLGIGlobalSdfEmptyDistance(o+d*advance,emptyDistance) || emptyDistance<=0) break;
            if(emptyDistance>=maxT-advance) { result=HLGIEmptyHit(maxT);return false; }
            float guard=max(0.001,abs(advance)*2e-6);
            float next=advance+max(0,emptyDistance-guard);
            if(next<=advance) break;
            advance=next;
        }
        if(advance>=maxT) break;
        HLGIAdvanceRayFootprint(footprint,advance,queryFootprint);
    }
    result=HLGIEmptyHit(maxT);return false;
}
// Public legacy query overloads retain their original material purpose.
bool TraceSceneDetailQuery(float3 o,float3 d,float maxT,bool shadowQuery,bool resolveMaterial,uint cullingMask,uint shadowRenderingLayers,bool useRenderingLayers,out HLGIHit result)
{ return TraceSceneDetailQuery(o,d,maxT,shadowQuery,resolveMaterial,cullingMask,shadowRenderingLayers,useRenderingLayers,HLGIPointQueryFootprint(),float4(o,1),result); }
bool TraceSceneQuery(float3 o,float3 d,float maxT,bool shadowQuery,bool resolveMaterial,uint cullingMask,uint shadowRenderingLayers,bool useRenderingLayers,out HLGIHit result)
{ return TraceSceneQuery(o,d,maxT,shadowQuery,resolveMaterial,cullingMask,shadowRenderingLayers,useRenderingLayers,HLGIPointQueryFootprint(),float4(o,1),result); }
bool TraceSceneDetailQuery(float3 o,float3 d,float maxT,bool shadowQuery,uint cullingMask,uint shadowRenderingLayers,bool useRenderingLayers,out HLGIHit result)
{ return TraceSceneDetailQuery(o,d,maxT,shadowQuery,!shadowQuery,cullingMask,shadowRenderingLayers,useRenderingLayers,result); }
bool TraceSceneQuery(float3 o,float3 d,float maxT,bool shadowQuery,uint cullingMask,uint shadowRenderingLayers,bool useRenderingLayers,out HLGIHit result)
{ return TraceSceneQuery(o,d,maxT,shadowQuery,!shadowQuery,cullingMask,shadowRenderingLayers,useRenderingLayers,result); }
bool TraceSceneDetailHit(float3 o,float3 d,float maxT,out HLGIHit result)
{ return TraceSceneDetailQuery(o,d,maxT,false,true,0xffffffffu,0xffffffffu,false,result); }
bool TraceSceneHit(float3 o,float3 d,float maxT,out HLGIHit result)
{ return TraceSceneQuery(o,d,maxT,false,true,0xffffffffu,0xffffffffu,false,result); }
bool TraceSceneHit(float3 o,float3 d,float maxT,HLGIRayFootprint footprint,float4 materialView,out HLGIHit result)
{ return TraceSceneQuery(o,d,maxT,false,true,0xffffffffu,0xffffffffu,false,footprint,materialView,result); }
// Ordinary visibility preserves surface Cull/alpha and ignores shadow-caster policy.
bool TraceSceneVisibilityHit(float3 o,float3 d,float maxT,out HLGIHit result)
{ return TraceSceneQuery(o,d,maxT,false,false,0xffffffffu,0xffffffffu,false,result); }
bool TraceSceneVisibilityHit(float3 o,float3 d,float maxT,HLGIRayFootprint footprint,float4 materialView,out HLGIHit result)
{ return TraceSceneQuery(o,d,maxT,false,false,0xffffffffu,0xffffffffu,false,footprint,materialView,result); }
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
// Visibility-only compatibility: unknown coverage conservatively blocks. This
// overload does not prove known radiance; transport must consume the known flag.
bool TraceShadow(float3 o,float3 d,float maxT,uint cullingMask,uint shadowRenderingLayers,bool useRenderingLayers)
{ bool known;return TraceShadow(o,d,maxT,cullingMask,shadowRenderingLayers,useRenderingLayers,known); }
// Visibility-only compatibility entry. Radiance/material consumers use the full
// record, so this projection of it cannot discard their primitive identity.
bool TraceScene(float3 o,float3 d,float maxT,out float t,out float3 n,out int index)
{
    HLGIHit result;bool found=TraceSceneVisibilityHit(o,d,maxT,result);
    t=result.t;n=result.rawNg;index=found?(int)result.ownerSlot:-1;
    return found;
}
int FaceIndex(float3 n)
{
    float3 a=abs(n);
    int axis = a.x>=a.y && a.x>=a.z ? 0 : a.y>=a.z ? 1 : 2;
    return axis*2 + (n[axis]<0 ? 1 : 0);
}
float3 FaceNormal(int face) { float3 n=0; n[face/2]=(face&1)==0?1:-1; return n; }
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
        if(any(e.tag.xyz != float3(p.identity.xy,_HLGI_Epoch)) || !HLGIHasSourceCacheMeasurement(e.irradiance,e.guide,e.nonAnalyticIrradiance)) continue;
        if(e.tag.w!=(float)surface.generation) continue;
#if defined(HLGI_CACHE_UPDATE_ITERATION)
        // Target invalidation writes the other pool; reject stale source taps
        // from this iteration's old pool before they can feed another patch.
        if(e.nonAnalyticIrradiance.w>0.5 || HLGIRejectOldCacheInputAt(e.anchor.xyz)) continue;
#endif
        // A channel absent from the current light table has no analytic contribution at any bounce.
        e.irradiance.rgb=HLGIActiveCacheIrradiance(e.irradiance.rgb,e.nonAnalyticIrradiance.rgb);
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
                // Unknown coverage or an unfinished connection cannot prove
                // occlusion. Do not discard that tap and renormalize the rest.
                if(!HLGIHitMaterialKnown(blocker)) { known=false;result=(HLGICacheEntry)0;return false; }
                continue;
            }
        }
        totalWeight+=weight;result.irradiance+=e.irradiance*weight;result.guide+=e.guide*weight;
        result.nonAnalyticIrradiance+=e.nonAnalyticIrradiance*weight;
    }
    if(totalWeight<=1e-5) { result=(HLGICacheEntry)0;return false; }
    result.irradiance/=totalWeight;result.guide/=totalWeight;result.nonAnalyticIrradiance/=totalWeight;
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
// Guide-only use: unknown connections produce no guide, never a numeric light value.
bool HLGICachedSample(HLGIHit hit,float3 shadingNormal,out HLGICacheEntry result)
{ bool known;return HLGICachedSample(hit,shadingNormal,result,known); }
float3 CachedIrradiance(HLGIHit hit,float3 shadingNormal,out bool known)
{
    HLGICacheEntry entry;
    return HLGICachedSample(hit,shadingNormal,entry,known)?max(entry.irradiance.rgb,0):0;
}
float3 DirectIrradiance(float3 p,float3 n,float3 biasNormal,uint2 receiverLayers,bool receivesShadows,
    float4 bakedMask,float3 footprintDirection,HLGIRayFootprint footprint,out bool known)
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
        bool hasBakedChannel=light.spot.w>=1 && light.spot.w<=4;
        if(receivesShadows || hasBakedChannel)
        {
            float strength=receivesShadows?saturate(light.spot.z):0;
            if(!isfinite(light.spot.z) || !isfinite(maxT)) { known=false;return 0; }
            bool bakedKnown=true;
            float bakedStrength=0;
            if(hasBakedChannel)
            {
                // URP's receiver keyword gates realtime shadows. BakedShadow
                // still runs, using full baked strength for additional lights
                // when their realtime shadow variant is disabled.
                bool additional=(light.masks.w&2u)!=0u;
                bakedStrength=additional && (!receivesShadows || (light.masks.w&4u)!=0u)?1:saturate(light.color.a);
                if(bakedStrength>0)
                {
                    float baked=bakedMask[(uint)light.spot.w-1u];
                    bakedKnown=isfinite(baked) && baked>=0 && baked<=1;
                    if(bakedKnown) visibility=lerp(1,baked,bakedStrength);
                }
            }
            // In Shadowmask mode an occluded baked path stays occluded. Only
            // trace realtime casters if they can further reduce this value.
            if(strength>0 && (!bakedKnown || visibility>1-strength))
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
                if(blocked)
                {
                    visibility=min(visibility,1-strength);
                    bakedKnown=bakedKnown || strength>=bakedStrength;
                }
            }
            if(!bakedKnown) { known=false;return 0; }
        }
        sum+=light.color.rgb*(ndl*attenuation*visibility);
    }
    known=all(isfinite(sum));return known?sum:0;
}
float3 DirectIrradiance(float3 p,float3 n,float3 biasNormal,uint2 receiverLayers,bool receivesShadows,
    float3 footprintDirection,HLGIRayFootprint footprint,out bool known)
{ return DirectIrradiance(p,n,biasNormal,receiverLayers,receivesShadows,1,footprintDirection,footprint,known); }
float3 DirectIrradiance(float3 p,float3 n,float3 biasNormal,uint2 receiverLayers,bool receivesShadows,out bool known)
{ return DirectIrradiance(p,n,biasNormal,receiverLayers,receivesShadows,biasNormal,HLGIPointQueryFootprint(),known); }
// Existing callers retain shadow receiving until their material source proves
// an explicit _RECEIVE_SHADOWS_OFF policy.
float3 DirectIrradiance(float3 p,float3 n,float3 biasNormal,uint2 receiverLayers,out bool known)
{ return DirectIrradiance(p,n,biasNormal,receiverLayers,true,known); }
// Compatibility value only. A zero return on unknown shadows is not measured
// black; callers that accumulate radiance must use the explicit known overload.
float3 DirectIrradiance(float3 p,float3 n,float3 biasNormal,uint2 receiverLayers)
{ bool known;return DirectIrradiance(p,n,biasNormal,receiverLayers,known); }
float3 ProxyRadiance(HLGIHit hit,float3 incomingDirection,HLGIRayFootprint hitFootprint,float emissionWeight,out float confidence,out float3 nonAnalytic)
{
    confidence=0;nonAnalytic=0;
    if(!HLGIHitOwnerCurrent(hit) || !HLGIHitMaterialKnown(hit)) return 0;
    HLGIProxy proxy=_HLGI_Proxies[hit.ownerSlot];
    HLGISurfaceSample surface;
    float3 diffuse=proxy.albedo.rgb,emission=proxy.emission.rgb;
    float3 shadingNormal=HLGIHitHas(hit.flags,HLGI_HIT_SHADING_NORMAL)?hit.shadingNormal:hit.rawNg;
    float3 biasNormal=hit.rawNg;float ao=1;
    uint4 receiverPolicy=_HLGI_LightingPolicies[hit.ownerSlot];
    bool receivesShadows=(receiverPolicy.w&1u)==0;
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
    if(all(isfinite(diffuse)) && all(saturate(diffuse)==0))
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
    if(materialResolved && _HLGI_BounceFeedback>0 && ao!=0)
    {
        float3 queryNg=HLGIHitHas(hit.flags,HLGI_HIT_ORIENTED_NG)?hit.rawNg:surface.geometricNormal;
        bool cacheKnown;
        HLGICachedSurface((int)hit.ownerSlot,hit.position,queryNg,shadingNormal,surface,cached,cacheKnown);
        if(!cacheKnown) { confidence=0;return 0; }
    }
    bool directKnown;
    float4 bakedMask=1;
    if ((receiverPolicy.w&2u)!=0u)
    {
        // The owner has a real lightmap mask. Missing UVs or an unmatched
        // surface must not turn into an unshadowed measurement.
        bakedMask=-1;
        if (materialResolved && (receiverPolicy.w&4u)!=0u)
            bakedMask=_HLGI_SurfaceShadowmask.Load(int3(surface.atlasPixel,0));
    }
    float3 direct=DirectIrradiance(hit.position,shadingNormal,biasNormal,receiverPolicy.xy,
        receivesShadows,bakedMask,incomingDirection,hitFootprint,directKnown);
    if(!directKnown || !all(isfinite(diffuse)) || !all(isfinite(emission)) || !isfinite(ao)) { confidence=0;return 0; }
    // Preserve the physical direct reflection. The 0.98 contraction cap belongs
    // only to recursive cache feedback, not to the material or its direct term.
    float3 reflectance=saturate(diffuse),feedbackReflectance=min(reflectance,0.98);
    float3 value=max(emission,0)*emissionWeight+reflectance*direct+
        feedbackReflectance*(ao*_HLGI_BounceFeedback*max(cached.irradiance.rgb,0));
    nonAnalytic=max(emission,0)*emissionWeight+feedbackReflectance*(ao*_HLGI_BounceFeedback*max(cached.nonAnalyticIrradiance.rgb,0));
    if(!HLGIHasRadianceMeasurement(float4(value,confidence))) { confidence=0;return 0; }
    return value;
}
float3 ProxyRadiance(HLGIHit hit,float3 incomingDirection,HLGIRayFootprint hitFootprint,float emissionWeight,out float confidence)
{ float3 nonAnalytic;return ProxyRadiance(hit,incomingDirection,hitFootprint,emissionWeight,confidence,nonAnalytic); }
float3 ProxyRadiance(HLGIHit hit,float3 incomingDirection,HLGIRayFootprint hitFootprint,out float confidence)
{ return ProxyRadiance(hit,incomingDirection,hitFootprint,1,confidence); }
float3 ProxyRadiance(HLGIHit hit,out float confidence)
{ return ProxyRadiance(hit,hit.rawNg,HLGIPointQueryFootprint(),confidence); }
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
// Return the nearest world hit as well: screen gathering must apply its same
// nearest-screen winner to this sample before adding the light contribution.
bool HLGIAreaLightContribution(float3 origin,float3 n,float4 guide,HLGIAreaSample sample,
    HLGIRayFootprint footprint,float4 materialView,out float3 value,out bool worldHit,out HLGIHit hit)
{
    value=0;worldHit=false;hit=HLGIEmptyHit(_HLGI_MaxDistance);
    float cosine=max(0,dot(n,sample.direction));
    if(cosine==0 || sample.distance>=_HLGI_MaxDistance)return true;
    float scale=max(sample.distance,max(abs(sample.position.x),max(abs(sample.position.y),abs(sample.position.z))));
    float tolerance=max(1e-5,16*1.192092896e-7*scale);
    float limit=min(_HLGI_MaxDistance,sample.distance+tolerance);
    worldHit=TraceSceneHit(origin,sample.direction,limit,footprint,materialView,hit);
    if(!worldHit)return true; // Alpha hole/back side has zero contribution; never resample.
    if(!HLGIHitMaterialKnown(hit))
    {
        // A separate, covered triangle can block the emitter before its shading is ready.
        const uint blockerFlags=HLGI_HIT_VALID|HLGI_HIT_TRIANGLE|HLGI_HIT_FRONT_FACE_KNOWN|HLGI_HIT_COVERAGE_CONFIRMED;
        bool differentPrimitive=hit.hardwareInstance!=sample.emitter.geometry.x || hit.primitive!=sample.emitter.geometry.z;
        return HLGIHitHas(hit.flags,blockerFlags) && !HLGIHitQueryUnresolved(hit) &&
            differentPrimitive && hit.t<sample.distance-tolerance;
    }
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
// Jacobi reads only the old buffer. Every output entry is written, including invalid slots.
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
    if(any(e.tag.xyz!=tag) || e.tag.w!=(float)surface.generation || change.x>0.5 || !HLGIHasSourceCacheMeasurement(e.irradiance,e.guide,e.nonAnalyticIrradiance))
        e=(HLGICacheEntry)0;
    // Persist the removal even for budget-skipped/unknown updates, so a returning
    // light channel cannot resurrect its old analytic contribution.
    // A cold/invalid entry remains age zero; this does not invent a measurement.
    e.irradiance.rgb=HLGIActiveCacheIrradiance(e.irradiance.rgb,e.nonAnalyticIrradiance.rgb);
    // Positive age below one keeps a valid old measurement available, but marks
    // it for replacement after a global light change. Persist across budget
    // waits and unknown updates; only a committed known estimate consumes it.
    if(_HLGI_GlobalReactive>0.5) e.irradiance.a=min(e.irradiance.a,0.5);
    // Nearby changes retain an estimate but shorten its history, even if this patch awaits budget.
    if(change.y>0.5) e.irradiance.a=min(e.irradiance.a,1);
#if defined(HLGI_CACHE_UPDATE_ITERATION)
    if(e.irradiance.a>0 && HLGIDisjointPoseInfluenceAt(surface.position))
        e.nonAnalyticIrradiance.w=1;
#endif
    e.tag=float4(tag,surface.generation);
    float2 geometricOct=PackNormalOctQuadEncode(surface.geometricNormal);
    e.anchor=float4(surface.position,geometricOct.x);e.normal=float4(surface.normal,geometricOct.y);
    if(_HLGI_CacheUpdateMask[id.x]!=0)
    {
        float3 position=surface.position,n=surface.normal;
        // Separate cache-update and camera-gather domains: an equal physical
        // patch/pixel index must not reuse the guide-producing random stream.
        uint rng=HLGIHash((id.x+HLGIHash((uint)_HLGI_FrameIndex+1))^0xA511E9B3u);
        float3 sum=0,nonAnalyticSum=0,guide=0;float guidePower=0;bool estimateKnown=true;
        [loop] for(int r=0;r<_HLGI_CacheRays;r++)
        {
            float3 origin=position+HLGIOffsetNormal(surface.geometricNormal,n)*_HLGI_RayBias;
            float weight;float3 direction=HLGISampleTransportDirection(origin,n,e.guide,rng,weight);
            if(!HLGIAreaMatchedDirectionWeight(origin,n,e.guide,direction,weight)) { estimateKnown=false;break; }
            if(!all(isfinite(direction))) { estimateKnown=false;break; }
            HLGIHit hit;
            float3 incoming=0,nonAnalyticIncoming=0;float materialConfidence=1;
            HLGIRayFootprint footprint;
            HLGITrySurfacePatchRayFootprint(surface,uint2(local%_HLGI_CacheGrid,local/_HLGI_CacheGrid),direction,footprint);
            if(weight>0 && TraceSceneHit(origin,direction,_HLGI_MaxDistance,footprint,float4(position,1),hit))
            {
                HLGIRayFootprint hitFootprint;HLGIAdvanceRayFootprint(footprint,hit.t,hitFootprint);
                float emissionWeight;
                if(!HLGIAreaDirectionEmissionWeight(origin,n,e.guide,direction,hit,emissionWeight)) { estimateKnown=false;break; }
                incoming=ProxyRadiance(hit,direction,hitFootprint,emissionWeight,materialConfidence,nonAnalyticIncoming);
            }
            else if(weight>0) { incoming=HLGIEnvironmentRadiance(direction);nonAnalyticIncoming=incoming; }
            if(!HLGIAccumulateRadianceSample(incoming,materialConfidence,weight,sum) ||
                !HLGIAccumulateRadianceSample(nonAnalyticIncoming,materialConfidence,weight,nonAnalyticSum)) { estimateKnown=false;break; }
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
                    !HLGIAccumulateRadianceSample(lightValue,1,1,sum) ||
                    !HLGIAccumulateRadianceSample(lightValue,1,1,nonAnalyticSum)) { estimateKnown=false;break; }
                float lightPower=dot(lightValue,float3(0.2126,0.7152,0.0722));
                guide+=lightSample.direction*lightPower;guidePower+=lightPower;
            }
        }
        HLGICommitSourceCacheEstimate(estimateKnown,sum,nonAnalyticSum,guide,guidePower,_HLGI_CacheRays,n,e.irradiance,e.guide,e.nonAnalyticIrradiance);
    }
    _HLGI_CacheWrite[id.x]=e;
}
#endif
