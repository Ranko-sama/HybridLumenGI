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
    Camera target;HybridLumenGIRendererFeature feature;ComparisonCapture finalCapture;bool verify,steady,finalImage,finished,quitPending;int frames,lastEngine=-1,startEngine,errors,lastSlot=-1;double started,firstRendered;string folder,firstError;
    [Serializable] sealed class Receipt
    {
        public int actualCameraFrames,engine,giFrame,publishedInstances,readyCards,hardwareMeshes,hardwareFallbacks,hardwareMaterialUnknownRecords;
        public string camera,hardwareMaterialStatus;public bool featureEnabled,hardwareBackend;
        public int sampleSlot;public double elapsedSeconds;
        public HybridLumenGIRendererFeature.CameraDiagnostics diagnostics;
        public int retirementPending,retirementOwned,retirementFailed,retirementUnknown,retirementFailedWithdrawals,deformationWorkers,deformationSnapshots,deformationFailed;
        public bool retirementAdmissionClosed,retirementSubmissionUncertain;public long deformationReservedBytes;
    }
    [Serializable] sealed class Result
    {
        public string mode,scene,unity,api,gpu,status,error;public bool debugBuild,verify120,verifySteady300,featureEnabled,testCaptureDisabled,auditProbeDisabled;
        public int requestedFrames,actualCameraFrames,startEngine,firstRenderEngine=-1,lastEngine=-1,errors,width,height;public double firstRenderWaitSeconds;
        public int requestedSeconds,initializationSeconds,sampleIntervalSeconds;public double elapsedSeconds;
        public bool finalImageMode,finalImageCaptured;public string actualViewMode,composition,imageScope;
    }
    Result result;Receipt previousQualified;StreamWriter receipts;
    Vector3 navigationStartPosition;Quaternion navigationStartRotation;float navigationYaw,navigationPitch;
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
            mode.steady=Array.IndexOf(Environment.GetCommandLineArgs(),"-localReleaseSteady300")>=0;
            mode.finalImage=Array.IndexOf(Environment.GetCommandLineArgs(),"-localReleaseFinalImage120")>=0;
            Require((mode.verify?1:0)+(mode.steady?1:0)+(mode.finalImage?1:0)<=1,"Select only one finite Release mode");
            mode.verify|=mode.steady||mode.finalImage;
            mode.Initialize(capture);
        }
        catch(Exception e){Debug.LogError("LOCAL_RELEASE_START_FAILED "+e);Application.Quit(1);}
        return true; // The old audit entry must never continue after Release startup, including failure.
    }
    void Initialize(ComparisonCapture capture)
    {
        started=Time.realtimeSinceStartupAsDouble;startEngine=Time.frameCount;
        result=new Result{mode="ordinary-local-release",scene=gameObject.scene.path,unity=Application.unityVersion,api=SystemInfo.graphicsDeviceType.ToString(),gpu=SystemInfo.graphicsDeviceName,
            status="running",debugBuild=Debug.isDebugBuild,verify120=verify&&!steady,verifySteady300=steady,requestedFrames=verify&&!steady?120:0,
            requestedSeconds=steady?300:0,initializationSeconds=steady?60:0,sampleIntervalSeconds=steady?5:0,featureEnabled=feature.isActive,testCaptureDisabled=!capture.enabled,
            auditProbeDisabled=!UnityEngine.Object.FindObjectsByType<RuntimeAuditProbe>(FindObjectsInactive.Include,FindObjectsSortMode.None).Any(p=>p.enabled),startEngine=startEngine,width=Screen.width,height=Screen.height};
        Require(!result.debugBuild&&result.testCaptureDisabled&&result.auditProbeDisabled,"Ordinary Release isolation failed");
        Debug.Log("LOCAL_RELEASE_START "+JsonUtility.ToJson(result));
        if(!verify)
        {
            navigationStartPosition=target.transform.position;navigationStartRotation=target.transform.rotation;
            ResetNavigation();return; // Normal use has no frame counter, diagnostics polling, capture or automatic quit.
        }
        folder=Arg("-localReleaseOutput");Require(!string.IsNullOrEmpty(folder)&&Path.IsPathRooted(folder)&&!Directory.Exists(folder),"New absolute Release verification directory required");
        Directory.CreateDirectory(folder);receipts=new StreamWriter(Path.Combine(folder,"diagnostics.jsonl")){AutoFlush=true};Save();
        if(finalImage)
        {
            finalCapture=capture;result.finalImageMode=true;
            var settings=typeof(HybridLumenGIRendererFeature).GetField("settings",BindingFlags.Instance|BindingFlags.NonPublic).GetValue(feature);
            result.actualViewMode=settings.GetType().GetField("debugView").GetValue(settings).ToString();
            result.composition=settings.GetType().GetField("composition").GetValue(settings).ToString();
            result.imageScope="Final linear HDR camera target from startup; not ordinary backbuffer pixels. Existing fixed-mapping PNG is preview only.";
            Require(result.actualViewMode=="Final","Final image mode requires existing Final settings");
            try{capture.BeginSingleFinalCapture(folder);}catch{capture.EndSingleFinalCapture();throw;}
            Save();
        }
        Application.runInBackground=true;Application.logMessageReceived+=OnLog;RenderPipelineManager.endCameraRendering+=Rendered;
    }
    void OnLog(string message,string stack,LogType type)
    {if(type==LogType.Error||type==LogType.Exception||type==LogType.Assert){errors++;firstError=firstError??message;}}
    void Update()
    {
        if(!verify){Navigate();return;}
        if(finished)return;
        if(errors>0){Finish(false);return;}
        if(quitPending){Finish(true);return;}
        if(frames==0&&(Time.frameCount-startEngine>120||Time.realtimeSinceStartupAsDouble-started>900))
        {errors++;firstError="First target-camera receipt exceeded existing startup limit";Finish(false);}
        else if(frames>0&&Time.frameCount>lastEngine+1){errors++;firstError="Target-camera receipts stopped";Finish(false);}
    }
    void ResetNavigation()
    {
        target.transform.SetPositionAndRotation(navigationStartPosition,navigationStartRotation);
        var angles=navigationStartRotation.eulerAngles;navigationYaw=angles.y;navigationPitch=Mathf.DeltaAngle(0,angles.x);
    }
    static float Keys(KeyCode positive,KeyCode negative) { return (Input.GetKey(positive)?1:0)-(Input.GetKey(negative)?1:0); }
    void Navigate()
    {
        if(!Application.isFocused||!target)return;
        if(Input.GetKeyDown(KeyCode.Escape)){Application.Quit();return;}
        if(Input.GetKeyDown(KeyCode.R)){ResetNavigation();return;}
        float dt=Mathf.Min(Time.unscaledDeltaTime,0.05f);
        float yaw=Keys(KeyCode.RightArrow,KeyCode.LeftArrow),pitch=Keys(KeyCode.DownArrow,KeyCode.UpArrow);
        if(yaw!=0||pitch!=0)
        {
            navigationYaw=Mathf.Repeat(navigationYaw+yaw*90*dt+180,360)-180;
            navigationPitch=Mathf.Clamp(navigationPitch+pitch*90*dt,-85,85);
            target.transform.rotation=Quaternion.Euler(navigationPitch,navigationYaw,0);
        }
        Vector3 move=new Vector3(Keys(KeyCode.D,KeyCode.A),Keys(KeyCode.E,KeyCode.Q),Keys(KeyCode.W,KeyCode.S));
        move=Vector3.ClampMagnitude(move,1);
        target.transform.position+=Quaternion.Euler(0,navigationYaw,0)*move*(3*dt);
    }
    void Rendered(ScriptableRenderContext context,Camera camera)
    {
        if(finished||camera!=target)return;
        try
        {
            Require(lastEngine<0||Time.frameCount==lastEngine+1,"Duplicate/skipped target-camera receipt");
            Require(feature.isActive,"Feature disabled during ordinary Release run");
            frames++;lastEngine=Time.frameCount;
            if(frames==1){firstRendered=Time.realtimeSinceStartupAsDouble;result.firstRenderEngine=lastEngine;result.firstRenderWaitSeconds=firstRendered-started;Require(lastEngine-startEngine<=120&&result.firstRenderWaitSeconds<=900,"First render exceeded existing startup limit");}
            double elapsed=Time.realtimeSinceStartupAsDouble-firstRendered;
            int slot=steady?Math.Min(60,(int)(elapsed/5)):-1;
            if(steady?slot!=lastSlot:frames==1||frames==60||frames==120)
            {
                var d=feature.GetDiagnostics().SingleOrDefault(x=>x.camera==target.name);
                var row=new Receipt{actualCameraFrames=frames,engine=lastEngine,camera=target.name,featureEnabled=feature.isActive,giFrame=d?.frame??-1,
                    publishedInstances=d?.publishedInstances??0,readyCards=d?.readyCards??0,hardwareBackend=d?.hardwareBackend??false,hardwareMeshes=d?.hardwareMeshes??0,
                    hardwareFallbacks=d?.hardwareFallbacks??0,hardwareMaterialUnknownRecords=d?.hardwareMaterialUnknownRecords??-1,hardwareMaterialStatus=d?.hardwareMaterialStatus};
                if(steady)
                {
                    row.sampleSlot=slot;row.elapsedSeconds=elapsed;row.diagnostics=d;
                    row.retirementPending=HybridLumenGIResourceRetirement.PendingCount;row.retirementOwned=HybridLumenGIResourceRetirement.OwnedCount;
                    row.retirementFailed=HybridLumenGIResourceRetirement.FailedCount;row.retirementUnknown=HybridLumenGIResourceRetirement.UnknownSubmissionCount;
                    row.retirementFailedWithdrawals=HybridLumenGIResourceRetirement.FailedWithdrawalCount;
                    row.retirementAdmissionClosed=HybridLumenGIResourceRetirement.AdmissionClosed;row.retirementSubmissionUncertain=HybridLumenGIResourceRetirement.SubmissionUncertain;
                    row.deformationReservedBytes=HybridLumenGIDeformedMesh.ReservedBytes;row.deformationWorkers=HybridLumenGIDeformedMesh.PendingWorkerCount;
                    row.deformationSnapshots=HybridLumenGIDeformedMesh.PublishedSnapshotCount;row.deformationFailed=HybridLumenGIDeformedMesh.FailedCleanupCount;
                    lastSlot=slot;result.elapsedSeconds=elapsed;
                }
                receipts.WriteLine(JsonUtility.ToJson(row));
                if(steady?elapsed>=60:frames>=60)
                {
                    Require(d!=null&&row.giFrame>0&&row.hardwareBackend&&row.hardwareMeshes>0&&row.readyCards>0&&row.publishedInstances>0&&row.hardwareMaterialUnknownRecords==0&&
                        row.hardwareMaterialStatus=="Uploads and both consumers bound; GPU completion unproven","Ordinary Release GI preparation/binding did not become ready");
                    Require(previousQualified==null||row.giFrame>previousQualified.giFrame,"GI execution frame did not progress");previousQualified=row;
                }
            }
            if(steady?elapsed>=300:frames==120)
            {
                if(finalImage){finalCapture.CaptureSingleFinalFrame(frames);result.finalImageCaptured=true;}
                quitPending=true;
            }
        }
        catch(Exception e){errors++;firstError=firstError??e.ToString();}
    }
    void Save(){if(folder!=null&&Directory.Exists(folder))File.WriteAllText(Path.Combine(folder,"release-result.json"),JsonUtility.ToJson(result,true));}
    void Finish(bool complete)
    {
        if(finished)return;finished=true;RenderPipelineManager.endCameraRendering-=Rendered;Application.logMessageReceived-=OnLog;receipts?.Dispose();receipts=null;
        try{finalCapture?.EndSingleFinalCapture();}catch(Exception e){errors++;firstError=firstError??("Final target cleanup: "+e);}
        result.actualCameraFrames=frames;result.lastEngine=lastEngine;result.errors=errors;result.error=firstError;
        result.status=complete&&(steady?result.elapsedSeconds>=300:frames==120)&&errors==0&&(!finalImage||result.finalImageCaptured)?"completed-finite-release-check":"failed";
        Save();Debug.Log("LOCAL_RELEASE_RESULT "+JsonUtility.ToJson(result));Application.Quit(result.status=="completed-finite-release-check"?0:1);
    }
    void OnApplicationQuit()
    {
        if(!verify||finished)return;
        try{finalCapture?.EndSingleFinalCapture();}catch(Exception e){errors++;firstError=firstError??("Final target cleanup: "+e);}
        result.actualCameraFrames=frames;result.lastEngine=lastEngine;result.errors=errors;result.error=firstError;result.status="closed-before-finite-check";Save();receipts?.Dispose();
    }
}
