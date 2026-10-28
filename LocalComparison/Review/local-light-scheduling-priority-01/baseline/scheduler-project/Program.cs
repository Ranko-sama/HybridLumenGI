using System.Reflection;
using System.Text.Json;
using HybridLumenGI;
using UnityEngine;
using L=HybridLumenGI.HybridLumenGILights;

static class Program
{
    internal static void Require(bool ok,string message){if(!ok)throw new Exception(message);}
    static void Main(string[] args)
    {
        bool candidate=args[0]=="candidate";
        var events=JsonSerializer.Deserialize<Dictionary<string,L.Data[]>>(File.ReadAllText(args[1]),new JsonSerializerOptions{IncludeFields=true});
        var rows=new List<object>();
        FeatureContext Build(L.Data[] records)
        {
            var f=new FeatureContext();foreach(var record in records)f.Append(record);
            return f;
        }
        void CheckRanges(string name,L.Data[] records,float[] centers,int globals)
        {
            var f=Build(records);Require(f.state.changes.global==globals,name+" global semantics");
            Require(f.state.changes.local.Count==centers.Length,name+" GPU local call count");
            Require(f.state.localLightChangeBounds.Count==(candidate?centers.Length:0),name+" scheduling bounds count");
            for(int i=0;i<centers.Length;i++)
            {
                var raw=f.state.changes.local[i];
                Require(raw.bounds.center==new Vector3(centers[i],0,0)&&raw.bounds.size==Vector3.one*2&&raw.influence==2,name+" original GPU range/influence changed");
                if(candidate)Require(f.state.localLightChangeBounds[i].center==raw.bounds.center && f.state.localLightChangeBounds[i].size==Vector3.one*6,name+" trace expansion mismatch");
            }
            rows.Add(new{name,globals,rawCenters=f.state.changes.local.Select(x=>x.bounds.center.x).ToArray(),schedulingCenters=f.state.localLightChangeBounds.Select(x=>x.center.x).ToArray()});
        }
        CheckRanges("initial",events["initial"],new[]{100f},0);
        CheckRanges("move",events["move"],new[]{100f,300f},0);
        CheckRanges("off",events["off"],new[]{300f},0);
        CheckRanges("directional",events["directional"],Array.Empty<float>(),1);
        using(var fixture=new Fixture())
        {
            var local=Build(events["off"]);var selected=fixture.Schedule(2,true,local.state.localLightChangeBounds);
            Require(selected.SequenceEqual(candidate?new[]{0,3}:new[]{0,1}),"Primary scheduling counterexample/correction");
            Require(fixture.scheduler.FairnessSelectedCount==1,"Original oldest-service quota changed");
            rows.Add(new{name="primary",selected,fairness=fixture.scheduler.FairnessSelectedCount});
        }
        // Duplicate local regions never accumulate. Inspect the actual pending state
        // before service, then use its real selection path.
        using(var fixture=new Fixture())
        {
            var local=Build(events["off"].Concat(events["off"]).ToArray());
            Require(fixture.Schedule(0,true,local.state.localLightChangeBounds).Length==0,"Zero budget");
            var priority=fixture.Pending();
            Require(priority[3]==(candidate?1000:750)&&priority.Take(3).All(x=>x==750),"Duplicate regions accumulated or replaced global dirtiness");
            local.state.localLightChangeBounds.Clear();
            var selected=fixture.Schedule(2,false,local.state.localLightChangeBounds);
            Require(selected.SequenceEqual(candidate?new[]{0,3}:new[]{0,1}),"Cleared event lost pending priority");
            rows.Add(new{name="duplicate-zero-budget",priority,selected,eventListAfterClear=local.state.localLightChangeBounds.Count});
        }
        using(var fixture=new Fixture())
        {
            var local=Build(events["off"]);fixture.surface.ReadyMask[3]=false;
            Require(fixture.Schedule(0,true,local.state.localLightChangeBounds).Length==0,"Missing-page zero budget");
            local.state.localLightChangeBounds.Clear();fixture.surface.ReadyMask[3]=true;
            var selected=fixture.Schedule(2,false,local.state.localLightChangeBounds);
            Require(selected.SequenceEqual(candidate?new[]{0,3}:new[]{0,1}),"Missing page lost priority after event list cleared");
            rows.Add(new{name="page-ready-next-frame",selected,eventListAfterClear=local.state.localLightChangeBounds.Count});
        }
        foreach(var control in new[]{"no-local","directional"})using(var fixture=new Fixture())
        {
            var local=Build(control=="directional"?events["directional"]:Array.Empty<L.Data>());
            var selected=fixture.Schedule(2,true,control=="no-local"?null:local.state.localLightChangeBounds);
            Require(selected.SequenceEqual(new[]{0,1}),control+" changed legacy selection");
            rows.Add(new{name=control,selected});
        }
        using(var fixture=new Fixture())
        {
            var local=Build(events["off"]);var seen=new HashSet<int>();var sequence=new List<int[]>();
            for(int i=0;i<4;i++)
            {
                var selected=fixture.Schedule(2,true,local.state.localLightChangeBounds);
                Require(selected.Length==2&&fixture.scheduler.FairnessSelectedCount==1,"Hard budget/fairness changed");
                foreach(int index in selected)seen.Add(index);sequence.Add(selected);
            }
            Require(seen.Count==4,"Repeated local priority starved distant patches");
            rows.Add(new{name="fixed-four-frame-fairness",sequence,served=seen.Order().ToArray()});
        }
        File.WriteAllText(args[2],JsonSerializer.Serialize(new{passed=true,candidate,rows},new JsonSerializerOptions{WriteIndented=true}));
        Console.WriteLine("PASS: actual scheduler selection, original quota/hard/zero budget, duplicate max, pending event after cleared list, absent/returned page, directional/no-local and fixed fairness controls. No Unity/GPU or measured quality/performance claim.");
    }
}

