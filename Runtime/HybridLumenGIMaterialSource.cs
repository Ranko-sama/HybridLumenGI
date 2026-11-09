using System;
using System.Collections.Generic;
using UnityEngine;

namespace HybridLumenGI
{
    /// <summary>
    /// Main-thread, read-only observation of one ordinary Renderer material slot.
    /// No Proxy, private material, Renderer mutation, or 32-bit identity hash is used.
    /// Slot-to-submesh mapping and renderer/geometry/lighting epochs belong to the caller.
    /// </summary>
    public sealed class HybridLumenGIMaterialSource
    {
        private const string LitName = "Universal Render Pipeline/Lit";
        // Fixed Unity Graphics feb4de2d9a93a4ae10d287d3a6d7003d08ea3e53 Lit/LitInput contract.
        private static readonly int[] Floats = Ids("_Metallic", "_Smoothness", "_BumpScale", "_OcclusionStrength", "_Cutoff",
            "_WorkflowMode", "_SmoothnessTextureChannel", "_Surface", "_AlphaClip", "_DetailAlbedoMapScale",
            "_DetailNormalMapScale", "_Parallax", "_ClearCoatMask", "_ClearCoatSmoothness", "_ReceiveShadows",
            "_SpecularHighlights", "_EnvironmentReflections");
        private static readonly int[] Colors = Ids("_BaseColor", "_SpecColor", "_EmissionColor");
        private static readonly int[] Textures = Ids("_BaseMap", "_MetallicGlossMap", "_SpecGlossMap", "_BumpMap",
            "_OcclusionMap", "_EmissionMap", "_DetailMask", "_DetailAlbedoMap", "_DetailNormalMap", "_ParallaxMap");
        // MPBs cannot change raster state. Never interpret an MPB _Cull as the source's Cull mode.
        private static readonly int[] RasterFloats = Ids("_Cull", "_Blend", "_SrcBlend", "_DstBlend", "_SrcBlendAlpha",
            "_DstBlendAlpha", "_ZWrite", "_BlendModePreserveSpecular", "_AlphaToMask", "_AddPrecomputedVelocity", "_QueueOffset");
        private static readonly int[] TransformTextures = Ids("_BaseMap", "_DetailAlbedoMap");
        private static readonly int[] Transforms = Ids("_BaseMap_ST", "_DetailAlbedoMap_ST");
        private readonly List<Material> materials = new List<Material>(8);
        private readonly MaterialPropertyBlock rendererBlock = new MaterialPropertyBlock();
        private readonly MaterialPropertyBlock materialBlock = new MaterialPropertyBlock();

        internal readonly struct Value : IEquatable<Value>
        {
            private readonly int id, x, y, z, w;
            private readonly byte origin; // 0 absent; 1 Material; 2 renderer MPB; 3 material-slot MPB.
            public Value(int id, byte origin, Vector4 value)
            { this.id = id; this.origin = origin; x = Bits(value.x); y = Bits(value.y); z = Bits(value.z); w = Bits(value.w); }
            public bool Equals(Value other) => id == other.id && origin == other.origin && x == other.x && y == other.y && z == other.z && w == other.w;
            internal bool TryRead(int property, out Vector4 value)
            {
                value = new Vector4(BitConverter.Int32BitsToSingle(x), BitConverter.Int32BitsToSingle(y),
                    BitConverter.Int32BitsToSingle(z), BitConverter.Int32BitsToSingle(w));
                return id == property && origin != 0;
            }
            internal bool TryRead(int property, out Vector4 value, out HybridLumenGIMaterialValueOrigin source)
            {
                bool present = TryRead(property, out value);
                source = id == property ? (HybridLumenGIMaterialValueOrigin)origin : HybridLumenGIMaterialValueOrigin.Absent;
                return present;
            }
        }

