using System;
using System.Collections.Generic;
using System.IO;
using HybridLumenGI;
using UnityEngine;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Rendering;

// Temporary observer of existing identity/moments outputs. Existing integer-copy dispatch only; no source mutation,
// RGB oracle, GPU timing or CPU-row substitute for visible GPU identity.
public static class SkinMotionHistoryTap
{
    public static readonly int[] Samples={119,120,127,128,159,239};
    [Serializable] public sealed class SourceRow
    {
        public int rowIndex,submesh;
        public uint keyLow,keyHigh,flags,rendererGroup;
        public string geometryGeneration,materialGeneration;
    }
    [Serializable] public sealed class Receipt
    {
        public int logicalFrame,engineFrame,rendererId,meshId,width,height;
        public string rendererName,rendererType,identityFormat,momentsFormat,identityFile,momentsFile,error;
        public string binaryLayout="Native readback row order, no display flip; little-endian uint4 identity and float4 moments, 16 bytes per pixel. moments.z is history length; CPU rows/flags are not GPU identity evidence.";
        public bool sourceEnabled,sourceActive,sourceForceOff,deformationRunning,useIdentity,recorded,complete;
        public float bendDegrees;
        public SourceRow[] rows;
        public int validPixels,historyAboveOne,historyAboveTwo,nonfiniteMoments;
        public float minimumHistory,maximumHistory;
        public double meanHistory;
    }
    [Serializable] public sealed class Analysis
    {
        public string status="failed",error;
        public string scope="Six actual GPU identity/moments readbacks for one ordinary skin source and an explicit A/B setting. CPU rows/flags are source metadata only. Passing is bounded functional behavior, not motion-picture quality adoption, radiometric accuracy, pixel-perfect coverage, performance or cleanup acceptance.";
        public int pending,completedFrames;
        public bool motionEnabled,stableInitialAccumulation,stableKeys,motionRowsQualified,motionHistoryRejected,motionAccumulation,
            motionHistoryBounded,observedPoseChange,stoppedAccumulation,finalNonzeroPose;
        public Receipt[] frames;
    }
    sealed class Pending
    {
        public Receipt receipt;
        public uint[] identity;
        public float[] moments;
        public int callbacks;
    }
    static readonly List<Pending> frames=new List<Pending>();
    static ComputeShader identityCopyShader;
    static GraphicsBuffer identityCopy;
    static Camera target;
    static SkinnedMeshRenderer skin;
    static string directory;
    static int logical=-1,armedEngine=-1,pending;
    static float bend;
    static bool running,configured,motionEnabled;
    public static string Failure {get;private set;}
    public static int PendingCount=>pending;
    public static GraphicsBuffer CopyBufferFor(Camera camera)=>Selected(camera)?identityCopy:null;
    public static void Configure(string output,Camera camera,bool enableMotion)
    {
        if(configured)throw new InvalidOperationException("Tap already configured.");
        directory=output;target=camera;frames.Clear();Failure=null;pending=0;configured=true;motionEnabled=enableMotion;
        identityCopyShader=Resources.Load<ComputeShader>("MovingOccluderIdentityCopy");
        Require(identityCopyShader,"Missing existing integer readback copy shader.");
        Require(camera.targetTexture&&camera.targetTexture.width==640&&camera.targetTexture.height==360,"Fixed half-resolution copy target differs.");
        identityCopy=new GraphicsBuffer(GraphicsBuffer.Target.Structured,320*180,16);
    }
    public static void Arm(int frame,SkinnedMeshRenderer renderer,float degrees,bool moving)
    {logical=frame;armedEngine=Time.frameCount;skin=renderer;bend=degrees;running=moving;}
    public static void Disarm(){logical=-1;}
    static bool Selected(Camera camera)=>configured&&camera==target&&Array.IndexOf(Samples,logical)>=0;
    static void Require(bool condition,string reason){if(!condition)throw new InvalidOperationException(reason);}
    static void Fail(Exception e){if(Failure==null)Failure=e.ToString();}
    static Pending Find(int frame)=>frames.Find(p=>p.receipt.logicalFrame==frame);

    // Inject immediately after the real identityFrame is built.
    public static void Prepare(Camera camera,HybridLumenGIReceiverIdentityFrame frame)
    {
        if(!Selected(camera))return;
        try
        {
            Require(armedEngine==Time.frameCount&&skin&&frame!=null,"Missing current skin/frame at Prepare.");
            Require(Find(logical)==null,"Duplicate selected identity preparation.");
            var rows=new List<SourceRow>();
            foreach(var draw in frame.Draws)
            {
                if(!ReferenceEquals(draw.Record.Renderer,skin))continue;
                var row=frame.Rows[draw.RowIndex];
                rows.Add(new SourceRow{rowIndex=draw.RowIndex,submesh=draw.Record.Submesh,keyLow=row.keyLow,keyHigh=row.keyHigh,
                    flags=row.flags,rendererGroup=row.reserved,geometryGeneration=draw.Record.GeometryGeneration.ToString(),materialGeneration=draw.Record.MaterialGeneration.ToString()});
            }
            var receipt=new Receipt{logicalFrame=logical,engineFrame=Time.frameCount,rendererId=skin.GetInstanceID(),
                meshId=skin.sharedMesh?skin.sharedMesh.GetInstanceID():0,rendererName=skin.name,rendererType=skin.GetType().FullName,
                sourceEnabled=skin.enabled,sourceActive=skin.gameObject.activeInHierarchy,sourceForceOff=skin.forceRenderingOff,
                bendDegrees=bend,deformationRunning=running,rows=rows.ToArray()};
            frames.Add(new Pending{receipt=receipt});
            Require(rows.Count>0,"Actual identity frame contains no skin source draw.");
        }
        catch(Exception e){Fail(e);}
    }

