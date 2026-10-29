using System;
using System.Collections.Generic;
using System.Threading;
using UnityEngine;
using UnityEngine.Rendering;

namespace HybridLumenGI
{
    /// <summary>
    /// Adds a lightweight world-space SDF proxy to the independent HybridLumenGI scene representation.
    /// Box proxies use world-space bounds; sphere proxies use a world-space sphere. This is not a mesh voxelizer.
    /// </summary>
    [ExecuteAlways, DisallowMultipleComponent]
    public sealed class HybridLumenGIProxy : MonoBehaviour
    {
        public enum Shape { Box = 0, Sphere = 1 }

        private static readonly List<HybridLumenGIProxy> Active = new List<HybridLumenGIProxy>();
        private static int version;
        private static int nextStableId;
        private static Vector3 sortPosition;

        [SerializeField] private Shape shape = Shape.Box;
        [SerializeField] private Renderer sourceRenderer;
        [SerializeField] private Collider sourceCollider;
        [SerializeField] private Color albedoTint = Color.white;
        [SerializeField] private Color emissionOverride = Color.black;
        [SerializeField, Min(0f)] private float emissionIntensity = 1f;
        [SerializeField, Range(0.01f, 1f)] private float roughness = 0.8f;
        [SerializeField] private bool readMaterialProperties = true;
        [Header("Scene residency")]
        [SerializeField, Tooltip("Optional authored aggregate proxy. All children switch to this proxy together when its bounds leave the near field.")]
        private HybridLumenGIProxy hlodParent;
        [SerializeField, Tooltip("An aggregate representation for distant geometry. Assign this proxy as HLOD Parent on its detail proxies.")]
        private bool farFieldOnly;
        [Header("Baked mesh distance field")]
        [SerializeField, Tooltip("Optional true mesh SDF. Analytic bounds remain the fallback until the tracing backend has uploaded this volume.")]
        private HybridLumenGIMeshSdf meshSdf;
        [Header("Baked surface charts")]
        [SerializeField, Tooltip("Triangle-isolated material charts. Without an asset, six first-layer cards remain an approximate fallback.")]
        private HybridLumenGISurfaceCharts surfaceCharts;
        public HybridLumenGISurfaceCharts SurfaceCharts => HybridLumenGIDeformedMesh.GetCharts(sourceRenderer,surfaceCharts);

        private Matrix4x4 lastMatrix;
        private Bounds lastBounds;
        private Color lastAlbedo;
        private Color lastEmission;
        private float lastDiffuseFraction;
        private Mesh lastMesh;
        private HybridLumenGIMeshSource.Version lastMeshSourceVersion;
        private int lastVertexCount;
        private Bounds lastLocalMeshBounds;
        private int lastObjectLayer;
        private uint lastRenderingLayerMask;
        private ShadowCastingMode lastShadowCastingMode;
        private MeshFilter sourceMeshFilter;
        private int stableId;
        private int revision = 1;
        private int geometryContentRevision = 1;
        private int validationPending;
        public int GeometryContentRevision => geometryContentRevision;

        public Shape ProxyShape => shape;
        public Renderer SourceRenderer => sourceRenderer;
        public Collider SourceCollider => sourceCollider;
        public Color AlbedoTint => albedoTint;
        public Color EmissionOverride => emissionOverride;
        public float EmissionIntensity => emissionIntensity;
        public float Roughness => roughness;
        public HybridLumenGIProxy HLODParent
        {
            get
            {
                // Invalid authored chains fall back to details. Bound traversal also handles a cycle
                // farther up the chain without recursion or unbounded work.
                HybridLumenGIProxy node = hlodParent;
                for (int depth = 0; node != null && depth < 64; depth++)
                {
                    if (node == this) return null;
                    if (node.hlodParent == null) return hlodParent;
                    node = node.hlodParent;
                }
                return null;
            }
        }
        public bool FarFieldOnly => farFieldOnly;
        public int StableId => stableId;
        public int Revision => revision;
        public Mesh SourceMesh => HybridLumenGIDeformedMesh.GetSourceMesh(sourceRenderer);
        public HybridLumenGIMeshSdf MeshSdf
        {
            get
            {
                var candidate=HybridLumenGIDeformedMesh.GetSdf(sourceRenderer,meshSdf);
                return candidate!=null && SourceMesh==candidate.SourceMesh?candidate:null;
            }
        }
        public Matrix4x4 SdfLocalToWorld => sourceRenderer != null ? sourceRenderer.localToWorldMatrix : transform.localToWorldMatrix;

