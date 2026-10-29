// Temporary diagnostic buffer ownership. Never changes product acceptance.
using System;
using System.Collections.Generic;
using System.IO;
using System.Runtime.InteropServices;
using HybridLumenGI;
using UnityEngine;
using UnityEngine.Rendering;

public static class CameraIdentityDepthDiagnosticTap
{
    public const int Width=640,Height=360,PointCount=264,OwnerCount=3,RowVectors=2433;
    const string Enabled="_HLGI_IdentityProbeEnabled",Map="_HLGI_IdentityProbeMap";
    static Camera targetCamera;static string directory;
    static GraphicsBuffer disabledMap,disabledRows;
    static readonly List<Probe> probes=new List<Probe>();
    static int pending,completed;
    public static string Failure;
    [StructLayout(LayoutKind.Sequential)]struct UInt4{public uint x,y,z,w;}
    [Serializable]public sealed class Selection
    {public int index,canonicalIndex,x,y;public bool projected;public string cohort;public Vector3 worldTarget;}
    [Serializable]public sealed class Owner
    {
        public int owner,rowIndex,submesh,drawIndex;public string renderer,mesh;
        public ulong token,geometryGeneration,materialGeneration;
        public uint keyLow,keyHigh,flags,group;public float[] localToWorld,currentToPrevious;
    }
    [Serializable]public sealed class Receipt
    {
        public int logicalFrame,engineFrame,width=Width,height=Height,points=PointCount,owners=OwnerCount,rowVectors=RowVectors,canonicalPixels;
        public bool captureRecorded,complete;public string error;
        public float[] customVP;public Selection[] selection;public Owner[] sourceRows;
    }
    [Serializable]sealed class PeerReceipt
    {public int logicalFrame,workFrame,engineFrame;public bool complete;public float[] vp;public Selection[] selection;}
    [Serializable]sealed class Link
    {public int logicalFrame,engineFrame,workFrame,bytes;}
    [Serializable]sealed class Result
    {public bool complete;public int framesExpected=8,framesCreated,framesCompleted,pendingReadbacks;public string failure;public Link[] frameLinks;}
    public sealed class Probe
    {
        internal GraphicsBuffer map,rows;internal uint[] mapData;internal Receipt receipt;
        internal bool initialized,requested;
    }
    static void Require(bool value,string message){if(!value)throw new InvalidOperationException(message);}
    static void Failed(Exception error){Failure=Failure??error.ToString();}
    static float[] Matrix(Matrix4x4 value){var data=new float[16];for(int i=0;i<16;i++)data[i]=value[i];return data;}
    static void Write(string name,byte[] data)
    {using(var file=new FileStream(Path.Combine(directory,name),FileMode.CreateNew,FileAccess.Write,FileShare.Read))file.Write(data,0,data.Length);}
    public static void Reset(Camera camera,string output)
    {
        Require(disabledMap==null&&disabledRows==null&&pending==0&&probes.Count==0,"Previous identity diagnostic not disposed");
        Require(SystemInfo.supportedRandomWriteTargetCount>=3,"Identity depth diagnostic requires three pixel UAV/RT slots");
        targetCamera=camera;directory=output;Failure=null;completed=0;
        disabledMap=new GraphicsBuffer(GraphicsBuffer.Target.Structured,1,4);disabledMap.SetData(new uint[1]);
        disabledRows=new GraphicsBuffer(GraphicsBuffer.Target.Structured,1,16);disabledRows.SetData(new UInt4[1]);
    }
    public static Probe Create(Camera camera,HybridLumenGIReceiverIdentityFrame frame,Matrix4x4 vp,int width,int height)
    {
        if(camera!=targetCamera)return null;
        int logical=CameraMotionTaaTap.RecordedFrames;
        if(logical<36||logical>43)return null;
        Probe probe=null;
        try
        {
            Require(width==Width&&height==Height&&frame.Rows.Count==OwnerCount&&frame.Draws.Count==OwnerCount,"Identity diagnostic ABI differs");
            Require(probes.Find(p=>p.receipt.logicalFrame==logical)==null,"Identity diagnostic frame recorded twice");
            var map=new uint[Width*Height];var selection=new Selection[PointCount];int index=0,unique=0;
            for(int group=0;group<2;group++)for(int j=0;j<11;j++)for(int i=0;i<(group==0?21:3);i++)
            {
                var target=new Vector3(group==0?.8f+.05f*i:2f+.2f*i,0,.5f+.1f*j);
                Vector4 clip=vp*new Vector4(target.x,target.y,target.z,1);
                bool valid=clip.w>0&&!float.IsNaN(clip.w)&&!float.IsInfinity(clip.w);
                Vector2 uv=valid?new Vector2(clip.x/clip.w*.5f+.5f,1-(clip.y/clip.w*.5f+.5f)):new Vector2(-1,-1);
                valid=valid&&uv.x>0&&uv.x<1&&uv.y>0&&uv.y<1;
                int x=valid?Mathf.FloorToInt(uv.x*Width):-1,y=valid?Mathf.FloorToInt(uv.y*Height):-1,canonical=-1;
                if(valid){int address=y*Width+x;if(map[address]==0){map[address]=(uint)index+1;unique++;}canonical=(int)map[address]-1;}
                selection[index]=new Selection{index=index,canonicalIndex=canonical,x=x,y=y,projected=valid,cohort=group==0?"event":"continued",worldTarget=target};index++;
            }
            Require(index==PointCount,"Identity diagnostic selection count differs");
            var owners=new Owner[OwnerCount];
            for(int i=0;i<frame.Draws.Count;i++)
            {
                var draw=frame.Draws[i];int rowIndex=draw.RowIndex;var record=draw.Record;var row=frame.Rows[rowIndex];
                Require(rowIndex>=0&&rowIndex<OwnerCount&&owners[rowIndex]==null,"Identity diagnostic row mapping ambiguous");
                owners[rowIndex]=new Owner{owner=rowIndex+1,rowIndex=rowIndex,drawIndex=i,renderer=record.Renderer.name,mesh=record.Mesh.name,submesh=record.Submesh,
                    token=record.Token,geometryGeneration=record.GeometryGeneration,materialGeneration=record.MaterialGeneration,
                    keyLow=row.keyLow,keyHigh=row.keyHigh,flags=row.flags,group=row.reserved,localToWorld=Matrix(record.LocalToWorld),currentToPrevious=Matrix(row.currentToPrevious)};
            }
            probe=new Probe{mapData=map,receipt=new Receipt{logicalFrame=logical,engineFrame=Time.frameCount,customVP=Matrix(vp),selection=selection,sourceRows=owners,canonicalPixels=unique}};
            probe.map=new GraphicsBuffer(GraphicsBuffer.Target.Structured,map.Length,4);
            probe.rows=new GraphicsBuffer(GraphicsBuffer.Target.Structured,RowVectors,16);
            probes.Add(probe);return probe;
        }
        catch(Exception error){probe?.map?.Dispose();probe?.rows?.Dispose();Failed(error);return null;}
    }
    public static void Configure(MaterialPropertyBlock block,Probe probe)
    {
        block.SetFloat(Enabled,probe!=null?1:0);block.SetBuffer(Map,probe!=null?probe.map:disabledMap);
    }
    public static GraphicsBuffer MapBuffer(Probe probe)=>probe!=null?probe.map:disabledMap;
    public static GraphicsBuffer RowsBuffer(Probe probe)=>probe!=null?probe.rows:disabledRows;
    public static void Initialize(CommandBuffer cmd,Probe probe)
    {
        if(probe==null)return;
        try{cmd.SetBufferData(probe.map,probe.mapData);cmd.SetBufferData(probe.rows,new UInt4[RowVectors]);probe.initialized=true;}
        catch(Exception error){Failed(error);}
    }
    public static void Bind(CommandBuffer cmd,Probe probe)
    {
        if(probe!=null&&!probe.initialized)Failed(new InvalidOperationException("Identity diagnostic was not initialized"));
        cmd.SetRandomWriteTarget(2,probe!=null?probe.rows:disabledRows);
    }
    public static void Readback(CommandBuffer cmd,Probe probe,bool captured)
    {
        if(probe==null||probe.requested)return;
        probe.requested=true;probe.receipt.captureRecorded=captured;pending++;
        try
        {
            cmd.RequestAsyncReadback(probe.rows,request=>
            {
                try
                {
                    Require(!request.hasError,"Identity depth diagnostic readback failed");byte[] data=request.GetData<byte>().ToArray();
                    Require(data.Length==RowVectors*16,"Identity diagnostic buffer size differs");
                    Write("probe-"+probe.receipt.logicalFrame.ToString("D3")+".bin",data);probe.receipt.complete=true;completed++;
                }
                catch(Exception error){probe.receipt.error=error.ToString();Failed(error);}
                finally{pending--;Write("probe-"+probe.receipt.logicalFrame.ToString("D3")+".json",System.Text.Encoding.UTF8.GetBytes(JsonUtility.ToJson(probe.receipt,true)));}
            });
        }
        catch(Exception error){pending--;probe.receipt.error=error.ToString();Failed(error);}
    }
    public static void Dispose()
    {
        var result=new Result{framesCreated=probes.Count,framesCompleted=completed,pendingReadbacks=pending};
        try
        {
            AsyncGPUReadback.WaitAllRequests();
            result.framesCompleted=completed;result.pendingReadbacks=pending;
            Require(pending==0&&completed==8&&probes.Count==8&&string.IsNullOrEmpty(Failure),Failure??"Eight fixed identity diagnostic readbacks were not completed");
            var links=new List<Link>();
            foreach(var probe in probes)
            {
                var r=probe.receipt;string stem="frame-"+r.logicalFrame.ToString("D3");
                var peer=JsonUtility.FromJson<PeerReceipt>(File.ReadAllText(Path.Combine(directory,stem+".json")));
                Require(r.complete&&r.captureRecorded&&peer.complete&&peer.logicalFrame==r.logicalFrame&&peer.engineFrame==r.engineFrame,"Identity diagnostic frame receipt differs");
                Require(peer.vp.Length==16&&peer.selection.Length==PointCount,"Identity diagnostic source receipt ABI differs");
                for(int j=0;j<16;j++)Require(peer.vp[j]==r.customVP[j],"Identity diagnostic VP differs from actual gather");
                for(int j=0;j<PointCount;j++)
                {
                    var a=r.selection[j];var b=peer.selection[j];
                    Require(a.index==b.index&&a.x==b.x&&a.y==b.y&&a.projected==b.projected&&a.cohort==b.cohort&&
                        a.worldTarget.x==b.worldTarget.x&&a.worldTarget.y==b.worldTarget.y&&a.worldTarget.z==b.worldTarget.z,"Identity diagnostic selection differs from original gather");
                }
                int bytes=checked((int)new FileInfo(Path.Combine(directory,"probe-"+r.logicalFrame.ToString("D3")+".bin")).Length);
                Require(bytes==RowVectors*16,"Identity diagnostic persisted buffer size differs");
                links.Add(new Link{logicalFrame=r.logicalFrame,engineFrame=r.engineFrame,workFrame=peer.workFrame,bytes=bytes});
            }
            links.Sort((a,b)=>a.logicalFrame.CompareTo(b.logicalFrame));
            for(int i=0;i<8;i++)Require(links[i].logicalFrame==36+i,"Identity diagnostic fixed window differs");
            result.frameLinks=links.ToArray();result.complete=true;
        }
        catch(Exception error){Failed(error);result.failure=Failure;throw;}
        finally
        {
            try{Write("probe-result.json",System.Text.Encoding.UTF8.GetBytes(JsonUtility.ToJson(result,true)));}
            finally
            {
                var retired=new List<GraphicsBuffer>();
                foreach(var probe in probes){if(probe.map!=null)retired.Add(probe.map);if(probe.rows!=null)retired.Add(probe.rows);probe.map=probe.rows=null;}
                probes.Clear();if(disabledMap!=null)retired.Add(disabledMap);if(disabledRows!=null)retired.Add(disabledRows);
                disabledMap=disabledRows=null;targetCamera=null;
                // An incomplete graph may have referenced a buffer without reaching its
                // readback. Use the product's detached-resource fence, never elapsed time.
                HybridLumenGIResourceRetirement.Retire(()=>{foreach(var buffer in retired)buffer.Dispose();});
            }
        }
    }
    public static void DisposeAfterMainTap()
    {
        Exception first=null;
        try{CameraMotionTaaTap.Dispose();}catch(Exception error){first=error;}
        try{Dispose();}catch(Exception error){first=first==null?error:new AggregateException("Camera and identity observers both failed cleanup",first,error);}
        if(first!=null)System.Runtime.ExceptionServices.ExceptionDispatchInfo.Capture(first).Throw();
    }
}
