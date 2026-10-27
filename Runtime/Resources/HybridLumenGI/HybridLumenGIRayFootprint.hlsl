#ifndef HYBRID_LUMEN_GI_RAY_FOOTPRINT_INCLUDED
#define HYBRID_LUMEN_GI_RAY_FOOTPRINT_INCLUDED

// Radius is world distance perpendicular to the ray, not diameter. slope=dr/ds
// is a dimensionless radial slope, not a full/half spread angle. Texture LOD
// consumes DIAMETER 2*radius. See the 2021 Ray Cones paper's published errata.
struct HLGIRayFootprint { float radius;float slope;uint valid; };

bool HLGIFootprintUnit(float3 value,out float3 unit)
{
    unit=0;
    if(!all(isfinite(value))) return false;
    float scale=max(abs(value.x),max(abs(value.y),abs(value.z)));
    if(!(scale>0)) return false;
    float3 scaled=value/scale;unit=scaled*rsqrt(dot(scaled,scaled));
    return all(isfinite(unit));
}
bool HLGIFootprintLength(float3 value,out float result)
{
    result=0;
    if(!all(isfinite(value))) return false;
    float scale=max(abs(value.x),max(abs(value.y),abs(value.z)));
    if(scale==0) return true;
    result=scale*length(value/scale);return isfinite(result);
}
bool HLGITryMakeRayFootprint(float radius,float slope,out HLGIRayFootprint footprint)
{
    footprint=(HLGIRayFootprint)0;
    if(!isfinite(radius) || !isfinite(slope) || radius<0) return false;
    footprint.radius=radius;footprint.slope=slope;footprint.valid=1u;return true;
}
bool HLGIAdvanceRayFootprint(HLGIRayFootprint footprint,float distance,out HLGIRayFootprint advanced)
{
    advanced=(HLGIRayFootprint)0;
    if(footprint.valid!=1u || !isfinite(distance) || distance<0) return false;
    // Apply this to every forward origin shift, including near/far handoff. Do
    // not restart the cone at the shifted origin or advance the same span twice.
    if(!isfinite(footprint.radius) || !isfinite(footprint.slope) || footprint.radius<0) return false;
    float radius=footprint.radius+footprint.slope*distance;
    // Converging cones are valid only before their focus, not after it.
    return HLGITryMakeRayFootprint(radius,footprint.slope,advanced);
}
bool HLGITryAngleSpread(float fullAngle,out float radialSlope)
{
    radialSlope=0;
    if(!isfinite(fullAngle) || fullAngle<0 || fullAngle>=3.14159265358979323846) return false;
    radialSlope=tan(0.5*fullAngle);return isfinite(radialSlope) && radialSlope>=0;
}

// The farthest vertex of a planar convex quad bounds its projection on the
// ray-normal plane. This circumscribes the actual rectangle, rather than using
// its area-equivalent disk. Offsets need not be centered on the ray origin.
bool HLGITryFootprintFromCorners(float3 a,float3 b,float3 c,float3 d,float3 rayDirection,
    out HLGIRayFootprint footprint)
{
    footprint=(HLGIRayFootprint)0;float3 ray;
    if(!HLGIFootprintUnit(rayDirection,ray)) return false;
    float la,lb,lc,ld;
    if(!HLGIFootprintLength(a-ray*dot(a,ray),la) || !HLGIFootprintLength(b-ray*dot(b,ray),lb) ||
        !HLGIFootprintLength(c-ray*dot(c,ray),lc) || !HLGIFootprintLength(d-ray*dot(d,ray),ld)) return false;
    return HLGITryMakeRayFootprint(max(max(la,lb),max(lc,ld)),0,footprint);
}

// pX/pY are actual accepted same-surface neighbor positions, at signed known
// full-resolution pixel offsets. representedFullPixelSpan normally equals 1,1:
// current GI stores one selected full-pixel center, not the whole GI block.
// Caller must reject depth discontinuities / unknown geometric identity before
// supplying differences. No invalid-neighbor fallback manufactures radius zero.
// This returns only the surface spatial footprint. Its zero slope represents
// a parallel bundle, NOT a completed diffuse BRDF angular-prefiltering model.
bool HLGITryScreenFootprint(float3 p,float3 pX,float3 pY,float2 neighborPixelDelta,
    float2 representedFullPixelSpan,float3 rayDirection,out HLGIRayFootprint footprint)
{
    footprint=(HLGIRayFootprint)0;
    if(!all(isfinite(p)) || !all(isfinite(pX)) || !all(isfinite(pY)) ||
        !all(isfinite(neighborPixelDelta)) || any(neighborPixelDelta==0) ||
        !all(isfinite(representedFullPixelSpan)) || any(representedFullPixelSpan<=0)) return false;
    float3 halfU=(pX-p)*(0.5*representedFullPixelSpan.x/neighborPixelDelta.x);
    float3 halfV=(pY-p)*(0.5*representedFullPixelSpan.y/neighborPixelDelta.y);
    float lu,lv;
    if(!HLGIFootprintLength(halfU,lu) || !HLGIFootprintLength(halfV,lv) || !(lu>0) || !(lv>0)) return false;
    // Two collinear neighbor axes cannot identify a 2D surface pixel.
    float3 u=halfU/lu,v=halfV/lv;
    if(dot(cross(u,v),cross(u,v))<=1e-12) return false;
    return HLGITryFootprintFromCorners(-halfU-halfV,halfU-halfV,-halfU+halfV,halfU+halfV,rayDirection,footprint);
}

