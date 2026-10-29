// Temporary finite-scene capture host. Raw transport is captured by the separate tap.
using System;
using System.Collections.Generic;
using System.IO;
using System.Reflection;
using HybridLumenGI;
using UnityEngine;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public sealed class FiniteWallReferenceScene : MonoBehaviour
{
    public Camera targetCamera;
    public HybridLumenGIRendererFeature feature;
    public MeshRenderer wall, floor;
    public Light sourceLight;
    public string outputDirectory;
    public const int Width=640,Height=360,MaximumFrames=180;
    public const double MaximumSeconds=180;
    RenderTexture target;
    RenderPipeline.StandardRequest request;
    StreamWriter frames;
    double started;
    bool finished,insideRequest,selectedFrameRendered;
    int lastRequestEngine=-1;
    string firstError;
    Vector3 cameraPosition;Quaternion cameraRotation;
    Result result;

    [Serializable] public sealed class Result
    {
        public string status="running",error,unity,api,gpu,pipeline,scene;
        public string renderPath="RenderPipeline.StandardRequest; disabled camera; one explicit request per engine Update";
        public string signal="CSTrace raw E/pi is in raw.rgba32f; final image is only an IndirectOnly preview";
        public bool cameraEnabled,cameraActive,cameraBase,targetCreated,renderRequestSupported,readbacksDrained;
        public int requests,cameraBegins,cameraEnds,contextBegins,contextEnds,targetWorkFrame=-1,previewCaptures;
        public int firstEngine=-1,lastEngine=-1;
        public double elapsedSeconds;
        public HybridLumenGIRendererFeature.CameraDiagnostics selectedDiagnostics;
    }
    [Serializable] sealed class Frame
    {public int engineFrame,request,cameraFrames;public double seconds;public bool ready;public HybridLumenGIRendererFeature.CameraDiagnostics diagnostics;}
    [Serializable] sealed class Source
    {
        public Vector3 cameraPosition;public Quaternion cameraRotation;
        public float cameraFieldOfView,cameraNear,cameraFar,cameraAspect;
        public SurfaceInput wall,floor;
        public LightInput light;
        public string colorSource="MaterialPropertyBlock.SetVector; no authoring-color conversion";
        public HybridLumenGIRendererFeature.Settings settings;
    }
    [Serializable] sealed class SurfaceInput
    {
        public string name,mesh,shader;public Matrix4x4 localToWorld;
        public Vector3[] vertices,normals;public int[] triangles;
        public Vector4 shaderLinearBaseColor;public Color materialBaseColor,materialEmission,proxyTint,proxyEmission;
        public float metallic,occlusionStrength,proxyEmissionIntensity;
        public bool normalMap,baseMap,emissionMap,occlusionMap,emissionKeyword,receiveShadows;
    }
    [Serializable] sealed class LightInput
    {public string type,shadows;public Color color;public float intensity;public Vector3 toLight;public bool enabled,useColorTemperature;}
    static SurfaceInput DescribeSurface(MeshRenderer renderer)
    {
        var mesh=renderer.GetComponent<MeshFilter>().sharedMesh;var material=renderer.sharedMaterial;var proxy=renderer.GetComponent<HybridLumenGIProxy>();
        var block=new MaterialPropertyBlock();renderer.GetPropertyBlock(block);
        return new SurfaceInput{name=renderer.name,mesh=mesh.name,shader=material.shader.name,localToWorld=renderer.localToWorldMatrix,
            vertices=mesh.vertices,normals=mesh.normals,triangles=mesh.triangles,shaderLinearBaseColor=block.GetVector("_BaseColor"),
            materialBaseColor=material.GetColor("_BaseColor"),materialEmission=material.GetColor("_EmissionColor"),proxyTint=proxy.AlbedoTint,proxyEmission=proxy.EmissionOverride,
            metallic=material.GetFloat("_Metallic"),occlusionStrength=material.GetFloat("_OcclusionStrength"),proxyEmissionIntensity=proxy.EmissionIntensity,
            normalMap=material.GetTexture("_BumpMap")!=null,baseMap=material.GetTexture("_BaseMap")!=null,emissionMap=material.GetTexture("_EmissionMap")!=null,occlusionMap=material.GetTexture("_OcclusionMap")!=null,
            emissionKeyword=material.IsKeywordEnabled("_EMISSION"),receiveShadows=renderer.receiveShadows};
    }
    static void Require(bool condition,string message){if(!condition)throw new InvalidOperationException(message);}
    static bool Finite(float v)=>!float.IsNaN(v)&&!float.IsInfinity(v);
    void Save(){if(result!=null)File.WriteAllText(Path.Combine(outputDirectory,"scene-result.json"),JsonUtility.ToJson(result,true));}
    void Start()
    {
        started=Time.realtimeSinceStartupAsDouble;
        try
        {
            Require(Path.IsPathRooted(outputDirectory)&&Directory.Exists(outputDirectory),"Prepared absolute output directory required");
            Require(!File.Exists(Path.Combine(outputDirectory,"scene-result.json")),"Scene output already exists");
            result=new Result{unity=Application.unityVersion,api=SystemInfo.graphicsDeviceType.ToString(),gpu=SystemInfo.graphicsDeviceName,scene=gameObject.scene.path};
            Save();
            Require(targetCamera&&feature&&wall&&floor&&sourceLight,"Prepared scene references missing");
            Require(SystemInfo.graphicsDeviceType==GraphicsDeviceType.Direct3D12&&QualitySettings.activeColorSpace==ColorSpace.Linear,"DX12 and Linear required");
            Require(FindObjectsByType<Renderer>(FindObjectsSortMode.None).Length==2&&FindObjectsByType<Light>(FindObjectsSortMode.None).Length==1,"Scene must contain exactly wall, floor and one light");
            Require(HybridLumenGIProxy.ActiveProxies.Count==2,"Scene must contain exactly two active proxies");
            targetCamera.enabled=false;
            var block=new MaterialPropertyBlock();block.SetVector("_BaseColor",new Vector4(.5f,.25f,.125f,1));wall.SetPropertyBlock(block);
            block.Clear();block.SetVector("_BaseColor",Vector4.one);floor.SetPropertyBlock(block);
            RenderSettings.ambientMode=AmbientMode.Flat;RenderSettings.ambientLight=Color.black;RenderSettings.ambientIntensity=0;
            RenderSettings.ambientProbe=new SphericalHarmonicsL2();RenderSettings.reflectionIntensity=0;RenderSettings.skybox=null;RenderSettings.fog=false;
            RenderSettings.sun=sourceLight;LightmapSettings.lightmaps=Array.Empty<LightmapData>();
            var settings=(HybridLumenGIRendererFeature.Settings)typeof(HybridLumenGIRendererFeature).GetField("settings",BindingFlags.NonPublic|BindingFlags.Instance).GetValue(feature);
            Require(settings.raysPerPixel==8&&settings.rayBias==.03f&&settings.traceDistance==20&&settings.screenSteps==0&&settings.bounceFeedback==0&&settings.guidedSamplingWeight==0&&settings.emissiveSamplingWeight==0&&settings.maxAreaEmitterTriangles==0&&settings.maxEmissiveProposals==0&&settings.environmentRadiance==Color.black&&settings.environmentCubemap==null&&settings.radianceClamp==0&&!settings.temporalAccumulation&&settings.filterIterations==0&&settings.preferHardwareTracing,"Frozen transport settings differ");
            cameraPosition=targetCamera.transform.position;cameraRotation=targetCamera.transform.rotation;
            File.WriteAllText(Path.Combine(outputDirectory,"scene-inputs.json"),JsonUtility.ToJson(new Source{cameraPosition=cameraPosition,cameraRotation=cameraRotation,
                cameraFieldOfView=targetCamera.fieldOfView,cameraNear=targetCamera.nearClipPlane,cameraFar=targetCamera.farClipPlane,cameraAspect=targetCamera.aspect,
                wall=DescribeSurface(wall),floor=DescribeSurface(floor),light=new LightInput{type=sourceLight.type.ToString(),shadows=sourceLight.shadows.ToString(),color=sourceLight.color,
                    intensity=sourceLight.intensity,toLight=-sourceLight.transform.forward,enabled=sourceLight.enabled,useColorTemperature=sourceLight.useColorTemperature},settings=settings},true));
            target=new RenderTexture(Width,Height,24,RenderTextureFormat.ARGBFloat,RenderTextureReadWrite.Linear){name="FiniteWallReferenceFinal",antiAliasing=1,useMipMap=false,autoGenerateMips=false,useDynamicScale=false};
            Require(target.Create()&&target.graphicsFormat==GraphicsFormat.R32G32B32A32_SFloat,"Final target creation/format failed");
            targetCamera.targetTexture=target;
            request=new RenderPipeline.StandardRequest{destination=target,mipLevel=0,slice=0,face=CubemapFace.Unknown};
            FiniteWallReferenceTap.Reset(targetCamera,outputDirectory);
            frames=new StreamWriter(new FileStream(Path.Combine(outputDirectory,"frames.jsonl"),FileMode.CreateNew,FileAccess.Write,FileShare.Read));
            Application.runInBackground=true;Application.logMessageReceived+=OnLog;
            RenderPipelineManager.beginContextRendering+=ContextBegan;RenderPipelineManager.endContextRendering+=ContextEnded;
            RenderPipelineManager.beginCameraRendering+=CameraBegan;RenderPipelineManager.endCameraRendering+=CameraEnded;
            Save();
        }
        catch(Exception error){firstError=error.ToString();Finish(false);}
    }
    void OnLog(string message,string stack,LogType type)
    {if(type==LogType.Error||type==LogType.Exception||type==LogType.Assert)firstError=firstError??message+"\n"+stack;}
    void ContextBegan(ScriptableRenderContext context,List<Camera> cameras){if(cameras.Contains(targetCamera))result.contextBegins++;}
    void ContextEnded(ScriptableRenderContext context,List<Camera> cameras){if(cameras.Contains(targetCamera))result.contextEnds++;}
    void CameraBegan(ScriptableRenderContext context,Camera camera)
    {if(camera!=targetCamera)return;result.cameraBegins++;if(!insideRequest)firstError=firstError??"Unrequested automatic camera render";}
    static bool Ready(HybridLumenGIRendererFeature.CameraDiagnostics d)
    {
        return d!=null&&d.hardwareBackend&&d.hardwareMeshes==2&&d.hardwareFallbacks==0&&d.hardwareMaterialUnknownRecords==0&&
            d.hardwareMaterialStatus=="Uploads and both consumers bound; GPU completion unproven"&&d.publishedInstances==2&&d.warmingInstances==0&&d.pendingCapacity==0&&
            d.chartedOwners==2&&d.approximateOwners==0&&d.readyCards>=2&&d.pendingCards==0&&d.lightSelected==1&&d.lightCapacityOmitted==0;
    }
    void CameraEnded(ScriptableRenderContext context,Camera camera)
    {
        if(camera!=targetCamera||finished)return;
        try
        {
            result.cameraEnds++;result.lastEngine=Time.frameCount;if(result.firstEngine<0)result.firstEngine=Time.frameCount;
            Require(insideRequest&&result.cameraEnds==result.requests,"Duplicate or unrequested camera receipt");
            HybridLumenGIRendererFeature.CameraDiagnostics diagnostic=null;
            foreach(var candidate in feature.GetDiagnostics())if(candidate.camera==targetCamera.name){Require(diagnostic==null,"Ambiguous diagnostics");diagnostic=candidate;}
            bool ready=Ready(diagnostic);
            frames.WriteLine(JsonUtility.ToJson(new Frame{engineFrame=Time.frameCount,request=result.requests,cameraFrames=result.cameraEnds,seconds=Time.realtimeSinceStartupAsDouble-started,ready=ready,diagnostics=diagnostic}));frames.Flush();
            if(FiniteWallReferenceTap.TargetWorkFrame<0&&ready)
            {
                // RecordRenderGraph increments state.frame after copying it to Work.frame.
                // This post-render diagnostic therefore selects exactly the next render's Work.frame.
                Require(result.cameraEnds<MaximumFrames,"No frame remains after readiness");
                FiniteWallReferenceTap.TargetWorkFrame=diagnostic.frame;result.targetWorkFrame=diagnostic.frame;
            }
            else if(FiniteWallReferenceTap.TargetWorkFrame>=0)
            {
                Require(ready&&diagnostic.frame==FiniteWallReferenceTap.TargetWorkFrame+1,"Selected frame lost readiness or work-frame correspondence");
                result.selectedDiagnostics=diagnostic;selectedFrameRendered=true;
            }
        }
        catch(Exception error){firstError=firstError??error.ToString();}
    }
    void Update()
    {
        if(finished||result==null)return;
        try
        {
            Require(firstError==null,firstError);
            Require(string.IsNullOrEmpty(FiniteWallReferenceTap.Failure),FiniteWallReferenceTap.Failure);
            Require(Time.realtimeSinceStartupAsDouble-started<=MaximumSeconds,"180 second capture deadline exceeded");
            if(selectedFrameRendered)
            {
                if(result.previewCaptures==0)CapturePreview();
                if(FiniteWallReferenceTap.Completed)Finish(true);
                return;
            }
            Require(result.cameraEnds<MaximumFrames,"180 render-frame readiness deadline exceeded");
            Require(!targetCamera.enabled&&targetCamera.gameObject.activeInHierarchy&&targetCamera.transform.position==cameraPosition&&targetCamera.transform.rotation==cameraRotation&&feature.isActive,"Frozen camera/feature changed");
            result.pipeline=RenderPipelineManager.currentPipeline?.GetType().FullName??"null";
            result.cameraEnabled=targetCamera.enabled;result.cameraActive=targetCamera.gameObject.activeInHierarchy;
            result.cameraBase=targetCamera.GetUniversalAdditionalCameraData().renderType==CameraRenderType.Base;result.targetCreated=target.IsCreated();
            result.renderRequestSupported=RenderPipeline.SupportsRenderRequest(targetCamera,request);Save();
            if(!result.renderRequestSupported)return;
            Require(lastRequestEngine!=Time.frameCount,"More than one request in an engine frame");lastRequestEngine=Time.frameCount;
            result.requests++;insideRequest=true;
            try{RenderPipeline.SubmitRenderRequest(targetCamera,request);}finally{insideRequest=false;}
            Require(result.cameraEnds==result.requests&&result.cameraBegins==result.requests&&result.contextBegins==result.requests&&result.contextEnds==result.requests,"Explicit render request did not produce one complete camera/context receipt");
        }
        catch(Exception error){firstError=firstError??error.ToString();Finish(false);}
    }
    void CapturePreview()
    {
        var read=AsyncGPUReadback.Request(target,0,TextureFormat.RGBAFloat);read.WaitForCompletion();
        Require(read.done&&!read.hasError,"Final preview readback failed");var values=read.GetData<float>();Require(values.Length==Width*Height*4,"Final preview shape mismatch");
        byte[] preview=new byte[Width*Height*4];
        for(int i=0;i<values.Length;i++){Require(Finite(values[i]),"Nonfinite final preview");float positive=Mathf.Max(0,values[i]);preview[i]=(i%4==3)?(byte)255:(byte)Mathf.RoundToInt(Mathf.Clamp01(Mathf.LinearToGammaSpace(positive/(1+positive)))*255);}
        byte[] raw=read.GetData<byte>().ToArray();
        File.WriteAllBytes(Path.Combine(outputDirectory,"final.rgba32f"),raw);
        File.WriteAllBytes(Path.Combine(outputDirectory,"final.exr"),ImageConversion.EncodeArrayToEXR(raw,GraphicsFormat.R32G32B32A32_SFloat,Width,Height,Width*16,Texture2D.EXRFlags.OutputAsFloat));
        File.WriteAllBytes(Path.Combine(outputDirectory,"final-preview.png"),ImageConversion.EncodeArrayToPNG(preview,GraphicsFormat.R8G8B8A8_UNorm,Width,Height,Width*4));
        result.previewCaptures++;
    }
    void Cleanup()
    {
        RenderPipelineManager.beginContextRendering-=ContextBegan;RenderPipelineManager.endContextRendering-=ContextEnded;
        RenderPipelineManager.beginCameraRendering-=CameraBegan;RenderPipelineManager.endCameraRendering-=CameraEnded;Application.logMessageReceived-=OnLog;
        try{AsyncGPUReadback.WaitAllRequests();FiniteWallReferenceTap.Dispose();if(result!=null)result.readbacksDrained=true;}
        finally
        {
            frames?.Dispose();frames=null;
            if(targetCamera){targetCamera.enabled=false;targetCamera.targetTexture=null;}
            if(target){target.Release();Destroy(target);target=null;}
        }
    }
    void Finish(bool completed)
    {
        if(finished)return;finished=true;
        try{Cleanup();}catch(Exception error){firstError=firstError??error.ToString();}
        if(result!=null){result.elapsedSeconds=Time.realtimeSinceStartupAsDouble-started;result.error=firstError;result.status=completed&&firstError==null&&FiniteWallReferenceTap.Completed&&result.previewCaptures==1?"collected":"failed";Save();Debug.Log("FINITE_WALL_REFERENCE_RESULT "+JsonUtility.ToJson(result));}
#if UNITY_EDITOR
        UnityEditor.EditorApplication.isPlaying=false;
#else
        Application.Quit(result!=null&&result.status=="collected"?0:1);
#endif
    }
    void OnDestroy(){if(!finished){firstError=firstError??"Scene destroyed before completion";Finish(false);}}
}
