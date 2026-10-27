#if UNITY_EDITOR
using System;
using System.IO;
using System.Reflection;
using UnityEditor;
using UnityEngine;
using HybridLumenGI;

// Two finite natural Play exits with one genuine re-entry. No manual product disposal.
public sealed class ResourceLifecycleProbe : MonoBehaviour
{
    ComparisonCapture capture;double started;bool leaving;
    void Start(){capture=GetComponent<ComparisonCapture>();started=Time.realtimeSinceStartupAsDouble;}
    void Update()
    {
        if(leaving)return;
        try
        {
            if(Time.realtimeSinceStartupAsDouble-started>950)throw new Exception("Lifecycle capture timeout");
            if(!(bool)typeof(ComparisonCapture).GetField("closing",BindingFlags.Instance|BindingFlags.NonPublic).GetValue(capture))return;
            var feature=(HybridLumenGIRendererFeature)capture.feature;bool found=false;
            foreach(var d in feature.GetDiagnostics())if(d.camera==capture.camera.name&&d.exactSoftwareGeometry&&d.softwareGeometryBytes>0)found=true;
            if(!found||!feature.isActive)throw new Exception("Active exact software resource coverage missing");
            if(HybridLumenGIDeformedMesh.PublishedSnapshotCount==0)throw new Exception("No live deformation snapshot before natural exit");
            if(HybridLumenGIResourceRetirement.AdmissionClosed)throw new Exception("Admission already closed before natural exit");
            ResourceLifecycleEditor.Append("before-natural-play-exit");ResourceShutdownTrace.Mark("lifecycle-before-natural-play-exit");
            SessionState.SetString(ResourceLifecycleEditor.StateKey,"await-edit");leaving=true;
            EditorApplication.ExitPlaymode();
        }
        catch(Exception e){leaving=true;ResourceLifecycleEditor.Fail(e.ToString());}
    }
}

[InitializeOnLoad]
public static class ResourceLifecycleEditor
{
    public const string StateKey="HLGI.ResourceShutdown01b.Phase";
    const string CycleKey="HLGI.ResourceShutdown01b.Cycle";
    static readonly string domain=Guid.NewGuid().ToString("N");
    static bool finishing;
    [Serializable] class Row
    {
        public string utc,stage,domain;public int cycle,engineFrame,pending,owned,failed,unknown,withdrawalFailed,materialBatches,arenas,jobs,published,cleanupFailed;
        public long materialBytes,arenaBytes,deformationBytes;public bool submissionUncertain,admissionClosed;
    }
    static string Arg(string key){var a=Environment.GetCommandLineArgs();int i=Array.IndexOf(a,key);return i>=0&&i+1<a.Length?a[i+1]:null;}
    static ResourceLifecycleEditor()
    {
        EditorApplication.playModeStateChanged+=state=>
        {
            if(SessionState.GetString(StateKey,"")=="await-edit"&&state==PlayModeStateChange.EnteredEditMode)EditorApplication.delayCall+=ReturnedToEdit;
        };
    }
    public static void StartPlay()
    {
        var capture=UnityEngine.Object.FindFirstObjectByType<ComparisonCapture>();
        capture.quitWhenComplete=false;capture.gameObject.AddComponent<ResourceLifecycleProbe>();
        EditorUtility.SetDirty(capture);UnityEditor.SceneManagement.EditorSceneManager.MarkSceneDirty(capture.gameObject.scene);
        UnityEditor.SceneManagement.EditorSceneManager.SaveScene(capture.gameObject.scene);
        SessionState.SetInt(CycleKey,0);SessionState.SetString(StateKey,"running");EditorApplication.EnterPlaymode();
    }
    public static void Append(string stage)
    {
        string root=Arg("-comparisonOutput");Directory.CreateDirectory(root);
        var row=new Row{utc=DateTime.UtcNow.ToString("o"),stage=stage,domain=domain,cycle=SessionState.GetInt(CycleKey,0),engineFrame=Time.frameCount,
            pending=HybridLumenGIResourceRetirement.PendingCount,owned=HybridLumenGIResourceRetirement.OwnedCount,
            failed=HybridLumenGIResourceRetirement.FailedCount,unknown=HybridLumenGIResourceRetirement.UnknownSubmissionCount,
            withdrawalFailed=HybridLumenGIResourceRetirement.FailedWithdrawalCount,submissionUncertain=HybridLumenGIResourceRetirement.SubmissionUncertain,
            admissionClosed=HybridLumenGIResourceRetirement.AdmissionClosed,materialBytes=HybridLumenGIHitMaterialBatch.TotalMaterialBytes,
            materialBatches=HybridLumenGIHitMaterialBatch.ResidentBatchCount,arenaBytes=HybridLumenGIRayTexturePool.TotalAllocatedBytes,
            arenas=HybridLumenGIRayTexturePool.ResidentBatchCount,deformationBytes=HybridLumenGIDeformedMesh.ReservedBytes,
            jobs=HybridLumenGIDeformedMesh.PendingWorkerCount,published=HybridLumenGIDeformedMesh.PublishedSnapshotCount,cleanupFailed=HybridLumenGIDeformedMesh.FailedCleanupCount};
        File.AppendAllText(Path.Combine(root,"lifecycle.jsonl"),JsonUtility.ToJson(row)+"\n");
    }
    static void ReturnedToEdit()
    {
        Append("natural-play-exit-returned");ResourceShutdownTrace.Mark("lifecycle-natural-play-exit-returned");
        if(HybridLumenGIResourceRetirement.OwnedCount!=0||HybridLumenGIResourceRetirement.PendingCount!=0||HybridLumenGIResourceRetirement.SubmissionUncertain||
            HybridLumenGIResourceRetirement.FailedCount!=0||HybridLumenGIResourceRetirement.FailedWithdrawalCount!=0||
            HybridLumenGIHitMaterialBatch.TotalAllocatedBytes!=0||HybridLumenGIDeformedMesh.ReservedBytes!=0||HybridLumenGIDeformedMesh.PendingWorkerCount!=0)
        {Fail("An owner remains after natural Play exit; no new Play will hide it");return;}
        if(SessionState.GetInt(CycleKey,0)==0)
        {
            SessionState.SetInt(CycleKey,1);SessionState.SetString(StateKey,"running");Append("reenter-play-request");EditorApplication.EnterPlaymode();return;
        }
        if(finishing)return;finishing=true;SessionState.SetString(StateKey,"complete");
        Debug.Log("RESOURCE_LIFECYCLE_COMPLETE two natural Play exits and one re-entry. Separately verify old-domain ticket/native evidence.");EditorApplication.Exit(0);
    }
    public static void Fail(string error)
    {Append("FAILED: "+error);SessionState.SetString(StateKey,"failed");Debug.LogError(error);EditorApplication.Exit(1);}
}
#endif
