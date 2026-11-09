using System;
using System.Collections.Generic;
using System.Threading;
using UnityEngine;
using UnityEngine.Rendering;
using static HybridLumenGI.HybridLumenGIUniformLighting;

namespace HybridLumenGI
{
    /// <summary>
    /// Adds a lightweight world-space SDF proxy to the independent HybridLumenGI scene representation.
    /// Collider-only boxes retain their orientation. Other box proxies use world bounds.
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

        private Matrix4x4 lastMatrix, lastBoxMatrix;
        private Bounds lastBounds;
        private Color lastAlbedo;
        private Color lastEmission;
        private float lastDiffuseFraction;
        internal bool UniformShadowsOff { get; private set; }
        internal HybridLumenGIShadowmask.Source BakedShadowSource { get; private set; }

        internal void RefreshShadowmask(LightmapData[] maps)
        {
            var source = HybridLumenGIShadowmask.Read(SourceRenderer, maps, out _);
            if (BakedShadowSource.Matches(source)) return;
            BakedShadowSource = source;
            MarkTransportDirty();
        }
        private Mesh lastMesh;
        private HybridLumenGIMeshSource.Version lastMeshSourceVersion;
        private int lastVertexCount;
        private Bounds lastLocalMeshBounds;
        private Bounds lastColliderShape;
        private int lastObjectLayer;
        private uint lastRenderingLayerMask;
        private ShadowCastingMode lastShadowCastingMode;
        private List<Material> uniformSlots;
        private MaterialPropertyBlock uniformBlock;
        private int stableId;
        private int revision = 1;
        private int geometryContentRevision = 1;
        private int validationPending;
        public int GeometryContentRevision => geometryContentRevision;

        public Shape ProxyShape => shape;
        public Renderer SourceRenderer => sourceRenderer != null ? sourceRenderer : null;
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
        public Mesh SourceMesh
        {
            get
            {
                if (sourceRenderer != null) return HybridLumenGIDeformedMesh.GetSourceMesh(sourceRenderer);
                if (meshSdf == null) return null;
                // The SDF baker takes the MeshFilter on the proxy object, even without a Renderer.
                var filter = GetComponent<MeshFilter>();
                return filter != null ? filter.sharedMesh : null;
            }
        }
        public HybridLumenGIMeshSdf MeshSdf
        {
            get
            {
                var candidate=HybridLumenGIDeformedMesh.GetSdf(sourceRenderer,meshSdf);
                return candidate!=null && SourceMesh==candidate.SourceMesh?candidate:null;
            }
        }
        private BoxCollider ColliderBox => shape == Shape.Box && sourceRenderer == null ? sourceCollider as BoxCollider : null;
        private Bounds ColliderShape
        {
            get
            {
                var box = ColliderBox;
                return box != null && box.enabled && box.gameObject.activeInHierarchy ? new Bounds(box.center, box.size) : default;
            }
        }
        public Matrix4x4 SdfLocalToWorld => sourceRenderer != null ? sourceRenderer.localToWorldMatrix :
            ColliderBox != null && MeshSdf == null ? sourceCollider.transform.localToWorldMatrix : transform.localToWorldMatrix;
        private Matrix4x4 BoxLocalToWorld => ColliderBox != null ? sourceCollider.transform.localToWorldMatrix : default;

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
            if (sourceRenderer == null) sourceRenderer = GetComponent<Renderer>();
            if (sourceCollider == null) sourceCollider = GetComponent<Collider>();
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
        public bool RefreshSignatureForRender() => RefreshSignatureForRender(true);