        internal readonly struct TextureValue : IEquatable<TextureValue>
        {
            private readonly int id, width, height, dimension, format, mips, filter, wrapU, wrapV, wrapW, aniso, bias;
            private readonly byte origin;
            private readonly Texture texture;
            private readonly uint update;
            private readonly bool identityTextureSupported;
            private readonly bool dataSrgb, texture2D, renderTexture, streaming;
            private readonly int activeMipLimit, loadedMip, loadingMip;
            public TextureValue(int id, byte origin, Texture texture)
            {
                this.id = id; this.origin = origin; this.texture = texture;
                update = texture != null ? texture.updateCount : 0;
                width = texture != null ? texture.width : 0; height = texture != null ? texture.height : 0;
                dimension = texture != null ? (int)texture.dimension : 0; format = texture != null ? (int)texture.graphicsFormat : 0;
                mips = texture != null ? texture.mipmapCount : 0; filter = texture != null ? (int)texture.filterMode : 0;
                wrapU = texture != null ? (int)texture.wrapModeU : 0; wrapV = texture != null ? (int)texture.wrapModeV : 0;
                wrapW = texture != null ? (int)texture.wrapModeW : 0; aniso = texture != null ? texture.anisoLevel : 0;
                bias = texture != null ? Bits(texture.mipMapBias) : 0;
                dataSrgb = texture != null && texture.isDataSRGB;
                texture2D = texture is Texture2D; renderTexture = texture is RenderTexture;
                // Public APIs verified against UnityCsReference 1c2d7db69c060103b6dc087af725442d1efaef9c.
                // These are an observation, not a residency fence or a frozen GPU resource.
                var source2D = texture as Texture2D;
                streaming = source2D != null && source2D.streamingMipmaps;
                activeMipLimit = source2D != null ? source2D.activeMipmapLimit : -1;
                loadedMip = source2D != null ? source2D.loadedMipmapLevel : -1;
                loadingMip = source2D != null ? source2D.loadingMipmapLevel : -1;
                identityTextureSupported = ReferenceEquals(texture, null) || (dimension == 2 && !(texture is RenderTexture));
            }
            public bool Equals(TextureValue b) => id == b.id && origin == b.origin && ReferenceEquals(texture, b.texture) &&
                update == b.update && width == b.width && height == b.height && dimension == b.dimension && format == b.format &&
                mips == b.mips && filter == b.filter && wrapU == b.wrapU && wrapV == b.wrapV && wrapW == b.wrapW && aniso == b.aniso && bias == b.bias &&
                dataSrgb == b.dataSrgb && texture2D == b.texture2D && renderTexture == b.renderTexture && streaming == b.streaming &&
                activeMipLimit == b.activeMipLimit && loadedMip == b.loadedMip && loadingMip == b.loadingMip;
            internal bool TryRead(int property, out Texture value, out bool identitySupported)
            { value = texture; identitySupported = identityTextureSupported; return id == property; }
            internal bool TryRead(int property, out HybridLumenGIFrozenTextureView value)
            {
                value = new HybridLumenGIFrozenTextureView(texture, (HybridLumenGIMaterialValueOrigin)origin,
                    width, height, dimension, format, mips, filter, wrapU, wrapV, wrapW, aniso,
                    BitConverter.Int32BitsToSingle(bias), update, dataSrgb, texture2D, renderTexture,
                    streaming, activeMipLimit, loadedMip, loadingMip);
                return id == property;
            }
        }

        /// <summary>
        /// Frozen alpha/raster inputs for the separate identity draw. Texture is a reference, not copied
        /// pixels: the caller must still revalidate Snapshot immediately before recording the draw.
        /// Supported covers material-local coverage only. LOD groups/fading, debug alpha overrides,
        /// MSAA, deformation and incompatible camera projection remain caller rejection conditions.
        /// </summary>
        public readonly struct IdentityCoverageData
        {
            public Texture BaseMap { get; }
            public Vector4 BaseMapST { get; }
            public float BaseColorAlpha { get; }
            public float Cutoff { get; }
            public int SourceCull { get; }
            public bool AlphaTest { get; }
            public bool SmoothnessFromAlbedoAlpha { get; }
            public bool Supported { get; }
            public string UnsupportedReason { get; }
            internal IdentityCoverageData(Value[] values, TextureValue[] textures, string[] keywords,
                string[] passes, bool[] passEnabled)
            {
                BaseMap = null; bool textureSupported = true;
                foreach (TextureValue item in textures)
                    if (item.TryRead(Shader.PropertyToID("_BaseMap"), out Texture texture, out bool compatible))
                    { BaseMap = texture; textureSupported = compatible; break; }
                BaseMapST = Read(values, "_BaseMap_ST", new Vector4(1, 1, 0, 0));
                BaseColorAlpha = Read(values, "_BaseColor", new Vector4(1, 1, 1, 1)).w;
                Cutoff = Read(values, "_Cutoff", new Vector4(.5f, 0, 0, 0)).x;
                SourceCull = (int)Read(values, "_Cull", new Vector4(2, 0, 0, 0)).x;
                AlphaTest = Array.IndexOf(keywords, "_ALPHATEST_ON") >= 0;
                SmoothnessFromAlbedoAlpha = Array.IndexOf(keywords, "_SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A") >= 0 ||
                    Array.IndexOf(keywords, "_GLOSSINESS_FROM_BASE_ALPHA") >= 0;
                int forward = Array.IndexOf(passes, "ForwardLit");
                UnsupportedReason = Array.IndexOf(keywords, "_PARALLAXMAP") >= 0 ? "Parallax changes the alpha UV." :
                    Array.IndexOf(keywords, "LOD_FADE_CROSSFADE") >= 0 ? "LOD crossfade coverage is not captured." :
                    Array.IndexOf(keywords, "_ADD_PRECOMPUTED_VELOCITY") >= 0 ? "Precomputed vertex motion is not captured." :
                    Read(values, "_AlphaToMask", default).x != 0 ? "Alpha-to-coverage is not captured." :
                    forward < 0 || !passEnabled[forward] ? "The source ForwardLit pass is unavailable." :
                    AlphaTest && !SmoothnessFromAlbedoAlpha && !textureSupported ? "Alpha texture is not a static 2D source." : null;
                Supported = UnsupportedReason == null;
            }
            private static Vector4 Read(Value[] values, string name, Vector4 fallback)
            {
                int property = Shader.PropertyToID(name);
                foreach (Value item in values) if (item.TryRead(property, out Vector4 value)) return value;
                return fallback;
            }
        }

