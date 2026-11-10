#ifndef HYBRID_LUMEN_GI_HARDWARE_SURFACE_INCLUDED
#define HYBRID_LUMEN_GI_HARDWARE_SURFACE_INCLUDED
#include "HybridLumenGIHardwareNormals.hlsl"

// Separate from the existing 80-byte normal/UV payload. All positions are
// object-space source vertices; w is a validity bit. Tangent w is source +/-1.
struct HLGITriangleSurface { float4 p0,p1,p2,t0,t1,t2; };
struct HLGIHardwareMaterialFrame
{
    float3 normal,tangent,bitangent; // interpolants, deliberately not orthonormalized
    float3 viewDirTS;
};

bool HLGIScaleDirectionMatrix(inout float3x3 value)
{
    if(!all(isfinite(value[0])) || !all(isfinite(value[1])) || !all(isfinite(value[2]))) return false;
    float3 greatest=max(abs(value[0]),max(abs(value[1]),abs(value[2])));
    float scale=max(greatest.x,max(greatest.y,greatest.z));
    if(!(scale>0)) return false;
    value/=scale;return true;
}

// URP Lit transforms and normalizes N and T at each vertex. It interpolates
// those values and the handedness, then constructs B from the interpolants.
// Gram-Schmidt or normalizing the interpolated N/T first changes normal maps.
bool HLGITryHardwareMaterialFrame(float3x3 objectToWorld,float3x3 normalToWorld,
    float3 normal0,float3 normal1,float3 normal2,float4 tangent0,float4 tangent1,float4 tangent2,
    float3 weights,float3 outgoing0,float3 outgoing1,float3 outgoing2,out HLGIHardwareMaterialFrame frame,
    bool requireNormalBasis=true)
{
    frame=(HLGIHardwareMaterialFrame)0;
    if(!all(isfinite(weights)) || any(weights<0) || abs(dot(weights,1)-1)>0.0001 ||
        !all(isfinite(tangent0)) || !all(isfinite(tangent1)) || !all(isfinite(tangent2)) ||
        abs(tangent0.w)!=1 || abs(tangent1.w)!=1 || abs(tangent2.w)!=1 ||
        !HLGIScaleDirectionMatrix(objectToWorld) || !HLGIScaleDirectionMatrix(normalToWorld)) return false;
    float determinantSign=determinant(objectToWorld);
    if(!isfinite(determinantSign) || determinantSign==0) return false;
    determinantSign=determinantSign<0?-1:1;
    float3 n0,n1,n2,t0,t1,t2,view0,view1,view2;
    if(!HLGIHardwareUnitNormal(normal0,n0) || !HLGIHardwareUnitNormal(normal1,n1) || !HLGIHardwareUnitNormal(normal2,n2) ||
        !HLGIHardwareUnitNormal(tangent0.xyz,t0) || !HLGIHardwareUnitNormal(tangent1.xyz,t1) || !HLGIHardwareUnitNormal(tangent2.xyz,t2) ||
        !HLGIHardwareUnitNormal(outgoing0,view0) || !HLGIHardwareUnitNormal(outgoing1,view1) ||
        !HLGIHardwareUnitNormal(outgoing2,view2)) return false;
    if(!HLGIHardwareUnitNormal(mul(normalToWorld,n0),n0) || !HLGIHardwareUnitNormal(mul(normalToWorld,n1),n1) ||
        !HLGIHardwareUnitNormal(mul(normalToWorld,n2),n2) || !HLGIHardwareUnitNormal(mul(objectToWorld,t0),t0) ||
        !HLGIHardwareUnitNormal(mul(objectToWorld,t1),t1) || !HLGIHardwareUnitNormal(mul(objectToWorld,t2),t2)) return false;
    float3 n=n0*weights.x+n1*weights.y+n2*weights.z,t=t0*weights.x+t1*weights.y+t2*weights.z;
    float sign=dot(float3(tangent0.w,tangent1.w,tangent2.w),weights)*determinantSign;
    float3 b=cross(n,t)*sign;
    if(!all(isfinite(n)) || !all(isfinite(t)) || !all(isfinite(b))) return false;
    bool normalBasisKnown=dot(n,n)>1e-16 && dot(b,b)>1e-16;
    if(requireNormalBasis && !normalBasisKnown) return false;
    frame.normal=n;frame.tangent=t;frame.bitangent=b;
    // URP 17 defines REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR whenever
    // _PARALLAXMAP is enabled. Its vertex shader converts each vertex's view
    // vector to tangent space, and the fragment interpolates those vectors.
    // This differs from rebuilding the view basis from interpolated N/T.
    // Perspective callers supply origin-worldPi; orthographic callers supply
    // the same world-space viewing direction for all three vertices.
    float3 b0=cross(n0,t0)*(tangent0.w*determinantSign),b1=cross(n1,t1)*(tangent1.w*determinantSign),b2=cross(n2,t2)*(tangent2.w*determinantSign);
    // Parallax remains defined through interpolant cancellation if the vertex frames are valid.
    if(!normalBasisKnown && any(float3(dot(b0,b0),dot(b1,b1),dot(b2,b2))<=1e-16)) return false;
    float3 ts0=float3(dot(t0,view0),dot(b0,view0),dot(n0,view0))*rsqrt(dot(n0,n0));
    float3 ts1=float3(dot(t1,view1),dot(b1,view1),dot(n1,view1))*rsqrt(dot(n1,n1));
    float3 ts2=float3(dot(t2,view2),dot(b2,view2),dot(n2,view2))*rsqrt(dot(n2,n2));
    frame.viewDirTS=ts0*weights.x+ts1*weights.y+ts2*weights.z;
    return all(isfinite(frame.viewDirTS));
}

