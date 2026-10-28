using HybridLumenGI;
using UnityEngine;
using UnityEngine.Rendering;
using System.Text.Json;

static class FailureRecovery
{
    static void Require(bool value,string message){if(!value)throw new Exception(message);}
    static (int slot,uint generation,bool ready)[] Snapshot(HybridLumenGIGlobalSdf global)
    {
        var result=new List<(int,uint,bool)>();
        for(int z=-2;z<2;z++)for(int y=-2;y<2;y++)for(int x=-2;x<2;x++)
        {
            Require(global.TryGetPage(0,x,y,z,out int slot,out uint generation,out bool ready),"Expected fixed clipmap key missing");
            result.Add((slot,generation,ready));
        }
        return result.ToArray();
    }
    public static void Check(bool expectRecovery)
    {
        foreach(bool fail in new[]{false,true})
        {
            var settings=HybridLumenGIGlobalSdf.Configuration.Default;
            settings.LevelCount=1;settings.BricksPerAxis=4;settings.UpdateBrickBudget=64;
            var scene=new HybridLumenGIScene();var sdf=new HybridLumenGISdfAtlas();
            using var global=new HybridLumenGIGlobalSdf(new ComputeShader());
            var state=new ActualFailureState(global);
            global.Prepare(scene,sdf,Vector3.zero,settings);
            var initial=new CommandBuffer();Require(global.RecordUpdate(initial)==64&&global.ReadyBrickCount==64,"Initial recording must cover all pages");
            var before=Snapshot(global);Require(before.All(p=>p.ready),"Initial CPU pages not ready");
            var pages=global.PagesBuffer;
            // No native commands execute here. This branch logically discards its recorded stream.
            if(fail)state.InvalidateFailedRender();
            bool readyAfterExit=global.IsReady;
            Require(readyAfterExit==(!fail||!expectRecovery),"Failure exit readiness differs from frozen phase");
            Require(state.uploadedSoftwareVersion==(fail?0UL:9UL)&&state.historyCalls==(fail?1:0)&&state.timingCalls==(fail?1:0),"Existing failure actions changed");
            global.Prepare(scene,sdf,Vector3.zero,settings);
            int pending=global.PendingBrickCount;
            Require(pending==(fail&&expectRecovery?64:0),"Discarded pages did not match retry expectation");
            var retry=new CommandBuffer();int updated=global.RecordUpdate(retry);
            Require(updated==pending&&updated<=settings.UpdateBrickBudget,"Retry does not honor original budget");
            var after=Snapshot(global);
            Require(ReferenceEquals(pages,global.PagesBuffer)&&!pages.released,"Recovery changed resource ownership");
            if(fail&&expectRecovery)
            {
                Require(after.Zip(before).All(p=>p.First.slot==p.Second.slot&&p.First.generation!=p.Second.generation&&p.First.ready),"Recovery must advance every generation and record every retry");
                int invalidation=retry.events.IndexOf("data:HLGI global SDF pages"),merge=retry.events.IndexOf("dispatch:0"),publish=retry.events.IndexOf("dispatch:1");
                Require(invalidation>=0&&invalidation<merge&&merge<publish&&retry.events.Count(e=>e.StartsWith("dispatch:"))==2,"Retry invalidation/merge/publish order changed");
            }
            else Require(after.SequenceEqual(before)&&!retry.events.Any(e=>e.StartsWith("dispatch:")),"Stable path changed page state or rebuilt");
            global.Prepare(scene,sdf,Vector3.zero,settings);
            Require(global.PendingBrickCount==0,"Recovered recording did not settle");
            var stable=new CommandBuffer();Require(global.RecordUpdate(stable)==0&&!stable.events.Any(e=>e.StartsWith("dispatch:"))&&Snapshot(global).SequenceEqual(after),"Unchanged following frame repeated recovery");
            Console.WriteLine(JsonSerializer.Serialize(new{path=fail?"discarded-recording/common-failure-exit":"successful-recording/control",readyAfterExit,retryPending=pending,retryUpdated=updated,
                allGenerationsAdvanced=after.Zip(before).All(p=>p.First.generation!=p.Second.generation),stableFollowingUpdates=global.UpdatedBrickCount,
                state.uploadedSoftwareVersion,state.historyCalls,state.timingCalls,actualGpuExecution=false}));
        }
    }
}
