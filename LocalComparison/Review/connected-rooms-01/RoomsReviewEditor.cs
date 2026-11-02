using System;
using System.IO;
using System.Linq;
using HybridLumenGI;
using HybridLumenGI.Editor;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public static class RoomsReviewEditor
{
    const string Source = "Assets/UnifiedRelease74/Generated/Variant/UnifiedSample.unity";
    const string Rooms = "Assets/UnifiedRelease74/Generated/Variant/ConnectedRooms.unity";
    public static void Generate()
    {
        var scene = EditorSceneManager.OpenScene(Source);
        if (AssetDatabase.LoadMainAssetAtPath(Rooms) || File.Exists(Rooms)) throw new IOException("Preserve prior generated scene.");
        if (HybridLumenGIConnectedRoomsBuilder.CreateCopy(scene) != Rooms) throw new IOException("Unexpected generated scene path.");
    }
    public static void Capture()
    {
        var args = Environment.GetCommandLineArgs();
        int i = Array.IndexOf(args, "-roomOutput");
        if (i < 0 || i + 1 >= args.Length || !Path.IsPathRooted(args[i + 1]) || Directory.Exists(args[i + 1]))
            throw new ArgumentException("Expected a new absolute capture directory.");
        string output = args[i + 1];
        Directory.CreateDirectory(output);
        var scene = EditorSceneManager.OpenScene(Rooms);
        var camera = UnityEngine.Object.FindFirstObjectByType<Camera>();
        var renderer = AssetDatabase.LoadAssetAtPath<UniversalRendererData>("Assets/UnifiedRelease74/Generated/Renderer.asset");
        var feature = renderer.rendererFeatures.OfType<HybridLumenGIRendererFeature>().Single();
        var view = new GameObject("Entry floor view").transform;
        view.SetPositionAndRotation(new Vector3(0, 1.3f, -5.55f), Quaternion.LookRotation(Vector3.down, Vector3.forward));
        camera.transform.SetPositionAndRotation(view.position, view.rotation);
        var capture = camera.gameObject.AddComponent<ComparisonCapture>();
        capture.camera = camera; capture.feature = feature; capture.door = view;
        capture.doorOffset = Vector3.zero; // This marker fixes the camera; only the actual partition door moves.
        capture.colorView = capture.thinView = capture.blackView = view;
        capture.lights = Array.Empty<Light>();
        bool closeDuringRun = Array.IndexOf(args, "-closePortalAt120") >= 0;
        capture.indirectOnly = true; capture.totalFrames = closeDuringRun ? 240 : 120; capture.outputRoot = output;
        capture.label = "Connected rooms, entry floor"; capture.quitWhenComplete = true;
        var driver = camera.gameObject.AddComponent<RoomsCaptureRequest>();
        driver.closeDuringRun = closeDuringRun;
        driver.open = closeDuringRun || Array.IndexOf(args, "-openPortal") >= 0; driver.output = output;
        if (!EditorSceneManager.SaveScene(scene, "Assets/HLGIRoomsReview/RoomView.unity", true)) throw new IOException("Scene copy failed.");
        EditorSceneManager.OpenScene("Assets/HLGIRoomsReview/RoomView.unity");
        EditorApplication.EnterPlaymode();
    }
}
