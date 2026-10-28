using System;
using System.Collections;
using System.IO;
using System.Reflection;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using HybridLumenGI;

[DefaultExecutionOrder(-300)]
public sealed class StreamingAuditProbe : MonoBehaviour
{
    public ComparisonCapture capture;public HybridLumenGIAssetPageStreamer streamer;
    public HybridLumenGIStreamedRepresentation detail,aggregate;
    Camera observer;RenderTexture observerTarget;StreamWriter writer;
    static object Field(object o,string n)=>o.GetType().GetField(n,BindingFlags.Instance|BindingFlags.NonPublic|BindingFlags.Public)?.GetValue(o);
    [Serializable] class Row
    {
        public int frame,ready,loading,failed,blocked,retiring,operations;
        public long resident,bundles,io,upload;public bool detailBound,aggregateBound,secondCamera;
        public uint detailGeneration,aggregateGeneration;public string mainPublished,mainWarming,secondPublished,error;
    }
    void Start()
    {
        var go=new GameObject("Streaming second consumer");observer=go.AddComponent<Camera>();observer.CopyFrom(capture.camera);
        observer.depth=-10;go.AddComponent<UniversalAdditionalCameraData>();
        observerTarget=new RenderTexture(160,90,24,RenderTextureFormat.ARGBHalf);observerTarget.Create();observer.targetTexture=observerTarget;
        observer.transform.SetPositionAndRotation(new Vector3(0,1.7f,-6),Quaternion.identity);
        RenderPipelineManager.endCameraRendering+=Rendered;
    }
    void Update()
    {
        int f=(int)Field(capture,"logicalFrame");var budget=HybridLumenGIAssetPageStreaming.Budgets.Default;
        if(f<30)budget.maxResidentBytes=1;streamer.SetBudgets(budget);
        bool far=f>=180&&f<360,away=f>=480;
        detail.SetWanted(!far&&!away);aggregate.SetWanted(!away);
        observer.enabled=f<270;
        capture.camera.transform.SetPositionAndRotation(away?new Vector3(220,1.7f,-6):far?new Vector3(0,1.7f,-14):new Vector3(0,1.7f,-6),Quaternion.identity);
    }
    void Rendered(ScriptableRenderContext context,Camera camera)
    {
        if(camera!=capture.camera)return;string directory=(string)Field(capture,"directory");if(string.IsNullOrEmpty(directory))return;
        if(writer==null)writer=new StreamWriter(Path.Combine(directory,"streaming.jsonl")){AutoFlush=true};
        var s=streamer.State;var row=new Row{frame=(int)Field(capture,"logicalFrame"),resident=s.ResidentBytes,bundles=s.BundleBytes,
            io=s.IoBytesStarted,upload=s.UploadBytesStarted,operations=s.OperationsStarted,blocked=streamer.BudgetBlockedGroups,
            retiring=s.RetiringLeases,detailBound=detail.HasBoundAssets,aggregateBound=aggregate.HasBoundAssets,
            detailGeneration=detail.Generation,aggregateGeneration=aggregate.Generation,secondCamera=observer.enabled,
            error=(detail.LastError??"")+" "+(aggregate.LastError??"")};
        foreach(var page in s.States){if(page.Status==HybridLumenGIAssetPageStreaming.Phase.Ready)row.ready++;else if(page.Status==HybridLumenGIAssetPageStreaming.Phase.Failed||page.Status==HybridLumenGIAssetPageStreaming.Phase.ReleaseFailed){row.failed++;row.error+=" "+page.LastError;}else if(page.Status!=HybridLumenGIAssetPageStreaming.Phase.Unloaded)row.loading++;}
        var pass=Field(capture.feature,"pass");var cameras=Field(pass,"cameras") as IDictionary;
        foreach(var state in cameras.Values)
        {
            var scene=(HybridLumenGIScene)Field(state,"scene");bool main=ReferenceEquals(Field(state,"camera"),camera);
            for(int i=0;i<scene.Capacity;i++)
            {
                var p=scene.GetProxy(i);if(p!=detail.Proxy&&p!=aggregate.Proxy)continue;
                string name=p==detail.Proxy?"detail ":"aggregate ";
                if(scene.IsPublished(i)){if(main)row.mainPublished+=name;else row.secondPublished+=name;}
                if(main&&scene.IsWarming(i))row.mainWarming+=name;
            }
        }
        writer.WriteLine(JsonUtility.ToJson(row));
    }
    void OnDestroy(){RenderPipelineManager.endCameraRendering-=Rendered;writer?.Dispose();if(observer)Destroy(observer.gameObject);if(observerTarget){observerTarget.Release();Destroy(observerTarget);}}
}
