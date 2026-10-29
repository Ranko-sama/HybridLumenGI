using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Security.Cryptography;
using System.Text;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.SceneManagement;
using Object = UnityEngine.Object;

namespace HybridLumenGI
{
    /// <summary>Literal scene inputs, not a GI evaluator. Values retain their Unity API representation.</summary>
    public static class HybridLumenGIValidationSourceData
    {
        [Serializable] public sealed class Asset
        {
            public string path, sha256, role;
            public long bytes;
            public string[] originalPaths = Array.Empty<string>(), roles = Array.Empty<string>();
        }
        [Serializable] public class Snapshot
        {
            public Geometry[] geometry;
            public MaterialInput[] materials;
            public LightInput[] lights;
            public EnvironmentInput environment;
            public RenderingInput rendering;
            public Asset[] assets;
            public string[] unsupported;
        }
        [Serializable] public sealed class SourceDocument : Snapshot
        {
            public string schema = "hlgi-validation-source-v2", sceneId;
            public string coordinateSystem = "Unity-left-handed-y-up", lengthUnit = "metre";
            public string valueConvention = "Literal Unity getters; Material color is authored API color, MPB color is a shader-space vector. No inferred albedo, exposure, radiance conversion, or baked decoding.";
            public string scope = "Source byte and input closure, not a claim that an independent renderer supports every recorded feature.";
            public ArchiveExclusion[] archiveExclusions = Array.Empty<ArchiveExclusion>();
        }
        [Serializable] public sealed class ArchiveExclusion { public string path, reason; }
        [Serializable] public sealed class ProvenanceArtifact { public string file, sha256, role; }
        [Serializable] public sealed class ProvenanceDocument { public ProvenanceArtifact[] artifacts; }
        [Serializable] public sealed class Geometry
        {
            public string key, name, rendererType, meshName, shadowCasting, lightProbeUsage, reflectionProbeUsage;
            public bool enabled, active, receiveShadows, forceRenderingOff, staticBatch;
            public int layer, lightmapIndex, realtimeLightmapIndex;
            public uint renderingLayerMask;
            public float[] localToWorld, lightmapScaleOffset, realtimeLightmapScaleOffset;
            public MeshInput mesh;
            public string[] materialKeys;
        }
        [Serializable] public sealed class MeshInput
        {
            public Vector3[] vertices, normals;
            public Vector4[] tangents;
            public Color[] colors;
            public UVChannel[] uv;
            public Submesh[] submeshes;
        }
        [Serializable] public sealed class UVChannel { public int channel; public Vector4[] values; }
        [Serializable] public sealed class Submesh { public string topology; public int baseVertex; public int[] indices; }
        [Serializable] public sealed class MaterialInput
        {
            public string key, name, shader, globalIlluminationFlags, propertyBlockScope;
            public string[] keywords, passes;
            public bool[] passEnabled;
            public int renderQueue;
            public bool enableInstancing, doubleSidedGI;
            public Property[] properties;
        }
        [Serializable] public sealed class Property
        {
            public string name, type, flags, origin;
            public float[] value;
            public TextureInput texture;
            public float[] textureScaleOffset;
        }
        [Serializable] public sealed class TextureInput
        {
            public string name, dimension, graphicsFormat, filterMode, wrapU, wrapV, wrapW;
            public int width, height, mipCount, anisoLevel;
            public float mipMapBias;
            public bool isDataSRGB, cpuReadable;
            public string rawFile, rawSha256;
            public string rawLayout = "Unity Texture2D.GetRawTextureData, all mip levels, native texture format; no image or color conversion";
        }
        [Serializable] public sealed class LightInput
        {
            public string key, name, type, shadows, bakeType, renderMode;
            public bool enabled, active, useColorTemperature;
            public int cullingMask;
            public uint renderingLayerMask;
            public float[] localToWorld, color, toLight;
            public float intensity, range, spotAngle, innerSpotAngle, colorTemperature, bounceIntensity;
            public float shadowStrength, shadowBias, shadowNormalBias, shadowNearPlane;
            public TextureInput cookie;
            public float cookieSize;
            public string shadowResolution;
            public int shadowCustomResolution;
            public AdditionalLightInput additional;
        }
        [Serializable] public sealed class AdditionalLightInput
        {
            public bool usePipelineSettings, customShadowLayers;
            public uint renderingLayers, shadowRenderingLayers;
            public int shadowResolutionTier;
            public string softShadowQuality;
            public float[] cookieSize, cookieOffset;
        }
        [Serializable] public sealed class LightmapInput
        { public TextureInput color, direction, shadowMask; }
        [Serializable] public sealed class EnvironmentInput
        {
            public string ambientMode, defaultReflectionMode, fogMode, lightmapsMode, sunKey;
            public float[] ambientLight, ambientSkyColor, ambientEquatorColor, ambientGroundColor, fogColor, ambientProbe;
            public float ambientIntensity, reflectionIntensity, fogDensity, fogStartDistance, fogEndDistance;
            public bool fog;
            public int reflectionBounces, defaultReflectionResolution, lightProbeCount;
            public MaterialInput skybox;
            public TextureInput customReflection;
            public LightmapInput[] lightmaps;
            public float[] hlgiEnvironmentRadiance;
            public string hlgiConstantUploadConversion = "UnityEngine.Color.linear; a supported cubemap replaces the constant";
            public TextureInput hlgiEnvironmentCubemap;
        }
        [Serializable] public sealed class RenderingInput
        {
            public string colorSpace, unityVersion, pipelineType;
            public string[] loadedScenes;
            public bool lightsUseLinearIntensity, lightsUseColorTemperature;
            public int cameraCullingMask;
            public string cameraClearFlags;
            public float[] cameraBackground;
            public PipelineInput urp;
        }
        [Serializable] public sealed class PipelineInput
        {
            public string rendererType, stencil;
            public Setting[] pipeline, renderer, camera;
            public string[] otherActiveFeatures;
        }
        [Serializable] public sealed class Setting { public string name, type, value; }

