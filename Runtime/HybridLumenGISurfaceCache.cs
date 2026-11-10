using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using UnityEngine;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Rendering;
using Stopwatch = System.Diagnostics.Stopwatch;
using static HybridLumenGI.HybridLumenGIUniformLighting;

namespace HybridLumenGI
{
    /// <summary>
    /// World-space material cards with variable, triangle-isolated baked charts.
    /// Uncharted renderers retain an explicitly approximate six-view fallback.
    /// Own one instance per camera and execute RecordCapture before its consumers.
    /// </summary>
    public sealed class HybridLumenGISurfaceCache : IDisposable
    {
        [Serializable]
        public sealed class Config
        {
            public int tileResolution = 32;
            public int maxResidentCards = 384;
            public int capturesPerFrame = 24;
            public int maxDrawsPerFrame = 256;
            public float captureRecordingCpuBudgetMilliseconds;
            public int maxAtlasMiB = 64;
            public int patchGrid = 4;
            public int layerMask = -1;
            public Vector3 referencePosition;
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct TriangleChartBinding
        {
            public uint cardIndex, chartId, layoutGeneration, geometryRevision;
            public TriangleChartBinding(uint cardIndex, uint chartId, uint layoutGeneration, uint geometryRevision)
            {
                this.cardIndex = cardIndex; this.chartId = chartId;
                this.layoutGeneration = layoutGeneration; this.geometryRevision = geometryRevision;
            }
        }

        /// <summary>Texture-free stock Lit approximation for one original submesh.
        /// Cull uses Unity's Off=0, Front=1, Back=2 convention. This is not hit-UV material evaluation.</summary>
        public struct HardwareMaterial
        {
            public uint cullMode;
            public Vector4 diffuse, emission;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct CardMetadata
        {
            public Matrix4x4 worldToCard;
            public Vector4 atlasRect;
            public Vector4 directionTolerance;
            public uint stableId, revision, generation, ready;
            public uint ownerSlot, chartId, layoutGeneration, flags;
        }
        [StructLayout(LayoutKind.Sequential)]
        private struct OwnerRange { public uint first,count,layoutGeneration,geometryRevision; }
        [StructLayout(LayoutKind.Sequential)]
        private struct EmissiveRecord { public Vector4 sphere, data; }

        private sealed class CapturedSubmesh
        {
            public Material material;
            public int index;
            public float cull;
        }

        private sealed class Owner
        {
            public HybridLumenGIProxy proxy;
            public Renderer renderer;
            public uint stableId, revision;
            public bool published;
            public int signature, geometrySignature, sourceGeometryRevision;
            public Bounds bounds;
            public HybridLumenGISurfaceCharts charts;
            public Mesh sourceMesh, captureMesh;
            public uint chartVersion, layoutGeneration;
            public int[] cardIndices;
            public int[][] primitiveCharts;
            public long primitiveChartBytes;
            public HybridLumenGIMaterialSource.Snapshot[] materialSources;
            public HybridLumenGIShadowmask.Source bakedShadow;
            public Texture2D shadowmaskTexture;
            public readonly List<CapturedSubmesh> submeshes = new List<CapturedSubmesh>();
        }

        private sealed class Card
        {
            public int tile = -1, age, chartIndex;
            public uint generation;
            public bool dirty;
        }

        private sealed class AtlasResources
        {
            public ComputeBuffer metadata, ranges, indices, anchors, emitters;
            public RTHandle diffuse, emission, position, normal, depth, shadowmask;

            public void Release()
            {
                metadata?.Release(); ranges?.Release(); indices?.Release(); anchors?.Release(); emitters?.Release();
                diffuse?.Release(); emission?.Release(); position?.Release(); normal?.Release(); depth?.Release(); shadowmask?.Release();
            }
        }

        public const int FallbackCardsPerInstance = 6;
        public const int MetadataStride = 128;
        public const int EmittersStride = 32;
        // CPU-only optional acceleration. Exhaustion leaves identity unknown;
        // it never invents a chart or rejects otherwise valid surface capture.
        public const long MaxTriangleMappingBytes = 16L * 1024 * 1024;
        private const long BytesPerAtlasPixel = 40; // RGBA8 + 2*RGBA16f + RGBA32f + D32.
        private static readonly string[] Keywords = { "_NORMALMAP", "_PARALLAXMAP", "_DETAIL_MULX2", "_DETAIL_SCALED",
            "_ALPHATEST_ON", "_EMISSION", "_METALLICSPECGLOSSMAP", "_SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A", "_OCCLUSIONMAP", "_SPECULAR_SETUP" };
        private static readonly int[] TextureProperties = Ids("_BaseMap", "_MetallicGlossMap", "_SpecGlossMap", "_BumpMap",
            "_OcclusionMap", "_EmissionMap", "_DetailMask", "_DetailAlbedoMap", "_DetailNormalMap", "_ParallaxMap");
        private static readonly int[] FloatProperties = Ids("_Metallic", "_Smoothness", "_BumpScale", "_OcclusionStrength", "_Cutoff",
            "_WorkflowMode", "_SmoothnessTextureChannel", "_Surface", "_AlphaClip", "_DetailAlbedoMapScale", "_DetailNormalMapScale", "_Parallax");
        private static readonly int[] VectorProperties = Ids("_BaseMap_ST", "_DetailAlbedoMap_ST");
        private static readonly int[] ColorProperties = Ids("_BaseColor", "_SpecColor", "_EmissionColor");
        private static readonly int CardsId = Shader.PropertyToID("_HLGI_SurfaceCards");
        private static readonly int CardCountId = Shader.PropertyToID("_HLGI_SurfaceCardCount");
        private static readonly int RangesId = Shader.PropertyToID("_HLGI_SurfaceOwnerRanges");
        private static readonly int IndicesId = Shader.PropertyToID("_HLGI_SurfaceCardIndices");
        private static readonly int AnchorsId = Shader.PropertyToID("_HLGI_SurfaceAnchors");
        private static readonly int EmittersId = Shader.PropertyToID("_HLGI_SurfaceEmitters");
        private static readonly int EmitterPaddingId = Shader.PropertyToID("_HLGI_AnchorEmitterPadding");
        private static readonly int AtlasSizeId = Shader.PropertyToID("_HLGI_SurfaceAtlasSize");
        private static readonly int DiffuseId = Shader.PropertyToID("_HLGI_SurfaceDiffuse");
        private static readonly int EmissionId = Shader.PropertyToID("_HLGI_SurfaceEmission");
        private static readonly int PositionId = Shader.PropertyToID("_HLGI_SurfacePosition");
        private static readonly int NormalId = Shader.PropertyToID("_HLGI_SurfaceNormal");
        private static readonly int ShadowmaskId = Shader.PropertyToID("_HLGI_SurfaceShadowmask");
        private static readonly int CardShadowmaskId = Shader.PropertyToID("_HLGI_CardShadowmask");
        private static readonly int CardReceivesShadowsId = Shader.PropertyToID("_HLGI_CardReceivesShadows");
        private static readonly int CardShadowmaskSTId = Shader.PropertyToID("_HLGI_CardShadowmaskST");
        private static readonly int CardUseShadowmaskId = Shader.PropertyToID("_HLGI_CardUseShadowmask");
        private static readonly int WorldToCardId = Shader.PropertyToID("_HLGI_CardWorldToCard");
        private static readonly int CardRectId = Shader.PropertyToID("_HLGI_CardRect");
        private static readonly int DirectionId = Shader.PropertyToID("_HLGI_CardDirection");
        private static readonly int GeometryDirectionId = Shader.PropertyToID("_HLGI_CardGeometryDirection");
        private static readonly int ObjectDeterminantSignId = Shader.PropertyToID("_HLGI_CardObjectDeterminantSign");
        private static readonly int TintId = Shader.PropertyToID("_HLGI_CardTint");
        private static readonly int ExtraEmissionId = Shader.PropertyToID("_HLGI_CardExtraEmission");
        private static readonly int CullId = Shader.PropertyToID("_HLGI_CardCull");

        private readonly List<int> candidates = new List<int>();
        private readonly List<int> pending = new List<int>();
        private readonly List<int> scheduled = new List<int>();
        private readonly List<Bounds> changedBounds = new List<Bounds>();
        private readonly HashSet<Bounds> changedRegionSet = new HashSet<Bounds>();
        private Stack<int> freeTiles = new Stack<int>();
        private readonly List<Material> sourceMaterials = new List<Material>();
        private readonly HybridLumenGIMaterialSource materialSource = new HybridLumenGIMaterialSource();
        private readonly MaterialPropertyBlock rendererBlock = new MaterialPropertyBlock();
        private readonly MaterialPropertyBlock submeshBlock = new MaterialPropertyBlock();
        private RenderTargetIdentifier[] targets;
        private LightmapData[] shadowmaskSources;
        internal void SetShadowmaskSources(LightmapData[] maps) => shadowmaskSources = maps;
        private Owner[] owners = Array.Empty<Owner>();
        private Card[] cards = Array.Empty<Card>();
        private CardMetadata[] metadata = Array.Empty<CardMetadata>();
        private OwnerRange[] ownerRanges = Array.Empty<OwnerRange>();
        private uint[] cardIndices = Array.Empty<uint>();
        private HybridLumenGISurfaceCharts[] candidateCharts = Array.Empty<HybridLumenGISurfaceCharts>();
        private int[] requestedCards = Array.Empty<int>();
        private bool[] desired = Array.Empty<bool>();
        private AtlasResources atlasResources;
        private long retiringAtlasBytes;
        private ComputeBuffer metadataBuffer, rangesBuffer, indicesBuffer, anchorsBuffer, emittersBuffer;
        private ComputeShader anchorShader;
        private int anchorKernel, patchGrid;
        private uint nextLayoutGeneration;
        private Shader captureShader;
        private Material clearMaterial;
        private HybridLumenGIScene preparedScene;
        private double captureRecordingBudgetTicks;
        private Vector3 referencePosition;
        private int tileSize, tileCount, tileColumns;
        private bool clearPending, metadataDirty;