        public static int Version => version;
        public static IReadOnlyList<HybridLumenGIProxy> ActiveProxies => Active;

        public static void SortByDistance(Vector3 position)
        {
            sortPosition = position;
            Active.Sort(CompareDistance);
        }

        private static int CompareDistance(HybridLumenGIProxy a, HybridLumenGIProxy b)
        {
            if (a == null) return b == null ? 0 : 1;
            if (b == null) return -1;
            float da = (a.GetWorldBounds().center - sortPosition).sqrMagnitude;
            float db = (b.GetWorldBounds().center - sortPosition).sqrMagnitude;
            return da.CompareTo(db);
        }

        private void Reset()
        {
            sourceRenderer = GetComponent<Renderer>();
            sourceCollider = GetComponent<Collider>();
            if (sourceCollider is SphereCollider) shape = Shape.Sphere;
        }

        private void OnEnable()
        {
            sourceRenderer ??= GetComponent<Renderer>();
            sourceCollider ??= GetComponent<Collider>();
            sourceMeshFilter = sourceRenderer != null ? sourceRenderer.GetComponent<MeshFilter>() : null;
            if (stableId == 0) stableId = NextExactInteger(ref nextStableId);
            if (!Active.Contains(this)) Active.Add(this);
            MarkDirty();
            CacheSignature();
        }

        private void OnDisable()
        {
            Active.Remove(this);
            version++;
        }

        private void OnValidate()
        {
            // Unity may invoke this on its loading thread. No component, Mesh,
            // Renderer or Active-list access is safe here. Main-thread preparation
            // coalesces these requests, including edits made while disabled.
            Interlocked.Exchange(ref validationPending,1);
        }

        private void LateUpdate() => RefreshSignatureForRender();

        /// <summary>
        /// Refresh on the main thread at each camera's scene preparation boundary.
        /// LateUpdate alone misses later scripts or manual camera renders. Repeated
        /// calls without source changes do not advance any generation.
        /// </summary>
        public bool RefreshSignatureForRender()
        {
            if (!isActiveAndEnabled) return false;
            if (Volatile.Read(ref validationPending)!=0)
            { MarkDirty(); return true; }
            Color albedo = GetAlbedo();
            Color emission = GetEmission();
            Bounds bounds = GetWorldBounds();
            float diffuseFraction = GetDiffuseFraction();
            Mesh mesh = RefreshSourceMesh();
            int vertices = mesh != null ? mesh.vertexCount : 0;
            Bounds localBounds=mesh!=null?mesh.bounds:default;
            bool sameMesh=ReferenceEquals(mesh,lastMesh);
            bool contentChanged=!sameMesh || vertices!=lastVertexCount || localBounds!=lastLocalMeshBounds;
            bool sourceNotified=sameMesh && !ReferenceEquals(HybridLumenGIMeshSource.GetVersion(mesh),lastMeshSourceVersion);
            int objectLayer = sourceRenderer != null ? sourceRenderer.gameObject.layer : gameObject.layer;
            uint renderingLayers = sourceRenderer != null ? sourceRenderer.renderingLayerMask : 1u;
            ShadowCastingMode casting = sourceRenderer != null ? sourceRenderer.shadowCastingMode : ShadowCastingMode.On;
            if (SdfLocalToWorld != lastMatrix || bounds != lastBounds ||
                albedo != lastAlbedo || emission != lastEmission || diffuseFraction != lastDiffuseFraction ||
                objectLayer != lastObjectLayer || renderingLayers != lastRenderingLayerMask || casting != lastShadowCastingMode ||
                contentChanged || sourceNotified)
            {
                // An ordinary receiver/editor may notify the shared Mesh directly.
                // Consume that source version locally; notifying again would cause
                // repeated peer invalidations as subsequent cameras refresh them.
                if(sourceNotified)
                {
                    BumpGeometryRevision();CacheSignature();return true;
                }
                CacheSignature();
                if(contentChanged) MarkDirty();else MarkTransportDirty();
                return true;
            }
            return false;
        }

