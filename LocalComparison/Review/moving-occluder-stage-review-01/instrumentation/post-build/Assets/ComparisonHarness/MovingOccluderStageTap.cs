// Test-only stage copies. Reuses MaterialEventGpu's ordered uint copy/readback
// and DenoiseSceneTap's original raw capture; does not execute transport queries.
using System;
using System.IO;
using System.Reflection;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
namespace HybridLumenGI
{
    public static class MovingOccluderStageTap
    {
        static ComparisonCapture capture;
        static ComputeShader copy;
        static GraphicsBuffer identityCopy;
        static int width,height,pending,frames;
        static string failure;
        static readonly HashSet<string> saved=new HashSet<string>();
        static readonly BindingFlags fields=BindingFlags.Instance|BindingFlags.Public|BindingFlags.NonPublic;
        static object Field(object o,string n)=>o.GetType().GetField(n,fields).GetValue(o);
        static int Logical=>(int)Field(capture,"logicalFrame");
        static string DirectoryPath=>(string)Field(capture,"directory");
        static bool Window(int f)=>f>=176&&f<=196;
        public static IEnumerable<GraphicsBuffer> OwnedBuffers {get{if(identityCopy!=null)yield return identityCopy;}}
        [Serializable] public sealed class Source
        {
            public string name;public int renderer,submesh,mesh;public bool door;
            public ulong token,geometryGeneration,materialGeneration;
            public uint keyLow,keyHigh,flags;public Matrix4x4 localToWorld,currentToPrevious;
        }
        [Serializable] sealed class SourcesFrame {public int logical,engine,gi;public List<Source> sources=new List<Source>();}
        [Serializable] sealed class Frame
        {
            public int logical,engine,gi,read,width,height,fullWidth,fullHeight,objects;
            public bool hardware,identityRecorded,historyAllowed,hasMotion;
            public Matrix4x4 vp,invVP,previousVP,previousInvVP;public Vector2 jitterDelta;
        }
        [Serializable] sealed class Receipt
        {
            public int logical,engine,gi,read,width,height,bytes;public string stage,file,sha256,format;
        }
        [Serializable] sealed class Summary {public int completedFrames,payloads,pending;public string failure;public bool passed;}
        static void WriteNew(string path,byte[] bytes)
        {using(var stream=new FileStream(path,FileMode.CreateNew,FileAccess.Write,FileShare.Read))stream.Write(bytes,0,bytes.Length);}
        static void SaveJson(string file,object value)=>WriteNew(Path.Combine(DirectoryPath,file),System.Text.Encoding.UTF8.GetBytes(JsonUtility.ToJson(value,true)));
        public static void Sources(Camera camera,int gi,int w,int h,HybridLumenGIReceiverRegistry.Snapshot snapshot,HybridLumenGIReceiverIdentityFrame identity)
        {
            if(!capture)capture=UnityEngine.Object.FindFirstObjectByType<ComparisonCapture>();
            if(!capture||camera!=capture.camera||Logical<175||Logical>196)return;
            try
            {
                if(snapshot==null||identity==null||identity.Rows.Count!=snapshot.Records.Count)throw new Exception("Missing source mapping");
                if(identityCopy==null){width=w;height=h;identityCopy=new GraphicsBuffer(GraphicsBuffer.Target.Structured,w*h,16);copy=Resources.Load<ComputeShader>("MovingOccluderIdentityCopy");if(!copy)throw new Exception("Missing copy shader");}
                if(width!=w||height!=h)throw new Exception("Changed dimensions");
                var result=new SourcesFrame{logical=Logical,engine=Time.frameCount,gi=gi};
                for(int i=0;i<snapshot.Records.Count;i++)
                {
                    var r=snapshot.Records[i];var row=identity.Rows[i];
                    result.sources.Add(new Source{name=r.Renderer.name,renderer=r.Renderer.GetInstanceID(),submesh=r.Submesh,mesh=r.Mesh.GetInstanceID(),
                        door=r.Renderer.transform==capture.door,token=r.Token,geometryGeneration=r.GeometryGeneration,materialGeneration=r.MaterialGeneration,
                        keyLow=row.keyLow,keyHigh=row.keyHigh,flags=row.flags,localToWorld=r.LocalToWorld,currentToPrevious=row.currentToPrevious});
                }
                SaveJson("door-sources-"+Logical.ToString("D4")+".json",result);
            }catch(Exception e){failure=failure??e.ToString();}
        }
        static Receipt Make(Frame f,string stage,int w,int h,string format)=>new Receipt{logical=f.logical,engine=f.engine,gi=f.gi,read=f.read,width=w,height=h,stage=stage,format=format,file="door-"+f.logical.ToString("D4")+"-"+stage+".bin"};
        static void Done(Receipt r,string folder,AsyncGPUReadbackRequest request)
        {
            try
            {
                if(!request.done||request.hasError)throw new Exception("Readback failed "+r.stage);
                byte[] bytes=request.GetData<byte>().ToArray();if(bytes.Length!=r.bytes)throw new Exception("Payload size mismatch "+r.stage);
                if(!saved.Add(r.logical+"/"+r.stage))throw new Exception("Duplicate stage payload");
                WriteNew(Path.Combine(folder,r.file),bytes);
                using(var hash=System.Security.Cryptography.SHA256.Create())r.sha256=BitConverter.ToString(hash.ComputeHash(bytes)).Replace("-","").ToLowerInvariant();
                WriteNew(Path.Combine(folder,r.file+".json"),System.Text.Encoding.UTF8.GetBytes(JsonUtility.ToJson(r)));
            }catch(Exception e){failure=failure??e.ToString();}finally{pending--;}
        }
        static void Read(CommandBuffer cmd,Frame f,RTHandle texture,string stage)
        {
            var r=Make(f,stage,texture.rt.width,texture.rt.height,texture.rt.graphicsFormat.ToString());r.bytes=r.width*r.height*16;
            string folder=DirectoryPath;pending++;try{cmd.RequestAsyncReadback(texture.rt,0,TextureFormat.RGBAFloat,q=>Done(r,folder,q));}catch{pending--;throw;}
        }
        static void Read(CommandBuffer cmd,Frame f,GraphicsBuffer buffer,string stage)
        {
            var r=Make(f,stage,width,height,"Structured stride "+buffer.stride);r.bytes=buffer.count*buffer.stride;
            string folder=DirectoryPath;pending++;try{cmd.RequestAsyncReadback(buffer,q=>Done(r,folder,q));}catch{pending--;throw;}
        }
        public static void Record(CommandBuffer cmd,Camera camera,int gi,int read,bool hardware,bool identityRecorded,bool historyAllowed,bool hasMotion,
            Matrix4x4 vp,Matrix4x4 invVP,Matrix4x4 previousVP,Matrix4x4 previousInvVP,Vector2 jitterDelta,
            RTHandle now,RTHandle previous,RTHandle geometry,RTHandle material,RTHandle history,RTHandle moments,RTHandle filtered,RTHandle motion,
            GraphicsBuffer objects,int objectCount,int fullWidth,int fullHeight)
        {
            if(!capture||camera!=capture.camera||!Window(Logical))return;
            try
            {
                if(failure!=null)throw new Exception(failure);
                if(!hardware||!identityRecorded||identityCopy==null)throw new Exception("Required DXR/identity capture unavailable");
                var f=new Frame{logical=Logical,engine=Time.frameCount,gi=gi,read=read,width=width,height=height,fullWidth=fullWidth,fullHeight=fullHeight,
                    objects=objectCount,hardware=hardware,identityRecorded=identityRecorded,historyAllowed=historyAllowed,hasMotion=hasMotion,
                    vp=vp,invVP=invVP,previousVP=previousVP,previousInvVP=previousInvVP,jitterDelta=jitterDelta};
                SaveJson("door-frame-"+Logical.ToString("D4")+".json",f);frames++;
                int k=copy.FindKernel("CopyIdentity");cmd.SetComputeIntParams(copy,"_Size",width,height);cmd.SetComputeBufferParam(copy,k,"_IdentityCopy",identityCopy);
                cmd.SetComputeTextureParam(copy,k,"_Identity",now.nameID);cmd.DispatchCompute(copy,k,(width+7)/8,(height+7)/8,1);Read(cmd,f,identityCopy,"identity-current");
                cmd.SetComputeTextureParam(copy,k,"_Identity",previous.nameID);cmd.DispatchCompute(copy,k,(width+7)/8,(height+7)/8,1);Read(cmd,f,identityCopy,"identity-previous");
                Read(cmd,f,objects,"objects");Read(cmd,f,geometry,"geometry");Read(cmd,f,material,"material");Read(cmd,f,history,"history");Read(cmd,f,moments,"moments");Read(cmd,f,filtered,"filtered");
                if(hasMotion)Read(cmd,f,motion,"motion");
            }catch(Exception e){failure=failure??e.ToString();}
        }
        public static void Finish(bool collected)
        {
            AsyncGPUReadback.WaitAllRequests();
            var result=new Summary{completedFrames=frames,payloads=saved.Count,pending=pending,failure=failure,passed=frames==21&&pending==0&&failure==null};
            if(capture&&!string.IsNullOrEmpty(DirectoryPath))SaveJson("door-stage-result.json",result);
            if(pending==0){identityCopy?.Dispose();identityCopy=null;}
            if(collected&&!result.passed)throw new Exception("Incomplete door-stage evidence: "+failure);
        }
    }
}