        public RTHandle DiffuseAtlas { get; private set; }
        public RTHandle EmissionAtlas { get; private set; }
        public RTHandle PositionAtlas { get; private set; }
        public RTHandle NormalAtlas { get; private set; }
        public RTHandle DepthAtlas { get; private set; }
        public RTHandle ShadowmaskAtlas { get; private set; }
        public int AtlasWidth { get; private set; }
        public int AtlasHeight { get; private set; }
        public uint AtlasGeneration { get; private set; }
        public int CardCount => cards.Length;
        public int[] CardOwners { get; private set; } = Array.Empty<int>();
        public int ChartedOwners { get; private set; }
        public int ApproximateOwners { get; private set; }
        public int RequiredCards { get; private set; }
        public int ResidentCards { get; private set; }
        public int ReadyCards { get; private set; }
        public int PendingCards { get; private set; }
        public int ScheduledCards => scheduled.Count;
        public int CapturedCards { get; private set; }
        internal bool LimitsCaptureRecording => captureRecordingBudgetTicks > 0;
        public int UnsupportedRenderers { get; private set; }
        public int DrawBudgetBlockedCards { get; private set; }
        public int WarmupBudgetBlockedCards { get; private set; }
        public bool[] ReadyMask { get; private set; } = Array.Empty<bool>();
        public IList<Bounds> ChangedBounds => changedBounds;
        public long AllocatedBytes => ActiveAtlasBytes + retiringAtlasBytes;
        private long ActiveAtlasBytes => (long)AtlasWidth * AtlasHeight * (BytesPerAtlasPixel + (ShadowmaskAtlas != null ? 8 : 0)) + (long)CardCount * (MetadataStride + 4 + patchGrid * patchGrid * 8 + EmittersStride) + (long)owners.Length * 16;
        public int GetCardCount(int slot) => slot >= 0 && slot < owners.Length && owners[slot] != null ? owners[slot].cardIndices.Length : 0;
        /// <summary>Frozen explicit capture bounds, including disabled/hidden warming sources.</summary>
        public bool TryGetPreparedCaptureBounds(int slot,out Bounds bounds)
        {
            bounds=default;
            if(slot<0 || slot>=owners.Length || owners[slot]==null) return false;
            bounds=owners[slot].bounds;return true;
        }
        public int GetCardIndex(int slot,int ordinal) => ordinal >= 0 && ordinal < GetCardCount(slot) ? owners[slot].cardIndices[ordinal] : -1;
        public uint GetLayoutGeneration(int slot) => slot >= 0 && slot < owners.Length && owners[slot] != null ? owners[slot].layoutGeneration : 0;
        public bool RequiresCardCoverage(int slot) => slot >= 0 && slot < owners.Length && owners[slot] != null && owners[slot].charts != null;
        /// <summary>CPU primitive-index payload plus outer-array references; excludes CLR array headers.
        /// At most 16 MiB per camera. Tables are built only for newly verified layouts/geometry,
        /// reused by every lookup, and released on retirement/disposal. No vertex/index copy is kept.</summary>
        public long TriangleMappingBytes { get; private set; }

        /// <summary>Current prepared exact-source geometry version, independent of card residency.</summary>
        public uint GetGeometryRevision(int slot) => TryGetPreparedProxy(slot, out var proxy) ? (uint)proxy.GeometryContentRevision : 0;

        /// <summary>O(1) exact original submesh/primitive mapping. Readiness is deliberately left
        /// to the GPU consumer; warming pages can supply identity before capture completes.</summary>
        public bool TryGetTriangleBinding(int slot, Mesh expectedMesh, int submesh, int primitive, out TriangleChartBinding binding)
        {
            binding = new TriangleChartBinding { cardIndex = uint.MaxValue };
            if (!TryGetPreparedProxy(slot, out var proxy) || slot >= owners.Length || expectedMesh == null) return false;
            Owner owner = owners[slot];
            if (owner == null || owner.proxy != proxy || owner.renderer != proxy.SourceRenderer || owner.charts == null ||
                owner.sourceMesh != expectedMesh || GetMesh(owner.renderer) != expectedMesh || owner.charts != proxy.SurfaceCharts ||
                !owner.charts.IsValid || owner.chartVersion != owner.charts.ContentVersion || owner.captureMesh != owner.charts.CaptureMesh ||
                owner.sourceGeometryRevision != proxy.GeometryContentRevision || owner.stableId != (uint)proxy.StableId ||
                owner.revision != (uint)proxy.Revision || owner.primitiveCharts == null || submesh < 0 || submesh >= owner.primitiveCharts.Length) return false;
            int[] table = owner.primitiveCharts[submesh];
            if (table == null || primitive < 0 || primitive >= table.Length) return false;
            int ordinal = table[primitive];
            if (ordinal < 0 || ordinal >= owner.cardIndices.Length) return false;
            int index = owner.cardIndices[ordinal];
            if (index < 0 || index >= cards.Length || CardOwners[index] != slot || cards[index].tile < 0 || cards[index].chartIndex != ordinal) return false;
            CardMetadata value = metadata[index];
            if (value.stableId != owner.stableId || value.revision != owner.revision || value.ownerSlot != (uint)slot ||
                value.layoutGeneration == 0 || value.layoutGeneration != owner.layoutGeneration || value.generation == 0 ||
                value.chartId != owner.charts.Charts[ordinal].stableId || (value.flags & 1u) == 0) return false;
            binding = new TriangleChartBinding { cardIndex = (uint)index, chartId = value.chartId,
                layoutGeneration = owner.layoutGeneration, geometryRevision = (uint)owner.sourceGeometryRevision };
            return true;
        }

        /// <summary>Reads the actual original submesh even when the owner has no resident cards.
        /// A nonempty per-submesh MPB replaces the renderer MPB; unspecified fields then use
        /// that submesh's material. Unsupported/invalid values return false, never owner material 0.</summary>
        public bool TryGetHardwareMaterial(int slot, Mesh expectedMesh, int submesh, out HardwareMaterial material)
        {
            material = default;
            if (!TryGetPreparedProxy(slot, out var proxy) || expectedMesh == null || !ExactSource(proxy.SourceRenderer) ||
                GetMesh(proxy.SourceRenderer) != expectedMesh || submesh < 0 || submesh >= expectedMesh.subMeshCount ||
                expectedMesh.GetTopology(submesh) != MeshTopology.Triangles) return false;
            Renderer renderer = proxy.SourceRenderer;
            renderer.GetSharedMaterials(sourceMaterials);
            if (submesh >= sourceMaterials.Count || !Supported(sourceMaterials[submesh])) return false;
            Material source = sourceMaterials[submesh];
            renderer.GetPropertyBlock(rendererBlock);
            renderer.GetPropertyBlock(submeshBlock, submesh);
            MaterialPropertyBlock block = submeshBlock.isEmpty ? rendererBlock : submeshBlock;
            float cull = SourceCull(source), surface = ReadFloat(source, block, "_Surface", 0f);
            if (!Finite(cull) || (cull != 0f && cull != 1f && cull != 2f) || !Finite(surface) || surface >= 0.5f) return false;
            Vector4 albedo = ReadLinearColor(source, block, "_BaseColor", Color.white, false);
            Vector4 specular = ReadLinearColor(source, block, "_SpecColor", new Color(0.2f, 0.2f, 0.2f, 1f), false);
            Vector4 emission = source.IsKeywordEnabled("_EMISSION") ? ReadLinearColor(source, block, "_EmissionColor", Color.clear, true) : default;
            float metallic = ReadFloat(source, block, "_Metallic", 0f);
            Color tint = proxy.AlbedoTint.linear, extra = proxy.EmissionOverride.linear;
            float intensity = proxy.EmissionIntensity;
            if (!Finite(albedo) || !Finite(specular) || !Finite(emission) || !Finite(metallic) || !Finite(intensity) ||
                !Finite(tint.r) || !Finite(tint.g) || !Finite(tint.b) || !Finite(extra.r) || !Finite(extra.g) || !Finite(extra.b)) return false;
            float fraction = source.IsKeywordEnabled("_SPECULAR_SETUP")
                ? 1f - Mathf.Clamp01(Mathf.Max(specular.x, Mathf.Max(specular.y, specular.z))) : 0.96f * (1f - Mathf.Clamp01(metallic));
            material.cullMode = (uint)cull;
            material.diffuse = new Vector4(Mathf.Clamp01(albedo.x * tint.r * fraction),
                Mathf.Clamp01(albedo.y * tint.g * fraction), Mathf.Clamp01(albedo.z * tint.b * fraction), 1f);
            material.emission = new Vector4(Mathf.Max(0f, (emission.x + extra.r) * intensity),
                Mathf.Max(0f, (emission.y + extra.g) * intensity), Mathf.Max(0f, (emission.z + extra.b) * intensity), 1f);
            return Finite(material.diffuse) && Finite(material.emission);
        }

        private bool TryGetPreparedProxy(int slot, out HybridLumenGIProxy proxy)
        {
            proxy = null;
            if (preparedScene == null || slot < 0 || slot >= preparedScene.Capacity) return false;
            var candidate = preparedScene.GetProxy(slot);
            if (candidate == null || !candidate.isActiveAndEnabled) return false;
            Renderer renderer = candidate.SourceRenderer;
            Vector4 identity = preparedScene.Data[slot].identity;
            if (renderer == null || !renderer.gameObject.activeInHierarchy || HasUnbakedUv0(renderer) ||
                candidate.StableId <= 0 || candidate.Revision <= 0 || candidate.GeometryContentRevision <= 0 ||
                (identity.w != 1f && identity.w != 2f) || identity.x != candidate.StableId || identity.y != candidate.Revision) return false;
            proxy = candidate;
            return true;
        }


