using System;
using UnityEngine;

namespace HybridLumenGI
{
    public enum HybridLumenGIMaterialValueOrigin : byte
    {
        Absent = 0, Material = 1, RendererPropertyBlock = 2, MaterialPropertyBlock = 3
    }

    /// <summary>Raw observed color/vector and its source. No gamma conversion, HDR clamp or premultiplication.</summary>
    public readonly struct HybridLumenGIFrozenColor
    {
        public Vector4 Value { get; }
        public HybridLumenGIMaterialValueOrigin Origin { get; }
        internal HybridLumenGIFrozenColor(Vector4 value, HybridLumenGIMaterialValueOrigin origin)
        { Value = value; Origin = origin; }
    }

    /// <summary>
    /// CPU-visible texture observation. Texture identifies the original object, not immutable pixels.
    /// Enum-valued integer fields preserve Unity's enum codes. Mip indices are the observed Unity values,
    /// never summed or reinterpreted here. HasTexture2DMipState is false for null/other texture types;
    /// their mip-state fields are -1. RenderTexture requires an external producer/copy/consumer ordering.
    /// updateCount and these fields cannot detect unreported native/GPU writes or establish a GPU fence.
    /// </summary>
    public readonly struct HybridLumenGIFrozenTextureView : IEquatable<HybridLumenGIFrozenTextureView>
    {
        public Texture Texture { get; }
        public HybridLumenGIMaterialValueOrigin Origin { get; }
        public int Width { get; }
        public int Height { get; }
        public int Dimension { get; }
        public int GraphicsFormat { get; }
        public int MipmapCount { get; }
        public int FilterMode { get; }
        public int WrapModeU { get; }
        public int WrapModeV { get; }
        public int WrapModeW { get; }
        public int AnisoLevel { get; }
        public float MipMapBias { get; }
        public uint UpdateCount { get; }
        public bool IsDataSRGB { get; }
        public bool HasTexture2DMipState { get; }
        public bool IsRenderTexture { get; }
        public bool StreamingMipmaps { get; }
        public int ActiveMipmapLimit { get; }
        public int LoadedMipmapLevel { get; }
        public int LoadingMipmapLevel { get; }
        internal HybridLumenGIFrozenTextureView(Texture texture, HybridLumenGIMaterialValueOrigin origin,
            int width, int height, int dimension, int format, int mips, int filter, int wrapU, int wrapV, int wrapW,
            int aniso, float bias, uint update, bool srgb, bool texture2D, bool renderTexture,
            bool streaming, int activeMipLimit, int loadedMip, int loadingMip)
        {
            Texture = texture; Origin = origin; Width = width; Height = height; Dimension = dimension;
            GraphicsFormat = format; MipmapCount = mips; FilterMode = filter; WrapModeU = wrapU;
            WrapModeV = wrapV; WrapModeW = wrapW; AnisoLevel = aniso; MipMapBias = bias; UpdateCount = update;
            IsDataSRGB = srgb; HasTexture2DMipState = texture2D; IsRenderTexture = renderTexture;
            StreamingMipmaps = streaming; ActiveMipmapLimit = activeMipLimit; LoadedMipmapLevel = loadedMip;
            LoadingMipmapLevel = loadingMip;
        }
        public bool Equals(HybridLumenGIFrozenTextureView b) => ReferenceEquals(Texture, b.Texture) && Origin == b.Origin &&
            Width == b.Width && Height == b.Height && Dimension == b.Dimension && GraphicsFormat == b.GraphicsFormat &&
            MipmapCount == b.MipmapCount && FilterMode == b.FilterMode && WrapModeU == b.WrapModeU && WrapModeV == b.WrapModeV &&
            WrapModeW == b.WrapModeW && AnisoLevel == b.AnisoLevel &&
            BitConverter.SingleToInt32Bits(MipMapBias) == BitConverter.SingleToInt32Bits(b.MipMapBias) && UpdateCount == b.UpdateCount &&
            IsDataSRGB == b.IsDataSRGB && HasTexture2DMipState == b.HasTexture2DMipState && IsRenderTexture == b.IsRenderTexture &&
            StreamingMipmaps == b.StreamingMipmaps && ActiveMipmapLimit == b.ActiveMipmapLimit &&
            LoadedMipmapLevel == b.LoadedMipmapLevel && LoadingMipmapLevel == b.LoadingMipmapLevel;
        public override bool Equals(object value) => value is HybridLumenGIFrozenTextureView other && Equals(other);
        public override int GetHashCode() => unchecked(Width * 397 ^ Height); // Equality is authoritative.
    }

