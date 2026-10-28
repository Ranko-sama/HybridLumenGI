// Read-only hooks at original producer/publication/consumer locations; no worker waits.
using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Threading.Tasks;
using System.Reflection;
using UnityEngine;

namespace HybridLumenGI
{
    public static partial class DeformationEventTap
    {
        static int lifecycleSequence;
        static readonly List<Life> earlyLifecycle=new List<Life>();
        [Serializable] sealed class MeshContent
        {
            public string label,file,sha256;public int mesh,bytes,vertices,normals,tangents,uv,submeshes;
            public int[] indices,topologies;public Bounds bounds;
            public string format="little endian: int vertex count then float3 positions; same count-prefixed normals(float3), tangents(float4), UV(float2); int submesh count; each int topology, int index count, int32 indices";
        }
        [Serializable] sealed class Life
        {
            public int sequence,logical,engine,captureFrame,publishedCaptureFrame,pendingFrame;
            public string phase,workerStatus,meshReceipt,assetsReceipt,sdfFingerprint,chartFingerprint;
            public uint requestGeneration,jobGeneration,chartVersion;
            public int mesh,capture,sdf,sdfMesh,texture,charts,chartsMesh,chartsCapture;
            public int snapshotMeshAfter;
            public bool linksCoherent;
            public long reservedBytes,snapshotReservation;
        }
        [Serializable] sealed class SnapshotAssets
        {
            public string captureMeshReceipt,sdfFile,sdfSha256;
            public int resolution,sdfBytes;public Bounds sdfBounds;public bool watertight;
            public HybridLumenGISurfaceCharts.Chart[] charts;
        }
        static int Id(UnityEngine.Object value)=>ReferenceEquals(value,null)?0:value.GetInstanceID();
        static string[] WorkerStates()
        {
            var values=new List<string>();
            var jobs=(IEnumerable)typeof(HybridLumenGIDeformedMesh).GetField("Jobs",BindingFlags.Static|BindingFlags.NonPublic).GetValue(null);
            foreach(var job in jobs)if(ReferenceEquals(Field(job,"owner"),deformation))
                values.Add(Field(job,"generation")+"/capture"+Field(job,"frame")+"/"+((Task)Field(job,"work")).Status+"/cleanupFailed="+Field(job,"cleanupFailed"));
            return values.ToArray();
        }
        public static void SaveVisibleInput(string label,Mesh mesh)=>SaveMesh(label,mesh);
        static string SaveMesh(string label,Mesh mesh)
        {
            if(mesh==null || directory==null)throw new Exception("Mesh receipt has no readable source/output");
            var p=mesh.vertices;var n=mesh.normals;var t=mesh.tangents;var uv=mesh.uv;
            var receipt=new MeshContent{label=label,mesh=Id(mesh),vertices=p.Length,normals=n.Length,tangents=t.Length,uv=uv.Length,
                submeshes=mesh.subMeshCount,indices=new int[mesh.subMeshCount],topologies=new int[mesh.subMeshCount],bounds=mesh.bounds};
            byte[] bytes;
            using(var stream=new MemoryStream())using(var writer=new BinaryWriter(stream))
            {
                writer.Write(p.Length);foreach(var v in p){writer.Write(v.x);writer.Write(v.y);writer.Write(v.z);}
                writer.Write(n.Length);foreach(var v in n){writer.Write(v.x);writer.Write(v.y);writer.Write(v.z);}
                writer.Write(t.Length);foreach(var v in t){writer.Write(v.x);writer.Write(v.y);writer.Write(v.z);writer.Write(v.w);}
                writer.Write(uv.Length);foreach(var v in uv){writer.Write(v.x);writer.Write(v.y);}
                writer.Write(mesh.subMeshCount);
                for(int s=0;s<mesh.subMeshCount;s++)
                {
                    int[] indices=mesh.GetIndices(s,true);receipt.indices[s]=indices.Length;receipt.topologies[s]=(int)mesh.GetTopology(s);
                    writer.Write(receipt.topologies[s]);writer.Write(indices.Length);foreach(int index in indices)writer.Write(index);
                }
                writer.Flush();bytes=stream.ToArray();
            }
            receipt.file="mesh-"+label+".bin";receipt.bytes=bytes.Length;receipt.sha256=Hash(bytes);
            WriteNew(Path.Combine(directory,receipt.file),bytes);SaveJson("mesh-"+label+".json",receipt);
            return "mesh-"+label+".json";
        }
        static void FlushLifecycle()
        {
            if(directory==null)return;
            foreach(var row in earlyLifecycle)File.AppendAllText(Path.Combine(directory,"geometry-lifecycle.jsonl"),JsonUtility.ToJson(row)+"\n");
            earlyLifecycle.Clear();
        }
        public static void GeometryLifecycle(string phase,HybridLumenGIDeformedMesh owner,object job,object snapshot)
        {
            if(!ReferenceEquals(owner,deformation))return;
            // Also record late actual destruction after observer Finish. Never throw into product rollback.
            try
            {
                var row=new Life{sequence=++lifecycleSequence,phase=phase,logical=logical,engine=Time.frameCount,
                    requestGeneration=(uint)Field(owner,"generation"),captureFrame=job!=null?(int)Field(job,"frame"):-1,
                    jobGeneration=job!=null?(uint)Field(job,"generation"):0,publishedCaptureFrame=owner.PublishedFrame,pendingFrame=owner.PendingFrame,
                    reservedBytes=HybridLumenGIDeformedMesh.ReservedBytes,snapshotMeshAfter=Id(HybridLumenGIDeformedMesh.GetSourceMesh(target))};
                var task=job!=null?Field(job,"work") as Task:null;row.workerStatus=task?.Status.ToString();
                if(snapshot!=null)
                {
                    var mesh=Field(snapshot,"mesh") as Mesh;var sdf=Field(snapshot,"sdf") as HybridLumenGIMeshSdf;
                    var charts=Field(snapshot,"charts") as HybridLumenGISurfaceCharts;
                    row.mesh=Id(mesh);row.capture=Id(Field(snapshot,"capture") as Mesh);row.sdf=Id(sdf);row.sdfMesh=Id(sdf?.SourceMesh);
                    row.texture=Id(Field(snapshot,"texture") as Texture3D);row.charts=Id(charts);row.chartsMesh=Id(charts?.SourceMesh);row.chartsCapture=Id(charts?.CaptureMesh);
                    row.chartVersion=charts?.ContentVersion??0;row.sdfFingerprint=Field(sdf,"geometryFingerprint") as string;row.chartFingerprint=Field(charts,"sourceFingerprint") as string;
                    row.snapshotReservation=(long)Field(snapshot,"reservation");
                    row.linksCoherent=row.mesh!=0 && row.sdfMesh==row.mesh && row.chartsMesh==row.mesh && row.capture!=0 && row.chartsCapture==row.capture && row.texture!=0;
                    if(phase=="capture" || phase=="publish")row.meshReceipt=SaveMesh(phase+"-"+row.sequence,mesh);
                    if(phase=="publish")
                    {
                        var distances=((Texture3D)Field(snapshot,"texture")).GetPixelData<float>(0).ToArray();
                        var bytes=new byte[distances.Length*4];Buffer.BlockCopy(distances,0,bytes,0,bytes.Length);
                        var assets=new SnapshotAssets{captureMeshReceipt=SaveMesh("capture-mesh-"+row.sequence,charts.CaptureMesh),
                            sdfFile="sdf-"+row.sequence+".bin",sdfSha256=Hash(bytes),sdfBytes=bytes.Length,resolution=sdf.Resolution,
                            sdfBounds=sdf.LocalBounds,watertight=sdf.Watertight,charts=charts.Charts};
                        WriteNew(Path.Combine(directory,assets.sdfFile),bytes);row.assetsReceipt="snapshot-assets-"+row.sequence+".json";
                        SaveJson(row.assetsReceipt,assets);
                        if(initialSnapshotMesh==0)initialSnapshotMesh=row.mesh;
                        if(logical>=160){publicationLogical=logical;publishedMesh=row.mesh;}
                    }
                }
                earlyLifecycle.Add(row);FlushLifecycle();
            }
            catch(Exception ex)
            {
                failure=failure??ex.ToString();
                if(directory!=null)try{File.AppendAllText(Path.Combine(directory,"geometry-observer-errors.txt"),ex+"\n");}catch{}
            }
        }
        static void CapturePrepared(HybridLumenGIScene scene,HybridLumenGISurfaceCache surface)
        {
            for(int i=0;i<scene.Capacity;i++)if(ReferenceEquals(scene.GetRenderer(i),target))
            {current.sceneSlot=i;current.sceneIdentity=scene.Data[i].identity;break;}
            foreach(var r in scene.DirtyRegions)current.changes.Add(new Dirty{stableId=r.StableId,previousRevision=r.PreviousRevision,
                revision=r.Revision,kind=(int)r.Kind,previous=r.PreviousBounds,current=r.CurrentBounds});
            foreach(var owner in (Array)Field(surface,"owners"))
            {
                if(owner==null || !ReferenceEquals(Field(owner,"renderer"),target))continue;
                current.surfaceMesh=Id(Field(owner,"sourceMesh") as Mesh);current.surfaceCaptureMesh=Id(Field(owner,"captureMesh") as Mesh);
                current.surfaceCharts=Id(Field(owner,"charts") as UnityEngine.Object);
                current.surfaceGeometryRevision=(int)Field(owner,"sourceGeometryRevision");current.surfaceLayout=(uint)Field(owner,"layoutGeneration");break;
            }
        }
        public static void GeometryBound(Camera selected,HybridLumenGIHardwareBackend geometry)
        {
            if(selected!=camera)return;
            Observe(()=>
            {
                boundGeometry=geometry;
                if(geometry==null)return;
                current.backendVersion=geometry.GeometryVersion;current.backendReady=geometry.IsReady;current.backendCanDispatch=geometry.CanDispatch;
                foreach(var state in (Array)Field(geometry,"meshStates"))
                {
                    if(state==null || !ReferenceEquals(Field(state,"renderer"),target))continue;
                    current.backendMesh=Id(Field(state,"mesh") as Mesh);current.backendGeometryRevision=(int)(uint)Field(state,"geometryRevision");
                    current.backendFirstInstance=(int)Field(state,"firstInstance");current.backendInstanceCount=(int)Field(state,"instanceCount");break;
                }
                // Called only after actual binding, before the original dispatch and detail decision.
                if(logical>=160 && firstNewDispatch<0 && publishedMesh!=0 && publishedMesh!=initialSnapshotMesh &&
                    current.hardware && geometry.CanDispatch && current.backendMesh==publishedMesh && current.backendInstanceCount>0)
                    firstNewDispatch=logical;
                current.firstNewDispatch=firstNewDispatch;
            });
        }
    }
}