        private static bool Finite(float value) => !float.IsNaN(value) && !float.IsInfinity(value);
        private static bool Finite(Vector4 value) => Finite(value.x) && Finite(value.y) && Finite(value.z) && Finite(value.w);

        /// <summary>Current page generation, or zero for an absent/out-of-range page.
        /// A nonzero generation alone does not mean capture or lighting has completed.</summary>
        public uint GetGeneration(int cardIndex)
        {
            if (cardIndex < 0 || cardIndex >= cards.Length || cards[cardIndex].tile < 0) return 0;
            return metadata[cardIndex].generation;
        }

        /// <summary>CPU recorded material-page readiness for this exact owner and
        /// revision, including warming owners. This is not a GPU fence, a coverage
        /// test, or evidence that any irradiance samples have converged.</summary>
        public bool IsSlotReady(int slot, int stableId, int revision)
        {
            if (preparedScene == null || slot < 0 || slot >= owners.Length || slot >= preparedScene.Capacity ||
                stableId <= 0 || revision < 0) return false;
            Vector4 identity = preparedScene.Data[slot].identity;
            if ((identity.w != 1f && identity.w != 2f) || (uint)identity.x != (uint)stableId || (uint)identity.y != (uint)revision) return false;
            Owner owner = owners[slot];
            if (owner == null || owner.stableId != (uint)stableId || owner.revision != (uint)revision) return false;
            if(owner.cardIndices == null || owner.cardIndices.Length == 0 || owner.layoutGeneration == 0) return false;
            foreach (int index in owner.cardIndices)
            {
                if(index < 0 || index >= cards.Length || CardOwners[index] != slot) return false;
                CardMetadata value = metadata[index];
                if (cards[index].tile < 0 || value.ready == 0 || !ReadyMask[index] || value.generation == 0 ||
                    value.stableId != (uint)stableId || value.revision != (uint)revision ||
                    value.ownerSlot != (uint)slot || value.layoutGeneration != owner.layoutGeneration) return false;
            }
            return true;
        }

        /// <summary>
        /// Read-only publication guard. Rechecks live source properties before
        /// Scene.Prepare consumes a previous GPU readiness ticket. It does not
        /// invalidate pages, consume ChangedBounds, schedule draws, or upload data.
        /// Only reusable scratch lists/property blocks are populated by the reads.
        /// </summary>
        public bool IsSlotSourceCurrent(int slot, int stableId, int revision)
        {
            if (!IsSlotReady(slot, stableId, revision)) return false;
            Owner owner = owners[slot];
            if (owner.proxy == null || !owner.proxy.isActiveAndEnabled || owner.proxy.StableId != stableId ||
                owner.proxy.Revision != revision || owner.proxy.SourceRenderer != owner.renderer ||
                !CanCaptureRegisteredRenderer(owner.renderer)) return false;
            if(owner.charts != owner.proxy.SurfaceCharts || (owner.charts != null &&
                (!owner.charts.IsValid || owner.chartVersion != owner.charts.ContentVersion || owner.sourceGeometryRevision!=owner.proxy.GeometryContentRevision ||
                 owner.captureMesh != owner.charts.CaptureMesh || owner.sourceMesh != GetMesh(owner.renderer)))) return false;
            owner.renderer.GetSharedMaterials(sourceMaterials);
            owner.renderer.GetPropertyBlock(rendererBlock);
            return owner.bakedShadow.Matches(HybridLumenGIShadowmask.Read(owner.renderer, shadowmaskSources, out _)) &&
                owner.signature == SourceSignature(owner.renderer, sourceMaterials) &&
                SourceMaterialsCurrent(owner) && owner.geometrySignature == GeometrySignature(owner.renderer);
        }

