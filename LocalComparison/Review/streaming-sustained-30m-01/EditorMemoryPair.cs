#if UNITY_EDITOR
using System;
using System.Collections.Generic;
using System.IO;
using HybridLumenGI;
using Unity.Profiling.Memory;
using UnityEditor;
using UnityEditor.Networking.PlayerConnection;
using UnityEditor.Profiling.Memory.Experimental;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.SceneManagement;

// Temporary Editor entry. Raw snapshots are the primary evidence. Decode both only after capture.
[InitializeOnLoad]
public static class EditorMemoryPair
{
    const string ScenePath = "Assets/UnifiedRelease74/Generated/Variant/UnifiedSample.unity";
    const string PipelineGuid = "ca5b7ea101c75f645851495aea1b326c";
    const string Key = "HLGI.EditorMemoryPair.";
    enum Stage { Idle, Before, TakingBefore, EnterPlay, Use, ExitPlay, After, TakingAfter, Read }
    static Stage Current => (Stage)SessionState.GetInt(Key + "stage", 0);
    static string Output => SessionState.GetString(Key + "output", "");
    static int editTicks, lastEngineFrame = -1;
    static HybridLumenGIUnifiedSample sample;
    static Camera camera;
    static RenderTexture target;
    static bool cameraWasEnabled;

    [Serializable] sealed class ObjectRow { public string label, type; public int instanceId; public bool persistent; public ulong bytes; }
    [Serializable] sealed class Endpoint
    {
        public string file, scene, pipeline, unityVersion;
        public int nativeObjectCount;
        public List<ObjectRow> namedObjects = new List<ObjectRow>();
    }
    [Serializable] sealed class Result
    {
        public string status, error;
        public string scope = "Local Editor NativeObjects with HLGI / HybridLumenGI / Hybrid Lumen GI in their names. Persistent is the native persistence flag. Unnamed allocations and total GI memory are outside this table.";
        public Endpoint before, after;
    }

