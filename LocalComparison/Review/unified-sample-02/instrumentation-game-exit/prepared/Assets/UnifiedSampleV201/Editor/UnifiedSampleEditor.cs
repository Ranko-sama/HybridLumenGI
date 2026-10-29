#if UNITY_EDITOR
using System;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Security.Cryptography;
using HybridLumenGI;
using HybridLumenGI.Editor;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.SceneManagement;

[InitializeOnLoad]
public static class UnifiedSampleEditor
{
    private const string Root = "Assets/UnifiedSampleV201", Generated = Root + "/Generated", Key = "UnifiedSampleV201.";
    private const string Bundles = "Assets/StreamingAssets/UnifiedSampleV201";
    [Serializable] private sealed class RestoreState { public SceneSetup[] scenes; public string qualityPipeline; public bool qualityWasNull, empty; }
    [Serializable] private sealed class Result { public string status, error, scene; public bool restored; }
    [Serializable] private sealed class HostReceipt { public string status, error; public int renderedFrames, completedStages; public bool readbacksDrained; }
    [Serializable] private sealed class AuthoringReceipt
    {
        public string sourceScene, variantScene, sourceBeforeSha256, sourceAfterSha256, bundleDirectory;
        public bool sourceUnchanged, emptyDestinations;
        public int detailMembers, aggregateMembers;
    }
    static UnifiedSampleEditor() { EditorApplication.playModeStateChanged += StateChanged; }
    private static void Require(bool value, string reason) { if (!value) throw new InvalidOperationException(reason); }
    private static string Sha(string path)
    { using (var hash = SHA256.Create()) return BitConverter.ToString(hash.ComputeHash(File.ReadAllBytes(path))).Replace("-", "").ToLowerInvariant(); }
    private static void StateChanged(PlayModeStateChange state)
    { if (state == PlayModeStateChange.EnteredEditMode && SessionState.GetBool(Key + "active", false)) EditorApplication.delayCall += Complete; }
    private static void Restore()
    {
        var saved = JsonUtility.FromJson<RestoreState>(SessionState.GetString(Key + "restore", ""));
        QualitySettings.renderPipeline = saved.qualityWasNull ? null : AssetDatabase.LoadAssetAtPath<RenderPipelineAsset>(saved.qualityPipeline);
        Require(saved.qualityWasNull || QualitySettings.renderPipeline != null, "Original quality pipeline unavailable.");
        if (saved.empty) EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);
        else EditorSceneManager.RestoreSceneManagerSetup(saved.scenes);
    }
    private static void Complete()
    {
        string output = SessionState.GetString(Key + "output", "");
        var result = new Result { status = "failed", scene = SessionState.GetString(Key + "scene", "") };
        try
        {
            var host = JsonUtility.FromJson<HostReceipt>(File.ReadAllText(Path.Combine(output, "host-result.json")));
            Require(host.status == "collected" && host.readbacksDrained && host.completedStages == 7 && host.renderedFrames <= 1200,
                "Incomplete unified sample: " + host.error);
            result.status = "collected";
        }
        catch (Exception error) { result.error = error.ToString(); }
        finally
        {
            try { Restore(); result.restored = true; }
            catch (Exception error) { result.status = "failed"; result.error += "\nRestore: " + error; }
            SessionState.SetBool(Key + "active", false);
            File.WriteAllText(Path.Combine(output, "editor-result.json"), JsonUtility.ToJson(result, true));
        }
        EditorApplication.Exit(result.status == "collected" && result.restored ? 0 : 1);
    }
    public static void Run()
    {
        string[] args = Environment.GetCommandLineArgs(); int at = Array.IndexOf(args, "-unifiedSampleOutput");
        Require(at >= 0 && at + 1 < args.Length, "Pass a fresh absolute -unifiedSampleOutput directory.");
        string output = args[at + 1];
        Require(Path.IsPathRooted(output) && !Directory.Exists(output) && !File.Exists(output), "Preserve existing output.");
        Require(!EditorApplication.isPlayingOrWillChangePlaymode && !SessionState.GetBool(Key + "active", false), "Editor already running.");
        Require(!Directory.Exists(Generated) && !Directory.Exists(Bundles) && SystemInfo.graphicsDeviceType == GraphicsDeviceType.Direct3D12 &&
            QualitySettings.activeColorSpace == ColorSpace.Linear, "Fresh owned roots and existing Linear DX12 project required.");
        var original = GraphicsSettings.currentRenderPipeline as UniversalRenderPipelineAsset;
        Require(original != null, "Existing URP pipeline required.");
        var setup = EditorSceneManager.GetSceneManagerSetup(); bool empty = setup.Length == 0;
        for (int i = 0; i < SceneManager.sceneCount; i++)
        {
            var loaded = SceneManager.GetSceneAt(i);
            Require(!loaded.isDirty, "Preserve an unsaved scene before batch validation.");
            if (string.IsNullOrEmpty(loaded.path))
            { Require(SceneManager.sceneCount == 1 && loaded.rootCount == 0, "Only a single unnamed empty scene is supported."); empty = true; }
        }
        string qualityPath = AssetDatabase.GetAssetPath(QualitySettings.renderPipeline);
        Require(QualitySettings.renderPipeline == null || !string.IsNullOrEmpty(qualityPath), "Quality pipeline must have a restorable asset path.");
        Directory.CreateDirectory(output);
        SessionState.SetString(Key + "output", output);
        SessionState.SetString(Key + "restore", JsonUtility.ToJson(new RestoreState { scenes = setup, empty = empty,
            qualityWasNull = QualitySettings.renderPipeline == null, qualityPipeline = qualityPath }));
        try
        {
            AssetDatabase.CreateFolder(Root, "Generated");
            var sourceSettings = new SerializedObject(original);
            int index = sourceSettings.FindProperty("m_DefaultRendererIndex").intValue;
            var sourceRenderer = sourceSettings.FindProperty("m_RendererDataList").GetArrayElementAtIndex(index).objectReferenceValue as UniversalRendererData;
            Require(sourceRenderer != null, "Universal renderer required.");
            var renderer = UnityEngine.Object.Instantiate(sourceRenderer); renderer.name = "UnifiedSampleRenderer";
            renderer.rendererFeatures.Clear(); renderer.renderingMode = RenderingMode.Forward;
            AssetDatabase.CreateAsset(renderer, Generated + "/Renderer.asset");
            var feature = ScriptableObject.CreateInstance<HybridLumenGIRendererFeature>(); feature.name = "UnifiedSampleGI";
            var settings = new HybridLumenGIRendererFeature.Settings
            {
                // Keep 120 original scene cards while the 18-card aggregate warms.
                resolutionScale = .5f, raysPerPixel = 1, residentProxies = 64, residentSurfaceCards = 192,
                surfaceTileResolution = 32, maxLights = 8, nearDistance = 12, farDistance = 40,
                preferHardwareTracing = false, exactSoftwareTracing = true,
                receiverSourceTracking = true, receiverObjectHistory = true, environmentRadiance = Color.black,
                environmentCubemap = null, measureGpuCost = false, adaptiveGpuBudget = false,
                debugView = HybridLumenGIRendererFeature.DebugView.Final, composition = HybridLumenGIRendererFeature.CompositionMode.Additive
            };
            typeof(HybridLumenGIRendererFeature).GetField("settings", BindingFlags.Instance | BindingFlags.NonPublic).SetValue(feature, settings);
            AssetDatabase.AddObjectToAsset(feature, renderer); renderer.rendererFeatures.Add(feature); feature.SetActive(true);
            EditorUtility.SetDirty(feature); EditorUtility.SetDirty(renderer);
            var pipeline = UnityEngine.Object.Instantiate(original); pipeline.name = "UnifiedSamplePipeline";
            pipeline.msaaSampleCount = 1; pipeline.renderScale = 1;
            AssetDatabase.CreateAsset(pipeline, Generated + "/Pipeline.asset");
            var serialized = new SerializedObject(pipeline); var list = serialized.FindProperty("m_RendererDataList");
            list.arraySize = 1; list.GetArrayElementAtIndex(0).objectReferenceValue = renderer;
            serialized.FindProperty("m_DefaultRendererIndex").intValue = 0; serialized.ApplyModifiedPropertiesWithoutUndo();
            QualitySettings.renderPipeline = pipeline;
            string authoringPath = HybridLumenGIValidationScene.CreateSceneAssets(Generated + "/Scenes");
            Require(!string.IsNullOrEmpty(authoringPath), "Validation generation cancelled.");
            var authoring = EditorSceneManager.OpenScene(authoringPath, OpenSceneMode.Single);
            var sequence = UnityEngine.Object.FindFirstObjectByType<HybridLumenGIValidationSequence>();
            Require(sequence != null, "Generated sequence missing.");
            var sequenceSettings = new SerializedObject(sequence);
            var camera = sequenceSettings.FindProperty("targetCamera").objectReferenceValue as Camera;
            sequenceSettings.FindProperty("feature").objectReferenceValue = feature;
            sequenceSettings.ApplyModifiedPropertiesWithoutUndo();
            Require(camera != null, "Generated camera missing.");
            Require(EditorSceneManager.SaveScene(authoring), "Could not save authoring configuration."); AssetDatabase.SaveAssets();
            string before = Sha(authoringPath);
            string[] names = { "White receiver", "Metal zero diffuse receiver", "Black zero diffuse receiver" };
            var sources = authoring.GetRootGameObjects().SelectMany(go => go.GetComponentsInChildren<HybridLumenGIProxy>(true))
                .Where(p => names.Contains(p.name)).ToArray();
            Require(sources.Length == 3, "Exactly three existing receiver details required.");
            var variant = HybridLumenGIUnifiedSampleBuilder.CreateVariant(authoring, camera, feature, sources, Generated + "/Variant", Bundles);
            string after = Sha(authoringPath); Require(before == after, "Authoring scene bytes changed while creating variant.");
            var scene = EditorSceneManager.OpenScene(variant.ScenePath, OpenSceneMode.Single);
            var controller = UnityEngine.Object.FindFirstObjectByType<HybridLumenGIUnifiedSample>();
            var driver = UnityEngine.Object.FindFirstObjectByType<HybridLumenGIAssetPageStreamer>();
            var bindings = UnityEngine.Object.FindObjectsByType<HybridLumenGIStreamedRepresentation>(FindObjectsSortMode.None);
            Require(controller != null && driver != null && bindings.Length == 4, "Complete sample control/page binding set required.");
            camera = UnityEngine.Object.FindObjectsByType<Camera>(FindObjectsSortMode.None).Single(c => c.name == "Validation Camera");
            bool emptyBindings = bindings.All(b => !b.HasBoundAssets && b.Proxy.SourceMesh == null && b.SourceRenderer.sharedMaterials.Length == 0 &&
                b.Proxy.MeshSdf == null && b.Proxy.SurfaceCharts == null);
            Require(emptyBindings, "Sample must begin with empty streamed source bindings."); camera.enabled = false;
            var host = new GameObject("Unified sample batch driver").AddComponent<UnifiedSampleHost>();
            host.Configure(camera, controller, feature, driver, bindings, output);
            EditorSceneManager.MarkSceneDirty(scene); Require(EditorSceneManager.SaveScene(scene), "Could not save sample driver.");
            AssetDatabase.SaveAssets(); AssetDatabase.Refresh(ImportAssetOptions.ForceSynchronousImport);
            File.WriteAllText(Path.Combine(output, "authoring-result.json"), JsonUtility.ToJson(new AuthoringReceipt
            { sourceScene = authoringPath, variantScene = variant.ScenePath, sourceBeforeSha256 = before, sourceAfterSha256 = after,
                sourceUnchanged = true, emptyDestinations = emptyBindings, detailMembers = 3, aggregateMembers = 1, bundleDirectory = Bundles }, true));
            SessionState.SetString(Key + "scene", variant.ScenePath); SessionState.SetBool(Key + "active", true); EditorApplication.isPlaying = true;
        }
        catch (Exception error)
        {
            var result = new Result { status = "failed", error = error.ToString() };
            try { Restore(); result.restored = true; } catch (Exception restore) { result.error += "\nRestore: " + restore; }
            SessionState.SetBool(Key + "active", false);
            File.WriteAllText(Path.Combine(output, "editor-result.json"), JsonUtility.ToJson(result, true)); EditorApplication.Exit(1);
        }
    }
}
#endif
