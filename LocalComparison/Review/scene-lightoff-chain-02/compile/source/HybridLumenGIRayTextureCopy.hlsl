#ifndef HYBRID_LUMEN_GI_RAY_TEXTURE_COPY_INCLUDED
#define HYBRID_LUMEN_GI_RAY_TEXTURE_COPY_INCLUDED

// Same 64-byte layout as the reader. During upload, storage.yzw hold the
// copied-texel count, error bit and copied-mip mask. Only Finish clears them
// and publishes ready. Each dispatch must be ordered with UAV dependencies.
struct HLGIRayTextureCopyMetadata
{
    uint4 geometry;
    uint4 state;
    uint4 storage;
    float4 sampling;
};
Texture2D<float4> _HLGI_RayTextureSource : register(t0);
RWStructuredBuffer<HLGIRayTextureCopyMetadata> _HLGI_RayTextureCopyMetadata : register(u0);
RWStructuredBuffer<uint4> _HLGI_RayTextureCopyTexels : register(u1);
cbuffer HLGIRayTextureCopyParameters : register(b0)
{
    uint _HLGI_CopyTextureIndex;
    uint _HLGI_CopyTextureGeneration;
    uint _HLGI_CopyTextureMip;
    uint _HLGI_CopyTextureCapacity;
    uint _HLGI_CopyRangeStart;
    uint _HLGI_CopyRangeCount;
};

bool HLGICopyDescriptor(out HLGIRayTextureCopyMetadata m)
{
    m=(HLGIRayTextureCopyMetadata)0;
    uint count,stride;_HLGI_RayTextureCopyMetadata.GetDimensions(count,stride);
    if(_HLGI_CopyTextureIndex>=count || stride!=64u) return false;
    m=_HLGI_RayTextureCopyMetadata[_HLGI_CopyTextureIndex];
    if(_HLGI_CopyTextureGeneration==0 || m.state.y!=_HLGI_CopyTextureGeneration) return false;
    return true;
}

bool HLGICopyAllocationValid(HLGIRayTextureCopyMetadata m)
{
    uint count,stride;_HLGI_RayTextureCopyTexels.GetDimensions(count,stride);
    uint width=m.geometry.y,height=m.geometry.z,mips=m.state.x;
    return stride==16u && m.geometry.x<count && _HLGI_CopyTextureCapacity>0 &&
        _HLGI_CopyTextureCapacity<=count-m.geometry.x && width>0 && height>0 &&
        width<=16384u && height<=16384u && mips>0 && mips<=15u &&
        mips<=(uint)firstbithigh(max(width,height))+1u;
}

uint HLGICopyChainTexels(uint2 size,uint mips)
{
    uint count=0;
    [loop] for(uint level=0;level<mips;level++) count+=max(1u,size.x>>level)*max(1u,size.y>>level);
    return count;
}
uint HLGICopyChainElements(uint2 size,uint mips,bool halfPairs)
{
    uint count=0;
    [loop] for(uint level=0;level<mips;level++)
    { uint width=max(1u,size.x>>level);count+=(halfPairs?(width+1u)/2u:width)*max(1u,size.y>>level); }
    return count;
}

// Explicit round-to-nearest-even, including subnormals. f32tof16 lowering may
// truncate on a backend; packed bits must not silently change that precision contract.
// Caller has already rejected nonfinite/out-of-half-range values, without clamping.
uint HLGICopyHalfBits(float value)
{
    uint bits=asuint(value),sign=(bits>>16u)&0x8000u;
    uint magnitude=bits&0x7fffffffu,exponent=magnitude>>23u;
    if(exponent>=113u)
        return sign|(((magnitude+0xfffu+((magnitude>>13u)&1u))>>13u)-0x1c000u);
    if(exponent<102u)return sign;
    uint shift=126u-exponent,mantissa=(magnitude&0x7fffffu)|0x800000u;
    return sign|((mantissa+((1u<<(shift-1u))-1u)+((mantissa>>shift)&1u))>>shift);
}
uint4 HLGICopyHalfBits4(float4 value)
{ return uint4(HLGICopyHalfBits(value.x),HLGICopyHalfBits(value.y),HLGICopyHalfBits(value.z),HLGICopyHalfBits(value.w)); }

