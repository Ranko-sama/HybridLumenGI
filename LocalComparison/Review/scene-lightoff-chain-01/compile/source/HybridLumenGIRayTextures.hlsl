#ifndef HYBRID_LUMEN_GI_RAY_TEXTURES_INCLUDED
#define HYBRID_LUMEN_GI_RAY_TEXTURES_INCLUDED

// 64B, identical to HybridLumenGIRayTextureLayout.Metadata. These are original
// source mip texels, not surface-card samples. RGB is already decoded by the
// copy pass's source Texture.Load; never apply another gamma conversion here.
struct HLGIRayTextureMetadata
{
    uint4 geometry; // absolute 16B element offset, logical width/height, first stored mip
    uint4 state;    // total mip count, generation, ready bit, sampler bits
    uint4 storage;  // stored texel count, reserved zeros
    float4 sampling;// explicit LOD bias, reserved anisotropy setting, zeros
};
StructuredBuffer<HLGIRayTextureMetadata> _HLGI_RayTextureMetadata;
// Integer storage avoids any NaN canonicalization of packed half bit patterns.
// Sampler bit24 selects row-aligned pairs of RGBA16F; zero retains float32 bits.
StructuredBuffer<uint4> _HLGI_RayTextureTexels;
bool HLGIRayHalfPairs(HLGIRayTextureMetadata metadata) { return (metadata.state.w&0x01000000u)!=0u; }

bool HLGIRayTextureValid(uint2 handle,out HLGIRayTextureMetadata metadata)
{
    metadata=(HLGIRayTextureMetadata)0;
    uint count,stride;_HLGI_RayTextureMetadata.GetDimensions(count,stride);
    if(handle.x>=count || handle.y==0 || stride!=64u) return false;
    metadata=_HLGI_RayTextureMetadata[handle.x];
    uint width=metadata.geometry.y,height=metadata.geometry.z,first=metadata.geometry.w;
    uint mips=metadata.state.x,filter=metadata.state.w&3u;
    uint wrapU=(metadata.state.w>>8)&7u,wrapV=(metadata.state.w>>16)&7u;
    if(width==0 || height==0 || width>16384u || height>16384u ||
        metadata.state.y!=handle.y || metadata.state.z!=1u || mips==0 || mips>15u || first>=mips ||
        mips>(uint)firstbithigh(max(width,height))+1u || filter>2u || wrapU>3u || wrapV>3u ||
        (metadata.state.w&~0x01070703u)!=0 || any(metadata.storage.yzw!=0u) ||
        !all(isfinite(metadata.sampling)) || metadata.sampling.y<0 || metadata.sampling.y>16 ||
        metadata.sampling.y!=floor(metadata.sampling.y) || any(metadata.sampling.zw!=0)) return false;
    _HLGI_RayTextureTexels.GetDimensions(count,stride);
    uint offset=metadata.geometry.x,stored=metadata.storage.x;
    if(stride!=16u || offset>=count || stored==0) return false;
    // The validated 16384 x 16384 limit bounds the full sum to 357913941,
    // safely below uint overflow. Fixed accumulation preserves exact validation
    // and avoids a nested dynamic loop/early-return optimizer failure observed
    // when this sampler is called inside the material-map loop on DXC/WARP.
    uint expected=0,elements=0;bool halfPairs=HLGIRayHalfPairs(metadata);
    [unroll] for(uint mip=0u;mip<15u;mip++)
        if(mip>=first && mip<mips)
        {
            uint w=max(1u,width>>mip),h=max(1u,height>>mip);
            expected+=w*h;elements+=(halfPairs?(w+1u)/2u:w)*h;
        }
    return stored==expected && elements<=count-offset;
}

// Reduce before float-to-int conversion. A huge finite UV must not overflow an
// integer coordinate. Signed repeat preserves small negative fractions, while
// mirror uses its positive period and mirror-once reflects only at zero.
float HLGIRayBoundedUV(float uv,uint mode)
{
    if(mode==0u) return uv-trunc(uv);
    if(mode==1u) return saturate(uv);
    float magnitude=abs(uv);
    if(mode==3u) return saturate(magnitude);
    float phase=magnitude-floor(magnitude*0.5)*2;
    return phase>1?2-phase:phase;
}

int HLGIRayWrapTexel(int coordinate,int size,uint mode)
{
    if(mode==1u || mode==3u) return clamp(coordinate,0,size-1);
    int period=mode==2u?2*size:size;
    int wrapped=coordinate%period;
    if(wrapped<0) wrapped+=period;
    return mode==2u && wrapped>=size?period-1-wrapped:wrapped;
}

