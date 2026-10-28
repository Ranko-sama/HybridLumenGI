#ifndef HYBRID_LUMEN_GI_HARDWARE_NORMALS_INCLUDED
#define HYBRID_LUMEN_GI_HARDWARE_NORMALS_INCLUDED

// URP 17 LitForwardPass / GetVertexNormalInputs transform and normalize each
// vertex normal before interpolation, then normalize once in the fragment.
// Interpolating in object space first changes Ns under nonuniform scale/shear.
// Scaling finite inputs below avoids overflow/underflow without changing this
// order or the mathematical direction. It does not invent an invalid normal.
bool HLGIHardwareUnitNormal(float3 value, out float3 unitNormal)
{
    unitNormal=0;
    if(!all(isfinite(value))) return false;
    float scale=max(abs(value.x),max(abs(value.y),abs(value.z)));
    if(!(scale>0)) return false;
    value/=scale;
    float lengthSquared=dot(value,value);
    if(!isfinite(lengthSquared) || !(lengthSquared>0)) return false;
    unitNormal=value*rsqrt(lengthSquared);
    return all(isfinite(unitNormal));
}

bool HLGITryHardwareShadingNormal(float3x3 normalToWorld,
    float3 normalA,float3 normalB,float3 normalC,float3 weights,out float3 shadingNormal)
{
    shadingNormal=0;
    if(!all(isfinite(weights)) || !all(isfinite(normalToWorld[0])) ||
        !all(isfinite(normalToWorld[1])) || !all(isfinite(normalToWorld[2]))) return false;
    float3 largest=max(abs(normalToWorld[0]),max(abs(normalToWorld[1]),abs(normalToWorld[2])));
    float matrixScale=max(largest.x,max(largest.y,largest.z));
    if(!(matrixScale>0)) return false;
    normalToWorld/=matrixScale;
    float3 sourceA,sourceB,sourceC;
    if(!HLGIHardwareUnitNormal(normalA,sourceA) || !HLGIHardwareUnitNormal(normalB,sourceB) ||
        !HLGIHardwareUnitNormal(normalC,sourceC)) return false;
    float3 worldA,worldB,worldC;
    if(!HLGIHardwareUnitNormal(mul(normalToWorld,sourceA),worldA) ||
        !HLGIHardwareUnitNormal(mul(normalToWorld,sourceB),worldB) ||
        !HLGIHardwareUnitNormal(mul(normalToWorld,sourceC),worldC)) return false;
    // All three source vertices must be usable, even at a zero barycentric
    // weight. The fallback rawNg remains an occluder but carries no valid-Ns flag.
    return HLGIHardwareUnitNormal(worldA*weights.x+worldB*weights.y+worldC*weights.z,shadingNormal);
}
#endif