        sealed class Context
        {
            internal readonly string directory;
            internal readonly Action<Object, string> observe;
            internal readonly SortedSet<string> unsupported = new SortedSet<string>(StringComparer.Ordinal);
            internal readonly Dictionary<string, Asset> assets = new Dictionary<string, Asset>(StringComparer.Ordinal);
            internal Context(string directory, Action<Object, string> observe) { this.directory = directory; this.observe = observe; }
            internal void Object(Object value, string role) { if (value) observe?.Invoke(value, role); }
            internal void Unsupported(string reason) { unsupported.Add(reason); }
        }

        public static Snapshot Capture(Scene scene, Camera camera, string runDirectory, Action<Object, string> observe = null,
            HybridLumenGIRendererFeature feature = null)
        {
            if (!scene.IsValid() || !scene.isLoaded || !camera) throw new InvalidOperationException("A loaded scene and camera are required.");
            var context = new Context(Path.GetFullPath(runDirectory), observe);
            var renderers = new List<Renderer>(); var lights = new List<Light>(); var sceneKeys = new List<string>();
            var components = new List<Component>();
            for (int i = 0; i < SceneManager.sceneCount; ++i)
            {
                var loaded = SceneManager.GetSceneAt(i); if (!loaded.isLoaded) continue;
                string key = SceneKey(loaded); sceneKeys.Add(key);
                if (string.IsNullOrEmpty(loaded.path)) context.Unsupported("unsaved-scene:" + key);
                foreach (var root in loaded.GetRootGameObjects())
                {
                    renderers.AddRange(root.GetComponentsInChildren<Renderer>(true));
                    lights.AddRange(root.GetComponentsInChildren<Light>(true));
                    components.AddRange(root.GetComponentsInChildren<Component>(true));
                }
            }
            if (sceneKeys.Distinct(StringComparer.Ordinal).Count() != sceneKeys.Count) context.Unsupported("duplicate-scene-paths");
            foreach (var renderer in Object.FindObjectsByType<Renderer>(FindObjectsInactive.Include, FindObjectsSortMode.None))
                if (!renderers.Contains(renderer)) context.Unsupported("renderer-outside-enumerated-scenes:" + renderer.GetType().FullName + ":" + renderer.name);
            foreach (var light in Object.FindObjectsByType<Light>(FindObjectsInactive.Include, FindObjectsSortMode.None))
                if (!lights.Contains(light)) context.Unsupported("light-outside-enumerated-scenes:" + light.name);
            // These sources need deformation, volume, or baked-light interpretation beyond this bounded exporter.
            foreach (var component in components)
            {
                if (!component) { context.Unsupported("missing-script-in-loaded-scene"); continue; }
                string type = component.GetType().FullName;
                if (component is Terrain || component is ReflectionProbe || component is LODGroup ||
                    type == "UnityEngine.ParticleSystem" || type == "UnityEngine.Animator" || type == "UnityEngine.Rendering.Volume" ||
                    type.Contains("ProbeVolume") || type.Contains("DecalProjector"))
                { context.Unsupported("unmodeled-component:" + Key(component) + ":" + type); context.Object(component, "unmodeled-scene-source"); }
            }
            renderers.Sort((a, b) => StringComparer.Ordinal.Compare(Key(a), Key(b)));
            lights.Sort((a, b) => StringComparer.Ordinal.Compare(Key(a), Key(b)));
            var geometry = new List<Geometry>(); var materials = new List<MaterialInput>();
            foreach (var renderer in renderers)
            {
                context.Object(renderer, "scene-renderer");
                string key = Key(renderer); Mesh mesh = null;
                if (renderer is MeshRenderer mr)
                {
                    var filter = renderer.GetComponent<MeshFilter>(); mesh = filter ? filter.sharedMesh : null;
                    if (mr.additionalVertexStreams) context.Unsupported("additional-vertex-streams:" + key);
                }
                else { context.Unsupported("renderer-type:" + key + ":" + renderer.GetType().FullName); }
                if (renderer.isPartOfStaticBatch) context.Unsupported("static-batched-geometry:" + key);
                if (renderer.lightProbeUsage != LightProbeUsage.Off) context.Unsupported("light-probe-interpolation:" + key);
                if (renderer.reflectionProbeUsage != ReflectionProbeUsage.Off) context.Unsupported("reflection-probe-interpolation:" + key);
                var shared = renderer.sharedMaterials; var keys = new string[shared.Length];
                var general = new MaterialPropertyBlock(); renderer.GetPropertyBlock(general);
                for (int slot = 0; slot < shared.Length; ++slot)
                {
                    keys[slot] = key + "/material[" + slot + "]";
                    var indexed = new MaterialPropertyBlock(); renderer.GetPropertyBlock(indexed, slot);
                    bool useIndexed = !indexed.isEmpty;
                    // Unity's indexed block replaces the renderer block, not a per-property merge.
                    materials.Add(Material(shared[slot], keys[slot], useIndexed ? indexed : general,
                        useIndexed ? "material-slot" : general.isEmpty ? "none" : "renderer", context));
                }
                geometry.Add(new Geometry { key = key, name = renderer.name, rendererType = renderer.GetType().FullName,
                    enabled = renderer.enabled, active = renderer.gameObject.activeInHierarchy, forceRenderingOff = renderer.forceRenderingOff,
                    staticBatch = renderer.isPartOfStaticBatch, layer = renderer.gameObject.layer, renderingLayerMask = renderer.renderingLayerMask,
                    localToWorld = Matrix(renderer.localToWorldMatrix), shadowCasting = renderer.shadowCastingMode.ToString(),
                    receiveShadows = renderer.receiveShadows, lightProbeUsage = renderer.lightProbeUsage.ToString(),
                    reflectionProbeUsage = renderer.reflectionProbeUsage.ToString(), lightmapIndex = renderer.lightmapIndex,
                    realtimeLightmapIndex = renderer.realtimeLightmapIndex, lightmapScaleOffset = Vector(renderer.lightmapScaleOffset),
                    realtimeLightmapScaleOffset = Vector(renderer.realtimeLightmapScaleOffset), meshName = mesh ? mesh.name : "",
                    mesh = Mesh(mesh, key, context), materialKeys = keys });
            }
            var lightInputs = lights.Select(l => Light(l, context)).ToArray();
            var environment = Environment(context, feature);
            var pipeline = GraphicsSettings.currentRenderPipeline; context.Object(pipeline, "render-pipeline-asset");
            if (!pipeline || pipeline.GetType().FullName != "UnityEngine.Rendering.Universal.UniversalRenderPipelineAsset")
                context.Unsupported("render-pipeline-not-urp");
            if (QualitySettings.activeColorSpace != ColorSpace.Linear) context.Unsupported("nonlinear-project-color-space");
            var result = new Snapshot { geometry = geometry.ToArray(), materials = materials.ToArray(), lights = lightInputs,
                environment = environment, rendering = new RenderingInput { colorSpace = QualitySettings.activeColorSpace.ToString(),
                    unityVersion = Application.unityVersion, pipelineType = pipeline ? pipeline.GetType().FullName : "none",
                    loadedScenes = sceneKeys.OrderBy(x => x, StringComparer.Ordinal).ToArray(), lightsUseLinearIntensity = GraphicsSettings.lightsUseLinearIntensity,
                    lightsUseColorTemperature = GraphicsSettings.lightsUseColorTemperature, cameraCullingMask = camera.cullingMask,
                    cameraClearFlags = camera.clearFlags.ToString(), cameraBackground = Color(camera.backgroundColor), urp = Pipeline(camera, context) },
                assets = context.assets.Values.OrderBy(x => x.path, StringComparer.Ordinal).ToArray(), unsupported = context.unsupported.ToArray() };
            ValidateNumbers(result); return result;
        }

