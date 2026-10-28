using System;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Security.Cryptography;
using HybridLumenGI;
using UnityEngine;

[DefaultExecutionOrder(30000)]
public sealed class PageWithdrawalMode : MonoBehaviour
{
    [Serializable] public sealed class FrozenPage {public string id,bundlePath,assetName,sha256;public int kind;public uint crc;public long fileBytes,residentBytes,uploadBytes;public string[] dependencies;}
    [Serializable] public sealed class Input {public string relativeRoot,platform;public string[] groupIds;public FrozenPage[] pages;public HybridLumenGIAssetPageStreaming.Budgets budgets;}
    [Serializable] public sealed class Result
    {
        public string status="running",error,unity,api,scope="One unbound request withdrawal; no GPU lease/HLOD/performance acceptance";
        public int ticks,withdrawTick=-1,zeroTicks,requestCalls,withdrawCalls;public bool pendingWithdrawalCovered,fullProductionAccepted;
    }
    private readonly object requester=new object();private HybridLumenGIAssetPageStreamer streamer;private ComparisonCapture capture;
    private Input input;private Result result=new Result();private bool closing;private int lastTick=-1;
    internal static bool Requested=>Array.IndexOf(Environment.GetCommandLineArgs(),"-pageWithdrawal")>=0;
    private static object Field(object o,string name)=>o.GetType().GetField(name,BindingFlags.Instance|BindingFlags.NonPublic|BindingFlags.Public).GetValue(o);
    private static string Hash(byte[] bytes){using(var h=SHA256.Create())return BitConverter.ToString(h.ComputeHash(bytes)).Replace("-","").ToLowerInvariant();}
    public static void Configure(ComparisonCapture capture)
    {
        capture.enabled=false;
        foreach(var sequence in UnityEngine.Object.FindObjectsByType<HybridLumenGIValidationSequence>(FindObjectsInactive.Include,FindObjectsSortMode.None))sequence.enabled=false;
        var probe=UnityEngine.Object.FindFirstObjectByType<StreamingAuditProbe>();
        if(probe==null)throw new Exception("Existing streaming probe missing");probe.enabled=false;
        foreach(var representation in UnityEngine.Object.FindObjectsByType<HybridLumenGIStreamedRepresentation>(FindObjectsInactive.Include,FindObjectsSortMode.None))
        {if(representation.HasBoundAssets)throw new Exception("Representation already bound before initialization");representation.enabled=false;}
        var mode=capture.gameObject.AddComponent<PageWithdrawalMode>();mode.enabled=false;mode.capture=capture;mode.streamer=probe.streamer;
        inputCheck(mode,probe);mode.enabled=true;
    }
    private static void inputCheck(PageWithdrawalMode mode,StreamingAuditProbe probe)
    {
        mode.input=JsonUtility.FromJson<Input>(File.ReadAllText(Path.Combine(Application.streamingAssetsPath,"PageWithdrawalInput.json")));
        var input=mode.input;var manifest=mode.streamer.Manifest;
        if(input.platform!="StandaloneWindows64" || manifest.TargetPlatform!=input.platform || manifest.RelativeRoot!=input.relativeRoot || manifest.Pages.Length!=input.pages.Length)
            throw new Exception("Frozen manifest identity/platform mismatch");
        var actual=new[]{(string)Field(probe.detail,"geometryPage"),(string)Field(probe.detail,"sdfPage"),(string)Field(probe.detail,"chartPage")}
            .Concat((string[])Field(probe.detail,"materialPages")).ToArray();
        if(!actual.SequenceEqual(input.groupIds))throw new Exception("Frozen detail group mismatch");
        foreach(var page in input.pages)
        {
            var d=manifest.Pages.Single(p=>p.id==page.id);
            if(d.bundlePath!=page.bundlePath || d.assetName!=page.assetName || (int)d.kind!=page.kind || d.crc!=page.crc ||
                d.fileBytes!=page.fileBytes || d.residentBytes!=page.residentBytes || d.uploadBytes!=page.uploadBytes || !d.dependencies.SequenceEqual(page.dependencies))
                throw new Exception("Frozen definition mismatch: "+page.id);
            byte[] bytes=File.ReadAllBytes(Path.Combine(Application.streamingAssetsPath,input.relativeRoot,page.bundlePath));
            if(bytes.LongLength!=page.fileBytes || Hash(bytes)!=page.sha256)throw new Exception("Frozen bundle bytes mismatch");
        }
        if(!mode.streamer.Available)throw new Exception("Original page driver unavailable");
        if(((System.Collections.IDictionary)Field(mode.streamer,"requests")).Count!=0 || mode.streamer.State.BundleBytes!=0 || mode.streamer.State.ResidentBytes!=0)
            throw new Exception("Page driver already had demand or reservations");
        mode.streamer.SetBudgets(input.budgets);
        string directory=Path.Combine(capturePath(mode),DateTime.UtcNow.ToString("yyyyMMdd-HHmmss")+"-"+Guid.NewGuid().ToString("N"));Directory.CreateDirectory(directory);
        PageWithdrawalTap.DirectoryPath=directory;PageWithdrawalTap.Active=true;
        mode.result.unity=Application.unityVersion;mode.result.api=SystemInfo.graphicsDeviceType.ToString();
        File.WriteAllText(Path.Combine(directory,"input.json"),JsonUtility.ToJson(input,true));
        Application.runInBackground=true;mode.capture.camera.enabled=true;
        Application.logMessageReceived+=mode.Log;
        PageWithdrawalTap.Snapshot("initialized",mode.streamer.State);mode.Save();
    }
    private static string capturePath(PageWithdrawalMode mode)=>mode.capture.outputRoot;
    void Start()
    {
        try
        {
            if(PageWithdrawalTap.Tick!=0)throw new Exception("Pump ran before the sole initial request");
            if(!streamer.SetRequests(requester,input.groupIds))throw new Exception("Group request rejected");
            result.requestCalls++;PageWithdrawalTap.Snapshot("request-accepted",streamer.State);
        }catch(Exception e){Finish("failed",e.ToString());}
    }
    void Update()
    {
        if(closing)return;
        try
        {
            if(PageWithdrawalTap.Failure!=null)throw new Exception("Observer failed: "+PageWithdrawalTap.Failure);
            if(!string.IsNullOrEmpty(result.error))throw new Exception("Native error log: "+result.error);
            int tick=PageWithdrawalTap.Tick;if(tick==lastTick)return;
            if(tick!=lastTick+1 && lastTick!=-1)throw new Exception("Pump tick sequence mismatch");lastTick=tick;result.ticks=tick;
            var state=streamer.State;
            if(state.States.Any(s=>s.LastError!=null || s.Status==HybridLumenGIAssetPageStreaming.Phase.Failed || s.Status==HybridLumenGIAssetPageStreaming.Phase.ReleaseFailed))
                throw new Exception("Original page operation reported error");
            if(state.States.Any(s=>s.ConsumerReferences!=0) || state.RetiringLeases!=0)throw new Exception("Unexpected consumer lease");
            if(result.withdrawTick<0)
            {
                // The only extra completion read is the native AssetBundleRequest inside this method.
                var check=streamer.PageWithdrawalCheck();bool pending=check!=null && !check.done;
                if(pending || tick>=64)
                {
                    streamer.RemoveRequests(requester);result.withdrawCalls++;result.withdrawTick=tick;result.pendingWithdrawalCovered=pending;
                    if(check!=null)PageWithdrawalTap.Write(check);
                    PageWithdrawalTap.Snapshot(pending?"pending-withdrawal":"uncovered-withdrawal",state);
                }
                else if(check!=null)PageWithdrawalTap.Write(check);
            }
            if(result.withdrawTick>=0)
            {
                bool zero=state.BundleBytes==0 && state.ResidentBytes==0 && state.IoBytesInFlight==0 && state.ActiveOperations==0 && state.RetiringLeases==0 &&
                    state.States.All(s=>s.Status==HybridLumenGIAssetPageStreaming.Phase.Unloaded && s.operation==null && s.ConsumerReferences==0 && !s.bundleReserved && !s.residentReserved && s.releasePins==0);
                result.zeroTicks=zero?result.zeroTicks+1:0;
                if(result.zeroTicks>=8){Finish(result.pendingWithdrawalCovered?"collected":"uncovered",null);return;}
                if(tick-result.withdrawTick>=128 && !zero){Finish("incomplete","Cleanup did not finish within128 pump ticks");return;}
            }
            Save();if(tick>=256)Finish("incomplete","Total pump tick limit");
        }catch(Exception e){Finish("failed",e.ToString());}
    }
    void Save()=>File.WriteAllText(Path.Combine(PageWithdrawalTap.DirectoryPath,"result.json"),JsonUtility.ToJson(result,true));
    void Finish(string status,string error)
    {
        if(closing)return;closing=true;result.status=status;result.error=error;
        int exit=status=="collected" || status=="uncovered"?0:1;
        try{PageWithdrawalTap.Snapshot("closing",streamer.State);Save();}
        catch(Exception e){exit=1;Debug.LogError("Page withdrawal result save failed: "+e);}
        finally
        {
            try{if(capture && capture.camera)capture.camera.enabled=false;}
            catch(Exception e){exit=1;Debug.LogException(e);}
            finally{Application.Quit(exit);} // Ordinary Update boundary; original shutdown owns GPU resources.
        }
    }
    void Log(string message,string stack,LogType type)
    {
        if(type==LogType.Error || type==LogType.Exception || type==LogType.Assert)result.error=(result.error??"")+"\n"+message;
    }
}
