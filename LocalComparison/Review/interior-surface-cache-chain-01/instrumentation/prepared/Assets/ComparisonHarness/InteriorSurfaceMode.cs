// One existing CPU fixture, one fixed snapshot and four actual GPU queries. No transport tuning.
using System;
using System.IO;
using System.Linq;
using System.Collections.Generic;
using System.Reflection;
using System.Security.Cryptography;
using UnityEngine;
using UnityEngine.Rendering;
using HybridLumenGI;
public static class InteriorSurfaceMode
{
    public static bool Enabled=>Array.IndexOf(Environment.GetCommandLineArgs(),"-interiorSurface")>=0;
    public static GraphicsBuffer Buffer{get;private set;}
    static ComparisonCapture capture;static HybridLumenGIProxy proxy;static Mesh mesh,captureMesh;static HybridLumenGISurfaceCharts asset;
    static Vector4[] origins;static int frame,receipts,pending,completed;static string directory,failure;static bool frozen,attempted,closed;
    const int Rows=80;
    [Serializable] class ChartRecord{public uint id;public int submesh;public int[] triangles,captureIndices;public Matrix4x4 localToCard;public Vector3 direction;}
    [Serializable] class Fixture{public Vector3 translation;public Vector3[] vertices,normals;public Vector2[] uv;public int[] indices;public string fingerprint;public ChartRecord[] charts;public Vector4[] origins;public int[] targetPrimitives;}
    [Serializable] class Binding{public bool valid;public int primitive;public uint cardIndex,chartId,layoutGeneration,geometryRevision;}
    [Serializable] class Snapshot{public int logical,engine,gi,slot,id,revision,geometryRevision,epoch,grid,atlasWidth,atlasHeight;public bool hardware,published,captureReady,sourceCurrent,charted;public uint atlasGeneration;public Binding[] bindings;public Vector4[] origins;}
    [Serializable] class Result{public int receipts,pending,completed,bytes;public bool attempted;public string failure,sha256;}
    static string payloadHash;
    static void Require(bool value,string message){if(!value)throw new Exception(message);}
    static void Json(string name,object o)=>File.WriteAllText(Path.Combine(directory,name),JsonUtility.ToJson(o,true));
    static void Quad(List<Vector3> v,List<int> ix,Vector3 a,Vector3 b,Vector3 c,Vector3 d)
    {int n=v.Count;v.AddRange(new[]{a,b,c,d});ix.AddRange(new[]{n,n+1,n+2,n,n+2,n+3});}
    public static void Configure(ComparisonCapture value)
    {
        capture=value;var audit=UnityEngine.Object.FindFirstObjectByType<RuntimeAuditProbe>();Require(audit,"Audit probe missing");audit.enabled=false;
        var v=new List<Vector3>();var ix=new List<int>();
        Quad(v,ix,new(-2,-2,-2),new(2,-2,-2),new(2,2,-2),new(-2,2,-2));
        Quad(v,ix,new(-2,2,2),new(2,2,2),new(2,-2,2),new(-2,-2,2));
        Quad(v,ix,new(-2,-2,2),new(2,-2,2),new(2,-2,-2),new(-2,-2,-2));
        Quad(v,ix,new(-2,2,-2),new(2,2,-2),new(2,2,2),new(-2,2,2));
        Quad(v,ix,new(-2,-2,2),new(-2,-2,-2),new(-2,2,-2),new(-2,2,2));
        Quad(v,ix,new(2,-2,-2),new(2,-2,2),new(2,2,2),new(2,2,-2));
        Quad(v,ix,new(-1,-1,-0.4f),new(1,-1,-0.4f),new(1,1,-0.4f),new(-1,1,-0.4f));
        Quad(v,ix,new(-1,-1,0.4f),new(1,-1,0.4f),new(1,1,0.4f),new(-1,1,0.4f));
        mesh=new Mesh{name="Existing enclosed-room and internal-layer CPU fixture"};mesh.SetVertices(v);mesh.SetTriangles(ix,0);
        mesh.uv=Enumerable.Range(0,v.Count).Select(i=>new Vector2(i%4==1||i%4==2?1:0,i%4>=2?1:0)).ToArray();mesh.RecalculateNormals();mesh.RecalculateBounds();
        var charts=HybridLumenGISurfaceCharts.Bake(mesh,new HybridLumenGISurfaceCharts.BakeSettings(),out var report);
        Require(report.inputTriangles==16&&report.validTriangles==16,"Fixture triangle count changed");
        captureMesh=HybridLumenGISurfaceCharts.CreateCaptureMesh(mesh,charts);asset=ScriptableObject.CreateInstance<HybridLumenGISurfaceCharts>();asset.SetBakedData(mesh,captureMesh,charts);
        var go=new GameObject("Same-owner internal layers");go.transform.position=new Vector3(100,0,0);go.AddComponent<MeshFilter>().sharedMesh=mesh;
        var renderer=go.AddComponent<MeshRenderer>();var shader=Shader.Find("Universal Render Pipeline/Lit");Require(shader,"Stock Lit missing");
        var material=new Material(shader);material.SetColor("_BaseColor",new Color(.5f,.5f,.5f,1));material.SetFloat("_Metallic",0);material.SetFloat("_Smoothness",0);renderer.sharedMaterial=material;
        proxy=go.AddComponent<HybridLumenGIProxy>();proxy.SetSources(renderer,null);proxy.SetSurfaceCharts(asset);
        origins=new Vector4[4];for(int i=0;i<4;i++){int t=12+i;Vector3 p=(v[ix[t*3]]+v[ix[t*3+1]]+v[ix[t*3+2]])/3f+go.transform.position+new Vector3(0,0,.5f);origins[i]=new Vector4(p.x,p.y,p.z,.75f);}
        capture.totalFrames=120;capture.quitWhenComplete=true;capture.featureOff=false;capture.indirectOnly=false;capture.label="interior-surface-cache-chain-01";capture.feature.SetActive(true);
        var settings=(HybridLumenGIRendererFeature.Settings)typeof(HybridLumenGIRendererFeature).GetField("settings",BindingFlags.Instance|BindingFlags.NonPublic).GetValue(capture.feature);
        settings.preferHardwareTracing=true;settings.exactSoftwareTracing=true;settings.measureGpuCost=false;settings.adaptiveGpuBudget=false;
        capture.camera.transform.SetPositionAndRotation(new Vector3(100,0,0),Quaternion.identity);capture.camera.nearClipPlane=.1f;capture.camera.farClipPlane=20;
        Buffer=new GraphicsBuffer(GraphicsBuffer.Target.Structured,4*Rows,16);Buffer.SetData(new Vector4[4*Rows]);
    }
    public static void Apply(ComparisonCapture value,int logical,string folder)
    {
        Require(value==capture&&!closed,"Unexpected fixture Apply");frame=logical;directory=folder;if(failure!=null)throw new Exception(failure);
        if(!frozen){frozen=true;Json("interior-source.json",new Fixture{translation=proxy.transform.position,vertices=mesh.vertices,normals=mesh.normals,uv=mesh.uv,indices=mesh.GetIndices(0),
            fingerprint=HybridLumenGISurfaceCharts.ComputeContentFingerprint(mesh),charts=asset.Charts.Select((c,i)=>new ChartRecord{id=c.stableId,submesh=c.sourceSubmesh,triangles=c.triangleIndices,captureIndices=captureMesh.GetIndices(i),localToCard=c.localToCard,direction=c.direction}).ToArray(),
            origins=origins,targetPrimitives=new[]{12,13,14,15}});}
    }
    public static void Record(CommandBuffer cmd,ComputeShader shader,int kernel,Camera camera,HybridLumenGIScene scene,HybridLumenGISurfaceCache surface,ComputeBuffer cache,int grid,int epoch,int gi,bool hardware)
    {
        if(!Enabled||camera!=capture.camera||frame!=119||attempted)return;attempted=true;
        int slot=-1;for(int i=0;i<scene.Capacity;i++)if(scene.GetProxy(i)==proxy){slot=i;break;}
        var s=new Snapshot{logical=frame,engine=Time.frameCount,gi=gi,slot=slot,id=proxy.StableId,revision=proxy.Revision,geometryRevision=proxy.GeometryContentRevision,epoch=epoch,grid=grid,
            hardware=hardware,published=scene.IsPublished(slot),captureReady=surface.IsSlotReady(slot,proxy.StableId,proxy.Revision),sourceCurrent=surface.IsSlotSourceCurrent(slot,proxy.StableId,proxy.Revision),
            charted=surface.RequiresCardCoverage(slot),atlasWidth=surface.AtlasWidth,atlasHeight=surface.AtlasHeight,atlasGeneration=surface.AtlasGeneration,origins=origins,bindings=new Binding[4]};
        for(int i=0;i<4;i++){bool valid=surface.TryGetTriangleBinding(slot,mesh,0,12+i,out var b);s.bindings[i]=new Binding{valid=valid,primitive=12+i,cardIndex=b.cardIndex,chartId=b.chartId,layoutGeneration=b.layoutGeneration,geometryRevision=b.geometryRevision};}
        Json("interior-snapshot.json",s);
        if(!hardware||kernel<0||!s.published||!s.captureReady||!s.sourceCurrent||!s.charted)return;
        cmd.SetComputeBufferParam(shader,kernel,"_ISC_Records",Buffer);cmd.SetComputeBufferParam(shader,kernel,"_HLGI_CacheRead",cache);cmd.SetComputeVectorArrayParam(shader,"_ISC_Origins",origins);
        cmd.DispatchCompute(shader,kernel,1,1,1);pending++;
        cmd.RequestAsyncReadback(Buffer,r=>{try{Require(r.done&&!r.hasError,"Interior query readback failed");var bytes=r.GetData<byte>().ToArray();Require(bytes.Length==4*Rows*16,"Interior query ABI changed");
            File.WriteAllBytes(Path.Combine(directory,"interior-query.bin"),bytes);using(var hash=SHA256.Create())payloadHash=BitConverter.ToString(hash.ComputeHash(bytes)).Replace("-","");completed++;}
            catch(Exception e){failure=failure??e.ToString();}finally{pending--;}});
    }
    public static void Rendered(int logical){Require(logical==receipts&&logical==frame,"Missing fixture frame receipt");receipts++;}
    public static void Close()
    {
        if(closed)return;closed=true;if(pending>0)AsyncGPUReadback.WaitAllRequests();Buffer?.Dispose();Buffer=null;
        Json("interior-result.json",new Result{receipts=receipts,pending=pending,completed=completed,attempted=attempted,bytes=completed*4*Rows*16,failure=failure,sha256=payloadHash});
        Require(receipts==120&&pending==0&&failure==null,"Finite internal-layer collection incomplete: "+failure);
    }
}
