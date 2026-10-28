// Test build only: one fixed light/occluder, two source material keywords,
// ordinary then native capture in one 64-frame process. No image/timing oracle.
using System;
using System.IO;
using System.Linq;
using System.Reflection;
using UnityEngine;
using UnityEngine.Rendering;
using HybridLumenGI;
public static class ScreenReceiveShadowsMode
{
    public static bool Enabled=>Array.IndexOf(Environment.GetCommandLineArgs(),"-screenReceiveShadows")>=0;
    static ComparisonCapture capture;static HybridLumenGIRendererFeature.Settings settings;
    static GraphicsBuffer buffer;static int frame,receipts,pending,completed;static string directory,failure;static bool closed;
    static readonly Vector3[] centers={new Vector3(99.4f,0,0),new Vector3(100.6f,0,0)};
    static Material[] materials=new Material[2];
    const BindingFlags Fields=BindingFlags.Instance|BindingFlags.NonPublic|BindingFlags.Public;
    static object Field(object o,string n)=>o.GetType().GetField(n,Fields).GetValue(o);
    static void Require(bool value,string message){if(!value)throw new Exception(message);}
    [Serializable] class Receipt{public int frame,engine,width,height;public bool hardware,native,onKeyword,offKeyword;public string file;public Vector3[] centers;}
    [Serializable] class Result{public int receipts,pending,completed;public string failure;}
    static void Json(string name,object o)=>File.WriteAllText(Path.Combine(directory,name),JsonUtility.ToJson(o,true));
    public static void Configure(ComparisonCapture value)
    {
        capture=value;var probe=UnityEngine.Object.FindFirstObjectByType<RuntimeAuditProbe>();Require(probe,"Probe missing");probe.enabled=false;
        foreach(var l in UnityEngine.Object.FindObjectsByType<Light>(FindObjectsInactive.Include,FindObjectsSortMode.None))l.enabled=false;
        var shader=Shader.Find("Universal Render Pipeline/Lit");Require(shader,"Stock Lit missing");
        for(int i=0;i<2;i++)
        {
            var g=GameObject.CreatePrimitive(PrimitiveType.Quad);g.name="Shadow policy "+i;g.transform.position=centers[i];g.transform.localScale=new Vector3(1,1.5f,1);
            var m=new Material(shader);materials[i]=m;m.SetColor("_BaseColor",new Color(.5f,.5f,.5f,1));m.SetFloat("_Metallic",0);m.SetFloat("_Smoothness",0);
            m.SetFloat("_ReceiveShadows",i==0?1:0);if(i==1)m.EnableKeyword("_RECEIVE_SHADOWS_OFF");else m.DisableKeyword("_RECEIVE_SHADOWS_OFF");
            m.SetColor("_EmissionColor",new Color(0,1,0,1));m.EnableKeyword("_EMISSION");
            g.GetComponent<Renderer>().sharedMaterial=m;g.AddComponent<HybridLumenGIProxy>().SetSources(g.GetComponent<Renderer>(),g.GetComponent<Collider>());
        }
        var blocker=GameObject.CreatePrimitive(PrimitiveType.Cube);blocker.name="Single shadow connection blocker";
        var blockerMaterial=new Material(shader);blockerMaterial.SetFloat("_Surface",0);blockerMaterial.SetFloat("_AlphaClip",0);
        blockerMaterial.DisableKeyword("_SURFACE_TYPE_TRANSPARENT");blockerMaterial.DisableKeyword("_ALPHATEST_ON");blockerMaterial.DisableKeyword("_EMISSION");
        blockerMaterial.SetColor("_EmissionColor",Color.black);blockerMaterial.renderQueue=2000;
        var blockerRenderer=blocker.GetComponent<Renderer>();blockerRenderer.sharedMaterial=blockerMaterial;
        Require(blockerRenderer.sharedMaterial==blockerMaterial && blockerMaterial.shader==shader &&
            blockerMaterial.GetFloat("_Surface")==0 && blockerMaterial.GetFloat("_AlphaClip")==0 &&
            !blockerMaterial.IsKeywordEnabled("_SURFACE_TYPE_TRANSPARENT") && !blockerMaterial.IsKeywordEnabled("_ALPHATEST_ON") &&
            !blockerMaterial.IsKeywordEnabled("_EMISSION") && blockerMaterial.GetColor("_EmissionColor")==Color.black && blockerMaterial.renderQueue==2000,
            "Blocker must be explicitly assigned opaque, non-clipped, non-emissive stock Lit");
        blocker.transform.position=new Vector3(102,0,-1);blocker.transform.localScale=new Vector3(1.4f,2,.2f);blocker.AddComponent<HybridLumenGIProxy>().SetSources(blocker.GetComponent<Renderer>(),blocker.GetComponent<Collider>());
        var light=new GameObject("Single policy light").AddComponent<Light>();light.type=LightType.Point;light.range=10;light.intensity=5;light.color=Color.white;
        light.shadows=LightShadows.Hard;light.shadowStrength=1;light.transform.position=new Vector3(104,0,-2);capture.lights=new[]{light};
        capture.totalFrames=64;capture.quitWhenComplete=true;capture.featureOff=false;capture.indirectOnly=false;capture.label="screen-receive-shadows-01";capture.feature.SetActive(true);
        settings=(HybridLumenGIRendererFeature.Settings)Field(capture.feature,"settings");settings.preferHardwareTracing=true;settings.exactSoftwareTracing=true;
        settings.composition=HybridLumenGIRendererFeature.CompositionMode.Additive;settings.bounceFeedback=0;settings.measureGpuCost=false;settings.adaptiveGpuBudget=false;
        settings.screenSteps=32;settings.screenThickness=.2f;settings.maxLights=1;settings.spatialLightSelection=false;
        capture.camera.transform.SetPositionAndRotation(new Vector3(100,0,-4),Quaternion.identity);capture.camera.nearClipPlane=.1f;capture.camera.farClipPlane=20;
        buffer=new GraphicsBuffer(GraphicsBuffer.Target.Structured,32,16);buffer.SetData(new Vector4[32]);
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
        cmd.SetComputeBufferParam(shader,kernel,"_SSR_Records",buffer);
        bool sample=frame==31||frame==63;cmd.SetComputeIntParam(shader,"_SSR_Enabled",sample?1:0);
        cmd.SetComputeVectorArrayParam(shader,"_SSR_Centers",centers.Select(p=>new Vector4(p.x,p.y,p.z,1)).ToArray());
        if(sample){Require(hardware,"Native proof requires actual hardware backend");cmd.SetBufferData(buffer,new Vector4[32]);
            Json("binding-"+frame+".json",new Receipt{frame=frame,engine=Time.frameCount,width=width,height=height,hardware=hardware,native=frame>=32,
                onKeyword=materials[0].IsKeywordEnabled("_RECEIVE_SHADOWS_OFF"),offKeyword=materials[1].IsKeywordEnabled("_RECEIVE_SHADOWS_OFF"),centers=centers,file="probe-"+frame+".bin"});}
    }
    public static void Read(CommandBuffer cmd,Camera camera)
    {
        if(!Enabled||camera!=capture.camera||(frame!=31&&frame!=63))return;int sampledFrame=frame;pending++;
        cmd.RequestAsyncReadback(buffer,r=>{try{Require(r.done&&!r.hasError,"Probe readback failed");var bytes=r.GetData<byte>().ToArray();Require(bytes.Length==512,"Probe size changed");
            File.WriteAllBytes(Path.Combine(directory,"probe-"+sampledFrame+".bin"),bytes);completed++;}catch(Exception e){Abort(e);}finally{pending--;}});
    }
    public static void Rendered(int logical){Require(logical==receipts&&logical==frame,"Missing frame receipt");receipts++;}
    public static void Abort(Exception e){failure=failure??e.ToString();}
    public static void Close()
    {
        if(closed)return;closed=true;if(pending>0)AsyncGPUReadback.WaitAllRequests();buffer?.Dispose();buffer=null;
        Json("shadow-result.json",new Result{receipts=receipts,pending=pending,completed=completed,failure=failure});
        Require(receipts==64&&pending==0&&completed==2&&failure==null,"Finite shadow capture incomplete: "+failure);
    }
}