    // Inject immediately after the existing temporal Dispatch in the same command buffer.
    public static void Record(CommandBuffer cmd,Camera camera,Texture identity,Texture moments,bool useIdentity)
    {
        if(!Selected(camera))return;
        try
        {
            var p=Find(logical);
            Require(p!=null&&p.receipt.engineFrame==Time.frameCount&&!p.receipt.recorded,"Missing/stale/duplicate temporal observation.");
            var r=p.receipt;r.useIdentity=useIdentity;
            Require(useIdentity&&identity&&moments,"Actual temporal dispatch did not use receiver identity.");
            r.width=identity.width;r.height=identity.height;r.identityFormat=identity.graphicsFormat.ToString();r.momentsFormat=moments.graphicsFormat.ToString();
            Require(identity.graphicsFormat==GraphicsFormat.R32G32B32A32_UInt&&moments.graphicsFormat==GraphicsFormat.R32G32B32A32_SFloat,"Unexpected native identity/moments formats.");
            Require(r.width>0&&r.height>0&&moments.width==r.width&&moments.height==r.height,"Identity/moments dimensions differ.");
            r.identityFile="frame-"+r.logicalFrame.ToString("D3")+"-identity.bin";r.momentsFile="frame-"+r.logicalFrame.ToString("D3")+"-moments.bin";r.recorded=true;
            Require(identityCopy.count==r.width*r.height,"Copy dimensions changed.");
            int kernel=identityCopyShader.FindKernel("CopyIdentity");
            cmd.SetComputeIntParams(identityCopyShader,"_Size",r.width,r.height);
            cmd.SetComputeBufferParam(identityCopyShader,kernel,"_IdentityCopy",identityCopy);
            cmd.SetComputeTextureParam(identityCopyShader,kernel,"_Identity",identity);
            cmd.DispatchCompute(identityCopyShader,kernel,(r.width+7)/8,(r.height+7)/8,1);
            pending++;
            try{cmd.RequestAsyncReadback(identityCopy,q=>ReadIdentity(p,q));}catch{pending--;throw;}
            pending++;
            try{cmd.RequestAsyncReadback(moments,0,q=>ReadMoments(p,q));}catch{pending--;throw;}
        }
        catch(Exception e){Fail(e);}
    }
    static void ReadIdentity(Pending p,AsyncGPUReadbackRequest request)
    {
        try
        {
            Require(!request.hasError,"Identity readback failed.");p.identity=request.GetData<uint>().ToArray();
            Require(p.identity.Length==p.receipt.width*p.receipt.height*4,"Identity readback byte length differs.");
            using(var writer=NewBinary(p.receipt.identityFile))foreach(uint value in p.identity)writer.Write(value);
        }
        catch(Exception e){p.receipt.error=e.ToString();Fail(e);}
        finally{pending--;p.callbacks++;FinishFrame(p);}
    }
    static void ReadMoments(Pending p,AsyncGPUReadbackRequest request)
    {
        try
        {
            Require(!request.hasError,"Moments readback failed.");p.moments=request.GetData<float>().ToArray();
            Require(p.moments.Length==p.receipt.width*p.receipt.height*4,"Moments readback byte length differs.");
            using(var writer=NewBinary(p.receipt.momentsFile))foreach(float value in p.moments)writer.Write(value);
        }
        catch(Exception e){p.receipt.error=e.ToString();Fail(e);}
        finally{pending--;p.callbacks++;FinishFrame(p);}
    }
    static BinaryWriter NewBinary(string file)=>new BinaryWriter(new FileStream(Path.Combine(directory,file),FileMode.CreateNew,FileAccess.Write));
    static bool Finite(float value)=>!float.IsNaN(value)&&!float.IsInfinity(value);
    static void FinishFrame(Pending p)
    {
        if(p.callbacks!=2)return;
        try
        {
            var r=p.receipt;
            if(r.error==null&&p.identity!=null&&p.moments!=null)
            {
                float minimum=float.PositiveInfinity,maximum=float.NegativeInfinity;double sum=0;
                for(int i=0;i<p.identity.Length;i+=4)
                {
                    if(p.identity[i+3]==0||p.identity[i+2]==0)continue;
                    bool owner=false;foreach(var row in r.rows)if((row.keyLow!=0||row.keyHigh!=0)&&row.keyLow==p.identity[i]&&row.keyHigh==p.identity[i+1]){owner=true;break;}
                    if(!owner)continue;
                    r.validPixels++;
                    if(!Finite(p.moments[i])||!Finite(p.moments[i+1])||!Finite(p.moments[i+2])||!Finite(p.moments[i+3])){r.nonfiniteMoments++;continue;}
                    float age=p.moments[i+2];minimum=Math.Min(minimum,age);maximum=Math.Max(maximum,age);sum+=age;
                    if(age>1)r.historyAboveOne++;if(age>2)r.historyAboveTwo++;
                }
                int finite=r.validPixels-r.nonfiniteMoments;
                r.minimumHistory=finite>0?minimum:0;r.maximumHistory=finite>0?maximum:0;r.meanHistory=finite>0?sum/finite:0;r.complete=true;
            }
            WriteJson("frame-"+r.logicalFrame.ToString("D3")+".json",r);
        }
        catch(Exception e){p.receipt.error=e.ToString();Fail(e);}
        finally{p.identity=null;p.moments=null;}
    }
    static void WriteJson(string file,object value)
    {using(var writer=new StreamWriter(new FileStream(Path.Combine(directory,file),FileMode.CreateNew,FileAccess.Write)))writer.Write(JsonUtility.ToJson(value,true));}
    static bool SameKeys(Receipt a,Receipt b)
    {
        if(a.rows.Length!=b.rows.Length)return false;
        foreach(var row in a.rows)
        {
            bool found=false;foreach(var other in b.rows)if(row.submesh==other.submesh&&row.keyLow==other.keyLow&&row.keyHigh==other.keyHigh){found=true;break;}
            if(!found)return false;
        }
        return true;
    }
    static bool AllFlags(Receipt receipt,uint flags)
    {if(receipt.rows==null||receipt.rows.Length==0)return false;foreach(var row in receipt.rows)if(row.flags!=flags)return false;return true;}
    public static Analysis DrainAndAnalyze()
    {
        Disarm();var result=new Analysis{motionEnabled=motionEnabled};
        try
        {
            AsyncGPUReadback.WaitAllRequests();Require(pending==0,"Readbacks did not drain.");
            Require(Failure==null,Failure??"Tap failed.");Require(frames.Count==Samples.Length,"Selected observations are missing.");
            foreach(int frame in Samples)
            {
                var p=Find(frame);Require(p!=null&&p.receipt.complete,"Incomplete selected frame "+frame);
                Require(p.receipt.validPixels>0&&p.receipt.nonfiniteMoments==0&&p.receipt.minimumHistory>=0,"No finite nonnegative visible skin identity/moments at frame "+frame);
                result.completedFrames++;
            }
            var a=Find(119).receipt;var b=Find(120).receipt;var c=Find(127).receipt;var d=Find(128).receipt;var e=Find(159).receipt;var f=Find(239).receipt;
            result.stableInitialAccumulation=a.historyAboveTwo>0;
            result.stableKeys=SameKeys(a,b)&&SameKeys(b,c)&&SameKeys(c,d)&&SameKeys(d,e)&&SameKeys(e,f);
            result.motionRowsQualified=AllFlags(b,motionEnabled?3u:0u)&&AllFlags(c,motionEnabled?3u:0u);
            result.motionHistoryRejected=b.maximumHistory<=1&&c.maximumHistory<=1;
            result.motionAccumulation=b.historyAboveOne>0||c.historyAboveOne>0;
            result.motionHistoryBounded=b.maximumHistory<=2&&c.maximumHistory<=2;
            result.observedPoseChange=b.deformationRunning&&c.deformationRunning&&Finite(b.bendDegrees)&&Finite(c.bendDegrees)&&b.bendDegrees!=c.bendDegrees;
            result.stoppedAccumulation=e.historyAboveOne>0&&f.historyAboveTwo>0;
            result.finalNonzeroPose=Finite(f.bendDegrees)&&f.bendDegrees!=0&&f.bendDegrees==c.bendDegrees&&!f.deformationRunning;
            bool movingBehavior=motionEnabled?result.motionAccumulation&&result.motionHistoryBounded:result.motionHistoryRejected;
            Require(result.stableInitialAccumulation&&result.stableKeys&&result.motionRowsQualified&&movingBehavior&&result.observedPoseChange&&result.stoppedAccumulation&&result.finalNonzeroPose,
                "Observed skin identity/history did not meet this explicit A/B side's fixed stopped/moving/stopped behavior.");
            result.status="passed";
        }
        catch(Exception error){result.error=error.ToString();Fail(error);}
        result.pending=pending;result.frames=frames.ConvertAll(p=>p.receipt).ToArray();
        if(identityCopy!=null){var owned=identityCopy;identityCopy=null;HybridLumenGIResourceRetirement.Retire(()=>owned.Dispose());}
        WriteJson("analysis.json",result);configured=false;target=null;skin=null;return result;
    }
}