        // Normalize only actual physical URP configuration. Never serialize rendererFeatures,
        // renderer asset bytes, object instance IDs, or HLGI algorithm settings into the physical hash.
        static PipelineInput Pipeline(Camera camera, Context c)
        {
            var asset = GraphicsSettings.currentRenderPipeline as UniversalRenderPipelineAsset;
            if (!asset) return null;
            var additional = camera.GetComponent<UniversalAdditionalCameraData>();
            int index = additional ? (ReadField(additional, "m_RendererIndex") is int selected ? selected : -2) : -1;
            int fallback = ReadField(asset, "m_DefaultRendererIndex") is int defaultIndex ? defaultIndex : -2;
            var list = ReadField(asset, "m_RendererDataList") as ScriptableRendererData[];
            if (index == -1) index = fallback;
            if (list == null || fallback < 0 || index == -2) { c.Unsupported("urp-renderer-selection-unavailable"); return null; }
            if (index < 0 || index >= list.Length || !list[index]) index = fallback;
            if (index < 0 || index >= list.Length || !list[index]) { c.Unsupported("urp-renderer-selection-invalid"); return null; }
            var data = list[index]; c.Object(data, "mixed-renderer-asset-provenance");
            var renderer = data as UniversalRendererData;
            if (!renderer) c.Unsupported("unmodeled-urp-renderer:" + data.GetType().FullName);
            var other = new List<string>();
            foreach (var feature in data.rendererFeatures)
            {
                if (!feature) { c.Unsupported("missing-urp-renderer-feature"); continue; }
                c.Object(feature, "renderer-feature-provenance");
                if (feature is HybridLumenGIRendererFeature || !feature.isActive) continue;
                other.Add(feature.GetType().FullName); c.Unsupported("unmodeled-active-renderer-feature:" + feature.GetType().FullName);
            }
            if (additional && additional.renderPostProcessing) c.Unsupported("camera-post-processing-not-modeled");
            return new PipelineInput { rendererType = data.GetType().FullName,
                stencil = renderer ? JsonUtility.ToJson(renderer.defaultStencilState) : "",
                pipeline = Settings(asset, c, new[] { "supportsCameraDepthTexture", "supportsCameraOpaqueTexture", "opaqueDownsampling",
                    "supportsHDR", "hdrColorBufferPrecision", "msaaSampleCount", "renderScale", "upscalingFilter", "fsrOverrideSharpness", "fsrSharpness",
                    "enableLODCrossFade", "lodCrossFadeDitheringType", "shEvalMode", "lightProbeSystem", "mainLightRenderingMode",
                    "supportsMainLightShadows", "mainLightShadowmapResolution", "additionalLightsRenderingMode", "maxAdditionalLightsCount",
                    "supportsAdditionalLightShadows", "additionalLightsShadowmapResolution", "additionalLightsShadowResolutionTierLow",
                    "additionalLightsShadowResolutionTierMedium", "additionalLightsShadowResolutionTierHigh", "reflectionProbeBlending",
                    "reflectionProbeBoxProjection", "shadowDistance", "shadowCascadeCount", "cascade2Split", "cascade3Split", "cascade4Split",
                    "cascadeBorder", "shadowDepthBias", "shadowNormalBias", "supportsSoftShadows", "supportsMixedLighting", "supportsLightCookies",
                    "useRenderingLayers", "colorGradingMode", "colorGradingLutSize" }),
                renderer = renderer ? Settings(renderer, c, new[] { "opaqueLayerMask", "transparentLayerMask", "shadowTransparentReceive",
                    "renderingMode", "depthPrimingMode", "copyDepthMode", "depthAttachmentFormat", "depthTextureFormat", "accurateGbufferNormals", "intermediateTextureMode" }) : Array.Empty<Setting>(),
                camera = additional ? Settings(additional, c, new[] { "renderType", "renderShadows", "renderPostProcessing", "antialiasing",
                    "antialiasingQuality", "stopNaN", "dithering", "allowXRRendering", "requiresDepthTexture", "requiresColorTexture" }) : Array.Empty<Setting>(),
                otherActiveFeatures = other.OrderBy(x => x, StringComparer.Ordinal).ToArray() };
        }
        static object ReadField(object value, string name)
        {
            for (var type = value.GetType(); type != null; type = type.BaseType)
            { var field = type.GetField(name, System.Reflection.BindingFlags.Instance | System.Reflection.BindingFlags.Public | System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.DeclaredOnly); if (field != null) return field.GetValue(value); }
            return null;
        }
        static Setting[] Settings(object value, Context c, string[] names)
        {
            var result = new List<Setting>();
            foreach (string name in names.OrderBy(x => x, StringComparer.Ordinal))
            {
                var property = value.GetType().GetProperty(name, System.Reflection.BindingFlags.Public | System.Reflection.BindingFlags.Instance);
                if (property == null) { c.Unsupported("urp-setting-unavailable:" + value.GetType().Name + ":" + name); continue; }
                object input = property.GetValue(value); string text;
                if (input is LayerMask mask) text = mask.value.ToString(System.Globalization.CultureInfo.InvariantCulture);
                else if (input is Vector2 v2) text = Scalar(v2.x) + "," + Scalar(v2.y);
                else if (input is Vector3 v3) text = Scalar(v3.x) + "," + Scalar(v3.y) + "," + Scalar(v3.z);
                else if (input is float f) text = Scalar(f);
                else if (input is bool b) text = b ? "true" : "false";
                else if (input != null && (input.GetType().IsPrimitive || input.GetType().IsEnum)) text = Convert.ToString(input, System.Globalization.CultureInfo.InvariantCulture);
                else { c.Unsupported("urp-setting-unmodeled:" + value.GetType().Name + ":" + name); continue; }
                result.Add(new Setting { name = name, type = property.PropertyType.FullName, value = text });
            }
            return result.ToArray();
        }
        static string Scalar(float value)
        { Finite(new[] { value }, 1, "URP setting"); return value.ToString("R", System.Globalization.CultureInfo.InvariantCulture); }

