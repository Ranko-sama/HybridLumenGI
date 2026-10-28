using System;
using System.Linq;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using HybridLumenGI;

public static class StreamingAuditEditor
{
    public static void Prepare()
    {
        const string path="Assets/RuntimeAudit/Streaming.unity";
        if(System.IO.File.Exists(path)){EditorSceneManager.OpenScene(path);return;}
        ComparisonRunnerEditor.Prepare();var scene=UnityEngine.SceneManagement.SceneManager.GetActiveScene();
        var capture=UnityEngine.Object.FindFirstObjectByType<ComparisonCapture>();
        var so=new SerializedObject(capture.feature);so.FindProperty("settings.nearDistance").floatValue=8;
        so.ApplyModifiedPropertiesWithoutUndo();EditorUtility.SetDirty(capture.feature);
        var detail=GameObject.Find("White receiver").GetComponent<HybridLumenGIProxy>();
        var far=UnityEngine.Object.Instantiate(detail.gameObject,detail.transform.parent);far.name="Streaming aggregate";
        var parent=far.GetComponent<HybridLumenGIProxy>();var po=new SerializedObject(parent);po.FindProperty("farFieldOnly").boolValue=true;po.ApplyModifiedPropertiesWithoutUndo();
        detail.SetHLODParent(parent);Selection.objects=new UnityEngine.Object[]{detail.gameObject,far};
        if(!EditorApplication.ExecuteMenuItem("Tools/Hybrid Lumen GI/Export Selected Proxies As Asset Pages"))throw new Exception("Asset page export menu unavailable");
        var rig=Selection.activeGameObject;var driver=rig.GetComponent<HybridLumenGIAssetPageStreamer>();if(!driver)throw new Exception("Export did not produce a streamer");
        detail.gameObject.SetActive(false);far.SetActive(false);rig.SetActive(true);
        var bindings=rig.GetComponentsInChildren<HybridLumenGIStreamedRepresentation>(true);
        var probe=capture.gameObject.AddComponent<StreamingAuditProbe>();probe.capture=capture;probe.streamer=driver;
        probe.detail=bindings.Single(x=>x.Proxy.HLODParent!=null);probe.aggregate=bindings.Single(x=>x.Proxy.HLODParent==null);
        capture.label="streaming-pages-hlod";EditorSceneManager.SaveScene(scene,path);AssetDatabase.SaveAssets();
    }
    public static void Play(){Prepare();EditorApplication.EnterPlaymode();}
}
