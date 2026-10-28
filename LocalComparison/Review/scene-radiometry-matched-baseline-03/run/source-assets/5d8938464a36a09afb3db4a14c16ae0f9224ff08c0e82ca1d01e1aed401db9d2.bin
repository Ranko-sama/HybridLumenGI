using System;
using System.Collections;
using System.IO;
using System.Reflection;
using System.Runtime.CompilerServices;
using UnityEngine;
using HybridLumenGI;

// Test-only observer: never queries a fence/prerequisite, submits, polls or disposes.
public static class RetirementProgressTrace
{
    const BindingFlags Instance=BindingFlags.Instance|BindingFlags.NonPublic|BindingFlags.Public;
    const BindingFlags Static=BindingFlags.Static|BindingFlags.NonPublic|BindingFlags.Public;
    static readonly string domain=Guid.NewGuid().ToString("N");static int sequence;
    static readonly bool enabled=Array.IndexOf(Environment.GetCommandLineArgs(),"-retirementProgressTrace")>=0;
    [Serializable] sealed class Row
    {
        public string domain,utc,stage,observed,detail,callback,prerequisite;
        public int sequence,frame,ticket,owned,pending,failed,unknown,failedWithdrawals;
        public bool submitted,submissionUnknown,requiresContext,outside,closing,deadlineReached;
        public long timestamp,deadline,materialBytes,arenaBytes,deformationBytes;
    }
    static object Get(object value,string field)=>value?.GetType().GetField(field,Instance)?.GetValue(value);
    static object State(string field)=>typeof(HybridLumenGIResourceRetirement).GetField(field,Static)?.GetValue(null);
    public static void Record(string stage,object ticket=null,string observed=null,string detail=null,Action destroy=null,object prerequisite=null)
    {
        if(!enabled)return;
        try
        {
            var args=Environment.GetCommandLineArgs();int i=Array.IndexOf(args,"-comparisonOutput");
            if(i<0||i+1>=args.Length)throw new Exception("Missing progress trace directory");
            string path=Path.Combine(args[i+1],"progress-timeline.jsonl");Directory.CreateDirectory(args[i+1]);
            long timestamp=System.Diagnostics.Stopwatch.GetTimestamp(),deadline=(long)(State("shutdownDeadline")??0L);
            var row=new Row{domain=domain,utc=DateTime.UtcNow.ToString("o"),sequence=++sequence,frame=Time.frameCount,
                stage=stage,ticket=ticket==null?0:RuntimeHelpers.GetHashCode(ticket),observed=observed,detail=detail,
                callback=destroy==null?null:destroy.Method.DeclaringType?.FullName+"."+destroy.Method.Name,
                prerequisite=prerequisite==null?"none":prerequisite.GetType().FullName,
                submitted=(bool)(Get(ticket,"submitted")??false),submissionUnknown=(bool)(Get(ticket,"submissionUnknown")??false),requiresContext=(bool)(Get(ticket,"requiresContext")??false),
                outside=(bool)(State("outsideRenderLoop")??false),closing=HybridLumenGIResourceRetirement.AdmissionClosed,
                timestamp=timestamp,deadline=deadline,deadlineReached=deadline!=0&&timestamp>=deadline,
                owned=HybridLumenGIResourceRetirement.OwnedCount,pending=HybridLumenGIResourceRetirement.PendingCount,
                failed=HybridLumenGIResourceRetirement.FailedCount,unknown=HybridLumenGIResourceRetirement.UnknownSubmissionCount,failedWithdrawals=HybridLumenGIResourceRetirement.FailedWithdrawalCount,
                materialBytes=HybridLumenGIHitMaterialBatch.TotalAllocatedBytes,arenaBytes=HybridLumenGIRayTexturePool.TotalAllocatedBytes,deformationBytes=HybridLumenGIDeformedMesh.ReservedBytes};
            File.AppendAllText(path,JsonUtility.ToJson(row)+"\n");
        }
        catch(Exception error){Debug.LogError("RETIREMENT_PROGRESS_OBSERVER_FAILED "+error);}
    }
}
