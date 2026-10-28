// A finite mode of the existing ComparisonCapture runner. Test project only.
using System;
using System.IO;
using System.Reflection;
using UnityEngine;
using UnityEngine.Rendering;
using HybridLumenGI;

public static class MaterialEventMode
{
    public static bool Requested { get; private set; }
    static ComparisonCapture capture;
    static Renderer target,control;
    static MeshFilter deformFilter;
    static Mesh initialMesh,dynamicMesh;
    static MaterialPropertyBlock originalSlot,eventSlot;
    static Vector3 cameraPosition,doorPosition;
    static Quaternion cameraRotation;
    static bool applied,closed;
    static int lastLogical=-1;
    static readonly BindingFlags Fields=BindingFlags.Instance|BindingFlags.Public|BindingFlags.NonPublic;
    static string DirectoryPath=>(string)typeof(ComparisonCapture).GetField("directory",Fields).GetValue(capture);
    [Serializable] sealed class Preflight
    {
        public string target,control;
        public bool rendererBlockEmpty,slotBlockEmpty,slot1BlockEmpty;
        public int materialSlots,eventLogicalFrame=160,totalLogicalFrames=256;
        public Vector4 eventBaseColor=new Vector4(0,0,1,1);
        public string scope="One ordinary slot-0 MPB write; no manual dirty, source regeneration, motion or lighting event.";
    }
    static Preflight preflight;
    public static void Configure(ComparisonCapture value)
    {
        if(Requested)throw new Exception("Duplicate material-event configuration");
        Requested=true;capture=value;
        var probe=UnityEngine.Object.FindFirstObjectByType<RuntimeAuditProbe>();
        if(!probe || !ReferenceEquals(probe.capture,capture))throw new Exception("Expected Functional probe missing");
        probe.enabled=false;
        target=probe.mutableRenderer;control=GameObject.Find("Green wall")?.GetComponent<Renderer>();
        if(!target || target.name!="White receiver" || !control || target.sharedMaterials.Length!=2)
            throw new Exception("Frozen target/control source is absent");
        var rendererBlock=new MaterialPropertyBlock();originalSlot=new MaterialPropertyBlock();eventSlot=new MaterialPropertyBlock();
        target.GetPropertyBlock(rendererBlock);target.GetPropertyBlock(originalSlot,0);target.GetPropertyBlock(eventSlot,0);
        var slot1=new MaterialPropertyBlock();target.GetPropertyBlock(slot1,1);
        if(!rendererBlock.isEmpty && originalSlot.isEmpty)
            throw new Exception("Slot override would mask renderer-level properties; single-variable preparation rejected");
        preflight=new Preflight{target=target.name,control=control.name,rendererBlockEmpty=rendererBlock.isEmpty,
            slotBlockEmpty=originalSlot.isEmpty,slot1BlockEmpty=slot1.isEmpty,materialSlots=target.sharedMaterials.Length};
        var feature=(HybridLumenGIRendererFeature)capture.feature;
        var settings=(HybridLumenGIRendererFeature.Settings)typeof(HybridLumenGIRendererFeature).GetField("settings",Fields).GetValue(feature);
        settings.preferHardwareTracing=true;settings.exactSoftwareTracing=true;
        settings.measureGpuCost=false;settings.adaptiveGpuBudget=false;settings.targetGpuMilliseconds=0;
        feature.SetActive(true);capture.featureOff=false;capture.indirectOnly=false;capture.totalFrames=256;capture.quitWhenComplete=true;
        capture.label="material-mpb-propagation-02";
        if(SystemInfo.graphicsDeviceType!=GraphicsDeviceType.Direct3D12 || !SystemInfo.supportsInlineRayTracing)
            throw new Exception("DX12 inline tracing is required");
        // Preserve only the original probe's initial deformation snapshot, never its later events.
        deformFilter=probe.deformation.GetComponent<MeshFilter>();initialMesh=deformFilter.sharedMesh;
        dynamicMesh=UnityEngine.Object.Instantiate(initialMesh);deformFilter.sharedMesh=dynamicMesh;
        probe.deformation.RequestCapture(dynamicMesh);
        MaterialEventTap.Configure(capture.camera,target,control);
    }
    public static void Apply(int logicalFrame)
    {
        if(closed || logicalFrame!=lastLogical+1 || logicalFrame>=256)throw new Exception("Material-event logical sequence mismatch");
        lastLogical=logicalFrame;
        if(logicalFrame==0)
        {
            capture.camera.transform.SetPositionAndRotation(capture.colorView.position,capture.colorView.rotation);
            cameraPosition=capture.camera.transform.position;cameraRotation=capture.camera.transform.rotation;doorPosition=capture.door.localPosition;
            WriteNew(Path.Combine(DirectoryPath,"material-event-preflight.json"),JsonUtility.ToJson(preflight,true));
        }
        if(capture.camera.transform.position!=cameraPosition || capture.camera.transform.rotation!=cameraRotation || capture.door.localPosition!=doorPosition)
            throw new Exception("Frozen camera/door changed");
        MaterialEventTap.BeginLogicalFrame(logicalFrame,Time.frameCount,DirectoryPath);
        if(logicalFrame==160)
        {
            MaterialEventTap.RequireEventCoverage();
            if(applied)throw new Exception("Repeated material event");
            var rendererBlock=new MaterialPropertyBlock();target.GetPropertyBlock(rendererBlock);
            target.GetPropertyBlock(eventSlot,0);
            if(rendererBlock.isEmpty!=preflight.rendererBlockEmpty || eventSlot.isEmpty!=preflight.slotBlockEmpty ||
                (!rendererBlock.isEmpty && eventSlot.isEmpty))throw new Exception("MPB precedence changed before the event");
            // No MarkDirty or synthetic invalidation. The product must observe this ordinary API change.
            eventSlot.SetColor("_BaseColor",Color.blue);target.SetPropertyBlock(eventSlot,0);applied=true;
            MaterialEventTap.RecordEvent(eventSlot.GetVector("_BaseColor"));
        }
    }
    public static void Rendered(int logicalFrame,int engineFrame)
    {
        if(!Requested || closed)return;
        if(logicalFrame!=lastLogical || engineFrame!=Time.frameCount)throw new Exception("Material-event capture receipt mismatch");
        MaterialEventTap.FrameEnded(logicalFrame,engineFrame);
    }
    public static void Close(bool collected)
    {
        if(!Requested || closed)return;closed=true;
        if(capture && capture.camera)capture.camera.enabled=false;
        try{MaterialEventTap.Finish(collected && applied && lastLogical==255);}
        finally
        {
            Exception restoreError=null;
            try{if(target && originalSlot!=null)target.SetPropertyBlock(originalSlot,0);}catch(Exception e){restoreError=e;}
            try{if(deformFilter && initialMesh)deformFilter.sharedMesh=initialMesh;}catch(Exception e){restoreError=restoreError??e;}
            try{if(dynamicMesh){var owned=dynamicMesh;dynamicMesh=null;HybridLumenGIResourceRetirement.Retire(()=>UnityEngine.Object.Destroy(owned));}}
            catch(Exception e){restoreError=restoreError??e;}
            if(restoreError!=null)throw restoreError;
        }
    }
    static void WriteNew(string path,string text)
    {
        byte[] bytes=System.Text.Encoding.UTF8.GetBytes(text);
        using(var stream=new FileStream(path,FileMode.CreateNew,FileAccess.Write,FileShare.Read))stream.Write(bytes,0,bytes.Length);
    }
}
