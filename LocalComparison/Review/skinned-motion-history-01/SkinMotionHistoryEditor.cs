#if UNITY_EDITOR
using System;
using System.IO;
using HybridLumenGI;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;

[InitializeOnLoad]
public static class SkinMotionHistoryEditor
{
    const string Key="SkinMotionHistory01.active";
    static string freshOutput;
    static SkinMotionHistoryEditor(){EditorApplication.playModeStateChanged+=Changed;}
    static void Changed(PlayModeStateChange state)
    {
        if(state!=PlayModeStateChange.EnteredEditMode||!SessionState.GetBool(Key,false))return;
        SessionState.SetBool(Key,false);bool success=false;
        try
        {
            string path=Path.Combine(SessionState.GetString(Key+".output",""),"usage-result.json");
            var result=File.Exists(path)?JsonUtility.FromJson<SkinMotionHistoryUsage.Result>(File.ReadAllText(path)):null;
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
                File.WriteAllText(Path.Combine(freshOutput,"usage-result.json"),JsonUtility.ToJson(new SkinMotionHistoryUsage.Result{status="failed",error=error.ToString()},true));
            EditorApplication.Exit(1);
        }
    }
    static void Prepare()
    {
        string[] args=Environment.GetCommandLineArgs();int at=Array.IndexOf(args,"-skinMotionOutput");
        if(at<0||at+1>=args.Length)throw new ArgumentException("Fresh -skinMotionOutput required.");
        int modeAt=Array.IndexOf(args,"-skinMotionEnabled");
        if(modeAt<0||modeAt+1>=args.Length||!bool.TryParse(args[modeAt+1],out bool motionEnabled))
            throw new ArgumentException("Explicit -skinMotionEnabled true/false required.");
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
        var featureObject=new SerializedObject(feature);
        var settings=featureObject.FindProperty("settings");
        var motionSetting=settings.FindPropertyRelative("skinnedMotionHistory");
        if(motionSetting==null)throw new InvalidOperationException("Candidate skinnedMotionHistory setting is missing.");
        motionSetting.boolValue=motionEnabled;
        featureObject.ApplyModifiedPropertiesWithoutUndo(); // In-memory author setting; never SaveAssets/SaveScene.
        if(settings.FindPropertyRelative("raysPerPixel").intValue!=2||settings.FindPropertyRelative("filterIterations").intValue!=4||
            !settings.FindPropertyRelative("preferHardwareTracing").boolValue||!settings.FindPropertyRelative("receiverObjectHistory").boolValue||
            settings.FindPropertyRelative("measureGpuCost").boolValue||settings.FindPropertyRelative("adaptiveGpuBudget").boolValue||
            settings.FindPropertyRelative("debugView").enumValueIndex!=(int)HybridLumenGIRendererFeature.DebugView.Final)
            throw new InvalidOperationException("Runner must supply 2ray/filter4/requested DXR/identity/Final with timing and feedback off.");
        var door=fields.FindProperty("door").objectReferenceValue as HybridLumenGIValidationMotion;
        var doorRenderer=door?door.GetComponent<MeshRenderer>():null;
        if(!doorRenderer||doorRenderer.motionVectorGenerationMode!=MotionVectorGenerationMode.Object)
            throw new InvalidOperationException("Saved door must use Object motion vectors.");
        Material[] materials=doorRenderer.sharedMaterials;
        if(materials.Length==0)throw new InvalidOperationException("Saved door has no material slots.");
        foreach(var material in materials)
        {
            if(!material||!material.shader||material.shader.name!="Universal Render Pipeline/Lit")
                throw new InvalidOperationException("Every saved door material must use ordinary Lit.");
            // Material.FindPass selects the active pipeline subshader. The driver
            // checks it after SupportsRenderRequest initializes the actual URP.
            // Keep the saved ordinary Lit toggle: URP renders skeletal motion even
            // with this toggle off. It controls stationary mesh draws, not support.
        }
        camera.enabled=false; // Avoid any automatic camera render before the driver owns its target.
        var driver=new GameObject("Bounded skin motion history A-B usage").AddComponent<SkinMotionHistoryUsage>();
        driver.interaction=interaction;driver.sample=sample;driver.output=output;driver.cameraSource=camera;driver.feature=feature;
        driver.door=door;driver.motionEnabled=motionEnabled;
        driver.configuredRays=2;driver.configuredFilter=4;
        SessionState.SetBool(Key,true);EditorApplication.EnterPlaymode();
    }
}
#endif
