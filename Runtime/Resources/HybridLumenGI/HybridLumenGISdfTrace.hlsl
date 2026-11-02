#ifndef HLGI_MESH_SDF_TRACE_INCLUDED
#define HLGI_MESH_SDF_TRACE_INCLUDED
#include "HybridLumenGIHit.hlsl"

// Include after HLGIProxy/_HLGI_Proxies. Layout matches HybridLumenGISdfAtlas.
struct HLGISdfMetadata
{
    column_major float4x4 worldToLocal;
    float4 boundsMinResolution;
    float4 boundsSizeMinScale;
    float4 voxelSizeError;
    uint distanceOffset, stableId, revision, valid; // bits 0/1: mesh SDF/signed, bit 2: collider-only box
};
StructuredBuffer<HLGISdfMetadata> _HLGI_SdfMetadata;
StructuredBuffer<float> _HLGI_SdfDistances;
int _HLGI_SdfSlotCount, _HLGI_SdfVoxelCount, _HLGI_SdfTraceSteps;

// This slot owns either a mesh volume or a collider box frame. Box coordinates
// are relative to the published proxy center and retain world distance units.
bool HLGIColliderBoxFrame(int slot, HLGIProxy p, out float3x3 worldToAxes, out float3 halfSize)
{
    worldToAxes = (float3x3)0;
    halfSize = p.extentsRoughness.xyz;
    if (slot < 0 || slot >= _HLGI_SdfSlotCount) return false;
    HLGISdfMetadata m = _HLGI_SdfMetadata[slot];
    if ((m.valid & 4u) == 0u || m.stableId != (uint)p.identity.x || m.revision != (uint)p.identity.y) return false;
    worldToAxes = (float3x3)m.worldToLocal;
    halfSize = m.boundsSizeMinScale.xyz;
    return true;
}

bool HLGIHasMeshSdf(int slot)
{
    if (slot < 0 || slot >= _HLGI_SdfSlotCount || slot >= _HLGI_ProxyCount) return false;
    HLGISdfMetadata m = _HLGI_SdfMetadata[slot];
    HLGIProxy p = _HLGI_Proxies[slot];
    uint size = (uint)m.boundsMinResolution.w;
    return (m.valid & 1u) != 0u && p.identity.w > 0.5 &&
        m.stableId == (uint)p.identity.x && m.revision == (uint)p.identity.y &&
        size >= 16u && size <= 64u && m.distanceOffset + size * size * size <= (uint)_HLGI_SdfVoxelCount;
}

float HLGISdfLoad(HLGISdfMetadata m, uint3 voxel, uint size)
{
    return _HLGI_SdfDistances[m.distanceOffset + voxel.x + size * (voxel.y + size * voxel.z)];
}

float HLGISdfSample(HLGISdfMetadata m, float3 localPosition)
{
    uint size = (uint)m.boundsMinResolution.w;
    // Asset samples are at voxel centers, not bounds endpoints. Clamp each index
    // independently so no interpolation tap enters another atlas allocation.
    float3 grid = clamp((localPosition - m.boundsMinResolution.xyz) /
        m.boundsSizeMinScale.xyz * size - 0.5, 0.0, (float)(size - 1u));
    uint3 a = (uint3)floor(grid);
    uint3 b = min(a + 1u, size - 1u);
    float3 blend = frac(grid);
    float z0 = lerp(
        lerp(HLGISdfLoad(m, uint3(a.x,a.y,a.z), size), HLGISdfLoad(m, uint3(b.x,a.y,a.z), size), blend.x),
        lerp(HLGISdfLoad(m, uint3(a.x,b.y,a.z), size), HLGISdfLoad(m, uint3(b.x,b.y,a.z), size), blend.x), blend.y);
    float z1 = lerp(
        lerp(HLGISdfLoad(m, uint3(a.x,a.y,b.z), size), HLGISdfLoad(m, uint3(b.x,a.y,b.z), size), blend.x),
        lerp(HLGISdfLoad(m, uint3(a.x,b.y,b.z), size), HLGISdfLoad(m, uint3(b.x,b.y,b.z), size), blend.x), blend.y);
    return lerp(z0, z1, blend.z);
}

bool HLGISdfBounds(float3 origin, float3 direction, float3 minimum, float3 maximum,
    float maxT, out float begin, out float end)
{
    begin = 1e-4;
    end = maxT;
    [unroll] for (int axis = 0; axis < 3; axis++)
    {
        if (abs(direction[axis]) < 1e-12)
        {
            if (origin[axis] < minimum[axis] || origin[axis] > maximum[axis]) return false;
        }
        else
        {
            float a = (minimum[axis] - origin[axis]) / direction[axis];
            float b = (maximum[axis] - origin[axis]) / direction[axis];
            begin = max(begin, min(a,b));
            end = min(end, max(a,b));
        }
    }
    return end >= begin;
}

float3 HLGISdfNormal(HLGISdfMetadata m, float3 p, float3 fallback,out bool valid)
{
    float3 h = m.voxelSizeError.xyz * 0.5;
    float3 gradient;
    gradient.x = (HLGISdfSample(m,p+float3(h.x,0,0))-HLGISdfSample(m,p-float3(h.x,0,0))) / (2*h.x);
    gradient.y = (HLGISdfSample(m,p+float3(0,h.y,0))-HLGISdfSample(m,p-float3(0,h.y,0))) / (2*h.y);
    gradient.z = (HLGISdfSample(m,p+float3(0,0,h.z))-HLGISdfSample(m,p-float3(0,0,h.z))) / (2*h.z);
    // Transform the gradient as a covector; this also handles negative scales.
    float3 worldNormal = mul(gradient, (float3x3)m.worldToLocal);
    float lengthSquared = dot(worldNormal, worldNormal);
    valid=all(isfinite(worldNormal)) && isfinite(lengthSquared) && lengthSquared > 1e-16;
    return valid ? worldNormal * rsqrt(lengthSquared) : fallback;
}