        static MeshInput Mesh(Mesh mesh, string key, Context c)
        {
            if (!mesh) { c.Unsupported("missing-mesh:" + key); return null; }
            c.Object(mesh, "mesh-source");
            if (!mesh.isReadable) { c.Unsupported("unreadable-mesh:" + key); return null; }
            if (mesh.blendShapeCount != 0) c.Unsupported("blendshape-mesh:" + key);
            var uv = new UVChannel[8];
            for (int i = 0; i < uv.Length; ++i) { var values = new List<Vector4>(); mesh.GetUVs(i, values); uv[i] = new UVChannel { channel = i, values = values.ToArray() }; }
            var subs = new Submesh[mesh.subMeshCount];
            for (int i = 0; i < subs.Length; ++i)
            {
                var topology = mesh.GetTopology(i);
                if (topology != MeshTopology.Triangles) c.Unsupported("nontriangle-topology:" + key + ":" + i);
                subs[i] = new Submesh { topology = topology.ToString(), baseVertex = (int)mesh.GetBaseVertex(i), indices = mesh.GetIndices(i, false) };
            }
            return new MeshInput { vertices = mesh.vertices, normals = mesh.normals, tangents = mesh.tangents,
                colors = mesh.colors, uv = uv, submeshes = subs };
        }

