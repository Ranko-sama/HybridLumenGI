using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using HybridLumenGI;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.SceneManagement;
using Object = UnityEngine.Object;

/// <summary>Creates a separate ordinary scene variant; never clears bindings in the authoring scene.</summary>
public static class HybridLumenGIUnifiedSampleBuilder
{
    public sealed class Result
    {
        public string ScenePath { get; internal set; }
        public HybridLumenGIAssetPageManifest Manifest { get; internal set; }
    }

    [MenuItem("Tools/Hybrid Lumen GI/Create Unified Sample From Selected Static Proxies")]
    private static void Menu()
    {
        var proxies = Selection.gameObjects.SelectMany(go => go.GetComponentsInChildren<HybridLumenGIProxy>(true)).Distinct().ToArray();
        if (proxies.Length < 2) throw new InvalidOperationException("Select at least two static detail proxies in the saved authoring scene (for example its three receivers).");
        var scene = proxies[0].gameObject.scene;
        Camera[] cameras = scene.GetRootGameObjects().SelectMany(go => go.GetComponentsInChildren<Camera>(true)).Where(c => c.enabled).ToArray();
        if (cameras.Length != 1) throw new InvalidOperationException("The menu requires one enabled camera. Use CreateVariant with explicit inputs otherwise.");
        var feature = CameraFeature(cameras[0]);
        string run = Guid.NewGuid().ToString("N");
        Result result = CreateVariant(scene, cameras[0], feature, proxies,
            "Assets/HybridLumenGIUnifiedSample/" + run, "Assets/StreamingAssets/HybridLumenGIUnifiedSample/" + run);
        Debug.Log("Unified sample saved: " + result.ScenePath + ". Open it separately; authoring bindings were retained.", result.Manifest);
    }

    private static HybridLumenGIRendererFeature CameraFeature(Camera camera)
    {
        var pipeline = GraphicsSettings.currentRenderPipeline as UniversalRenderPipelineAsset;
        if (pipeline == null) throw new InvalidOperationException("The camera requires an active URP pipeline.");
        // Read authored selection without creating a runtime renderer. Unrelated loaded
        // Renderer Data assets must not affect this camera's feature selection.
        using var pipelineState = new SerializedObject(pipeline);
        var renderers = pipelineState.FindProperty("m_RendererDataList");
        int defaultIndex = pipelineState.FindProperty("m_DefaultRendererIndex").intValue;
        int index = -1;
        if (camera.TryGetComponent<UniversalAdditionalCameraData>(out var cameraData))
        {
            using var cameraState = new SerializedObject(cameraData);
            index = cameraState.FindProperty("m_RendererIndex").intValue;
        }
        // URP uses the default for the default sentinel or a missing selected Data.
        if (index < 0 || index >= renderers.arraySize || renderers.GetArrayElementAtIndex(index).objectReferenceValue == null)
            index = defaultIndex;
        if (index < 0 || index >= renderers.arraySize ||
            !(renderers.GetArrayElementAtIndex(index).objectReferenceValue is UniversalRendererData renderer))
            throw new InvalidOperationException("The camera requires valid Universal Renderer Data.");
        var features = renderer.rendererFeatures.OfType<HybridLumenGIRendererFeature>()
            .Where(f => f != null && f.isActive && EditorUtility.IsPersistent(f)).ToArray();
        if (features.Length != 1)
            throw new InvalidOperationException("The camera's Renderer Data must contain exactly one active GI feature. Use CreateVariant with explicit inputs otherwise.");
        return features[0];
    }

