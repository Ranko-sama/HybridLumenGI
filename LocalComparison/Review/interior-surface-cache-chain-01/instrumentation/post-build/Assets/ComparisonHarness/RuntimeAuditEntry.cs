using System;
using System.IO;
using System.Reflection;
using UnityEngine;
using UnityEngine.SceneManagement;
using HybridLumenGI;

// Portable entry for the fixed two-scene test Player; production feature is unchanged.
public static class RuntimeAuditEntry
{
    static string Arg(string key,string fallback){var a=Environment.GetCommandLineArgs();int i=Array.IndexOf(a,key);return i>=0&&i+1<a.Length?a[i+1]:fallback;}
    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
    static void Configure()
    {
        if(Application.isEditor)return;
        if(Arg("-auditScene","functional")=="streaming"&&SceneManager.GetActiveScene().buildIndex!=1)
        {SceneManager.sceneLoaded+=Loaded;SceneManager.LoadScene(1);return;}
        Apply();
    }
    static void Loaded(Scene scene,LoadSceneMode mode){SceneManager.sceneLoaded-=Loaded;Apply();}
    static void Apply()
    {
        var capture=UnityEngine.Object.FindFirstObjectByType<ComparisonCapture>();
        capture.outputRoot=Path.GetFullPath(Arg("-auditOutput",Path.Combine(Path.GetDirectoryName(Application.dataPath),"TestResults")));
        capture.totalFrames=720;
        var feature=(HybridLumenGIRendererFeature)capture.feature;
        var settings=(HybridLumenGIRendererFeature.Settings)typeof(HybridLumenGIRendererFeature).GetField("settings",BindingFlags.Instance|BindingFlags.NonPublic).GetValue(feature);
        string mode=Arg("-comparisonMode","final");settings.preferHardwareTracing=mode=="hardware";settings.exactSoftwareTracing=mode!="sdf";
        capture.featureOff=mode=="off";feature.SetActive(!capture.featureOff);
        capture.label="player-"+Arg("-auditScene","functional")+"-"+mode;
        if(InteriorSurfaceMode.Enabled)InteriorSurfaceMode.Configure(capture);
    }
}
