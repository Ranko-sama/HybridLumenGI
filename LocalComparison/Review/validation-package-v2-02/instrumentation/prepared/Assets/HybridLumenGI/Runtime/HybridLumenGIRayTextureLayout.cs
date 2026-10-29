using System;
using System.Runtime.InteropServices;
using UnityEngine.Experimental.Rendering;

namespace HybridLumenGI
{
    /// <summary>
    /// Exact logical mips with either float32 texels or row-aligned pairs of RGBA16F.
    /// Dimensions are those of the logical source, before the first resident mip.
    /// This describes storage, not Unity texture residency or completed GPU work.
    /// </summary>
    public readonly struct HybridLumenGIRayTextureLayout
    {
        public const int TexelStride = 16;
        public const uint HalfPairsBit = 1u<<24;
        public const int MaxDimension = 16384;
        public readonly int Width, Height, MipCount, FirstMip, TexelCount;
        public readonly int StorageElementCount;
        public readonly bool PackedHalf;
        public long ByteCount => (long)StorageElementCount * TexelStride;

        private HybridLumenGIRayTextureLayout(int width, int height, int mips, int first, int count,int elements,bool half)
        { Width=width; Height=height; MipCount=mips; FirstMip=first; TexelCount=count;StorageElementCount=elements;PackedHalf=half; }

        // Explicit bounded formats only. Unknown/32-bit floating formats preserve all four
        // float32 components. sRGB decode happens before half rounding; alpha is never gamma.
        public static bool CanPackHalf(int format) => (GraphicsFormat)format switch
        {
            GraphicsFormat.R8_UNorm or GraphicsFormat.R8G8_UNorm or GraphicsFormat.R8G8B8A8_UNorm or
            GraphicsFormat.R8G8B8A8_SRGB or GraphicsFormat.B8G8R8A8_UNorm or GraphicsFormat.B8G8R8A8_SRGB or
            GraphicsFormat.R16_SFloat or GraphicsFormat.R16G16_SFloat or GraphicsFormat.R16G16B16A16_SFloat or
            GraphicsFormat.RGBA_DXT1_UNorm or GraphicsFormat.RGBA_DXT1_SRGB or
            GraphicsFormat.RGBA_DXT3_UNorm or GraphicsFormat.RGBA_DXT3_SRGB or
            GraphicsFormat.RGBA_DXT5_UNorm or GraphicsFormat.RGBA_DXT5_SRGB or
            GraphicsFormat.R_BC4_UNorm or GraphicsFormat.R_BC4_SNorm or
            GraphicsFormat.RG_BC5_UNorm or GraphicsFormat.RG_BC5_SNorm or
            GraphicsFormat.RGBA_BC7_UNorm or GraphicsFormat.RGBA_BC7_SRGB => true,
            _ => false
        };

        public static bool TryCreate(int width, int height, int mipCount, int firstMip,
            out HybridLumenGIRayTextureLayout result,bool packedHalf=false)
        {
            result=default;
            if(width<=0 || height<=0 || width>MaxDimension || height>MaxDimension ||
                mipCount<=0 || mipCount>31 || firstMip<0 || firstMip>=mipCount)
                return false;
            int levels=1;
            for(int extent=Math.Max(width,height);extent>1;extent>>=1) levels++;
            // A truncated chain is valid. Invented extra 1x1 levels are not.
            if(mipCount>levels) return false;
            long count=0,elements=0;
            for(int mip=firstMip;mip<mipCount;mip++)
            {
                count+=(long)Math.Max(1,width>>mip)*Math.Max(1,height>>mip);
                int mipWidth=Math.Max(1,width>>mip),mipHeight=Math.Max(1,height>>mip);
                elements+=(long)(packedHalf?(mipWidth+1)/2:mipWidth)*mipHeight;
                if(count>int.MaxValue) return false;
            }
            result=new HybridLumenGIRayTextureLayout(width,height,mipCount,firstMip,(int)count,(int)elements,packedHalf);
            return true;
        }

        /// <summary>Absolute source mip index; offset is relative to this allocation.</summary>
        public bool TryGetMip(int mip, out int offset, out int width, out int height)
        {
            offset=width=height=0;
            if(TexelCount<=0 || mip<FirstMip || mip>=MipCount) return false;
            for(int level=FirstMip;level<mip;level++)
            {
                int mipWidth=Math.Max(1,Width>>level);
                offset+=(PackedHalf?(mipWidth+1)/2:mipWidth)*Math.Max(1,Height>>level);
            }
            width=Math.Max(1,Width>>mip);height=Math.Max(1,Height>>mip);
            return true;
        }

        public bool Fits(int offset, int capacity) => StorageElementCount>0 && offset>=0 && capacity>=0 &&
            offset<=capacity && StorageElementCount<=capacity-offset;

        /// <summary>
        /// Unity filter values: Point 0, Bilinear 1, Trilinear 2. Per-axis wrap:
        /// Repeat 0, Clamp 1, Mirror 2, MirrorOnce 3. Unused bits stay zero.
        /// </summary>
        public static bool TryPackSampler(int filter, int wrapU, int wrapV, out uint packed)
        {
            packed=0;
            if(filter<0 || filter>2 || wrapU<0 || wrapU>3 || wrapV<0 || wrapV>3) return false;
            packed=(uint)filter|((uint)wrapU<<8)|((uint)wrapV<<16);
            return true;
        }

        /// <summary>Creates an unready descriptor. Only GPU copy validation and Finalize publish it.</summary>
        public bool TryMakeMetadata(int offset, int capacity, uint generation, int filter, int wrapU, int wrapV,
            float lodBias, int anisoLevel, out HybridLumenGIRayTextureMetadata metadata)
        {
            metadata=default;
            if(!Fits(offset,capacity) || generation==0 || !TryPackSampler(filter,wrapU,wrapV,out uint sampler) ||
                float.IsNaN(lodBias) || float.IsInfinity(lodBias) || anisoLevel<0 || anisoLevel>16) return false;
            metadata=new HybridLumenGIRayTextureMetadata
            {
                offset=(uint)offset,width=(uint)Width,height=(uint)Height,firstMip=(uint)FirstMip,
                mipCount=(uint)MipCount,generation=generation,flags=0,sampler=sampler|(PackedHalf?HalfPairsBit:0),
                texelCount=(uint)TexelCount,lodBias=lodBias,anisoLevel=anisoLevel
            };
            return true;
        }
    }

    /// <summary>64-byte CPU/HLSL ABI. Bit 0 of flags means the complete stored chain is ready.</summary>
    [StructLayout(LayoutKind.Sequential,Pack=4)]
    public struct HybridLumenGIRayTextureMetadata
    {
        public uint offset,width,height,firstMip;
        public uint mipCount,generation,flags,sampler;
        public uint texelCount,reserved0,reserved1,reserved2;
        public float lodBias,anisoLevel,reserved3,reserved4;
    }
}
