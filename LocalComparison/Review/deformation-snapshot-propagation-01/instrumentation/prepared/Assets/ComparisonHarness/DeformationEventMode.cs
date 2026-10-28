// One normal readable-mesh update in the existing finite Player harness.
using System;
using System.IO;
using System.Reflection;
using UnityEngine;
using UnityEngine.Rendering;
using HybridLumenGI;

public static class DeformationEventMode
{
    public static bool Requested { get; private set; }
    static ComparisonCapture capture;
    static HybridLumenGIDeformedMesh deformation;
    static MeshFilter filter;static Mesh original,dynamicMesh;
    static Vector3 cameraPosition,doorPosition;static Quaternion cameraRotation;
    static Matrix4x4 targetMatrix;
    static bool applied,closed;static int lastLogical=-1;
    static readonly BindingFlags Fields=BindingFlags.Instance|BindingFlags.Public|BindingFlags.NonPublic;
    static string DirectoryPath=>(string)typeof(ComparisonCapture).GetField("directory",Fields).GetValue(capture);
    public static void Configure(ComparisonCapture value)
    {
        if(Requested)throw new Exception("Duplicate deformation-event configuration");
        Requested=true;capture=value;
        var probe=UnityEngine.Object.FindFirstObjectByType<RuntimeAuditProbe>();
        if(!probe || !ReferenceEquals(probe.capture,capture))throw new Exception("Expected Functional probe missing");
        probe.enabled=false;deformation=probe.deformation;
        var target=deformation?deformation.GetComponent<Renderer>():null;
        var control=GameObject.Find("Green wall")?.GetComponent<Renderer>();
        if(!target || target.name!="Audit deforming occluder" || !control || target.sharedMaterials.Length!=1)
            throw new Exception("Frozen deformation target/control absent");
        targetMatrix=target.localToWorldMatrix;
        var feature=(HybridLumenGIRendererFeature)capture.feature;
        var settings=(HybridLumenGIRendererFeature.Settings)typeof(HybridLumenGIRendererFeature).GetField("settings",Fields).GetValue(feature);
        settings.preferHardwareTracing=true;settings.exactSoftwareTracing=true;
        settings.measureGpuCost=false;settings.adaptiveGpuBudget=false;settings.targetGpuMilliseconds=0;
        feature.SetActive(true);capture.featureOff=false;capture.indirectOnly=false;capture.totalFrames=256;capture.quitWhenComplete=true;
        capture.label="deformation-snapshot-propagation-01";
        if(SystemInfo.graphicsDeviceType!=GraphicsDeviceType.Direct3D12 || !SystemInfo.supportsInlineRayTracing)
            throw new Exception("DX12 inline tracing required");
        filter=deformation.GetComponent<MeshFilter>();original=filter.sharedMesh;
        dynamicMesh=UnityEngine.Object.Instantiate(original);filter.sharedMesh=dynamicMesh;
        DeformationEventTap.Configure(capture.camera,target,control,deformation);
        deformation.RequestCapture(dynamicMesh); // Same initial setup as the existing Functional probe.
    }
    public static void Apply(int logicalFrame)
    {
        if(closed || logicalFrame!=lastLogical+1 || logicalFrame>=256)throw new Exception("Deformation-event sequence mismatch");
        lastLogical=logicalFrame;
        if(logicalFrame==0)
        {
            capture.camera.transform.SetPositionAndRotation(capture.colorView.position,capture.colorView.rotation);
            cameraPosition=capture.camera.transform.position;cameraRotation=capture.camera.transform.rotation;doorPosition=capture.door.localPosition;
        }
        if(capture.camera.transform.position!=cameraPosition || capture.camera.transform.rotation!=cameraRotation ||
            capture.door.localPosition!=doorPosition || deformation.GetComponent<Renderer>().localToWorldMatrix!=targetMatrix)
            throw new Exception("Frozen camera/door/target transform changed");
        DeformationEventTap.BeginLogicalFrame(logicalFrame,Time.frameCount,DirectoryPath);
        if(logicalFrame==0)DeformationEventTap.SaveVisibleInput("initial",dynamicMesh);
        if(logicalFrame==160)
        {
            DeformationEventTap.RequireEventCoverage();
            if(applied)throw new Exception("Repeated deformation event");
            DeformationEventTap.SaveVisibleInput("before-event",dynamicMesh);
            var vertices=dynamicMesh.vertices;
            for(int i=0;i<vertices.Length;i++)if(vertices[i].y>0)vertices[i].x+=0.8f;
            dynamicMesh.vertices=vertices;dynamicMesh.RecalculateBounds();dynamicMesh.RecalculateNormals();
            DeformationEventTap.SaveVisibleInput("after-event",dynamicMesh);
            deformation.RequestCapture(dynamicMesh);applied=true;
            DeformationEventTap.RecordEvent();
        }
    }
    public static void Rendered(int logicalFrame,int engineFrame)
    {
        if(!Requested || closed)return;
        if(logicalFrame!=lastLogical || engineFrame!=Time.frameCount)throw new Exception("Deformation capture receipt mismatch");
        DeformationEventTap.FrameEnded(logicalFrame,engineFrame);
    }
    public static void Close(bool collected)
    {
        if(!Requested || closed)return;closed=true;
        if(capture && capture.camera)capture.camera.enabled=false;
        try{DeformationEventTap.Finish(collected && applied && lastLogical==255);}
        finally
        {
            Exception error=null;
            try{if(filter && original)filter.sharedMesh=original;}catch(Exception e){error=e;}
            try{if(dynamicMesh){var owned=dynamicMesh;dynamicMesh=null;HybridLumenGIResourceRetirement.Retire(()=>UnityEngine.Object.Destroy(owned));}}
            catch(Exception e){error=error??e;}
            if(error!=null)throw error;
        }
    }
}