    /// <summary>
    /// Frozen Lit inputs, not a GPU material or a claim that any keyword has been implemented by a hit shader.
    /// Constructed only from Snapshot's captured data; no live Material/Texture/MPB getters are used here.
    /// Scalar/color convenience getters return zero for absent properties (except source Cull defaults to Back).
    /// Use TryGetFloat/TryGetVector and Origin to distinguish absence from an explicit zero/null override.
    /// All map references are retained even with their sampling keyword disabled. Consumers decide which maps
    /// are relevant, what null shader defaults mean, coverage support and residency; this class decides none.
    /// </summary>
    public sealed class HybridLumenGIHitMaterialData
    {
        private readonly HybridLumenGIMaterialSource.Value[] values;
        private readonly HybridLumenGIMaterialSource.TextureValue[] textures;
        private readonly string[] keywords;
        internal HybridLumenGIHitMaterialData(HybridLumenGIMaterialSource.Value[] values,
            HybridLumenGIMaterialSource.TextureValue[] textures, string[] keywords)
        {
            this.values = (HybridLumenGIMaterialSource.Value[])values.Clone();
            this.textures = (HybridLumenGIMaterialSource.TextureValue[])textures.Clone();
            this.keywords = (string[])keywords.Clone();
        }
        public int KeywordCount => keywords.Length;
        public string GetKeyword(int index) => keywords[index];
        public bool IsKeywordEnabled(string keyword) => keyword != null && Array.IndexOf(keywords, keyword) >= 0;
        public bool TryGetVector(int propertyId, out Vector4 value, out HybridLumenGIMaterialValueOrigin origin)
        {
            foreach (var item in values) if (item.TryRead(propertyId, out value, out origin)) return true;
            value = default; origin = HybridLumenGIMaterialValueOrigin.Absent; return false;
        }
        public bool TryGetFloat(int propertyId, out float value, out HybridLumenGIMaterialValueOrigin origin)
        { bool present = TryGetVector(propertyId, out Vector4 raw, out origin); value = raw.x; return present; }
        public bool TryGetVector(string property, out Vector4 value, out HybridLumenGIMaterialValueOrigin origin) =>
            TryGetVector(Shader.PropertyToID(property), out value, out origin);
        public bool TryGetFloat(string property, out float value, out HybridLumenGIMaterialValueOrigin origin) =>
            TryGetFloat(Shader.PropertyToID(property), out value, out origin);
        private float Scalar(string property) { TryGetFloat(property, out float value, out _); return value; }
        private Vector4 Vector(string property) { TryGetVector(property, out Vector4 value, out _); return value; }
        private HybridLumenGIFrozenColor Color(string property)
        { TryGetVector(property, out Vector4 value, out var origin); return new HybridLumenGIFrozenColor(value, origin); }
        public HybridLumenGIFrozenTextureView GetTexture(string property)
        {
            int id = Shader.PropertyToID(property);
            foreach (var item in textures) if (item.TryRead(id, out HybridLumenGIFrozenTextureView view)) return view;
            return new HybridLumenGIFrozenTextureView(null, HybridLumenGIMaterialValueOrigin.Absent,
                0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, false, false, false, false, -1, -1, -1);
        }
        public HybridLumenGIFrozenColor BaseColor => Color("_BaseColor");
        public HybridLumenGIFrozenColor SpecColor => Color("_SpecColor");
        public HybridLumenGIFrozenColor EmissionColor => Color("_EmissionColor");
        public Vector4 BaseMapST => Vector("_BaseMap_ST");
        public Vector4 DetailAlbedoMapST => Vector("_DetailAlbedoMap_ST");
        public float Metallic => Scalar("_Metallic");
        public float Smoothness => Scalar("_Smoothness");
        public float BumpScale => Scalar("_BumpScale");
        public float OcclusionStrength => Scalar("_OcclusionStrength");
        public float Cutoff => Scalar("_Cutoff");
        public float WorkflowMode => Scalar("_WorkflowMode");
        public float SmoothnessTextureChannel => Scalar("_SmoothnessTextureChannel");
        public float Surface => Scalar("_Surface");
        public float AlphaClip => Scalar("_AlphaClip");
        public float DetailAlbedoMapScale => Scalar("_DetailAlbedoMapScale");
        public float DetailNormalMapScale => Scalar("_DetailNormalMapScale");
        public float Parallax => Scalar("_Parallax");
        public float ClearCoatMask => Scalar("_ClearCoatMask");
        public float ClearCoatSmoothness => Scalar("_ClearCoatSmoothness");
        public float ReceiveShadows => Scalar("_ReceiveShadows");
        public float SpecularHighlights => Scalar("_SpecularHighlights");
        public float EnvironmentReflections => Scalar("_EnvironmentReflections");
        public int SourceCull => TryGetFloat("_Cull", out float cull, out _) ? (int)cull : 2;
        public HybridLumenGIFrozenTextureView BaseMap => GetTexture("_BaseMap");
        public HybridLumenGIFrozenTextureView MetallicGlossMap => GetTexture("_MetallicGlossMap");
        public HybridLumenGIFrozenTextureView SpecGlossMap => GetTexture("_SpecGlossMap");
        public HybridLumenGIFrozenTextureView BumpMap => GetTexture("_BumpMap");
        public HybridLumenGIFrozenTextureView OcclusionMap => GetTexture("_OcclusionMap");
        public HybridLumenGIFrozenTextureView EmissionMap => GetTexture("_EmissionMap");
        public HybridLumenGIFrozenTextureView DetailMask => GetTexture("_DetailMask");
        public HybridLumenGIFrozenTextureView DetailAlbedoMap => GetTexture("_DetailAlbedoMap");
        public HybridLumenGIFrozenTextureView DetailNormalMap => GetTexture("_DetailNormalMap");
        public HybridLumenGIFrozenTextureView ParallaxMap => GetTexture("_ParallaxMap");
    }
}
