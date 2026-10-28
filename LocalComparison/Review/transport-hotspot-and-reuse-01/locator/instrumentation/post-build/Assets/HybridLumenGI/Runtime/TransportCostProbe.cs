// Temporary test-project instrumentation. Uses the unchanged native ABI/query pool.
using System;
using UnityEngine;
using UnityEngine.Rendering;
namespace HybridLumenGI
{
    public static class TransportCostProbe
    {
        static Camera selected;
        public static HybridLumenGINativeGpuTiming Timing {get;private set;}
        public static HybridLumenGINativeGpuTiming.FrameToken Parent {get;private set;}
        public static string Failure {get;private set;}
        public static void Configure(Camera camera)
        {
            if(Timing!=null)throw new InvalidOperationException("Diagnostic owner already configured");
            selected=camera;Timing=new HybridLumenGINativeGpuTiming(camera.GetInstanceID());Timing.EnableCompletedRecords(true);
        }
        public static void Begin(Camera camera,HybridLumenGINativeGpuTiming.FrameToken parent)
        {
            if(camera!=selected||Timing==null)return;
            Parent=parent;
            try{Timing.BeginFrame(Time.frameCount,parent.Generation,parent.IsValid,out _);}
            catch(Exception e){Fail("Begin: "+e);}
        }
        public static void Invalidate(Camera camera)
        {if(camera==selected&&Timing!=null){Timing.Invalidate();Parent=default;}}
        static void Fail(string reason){if(Failure==null)Failure=reason;}
        public static Scope Profile(Camera camera,CommandBuffer cmd,int index)
        {
            if(camera!=selected||Timing==null||!Parent.IsValid)return default;
            var token=Timing.CurrentFrameToken;
            try
            {
                if(!Timing.TryRecordBegin((HybridLumenGINativeGpuTiming.Scope)index,token,out var e))
                {Fail("Missing diagnostic begin "+index);return default;}
                cmd.IssuePluginEventAndData(e.Callback,e.EventId,e.Data);return new Scope(cmd,index,token);
            }
            catch(Exception e){Fail("Begin event: "+e);return default;}
        }
        public readonly struct Scope : IDisposable
        {
            readonly CommandBuffer cmd;readonly int index;readonly HybridLumenGINativeGpuTiming.FrameToken token;
            internal Scope(CommandBuffer command,int scope,HybridLumenGINativeGpuTiming.FrameToken ticket){cmd=command;index=scope;token=ticket;}
            public void Dispose()
            {
                if(cmd==null)return;
                try
                {
                    if(!Timing.TryRecordEnd((HybridLumenGINativeGpuTiming.Scope)index,token,out var e)){Fail("Missing diagnostic end "+index);return;}
                    cmd.IssuePluginEventAndData(e.Callback,e.EventId,e.Data);
                }
                catch(Exception e){Fail("End event: "+e);}
            }
        }
        public static void Resolve(CommandBuffer cmd,Camera camera,HybridLumenGINativeGpuTiming.FrameToken frozenParent)
        {
            if(camera!=selected||Timing==null||!Parent.IsValid)return;
            try
            {
                if(frozenParent.Id!=Parent.Id||frozenParent.Owner!=Parent.Owner||frozenParent.EngineFrame!=Parent.EngineFrame||
                    frozenParent.Generation!=Parent.Generation||frozenParent.DeviceEpoch!=Parent.DeviceEpoch||frozenParent.Epoch!=Parent.Epoch)
                {Fail("Frozen parent association mismatch");return;}
                if(!Timing.TryResolve(Timing.CurrentFrameToken,out var e)){Fail("Missing diagnostic resolve");return;}
                cmd.IssuePluginEventAndData(e.Callback,e.EventId,e.Data);
            }
            catch(Exception e){Fail("Resolve event: "+e);}
        }
        public static void Stop(){Timing?.Dispose();selected=null;}
    }
}
