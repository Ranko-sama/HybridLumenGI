#ifndef HLGI_EXACT_MESH_INCLUDED
#define HLGI_EXACT_MESH_INCLUDED
#include "HybridLumenGIHit.hlsl"
#include "HybridLumenGILightingPolicy.hlsl"
#include "HybridLumenGIHardwareNormals.hlsl"


StructuredBuffer<uint> _HLGI_HardwareMeshFlags;
int _HLGI_ExactCoversPublished;
// 128B, identical to HybridLumenGIHardwareBackend.InstanceData.
struct HLGIHardwareInstance
{
    column_major float4x4 normalToWorld;
    uint4 geometry; // owner slot, triangle offset, triangle count, source submesh
    uint4 identity; // stable ID, owner revision, geometry revision, effective Cull
    float4 diffuse,emission; // same-submesh constant approximation, not texture evaluation
};
StructuredBuffer<HLGIHardwareInstance> _HLGI_HardwareInstances;
struct HLGITriangleNormals { float4 a; float4 b; float4 c; float4 face; float4 uvY; };
StructuredBuffer<HLGITriangleNormals> _HLGI_HardwareTriangleNormals;
StructuredBuffer<uint4> _HLGI_HardwareTriangleBindings;
#include "HybridLumenGIHardwareMaterials.hlsl"

bool HLGIHardwareHasMesh(int slot)
{
    uint count,stride;_HLGI_HardwareMeshFlags.GetDimensions(count,stride);
    if(slot<0 || (uint)slot>=count) return false;
    return _HLGI_HardwareMeshFlags[slot]!=0;
}
bool HLGIHardwareInstanceValid(HLGIHardwareInstance instance)
{
    if(instance.geometry.x>=(uint)_HLGI_ProxyCount || instance.identity.z==0u || instance.identity.w>2u) return false;
    HLGIProxy proxy=_HLGI_Proxies[instance.geometry.x];
    return proxy.identity.w>0.5 && proxy.identity.w<1.5 &&
        (uint)proxy.identity.x==instance.identity.x && (uint)proxy.identity.y==instance.identity.y;
}
bool HLGIHardwareGeometry(uint instanceIndex,uint primitive,out HLGIHardwareInstance instance,
    out HLGITriangleNormals attributes,out float3 rawNg)
{
    instance=(HLGIHardwareInstance)0;attributes=(HLGITriangleNormals)0;rawNg=0;
    uint count,stride;_HLGI_HardwareInstances.GetDimensions(count,stride);
    if(instanceIndex>=count) return false;
    instance=_HLGI_HardwareInstances[instanceIndex];
    if(!HLGIHardwareInstanceValid(instance) || primitive>=instance.geometry.z) return false;
    _HLGI_HardwareTriangleNormals.GetDimensions(count,stride);
    if(instance.geometry.y>=count || primitive>=count-instance.geometry.y) return false;
    attributes=_HLGI_HardwareTriangleNormals[instance.geometry.y+primitive];
    float3 face=mul((float3x3)instance.normalToWorld,attributes.face.xyz);
    float scale=max(abs(face.x),max(abs(face.y),abs(face.z)));
    // Keep the geometric occluder if an attribute is unusable. It has no trusted
    // front-face/material orientation; do not replace it with an invented axis.
    if(!all(isfinite(face)) || scale==0) return true;
    face/=scale;float lengthSquared=dot(face,face);
    // Source winding is transformed as a covector, without a determinant sign.
    // DXR's instance front/back convention is also defined in object space; a
    // mirrored instance transform alone does not reverse it. Card identity uses
    // this same inverse-transpose source orientation, never a face-forward Ns.
    rawNg=face*rsqrt(lengthSquared);return true;
}
bool HLGIHardwareSideAllowed(uint cullMode,bool frontFace)
{
    return cullMode==0u || (cullMode==1u && !frontFace) || (cullMode==2u && frontFace);
}
float HLGIExactHitRadius(float coneRadiusAtOrigin,float coneSlope,float distance)
{
    float radius=coneRadiusAtOrigin+coneSlope*distance;
    return isfinite(coneRadiusAtOrigin) && coneRadiusAtOrigin>=0 && isfinite(coneSlope) &&
        isfinite(radius) && radius>=0 ? radius : -1;
}
// Coverage is required for every purpose. Visibility does not require a full
// material payload; a failure in an unrequested map cannot invalidate coverage.
void HLGIHardwareResolveCommittedMaterial(uint instanceIndex,uint primitive,
    HLGIHardwareInstance instance,HLGITriangleNormals attributes,float3x4 objectToWorld,float2 barycentric,
    float4 materialView,float3 direction,float coneRadiusAtOrigin,float coneSlope,
    bool shadowQuery,bool resolveMaterial,inout HLGIHit hit)
{
    if(!isfinite(hit.t) || hit.t<0)
    {
        hit.flags|=HLGI_HIT_MATERIAL_UNKNOWN;
        return;
    }
    float hitRadius=HLGIExactHitRadius(coneRadiusAtOrigin,coneSlope,hit.t);
    bool covered=true;HLGIHitMaterialSurface material;float3 materialNormal;
    bool coverageKnown=HLGIHardwareEvaluateHit(instanceIndex,primitive,instance,attributes,objectToWorld,barycentric,
        materialView,direction,hitRadius,true,shadowQuery,covered,material,materialNormal);
    // Recheck the committed identity against the frozen material/texture batch.
    // An unexpected transparent or stale result is unknown, never a miss that
    // would silently expose geometry beyond this committed nearest triangle.
    if(!coverageKnown || !covered) hit.flags|=HLGI_HIT_MATERIAL_UNKNOWN;
    else if(resolveMaterial && !shadowQuery)
    {
        bool materialKnown=HLGIHardwareEvaluateHit(instanceIndex,primitive,instance,attributes,objectToWorld,barycentric,
            materialView,direction,hitRadius,false,false,covered,material,materialNormal);
        if(!materialKnown) hit.flags|=HLGI_HIT_MATERIAL_UNKNOWN;
        else
        {
            hit.materialDiffuse=material.diffuseReflectance;hit.materialEmission=material.emission;
            hit.materialOcclusion=material.occlusion;hit.materialReceivesShadows=material.receivesShadows?1u:0u;
            hit.shadingNormal=materialNormal;hit.flags|=HLGI_HIT_UV_MATERIAL|HLGI_HIT_SHADING_NORMAL;
        }
    }
}
// Software traversal uses the same prepared transform, not a live Renderer value.
struct HLGIExactObjectTransform { column_major float4x4 objectToWorld; };
StructuredBuffer<HLGIExactObjectTransform> _HLGI_HardwareObjectToWorld;
bool HLGIExactObjectToWorld(uint instanceIndex,out float3x4 matrixValue)
{
    matrixValue=(float3x4)0;uint count,stride;_HLGI_HardwareObjectToWorld.GetDimensions(count,stride);
    if(stride!=64u || instanceIndex>=count)return false;
    matrixValue=(float3x4)_HLGI_HardwareObjectToWorld[instanceIndex].objectToWorld;
    return all(isfinite(matrixValue[0])) && all(isfinite(matrixValue[1])) && all(isfinite(matrixValue[2]));
}
#endif
