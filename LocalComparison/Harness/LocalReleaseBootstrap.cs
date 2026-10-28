// Ordinary existing-scene Release startup. Optional bounded check uses only public CPU diagnostics.
using System;
using System.IO;
using System.Linq;
using System.Reflection;
using UnityEngine;
using UnityEngine.Rendering;
using HybridLumenGI;
public sealed class LocalReleaseBootstrap : MonoBehaviour
{
    Camera target;HybridLumenGIRendererFeature feature;bool verify,finished,quitPending;int frames,lastEngine=-1,startEngine,errors;double started;string folder,firstError;
    [Serializable] sealed class Receipt
    {
        public int actualCameraFrames,engine,giFrame,publishedInstances,readyCards,hardwareMeshes,hardwareFallbacks,hardwareMaterialUnknownRecords;
        public string camera,hardwareMaterialStatus;public bool featureEnabled,hardwareBackend;
    }
    [Serializable] sealed class Result
    {
        public string mode,scene,unity,api,gpu,status,error;public bool debugBuild,verify120,featureEnabled,testCaptureDisabled,auditProbeDisabled;
        public int requestedFrames,actualCameraFrames,startEngine,firstRenderEngine=-1,lastEngine=-1,errors,width,height;public double firstRenderWaitSeconds;
    }
    Result result;Receipt previousQualified;StreamWriter receipts;
    static string Arg(string name){var args=Environment.GetCommandLineArgs();int i=Array.IndexOf(args,name);return i>=0&&i+1<args.Length?args[i+1]:null;}
    static void Require(bool value,string reason){if(!value)throw new Exception(reason);}
    public static bool TryStart()
    {
        if(Application.isEditor||Debug.isDebugBuild)return false;
        try
        {
            var capture=UnityEngine.Object.FindFirstObjectByType<ComparisonCapture>();Require(capture&&capture.camera&&capture.feature&&capture.colorView,"Existing Functional startup references missing");
            capture.enabled=false;
            foreach(var probe in UnityEngine.Object.FindObjectsByType<RuntimeAuditProbe>(FindObjectsInactive.Include,FindObjectsSortMode.None))probe.enabled=false;
            foreach(var probe in UnityEngine.Object.FindObjectsByType<StreamingAuditProbe>(FindObjectsInactive.Include,FindObjectsSortMode.None))probe.enabled=false;
            var mode=capture.gameObject.AddComponent<LocalReleaseBootstrap>();mode.target=capture.camera;mode.feature=(HybridLumenGIRendererFeature)capture.feature;
            var settings=(HybridLumenGIRendererFeature.Settings)typeof(HybridLumenGIRendererFeature).GetField("settings",BindingFlags.Instance|BindingFlags.NonPublic).GetValue(mode.feature);
            settings.preferHardwareTracing=true; // Same actual-DXR preference used by the existing runtime entry's hardware mode.
            mode.feature.SetActive(true);mode.target.targetTexture=null;mode.target.enabled=true;
            mode.target.transform.SetPositionAndRotation(capture.colorView.position,capture.colorView.rotation);
            mode.verify=Array.IndexOf(Environment.GetCommandLineArgs(),"-localReleaseVerify120")>=0;
            mode.Initialize(capture);
        }
        catch(Exception e){Debug.LogError("LOCAL_RELEASE_START_FAILED "+e);Application.Quit(1);}
        return true; // The old audit entry must never continue after Release startup, including failure.
    }
    void Initialize(ComparisonCapture capture)
    {
        started=Time.realtimeSinceStartupAsDouble;startEngine=Time.frameCount;
        result=new Result{mode="ordinary-local-release",scene=gameObject.scene.path,unity=Application.unityVersion,api=SystemInfo.graphicsDeviceType.ToString(),gpu=SystemInfo.graphicsDeviceName,
            status="running",debugBuild=Debug.isDebugBuild,verify120=verify,requestedFrames=verify?120:0,featureEnabled=feature.isActive,testCaptureDisabled=!capture.enabled,
            auditProbeDisabled=!UnityEngine.Object.FindObjectsByType<RuntimeAuditProbe>(FindObjectsInactive.Include,FindObjectsSortMode.None).Any(p=>p.enabled),startEngine=startEngine,width=Screen.width,height=Screen.height};
        Require(!result.debugBuild&&result.testCaptureDisabled&&result.auditProbeDisabled,"Ordinary Release isolation failed");
        Debug.Log("LOCAL_RELEASE_START "+JsonUtility.ToJson(result));
        if(!verify)return; // Normal local use has no frame counter, diagnostics polling, file capture or automatic quit.
        folder=Arg("-localReleaseOutput");Require(!string.IsNullOrEmpty(folder)&&Path.IsPathRooted(folder)&&!Directory.Exists(folder),"New absolute Release verification directory required");
        Directory.CreateDirectory(folder);receipts=new StreamWriter(Path.Combine(folder,"diagnostics.jsonl")){AutoFlush=true};Save();
        Application.runInBackground=true;Application.logMessageReceived+=OnLog;RenderPipelineManager.endCameraRendering+=Rendered;
    }
    void OnLog(string message,string stack,LogType type)
    {if(type==LogType.Error||type==LogType.Exception||type==LogType.Assert){errors++;firstError=firstError??message;}}
    void Update()
    {
        if(!verify||finished)return;
        if(errors>0){Finish(false);return;}
        if(quitPending){Finish(true);return;}
        if(frames==0&&(Time.frameCount-startEngine>120||Time.realtimeSinceStartupAsDouble-started>900))
        {errors++;firstError="First target-camera receipt exceeded existing startup limit";Finish(false);}
        else if(frames>0&&Time.frameCount>lastEngine+1){errors++;firstError="Target-camera receipts stopped";Finish(false);}
    }
    void Rendered(ScriptableRenderContext context,Camera camera)
    {
        if(finished||camera!=target)return;
        try
        {
            Require(lastEngine<0||Time.frameCount==lastEngine+1,"Duplicate/skipped target-camera receipt");
            Require(feature.isActive,"Feature disabled during ordinary Release run");
            frames++;lastEngine=Time.frameCount;
            if(frames==1){result.firstRenderEngine=lastEngine;result.firstRenderWaitSeconds=Time.realtimeSinceStartupAsDouble-started;Require(lastEngine-startEngine<=120&&result.firstRenderWaitSeconds<=900,"First render exceeded existing startup limit");}
            if(frames==1||frames==60||frames==120)
            {
                var d=feature.GetDiagnostics().SingleOrDefault(x=>x.camera==target.name);
                var row=new Receipt{actualCameraFrames=frames,engine=lastEngine,camera=target.name,featureEnabled=feature.isActive,giFrame=d?.frame??-1,
                    publishedInstances=d?.publishedInstances??0,readyCards=d?.readyCards??0,hardwareBackend=d?.hardwareBackend??false,hardwareMeshes=d?.hardwareMeshes??0,
                    hardwareFallbacks=d?.hardwareFallbacks??0,hardwareMaterialUnknownRecords=d?.hardwareMaterialUnknownRecords??-1,hardwareMaterialStatus=d?.hardwareMaterialStatus};
                receipts.WriteLine(JsonUtility.ToJson(row));
                if(frames>=60)
                {
                    Require(d!=null&&row.giFrame>0&&row.hardwareBackend&&row.hardwareMeshes>0&&row.readyCards>0&&row.publishedInstances>0&&row.hardwareMaterialUnknownRecords==0&&
                        row.hardwareMaterialStatus=="Uploads and both consumers bound; GPU completion unproven","Ordinary Release GI preparation/binding did not become ready");
                    Require(previousQualified==null||row.giFrame>previousQualified.giFrame,"GI execution frame did not progress");previousQualified=row;
                }
            }
            if(frames==120)quitPending=true;
        }
        catch(Exception e){errors++;firstError=firstError??e.ToString();}
    }
    void Save(){if(folder!=null&&Directory.Exists(folder))File.WriteAllText(Path.Combine(folder,"release-result.json"),JsonUtility.ToJson(result,true));}
    void Finish(bool complete)
    {
        if(finished)return;finished=true;RenderPipelineManager.endCameraRendering-=Rendered;Application.logMessageReceived-=OnLog;receipts?.Dispose();receipts=null;target.enabled=false;
        result.actualCameraFrames=frames;result.lastEngine=lastEngine;result.errors=errors;result.error=firstError;result.status=complete&&frames==120&&errors==0?"completed-finite-release-check":"failed";
        Save();Debug.Log("LOCAL_RELEASE_RESULT "+JsonUtility.ToJson(result));Application.Quit(result.status=="completed-finite-release-check"?0:1);
    }
    void OnApplicationQuit()
    {
        if(!verify||finished)return;
        result.actualCameraFrames=frames;result.lastEngine=lastEngine;result.errors=errors;result.error=firstError;result.status="closed-before-finite-check";Save();receipts?.Dispose();
    }
}