        internal bool RefreshSignatureForRender(bool refreshInstance, Bounds? observedBounds = null)
        {
            if (!isActiveAndEnabled) return false;
            if (Volatile.Read(ref validationPending)!=0)
            { MarkDirty(); return true; }
            Mesh mesh = SourceMesh;
            int vertices = mesh != null ? mesh.vertexCount : 0;
            Bounds localBounds=mesh!=null?mesh.bounds:default;
            bool sameMesh=ReferenceEquals(mesh,lastMesh);
            bool contentChanged=!sameMesh || vertices!=lastVertexCount || localBounds!=lastLocalMeshBounds ||
                !ColliderShape.Equals(lastColliderShape);
            bool sourceNotified=sameMesh && !ReferenceEquals(HybridLumenGIMeshSource.GetVersion(mesh),lastMeshSourceVersion);
            // A remote instance can still discover a shared geometry edit. Local
            // material and transform state is only needed for a candidate camera.
            if (!refreshInstance && !contentChanged && !sourceNotified) return false;
            ReadMaterialInputs(true, out Color albedo, out Color emission, out float diffuseFraction, out bool shadowsOff);
            Bounds bounds = observedBounds ?? GetWorldBounds();
            int objectLayer = sourceRenderer != null ? sourceRenderer.gameObject.layer : gameObject.layer;
            uint renderingLayers = sourceRenderer != null ? sourceRenderer.renderingLayerMask : 1u;
            ShadowCastingMode casting = sourceRenderer != null ? sourceRenderer.shadowCastingMode : ShadowCastingMode.On;
            if (SdfLocalToWorld != lastMatrix || BoxLocalToWorld != lastBoxMatrix || bounds != lastBounds ||
                !albedo.Equals(lastAlbedo) || !emission.Equals(lastEmission) || diffuseFraction != lastDiffuseFraction || shadowsOff != UniformShadowsOff ||
                objectLayer != lastObjectLayer || renderingLayers != lastRenderingLayerMask || casting != lastShadowCastingMode ||
                contentChanged || sourceNotified)
            {
                // An ordinary receiver/editor may notify the shared Mesh directly.
                // Consume that source version locally; notifying again would cause
                // repeated peer invalidations as subsequent cameras refresh them.
                if(sourceNotified)
                {
                    MarkGeometryRepresentationChanged();return true;
                }
                CacheSignature();
                if(contentChanged) MarkDirty();else MarkTransportDirty();
                return true;
            }
            return false;
        }

