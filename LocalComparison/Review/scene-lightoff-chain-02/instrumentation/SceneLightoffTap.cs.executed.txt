// Test-project-only observation. The controller changes only the real Light.
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Runtime.InteropServices;
using UnityEngine;
using UnityEngine.Rendering;
using HybridLumenGI;

public static class SceneLightoffTap
{
    static readonly bool requested=Array.IndexOf(Environment.GetCommandLineArgs(),"-sceneLightoffProbe")>=0;
    public static bool Enabled=>requested&&!finished;
    public static readonly int[] Samples={119,120,121,123,127,135,151,239,359};
    // Same two original C controls, plus two fixed points on the other half of the floor.
    static readonly Vector3[] Points={new Vector3(6.5f,0,-.5f),new Vector3(6.5f,0,1.2f),new Vector3(9.5f,0,-.5f),new Vector3(9.5f,0,1.2f)};
    static readonly int[] X={160,100,220,100},Y={45,90,90,30};
    static ComparisonCapture capture;static Light lamp;static GraphicsBuffer records;
    static bool finished,warmupPassed;static int pending,errors;
    static readonly HashSet<string> completed=new HashSet<string>();
    static readonly Dictionary<int,Selection[]> selections=new Dictionary<int,Selection[]>();
    static readonly Dictionary<int,Selection[]> pointRules=new Dictionary<int,Selection[]>();
    static readonly Dictionary<int,int[]> pointAliases=new Dictionary<int,int[]>();
    static readonly Dictionary<int,byte[]> observedCache=new Dictionary<int,byte[]>();
    static readonly Dictionary<string,byte[]> actualCache=new Dictionary<string,byte[]>();
    static readonly Dictionary<int,int> workFrames=new Dictionary<int,int>(),epochs=new Dictionary<int,int>();
    static readonly HashSet<int> observationReserved=new HashSet<int>();
    public static bool CompletionProven=>pending==0;
    const BindingFlags Fields=BindingFlags.Instance|BindingFlags.Public|BindingFlags.NonPublic;
    static object Field(object value,string name)=>value.GetType().GetField(name,Fields).GetValue(value);
    [StructLayout(LayoutKind.Sequential)] struct Seed {public Vector4 a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t;}
    [Serializable] public class Selection
    {
        public int lane,entry=-1,card=-1,slot=-1,cellX,cellY,stableId,revision;
        public uint generation,layout,chart;
        public bool ready,published;
        public Vector3 point,projected;
        public Selection Copy()=>(Selection)MemberwiseClone();
        public LightoffPatchMap.Identity Identity()=>new LightoffPatchMap.Identity{entry=entry,card=card,slot=slot,stableId=stableId,revision=revision,
            layout=layout,chart=chart,generation=generation,cellX=cellX,cellY=cellY};
    }
    [Serializable] class Command {public int logicalFrame,engineFrame,lampInstance;public bool enabled;public Vector3 lampPosition,doorPosition,cameraPosition;}
    [Serializable] class ChangeRow {public Vector4 minimum,maximum,receiver;}
    [Serializable] class ChangeSnapshot {public int count;public float globalLighting,globalGeometry;public ChangeRow[] regions;}
    [Serializable] class LightRecord
    {
        public Vector4 positionType,directionRange,color,spot;public uint cullingMask,renderingLayers,shadowRenderingLayers,flags;
        public static LightRecord From(HybridLumenGILights.Data d)=>new LightRecord{positionType=d.positionType,directionRange=d.directionRange,color=d.color,spot=d.spot,
            cullingMask=d.cullingMask,renderingLayers=d.renderingLayers,shadowRenderingLayers=d.shadowRenderingLayers,flags=d.flags};
    }
    [Serializable] class LightUpdate {public int logicalFrame,engineFrame,giFrame,previousCount,count,lampInstance;public bool lampEnabled;public string phase;public LightRecord[] records,changes;public ChangeSnapshot domains;}
    [Serializable] class Owner {public int slot,stableId,revision;public string name;public bool active,published,ready;public Color emission;public uint layout;}
    [Serializable] class Candidate {public int entry;public float priority;public long previousService,newService;public uint selected;public int lastScheduledFrame;}
    [Serializable] class RegionSource {public string source;public int kind,slot,stableId;public Vector3 minimum,maximum;}
    [Serializable] class Schedule
    {
        public int logicalFrame,engineFrame,giFrame,readBuffer,writeBuffer,epoch,patchGrid,requestedBudget,effectiveBudget,valid,selected,fairness,unscheduled;
        public long tick,maxAge;public bool lightingChanged;public uint[] cpuMask;
        public Owner[] owners;public Candidate[] candidates;public Selection[] patches,points;public int[] aliases;public ChangeSnapshot domains;
        public bool[] readyCards;public int[] cardOwners;public uint[] cardGenerations;public RegionSource[] regionSources;
        public int dirtyScene,changedSurface,changedRepresentation,changedGeometry;
    }
    [Serializable] class Binding {public int logicalFrame,engineFrame,giFrame,cacheRead,cacheWrite,gatherRead,lightCount,areaCount;public bool exact,distinct;}
    [Serializable] class Receipt {public int logicalFrame,engineFrame,giFrame,bytes,stride,count,activeCount;public string stage;}
    [Serializable] class Summary {public bool collected,warmupPassed,passed;public int errors,pending,files;public string[] missing;}
    public static GraphicsBuffer Records
    {
        get{if(!Enabled)throw new Exception("Light-off observer admission closed");if(records==null){records=new GraphicsBuffer(GraphicsBuffer.Target.Structured,4,320);records.SetData(new Seed[4]);}return records;}
    }
    static bool Target(Camera camera,out int logical,out string directory)
    {
        logical=-1;directory=null;if(!Enabled)return false;
        if(!capture)capture=UnityEngine.Object.FindFirstObjectByType<ComparisonCapture>();
        if(!capture||capture.camera!=camera)return false;
        logical=(int)Field(capture,"logicalFrame");directory=(string)Field(capture,"directory");
        return logical>=0&&logical<360&&!string.IsNullOrEmpty(directory);
    }
    public static bool Wants(int frame)=>Enabled&&Array.IndexOf(Samples,frame)>=0;
    static void Json(string directory,string filename,object value,bool append=false)
    {if(append)File.AppendAllText(Path.Combine(directory,filename),JsonUtility.ToJson(value)+"\n");else File.WriteAllText(Path.Combine(directory,filename),JsonUtility.ToJson(value,true));}
    static void Failure(Exception error){errors++;Debug.LogError("SCENE_LIGHTOFF_OBSERVER_FAILED: "+error);}
    public static void Apply(ComparisonCapture owner,int logical,Vector3 doorOrigin)
    {
        if(errors!=0)throw new Exception("Stop after failed observer callback");
        capture=owner;
        if(!lamp)lamp=owner.lights.Single(l=>l.name=="Behind thin wall");
        if(lamp.type!=LightType.Point||Vector3.Distance(lamp.transform.position,new Vector3(8,2,2))>1e-5f||lamp.range!=5)throw new Exception("Fixed source identity/position/range changed");
        owner.door.localPosition=doorOrigin;owner.camera.transform.SetPositionAndRotation(owner.thinView.position,owner.thinView.rotation);
        foreach(var light in owner.lights)light.enabled=light==lamp&&logical<120;
        if(!Target(owner.camera,out int frame,out string directory)||frame!=logical)throw new Exception("Controller frame/source mismatch");
        Json(directory,"lightoff-commands.jsonl",new Command{logicalFrame=logical,engineFrame=Time.frameCount,lampInstance=lamp.GetInstanceID(),enabled=lamp.enabled,
            lampPosition=lamp.transform.position,doorPosition=owner.door.localPosition,cameraPosition=owner.camera.transform.position},true);
        FrameTimingManager.CaptureFrameTimings();
    }
    static ChangeSnapshot Changes(object state)
    {
        var source=Field(state,"changes");int count=(int)Field(source,"count");var array=(Array)Field(source,"regions");
        return new ChangeSnapshot{count=count,globalLighting=(float)Field(source,"globalReactive"),globalGeometry=(float)Field(source,"globalGeometryChange"),
            regions=Enumerable.Range(0,count).Select(i=>{var r=array.GetValue(i);return new ChangeRow{minimum=(Vector4)Field(r,"minimum"),maximum=(Vector4)Field(r,"maximum"),receiver=(Vector4)Field(r,"receiver")};}).ToArray()};
    }
    public static void Lights(object state,string phase,int count)
    {
        var camera=(Camera)Field(state,"camera");if(!Target(camera,out int logical,out string directory))return;
        int previous=(int)Field(state,"previousLightCount");var data=(HybridLumenGILights.Data[])Field(state,"lightData");
        Json(directory,"lightoff-lights.jsonl",new LightUpdate{logicalFrame=logical,engineFrame=Time.frameCount,giFrame=(int)Field(state,"frame"),
            previousCount=previous,count=count,lampInstance=lamp.GetInstanceID(),lampEnabled=lamp.enabled,phase=phase,records=data.Take(count).Select(LightRecord.From).ToArray(),
            changes=((List<HybridLumenGILights.Data>)Field(state,"lightChanges")).Select(LightRecord.From).ToArray(),domains=Changes(state)},true);
    }
    static Selection[] Select(object state)
    {
        var scene=(HybridLumenGIScene)Field(state,"scene");var surface=(HybridLumenGISurfaceCache)Field(state,"surfaceCache");
        int grid=(int)Field(state,"patchGrid");var metadata=(Array)Field(surface,"metadata");var selected=new Selection[4];
        for(int lane=0;lane<4;lane++)
        {
            var row=new Selection{lane=lane,point=Points[lane]};selected[lane]=row;
            int owner=-1;for(int slot=0;slot<scene.Capacity;slot++){var proxy=scene.GetProxy(slot);if(proxy&&proxy.name=="Thin-wall floor"){if(owner!=-1)throw new Exception("Ambiguous fixed floor");owner=slot;}}
            if(owner<0)continue;
            float best=-1;uint bestChart=uint.MaxValue;
            for(int card=0;card<surface.CardCount;card++)
            {
                if(surface.CardOwners[card]!=owner)continue;var meta=metadata.GetValue(card);
                var direction=(Vector4)Field(meta,"directionTolerance");float facing=Vector3.Dot((Vector3)direction,Vector3.up);
                var projected=((Matrix4x4)Field(meta,"worldToCard")).MultiplyPoint3x4(Points[lane]);
                uint chart=(uint)Field(meta,"chartId");
                if(facing<.85f||projected.x<0||projected.x>1||projected.y<0||projected.y>1||projected.z<0||projected.z>1||
                    facing<best||(facing==best&&chart>=bestChart))continue;
                best=facing;bestChart=chart;var identity=scene.Data[owner].identity;
                row.card=card;row.slot=owner;row.chart=chart;row.projected=projected;row.cellX=Mathf.Min(grid-1,(int)(projected.x*grid));row.cellY=Mathf.Min(grid-1,(int)(projected.y*grid));
                row.entry=card*grid*grid+row.cellY*grid+row.cellX;row.stableId=(int)identity.x;row.revision=(int)identity.y;
                row.generation=surface.GetGeneration(card);row.layout=surface.GetLayoutGeneration(owner);row.published=scene.IsPublished(owner);
                row.ready=surface.ReadyMask[card]&&surface.IsSlotReady(owner,row.stableId,row.revision);
            }
        }
        return selected;
    }
    public static void Scheduled(object state,int giFrame,int cacheRead,int requestedBudget,float influence)
    {
        if(!Target((Camera)Field(state,"camera"),out int logical,out string directory))return;
        var scheduler=(HybridLumenGICacheScheduler)Field(state,"scheduler");var scene=(HybridLumenGIScene)Field(state,"scene");var surface=(HybridLumenGISurfaceCache)Field(state,"surfaceCache");
        var candidates=(Array)Field(scheduler,"candidates");var service=(long[])Field(scheduler,"lastService");
        var rows=Enumerable.Range(0,scheduler.ValidEntryCount).Select(i=>{var c=candidates.GetValue(i);int entry=(int)Field(c,"index");return new Candidate{
            entry=entry,priority=(float)Field(c,"priority"),previousService=(long)Field(c,"lastService"),newService=service[entry],
            selected=scheduler.Mask[entry],lastScheduledFrame=scheduler.LastScheduledFrame(entry)};}).ToArray();
        var owners=new List<Owner>();for(int slot=0;slot<scene.Capacity;slot++){
            var proxy=scene.GetProxy(slot);if(!proxy)continue;var id=scene.Data[slot].identity;
            owners.Add(new Owner{slot=slot,name=proxy.name,stableId=(int)id.x,revision=(int)id.y,active=id.w>.5f,published=scene.IsPublished(slot),
                ready=surface.IsSlotReady(slot,(int)id.x,(int)id.y),emission=proxy.GetEmissionLinear(),layout=surface.GetLayoutGeneration(slot)});
        }
        var points=Select(state);var mapping=LightoffPatchMap.Build(points.Select(p=>p.Identity()).ToArray());
        var patches=mapping.representatives.Select((point,lane)=>{var p=points[point].Copy();p.lane=lane;return p;}).ToArray();
        if(logical==0 && (points.Length!=4 || patches.Length!=2 || patches.Any(p=>p.entry<0) ||
            patches.Select(p=>p.entry).Distinct().Count()!=2 || !mapping.aliases.SequenceEqual(new[]{0,0,1,1})))
            throw new Exception("First-frame fixed geometric rules/unique addresses/aliases do not match the frozen C mapping");
        pointRules.Add(logical,points);pointAliases.Add(logical,mapping.aliases);
        selections.Add(logical,patches);workFrames.Add(logical,giFrame);epochs.Add(logical,(int)Field(state,"epoch"));
        if(logical>119)for(int point=0;point<4;point++){
            var a=pointRules[119][point];var b=points[point];
            if(pointAliases[119][point]!=mapping.aliases[point]||a.entry!=b.entry||a.card!=b.card||!LightoffPatchMap.Same(a.Identity(),b.Identity())||!b.ready||!b.published)
                throw new Exception("Fixed patch mapping/identity changed after119");
        }
        var sdf=(HybridLumenGISdfAtlas)Field(state,"sdf");var regionSources=new List<RegionSource>();
        foreach(var dirty in scene.DirtyRegions){
            if(dirty.HasPrevious)regionSources.Add(new RegionSource{source="scene-previous",kind=(int)dirty.Kind,slot=dirty.Slot,stableId=dirty.StableId,minimum=dirty.PreviousBounds.min,maximum=dirty.PreviousBounds.max});
            if(dirty.HasCurrent)regionSources.Add(new RegionSource{source="scene-current",kind=(int)dirty.Kind,slot=dirty.Slot,stableId=dirty.StableId,minimum=dirty.CurrentBounds.min,maximum=dirty.CurrentBounds.max});
        }
        foreach(var bounds in surface.ChangedBounds)regionSources.Add(new RegionSource{source="surface",minimum=bounds.min,maximum=bounds.max});
        foreach(var bounds in sdf.RepresentationChangedBounds)regionSources.Add(new RegionSource{source="representation",minimum=bounds.min,maximum=bounds.max});
        foreach(var bounds in sdf.GeometryChangedBounds)regionSources.Add(new RegionSource{source="sdf-geometry",minimum=bounds.min,maximum=bounds.max});
        foreach(var bounds in sdf.TransformChangedBounds)regionSources.Add(new RegionSource{source="sdf-transform",minimum=bounds.min,maximum=bounds.max});
        var snapshot=new Schedule{logicalFrame=logical,engineFrame=Time.frameCount,giFrame=giFrame,readBuffer=cacheRead,writeBuffer=1-cacheRead,
            epoch=(int)Field(state,"epoch"),patchGrid=(int)Field(state,"patchGrid"),requestedBudget=requestedBudget,effectiveBudget=Mathf.Clamp(requestedBudget,0,scheduler.ValidEntryCount),
            valid=scheduler.ValidEntryCount,selected=scheduler.SelectedCount,fairness=scheduler.FairnessSelectedCount,unscheduled=scheduler.UnscheduledEntryCount,
            tick=(long)Field(scheduler,"tick"),maxAge=scheduler.MaxFramesSinceUpdate,lightingChanged=(bool)Field(state,"lightingChanged"),
            cpuMask=(uint[])scheduler.Mask.Clone(),owners=owners.ToArray(),candidates=rows,patches=patches,points=points,aliases=mapping.aliases,domains=Changes(state),
            readyCards=(bool[])surface.ReadyMask.Clone(),cardOwners=(int[])surface.CardOwners.Clone(),
            cardGenerations=Enumerable.Range(0,surface.CardCount).Select(surface.GetGeneration).ToArray(),regionSources=regionSources.ToArray(),
            dirtyScene=scene.DirtyRegions.Count,changedSurface=surface.ChangedBounds.Count,
            changedRepresentation=sdf.RepresentationChangedBounds.Count,changedGeometry=sdf.GeometryChangedBounds.Count};
        Json(directory,"lightoff-schedule-"+logical.ToString("D4")+".json",snapshot);
        if(logical>119&&(regionSources.Count!=0||snapshot.domains.globalGeometry!=0))throw new Exception("Unexpected geometry/surface/source-region event after119");
    }
    static void Save(string directory,Receipt receipt,byte[] data)
    {
        string key=receipt.logicalFrame.ToString("D4")+"-"+receipt.stage;
        if(!completed.Add(key))throw new Exception("Duplicate light-off receipt "+key);
        receipt.bytes=data.Length;File.WriteAllBytes(Path.Combine(directory,"lightoff-"+key+".bin"),data);
        Json(directory,"lightoff-receipts.jsonl",receipt,true);
    }
    static void Buffer(CommandBuffer cmd,ComputeBuffer buffer,string stage,int logical,int giFrame,string directory,int active=-1,int offset=0,int size=-1,Action<byte[]> observe=null)
    {
        if(buffer==null)throw new Exception("Missing actual source "+stage);
        int bytes=size<0?buffer.count*buffer.stride:size;
        var receipt=new Receipt{logicalFrame=logical,engineFrame=Time.frameCount,giFrame=giFrame,stage=stage,stride=buffer.stride,count=bytes/buffer.stride,activeCount=active};
        pending++;cmd.RequestAsyncReadback(buffer,bytes,offset,request=>{try{
            if(request.hasError)throw new Exception("Light-off source readback failed: "+stage);var data=request.GetData<byte>().ToArray();Save(directory,receipt,data);
            if(data.Length!=bytes)throw new Exception("Light-off readback size mismatch");observe?.Invoke(data);
        }catch(Exception error){Failure(error);}finally{pending--;}});
    }
    public static void Begin(CommandBuffer cmd,ComputeShader shader,int kernel,object state,int giFrame,int read,int lightCount,int areaCount,bool exact)
    {
        if(!Target((Camera)Field(state,"camera"),out int logical,out string directory))return;
        if(!exact)throw new Exception("Light-off actual backend is not exact software");
        var entries=selections[logical];var cache=(ComputeBuffer[])Field(state,"cache");
        if(ReferenceEquals(cache[read],cache[1-read]))throw new Exception("Product Jacobi buffers alias");
        Json(directory,"lightoff-bindings.jsonl",new Binding{logicalFrame=logical,engineFrame=Time.frameCount,giFrame=giFrame,cacheRead=read,cacheWrite=1-read,gatherRead=1-read,
            lightCount=lightCount,areaCount=areaCount,exact=exact,distinct=true},true);
        if(!observationReserved.Add(logical))throw new Exception("Duplicate private observation admission");
        pending++; // Own completion before the first recorded use, including a later recording exception.
        var addresses=new[]{-1,-1,-1,-1};for(int i=0;i<entries.Length;i++)addresses[i]=entries[i].entry;
        cmd.SetBufferData(Records,new Seed[4]);cmd.SetComputeIntParams(shader,"_LO_Entries",addresses);
        cmd.SetComputeIntParam(shader,"_LO_Logical",logical);cmd.SetComputeIntParam(shader,"_LO_GiFrame",giFrame);cmd.SetComputeBufferParam(shader,kernel,"_LO_Records",Records);
        var scheduler=(HybridLumenGICacheScheduler)Field(state,"scheduler");var changes=Field(state,"changes");
        Buffer(cmd,scheduler.UpdateMask,"gpu-mask",logical,giFrame,directory);
        Buffer(cmd,(ComputeBuffer)Field(state,"lights"),"gpu-lights",logical,giFrame,directory,lightCount);
        Buffer(cmd,(ComputeBuffer)Field(changes,"buffer"),"gpu-changes",logical,giFrame,directory,(int)Field(changes,"count"));
        Buffer(cmd,((HybridLumenGIEmissiveSampling)Field(state,"emissiveSampling")).Buffer,"gpu-proposals",logical,giFrame,directory);
    }
    public static void AfterCache(CommandBuffer cmd,object state,int giFrame,int written)
    {
        if(!Target((Camera)Field(state,"camera"),out int logical,out string directory))return;
        var receipt=new Receipt{logicalFrame=logical,engineFrame=Time.frameCount,giFrame=giFrame,stage="cache-observed",stride=320,count=4,activeCount=selections[logical].Length};
        if(!observationReserved.Contains(logical))throw new Exception("Missing private observation reservation");
        cmd.RequestAsyncReadback(Records,request=>{try{
            if(request.hasError)throw new Exception("Light-off cache observation readback failed");var bytes=request.GetData<byte>().ToArray();Save(directory,receipt,bytes);
            if(bytes.Length!=1280)throw new Exception("Light-off cache observation layout mismatch");observedCache.Add(logical,bytes);
            foreach(var p in selections[logical])if(p.entry>=0)Validate(logical,p.lane);
        }catch(Exception error){Failure(error);}finally{pending--;}});
        var cache=((ComputeBuffer[])Field(state,"cache"))[written];
        foreach(var selection in selections[logical])if(selection.entry>=0){int lane=selection.lane;
            Buffer(cmd,cache,"cache-actual-"+lane,logical,giFrame,directory,1,selection.entry*80,80,data=>{actualCache.Add(logical+"/"+lane,data);Validate(logical,lane);});}
    }
    public static void Texture(CommandBuffer cmd,RenderTexture texture,Camera camera,int giFrame,string stage)
    {
        if(!Target(camera,out int logical,out string directory)||!Wants(logical))return;
        if(texture.width!=320||texture.height!=180)throw new Exception("Fixed GI stage dimensions changed");
        var receipt=new Receipt{logicalFrame=logical,engineFrame=Time.frameCount,giFrame=giFrame,stage=stage,stride=16,count=4,activeCount=4};
        pending++;cmd.RequestAsyncReadback(texture,0,TextureFormat.RGBAFloat,request=>{try{
            if(request.hasError)throw new Exception("Light-off stage readback failed: "+stage);var data=request.GetData<byte>();var selected=new byte[64];
            if(data.Length!=320*180*16)throw new Exception("Light-off stage size mismatch");
            for(int lane=0;lane<4;lane++)for(int b=0;b<16;b++)selected[lane*16+b]=data[(Y[lane]*320+X[lane])*16+b];Save(directory,receipt,selected);
        }catch(Exception error){Failure(error);}finally{pending--;}});
    }
    static float F(byte[] bytes,int offset)=>BitConverter.ToSingle(bytes,offset);
    static void Validate(int logical,int lane)
    {
        if(!observedCache.TryGetValue(logical,out var bytes))return;
        var p=selections[logical][lane];int start=lane*320;
        if(BitConverter.ToUInt32(bytes,start+288)!=(uint)p.entry||BitConverter.ToUInt32(bytes,start+292)!=(uint)logical||
            BitConverter.ToUInt32(bytes,start+296)!=(uint)workFrames[logical]||BitConverter.ToUInt32(bytes,start+300)!=0x4C4F3031u||
            BitConverter.ToUInt32(bytes,start+316)!=(uint)workFrames[logical]||F(bytes,start+276)!=epochs[logical])
            throw new Exception("Actual cache observer entry/frame/epoch mismatch");
        if(F(bytes,start+256)!=0&&(BitConverter.ToUInt32(bytes,start+304)!=(uint)p.card||BitConverter.ToUInt32(bytes,start+308)!=p.generation||
            BitConverter.ToUInt32(bytes,start+312)!=(uint)p.slot||F(bytes,start+104)!=epochs[logical]))throw new Exception("Covered cache identity/epoch mismatch");
        if(F(bytes,start+264)!=0)for(int f=0;f<20;f++){
            float value=F(bytes,start+80+f*4);if(float.IsNaN(value)||float.IsInfinity(value))throw new Exception("Valid cache is nonfinite");
        }
        if(actualCache.TryGetValue(logical+"/"+lane,out var actual))for(int b=0;b<80;b++)
            if(bytes[start+80+b]!=actual[b])throw new Exception("Observer differs from actual cache write");
    }
    public static void Gate119()
    {
        AsyncGPUReadback.WaitAllRequests();
        if(pending!=0||errors!=0||!selections.TryGetValue(119,out var selected)||!observedCache.TryGetValue(119,out var bytes))throw new Exception("119 readiness is unproven; stop before disabling light");
        if(pointAliases[119].Any(alias=>alias<0)||selected.Length!=2||selected.Select(p=>p.entry).Distinct().Count()!=2)
            throw new Exception("All four fixed rules must map to the two frozen unique patches");
        for(int lane=0;lane<selected.Length;lane++)
        {
            var p=selected[lane];int start=lane*320;
            if(p.entry<0||!p.ready||!p.published||p.generation==0||!actualCache.TryGetValue("119/"+lane,out var value))throw new Exception("119 owner/card/write coverage missing");
            if(BitConverter.ToUInt32(bytes,start+288)!=(uint)p.entry||BitConverter.ToUInt32(bytes,start+292)!=119||BitConverter.ToUInt32(bytes,start+300)!=0x4C4F3031u||
                F(bytes,start+256)!=1||F(bytes,start+264)!=1||F(bytes,start+92)<=0)throw new Exception("119 actual patch coverage/measurement missing");
            for(int b=0;b<80;b++)if(bytes[start+80+b]!=value[b])throw new Exception("119 observer differs from actual cache write");
            for(int f=0;f<20;f++){float v=F(value,f*4);if(float.IsNaN(v)||float.IsInfinity(v))throw new Exception("119 valid cache is nonfinite");}
            if(F(value,16)!=p.stableId||F(value,20)!=p.revision||F(value,28)!=p.generation)throw new Exception("119 cache identity mismatch");
        }
        warmupPassed=true;
        Json((string)Field(capture,"directory"),"lightoff-warmup119.json",new Summary{warmupPassed=true,passed=true,pending=pending,errors=errors,files=completed.Count});
    }
    public static void Finish(bool collected)
    {
        if(!requested||finished)return;finished=true;
        try{
            AsyncGPUReadback.WaitAllRequests();
            var missing=new List<string>();
            for(int frame=0;frame<360;frame++)foreach(string stage in new[]{"gpu-mask","gpu-lights","gpu-changes","gpu-proposals","cache-observed"})if(!completed.Contains(frame.ToString("D4")+"-"+stage))missing.Add(frame.ToString("D4")+"-"+stage);
            foreach(var pair in selections)foreach(var p in pair.Value)if(p.entry>=0&&!completed.Contains(pair.Key.ToString("D4")+"-cache-actual-"+p.lane))missing.Add(pair.Key.ToString("D4")+"-cache-actual-"+p.lane);
            foreach(int frame in Samples)foreach(string stage in new[]{"raw","history","filtered"})if(!completed.Contains(frame.ToString("D4")+"-"+stage))missing.Add(frame.ToString("D4")+"-"+stage);
            var result=new Summary{collected=collected,warmupPassed=warmupPassed,errors=errors,pending=pending,files=completed.Count,missing=missing.ToArray(),passed=collected&&warmupPassed&&errors==0&&pending==0&&missing.Count==0};
            if(capture)Json((string)Field(capture,"directory"),"lightoff-summary.json",result);
            if(collected&&!result.passed)throw new Exception("Light-off observation incomplete");
        }finally{if(pending==0){records?.Dispose();records=null;}}
    }
}
