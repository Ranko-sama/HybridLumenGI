using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using UnityEngine;

namespace HybridLumenGI
{
    [StructLayout(LayoutKind.Sequential,Pack=4)]
    public struct HybridLumenGIHitMaterialUInt4
    {
        public uint x,y,z,w;
        public HybridLumenGIHitMaterialUInt4(uint x,uint y,uint z,uint w)
        { this.x=x;this.y=y;this.z=z;this.w=w; }
    }

    /// <summary>240-byte CPU/HLSL record. A record is not proof that any of its textures are ready.</summary>
    [StructLayout(LayoutKind.Sequential,Pack=4)]
    public struct HybridLumenGIHitMaterialRecord
    {
        public HybridLumenGIHitMaterialUInt4 identity; // generation, keywords, source Cull, present texture bits
        public Vector4 baseColor,specColor,emissionColor;
        public Vector4 surface,detail,baseST,detailST,proxyTint,proxyEmission;
        public HybridLumenGIHitMaterialUInt4 textures0,textures1,textures2,textures3,textures4;
    }

    /// <summary>
    /// Encodes the captured ordinary Lit contract without consulting live materials, textures or MPBs.
    /// Null shader defaults are distinct from a specified texture whose upload is missing or stale.
    /// All texture handles are copied; the uploader and consumer must retain the matching lease.
    /// </summary>
    public static class HybridLumenGIHitMaterialLayout
    {
        public const int Stride=240;
        public const int TextureCount=10;
        public const uint AlphaTest=1u<<0,SpecularWorkflow=1u<<1,MetallicSpecularMap=1u<<2,
            SmoothnessFromBaseAlpha=1u<<3,NormalMap=1u<<4,Emission=1u<<5,OcclusionMap=1u<<6,
            DetailEnabled=1u<<7,DetailScaled=1u<<8,ParallaxMap=1u<<9,ReceiveShadowsOff=1u<<10,
            SpecularHighlightsOff=1u<<11,EnvironmentReflectionsOff=1u<<12;

        public static uint KeywordFlags(HybridLumenGIHitMaterialData material)
        {
            if(material==null) return 0;
            uint flags=0;
            if(material.IsKeywordEnabled("_ALPHATEST_ON")) flags|=AlphaTest;
            if(material.IsKeywordEnabled("_SPECULAR_SETUP")) flags|=SpecularWorkflow;
            if(material.IsKeywordEnabled("_METALLICSPECGLOSSMAP")) flags|=MetallicSpecularMap;
            if(material.IsKeywordEnabled("_SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A")) flags|=SmoothnessFromBaseAlpha;
            if(material.IsKeywordEnabled("_NORMALMAP")) flags|=NormalMap;
            if(material.IsKeywordEnabled("_EMISSION")) flags|=Emission;
            if(material.IsKeywordEnabled("_OCCLUSIONMAP")) flags|=OcclusionMap;
            if(material.IsKeywordEnabled("_DETAIL_MULX2") || material.IsKeywordEnabled("_DETAIL_SCALED")) flags|=DetailEnabled;
            if(material.IsKeywordEnabled("_DETAIL_SCALED")) flags|=DetailScaled;
            if(material.IsKeywordEnabled("_PARALLAXMAP")) flags|=ParallaxMap;
            if(material.IsKeywordEnabled("_RECEIVE_SHADOWS_OFF")) flags|=ReceiveShadowsOff;
            if(material.IsKeywordEnabled("_SPECULARHIGHLIGHTS_OFF")) flags|=SpecularHighlightsOff;
            if(material.IsKeywordEnabled("_ENVIRONMENTREFLECTIONS_OFF")) flags|=EnvironmentReflectionsOff;
            return flags;
        }

        public static HybridLumenGIFrozenTextureView GetTexture(HybridLumenGIHitMaterialData material,int index)
        {
            if(material==null) throw new ArgumentNullException(nameof(material));
            switch(index)
            {
                case 0:return material.BaseMap;
                case 1:return material.MetallicGlossMap;
                case 2:return material.SpecGlossMap;
                case 3:return material.BumpMap;
                case 4:return material.OcclusionMap;
                case 5:return material.EmissionMap;
                case 6:return material.DetailMask;
                case 7:return material.DetailAlbedoMap;
                case 8:return material.DetailNormalMap;
                case 9:return material.ParallaxMap;
                default:throw new ArgumentOutOfRangeException(nameof(index));
            }
        }

        /// <summary>Only these maps need an upload for the full material evaluator.</summary>
        public static bool UsesTexture(uint flags,int index)
        {
            switch(index)
            {
                case 0:return true;
                case 1:return (flags&(MetallicSpecularMap|SpecularWorkflow))==MetallicSpecularMap;
                case 2:return (flags&(MetallicSpecularMap|SpecularWorkflow))==(MetallicSpecularMap|SpecularWorkflow);
                case 3:return (flags&NormalMap)!=0;
                case 4:return (flags&OcclusionMap)!=0;
                case 5:return (flags&Emission)!=0;
                case 6:case 7:case 8:return (flags&DetailEnabled)!=0;
                case 9:return (flags&ParallaxMap)!=0;
                default:throw new ArgumentOutOfRangeException(nameof(index));
            }
        }

