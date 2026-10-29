using System;
using System.Collections.Generic;
using System.Linq;
using System.Reflection;
using System.Text.Json;
using HybridLumenGI;
using UnityEngine;
using UnityEngine.Rendering;

static class SurfaceFailureEntry
{
    static void Require(bool value,string message){if(!value)throw new Exception(message);}
    static object Field(object value,string name)=>value.GetType().GetField(name,BindingFlags.NonPublic|BindingFlags.Public|BindingFlags.Instance).GetValue(value);
    static T Fixture<T>(string name,params object[] values)=>(T)typeof(Program).GetMethod(name,BindingFlags.NonPublic|BindingFlags.Static).Invoke(null,values);
    static uint Ready(object value)=>(uint)Field(value,"ready");
    static int[] Tiles(HybridLumenGISurfaceCache cache)=>((Array)Field(cache,"cards")).Cast<object>().Select(c=>(int)Field(c,"tile")).ToArray();
    static object[] Resources(HybridLumenGISurfaceCache cache)=>new[]{Field(cache,"metadataBuffer"),Field(cache,"rangesBuffer"),Field(cache,"indicesBuffer"),Field(cache,"anchorsBuffer"),Field(cache,"emittersBuffer"),cache.DiffuseAtlas,cache.EmissionAtlas,cache.PositionAtlas,cache.NormalAtlas,cache.DepthAtlas};
    static string Snapshot(HybridLumenGISurfaceCache cache)=>JsonSerializer.Serialize(new{
        cache.ReadyCards,cache.PendingCards,cache.ScheduledCards,cache.CapturedCards,cache.AtlasGeneration,
        layout=cache.GetLayoutGeneration(0),tiles=Tiles(cache),readyMask=cache.ReadyMask,
        cards=Enumerable.Range(0,cache.GetCardCount(0)).Select(i=>new{index=cache.GetCardIndex(0,i),generation=cache.GetGeneration(cache.GetCardIndex(0,i)),
            ready=Ready(((Array)Field(cache,"metadata")).GetValue(cache.GetCardIndex(0,i))),dirty=(bool)Field(((Array)Field(cache,"cards")).GetValue(cache.GetCardIndex(0,i)),"dirty")}).ToArray()});
    static int Main(string[] args)
    {
        bool recovery=args.Contains("--expect-recovery");
        foreach(bool fail in new[]{false,true})
        {
            var scene=new HybridLumenGIScene(1);var proxy=Fixture<HybridLumenGIProxy>("Proxy",11,2,1);scene.Set(0,proxy);
            var config=Fixture<HybridLumenGISurfaceCache.Config>("Config",2,2,4);
            using var cache=new HybridLumenGISurfaceCache();var state=new ActualFailureState(cache);
            cache.Prepare(scene,config);Require(cache.ResidentCards==2&&cache.ScheduledCards==2,"Frozen owner must start with exactly two scheduled cards");
            var first=Fixture<CommandBuffer>("Capture",cache);
            Require(cache.CapturedCards==2&&cache.ReadyCards==2&&cache.IsSlotReady(0,proxy.StableId,proxy.Revision),"Initial two-card recording is incomplete");
            Require(first.Entries.Count(e=>e.Kind=="Clear")==1&&!(bool)Field(cache,"clearPending"),"Initial atlas clear must be recorded and consumed");
            object owner=((Array)Field(cache,"owners")).GetValue(0);object[] resources=Resources(cache);int[] tiles=Tiles(cache);
            uint atlas=cache.AtlasGeneration,layout=cache.GetLayoutGeneration(0);uint[] generations=Enumerable.Range(0,2).Select(i=>cache.GetGeneration(cache.GetCardIndex(0,i))).ToArray();
            string initial=Snapshot(cache);
            // Recording adapters never execute native commands. This branch logically drops that recording.
            if(fail)state.InvalidateFailedRender();
            bool expectedRecovery=fail&&recovery;
            Require(cache.IsSlotReady(0,proxy.StableId,proxy.Revision)==!expectedRecovery,"Immediate owner readiness disagrees with the frozen branch");
            Require((bool)Field(cache,"clearPending")==expectedRecovery,"Discarded initialization clear was not restored");
            Require(state.uploadedSoftwareVersion==(fail?0UL:9UL)&&state.globalSdf.calls==(fail?1:0)&&state.historyCalls==(fail?1:0)&&state.feedbackCalls==(fail?1:0),"Existing common failure actions changed");
            string afterFailure=Snapshot(cache);config.capturesPerFrame=1;config.maxDrawsPerFrame=2;
            var snapshots=new List<string>();var commands=new List<string[]>();var captures=new List<int>();
            for(int step=0;step<3;step++)
            {
                cache.Prepare(scene,config);int expected=expectedRecovery&&step<2?1:0;
                Require(cache.ScheduledCards==expected,"Retry scheduling differs from fixed one-card budget");
                var command=Fixture<CommandBuffer>("Capture",cache);captures.Add(cache.CapturedCards);commands.Add(command.Entries.Select(e=>e.Kind).ToArray());
                Require(cache.CapturedCards==expected,"Capture did not obey original draw/capture limits");
                Require(cache.IsSlotReady(0,proxy.StableId,proxy.Revision)==(!expectedRecovery||step>=1),"Owner became ready before both cards were recaptured");
                Require(command.Entries.Count(e=>e.Kind=="Clear")==((expectedRecovery&&step==0)?1:0),"Initialization clear is missing or repeats");
                if(expected!=0)
                {
                    var entries=command.Entries;var metadata=(ComputeBuffer)Field(cache,"metadataBuffer");var uploads=entries.Where(e=>e.Kind=="Upload"&&ReferenceEquals(e.Buffer,metadata)).ToArray();
                    int draw=entries.FindIndex(e=>e.Kind=="DrawMesh"),anchor=entries.FindIndex(e=>e.Kind=="Dispatch"),publish=entries.FindLastIndex(e=>e.Kind=="Upload"&&ReferenceEquals(e.Buffer,metadata));
                    Require(entries.FindIndex(e=>e.Kind=="TileClear")<draw&&draw<anchor&&anchor<publish,"Clear/draw/anchor/ready ordering changed");
                    Require(uploads.Last().Data.Count(x=>Ready(x)!=0)==step+1,"Ready publication exceeds recovered cards");
                    if(step==0)Require(uploads.Length==2&&uploads[0].Data.All(x=>Ready(x)==0)&&entries.IndexOf(uploads[0])<entries.FindIndex(e=>e.Kind=="Clear"),"Full invalid metadata must precede clearing/recovery");
                }
                else Require(command.Entries.Count==0,"Stable/successful path recorded unnecessary work");
                Require(Resources(cache).Zip(resources).All(x=>ReferenceEquals(x.First,x.Second))&&resources.OfType<ComputeBuffer>().All(x=>!x.Released)&&resources.OfType<RTHandle>().All(x=>!x.Released),"Recovery replaced or released owned resources");
                Require(Tiles(cache).SequenceEqual(tiles)&&ReferenceEquals(owner,((Array)Field(cache,"owners")).GetValue(0))&&cache.AtlasGeneration==atlas&&cache.GetLayoutGeneration(0)==layout,"Owner/tile/atlas/layout identity changed");
                uint[] current=Enumerable.Range(0,2).Select(i=>cache.GetGeneration(cache.GetCardIndex(0,i))).ToArray();
                Require(current.Zip(generations).All(x=>x.First==(expectedRecovery?(x.Second>=0x00ffffffu?1u:x.Second+1u):x.Second)),"Per-card generation rule changed");
                snapshots.Add(Snapshot(cache));
            }
            Console.WriteLine(JsonSerializer.Serialize(new{path=fail?"discarded-recording/common-failure-exit":"successful-recording/control",initial,afterFailure,captures,commands,snapshots,
                state.uploadedSoftwareVersion,sdfCalls=state.globalSdf.calls,state.historyCalls,state.feedbackCalls,productCounterexample=fail&&!recovery}));
        }
        Console.WriteLine("PASS: actual SurfaceCache and extracted common failure method; two fixed branches, recording adapters only.");return 0;
    }
}
