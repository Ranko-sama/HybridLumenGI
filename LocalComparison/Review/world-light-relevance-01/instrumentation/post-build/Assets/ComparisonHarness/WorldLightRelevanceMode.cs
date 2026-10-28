// Unique 64-frame native admission/upload fixture. Test build only.
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using UnityEngine;
using UnityEngine.Rendering;
using HybridLumenGI;

public static class WorldLightRelevanceMode
{
    public static bool Enabled=>Array.IndexOf(Environment.GetCommandLineArgs(),"-worldLightRelevance")>=0;
    const BindingFlags Flags=BindingFlags.Instance|BindingFlags.Public|BindingFlags.NonPublic;
    static object Field(object value,string name)=>value.GetType().GetField(name,Flags).GetValue(value);
    static ComparisonCapture capture;static Light[] selected;
    static Vector3 position,doorPosition,targetPoint;static Quaternion rotation;
    static string directory,failure;static int logical=-1,receipts,pending,bindings;static bool completed,closed,useLayers;
    static Inputs frozen;static Receipt receipt;
    [Serializable] sealed class LightInput {public int id;public string role;public Vector3 position;public float range;public string packedBase64;}
    [Serializable] sealed class Inputs
    {
        public int maximumFrames=64,capacity=2;public bool spatialSelection=true;
        public string target="Green wall, local X-minus face center",featureJson;
        public Vector3 targetPoint,cameraPosition,doorPosition;public Quaternion cameraRotation;
        public float near,far,fov,aspect;public LightInput[] lights;
    }
    [Serializable] sealed class Extent {public int slot,cards;public bool published,warming;public Vector3 traversalMin,traversalMax,captureMin,captureMax;}
    [Serializable] sealed class Receipt
    {
        public int logical,engine,gi,boundCount,candidates,outside,selected,omitted,bufferCount,bufferStride;
        public bool hardware,domainValid,useRenderingLayers;public string status,domainReason;
        public Vector3 domainMin,domainMax;public Matrix4x4 inverseGpuVP;
        public List<Extent> extents=new List<Extent>();public LightInput[] sources;
        public string gpuFile="lights.bin",gpuSha256;public bool gpuCompleted;
        public string countEvidence="Actual C# _HLGI_LightCount binding argument; not GPU constant readback";
    }
    [Serializable] sealed class Result {public int receipts,bindings,pending;public bool completed;public string failure;}
    static void Require(bool ok,string message){if(!ok)throw new Exception(message);}
    static void WriteNew(string name,byte[] bytes)
    {using(var s=new FileStream(Path.Combine(directory,name),FileMode.CreateNew,FileAccess.Write,FileShare.Read))s.Write(bytes,0,bytes.Length);}
    static void Json(string name,object value)=>WriteNew(name,System.Text.Encoding.UTF8.GetBytes(JsonUtility.ToJson(value,true)));
    static byte[] Pack(HybridLumenGILights.Data value)
    {
        Require(Marshal.SizeOf<HybridLumenGILights.Data>()==80,"Light ABI changed");
        var bytes=new byte[80];var pin=GCHandle.Alloc(bytes,GCHandleType.Pinned);
        try{Marshal.StructureToPtr(value,pin.AddrOfPinnedObject(),false);}finally{pin.Free();}return bytes;
    }
    static LightInput[] Sources(bool layers)
    {
        var all=UnityEngine.Object.FindObjectsByType<Light>(FindObjectsInactive.Include,FindObjectsSortMode.InstanceID);
        var valid=new List<LightInput>();
        foreach(var l in all)if(HybridLumenGILights.TryPack(l,layers,out var packed))
        {
            int i=Array.IndexOf(selected,l);Require(i>=0,"Unexpected valid world light");
            valid.Add(new LightInput{id=l.GetInstanceID(),role=i<2?"outside-"+i:"relevant",position=l.transform.position,range=l.range,packedBase64=Convert.ToBase64String(Pack(packed))});
        }
        Require(valid.Count==3 && valid.Select(x=>x.id).SequenceEqual(selected.Select(x=>x.GetInstanceID())),"Actual discovery changed");return valid.ToArray();
    }
    public static void Configure(ComparisonCapture value)
    {
        capture=value;Require(capture && capture.camera && capture.colorView,"Missing fixed scene");
        var probe=UnityEngine.Object.FindFirstObjectByType<RuntimeAuditProbe>();Require(probe && probe.deformation,"Missing initial deformation source");
        probe.enabled=false;
        // Preserve the initial existing mesh snapshot, without probe motion or mixed events.
        probe.deformation.RequestCapture(probe.deformation.GetComponent<MeshFilter>().sharedMesh);
        var wall=GameObject.Find("Green wall");Require(wall && wall.GetComponent<Renderer>(),"Existing target missing");
        targetPoint=wall.transform.TransformPoint(new Vector3(-.5f,0,0));
        foreach(var l in UnityEngine.Object.FindObjectsByType<Light>(FindObjectsInactive.Include,FindObjectsSortMode.InstanceID))l.enabled=false;
        var made=new List<Light>();for(int i=0;i<3;i++)made.Add(new GameObject("World light fixture "+i).AddComponent<Light>());
        selected=UnityEngine.Object.FindObjectsByType<Light>(FindObjectsInactive.Include,FindObjectsSortMode.InstanceID).Where(made.Contains).ToArray();
        Require(selected.Length==3,"Fixture discovery failed");
        for(int i=0;i<3;i++)
        {
            var l=selected[i];l.name=i<2?"Outside "+i:"Relevant surface light";l.type=LightType.Point;l.range=10;l.intensity=1;
            l.color=Color.white;l.shadows=LightShadows.None;l.cullingMask=-1;l.enabled=true;
            l.transform.position=i<2?new Vector3((i+1)*10000000f,0,0):targetPoint+Vector3.left;
        }
        capture.lights=selected;capture.totalFrames=64;capture.quitWhenComplete=true;capture.featureOff=false;capture.indirectOnly=false;
        capture.label="world-light-relevance-01";capture.feature.SetActive(true);
        var settings=(HybridLumenGIRendererFeature.Settings)Field(capture.feature,"settings");
        settings.preferHardwareTracing=true;settings.exactSoftwareTracing=true;settings.maxLights=2;settings.spatialLightSelection=true;
        settings.measureGpuCost=false;settings.adaptiveGpuBudget=false;settings.targetGpuMilliseconds=0;
        position=capture.colorView.position;rotation=capture.colorView.rotation;doorPosition=capture.door.localPosition;
        capture.camera.transform.SetPositionAndRotation(position,rotation);
        frozen=new Inputs{targetPoint=targetPoint,cameraPosition=position,cameraRotation=rotation,doorPosition=doorPosition,
            near=capture.camera.nearClipPlane,far=capture.camera.farClipPlane,fov=capture.camera.fieldOfView,aspect=capture.camera.aspect,
            featureJson=JsonUtility.ToJson(capture.feature,true),lights=Sources(false)};
    }
    public static void Apply(ComparisonCapture value,int frame,string folder)
    {
        Require(value==capture && !closed && frame>=0 && frame<64,"Unexpected fixture Apply");logical=frame;
        if(directory==null){directory=folder;Json("light-inputs.json",frozen);}
        Require(capture.camera.transform.position==position && capture.camera.transform.rotation==rotation && capture.door.localPosition==doorPosition,"Fixed scene moved");
        Require(Sources(false).Select(x=>x.packedBase64).SequenceEqual(frozen.lights.Select(x=>x.packedBase64)),"Frozen light inputs changed");
        if(failure!=null)throw new Exception(failure);
    }
    public static void Selection(object state,bool layers)
    {if(Enabled && ReferenceEquals(Field(state,"camera"),capture.camera))useLayers=layers;}
    public static void Observe(CommandBuffer cmd,object state,int count,int gi,bool hardware,Matrix4x4 inverse)
    {
        if(!Enabled || closed || logical!=63 || !ReferenceEquals(Field(state,"camera"),capture.camera))return;
        try
        {
            Require(bindings++==0,"Duplicate final-frame transport binding");
            var domain=(HybridLumenGILightRelevance.Domain)Field(state,"lightDomain");
            var d=(HybridLumenGILights.SelectionDiagnostics)Field(state,"lightSelection");var buffer=(ComputeBuffer)Field(state,"lights");
            receipt=new Receipt{logical=logical,engine=Time.frameCount,gi=gi,boundCount=count,hardware=hardware,
                domainValid=domain.IsValid,domainMin=domain.Minimum,domainMax=domain.Maximum,inverseGpuVP=inverse,
                candidates=d.ValidCandidates,outside=d.OutsideDomain,selected=d.Selected,omitted=d.CapacityOmitted,status=d.Status,
                domainReason=(string)Field(state,"lightDomainReason"),useRenderingLayers=useLayers,sources=Sources(useLayers),bufferCount=buffer.count,bufferStride=buffer.stride};
            var scene=(HybridLumenGIScene)Field(state,"scene");var surface=(HybridLumenGISurfaceCache)Field(state,"surfaceCache");
            for(int slot=0;slot<scene.Capacity;slot++)if(scene.IsPublished(slot)||scene.IsWarming(slot))
            {
                Require(scene.TryGetPreparedTraversalBounds(slot,out var b),"Missing prepared traversal");
                var e=new Extent{slot=slot,published=scene.IsPublished(slot),warming=scene.IsWarming(slot),cards=surface.GetCardCount(slot),traversalMin=b.min,traversalMax=b.max};
                if(e.cards>0){Require(surface.TryGetPreparedCaptureBounds(slot,out var c),"Missing prepared capture");e.captureMin=c.min;e.captureMax=c.max;}receipt.extents.Add(e);
            }
            Json("binding.json",receipt);pending++;
            cmd.RequestAsyncReadback(buffer,buffer.count*buffer.stride,0,request=>
            {
                try
                {
                    Require(request.done&&!request.hasError,"Final light upload readback failed");var bytes=request.GetData<byte>().ToArray();
                    Require(bytes.Length==receipt.bufferCount*receipt.bufferStride,"Readback size mismatch");WriteNew(receipt.gpuFile,bytes);
                    using(var digest=SHA256.Create())receipt.gpuSha256=BitConverter.ToString(digest.ComputeHash(bytes)).Replace("-","").ToLowerInvariant();
                    receipt.gpuCompleted=true;Json("upload.json",receipt);completed=true;
                }
                catch(Exception e){Abort(e);}finally{pending--;}
            });
        }
        catch(Exception e){Abort(e);} // Never throw into the product fallback path.
    }
    public static void Rendered(int frame)
    {Require(frame==receipts && logical==frame,"Missing/duplicate fixture receipt");receipts++;}
    public static void Abort(Exception error){if(failure==null)failure=error.ToString();}
    public static void Close()
    {
        if(closed)return;closed=true;
        if(pending>0)AsyncGPUReadback.WaitAllRequests();
        Json("light-result.json",new Result{receipts=receipts,bindings=bindings,pending=pending,completed=completed,failure=failure});
        Require(failure==null && receipts==64 && bindings==1 && pending==0 && completed,"Incomplete finite light upload receipt: "+failure);
    }
}
