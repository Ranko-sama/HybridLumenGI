using HybridLumenGI;
using UnityEngine;
using UnityEngine.Rendering;
using System.Reflection;
using System.Runtime.InteropServices;
int checks=0;
void Require(bool condition,string message){checks++;if(!condition)throw new Exception(message);}
object Field(object obj,string name)=>obj.GetType().GetField(name,BindingFlags.Public|BindingFlags.Instance).GetValue(obj);
var settings=HybridLumenGIGlobalSdf.Configuration.Default;
settings.LevelCount=2;settings.BricksPerAxis=4;settings.UpdateBrickBudget=7;settings.MaxDistanceInBricks=.5f;
var scene=new HybridLumenGIScene();var sdf=new HybridLumenGISdfAtlas();var shader=new ComputeShader();
using var global=new HybridLumenGIGlobalSdf(shader);
var camera=Vector3.zero;
void Frame()
{
    global.Prepare(scene,sdf,camera,settings);
    var commands=new CommandBuffer();global.RecordUpdate(commands);
    Require(global.UpdatedBrickCount<=settings.UpdateBrickBudget,"Exceeded per-frame brick budget.");
}
void Drain()
{
    for(int i=0;i<100;i++){Frame();if(global.PendingBrickCount==0)return;}
    throw new Exception("Static scene failed to make scheduling progress.");
}
global.Prepare(scene,sdf,camera,settings);
Require(global.PendingBrickCount==128&&global.ReadyBrickCount==0&&!global.IsReady,"Fresh pages must be unknown.");
var before=new CommandBuffer();global.Bind(before,shader,0);
Require(before.ints["_HLGI_GlobalSdfLevelCount"]==0,"Query enabled before invalidations were queued.");
var first=new CommandBuffer();global.RecordUpdate(first);
Require(first.events.IndexOf("data:HLGI global SDF pages")<first.events.IndexOf("dispatch:0")&&first.events.IndexOf("dispatch:0")<first.events.IndexOf("dispatch:1"),"Invalidation/merge/publish command order is wrong.");
Require(global.UpdatedBrickCount==7&&global.ReadyBrickCount==7&&global.PendingBrickCount==121,"Scheduled diagnostics wrong.");
Require(global.RecordUpdate(first)==0,"Duplicate RecordUpdate submitted work twice.");
Require(global.PagesBuffer.data.All(p=>(uint)Field(p,"ready")==0),"CPU optimistically published selected pages before GPU writes.");
Require(global.DistancesBuffer.data.All(v=>(float)v==0),"Generation words must start invalid.");
foreach(var name in new[]{"Page","Level","Job","ObjectBounds"})Require(Marshal.SizeOf(typeof(HybridLumenGIGlobalSdf).GetNestedType(name,BindingFlags.NonPublic))==32,"GPU struct stride mismatch: "+name);
Drain();Require(global.IsReady&&global.ReadyBrickCount==128,"Pages failed to become scheduled resident.");
Frame();Require(global.UpdatedBrickCount==0&&global.PendingBrickCount==0,"Unchanged frame recomposed pages.");
Require(global.TryGetPage(0,0,0,0,out int originPage,out uint generation,out bool ready)&&ready,"Origin page not resident.");
settings.UpdateBrickBudget=0;camera=new Vector3(2,0,0);global.Prepare(scene,sdf,camera,settings);
Require(global.PendingBrickCount==16,"One finest-level brick shift must expose exactly one 4x4 slab.");
global.RecordUpdate(new CommandBuffer());
Require(global.TryGetPage(0,0,0,0,out int overlapPage,out uint overlapGeneration,out bool overlapReady)&&overlapReady&&originPage==overlapPage&&generation==overlapGeneration,"Clipmap shift lost overlap reuse.");
camera=new Vector3(8,0,0);global.Prepare(scene,sdf,camera,settings);
Require(!global.TryGetPage(0,0,0,0,out _,out _,out _),"Rolled-out world key is still addressable.");
Require(global.TryGetPage(0,4,0,0,out int wrapPage,out uint wrapGeneration,out bool wrapReady)&&wrapPage==originPage&&wrapGeneration!=generation&&!wrapReady,"Toroidal collision reused old world data.");
camera=Vector3.zero;global.Prepare(scene,sdf,camera,settings);
Require(global.TryGetPage(0,0,0,0,out int returnedPage,out uint returnedGeneration,out bool returnedReady)&&returnedPage==originPage&&returnedGeneration!=generation&&!returnedReady,"Returning to old world location resurrected stale page.");
camera=new Vector3(-.01f,-.01f,-.01f);global.Prepare(scene,sdf,camera,settings);
Require(global.TryGetPage(0,-3,-3,-3,out _,out _,out _)&&!global.TryGetPage(0,1,1,1,out _,out _,out _),"Negative world coordinates were truncated instead of floored.");
for(int axis=4;axis<=16;axis*=2)
for(int ox=-19;ox<20;ox+=7)
{
    var mapped=new HashSet<int>();
    for(int z=ox;z<ox+axis;z++)for(int y=ox;y<ox+axis;y++)for(int x=ox;x<ox+axis;x++)mapped.Add(HybridLumenGIGlobalSdf.PhysicalPage(x,y,z,axis));
    Require(mapped.Count==axis*axis*axis&&mapped.Min()==0&&mapped.Max()==axis*axis*axis-1,"Modulo mapping is not bijective.");
}
camera=Vector3.zero;settings.UpdateBrickBudget=1024;Drain();settings.UpdateBrickBudget=0;
scene.DirtyRegions.Add(new(){HasCurrent=true,CurrentBounds=new Bounds(new Vector3(1000,0,0),Vector3.one)});
global.Prepare(scene,sdf,camera,settings);Require(global.PendingBrickCount==0,"Far-away change invalidated all pages.");global.RecordUpdate(new CommandBuffer());scene.DirtyRegions.Clear();
scene.DirtyRegions.Add(new(){HasPrevious=true,PreviousBounds=new Bounds(new Vector3(4.1f,0,0),new Vector3(.1f,.1f,.1f)),HasCurrent=true,CurrentBounds=new Bounds(new Vector3(-4.1f,0,0),new Vector3(.1f,.1f,.1f))});
global.Prepare(scene,sdf,camera,settings);Require(global.PendingBrickCount>0&&global.PendingBrickCount<128,"Local old/new geometry change did not invalidate only affected distance neighborhoods.");
Require(global.TryGetPage(0,1,0,0,out _,out _,out bool positiveReady)&&!positiveReady&&global.TryGetPage(0,-2,0,0,out _,out _,out bool negativeReady)&&!negativeReady,"Neighbor distance pages outside the object bounds were not invalidated.");
scene.DirtyRegions.Clear();settings.UpdateBrickBudget=1024;Drain();settings.UpdateBrickBudget=0;
sdf.RepresentationChangedBounds.Add(new Bounds(Vector3.zero,Vector3.one*.1f));global.Prepare(scene,sdf,camera,settings);
Require(global.PendingBrickCount>0,"SDF upload-ready representation changes were ignored.");
sdf.RepresentationChangedBounds.Clear();settings.UpdateBrickBudget=1024;Drain();settings.UpdateBrickBudget=0;
scene.Data[0]=new(){centerShape=new Vector4(0,0,0,0),extentsRoughness=new Vector4(1,1,1,0),identity=new Vector4(1,1,0,2)};
scene.Proxies[0]=new(){Renderer=new Renderer{bounds=new Bounds(Vector3.zero,Vector3.one*2)}};
global.Prepare(scene,sdf,camera,settings);Require(global.PendingBrickCount==0,"Warming HLOD geometry entered the published global field.");global.RecordUpdate(new CommandBuffer());
Require(((Vector4)Field(global.ObjectBoundsBuffer.data[0],"maximum")).w==0,"Warming object bounds were published.");
scene.Data[0].identity.w=1;global.Prepare(scene,sdf,camera,settings);Require(global.PendingBrickCount>0,"Newly published geometry did not invalidate pages.");global.RecordUpdate(new CommandBuffer());
Require(((Vector4)Field(global.ObjectBoundsBuffer.data[0],"minimum")).w==1,"Renderer bounds safety clamp was not enabled.");
settings.UpdateBrickBudget=1024;Drain();settings.UpdateBrickBudget=0;
scene.Proxies[0].Renderer.bounds=new Bounds(new Vector3(3,0,0),Vector3.one*2);global.Prepare(scene,sdf,camera,settings);
Require(global.PendingBrickCount>0,"Renderer bound change was missed without a scene revision.");
settings.UpdateBrickBudget=1024;Drain();global.InvalidateAll();
Require(!global.IsReady,"Cancelled update invalidation left IsReady true.");global.Prepare(scene,sdf,camera,settings);Require(global.PendingBrickCount==128,"Cancelled commands did not cause retry of all pages.");
global.RecordUpdate(new CommandBuffer());settings.BaseVoxelSize*=2;global.Prepare(scene,sdf,camera,settings);Require(global.PendingBrickCount==128,"Clipmap metric change reused old distances.");
global.RecordUpdate(new CommandBuffer());scene.RequiresFullInvalidation=true;global.Prepare(scene,sdf,camera,settings);Require(global.PendingBrickCount==128,"Scene hard invalidation was ignored.");
Require(global.AllocatedBytes>0,"Memory diagnostic is missing.");
var buffer=global.PagesBuffer;global.Dispose();Require(buffer.released&&global.AllocatedBytes==0&&!global.IsReady,"Dispose did not release clipmap resources.");
Console.WriteLine($"Actual-source global SDF scheduler: {checks} assertions passed. Unity/GPU APIs are recording shims; shader math is checked separately.");
NonGeometricDirty.Check(args.Contains("--expect-nongeometric-reuse"));
