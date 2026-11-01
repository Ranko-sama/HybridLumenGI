using System;
using System.IO;
using System.Linq;
using HybridLumenGI;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

// Only the copy under the temporary Assets root is edited. Meshes, charts,
// light and feature are the saved inputs from the finite-wall comparison.
public static class OffscreenWallEditor
{
    const string Root = "Assets/HLGIOffscreenWall01";
    [Serializable] sealed class Setup
    {
        public string order;
        public Vector3 camera, forward, up;
        public float fov, aspect;
        public Vector3[] wallWorld;
        public Vector2[] wallUv;
        public bool wallIntersectsFrustum, floorIntersectsFrustum;
    }
    public static void Run()
    {
        var args = Environment.GetCommandLineArgs();
        int index = Array.IndexOf(args, "-wallOutput");
        if (index < 0 || index + 1 >= args.Length || !Path.IsPathRooted(args[index + 1]))
            throw new ArgumentException("Expected an absolute output directory.");
        string output = args[index + 1];
        if (Directory.Exists(output)) throw new IOException("Preserve the existing capture.");
        Directory.CreateDirectory(output);
        bool swap = Array.IndexOf(args, "-swapWall") >= 0;
        string order = swap ? "BlueRed" : "RedBlue";
        string assets = Root + "/Generated/";
        var pipeline = AssetDatabase.LoadAssetAtPath<UniversalRenderPipelineAsset>(assets + "Pipeline.asset");
        var renderer = AssetDatabase.LoadAssetAtPath<UniversalRendererData>(assets + "Renderer.asset");
        var feature = renderer.rendererFeatures.OfType<HybridLumenGIRendererFeature>().Single();
        if (!pipeline || !feature.isActive || QualitySettings.activeColorSpace != ColorSpace.Linear ||
            SystemInfo.graphicsDeviceType != GraphicsDeviceType.Direct3D12)
            throw new InvalidOperationException("Expected the saved GI feature and Linear DX12.");
        QualitySettings.renderPipeline = pipeline;
        var scene = EditorSceneManager.OpenScene(assets + "FiniteWall.unity");
        UnityEngine.Object.DestroyImmediate(GameObject.Find("FiniteWallReferenceHost"));
        var wall = GameObject.Find("ReferenceWall").GetComponent<MeshRenderer>();
        var floor = GameObject.Find("ReferenceFloor").GetComponent<MeshRenderer>();
        var camera = GameObject.Find("FiniteWallReferenceCamera").GetComponent<Camera>();
        var light = GameObject.Find("WhiteDirectionalToPositiveX").GetComponent<Light>();
        var mesh = wall.GetComponent<MeshFilter>().sharedMesh;
        var wallMaterial = new Material(wall.sharedMaterial);
        var texture = new Texture2D(8, 2, TextureFormat.RGBA32, false, true) {
            name = order, filterMode = FilterMode.Point, wrapMode = TextureWrapMode.Clamp, anisoLevel = 1 };
        var red = new Color32(204, 13, 13, 255);
        var blue = new Color32(13, 13, 204, 255);
        var pixels = new Color32[16];
        for (int i = 0; i < pixels.Length; i++) pixels[i] = (i % 8 < 4) != swap ? red : blue;
        texture.SetPixels32(pixels);
        texture.Apply(false, false);
        AssetDatabase.CreateAsset(texture, Root + "/" + order + ".asset");
        wallMaterial.SetTexture("_BaseMap", texture);
        AssetDatabase.CreateAsset(wallMaterial, Root + "/" + order + ".mat");
        wall.sharedMaterial = wallMaterial;
        RenderSettings.skybox = null;
        RenderSettings.ambientMode = AmbientMode.Flat;
        RenderSettings.ambientLight = Color.black;
        RenderSettings.ambientIntensity = RenderSettings.reflectionIntensity = 0;
        RenderSettings.sun = light;
        camera.transform.SetPositionAndRotation(new Vector3(.85f, 1.5f, 0), Quaternion.LookRotation(Vector3.down, Vector3.left));
        camera.aspect = 640f / 360f;
        var planes = GeometryUtility.CalculateFrustumPlanes(camera);
        var setup = new Setup { order = order, camera = camera.transform.position, forward = camera.transform.forward,
            up = camera.transform.up, fov = camera.fieldOfView, aspect = camera.aspect,
            wallWorld = mesh.vertices.Select(v => wall.transform.TransformPoint(v)).ToArray(), wallUv = mesh.uv,
            wallIntersectsFrustum = GeometryUtility.TestPlanesAABB(planes, wall.bounds),
            floorIntersectsFrustum = GeometryUtility.TestPlanesAABB(planes, floor.bounds) };
        File.WriteAllText(Path.Combine(output, "setup.json"), JsonUtility.ToJson(setup, true));
        if (setup.wallIntersectsFrustum || !setup.floorIntersectsFrustum || camera.orthographic)
            throw new InvalidOperationException("The floor must be visible and the entire wall outside the perspective frustum.");
        var capture = camera.gameObject.AddComponent<ComparisonCapture>();
        capture.camera = camera; capture.feature = feature;
        capture.door = capture.colorView = capture.thinView = capture.blackView = camera.transform;
        capture.lights = new[] { light };
        capture.outputRoot = output; capture.label = "Offscreen finite wall " + order;
        capture.indirectOnly = true; capture.totalFrames = 31; capture.quitWhenComplete = true;
        camera.gameObject.AddComponent<OffscreenWallRequest>();
        if (!EditorSceneManager.SaveScene(scene, Root + "/View" + order + ".unity")) throw new IOException("Cannot save capture scene.");
        AssetDatabase.SaveAssets();
        EditorApplication.EnterPlaymode();
    }
}