// worldToCard maps directly to [0,1], as HLGISurfaceCardUv does. Integer cell
// boundaries exactly match the anchor scanner, including odd tile dimensions.
// The anchor can be near an edge; subtract its actual UV from all four corners.
// Ng is geometry, never the normal-map Ns. The inverse describes its local
// tangent plane only; chart curvature/visibility still require the caller's gates.
bool HLGITryCardPatchFootprint(column_major float4x4 worldToCard,float3 anchor,float3 geometricNormal,
    uint2 cardPixelCount,uint2 cell,uint gridSize,float3 rayDirection,out HLGIRayFootprint footprint)
{
    footprint=(HLGIRayFootprint)0;
    if(gridSize<1u || gridSize>4u || any(cell>=gridSize) || any(cardPixelCount==0u) ||
        any(cardPixelCount>32768u) || !all(isfinite(anchor)) ||
        !all(isfinite(worldToCard[0])) || !all(isfinite(worldToCard[1])) ||
        !all(isfinite(worldToCard[2])) || any(worldToCard[3]!=float4(0,0,0,1))) return false;
    float3 n;if(!HLGIFootprintUnit(geometricNormal,n)) return false;
    uint2 begin=cell*cardPixelCount/gridSize,end=(cell+1u)*cardPixelCount/gridSize;
    if(any(end<=begin)) return false;
    float2 low=(float2)begin/cardPixelCount,high=(float2)end/cardPixelCount;
    float3 uvw=mul(worldToCard,float4(anchor,1)).xyz;
    if(!all(isfinite(uvw)) || uvw.z<0 || uvw.z>1 || any(uvw.xy<low) || any(uvw.xy>high)) return false;
    float3 gu=worldToCard[0].xyz,gv=worldToCard[1].xyz;
    gu-=n*dot(n,gu);gv-=n*dot(n,gv);
    float3 maximum=max(abs(gu),abs(gv));float scale=max(maximum.x,max(maximum.y,maximum.z));
    if(!all(isfinite(gu)) || !all(isfinite(gv)) || !(scale>0)) return false;
    gu/=scale;gv/=scale;
    float a=dot(gu,gu),b=dot(gu,gv),c=dot(gv,gv),det=a*c-b*b;
    if(!isfinite(det) || !(det>1e-12*a*c)) return false;
    float3 basisU=((gu*c-gv*b)/det)/scale,basisV=((gv*a-gu*b)/det)/scale;
    float2 deltaLow=low-uvw.xy,deltaHigh=high-uvw.xy;
    return HLGITryFootprintFromCorners(basisU*deltaLow.x+basisV*deltaLow.y,
        basisU*deltaHigh.x+basisV*deltaLow.y,basisU*deltaLow.x+basisV*deltaHigh.y,
        basisU*deltaHigh.x+basisV*deltaHigh.y,rayDirection,footprint);
}

// Project an incoming ray-normal disk onto the Ng tangent plane and then onto
// the outgoing ray-normal plane. The largest singular value bounds the ellipse.
// BRDF/curvature angular propagation is deliberately not inferred here.
bool HLGITryRetargetFootprint(HLGIRayFootprint incoming,float3 incomingDirection,float3 geometricNormal,
    float3 outgoingDirection,out HLGIRayFootprint outgoing)
{
    outgoing=(HLGIRayFootprint)0;float3 source,target,n;
    if(incoming.valid!=1u || !isfinite(incoming.radius) || incoming.radius<0 || !isfinite(incoming.slope) ||
        !HLGIFootprintUnit(incomingDirection,source) || !HLGIFootprintUnit(outgoingDirection,target) ||
        !HLGIFootprintUnit(geometricNormal,n)) return false;
    float cosine=dot(n,source);if(abs(cosine)<1e-6) return false;
    float3 up=abs(source.z)<0.9?float3(0,0,1):float3(0,1,0),u;
    if(!HLGIFootprintUnit(cross(up,source),u)) return false;
    float3 v=cross(source,u);
    u-=source*(dot(n,u)/cosine);v-=source*(dot(n,v)/cosine);
    u-=target*dot(target,u);v-=target*dot(target,v);
    float3 maximum=max(abs(u),abs(v));float scale=max(maximum.x,max(maximum.y,maximum.z));
    if(!all(isfinite(u)) || !all(isfinite(v)) || !(scale>0)) return false;
    u/=scale;v/=scale;
    float a=dot(u,u),b=dot(u,v),c=dot(v,v);
    float eigenvalue=0.5*(a+c+sqrt(max(0,(a-c)*(a-c)+4*b*b)));
    float radius=(incoming.radius*scale)*sqrt(eigenvalue);
    return HLGITryMakeRayFootprint(radius,0,outgoing);
}

// The spatial footprint must already be expressed perpendicular to this shadow
// direction (use screen/card/retarget above). Directional-light connections are
// parallel. Point/spot connections converge on the single light position: at
// blocker distance t, r(t)=r0*(1-t/L). These are not area-light penumbra models.
bool HLGITryDirectionalShadowFootprint(HLGIRayFootprint surface,out HLGIRayFootprint shadow)
{
    shadow=(HLGIRayFootprint)0;
    if(surface.valid!=1u || !isfinite(surface.slope)) return false;
    return HLGITryMakeRayFootprint(surface.radius,0,shadow);
}
bool HLGITryPointShadowFootprint(HLGIRayFootprint surface,float lightDistance,out HLGIRayFootprint shadow)
{
    shadow=(HLGIRayFootprint)0;
    if(surface.valid!=1u || !isfinite(surface.slope) || !isfinite(lightDistance) || !(lightDistance>0)) return false;
    return HLGITryMakeRayFootprint(surface.radius,-surface.radius/lightDistance,shadow);
}
#endif
