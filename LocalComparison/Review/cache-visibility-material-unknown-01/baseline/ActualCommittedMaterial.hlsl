void HLGIHardwareResolveCommittedMaterial(uint instanceIndex,uint primitive,
    HLGIHardwareInstance instance,HLGITriangleNormals attributes,float3x4 objectToWorld,float2 barycentric,
    float4 materialView,float3 direction,float coneRadiusAtOrigin,float coneSlope,
    bool shadowQuery,bool resolveMaterial,inout HLGIHit hit)
{
    float hitRadius=coneRadiusAtOrigin+coneSlope*hit.t;
    bool footprintKnown=isfinite(coneRadiusAtOrigin) && coneRadiusAtOrigin>=0 && isfinite(coneSlope) &&
        isfinite(hit.t) && hit.t>=0 && isfinite(hitRadius) && hitRadius>=0;
    bool covered=true;HLGIHitMaterialSurface material;float3 materialNormal;
    bool coverageKnown=false;
    if(footprintKnown)
        coverageKnown=HLGIHardwareEvaluateHit(instanceIndex,primitive,instance,attributes,objectToWorld,barycentric,
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
