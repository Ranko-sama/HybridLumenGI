// Independent, finite CPU-source checks. No private state, mesh writes or GPU-consumption claim.
using System;
using System.Collections.Generic;
using System.IO;
using HybridLumenGI;
using UnityEngine;

public sealed class ContinuousDeformationCheck : IDisposable
{
    const double Tolerance=2e-6;
    readonly ContinuousDeformationExample sample;
    readonly string folder;
    readonly Mesh originalMesh,producerMesh;
    readonly Renderer renderer;
    readonly HybridLumenGIProxy proxy;
    readonly MeshFilter filter;
    readonly MeshData original;
    readonly Dictionary<int,Command> commands=new Dictionary<int,Command>();
    readonly Result result=new Result();
    StreamWriter snapshots;
    int lastLogical=-1,lastEngine=-1,lastSourceId,lastCapturedFrame=-1,finalPoseEngine=-1;
    int firstMotionCapture=-1;
    Vector3[] firstMotionPositions;
    bool seenSnapshot,finished,disposed;

    [Serializable] sealed class Submesh { public int topology;public int[] indices; }
    [Serializable] sealed class MeshData
    {
        public string name;public int instanceId;
        public Vector3[] positions,normals;public Vector4[] tangents;public Vector2[] uv;
        public Submesh[] submeshes;
    }
    [Serializable] sealed class Command
    { public int logical,engine;public float commandedTime;public double expectedTime; }
    [Serializable] sealed class Snapshot
    {
        public int logical,engine,sourceId,publishedFrame,capturedLogical,sdfId,chartsId;
        public float capturedCommandedTime;public double expectedTime,expectedShear,maxScalarError;
        public bool motionWindow;public Vector3[] positions;
    }
    [Serializable] sealed class FeatureReceipt
    {
        public int logical,engine,cameraId,giFrame,publishedInstances,readyCards,hardwareMeshes,hardwareMaterialUnknownRecords;
        public string camera;public bool featureActive,hardwareBackend;
    }
    [Serializable] sealed class Result
    {
        public string status="running",error;
        public string scope="Public CPU publication tuple and complete logical mesh agreement; not target-ray GPU consumption or image-quality approval";
        public double scalarTolerance=Tolerance,finalExpectedTime=128*(double)(1f/60f);
        public int observations,snapshotChanges,motionPublications,finalPublishedFrame=-1,finalSourceId;
        public int originalId,producerId,rendererId,proxyId,sdfResolution,updateIntervalFrames,vertexBudget,maximumWorkers;
        public long memoryBudgetBytes,uploadBudgetBytes;
        public bool differingMotionContents,finalAgrees;
        public double finalProducerError,finalReferenceError;
        public List<Command> commands=new List<Command>();
        public List<FeatureReceipt> feature=new List<FeatureReceipt>();
    }
    [Serializable] sealed class FinalMeshes
    { public MeshData originalCurrent,producer,published,expected; }

    public ContinuousDeformationCheck(ContinuousDeformationExample sample,string folder)
    {
        this.sample=sample;this.folder=folder;
        try
        {
            Require(sample&&sample.OriginalMesh&&sample.ProducerMesh&&sample.SourceRenderer,"Example source missing");
            Require(Directory.Exists(folder),"Checker requires the root's existing output folder");
            Require(!File.Exists(Path.Combine(folder,"check-result.json"))&&!File.Exists(Path.Combine(folder,"snapshots.jsonl"))&&
                !File.Exists(Path.Combine(folder,"original-mesh.json"))&&!File.Exists(Path.Combine(folder,"final-meshes.json")),"Checker output already exists");
            originalMesh=sample.OriginalMesh;producerMesh=sample.ProducerMesh;renderer=sample.SourceRenderer;
            proxy=renderer.GetComponent<HybridLumenGIProxy>();filter=renderer.GetComponent<MeshFilter>();
            Require(proxy&&filter&&sample.Deformation,"Example components missing");
            original=Read(originalMesh);Compare(original,original,"original finite streams");
            Require(original.positions.Length>0,"Original mesh is empty");
            result.originalId=originalMesh.GetInstanceID();result.producerId=producerMesh.GetInstanceID();
            result.rendererId=renderer.GetInstanceID();result.proxyId=proxy.GetInstanceID();
            result.sdfResolution=sample.Deformation.sdfResolution;result.updateIntervalFrames=sample.Deformation.updateIntervalFrames;
            result.vertexBudget=HybridLumenGIDeformedMesh.VertexBudgetPerFrame;result.maximumWorkers=HybridLumenGIDeformedMesh.MaximumWorkers;
            result.memoryBudgetBytes=HybridLumenGIDeformedMesh.MemoryBudgetBytes;result.uploadBudgetBytes=HybridLumenGIDeformedMesh.UploadBudgetBytesPerFrame;
            File.WriteAllText(Path.Combine(folder,"original-mesh.json"),JsonUtility.ToJson(original,true));
            snapshots=new StreamWriter(new FileStream(Path.Combine(folder,"snapshots.jsonl"),FileMode.CreateNew,FileAccess.Write)){AutoFlush=true};
            var initial=new Command{logical=-1,engine=Time.frameCount,commandedTime=0,expectedTime=0};
            commands.Add(initial.engine,initial);result.commands.Add(initial);Save();
        }
        catch(Exception error){Fail(error);throw;}
    }