        private Mesh RefreshSourceMesh()
        {
            sourceMeshFilter = sourceRenderer != null ? sourceRenderer.GetComponent<MeshFilter>() : null;
            return SourceMesh;
        }

        private void CacheSignature()
        {
            lastMatrix = SdfLocalToWorld;
            lastBounds = GetWorldBounds();
            lastAlbedo = GetAlbedo();
            lastEmission = GetEmission();
            lastDiffuseFraction = GetDiffuseFraction();
            lastMesh = SourceMesh;
            lastMeshSourceVersion = HybridLumenGIMeshSource.GetVersion(lastMesh);
            lastVertexCount = lastMesh != null ? lastMesh.vertexCount : 0;
            lastLocalMeshBounds=lastMesh!=null?lastMesh.bounds:default;
            lastObjectLayer = sourceRenderer != null ? sourceRenderer.gameObject.layer : gameObject.layer;
            lastRenderingLayerMask = sourceRenderer != null ? sourceRenderer.renderingLayerMask : 1u;
            lastShadowCastingMode = sourceRenderer != null ? sourceRenderer.shadowCastingMode : ShadowCastingMode.On;
        }

        /// <summary>
        /// Call on the main thread after in-place mesh edits with unchanged bounds/vertex count or property-block changes.
        /// This invalidates cached transport; edited mesh vertices still require an SDF rebake.
        /// Every active proxy sharing the edited Mesh is notified, including those without an SDF.
        /// Transform, bounds, mesh reference/count and uniform material changes are detected automatically.
        /// </summary>
        public void MarkDirty()
        {
            if (Interlocked.Exchange(ref validationPending,0)!=0)
            {
                sourceRenderer ??= GetComponent<Renderer>();
                sourceCollider ??= GetComponent<Collider>();
                if (hlodParent == this) hlodParent = null;
            }
            Mesh mesh = RefreshSourceMesh() ?? lastMesh;
            // Notify the shared SDF source stamp once, then update instances without
            // recursively calling MarkDirty. Different assets and chart-only owners
            // still share one editable Mesh and must invalidate their own generations.
            HybridLumenGIMeshSdf.NotifyGeometryChanged(mesh);
            BumpGeometryRevision();
            CacheSignature();
            if (mesh == null) return;
            for (int i = 0; i < Active.Count; i++)
            {
                HybridLumenGIProxy proxy = Active[i];
                if (proxy == null || ReferenceEquals(proxy,this) || !proxy.isActiveAndEnabled ||
                    !ReferenceEquals(proxy.RefreshSourceMesh(),mesh)) continue;
                proxy.BumpGeometryRevision();
                // Consume the shared source edit so the next camera/LateUpdate does
                // not broadcast the same count/bounds change a second time.
                proxy.CacheSignature();
            }
        }
        private void BumpGeometryRevision()
        {
            NextExactInteger(ref geometryContentRevision);
            MarkTransportDirty();
        }
        private void MarkTransportDirty()
        {
            NextExactInteger(ref revision);
            unchecked { version++; }
        }

        private static int NextExactInteger(ref int value)
        {
            // GPU metadata uses floats, so every exposed generation remains exactly representable.
            value = value >= 0x00ffffff ? 1 : value + 1;
            return value;
        }

        public Bounds GetWorldBounds()
        {
            if(HybridLumenGIDeformedMesh.HasSnapshot(sourceRenderer))return HybridLumenGIDeformedMesh.BoundsOf(sourceRenderer);
            // A collider may cover only part of a renderer. Mesh tracing needs conservative renderer bounds.
            if (sourceRenderer is MeshRenderer || (meshSdf != null && meshSdf.IsValid && sourceRenderer != null)) return sourceRenderer.bounds;
            if (sourceCollider != null) return sourceCollider.bounds;
            if (sourceRenderer != null) return sourceRenderer.bounds;
            return new Bounds(transform.position, Vector3.one);
        }

        public Color GetAlbedo()
        {
            Color value = albedoTint;
            if (readMaterialProperties && sourceRenderer != null && sourceRenderer.sharedMaterial != null)
            {
                Material material = sourceRenderer.sharedMaterial;
                if (material.HasProperty("_BaseColor")) value *= material.GetColor("_BaseColor");
                else if (material.HasProperty("_Color")) value *= material.GetColor("_Color");
            }
            value.a = 1f;
            return value;
        }