        public bool Prepare(HybridLumenGIScene scene, Config config)
        {
            if (scene == null) throw new ArgumentNullException(nameof(scene));
            if (config == null) throw new ArgumentNullException(nameof(config));
            SetShadowmaskSources(scene.ShadowmaskSources);
            changedBounds.Clear();
            changedRegionSet.Clear();
            captureShader ??= Resources.Load<Shader>("HybridLumenGI/HybridLumenGICardCapture");
            if (captureShader == null) throw new InvalidOperationException("HybridLumenGICardCapture shader is missing.");
            if(anchorShader == null)
            {
                anchorShader=Resources.Load<ComputeShader>("HybridLumenGI/HybridLumenGISurfaceAnchors");
                if(anchorShader == null) throw new InvalidOperationException("Surface anchor compute shader is missing.");
                anchorKernel=anchorShader.FindKernel("CSBuildAnchors");
            }
            if (clearMaterial == null) clearMaterial = CoreUtils.CreateEngineMaterial(captureShader);
            int resolution = Mathf.Clamp(Mathf.NextPowerOfTwo(Mathf.Max(16, config.tileResolution)), 16, 128);
            int grid=Mathf.Clamp(config.patchGrid,1,4);
            int wantedTiles = Mathf.Clamp(config.maxResidentCards,0,16384);
            long budget = Math.Max(0, config.maxAtlasMiB) * 1024L * 1024L;
            while (wantedTiles > 0 && EstimateBytes(wantedTiles, resolution, scene.Capacity,grid) > budget) wantedTiles--;
            bool changed = EnsureStorage(scene.Capacity, wantedTiles, resolution,grid);
            preparedScene = scene;
            float captureMilliseconds = config.captureRecordingCpuBudgetMilliseconds;
            captureRecordingBudgetTicks = captureMilliseconds > 0 && !float.IsInfinity(captureMilliseconds)
                ? captureMilliseconds * (Stopwatch.Frequency / 1000.0) : 0;
            referencePosition = config.referencePosition;
            candidates.Clear();
            Array.Clear(desired, 0, desired.Length);
            UnsupportedRenderers = CapturedCards = DrawBudgetBlockedCards = WarmupBudgetBlockedCards = 0;
            RequiredCards=ChartedOwners=ApproximateOwners=0;

            for (int slot = 0; slot < scene.Capacity; slot++)
            {
                requestedCards[slot]=0;candidateCharts[slot]=null;
                if (scene.Data[slot].identity.w < 0.5f) continue;
                Renderer renderer = scene.GetRenderer(slot);
                if (!Eligible(renderer, config.layerMask)) { UnsupportedRenderers++; continue; }
                var proxy=scene.GetProxy(slot);
                var asset=proxy.SurfaceCharts;
                if(asset != null)
                {
                    Mesh source=GetMesh(renderer);
                    Owner previous=owners[slot];
                    bool sourceAlreadyChecked=previous!=null && previous.charts==asset && previous.chartVersion==asset.ContentVersion &&
                        previous.sourceGeometryRevision==proxy.GeometryContentRevision && previous.sourceMesh==source && previous.captureMesh==asset.CaptureMesh;
                    if(!ExactSource(renderer) || !asset.IsValid || (!sourceAlreadyChecked && !asset.MatchesSource(source)))
                    { UnsupportedRenderers++;continue; }
                    // Required charts must all have a supported source material. Never mark a
                    // partially captured asset complete by silently dropping a submesh.
                    bool supported=true;
                    foreach(var chart in asset.Charts)
                        if(chart.sourceSubmesh<0 || chart.sourceSubmesh>=sourceMaterials.Count || !Supported(sourceMaterials[chart.sourceSubmesh]))
                        { supported=false;break; }
                    if(!supported) { UnsupportedRenderers++;continue; }
                    candidateCharts[slot]=asset;requestedCards[slot]=asset.Charts.Length;
                }
                else requestedCards[slot]=FallbackCardsPerInstance;
                RequiredCards+=requestedCards[slot];
                candidates.Add(slot);
            }
            candidates.Sort(CompareResidency);
            FillResidency(tileCount);
            if (RequiredCards > tileCount && RetainPublishedHlodCards(scene))
            {
                // Keep matching layouts from the original selection alongside the retained
                // HLOD pages. Only new allocations need to compete again for the free tiles.
                int remaining = tileCount;
                foreach (int slot in candidates)
                {
                    desired[slot] = desired[slot] && MatchesRequestedLayout(slot);
                    if (desired[slot]) remaining -= requestedCards[slot];
                }
                FillResidency(remaining);
            }
            for (int slot = 0; slot < owners.Length; slot++)
            {
                // Keep retired published owners' old bounds for invalidation, but
                // never let an unpublished warm-up change erase current HLOD light.
                Owner previous = owners[slot];
                if (previous != null && (uint)scene.Data[slot].identity.x == previous.stableId && scene.Data[slot].identity.w >= 0.5f)
                    previous.published = scene.Data[slot].identity.w == 1f;
                if(previous==null) continue;
                // Retire all changed layouts before allocating any of them, so an earlier
                // growing owner can use pages released by a later shrinking owner.
                if (!desired[slot] || !MatchesRequestedLayout(slot)) { Retire(slot); changed = true; }
            }

            foreach(int slot in candidates)
            {
                if (!desired[slot])
                {
                    if (scene.IsWarming(slot)) WarmupBudgetBlockedCards += requestedCards[slot];
                    continue;
                }
                HybridLumenGIProxy proxy = scene.GetProxy(slot);
                Renderer renderer = proxy.SourceRenderer;
                Bounds captureBounds = CaptureBounds(renderer);
                Owner owner = owners[slot];
                uint stableId = (uint)scene.Data[slot].identity.x, revision = (uint)scene.Data[slot].identity.y;
                if (owner == null)
                {
                    owner = new Owner { proxy = proxy, renderer = renderer, stableId = stableId, bounds = captureBounds,
                        published = scene.Data[slot].identity.w == 1f, charts=candidateCharts[slot], sourceMesh=GetMesh(renderer),
                        cardIndices=new int[requestedCards[slot]],layoutGeneration=NextLayoutGeneration(),sourceGeometryRevision=proxy.GeometryContentRevision };
                    owner.chartVersion=owner.charts!=null?owner.charts.ContentVersion:0;
                    owner.captureMesh=owner.charts!=null?owner.charts.CaptureMesh:null;
                    owners[slot] = owner;
                    for (int chart = 0; chart < owner.cardIndices.Length; chart++)
                    {
                        int index=freeTiles.Pop();owner.cardIndices[chart]=index;
                        cards[index].tile=index;cards[index].chartIndex=chart;CardOwners[index]=slot;
                    }
                    BuildTriangleMapping(owner);
                    changed = true;
                }
                bool sourceGeometryChanged = owner.sourceGeometryRevision != proxy.GeometryContentRevision;
                if (sourceGeometryChanged) BuildTriangleMapping(owner);
                owner.sourceGeometryRevision=proxy.GeometryContentRevision;
                if(owner.charts!=null) ChartedOwners++;else ApproximateOwners++;
                renderer.GetSharedMaterials(sourceMaterials);
                renderer.GetPropertyBlock(rendererBlock);
                int signature = SourceSignature(renderer, sourceMaterials);
                var bakedShadow = HybridLumenGIShadowmask.Read(renderer, shadowmaskSources, out var shadowmaskTexture);
                int geometrySignature = GeometrySignature(renderer);
                if (!TryCaptureMaterialSources(owner, out var observedSources, out bool volatileMaterialContent))
                {
                    // Invalid source uniforms/types cannot be published as fresh material pages.
                    // A RenderTexture is still observable and capturable; only its history is unstable.
                    Retire(slot); UnsupportedRenderers++; changed = true; continue;
                }
                bool materialsChanged = owner.signature != signature || owner.submeshes.Count == 0 ||
                    !SameMaterialSources(owner.materialSources, observedSources);
                if (owner.revision != revision || owner.geometrySignature != geometrySignature || materialsChanged || volatileMaterialContent ||
                    sourceGeometryChanged || !owner.bakedShadow.Matches(bakedShadow))
                {
                    if (owner.published)
                    {
                        AddChangedBounds(owner.bounds);
                        AddChangedBounds(captureBounds);
                    }
                    owner.bounds = captureBounds;
                    owner.revision = revision;
                    owner.signature = signature;
                    owner.geometrySignature = geometrySignature;
                    owner.bakedShadow = bakedShadow;
                    owner.shadowmaskTexture = shadowmaskTexture;
                    if (materialsChanged)
                    {
                        RebuildMaterials(owner, sourceMaterials);
                        owner.materialSources = observedSources;
                    }
                    foreach(int cardIndex in owner.cardIndices)
                    {
                        Card card = cards[cardIndex];
                        // Keep accumulated age so continuously edited objects do not starve.
                        card.dirty = true;
                        CardMetadata value = owner.charts!=null ? MakeChart(owner,card.chartIndex,card.tile) : MakeCard(captureBounds, card.chartIndex, card.tile);
                        value.stableId = stableId;
                        value.revision = revision;
                        value.ownerSlot=(uint)slot;value.layoutGeneration=owner.layoutGeneration;
                        value.chartId=owner.charts!=null?owner.charts.Charts[card.chartIndex].stableId:(uint)(card.chartIndex+1);
                        value.flags=owner.charts!=null?1u:0u;
                        if (owner.charts != null)
                            foreach (var submesh in owner.submeshes)
                                if (submesh.index == owner.charts.Charts[card.chartIndex].sourceSubmesh)
                                { value.flags |= (uint)Mathf.Clamp((int)submesh.cull, 0, 2) << 1; break; }
                        // Lighting cache tags store this generation as a float.
                        // Per-card increments remain exact and cannot collide merely
                        // because unrelated cards consumed a global generation range.
                        card.generation = card.generation >= 0x00ffffffu ? 1u : card.generation + 1u;
                        value.generation = card.generation;
                        value.ready = 0;
                        metadata[cardIndex] = value;
                        ReadyMask[cardIndex] = false;
                    }
                    metadataDirty = changed = true;
                }
            }

            RebuildRanges();

            pending.Clear();
            scheduled.Clear();
            ResidentCards = ReadyCards = 0;
            for (int index = 0; index < cards.Length; index++)
            {
                Card card = cards[index];
                if (card.tile < 0) continue;
                ResidentCards++;
                if (metadata[index].ready != 0) ReadyCards++;
                if (!card.dirty) continue;
                card.age = Mathf.Min(card.age + 1, 1000000);
                pending.Add(index);
            }
            pending.Sort(ComparePending);
            int drawRemaining = Mathf.Max(0, config.maxDrawsPerFrame);
            int captureRemaining = Mathf.Max(0, config.capturesPerFrame);
            foreach (int index in pending)
            {
                Owner owner = owners[CardOwners[index]];
                int draws = (owner.charts!=null?1:owner.submeshes.Count) + 1; // Includes the per-tile clear draw.
                if (draws > drawRemaining) { DrawBudgetBlockedCards++; continue; }
                if (captureRemaining == 0) break;
                scheduled.Add(index);
                // Time-limited capture may stop before this card. Only report
                // its recovery once the draw and anchors have been recorded.
                if (owner.published && !LimitsCaptureRecording) AddChangedBounds(owner.bounds);
                drawRemaining -= draws;
                captureRemaining--;
            }
            PendingCards = pending.Count;
            // A newly captured page changes the hit-material representation this frame.
            return changed || scheduled.Count > 0;
        }

        /// <summary>Reject recorded readiness after a failed render without replacing resources.
        /// Restoring the atlas clear requires invalidating every resident card, including warming cards.</summary>
        public void InvalidateRecordedCapture()
        {
            metadataDirty = clearPending = true;
            scheduled.Clear(); pending.Clear();
            ReadyCards = CapturedCards = PendingCards = 0;
            for (int index = 0; index < cards.Length; index++)
            {
                Card card = cards[index];
                if (card.tile < 0) continue;
                card.dirty = true;
                card.generation = card.generation >= 0x00ffffffu ? 1u : card.generation + 1u;
                CardMetadata value = metadata[index];
                value.generation = card.generation; value.ready = 0;
                metadata[index] = value; ReadyMask[index] = false;
                PendingCards++;
            }
        }