        public static bool TryEncode(HybridLumenGIHitMaterialData material,uint generation,
            IReadOnlyList<HybridLumenGIRayTexturePool.Handle> handles,Vector4 linearProxyTint,Vector4 linearProxyEmission,
            out HybridLumenGIHitMaterialRecord record,out string reason)
        {
            record=default;reason=null;
            if(material==null || generation==0 || handles==null || handles.Count!=TextureCount)
            { reason="Missing frozen material, generation or ten texture handles.";return false; }
            if(!Finite(linearProxyTint) || !Finite(linearProxyEmission) || linearProxyEmission.w<0)
            { reason="Proxy parameters must be finite, with nonnegative emission intensity.";return false; }
            if(material.Surface>=0.5f || material.IsKeywordEnabled("_SURFACE_TYPE_TRANSPARENT") ||
                material.IsKeywordEnabled("_ALPHAPREMULTIPLY_ON") || material.IsKeywordEnabled("_ALPHAMODULATE_ON") ||
                material.IsKeywordEnabled("_CLEARCOAT") || material.IsKeywordEnabled("_CLEARCOATMAP"))
            { reason="This record describes opaque ordinary Lit, without transparent or clear-coat variants.";return false; }
            uint flags=KeywordFlags(material),present=0;
            var bindings=new HybridLumenGIHitMaterialUInt4[5];
            for(int i=0;i<TextureCount;i++)
            {
                var view=GetTexture(material,i);
                bool specified=!ReferenceEquals(view.Texture,null);
                if(specified) present|=1u<<i;
                // A missing/stale specified map stays present with an invalid handle. The
                // GPU reports unknown instead of silently substituting the shader default.
                var handle=specified && UsesTexture(flags,i)?handles[i]:default;
                int pair=i>>1;
                if((i&1)==0) { bindings[pair].x=handle.Index;bindings[pair].y=handle.Generation; }
                else { bindings[pair].z=handle.Index;bindings[pair].w=handle.Generation; }
            }
            var next=new HybridLumenGIHitMaterialRecord
            {
                identity=new HybridLumenGIHitMaterialUInt4(generation,flags,(uint)material.SourceCull,present),
                baseColor=ShaderColor(material.BaseColor,new Vector4(1,1,1,1),false),
                specColor=ShaderColor(material.SpecColor,new Vector4(.2f,.2f,.2f,1),false),
                emissionColor=ShaderColor(material.EmissionColor,new Vector4(0,0,0,1),true),
                surface=new Vector4(Scalar(material,"_Metallic",0),Scalar(material,"_Smoothness",.5f),
                    Scalar(material,"_OcclusionStrength",1),Scalar(material,"_BumpScale",1)),
                detail=new Vector4(Scalar(material,"_Cutoff",.5f),Scalar(material,"_DetailAlbedoMapScale",1),
                    Scalar(material,"_DetailNormalMapScale",1),Scalar(material,"_Parallax",.005f)),
                baseST=Transform(material,"_BaseMap_ST"),detailST=Transform(material,"_DetailAlbedoMap_ST"),
                proxyTint=linearProxyTint,proxyEmission=linearProxyEmission,
                textures0=bindings[0],textures1=bindings[1],textures2=bindings[2],textures3=bindings[3],textures4=bindings[4]
            };
            if(next.identity.z>2u || !Finite(next.baseColor) || !Finite(next.specColor) || !Finite(next.emissionColor) ||
                !Finite(next.surface) || !Finite(next.detail) || !Finite(next.baseST) || !Finite(next.detailST))
            { reason="Nonfinite material encoding or invalid source Cull.";return false; }
            record=next;return true;
        }

        private static float Scalar(HybridLumenGIHitMaterialData data,string property,float fallback)
            => data.TryGetFloat(property,out float value,out _)?value:fallback;
        private static Vector4 Transform(HybridLumenGIHitMaterialData data,string property)
            => data.TryGetVector(property,out var value,out _)?value:new Vector4(1,1,0,0);
        private static Vector4 ShaderColor(HybridLumenGIFrozenColor color,Vector4 fallback,bool hdr)
        {
            Vector4 value=color.Origin==HybridLumenGIMaterialValueOrigin.Absent?fallback:color.Value;
            // Ordinary Material colors are authoring-space colors in a Linear project.
            // MPB vectors already target shader space. HDR emission is linear in either
            // path. Alpha is unchanged by Color.linear, including over-range authoring.
            if(!hdr && (color.Origin==HybridLumenGIMaterialValueOrigin.Material || color.Origin==HybridLumenGIMaterialValueOrigin.Absent))
            {
                Color linear=new Color(value.x,value.y,value.z,value.w).linear;
                return new Vector4(linear.r,linear.g,linear.b,linear.a);
            }
            return value;
        }
        private static bool Finite(Vector4 v) => Finite(v.x)&&Finite(v.y)&&Finite(v.z)&&Finite(v.w);
        private static bool Finite(float x) => !float.IsNaN(x)&&!float.IsInfinity(x);
    }
}