    static void Require(bool value,string reason){if(!value)throw new InvalidOperationException(reason);}
    static double ExpectedTime(int logical)=>Math.Max(0,Math.Min(128,logical-31))*(double)(1f/60f);
    static double Coefficient(double time)=>0.4*Math.Sin(2*Math.PI*time/4);
    static bool Finite(double value)=>!double.IsNaN(value)&&!double.IsInfinity(value);
    static MeshData Read(Mesh mesh)
    {
        Require(mesh&&mesh.isReadable,"Readable mesh required");
        var data=new MeshData{name=mesh.name,instanceId=mesh.GetInstanceID(),positions=mesh.vertices,normals=mesh.normals,tangents=mesh.tangents,uv=mesh.uv,submeshes=new Submesh[mesh.subMeshCount]};
        for(int s=0;s<data.submeshes.Length;s++)data.submeshes[s]=new Submesh{topology=(int)mesh.GetTopology(s),indices=mesh.GetIndices(s,true)};
        return data;
    }
    static Vector3 Normalize(double x,double y,double z)
    {
        double length=Math.Sqrt(x*x+y*y+z*z);Require(Finite(length)&&length>0,"Reference direction is invalid");
        return new Vector3((float)(x/length),(float)(y/length),(float)(z/length));
    }
    MeshData Expected(double time)
    {
        if(time==0)return original;
        double k=Coefficient(time);
        var data=new MeshData{name="Independent shear reference",positions=new Vector3[original.positions.Length],normals=new Vector3[original.normals.Length],
            tangents=new Vector4[original.tangents.Length],uv=original.uv,submeshes=original.submeshes};
        for(int i=0;i<data.positions.Length;i++)
        {var p=original.positions[i];data.positions[i]=new Vector3((float)(p.x+k*p.y),p.y,p.z);}
        for(int i=0;i<data.normals.Length;i++)
        {var n=original.normals[i];data.normals[i]=Normalize(n.x,n.y-k*n.x,n.z);}
        for(int i=0;i<data.tangents.Length;i++)
        {var t=original.tangents[i];var n=Normalize(t.x+k*t.y,t.y,t.z);data.tangents[i]=new Vector4(n.x,n.y,n.z,t.w);}
        return data;
    }
    static void Scalar(double actual,double expected,string label,ref double maximum)
    {
        double error=Math.Abs(actual-expected);
        Require(Finite(actual)&&Finite(expected)&&error<=Tolerance,label+" differs: "+actual.ToString("R")+" / "+expected.ToString("R"));
        maximum=Math.Max(maximum,error);
    }
    static double Compare(MeshData actual,MeshData expected,string label)
    {
        Require(actual.positions.Length==expected.positions.Length&&actual.normals.Length==expected.normals.Length&&actual.tangents.Length==expected.tangents.Length&&
            actual.uv.Length==expected.uv.Length&&actual.submeshes.Length==expected.submeshes.Length,label+" stream lengths differ");
        double maximum=0;
        for(int i=0;i<actual.positions.Length;i++)for(int c=0;c<3;c++)Scalar(actual.positions[i][c],expected.positions[i][c],label+" position["+i+"]["+c+"]",ref maximum);
        for(int i=0;i<actual.normals.Length;i++)for(int c=0;c<3;c++)Scalar(actual.normals[i][c],expected.normals[i][c],label+" normal["+i+"]["+c+"]",ref maximum);
        for(int i=0;i<actual.tangents.Length;i++)for(int c=0;c<4;c++)Scalar(actual.tangents[i][c],expected.tangents[i][c],label+" tangent["+i+"]["+c+"]",ref maximum);
        for(int i=0;i<actual.uv.Length;i++)for(int c=0;c<2;c++)Scalar(actual.uv[i][c],expected.uv[i][c],label+" uv["+i+"]["+c+"]",ref maximum);
        for(int s=0;s<actual.submeshes.Length;s++)
        {
            var a=actual.submeshes[s];var e=expected.submeshes[s];Require(a.topology==e.topology&&a.indices.Length==e.indices.Length,label+" submesh "+s+" differs");
            for(int i=0;i<a.indices.Length;i++)Require(a.indices[i]==e.indices[i],label+" index["+s+"]["+i+"] differs");
        }
        return maximum;
    }
    void CheckVisibleSource()
    {
        Require(sample&&ReferenceEquals(sample.OriginalMesh,originalMesh)&&ReferenceEquals(sample.ProducerMesh,producerMesh)&&ReferenceEquals(sample.SourceRenderer,renderer)&&
            ReferenceEquals(filter.sharedMesh,producerMesh)&&ReferenceEquals(proxy.SourceRenderer,renderer),"Visible producer/source identity changed");
    }
    Mesh PublishedSource()
    {
        Require(HybridLumenGIDeformedMesh.HasSnapshot(renderer),"Expected published snapshot missing");
        var source=HybridLumenGIDeformedMesh.GetSourceMesh(renderer);var sdf=proxy.MeshSdf;var charts=proxy.SurfaceCharts;
        Require(source&&sdf&&charts&&ReferenceEquals(proxy.SourceMesh,source)&&ReferenceEquals(sdf.SourceMesh,source)&&ReferenceEquals(charts.SourceMesh,source)&&
            sdf.IsValid&&charts.IsValid,"Published mesh/SDF/charts tuple is inconsistent or invalid");
        return source;
    }