        /// <summary>
        /// Owned scalar copies and private arrays; Unity object references identify the observed source,
        /// not a pixel-content copy. Equality never calls live source APIs or trusts a hash/CRC.
        /// </summary>
        public sealed class Snapshot : IEquatable<Snapshot>
        {
            public Renderer SourceRenderer { get; }
            public Material SourceMaterial { get; }
            public Shader Shader { get; }
            public int MaterialIndex { get; }
            public bool CanReuseHistory { get; }
            public IdentityCoverageData IdentityCoverage { get; }
            public HybridLumenGIHitMaterialData HitMaterial { get; }
            private readonly int materialCount, rawQueue, effectiveQueue, giFlags;
            private readonly bool instancing, doubleSided;
            private readonly string shaderName, renderType;
            private readonly string[] keywords, passes;
            private readonly bool[] passEnabled;
            private readonly Value[] values;
            private readonly TextureValue[] textures;

            internal Snapshot(Renderer renderer, Material source, int index, int count, Value[] values,
                TextureValue[] textures, bool reusable, string[] keywords, string[] passes, bool[] enabled)
            {
                SourceRenderer = renderer; SourceMaterial = source; Shader = source.shader; MaterialIndex = index;
                materialCount = count; rawQueue = source.renderQueue; effectiveQueue = rawQueue < 0 ? Shader.renderQueue : rawQueue;
                giFlags = (int)source.globalIlluminationFlags; instancing = source.enableInstancing; doubleSided = source.doubleSidedGI;
                shaderName = Shader.name; renderType = source.GetTag("RenderType", false, "");
                // Defensively own even internal-constructor inputs: packages without
                // an asmdef can share an assembly with caller scripts.
                this.values = (Value[])values.Clone(); this.textures = (TextureValue[])textures.Clone(); CanReuseHistory = reusable;
                this.keywords = (string[])keywords.Clone(); this.passes = (string[])passes.Clone(); passEnabled = (bool[])enabled.Clone();
                IdentityCoverage = new IdentityCoverageData(this.values, this.textures, this.keywords, this.passes, passEnabled);
                HitMaterial = new HybridLumenGIHitMaterialData(this.values, this.textures, this.keywords,
                    !source.GetShaderPassEnabled("ShadowCaster"));
            }
            public bool Equals(Snapshot other)
            {
                if (ReferenceEquals(this, other)) return true;
                if (ReferenceEquals(other, null) || !ReferenceEquals(SourceRenderer, other.SourceRenderer) ||
                    !ReferenceEquals(SourceMaterial, other.SourceMaterial) || !ReferenceEquals(Shader, other.Shader) ||
                    MaterialIndex != other.MaterialIndex || materialCount != other.materialCount || rawQueue != other.rawQueue ||
                    effectiveQueue != other.effectiveQueue || giFlags != other.giFlags || instancing != other.instancing ||
                    doubleSided != other.doubleSided || CanReuseHistory != other.CanReuseHistory ||
                    HitMaterial.ShadowCasterDisabled != other.HitMaterial.ShadowCasterDisabled ||
                    shaderName != other.shaderName || renderType != other.renderType || values.Length != other.values.Length ||
                    textures.Length != other.textures.Length || keywords.Length != other.keywords.Length || passes.Length != other.passes.Length) return false;
                for (int i = 0; i < values.Length; i++) if (!values[i].Equals(other.values[i])) return false;
                for (int i = 0; i < textures.Length; i++) if (!textures[i].Equals(other.textures[i])) return false;
                for (int i = 0; i < keywords.Length; i++) if (keywords[i] != other.keywords[i]) return false;
                for (int i = 0; i < passes.Length; i++) if (passes[i] != other.passes[i] || passEnabled[i] != other.passEnabled[i]) return false;
                return true;
            }
            public override bool Equals(object obj) => obj is Snapshot other && Equals(other);
            // Intentionally non-authoritative. Dictionary equality still compares every frozen field.
            public override int GetHashCode() => MaterialIndex;
        }

