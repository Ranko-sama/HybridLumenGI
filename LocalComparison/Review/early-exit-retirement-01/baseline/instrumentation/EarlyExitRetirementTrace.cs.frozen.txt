// Temporary attribution only: never queries completion, polls, submits or disposes.
using System;
using System.IO;
using System.Reflection;
using System.Runtime.CompilerServices;
using UnityEngine;
using HybridLumenGI;

public static class EarlyExitRetirementTrace
{
    const BindingFlags Instance=BindingFlags.Instance|BindingFlags.NonPublic|BindingFlags.Public;
    const BindingFlags Static=BindingFlags.Static|BindingFlags.NonPublic|BindingFlags.Public;
    static readonly bool enabled=Array.IndexOf(Environment.GetCommandLineArgs(),"-earlyExitRetirementTrace")>=0;
    static readonly string domain=Guid.NewGuid().ToString("N");
    static int sequence,context,parent;static string phase="initial",nextOwner;static long nextBytes=-1;static bool stacks;
    [Serializable] sealed class Row
    {
        public string domain,utc,stage,phase,observed,detail,callback,prerequisite,owner,enqueueStack;
        public int sequence,frame,context,ticket,parent,owned,pending,failed,unknown,failedWithdrawals;
        public bool submitted,submissionUnknown,requiresContext,outside,contextEnded,closing,deadlineReached;
        public long timestamp,deadline,logicalBytes,materialBytes,arenaBytes,deformationBytes;
    }
    static object Get(object value,string field)=>value?.GetType().GetField(field,Instance)?.GetValue(value);
    static object State(string field)=>typeof(HybridLumenGIResourceRetirement).GetField(field,Static)?.GetValue(null);
#if UNITY_EDITOR
    [UnityEditor.InitializeOnLoadMethod]
    static void InitializeEditor()=>EnableAllocationStacks();
#endif
    public static void EnableAllocationStacks()
    {
        if(!enabled||stacks)return;
        Unity.Collections.NativeLeakDetection.Mode=Unity.Collections.NativeLeakDetectionMode.EnabledWithStackTrace;
        stacks=true;Record("allocation-stacks-enabled",detail:"before instrumented feature/backend/private observer allocation");
    }
    public static void Owner(string label,long bytes=-1)
    {if(enabled){nextOwner=label;nextBytes=bytes;}}
    // The value passed here is the product's existing capability read, not an extra read.
    public static bool FenceSupport(bool value,string site)
    {Record("fence-support-read",observed:value?"supported":"unsupported",detail:site);return value;}
    public static void Record(string stage,object ticket=null,string observed=null,string detail=null,Action destroy=null,object prerequisite=null)
    {
        if(!enabled)return;
        try
        {
            if(stage=="begin-context"){context++;phase="context";}
            else if(stage=="end-context-enter")phase="own-end-context";
            else if(stage=="end-context-return")phase="after-own-end-context-callback";
            else if(stage=="idle-enter")phase="idle";
            else if(stage=="shutdown-closed")phase="shutdown";
            int id=ticket==null?0:RuntimeHelpers.GetHashCode(ticket);
            var args=Environment.GetCommandLineArgs();int i=Array.IndexOf(args,"-comparisonOutput");
            if(i<0||i+1>=args.Length)throw new Exception("Missing trace output directory");
            Directory.CreateDirectory(args[i+1]);long timestamp=System.Diagnostics.Stopwatch.GetTimestamp(),deadline=(long)(State("shutdownDeadline")??0L);
            var row=new Row{domain=domain,utc=DateTime.UtcNow.ToString("o"),sequence=++sequence,frame=Time.frameCount,context=context,phase=phase,
                stage=stage,ticket=id,parent=parent,observed=observed,detail=detail,
                callback=destroy==null?null:destroy.Method.DeclaringType?.FullName+"."+destroy.Method.Name,prerequisite=prerequisite==null?"none":prerequisite.GetType().FullName,
                owner=stage=="enqueue"?nextOwner:null,logicalBytes=stage=="enqueue"?nextBytes:-1,enqueueStack=stage=="enqueue"?new System.Diagnostics.StackTrace(1,true).ToString():null,
                submitted=(bool)(Get(ticket,"submitted")??false),submissionUnknown=(bool)(Get(ticket,"submissionUnknown")??false),requiresContext=(bool)(Get(ticket,"requiresContext")??false),
                outside=(bool)(State("outsideRenderLoop")??false),contextEnded=(bool)(State("contextEnded")??false),closing=HybridLumenGIResourceRetirement.AdmissionClosed,
                timestamp=timestamp,deadline=deadline,deadlineReached=deadline!=0&&timestamp>=deadline,
                owned=HybridLumenGIResourceRetirement.OwnedCount,pending=HybridLumenGIResourceRetirement.PendingCount,failed=HybridLumenGIResourceRetirement.FailedCount,
                unknown=HybridLumenGIResourceRetirement.UnknownSubmissionCount,failedWithdrawals=HybridLumenGIResourceRetirement.FailedWithdrawalCount,
                materialBytes=HybridLumenGIHitMaterialBatch.TotalAllocatedBytes,arenaBytes=HybridLumenGIRayTexturePool.TotalAllocatedBytes,deformationBytes=HybridLumenGIDeformedMesh.ReservedBytes};
            File.AppendAllText(Path.Combine(args[i+1],"early-exit-timeline.jsonl"),JsonUtility.ToJson(row)+"\n");
            if(stage=="enqueue"){nextOwner=null;nextBytes=-1;}
            if(stage=="destroy-begin")parent=id;
            if(stage=="destroy-returned"||stage=="destroy-failed")parent=0;
        }
        catch(Exception error){Debug.LogError("EARLY_EXIT_TRACE_FAILED "+error);}
    }
}