        static MaterialInput Material(Material material, string key, MaterialPropertyBlock block, string scope, Context c)
        {
            if (!material || !material.shader) { c.Unsupported("missing-material:" + key); return new MaterialInput { key = key, properties = Array.Empty<Property>() }; }
            c.Object(material, "material-source"); c.Object(material.shader, "shader-source");
            var shader = material.shader;
            if (shader.name != "Universal Render Pipeline/Lit") c.Unsupported("unmodeled-shader:" + key + ":" + shader.name);
            var properties = new List<Property>();
            for (int i = 0; i < shader.GetPropertyCount(); ++i)
            {
                string name = shader.GetPropertyName(i), type = shader.GetPropertyType(i).ToString(); int id = Shader.PropertyToID(name);
                bool overridden = block != null && block.HasProperty(id);
                var p = new Property { name = name, type = type, flags = shader.GetPropertyFlags(i).ToString(), origin = overridden ? "property-block-" + scope : "material" };
                if (type == "Float" || type == "Range")
                {
                    if (overridden && !block.HasFloat(id)) c.Unsupported("property-block-type:" + key + ":" + name);
                    p.value = new[] { overridden ? block.GetFloat(id) : material.GetFloat(id) };
                }
                else if (type == "Color" || type == "Vector")
                {
                    if (overridden && !block.HasVector(id)) c.Unsupported("property-block-type:" + key + ":" + name);
                    p.value = overridden ? Vector(block.GetVector(id)) : type == "Color" ? Color(material.GetColor(id)) : Vector(material.GetVector(id));
                }
                else if (type == "Texture")
                {
                    if (overridden && !block.HasTexture(id)) c.Unsupported("property-block-type:" + key + ":" + name);
                    p.texture = Texture(overridden ? block.GetTexture(id) : material.GetTexture(id), key + ":" + name, c);
                    int st = Shader.PropertyToID(name + "_ST");
                    if (block != null && block.HasProperty(st))
                    {
                        if (!block.HasVector(st)) c.Unsupported("property-block-type:" + key + ":" + name + "_ST");
                        p.textureScaleOffset = Vector(block.GetVector(st));
                    }
                    else { var scale = material.GetTextureScale(name); var offset = material.GetTextureOffset(name); p.textureScaleOffset = new[] { scale.x, scale.y, offset.x, offset.y }; }
                }
                else { c.Unsupported("unmodeled-property-type:" + key + ":" + name + ":" + type); }
                properties.Add(p);
            }
            if (material.HasProperty("_Surface") && material.GetFloat("_Surface") != 0) c.Unsupported("transparent-lit:" + key);
            // Shader-declared properties are enumerated; arbitrary globals/procedural buffer reads are not inferred.
            var passes = new string[material.passCount]; var enabled = new bool[passes.Length];
            for (int i = 0; i < passes.Length; ++i) { passes[i] = material.GetPassName(i); enabled[i] = material.GetShaderPassEnabled(passes[i]); }
            return new MaterialInput { key = key, name = material.name, shader = shader.name, renderQueue = material.renderQueue,
                keywords = material.shaderKeywords.OrderBy(x => x, StringComparer.Ordinal).ToArray(), passes = passes, passEnabled = enabled,
                enableInstancing = material.enableInstancing, doubleSidedGI = material.doubleSidedGI,
                globalIlluminationFlags = material.globalIlluminationFlags.ToString(), propertyBlockScope = scope,
                properties = properties.OrderBy(p => p.name, StringComparer.Ordinal).ToArray() };
        }

