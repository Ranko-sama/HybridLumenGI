#if UNITY_EDITOR
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Security.Cryptography;
using System.Text.RegularExpressions;
using HybridLumenGI;
using HybridLumenGI.Editor;
using UnityEditor;
using UnityEditor.Build;
using UnityEditor.Build.Reporting;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.SceneManagement;

/// <summary>Release-only build of the existing unified sample in fresh, owned asset folders.</summary>
public static class UnifiedSampleReleaseBuild
{
    private const string Root = "Assets/UnifiedRelease74", Generated = Root + "/Generated";
    private const string Bundles = "Assets/StreamingAssets/UnifiedRelease74";
    [Serializable] private sealed class Input { public string path, sha256; public long bytes; }
    [Serializable] private sealed class Receipt
    {
        public string result = "started", error, restoreError, unity, output, scene, authoringScene;
        public string configuration = "Release", requestedOptions = "None", actualOptions;
        public string pipeline, renderer, manifest, bundleDirectory = Bundles, executableSha256;
        public string sourceBeforeSha256, sourceAfterSha256;
        public string inputScope = "Actual scene/pipeline dependencies, generated pages and all StreamingAssets, product/harness sources and project settings. Build provenance, not a physical reference.";
        public string interactionScope = "Ordinary enabled camera and interaction; finite Host disabled unless explicitly launched with -unifiedSampleVerify.";
        public string qualityName, colorSpace, scriptingBackend;
        public string[] graphicsApis, dependencyRoots, dependenciesWithoutProjectFile;
        public int qualityIndex, errors, warnings, detailMembers, aggregateMembers;
        public ulong totalBytes;
        public bool sourceUnchanged, emptyDestinations, inputsUnchanged, ordinaryCameraEnabled, verificationHostDisabled, restored;
        public HybridLumenGIRendererFeature.Settings featureSettings;
        public Input[] inputs, products;
    }
    private static void Require(bool value, string reason)
    { if (!value) throw new InvalidOperationException(reason); }
    private static string Arg(string key)
    { var args = Environment.GetCommandLineArgs(); int index = Array.IndexOf(args, key); return index >= 0 && index + 1 < args.Length ? args[index + 1] : ""; }
    private static string Sha(string path)
    { using (var hash = SHA256.Create()) return BitConverter.ToString(hash.ComputeHash(File.ReadAllBytes(path))).Replace("-", "").ToLowerInvariant(); }
    private static Input ReadInput(string path)
    { return new Input { path = path.Replace('\\', '/'), sha256 = Sha(path), bytes = new FileInfo(path).Length }; }
    private static IEnumerable<T> InScene<T>(Scene scene) where T : Component
    { return scene.GetRootGameObjects().SelectMany(go => go.GetComponentsInChildren<T>(true)); }
    private static T Named<T>(Scene scene, string name) where T : Component
    { return InScene<T>(scene).Single(item => item.name == name); }
    private static void FreshOwnedDirectory(string path)
    {
        Require(!Directory.Exists(path) && !File.Exists(path) && !File.Exists(path + ".meta") && !Directory.Exists(path + ".meta"), "Preserve existing owned path: " + path);
        for (var node = new DirectoryInfo(Path.GetFullPath(path)); node != null; node = node.Parent)
            if (node.Exists) Require((node.Attributes & FileAttributes.ReparsePoint) == 0, "Reparse path is not supported: " + node.FullName);
    }
    private static bool CaptureSceneSetup(out SceneSetup[] setup)
    {
        setup = EditorSceneManager.GetSceneManagerSetup(); bool empty = setup.Length == 0;
        for (int i = 0; i < SceneManager.sceneCount; i++)
        {
            Scene scene = SceneManager.GetSceneAt(i);
            Require(!scene.isDirty, "Save modified scenes before building the sample.");
            if (string.IsNullOrEmpty(scene.path))
            { Require(SceneManager.sceneCount == 1 && scene.rootCount == 0, "Only a single clean unnamed empty scene is supported."); empty = true; }
        }
        return empty;
    }

