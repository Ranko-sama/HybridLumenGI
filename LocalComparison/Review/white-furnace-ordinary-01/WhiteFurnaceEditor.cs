using System;
using System.IO;
using System.Linq;
using System.Reflection;
using HybridLumenGI;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

// A temporary scene for the existing local ComparisonCapture. All saved inputs
// belong to the new folder. The calling script restores the project quality setting.
public static class WhiteFurnaceEditor
{
    private const string Root = "Assets/HLGIWhiteFurnace01";
    private const string Sample = "Assets/UnifiedRelease74/Generated";

    public static void Run()
    {
        var args = Environment.GetCommandLineArgs();
        int at = Array.IndexOf(args, "-furnaceOutput");
        if (at < 0 || at + 1 >= args.Length || !Path.IsPathRooted(args[at + 1]) || Directory.Exists(args[at + 1]))
            throw new InvalidOperationException("Pass a fresh absolute capture directory.");
        if (QualitySettings.activeColorSpace != ColorSpace.Linear || SystemInfo.graphicsDeviceType != GraphicsDeviceType.Direct3D12)
            throw new InvalidOperationException("The capture requires Linear DX12.");
        if (!AssetDatabase.CopyAsset(Sample + "/Renderer.asset", Root + "/Renderer.asset") ||
            !AssetDatabase.CopyAsset(Sample + "/Pipeline.asset", Root + "/Pipeline.asset"))
            throw new InvalidOperationException("Cannot copy the sample pipeline and renderer.");
        var renderer = AssetDatabase.LoadAssetAtPath<UniversalRendererData>(Root + "/Renderer.asset");
        var feature = renderer.rendererFeatures.OfType<HybridLumenGIRendererFeature>().Single();
        if (AssetDatabase.GetAssetPath(feature) != Root + "/Renderer.asset" || renderer.rendererFeatures.Count != 1)
            throw new InvalidOperationException("Expected an independent renderer with just its copied GI feature.");
        var settings = (HybridLumenGIRendererFeature.Settings)typeof(HybridLumenGIRendererFeature)
            .GetField("settings", BindingFlags.Instance | BindingFlags.NonPublic).GetValue(feature);
        feature.SetActive(true);
        settings.debugView = HybridLumenGIRendererFeature.DebugView.IndirectOnly;
        settings.composition = HybridLumenGIRendererFeature.CompositionMode.Additive;
        settings.environmentRadiance = Color.white;
        settings.environmentCubemap = null;
        settings.indirectIntensity = 1;
        settings.radianceClamp = 0;
        settings.raysPerPixel = 2;
        settings.filterIterations = 4;
        settings.guidedSamplingWeight = settings.emissiveSamplingWeight = 0;
        settings.maxAreaEmitterTriangles = 0;
        settings.preferHardwareTracing = settings.measureGpuCost = settings.adaptiveGpuBudget = false;
        EditorUtility.SetDirty(feature);
        var pipeline = AssetDatabase.LoadAssetAtPath<UniversalRenderPipelineAsset>(Root + "/Pipeline.asset");
        var so = new SerializedObject(pipeline);
        var list = so.FindProperty("m_RendererDataList");
        list.arraySize = 1;
        list.GetArrayElementAtIndex(0).objectReferenceValue = renderer;
        so.FindProperty("m_DefaultRendererIndex").intValue = 0;
        so.ApplyModifiedPropertiesWithoutUndo();
        pipeline.renderScale = 1;
        pipeline.msaaSampleCount = 1;
        QualitySettings.renderPipeline = pipeline;

        var scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);
        RenderSettings.skybox = null;
        RenderSettings.fog = false;
        RenderSettings.ambientMode = AmbientMode.Flat;
        RenderSettings.ambientLight = Color.black;
        RenderSettings.ambientIntensity = RenderSettings.reflectionIntensity = 0;
        LightmapSettings.lightmaps = Array.Empty<LightmapData>();
        var material = new Material(Shader.Find("Universal Render Pipeline/Lit"));
        material.SetColor("_BaseColor", Color.white);
        material.SetFloat("_WorkflowMode", 0);
        material.EnableKeyword("_SPECULAR_SETUP");
        material.SetColor("_SpecColor", Color.black);
        material.SetFloat("_Metallic", 0);
        material.DisableKeyword("_EMISSION");
        AssetDatabase.CreateAsset(material, Root + "/White.mat");
        var plane = GameObject.CreatePrimitive(PrimitiveType.Plane);
        plane.name = "White furnace receiver";
        var surface = plane.GetComponent<MeshRenderer>();
        surface.sharedMaterial = material;
        surface.lightProbeUsage = LightProbeUsage.Off;
        surface.reflectionProbeUsage = ReflectionProbeUsage.Off;

        var camera = new GameObject("White furnace camera").AddComponent<Camera>();
        camera.transform.SetPositionAndRotation(new Vector3(0, 6, 0), Quaternion.LookRotation(Vector3.down, Vector3.forward));
        camera.orthographic = true;
        camera.orthographicSize = 6;
        camera.clearFlags = CameraClearFlags.SolidColor;
        camera.backgroundColor = Color.black;
        camera.GetUniversalAdditionalCameraData().SetRenderer(0);
        camera.enabled = false;
        var capture = camera.gameObject.AddComponent<ComparisonCapture>();
        capture.camera = camera;
        capture.feature = feature;
        capture.door = new GameObject("Stationary capture marker").transform;
        capture.colorView = capture.thinView = capture.blackView = camera.transform;
        capture.lights = Array.Empty<Light>();
        capture.outputRoot = args[at + 1];
        capture.indirectOnly = true;
        capture.label = "one-frame open white furnace, outgoing RGB";
        capture.totalFrames = 1;
        capture.quitWhenComplete = true;
        camera.gameObject.AddComponent<WhiteFurnaceRequest>();
        if (!EditorSceneManager.SaveScene(scene, Root + "/WhiteFurnace.unity"))
            throw new InvalidOperationException("Cannot save the temporary receiver scene.");
        AssetDatabase.SaveAssets();
        EditorApplication.isPlaying = true;
    }
}