        static TextureInput Texture(Texture texture, string key, Context c)
        {
            if (!texture) return null;
            c.Object(texture, "texture-source");
            var value = new TextureInput { name = texture.name, width = texture.width, height = texture.height,
                dimension = texture.dimension.ToString(), graphicsFormat = texture.graphicsFormat.ToString(), mipCount = texture.mipmapCount,
                filterMode = texture.filterMode.ToString(), wrapU = texture.wrapModeU.ToString(), wrapV = texture.wrapModeV.ToString(),
                wrapW = texture.wrapModeW.ToString(), mipMapBias = texture.mipMapBias, anisoLevel = texture.anisoLevel,
                isDataSRGB = texture.isDataSRGB };
            if (texture is Texture2D two && two.isReadable)
            {
                value.cpuReadable = true; byte[] bytes = two.GetRawTextureData();
                var asset = ArchiveBytes(c.directory, bytes, "texture-cpu-native-bytes"); c.assets[asset.path] = asset;
                value.rawFile = asset.path; value.rawSha256 = asset.sha256;
                // CPU bytes alone cannot certify arbitrary GPU/native writes. No unobserved producer is accepted.
                c.Unsupported("texture-gpu-content-not-observed:" + key);
            }
            else c.Unsupported("texture-pixels-unavailable:" + key);
            return value;
        }

        static LightInput Light(Light light, Context c)
        {
            string key = Key(light); c.Object(light, "light-source");
            if (light.type != LightType.Directional && light.type != LightType.Point && light.type != LightType.Spot) c.Unsupported("unmodeled-light-type:" + key);
            if (HybridLumenGILights.GetBakeType(light) != LightmapBakeType.Realtime) c.Unsupported("baked-or-mixed-light:" + key);
            var direction = -light.transform.forward;
            var additional = light.GetComponent<UniversalAdditionalLightData>(); c.Object(additional, "urp-light-data");
            // URP 17 creates this component on demand. Missing-component defaults are explicitly
            // defined by the archived UniversalAdditionalLightData source; do not mutate the light.
            var cookieSize = additional ? additional.lightCookieSize : Vector2.one;
            var cookieOffset = additional ? additional.lightCookieOffset : Vector2.zero;
            var extra = new AdditionalLightInput { usePipelineSettings = !additional || additional.usePipelineSettings,
                customShadowLayers = additional && additional.customShadowLayers, renderingLayers = additional ? additional.renderingLayers : 1u,
                shadowRenderingLayers = additional ? additional.shadowRenderingLayers : 1u,
                shadowResolutionTier = additional ? additional.additionalLightsShadowResolutionTier : UniversalAdditionalLightData.AdditionalLightsShadowDefaultResolutionTier,
                softShadowQuality = additional ? additional.softShadowQuality.ToString() : "UsePipelineSettings",
                cookieSize = new[] { cookieSize.x, cookieSize.y }, cookieOffset = new[] { cookieOffset.x, cookieOffset.y } };
            return new LightInput { key = key, name = light.name, type = light.type.ToString(), enabled = light.enabled,
                active = light.gameObject.activeInHierarchy, localToWorld = Matrix(light.transform.localToWorldMatrix), color = Color(light.color),
                toLight = new[] { direction.x, direction.y, direction.z }, intensity = light.intensity, range = light.range,
                spotAngle = light.spotAngle, innerSpotAngle = light.innerSpotAngle, useColorTemperature = light.useColorTemperature,
                colorTemperature = light.colorTemperature, bounceIntensity = light.bounceIntensity, cullingMask = light.cullingMask,
                renderingLayerMask = unchecked((uint)light.renderingLayerMask), shadows = light.shadows.ToString(), shadowStrength = light.shadowStrength,
                shadowBias = light.shadowBias, shadowNormalBias = light.shadowNormalBias, shadowNearPlane = light.shadowNearPlane,
                shadowResolution = light.shadowResolution.ToString(), shadowCustomResolution = light.shadowCustomResolution, additional = extra,
                bakeType = HybridLumenGILights.GetBakeType(light).ToString(), renderMode = light.renderMode.ToString(), cookieSize = light.cookieSize,
                cookie = Texture(light.cookie, key + ":cookie", c) };
        }