bool HLGITraceMeshSdf(float3 origin, float3 direction, float maxT, int slot, out float t, out float3 normal,out bool validGradient,out bool unresolved)
{
    t = maxT;
    normal = 0;
    validGradient=false;
    unresolved=false;
    if (!HLGIHasMeshSdf(slot) || maxT <= 1e-4) return false;
    HLGISdfMetadata m = _HLGI_SdfMetadata[slot];
    float3 localOrigin = mul(m.worldToLocal,float4(origin,1)).xyz;
    float3 localDirection = mul((float3x3)m.worldToLocal,direction);
    float speed = length(localDirection);
    if (!isfinite(speed) || speed < 1e-12) return false;
    float begin, end;
    if (!HLGISdfBounds(localOrigin, localDirection, m.boundsMinResolution.xyz,
        m.boundsMinResolution.xyz + m.boundsSizeMinScale.xyz, maxT, begin, end)) return false;

    bool signedField = (m.valid & 2u) != 0u;
    float minimumVoxel = min(m.voxelSizeError.x, min(m.voxelSizeError.y,m.voxelSizeError.z));
    float epsilon = max(1e-6, minimumVoxel * (signedField ? 0.025 : 0.25));
    float refinementStep = max(1e-6, minimumVoxel * 0.2 / speed);
    float previousT = begin;
    float previousDistance = HLGISdfSample(m, localOrigin + localDirection * begin);
    float currentT = begin;
    bool hit = false;
    [loop] for (int step = 0; step < min(_HLGI_SdfTraceSteps,128) && currentT <= end; step++)
    {
        float distance = HLGISdfSample(m, localOrigin + localDirection * currentT);
        if (!isfinite(distance)) { t=begin;unresolved=true;return false; }
        if (abs(distance) <= epsilon)
        {
            hit = true;
            break;
        }
        if (signedField && distance * previousDistance < 0.0)
        {
            // Refine a sign change to the actual sampled zero surface instead of
            // returning the entire conservative interpolation-error shell as solid.
            float low = previousT, high = currentT;
            float lowDistance = previousDistance;
            [unroll] for (int refine = 0; refine < 6; refine++)
            {
                float middle = (low + high) * 0.5;
                float middleDistance = HLGISdfSample(m, localOrigin + localDirection * middle);
                if (middleDistance * lowDistance > 0) { low = middle; lowDistance = middleDistance; }
                else high = middle;
            }
            currentT = (low + high) * 0.5;
            hit = true;
            break;
        }
        previousT = currentT;
        previousDistance = distance;
        // Error-subtracted empty-space steps are conservative. In the remaining
        // uncertainty region use bounded voxel-scale refinement. Exhaustion is
        // not proof of an empty interval; the query wrapper preserves uncertainty.
        float emptyStep = max(0, abs(distance) - m.voxelSizeError.w) * m.boundsSizeMinScale.w;
        currentT += max(emptyStep, refinementStep);
    }
    if (!hit)
    {
        if(currentT<=end && currentT<maxT) { t=begin;unresolved=true; }
        return false;
    }
    if(currentT >= maxT) return false;
    t = currentT;
    normal = HLGISdfNormal(m, localOrigin + localDirection * t, -direction,validGradient);
    return true;
}

bool HLGITraceMeshSdfHit(float3 origin,float3 direction,float maxT,int slot,out HLGIHit result)
{
    result=HLGIEmptyHit(maxT);
    float t;float3 normal;bool validGradient,unresolved;
    if(!HLGITraceMeshSdf(origin,direction,maxT,slot,t,normal,validGradient,unresolved))
    {
        if(!unresolved)return false;
        // The clipped domain start is conservative. The last march location
        // cannot certify the skipped prefix, and must not become a fake hit.
        result.t=t;result.flags=HLGI_HIT_VALID|HLGI_HIT_MATERIAL_UNKNOWN|HLGI_HIT_QUERY_UNRESOLVED;
        return true;
    }
    bool signedField=(_HLGI_SdfMetadata[slot].valid&2u)!=0u;
    result.t=t;result.position=origin+direction*t;
    result.rawNg=result.shadingNormal=normal;
    result.ownerSlot=(uint)slot;
    result.stableId=(uint)_HLGI_Proxies[slot].identity.x;
    result.ownerRevision=(uint)_HLGI_Proxies[slot].identity.y;
    result.representation=signedField?HLGI_REPRESENTATION_SIGNED_SDF:HLGI_REPRESENTATION_UNSIGNED_SDF;
    result.flags=HLGI_HIT_VALID;
    if(validGradient) result.flags|=HLGI_HIT_GEOMETRIC_NORMAL;
    if(signedField&&validGradient) result.flags|=HLGI_HIT_ORIENTED_NG;
    // A volume gradient has no source primitive, submesh, UV or winding/front-face
    // identity. Even a signed field cannot manufacture a triangle area PDF.
    return true;
}

#endif