        private void CacheSignature()
        {
            lastMatrix = SdfLocalToWorld;
            lastBoxMatrix = BoxLocalToWorld;
            lastBounds = GetWorldBounds();
            ReadMaterialInputs(true, out lastAlbedo, out lastEmission, out lastDiffuseFraction, out bool shadowsOff);
            UniformShadowsOff = shadowsOff;
            lastMesh = SourceMesh;
            lastMeshSourceVersion = HybridLumenGIMeshSource.GetVersion(lastMesh);
            lastVertexCount = lastMesh != null ? lastMesh.vertexCount : 0;
            lastLocalMeshBounds=lastMesh!=null?lastMesh.bounds:default;
            lastColliderShape = ColliderShape;
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
                if (sourceRenderer == null) sourceRenderer = GetComponent<Renderer>();
                if (sourceCollider == null) sourceCollider = GetComponent<Collider>();
                if (hlodParent == this) hlodParent = null;
            }
            Mesh mesh = SourceMesh ?? lastMesh;
            // Notify the shared SDF source stamp once, then update instances without
            // recursively calling MarkDirty. Different assets and chart-only owners
            // still share one editable Mesh and must invalidate their own generations.
            HybridLumenGIMeshSdf.NotifyGeometryChanged(mesh);
            MarkGeometryRepresentationChanged();
            if (mesh == null) return;
            for (int i = 0; i < Active.Count; i++)
            {
                HybridLumenGIProxy proxy = Active[i];
                if (proxy == null || ReferenceEquals(proxy,this) || !proxy.isActiveAndEnabled ||
                    !ReferenceEquals(proxy.SourceMesh,mesh)) continue;
                // Consume the shared source edit so the next camera/LateUpdate does
                // not broadcast the same count/bounds change a second time.
                proxy.MarkGeometryRepresentationChanged();
            }
        }

        // An instance can change its GI representation without editing the shared source mesh.
        internal void MarkGeometryRepresentationChanged()
        {
            NextExactInteger(ref geometryContentRevision);
            MarkTransportDirty();
            CacheSignature();
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

        // Use one pose for residency, BVH traversal and the final box hit. A collider on
        // a different object has its own transform, and a partial collider never replaces a renderer.
        internal bool TryGetColliderBox(out Bounds world, out Matrix4x4 worldToAxes, out Vector3 halfSize)
        {
            world = default;
            worldToAxes = default;
            halfSize = default;
            var box = ColliderBox;
            if (box == null || !box.enabled || !box.gameObject.activeInHierarchy) return false;
            var pose = box.transform;
            Matrix4x4 localToWorld = pose.localToWorldMatrix;
            Matrix4x4 axes = Matrix4x4.Rotate(pose.rotation);
            Vector3 size = box.size;
            Vector3 worldExtent = Vector3.zero;
            for (int i = 0; i < 3; i++)
            {
                Vector3 axis = axes.GetColumn(i);
                Vector3 column = localToWorld.GetColumn(i);
                float scale = Vector3.Dot(column, axis);
                // A sheared hierarchy does not supply an unambiguous rigid physics box.
                if (!((column - scale * axis).sqrMagnitude <= 1e-10f * scale * scale)) return false;
                float extent = 0.5f * size[i] * Mathf.Abs(scale);
                if (!(extent > 0f) || float.IsInfinity(extent)) return false;
                halfSize[i] = extent;
                worldExtent += extent * new Vector3(Mathf.Abs(axis.x), Mathf.Abs(axis.y), Mathf.Abs(axis.z));
            }
            world = new Bounds(localToWorld.MultiplyPoint3x4(box.center), worldExtent * 2f);
            worldToAxes = axes.transpose;
            return true;
        }

        private static Bounds TransformBounds(Bounds local, Matrix4x4 matrix)
        {
            Vector3 lo = local.min, hi = local.max;
            var world = new Bounds(matrix.MultiplyPoint3x4(local.center), Vector3.zero);
            for (int i = 0; i < 8; i++)
                world.Encapsulate(matrix.MultiplyPoint3x4(new Vector3((i & 1) == 0 ? lo.x : hi.x,
                    (i & 2) == 0 ? lo.y : hi.y, (i & 4) == 0 ? lo.z : hi.z)));
            return world;
        }

        public Bounds GetWorldBounds()
        {
            Renderer renderer = SourceRenderer;
            if (HybridLumenGIDeformedMesh.HasSnapshot(renderer)) return HybridLumenGIDeformedMesh.BoundsOf(renderer);
            // A collider may cover only part of a renderer. Mesh tracing needs conservative renderer bounds.
            if (renderer is MeshRenderer || (renderer != null && meshSdf != null && meshSdf.IsValid)) return renderer.bounds;
            if (TryGetColliderBox(out Bounds box, out _, out _)) return box;
            if (sourceCollider != null) return sourceCollider.bounds;
            if (renderer != null) return renderer.bounds;
            var mesh = SourceMesh;
            if (mesh != null) return TransformBounds(mesh.bounds, transform.localToWorldMatrix);
            return new Bounds(transform.position, Vector3.one);
        }

        public Color GetAlbedo()
        {
            ReadMaterialInputs(false, out Color albedo, out _, out _, out _);
            return albedo;
        }

        public Color GetEmission()
        {
            ReadMaterialInputs(false, out _, out Color emission, out _, out _);
            return emission;
        }

        /// <summary>Linear uniform fallback. Texture detail requires a resolved surface or triangle hit.</summary>
        public Color GetDiffuseReflectanceLinear()
        {
            ReadMaterialInputs(true, out Color tint, out _, out float fraction, out _);
            return new Color(Mathf.Clamp01(tint.r) * fraction, Mathf.Clamp01(tint.g) * fraction,
                Mathf.Clamp01(tint.b) * fraction, 1f);
        }

        public Color GetEmissionLinear()
        {
            ReadMaterialInputs(true, out _, out Color emission, out _, out _);
            return emission;
        }

        private MaterialPropertyBlock GetUniformBlock(Material material, out bool shadowsOff)
        {
            shadowsOff = false;
            if (!(sourceRenderer is MeshRenderer renderer)) return null;
            bool hasBlock = renderer.HasPropertyBlock();
            bool keywordOff = material.IsKeywordEnabled("_RECEIVE_SHADOWS_OFF");
            if ((!hasBlock && !keywordOff) || material.shader == null ||
                material.shader.name != "Universal Render Pipeline/Lit" || material.renderQueue > 2500)
                return null;
            Mesh mesh = SourceMesh;
            if (mesh == null || mesh.subMeshCount != 1) return null;
            uniformSlots ??= new List<Material>(1);
            renderer.GetSharedMaterials(uniformSlots);
            bool single = uniformSlots.Count == 1;
            uniformSlots.Clear();
            if (!single) return null;
            MaterialPropertyBlock block = null;
            if (hasBlock)
            {
                block = uniformBlock ??= new MaterialPropertyBlock();
                renderer.GetPropertyBlock(block, 0);
                if (block.isEmpty) renderer.GetPropertyBlock(block);
            }
            if (ReadFloat(material, block, "_Surface", 0f) < 0.5f)
            {
                shadowsOff = keywordOff;
                return block;
            }
            block?.Clear();
            return null;
        }

        private void ReadMaterialInputs(bool linear, out Color albedo, out Color emission, out float diffuseFraction, out bool shadowsOff)
        {
            albedo = linear ? albedoTint.linear : albedoTint;
            emission = linear ? emissionOverride.linear : emissionOverride;
            diffuseFraction = 0.96f;
            shadowsOff = false;
            Material material = readMaterialProperties && sourceRenderer != null ? sourceRenderer.sharedMaterial : null;
            if (material != null)
            {
                var block = GetUniformBlock(material, out shadowsOff);
                string baseName = material.HasProperty("_BaseColor") ? "_BaseColor" : "_Color";
                if (material.HasProperty(baseName))
                {
                    if (linear) albedo *= (Color)ReadLinearColor(material, block, baseName, Color.white, false);
                    else if (block != null && block.HasProperty(Shader.PropertyToID(baseName)))
                        albedo *= ((Color)block.GetVector(Shader.PropertyToID(baseName))).gamma;
                    else albedo *= material.GetColor(baseName);
                }
                if (material.IsKeywordEnabled("_EMISSION") && material.HasProperty("_EmissionColor"))
                    emission += (Color)ReadLinearColor(material, block, "_EmissionColor", Color.black, true);
                if (material.IsKeywordEnabled("_SPECULAR_SETUP") && material.HasProperty("_SpecColor"))
                {
                    Vector4 spec = ReadLinearColor(material, block, "_SpecColor", Color.black, false);
                    diffuseFraction = 1f - Mathf.Clamp01(Mathf.Max(spec.x, Mathf.Max(spec.y, spec.z)));
                }
                else diffuseFraction *= 1f - Mathf.Clamp01(ReadFloat(material, block, "_Metallic", 0f));
                block?.Clear();
            }
            albedo.a = 1f;
            emission.r *= emissionIntensity; emission.g *= emissionIntensity; emission.b *= emissionIntensity;
            if (linear) emission = new Color(Mathf.Max(0f, emission.r), Mathf.Max(0f, emission.g), Mathf.Max(0f, emission.b), 1f);
            emission.a = 1f;
        }

        public void SetSources(Renderer renderer, Collider collider)
        {
            sourceRenderer = renderer;
            sourceCollider = collider;
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