        static EnvironmentInput Environment(Context c, HybridLumenGIRendererFeature feature)
        {
            var probe = RenderSettings.ambientProbe; var sh = new float[27];
            for (int channel = 0; channel < 3; ++channel) for (int n = 0; n < 9; ++n) sh[channel * 9 + n] = probe[channel, n];
            var maps = LightmapSettings.lightmaps ?? Array.Empty<LightmapData>(); var inputs = new LightmapInput[maps.Length];
            for (int i = 0; i < maps.Length; ++i) inputs[i] = new LightmapInput { color = Texture(maps[i].lightmapColor, "lightmap-color:" + i, c),
                direction = Texture(maps[i].lightmapDir, "lightmap-direction:" + i, c), shadowMask = Texture(maps[i].shadowMask, "lightmap-shadowmask:" + i, c) };
            if (maps.Length != 0) c.Unsupported("baked-lightmap-decoding-not-implemented");
            var probes = LightmapSettings.lightProbes; c.Object(probes, "light-probe-source");
            if (probes && probes.count != 0) c.Unsupported("baked-light-probe-decoding-not-implemented");
            if (RenderSettings.skybox) c.Unsupported("skybox-shader-integration-not-implemented");
            if (RenderSettings.reflectionIntensity != 0) c.Unsupported("reflection-environment-integration-not-implemented");
            if (RenderSettings.fog) c.Unsupported("fog-integration-not-implemented");
            var field = typeof(HybridLumenGIRendererFeature).GetField("settings", System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance);
            var settings = feature && field != null ? field.GetValue(feature) as HybridLumenGIRendererFeature.Settings : null;
            if (settings == null) c.Unsupported("hlgi-environment-source-unavailable");
            return new EnvironmentInput { ambientMode = RenderSettings.ambientMode.ToString(), ambientLight = Color(RenderSettings.ambientLight),
                ambientSkyColor = Color(RenderSettings.ambientSkyColor), ambientEquatorColor = Color(RenderSettings.ambientEquatorColor),
                ambientGroundColor = Color(RenderSettings.ambientGroundColor), ambientIntensity = RenderSettings.ambientIntensity, ambientProbe = sh,
                defaultReflectionMode = RenderSettings.defaultReflectionMode.ToString(), reflectionIntensity = RenderSettings.reflectionIntensity,
                reflectionBounces = RenderSettings.reflectionBounces, defaultReflectionResolution = RenderSettings.defaultReflectionResolution,
                customReflection = Texture(RenderSettings.customReflectionTexture, "environment-reflection", c),
                skybox = RenderSettings.skybox ? Material(RenderSettings.skybox, "environment/skybox", null, "none", c) : null,
                fog = RenderSettings.fog, fogMode = RenderSettings.fogMode.ToString(), fogColor = Color(RenderSettings.fogColor),
                fogDensity = RenderSettings.fogDensity, fogStartDistance = RenderSettings.fogStartDistance, fogEndDistance = RenderSettings.fogEndDistance,
                lightmapsMode = LightmapSettings.lightmapsMode.ToString(), lightmaps = inputs, lightProbeCount = probes ? probes.count : 0,
                sunKey = RenderSettings.sun ? Key(RenderSettings.sun) : "",
                hlgiEnvironmentRadiance = settings != null ? Color(settings.environmentRadiance) : null,
                hlgiEnvironmentCubemap = settings != null ? Texture(settings.environmentCubemap, "hlgi-environment-cubemap", c) : null };
        }

        public static string SceneKey(Scene scene) => string.IsNullOrEmpty(scene.path) ? "unsaved:" + scene.name : scene.path.Replace('\\', '/');
        public static string Key(Component component)
        {
            var indices = new List<int>(); var node = component.transform;
            while (node) { indices.Add(node.GetSiblingIndex()); node = node.parent; }
            indices.Reverse(); var all = component.GetComponents<Component>(); int index = Array.IndexOf(all, component);
            return SceneKey(component.gameObject.scene) + "/hierarchy/" + string.Join("/", indices) + "/component/" + index;
        }
        public static float[] Matrix(Matrix4x4 m)
        { var result = new float[16]; for (int r = 0; r < 4; ++r) for (int c = 0; c < 4; ++c) result[r * 4 + c] = m[r, c]; Finite(result, 16, "matrix"); return result; }
        static float[] Vector(Vector4 value) => new[] { value.x, value.y, value.z, value.w };
        static float[] Color(Color value) => new[] { value.r, value.g, value.b, value.a };
        public static void Finite(float[] values, int length, string name)
        { if (values == null || values.Length != length || values.Any(v => float.IsNaN(v) || float.IsInfinity(v))) throw new InvalidDataException("Nonfinite or invalid " + name); }

