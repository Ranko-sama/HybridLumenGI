#ifndef HLGI_HIT_INCLUDED
#define HLGI_HIT_INCLUDED

// A local query result, not a persistent GPU buffer ABI. Unknown source identity
// stays unknown: an SDF/analytic hit must never acquire a triangle or area PDF.
#define HLGI_HIT_VALID               1u
#define HLGI_HIT_ORIENTED_NG         2u
#define HLGI_HIT_FRONT_FACE_KNOWN     4u
#define HLGI_HIT_FRONT_FACE           8u
#define HLGI_HIT_TRIANGLE            16u
#define HLGI_HIT_UV                  32u
#define HLGI_HIT_SURFACE_BINDING     64u
#define HLGI_HIT_SHADING_NORMAL     128u
#define HLGI_HIT_GEOMETRIC_NORMAL   256u
#define HLGI_HIT_MATERIAL_UNKNOWN   512u
#define HLGI_HIT_UV_MATERIAL       1024u
#define HLGI_HIT_QUERY_UNRESOLVED  2048u
#define HLGI_REPRESENTATION_NONE      0u
#define HLGI_REPRESENTATION_TRIANGLE  1u
#define HLGI_REPRESENTATION_SIGNED_SDF 2u
#define HLGI_REPRESENTATION_UNSIGNED_SDF 3u
#define HLGI_REPRESENTATION_ANALYTIC  4u

struct HLGIHit
{
    // For QUERY_UNRESOLVED, t is a conservative interval lower bound, not an
    // intersection. No position/normal/primitive/material identity is supplied.
    float t;
    float3 position;
    float3 rawNg;
    float3 shadingNormal;
    uint ownerSlot, stableId, ownerRevision, geometryRevision;
    uint submesh, primitive, hardwareInstance;
    float2 barycentrics, uv;
    uint representation, flags;
    // physical card, stable chart ID, layout generation, geometry content revision.
    uint4 surfaceBinding;
    // Local committed hit material, not a persistent buffer ABI. These fields
    // are meaningful only with UV_MATERIAL and without MATERIAL_UNKNOWN.
    float3 materialDiffuse, materialEmission;
    float materialOcclusion;
    uint materialReceivesShadows;
};

HLGIHit HLGIEmptyHit(float maxT)
{
    HLGIHit hit=(HLGIHit)0;
    hit.t=maxT;
    hit.ownerSlot=hit.submesh=hit.primitive=hit.hardwareInstance=0xffffffffu;
    hit.surfaceBinding.x=0xffffffffu;
    return hit;
}

// Bias is a separate geometric operation. Neither source identity nor a stock
// URP Lit shading normal is changed to face the incident ray.
float3 HLGIOffsetNormal(float3 rawNg,float3 toward)
{
    return dot(rawNg,toward)<0 ? -rawNg : rawNg;
}

bool HLGIHitHas(uint flags,uint required) { return (flags&required)==required; }
// Unknown coverage/material is still a valid nearest occluder, never a miss.
bool HLGIHitQueryUnresolved(HLGIHit hit) { return (hit.flags&HLGI_HIT_QUERY_UNRESOLVED)!=0u; }
bool HLGIHitMaterialKnown(HLGIHit hit) { return (hit.flags&(HLGI_HIT_MATERIAL_UNKNOWN|HLGI_HIT_QUERY_UNRESOLVED))==0u; }
// Unknown coverage preserves the nearest occluder. Only proven transparent
// candidates may be skipped; two-sided shadow casting never bypasses alpha.
bool HLGIHitCoverageBlocks(bool known,bool covered) { return !known || covered; }
#endif
