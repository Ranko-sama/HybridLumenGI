// Finite use of the same ordinary example. Only public CPU state and two existing image captures.
using System;
using System.IO;
using System.Linq;
using System.Reflection;
using HybridLumenGI;
using UnityEngine;
using UnityEngine.Rendering;

public sealed class ContinuousDeformationRun : MonoBehaviour
{
    ComparisonCapture capture;HybridLumenGIRendererFeature feature;ContinuousDeformationExample sample;ContinuousDeformationCheck check;
    string folder,firstError,lightState;int frames,lastEngine=-1,startEngine,errors,captures;bool finished,quitPending;
    double started;Vector3 position,door;Quaternion rotation;Matrix4x4 objectMatrix;
    [Serializable] sealed class Result
    {
        public string status="running",error,scene,api,gpu,environmentCubeName,view,composition;
        public string imageScope="Final linear HDR target, motion-ending and settled same visible pose; not ordinary backbuffer or per-ray consumption proof";
        public bool debugBuild,testCaptureDisabled,auditProbeDisabled,normalQuitObserved,sourceClosed;
        public int requestedFrames=256,actualCameraFrames,captures,errors,firstEngine=-1,lastEngine=-1;
        public double firstRenderWaitSeconds;
    }
    Result result;
    static void Require(bool value,string message){if(!value)throw new Exception(message);}
    static string Arg(string name){var args=Environment.GetCommandLineArgs();int i=Array.IndexOf(args,name);return i>=0&&i+1<args.Length?args[i+1]:null;}
    public static void Begin(ComparisonCapture capture,HybridLumenGIRendererFeature feature)
    {
        var mode=capture.gameObject.AddComponent<ContinuousDeformationRun>();mode.capture=capture;mode.feature=feature;
        try{mode.Initialize();}catch{mode.Cleanup();throw;}
    }
    string Lights()=>string.Join("\n",capture.lights.Select(l=>JsonUtility.ToJson(new Lamp(l))));
    [Serializable] sealed class Lamp
    {
        public int id,type;public bool enabled;public float intensity,range,spot;public Color color;public Vector3 position;public Quaternion rotation;
        public Lamp(Light l){id=l.GetInstanceID();type=(int)l.type;enabled=l.enabled;intensity=l.intensity;range=l.range;spot=l.spotAngle;color=l.color;position=l.transform.position;rotation=l.transform.rotation;}
    }
    void Initialize()
    {
        started=Time.realtimeSinceStartupAsDouble;startEngine=Time.frameCount;
        folder=Arg("-localReleaseOutput");Require(!string.IsNullOrEmpty(folder)&&Path.IsPathRooted(folder)&&!Directory.Exists(folder),"New absolute output required");Directory.CreateDirectory(folder);
        var settings=(HybridLumenGIRendererFeature.Settings)typeof(HybridLumenGIRendererFeature).GetField("settings",BindingFlags.Instance|BindingFlags.NonPublic).GetValue(feature);
        var cube=settings.environmentCubemap;
        Require(cube&&cube.name=="CurrentRelease67Environment"&&HybridLumenGIRendererFeature.IsSupportedEnvironmentCubemap(cube)&&cube.format==TextureFormat.RGBAFloat&&cube.width==2&&cube.mipmapCount==1&&cube.filterMode==FilterMode.Bilinear&&cube.wrapMode==TextureWrapMode.Clamp,"Existing67 Cube configuration differs");
        result=new Result{scene=gameObject.scene.path,api=SystemInfo.graphicsDeviceType.ToString(),gpu=SystemInfo.graphicsDeviceName,debugBuild=Debug.isDebugBuild,testCaptureDisabled=!capture.enabled,
            auditProbeDisabled=!UnityEngine.Object.FindObjectsByType<RuntimeAuditProbe>(FindObjectsInactive.Include,FindObjectsSortMode.None).Any(p=>p.enabled),environmentCubeName=cube.name,view=settings.debugView.ToString(),composition=settings.composition.ToString()};
        Require(result.api=="Direct3D12"&&!result.debugBuild&&result.testCaptureDisabled&&result.auditProbeDisabled&&result.view=="Final"&&result.composition=="Additive"&&feature.isActive,"Release configuration differs");
        sample=ContinuousDeformationExample.Create(capture,false);
        Require(sample.Deformation.sdfResolution==16&&sample.Deformation.updateIntervalFrames==12,"Frozen deformation resolution/interval differs");
        position=capture.camera.transform.position;rotation=capture.camera.transform.rotation;door=capture.door.localPosition;objectMatrix=sample.SourceRenderer.localToWorldMatrix;lightState=Lights();
        check=new ContinuousDeformationCheck(sample,folder);capture.BeginSingleFinalCapture(folder);
        Application.runInBackground=true;Application.logMessageReceived+=OnLog;RenderPipelineManager.endCameraRendering+=Rendered;Save();
        Debug.Log("CONTINUOUS_DEFORMATION_START "+JsonUtility.ToJson(result));
    }
    void OnLog(string message,string stack,LogType type){if(type==LogType.Error||type==LogType.Exception||type==LogType.Assert){errors++;firstError=firstError??message;}}
    void Update()
    {
        if(finished||result==null)return;
        if(errors>0||quitPending){Finish(errors==0);return;}
        try
        {
            if(frames==0)Require(Time.frameCount-startEngine<=120&&Time.realtimeSinceStartupAsDouble-started<=900,"First camera exceeded startup limit");
            else Require(Time.frameCount<=lastEngine+1,"Target-camera receipts stopped");
            if(frames==32)sample.SetRunning(true);
            if(frames>=32&&frames<160)sample.Advance(1f/60f);
            if(frames==160)sample.SetRunning(false);
        }
        catch(Exception e){errors++;firstError=firstError??e.ToString();}
    }
    void Rendered(ScriptableRenderContext context,Camera camera)
    {
        if(finished||camera!=capture.camera)return;
        try
        {
            Require(lastEngine<0||Time.frameCount==lastEngine+1,"Duplicate/skipped target-camera receipt");
            Require(camera.transform.position==position&&camera.transform.rotation==rotation&&capture.door.localPosition==door&&sample.SourceRenderer.localToWorldMatrix==objectMatrix&&Lights()==lightState&&feature.isActive,"Frozen camera/lights/door/object changed");
            if(frames==0){result.firstEngine=Time.frameCount;result.firstRenderWaitSeconds=Time.realtimeSinceStartupAsDouble-started;}
            check.Observe(frames,Time.frameCount,(float)sample.MotionTime,feature,camera);
            if(frames==159||frames==255){capture.CaptureContinuousDeformationFrame(frames);captures++;}
            frames++;lastEngine=Time.frameCount;if(frames==256)quitPending=true;
        }
        catch(Exception e){errors++;firstError=firstError??e.ToString();}
    }
    void Cleanup()
    {
        RenderPipelineManager.endCameraRendering-=Rendered;Application.logMessageReceived-=OnLog;
        try{check?.Dispose();}catch(Exception e){errors++;firstError=firstError??e.ToString();}
        try{capture?.EndSingleFinalCapture();}catch(Exception e){errors++;firstError=firstError??e.ToString();}
        if(capture&&capture.camera)capture.camera.enabled=false;
        try
        {
            if(sample)
            {
                sample.Close();
                Require(!sample.Deformation.enabled&&sample.ProducerMesh==null&&sample.SourceRenderer.GetComponent<MeshFilter>().sharedMesh==sample.OriginalMesh,"Example source did not detach");
                if(result!=null)result.sourceClosed=true;
            }
        }
        catch(Exception e){errors++;firstError=firstError??e.ToString();}
    }
    void Save(){if(result!=null&&folder!=null)File.WriteAllText(Path.Combine(folder,"continuous-result.json"),JsonUtility.ToJson(result,true));}
    void Finish(bool completed)
    {
        if(finished)return;finished=true;
        if(completed)try{check.Finish();}catch(Exception e){errors++;firstError=firstError??e.ToString();}
        Cleanup();result.actualCameraFrames=frames;result.lastEngine=lastEngine;result.captures=captures;result.errors=errors;result.error=firstError;
        result.status=completed&&errors==0&&frames==256&&captures==2?"collected":"failed";Save();Debug.Log("CONTINUOUS_DEFORMATION_RESULT "+JsonUtility.ToJson(result));Application.Quit(result.status=="collected"?0:1);
    }
    void OnApplicationQuit(){if(result==null)return;if(!finished)Finish(false);result.normalQuitObserved=true;Save();}
}
