// Temporary CPU-only diagnostic. Never enable feedback or alter render settings.
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Threading;
using UnityEngine;
using UnityEngine.Rendering;

namespace HybridLumenGI
{
    public static class StartupStageProbe
    {
        const int Capacity=1024;
        [Serializable] public struct Entry
        {
            public int sequence,scopeId,engineFrame,threadId,cameraId;
            public long timestamp;
            public double millisecondsFromOrigin;
            public string kind,stage;
        }
        [Serializable] sealed class Receipt
        {
            public string schema="startup-stage-cpu-v1",status,error,unity,api,gpu,camera;
            public string scope="CPU elapsed wall-clock at the named managed boundary; includes blocking and instrumentation overhead; nested scopes overlap. Command recording is not GPU execution or completion. Origin is probe first use / RuntimeInitialize, not process launch. No performance acceptance threshold.";
            public bool cpuOnly=true,firstRequestReturned,runtimeInitializeObserved;
            public long stopwatchFrequency,originTimestamp;
            public int firstRequestEngineFrame,contextBegins,contextEnds,cameraBegins,cameraEnds;
            public Entry[] events;
        }
        static readonly Entry[] entries=new Entry[Capacity];
        static int count,nextScope,thread,firstRequestEngine=-1;
        static int contextBegins,contextEnds,cameraBegins,cameraEnds;
        static long origin;
        static bool initialized,configured,finished,insideRequest,requestReturned,runtimeInitializeObserved;
        static Camera selected;
        static string directory,cameraName;
        public static string Failure {get;private set;}
        public static bool Written {get;private set;}