[numthreads(1,1,1)]
void CSBeginRayTextureCopy(uint3 id:SV_DispatchThreadID)
{
    if(any(id!=0u)) return;
    HLGIRayTextureCopyMetadata m;
    if(!HLGICopyDescriptor(m)) return;
    m.state.z=0u;m.storage.yzw=uint3(0,1,0);
    if(HLGICopyAllocationValid(m))
    {
        uint width,height,mips;_HLGI_RayTextureSource.GetDimensions(0,width,height,mips);
        // Match the actual bound SRV, not loadedMip + activeMipmapLimit. A
        // complete resident tail has a unique size/count pair in the logical
        // source chain, including NPOT and truncated chains.
        [loop] for(uint first=0;first<m.state.x;first++)
        {
            if(width!=max(1u,m.geometry.y>>first) || height!=max(1u,m.geometry.z>>first) ||
                mips!=m.state.x-first) continue;
            uint count=HLGICopyChainTexels(uint2(width,height),mips);
            if(HLGICopyChainElements(uint2(width,height),mips,(m.state.w&0x01000000u)!=0u)>_HLGI_CopyTextureCapacity) break;
            m.geometry.w=first;m.storage=uint4(count,0,0,0);m.state.z=2u;
            break;
        }
    }
    _HLGI_RayTextureCopyMetadata[_HLGI_CopyTextureIndex]=m;
}

groupshared uint HLGICopiedInGroup;
[numthreads(8,8,1)]
void CSCopyRayTextureMip(uint3 id:SV_DispatchThreadID,uint local:SV_GroupIndex)
{
    if(local==0u) HLGICopiedInGroup=0u;
    GroupMemoryBarrierWithGroupSync();
    HLGIRayTextureCopyMetadata m;
    bool valid=HLGICopyDescriptor(m);
    valid=valid && HLGICopyAllocationValid(m) && m.state.z==2u && m.storage.z==0u &&
        m.geometry.w<m.state.x && m.storage.x>0u;
    uint residentMips=valid?m.state.x-m.geometry.w:0u;
    bool halfPairs=(m.state.w&0x01000000u)!=0u;
    if(valid) valid=m.storage.x==HLGICopyChainTexels(max(uint2(1,1),m.geometry.yz>>m.geometry.w),residentMips) &&
        HLGICopyChainElements(max(uint2(1,1),m.geometry.yz>>m.geometry.w),residentMips,halfPairs)<=_HLGI_CopyTextureCapacity;
    // The host dispatches all logical mip indices. Source-view indices beyond
    // a reduced resident chain are intentional no-ops, never out-of-range Load.
    if(valid && _HLGI_CopyTextureMip<residentMips)
    {
        uint width,height,mips;_HLGI_RayTextureSource.GetDimensions(_HLGI_CopyTextureMip,width,height,mips);
        uint absolute=m.geometry.w+_HLGI_CopyTextureMip;
        bool dimensions=width==max(1u,m.geometry.y>>absolute) && height==max(1u,m.geometry.z>>absolute) && mips==residentMips;
        if(!dimensions)
        {
            if(all(id==0u)) InterlockedOr(_HLGI_RayTextureCopyMetadata[_HLGI_CopyTextureIndex].storage.z,1u);
        }
        else if(id.x<width && id.y<height && id.z==0u && (!halfPairs || (id.x&1u)==0u))
        {
            uint offset=m.geometry.x;
            [loop] for(uint level=m.geometry.w;level<absolute;level++)
            {
                uint levelWidth=max(1u,m.geometry.y>>level);
                offset+=(halfPairs?(levelWidth+1u)/2u:levelWidth)*max(1u,m.geometry.z>>level);
            }
            uint status;
            float4 texel=_HLGI_RayTextureSource.Load(int3(id.xy,_HLGI_CopyTextureMip),int2(0,0),status);
            // The SRV performs sRGB decoding. Never gamma-transform this value
            // again. Unmapped tiled texels or nonfinite data invalidate the
            // whole capture, rather than becoming a known transparent texel.
            bool mapped=CheckAccessFullyMapped(status) && all(isfinite(texel));
            float4 neighbor=0;uint copied=1u;
            if(halfPairs)
            {
                mapped=mapped && all(abs(texel)<=65504.0);
                if(id.x+1u<width)
                {
                    neighbor=_HLGI_RayTextureSource.Load(int3(id.xy+uint2(1,0),_HLGI_CopyTextureMip),int2(0,0),status);
                    mapped=mapped && CheckAccessFullyMapped(status) && all(isfinite(neighbor)) && all(abs(neighbor)<=65504.0);
                    copied=2u;
                }
            }
            if(mapped)
            {
                if(halfPairs)
                {
                    // One writer owns both texels; odd row tails are padded with zero,
                    // never paired across rows/mips or written with a racy RMW.
                    uint4 a=HLGICopyHalfBits4(texel),b=HLGICopyHalfBits4(neighbor);
                    _HLGI_RayTextureCopyTexels[offset+id.y*((width+1u)/2u)+id.x/2u]=
                        uint4(a.x|(a.y<<16),a.z|(a.w<<16),b.x|(b.y<<16),b.z|(b.w<<16));
                }
                else _HLGI_RayTextureCopyTexels[offset+id.y*width+id.x]=asuint(texel);
                InterlockedAdd(HLGICopiedInGroup,copied);
            }
            else InterlockedOr(_HLGI_RayTextureCopyMetadata[_HLGI_CopyTextureIndex].storage.z,1u);
            if(all(id==0u))
            {
                uint previousMask;
                InterlockedOr(_HLGI_RayTextureCopyMetadata[_HLGI_CopyTextureIndex].storage.w,1u<<_HLGI_CopyTextureMip,previousMask);
                // A duplicate mip dispatch must not compensate for another
                // mip's missing pixels and make the aggregate count look full.
                if((previousMask&(1u<<_HLGI_CopyTextureMip))!=0u)
                    InterlockedOr(_HLGI_RayTextureCopyMetadata[_HLGI_CopyTextureIndex].storage.z,1u);
            }
        }
    }
    GroupMemoryBarrierWithGroupSync();
    if(local==0u && HLGICopiedInGroup>0u)
        InterlockedAdd(_HLGI_RayTextureCopyMetadata[_HLGI_CopyTextureIndex].storage.y,HLGICopiedInGroup);
}

