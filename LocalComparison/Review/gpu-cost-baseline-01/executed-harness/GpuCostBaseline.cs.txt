// Single-purpose test-project observer; no production transport or query implementation.
using System;
using System.Collections;
using System.IO;
using System.Reflection;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using HybridLumenGI;

public sealed class GpuCostBaseline : MonoBehaviour
{
    const int WarmupLimit=256,Window=512,Drain=32,Limit=800;
    const BindingFlags Fields=BindingFlags.Instance|BindingFlags.Public|BindingFlags.NonPublic;
    ComparisonCapture capture;RuntimeAuditProbe probe;HybridLumenGIRendererFeature feature;
    HybridLumenGIRendererFeature.Settings settings;
    RenderTexture target;Mesh dynamicMesh;string directory,settingsJson,failure;
    Vector3 cameraPosition,doorPosition;Quaternion cameraRotation;
    object state;FieldInfo[] fields;
    HybridLumenGINativeGpuTiming timing;HybridLumenGIGpuBudgetController controller;
    HybridLumenGIScene scene;HybridLumenGISurfaceCache surface;HybridLumenGIGlobalSdf global;
    HybridLumenGIHardwareBackend hardware;HybridLumenGIReceiverHistory receiver;
    HybridLumenGICacheScheduler scheduler;HybridLumenGIHlodReadback readiness;
    static readonly string[] Names={"frame","width","height","fullWidth","fullHeight","lastHardware","useNativeGpuTiming",
        "effectiveBudget","gpuGeneration","receiverIdentityEnabled","receiverIdentityDraws","receiverUnknownRectangles",
        "hardwareMaterialStatus","hardwareMaterialUnknownRecords","hardwareMaterialFrameBytes","gpuSettings"};
    static readonly FieldInfo TokenId=typeof(HybridLumenGINativeGpuTiming.FrameToken).GetField("Id",Fields),
        TokenOwner=typeof(HybridLumenGINativeGpuTiming.FrameToken).GetField("Owner",Fields),
        TokenEpoch=typeof(HybridLumenGINativeGpuTiming.FrameToken).GetField("Epoch",Fields);
    readonly Frame[] frames=new Frame[Limit];
    readonly HybridLumenGINativeGpuTiming.CompletedSample[] completions=new HybridLumenGINativeGpuTiming.CompletedSample[Limit];
    int count,sampleCount,readyStreak,start=-1,end=-1,lastEngine=-1,startupFrame;
    Frame anchor;bool finishing,finished;double startupTime;
    [Serializable] struct Frame
    {
        public int index,engineFrame,giFrame,width,height,fullWidth,fullHeight,generation,stage;
        public ulong token,owner,deviceEpoch;public long epoch;
        public bool native,hardware,dispatchable,identity,published,feedback,ready,deformation;
        public int instances,warming,capacityPending,cards,cardPending,globalReady,globalPending,globalUpdated,meshes,unrepresented,
            identityDraws,identityUnknown,materialUnknown,patchQuota,captureQuota,brickQuota,patchesScheduled,rtasPending;
        public long materialBytes,uploadBytes;public double scale;
        public string materialStatus,timingStatus;
        public ulong completed,exported,unexported,invalid,cancelled,timedOut,feedbackRejected;
        public int buffered,pending;
    }
    [Serializable] class Sample
    {
        public ulong token,owner,deviceEpoch,frequency,begin0,end0,begin1,end1,begin2,end2;
        public int generation,sourceFrame,readFrame;public long epoch;
        public Sample(HybridLumenGINativeGpuTiming.CompletedSample s)
        {token=s.Token;owner=s.Owner;deviceEpoch=s.DeviceEpoch;frequency=s.Frequency;begin0=s.Begin0;end0=s.End0;begin1=s.Begin1;end1=s.End1;begin2=s.Begin2;end2=s.End2;
         generation=s.Generation;sourceFrame=s.SourceFrame;readFrame=s.ReadFrame;epoch=s.Epoch;}
    }
    [Serializable] class Run
    {
        public string status,error,unity,gpu,api,driver,scene,scope;
        public int warmupLimit=WarmupLimit,window=Window,drainLimit=Drain,frameLimit=Limit,frames,completions,sourceStart,sourceEnd,firstEngineFrame;
        public bool measureOnly,adaptive;public float targetMs;
        public string scopeExclusions="CPU preparation, out-of-scope uploads/RenderGraph work and whole-app GPU time. Queue intervals can include barriers/waits. Finite descriptive statistics only.";
    }
    static object Field(object o,string n)=>o?.GetType().GetField(n,Fields)?.GetValue(o);
    T Read<T>(int i)=>(T)fields[i].GetValue(state);
    static string Arg(string name){var a=Environment.GetCommandLineArgs();int i=Array.IndexOf(a,name);return i>=0&&i+1<a.Length?a[i+1]:null;}
    public static void Configure(ComparisonCapture c)
    {
        // Called by the existing AfterSceneLoad entry, before either original Start.
        c.enabled=false;var p=UnityEngine.Object.FindFirstObjectByType<RuntimeAuditProbe>();
        if(!p)throw new Exception("Functional source probe missing");p.enabled=false;
        var observer=c.gameObject.AddComponent<GpuCostBaseline>();observer.capture=c;observer.probe=p;
    }
    void Start()
    {
        try
        {
            string root=Arg("-gpuCostOutput");if(!Path.IsPathRooted(root))throw new Exception("Explicit output required");
            directory=Path.Combine(root,DateTime.UtcNow.ToString("yyyyMMdd-HHmmss")+"-"+Guid.NewGuid().ToString("N"));Directory.CreateDirectory(directory);
            feature=(HybridLumenGIRendererFeature)capture.feature;settings=(HybridLumenGIRendererFeature.Settings)Field(feature,"settings");
            File.WriteAllText(Path.Combine(directory,"feature-before.json"),JsonUtility.ToJson(feature,true));
            settings.preferHardwareTracing=true;settings.measureGpuCost=true;settings.adaptiveGpuBudget=false;settings.targetGpuMilliseconds=0;settings.preferNativeGpuTiming=true;
            feature.SetActive(true);settingsJson=JsonUtility.ToJson(settings);
            File.WriteAllText(Path.Combine(directory,"feature-measure.json"),JsonUtility.ToJson(feature,true));
            if(SystemInfo.graphicsDeviceType!=GraphicsDeviceType.Direct3D12||!SystemInfo.supportsInlineRayTracing)throw new Exception("DX12 inline RT required");
            var camera=capture.camera;var data=camera.GetUniversalAdditionalCameraData();
            if(camera.stereoEnabled||data.renderType!=CameraRenderType.Base||data.cameraStack.Count!=0)throw new Exception("Single base camera required");
            target=new RenderTexture(640,360,24,RenderTextureFormat.ARGBFloat,RenderTextureReadWrite.Linear)
                {name="Fixed cost baseline HDR",antiAliasing=1,useMipMap=false,autoGenerateMips=false,useDynamicScale=false};
            if(!target.Create())throw new Exception("Fixed HDR target failed");
            camera.targetTexture=target;camera.allowHDR=true;camera.allowMSAA=false;camera.allowDynamicResolution=false;camera.enabled=true;data.renderPostProcessing=false;
            camera.transform.SetPositionAndRotation(capture.colorView.position,capture.colorView.rotation);
            cameraPosition=camera.transform.position;cameraRotation=camera.transform.rotation;doorPosition=capture.door.localPosition;
            // The same initial snapshot as RuntimeAuditProbe.Start, with no later deformation events.
            dynamicMesh=Instantiate(probe.deformation.GetComponent<MeshFilter>().sharedMesh);
            probe.deformation.GetComponent<MeshFilter>().sharedMesh=dynamicMesh;probe.deformation.RequestCapture(dynamicMesh);
            Application.runInBackground=true;startupFrame=Time.frameCount;startupTime=Time.realtimeSinceStartupAsDouble;
            Application.logMessageReceived+=Log;RenderPipelineManager.endCameraRendering+=Rendered;
        }
        catch(Exception e){Fail(e.ToString());}
    }
    void Bind()
    {
        var cameras=Field(Field(feature,"pass"),"cameras") as IDictionary;
        if(cameras==null)throw new Exception("Camera state absent");
        foreach(var candidate in cameras.Values)if(ReferenceEquals(Field(candidate,"camera"),capture.camera)){if(state!=null)throw new Exception("Ambiguous camera state");state=candidate;}
        if(state==null)throw new Exception("Target camera state absent");
        fields=new FieldInfo[Names.Length];for(int i=0;i<Names.Length;i++)fields[i]=state.GetType().GetField(Names[i],Fields)??throw new Exception("Missing field "+Names[i]);
        timing=(HybridLumenGINativeGpuTiming)Field(state,"nativeGpuTiming");controller=(HybridLumenGIGpuBudgetController)Field(state,"gpuBudget");
        scene=(HybridLumenGIScene)Field(state,"scene");surface=(HybridLumenGISurfaceCache)Field(state,"surfaceCache");global=(HybridLumenGIGlobalSdf)Field(state,"globalSdf");
        hardware=(HybridLumenGIHardwareBackend)Field(state,"hardware");receiver=(HybridLumenGIReceiverHistory)Field(state,"receiverHistory");
        scheduler=(HybridLumenGICacheScheduler)Field(state,"scheduler");readiness=(HybridLumenGIHlodReadback)Field(state,"readiness");
    }
    void Rendered(ScriptableRenderContext context,Camera camera)
    {
        if(camera!=capture.camera||finishing||finished)return;
        try
        {
            if(count>=Limit||lastEngine>=0&&Time.frameCount!=lastEngine+1)throw new Exception("Duplicate/skipped receipt or frame limit");
            if(state==null)Bind();
            var budget=Read<HybridLumenGIGpuBudgetController.Budget>(7);var token=timing.CurrentFrameToken;
            var r=new Frame{index=count,engineFrame=Time.frameCount,giFrame=Read<int>(0),width=Read<int>(1),height=Read<int>(2),fullWidth=Read<int>(3),fullHeight=Read<int>(4),
                hardware=Read<bool>(5),native=Read<bool>(6),generation=Read<int>(8),identity=Read<bool>(9),identityDraws=Read<int>(10),identityUnknown=Read<int>(11),
                materialStatus=Read<string>(12),materialUnknown=Read<int>(13),materialBytes=Read<long>(14),
                token=(ulong)TokenId.GetValue(token),owner=(ulong)TokenOwner.GetValue(token),epoch=(long)TokenEpoch.GetValue(token),deviceEpoch=timing.DeviceEpoch,
                published=receiver.IsPublished,dispatchable=hardware.CanDispatch,feedback=controller.FeedbackActive,
                instances=scene.PublishedCount,warming=scene.WarmingCount,capacityPending=scene.PendingCapacity,cards=surface.ReadyCards,cardPending=surface.PendingCards,
                globalReady=global.ReadyBrickCount,globalPending=global.PendingBrickCount,globalUpdated=global.UpdatedBrickCount,
                meshes=hardware.MeshCount,unrepresented=hardware.FallbackCount,patchQuota=budget.CachePatches,captureQuota=budget.SurfaceCaptures,brickQuota=budget.GlobalBricks,scale=budget.Scale,
                patchesScheduled=scheduler.SelectedCount,rtasPending=HybridLumenGIRtasBudget.PendingDemands,uploadBytes=HybridLumenGIRayTexturePool.UploadBytesUsed,
                deformation=HybridLumenGIDeformedMesh.HasSnapshot(probe.deformation.GetComponent<Renderer>()),timingStatus=timing.Status.ToString()};
            while(timing.TryDequeueCompleted(out var s))
            {if(sampleCount==completions.Length)throw new Exception("Completion export overflow");completions[sampleCount++]=s;}
            r.completed=timing.CompletedResults;r.exported=timing.ExportedResults;r.unexported=timing.UnexportedResults;r.invalid=timing.InvalidCompletedResults;
            r.cancelled=timing.CancelledSubmissions;r.timedOut=timing.TimedOutSubmissions;r.feedbackRejected=timing.RejectedResults;r.buffered=timing.BufferedCompletedRecords;r.pending=timing.PendingCount;
            r.ready=token.IsValid&&token.EngineFrame==Time.frameCount&&r.hardware&&r.dispatchable&&r.instances==22&&r.warming==0&&r.capacityPending==0&&r.cards==132&&r.cardPending==0&&r.globalPending==0&&
                r.meshes==22&&r.unrepresented==0&&r.identity&&r.published&&r.identityDraws>0&&r.materialUnknown==0&&r.materialBytes>0&&
                r.materialStatus=="Uploads and both consumers bound; GPU completion unproven"&&r.deformation&&r.rtasPending==0&&!readiness.Pending&&r.uploadBytes==0;
            r.stage=start<0?0:Time.frameCount<=end?1:2;frames[count++]=r;lastEngine=Time.frameCount;
            // Product initialization/backend changes explicitly invalidate the current
            // timing ticket. Only that known warmup transition can lack a submission.
            bool warmupInvalidation=start<0&&!token.IsValid&&timing.Status==HybridLumenGINativeGpuTiming.TimingStatus.Invalidated;
            if(!r.native||!timing.Available||(!token.IsValid||token.EngineFrame!=Time.frameCount)&&!warmupInvalidation)
                throw new Exception("NativeDX12 submission unavailable: "+r.timingStatus);
            if(settings.adaptiveGpuBudget||!settings.measureGpuCost||settings.targetGpuMilliseconds!=0||r.feedback||r.scale!=1||
                r.patchQuota!=Mathf.Clamp(settings.cachePatchesPerFrame,1,4096)||r.captureQuota!=Mathf.Clamp(settings.surfaceCapturesPerFrame,1,96)||
                r.brickQuota!=(settings.globalSdfEnabled?Mathf.Clamp(settings.globalSdfBricksPerFrame,1,128):0))throw new Exception("Fixed static quotas changed");
            if(camera.targetTexture!=target||camera.transform.position!=cameraPosition||camera.transform.rotation!=cameraRotation||capture.door.localPosition!=doorPosition||Read<string>(15)!=settingsJson)
                throw new Exception("Frozen scene/configuration changed");
            if(start<0)
            {
                readyStreak=r.ready&&(readyStreak==0||SameIdentity(r,anchor))?readyStreak+1:0;anchor=r;
                if(readyStreak==16){start=Time.frameCount+1;end=start+Window-1;}
                else if(count==WarmupLimit)throw new Exception("Readiness absent within 256 target-camera frames");
            }
            else
            {
                if(!r.ready||!SameIdentity(r,anchor))throw new Exception("Window/drain readiness or submission identity changed");
                if(r.invalid!=anchor.invalid||r.unexported!=anchor.unexported||r.timedOut!=anchor.timedOut||r.cancelled!=anchor.cancelled)
                    throw new Exception("Window/drain invalid, unexported, timed out or cancelled submission");
                if(Time.frameCount==end+Drain)finishing=true;
            }
        }
        catch(Exception e){Fail(e.ToString());}
    }
    static bool SameIdentity(Frame a,Frame b)=>a.owner==b.owner&&a.generation==b.generation&&a.deviceEpoch==b.deviceEpoch&&a.epoch==b.epoch&&
        a.width==b.width&&a.height==b.height&&a.fullWidth==b.fullWidth&&a.fullHeight==b.fullHeight;
    void Update()
    {
        if(finished)return;
        if(finishing){Finish();return;}
        if(lastEngine<0&&(Time.frameCount-startupFrame>120||Time.realtimeSinceStartupAsDouble-startupTime>900))Fail("First render receipt timeout");
        else if(lastEngine>=0&&Time.frameCount>lastEngine+1)Fail("Target camera stopped rendering");
    }
    void Log(string text,string stack,LogType type){if(type==LogType.Error||type==LogType.Assert||type==LogType.Exception)Fail("Unity "+type+": "+text);}
    void Fail(string text){if(failure==null)failure=text;finishing=true;}
    void Finish()
    {
        finished=true;RenderPipelineManager.endCameraRendering-=Rendered;Application.logMessageReceived-=Log;
        try{capture.camera.enabled=false;capture.camera.targetTexture=null;if(target){target.Release();Destroy(target);}}
        catch(Exception e){failure=failure??("Target cleanup: "+e);}
        try
        {
            var run=new Run{status=failure==null?"collected":"failed",error=failure,unity=Application.unityVersion,gpu=SystemInfo.graphicsDeviceName,
                api=SystemInfo.graphicsDeviceType.ToString(),driver=SystemInfo.graphicsDeviceVersion,scene=gameObject.scene.path,
                scope="Fixed Functional DXR; preallocated CPU receipts and validated native completions only; no image/readback/per-frame IO.",
                frames=count,completions=sampleCount,sourceStart=start,sourceEnd=end,firstEngineFrame=count==0?-1:frames[0].engineFrame,
                measureOnly=settings!=null&&settings.measureGpuCost,adaptive=settings!=null&&settings.adaptiveGpuBudget,targetMs=settings==null?-1:settings.targetGpuMilliseconds};
            if(directory!=null)
            {
                File.WriteAllText(Path.Combine(directory,"run.json"),JsonUtility.ToJson(run,true));
                using(var w=new StreamWriter(Path.Combine(directory,"frames.jsonl")))for(int i=0;i<count;i++)w.WriteLine(JsonUtility.ToJson(frames[i]));
                using(var w=new StreamWriter(Path.Combine(directory,"completions.jsonl")))for(int i=0;i<sampleCount;i++)w.WriteLine(JsonUtility.ToJson(new Sample(completions[i])));
            }
            Debug.Log("GPU_COST_BASELINE_"+(failure==null?"COLLECTED":"FAILED")+" frames="+count+" samples="+sampleCount+" "+failure);
        }
        catch(Exception e){failure=failure??e.ToString();Debug.LogError("GPU_COST_BASELINE_WRITE_FAILED "+e);}
        finally{Application.Quit(failure==null?0:1);}
    }
}
