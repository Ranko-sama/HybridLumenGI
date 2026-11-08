#ifndef HYBRID_LUMEN_GI_HARDWARE_TRACE_INCLUDED
#define HYBRID_LUMEN_GI_HARDWARE_TRACE_INCLUDED

#include "UnityRayQuery.cginc"
#include "HybridLumenGIExactMesh.hlsl"
RaytracingAccelerationStructure _HLGI_AccelerationStructure;
bool HLGIHardwareTraceQuery(float3 origin,float3 direction,float maxT,bool shadowQuery,bool resolveMaterial,
    uint cullingMask,uint shadowRenderingLayers,bool useRenderingLayers,
    float coneRadiusAtOrigin,float coneSlope,float4 materialView,out HLGIHit hit)
{
    hit=HLGIEmptyHit(maxT);
    if(!isfinite(maxT) || maxT<=0.0001 || !all(isfinite(origin)) || !all(isfinite(direction)) || dot(direction,direction)<1e-16) return false;
    // Force candidate evaluation even if the instance/submesh is marked opaque.
    // Rejecting a COMMITTED closest hit would incorrectly lose farther valid
    // surfaces. No accept-first flag: continue traversal after every accepted hit.
    const uint flags=RAY_FLAG_FORCE_NON_OPAQUE | RAY_FLAG_SKIP_PROCEDURAL_PRIMITIVES;
    UnityRayQuery<flags> query;
    RayDesc ray;ray.Origin=origin;ray.Direction=direction;ray.TMin=0.0001;ray.TMax=maxT;
    query.TraceRayInline(_HLGI_AccelerationStructure,flags,0xff,ray);
    while(query.Proceed())
    {
        if(query.CandidateType()!=CANDIDATE_NON_OPAQUE_TRIANGLE) continue;
        HLGIHardwareInstance candidate;HLGITriangleNormals attributes;float3 rawNg;
        if(!HLGIHardwareGeometry(query.CandidateInstanceID(),query.CandidatePrimitiveIndex(),candidate,attributes,rawNg)) continue;
        // An excluded nearer caster must not hide a farther valid caster. Keep
        // the decision inside traversal, before committing this candidate.
        // Surface queries intentionally ignore shadow casting and light layers.
        if(shadowQuery && !HLGIShadowOwnerAllowed(candidate.geometry.x,cullingMask,shadowRenderingLayers,useRenderingLayers)) continue;
        bool frontFace=dot(rawNg,direction)<0;
        bool sideAllowed=dot(rawNg,rawNg)<0.5 || HLGIHardwareSideAllowed(candidate.identity.w,frontFace) ||
            (shadowQuery && HLGIShadowTwoSided(candidate.geometry.x));
        if(!sideAllowed) continue;
        float candidateT=query.CandidateTriangleRayT();
        bool covered=true;HLGIHitMaterialSurface candidateMaterial;float3 candidateNormal;
        bool coverageKnown=false;
        if(isfinite(candidateT) && candidateT>=0)
            coverageKnown=HLGIHardwareEvaluateHit(query.CandidateInstanceID(),query.CandidatePrimitiveIndex(),candidate,attributes,
                query.CandidateObjectToWorld3x4(),query.CandidateTriangleBarycentrics(),materialView,direction,
                HLGIExactHitRadius(coneRadiusAtOrigin,coneSlope,candidateT),true,shadowQuery,
                covered,candidateMaterial,candidateNormal);
        if(!HLGIHitCoverageBlocks(coverageKnown,covered)) continue;
        query.CommitNonOpaqueTriangleHit();
    }
    if(query.CommittedStatus()!=COMMITTED_TRIANGLE_HIT) return false;
    uint instanceIndex=query.CommittedInstanceID(),primitive=query.CommittedPrimitiveIndex();
    HLGIHardwareInstance instance;HLGITriangleNormals normals;float3 rawNg;
    if(!HLGIHardwareGeometry(instanceIndex,primitive,instance,normals,rawNg)) return false;
    float2 barycentric=query.CommittedTriangleBarycentrics();
    float3 weights=float3(1-barycentric.x-barycentric.y,barycentric.xy);
    float3 shadingNormal=0;
    bool normalValid=normals.face.w>0.5 && HLGITryHardwareShadingNormal((float3x3)instance.normalToWorld,
        normals.a.xyz,normals.b.xyz,normals.c.xyz,weights,shadingNormal);
    if(!normalValid) shadingNormal=rawNg;
    hit.t=query.CommittedRayT();hit.position=origin+direction*hit.t;
    hit.rawNg=rawNg;hit.shadingNormal=shadingNormal;
    hit.ownerSlot=instance.geometry.x;hit.submesh=instance.geometry.w;hit.primitive=primitive;hit.hardwareInstance=instanceIndex;
    hit.stableId=instance.identity.x;hit.ownerRevision=instance.identity.y;hit.geometryRevision=instance.identity.z;
    hit.barycentrics=barycentric;hit.representation=HLGI_REPRESENTATION_TRIANGLE;
    hit.flags=HLGI_HIT_VALID|HLGI_HIT_TRIANGLE;
    if(dot(rawNg,rawNg)>0.5)
    {
        hit.flags|=HLGI_HIT_GEOMETRIC_NORMAL|HLGI_HIT_ORIENTED_NG|HLGI_HIT_FRONT_FACE_KNOWN;
        if(dot(rawNg,direction)<0) hit.flags|=HLGI_HIT_FRONT_FACE;
    }
    if(normalValid) hit.flags|=HLGI_HIT_SHADING_NORMAL;
    HLGIHardwareResolveCommittedMaterial(instanceIndex,primitive,instance,normals,query.CommittedObjectToWorld3x4(),barycentric,
        materialView,direction,coneRadiusAtOrigin,coneSlope,shadowQuery,resolveMaterial,hit);
    float2 uv=float2(dot(float3(normals.a.w,normals.b.w,normals.c.w),weights),dot(normals.uvY.xyz,weights));
    if(normals.uvY.w>0.5 && all(isfinite(uv))) { hit.uv=uv;hit.flags|=HLGI_HIT_UV; }
    uint count,stride;_HLGI_HardwareTriangleBindings.GetDimensions(count,stride);
    if(instance.geometry.y<count && primitive<count-instance.geometry.y)
    {
        uint4 binding=_HLGI_HardwareTriangleBindings[instance.geometry.y+primitive];
        if(binding.x!=0xffffffffu && binding.y!=0u && binding.z!=0u && binding.w==hit.geometryRevision)
        { hit.surfaceBinding=binding;hit.flags|=HLGI_HIT_SURFACE_BINDING; }
    }
    return true;
}
// Legacy callers describe point queries. Filtered transport supplies an explicit
// footprint and a homogeneous material view (point w=1, direction w=0).
bool HLGIHardwareTraceQuery(float3 origin,float3 direction,float maxT,bool shadowQuery,bool resolveMaterial,
    uint cullingMask,uint shadowRenderingLayers,bool useRenderingLayers,
    float coneRadiusAtOrigin,float coneSlope,float3 materialViewOrigin,out HLGIHit hit)
{
    return HLGIHardwareTraceQuery(origin,direction,maxT,shadowQuery,resolveMaterial,cullingMask,shadowRenderingLayers,useRenderingLayers,
        coneRadiusAtOrigin,coneSlope,float4(materialViewOrigin,1),hit);
}
bool HLGIHardwareTraceQuery(float3 origin,float3 direction,float maxT,bool shadowQuery,bool resolveMaterial,
    uint cullingMask,uint shadowRenderingLayers,bool useRenderingLayers,out HLGIHit hit)
{
    return HLGIHardwareTraceQuery(origin,direction,maxT,shadowQuery,resolveMaterial,cullingMask,shadowRenderingLayers,useRenderingLayers,0,0,origin,hit);
}
// Public legacy overloads preserve their original surface/full and shadow/coverage purposes.
bool HLGIHardwareTraceQuery(float3 origin,float3 direction,float maxT,bool shadowQuery,
    uint cullingMask,uint shadowRenderingLayers,bool useRenderingLayers,
    float coneRadiusAtOrigin,float coneSlope,float3 materialViewOrigin,out HLGIHit hit)
{
    return HLGIHardwareTraceQuery(origin,direction,maxT,shadowQuery,!shadowQuery,cullingMask,shadowRenderingLayers,useRenderingLayers,coneRadiusAtOrigin,coneSlope,materialViewOrigin,hit);
}
bool HLGIHardwareTraceQuery(float3 origin,float3 direction,float maxT,bool shadowQuery,
    uint cullingMask,uint shadowRenderingLayers,bool useRenderingLayers,out HLGIHit hit)
{
    return HLGIHardwareTraceQuery(origin,direction,maxT,shadowQuery,!shadowQuery,cullingMask,shadowRenderingLayers,useRenderingLayers,0,0,origin,hit);
}
bool HLGIHardwareTraceHit(float3 origin,float3 direction,float maxT,float coneRadiusAtOrigin,float coneSlope,float3 materialViewOrigin,out HLGIHit hit)
{
    return HLGIHardwareTraceQuery(origin,direction,maxT,false,true,0xffffffffu,0xffffffffu,false,coneRadiusAtOrigin,coneSlope,materialViewOrigin,hit);
}
bool HLGIHardwareTraceHit(float3 origin,float3 direction,float maxT,out HLGIHit hit)
{
    return HLGIHardwareTraceQuery(origin,direction,maxT,false,true,0xffffffffu,0xffffffffu,false,hit);
}
bool HLGIHardwareFallbackMaterial(HLGIHit hit,out float3 diffuse,out float3 emission)
{
    diffuse=0;emission=0;
    // Retained name for callers compiled against the old API. No constant
    // approximation can turn failed texture/coverage evaluation into known GI.
    if(!HLGIHitMaterialKnown(hit) || !HLGIHitHas(hit.flags,HLGI_HIT_VALID|HLGI_HIT_TRIANGLE|HLGI_HIT_UV_MATERIAL)) return false;
    diffuse=hit.materialDiffuse;emission=hit.materialEmission;return true;
}

// Compatibility accessors. New transport code must keep HLGIHit until material
// resolution, otherwise submesh/chart identity is lost again.
bool HLGIHardwareTraceAttributes(float3 origin,float3 direction,float maxT,
    out float hitT,out float3 hitNormal,out float3 geometricNormal,out float2 uv,out bool hasUV,out int hitIndex)
{
    HLGIHit hit;bool found=HLGIHardwareTraceHit(origin,direction,maxT,hit);
    hitT=hit.t;hitNormal=hit.shadingNormal;geometricNormal=hit.rawNg;uv=hit.uv;
    hasUV=HLGIHitHas(hit.flags,HLGI_HIT_UV);hitIndex=found?(int)hit.ownerSlot:-1;return found;
}
bool HLGIHardwareTrace(float3 origin,float3 direction,float maxT,out float hitT,out float3 hitNormal,out int hitIndex)
{
    HLGIHit hit;bool found=HLGIHardwareTraceHit(origin,direction,maxT,hit);
    hitT=hit.t;hitNormal=HLGIOffsetNormal(hit.rawNg,-direction);hitIndex=found?(int)hit.ownerSlot:-1;return found;
}
#endif