        /// <summary>
        /// Record on the graphics queue in an unsafe raster-capable pass, before
        /// BindCompute consumers. Import/register all five atlas textures in RG.
        /// This sets render targets/viewport but never modifies camera matrices.
        /// The caller binds its next targets; restoreViewport restores its viewport.
        /// </summary>
        public int RecordCapture(CommandBuffer command, Rect restoreViewport)
        {
            if (metadataBuffer == null) throw new InvalidOperationException("Call Prepare before RecordCapture.");
            CapturedCards = 0;
            if (metadataDirty)
            {
                command.SetBufferData(metadataBuffer, metadata);
                command.SetBufferData(rangesBuffer, ownerRanges);
                command.SetBufferData(indicesBuffer, cardIndices);
            }
            if (clearPending || scheduled.Count > 0)
            {
                command.SetRenderTarget(targets, DepthAtlas.nameID);
                command.SetViewport(new Rect(0, 0, AtlasWidth, AtlasHeight));
                if (clearPending)
                {
                    command.SetViewport(new Rect(0, 0, AtlasWidth, AtlasHeight));
                    command.ClearRenderTarget(true, true, Color.clear, SystemInfo.usesReversedZBuffer ? 0f : 1f);
                    clearPending = false;
                }
                long firstCapture = 0;
                foreach (int index in scheduled)
                {
                    Card card = cards[index];
                    Owner owner = owners[CardOwners[index]];
                    if (owner == null || owner.proxy == null || !owner.proxy.isActiveAndEnabled ||
                        !CanCaptureRegisteredRenderer(owner.renderer)) continue;
                    if (LimitsCaptureRecording)
                    {
                        long now = Stopwatch.GetTimestamp();
                        if (CapturedCards == 0) firstCapture = now;
                        else if (now - firstCapture >= captureRecordingBudgetTicks) break;
                    }
                    Rect fullTile = TileRect(card.tile);
                    // ClearRenderTarget may clear an entire attachment regardless of
                    // viewport. A raster clear preserves every other resident tile.
                    command.SetGlobalVector(CardRectId, new Vector4(fullTile.x / AtlasWidth, fullTile.y / AtlasHeight, fullTile.width / AtlasWidth, fullTile.height / AtlasHeight));
                    command.DrawProcedural(Matrix4x4.identity, clearMaterial, 1, MeshTopology.Triangles, 6);
                    CardMetadata value = metadata[index];
                    command.SetGlobalVector(CardRectId, value.atlasRect);
                    command.SetGlobalMatrix(WorldToCardId, value.worldToCard);
                    command.SetGlobalVector(DirectionId, value.directionTolerance);
                    Vector4 projectionAxis = default;
                    if (owner.charts != null)
                    {
                        // Undo the material's Cull Front flip for the winding oracle.
                        float sign = ((value.flags >> 1) & 3u) == 1u ? -1f : 1f;
                        var axis = value.directionTolerance;
                        projectionAxis = new Vector4(sign * axis.x, sign * axis.y, sign * axis.z, 1f);
                    }
                    command.SetGlobalVector(GeometryDirectionId, projectionAxis);
                    // Fallback uses DX12's default Unity raster winding plus the
                    // source object's mirror sign. External un-restored invert-culling is unsupported.
                    command.SetGlobalFloat(ObjectDeterminantSignId, owner.renderer.localToWorldMatrix.determinant < 0f ? -1f : 1f);
                    Color tint = owner.proxy.AlbedoTint.linear;
                    Color extraEmission = owner.proxy.EmissionOverride.linear;
                    command.SetGlobalVector(TintId, new Vector4(tint.r, tint.g, tint.b, 1));
                    command.SetGlobalVector(ExtraEmissionId, new Vector4(extraEmission.r, extraEmission.g, extraEmission.b, owner.proxy.EmissionIntensity));
                    command.SetGlobalFloat(CardUseShadowmaskId, owner.bakedShadow.captureUv ? 1f : 0f);
                    command.SetGlobalVector(CardShadowmaskSTId, owner.bakedShadow.scaleOffset);
                    command.SetGlobalTexture(CardShadowmaskId, owner.bakedShadow.captureUv ? owner.shadowmaskTexture : Texture2D.whiteTexture);
                    if(owner.charts!=null)
                    {
                        int sourceSubmesh=owner.charts.Charts[card.chartIndex].sourceSubmesh;
                        CapturedSubmesh submesh=owner.submeshes.Find(item=>item.index==sourceSubmesh);
                        if(submesh==null) continue;
                        command.SetGlobalFloat(CullId,submesh.cull);
                        // CaptureMesh has one submesh per chart. It retains the source vertex
                        // attributes but draws only this chart's assigned triangles, including
                        // internal surfaces hidden by other triangles in the original renderer.
                        command.DrawMesh(owner.captureMesh,owner.renderer.localToWorldMatrix,submesh.material,card.chartIndex,0,null);
                    }
                    else foreach (CapturedSubmesh submesh in owner.submeshes)
                    {
                        command.SetGlobalFloat(CullId, submesh.cull);
                        if (ExactSource(owner.renderer))
                        {
                            // Registered static HLOD sources may be hidden from
                            // camera rendering while their replacement warms up.
                            // DrawMesh has an explicit mesh/matrix and does not
                            // depend on Renderer.enabled semantics. MPB values
                            // are already copied into this capture-only material.
                            command.DrawMesh(GetMesh(owner.renderer), owner.renderer.localToWorldMatrix,
                                submesh.material, submesh.index, 0, null);
                        }
                        else command.DrawRenderer(owner.renderer, submesh.material, submesh.index, 0);
                    }
                    RecordAnchors(command,index,value.atlasRect,Mathf.Max(value.directionTolerance.w,0.001f));
                    value.ready = 1;
                    metadata[index] = value;
                    ReadyMask[index] = true;
                    card.dirty = false;
                    card.age = 0;
                    CapturedCards++;
                    if (owner.published && LimitsCaptureRecording) AddChangedBounds(owner.bounds);
                }
                command.SetViewport(restoreViewport);
                command.SetGlobalTexture(CardShadowmaskId, Texture2D.whiteTexture);
            }
            // Publish readiness after raster writes in the same queue. Prepare alone
            // never advertises an uploaded/captured page as GPU-ready.
            if (metadataDirty || CapturedCards > 0) command.SetBufferData(metadataBuffer, metadata);
            metadataDirty = false;
            ReadyCards += CapturedCards;
            PendingCards = Mathf.Max(0, PendingCards - CapturedCards);
            scheduled.Clear();
            return CapturedCards;
        }

        public void BindCompute(CommandBuffer command, ComputeShader compute, int kernel)
        {
            if (metadataBuffer == null) throw new InvalidOperationException("Prepare surface-cache resources before binding.");
            command.SetComputeBufferParam(compute, kernel, CardsId, metadataBuffer);
            command.SetComputeBufferParam(compute, kernel, RangesId, rangesBuffer);
            command.SetComputeBufferParam(compute, kernel, IndicesId, indicesBuffer);
            command.SetComputeBufferParam(compute, kernel, AnchorsId, anchorsBuffer);
            command.SetComputeIntParam(compute, CardCountId, metadata.Length);
            command.SetComputeVectorParam(compute, AtlasSizeId, new Vector4(AtlasWidth, AtlasHeight, 1f / AtlasWidth, 1f / AtlasHeight));
            command.SetComputeTextureParam(compute, kernel, DiffuseId, DiffuseAtlas.nameID);
            command.SetComputeTextureParam(compute, kernel, EmissionId, EmissionAtlas.nameID);
            command.SetComputeTextureParam(compute, kernel, PositionId, PositionAtlas.nameID);
            command.SetComputeTextureParam(compute, kernel, NormalId, NormalAtlas.nameID);
            if (ShadowmaskAtlas != null) command.SetComputeTextureParam(compute, kernel, ShadowmaskId, ShadowmaskAtlas.nameID);
            else command.SetComputeTextureParam(compute, kernel, ShadowmaskId, Texture2D.whiteTexture);
        }

        /// <summary>Bind per-card proposal descriptors. Consumers must also validate
        /// current surface-card identity/readiness and require published owners.
        /// The descriptor alone is neither a light source nor a readiness ticket.</summary>
        public void BindEmitters(CommandBuffer command,ComputeShader compute,int kernel)
        {
            if (emittersBuffer == null) throw new InvalidOperationException("Prepare surface-cache resources before binding emitters.");
            command.SetComputeBufferParam(compute,kernel,EmittersId,emittersBuffer);
        }

        private void RecordAnchors(CommandBuffer command,int cardIndex,Vector4 rect,float emitterPadding)
        {
            command.SetComputeIntParam(anchorShader,"_HLGI_AnchorCard",cardIndex);
            command.SetComputeIntParam(anchorShader,"_HLGI_AnchorGrid",patchGrid);
            command.SetComputeVectorParam(anchorShader,"_HLGI_AnchorRect",rect);
            command.SetComputeFloatParam(anchorShader,EmitterPaddingId,emitterPadding);
            command.SetComputeVectorParam(anchorShader,AtlasSizeId,new Vector4(AtlasWidth,AtlasHeight,1f/AtlasWidth,1f/AtlasHeight));
            command.SetComputeTextureParam(anchorShader,anchorKernel,DiffuseId,DiffuseAtlas.nameID);
            command.SetComputeTextureParam(anchorShader,anchorKernel,EmissionId,EmissionAtlas.nameID);
            command.SetComputeTextureParam(anchorShader,anchorKernel,PositionId,PositionAtlas.nameID);
            command.SetComputeTextureParam(anchorShader,anchorKernel,NormalId,NormalAtlas.nameID);
            command.SetComputeBufferParam(anchorShader,anchorKernel,AnchorsId,anchorsBuffer);
            BindEmitters(command,anchorShader,anchorKernel);
            command.DispatchCompute(anchorShader,anchorKernel,1,1,1);
        }

        private uint NextLayoutGeneration()
        {
            nextLayoutGeneration=nextLayoutGeneration==uint.MaxValue?1u:nextLayoutGeneration+1u;
            return nextLayoutGeneration;
        }

        private void RebuildRanges()
        {
            int cursor=0;
            for(int slot=0;slot<owners.Length;slot++)
            {
                Owner owner=owners[slot];
                OwnerRange range=default;
                if(owner!=null)
                {
                    range=new OwnerRange{first=(uint)cursor,count=(uint)owner.cardIndices.Length,
                        layoutGeneration=owner.layoutGeneration,geometryRevision=(uint)owner.sourceGeometryRevision};
                    foreach(int index in owner.cardIndices)
                    {
                        if(cardIndices[cursor]!=(uint)index) { cardIndices[cursor]=(uint)index;metadataDirty=true; }
                        cursor++;
                    }
                }
                var before=ownerRanges[slot];
                if(before.first!=range.first || before.count!=range.count || before.layoutGeneration!=range.layoutGeneration || before.geometryRevision!=range.geometryRevision)
                { ownerRanges[slot]=range;metadataDirty=true; }
            }
            for(;cursor<cardIndices.Length;cursor++)
                if(cardIndices[cursor]!=uint.MaxValue) { cardIndices[cursor]=uint.MaxValue;metadataDirty=true; }
        }

        private bool Eligible(Renderer renderer, int mask)
        {
            if (!CanCaptureRegisteredRenderer(renderer) || (mask & (1 << renderer.gameObject.layer)) == 0) return false;
            Mesh mesh = GetMesh(renderer);
            renderer.GetSharedMaterials(sourceMaterials);
            for (int submesh = 0; submesh < Mathf.Min(mesh.subMeshCount, sourceMaterials.Count); submesh++)
                if (mesh.GetTopology(submesh) == MeshTopology.Triangles && Supported(sourceMaterials[submesh])) return true;
            return false;
        }

        private static bool CanCaptureRegisteredRenderer(Renderer renderer)
        {
            if (renderer == null || !renderer.gameObject.activeInHierarchy || GetMesh(renderer) == null || HasUnbakedUv0(renderer)) return false;
            Matrix4x4 objectToWorld = renderer.localToWorldMatrix;
            float determinant = objectToWorld.determinant;
            if (!Finite(determinant) || determinant == 0f) return false;
            Matrix4x4 inverse = objectToWorld.inverse;
            for (int i = 0; i < 16; i++) if (!Finite(objectToWorld[i]) || !Finite(inverse[i])) return false;
            // A disabled/force-hidden MeshRenderer still supplies a stable shared
            // mesh for explicit world-card capture. A disabled skinned renderer
            // cannot be assumed to have an updated deformation, so reject it.
            if (ExactSource(renderer)) return true;
            return renderer is SkinnedMeshRenderer && renderer.enabled && !renderer.forceRenderingOff;
        }

