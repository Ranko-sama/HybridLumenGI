using System;
using System.IO;
using HybridLumenGI;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

// One ordinary source-switching exercise. No radiometric oracle or benchmark.
[DefaultExecutionOrder(20000)]
public sealed class SkinnedSampleUsage : MonoBehaviour
{
    public Camera cameraSource;
    public HybridLumenGIUnifiedSampleInteraction interaction;
    public HybridLumenGIRendererFeature feature;
    public HybridLumenGIValidationMotion door;
    public string output;
    [Serializable] sealed class Result
    {
        public string status="running",error,scope="One saved ordinary sample: real skin capture, settled source publication and return to readable mesh. Not full dynamic quality or performance.";
        public int requests,movingPublications,skinPublishedFrame=-1,meshPublishedFrame=-1;
        public float stoppedBendDegrees,maximumSettledVertexError;
        public bool trueSkinnedSource,oldSkinWithdrawn,authorMeshRestored;
        public string skinMeshName,skinPublicationPhase,meshPublicationPhase;
    }
    readonly Result result=new Result();
    HybridLumenGIProxy proxy;
    MeshRenderer originalRenderer;
    Mesh originalMesh,expectedSkin;
    SkinnedMeshRenderer skin;
    HybridLumenGIDeformedMesh deformation;
    Vector3[] lastMovingVertices;
    RenderTexture target;
    int stage,lastPublished=-1,originalCaptureRate;
    double began;
    bool ended,insideRequest;