        static void ValidateNumbers(object value)
        {
            // JsonUtility does not reject nonfinite numeric data; reject it before serializing a physical input.
            if (value == null || value is string || value is bool || value is Enum) return;
            if (value is float f) { if (float.IsNaN(f) || float.IsInfinity(f)) throw new InvalidDataException("Nonfinite source input."); return; }
            if (value is double d) { if (double.IsNaN(d) || double.IsInfinity(d)) throw new InvalidDataException("Nonfinite source input."); return; }
            if (value.GetType().IsPrimitive) return;
            if (value is System.Collections.IEnumerable items) { foreach (var item in items) ValidateNumbers(item); return; }
            foreach (var field in value.GetType().GetFields(System.Reflection.BindingFlags.Instance | System.Reflection.BindingFlags.Public)) ValidateNumbers(field.GetValue(value));
        }
        public static string Hash(byte[] bytes)
        { using (var sha = SHA256.Create()) return BitConverter.ToString(sha.ComputeHash(bytes)).Replace("-", "").ToLowerInvariant(); }
        public static string Resolve(string root, string relative)
        {
            if (string.IsNullOrEmpty(relative) || Path.IsPathRooted(relative) || relative.Contains("\\") || relative.Contains(":")) throw new InvalidDataException("Expected manifest-relative path.");
            string[] segments = relative.Split('/');
            if (segments.Any(x => x.Length == 0 || x == "." || x == "..")) throw new InvalidDataException("Unsafe source package path.");
            string basePath = Path.GetFullPath(root).TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
            string path = basePath;
            if ((Directory.Exists(basePath) || File.Exists(basePath)) && (File.GetAttributes(basePath) & FileAttributes.ReparsePoint) != 0)
                throw new InvalidDataException("Source package root is a reparse point.");
            foreach (string segment in segments)
            {
                path = Path.Combine(path, segment);
                if ((Directory.Exists(path) || File.Exists(path)) && (File.GetAttributes(path) & FileAttributes.ReparsePoint) != 0)
                    throw new InvalidDataException("Source package path contains a reparse point.");
            }
            return Path.GetFullPath(path);
        }
        public static HybridLumenGIValidationSourceState.FileLink WriteJson(string directory, string file, object value)
        {
            ValidateNumbers(value); byte[] bytes = new UTF8Encoding(false).GetBytes(JsonUtility.ToJson(value, true));
            WriteBytes(directory, file, bytes);
            return new HybridLumenGIValidationSourceState.FileLink { file = file, sha256 = Hash(bytes) };
        }
        static void WriteBytes(string root, string file, byte[] bytes)
        {
            string path = Resolve(root, file); Directory.CreateDirectory(Path.GetDirectoryName(path));
            if (File.Exists(path)) { if (!File.ReadAllBytes(path).SequenceEqual(bytes)) throw new IOException("Refusing to overwrite different source evidence: " + file); }
            else File.WriteAllBytes(path, bytes);
            if (Hash(File.ReadAllBytes(path)) != Hash(bytes)) throw new IOException("Source evidence readback differs: " + file);
        }
        public static Asset ArchiveBytes(string directory, byte[] bytes, string role)
        {
            string digest = Hash(bytes), path = "source-assets/" + digest + ".bin"; WriteBytes(directory, path, bytes);
            return new Asset { path = path, sha256 = digest, bytes = bytes.LongLength, role = role, roles = new[] { role } };
        }
        public static void CopyVerified(string sourceRoot, string destinationRoot, string file, string sha256)
        { byte[] bytes = File.ReadAllBytes(Resolve(sourceRoot, file)); if (Hash(bytes) != sha256) throw new InvalidDataException("Source byte hash differs: " + file); WriteBytes(destinationRoot, file, bytes); }
        public static ProvenanceDocument VerifyProvenance(string directory)
            => VerifyProvenance(directory, out _);
        public static ProvenanceDocument VerifyProvenance(string directory, out HybridLumenGIValidationSourceState.FileLink index)
        {
            const string file = "source-provenance.json";
            byte[] bytes = File.ReadAllBytes(Resolve(directory, file));
            var document = JsonUtility.FromJson<ProvenanceDocument>(Encoding.UTF8.GetString(bytes));
            if (document == null || document.artifacts == null) throw new InvalidDataException("Source-origin provenance index is required.");
            var paths = new HashSet<string>(StringComparer.OrdinalIgnoreCase) { file };
            foreach (var artifact in document.artifacts)
            {
                if (artifact == null || !paths.Add(artifact.file) || !IsHash(artifact.sha256) || string.IsNullOrWhiteSpace(artifact.role))
                    throw new InvalidDataException("Invalid/duplicate source-origin provenance artifact.");
                if (Hash(File.ReadAllBytes(Resolve(directory, artifact.file))) != artifact.sha256)
                    throw new InvalidDataException("Source-origin provenance bytes differ: " + artifact.file);
            }
            index = new HybridLumenGIValidationSourceState.FileLink { file = file, sha256 = Hash(bytes) };
            return document;
        }
        public static SourceDocument VerifyPackage(string directory, HybridLumenGIValidationSourceState.FileLink source)
        {
            if (source == null || !IsHash(source.sha256)) throw new InvalidDataException("A source file and SHA-256 are required.");
            byte[] bytes = File.ReadAllBytes(Resolve(directory, source.file));
            if (Hash(bytes) != source.sha256) throw new InvalidDataException("Source descriptor hash differs.");
            var doc = JsonUtility.FromJson<SourceDocument>(Encoding.UTF8.GetString(bytes));
            if (doc == null || doc.schema != "hlgi-validation-source-v2" || string.IsNullOrEmpty(doc.sceneId) ||
                doc.coordinateSystem != "Unity-left-handed-y-up" || doc.lengthUnit != "metre" || doc.geometry == null ||
                doc.materials == null || doc.lights == null || doc.environment == null || doc.rendering == null || doc.assets == null || doc.unsupported == null)
                throw new InvalidDataException("Invalid source descriptor.");
            var paths = new HashSet<string>(StringComparer.OrdinalIgnoreCase) { source.file };
            foreach (var asset in doc.assets)
            {
                if (asset == null || !paths.Add(asset.path) || !IsHash(asset.sha256) || string.IsNullOrEmpty(asset.role)) throw new InvalidDataException("Invalid or duplicate source asset.");
                byte[] actual = File.ReadAllBytes(Resolve(directory, asset.path));
                if (Hash(actual) != asset.sha256 || actual.LongLength != asset.bytes) throw new InvalidDataException("Source asset hash/length differs: " + asset.path);
            }
            ValidateNumbers(doc); return doc;
        }
        static bool IsHash(string value) => value != null && value.Length == 64 && value.All(c => c >= '0' && c <= '9' || c >= 'a' && c <= 'f');
    }
}
