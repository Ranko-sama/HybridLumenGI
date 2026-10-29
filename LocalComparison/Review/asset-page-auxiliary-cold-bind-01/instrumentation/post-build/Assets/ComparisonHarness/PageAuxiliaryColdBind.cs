// One fixed native distance-demand -> complete page binding observation. No product mutation.
using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Security.Cryptography;
using HybridLumenGI;
using UnityEngine;
using UnityEngine.Rendering;

public sealed class PageAuxiliaryColdBind : MonoBehaviour
{
    [Serializable] public sealed class FrozenPage {public string id,bundlePath,assetName,sha256;public int kind;public uint crc;public long fileBytes,residentBytes,uploadBytes;public string[] dependencies;}
    [Serializable] public sealed class Input {public string relativeRoot,platform;public string[] groupIds;public FrozenPage[] pages;public HybridLumenGIAssetPageStreaming.Budgets budgets;}
    [Serializable] public sealed class Receipt
    {
        public string stage;public int frame,engine,requests,activeOperations;public long bundles,resident,io;
        public bool bound,allReady,rendererEnabled,proxyEnabled,exactBindings;public string[] pages;
    }
    [Serializable] public sealed class Result
    {
        public string status="running",error,unity,api;public int frames,maximumFrames=120;public bool coldQualified,auxiliaryAdded,normalQuitObserved;
        public Vector3 primaryPosition,auxiliaryPosition;public float loadDistance,unloadDistance;public bool explicitObserverAbsent,distanceModeBeforeCold;
        public Receipt[] receipts;
    }
    Camera target;HybridLumenGIAssetPageStreamer streamer;HybridLumenGIStreamedRepresentation detail;
    Transform auxiliary,explicitObserver;Bounds bounds;Input input;Result result=new Result();
    readonly List<Receipt> receipts=new List<Receipt>();string folder,firstError;int lastEngine=-1;bool quitPending,quitIssued;
    static object Field(object o,string n)=>o.GetType().GetField(n,BindingFlags.Instance|BindingFlags.Public|BindingFlags.NonPublic).GetValue(o);
    static void Require(bool condition,string message){if(!condition)throw new Exception(message);}
    static string Hash(byte[] bytes){using(var h=SHA256.Create())return BitConverter.ToString(h.ComputeHash(bytes)).Replace("-","").ToLowerInvariant();}
    static string Arg(string key){var a=Environment.GetCommandLineArgs();int i=Array.IndexOf(a,key);return i>=0&&i+1<a.Length?a[i+1]:null;}
    public static bool TryStart()
    {
        if(Array.IndexOf(Environment.GetCommandLineArgs(),"-auxiliaryColdBind")<0)return false;
        PageAuxiliaryColdBind mode=null;
        try
        {
            var capture=UnityEngine.Object.FindFirstObjectByType<ComparisonCapture>();
            Require(capture&&capture.camera&&capture.feature,"Existing capture references missing");capture.enabled=false;
            var probe=UnityEngine.Object.FindFirstObjectByType<StreamingAuditProbe>();Require(probe&&probe.detail&&probe.streamer,"Existing streaming references missing");
            probe.enabled=false;
            foreach(var p in UnityEngine.Object.FindObjectsByType<RuntimeAuditProbe>(FindObjectsInactive.Include,FindObjectsSortMode.None))p.enabled=false;
            foreach(var p in UnityEngine.Object.FindObjectsByType<HybridLumenGIValidationSequence>(FindObjectsInactive.Include,FindObjectsSortMode.None))p.enabled=false;
            foreach(var p in UnityEngine.Object.FindObjectsByType<HybridLumenGIStreamedRepresentation>(FindObjectsInactive.Include,FindObjectsSortMode.None))if(p!=probe.detail)p.enabled=false;
            mode=capture.gameObject.AddComponent<PageAuxiliaryColdBind>();mode.target=capture.camera;mode.detail=probe.detail;mode.streamer=probe.streamer;
            mode.folder=Arg("-auditOutput");Require(Path.IsPathRooted(mode.folder)&&!Directory.Exists(mode.folder),"New absolute result directory required");Directory.CreateDirectory(mode.folder);
            mode.Initialize();
        }
        catch(Exception e){if(mode!=null&&!string.IsNullOrEmpty(mode.folder)&&Directory.Exists(mode.folder))mode.Finish("failed",e.ToString());else{Debug.LogError(e);Application.Quit(1);}}
        return true;
    }
    void Initialize()
    {
        input=JsonUtility.FromJson<Input>(File.ReadAllText(Path.Combine(Application.streamingAssetsPath,"AuxiliaryColdBindInput.json")));
        Require(streamer.Available,"Existing page driver unavailable");var manifest=streamer.Manifest;
        Require(manifest.RelativeRoot==input.relativeRoot&&manifest.TargetPlatform==input.platform&&manifest.Pages.Length==input.pages.Length,"Frozen manifest identity differs");
        var group=new[]{(string)Field(detail,"geometryPage"),(string)Field(detail,"sdfPage"),(string)Field(detail,"chartPage")}.Concat((string[])Field(detail,"materialPages")).ToArray();
        Require(group.SequenceEqual(input.groupIds),"Frozen detail group differs");
        foreach(var page in input.pages)
        {
            var d=manifest.Pages.Single(p=>p.id==page.id);
            Require(d.bundlePath==page.bundlePath&&d.assetName==page.assetName&&(int)d.kind==page.kind&&d.crc==page.crc&&d.fileBytes==page.fileBytes&&d.residentBytes==page.residentBytes&&d.uploadBytes==page.uploadBytes&&d.dependencies.SequenceEqual(page.dependencies),"Manifest page differs: "+page.id);
            byte[] bytes=File.ReadAllBytes(Path.Combine(Application.streamingAssetsPath,input.relativeRoot,page.bundlePath));
            Require(bytes.LongLength==page.fileBytes&&Hash(bytes)==page.sha256,"Bundle bytes differ: "+page.id);
        }
        CheckBudgets();Require(!detail.HasBoundAssets,"Detail already bound at startup");
        var local=(Bounds)Field(detail,"localBounds");Matrix4x4 matrix=detail.transform.localToWorldMatrix;
        Vector3 x=matrix.MultiplyVector(new Vector3(local.extents.x,0,0)),y=matrix.MultiplyVector(new Vector3(0,local.extents.y,0)),z=matrix.MultiplyVector(new Vector3(0,0,local.extents.z));
        bounds=new Bounds(matrix.MultiplyPoint3x4(local.center),2f*new Vector3(Mathf.Abs(x.x)+Mathf.Abs(y.x)+Mathf.Abs(z.x),Mathf.Abs(x.y)+Mathf.Abs(y.y)+Mathf.Abs(z.y),Mathf.Abs(x.z)+Mathf.Abs(y.z)+Mathf.Abs(z.z)));
        result.loadDistance=(float)Field(detail,"loadDistance");result.unloadDistance=(float)Field(detail,"unloadDistance");
        explicitObserver=(Transform)Field(detail,"observer");result.explicitObserverAbsent=explicitObserver==null;
        Require(result.explicitObserverAbsent&&Camera.main==target,"Frozen null observer/main-camera fallback differs");
        target.transform.position=bounds.center+Vector3.forward*(Mathf.Max(result.loadDistance,result.unloadDistance)+bounds.extents.magnitude+100f);
        auxiliary=new GameObject("Explicit auxiliary distance viewpoint").transform;auxiliary.position=bounds.center;
        result.primaryPosition=target.transform.position;result.auxiliaryPosition=auxiliary.position;
        detail.SetAdditionalObservers(null);detail.UseDistanceRequests();detail.enabled=true;
        result.distanceModeBeforeCold=!(bool)Field(detail,"manualMode");Require(result.distanceModeBeforeCold,"Manual mode remained active");
        target.targetTexture=null;target.enabled=true;Application.runInBackground=true;
        result.unity=Application.unityVersion;result.api=SystemInfo.graphicsDeviceType.ToString();
        Application.logMessageReceived+=Log;RenderPipelineManager.endCameraRendering+=Rendered;
        CheckViewpoints();RequireCold();Record("initialized",false);Save();
    }
    void CheckBudgets()=>Require(JsonUtility.ToJson(Field(streamer,"budgets"))==JsonUtility.ToJson(input.budgets),"Original page budgets changed");
    void CheckViewpoints()
    {
        Require(Camera.main==target&&(Transform)Field(detail,"observer")==explicitObserver,"Legacy observer changed");
        Require(target.transform.position==result.primaryPosition&&bounds.SqrDistance(target.transform.position)>Mathf.Pow(Mathf.Max(result.loadDistance,result.unloadDistance),2),"Primary viewpoint left the frozen far position");
        Require(!(bool)Field(detail,"manualMode"),"Distance mode was replaced");
        if(result.auxiliaryAdded)Require(auxiliary.position==result.auxiliaryPosition&&bounds.SqrDistance(auxiliary.position)<=result.loadDistance*result.loadDistance,"Auxiliary viewpoint is not near");
        CheckBudgets();
    }
    void RequireCold()
    {
        var s=streamer.State;
        Require(!detail.HasBoundAssets&&((IDictionary)Field(streamer,"requests")).Count==0&&s.BundleBytes==0&&s.ResidentBytes==0&&s.IoBytesInFlight==0&&s.ActiveOperations==0&&s.RetiringLeases==0,"Cold driver already has demand/reservations");
        Require(s.States.All(p=>p.Status==HybridLumenGIAssetPageStreaming.Phase.Unloaded&&!p.Wanted&&p.ConsumerReferences==0),"Cold pages already loaded/wanted");
    }
    bool ExactBindings()
    {
        var leases=((IEnumerable)Field(detail,"leases")).Cast<HybridLumenGIAssetPageStreaming.Lease>().ToArray();
        object Asset(string id)=>leases.Single(p=>p.Id==id).Asset;
        var mesh=(Mesh)Asset(input.groupIds[0]);var sdf=(HybridLumenGIMeshSdf)Asset(input.groupIds[1]);var charts=(HybridLumenGISurfaceCharts)Asset(input.groupIds[2]);
        var materials=input.groupIds.Skip(3).Select(id=>(Material)Asset(id)).ToArray();
        return mesh&&sdf&&charts&&sdf.SourceMesh==mesh&&charts.SourceMesh==mesh&&((MeshFilter)Field(detail,"meshFilter")).sharedMesh==mesh&&
            detail.SourceRenderer.sharedMaterials.SequenceEqual(materials)&&materials.All(m=>m)&&mesh.subMeshCount==materials.Length&&
            detail.Proxy.MeshSdf==sdf&&detail.Proxy.SurfaceCharts==charts&&detail.SourceRenderer.enabled&&detail.Proxy.enabled;
    }
    void Rendered(ScriptableRenderContext context,Camera camera)
    {
        if(camera!=target||quitPending||lastEngine==Time.frameCount)return;lastEngine=Time.frameCount;result.frames++;
        try
        {
            CheckViewpoints();Require(firstError==null,firstError);
            Require(string.IsNullOrEmpty(detail.LastError)&&streamer.State.States.All(p=>p.LastError==null&&p.Status!=HybridLumenGIAssetPageStreaming.Phase.Failed&&p.Status!=HybridLumenGIAssetPageStreaming.Phase.ReleaseFailed),"Native page/representation error");
            if(result.frames==2)
            {
                RequireCold();result.coldQualified=true;Record("cold-two-frames",false);
                detail.SetAdditionalObservers(auxiliary);result.auxiliaryAdded=true;Save();
            }
            if(detail.HasBoundAssets)
            {
                Require(result.coldQualified&&result.auxiliaryAdded,"Binding preceded auxiliary demand");
                Require(input.pages.All(p=>streamer.State.GetState(p.id).Status==HybridLumenGIAssetPageStreaming.Phase.Ready)&&ExactBindings(),"Complete asset/mesh/material binding did not match");
                Record("complete-binding",true);Finish("collected",null);return;
            }
            if(result.frames>=120)Finish("uncovered","Complete binding not reached by120 actual target-camera frames");
        }catch(Exception e){Finish("failed",e.ToString());}
    }
    void Record(string stage,bool exact)
    {
        var s=streamer.State;receipts.Add(new Receipt{stage=stage,frame=result.frames,engine=Time.frameCount,requests=((IDictionary)Field(streamer,"requests")).Count,
            activeOperations=s.ActiveOperations,bundles=s.BundleBytes,resident=s.ResidentBytes,io=s.IoBytesInFlight,bound=detail.HasBoundAssets,
            allReady=input.pages.All(p=>s.GetState(p.id).Status==HybridLumenGIAssetPageStreaming.Phase.Ready),rendererEnabled=detail.SourceRenderer.enabled,proxyEnabled=detail.Proxy.enabled,exactBindings=exact,
            pages=s.States.Select(p=>p.Id+":"+p.Status+":wanted="+p.Wanted+":refs="+p.ConsumerReferences).ToArray()});
    }
    void Save(){result.receipts=receipts.ToArray();File.WriteAllText(Path.Combine(folder,"result.json"),JsonUtility.ToJson(result,true));}
    void Finish(string status,string error){if(quitPending)return;quitPending=true;result.status=status;result.error=error;if(streamer!=null&&streamer.State!=null&&input!=null)Record(status,false);Save();}
    void Update()
    {
        if(firstError!=null&&!quitPending)Finish("failed",firstError);
        if(!quitPending||quitIssued)return;quitIssued=true;RenderPipelineManager.endCameraRendering-=Rendered;if(target)target.enabled=false;
        Application.Quit(result.status=="collected"||result.status=="uncovered"?0:1);
    }
    void Log(string message,string stack,LogType type){if(type==LogType.Error||type==LogType.Exception||type==LogType.Assert)firstError=firstError??message;}
    void OnApplicationQuit(){result.normalQuitObserved=true;if(!string.IsNullOrEmpty(folder)&&Directory.Exists(folder))Save();}
    void OnDestroy(){RenderPipelineManager.endCameraRendering-=Rendered;Application.logMessageReceived-=Log;}
}