bool HLGIApplyHardwareNormal(HLGIHardwareMaterialFrame frame,float3 normalTS,out float3 normalWS)
{
    normalWS=0;
    if(!all(isfinite(normalTS))) return false;
    return HLGIHardwareUnitNormal(frame.tangent*normalTS.x+frame.bitangent*normalTS.y+frame.normal*normalTS.z,normalWS);
}

// Explicit world-space cone radius at the hit, measured perpendicular to the
// ray. Project its disk onto the triangle and find the largest singular value
// of the world-to-texel UV derivative. LOD uses footprint DIAMETER (2*radius).
// The caller must propagate radius/spread through transport; this helper does
// not manufacture a screen derivative or claim that fixed mip zero is adequate.
// Leave the finite footprint LOD unclamped so the texture sampler can apply
// mip bias before clamping to the actual resident levels.
bool HLGITryHardwareTextureLod(float3 p0,float3 p1,float3 p2,float2 uv0,float2 uv1,float2 uv2,
    float2 uvScale,uint2 textureSize,float3 rayDirection,float coneRadius,out float lod)
{
    lod=0;
    if(!all(isfinite(p0)) || !all(isfinite(p1)) || !all(isfinite(p2)) ||
        !all(isfinite(uv0)) || !all(isfinite(uv1)) || !all(isfinite(uv2)) || !all(isfinite(uvScale)) ||
        any(textureSize==0u) || any(textureSize>16384u) || !isfinite(coneRadius) || coneRadius<0) return false;
    float3 ray;if(!HLGIHardwareUnitNormal(rayDirection,ray)) return false;
    float3 e1=p1-p0,e2=p2-p0;
    float3 largest=max(abs(e1),abs(e2));float scale=max(largest.x,max(largest.y,largest.z));
    if(!all(isfinite(e1)) || !all(isfinite(e2)) || !(scale>0)) return false;
    e1/=scale;e2/=scale;
    float3 area=cross(e1,e2);float areaSquared=dot(area,area);
    if(!isfinite(areaSquared) || !(areaSquared>1e-20)) return false;
    float2 delta1=uv1-uv0,delta2=uv2-uv0;
    float3 g1=cross(e2,area)/areaSquared,g2=cross(area,e1)/areaSquared;
    float3 gradU=(g1*delta1.x+g2*delta2.x)/scale*(uvScale.x*(float)textureSize.x);
    float3 gradV=(g1*delta1.y+g2*delta2.y)/scale*(uvScale.y*(float)textureSize.y);
    if(!all(isfinite(gradU)) || !all(isfinite(gradV))) return false;
    if(coneRadius==0) return true;
    largest=max(abs(gradU),abs(gradV));float gradientScale=max(largest.x,max(largest.y,largest.z));
    if(gradientScale==0) return true; // Constant UV is a point footprint.
    gradU/=gradientScale;gradV/=gradientScale;
    float cosine=abs(dot(area*rsqrt(areaSquared),ray));
    float maximumLod=(float)firstbithigh(max(textureSize.x,textureSize.y));
    if(cosine<1e-6) { lod=maximumLod;return true; }
    float u=dot(gradU,ray)/cosine,v=dot(gradV,ray)/cosine;
    float a=dot(gradU,gradU)+u*u,b=dot(gradU,gradV)+u*v,c=dot(gradV,gradV)+v*v;
    float covarianceScale=max(a,max(abs(b),c));
    if(!isfinite(covarianceScale) || !(covarianceScale>0)) return false;
    a/=covarianceScale;b/=covarianceScale;c/=covarianceScale;
    float eigenvalue=0.5*(a+c+sqrt(max(0,(a-c)*(a-c)+4*b*b)));
    float footprintLog=1+log2(coneRadius)+log2(gradientScale)+0.5*(log2(covarianceScale)+log2(eigenvalue));
    if(!isfinite(footprintLog)) return false;
    lod=footprintLog;return true;
}
#endif
