// Finite material-event receipts beside existing consumers. Installed only for the test build.
using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Text;
using UnityEngine;
using UnityEngine.Rendering;

namespace HybridLumenGI
{
    public static partial class MaterialEventTap
    {
        const BindingFlags Fields=BindingFlags.Instance|BindingFlags.Public|BindingFlags.NonPublic;
        static Camera camera;static Renderer target,control;
        static bool active,finished,eventRecorded;
        static int logical=-1,engine=-1,pending;
        static string directory,failure;
        static Frame current;
        static readonly List<Frame> frames=new List<Frame>(256);
        static readonly HashSet<string> saved=new HashSet<string>();
        static readonly int[] DetailedFrames=Enumerable.Range(158,18).Concat(new[]{191,223,255}).ToArray();
        static object Field(object o,string n)=>o?.GetType().GetField(n,Fields)?.GetValue(o);
        static bool Detailed=>Array.IndexOf(DetailedFrames,logical)>=0;
        static void Observe(Action action)
        {
            if(!active)return;
            try{action();}catch(Exception ex){if(failure==null)failure=ex.ToString();}
            // Never throw into product fallback/quarantine/finally paths.
        }
        public static void Abort(Exception error){if(failure==null)failure=error.ToString();}
        [Serializable] sealed class Source
        {
            public string role;
            public int submesh,row,mesh;
            public ulong token,geometryGeneration,materialGeneration;
            public Vector4 baseColor;
            public int origin;
            public Matrix4x4 matrix;
            public uint keyLow,keyHigh,reusable,rendererGroup;
            public Vector2 projectedCenter;
        }
        [Serializable] sealed class Card
        {
            public int index,chartIndex,submesh,age;
            public uint ownerSlot,ownerId,ownerRevision,layout,chartId,generation,ready;
            public bool dirty,scheduled;
            public Vector4 baseColor;
            public int origin;
        }
        [Serializable] sealed class Upload
        {
            public string role;public int index,submesh;
            public uint batchGeneration;
            public byte[] record240,binding32;
            public Vector4 frozenBaseColor;
            public int origin;
        }
        [Serializable] sealed class Frame
        {
            public int logical,engine,gi,sourceCalls,transportCalls,read,cacheRead,epoch;
            public uint expectedMaterialBatch;
            public ulong historySequence;
            public int historyEngineFrame;
            public bool historyTokenReusable;
            public Matrix4x4 viewProjection;
            public int unknownRects,capturedCards,scheduledPatches,selectedCacheMask;
            public bool hardware,useIdentity,historyAllowed,receiverRecorded,identityRecorded,hitBound;
            public List<Source> sources=new List<Source>(3);
            public List<Card> cardsBefore=new List<Card>(),cardsAfter=new List<Card>();
            public List<Upload> uploads=new List<Upload>(3);
            public string materialStatus;
        }
        [Serializable] sealed class Event { public int logical,engine;public Vector4 baseColor;public string api="Renderer.SetPropertyBlock(slot0), without manual invalidation"; }
        [Serializable] sealed class Receipt
        {
            public int logical,engine,gi,read,cacheRead,width,height,stride,count,bytes;
            public string stage,file,sha256;
        }
        static string Role(Renderer renderer,int submesh)
        {
            if(ReferenceEquals(renderer,target) && submesh<2)return "target-slot"+submesh;
            if(ReferenceEquals(renderer,control) && submesh==0)return "control";
            return null;
        }
        public static void Configure(Camera selected,Renderer selectedTarget,Renderer selectedControl)
        {
            if(active || camera!=null)throw new Exception("Duplicate material-event tap");
            camera=selected;target=selectedTarget;control=selectedControl;active=true;
            ConfigureGpu();
        }
        public static void BeginLogicalFrame(int frame,int engineFrame,string output)
        {
            if(!active || frame!=logical+1 || pending!=0)throw new Exception("Material-event pending/sequence violation");
            if(failure!=null)throw new Exception(failure);
            logical=frame;engine=engineFrame;directory=output;current=new Frame{logical=logical,engine=engine};
        }
        public static void Sources(Camera selected,int gi,object state,HybridLumenGIReceiverRegistry.Snapshot snapshot,
            HybridLumenGIReceiverIdentityFrame identity,Matrix4x4 vp)
        {
            if(selected!=camera)return;
            Observe(()=>
            {
                if(logical==0 && current.sourceCalls==0){engine=Time.frameCount;current.engine=engine;}
                if(engine!=Time.frameCount || ++current.sourceCalls!=1)throw new Exception("Source frame mismatch");
                EnsureDimensions((int)Field(state,"width"),(int)Field(state,"height"));
                current.gi=gi;current.epoch=(int)Field(state,"epoch");current.unknownRects=identity?.UnknownRects.Count??-1;
                current.viewProjection=vp;
                if(snapshot==null || identity==null)return;
                for(int i=0;i<snapshot.Records.Count;i++)
                {
                    var r=snapshot.Records[i];string role=Role(r.Renderer,r.Submesh);if(role==null)continue;
                    var row=identity.Rows[i];var color=r.Material.HitMaterial.BaseColor;
                    Vector3 world=r.LocalToWorld.MultiplyPoint(r.Mesh.bounds.center);Vector4 clip=vp*new Vector4(world.x,world.y,world.z,1);
                    Vector2 uv=new Vector2(clip.x,clip.y)/clip.w*.5f+Vector2.one*.5f;
                    if(SystemInfo.graphicsUVStartsAtTop)uv.y=1-uv.y;
                    current.sources.Add(new Source{role=role,submesh=r.Submesh,row=i,mesh=r.Mesh.GetInstanceID(),token=r.Token,
                        geometryGeneration=r.GeometryGeneration,materialGeneration=r.MaterialGeneration,matrix=r.LocalToWorld,
                        baseColor=color.Value,origin=(int)color.Origin,keyLow=row.keyLow,keyHigh=row.keyHigh,reusable=row.flags,
                        rendererGroup=row.reserved,projectedCenter=uv});
                }
                CaptureCards((HybridLumenGISurfaceCache)Field(state,"surfaceCache"),current.cardsBefore);
            });
        }
        static void CaptureCards(HybridLumenGISurfaceCache surface,List<Card> output)
        {
            var owners=(Array)Field(surface,"owners");var metadata=(Array)Field(surface,"metadata");var cards=(Array)Field(surface,"cards");
            var scheduled=(IList)Field(surface,"scheduled");
            foreach(var owner in owners)
            {
                if(owner==null || !ReferenceEquals(Field(owner,"renderer"),target))continue;
                var charts=(HybridLumenGISurfaceCharts)Field(owner,"charts");
                var snapshots=(HybridLumenGIMaterialSource.Snapshot[])Field(owner,"materialSources");
                foreach(int index in (int[])Field(owner,"cardIndices"))
                {
                    object c=cards.GetValue(index),m=metadata.GetValue(index);int chartIndex=(int)Field(c,"chartIndex");
                    int submesh=charts!=null?charts.Charts[chartIndex].sourceSubmesh:-1;
                    var color=submesh>=0?snapshots[submesh].HitMaterial.BaseColor:default;
                    output.Add(new Card{index=index,chartIndex=chartIndex,submesh=submesh,age=(int)Field(c,"age"),dirty=(bool)Field(c,"dirty"),
                        scheduled=scheduled.Contains(index),ownerSlot=(uint)Field(m,"ownerSlot"),ownerId=(uint)Field(m,"stableId"),
                        ownerRevision=(uint)Field(m,"revision"),layout=(uint)Field(m,"layoutGeneration"),chartId=(uint)Field(m,"chartId"),
                        generation=(uint)Field(m,"generation"),ready=(uint)Field(m,"ready"),baseColor=color.Value,origin=(int)color.Origin});
                }
            }
        }
        public static void BeginTransport(Camera selected,int gi,int read,int cacheRead,bool hardware,bool identity,bool valid,
            bool receiverRecorded,bool identityRecorded,uint materialBatch,HybridLumenGIHistoryLifecycle.FrameToken historyToken)
        {
            if(selected!=camera)return;
            Observe(()=>
            {
                if(engine!=Time.frameCount || gi!=current.gi || ++current.transportCalls!=1)throw new Exception("Transport receipt mismatch");
                current.read=read;current.cacheRead=cacheRead;current.hardware=hardware;current.useIdentity=identity;current.historyAllowed=valid;
                current.receiverRecorded=receiverRecorded;current.identityRecorded=identityRecorded;
                current.expectedMaterialBatch=materialBatch;
                current.historySequence=historyToken.Sequence;current.historyEngineFrame=historyToken.EngineFrame;current.historyTokenReusable=historyToken.Reusable;
            });
        }
        public static void CaptureRecorded(Camera selected,HybridLumenGISurfaceCache surface)
        {
            if(selected!=camera)return;
            Observe(()=>{current.capturedCards=surface.CapturedCards;CaptureCards(surface,current.cardsAfter);});
        }
        public static void MaterialUpload(uint generation,HybridLumenGIHitMaterialBatch.Source[] sources,
            HybridLumenGIHitMaterialRecord[] records,HybridLumenGIHitMaterialBinding[] bindings)
        {
            Observe(()=>
            {
                if(current==null || generation!=current.expectedMaterialBatch)return;
                if(current.transportCalls!=1)throw new Exception("Material upload outside target transport");
                for(int i=0;i<sources.Length;i++)
                {
                    var s=sources[i];string role=Role(s.Snapshot.SourceRenderer,(int)s.Submesh);if(role==null)continue;
                    var color=s.Snapshot.HitMaterial.BaseColor;
                    current.uploads.Add(new Upload{role=role,index=i,submesh=(int)s.Submesh,batchGeneration=generation,record240=Bytes(records[i],240),binding32=Bytes(bindings[i],32),
                        frozenBaseColor=color.Value,origin=(int)color.Origin});
                }
            });
        }
        public static void MaterialBound(Camera selected,bool bound,string status)
        {if(selected==camera)Observe(()=>{current.hitBound=bound;current.hardware=bound;current.materialStatus=status;});}
        static byte[] Bytes<T>(T value,int expected) where T:struct
        {
            if(Marshal.SizeOf<T>()!=expected)throw new Exception("Actual upload ABI mismatch");
            byte[] bytes=new byte[expected];IntPtr memory=Marshal.AllocHGlobal(expected);
            try{Marshal.StructureToPtr(value,memory,false);Marshal.Copy(memory,bytes,0,expected);return bytes;}
            finally{Marshal.FreeHGlobal(memory);}
        }
        public static void RecordEvent(Vector4 color)
        {
            if(logical!=160 || eventRecorded)throw new Exception("Material event identity mismatch");eventRecorded=true;
            SaveJson("event.json",new Event{logical=logical,engine=engine,baseColor=color});
        }
        static void SaveJson(string name,object value)=>WriteNew(Path.Combine(directory,name),Encoding.UTF8.GetBytes(JsonUtility.ToJson(value,true)));
        static void WriteNew(string path,byte[] bytes)
        {using(var stream=new FileStream(path,FileMode.CreateNew,FileAccess.Write,FileShare.Read))stream.Write(bytes,0,bytes.Length);}
        static string Hash(byte[] bytes)
        {using(var hash=SHA256.Create())return BitConverter.ToString(hash.ComputeHash(bytes)).Replace("-","").ToLowerInvariant();}
        static void Save(Receipt receipt,byte[] bytes)
        {
            string key=receipt.logical.ToString("D4")+"-"+receipt.stage;
            if(!saved.Add(key))throw new Exception("Duplicate material-event payload "+key);
            receipt.bytes=bytes.Length;receipt.file="material-"+key+".bin";receipt.sha256=Hash(bytes);
            WriteNew(Path.Combine(directory,receipt.file),bytes);
            File.AppendAllText(Path.Combine(directory,"payloads.jsonl"),JsonUtility.ToJson(receipt)+"\n");
        }
    }
}