sealed class Fixture:IDisposable
{
    internal HybridLumenGIScene scene=new();
    internal HybridLumenGICacheScheduler scheduler=new();
    internal HybridLumenGISurfaceCache surface;
    int frame;
    readonly MethodInfo prepare=typeof(HybridLumenGICacheScheduler).GetMethod("Prepare");
    public Fixture()
    {
        HybridLumenGIProxy.ActiveProxies.Clear();
        for(int i=0;i<4;i++)HybridLumenGIProxy.ActiveProxies.Add(new HybridLumenGIProxy{StableId=i+1,bounds=new Bounds(new Vector3(i*100,0,0),Vector3.one)});
        scene.Prepare(Vector3.zero,32,1000,1000,16,32);
        scene.Prepare(Vector3.zero,32,1000,1000,16,32);
        Program.Require(scene.DirtyRegions.Count==0,"Unconsumed scene change would confound local-light priority");
        int[] owners=Enumerable.Range(1,4).Select(id=>Array.FindIndex(scene.Data,x=>(int)x.identity.x==id)).ToArray();
        Program.Require(owners.All(x=>x>=0),"Actual residency missing fixture owner");
        surface=new HybridLumenGISurfaceCache(owners,scene.Capacity);
        Program.Require(Schedule(4,false,null).SequenceEqual(new[]{0,1,2,3}),"Warmup all ready patches");
        Program.Require(scheduler.ScheduledCoverage==1&&Enumerable.Range(0,4).Select(scheduler.LastScheduledFrame).Distinct().Count()==1,"Stable equal-service starting state required");
    }
    internal int[] Schedule(int budget,bool lighting,IReadOnlyList<Bounds> bounds)
    {
        var args=new List<object>{scene,surface,1,frame++,budget,lighting,0f,false};
        if(prepare.GetParameters().Length==9)args.Add(bounds);
        prepare.Invoke(scheduler,args.ToArray());
        return Enumerable.Range(0,scheduler.Mask.Length).Where(i=>scheduler.Mask[i]!=0).ToArray();
    }
    internal float[] Pending()=>(float[])((float[])typeof(HybridLumenGICacheScheduler).GetField("pendingPriority",BindingFlags.Instance|BindingFlags.NonPublic).GetValue(scheduler)).Clone();
    public void Dispose(){scheduler.Dispose();scene.Dispose();}
}

public partial class FeatureContext
{
    public sealed class Settings {public float traceDistance=2;}
    public sealed class Changes
    {
        public int global;public List<(Bounds bounds,float influence)> local=new();
        public void MarkGlobalLightingChange(){global++;}
        public void Add(Bounds b,bool geometry,float influence){Program.Require(!geometry,"Light classified as geometry");local.Add((b,influence));}
    }
    public sealed class CameraState {public readonly Changes changes=new();public readonly List<Bounds> localLightChangeBounds=new(64);}
    readonly Settings s=new();public readonly CameraState state=new();
    public void Append(L.Data value){AddLightChange(state,value);}
}
namespace UnityEngine
{
    public partial struct Vector3 { public static explicit operator Vector3(Vector4 v)=>new(v.x,v.y,v.z); }
}