        private static bool HasUnbakedUv0(Renderer renderer)
        {
            // Exact hits and explicit card draws read the prepared mesh's UV0.
            // A separate stream can change the real renderer's coverage and material.
            Mesh stream = (renderer as MeshRenderer)?.additionalVertexStreams;
            return stream != null && stream.HasVertexAttribute(VertexAttribute.TexCoord0);
        }

        private static bool ExactSource(Renderer renderer) => renderer is MeshRenderer || HybridLumenGIDeformedMesh.HasSnapshot(renderer);
        private static Mesh GetMesh(Renderer renderer) => HybridLumenGIDeformedMesh.GetSourceMesh(renderer);

        private static Bounds CaptureBounds(Renderer renderer)
        {
            Mesh mesh = GetMesh(renderer);
            if (!ExactSource(renderer) || mesh == null) return renderer.bounds;
            // The explicit DrawMesh source is sharedMesh + localToWorld, even
            // while the Renderer is disabled and its render-time bounds are stale.
            Bounds local = mesh.bounds;
            Matrix4x4 matrix = renderer.localToWorldMatrix;
            Vector3 x = matrix.MultiplyVector(new Vector3(local.extents.x, 0, 0));
            Vector3 y = matrix.MultiplyVector(new Vector3(0, local.extents.y, 0));
            Vector3 z = matrix.MultiplyVector(new Vector3(0, 0, local.extents.z));
            Vector3 extents = new Vector3(Mathf.Abs(x.x) + Mathf.Abs(y.x) + Mathf.Abs(z.x),
                Mathf.Abs(x.y) + Mathf.Abs(y.y) + Mathf.Abs(z.y), Mathf.Abs(x.z) + Mathf.Abs(y.z) + Mathf.Abs(z.z));
            return new Bounds(matrix.MultiplyPoint3x4(local.center), extents * 2);
        }

        private static bool Supported(Material material) => material != null && material.shader != null &&
            material.shader.name == "Universal Render Pipeline/Lit" && material.renderQueue <= 2500 &&
            (!material.HasProperty("_Surface") || material.GetFloat("_Surface") < 0.5f) &&
            (SourceCull(material) == 0f || SourceCull(material) == 1f || SourceCull(material) == 2f);

        // Unity MaterialPropertyBlock cannot change render state. Cull must come
        // from the source Material, not an MPB copied into our capture Material.
        private static float SourceCull(Material material) => material.HasProperty("_Cull") ? material.GetFloat("_Cull") : 2f;

        private bool TryCaptureMaterialSources(Owner owner, out HybridLumenGIMaterialSource.Snapshot[] snapshots,
            out bool volatileContent)
        {
            snapshots = new HybridLumenGIMaterialSource.Snapshot[sourceMaterials.Count];
            volatileContent = false;
            Mesh mesh = GetMesh(owner.renderer);
            int count = mesh != null ? Mathf.Min(mesh.subMeshCount, sourceMaterials.Count) : 0;
            bool any = false;
            for (int i = 0; i < count; i++)
            {
                if (!Supported(sourceMaterials[i]) || mesh.GetTopology(i) != MeshTopology.Triangles) continue;
                if (!materialSource.TryCapture(owner.renderer, i, sourceMaterials[i], out snapshots[i], out _)) return false;
                // Live texture pixels can change without a change to the capture material's bindings.
                volatileContent |= !snapshots[i].CanReuseHistory;
                any = true;
            }
            return any;
        }

        private static bool SameMaterialSources(HybridLumenGIMaterialSource.Snapshot[] previous, HybridLumenGIMaterialSource.Snapshot[] current)
        {
            if (previous == null || current == null || previous.Length != current.Length) return false;
            for (int i = 0; i < current.Length; i++)
            {
                if (current[i] == null) { if (previous[i] != null) return false; continue; }
                if (!current[i].Equals(previous[i])) return false;
            }
            return true;
        }

        private bool SourceMaterialsCurrent(Owner owner)
        {
            if (owner.materialSources == null || owner.materialSources.Length != sourceMaterials.Count) return false;
            Mesh mesh = GetMesh(owner.renderer);
            for (int i = 0; i < sourceMaterials.Count; i++)
            {
                var snapshot = owner.materialSources[i];
                if (snapshot != null)
                {
                    if (mesh == null || i >= mesh.subMeshCount || mesh.GetTopology(i) != MeshTopology.Triangles) return false;
                    if (!materialSource.IsCurrent(owner.renderer, i, snapshot)) return false;
                }
                else if (mesh != null && i < mesh.subMeshCount && mesh.GetTopology(i) == MeshTopology.Triangles && Supported(sourceMaterials[i]))
                    return false; // A previously unsupported slot became capturable without a rebuild.
            }
            return true;
        }

        private int SourceSignature(Renderer renderer, List<Material> materials)
        {
            unchecked
            {
                int hash = 17;
                Mesh mesh = GetMesh(renderer);
                hash = hash * 397 ^ (mesh != null ? mesh.subMeshCount : 0);
                for (int i = 0; i < materials.Count; i++)
                {
                    Material source = materials[i];
                    if (source == null) { hash *= 397; continue; }
                    hash = hash * 397 ^ source.GetInstanceID();
                    hash = hash * 397 ^ (int)source.ComputeCRC();
                    foreach (int property in TextureProperties)
                    {
                        if (!source.HasProperty(property)) continue;
                        Texture texture = source.GetTexture(property);
                        if (texture != null) hash = hash * 397 ^ (int)texture.updateCount;
                    }
                    renderer.GetPropertyBlock(submeshBlock, i);
                    hash = hash * 397 ^ BlockHash(submeshBlock.isEmpty ? rendererBlock : submeshBlock);
                }
                return hash;
            }
        }

        private static int GeometrySignature(Renderer renderer)
        {
            unchecked
            {
                int hash = renderer.localToWorldMatrix.GetHashCode() * 397 ^ CaptureBounds(renderer).GetHashCode();
                Mesh mesh = GetMesh(renderer);
                hash = hash * 397 ^ (mesh != null ? mesh.GetInstanceID() ^ mesh.vertexCount ^ mesh.subMeshCount : 0);
                // Skinning changes may preserve renderer bounds. Their geometry
                // pages are dynamic, while material copies can still be reused.
                if (renderer is SkinnedMeshRenderer && !HybridLumenGIDeformedMesh.HasSnapshot(renderer)) hash = hash * 397 ^ Time.frameCount;
                return hash;
            }
        }

        internal void AddChangedBounds(Bounds bounds)
        {
            if (changedRegionSet.Add(bounds)) changedBounds.Add(bounds);
        }

        private static int BlockHash(MaterialPropertyBlock block)
        {
            unchecked
            {
                int hash = 17;
                // Include fixed property identity and presence, not just the
                // sequence of present values (_Metallic=1 != _Smoothness=1).
                // This remains a compact invalidation hash, not exact identity.
                foreach (int p in FloatProperties)
                {
                    bool present = block.HasProperty(p); hash = (hash * 397 ^ p) * 397 ^ (present ? 1 : 0);
                    if (present) hash = hash * 397 ^ block.GetFloat(p).GetHashCode();
                }
                foreach (int p in ColorProperties)
                {
                    bool present = block.HasProperty(p); hash = (hash * 397 ^ p) * 397 ^ (present ? 1 : 0);
                    if (present) hash = hash * 397 ^ block.GetColor(p).GetHashCode();
                }
                foreach (int p in VectorProperties)
                {
                    bool present = block.HasProperty(p); hash = (hash * 397 ^ p) * 397 ^ (present ? 1 : 0);
                    if (present) hash = hash * 397 ^ block.GetVector(p).GetHashCode();
                }
                foreach (int p in TextureProperties)
                {
                    bool present = block.HasProperty(p); hash = (hash * 397 ^ p) * 397 ^ (present ? 1 : 0);
                    if (!present) continue;
                    Texture texture = block.GetTexture(p);
                    hash = hash * 397 ^ (texture != null ? texture.GetInstanceID() : 0);
                    hash = hash * 397 ^ (texture != null ? (int)texture.updateCount : 0);
                }
                return hash;
            }
        }

        private void RebuildMaterials(Owner owner, List<Material> sources)
        {
            foreach (CapturedSubmesh old in owner.submeshes) CoreUtils.Destroy(old.material);
            owner.submeshes.Clear();
            Mesh mesh = GetMesh(owner.renderer);
            int count = mesh != null ? Mathf.Min(mesh.subMeshCount, sources.Count) : 0;
            for (int i = 0; i < count; i++)
            {
                Material source = sources[i];
                if (!Supported(source) || mesh.GetTopology(i) != MeshTopology.Triangles) continue;
                var copy = CoreUtils.CreateEngineMaterial(captureShader);
                copy.CopyPropertiesFromMaterial(source);
                // Synchronize by name in the capture shader's own keyword space.
                // No override-shader keyword remapping is assumed.
                foreach (string keyword in Keywords) CoreUtils.SetKeyword(copy, keyword, source.IsKeywordEnabled(keyword));
                owner.renderer.GetPropertyBlock(submeshBlock, i);
                MaterialPropertyBlock block = submeshBlock.isEmpty ? rendererBlock : submeshBlock;
                foreach (int p in FloatProperties) if (block.HasProperty(p)) copy.SetFloat(p, block.GetFloat(p));
                foreach (int p in ColorProperties) if (block.HasProperty(p)) copy.SetColor(p, block.GetColor(p));
                foreach (int p in VectorProperties) if (block.HasProperty(p)) copy.SetVector(p, block.GetVector(p));
                foreach (int p in TextureProperties) if (block.HasProperty(p)) copy.SetTexture(p, block.GetTexture(p));
                copy.SetFloat("_Cull", SourceCull(source));
                copy.SetFloat(CardReceivesShadowsId, source.IsKeywordEnabled("_RECEIVE_SHADOWS_OFF") ? 0f : 1f);
                copy.enableInstancing = false; // Each explicit renderer/submesh draw owns its matrices.
                owner.submeshes.Add(new CapturedSubmesh { material = copy, index = i, cull = copy.GetFloat("_Cull") });
            }
        }