    public static Result CreateVariant(Scene authoring, Camera camera, HybridLumenGIRendererFeature feature,
        IReadOnlyList<HybridLumenGIProxy> detailSources, string assetDirectory, string bundleOutputDirectory)
    {
        if (Application.isPlaying) throw new InvalidOperationException("Generate the sample outside Play mode.");
        if (!authoring.IsValid() || !authoring.isLoaded || string.IsNullOrEmpty(authoring.path) || authoring.isDirty)
            throw new InvalidOperationException("The authoring scene must be saved, loaded and clean.");
        if (SceneManager.GetActiveScene() != authoring) throw new InvalidOperationException("Make the authoring scene active before exporting its physical settings.");
        if (camera == null || camera.gameObject.scene != authoring || feature == null || !feature.isActive || detailSources == null || detailSources.Count < 2)
            throw new ArgumentException("Explicit authoring camera, GI feature and at least two static details are required.");
        string assetFull = NewDirectory(assetDirectory, "Assets/"), bundleFull = NewDirectory(bundleOutputDirectory, "Assets/StreamingAssets/");
        if (Within(assetFull, bundleFull) || Within(bundleFull, assetFull)) throw new ArgumentException("Output directories overlap.");
        var originals = detailSources.ToArray();
        if (originals.Distinct().Count() != originals.Length) throw new ArgumentException("Duplicate detail proxy.");
        foreach (var proxy in originals) ValidateDetail(proxy, authoring, originals[0]);
        var featureState = new SerializedObject(feature);
        float near = featureState.FindProperty("settings.nearDistance").floatValue;
        float far = featureState.FindProperty("settings.farDistance").floatValue;
        if (far <= near * 1.5f + 5f) throw new InvalidOperationException("The sample requires room between near and far GI residency distances.");
        Bounds authoredBounds = originals[0].SourceRenderer.bounds;
        foreach (var source in originals) authoredBounds.Encapsulate(source.SourceRenderer.bounds);
        if (authoredBounds.SqrDistance(camera.transform.position) >= near * near * .64f)
            throw new InvalidOperationException("Place the authoring camera inside 80% of the GI near distance for the sample's Near view.");
        int[] cameraAddress = Address(camera.transform);
        int[][] detailAddresses = originals.Select(p => Address(p.transform)).ToArray();
        string scenePath = assetDirectory + "/UnifiedSample.unity";
        Scene previous = SceneManager.GetActiveScene(), variant = default;
        Directory.CreateDirectory(assetDirectory); AssetDatabase.Refresh();
        try
        {
            if (!EditorSceneManager.SaveScene(authoring, scenePath, true)) throw new IOException("Could not save an independent scene copy.");
            variant = EditorSceneManager.OpenScene(scenePath, OpenSceneMode.Additive);
            SceneManager.SetActiveScene(variant);
            var target = Resolve(variant, cameraAddress).GetComponent<Camera>();
            var details = detailAddresses.Select(p => Resolve(variant, p).GetComponent<HybridLumenGIProxy>()).ToArray();
            // This is the same scene at rest. The finite-validation camera/light driver must not own it in ordinary use.
            foreach (var root in variant.GetRootGameObjects())
            {
                foreach (var sequence in root.GetComponentsInChildren<HybridLumenGIValidationSequence>(true)) sequence.enabled = false;
                foreach (var motion in root.GetComponentsInChildren<HybridLumenGIValidationMotion>(true)) motion.enabled = false;
            }
            var aggregate = CreateAggregate(details, assetDirectory);
            foreach (var detail in details) detail.SetHLODParent(aggregate);
            var allSources = details.Concat(new[] { aggregate }).ToArray();
            var export = HybridLumenGIAssetPageBuilder.Export(allSources, assetDirectory + "/Pages", bundleOutputDirectory);
            var bindings = export.Rig.GetComponentsInChildren<HybridLumenGIStreamedRepresentation>(true);
            var aggregateBinding = bindings.Single(b => b.Proxy.HLODParent == null);
            var detailBindings = bindings.Where(b => b.Proxy.HLODParent == aggregateBinding.Proxy).ToArray();
            if (detailBindings.Length != details.Length) throw new InvalidOperationException("Export did not preserve the complete authored group.");
            Bounds bounds = aggregate.SourceRenderer.bounds;
            foreach (var source in allSources) ClearVariantSource(source);
            var driver = export.Rig.GetComponent<HybridLumenGIAssetPageStreamer>();
            var controllerObject = new GameObject("Hybrid GI unified sample controls");
            var controller = controllerObject.AddComponent<HybridLumenGIUnifiedSample>();
            controller.Configure(target, feature, driver, aggregateBinding, detailBindings, bounds, near, far);
            AddOrdinaryInteraction(variant, target, controller);
            // The saved variant starts with empty bindings. Only the manifest contains page descriptions, not source assets.
            export.Rig.SetActive(true); target.enabled = true;
            foreach (var binding in bindings)
                if (binding.Proxy.SourceMesh != null || binding.SourceRenderer.sharedMaterials.Length != 0 || binding.Proxy.MeshSdf != null || binding.Proxy.SurfaceCharts != null)
                    throw new InvalidOperationException("Destination unexpectedly retains a source asset.");
            if (!EditorSceneManager.SaveScene(variant, scenePath)) throw new IOException("Could not save the configured variant.");
            AssetDatabase.SaveAssets();
            return new Result { ScenePath = scenePath, Manifest = export.Manifest };
        }
        finally
        {
            EditorUtility.ClearProgressBar();
            if (variant.IsValid() && variant.isLoaded) EditorSceneManager.CloseScene(variant, true);
            if (previous.IsValid() && previous.isLoaded) SceneManager.SetActiveScene(previous);
            // New owned paths are retained on failure for inspection. Never delete/overwrite authoring assets.
        }
    }