        static void InitializeIfNeeded()
        {
            if(initialized)return;
            initialized=true;origin=Stopwatch.GetTimestamp();thread=Thread.CurrentThread.ManagedThreadId;
        }
        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.SubsystemRegistration)]
        static void SubsystemRegistration()
        {InitializeIfNeeded();runtimeInitializeObserved=true;Mark("RuntimeInitialize.SubsystemRegistration");}
        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterAssembliesLoaded)]
        static void AssembliesLoaded(){Mark("RuntimeInitialize.AfterAssembliesLoaded");}
        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.BeforeSceneLoad)]
        static void BeforeScene(){Mark("RuntimeInitialize.BeforeSceneLoad");}
        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
        static void AfterScene(){Mark("RuntimeInitialize.AfterSceneLoad");}

        static void Fail(string reason){if(Failure==null)Failure=reason;}
        static bool Accept(Camera camera)
        {return !finished&&(!configured||camera==null||camera==selected);}
        static void Record(string kind,string stage,int id,Camera camera)
        {
            InitializeIfNeeded();if(finished)return;
            int caller=Thread.CurrentThread.ManagedThreadId;
            if(caller!=thread){Fail("CPU probe called outside its initializing thread");return;}
            if(count==Capacity){Fail("Bounded CPU event buffer overflow");return;}
            long now=Stopwatch.GetTimestamp();
            entries[count]=new Entry{sequence=count,scopeId=id,engineFrame=Time.frameCount,threadId=caller,
                cameraId=camera!=null?camera.GetInstanceID():0,timestamp=now,
                millisecondsFromOrigin=(now-origin)*1000.0/Stopwatch.Frequency,kind=kind,stage=stage};count++;
        }
        public static void Mark(string stage){Record("marker",stage,0,null);}
        public static Scope Measure(Camera camera,string stage)
        {
            if(!Accept(camera))return default;
            int id=++nextScope;Record("begin",stage,id,camera);return new Scope(id,stage,camera);
        }
        public readonly struct Scope:IDisposable
        {
            readonly int id;readonly string stage;readonly Camera camera;
            internal Scope(int value,string name,Camera source){id=value;stage=name;camera=source;}
            public void Dispose(){if(id!=0)Record("end",stage,id,camera);}
        }
        public static int FindKernel(ComputeShader shader,string kernel,Camera camera)
        {
            if(!Accept(camera))return shader.FindKernel(kernel);
            using(Measure(camera,"Feature.FindKernel/"+kernel))return shader.FindKernel(kernel);
        }
        // Configuration allocates no files and does not query or synchronize the GPU.
        public static void Configure(Camera camera,string outputDirectory)
        {
            InitializeIfNeeded();
            if(configured){Fail("CPU probe configured more than once in this process");return;}
            configured=true;selected=camera;
            cameraName=camera!=null?camera.name:null;directory=outputDirectory;
            if(camera==null||string.IsNullOrEmpty(directory)||!Path.IsPathRooted(directory))Fail("CPU probe requires a selected camera and absolute output directory");
            RenderPipelineManager.beginContextRendering+=ContextBegin;RenderPipelineManager.endContextRendering+=ContextEnd;
            RenderPipelineManager.beginCameraRendering+=CameraBegin;RenderPipelineManager.endCameraRendering+=CameraEnd;
            Mark("Probe.Configured");
        }
        static void ContextBegin(ScriptableRenderContext context,List<Camera> cameras)
        {if(cameras.Contains(selected)){contextBegins++;Callback("Callback.beginContextRendering");}}
        static void ContextEnd(ScriptableRenderContext context,List<Camera> cameras)
        {if(cameras.Contains(selected)){contextEnds++;Callback("Callback.endContextRendering");}}
        static void CameraBegin(ScriptableRenderContext context,Camera camera)
        {if(camera==selected){cameraBegins++;Callback("Callback.beginCameraRendering");}}
        static void CameraEnd(ScriptableRenderContext context,Camera camera)
        {if(camera==selected){cameraEnds++;Callback("Callback.endCameraRendering");}}
        static void Callback(string name)
        {if(!insideRequest)Fail("Selected camera callback occurred outside the first explicit request");Record("marker",name,0,selected);}
        public static void Submit(Camera camera,RenderPipeline.StandardRequest request)
        {
            if(finished||!configured||camera!=selected){RenderPipeline.SubmitRenderRequest(camera,request);return;}
            firstRequestEngine=Time.frameCount;insideRequest=true;
            var scope=Measure(camera,"Host.SubmitRenderRequest");
            try{RenderPipeline.SubmitRenderRequest(camera,request);requestReturned=true;}
            finally
            {
                insideRequest=false;scope.Dispose();
                // Only the completed/failed request boundary may write the buffered trace.
                Finish();
            }
        }
        public static void Stop(Camera camera)
        {if(configured&&camera==selected&&!finished){Fail("Host stopped before first explicit request completed");Finish();}}
        static void Finish()
        {
            if(finished)return;
            if(!requestReturned)Fail("First explicit request did not return successfully");
            if(contextBegins!=1||contextEnds!=1||cameraBegins!=1||cameraEnds!=1)Fail("First request callback counts are not exactly one complete context/camera pair");
            Mark("Probe.BufferedCaptureEnd");finished=true;
            RenderPipelineManager.beginContextRendering-=ContextBegin;RenderPipelineManager.endContextRendering-=ContextEnd;
            RenderPipelineManager.beginCameraRendering-=CameraBegin;RenderPipelineManager.endCameraRendering-=CameraEnd;
            try
            {
                var copy=new Entry[count];Array.Copy(entries,copy,count);
                var receipt=new Receipt{status=Failure==null?"collected":"incomplete",error=Failure,
                    unity=Application.unityVersion,api=SystemInfo.graphicsDeviceType.ToString(),gpu=SystemInfo.graphicsDeviceName,
                    camera=cameraName,firstRequestReturned=requestReturned,runtimeInitializeObserved=runtimeInitializeObserved,
                    stopwatchFrequency=Stopwatch.Frequency,originTimestamp=origin,firstRequestEngineFrame=firstRequestEngine,
                    contextBegins=contextBegins,contextEnds=contextEnds,cameraBegins=cameraBegins,cameraEnds=cameraEnds,events=copy};
                // CreateNew preserves every earlier result, including failures.
                using(var stream=new FileStream(Path.Combine(directory,"startup-stage-cpu.json"),FileMode.CreateNew,FileAccess.Write,FileShare.Read))
                using(var writer=new StreamWriter(stream))writer.Write(JsonUtility.ToJson(receipt,true));
                Written=true;
            }
            catch(Exception error){Fail("CPU trace write failed: "+error.Message);}
        }
    }
}