        public Color GetEmission()
        {
            Color value = emissionOverride;
            if (readMaterialProperties && sourceRenderer != null && sourceRenderer.sharedMaterial != null)
            {
                Material material = sourceRenderer.sharedMaterial;
                if (material.IsKeywordEnabled("_EMISSION") && material.HasProperty("_EmissionColor"))
                    value += material.GetColor("_EmissionColor");
            }
            value.r *= emissionIntensity;
            value.g *= emissionIntensity;
            value.b *= emissionIntensity;
            value.a = 1f;
            return value;
        }

        /// <summary>Linear diffuse reflectance for the Lambert transport cache. Texture and property-block capture require a surface capture pass.</summary>
        public Color GetDiffuseReflectanceLinear()
        {
            Color tint = albedoTint.linear;
            Material material = readMaterialProperties && sourceRenderer != null ? sourceRenderer.sharedMaterial : null;
            if (material != null)
            {
                if (material.HasProperty("_BaseColor")) tint *= material.GetColor("_BaseColor").linear;
                else if (material.HasProperty("_Color")) tint *= material.GetColor("_Color").linear;
            }
            float diffuse = GetDiffuseFraction();
            return new Color(Mathf.Clamp01(tint.r) * diffuse, Mathf.Clamp01(tint.g) * diffuse,
                Mathf.Clamp01(tint.b) * diffuse, 1f);
        }

        public Color GetEmissionLinear()
        {
            Color value = emissionOverride.linear;
            Material material = readMaterialProperties && sourceRenderer != null ? sourceRenderer.sharedMaterial : null;
            if (material != null && material.IsKeywordEnabled("_EMISSION") && material.HasProperty("_EmissionColor"))
                // URP Lit's HDR emission property is uploaded without sRGB
                // conversion. Confirmed by the actual Linear GPU color probe.
                value += material.GetColor("_EmissionColor");
            return new Color(Mathf.Max(0f, value.r * emissionIntensity), Mathf.Max(0f, value.g * emissionIntensity),
                Mathf.Max(0f, value.b * emissionIntensity), 1f);
        }

        private float GetDiffuseFraction()
        {
            Material material = readMaterialProperties && sourceRenderer != null ? sourceRenderer.sharedMaterial : null;
            if (material == null) return 0.96f;
            if (material.IsKeywordEnabled("_SPECULAR_SETUP") && material.HasProperty("_SpecColor"))
            {
                Color specular = material.GetColor("_SpecColor").linear;
                return 1f - Mathf.Clamp01(Mathf.Max(specular.r, specular.g, specular.b));
            }
            return 0.96f * (1f - (material.HasProperty("_Metallic") ? Mathf.Clamp01(material.GetFloat("_Metallic")) : 0f));
        }

        public void SetSources(Renderer renderer, Collider collider)
        {
            sourceRenderer = renderer;
            sourceCollider = collider;
            sourceMeshFilter = sourceRenderer != null ? sourceRenderer.GetComponent<MeshFilter>() : null;
            if (collider is SphereCollider) shape = Shape.Sphere;
            MarkDirty();
        }

        public void SetMeshSdf(HybridLumenGIMeshSdf asset)
        {
            meshSdf = asset;
            MarkDirty();
        }

        public void SetSurfaceCharts(HybridLumenGISurfaceCharts asset)
        {
            surfaceCharts = asset;
            MarkDirty();
        }

        /// <summary>Runtime binding for additive-scene detail and a persistent authored HLOD parent.</summary>
        public void SetHLODParent(HybridLumenGIProxy parent)
        {
            if(parent==this) parent=null;
            // Reject cycles before publishing a new group relationship.
            var ancestor=parent;
            for(int depth=0;ancestor!=null && depth<64;depth++)
            {
                if(ancestor==this) throw new ArgumentException("HLOD parent would create a cycle.",nameof(parent));
                ancestor=ancestor.hlodParent;
            }
            if(ancestor!=null) throw new ArgumentException("HLOD parent chain exceeds the supported depth.",nameof(parent));
            if(hlodParent==parent) return;
            hlodParent=parent;MarkDirty();
        }
    }
}