    private static void AddOrdinaryInteraction(Scene variant, Camera camera, HybridLumenGIUnifiedSample controller)
    {
        // Navigation works for every generated sample. Optional event controls use only the
        // existing standard validation driver's references, never arbitrary scene discovery.
        var sequences = variant.GetRootGameObjects()
            .SelectMany(root => root.GetComponentsInChildren<HybridLumenGIValidationSequence>(true)).ToArray();
        HybridLumenGIValidationMotion door = null;
        Renderer wall = null;
        Light[] lights = Array.Empty<Light>();
        if (sequences.Length == 1)
        {
            var source = new SerializedObject(sequences[0]);
            door = source.FindProperty("door").objectReferenceValue as HybridLumenGIValidationMotion;
            var lightArray = source.FindProperty("switchedLights");
            lights = new Light[lightArray.arraySize];
            for (int i = 0; i < lights.Length; i++) lights[i] = lightArray.GetArrayElementAtIndex(i).objectReferenceValue as Light;
            var walls = sequences[0].GetComponentsInChildren<Renderer>(true)
                .Where(renderer => renderer.name == "Red wall" && renderer.sharedMaterials.Length > 0).ToArray();
            if (walls.Length == 1) wall = walls[0]; // Selected/streamed source shells have no materials and stay unbound.
        }
        controller.gameObject.AddComponent<HybridLumenGIUnifiedSampleInteraction>().Configure(camera, controller, door, wall, lights);
    }

