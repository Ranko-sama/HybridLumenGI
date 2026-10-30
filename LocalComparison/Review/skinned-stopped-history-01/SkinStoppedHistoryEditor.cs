#if UNITY_EDITOR
using System;
using System.IO;
using HybridLumenGI;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;

[InitializeOnLoad]
public static class SkinStoppedHistoryEditor
{
    const string Key="SkinStoppedHistory01.active";
    static string freshOutput;
    static SkinStoppedHistoryEditor(){EditorApplication.playModeStateChanged+=Changed;}
    static void Changed(PlayModeStateChange state)
    {
        if(state!=PlayModeStateChange.EnteredEditMode||!SessionState.GetBool(Key,false))return;
        SessionState.SetBool(Key,false);bool success=false;
        try
        {
            string path=Path.Combine(SessionState.GetString(Key+".output",""),"usage-result.json");
            var result=File.Exists(path)?JsonUtility.FromJson<SkinStoppedHistoryUsage.Result>(File.ReadAllText(path)):null;
            success=result!=null&&result.status=="passed"&&result.requests==240&&result.readbacksDrained;
        }
        catch(Exception error){Debug.LogError(error);}
        EditorApplication.delayCall+=()=>EditorApplication.Exit(success?0:1);
    }
    public static void Run()
    {
        try{Prepare();}
        catch(Exception error)
        {
            SessionState.SetBool(Key,false);Debug.LogError(error);
            if(freshOutput!=null&&!File.Exists(Path.Combine(freshOutput,"usage-result.json")))
                File.WriteAllText(Path.Combine(freshOutput,"usage-result.json"),JsonUtility.ToJson(new SkinStoppedHistoryUsage.Result{status="failed",error=error.ToString()},true));
            EditorApplication.Exit(1);
        }
    }
    static void Prepare()
    {
        string[] args=Environment.GetCommandLineArgs();int at=Array.IndexOf(args,"-skinStoppedHistoryOutput");
        if(at<0||at+1>=args.Length)throw new ArgumentException("Fresh -skinStoppedHistoryOutput required.");
        string output=args[at+1];
        if(!Path.IsPathRooted(output)||Directory.Exists(output)||File.Exists(output))throw new ArgumentException("Preserve existing output.");
        Directory.CreateDirectory(output);freshOutput=output;SessionState.SetString(Key+".output",output);
        EditorSceneManager.OpenScene("Assets/UnifiedRelease74/Generated/Variant/UnifiedSample.unity",OpenSceneMode.Single);
        QualitySettings.renderPipeline=AssetDatabase.LoadAssetAtPath<RenderPipelineAsset>(AssetDatabase.GUIDToAssetPath("ca5b7ea101c75f645851495aea1b326c"));
        var interaction=UnityEngine.Object.FindFirstObjectByType<HybridLumenGIUnifiedSampleInteraction>();
        if(!interaction)throw new InvalidOperationException("Saved unified interaction is missing.");
        var fields=new SerializedObject(interaction);
        var sample=fields.FindProperty("sample").objectReferenceValue as HybridLumenGIUnifiedSample;
        var camera=fields.FindProperty("targetCamera").objectReferenceValue as Camera;
        var feature=sample?new SerializedObject(sample).FindProperty("feature").objectReferenceValue as HybridLumenGIRendererFeature:null;
        if(!sample||!camera||!feature)throw new InvalidOperationException("Saved sample references are incomplete.");
        var settings=new SerializedObject(feature).FindProperty("settings");
        if(settings.FindPropertyRelative("raysPerPixel").intValue!=2||settings.FindPropertyRelative("filterIterations").intValue!=4||
            !settings.FindPropertyRelative("preferHardwareTracing").boolValue||!settings.FindPropertyRelative("receiverObjectHistory").boolValue||
            settings.FindPropertyRelative("measureGpuCost").boolValue||settings.FindPropertyRelative("adaptiveGpuBudget").boolValue||
            settings.FindPropertyRelative("debugView").enumValueIndex!=(int)HybridLumenGIRendererFeature.DebugView.Final)
            throw new InvalidOperationException("Runner must supply 2ray/filter4/requested DXR/identity/Final with timing and feedback off.");
        camera.enabled=false; // Avoid any automatic camera render before the driver owns its target.
        var driver=new GameObject("Bounded stopped skin history usage").AddComponent<SkinStoppedHistoryUsage>();
        driver.interaction=interaction;driver.sample=sample;driver.output=output;driver.cameraSource=camera;driver.feature=feature;
        driver.door=fields.FindProperty("door").objectReferenceValue as HybridLumenGIValidationMotion;
        driver.configuredRays=2;driver.configuredFilter=4;
        SessionState.SetBool(Key,true);EditorApplication.EnterPlaymode();
    }
}
#endif
