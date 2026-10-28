// Finite read-only GPU receipts for the single MPB event. Never installed in product sources.
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using UnityEngine;
using UnityEngine.Rendering;

namespace HybridLumenGI
{
    public static partial class MaterialEventTap
    {
        static ComputeShader copy;
        static GraphicsBuffer trace,identityCopy,samples;
        static int width,height,grid,selectedCache=-1;
        static Vector4[] pixels=new Vector4[3];
        static Selection selection;
        static readonly Dictionary<string,byte[]> received=new Dictionary<string,byte[]>();
        [Serializable] sealed class Point { public string role;public int x,y,interiorCandidates;public uint keyLow,keyHigh,row,primitivePlusOne; }
        [Serializable] sealed class Selection
        {
            public int logical=158,cacheIndex,cell,grid;
            public int screenMask=MaterialEventSelection.ScreenMask,traceMask=MaterialEventSelection.TraceMask;
            public bool slot1ScreenHistoryCovered=false;
            public uint ownerSlot,ownerId,ownerRevision,layout,chartId,generation;
            public Point[] points;
            public string rule="3x3 identity interior, nearest projected mesh bounds center; raster tie-break; no radiance selection. Cache sorted by full identity and cell, valid prior measurement.";
        }
        [Serializable] sealed class EndReceipt
        {
            public bool collected,eventApplied,pendingComplete;
            public int completedFrames,lastLogical,payloads;
            public string failure,scope="Finite material propagation evidence; actual contribution coverage is evaluated from recorded winning paths, never inferred from color.";
        }
        static void ConfigureGpu()
        {
            copy=Resources.Load<ComputeShader>("MaterialEventReadback");
            if(!copy)throw new Exception("Material-event copy shader missing");
            trace=new GraphicsBuffer(GraphicsBuffer.Target.Structured,4*256,128);samples=new GraphicsBuffer(GraphicsBuffer.Target.Structured,3,272);
        }
        public static IEnumerable<GraphicsBuffer> OwnedBuffers
        {get{if(active){if(trace!=null)yield return trace;if(samples!=null)yield return samples;if(identityCopy!=null)yield return identityCopy;}}}
        static void EnsureDimensions(int w,int h)
        {
            if(width==0){width=w;height=h;identityCopy=new GraphicsBuffer(GraphicsBuffer.Target.Structured,w*h,16);}
            if(width!=w||height!=h)throw new Exception("Material-event dimensions changed");
        }
        static Receipt NewReceipt(string stage,int stride,int count)=>new Receipt{logical=logical,engine=engine,gi=current.gi,
            read=current.read,cacheRead=current.cacheRead,width=width,height=height,stage=stage,stride=stride,count=count};
        static void Completed(Receipt receipt,AsyncGPUReadbackRequest request)
        {
            try
            {
                if(request.hasError || !request.done)throw new Exception("Incomplete GPU payload "+receipt.stage);
                byte[] bytes=request.GetData<byte>().ToArray();
                if(bytes.Length!=receipt.stride*receipt.count)throw new Exception("GPU payload size mismatch "+receipt.stage);
                Save(receipt,bytes);received.Add(receipt.logical+"/"+receipt.stage,bytes);
            }
            catch(Exception ex){if(failure==null)failure=ex.ToString();}
            finally{pending--;}
        }
        static void Read(CommandBuffer cmd,ComputeBuffer buffer,string stage,int stride,int count)
        {
            var receipt=NewReceipt(stage,stride,count);pending++;
            try{cmd.RequestAsyncReadback(buffer,r=>Completed(receipt,r));}catch{pending--;throw;}
        }
        static void Read(CommandBuffer cmd,GraphicsBuffer buffer,string stage,int stride,int count)
        {
            var receipt=NewReceipt(stage,stride,count);pending++;
            try{cmd.RequestAsyncReadback(buffer,r=>Completed(receipt,r));}catch{pending--;throw;}
        }
        static void Read(CommandBuffer cmd,RTHandle texture,string stage)
        {
            var receipt=NewReceipt(stage,16,texture.rt.width*texture.rt.height);receipt.width=texture.rt.width;receipt.height=texture.rt.height;
            pending++;try{cmd.RequestAsyncReadback(texture.rt,0,TextureFormat.RGBAFloat,r=>Completed(receipt,r));}catch{pending--;throw;}
        }
        public static void BindTrace(Camera selected,CommandBuffer cmd,ComputeShader shader,int update,int gather,int w,int h,
            HybridLumenGICacheScheduler scheduler,int patchGrid)
        {
            if(selected!=camera)return;
            Observe(()=>
            {
                EnsureDimensions(w,h);
                grid=patchGrid;current.scheduledPatches=scheduler.SelectedCount;
                current.selectedCacheMask=selectedCache>=0?(int)scheduler.Mask[selectedCache]:-1;
                bool enabled=Detailed && selection!=null;
                cmd.SetComputeIntParam(shader,"_GC_Enabled",enabled?1:0);
                cmd.SetComputeIntParam(shader,"_GC_ActiveMask",MaterialEventSelection.TraceMask);
                cmd.SetComputeIntParam(shader,"_GC_Logical",logical);cmd.SetComputeIntParam(shader,"_GC_GiFrame",current.gi);
                cmd.SetComputeIntParam(shader,"_GC_CacheIndex",selectedCache);cmd.SetComputeVectorArrayParam(shader,"_GC_Pixels",pixels);
                cmd.SetComputeBufferParam(shader,update,"_GC_Records",trace);cmd.SetComputeBufferParam(shader,gather,"_GC_Records",trace);
            });
        }
        public static void Gpu(Camera selected,CommandBuffer cmd,RTHandle identityNow,RTHandle identityThen,RTHandle raw,
            RTHandle material,RTHandle geometry,RTHandle history,RTHandle moments,RTHandle previousHistory,RTHandle previousMoments,
            RTHandle receiverDiffuse,GraphicsBuffer candidates,GraphicsBuffer objects,int objectCount,ComputeBuffer oldCache,ComputeBuffer newCache)
        {
            if(selected!=camera || !Detailed)return;
            Observe(()=>
            {
                if(!current.hardware || !current.useIdentity || !current.identityRecorded)throw new Exception("Required GPU consumer unavailable");
                current.objectCount=objectCount;
                cmd.SetComputeIntParams(copy,"_Size",width,height);
                cmd.SetComputeIntParams(copy,"_FullSize",receiverDiffuse.rt.width,receiverDiffuse.rt.height);
                if(logical==158)
                {
                    int k=copy.FindKernel("CopyIdentity");cmd.SetComputeBufferParam(copy,k,"_IdentityCopy",identityCopy);
                    cmd.SetComputeTextureParam(copy,k,"_Identity",identityNow.nameID);cmd.DispatchCompute(copy,k,(width+7)/8,(height+7)/8,1);
                    Read(cmd,identityCopy,"identity-current",16,width*height);
                    cmd.SetComputeTextureParam(copy,k,"_Identity",identityThen.nameID);cmd.DispatchCompute(copy,k,(width+7)/8,(height+7)/8,1);
                    Read(cmd,identityCopy,"identity-previous",16,width*height);
                    Read(cmd,geometry,"geometry");Read(cmd,material,"material");Read(cmd,raw,"raw");
                    Read(cmd,history,"history");Read(cmd,moments,"moments");
                    Read(cmd,previousHistory,"previous-history");Read(cmd,previousMoments,"previous-moments");
                    Read(cmd,receiverDiffuse,"receiver-diffuse");
                }
                else
                {
                    if(selection==null)throw new Exception("Selection was not frozen before event");
                    int k=copy.FindKernel("CopySamples");
                    cmd.SetComputeIntParam(copy,"_ObjectCount",objectCount);cmd.SetComputeIntParam(copy,"_Logical",logical);cmd.SetComputeIntParam(copy,"_GiFrame",current.gi);
                    cmd.SetComputeIntParam(copy,"_ActiveScreenMask",MaterialEventSelection.ScreenMask);
                    cmd.SetComputeVectorArrayParam(copy,"_Pixels",pixels);
                    cmd.SetComputeBufferParam(copy,k,"_Candidates",candidates);cmd.SetComputeBufferParam(copy,k,"_Objects",objects);
                    cmd.SetComputeBufferParam(copy,k,"_Samples",samples);
                    string[] names={"_IdentityNow","_IdentityThen","_Raw","_Material","_Geometry","_History","_Moments","_PreviousHistory","_PreviousMoments","_ReceiverDiffuse"};
                    RTHandle[] textures={identityNow,identityThen,raw,material,geometry,history,moments,previousHistory,previousMoments,receiverDiffuse};
                    for(int i=0;i<names.Length;i++)cmd.SetComputeTextureParam(copy,k,names[i],textures[i].nameID);
                    cmd.DispatchCompute(copy,k,1,1,1);Read(cmd,samples,"samples",272,3);Read(cmd,trace,"actual-paths",128,4*256);
                }
                Read(cmd,oldCache,"cache-previous",80,oldCache.count);Read(cmd,newCache,"cache-current",80,newCache.count);
            });
        }
        static uint U(byte[] b,int offset)=>BitConverter.ToUInt32(b,offset);
        static float F(byte[] b,int offset)=>BitConverter.ToSingle(b,offset);
        static bool Finite(float v)=>!float.IsNaN(v)&&!float.IsInfinity(v);
        static bool SameIdentity(byte[] b,int offset,Source s)=>MaterialEventSelection.MatchesSource(b,offset,s.keyLow,s.keyHigh);
        static void Select()
        {
            byte[] ids=received["158/identity-current"],geometry=received["158/geometry"],cache=received["158/cache-current"];
            var points=new List<Point>();
            foreach(string role in MaterialEventSelection.ScreenRoles)
            {
                var source=current.sources.Single(s=>s.role==role);
                int best=MaterialEventSelection.FindInterior(ids,geometry,width,height,source.keyLow,source.keyHigh,
                    source.projectedCenter.x,source.projectedCenter.y,out int candidates);
                if(best<0)throw new Exception("UNCOVERED: no stable geometric interior for "+role);
                points.Add(new Point{role=role,x=best%width,y=best/width,keyLow=source.keyLow,keyHigh=source.keyHigh,row=(uint)source.row+1,
                    primitivePlusOne=U(ids,best*16+8),interiorCandidates=candidates});
            }
            Card chosen=null;int cell=-1;
            foreach(var card in current.cardsAfter.Where(c=>c.submesh==0&&c.ready!=0&&!c.dirty).OrderBy(c=>c.ownerId).ThenBy(c=>c.ownerRevision).ThenBy(c=>c.layout).ThenBy(c=>c.chartId))
            {
                for(int j=0;j<grid*grid;j++)
                {
                    int index=card.index*grid*grid+j,p=index*80;
                    if(p+80>cache.Length)throw new Exception("Cache ABI bounds");
                    if(F(cache,p+12)<=0||!Finite(F(cache,p+12))||F(cache,p+16)!=card.ownerId||F(cache,p+20)!=card.ownerRevision||
                        F(cache,p+24)!=current.epoch||F(cache,p+28)!=card.generation)continue;
                    chosen=card;selectedCache=index;cell=j;break;
                }
                if(chosen!=null)break;
            }
            if(chosen==null)throw new Exception("UNCOVERED: target slot0 lacks a valid cache measurement at selection");
            selection=new Selection{points=points.ToArray(),cacheIndex=selectedCache,cell=cell,grid=grid,ownerSlot=chosen.ownerSlot,
                ownerId=chosen.ownerId,ownerRevision=chosen.ownerRevision,layout=chosen.layout,chartId=chosen.chartId,generation=chosen.generation};
            for(int i=0;i<points.Count;i++)pixels[i]=new Vector4(points[i].x,points[i].y,0,0);
            SaveJson("selection.json",selection);
        }
        static string StableSource(Source s)=>s.role+"/"+s.submesh+"/"+s.mesh+"/"+s.token+"/"+s.geometryGeneration+"/"+s.materialGeneration+"/"+s.origin+"/"+JsonUtility.ToJson(s.baseColor)+"/"+JsonUtility.ToJson(s.matrix);
        static string StableCards(Frame f)=>string.Join(";",f.cardsAfter.OrderBy(c=>c.index).Select(c=>c.index+"/"+c.ownerSlot+"/"+c.ownerId+"/"+c.ownerRevision+"/"+c.layout+"/"+c.chartId+"/"+c.submesh+"/"+c.generation+"/"+c.ready+"/"+c.dirty+"/"+c.origin+"/"+JsonUtility.ToJson(c.baseColor)));
        public static void FrameEnded(int frame,int engineFrame)
        {
            if(!active||current==null||frame!=logical||engineFrame!=engine)throw new Exception("Frame end identity mismatch");
            if(pending>0)AsyncGPUReadback.WaitAllRequests();
            if(pending!=0 && failure==null)failure="Readback outstanding after bounded frame drain";
            if(current.sourceCalls!=1||current.transportCalls!=1)failure=failure??"Missing actual source/transport receipt";
            File.AppendAllText(Path.Combine(directory,"material-frames.jsonl"),JsonUtility.ToJson(current)+"\n");frames.Add(current);
            if(failure!=null)throw new Exception(failure);
            if(logical>=144 && (!current.hardware||!current.hitBound||!current.receiverRecorded||!current.identityRecorded||current.sources.Count!=3||current.uploads.Count!=3))
                throw new Exception("Required source/capture/DXR consumer readiness unavailable");
            if(logical==158)Select();
            if(Detailed&&logical!=158)
            {
                byte[] data=received[logical+"/samples"],path=received[logical+"/actual-paths"];
                for(int i=0;i<3;i++)
                {
                    if((MaterialEventSelection.ScreenMask&(1<<i))==0)
                    {if(U(data,i*272+60)!=0)throw new Exception("Inactive sample lane was populated");continue;}
                    int p=i*272;if(U(data,p+8)!=logical||U(data,p+12)!=current.gi)throw new Exception("Sample receipt label mismatch");
                    for(int n=64;n<192;n+=4)if(!Finite(F(data,p+n)))throw new Exception("Nonfinite selected transport data");
                }
                for(int lane=0;lane<4;lane++)
                {
                    if((MaterialEventSelection.TraceMask&(1<<lane))==0)continue;
                    int p=lane*256*128;uint count=U(path,p+4);
                    if(U(path,p+8)!=1||U(path,p+12)!=0||U(path,p+16)!=logical||U(path,p+20)!=current.gi||U(path,p+24)!=lane||count<2||count>256||U(path,p+(int)(count-1)*128)!=1)
                        throw new Exception("Actual path stream missing, stale, overflowed or unterminated");
                }
            }
            // The only retained payloads needed by the pre-event gate are the immediately preceding frame.
            foreach(string key in received.Keys.Where(k=>!k.StartsWith(logical+"/")).ToArray())received.Remove(key);
        }
        public static void RequireEventCoverage()
        {
            if(logical!=160||frames.Count!=160||selection==null)throw new Exception("Pre-event receipt missing");
            var baseline=frames[144];string[] sources=baseline.sources.OrderBy(s=>s.role).Select(StableSource).ToArray();string cards=StableCards(baseline);
            foreach(var f in frames.Skip(144))
            {
                if(!sources.SequenceEqual(f.sources.OrderBy(s=>s.role).Select(StableSource))||cards!=StableCards(f)||!f.historyAllowed||
                    f.sources.Any(s=>(s.reusable&1)==0)||f.cardsAfter.Count==0||f.cardsAfter.Any(c=>c.ready==0||c.dirty))
                    throw new Exception("UNCOVERED: last sixteen frames lack stable source/material/necessary cache readiness");
                foreach(var upload in f.uploads)
                {
                    var source=f.sources.Single(s=>s.role==upload.role);
                    if(upload.record240.Length!=240||upload.binding32.Length!=32||U(upload.record240,0)!=upload.batchGeneration||
                        U(upload.binding32,0)!=upload.index||U(upload.binding32,4)!=upload.batchGeneration||U(upload.binding32,16)==0||
                        U(upload.binding32,28)!=upload.submesh||upload.frozenBaseColor!=source.baseColor||upload.origin!=source.origin)
                        throw new Exception("UNCOVERED: selected actual upload is missing, unknown or does not match frozen source");
                }
            }
            byte[] sample=received["159/samples"],cache=received["159/cache-current"];
            for(int i=0;i<selection.points.Length;i++)
            {
                Source source=frames[159].sources.Single(s=>s.role==selection.points[i].role);int p=i*272;
                if(!SameIdentity(sample,p+16,source)||!SameIdentity(sample,p+32,source)||U(sample,p+24)!=U(sample,p+40)||
                    U(sample,p+48)!=source.row+1||U(sample,p+52)!=0||U(sample,p+56)!=U(sample,p+24)||U(sample,p+60)!=127||
                    U(sample,p+256)!=source.keyLow||U(sample,p+260)!=source.keyHigh||U(sample,p+264)!=source.reusable||
                    F(sample,p+64+12)<=0||F(sample,p+96+8)<1||F(sample,p+96+12)<=1e-6||F(sample,p+128+8)<=0)
                    throw new Exception("UNCOVERED: selected receiver identity/material/measurement is not ready at 159");
            }
            int c=selectedCache*80;
            if(F(cache,c+12)<=0||F(cache,c+16)!=selection.ownerId||F(cache,c+20)!=selection.ownerRevision||F(cache,c+28)!=selection.generation)
                throw new Exception("UNCOVERED: selected cache is not ready at 159");
            SaveJson("event-admission.json",new EndReceipt{collected=true,pendingComplete=pending==0,completedFrames=frames.Count,lastLogical=159,payloads=saved.Count});
        }
        public static void Finish(bool collected)
        {
            if(finished)return;finished=true;active=false; // caller has disabled camera before releasing observer-owned buffers
            try
            {
                AsyncGPUReadback.WaitAllRequests();
                if(pending!=0)failure=failure??"Readbacks incomplete at close";
                if(directory!=null)SaveJson("material-event-result.json",new EndReceipt{collected=collected&&failure==null,eventApplied=eventRecorded,
                    pendingComplete=pending==0,completedFrames=frames.Count,lastLogical=logical,payloads=saved.Count,failure=failure});
            }
            finally
            {
                // Drain requests is not an all-context submission certificate. Reuse the product's
                // existing retirement owner for final-queue completion, including early failures.
                var a=trace;var b=identityCopy;var c=samples;trace=null;identityCopy=null;samples=null;
                if(a!=null||b!=null||c!=null)HybridLumenGIResourceRetirement.Retire(()=>{a?.Release();b?.Release();c?.Release();});
            }
            if(failure!=null)throw new Exception(failure);
        }
    }
}
