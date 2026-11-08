#ifndef HYBRID_LUMEN_GI_HARDWARE_MATERIALS_INCLUDED
#define HYBRID_LUMEN_GI_HARDWARE_MATERIALS_INCLUDED

// Included after the hardware instance and normal/UV structures are declared.
#include "HybridLumenGIHitMaterials.hlsl"
#include "HybridLumenGIHardwareSurface.hlsl"

struct HLGIHardwareMaterialBinding { uint4 table,source; };
StructuredBuffer<HLGIHitMaterialRecord> _HLGI_HitMaterials;
StructuredBuffer<HLGIHardwareMaterialBinding> _HLGI_HardwareMaterialBindings;
StructuredBuffer<HLGITriangleSurface> _HLGI_HardwareTriangleSurface;

bool HLGIHardwareMaterialRecord(uint instanceIndex,HLGIHardwareInstance instance,out HLGIHitMaterialRecord record)
{
    record=(HLGIHitMaterialRecord)0;
    uint count,stride;_HLGI_HardwareMaterialBindings.GetDimensions(count,stride);
    if(stride!=32u || instanceIndex>=count) return false;
    HLGIHardwareMaterialBinding binding=_HLGI_HardwareMaterialBindings[instanceIndex];
    if(binding.table.y==0u || any(binding.table.zw!=0u) ||
        any(binding.source!=uint4(instance.identity.xyz,instance.geometry.w))) return false;
    _HLGI_HitMaterials.GetDimensions(count,stride);
    if(stride!=240u || binding.table.x>=count) return false;
    record=_HLGI_HitMaterials[binding.table.x];
    return record.identity.x==binding.table.y && record.identity.z==instance.identity.w && HLGIHitMaterialHeaderValid(record);
}

bool HLGIHardwareWorldTriangle(HLGIHardwareInstance instance,uint primitive,float3x4 objectToWorld,
    out HLGITriangleSurface triangleData,out float3 p0,out float3 p1,out float3 p2)
{
    triangleData=(HLGITriangleSurface)0;p0=p1=p2=0;
    uint count,stride;_HLGI_HardwareTriangleSurface.GetDimensions(count,stride);
    if(stride!=96u || primitive>=instance.geometry.z || instance.geometry.y>=count || primitive>=count-instance.geometry.y ||
        !all(isfinite(objectToWorld[0])) || !all(isfinite(objectToWorld[1])) || !all(isfinite(objectToWorld[2]))) return false;
    triangleData=_HLGI_HardwareTriangleSurface[instance.geometry.y+primitive];
    if(triangleData.p0.w!=1 || triangleData.p1.w!=1 || triangleData.p2.w!=1 || !all(isfinite(triangleData.p0)) ||
        !all(isfinite(triangleData.p1)) || !all(isfinite(triangleData.p2))) return false;
    p0=mul(objectToWorld,float4(triangleData.p0.xyz,1));p1=mul(objectToWorld,float4(triangleData.p1.xyz,1));p2=mul(objectToWorld,float4(triangleData.p2.xyz,1));
    return all(isfinite(p0)) && all(isfinite(p1)) && all(isfinite(p2));
}

uint HLGIHardwareMaterialTextureMask(HLGIHitMaterialRecord record,bool coverageOnly)
{
    uint flags=record.identity.y;
    if(coverageOnly)
    {
        if((flags&HLGI_MATERIAL_ALPHA_TEST)==0u || (flags&HLGI_MATERIAL_SMOOTH_BASE_ALPHA)!=0u) return 0u;
        return 1u|((flags&HLGI_MATERIAL_PARALLAX)!=0u?512u:0u);
    }
    uint required=1u;
    if((flags&HLGI_MATERIAL_METAL_SPEC_MAP)!=0u) required|=(flags&HLGI_MATERIAL_SPECULAR)!=0u?4u:2u;
    if((flags&HLGI_MATERIAL_NORMAL)!=0u) required|=8u;
    if((flags&HLGI_MATERIAL_OCCLUSION)!=0u) required|=16u;
    if((flags&HLGI_MATERIAL_EMISSION)!=0u) required|=32u;
    if((flags&HLGI_MATERIAL_DETAIL)!=0u) required|=448u;
    if((flags&HLGI_MATERIAL_PARALLAX)!=0u) required|=512u;
    return required;
}

