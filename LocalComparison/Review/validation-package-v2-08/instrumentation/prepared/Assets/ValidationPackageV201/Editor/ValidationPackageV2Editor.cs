#if UNITY_EDITOR
using System;
using System.IO;
using System.Reflection;
using HybridLumenGI;
using HybridLumenGI.Editor;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

[InitializeOnLoad]
public static class ValidationPackageV2Editor
{
    private const string Root = "Assets/ValidationPackageV201", Generated = Root + "/Generated", Key = "ValidationPackageV201.";
    [Serializable] private sealed class RestoreState { public SceneSetup[] scenes; public string qualityPipeline; public bool qualityWasNull, empty; }
    [Serializable] private sealed class Result { public string status, error, scene; public bool restored; }
    static ValidationPackageV2Editor() { EditorApplication.playModeStateChanged += StateChanged; }
    private static void Require(bool value, string reason) { if (!value) throw new InvalidOperationException(reason); }
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
            var host = JsonUtility.FromJson<ValidationPackageV2Host.Receipt>(File.ReadAllText(Path.Combine(output, "host-result.json")));
            Require(host.status == "collected" && host.referenceDrained && host.renderedFrames == HybridLumenGIValidationSequence.TotalFrames,
                "Incomplete fixed-sequence capture: " + host.error);
            Require(File.Exists(Path.Combine(host.captureDirectory, "candidate.json")), "Missing v2 candidate manifest.");
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
        string[] args = Environment.GetCommandLineArgs(); int at = Array.IndexOf(args, "-validationPackageOutput");
        Require(at >= 0 && at + 1 < args.Length, "Pass a fresh absolute -validationPackageOutput directory.");
        string output = args[at + 1];
        Require(Path.IsPathRooted(output) && !Directory.Exists(output) && !File.Exists(output), "Preserve existing capture output.");
        Require(!EditorApplication.isPlayingOrWillChangePlaymode && !SessionState.GetBool(Key + "active", false), "Editor already running a capture.");
        Require(!Directory.Exists(Generated) && SystemInfo.graphicsDeviceType == GraphicsDeviceType.Direct3D12 &&
            QualitySettings.activeColorSpace == ColorSpace.Linear, "Fresh generated root and existing Linear DX12 project required.");
        var original = GraphicsSettings.currentRenderPipeline as UniversalRenderPipelineAsset;
        Require(original != null, "Existing URP pipeline required.");
        var setup = EditorSceneManager.GetSceneManagerSetup(); bool empty = setup.Length == 0;
        for (int i = 0; i < UnityEngine.SceneManagement.SceneManager.sceneCount; i++)
        {
            var loaded = UnityEngine.SceneManagement.SceneManager.GetSceneAt(i);
            Require(!loaded.isDirty, "Preserve an unsaved scene before batch validation.");
            if (string.IsNullOrEmpty(loaded.path))
            {
                Require(UnityEngine.SceneManagement.SceneManager.sceneCount == 1 && loaded.rootCount == 0,
                    "Only a single unnamed empty scene can be restored without a saved scene path.");
                empty = true;
            }
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
            var renderer = UnityEngine.Object.Instantiate(sourceRenderer); renderer.name = "ValidationV2Renderer";
            renderer.rendererFeatures.Clear(); renderer.renderingMode = RenderingMode.Forward;
            AssetDatabase.CreateAsset(renderer, Generated + "/Renderer.asset");
            var feature = ScriptableObject.CreateInstance<HybridLumenGIRendererFeature>(); feature.name = "ValidationV2GI";
            var settings = new HybridLumenGIRendererFeature.Settings
            {
                resolutionScale = .5f, raysPerPixel = 1, residentProxies = 64, residentSurfaceCards = 128,
                surfaceTileResolution = 32, maxLights = 8, preferHardwareTracing = false, exactSoftwareTracing = true,
                receiverSourceTracking = true, receiverObjectHistory = true, environmentRadiance = Color.black,
                environmentCubemap = null, measureGpuCost = false, adaptiveGpuBudget = false,
                debugView = HybridLumenGIRendererFeature.DebugView.Final, composition = HybridLumenGIRendererFeature.CompositionMode.Additive
            };
            typeof(HybridLumenGIRendererFeature).GetField("settings", BindingFlags.Instance | BindingFlags.NonPublic).SetValue(feature, settings);
            AssetDatabase.AddObjectToAsset(feature, renderer); renderer.rendererFeatures.Add(feature); feature.SetActive(true);
            EditorUtility.SetDirty(feature); EditorUtility.SetDirty(renderer);
            var pipeline = UnityEngine.Object.Instantiate(original); pipeline.name = "ValidationV2Pipeline";
            pipeline.msaaSampleCount = 1; pipeline.renderScale = 1;
            AssetDatabase.CreateAsset(pipeline, Generated + "/Pipeline.asset");
            var serialized = new SerializedObject(pipeline); var list = serialized.FindProperty("m_RendererDataList");
            list.arraySize = 1; list.GetArrayElementAtIndex(0).objectReferenceValue = renderer;
            serialized.FindProperty("m_DefaultRendererIndex").intValue = 0; serialized.ApplyModifiedPropertiesWithoutUndo();
            QualitySettings.renderPipeline = pipeline;
            string scenePath = HybridLumenGIValidationScene.CreateSceneAssets(Generated + "/Scenes");
            Require(!string.IsNullOrEmpty(scenePath), "Validation asset generation was cancelled.");
            var scene = EditorSceneManager.OpenScene(scenePath, OpenSceneMode.Single);
            var sequence = UnityEngine.Object.FindFirstObjectByType<HybridLumenGIValidationSequence>();
            Require(sequence != null, "Existing scene generator did not produce its validation sequence.");
            var sequenceSettings = new SerializedObject(sequence);
            var camera = sequenceSettings.FindProperty("targetCamera").objectReferenceValue as Camera;
            Require(camera != null, "Generated validation camera missing.");
            camera.enabled = false;
            sequenceSettings.FindProperty("feature").objectReferenceValue = feature;
            sequenceSettings.FindProperty("runOnStart").boolValue = false;
            sequenceSettings.FindProperty("expectedBackend").enumValueIndex = (int)HybridLumenGIValidationSequence.ExpectedBackend.Software;
            sequenceSettings.FindProperty("exportReferencePackage").boolValue = true;
            string sourceDirectory = Path.Combine(output, "source-package");
            sequenceSettings.FindProperty("referenceSourcePackage").stringValue = sourceDirectory;
            sequenceSettings.FindProperty("explicitRenderRequests").boolValue = true;
            sequenceSettings.FindProperty("outputRoot").stringValue = Path.Combine(output, "capture");
            sequenceSettings.FindProperty("runLabel").stringValue = "validation-v2-existing-sequence";
            sequenceSettings.ApplyModifiedPropertiesWithoutUndo();
            var host = new GameObject("Validation v2 batch driver").AddComponent<ValidationPackageV2Host>();
            host.sequence = sequence; host.targetCamera = camera; host.receiptDirectory = output;
            EditorSceneManager.MarkSceneDirty(scene); Require(EditorSceneManager.SaveScene(scene), "Could not save generated validation assets.");
            AssetDatabase.SaveAssets();
            AssetDatabase.Refresh(ImportAssetOptions.ForceSynchronousImport);
            // Archive Editor assets before Play/pipeline creation. Runtime still
            // verifies the package and freezes the actual sources for every frame.
            HybridLumenGIValidationSourceExport.Export(scene, camera, feature, sourceDirectory);
            SessionState.SetString(Key + "scene", scenePath);
            SessionState.SetBool(Key + "active", true); EditorApplication.isPlaying = true;
        }
        catch (Exception error)
        {
            var result = new Result { status = "failed", error = error.ToString() };
            try { Restore(); result.restored = true; } catch (Exception restore) { result.error += "\nRestore: " + restore; }
            SessionState.SetBool(Key + "active", false);
            File.WriteAllText(Path.Combine(output, "editor-result.json"), JsonUtility.ToJson(result, true));
            EditorApplication.Exit(1);
        }
    }
}
#endif
