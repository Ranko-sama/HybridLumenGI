// Temporary Editor-only entry: use the actual Settings and Unity serializer,
// then invoke the unchanged ordinary Player builder in this same Unity process.
using System;
using System.Collections.Generic;
using System.IO;
using System.Reflection;
using HybridLumenGI;
using UnityEditor;
using UnityEngine;

public static class GpuControlsBuildCheck
{
    [Serializable] private sealed class Result
    {
        public string status="running",unity,error;
        public string scope="Actual Settings/JsonUtility configuration comparison; not rendered history or GPU timing acceptance.";
        public List<string> checks=new List<string>();
    }
    private static readonly string ReportPath=Path.Combine(
        @"C:/Users/Administrator/Desktop/test/HybridLumenGI/LocalComparison/Review/gpu-controls-preserve-history-01",
        "settings-check.json");
    private static readonly MethodInfo Snapshot=typeof(HybridLumenGIRendererFeature.Settings).GetMethod(
        "TransportSettingsJson",BindingFlags.Instance|BindingFlags.NonPublic);

    private static string Transport(HybridLumenGIRendererFeature.Settings settings)
    {
        if(Snapshot==null)throw new Exception("Missing actual transport settings method.");
        return (string)Snapshot.Invoke(settings,null);
    }
    private static void Check(bool condition,string description,Result result)
    {
        if(!condition)throw new Exception(description);
        result.checks.Add(description);
    }
    public static void Run()
    {
        if(File.Exists(ReportPath))throw new Exception("Preserve the existing settings check result.");
        var result=new Result{unity=Application.unityVersion};
        try
        {
            var baseline=new HybridLumenGIRendererFeature.Settings();
            string original=JsonUtility.ToJson(baseline),transport=Transport(baseline);
            Check(JsonUtility.ToJson(baseline)==original,"Snapshot leaves live default Settings unchanged",result);
            var changes=new Dictionary<string,Action<HybridLumenGIRendererFeature.Settings>>
            {
                {"measure",s=>s.measureGpuCost=true},
                {"provider",s=>s.preferNativeGpuTiming=false},
                {"feedback",s=>s.adaptiveGpuBudget=true},
                {"target",s=>s.targetGpuMilliseconds=25},
                {"minimum-work",s=>s.minimumGpuWorkFraction=.25f}
            };
            foreach(var change in changes)
            {
                var value=new HybridLumenGIRendererFeature.Settings();change.Value(value);
                string full=JsonUtility.ToJson(value);
                Check(full!=original,change.Key+": full timing configuration changes",result);
                Check(Transport(value)==transport,change.Key+": transport configuration stays valid",result);
                Check(JsonUtility.ToJson(value)==full,change.Key+": snapshot does not mutate live controls",result);
            }
            var combined=new HybridLumenGIRendererFeature.Settings();
            foreach(var change in changes)change.Value(combined);
            Check(Transport(combined)==transport,"Combined controls retain transport configuration",result);
            combined.raysPerPixel++;
            Check(Transport(combined)!=transport,"Ray-count change still invalidates with controls changed",result);
            var light=new HybridLumenGIRendererFeature.Settings{bounceFeedback=.5f};
            Check(Transport(light)!=transport,"Bounce change still invalidates transport",result);
            Check(Transport(baseline)==transport,"Repeated unchanged snapshot remains stable",result);
            result.status="passed";
        }
        catch(Exception error)
        {
            result.status="failed";result.error=error.ToString();
            File.WriteAllText(ReportPath,JsonUtility.ToJson(result,true));
            Debug.LogException(error);EditorApplication.Exit(1);return;
        }
        File.WriteAllText(ReportPath,JsonUtility.ToJson(result,true));
        HybridLumenGI.Editor.HybridLumenGIPlayerBuild.Build();
    }
}
