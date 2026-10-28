// Test-only source Lit materials; original renderer lists perform both captures.
using System;
using System.IO;
using System.Linq;
using System.Reflection;
using UnityEngine;
using UnityEngine.Rendering;
using HybridLumenGI;
public static class SurfaceDetailAlbedoMode
{
    public static bool Enabled=>Array.IndexOf(Environment.GetCommandLineArgs(),"-surfaceDetailAlbedo")>=0;
    static ComparisonCapture capture;static HybridLumenGIRendererFeature.Settings settings;
    static GraphicsBuffer buffer;static int frame,receipts,pending,completed;static string directory,failure;static bool closed;
    static readonly Vector3[] centers={new Vector3(99.4f,0,0),new Vector3(100.6f,0,0)};
    static Material[] materials=new Material[2];
    const BindingFlags Fields=BindingFlags.Instance|BindingFlags.NonPublic|BindingFlags.Public;
    static object Field(object o,string n)=>o.GetType().GetField(n,Fields).GetValue(o);
    static void Require(bool value,string message){if(!value)throw new Exception(message);}
    [Serializable] class Receipt{public int frame,engine,width,height;public bool hardware,native,mulKeyword,scaledKeyword;public string file;public Vector3[] centers;}
    [Serializable] class Result{public int receipts,pending,completed;public string failure;}
    static void Json(string name,object o)=>File.WriteAllText(Path.Combine(directory,name),JsonUtility.ToJson(o,true));
    static Texture2D Texture(Color low,Color high,bool upperRight)
    {
        var t=new Texture2D(2,2,TextureFormat.RGBAFloat,false,true){filterMode=FilterMode.Point,wrapMode=TextureWrapMode.Repeat};
        t.SetPixels(upperRight?new[]{low,low,low,high}:new[]{low,high,high,high});t.Apply(false,false);return t;
    }
    public static void Configure(ComparisonCapture value)
    {
        capture=value;var probe=UnityEngine.Object.FindFirstObjectByType<RuntimeAuditProbe>();Require(probe,"Probe missing");probe.enabled=false;
        foreach(var l in UnityEngine.Object.FindObjectsByType<Light>(FindObjectsInactive.Include,FindObjectsSortMode.None))l.enabled=false;
        var shader=Shader.Find("Universal Render Pipeline/Lit");Require(shader,"Stock Lit missing");
        var baseMap=Texture(new Color(.5f,.75f,.25f,1),new Color(.25f,.5f,.75f,1),false);
        var mask=Texture(new Color(.125f,.25f,.5f,.75f),new Color(.125f,.25f,.5f,.25f),false);
        var detail=Texture(new Color(.25f,.75f,.5f,1),new Color(.75f,.25f,.625f,1),true);
        for(int i=0;i<2;i++)
        {
            var g=GameObject.CreatePrimitive(PrimitiveType.Quad);g.name="Detail color "+i;g.transform.position=centers[i];g.transform.localScale=new Vector3(1,1.5f,1);
            var mesh=UnityEngine.Object.Instantiate(g.GetComponent<MeshFilter>().sharedMesh);mesh.uv=Enumerable.Repeat(new Vector2(.125f,.125f),mesh.vertexCount).ToArray();g.GetComponent<MeshFilter>().sharedMesh=mesh;
            var m=new Material(shader);materials[i]=m;m.SetColor("_BaseColor",new Color(.5f,.375f,.25f,1));m.SetFloat("_Metallic",0);m.SetFloat("_Smoothness",0);
            m.SetTexture("_BaseMap",baseMap);m.SetTextureScale("_BaseMap",new Vector2(2,3));m.SetTextureOffset("_BaseMap",new Vector2(.1f,.05f));
            m.SetTexture("_DetailMask",mask);m.SetTexture("_DetailAlbedoMap",detail);m.SetTextureScale("_DetailAlbedoMap",new Vector2(1.5f,.5f));m.SetTextureOffset("_DetailAlbedoMap",new Vector2(.2f,.3f));
            m.SetFloat("_DetailAlbedoMapScale",.5f);m.DisableKeyword("_DETAIL_MULX2");m.DisableKeyword("_DETAIL_SCALED");m.EnableKeyword(i==0?"_DETAIL_MULX2":"_DETAIL_SCALED");
            m.SetColor("_EmissionColor",new Color(.125f,.25f,.5f,1));m.EnableKeyword("_EMISSION");
            Require(m.shader==shader&&m.IsKeywordEnabled(i==0?"_DETAIL_MULX2":"_DETAIL_SCALED")&&!m.IsKeywordEnabled(i==0?"_DETAIL_SCALED":"_DETAIL_MULX2"),"Source detail variant not configured");
            g.GetComponent<Renderer>().sharedMaterial=m;g.AddComponent<HybridLumenGIProxy>().SetSources(g.GetComponent<Renderer>(),g.GetComponent<Collider>());
        }
        capture.totalFrames=64;capture.quitWhenComplete=true;capture.featureOff=false;capture.indirectOnly=false;capture.label="surface-detail-albedo-01";capture.feature.SetActive(true);
        settings=(HybridLumenGIRendererFeature.Settings)Field(capture.feature,"settings");settings.preferHardwareTracing=true;settings.exactSoftwareTracing=true;
        settings.composition=HybridLumenGIRendererFeature.CompositionMode.Additive;settings.bounceFeedback=0;settings.measureGpuCost=false;settings.adaptiveGpuBudget=false;
        capture.camera.transform.SetPositionAndRotation(new Vector3(100,0,-4),Quaternion.identity);capture.camera.nearClipPlane=.1f;capture.camera.farClipPlane=20;
        buffer=new GraphicsBuffer(GraphicsBuffer.Target.Structured,8,16);buffer.SetData(new Vector4[8]);
    }
    public static void Apply(ComparisonCapture value,int logical,string folder)
    {
        Require(value==capture&&!closed,"Unexpected fixture Apply");frame=logical;directory=folder;
        if(frame==32)settings.composition=HybridLumenGIRendererFeature.CompositionMode.ReplaceNativeDiffuseGI;
        if(failure!=null)throw new Exception(failure);
    }
    public static void Bind(CommandBuffer cmd,Camera camera,ComputeShader shader,int kernel,bool hardware,int width,int height)
    {
        if(!Enabled||camera!=capture.camera)return;
        cmd.SetComputeBufferParam(shader,kernel,"_SDA_Records",buffer);bool sample=frame==31||frame==63;cmd.SetComputeIntParam(shader,"_SDA_Enabled",sample?1:0);
        cmd.SetComputeVectorArrayParam(shader,"_SDA_Centers",centers.Select(p=>new Vector4(p.x,p.y,p.z,1)).ToArray());
        if(sample){Require(hardware,"Expected actual hardware backend");cmd.SetBufferData(buffer,new Vector4[8]);
            Json("binding-"+frame+".json",new Receipt{frame=frame,engine=Time.frameCount,width=width,height=height,hardware=hardware,native=frame>=32,
                mulKeyword=materials[0].IsKeywordEnabled("_DETAIL_MULX2"),scaledKeyword=materials[1].IsKeywordEnabled("_DETAIL_SCALED"),centers=centers,file="probe-"+frame+".bin"});}
    }
    public static void Read(CommandBuffer cmd,Camera camera)
    {
        if(!Enabled||camera!=capture.camera||(frame!=31&&frame!=63))return;int sampledFrame=frame;pending++;
        cmd.RequestAsyncReadback(buffer,r=>{try{Require(r.done&&!r.hasError,"Capture readback failed");var bytes=r.GetData<byte>().ToArray();Require(bytes.Length==128,"Capture size changed");
            File.WriteAllBytes(Path.Combine(directory,"probe-"+sampledFrame+".bin"),bytes);completed++;}catch(Exception e){Abort(e);}finally{pending--;}});
    }
    public static void Rendered(int logical){Require(logical==receipts&&logical==frame,"Missing frame receipt");receipts++;}
    public static void Abort(Exception e){failure=failure??e.ToString();}
    public static void Close()
    {
        if(closed)return;closed=true;if(pending>0)AsyncGPUReadback.WaitAllRequests();buffer?.Dispose();buffer=null;
        Json("detail-result.json",new Result{receipts=receipts,pending=pending,completed=completed,failure=failure});
        Require(receipts==64&&pending==0&&completed==2&&failure==null,"Finite detail capture incomplete: "+failure);
    }
}