// Progressive, contiguous physical-element ranges. The sequence cursor is not a
// mip mask: CAS rejects duplicates/gaps/overlap, and the independent copied-texel
// count rejects underdispatch. Begin/each range/Finish require UAV dependencies.
[numthreads(64,1,1)]
void CSCopyRayTextureRange(uint3 id:SV_DispatchThreadID)
{
    HLGIRayTextureCopyMetadata m;
    if(!HLGICopyDescriptor(m))return;
    bool valid=HLGICopyAllocationValid(m)&&(m.state.z==2u||m.state.z==3u)&&m.storage.z==0u&&
        m.geometry.w<m.state.x&&_HLGI_CopyRangeCount>0u&&_HLGI_CopyRangeStart<_HLGI_CopyTextureCapacity&&
        _HLGI_CopyRangeCount<=_HLGI_CopyTextureCapacity-_HLGI_CopyRangeStart;
    if(!valid){if(all(id==0u))InterlockedOr(_HLGI_RayTextureCopyMetadata[_HLGI_CopyTextureIndex].storage.z,1u);return;}
    uint width,height,mips;_HLGI_RayTextureSource.GetDimensions(0,width,height,mips);
    bool halfPairs=(m.state.w&0x01000000u)!=0u;
    valid=width==max(1u,m.geometry.y>>m.geometry.w)&&height==max(1u,m.geometry.z>>m.geometry.w)&&mips==m.state.x-m.geometry.w&&
        m.storage.x==HLGICopyChainTexels(uint2(width,height),mips)&&HLGICopyChainElements(uint2(width,height),mips,halfPairs)<=_HLGI_CopyTextureCapacity;
    if(!valid){if(all(id==0u))InterlockedOr(_HLGI_RayTextureCopyMetadata[_HLGI_CopyTextureIndex].storage.z,1u);return;}
    if(all(id==0u))
    {
        uint previous;
        InterlockedExchange(_HLGI_RayTextureCopyMetadata[_HLGI_CopyTextureIndex].state.z,3u,previous);
        InterlockedCompareExchange(_HLGI_RayTextureCopyMetadata[_HLGI_CopyTextureIndex].storage.w,_HLGI_CopyRangeStart,
            _HLGI_CopyRangeStart+_HLGI_CopyRangeCount,previous);
        if(previous!=_HLGI_CopyRangeStart)InterlockedOr(_HLGI_RayTextureCopyMetadata[_HLGI_CopyTextureIndex].storage.z,1u);
    }
    if(id.y!=0u||id.z!=0u||id.x>=_HLGI_CopyRangeCount)return;
    uint physical=_HLGI_CopyRangeStart+id.x,localElement=physical,mip=0u;
    [loop] for(;mip<mips;mip++)
    {
        uint w=max(1u,width>>mip),h=max(1u,height>>mip),count=(halfPairs?(w+1u)/2u:w)*h;
        if(localElement<count)break;localElement-=count;
    }
    // Full logical allocation may exceed the current mapped SRV tail. Budgeted
    // unused elements need no loads or writes, but the sequence still completes.
    if(mip>=mips)return;
    uint w=max(1u,width>>mip),pitch=halfPairs?(w+1u)/2u:w;
    uint2 xy=uint2((localElement%pitch)*(halfPairs?2u:1u),localElement/pitch);
    uint status;float4 a=_HLGI_RayTextureSource.Load(int3(xy,mip),int2(0,0),status),b=0;
    bool mapped=CheckAccessFullyMapped(status)&&all(isfinite(a));uint copied=1u;
    if(halfPairs)
    {
        mapped=mapped&&all(abs(a)<=65504.0);
        if(xy.x+1u<w)
        {b=_HLGI_RayTextureSource.Load(int3(xy+uint2(1,0),mip),int2(0,0),status);mapped=mapped&&CheckAccessFullyMapped(status)&&all(isfinite(b))&&all(abs(b)<=65504.0);copied=2u;}
    }
    if(!mapped){InterlockedOr(_HLGI_RayTextureCopyMetadata[_HLGI_CopyTextureIndex].storage.z,1u);return;}
    if(halfPairs)
    {uint4 x=HLGICopyHalfBits4(a),y=HLGICopyHalfBits4(b);_HLGI_RayTextureCopyTexels[m.geometry.x+physical]=uint4(x.x|(x.y<<16),x.z|(x.w<<16),y.x|(y.y<<16),y.z|(y.w<<16));}
    else _HLGI_RayTextureCopyTexels[m.geometry.x+physical]=asuint(a);
    InterlockedAdd(_HLGI_RayTextureCopyMetadata[_HLGI_CopyTextureIndex].storage.y,copied);
}

