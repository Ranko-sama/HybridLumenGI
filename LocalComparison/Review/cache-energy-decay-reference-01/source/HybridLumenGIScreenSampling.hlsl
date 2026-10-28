#ifndef HLGI_SCREEN_SAMPLING_INCLUDED
#define HLGI_SCREEN_SAMPLING_INCLUDED

// A GI texel stores one full-resolution depth sample, not depth at its own UV.
// Sizes are positive, GI <= full, and within D3D12's 16384 texture dimension
// limit. Integer arithmetic avoids rounding across a full-pixel boundary when
// (giPixel + 0.5) * fullSize / giSize is mathematically an integer.
uint2 HLGIFullPixelForGiPixel(uint2 giPixel,uint2 giSize,uint2 fullSize)
{
    return ((giPixel*2u+1u)*fullSize)/(giSize*2u);
}

float2 HLGIFullPixelCenterUv(uint2 fullPixel,uint2 fullSize)
{
    return ((float2)fullPixel+0.5)/(float2)fullSize;
}

float2 HLGIGiSampleUv(uint2 giPixel,uint2 giSize,uint2 fullSize)
{
    return HLGIFullPixelCenterUv(HLGIFullPixelForGiPixel(giPixel,giSize,fullSize),fullSize);
}

uint2 HLGIFullPixelForUv(float2 uv,uint2 fullSize)
{
    // Callers reject nonfinite/offscreen coordinates before this conversion.
    return min((uint2)(uv*(float2)fullSize),fullSize-1u);
}

uint2 HLGIClosestGiPixel(float2 uv,uint2 giSize,uint2 fullSize)
{
    // Actual centers s(i) = floor((i+0.5)*F/L)+0.5 differ from the uniform
    // GI centers by at most half a full pixel. With F/L >= 1, the closest s(i)
    // is among floor(uv*L)-1, floor(uv*L), floor(uv*L)+1. Test actual centers
    // per axis; separability also gives the closest center in 2D. Equal-distance
    // ties select the smaller index. Never interpolate the encoded geometry.
    int2 basePixel=clamp((int2)floor(uv*(float2)giSize),0,(int2)giSize-1);
    float2 target=uv*(float2)fullSize;
    uint2 best=(uint2)max(basePixel-1,0);
    float2 bestDistance=abs((float2)HLGIFullPixelForGiPixel(best,giSize,fullSize)+0.5-target);
    [unroll] for(int offset=0;offset<=1;offset++)
    {
        uint2 candidate=(uint2)min(basePixel+offset,(int2)giSize-1);
        float2 candidateDistance=abs((float2)HLGIFullPixelForGiPixel(candidate,giSize,fullSize)+0.5-target);
        if(candidateDistance.x<bestDistance.x) { best.x=candidate.x;bestDistance.x=candidateDistance.x; }
        if(candidateDistance.y<bestDistance.y) { best.y=candidate.y;bestDistance.y=candidateDistance.y; }
    }
    return best;
}

void HLGIGiBilinearFootprint(float2 uv,uint2 giSize,uint2 fullSize,
    out uint2 lower,out uint2 upper,out float2 fraction)
{
    uint2 closest=HLGIClosestGiPixel(uv,giSize,fullSize);
    float2 target=uv*(float2)fullSize;
    float2 center=(float2)HLGIFullPixelForGiPixel(closest,giSize,fullSize)+0.5;
    lower=closest;upper=closest;
    if(target.x<center.x) lower.x=(uint)max((int)closest.x-1,0);
    else upper.x=min(closest.x+1u,giSize.x-1u);
    if(target.y<center.y) lower.y=(uint)max((int)closest.y-1,0);
    else upper.y=min(closest.y+1u,giSize.y-1u);
    float2 lo=(float2)HLGIFullPixelForGiPixel(lower,giSize,fullSize)+0.5;
    float2 hi=(float2)HLGIFullPixelForGiPixel(upper,giSize,fullSize)+0.5;
    // Duplicate edge indices have a zero span. Interior sample centers have
    // weight one on themselves, even for odd/non-integer downsample ratios.
    fraction=float2(hi.x>lo.x?saturate((target.x-lo.x)/(hi.x-lo.x)):0,
                    hi.y>lo.y?saturate((target.y-lo.y)/(hi.y-lo.y)):0);
}

#endif