    static void Require(bool value,string reason) { if(!value)throw new InvalidOperationException(reason); }
    void Start()
    {
        try
        {
            Require(cameraSource&&interaction&&feature&&door,"Missing saved sample references.");
            proxy=door.GetComponent<HybridLumenGIProxy>();originalRenderer=door.GetComponent<MeshRenderer>();
            originalMesh=door.GetComponent<MeshFilter>().sharedMesh;
            Require(proxy&&originalRenderer&&proxy.SourceRenderer==originalRenderer&&originalMesh,"Original door binding differs.");
            began=Time.realtimeSinceStartupAsDouble;originalCaptureRate=Time.captureFramerate;Time.captureFramerate=30;
            target=new RenderTexture(640,360,24,RenderTextureFormat.ARGBHalf,RenderTextureReadWrite.Linear){name="Skin usage final",antiAliasing=1};
            target.Create();cameraSource.enabled=false;cameraSource.targetTexture=target;cameraSource.aspect=640f/360;
            Save();
        }
        catch(Exception e){Finish(e.ToString());}
    }
    void Update()
    {
        if(ended||insideRequest)return;
        try
        {
            Require(result.requests<600&&Time.realtimeSinceStartupAsDouble-began<600,"Bounded usage window exhausted.");
            if(!RenderPipeline.SupportsRenderRequest(cameraSource,new RenderPipeline.StandardRequest{destination=target}))return;
            insideRequest=true;
            try { RenderPipeline.SubmitRenderRequest(cameraSource,new RenderPipeline.StandardRequest{destination=target}); }
            finally { insideRequest=false; }
            result.requests++;
            if(stage==0&&result.requests>=8)
            {
                interaction.SetSkinnedDeformation(true);interaction.SetDeformationRunning(true);
                skin=proxy.SourceRenderer as SkinnedMeshRenderer;deformation=door.GetComponent<HybridLumenGIDeformedMesh>();
                Require(skin&&skin.enabled&&!originalRenderer.enabled&&deformation,"Visible source did not switch to skin.");
                result.trueSkinnedSource=true;stage=1;
            }
            else if(stage==1)
            {
                if(deformation.PublishedFrame!=lastPublished&&HybridLumenGIDeformedMesh.HasSnapshot(skin))
                {
                    Mesh m=HybridLumenGIDeformedMesh.GetSourceMesh(skin);
                    Require(m.name=="HLGI baked deformation","Core did not publish its BakeMesh path.");
                    Vector3[] vertices=m.vertices;
                    if(lastMovingVertices!=null&&MaximumDifference(lastMovingVertices,vertices)>1e-5f)result.movingPublications++;
                    lastMovingVertices=vertices;lastPublished=deformation.PublishedFrame;
                }
                if(result.requests>=104)
                {
                    interaction.SetDeformationRunning(false);result.stoppedBendDegrees=interaction.BendDegrees;
                    Require(Mathf.Abs(result.stoppedBendDegrees)>1,"Stopped pose is too close to rest to exercise deformation.");
                    expectedSkin=new Mesh();skin.BakeMesh(expectedSkin,false);stage=2;
                }
            }
            else if(stage==2&&HybridLumenGIDeformedMesh.HasSnapshot(skin))
            {
                Mesh current=HybridLumenGIDeformedMesh.GetSourceMesh(skin);
                float difference=MaximumDifference(expectedSkin.vertices,current.vertices);
                if(difference<=1e-5f&&Published(out var publication))
                {
                    Require(result.movingPublications>0,"No changed skin snapshot was published during motion.");
                    result.maximumSettledVertexError=difference;result.skinPublishedFrame=deformation.PublishedFrame;
                    result.skinMeshName=current.name;result.skinPublicationPhase=publication.phase.ToString();
                    CaptureFinal();
                    interaction.SetSkinnedDeformation(false);
                    result.oldSkinWithdrawn=!HybridLumenGIDeformedMesh.HasSnapshot(skin);
                    Require(result.oldSkinWithdrawn&&!skin.enabled&&originalRenderer.enabled&&proxy.SourceRenderer==originalRenderer,"Skin source survived the return to mesh.");
                    stage=3;
                }
            }
            else if(stage==3&&HybridLumenGIDeformedMesh.HasSnapshot(originalRenderer)&&Published(out var meshPublication))
            {
                Mesh current=HybridLumenGIDeformedMesh.GetSourceMesh(originalRenderer);
                Require(current.name=="HLGI readable deformation","Readable mesh mode did not return.");
                if(MaximumDifference(door.GetComponent<MeshFilter>().sharedMesh.vertices,current.vertices)>1e-5f)return;
                result.meshPublishedFrame=deformation.PublishedFrame;result.meshPublicationPhase=meshPublication.phase.ToString();
                interaction.enabled=false;
                result.authorMeshRestored=proxy.SourceRenderer==originalRenderer&&door.GetComponent<MeshFilter>().sharedMesh==originalMesh&&originalRenderer.enabled;
                Require(result.authorMeshRestored&&!HybridLumenGIDeformedMesh.HasSnapshot(originalRenderer),"Close did not restore the authored source and withdraw its snapshot.");
                Finish(null);
            }
        }
        catch(Exception e){Finish(e.ToString());}
    }
    bool Published(out HybridLumenGIScene.PublicationSnapshot value)
    {
        return feature.TryGetPublication(cameraSource,proxy,out value)&&value.preparedEngineFrame==Time.frameCount&&
            value.phase==HybridLumenGIScene.PublicationPhase.Published;
    }
    static float MaximumDifference(Vector3[] a,Vector3[] b)
    {
        Require(a.Length==b.Length&&a.Length>0,"Vertex layout differs.");float maximum=0;
        for(int i=0;i<a.Length;i++)
        {
            Vector3 d=a[i]-b[i];float x=Mathf.Max(Mathf.Abs(d.x),Mathf.Abs(d.y),Mathf.Abs(d.z));
            Require(!float.IsNaN(x)&&!float.IsInfinity(x),"Nonfinite position difference.");maximum=Mathf.Max(maximum,x);
        }
        return maximum;
    }
    void CaptureFinal()
    {
        RenderTexture previous=RenderTexture.active;
        var read=new Texture2D(640,360,TextureFormat.RGBAFloat,false,true);
        var display=new Texture2D(640,360,TextureFormat.RGB24,false,true);
        try
        {
            RenderTexture.active=target;read.ReadPixels(new Rect(0,0,640,360),0,0);read.Apply();
            Color[] pixels=read.GetPixels();
            for(int i=0;i<pixels.Length;i++)
            {
                var c=pixels[i];c.r=Tone(c.r);c.g=Tone(c.g);c.b=Tone(c.b);c.a=1;pixels[i]=c;
            }
            display.SetPixels(pixels);display.Apply();File.WriteAllBytes(Path.Combine(output,"settled-skin-final.png"),display.EncodeToPNG());
        }
        finally { RenderTexture.active=previous;Destroy(read);Destroy(display); }
    }
    static float Tone(float value) { value=Mathf.Max(0,value);return Mathf.LinearToGammaSpace(value/(1+value)); }
    void Save(){File.WriteAllText(Path.Combine(output,"usage-result.json"),JsonUtility.ToJson(result,true));}
    void Finish(string error)
    {
        if(ended)return;ended=true;result.error=error;result.status=error==null?"passed":"failed";Save();
        if(error!=null)Debug.LogError(error);if(interaction)interaction.enabled=false;
        Time.captureFramerate=originalCaptureRate;if(cameraSource)cameraSource.targetTexture=null;
        if(expectedSkin)Destroy(expectedSkin);
        if(target){var owned=target;HybridLumenGIResourceRetirement.Retire(()=>{owned.Release();Destroy(owned);});target=null;}
#if UNITY_EDITOR
        UnityEditor.EditorApplication.isPlaying=false;
#endif
    }
}
