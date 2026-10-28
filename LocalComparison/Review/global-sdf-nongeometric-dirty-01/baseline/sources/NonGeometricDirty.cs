using HybridLumenGI;
using UnityEngine;
using UnityEngine.Rendering;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Kind=HybridLumenGI.HybridLumenGIScene.ChangeKind;

static class NonGeometricDirty
{
    static void Require(bool value,string message){if(!value)throw new Exception(message);}
    static (int slot,uint generation,bool ready)[] Snapshot(HybridLumenGIGlobalSdf global)
    {
        var result=new List<(int,uint,bool)>();
        for(int level=0;level<2;level++)for(int z=-2;z<2;z++)for(int y=-2;y<2;y++)for(int x=-2;x<2;x++)
        {
            Require(global.TryGetPage(level,x,y,z,out int slot,out uint generation,out bool ready),"Expected page key missing");
            result.Add((slot,generation,ready));
        }
        Require(result.Count==128&&result.Select(p=>p.Item1).Distinct().Count()==128,"Both levels/all physical slots required");
        return result.ToArray();
    }
    static string Hash((int slot,uint generation,bool ready)[] pages)=>Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(string.Join("|",pages.Select(p=>$"{p.slot},{p.generation},{p.ready}")))));
    public static void Check(bool expectReuse)
    {
        var cases=new (string label,Kind kind,string extra)[]{
            ("material",Kind.Material,"pure"),("lighting-policy",Kind.Lighting,"pure"),("material-and-policy",Kind.Material|Kind.Lighting,"pure"),
            ("mixed-geometry",Kind.Material|Kind.Transform,"geometry"),("zero-kind",0,"geometry"),("unknown-kind",(Kind)32768,"geometry"),
            ("material-plus-representation",Kind.Material,"representation"),("policy-plus-renderer-bounds",Kind.Lighting,"bounds"),
            ("material-with-existing-backlog",Kind.Material,"backlog")};
        foreach(var spec in cases)
        {
            bool partial=spec.extra=="backlog",pure=spec.extra=="pure";
            var settings=HybridLumenGIGlobalSdf.Configuration.Default;
            settings.LevelCount=2;settings.BricksPerAxis=4;settings.UpdateBrickBudget=partial?7:128;
            var scene=new HybridLumenGIScene();var sdf=new HybridLumenGISdfAtlas();
            if(spec.extra=="bounds")
            {
                scene.Data[0]=new(){centerShape=new Vector4(0,0,0,0),extentsRoughness=new Vector4(1,1,1,0),identity=new Vector4(1,1,0,1)};
                scene.Proxies[0]=new(){Renderer=new Renderer{bounds=new Bounds(Vector3.zero,Vector3.one*2)}};
            }
            using var global=new HybridLumenGIGlobalSdf(new ComputeShader());
            global.Prepare(scene,sdf,Vector3.zero,settings);
            Require(global.LevelCount==2&&global.PagesBuffer.count==128&&global.PendingBrickCount==128&&global.ReadyBrickCount==0,"Legal fresh128-page premise");
            Require(global.RecordUpdate(new CommandBuffer())==settings.UpdateBrickBudget,"Initial budget not consumed");
            var before=Snapshot(global);var buffer=global.PagesBuffer;
            Require(global.ReadyBrickCount==(partial?7:128)&&global.PendingBrickCount==(partial?121:0)&&before.Count(p=>p.ready)==(partial?7:128),"Initial full-ready/backlog premise");
            var bounds=new Bounds(Vector3.zero,Vector3.one*.1f);
            scene.DirtyRegions.Add(new(){Kind=spec.kind,HasPrevious=true,HasCurrent=true,PreviousBounds=bounds,CurrentBounds=bounds});
            if(spec.extra=="representation")sdf.RepresentationChangedBounds.Add(bounds);
            if(spec.extra=="bounds")scene.Proxies[0].Renderer.bounds=new Bounds(new Vector3(3,0,0),Vector3.one*2);
            global.Prepare(scene,sdf,Vector3.zero,settings);
            int pending=global.PendingBrickCount,invalidated=global.InvalidatedBrickCount;
            int expectedPending=partial?(expectReuse?121:128):(pure&&expectReuse?0:128);
            int expectedInvalidated=(pure||partial)&&expectReuse?0:(partial?7:128);
            Require(pending==expectedPending&&invalidated==expectedInvalidated,"Dirty classification lost or added geometry work: "+spec.label);
            Require(scene.DirtyRegions.Count==1&&scene.DirtyRegions[0].Kind==spec.kind,"Shared scene event changed");
            var command=new CommandBuffer();int updated=global.RecordUpdate(command);var after=Snapshot(global);
            Require(updated==Math.Min(pending,settings.UpdateBrickBudget),"Existing pending work/budget lost");
            Require(ReferenceEquals(buffer,global.PagesBuffer)&&!buffer.released,"Resource ownership changed");
            int dispatches=command.events.Count(e=>e.StartsWith("dispatch:"));
            Require(dispatches==(updated==0?0:2),"Unexpected merge/publish work");
            if(updated>0)Require(command.events.IndexOf("data:HLGI global SDF pages")<command.events.IndexOf("dispatch:0")&&command.events.IndexOf("dispatch:0")<command.events.IndexOf("dispatch:1"),"Invalidation/merge/publish order changed");
            if(pure&&expectReuse)Require(after.SequenceEqual(before),"Nongeometric event changed ready page state");
            if(partial&&expectReuse)
            {
                Require(after.Zip(before).All(p=>p.First.generation==p.Second.generation&&(!p.Second.ready||p.First.ready)),"Existing ready pages were invalidated");
                Require(global.ReadyBrickCount==14&&global.PendingBrickCount==114,"Existing backlog did not make progress");
            }
            Console.WriteLine(JsonSerializer.Serialize(new{spec.label,kind=(int)spec.kind,beforeHash=Hash(before),afterHash=Hash(after),pendingBeforeRecord=pending,invalidated,updated,
                readyAfterRecord=global.ReadyBrickCount,pendingAfterRecord=global.PendingBrickCount,dispatches,sharedEventRetained=true,actualGpuExecution=false}));
        }
    }
}