    public void Observe(int logical,int engine,float commandedTime,HybridLumenGIRendererFeature feature,Camera camera)
    {
        try
        {
            Require(!disposed&&!finished&&result.error==null,"Checker is no longer observing");
            Require(logical==lastLogical+1&&logical<=255&&(lastEngine<0||engine==lastEngine+1),"Camera sequence differs");
            double expectedTime=ExpectedTime(logical),unused=0;Scalar(commandedTime,expectedTime,"commanded time",ref unused);
            Require(sample.Running==(logical>=32&&logical<160),"Running state differs from fixed commands");
            var command=new Command{logical=logical,engine=engine,commandedTime=commandedTime,expectedTime=expectedTime};
            // The constructor's paused receipt can share the first callback engine frame.
            if(commands.TryGetValue(engine,out var prior)){Require(prior.logical==-1&&logical==0,"Engine command already recorded");result.commands.Remove(prior);}
            commands[engine]=command;result.commands.Add(command);lastLogical=logical;lastEngine=engine;result.observations++;
            if(logical==159)finalPoseEngine=engine;
            CheckVisibleSource();
            if(HybridLumenGIDeformedMesh.HasSnapshot(renderer))
            {
                var source=PublishedSource();seenSnapshot=true;int captured=sample.Deformation.PublishedFrame;
                if(source.GetInstanceID()!=lastSourceId||captured!=lastCapturedFrame)
                {
                    Require(commands.TryGetValue(captured,out var capture),"Published capture frame has no recorded command: "+captured);
                    var data=Read(source);double error=Compare(data,Expected(capture.expectedTime),"captured frame "+captured);
                    bool moving=logical>=32&&logical<160&&capture.logical>=32&&capture.logical<160;
                    if(moving)
                    {
                        result.motionPublications++;
                        if(firstMotionPositions==null){firstMotionPositions=data.positions;firstMotionCapture=captured;}
                        else if(captured!=firstMotionCapture)
                            for(int i=0;i<data.positions.Length;i++)for(int c=0;c<3;c++)
                                if(Math.Abs((double)data.positions[i][c]-firstMotionPositions[i][c])>Tolerance)result.differingMotionContents=true;
                    }
                    snapshots.WriteLine(JsonUtility.ToJson(new Snapshot{logical=logical,engine=engine,sourceId=source.GetInstanceID(),publishedFrame=captured,capturedLogical=capture.logical,
                        sdfId=proxy.MeshSdf.GetInstanceID(),chartsId=proxy.SurfaceCharts.GetInstanceID(),capturedCommandedTime=capture.commandedTime,expectedTime=capture.expectedTime,
                        expectedShear=Coefficient(capture.expectedTime),maxScalarError=error,motionWindow=moving,positions=data.positions}));
                    result.snapshotChanges++;lastSourceId=source.GetInstanceID();lastCapturedFrame=captured;
                }
            }
            else Require(!seenSnapshot,"Published source disappeared");
            if(logical==159||logical==255)CheckFeature(logical,engine,feature,camera);
            if(logical==255)CheckFinal();
        }
        catch(Exception error){Fail(error);throw;}
    }
    void CheckFeature(int logical,int engine,HybridLumenGIRendererFeature feature,Camera camera)
    {
        Require(feature&&camera,"Feature or target camera missing");
        HybridLumenGIRendererFeature.CameraDiagnostics found=null;
        foreach(var d in feature.GetDiagnostics())if(d.camera==camera.name){Require(found==null,"Ambiguous camera diagnostics");found=d;}
        Require(found!=null,"Target camera diagnostics missing");
        var row=new FeatureReceipt{logical=logical,engine=engine,cameraId=camera.GetInstanceID(),camera=camera.name,featureActive=feature.isActive,giFrame=found.frame,
            publishedInstances=found.publishedInstances,readyCards=found.readyCards,hardwareBackend=found.hardwareBackend,hardwareMeshes=found.hardwareMeshes,hardwareMaterialUnknownRecords=found.hardwareMaterialUnknownRecords};
        result.feature.Add(row);
        Require(row.featureActive&&row.giFrame>0&&row.publishedInstances>0&&row.readyCards>0&&row.hardwareBackend&&row.hardwareMeshes>0&&row.hardwareMaterialUnknownRecords==0,"Public Feature progress/hardware/material condition failed");
        if(logical==255)Require(result.feature.Count==2&&row.giFrame>result.feature[0].giFrame,"Feature frame did not progress");
        PublishedSource();
    }
    void CheckFinal()
    {
        CheckVisibleSource();var source=PublishedSource();
        var data=new FinalMeshes{originalCurrent=Read(originalMesh),producer=Read(producerMesh),published=Read(source),expected=Expected(ExpectedTime(255))};
        File.WriteAllText(Path.Combine(folder,"final-meshes.json"),JsonUtility.ToJson(data,true));
        Compare(data.originalCurrent,original,"original preservation");Compare(data.producer,data.expected,"final producer/reference");
        result.finalProducerError=Compare(data.published,data.producer,"final publication/producer");
        result.finalReferenceError=Compare(data.published,data.expected,"final publication/reference");
        Require(finalPoseEngine>=0&&sample.Deformation.PublishedFrame>=finalPoseEngine,"Final publication predates final visible pose");
        result.finalPublishedFrame=sample.Deformation.PublishedFrame;result.finalSourceId=source.GetInstanceID();result.finalAgrees=true;
    }
    public void Finish()
    {
        if(finished)return;
        try
        {
            Require(!disposed&&result.error==null&&lastLogical==255&&result.observations==256,"Finite camera sequence incomplete");
            Require(result.motionPublications>=2&&result.differingMotionContents,"No two distinct captured motion poses were published during motion");
            Require(result.feature.Count==2&&result.finalAgrees,"Final or Feature checks incomplete");
            result.status="passed";finished=true;Save();Dispose();
        }
        catch(Exception error){Fail(error);throw;}
    }
    void Save()=>File.WriteAllText(Path.Combine(folder,"check-result.json"),JsonUtility.ToJson(result,true));
    void Fail(Exception error)
    {
        if(result.error!=null)return;
        result.status="failed";result.error=error.ToString();
        try{Save();}finally{Dispose();}
    }
    public void Dispose(){if(disposed)return;disposed=true;snapshots?.Dispose();snapshots=null;}
}
