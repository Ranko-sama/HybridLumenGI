#if UNITY_EDITOR
using System;
using System.IO;
using HybridLumenGI;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;

[InitializeOnLoad]
public static class SkinnedSampleUsageEditor
{
    const string Key="SkinnedSampleUsage01.active";
    static SkinnedSampleUsageEditor(){EditorApplication.playModeStateChanged+=Changed;}
    static void Changed(PlayModeStateChange state)
    {
        if(state!=PlayModeStateChange.EnteredEditMode||!SessionState.GetBool(Key,false))return;
        SessionState.SetBool(Key,false);
        string path=Path.Combine(SessionState.GetString(Key+".output",""),"usage-result.json");
        bool success=File.Exists(path)&&File.ReadAllText(path).Contains("\"status\": \"passed\"");
        EditorApplication.delayCall+=()=>EditorApplication.Exit(success?0:1);
    }
    public static void Run()
    {
        string[] args=Environment.GetCommandLineArgs();int at=Array.IndexOf(args,"-skinUsageOutput");
        if(at<0||at+1>=args.Length)throw new ArgumentException("Fresh -skinUsageOutput required.");
        string output=args[at+1];
        if(!Path.IsPathRooted(output)||Directory.Exists(output))throw new ArgumentException("Preserve existing output.");
        Directory.CreateDirectory(output);SessionState.SetString(Key+".output",output);
        EditorSceneManager.OpenScene("Assets/UnifiedRelease74/Generated/Variant/UnifiedSample.unity",OpenSceneMode.Single);
        QualitySettings.renderPipeline=AssetDatabase.LoadAssetAtPath<RenderPipelineAsset>(AssetDatabase.GUIDToAssetPath("ca5b7ea101c75f645851495aea1b326c"));
        var interaction=UnityEngine.Object.FindFirstObjectByType<HybridLumenGIUnifiedSampleInteraction>();
        var settings=new SerializedObject(interaction);
        var sample=settings.FindProperty("sample").objectReferenceValue as HybridLumenGIUnifiedSample;
        var driver=new GameObject("Bounded skin sample usage").AddComponent<SkinnedSampleUsage>();
        driver.interaction=interaction;driver.output=output;
        driver.cameraSource=settings.FindProperty("targetCamera").objectReferenceValue as Camera;
        driver.door=settings.FindProperty("door").objectReferenceValue as HybridLumenGIValidationMotion;
        driver.feature=new SerializedObject(sample).FindProperty("feature").objectReferenceValue as HybridLumenGIRendererFeature;
        SessionState.SetBool(Key,true);EditorApplication.EnterPlaymode();
    }
}
#endif
