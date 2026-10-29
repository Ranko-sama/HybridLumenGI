using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Reflection;
using System.Runtime.CompilerServices;
using UnityEngine;
using UnityEngine.Rendering;
using HybridLumenGI;
#if UNITY_EDITOR
using UnityEditor;
#endif

// Attribution-only test-project helper. It never submits, polls retirement,
// destroys resources, changes accounting, or treats a diagnostic as completion.
public static class ResourceShutdownTrace
{
    const BindingFlags Fields=BindingFlags.Public|BindingFlags.NonPublic|BindingFlags.Instance;
    const BindingFlags Statics=BindingFlags.Public|BindingFlags.NonPublic|BindingFlags.Static;
    static bool installed,firstCamera;
    static string path,phase="initialization";
    static int sequence,lastCameraFrame=-1;
    static string lastCamera;
    static readonly string domain=Guid.NewGuid().ToString("N");
    static readonly Dictionary<int,Row> owners=new Dictionary<int,Row>();
    static readonly Dictionary<int,string> lastPoll=new Dictionary<int,string>();
    [Serializable] sealed class Row
    {
        public int sequence,engineFrame,ticket,submittedCount,pendingCount,ownedCount,lastObservedCameraFrame;
        public string domain,utc,stage,phase,owner,callback,resources,prerequisite,completion,stack,lastObservedCamera,diagnostics;
        public bool submitted,outsideRenderLoop,requiresContext,submissionUnknown;
        public long logicalBytes,materialBytes,arenaBytes,deformationBytes;
        public int materialBatches,arenas,deformationJobs,publishedSnapshots,failedWithdrawals,failedCleanup;
        public bool admissionClosed;
    }
    static object Get(object o,string name)=>o?.GetType().GetField(name,Fields)?.GetValue(o);
    static object Static(string name)=>typeof(HybridLumenGIResourceRetirement).GetField(name,Statics)?.GetValue(null);
    static bool Enabled=>Array.IndexOf(Environment.GetCommandLineArgs(),"-resourceShutdownTrace")>=0;
    static string Arg(string name){var a=Environment.GetCommandLineArgs();int i=Array.IndexOf(a,name);return i>=0&&i+1<a.Length?a[i+1]:null;}
    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.BeforeSceneLoad)]
    static void RuntimeStart(){if(!Application.isEditor&&!Debug.isDebugBuild)return;Install();Mark("runtime-before-scene");}
#if UNITY_EDITOR
    [InitializeOnLoadMethod]
    static void EditorStart()
    {
        Install();if(!Enabled)return;
        EditorApplication.playModeStateChanged+=s=>Mark("playmode-"+s);
        AssemblyReloadEvents.beforeAssemblyReload+=()=>Mark("before-assembly-reload");
        EditorApplication.quitting+=()=>Mark("editor-quitting");
    }