    public static void Build()
    {
        string output = Arg("-currentPlayerOutput"), receiptPath = Arg("-currentPlayerReceipt");
        string configuration = Arg("-currentPlayerConfiguration");
        Require(configuration == "" || configuration == "Release", "This entry builds Release only.");
        Require(Path.IsPathRooted(output) && Path.GetExtension(output).Equals(".exe", StringComparison.OrdinalIgnoreCase) &&
            Path.IsPathRooted(receiptPath) && !File.Exists(receiptPath) && !Directory.Exists(receiptPath), "Fresh absolute executable and receipt paths are required.");
        output = Path.GetFullPath(output); receiptPath = Path.GetFullPath(receiptPath);
        string buildDirectory = Path.GetDirectoryName(output);
        FreshOwnedDirectory(buildDirectory);
        Require(!receiptPath.StartsWith(buildDirectory + Path.DirectorySeparatorChar, StringComparison.OrdinalIgnoreCase), "Keep the receipt outside the fresh Player directory.");
        Directory.CreateDirectory(Path.GetDirectoryName(receiptPath));
        var result = new Receipt { unity = Application.unityVersion, output = output };
        Exception failure = null; SceneSetup[] setup = null; bool restoreEmpty = false, stateCaptured = false;
        RenderPipelineAsset originalQuality = null;
        UnityEngine.Object[] selection = null;
        try
        {
            Require(!EditorApplication.isPlayingOrWillChangePlaymode, "Build outside Play mode.");
            // The external staging transaction owns Root and has already placed this build/Player harness there.
            Require(AssetDatabase.IsValidFolder(Root), "The caller must stage the owned release harness root first.");
            FreshOwnedDirectory(Generated); FreshOwnedDirectory(Bundles);
            Require(AssetDatabase.IsValidFolder("Assets/StreamingAssets"), "Existing StreamingAssets parent required; do not introduce an unowned parent.");
            Require(PlayerSettings.colorSpace == ColorSpace.Linear && QualitySettings.activeColorSpace == ColorSpace.Linear &&
                PlayerSettings.GetScriptingBackend(NamedBuildTarget.Standalone) == ScriptingImplementation.Mono2x &&
                !PlayerSettings.GetUseDefaultGraphicsAPIs(BuildTarget.StandaloneWindows64) &&
                PlayerSettings.GetGraphicsAPIs(BuildTarget.StandaloneWindows64).SequenceEqual(new[] { GraphicsDeviceType.Direct3D12 }),
                "Existing settings must explicitly select Windows Mono / DX12 / Linear.");
            Require(EditorUserBuildSettings.activeBuildTarget == BuildTarget.StandaloneWindows64, "Select Windows x64 before generating bundles.");
            // A quality override is per level. Do not silently build a Player whose default level uses a different renderer.
            var standalone = Regex.Match(File.ReadAllText("ProjectSettings/QualitySettings.asset"), @"(?m)^\s+Standalone:\s*(\d+)\s*$");
            Require(standalone.Success && int.Parse(standalone.Groups[1].Value) == QualitySettings.GetQualityLevel(), "Current quality level must be the Standalone default.");
            var original = GraphicsSettings.currentRenderPipeline as UniversalRenderPipelineAsset;
            Require(original != null, "Existing URP pipeline required.");
            restoreEmpty = CaptureSceneSetup(out setup); originalQuality = QualitySettings.renderPipeline;
            Require(originalQuality == null || !string.IsNullOrEmpty(AssetDatabase.GetAssetPath(originalQuality)), "Quality pipeline must have a restorable asset path.");
            selection = Selection.objects; stateCaptured = true;
            result.qualityIndex = QualitySettings.GetQualityLevel(); result.qualityName = QualitySettings.names[result.qualityIndex];
            result.colorSpace = PlayerSettings.colorSpace.ToString(); result.scriptingBackend = PlayerSettings.GetScriptingBackend(NamedBuildTarget.Standalone).ToString();
            result.graphicsApis = PlayerSettings.GetGraphicsAPIs(BuildTarget.StandaloneWindows64).Select(api => api.ToString()).ToArray();
            Require(!string.IsNullOrEmpty(AssetDatabase.CreateFolder(Root, "Generated")), "Could not create the owned generated-asset directory.");

            var sourceSettings = new SerializedObject(original);
            int index = sourceSettings.FindProperty("m_DefaultRendererIndex").intValue;
            var sourceRenderer = sourceSettings.FindProperty("m_RendererDataList").GetArrayElementAtIndex(index).objectReferenceValue as UniversalRendererData;
            Require(sourceRenderer != null, "Universal renderer required.");
            var renderer = UnityEngine.Object.Instantiate(sourceRenderer); renderer.name = "UnifiedRelease74Renderer";
            renderer.rendererFeatures.Clear(); renderer.renderingMode = RenderingMode.Forward;
            result.renderer = Generated + "/Renderer.asset"; AssetDatabase.CreateAsset(renderer, result.renderer);
            var feature = ScriptableObject.CreateInstance<HybridLumenGIRendererFeature>(); feature.name = "UnifiedRelease74GI";
            var settings = new HybridLumenGIRendererFeature.Settings
            {
                // Preserve the 120 scene cards while the 18-card aggregate warms.
                resolutionScale = .5f, raysPerPixel = 1, residentProxies = 64, residentSurfaceCards = 192,
                surfaceTileResolution = 32, maxLights = 8, nearDistance = 12, farDistance = 40,
                preferHardwareTracing = false, exactSoftwareTracing = true,
                receiverSourceTracking = true, receiverObjectHistory = true, environmentRadiance = Color.black,
                environmentCubemap = null, measureGpuCost = false, adaptiveGpuBudget = false,
                debugView = HybridLumenGIRendererFeature.DebugView.Final, composition = HybridLumenGIRendererFeature.CompositionMode.Additive
            };
            typeof(HybridLumenGIRendererFeature).GetField("settings", BindingFlags.Instance | BindingFlags.NonPublic).SetValue(feature, settings);
            AssetDatabase.AddObjectToAsset(feature, renderer); renderer.rendererFeatures.Add(feature); feature.SetActive(true);
            EditorUtility.SetDirty(feature); EditorUtility.SetDirty(renderer); result.featureSettings = settings;
            var pipeline = UnityEngine.Object.Instantiate(original); pipeline.name = "UnifiedRelease74Pipeline";
            pipeline.msaaSampleCount = 1; pipeline.renderScale = 1;
            result.pipeline = Generated + "/Pipeline.asset"; AssetDatabase.CreateAsset(pipeline, result.pipeline);
            var serialized = new SerializedObject(pipeline); var list = serialized.FindProperty("m_RendererDataList");
            list.arraySize = 1; list.GetArrayElementAtIndex(0).objectReferenceValue = renderer;
            serialized.FindProperty("m_DefaultRendererIndex").intValue = 0; serialized.ApplyModifiedPropertiesWithoutUndo();
            QualitySettings.renderPipeline = pipeline;

            result.authoringScene = HybridLumenGIValidationScene.CreateSceneAssets(Generated + "/Scenes");
            Require(!string.IsNullOrEmpty(result.authoringScene), "Validation scene generation cancelled.");
            var authoring = EditorSceneManager.OpenScene(result.authoringScene, OpenSceneMode.Single);
            var sequence = InScene<HybridLumenGIValidationSequence>(authoring).Single();
            var sequenceSettings = new SerializedObject(sequence);
            var camera = sequenceSettings.FindProperty("targetCamera").objectReferenceValue as Camera;
            sequenceSettings.FindProperty("feature").objectReferenceValue = feature; sequenceSettings.ApplyModifiedPropertiesWithoutUndo();
            Require(camera != null, "Generated camera missing.");
            Require(EditorSceneManager.SaveScene(authoring), "Could not save authoring configuration."); AssetDatabase.SaveAssets();
            result.sourceBeforeSha256 = Sha(result.authoringScene);
            string[] names = { "White receiver", "Metal zero diffuse receiver", "Black zero diffuse receiver" };
            var details = names.Select(name => Named<HybridLumenGIProxy>(authoring, name)).ToArray();
            var variant = HybridLumenGIUnifiedSampleBuilder.CreateVariant(authoring, camera, feature, details, Generated + "/Variant", Bundles);
            result.scene = variant.ScenePath; result.manifest = AssetDatabase.GetAssetPath(variant.Manifest);
            result.sourceAfterSha256 = Sha(result.authoringScene); result.sourceUnchanged = result.sourceBeforeSha256 == result.sourceAfterSha256;
            Require(result.sourceUnchanged, "Creating the runtime variant changed authoring bytes.");
            var scene = EditorSceneManager.OpenScene(result.scene, OpenSceneMode.Single);
            var controller = InScene<HybridLumenGIUnifiedSample>(scene).Single();
            var driver = InScene<HybridLumenGIAssetPageStreamer>(scene).Single();
            var bindings = InScene<HybridLumenGIStreamedRepresentation>(scene).ToArray();
            Require(bindings.Length == 4 && bindings.Count(b => b.Proxy.HLODParent == null) == 1, "Complete sample group required.");
            result.aggregateMembers = 1; result.detailMembers = 3;
            result.emptyDestinations = bindings.All(b => !b.HasBoundAssets && b.Proxy.SourceMesh == null && b.SourceRenderer.sharedMaterials.Length == 0 && b.Proxy.MeshSdf == null && b.Proxy.SurfaceCharts == null);
            Require(result.emptyDestinations, "The saved runtime variant must start without streamed asset bindings.");
            camera = Named<Camera>(scene, "Validation Camera");
            var door = Named<HybridLumenGIValidationMotion>(scene, "Moving occluder");
            var redWall = Named<Renderer>(scene, "Red wall");
            Require(Named<Renderer>(scene, "Green wall") != redWall && !door.enabled, "Expected fixed walls and inactive finite-sequence motion.");
            var interaction = new GameObject("Unified release ordinary interaction").AddComponent<HybridLumenGIUnifiedSampleInteraction>();
            interaction.Configure(camera, controller, door, redWall, InScene<Light>(scene).OrderBy(light => light.name, StringComparer.Ordinal).ToArray());
            var host = new GameObject("Unified release optional verification").AddComponent<UnifiedSampleHost>();
            host.Configure(camera, controller, feature, driver, bindings, Path.Combine(buildDirectory, "verification"));
            host.enabled = false; camera.enabled = true; camera.targetTexture = null;
            camera.GetUniversalAdditionalCameraData().SetRenderer(0);
            new GameObject("Unified release command line").AddComponent<UnifiedSampleReleaseBootstrap>();
            result.ordinaryCameraEnabled = camera.enabled; result.verificationHostDisabled = !host.enabled;
            Require(InScene<Camera>(scene).Count(c => c.enabled && c.gameObject.activeInHierarchy) == 1 &&
                InScene<HybridLumenGIValidationSequence>(scene).All(item => !item.enabled), "Only the ordinary camera may drive this variant.");
            EditorSceneManager.MarkSceneDirty(scene); Require(EditorSceneManager.SaveScene(scene), "Could not save release variant.");
            AssetDatabase.SaveAssets(); AssetDatabase.Refresh(ImportAssetOptions.ForceSynchronousImport);
            Require(Sha(result.authoringScene) == result.sourceBeforeSha256, "Variant interaction changed authoring scene bytes.");

            result.dependencyRoots = new[] { result.scene, result.authoringScene, result.pipeline, result.manifest,
                AssetDatabase.GetAssetPath(original), AssetDatabase.GetAssetPath(sourceRenderer) }.Distinct().ToArray();
            var dependencies = AssetDatabase.GetDependencies(result.dependencyRoots, true);
            result.dependenciesWithoutProjectFile = dependencies.Where(path => !File.Exists(path)).OrderBy(path => path, StringComparer.Ordinal).ToArray();
            var paths = new HashSet<string>(dependencies.Where(File.Exists), StringComparer.Ordinal);
            foreach (string path in paths.ToArray()) if (File.Exists(path + ".meta")) paths.Add(path + ".meta");
            foreach (string directory in new[] { Root, "Assets/StreamingAssets", "Assets/HybridLumenGI/Runtime", "Assets/HybridLumenGI/Editor", "Assets/ComparisonHarness" })
            {
                Require(Directory.Exists(directory), "Required build input folder missing: " + directory);
                foreach (string path in Directory.GetFiles(directory, "*", SearchOption.AllDirectories)) paths.Add(path.Replace('\\', '/'));
            }
            // The scene list is supplied explicitly below. EditorBuildSettings/scene-manager bookkeeping is
            // not a Player source; pin actual runtime/build settings instead of every editor-generated file.
            foreach (string path in new[] {
                "ProjectSettings/ProjectSettings.asset", "ProjectSettings/GraphicsSettings.asset", "ProjectSettings/QualitySettings.asset",
                "ProjectSettings/TagManager.asset", "ProjectSettings/InputManager.asset", "ProjectSettings/TimeManager.asset",
                "ProjectSettings/DynamicsManager.asset", "ProjectSettings/Physics2DSettings.asset", "ProjectSettings/AudioManager.asset",
                "ProjectSettings/NavMeshAreas.asset", "ProjectSettings/VFXManager.asset", "ProjectSettings/URPProjectSettings.asset" })
                if (File.Exists(path)) paths.Add(path);
            paths.Add("Packages/manifest.json"); paths.Add("Packages/packages-lock.json");
            result.inputs = paths.OrderBy(path => path, StringComparer.Ordinal).Select(ReadInput).ToArray();
            File.WriteAllText(receiptPath, JsonUtility.ToJson(result, true));
            Directory.CreateDirectory(buildDirectory);
            BuildReport report = BuildPipeline.BuildPlayer(new BuildPlayerOptions
            { scenes = new[] { result.scene }, locationPathName = output, target = BuildTarget.StandaloneWindows64, options = BuildOptions.None });
            result.result = report.summary.result.ToString(); result.actualOptions = report.summary.options.ToString();
            result.errors = (int)report.summary.totalErrors; result.warnings = (int)report.summary.totalWarnings; result.totalBytes = report.summary.totalSize;
            result.executableSha256 = File.Exists(output) ? Sha(output) : null;
            result.products = Directory.GetFiles(buildDirectory, "*", SearchOption.AllDirectories).OrderBy(path => path, StringComparer.Ordinal).Select(ReadInput).ToArray();
            result.inputsUnchanged = result.inputs.All(input => File.Exists(input.path) && Sha(input.path) == input.sha256);
            Require(result.inputsUnchanged, "Build inputs changed; preserve this build but reject source matching.");
            Require(report.summary.result == BuildResult.Succeeded && report.summary.totalErrors == 0 && report.summary.options == BuildOptions.None,
                "Release build failed or actual options changed.");
        }
        catch (Exception error) { failure = error; result.error = error.ToString(); result.result = "Failed"; }
        finally
        {
            if (stateCaptured)
            {
                try
                {
                    QualitySettings.renderPipeline = originalQuality;
                    if (restoreEmpty) EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);
                    else EditorSceneManager.RestoreSceneManagerSetup(setup);
                    Selection.objects = selection.Where(item => item != null).ToArray();
                    AssetDatabase.SaveAssets();
                    Require(QualitySettings.renderPipeline == originalQuality, "Original quality pipeline was not restored.");
                    result.restored = true;
                }
                catch (Exception error) { result.restoreError = error.ToString(); result.result = "Failed"; if (failure == null) failure = error; }
            }
            File.WriteAllText(receiptPath, JsonUtility.ToJson(result, true));
            // New assets and partial build outputs are retained for the caller's owned-path archive/restore.
        }
        if (failure != null) throw new InvalidOperationException("Unified Release74 build failed; see " + receiptPath, failure);
        Debug.Log("UNIFIED_RELEASE_BUILD_SUCCEEDED " + output);
    }
}
#endif
