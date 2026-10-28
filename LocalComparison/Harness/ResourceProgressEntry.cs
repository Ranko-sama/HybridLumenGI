using System.IO;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;

public static class ResourceProgressEntry
{
    public static void Play()
    {
        ThinWallEditor.Prepare();
        var capture=Object.FindFirstObjectByType<ComparisonCapture>();
        capture.totalFrames=12;capture.label="resource-shutdown-01c-12-frame-exit";
        EditorUtility.SetDirty(capture);var scene=UnityEngine.SceneManagement.SceneManager.GetActiveScene();
        EditorSceneManager.MarkSceneDirty(scene);EditorSceneManager.SaveScene(scene);
        File.WriteAllText(Path.Combine(capture.outputRoot,"resource-probe-contract.json"),"{\"frames\":12,\"thinWallStageObserverEnabled\":false,\"scope\":\"Independent resource exit probe; does not change A/B/C 120-frame contract\",\"exit\":\"Natural ComparisonCapture.Finish -> EditorApplication.Exit\"}");
        EditorApplication.EnterPlaymode();
    }
}
