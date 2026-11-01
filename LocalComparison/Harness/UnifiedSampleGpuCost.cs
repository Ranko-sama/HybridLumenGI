// Temporary Player observer. Reuses the product's completed native timestamp records.
// The optional door workload runs the ordinary sample interaction on the existing backbuffer.
using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Reflection;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using HybridLumenGI;

public sealed class UnifiedSampleGpuCost : MonoBehaviour
{
    const int WarmupLimit=256,Window=512,Drain=32,Limit=800;
    const string ExpectedScene="Assets/UnifiedRelease74/Generated/Variant/UnifiedSample.unity";
    const BindingFlags Fields=BindingFlags.Instance|BindingFlags.Public|BindingFlags.NonPublic;
    HybridLumenGIUnifiedSample sample;Camera targetCamera;HybridLumenGIRendererFeature feature;
    HybridLumenGIRendererFeature.Settings settings;HybridLumenGIAssetPageStreamer streamer;
    HybridLumenGIStreamedRepresentation aggregate;HybridLumenGIStreamedRepresentation[] details;
    HashSet<HybridLumenGIProxy> visible;List<HybridLumenGIProxy> published,target;
    HybridLumenGIUnifiedSample.Ledger startLedger,endLedger;
    HybridLumenGIUnifiedSampleInteraction interaction;
    Transform door;
    bool doorMotion, memoryWindowCaptured;
    HybridLumenGIVideoMemory.Snapshot memoryWindow;
    object state;FieldInfo[] fields;HybridLumenGINativeGpuTiming timing;
    HybridLumenGIGpuBudgetController controller;HybridLumenGIScene scene;
    HybridLumenGISurfaceCache surface;HybridLumenGIGlobalSdf global;
    HybridLumenGIHardwareBackend geometry;HybridLumenGIReceiverHistory receiver;
    HybridLumenGICacheScheduler scheduler;
    string outputRoot,directory,settingsBefore,settingsJson,failure;
    Vector3 cameraPosition;Quaternion cameraRotation;Matrix4x4 cameraProjection;
    int count,sampleCount,readyStreak,start=-1,end=-1,lastEngine=-1,startupFrame,windowCompletions;
    double startupTime;Frame anchor;bool finishing,finished,subscribed;
    readonly Frame[] frames=new Frame[Limit];
    readonly HybridLumenGINativeGpuTiming.CompletedSample[] completions=new HybridLumenGINativeGpuTiming.CompletedSample[Limit];
    readonly bool[] seen=new bool[Window];
    static readonly string[] Names={"frame","width","height","fullWidth","fullHeight","lastHardware","useNativeGpuTiming",
        "effectiveBudget","gpuGeneration","receiverIdentityEnabled","receiverIdentityDraws","receiverUnknownRectangles",
        "hardwareMaterialStatus","hardwareMaterialUnknownRecords","hardwareMaterialFrameBytes","gpuSettings","exactSoftwareGeometry"};
    static readonly FieldInfo TokenId=typeof(HybridLumenGINativeGpuTiming.FrameToken).GetField("Id",Fields),
        TokenOwner=typeof(HybridLumenGINativeGpuTiming.FrameToken).GetField("Owner",Fields),
        TokenEpoch=typeof(HybridLumenGINativeGpuTiming.FrameToken).GetField("Epoch",Fields);