        /// <summary>
        /// Captures an exact CPU-visible source observation. expectedSource must still occupy this slot.
        /// A nonempty per-material MPB replaces the entire renderer MPB, even if it contains only unrelated properties.
        /// Renderer active/enabled state is deliberately not a material qualification rule.
        /// </summary>
        public bool TryCapture(Renderer renderer, int materialIndex, Material expectedSource, out Snapshot snapshot, out string reason)
        {
            snapshot = null; reason = null;
            if (renderer == null || expectedSource == null || materialIndex < 0) return Fail("Missing renderer/material or invalid material slot.", out reason);
            materials.Clear(); renderer.GetSharedMaterials(materials);
            if (materialIndex >= materials.Count || !ReferenceEquals(materials[materialIndex], expectedSource))
                return Fail("Material slot changed before observation.", out reason);
            Material source = expectedSource;
            if (source.shader == null || !string.Equals(source.shader.name, LitName, StringComparison.Ordinal))
                return Fail("Only the fixed ordinary Universal Render Pipeline/Lit contract is supported.", out reason);
            int queue = source.renderQueue < 0 ? source.shader.renderQueue : source.renderQueue;
            if (queue < 0 || queue > 2500) return Fail("Material is outside the opaque render queue.", out reason);
            float cull = source.HasProperty("_Cull") ? source.GetFloat("_Cull") : 2f;
            if (cull != 0f && cull != 1f && cull != 2f) return Fail("Source material raster Cull is invalid.", out reason);
            if (source.HasProperty("_Surface") && (!Finite(source.GetFloat("_Surface")) || source.GetFloat("_Surface") >= .5f))
                return Fail("Source material is not opaque.", out reason);

            renderer.GetPropertyBlock(rendererBlock); renderer.GetPropertyBlock(materialBlock, materialIndex);
            bool perMaterial = !materialBlock.isEmpty;
            MaterialPropertyBlock block = perMaterial ? materialBlock : rendererBlock;
            byte blockOrigin = perMaterial ? (byte)3 : (byte)2;
            var values = new Value[Floats.Length + Colors.Length + RasterFloats.Length + Transforms.Length];
            int cursor = 0;
            foreach (int id in Floats)
            {
                bool overridden = block.HasProperty(id), present = overridden || source.HasProperty(id);
                if (overridden && !block.HasFloat(id)) return Fail("A Lit float override has an incompatible MPB type.", out reason);
                float value = overridden ? block.GetFloat(id) : present ? source.GetFloat(id) : 0f;
                if (!Finite(value)) return Fail("A Lit float is not finite.", out reason);
                if (id == Shader.PropertyToID("_Surface") && value >= .5f) return Fail("Effective Lit surface is not opaque.", out reason);
                values[cursor++] = new Value(id, overridden ? blockOrigin : present ? (byte)1 : (byte)0, new Vector4(value, 0, 0, 0));
            }
            foreach (int id in Colors)
            {
                bool overridden = block.HasProperty(id), present = overridden || source.HasProperty(id);
                if (overridden && !block.HasVector(id)) return Fail("A Lit color override has an incompatible MPB type.", out reason);
                // Material authoring colors and MPB shader-space vectors retain different origins.
                // Do not gamma-convert while constructing identity, especially HDR emission.
                Vector4 value = overridden ? block.GetVector(id) : present ? (Vector4)source.GetColor(id) : default;
                if (!Finite(value)) return Fail("A Lit color is not finite.", out reason);
                values[cursor++] = new Value(id, overridden ? blockOrigin : present ? (byte)1 : (byte)0, value);
            }
            foreach (int id in RasterFloats)
            {
                bool present = source.HasProperty(id);
                float value = present ? source.GetFloat(id) : 0f;
                if (!Finite(value)) return Fail("A material raster property is not finite.", out reason);
                values[cursor++] = new Value(id, present ? (byte)1 : (byte)0, new Vector4(value, 0, 0, 0));
            }
            for (int i = 0; i < Transforms.Length; i++)
            {
                int id = Transforms[i]; bool overridden = block.HasProperty(id), present = source.HasProperty(TransformTextures[i]);
                if (overridden && !block.HasVector(id)) return Fail("A Lit texture transform override has an incompatible MPB type.", out reason);
                Vector2 scale = present ? source.GetTextureScale(TransformTextures[i]) : Vector2.one;
                Vector2 offset = present ? source.GetTextureOffset(TransformTextures[i]) : Vector2.zero;
                Vector4 value = overridden ? block.GetVector(id) : new Vector4(scale.x, scale.y, offset.x, offset.y);
                if (!Finite(value)) return Fail("A Lit texture transform is not finite.", out reason);
                values[cursor++] = new Value(id, overridden ? blockOrigin : present ? (byte)1 : (byte)0, value);
            }
            bool reusable = true;
            var textures = new TextureValue[Textures.Length];
            for (int i = 0; i < Textures.Length; i++)
            {
                int id = Textures[i]; bool overridden = block.HasProperty(id), present = overridden || source.HasProperty(id);
                if (overridden && !block.HasTexture(id)) return Fail("A Lit texture override has an incompatible MPB type.", out reason);
                Texture texture = overridden ? block.GetTexture(id) : present ? source.GetTexture(id) : null;
                if (!ReferenceEquals(texture, null) && texture == null) return Fail("A referenced texture was destroyed.", out reason);
                if (texture != null && !Finite(texture.mipMapBias)) return Fail("A texture sampler value is not finite.", out reason);
                // RenderTexture includes CustomRenderTexture. GPU writes do NOT automatically increment updateCount.
                if (texture is RenderTexture) reusable = false;
                textures[i] = new TextureValue(id, overridden ? blockOrigin : present ? (byte)1 : (byte)0, texture);
            }
            string[] keywords = (string[])(source.shaderKeywords ?? Array.Empty<string>()).Clone();
            Array.Sort(keywords, StringComparer.Ordinal);
            var passes = new string[source.passCount]; var enabled = new bool[passes.Length];
            for (int i = 0; i < passes.Length; i++) { passes[i] = source.GetPassName(i); enabled[i] = source.GetShaderPassEnabled(passes[i]); }
            snapshot = new Snapshot(renderer, source, materialIndex, materials.Count, values, textures, reusable, keywords, passes, enabled);
            return true;
        }