        private CardMetadata MakeCard(Bounds bounds, int face, int tile)
        {
            Vector3 direction = Vector3.zero;
            direction[face / 2] = (face & 1) == 0 ? 1f : -1f;
            Vector3 forward = -direction;
            Vector3 right = Vector3.Cross(Mathf.Abs(forward.y) > 0.9f ? Vector3.forward : Vector3.up, forward).normalized;
            Vector3 up = Vector3.Cross(forward, right);
            Vector3 extents = bounds.extents;
            float halfWidth = Mathf.Max(0.005f, DotAbs(right, extents)) * 1.01f;
            float halfHeight = Mathf.Max(0.005f, DotAbs(up, extents)) * 1.01f;
            float halfDepth = Mathf.Max(0.005f, DotAbs(direction, extents)) * 1.01f;
            Vector3 eye = bounds.center + direction * (halfDepth + 0.01f);
            float depthRange = 2f * halfDepth + 0.02f;
            Matrix4x4 worldToCard = Matrix4x4.identity;
            worldToCard.SetRow(0, new Vector4(right.x / (2 * halfWidth), right.y / (2 * halfWidth), right.z / (2 * halfWidth), 0.5f - Vector3.Dot(right, bounds.center) / (2 * halfWidth)));
            worldToCard.SetRow(1, new Vector4(up.x / (2 * halfHeight), up.y / (2 * halfHeight), up.z / (2 * halfHeight), 0.5f - Vector3.Dot(up, bounds.center) / (2 * halfHeight)));
            worldToCard.SetRow(2, new Vector4(forward.x / depthRange, forward.y / depthRange, forward.z / depthRange, -Vector3.Dot(forward, eye) / depthRange));
            Rect rect = TileRect(tile);
            float worldTexel = Mathf.Max(halfWidth, halfHeight) * 2f / (tileSize - 2);
            return new CardMetadata
            {
                worldToCard = worldToCard,
                atlasRect = new Vector4((rect.x + 1) / AtlasWidth, (rect.y + 1) / AtlasHeight,
                    (tileSize - 2f) / AtlasWidth, (tileSize - 2f) / AtlasHeight),
                directionTolerance = new Vector4(direction.x, direction.y, direction.z, Mathf.Max(0.002f, worldTexel * 1.5f))
            };
        }

        private CardMetadata MakeChart(Owner owner,int chartIndex,int tile)
        {
            var chart=owner.charts.Charts[chartIndex];
            Matrix4x4 objectToWorld=owner.renderer.localToWorldMatrix;
            Matrix4x4 worldToObject=objectToWorld.inverse;
            Matrix4x4 worldToCard=chart.localToCard*worldToObject;
            Vector3 direction=ChartFacingAxis(objectToWorld,worldToObject,chart.direction);
            foreach(var material in owner.submeshes)
                if(material.index==chart.sourceSubmesh && material.cull>0.5f && material.cull<1.5f) { direction=-direction;break; }
            Matrix4x4 cardToWorld=worldToCard.inverse;
            float texel=Mathf.Max(cardToWorld.MultiplyVector(Vector3.right).magnitude,cardToWorld.MultiplyVector(Vector3.up).magnitude)/(tileSize-2);
            Rect rect=TileRect(tile);
            return new CardMetadata
            {
                worldToCard=worldToCard,
                atlasRect=new Vector4((rect.x+1)/AtlasWidth,(rect.y+1)/AtlasHeight,(tileSize-2f)/AtlasWidth,(tileSize-2f)/AtlasHeight),
                directionTolerance=new Vector4(direction.x,direction.y,direction.z,Mathf.Max(0.002f,texel*1.5f))
            };
        }

        // A chart projects parallel to its baked axis d. M*d keeps the correct sign
        // against every transformed member normal M^-T*n, including under reflection.
        // Scaling by |M^-T*d| gives the seed plane a facing score of one at any scale.
        private static Vector3 ChartFacingAxis(Matrix4x4 objectToWorld, Matrix4x4 worldToObject, Vector3 d)
        {
            Vector3 ray = objectToWorld.MultiplyVector(d);
            Vector3 normal = worldToObject.transpose.MultiplyVector(d);
            double scale = Math.Sqrt((double)normal.x * normal.x + (double)normal.y * normal.y + (double)normal.z * normal.z);
            // Keep even the sum of three GPU dot-product terms representable.
            float largest = Mathf.Max(Mathf.Abs(ray.x), Mathf.Max(Mathf.Abs(ray.y), Mathf.Abs(ray.z)));
            if (largest > 0f) scale = Math.Min(scale, (float.MaxValue / 4d) / largest);
            return new Vector3((float)(ray.x * scale), (float)(ray.y * scale), (float)(ray.z * scale));
        }

        private void FillResidency(int remaining)
        {
            foreach (int slot in candidates)
            {
                int required = requestedCards[slot];
                if (desired[slot] || required > remaining) continue;
                desired[slot] = true;
                remaining -= required;
            }
        }

        private bool MatchesRequestedLayout(int slot)
        {
            Owner previous = owners[slot];
            if (previous == null || previous.stableId != (uint)preparedScene.Data[slot].identity.x ||
                previous.cardIndices.Length != requestedCards[slot]) return false;
            Renderer renderer = preparedScene.GetRenderer(slot);
            HybridLumenGISurfaceCharts asset = candidateCharts[slot];
            return previous.renderer == renderer && previous.sourceMesh == GetMesh(renderer) &&
                previous.charts == asset && (asset == null ||
                    (previous.chartVersion == asset.ContentVersion && previous.captureMesh == asset.CaptureMesh));
        }

        private bool RetainPublishedHlodCards(HybridLumenGIScene scene)
        {
            bool retained = false;
            foreach (var group in scene.GetPublishedHlodGroups())
            {
                bool needsRetention = false;
                foreach (int id in group)
                {
                    if (scene.TryGetPublishedSlot(id, out int slot) && desired[slot]) continue;
                    needsRetention = true;
                    break;
                }
                if (!needsRetention) continue;

                // The handoff can make all staged members compete with ordinary published
                // objects in this Prepare. Preserve only a complete, still-current layout.
                bool current = true;
                foreach (int id in group)
                {
                    if (scene.TryGetPublishedSlot(id, out int slot) && MatchesRequestedLayout(slot) &&
                        IsSlotSourceCurrent(slot, id, (int)scene.Data[slot].identity.y)) continue;
                    current = false;
                    break;
                }
                if (!current) continue;

                foreach (int id in group)
                    if (scene.TryGetPublishedSlot(id, out int slot)) desired[slot] = true;
                retained = true;
            }
            return retained;
        }

        private int CompareResidency(int a, int b)
        {
            // A staging HLOD representation must not evict currently published
            // material pages before its own GPU lighting has become publishable.
            bool publishedA = preparedScene.Data[a].identity.w == 1f;
            bool publishedB = preparedScene.Data[b].identity.w == 1f;
            if (publishedA != publishedB) return publishedA ? -1 : 1;
            float da = CaptureBounds(preparedScene.GetRenderer(a)).SqrDistance(referencePosition) * (owners[a] != null ? 0.8f : 1f);
            float db = CaptureBounds(preparedScene.GetRenderer(b)).SqrDistance(referencePosition) * (owners[b] != null ? 0.8f : 1f);
            int comparison = da.CompareTo(db);
            return comparison != 0 ? comparison : a.CompareTo(b);
        }
        private int ComparePending(int a, int b)
        {
            int age = cards[b].age.CompareTo(cards[a].age);
            return age != 0 ? age : a.CompareTo(b);
        }
        private Rect TileRect(int tile) => new Rect((tile % tileColumns) * tileSize, (tile / tileColumns) * tileSize, tileSize, tileSize);
        private static float DotAbs(Vector3 axis, Vector3 value) => Mathf.Abs(axis.x) * value.x + Mathf.Abs(axis.y) * value.y + Mathf.Abs(axis.z) * value.z;
        private static int[] Ids(params string[] names) { var ids = new int[names.Length]; for (int i = 0; i < names.Length; i++) ids[i] = Shader.PropertyToID(names[i]); return ids; }

        private long EstimateBytes(int tiles, int size, int slots,int grid)
        {
            int columns = Mathf.Max(1, Mathf.CeilToInt(Mathf.Sqrt(Mathf.Max(1, tiles))));
            int rows = Mathf.Max(1, (tiles + columns - 1) / columns);
            return (long)columns * rows * size * size * (BytesPerAtlasPixel + (shadowmaskSources != null ? 8 : 0)) + (long)Mathf.Max(1,tiles) * (MetadataStride+4+grid*grid*8+EmittersStride) + (long)slots*16;
        }