[numthreads(1,1,1)]
void CSFinishRayTextureCopy(uint3 id:SV_DispatchThreadID)
{
    if(any(id!=0u)) return;
    HLGIRayTextureCopyMetadata m;
    if(!HLGICopyDescriptor(m)) return;
    bool ranged=m.state.z==3u;
    bool ready=HLGICopyAllocationValid(m) && (m.state.z==2u||ranged) && m.geometry.w<m.state.x &&
        m.storage.z==0u && m.storage.x>0u && m.storage.y==m.storage.x;
    if(ready)
    {
        uint width,height,mips;_HLGI_RayTextureSource.GetDimensions(0,width,height,mips);
        ready=width==max(1u,m.geometry.y>>m.geometry.w) && height==max(1u,m.geometry.z>>m.geometry.w) &&
            mips==m.state.x-m.geometry.w && m.storage.w==(ranged?_HLGI_CopyTextureCapacity:((1u<<mips)-1u)) &&
            m.storage.x==HLGICopyChainTexels(uint2(width,height),mips) &&
            HLGICopyChainElements(uint2(width,height),mips,(m.state.w&0x01000000u)!=0u)<=_HLGI_CopyTextureCapacity;
    }
    m.state.z=ready?1u:0u;
    if(ready) m.storage.yzw=0u;
    _HLGI_RayTextureCopyMetadata[_HLGI_CopyTextureIndex]=m;
}
#endif