uint HLGIRayMipOffset(HLGIRayTextureMetadata metadata,uint mip)
{
    uint offset=metadata.geometry.x;
    [loop] for(uint level=metadata.geometry.w;level<mip;level++)
    {
        uint width=max(1u,metadata.geometry.y>>level);
        offset+=(HLGIRayHalfPairs(metadata)?(width+1u)/2u:width)*max(1u,metadata.geometry.z>>level);
    }
    return offset;
}

bool HLGIRayLoadTexel(uint offset,uint2 size,int2 coordinate,uint2 wrap,bool halfPairs,out float4 value)
{
    uint x=(uint)HLGIRayWrapTexel(coordinate.x,(int)size.x,wrap.x);
    uint y=(uint)HLGIRayWrapTexel(coordinate.y,(int)size.y,wrap.y);
    uint4 bits=_HLGI_RayTextureTexels[offset+y*(halfPairs?(size.x+1u)/2u:size.x)+(halfPairs?x/2u:x)];
    if(halfPairs)
    {
        uint2 pair=(x&1u)==0u?bits.xy:bits.zw;
        value=float4(f16tof32(pair.x&65535u),f16tof32(pair.x>>16),f16tof32(pair.y&65535u),f16tof32(pair.y>>16));
    }
    else value=asfloat(bits);
    return all(isfinite(value));
}

bool HLGIRaySampleMip(HLGIRayTextureMetadata metadata,float2 boundedUV,uint mip,bool bilinear,out float4 rgba)
{
    rgba=0;
    uint2 size=max(uint2(1,1),metadata.geometry.yz>>mip);
    uint2 wrap=uint2((metadata.state.w>>8)&7u,(metadata.state.w>>16)&7u);
    uint offset=HLGIRayMipOffset(metadata,mip);
    float2 texel=boundedUV*(float2)size-(bilinear?0.5:0.0);
    int2 coordinate=(int2)floor(texel);
    bool halfPairs=HLGIRayHalfPairs(metadata);
    if(!bilinear) return HLGIRayLoadTexel(offset,size,coordinate,wrap,halfPairs,rgba);
    float2 fraction=texel-floor(texel);
    float4 a,b,c,d;
    if(!HLGIRayLoadTexel(offset,size,coordinate,wrap,halfPairs,a) ||
        !HLGIRayLoadTexel(offset,size,coordinate+int2(1,0),wrap,halfPairs,b) ||
        !HLGIRayLoadTexel(offset,size,coordinate+int2(0,1),wrap,halfPairs,c) ||
        !HLGIRayLoadTexel(offset,size,coordinate+int2(1,1),wrap,halfPairs,d)) return false;
    rgba=(a*(1-fraction.x)+b*fraction.x)*(1-fraction.y)+
         (c*(1-fraction.x)+d*fraction.x)*fraction.y;
    return all(isfinite(rgba));
}

// Explicit isotropic LOD only. Point/bilinear choose floor(LOD+0.5), including
// ties. Trilinear blends adjacent mip levels. Bias is applied before clamping to
// [first resident mip,last mip]. Anisotropy is retained in metadata but not used.
// False means unknown/stale/invalid, never a proven transparent alpha value.
bool HLGISampleRayTexture(uint2 handle,float2 uv,float explicitAbsoluteLod,out float4 rgba)
{
    rgba=0;
    if(!all(isfinite(uv)) || !isfinite(explicitAbsoluteLod)) return false;
    HLGIRayTextureMetadata metadata;
    if(!HLGIRayTextureValid(handle,metadata)) return false;
    float lod=explicitAbsoluteLod+metadata.sampling.x;
    if(!isfinite(lod)) return false;
    lod=clamp(lod,(float)metadata.geometry.w,(float)(metadata.state.x-1));
    float2 bounded=float2(HLGIRayBoundedUV(uv.x,(metadata.state.w>>8)&7u),
                         HLGIRayBoundedUV(uv.y,(metadata.state.w>>16)&7u));
    uint filter=metadata.state.w&3u;
    float4 sampled=0;
    if(filter<2u)
    {
        if(!HLGIRaySampleMip(metadata,bounded,(uint)floor(lod+0.5),filter==1u,sampled)) return false;
    }
    else
    {
        uint lower=(uint)floor(lod),upper=min(lower+1,metadata.state.x-1);
        float4 a,b;
        if(!HLGIRaySampleMip(metadata,bounded,lower,true,a) ||
            !HLGIRaySampleMip(metadata,bounded,upper,true,b)) return false;
        float weight=lod-(float)lower;sampled=a*(1-weight)+b*weight;
    }
    if(!all(isfinite(sampled))) return false;
    rgba=sampled;return true;
}
#endif