        private bool EnsureStorage(int slots, int wantedTiles, int resolution,int grid)
        {
            bool withShadowmask = shadowmaskSources != null;
            if (atlasResources != null && owners.Length == slots && tileCount == wantedTiles && tileSize == resolution &&
                patchGrid == grid && (ShadowmaskAtlas != null) == withShadowmask) return false;

            int columns = Mathf.Max(1, Mathf.CeilToInt(Mathf.Sqrt(Mathf.Max(1, wantedTiles))));
            int width = columns * resolution;
            int height = Mathf.Max(1, (wantedTiles + columns - 1) / columns) * resolution;
            int count = Mathf.Max(1, wantedTiles);
            var nextOwners = new Owner[slots];
            var nextDesired = new bool[slots];
            var nextCharts = new HybridLumenGISurfaceCharts[slots];
            var nextRequested = new int[slots];
            var nextCards = new Card[count];
            var nextMetadata = new CardMetadata[count];
            var nextRanges = new OwnerRange[slots];
            var nextIndices = new uint[count];
            var nextReady = new bool[count];
            var nextCardOwners = new int[count];
            var nextFreeTiles = new Stack<int>(wantedTiles);
            var nextTargets = new RenderTargetIdentifier[withShadowmask ? 5 : 4];
            for (int i = 0; i < count; i++)
            {
                nextCards[i] = new Card();
                nextCardOwners[i] = -1;
                nextIndices[i] = uint.MaxValue;
            }
            for (int tile = wantedTiles - 1; tile >= 0; tile--) nextFreeTiles.Push(tile);

            var next = new AtlasResources();
            try
            {
                next.metadata = new ComputeBuffer(count, MetadataStride, ComputeBufferType.Structured) { name = "Hybrid GI Surface Cards" };
                next.metadata.SetData(nextMetadata);
                next.ranges = new ComputeBuffer(Mathf.Max(1, slots), 16, ComputeBufferType.Structured) { name = "HLGI owner chart ranges" };
                next.ranges.SetData(slots > 0 ? nextRanges : new OwnerRange[1]);
                next.indices = new ComputeBuffer(count, 4, ComputeBufferType.Structured) { name = "HLGI chart indices" };
                next.indices.SetData(nextIndices);
                var emptyAnchors = new Vector2Int[count * grid * grid];
                for (int i = 0; i < emptyAnchors.Length; i++) emptyAnchors[i] = new Vector2Int(-1, -1);
                next.anchors = new ComputeBuffer(emptyAnchors.Length, 8, ComputeBufferType.Structured) { name = "HLGI captured surface anchors" };
                next.anchors.SetData(emptyAnchors);
                next.emitters = new ComputeBuffer(count, EmittersStride, ComputeBufferType.Structured) { name = "HLGI card emissive proposals" };
                next.emitters.SetData(new EmissiveRecord[count]);
                next.diffuse = Allocate(width, height, GraphicsFormat.R8G8B8A8_UNorm, "HLGI Card Diffuse");
                next.emission = Allocate(width, height, GraphicsFormat.R16G16B16A16_SFloat, "HLGI Card Emission");
                next.position = Allocate(width, height, GraphicsFormat.R32G32B32A32_SFloat, "HLGI Card Position Depth");
                next.normal = Allocate(width, height, GraphicsFormat.R16G16B16A16_SFloat, "HLGI Card Normal");
                next.depth = RTHandles.Alloc(width, height, depthBufferBits: DepthBits.Depth32,
                    colorFormat: GraphicsFormat.None, filterMode: FilterMode.Point, wrapMode: TextureWrapMode.Clamp, name: "HLGI Card Depth");
                if (withShadowmask) next.shadowmask = Allocate(width, height, GraphicsFormat.R16G16B16A16_SFloat, "HLGI Card Shadowmask");
                nextTargets[0] = next.diffuse.nameID; nextTargets[1] = next.emission.nameID;
                nextTargets[2] = next.position.nameID; nextTargets[3] = next.normal.nameID;
                if (withShadowmask) nextTargets[4] = next.shadowmask.nameID;
            }
            catch
            {
                next.Release();
                throw;
            }

            var previous = atlasResources;
            long previousBytes = ActiveAtlasBytes;
            ClearStorage();
            atlasResources = next;
            // Readbacks may outlive the old resources even though per-card generations restart at allocation.
            AtlasGeneration = AtlasGeneration == uint.MaxValue ? 1u : AtlasGeneration + 1u;
            tileCount = wantedTiles;
            tileSize = resolution;
            patchGrid = grid;
            tileColumns = columns;
            AtlasWidth = width;
            AtlasHeight = height;
            owners = nextOwners; desired = nextDesired; candidateCharts = nextCharts; requestedCards = nextRequested;
            cards = nextCards; metadata = nextMetadata; ownerRanges = nextRanges; cardIndices = nextIndices;
            ReadyMask = nextReady; CardOwners = nextCardOwners; freeTiles = nextFreeTiles; targets = nextTargets;
            metadataBuffer = next.metadata; rangesBuffer = next.ranges; indicesBuffer = next.indices;
            anchorsBuffer = next.anchors; emittersBuffer = next.emitters;
            DiffuseAtlas = next.diffuse; EmissionAtlas = next.emission; PositionAtlas = next.position;
            NormalAtlas = next.normal; DepthAtlas = next.depth; ShadowmaskAtlas = next.shadowmask;
            clearPending = metadataDirty = true;
            if (previous != null)
            {
                retiringAtlasBytes += previousBytes;
                HybridLumenGIResourceRetirement.Retire(() =>
                {
                    previous.Release();
                    retiringAtlasBytes -= previousBytes;
                });
            }
            return true;
        }

        private static RTHandle Allocate(int width, int height, GraphicsFormat format, string name) => RTHandles.Alloc(width, height,
            colorFormat: format, filterMode: FilterMode.Point, wrapMode: TextureWrapMode.Clamp, name: name);

        private void ClearTriangleMapping(Owner owner)
        {
            TriangleMappingBytes -= owner.primitiveChartBytes;
            owner.primitiveChartBytes = 0;
            owner.primitiveCharts = null;
        }

        private void BuildTriangleMapping(Owner owner)
        {
            ClearTriangleMapping(owner);
            if (owner.charts == null || owner.sourceMesh == null) return;
            Mesh mesh = owner.sourceMesh;
            int submeshCount = mesh.subMeshCount;
            long bytes = (long)submeshCount * IntPtr.Size;
            for (int s = 0; s < submeshCount; s++)
            {
                if (mesh.GetTopology(s) != MeshTopology.Triangles) continue;
                long count = (long)mesh.GetIndexCount(s);
                if (count % 3 != 0 || count / 3 > int.MaxValue) return;
                bytes += count / 3 * sizeof(int);
            }
            if (bytes > MaxTriangleMappingBytes - TriangleMappingBytes) return;
            var tables = new int[submeshCount][];
            for (int s = 0; s < submeshCount; s++)
            {
                int count = mesh.GetTopology(s) == MeshTopology.Triangles ? (int)(mesh.GetIndexCount(s) / 3) : 0;
                tables[s] = count > 0 ? new int[count] : Array.Empty<int>();
                for (int t = 0; t < count; t++) tables[s][t] = -1;
            }
            for (int ordinal = 0; ordinal < owner.charts.Charts.Length; ordinal++)
            {
                var chart = owner.charts.Charts[ordinal];
                if (chart.sourceSubmesh < 0 || chart.sourceSubmesh >= submeshCount || chart.triangleIndices == null) return;
                int[] table = tables[chart.sourceSubmesh];
                foreach (int primitive in chart.triangleIndices)
                {
                    // A corrupt mutable asset must not select an arbitrary first chart.
                    if (primitive < 0 || primitive >= table.Length || table[primitive] != -1) return;
                    table[primitive] = ordinal;
                }
            }
            owner.primitiveCharts = tables;
            owner.primitiveChartBytes = bytes;
            TriangleMappingBytes += bytes;
        }

        private void Retire(int slot)
        {
            Owner owner = owners[slot];
            if (owner != null)
            {
                ClearTriangleMapping(owner);
                if (owner.published) AddChangedBounds(owner.bounds);
                foreach (CapturedSubmesh submesh in owner.submeshes) CoreUtils.Destroy(submesh.material);
            }
            owners[slot] = null;
            if(owner!=null) foreach (int index in owner.cardIndices)
            {
                if (cards[index].tile >= 0) freeTiles.Push(cards[index].tile);
                cards[index].tile = -1;
                cards[index].dirty = false;
                cards[index].age = 0;
                metadata[index] = default;
                ReadyMask[index] = false;
                CardOwners[index]=-1;
            }
            metadataDirty = true;
        }

        private void ClearStorage()
        {
            for (int slot = 0; slot < owners.Length; slot++) if (owners[slot] != null) Retire(slot);
            atlasResources = null;
            metadataBuffer = rangesBuffer = indicesBuffer = anchorsBuffer = emittersBuffer = null;
            DiffuseAtlas = EmissionAtlas = PositionAtlas = NormalAtlas = DepthAtlas = null;
            ShadowmaskAtlas = null; targets = null;
            owners = Array.Empty<Owner>(); cards = Array.Empty<Card>(); metadata = Array.Empty<CardMetadata>(); desired = Array.Empty<bool>();
            ReadyMask = Array.Empty<bool>();
            ownerRanges=Array.Empty<OwnerRange>();cardIndices=Array.Empty<uint>();CardOwners=Array.Empty<int>();
            candidateCharts=Array.Empty<HybridLumenGISurfaceCharts>();requestedCards=Array.Empty<int>();
            freeTiles.Clear(); scheduled.Clear(); pending.Clear(); candidates.Clear();
            AtlasWidth = AtlasHeight = ResidentCards = ReadyCards = PendingCards = CapturedCards = 0;
            WarmupBudgetBlockedCards = 0;
        }

        public void Dispose()
        {
            shadowmaskSources = null;
            var resources = atlasResources;
            ClearStorage();
            resources?.Release();
            CoreUtils.Destroy(clearMaterial); clearMaterial = null;
            preparedScene = null;
        }
    }
}
