#include "HybridLumenGIHit.hlsl"
#include "HybridLumenGIRayFootprint.hlsl"
#include "HybridLumenGIAreaEmission.hlsl"

// Existing RadianceValidity WARP host input/output layout.
struct AreaInput { uint4 mode; float4 unused[12]; };
struct AreaOutput { float4 values[23]; };
StructuredBuffer<AreaInput> inputs : register(t0);
RWStructuredBuffer<AreaOutput> outputs : register(u0);
cbuffer Counts : register(b0) { uint count; }
static uint active;
static const float _HLGI_MaxDistance = 10;
static const uint _HLGI_AreaMaterialGeneration = 19;
#define PI 3.14159265358979323846

// Freeze the shared bridge inputs. Mode 1 represents known opaque coverage
// with a deferred shading-only map. Mode 2 represents an unavailable alpha map.
struct HLGIHardwareInstance { uint unused; };
struct HLGITriangleNormals { uint unused; };
struct HLGIHitMaterialSurface { float3 diffuseReflectance, emission; float occlusion; bool receivesShadows; };
bool HLGIHardwareEvaluateHit(uint instanceIndex,uint primitive,HLGIHardwareInstance instance,
    HLGITriangleNormals attributes,float3x4 objectToWorld,float2 barycentrics,float4 view,
    float3 direction,float radius,bool coverageOnly,bool shadowCoverage,
    out bool covered,out HLGIHitMaterialSurface material,out float3 normal)
{
    covered = true;
    material = (HLGIHitMaterialSurface)0;
    material.emission = float3(.5, 1, 2);
    normal = float3(0, -1, 0);
    return coverageOnly ? active != 2u : active == 7u;
}

#include "ActualCommittedMaterial.hlsl"

bool TraceSceneHit(float3 origin,float3 direction,float limit,HLGIRayFootprint footprint,float4 view,out HLGIHit hit)
{
    hit = HLGIEmptyHit(limit);
    if (active == 0u) return false;
    hit.t = active == 6u ? 2.0 - 0.000001 : active == 7u ? 2.0 : 1.0;
    if (active == 4u)
    {
        hit.flags = HLGI_HIT_VALID | HLGI_HIT_QUERY_UNRESOLVED;
        return true;
    }
    bool emitter = active == 3u || active == 7u;
    hit.flags = HLGI_HIT_VALID | HLGI_HIT_TRIANGLE;
    if (active != 5u) hit.flags |= HLGI_HIT_FRONT_FACE_KNOWN | HLGI_HIT_GEOMETRIC_NORMAL;
    hit.ownerSlot = emitter ? 17u : 9u;
    hit.stableId = 3u; hit.ownerRevision = 5u; hit.geometryRevision = 7u;
    hit.hardwareInstance = emitter ? 11u : 8u;
    hit.submesh = 0u; hit.primitive = emitter ? 13u : 3u;
    hit.position = origin + hit.t * direction;
    HLGIHardwareResolveCommittedMaterial(hit.hardwareInstance,hit.primitive,
        (HLGIHardwareInstance)0,(HLGITriangleNormals)0,(float3x4)0,0,view,direction,0,0,false,true,hit);
    return true;
}

float HLGITransportDirectionPdf(float3 origin,float3 n,float4 guide,float3 direction) { return 1; }
#include "ActualAreaContribution.hlsl"

[numthreads(64,1,1)]
void CSAreaCoveredBlocker(uint3 id : SV_DispatchThreadID)
{
    if (id.x >= count) return;
    active = inputs[id.x].mode.x;
    HLGIAreaSample sample = (HLGIAreaSample)0;
    sample.emitter.identity = uint4(17, 3, 5, 7);
    sample.emitter.geometry = uint4(11, 0, 13, 19);
    sample.direction = float3(0, 1, 0);
    sample.position = 2 * sample.direction;
    sample.distance = 2;
    sample.pdf = 1;
    float3 value; bool worldHit; HLGIHit hit;
    bool known = HLGIAreaLightContribution(0,sample.direction,0,sample,(HLGIRayFootprint)0,float4(0,0,0,1),value,worldHit,hit);
    AreaOutput output = (AreaOutput)0;
    output.values[0] = float4(value,known ? 1 : 0);
    output.values[1] = float4(worldHit ? 1 : 0,HLGIHitMaterialKnown(hit) ? 1 : 0,hit.flags,hit.t);
    outputs[id.x] = output;
}