#endif
    static void Install()
    {
        if(installed||!Enabled)return;installed=true;
        string root=Arg("-comparisonOutput");if(string.IsNullOrEmpty(root))return;
        Directory.CreateDirectory(root);path=Path.Combine(root,"retirement-timeline.jsonl");
        Application.quitting+=()=>Mark("application-quitting");
        RenderPipelineManager.endCameraRendering+=CameraEnded;
        Mark("trace-installed");
    }
    static void CameraEnded(ScriptableRenderContext context,Camera camera)
    {
        lastCamera=camera.name;lastCameraFrame=Time.frameCount;
        if(firstCamera)return;firstCamera=true;Mark("first-camera-complete");
    }
    public static void Mark(string stage)
    {
        phase=stage;Record(stage,null,null,null,true);
    }
    public static void Record(string stage,object ticket,Action destroy=null,object prerequisite=null,bool includeState=false)
    {
        if(!Enabled)return;
        try
        {
            Install();if(path==null)return;
            var row=new Row {domain=domain,utc=DateTime.UtcNow.ToString("o"),engineFrame=Time.frameCount,
                stage=stage,phase=phase,ticket=ticket==null?0:RuntimeHelpers.GetHashCode(ticket),
                pendingCount=(Static("pending") as IList)?.Count??-1,ownedCount=(Static("owned") as IList)?.Count??-1,
                lastObservedCamera=lastCamera,lastObservedCameraFrame=lastCameraFrame};
            row.submitted=ticket!=null&&(bool)(Get(ticket,"submitted")??false);
            row.requiresContext=(bool)(Get(ticket,"requiresContext")??false);row.submissionUnknown=(bool)(Get(ticket,"submissionUnknown")??false);
            row.outsideRenderLoop=(bool)(Static("outsideRenderLoop")??false);
            row.completion="not-submitted";
            if(row.submitted){try{row.completion=((GraphicsFence)Get(ticket,"fence")).passed?"passed":"not-passed";}catch(Exception e){row.completion="query-failed:"+e.GetType().Name;}}
            string state=row.submitted+"/"+row.completion+"/"+row.submissionUnknown;
            if(stage=="poll"&&lastPoll.TryGetValue(row.ticket,out var previous)&&state==previous)return;
            if(stage=="poll")lastPoll[row.ticket]=state;
            row.sequence=++sequence;
            if(destroy!=null&&stage=="enqueue")
            {
                row.callback=destroy.Method.DeclaringType?.FullName+"."+destroy.Method.Name;
                row.owner=destroy.Target==null?"static":destroy.Target.GetType().FullName+"#"+RuntimeHelpers.GetHashCode(destroy.Target);
                var descriptions=new List<string>();Describe(destroy.Target,descriptions,ref row.logicalBytes,0);row.resources=string.Join(";",descriptions);
                row.stack=Environment.StackTrace;owners[row.ticket]=row;
            }
            else if(owners.TryGetValue(row.ticket,out var description))
            {row.callback=description.callback;row.owner=description.owner;row.resources=description.resources;row.logicalBytes=description.logicalBytes;}
            row.materialBytes=HybridLumenGIHitMaterialBatch.TotalMaterialBytes;row.materialBatches=HybridLumenGIHitMaterialBatch.ResidentBatchCount;
            row.arenaBytes=HybridLumenGIRayTexturePool.TotalAllocatedBytes;row.arenas=HybridLumenGIRayTexturePool.ResidentBatchCount;
            row.deformationBytes=HybridLumenGIDeformedMesh.ReservedBytes;row.deformationJobs=HybridLumenGIDeformedMesh.PendingWorkerCount;
            row.publishedSnapshots=HybridLumenGIDeformedMesh.PublishedSnapshotCount;row.failedCleanup=HybridLumenGIDeformedMesh.FailedCleanupCount;
            row.failedWithdrawals=HybridLumenGIResourceRetirement.FailedWithdrawalCount;row.admissionClosed=HybridLumenGIResourceRetirement.AdmissionClosed;
            row.prerequisite=prerequisite==null?"none":prerequisite.GetType().FullName;
            if(Static("owned") is IList owned)foreach(var item in owned)if((bool)(Get(Get(item,"ticket"),"submitted")??false))row.submittedCount++;
            if(includeState)
            {
                var capture=UnityEngine.Object.FindFirstObjectByType<ComparisonCapture>();
                if(capture&&capture.feature is HybridLumenGIRendererFeature feature)
                {
                    var details=new List<string>();foreach(var d in feature.GetDiagnostics())details.Add(JsonUtility.ToJson(d));
                    row.diagnostics=string.Join("\n",details);
                }
            }
            File.AppendAllText(path,JsonUtility.ToJson(row)+"\n");
        }
        catch(Exception e){Debug.LogWarning("RESOURCE_TRACE_WRITE_FAILED "+e.GetType().Name+": "+e.Message);}
    }
    static void Describe(object value,List<string> result,ref long bytes,int depth)
    {
        if(value==null||depth>1)return;
        foreach(var field in value.GetType().GetFields(Fields))
        {
            object v=field.GetValue(value);
            if(depth==0&&v is ComputeBuffer c){long b=(long)c.count*c.stride;bytes+=b;result.Add(field.Name+":ComputeBuffer count="+c.count+" stride="+c.stride+" bytes="+b);}
            else if(depth==0&&v is GraphicsBuffer g){long b=(long)g.count*g.stride;bytes+=b;result.Add(field.Name+":GraphicsBuffer count="+g.count+" stride="+g.stride+" bytes="+b);}
            else if(v is Camera camera)result.Add(camera?field.Name+":Camera "+camera.name+" id="+camera.GetInstanceID():field.Name+":destroyed Camera");
            else if(v is UnityEngine.Object o)result.Add(o?field.Name+":"+o.GetType().Name+" "+o.name+" id="+o.GetInstanceID():field.Name+":destroyed Unity object");
            else if(field.Name=="<>4__this"&&depth==0)Describe(v,result,ref bytes,depth+1);
            else if(field.Name=="bytes"||field.Name=="budgetOwner")result.Add(field.Name+"="+v);
        }
    }
}