    private static void ValidateDetail(HybridLumenGIProxy proxy, Scene scene, HybridLumenGIProxy policy)
    {
        if (proxy == null || proxy.gameObject.scene != scene || !proxy.isActiveAndEnabled || proxy.HLODParent != null || proxy.FarFieldOnly)
            throw new InvalidOperationException("Details must be enabled, ungrouped proxies in the authoring scene.");
        var renderer = proxy.SourceRenderer as MeshRenderer; Mesh mesh = proxy.SourceMesh;
        if (renderer == null || renderer.gameObject != proxy.gameObject || !renderer.enabled || mesh == null || !mesh.isReadable || mesh.subMeshCount != renderer.sharedMaterials.Length)
            throw new InvalidOperationException("A detail needs a readable static mesh, matching material slots and a same-object MeshRenderer.");
        if (renderer.HasPropertyBlock() || renderer.lightmapIndex >= 0 || renderer.realtimeLightmapIndex >= 0 || renderer.localToWorldMatrix.determinant <= 0f)
            throw new InvalidOperationException("This sample aggregate does not support MPBs, baked lightmaps or mirrored/singular transforms.");
        if (PrefabUtility.IsPartOfPrefabInstance(proxy.gameObject) || proxy.GetComponents<Component>().Any(c =>
            !(c is Transform || c is MeshFilter || c is MeshRenderer || c is HybridLumenGIProxy || c is Collider)))
            throw new InvalidOperationException("Selected sources must be plain authored mesh/proxy/collider objects, without prefab or custom-component asset bindings.");
        for (Transform node = proxy.transform; node != null; node = node.parent)
            if (node.GetComponent<Animator>() != null || node.GetComponent<Animation>() != null || node.GetComponent<HybridLumenGIValidationMotion>() != null)
                throw new InvalidOperationException("Selected details must have static transform ancestry.");
        for (int i = 0; i < mesh.subMeshCount; i++)
            if (mesh.GetTopology(i) != MeshTopology.Triangles || renderer.sharedMaterials[i] == null || renderer.sharedMaterials[i].shader == null || renderer.sharedMaterials[i].shader.name != "Universal Render Pipeline/Lit")
                throw new InvalidOperationException("This sample aggregate supports triangle submeshes with URP Lit materials.");
        if (proxy.MeshSdf == null || proxy.SurfaceCharts == null || !proxy.SurfaceCharts.IsValid)
            throw new InvalidOperationException("Bake and bind the selected source SDF and surface charts first.");
        var reference = policy.SourceRenderer;
        if (proxy.gameObject.layer != policy.gameObject.layer || renderer.renderingLayerMask != reference.renderingLayerMask || renderer.shadowCastingMode != reference.shadowCastingMode ||
            renderer.receiveShadows != reference.receiveShadows || proxy.AlbedoTint != policy.AlbedoTint || proxy.EmissionOverride != policy.EmissionOverride ||
            proxy.EmissionIntensity != policy.EmissionIntensity || proxy.Roughness != policy.Roughness)
            throw new InvalidOperationException("Selected details need matching object lighting and proxy policies.");
        var proxyFields = new SerializedObject(proxy); var policyFields = new SerializedObject(policy);
        if (proxyFields.FindProperty("readMaterialProperties").boolValue != policyFields.FindProperty("readMaterialProperties").boolValue ||
            proxyFields.FindProperty("shape").intValue != policyFields.FindProperty("shape").intValue)
            throw new InvalidOperationException("Selected proxy policies differ.");
        if ((LightmapSettings.lightProbes != null && LightmapSettings.lightProbes.count != 0) ||
            scene.GetRootGameObjects().SelectMany(go => go.GetComponentsInChildren<ReflectionProbe>(true)).Any(p => p.isActiveAndEnabled) ||
            RenderSettings.reflectionIntensity != 0f)
            throw new InvalidOperationException("This exact geometry aggregation sample requires no baked light probes, active reflection probes or environment reflection.");
    }
    private static HybridLumenGIProxy CreateAggregate(HybridLumenGIProxy[] details, string directory)
    {
        var combines = new List<CombineInstance>(); var materials = new List<Material>();
        foreach (var detail in details)
            for (int sub = 0; sub < detail.SourceMesh.subMeshCount; sub++)
            {
                combines.Add(new CombineInstance { mesh = detail.SourceMesh, subMeshIndex = sub, transform = detail.SourceRenderer.localToWorldMatrix });
                materials.Add(detail.SourceRenderer.sharedMaterials[sub]);
            }
        var mesh = new Mesh { name = "Unified exact aggregate", indexFormat = IndexFormat.UInt32 };
        mesh.CombineMeshes(combines.ToArray(), false, true, false); mesh.RecalculateBounds();
        AssetDatabase.CreateAsset(mesh, directory + "/AggregateMesh.asset");
        var go = new GameObject("Unified exact aggregate source"); go.layer = details[0].gameObject.layer;
        go.AddComponent<MeshFilter>().sharedMesh = mesh;
        var renderer = go.AddComponent<MeshRenderer>(); var original = details[0].SourceRenderer;
        renderer.sharedMaterials = materials.ToArray(); renderer.renderingLayerMask = original.renderingLayerMask;
        renderer.shadowCastingMode = original.shadowCastingMode; renderer.receiveShadows = original.receiveShadows;
        // ValidateDetail excluded effective probe lighting; retain the authored renderer policy.
        renderer.lightProbeUsage = original.lightProbeUsage; renderer.reflectionProbeUsage = original.reflectionProbeUsage;
        renderer.motionVectorGenerationMode = original.motionVectorGenerationMode;
        var proxy = go.AddComponent<HybridLumenGIProxy>(); EditorUtility.CopySerialized(details[0], proxy);
        proxy.SetSources(renderer, null); proxy.SetHLODParent(null);
        var fields = new SerializedObject(proxy); fields.FindProperty("farFieldOnly").boolValue = true; fields.ApplyModifiedPropertiesWithoutUndo();
        BakeAggregate(proxy, mesh, directory);
        return proxy;
    }
    private static void BakeAggregate(HybridLumenGIProxy proxy, Mesh mesh, string directory)
    {
        const int resolution = 32;
        Texture3D texture = null; Mesh capture = null;
        HybridLumenGIMeshSdf sdf = null; HybridLumenGISurfaceCharts charts = null;
        try
        {
            float[] data = HybridLumenGIMeshSdfBaker.Bake(mesh, resolution, (done, total) =>
                Application.isBatchMode || !EditorUtility.DisplayCancelableProgressBar("Unified aggregate SDF", mesh.name, (float)done / Mathf.Max(1, total)), out Bounds bounds, out bool closed);
            if (data == null) throw new OperationCanceledException();
            var baked = HybridLumenGISurfaceCharts.Bake(mesh, new HybridLumenGISurfaceCharts.BakeSettings(), out var report);
            if (baked.Length == 0 || report.nonTriangleSubmeshes != 0) throw new InvalidOperationException("Incomplete aggregate chart surface.");
            capture = HybridLumenGISurfaceCharts.CreateCaptureMesh(mesh, baked);
            texture = new Texture3D(resolution, resolution, resolution, TextureFormat.RFloat, false)
            { name = mesh.name + " Distance", wrapMode = TextureWrapMode.Clamp, filterMode = FilterMode.Bilinear };
            texture.SetPixelData(data, 0); texture.Apply(false, false);
            sdf = ScriptableObject.CreateInstance<HybridLumenGIMeshSdf>();
            sdf.SetBakedData(mesh, texture, bounds, resolution, closed, HybridLumenGIMeshSdf.ComputeGeometryFingerprint(mesh));
            charts = ScriptableObject.CreateInstance<HybridLumenGISurfaceCharts>(); charts.SetBakedData(mesh, capture, baked);
            AssetDatabase.CreateAsset(sdf, directory + "/AggregateSDF.asset"); AssetDatabase.AddObjectToAsset(texture, sdf);
            AssetDatabase.CreateAsset(charts, directory + "/AggregateCharts.asset"); AssetDatabase.AddObjectToAsset(capture, charts);
            proxy.SetMeshSdf(sdf); proxy.SetSurfaceCharts(charts);
        }
        finally
        {
            foreach (Object value in new Object[] { texture, capture, sdf, charts })
                if (value != null && !EditorUtility.IsPersistent(value)) Object.DestroyImmediate(value);
        }
    }
    private static void ClearVariantSource(HybridLumenGIProxy proxy)
    {
        var renderer = (MeshRenderer)proxy.SourceRenderer;
        proxy.enabled = false; proxy.SetHLODParent(null); proxy.SetMeshSdf(null); proxy.SetSurfaceCharts(null); proxy.SetSources(null, null);
        renderer.enabled = false; renderer.forceRenderingOff = true; renderer.sharedMaterials = Array.Empty<Material>();
        renderer.GetComponent<MeshFilter>().sharedMesh = null;
        foreach (var collider in renderer.GetComponents<MeshCollider>()) collider.sharedMesh = null;
    }
    private static int[] Address(Transform transform)
    {
        var result = new List<int>(); for (var node = transform; node != null; node = node.parent) result.Add(node.GetSiblingIndex());
        result.Reverse(); return result.ToArray();
    }
    private static Transform Resolve(Scene scene, int[] address)
    {
        Transform result = scene.GetRootGameObjects()[address[0]].transform;
        for (int i = 1; i < address.Length; i++) result = result.GetChild(address[i]);
        return result;
    }
    private static bool Within(string child, string parent) => child.Equals(parent, StringComparison.OrdinalIgnoreCase) || child.StartsWith(parent + Path.DirectorySeparatorChar, StringComparison.OrdinalIgnoreCase);
    private static string NewDirectory(string path, string prefix)
    {
        if (string.IsNullOrEmpty(path) || !path.StartsWith(prefix, StringComparison.Ordinal) || path.IndexOf('\\') >= 0) throw new ArgumentException("Expected new " + prefix + "... output.");
        string project = Path.GetFullPath(Path.Combine(Application.dataPath, ".."));
        if (!Path.GetFullPath(".").Equals(project, StringComparison.OrdinalIgnoreCase)) throw new InvalidOperationException("Unity project working directory required.");
        string current = project;
        foreach (string part in path.Split('/'))
        {
            if (part.Length == 0 || part == "." || part == ".." || part.IndexOf(':') >= 0 || part.IndexOfAny(Path.GetInvalidFileNameChars()) >= 0 || part.EndsWith(".", StringComparison.Ordinal) || part.EndsWith(" ", StringComparison.Ordinal))
                throw new ArgumentException("Invalid output path segment.");
            current = Path.Combine(current, part);
            if (File.Exists(current) || (!Directory.Exists(current) && File.Exists(current + ".meta")) ||
                (Directory.Exists(current) && (File.GetAttributes(current) & FileAttributes.ReparsePoint) != 0)) throw new IOException("Output ancestor is not safe: " + current);
        }
        if (Directory.Exists(current) || File.Exists(current + ".meta") || AssetDatabase.LoadMainAssetAtPath(path) != null) throw new IOException("Output already exists: " + path);
        return current;
    }
}