        /// <summary>
        /// Re-observes live CPU state without modifying the snapshot or original objects. No frame cache.
        /// Texture2D GPU/native writes require the producer to call Texture.IncrementUpdateCount;
        /// unreported writes, shader hot reload, globals, probes/lightmaps, deformation and future render
        /// callbacks cannot be proved current here. Their owners must separately invalidate history.
        /// This is not GPU synchronization or a promise that a later draw used these observations.
        /// </summary>
        public bool IsCurrent(Renderer renderer, int index, Snapshot snapshot) => snapshot != null && snapshot.CanReuseHistory &&
            TryCapture(renderer, index, snapshot.SourceMaterial, out Snapshot current, out _) && snapshot.Equals(current);

        private static bool Fail(string text, out string reason) { reason = text; return false; }
        private static bool Finite(float x) => !float.IsNaN(x) && !float.IsInfinity(x);
        private static bool Finite(Vector4 v) => Finite(v.x) && Finite(v.y) && Finite(v.z) && Finite(v.w);
        private static int Bits(float value) => BitConverter.SingleToInt32Bits(value);
        private static int[] Ids(params string[] names)
        { var ids = new int[names.Length]; for (int i = 0; i < names.Length; i++) ids[i] = Shader.PropertyToID(names[i]); return ids; }
    }
}