    [Serializable] struct Frame
    {
        public bool doorMoving;
        public Vector3 doorPosition;
        public int index,engineFrame,giFrame,width,height,fullWidth,fullHeight,generation,stage;
        public ulong token,owner,deviceEpoch;public long epoch;
        public bool native,hardware,exactSoftware,identity,published,feedback,ready,groupPublished,groupTransitioning;
        public int instances,warming,capacityPending,cards,cardPending,globalReady,globalPending,globalUpdated,
            meshes,unrepresented,identityDraws,identityUnknown,materialUnknown,patchQuota,captureQuota,brickQuota,patchesScheduled,
            pagePending,pageFailed,pageActiveOperations,pageRetiringLeases,visibleMembers,groupMembers;
        public long materialBytes,uploadBytes,pageIoBytesInFlight;public double scale;
        public string materialStatus,timingStatus;
        public ulong completed,exported,unexported,invalid,cancelled,timedOut,feedbackRejected;
        public int buffered,pending;
    }
    [Serializable] sealed class Sample
    {
        public ulong token,owner,deviceEpoch,frequency,begin0,end0,begin1,end1,begin2,end2;
        public int generation,sourceFrame,readFrame;public long epoch;
        public Sample(HybridLumenGINativeGpuTiming.CompletedSample s)
        {token=s.Token;owner=s.Owner;deviceEpoch=s.DeviceEpoch;frequency=s.Frequency;begin0=s.Begin0;end0=s.End0;begin1=s.Begin1;end1=s.End1;begin2=s.Begin2;end2=s.End2;
         generation=s.Generation;sourceFrame=s.SourceFrame;readFrame=s.ReadFrame;epoch=s.Epoch;}
    }
    [Serializable] sealed class Run
    {
        public string status,error,unity,gpu,api,driver,scene,scope,outputDirectory;
        public int warmupLimit=WarmupLimit,window=Window,drainLimit=Drain,frameLimit=Limit,frames,completions,windowCompletions,
            sourceStart,sourceEnd,firstEngineFrame,backbufferWidth=960,backbufferHeight=540,vSyncCount,targetFrameRate;
        public bool measureOnly,adaptive,doorMotion,memoryWindowCaptured;public float targetMs;
        public HybridLumenGIVideoMemory.Snapshot memoryWindow;
        public string[] scopes={"ReceiverCapture","Transport","Composite"};
        public string scopeExclusions="CPU preparation, uploads outside scopes, query resolve, whole-app GPU time and total driver VRAM. Queue intervals can include barriers/waits. Ledger estimates are not additive or a total-VRAM measurement.";
    }
    static object Field(object o,string name)=>o?.GetType().GetField(name,Fields)?.GetValue(o);
    T Read<T>(int index)=>(T)fields[index].GetValue(state);
    static void Require(bool value,string message){if(!value)throw new InvalidOperationException(message);}

    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
    static void Install()
    {
        string[] args=Environment.GetCommandLineArgs();int i=Array.IndexOf(args,"-gpuCostOutput");
        if(i<0)return; // The ordinary Player remains unchanged without this flag.
        var host=new GameObject("Unified sample fixed GPU cost observer").AddComponent<UnifiedSampleGpuCost>();
        host.outputRoot=i+1<args.Length&&!args[i+1].StartsWith("-",StringComparison.Ordinal)?args[i+1]:null;
        try
        {
            var samples=UnityEngine.Object.FindObjectsByType<HybridLumenGIUnifiedSample>(FindObjectsSortMode.None);
            Require(samples.Length==1,"Exactly one existing UnifiedSample is required");host.sample=samples[0];
            var inputs=UnityEngine.Object.FindObjectsByType<HybridLumenGIUnifiedSampleInteraction>(FindObjectsSortMode.None);
            host.doorMotion=Array.IndexOf(args,"-hlgiDoorMotion")>=0;
            if(host.doorMotion)
            {
                Require(inputs.Length==1 && inputs[0].isActiveAndEnabled,"Expected one ordinary interaction");
                host.interaction=inputs[0];
                var motion=Field(host.interaction,"door") as HybridLumenGIValidationMotion;
                Require(motion,"The sample has no moving door");
                host.door=motion.transform;
                typeof(HybridLumenGIUnifiedSampleInteraction).GetField("showControls",Fields).SetValue(host.interaction,false);
                host.sample.MeasureVideoMemory=false;
            }
            else foreach(var input in inputs)input.enabled=false;
            host.sample.ShowControls=false;
        }
        catch(Exception error){host.Fail(error.ToString());}
    }
    void Start()
    {
        try
        {
            Require(!string.IsNullOrWhiteSpace(outputRoot)&&Path.IsPathRooted(outputRoot),"Explicit absolute -gpuCostOutput directory required");
            directory=Path.Combine(outputRoot,DateTime.UtcNow.ToString("yyyyMMdd-HHmmss")+"-"+Guid.NewGuid().ToString("N"));Directory.CreateDirectory(directory);
            if(failure!=null)return;
            Require(sample&&sample.isActiveAndEnabled&&sample.gameObject.scene.path==ExpectedScene,"Expected saved UnifiedSample scene/controller required");
            targetCamera=Field(sample,"targetCamera") as Camera;feature=Field(sample,"feature") as HybridLumenGIRendererFeature;
            streamer=Field(sample,"streamer") as HybridLumenGIAssetPageStreamer;
            aggregate=Field(sample,"aggregate") as HybridLumenGIStreamedRepresentation;
            details=Field(sample,"details") as HybridLumenGIStreamedRepresentation[];
            visible=Field(sample,"visible") as HashSet<HybridLumenGIProxy>;
            Require(targetCamera&&feature&&feature.isActive&&streamer&&aggregate&&details!=null&&details.Length>0&&visible!=null,"Existing sample references missing");
            published=new List<HybridLumenGIProxy>(details.Length+1);target=new List<HybridLumenGIProxy>(details.Length+1);
            settings=Field(feature,"settings") as HybridLumenGIRendererFeature.Settings;
            Require(settings!=null&&settings.preferHardwareTracing==doorMotion&&settings.exactSoftwareTracing,"Unexpected authored backend preference");
            settingsBefore=JsonUtility.ToJson(settings,true);
            settings.measureGpuCost=true;settings.preferNativeGpuTiming=true;settings.adaptiveGpuBudget=false;settings.targetGpuMilliseconds=0;
            settingsJson=JsonUtility.ToJson(settings);
            Require(SystemInfo.graphicsDeviceType==GraphicsDeviceType.Direct3D12,"Native timing requires DX12");
            var data=targetCamera.GetUniversalAdditionalCameraData();
            Require(targetCamera.isActiveAndEnabled&&targetCamera.targetTexture==null&&!targetCamera.stereoEnabled&&data.renderType==CameraRenderType.Base&&data.cameraStack.Count==0,"Keep one ordinary enabled Base camera on its backbuffer");
            Require(Screen.width==960&&Screen.height==540&&targetCamera.pixelWidth==960&&targetCamera.pixelHeight==540,"Launch the saved scene at 960x540; observer does not resize");
            cameraPosition=targetCamera.transform.position;cameraRotation=targetCamera.transform.rotation;cameraProjection=targetCamera.projectionMatrix;
            Application.runInBackground=true;startupFrame=Time.frameCount;startupTime=Time.realtimeSinceStartupAsDouble;
            Application.logMessageReceived+=Log;RenderPipelineManager.endCameraRendering+=Rendered;subscribed=true;
        }
        catch(Exception error){Fail(error.ToString());}
    }
    void BindCurrent()
    {
        var cameras=Field(Field(feature,"pass"),"cameras") as IDictionary;object current=null;
        Require(cameras!=null,"Camera state dictionary absent");
        foreach(var candidate in cameras.Values)if(ReferenceEquals(Field(candidate,"camera"),targetCamera))
        {Require(current==null,"Ambiguous target camera state");current=candidate;}
        Require(current!=null,"Target camera state absent");
        if(ReferenceEquals(current,state))return;
        Require(start<0,"Camera state changed inside the fixed window/drain");state=current;readyStreak=0;
        fields=new FieldInfo[Names.Length];for(int i=0;i<Names.Length;i++)fields[i]=state.GetType().GetField(Names[i],Fields)??throw new Exception("Missing field "+Names[i]);
        timing=(HybridLumenGINativeGpuTiming)Field(state,"nativeGpuTiming");controller=(HybridLumenGIGpuBudgetController)Field(state,"gpuBudget");
        scene=(HybridLumenGIScene)Field(state,"scene");surface=(HybridLumenGISurfaceCache)Field(state,"surfaceCache");global=(HybridLumenGIGlobalSdf)Field(state,"globalSdf");
        geometry=(HybridLumenGIHardwareBackend)Field(state,doorMotion?"hardware":"softwareGeometry");receiver=(HybridLumenGIReceiverHistory)Field(state,"receiverHistory");
        scheduler=(HybridLumenGICacheScheduler)Field(state,"scheduler");
    }
    void Rendered(ScriptableRenderContext context,Camera camera)
    {
        if(camera!=targetCamera||finishing||finished)return;
        try
        {
            Require(count<Limit&&(lastEngine<0||Time.frameCount==lastEngine+1),"Duplicate/skipped target receipt or 800-frame limit");BindCurrent();
            var budget=Read<HybridLumenGIGpuBudgetController.Budget>(7);var token=timing.CurrentFrameToken;
            var r=new Frame{index=count,engineFrame=Time.frameCount,giFrame=Read<int>(0),width=Read<int>(1),height=Read<int>(2),fullWidth=Read<int>(3),fullHeight=Read<int>(4),
                hardware=Read<bool>(5),native=Read<bool>(6),generation=Read<int>(8),identity=Read<bool>(9),identityDraws=Read<int>(10),identityUnknown=Read<int>(11),
                materialStatus=Read<string>(12),materialUnknown=Read<int>(13),materialBytes=Read<long>(14),exactSoftware=Read<bool>(16),
                token=(ulong)TokenId.GetValue(token),owner=(ulong)TokenOwner.GetValue(token),epoch=(long)TokenEpoch.GetValue(token),deviceEpoch=timing.DeviceEpoch,
                published=receiver.IsPublished,feedback=controller.FeedbackActive,instances=scene.PublishedCount,warming=scene.WarmingCount,
                capacityPending=scene.PendingCapacity,cards=surface.ReadyCards,cardPending=surface.PendingCards,
                globalReady=global.ReadyBrickCount,globalPending=global.PendingBrickCount,globalUpdated=global.UpdatedBrickCount,
                meshes=geometry.MeshCount,unrepresented=geometry.FallbackCount,patchQuota=budget.CachePatches,captureQuota=budget.SurfaceCaptures,
                doorMoving=doorMotion&&interaction.DoorMoving,doorPosition=doorMotion?door.localPosition:default,
                brickQuota=budget.GlobalBricks,scale=budget.Scale,patchesScheduled=scheduler.SelectedCount,
                uploadBytes=HybridLumenGIRayTexturePool.UploadBytesUsed,timingStatus=timing.Status.ToString(),visibleMembers=visible.Count};
            bool publicationKnown=feature.TryGetHlodPublication(camera,aggregate.Proxy,published,target,out var publication);
            r.groupMembers=published.Count;r.groupTransitioning=publication.transitioning;
            bool complete=published.Count==1&&published[0]==aggregate.Proxy&&aggregate.HasBoundAssets;
            if(published.Count==details.Length)
            {bool all=true;foreach(var detail in details)all&=detail&&detail.HasBoundAssets&&published.Contains(detail.Proxy);complete|=all;}
            bool visibleMatches=visible.Count==published.Count;foreach(var proxy in published)visibleMatches&=visible.Contains(proxy);
            r.groupPublished=publicationKnown&&publication.preparedEngineFrame==Time.frameCount&&publication.phase==HybridLumenGIScene.PublicationPhase.Published&&complete&&visibleMatches;
            var pages=streamer.State;
            if(pages!=null)
            {
                r.pageActiveOperations=pages.ActiveOperations;r.pageIoBytesInFlight=pages.IoBytesInFlight;r.pageRetiringLeases=pages.RetiringLeases;
                for(int i=0;i<pages.States.Count;i++)
                {
                    var page=pages.States[i];
                    if(page.Status==HybridLumenGIAssetPageStreaming.Phase.Failed||page.Status==HybridLumenGIAssetPageStreaming.Phase.ReleaseFailed)r.pageFailed++;
                    if(page.Wanted&&page.Status!=HybridLumenGIAssetPageStreaming.Phase.Ready||
                        page.Status==HybridLumenGIAssetPageStreaming.Phase.LoadingBundle||page.Status==HybridLumenGIAssetPageStreaming.Phase.BundleReady||
                        page.Status==HybridLumenGIAssetPageStreaming.Phase.LoadingAsset||page.Status==HybridLumenGIAssetPageStreaming.Phase.Releasing)r.pagePending++;
                }
            }
            while(timing.TryDequeueCompleted(out var value))
            {Require(sampleCount<completions.Length,"Completion export overflow");completions[sampleCount++]=value;}
            r.completed=timing.CompletedResults;r.exported=timing.ExportedResults;r.unexported=timing.UnexportedResults;r.invalid=timing.InvalidCompletedResults;
            r.cancelled=timing.CancelledSubmissions;r.timedOut=timing.TimedOutSubmissions;r.feedbackRejected=timing.RejectedResults;r.buffered=timing.BufferedCompletedRecords;r.pending=timing.PendingCount;
            bool settled=r.warming==0&&r.capacityPending==0&&r.cardPending==0&&(!settings.globalSdfEnabled||r.globalPending==0)&&
                (!settings.receiverObjectHistory||r.identity&&r.published&&r.identityDraws>0&&r.identityUnknown==0)&&r.materialUnknown==0&&r.uploadBytes==0;
            bool movingWindow=doorMotion&&start>=0;
            // Retain the cost of recaptures, dirty bricks and uploads caused by motion.
            r.ready=token.IsValid&&token.EngineFrame==Time.frameCount&&r.native&&r.hardware==doorMotion&&r.exactSoftware!=doorMotion&&
                r.instances>0&&r.cards>0&&r.groupPublished&&!r.groupTransitioning&&streamer.Available&&pages!=null&&
                r.pagePending==0&&r.pageFailed==0&&r.pageActiveOperations==0&&r.pageIoBytesInFlight==0&&r.pageRetiringLeases==0&&
                (movingWindow ? r.doorMoving && r.groupMembers==details.Length : settled);
            r.stage=start<0?0:Time.frameCount<=end?1:2;frames[count++]=r;lastEngine=Time.frameCount;
            bool initialization=start<0&&!token.IsValid&&timing.Status==HybridLumenGINativeGpuTiming.TimingStatus.Invalidated;
            Require(r.native&&timing.Available&&((token.IsValid&&token.EngineFrame==Time.frameCount)||initialization),"NativeDX12 submission unavailable: "+r.timingStatus);
            Require(!settings.adaptiveGpuBudget&&settings.measureGpuCost&&settings.preferNativeGpuTiming&&settings.targetGpuMilliseconds==0&&!r.feedback&&r.scale==1&&
                r.patchQuota==Mathf.Clamp(settings.cachePatchesPerFrame,1,4096)&&r.captureQuota==Mathf.Clamp(settings.surfaceCapturesPerFrame,1,96)&&
                r.brickQuota==(settings.globalSdfEnabled?Mathf.Clamp(settings.globalSdfBricksPerFrame,1,128):0),"Static measurement-only quotas changed");
            Require(sample.isActiveAndEnabled&&!sample.ShowControls&&feature.isActive&&settings.preferHardwareTracing==doorMotion&&settings.exactSoftwareTracing&&
                camera.targetTexture==null&&camera.transform.position==cameraPosition&&camera.transform.rotation==cameraRotation&&camera.projectionMatrix==cameraProjection&&
                camera.pixelWidth==960&&camera.pixelHeight==540&&r.fullWidth==960&&r.fullHeight==540&&Read<string>(15)==settingsJson,"Authored camera/backend/settings changed");
            if(start<0)
            {
                readyStreak=r.ready&&(readyStreak==0||SameIdentity(r,anchor))?readyStreak+1:0;anchor=r;
                if(readyStreak==16)
                {
                    start=Time.frameCount+1;end=start+Window-1;startLedger=sample.CaptureLedger();
                    if(doorMotion){interaction.SetDoorMoving(true);sample.MeasureVideoMemory=true;}
                }
                else Require(count<WarmupLimit,"No stable readiness within 256 target-camera frames");
            }
            else
            {
                Require(r.ready&&SameIdentity(r,anchor),"Window/drain readiness, backend, size or submission identity changed");
                Require(r.invalid==anchor.invalid&&r.unexported==anchor.unexported&&r.timedOut==anchor.timedOut&&r.cancelled==anchor.cancelled,"Window/drain invalid, unexported, timed out or cancelled submission");
                if(doorMotion && Time.frameCount==end)
                {
                    memoryWindow=sample.CaptureLedger().processVideoMemory;memoryWindowCaptured=true;
                    sample.MeasureVideoMemory=false;
                }
                if(Time.frameCount==end+Drain)finishing=true;
            }
        }
        catch(Exception error){Fail(error.ToString());}
    }
    static bool SameIdentity(Frame a,Frame b)=>a.owner==b.owner&&a.generation==b.generation&&a.deviceEpoch==b.deviceEpoch&&a.epoch==b.epoch&&
        a.width==b.width&&a.height==b.height&&a.fullWidth==b.fullWidth&&a.fullHeight==b.fullHeight&&a.native==b.native&&a.hardware==b.hardware&&
        a.exactSoftware==b.exactSoftware&&a.identity==b.identity&&a.patchQuota==b.patchQuota&&a.captureQuota==b.captureQuota&&a.brickQuota==b.brickQuota&&a.scale==b.scale;
    void Update()
    {
        if(finished)return;
        // Deferred to the next engine Update, after URP has restored the ordinary target.
        if(finishing){Finish();return;}
        if(lastEngine<0&&(Time.frameCount-startupFrame>120||Time.realtimeSinceStartupAsDouble-startupTime>900))Fail("First render receipt timeout");
        else if(lastEngine>=0&&Time.frameCount>lastEngine+1)Fail("Target camera stopped rendering");
    }
    void Log(string text,string stack,LogType type){if(type==LogType.Error||type==LogType.Assert||type==LogType.Exception)Fail("Unity "+type+": "+text);}
    void Fail(string error){if(failure==null)failure=error;finishing=true;}
    void CheckWindow()
    {
        Require(start>=0&&end-start+1==Window,"Fixed window was not completed");
        for(int i=0;i<sampleCount;i++)
        {
            var s=completions[i];if(s.SourceFrame<start||s.SourceFrame>end)continue;
            int offset=s.SourceFrame-start;Require(!seen[offset],"Duplicate completed source frame");seen[offset]=true;
            Frame receipt=default;bool found=false;
            for(int j=0;j<count;j++)if(frames[j].engineFrame==s.SourceFrame){receipt=frames[j];found=true;break;}
            Require(found&&receipt.stage==1&&receipt.ready&&s.Token==receipt.token&&s.Owner==receipt.owner&&s.Generation==receipt.generation&&
                s.Epoch==receipt.epoch&&s.DeviceEpoch==receipt.deviceEpoch&&s.Frequency>0&&s.ReadFrame>=s.SourceFrame&&
                s.Begin0<=s.End0&&s.End0<=s.Begin1&&s.Begin1<=s.End1&&s.End1<=s.Begin2&&s.Begin2<=s.End2,"Completed source/receipt/timestamps mismatch");
            windowCompletions++;
        }
        Require(windowCompletions==Window,"Missing one or more of the 512 fixed source-frame completions; no partial percentiles");
    }
    void Finish()
    {
        finished=true;
        if(subscribed){RenderPipelineManager.endCameraRendering-=Rendered;Application.logMessageReceived-=Log;subscribed=false;}
        try
        {
            if(failure==null)CheckWindow();
            if(sample)endLedger=sample.CaptureLedger();
        }
        catch(Exception error){failure=failure??error.ToString();}
        try
        {
            var run=new Run{status=failure==null?"collected":"failed",error=failure,unity=Application.unityVersion,gpu=SystemInfo.graphicsDeviceName,
                api=SystemInfo.graphicsDeviceType.ToString(),driver=SystemInfo.graphicsDeviceVersion,scene=sample?sample.gameObject.scene.path:ExpectedScene,
                scope=doorMotion?"Ordinary M door cycle, fixed camera, DXR. Native GI intervals and process memory over the same source window.":"Fixed authored UnifiedSample; 960x540 ordinary backbuffer; exact-software transport; existing native ReceiverCapture/Transport/Composite completions only. No image or per-frame file IO.",
                doorMotion=doorMotion,memoryWindow=memoryWindow,memoryWindowCaptured=memoryWindowCaptured,
                outputDirectory=directory,frames=count,completions=sampleCount,windowCompletions=windowCompletions,sourceStart=start,sourceEnd=end,
                firstEngineFrame=count==0?-1:frames[0].engineFrame,measureOnly=settings!=null&&settings.measureGpuCost,adaptive=settings!=null&&settings.adaptiveGpuBudget,
                targetMs=settings==null?-1:settings.targetGpuMilliseconds,vSyncCount=QualitySettings.vSyncCount,targetFrameRate=Application.targetFrameRate};
            if(directory!=null)
            {
                File.WriteAllText(Path.Combine(directory,"run.json"),JsonUtility.ToJson(run,true));
                File.WriteAllText(Path.Combine(directory,"settings-before.json"),settingsBefore??"null");
                File.WriteAllText(Path.Combine(directory,"settings-measure.json"),settingsJson??"null");
                if(startLedger!=null)File.WriteAllText(Path.Combine(directory,"start-ledger.json"),JsonUtility.ToJson(startLedger,true));
                if(endLedger!=null)File.WriteAllText(Path.Combine(directory,"end-ledger.json"),JsonUtility.ToJson(endLedger,true));
                using(var writer=new StreamWriter(Path.Combine(directory,"frames.jsonl")))for(int i=0;i<count;i++)writer.WriteLine(JsonUtility.ToJson(frames[i]));
                using(var writer=new StreamWriter(Path.Combine(directory,"completions.jsonl")))for(int i=0;i<sampleCount;i++)writer.WriteLine(JsonUtility.ToJson(new Sample(completions[i])));
            }
            Debug.Log("UNIFIED_SAMPLE_GPU_COST_"+(failure==null?"COLLECTED":"FAILED")+" frames="+count+" windowCompletions="+windowCompletions+" "+failure);
        }
        catch(Exception error){failure=failure??error.ToString();Debug.LogError("UNIFIED_SAMPLE_GPU_COST_WRITE_FAILED "+error);}
        finally{Application.Quit(failure==null?0:1);}
    }
    void OnDisable(){if(!finished)Fail("Observer disabled before completing the fixed cost window");}
}