    static EditorMemoryPair()
    {
        EditorApplication.update += Tick;
        EditorApplication.playModeStateChanged += ModeChanged;
    }
    public static void Run()
    {
        try
        {
            Require(Current == Stage.Idle && !EditorApplication.isPlayingOrWillChangePlaymode, "Expected an idle Edit session.");
            string[] args = Environment.GetCommandLineArgs();
            int i = Array.IndexOf(args, "-hlgiMemoryPairOutput");
            Require(i >= 0 && i + 1 < args.Length && Path.IsPathRooted(args[i + 1]), "A fresh absolute output path is required.");
            string output = Path.GetFullPath(args[i + 1]);
            Require(!Directory.Exists(output) && !File.Exists(output), "Output already exists.");
            Directory.CreateDirectory(output);
            SessionState.SetString(Key + "output", output);
            Require(!EditorSettings.enterPlayModeOptionsEnabled ||
                (EditorSettings.enterPlayModeOptions & (EnterPlayModeOptions.DisableDomainReload | EnterPlayModeOptions.DisableSceneReload)) == 0,
                "Expected ordinary domain and scene reload.");
            for (int n = 0; n < SceneManager.sceneCount; n++)
                Require(!SceneManager.GetSceneAt(n).isDirty, "An open scene has unsaved edits.");
            EditorSceneManager.OpenScene(ScenePath, OpenSceneMode.Single);
            Set(Stage.Before);
        }
        catch (Exception e) { Fail(e); }
    }
    static void Set(Stage stage)
    {
        SessionState.SetInt(Key + "stage", (int)stage);
        SessionState.SetFloat(Key + "deadline", (float)(EditorApplication.timeSinceStartup + 360));
        editTicks = 0;
    }
    static void ModeChanged(PlayModeStateChange change)
    {
        if (Current == Stage.EnterPlay && change == PlayModeStateChange.EnteredPlayMode) Set(Stage.Use);
        else if (Current == Stage.ExitPlay && change == PlayModeStateChange.EnteredEditMode) Set(Stage.After);
    }
    static void Tick()
    {
        Stage stage = Current;
        if (stage == Stage.Idle) return;
        try
        {
            Require(EditorApplication.timeSinceStartup < SessionState.GetFloat(Key + "deadline", 0), "Timeout in " + stage);
            if (stage == Stage.Before || stage == Stage.After)
            {
                if (++editTicks >= 3 && !EditorApplication.isCompiling && !EditorApplication.isUpdating)
                    Take(stage == Stage.Before);
            }
            else if (stage == Stage.Use) UseSample();
            else if (stage == Stage.Read)
            {
                var result = new Result { status = "collected", before = Read("before.snap"), after = Read("after.snap") };
                Finish(result, 0);
            }
        }
        catch (Exception e) { Fail(e); }
    }
    static void Take(bool before)
    {
        var scene = SceneManager.GetActiveScene();
        Require(!EditorApplication.isPlayingOrWillChangePlaymode && SceneManager.sceneCount == 1 &&
            scene.isLoaded && scene.path == ScenePath && !scene.isDirty, "Expected the same saved scene in Edit.");
        Require(AssetDatabase.AssetPathToGUID(AssetDatabase.GetAssetPath(GraphicsSettings.currentRenderPipeline)) == PipelineGuid,
            "Expected the saved sample pipeline at both endpoints.");
        Require(EditorConnection.instance.ConnectedPlayers.Count == 0, "A connected Player could be the snapshot target.");
        Require(SystemInfo.graphicsDeviceType == GraphicsDeviceType.Direct3D12, "Expected a real DX12 Editor.");
        Require(before || File.Exists(Path.Combine(Output, "ready-ledger.json")), "No real near publication was recorded.");
        string path = Path.Combine(Output, before ? "before.snap" : "after.snap");
        Require(!File.Exists(path), "Snapshot already exists.");
        Stage taking = before ? Stage.TakingBefore : Stage.TakingAfter;
        Set(taking);
        Unity.Profiling.Memory.MemoryProfiler.TakeSnapshot(path, (actual, ok) =>
        {
            try
            {
                Require(Current == taking && ok && string.Equals(Path.GetFullPath(actual), path, StringComparison.OrdinalIgnoreCase)
                    && File.Exists(path) && new FileInfo(path).Length > 0, "Native capture did not produce " + path);
                if (before)
                {
                    Set(Stage.EnterPlay);
                    EditorApplication.delayCall += EditorApplication.EnterPlaymode;
                }
                else Set(Stage.Read);
            }
            catch (Exception e) { Fail(e); }
        }, CaptureFlags.NativeObjects);
    }
    static void UseSample()
    {
        Require(EditorApplication.isPlaying && SceneManager.GetActiveScene().path == ScenePath, "Expected the saved sample in Play.");
        if (Time.frameCount == lastEngineFrame) return;
        lastEngineFrame = Time.frameCount;
        if (!sample)
        {
            var samples = UnityEngine.Object.FindObjectsByType<HybridLumenGIUnifiedSample>(FindObjectsSortMode.None);
            Require(samples.Length == 1 && samples[0].isActiveAndEnabled, "Expected one enabled unified sample.");
            sample = samples[0];
            camera = new SerializedObject(sample).FindProperty("targetCamera").objectReferenceValue as Camera;
            Require(camera && camera.enabled && !camera.targetTexture, "Expected the ordinary enabled screen camera.");
            sample.GoNear();
            if (Application.isBatchMode)
            {
                cameraWasEnabled = camera.enabled;
                target = new RenderTexture(960, 540, 24, RenderTextureFormat.ARGBHalf, RenderTextureReadWrite.Linear)
                    { name = "Editor memory pair request destination", antiAliasing = 1 };
                Require(target.Create(), "Render destination unavailable.");
                camera.enabled = false;
                camera.targetTexture = target;
            }
        }
        if (target)
        {
            var request = new RenderPipeline.StandardRequest { destination = target };
            if (!RenderPipeline.SupportsRenderRequest(camera, request)) return;
            RenderPipeline.SubmitRenderRequest(camera, request);
        }
        var ledger = sample.CaptureLedger();
        if (!ledger.featureEnabled || ledger.actualBackend != "DXR" || ledger.cameraGi == null ||
            ledger.cameraGi.frame <= 0 || ledger.publicationWorkFrame <= 0 ||
            ledger.publicationEngineFrame < Time.frameCount - 1 || ledger.status != "complete details published" ||
            ledger.requestedRepresentation != "details" || ledger.availableRepresentation != "details" ||
            ledger.visibleMembers != 3 || ledger.boundMembers != 4 || ledger.pagesReady <= 0 || ledger.pagesFailed != 0) return;
        File.WriteAllText(Path.Combine(Output, "ready-ledger.json"), JsonUtility.ToJson(ledger, true));
        ReleaseDestination();
        Set(Stage.ExitPlay);
        EditorApplication.ExitPlaymode();
    }
    static void ReleaseDestination()
    {
        if (!target) return;
        if (camera) { camera.targetTexture = null; camera.enabled = cameraWasEnabled; }
        UnityEngine.Object.Destroy(target);
        target = null;
    }

#pragma warning disable 618 // The Editor 6000.0 installed reader is used only by this temporary probe.
    static T[] Values<T>(ArrayEntries<T> column)
    {
        uint count = column.GetNumEntries();
        var values = new T[checked((int)count)];
        if (count > 0) column.GetEntries(0, count, ref values);
        return values;
    }
    static Endpoint Read(string file)
    {
        using (var snap = PackedMemorySnapshot.Load(Path.Combine(Output, file)))
        {
            var types = Values(snap.nativeTypes.typeName);
            var labels = Values(snap.nativeObjects.objectName);
            var typeIds = Values(snap.nativeObjects.nativeTypeArrayIndex);
            var instanceIds = Values(snap.nativeObjects.instanceId);
            var sizes = Values(snap.nativeObjects.size);
            var flags = Values(snap.nativeObjects.flags);
            Require(labels.Length > 0 && labels.Length == sizes.Length && labels.Length == flags.Length &&
                labels.Length == typeIds.Length && labels.Length == instanceIds.Length, "Incomplete native-object columns in " + file);
            var point = new Endpoint { file = file, scene = ScenePath, pipeline = PipelineGuid,
                unityVersion = Application.unityVersion, nativeObjectCount = labels.Length };
            for (int i = 0; i < labels.Length; i++)
            {
                string n = labels[i] ?? "";
                if (n.IndexOf("HLGI", StringComparison.OrdinalIgnoreCase) < 0 &&
                    n.IndexOf("HybridLumenGI", StringComparison.OrdinalIgnoreCase) < 0 &&
                    n.IndexOf("Hybrid Lumen GI", StringComparison.OrdinalIgnoreCase) < 0) continue;
                point.namedObjects.Add(new ObjectRow { label = n, type = types[typeIds[i]], instanceId = instanceIds[i], bytes = sizes[i],
                    persistent = (flags[i] & ObjectFlags.IsPersistent) != 0 });
            }
            return point;
        }
    }
#pragma warning restore 618
    static void Require(bool condition, string message)
    { if (!condition) throw new InvalidOperationException(message); }
    static void Fail(Exception e)
    {
        Debug.LogException(e);
        ReleaseDestination();
        Finish(new Result { status = "incomplete", error = Current + ": " + e.Message }, 1);
    }
    static void Finish(Result result, int exit)
    {
        string output = Output;
        SessionState.EraseString(Key + "output");
        Set(Stage.Idle);
        try
        {
            if (!string.IsNullOrEmpty(output))
                File.WriteAllText(Path.Combine(output, "result.json"), JsonUtility.ToJson(result, true));
        }
        finally { EditorApplication.delayCall += () => EditorApplication.Exit(exit); }
    }
}
#endif
