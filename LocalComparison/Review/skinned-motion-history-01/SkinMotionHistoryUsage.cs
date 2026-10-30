using System;
using System.Collections.Generic;
using System.IO;
using System.Reflection;
using HybridLumenGI;
using UnityEngine;
using UnityEngine.Rendering;

// A fixed ordinary-use sequence, not the 720-frame validation protocol.
[DefaultExecutionOrder(20000)]
public sealed class SkinMotionHistoryUsage : MonoBehaviour
{
    public Camera cameraSource;
    public HybridLumenGIUnifiedSampleInteraction interaction;
    public HybridLumenGIUnifiedSample sample;
    public HybridLumenGIRendererFeature feature;
    public HybridLumenGIValidationMotion door;
    public string output;
    public int configuredRays,configuredFilter;
    public bool motionEnabled;
    [Serializable] public sealed class Event
    {public string action;public int afterLogicalFrame,engineFrame;public float bendDegrees;}
    [Serializable] public sealed class Observation
    {public int logicalFrame,engineFrame;public HybridLumenGIRendererFeature.CameraDiagnostics diagnostics;}
    [Serializable] public sealed class PoseFrame
    {public int logicalFrame,engineFrame;public float bendDegrees;public bool deformationRunning,skinnedSource;}
    [Serializable] public sealed class Result
    {
        public string status="running",error;
        public string scope="240 ordinary 640x360 A/B render requests with saved ordinary Lit materials and standard URP skeletal motion; native skin identity/moments and three Final images. Tap pass is not motion quality adoption, radiometric accuracy, performance, cleanup acceptance or general deformation reprojection.";
        public int requests,beginCallbacks,endCallbacks,raysPerPixel,filterIterations;
        public bool motionEnabled,requestedDXR,measureCost,feedback,readbacksDrained,sampleMotionVectorsPassPresent,sampleMotionVectorsPassEnabled;
        public string[] sampleMotionMaterials;
        public float stoppedBendDegrees;
        public List<Event> events=new List<Event>();
        public List<Observation> observations=new List<Observation>();
        public List<PoseFrame> trajectory=new List<PoseFrame>();
    }
    readonly Result result=new Result();
    HybridLumenGIProxy proxy;
    MeshRenderer originalRenderer;
    SkinnedMeshRenderer skin;
    RenderTexture target,originalTarget;
    float originalAspect;
    int originalCaptureRate,requestBegins,requestEnds;
    double began;
    bool ended,insideRequest,subscribed,savedState;
    string callbackError;
    static void Require(bool value,string reason){if(!value)throw new InvalidOperationException(reason);}
    void Start()
    {
        began=Time.realtimeSinceStartupAsDouble;
        try
        {
            Require(cameraSource&&interaction&&sample&&feature&&door,"Missing saved sample references.");
            Require(Directory.Exists(output)&&!File.Exists(Path.Combine(output,"usage-result.json")),"Fresh output directory required.");
            proxy=door.GetComponent<HybridLumenGIProxy>();originalRenderer=door.GetComponent<MeshRenderer>();
            Require(proxy&&originalRenderer&&proxy.SourceRenderer==originalRenderer,"Original door binding differs.");
            Require(ReadMotionSetting()==motionEnabled,"Actual feature skinnedMotionHistory differs from requested A/B side.");
            Require(originalRenderer.motionVectorGenerationMode==MotionVectorGenerationMode.Object,"Original sample door must use Object motion vectors.");
            Material[] materials=originalRenderer.sharedMaterials;Require(materials.Length>0,"Original sample material slots are empty.");
            result.sampleMotionMaterials=new string[materials.Length];
            for(int i=0;i<materials.Length;i++)
            {
                Require(materials[i],"Sample material is missing.");
                result.sampleMotionMaterials[i]=materials[i].name;
            }
            result.motionEnabled=motionEnabled;
            Require(configuredRays==2&&configuredFilter==4&&feature.RequestedPreferHardwareTracing&&!feature.RequestedMeasureGpuCost&&!feature.RequestedAdaptiveGpuBudget,"Expected 2ray/filter4/requested-DXR with timing/feedback off.");
            result.raysPerPixel=configuredRays;result.filterIterations=configuredFilter;result.requestedDXR=feature.RequestedPreferHardwareTracing;
            result.measureCost=feature.RequestedMeasureGpuCost;result.feedback=feature.RequestedAdaptiveGpuBudget;
            originalCaptureRate=Time.captureFramerate;originalTarget=cameraSource.targetTexture;originalAspect=cameraSource.aspect;savedState=true;
            Time.captureFramerate=30;Application.runInBackground=true;sample.ShowControls=false;sample.MeasureVideoMemory=false;
            interaction.SetDoorMoving(false);interaction.SetDeformationRunning(false);door.ApplyFrame(0);
            target=new RenderTexture(640,360,24,RenderTextureFormat.ARGBHalf,RenderTextureReadWrite.Linear){name="Skin motion A-B ordinary Final",antiAliasing=1};
            Require(target.Create(),"Target allocation failed.");cameraSource.enabled=false;cameraSource.targetTexture=target;cameraSource.aspect=640f/360f;
            SkinMotionHistoryTap.Configure(output,cameraSource,motionEnabled);
            RenderPipelineManager.beginCameraRendering+=BeginCamera;RenderPipelineManager.endCameraRendering+=EndCamera;subscribed=true;
            Save();
        }
        catch(Exception e){Finish(e.ToString());}
    }
    void BeginCamera(ScriptableRenderContext context,Camera camera)
    {
        if(camera!=cameraSource)return;
        result.beginCallbacks++;requestBegins++;
        if(!insideRequest)callbackError="Target camera rendered outside the one explicit request.";
    }
    void EndCamera(ScriptableRenderContext context,Camera camera)
    {
        if(camera!=cameraSource)return;
        result.endCallbacks++;requestEnds++;
        if(!insideRequest)callbackError="Target camera ended outside the one explicit request.";
    }
    void Update()
    {
        if(ended||insideRequest)return;
        try
        {
            Require(Time.realtimeSinceStartupAsDouble-began<600,"600-second driver deadline exceeded.");
            Require(SkinMotionHistoryTap.Failure==null,SkinMotionHistoryTap.Failure??"Tap failed.");
            Require(result.requests<240,"Request bound exceeded.");
            // This also initializes currentPipeline; do not short-circuit on currentPipeline==null.
            if(!RenderPipeline.SupportsRenderRequest(cameraSource,new RenderPipeline.StandardRequest{destination=target}))return;
            if(result.requests==0)
            {
                result.sampleMotionVectorsPassEnabled=true;
                foreach(var material in originalRenderer.sharedMaterials)
                {
                    Require(material&&material.FindPass("MotionVectors")>=0,"Initialized URP must expose the ordinary Lit MotionVectors pass.");
                    result.sampleMotionVectorsPassEnabled&=material.GetShaderPassEnabled("MotionVectors");
                }
                result.sampleMotionVectorsPassPresent=true;
            }
            int logical=result.requests;requestBegins=requestEnds=0;
            Require(ReadMotionSetting()==motionEnabled,"A/B motion setting changed during the fixed sequence.");
            if(skin)Require(skin.skinnedMotionVectors&&skin.motionVectorGenerationMode==MotionVectorGenerationMode.Object,"Ordinary skin motion-vector settings changed.");
            result.trajectory.Add(new PoseFrame{logicalFrame=logical,engineFrame=Time.frameCount,bendDegrees=interaction.BendDegrees,
                deformationRunning=interaction.DeformationRunning,skinnedSource=skin!=null});
            SkinMotionHistoryTap.Arm(logical,skin,interaction.BendDegrees,interaction.DeformationRunning);
            insideRequest=true;
            try{RenderPipeline.SubmitRenderRequest(cameraSource,new RenderPipeline.StandardRequest{destination=target});}
            finally{insideRequest=false;SkinMotionHistoryTap.Disarm();}
            result.requests++;
            Require(callbackError==null&&requestBegins==1&&requestEnds==1,callbackError??"The explicit request did not produce exactly one begin/end camera pair.");
            if(Array.IndexOf(SkinMotionHistoryTap.Samples,logical)>=0)
            {
                HybridLumenGIRendererFeature.CameraDiagnostics found=null;
                foreach(var value in feature.GetDiagnostics())if(value.camera==cameraSource.name){Require(found==null,"Ambiguous camera diagnostics.");found=value;}
                Require(found!=null&&found.hardwareBackend,"Selected A/B request did not use the actual DXR backend.");
                result.observations.Add(new Observation{logicalFrame=logical,engineFrame=Time.frameCount,diagnostics=found});
            }
            if(logical==127||logical==128||logical==159)CaptureFinal(logical);
            if(logical==7)
            {
                interaction.SetSkinnedDeformation(true);interaction.SetDeformationRunning(false);
                skin=proxy.SourceRenderer as SkinnedMeshRenderer;
                Require(skin&&skin.enabled&&!originalRenderer.enabled,"Source did not switch from MeshRenderer to actual SkinnedMeshRenderer.");
                Require(skin.skinnedMotionVectors&&skin.motionVectorGenerationMode==MotionVectorGenerationMode.Object,"Actual sample Skin must use skinned motion vectors and Object mode.");
                foreach(var material in skin.sharedMaterials)
                {
                    Require(material&&material.FindPass("MotionVectors")>=0,"Actual Skin material lacks the ordinary Lit MotionVectors pass.");
                    result.sampleMotionVectorsPassEnabled&=material.GetShaderPassEnabled("MotionVectors");
                }
                AddEvent("switch-to-skin-stopped",logical);
            }
            if(logical==119){interaction.SetDeformationRunning(true);Require(interaction.DeformationRunning,"Motion did not start.");AddEvent("start-deformation",logical);}
            if(logical==127)
            {
                interaction.SetDeformationRunning(false);result.stoppedBendDegrees=interaction.BendDegrees;
                Require(!interaction.DeformationRunning&&!float.IsNaN(result.stoppedBendDegrees)&&!float.IsInfinity(result.stoppedBendDegrees)&&result.stoppedBendDegrees!=0,"Stopped skin pose must be finite and nonzero.");
                AddEvent("stop-deformation",logical);
            }
            if(logical>127)Require(!interaction.DeformationRunning&&interaction.BendDegrees==result.stoppedBendDegrees,"Stopped pose changed after the fixed stop event.");
            if(result.requests==240)Finish(null);
        }
        catch(Exception e){Finish(e.ToString());}
    }
    void AddEvent(string action,int logical)
    {result.events.Add(new Event{action=action,afterLogicalFrame=logical,engineFrame=Time.frameCount,bendDegrees=interaction.BendDegrees});}
    bool ReadMotionSetting()
    {
        var field=typeof(HybridLumenGIRendererFeature).GetField("settings",BindingFlags.Instance|BindingFlags.NonPublic);
        Require(field!=null,"Feature settings field is unavailable.");
        var settings=field.GetValue(feature) as HybridLumenGIRendererFeature.Settings;
        Require(settings!=null,"Feature settings are unavailable.");return settings.skinnedMotionHistory;
    }
    void CaptureFinal(int logical)
    {
        string file=Path.Combine(output,"frame-"+logical.ToString("D3")+"-final.png");Require(!File.Exists(file),"Preserve existing Final image.");
        RenderTexture previous=RenderTexture.active;var read=new Texture2D(640,360,TextureFormat.RGBAFloat,false,true);var display=new Texture2D(640,360,TextureFormat.RGB24,false,true);
        try
        {
            RenderTexture.active=target;read.ReadPixels(new Rect(0,0,640,360),0,0);read.Apply();Color[] pixels=read.GetPixels();
            for(int i=0;i<pixels.Length;i++){var c=pixels[i];pixels[i]=new Color(Tone(c.r),Tone(c.g),Tone(c.b),1);}
            display.SetPixels(pixels);display.Apply();File.WriteAllBytes(file,display.EncodeToPNG());
        }
        finally{RenderTexture.active=previous;Destroy(read);Destroy(display);}
    }
    static float Tone(float value){value=Mathf.Max(0,value);return Mathf.LinearToGammaSpace(value/(1+value));}
    void Save(){File.WriteAllText(Path.Combine(output,"usage-result.json"),JsonUtility.ToJson(result,true));}
    void Finish(string error)
    {
        if(ended)return;ended=true;
        if(subscribed){RenderPipelineManager.beginCameraRendering-=BeginCamera;RenderPipelineManager.endCameraRendering-=EndCamera;subscribed=false;}
        try
        {
            var analysis=SkinMotionHistoryTap.DrainAndAnalyze();result.readbacksDrained=analysis.pending==0;
            if(error==null&&analysis.status!="passed")error=analysis.error;
            if(error==null&&result.requests!=240)error="Did not complete exactly 240 requests.";
            if(error==null&&result.trajectory.Count!=240)error="Did not retain the actual bend for every request.";
        }
        catch(Exception e){error=error==null?e.ToString():error+"\nDrain: "+e;}
        try
        {
            if(interaction)interaction.enabled=false;
            if(savedState){Time.captureFramerate=originalCaptureRate;if(cameraSource){cameraSource.targetTexture=originalTarget;cameraSource.aspect=originalAspect;}}
            if(target){var owned=target;HybridLumenGIResourceRetirement.Retire(()=>{owned.Release();Destroy(owned);});target=null;}
        }
        catch(Exception e){error=error==null?e.ToString():error+"\nCleanup: "+e;}
        result.error=error;result.status=error==null?"passed":"failed";
        try{Save();}catch(Exception e){Debug.LogError(e);}
        if(error!=null)Debug.LogError(error);
#if UNITY_EDITOR
        UnityEditor.EditorApplication.isPlaying=false;
#else
        Application.Quit(error==null?0:1);
#endif
    }
}
