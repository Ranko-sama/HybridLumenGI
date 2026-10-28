using System;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEditor.Build;
using UnityEditor.Build.Reporting;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using HybridLumenGI;

// Local, shared old/new experiment setup. Never included in the delivered source archive.
public static class ComparisonRunnerEditor
{
    const string Root = "Assets/Comparison";
    static string Arg(string name, string fallback)
    {
        var a = Environment.GetCommandLineArgs(); int i = Array.IndexOf(a, name);
        return i >= 0 && i + 1 < a.Length ? a[i + 1] : fallback;
    }
    static void Set(SerializedObject so, string name, object value)
    {
        var p = so.FindProperty("settings." + name) ?? so.FindProperty(name);
        if (p == null) throw new InvalidOperationException("Missing setting: " + name);
        if (value is bool b) p.boolValue=b; else if(value is int n) p.intValue=n; else p.floatValue=Convert.ToSingle(value);
    }
    public static void AssignBakedSources(HybridLumenGIProxy proxy)
    {
        // Only the newer package exposes these asset APIs. The old package retains its actual box representation.
        foreach (string kind in new[] {"MeshSdf", "SurfaceCharts"})
        {
            var method=proxy.GetType().GetMethod("Set"+kind);
            if(method==null) continue;
            var type=method.GetParameters()[0].ParameterType;
            var ids=AssetDatabase.FindAssets("t:"+type.Name,new[]{"Assets/LocalTest"});
            if(ids.Length!=1) throw new InvalidOperationException("Expected one prepared "+kind+" asset, got "+ids.Length);
            method.Invoke(proxy,new object[]{AssetDatabase.LoadAssetAtPath(AssetDatabase.GUIDToAssetPath(ids[0]),type)});
        }
    }
    public static void Prepare()
    {
        Directory.CreateDirectory(Root); AssetDatabase.Refresh();
        PlayerSettings.companyName="HLGI-LocalTest"; PlayerSettings.productName="HLGI-Comparison";
        PlayerSettings.colorSpace=ColorSpace.Linear; PlayerSettings.enableFrameTimingStats=true;
        PlayerSettings.SetUseDefaultGraphicsAPIs(BuildTarget.StandaloneWindows64,false);
        PlayerSettings.SetGraphicsAPIs(BuildTarget.StandaloneWindows64,new[]{GraphicsDeviceType.Direct3D12});
        PlayerSettings.SetScriptingBackend(NamedBuildTarget.Standalone,ScriptingImplementation.Mono2x);
        PlayerSettings.defaultScreenWidth=640; PlayerSettings.defaultScreenHeight=360;
        PlayerSettings.fullScreenMode=FullScreenMode.Windowed;
        QualitySettings.vSyncCount=0; QualitySettings.antiAliasing=0;
        var renderer=AssetDatabase.LoadAssetAtPath<UniversalRendererData>(Root+"/Renderer.asset");
        if(renderer==null)
        {
            renderer=ScriptableObject.CreateInstance<UniversalRendererData>();
            AssetDatabase.CreateAsset(renderer,Root+"/Renderer.asset");
        }
        var feature=renderer.rendererFeatures.OfType<HybridLumenGIRendererFeature>().FirstOrDefault();
        if(feature==null)
        {
            feature=ScriptableObject.CreateInstance<HybridLumenGIRendererFeature>();
            feature.name="Comparison GI"; AssetDatabase.AddObjectToAsset(feature,renderer);
            renderer.rendererFeatures.Add(feature);
        }
        string mode=Arg("-comparisonMode","final");
        bool isNew=feature.GetType().GetField("settings",System.Reflection.BindingFlags.Instance|System.Reflection.BindingFlags.NonPublic|System.Reflection.BindingFlags.Public)!=null;
        var so=new SerializedObject(feature);
        Set(so,isNew?"resolutionScale":"internalResolutionScale",.5f);
        Set(so,"raysPerPixel",2); Set(so,isNew?"screenSteps":"screenTraceSteps",24);
        Set(so,isNew?"traceDistance":"maxTraceDistance",18f); Set(so,"rayBias",.06f);
        Set(so,"screenThickness",.18f); Set(so,isNew?"residentProxies":"maxSdfProxies",32);
        Set(so,"indirectIntensity",1f); Set(so,"temporalCurrentWeight",.25f);
        Set(so,"includeSceneView",false); Set(so,"normalsOctEncoded",false);
        bool off=mode=="off"||mode=="sdf-off";
        Set(so,"debugView",mode=="indirect"?1:0);
        if(isNew) {Set(so,"preferHardwareTracing",mode=="hardware");Set(so,"exactSoftwareTracing",!mode.StartsWith("sdf")); Set(so,"adaptiveGpuBudget",false);}
        if(isNew && Arg("-comparisonBounceFeedback", "") != "") Set(so, "bounceFeedback", float.Parse(Arg("-comparisonBounceFeedback", "1"), System.Globalization.CultureInfo.InvariantCulture));
        so.ApplyModifiedPropertiesWithoutUndo(); feature.SetActive(!off);
        EditorUtility.SetDirty(feature); EditorUtility.SetDirty(renderer);
        var pipeline=AssetDatabase.LoadAssetAtPath<UniversalRenderPipelineAsset>(Root+"/Pipeline.asset");
        if(pipeline==null) {pipeline=UniversalRenderPipelineAsset.Create(renderer);AssetDatabase.CreateAsset(pipeline,Root+"/Pipeline.asset");}
        pipeline.supportsHDR=true;pipeline.supportsCameraDepthTexture=true;pipeline.supportsCameraOpaqueTexture=true;
        pipeline.msaaSampleCount=1;pipeline.renderScale=1;
        var pipelineSO=new SerializedObject(pipeline);
        pipelineSO.FindProperty("m_MainLightRenderingMode").intValue=(int)LightRenderingMode.PerPixel;
        pipelineSO.FindProperty("m_AdditionalLightsRenderingMode").intValue=(int)LightRenderingMode.PerPixel;
        pipelineSO.FindProperty("m_MainLightShadowsSupported").boolValue=true;
        pipelineSO.FindProperty("m_AdditionalLightShadowsSupported").boolValue=true;
        pipelineSO.ApplyModifiedPropertiesWithoutUndo();pipeline.shadowDistance=50;
        GraphicsSettings.defaultRenderPipeline=pipeline;QualitySettings.renderPipeline=pipeline;
        var graph=GraphicsSettings.GetRenderPipelineSettings<RenderGraphSettings>();if(graph!=null)graph.enableRenderCompatibilityMode=false;
        EditorUtility.SetDirty(pipeline);AssetDatabase.SaveAssets();
        string scenePath="Assets/ComparisonScene/Run/Validation.unity";
        if(!File.Exists(scenePath))
        {
            var active=UnityEngine.SceneManagement.SceneManager.GetActiveScene();
            if(active.IsValid()&&string.IsNullOrEmpty(active.path))EditorSceneManager.SaveScene(active,Root+"/Bootstrap.unity");
            HybridLumenGI.Editor.ComparisonSceneBuilder.CreateScene();
        }
        var scene=EditorSceneManager.OpenScene(scenePath,OpenSceneMode.Single);
        var capture=UnityEngine.Object.FindFirstObjectByType<ComparisonCapture>();
        capture.feature=feature;capture.featureOff=off;capture.indirectOnly=mode=="indirect";
        capture.totalFrames=int.Parse(Arg("-comparisonFrames","720"));
        capture.label=Arg("-comparisonLabel",isNew?"integration15-local-compat":"old-local-compat")+"-"+mode;
        capture.outputRoot=Arg("-comparisonOutput","I:/Unity test/Comparison/Results");
        EditorUtility.SetDirty(capture);EditorSceneManager.MarkSceneDirty(scene);EditorSceneManager.SaveScene(scene);
        EditorBuildSettings.scenes=new[]{new EditorBuildSettingsScene(scenePath,true)};
        AssetDatabase.SaveAssets();
        Debug.Log("COMPARISON_PREPARED "+capture.label+" Unity="+Application.unityVersion+" GPU="+SystemInfo.graphicsDeviceName+" API="+SystemInfo.graphicsDeviceType);
        foreach(var format in new[]{UnityEngine.Experimental.Rendering.GraphicsFormat.R16G16B16A16_SFloat,UnityEngine.Experimental.Rendering.GraphicsFormat.R32G32B32A32_SFloat,UnityEngine.Experimental.Rendering.GraphicsFormat.R8G8B8A8_UNorm,UnityEngine.Experimental.Rendering.GraphicsFormat.R32G32_UInt})
            Debug.Log("COMPARISON_FORMAT "+format+" Render="+SystemInfo.IsFormatSupported(format,UnityEngine.Experimental.Rendering.GraphicsFormatUsage.Render)+" Sample="+SystemInfo.IsFormatSupported(format,UnityEngine.Experimental.Rendering.GraphicsFormatUsage.Sample)+" LoadStore="+SystemInfo.IsFormatSupported(format,UnityEngine.Experimental.Rendering.GraphicsFormatUsage.LoadStore));
    }
    public static void Play(){Prepare();EditorApplication.EnterPlaymode();}
    public static void Build()
    {
        Prepare();string target=Arg("-comparisonBuild","I:/Unity test/Comparison/Build/Comparison.exe");
        Directory.CreateDirectory(Path.GetDirectoryName(target));
        var report=BuildPipeline.BuildPlayer(new BuildPlayerOptions{scenes=EditorBuildSettings.scenes.Select(s=>s.path).ToArray(),locationPathName=target,target=BuildTarget.StandaloneWindows64,options=BuildOptions.Development});
        File.WriteAllText(Path.ChangeExtension(target,"build.txt"),report.summary.result+"\n"+report.summary.totalSize);
        if(report.summary.result!=BuildResult.Succeeded)throw new Exception("Player build failed: "+report.summary.result);
    }
}