// A generation/geometry failure remains an unknown nearest occluder. Callers
// must not turn this function's false result into a transparent candidate.
bool HLGIHardwareEvaluateHit(uint instanceIndex,uint primitive,HLGIHardwareInstance instance,HLGITriangleNormals attributes,
    float3x4 objectToWorld,float2 barycentrics,float4 materialView,float3 rayDirection,float coneRadius,bool coverageOnly,bool shadowCoverage,
    out bool covered,out HLGIHitMaterialSurface material,out float3 shadingNormal)
{
    covered=true;material=(HLGIHitMaterialSurface)0;shadingNormal=0;
    if(shadowCoverage && !coverageOnly) return false;
    HLGIHitMaterialRecord record;
    if(!HLGIHardwareMaterialRecord(instanceIndex,instance,record)) return false;
    // Stock URP ShadowCaster samples transformed base UV directly. Its alpha
    // test does not use the ForwardLit parallax offset or require a height map,
    // tangent frame or camera view. Ordinary visibility keeps surface coverage.
    if(shadowCoverage) record.identity.y&=~HLGI_MATERIAL_PARALLAX;
    HLGIHitMaterialLods lods=(HLGIHitMaterialLods)0;
    uint flags=record.identity.y,required=HLGIHardwareMaterialTextureMask(record,coverageOnly);
    if(coverageOnly && required==0u)
        return HLGIEvaluateHitCoverage(record,0,float3(0,0,1),lods,covered);
    float3 weights=float3(1-barycentrics.x-barycentrics.y,barycentrics);
    if(!all(isfinite(weights)) || any(weights<0)) return false;
    float2 uv0=float2(attributes.a.w,attributes.uvY.x),uv1=float2(attributes.b.w,attributes.uvY.y),uv2=float2(attributes.c.w,attributes.uvY.z);
    uint specified=required&record.identity.w;
    // An unknown cone only invalidates evaluations that sample an assigned map.
    if(specified!=0u && (!isfinite(coneRadius) || coneRadius<0)) return false;
    bool needsParallax=(flags&HLGI_MATERIAL_PARALLAX)!=0u;
    bool needsFrame=needsParallax || (!coverageOnly && (flags&(HLGI_MATERIAL_NORMAL|HLGI_MATERIAL_DETAIL))!=0u);
    bool needsTriangle=specified!=0u || needsFrame;
    HLGITriangleSurface triangleData;float3 p0,p1,p2;
    triangleData=(HLGITriangleSurface)0;p0=p1=p2=0;
    if(needsTriangle && !HLGIHardwareWorldTriangle(instance,primitive,objectToWorld,triangleData,p0,p1,p2)) return false;
    if(specified!=0u && (attributes.uvY.w<=0.5 || !all(isfinite(uv0)) || !all(isfinite(uv1)) || !all(isfinite(uv2)))) return false;
    float2 uv=specified!=0u?uv0*weights.x+uv1*weights.y+uv2*weights.z:0;
    float3 viewDirTS=float3(0,0,1);
    HLGIHardwareMaterialFrame frame=(HLGIHardwareMaterialFrame)0;
    if(needsFrame)
    {
        // Homogeneous view convention: w=1 is a world-space point (physical
        // ray origin/perspective camera); w=0 is a direction TOWARD an
        // orthographic viewer. Only parallax consumes this observation.
        if(needsParallax && (!all(isfinite(materialView)) || (materialView.w!=0 && materialView.w!=1))) return false;
        float3 outgoing0=-rayDirection,outgoing1=-rayDirection,outgoing2=-rayDirection;
        if(needsParallax)
        {
            outgoing0=materialView.xyz-materialView.w*p0;
            outgoing1=materialView.xyz-materialView.w*p1;
            outgoing2=materialView.xyz-materialView.w*p2;
        }
        if(attributes.face.w<=0.5 || !HLGITryHardwareMaterialFrame((float3x3)objectToWorld,(float3x3)instance.normalToWorld,
            attributes.a.xyz,attributes.b.xyz,attributes.c.xyz,triangleData.t0,triangleData.t1,triangleData.t2,weights,
            outgoing0,outgoing1,outgoing2,frame)) return false;
        viewDirTS=frame.viewDirTS;
    }
    [loop] for(uint map=0u;map<10u;map++)
    {
        if((specified&(1u<<map))==0u) continue;
        HLGIRayTextureMetadata texture;
        if(!HLGIRayTextureValid(HLGIHitTextureHandle(record,map),texture)) return false;
        float2 scale=record.baseST.xy;
        if(map==7u || map==8u) scale*=record.detailST.xy;
        float level;
        if(!HLGITryHardwareTextureLod(p0,p1,p2,uv0,uv1,uv2,scale,texture.geometry.yz,rayDirection,coneRadius,level)) return false;
        lods.values[map]=level;
    }
    if(coverageOnly) return HLGIEvaluateHitCoverage(record,uv,viewDirTS,lods,covered);
    if(!HLGIEvaluateHitMaterial(record,uv,viewDirTS,lods,material)) return false;
    bool known;
    if(needsFrame) known=HLGIApplyHardwareNormal(frame,material.normalTS,shadingNormal);
    else known=attributes.face.w>0.5 && HLGITryHardwareShadingNormal((float3x3)instance.normalToWorld,
        attributes.a.xyz,attributes.b.xyz,attributes.c.xyz,weights,shadingNormal);
    if(!known) { material=(HLGIHitMaterialSurface)0;shadingNormal=0; }
    return known;
}
// Compatibility for callers that describe an ordinary point-origin surface
// query. Shadow queries must use the explicit shadowCoverage overload above.
bool HLGIHardwareEvaluateHit(uint instanceIndex,uint primitive,HLGIHardwareInstance instance,HLGITriangleNormals attributes,
    float3x4 objectToWorld,float2 barycentrics,float3 rayOrigin,float3 rayDirection,float coneRadius,bool coverageOnly,
    out bool covered,out HLGIHitMaterialSurface material,out float3 shadingNormal)
{
    return HLGIHardwareEvaluateHit(instanceIndex,primitive,instance,attributes,objectToWorld,barycentrics,
        float4(rayOrigin,1),rayDirection,coneRadius,coverageOnly,false,covered,material,shadingNormal);
}
#endif
