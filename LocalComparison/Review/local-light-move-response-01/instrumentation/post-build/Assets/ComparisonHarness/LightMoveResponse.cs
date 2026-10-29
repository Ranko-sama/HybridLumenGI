// Test-project-only one-event controller. Product state is read, never injected.
using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Reflection;
using HybridLumenGI;
using UnityEngine;
using UnityEngine.Rendering;

public sealed class LightMoveResponse : MonoBehaviour
{
    const BindingFlags Fields=BindingFlags.Instance|BindingFlags.Public|BindingFlags.NonPublic;
    static object Field(object o,string n)=>o.GetType().GetField(n,Fields).GetValue(o);
    static readonly Vector3 A=new Vector3(-2.4f,2.8f,2),B=new Vector3(2.4f,2.8f,2);
    static readonly int[] Samples={90,119,120,135,179};
    ComparisonCapture capture;HybridLumenGIRendererFeature feature;Light lamp;string folder,firstError;
    int frames,lastEngine=-1,startEngine,errors,captures;double started;bool moved,finished,quitPending;
    Vector3 cameraPosition,doorPosition;Quaternion cameraRotation;LightState[] initial;
    [Serializable] sealed class LightState
    {
        public string name;public int instance,type;public bool enabled;public float intensity,range;public Color color;public Vector3 position;public Quaternion rotation;
        public static LightState From(Light l)=>new LightState{name=l.name,instance=l.GetInstanceID(),type=(int)l.type,enabled=l.enabled,intensity=l.intensity,range=l.range,color=l.color,position=l.transform.position,rotation=l.transform.rotation};
    }
    [Serializable] sealed class LightRecord
    {
        public Vector4 positionType,directionRange,color,spot;public uint cullingMask,renderingLayers,shadowRenderingLayers,flags;
        public static LightRecord From(HybridLumenGILights.Data d)=>new LightRecord{positionType=d.positionType,directionRange=d.directionRange,color=d.color,spot=d.spot,cullingMask=d.cullingMask,renderingLayers=d.renderingLayers,shadowRenderingLayers=d.shadowRenderingLayers,flags=d.flags};
    }
    [Serializable] sealed class ChangeRow {public Vector4 minimum,maximum,receiver;}
    [Serializable] sealed class Snapshot
    {
        public int logical,engine,gi,count;public float globalLighting,globalGeometry;public LightState lamp;public LightRecord[] selected,changes;public ChangeRow[] regions;
        public HybridLumenGIRendererFeature.CameraDiagnostics diagnostics;
    }
    [Serializable] sealed class Event {public int logical=120,engine,previousRenderEngine,lampInstance;public Vector3 from,to;}
    [Serializable] sealed class Result
    {
        public string status="running",error,scene,api,gpu,view="IndirectOnly",scope="Five existing linear HDR captures; no physical-truth, convergence or performance claim";
        public bool debugBuild,testCaptureDisabled,auditProbeDisabled,normalQuitObserved,moved;
        public int requestedFrames=180,actualCameraFrames,captures,errors,firstEngine=-1,lastEngine=-1;
    }
    Result result;
    static void Require(bool value,string message){if(!value)throw new Exception(message);}
    static string Arg(string name){var args=Environment.GetCommandLineArgs();int i=Array.IndexOf(args,name);return i>=0&&i+1<args.Length?args[i+1]:null;}
    public static bool TryStart()
    {
        if(Application.isEditor||Debug.isDebugBuild||Array.IndexOf(Environment.GetCommandLineArgs(),"-localLightMove")<0)return false;
        try
        {
            var c=UnityEngine.Object.FindFirstObjectByType<ComparisonCapture>();Require(c&&c.camera&&c.feature&&c.colorView&&c.door,"Existing Functional references missing");
            c.enabled=false;
            foreach(var p in UnityEngine.Object.FindObjectsByType<RuntimeAuditProbe>(FindObjectsInactive.Include,FindObjectsSortMode.None))p.enabled=false;
            foreach(var p in UnityEngine.Object.FindObjectsByType<StreamingAuditProbe>(FindObjectsInactive.Include,FindObjectsSortMode.None))p.enabled=false;
            var m=c.gameObject.AddComponent<LightMoveResponse>();m.capture=c;m.feature=(HybridLumenGIRendererFeature)c.feature;m.Initialize();
        }
        catch(Exception e){Debug.LogError("LIGHT_MOVE_START_FAILED "+e);Application.Quit(1);}
        return true;
    }
    void Initialize()
    {
        folder=Arg("-localReleaseOutput");Require(!string.IsNullOrEmpty(folder)&&Path.IsPathRooted(folder)&&!Directory.Exists(folder),"New absolute output required");Directory.CreateDirectory(folder);
        lamp=capture.lights.Single(l=>l.name=="Point (toggle for invalidation)");
        Require(lamp.type==LightType.Point&&lamp.enabled&&lamp.transform.position==A&&lamp.intensity==7&&lamp.range==8&&lamp.color==new Color(1,.75f,.5f,1),"Frozen source identity/state differs");
        initial=capture.lights.Select(LightState.From).ToArray();
        var settings=(HybridLumenGIRendererFeature.Settings)Field(feature,"settings");settings.preferHardwareTracing=true;settings.debugView=HybridLumenGIRendererFeature.DebugView.IndirectOnly;
        feature.SetActive(true);capture.camera.enabled=true;capture.camera.transform.SetPositionAndRotation(capture.colorView.position,capture.colorView.rotation);
        cameraPosition=capture.camera.transform.position;cameraRotation=capture.camera.transform.rotation;doorPosition=capture.door.localPosition;
        result=new Result{scene=gameObject.scene.path,api=SystemInfo.graphicsDeviceType.ToString(),gpu=SystemInfo.graphicsDeviceName,debugBuild=Debug.isDebugBuild,testCaptureDisabled=!capture.enabled,
            auditProbeDisabled=!UnityEngine.Object.FindObjectsByType<RuntimeAuditProbe>(FindObjectsInactive.Include,FindObjectsSortMode.None).Any(p=>p.enabled)};
        Require(result.api=="Direct3D12"&&!result.debugBuild&&result.testCaptureDisabled&&result.auditProbeDisabled,"Release isolation differs");
        try{capture.BeginSingleFinalCapture(folder);}catch{capture.EndSingleFinalCapture();throw;}
        started=Time.realtimeSinceStartupAsDouble;startEngine=Time.frameCount;Application.runInBackground=true;
        Application.logMessageReceived+=OnLog;RenderPipelineManager.endCameraRendering+=Rendered;Save();
    }
    void OnLog(string message,string stack,LogType type){if(type==LogType.Error||type==LogType.Exception||type==LogType.Assert){errors++;firstError=firstError??message;}}
    void Update()
    {
        if(finished||result==null)return;
        if(errors>0||quitPending){Finish(errors==0);return;}
        try
        {
            if(frames==0)Require(Time.frameCount-startEngine<=120&&Time.realtimeSinceStartupAsDouble-started<=900,"First camera receipt exceeded startup guard");
            else Require(Time.frameCount<=lastEngine+1,"Target-camera receipt stopped");
            if(frames==120&&!moved)
            {
                Require(lamp.transform.position==A,"Light moved before event");lamp.transform.position=B;moved=true;
                File.WriteAllText(Path.Combine(folder,"event.json"),JsonUtility.ToJson(new Event{engine=Time.frameCount,previousRenderEngine=lastEngine,lampInstance=lamp.GetInstanceID(),from=A,to=B},true));
            }
        }
        catch(Exception e){errors++;firstError=firstError??e.ToString();}
    }
    void Rendered(ScriptableRenderContext context,Camera camera)
    {
        if(finished||camera!=capture.camera)return;
        try
        {
            Require(lastEngine<0||Time.frameCount==lastEngine+1,"Duplicate/skipped target camera");
            Require(camera.transform.position==cameraPosition&&camera.transform.rotation==cameraRotation&&capture.door.localPosition==doorPosition&&feature.isActive,"Frozen view/door/feature changed");
            for(int i=0;i<initial.Length;i++)
            {
                var l=capture.lights[i];var old=initial[i];var current=LightState.From(l);current.position=old.position;
                Require(JsonUtility.ToJson(current)==JsonUtility.ToJson(old)&&l.transform.position==(l==lamp&&frames>=120?B:old.position),"Unexpected light state changed");
            }
            if(Array.IndexOf(Samples,frames)>=0){SnapshotState(frames);capture.CaptureLightMoveFrame(frames);captures++;}
            if(frames==0)result.firstEngine=Time.frameCount;
            frames++;lastEngine=Time.frameCount;if(frames==180)quitPending=true;
        }
        catch(Exception e){errors++;firstError=firstError??e.ToString();}
    }
    void SnapshotState(int logical)
    {
        var states=(IDictionary)Field(Field(feature,"pass"),"cameras");var state=states[capture.camera.GetInstanceID()];Require(state!=null,"Current camera state absent");
        int count=(int)Field(state,"previousLightCount");var domain=Field(state,"changes");int size=(int)Field(domain,"count");var regions=(Array)Field(domain,"regions");
        var row=new Snapshot{logical=logical,engine=Time.frameCount,gi=(int)Field(state,"frame"),count=count,lamp=LightState.From(lamp),
            selected=((HybridLumenGILights.Data[])Field(state,"lightData")).Take(count).Select(LightRecord.From).ToArray(),
            changes=((List<HybridLumenGILights.Data>)Field(state,"lightChanges")).Select(LightRecord.From).ToArray(),
            globalLighting=(float)Field(domain,"globalReactive"),globalGeometry=(float)Field(domain,"globalGeometryChange"),
            regions=Enumerable.Range(0,size).Select(i=>{var r=regions.GetValue(i);return new ChangeRow{minimum=(Vector4)Field(r,"minimum"),maximum=(Vector4)Field(r,"maximum"),receiver=(Vector4)Field(r,"receiver")};}).ToArray(),
            diagnostics=feature.GetDiagnostics().Single(d=>d.camera==capture.camera.name)};
        File.WriteAllText(Path.Combine(folder,"lights-"+logical.ToString("D4")+".json"),JsonUtility.ToJson(row,true));
    }
    void Save(){if(result!=null)File.WriteAllText(Path.Combine(folder,"light-move-result.json"),JsonUtility.ToJson(result,true));}
    void Finish(bool completed)
    {
        if(finished)return;finished=true;RenderPipelineManager.endCameraRendering-=Rendered;Application.logMessageReceived-=OnLog;
        try{capture.EndSingleFinalCapture();}catch(Exception e){errors++;firstError=firstError??e.ToString();}
        result.actualCameraFrames=frames;result.lastEngine=lastEngine;result.captures=captures;result.errors=errors;result.error=firstError;result.moved=moved;
        result.status=completed&&errors==0&&frames==180&&captures==5&&moved?"collected":"failed";Save();Application.Quit(result.status=="collected"?0:1);
    }
    void OnApplicationQuit(){if(result==null)return;if(!finished)Finish(false);result.normalQuitObserved=true;Save();}
}
