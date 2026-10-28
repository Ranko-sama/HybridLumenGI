#ifndef HLGI_SCREEN_GEOMETRY_INCLUDED
#define HLGI_SCREEN_GEOMETRY_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

// RGBA32F history contract (point loads only): xy = shading-normal oct coordinates;
// z = geometric-normal oct12+12 as a numeric integer + 1; w = unchanged raw depth.
// z == 0 is an invalid receiver; z == -1 is a valid receiver with unknown Ng.
// All integer codes 1..2^24 are exactly representable in float32. Do not reinterpret
// bits, use half precision, or filter the encoded values before decoding them.
bool HLGIScreenGeometryDepthValid(float rawDepth)
{
    if(!isfinite(rawDepth) || rawDepth<0 || rawDepth>1) return false;
#if UNITY_REVERSED_Z
    return rawDepth>1e-6;
#else
    return rawDepth<1-1e-6;
#endif
}

bool HLGIScreenGeometryUnitNormal(float3 value,out float3 unitNormal)
{
    unitNormal=0;
    float lengthSquared=dot(value,value);
    if(!all(isfinite(value)) || !isfinite(lengthSquared) || lengthSquared<1e-12) return false;
    unitNormal=value*rsqrt(lengthSquared);
    return true;
}

float4 HLGIPackScreenGeometry(float3 shadingNormal,float3 geometricNormal,bool hasGeometricNormal,float rawDepth)
{
    float3 ns,ng;
    if(!HLGIScreenGeometryDepthValid(rawDepth) || !HLGIScreenGeometryUnitNormal(shadingNormal,ns)) return 0;
    float code=-1;
    if(hasGeometricNormal && HLGIScreenGeometryUnitNormal(geometricNormal,ng))
    {
        float2 oct=PackNormalOctQuadEncode(ng);
        uint2 quantized=(uint2)floor(saturate(oct*0.5+0.5)*4095.0+0.5);
        uint integerCode=quantized.x+(quantized.y<<12)+1u;
        code=(float)integerCode;
    }
    return float4(PackNormalOctQuadEncode(ns),code,rawDepth);
}

bool HLGIDecodeScreenGeometry(float4 packed,out float3 shadingNormal,out float3 geometricNormal,out bool hasGeometricNormal)
{
    shadingNormal=0;geometricNormal=0;hasGeometricNormal=false;
    if(!all(isfinite(packed)) || any(abs(packed.xy)>1) || !HLGIScreenGeometryDepthValid(packed.w)) return false;
    bool known=packed.z>=1 && packed.z<=16777216.0 && floor(packed.z)==packed.z;
    if(packed.z!=-1 && !known) return false;
    shadingNormal=UnpackNormalOctQuadEncode(packed.xy);
    if(known)
    {
        uint bits=(uint)packed.z-1u;
        uint2 quantized=uint2(bits&4095u,bits>>12);
        float2 oct=(float2)quantized*(2.0/4095.0)-1;
        geometricNormal=UnpackNormalOctQuadEncode(oct);
        hasGeometricNormal=true;
    }
    return true;
}

#endif
