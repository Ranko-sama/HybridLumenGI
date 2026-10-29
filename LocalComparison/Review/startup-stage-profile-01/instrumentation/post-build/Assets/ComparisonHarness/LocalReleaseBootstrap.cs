// Ordinary existing-scene Release startup. Optional bounded check uses only public CPU diagnostics.
using System;
using System.IO;
using System.Collections.Generic;
using System.Linq;
using System.Reflection;
using UnityEngine;
using UnityEngine.Rendering;
using HybridLumenGI;
public sealed class LocalReleaseBootstrap : MonoBehaviour
{
    Camera target;HybridLumenGIRendererFeature feature;ComparisonCapture finalCapture;bool verify,steady,finalImage,finished,quitPending;int frames,lastEngine=-1,startEngine,errors,lastSlot=-1;double started,firstRendered;string folder,firstError;
    bool explicitRequest,insideRequest;int lastRequestEngine=-1;
    RenderPipeline.StandardRequest request;
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
        public bool environmentCubePresent,environmentCubeSupported,environmentCubeLinear;
        public string environmentCubeName,environmentCubeFormat,environmentCubeGraphicsFormat,environmentCubeFilterMode,environmentCubeWrapMode;
        public int environmentCubeInstanceId,environmentCubeWidth,environmentCubeHeight,environmentCubeMipCount;
        public bool finalImageMode,finalImageCaptured;public string actualViewMode,composition,imageScope;
        public bool explicitRequest,renderRequestSupported,cameraDisabledDuringRequests;
        public string renderPath;
        public int requests,cameraBegins,cameraEnds,contextBegins,contextEnds;
    }
    Result result;Receipt previousQualified;StreamWriter receipts;
    Vector3 navigationStartPosition;Quaternion navigationStartRotation;float navigationYaw,navigationPitch;
    static string Arg(string name){var args=Environment.GetCommandLineArgs();int i=Array.IndexOf(args,name);return i>=0&&i+1<args.Length?args[i+1]:null;}
    static void Require(bool value,string reason){if(!value)throw new Exception(reason);}
    public static bool TryStart()
    {
                using var __startupStart=global::HybridLumenGI.StartupStageProbe.Measure(null,"Host.TryStart");
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
            mode.explicitRequest=Array.IndexOf(Environment.GetCommandLineArgs(),"-localReleaseExplicitRequest")>=0;
            Require(!mode.explicitRequest||(mode.finalImage&&Application.isBatchMode),"Explicit requests require -localReleaseFinalImage120 and -batchmode");
            mode.verify|=mode.steady||mode.finalImage;
            if(Array.IndexOf(Environment.GetCommandLineArgs(),"-localContinuousDeformation256")>=0)
            {
                Require(!mode.verify,"Select only one finite Release mode");
                ContinuousDeformationRun.Begin(capture,mode.feature);Destroy(mode);return true;
            }
            mode.Initialize(capture);
        }
        catch(Exception e){Debug.LogError("LOCAL_RELEASE_START_FAILED "+e);Application.Quit(1);}
        return true; // The old audit entry must never continue after Release startup, including failure.
    }
    void Initialize(ComparisonCapture capture)
    {
                using var __startupInitialize=global::HybridLumenGI.StartupStageProbe.Measure(target,"Host.Initialize");
        started=Time.realtimeSinceStartupAsDouble;startEngine=Time.frameCount;
        result=new Result{mode="startup-stage-profile-01",scene=gameObject.scene.path,unity=Application.unityVersion,api=SystemInfo.graphicsDeviceType.ToString(),gpu=SystemInfo.graphicsDeviceName,
            status="running",debugBuild=Debug.isDebugBuild,verify120=verify&&!steady,verifySteady300=steady,requestedFrames=verify&&!steady?12:0,
            requestedSeconds=steady?300:0,initializationSeconds=steady?60:0,sampleIntervalSeconds=steady?5:0,featureEnabled=feature.isActive,testCaptureDisabled=!capture.enabled,
            auditProbeDisabled=!UnityEngine.Object.FindObjectsByType<RuntimeAuditProbe>(FindObjectsInactive.Include,FindObjectsSortMode.None).Any(p=>p.enabled),startEngine=startEngine,width=Screen.width,height=Screen.height};
        result.explicitRequest=explicitRequest;
        result.renderPath=explicitRequest?"RenderPipeline.StandardRequest; disabled camera; one request per Update":"ordinary automatic camera rendering";
        Require(!result.debugBuild&&result.testCaptureDisabled&&result.auditProbeDisabled,"Ordinary Release isolation failed");
        Debug.Log("LOCAL_RELEASE_START "+JsonUtility.ToJson(result));
        if(!verify)
        {
            navigationStartPosition=target.transform.position;navigationStartRotation=target.transform.rotation;
            ContinuousDeformationExample.Create(capture,true);
            ResetNavigation();return; // Normal use has no frame counter, diagnostics polling, capture or automatic quit.
        }
        folder=Arg("-localReleaseOutput");Require(!string.IsNullOrEmpty(folder)&&Path.IsPathRooted(folder)&&!Directory.Exists(folder),"New absolute Release verification directory required");
        Directory.CreateDirectory(folder);global::HybridLumenGI.StartupStageProbe.Configure(target,folder);receipts=new StreamWriter(Path.Combine(folder,"diagnostics.jsonl")){AutoFlush=true};Save();
        if(finalImage)
        {
            finalCapture=capture;result.finalImageMode=true;
            var settings=typeof(HybridLumenGIRendererFeature).GetField("settings",BindingFlags.Instance|BindingFlags.NonPublic).GetValue(feature);
            result.actualViewMode=settings.GetType().GetField("debugView").GetValue(settings).ToString();
            result.composition=settings.GetType().GetField("composition").GetValue(settings).ToString();
            result.imageScope="Unchanged Release71 linear HDR render target; this diagnostic performs no image readback.";
            var cube=((HybridLumenGIRendererFeature.Settings)settings).environmentCubemap;
            result.environmentCubePresent=cube!=null;
            result.environmentCubeSupported=HybridLumenGIRendererFeature.IsSupportedEnvironmentCubemap(cube);
            if(cube!=null)
            {
                result.environmentCubeName=cube.name;result.environmentCubeInstanceId=cube.GetInstanceID();
                result.environmentCubeFormat=cube.format.ToString();result.environmentCubeGraphicsFormat=cube.graphicsFormat.ToString();
                result.environmentCubeLinear=!UnityEngine.Experimental.Rendering.GraphicsFormatUtility.IsSRGBFormat(cube.graphicsFormat);
                result.environmentCubeWidth=cube.width;result.environmentCubeHeight=cube.height;result.environmentCubeMipCount=cube.mipmapCount;
                result.environmentCubeFilterMode=cube.filterMode.ToString();result.environmentCubeWrapMode=cube.wrapMode.ToString();
            }
            Save();
            Require(result.environmentCubePresent&&result.environmentCubeSupported&&result.environmentCubeLinear&&
                result.environmentCubeName=="CurrentRelease67Environment"&&result.environmentCubeFormat=="RGBAFloat"&&
                result.environmentCubeWidth==2&&result.environmentCubeHeight==2&&result.environmentCubeMipCount==1&&
                result.environmentCubeFilterMode=="Bilinear"&&result.environmentCubeWrapMode=="Clamp","Frozen Release67 environment asset missing or invalid");
            Require(result.actualViewMode=="Final","Final image mode requires existing Final settings");
            try{capture.BeginSingleFinalCapture(folder);}catch{capture.EndSingleFinalCapture();throw;}
            if(explicitRequest)
            {
                target.enabled=false;
                Require(target.targetTexture&&target.targetTexture.IsCreated(),"Explicit request requires the initialized Final HDR target");
                request=new RenderPipeline.StandardRequest{destination=target.targetTexture,mipLevel=0,slice=0,face=CubemapFace.Unknown};
            }
            Save();
        }
        Application.runInBackground=true;Application.logMessageReceived+=OnLog;RenderPipelineManager.endCameraRendering+=Rendered;
        if(explicitRequest)
        {
            RenderPipelineManager.beginCameraRendering+=CameraBegan;
            RenderPipelineManager.beginContextRendering+=ContextBegan;RenderPipelineManager.endContextRendering+=ContextEnded;
        }
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
        if(explicitRequest&&!finished)SubmitExplicitFrame();
    }
    void ExplicitFailure(string reason){errors++;firstError=firstError??reason;}
    void CameraBegan(ScriptableRenderContext context,Camera camera)
    {
        if(camera!=target||finished)return;
        result.cameraBegins++;if(!insideRequest)ExplicitFailure("Unrequested automatic target-camera render");
    }
    void ContextBegan(ScriptableRenderContext context,List<Camera> cameras)
    {
        if(finished||!cameras.Contains(target))return;
        result.contextBegins++;if(!insideRequest)ExplicitFailure("Unrequested target render context");
    }
    void ContextEnded(ScriptableRenderContext context,List<Camera> cameras)
    {
        if(finished||!cameras.Contains(target))return;
        result.contextEnds++;if(!insideRequest)ExplicitFailure("Unrequested target render context completion");
    }
    void RemoveExplicitCallbacks()
    {
        if(!explicitRequest)return;
        RenderPipelineManager.beginCameraRendering-=CameraBegan;
        RenderPipelineManager.beginContextRendering-=ContextBegan;RenderPipelineManager.endContextRendering-=ContextEnded;
    }
    void SubmitExplicitFrame()
    {
        try
        {
            Require(!target.enabled&&target.gameObject.activeInHierarchy&&target.targetTexture==request.destination&&request.destination.IsCreated(),"Explicit request camera/target changed");
            result.cameraDisabledDuringRequests=!target.enabled;
            result.renderRequestSupported=RenderPipeline.SupportsRenderRequest(target,request);
            if(!result.renderRequestSupported)return; // Existing startup deadline still applies.
            Require(lastRequestEngine!=Time.frameCount,"More than one explicit request per engine frame");
            lastRequestEngine=Time.frameCount;result.requests++;insideRequest=true;
            try{global::HybridLumenGI.StartupStageProbe.Submit(target,request);}finally{insideRequest=false;}
            Require(result.requests==result.cameraBegins&&result.requests==result.cameraEnds&&result.requests==result.contextBegins&&result.requests==result.contextEnds&&result.requests==frames,"Explicit request camera/context receipt closure failed");
            Require(errors==0,firstError??"Explicit request reported an error");
            // Capture after the entire request/context completes, on the same engine frame.
            // This CPU startup diagnosis does not issue an HDR readback.
        }
        catch(Exception e){ExplicitFailure(e.ToString());Finish(false);}
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
            if(explicitRequest)
            {
                result.cameraEnds++;
                Require(insideRequest&&result.cameraEnds==result.requests&&result.cameraBegins==result.requests,"Duplicate or unrequested explicit camera receipt");
            }
            Require(lastEngine<0||Time.frameCount==lastEngine+1,"Duplicate/skipped target-camera receipt");
            Require(feature.isActive,"Feature disabled during ordinary Release run");
            frames++;lastEngine=Time.frameCount;
            if(frames==1){firstRendered=Time.realtimeSinceStartupAsDouble;result.firstRenderEngine=lastEngine;result.firstRenderWaitSeconds=firstRendered-started;Require(lastEngine-startEngine<=120&&result.firstRenderWaitSeconds<=900,"First render exceeded existing startup limit");}
            double elapsed=Time.realtimeSinceStartupAsDouble-firstRendered;
            int slot=steady?Math.Min(60,(int)(elapsed/5)):-1;
            if(steady?slot!=lastSlot:frames==1||frames==12)
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
                if(steady?elapsed>=60:frames>=12)
                {
                    Require(d!=null&&row.giFrame>0&&row.hardwareBackend&&row.hardwareMeshes>0&&row.readyCards>0&&row.publishedInstances>0&&row.hardwareMaterialUnknownRecords==0&&
                        row.hardwareMaterialStatus=="Uploads and both consumers bound; GPU completion unproven","Ordinary Release GI preparation/binding did not become ready");
                    Require(previousQualified==null||row.giFrame>previousQualified.giFrame,"GI execution frame did not progress");previousQualified=row;
                }
            }
            if(steady?elapsed>=300:frames==12)
            {
                // Final HDR target is unchanged; no image is read back in this diagnosis.
                quitPending=true;
            }
        }
        catch(Exception e){errors++;firstError=firstError??e.ToString();}
    }
    void Save(){if(folder!=null&&Directory.Exists(folder))File.WriteAllText(Path.Combine(folder,"release-result.json"),JsonUtility.ToJson(result,true));}
    void Finish(bool complete)
    {
                using var __startupFinish=global::HybridLumenGI.StartupStageProbe.Measure(target,"Host.Finish");
        if(finished)return;global::HybridLumenGI.StartupStageProbe.Stop(target);finished=true;RemoveExplicitCallbacks();RenderPipelineManager.endCameraRendering-=Rendered;Application.logMessageReceived-=OnLog;receipts?.Dispose();receipts=null;
        try{finalCapture?.EndSingleFinalCapture();}catch(Exception e){errors++;firstError=firstError??("Final target cleanup: "+e);}
        if(explicitRequest&&target)target.enabled=false;
        result.actualCameraFrames=frames;result.lastEngine=lastEngine;result.errors=errors;result.error=firstError;
        result.status=complete&&(steady?result.elapsedSeconds>=300:frames==12)&&errors==0?"completed-finite-release-check":"failed";
        Save();Debug.Log("LOCAL_RELEASE_RESULT "+JsonUtility.ToJson(result));Application.Quit(result.status=="completed-finite-release-check"?0:1);
    }
    void OnApplicationQuit()
    {
        global::HybridLumenGI.StartupStageProbe.Stop(target);
        if(!verify||finished)return;
        RemoveExplicitCallbacks();RenderPipelineManager.endCameraRendering-=Rendered;Application.logMessageReceived-=OnLog;
        try{finalCapture?.EndSingleFinalCapture();}catch(Exception e){errors++;firstError=firstError??("Final target cleanup: "+e);}
        if(explicitRequest&&target)target.enabled=false;
        result.actualCameraFrames=frames;result.lastEngine=lastEngine;result.errors=errors;result.error=firstError;result.status="closed-before-finite-check";Save();receipts?.Dispose();
    }
}
