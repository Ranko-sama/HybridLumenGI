using System;
using System.Collections;
using System.IO;
using System.Reflection;
using System.Text;
using UnityEngine;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

// Shared old/new runner. No HybridLumenGI implementation types or algorithm writes.
[DefaultExecutionOrder(-500)]
public sealed class ComparisonCapture : MonoBehaviour
{
    public Camera camera;
    public ScriptableRendererFeature feature;
    public Transform door;
    public Light[] lights;
    public Transform colorView, thinView, blackView;
    public string outputRoot, label;
    public bool featureOff, indirectOnly, quitWhenComplete = true;
    public int totalFrames = 720;
    public Vector3 doorOffset = new Vector3(2.2f, 0, 0);
    const int Width = 640, Height = 360;
    [Serializable] sealed class Run
    {
        public string status = "running", label, startedUtc, completedUtc, error, unity, urpAssembly, api, gpu, driver, featureType, actualMode, scene;
        public int requestedFrames, renderedFrames, captures, errors, width = Width, height = Height;
        public int startupEngineFrame = -1, firstRenderEngineFrame = -1, startupFrameLimit = 120;
        public double firstRenderWaitSeconds, startupSecondsLimit = 900;
        public bool fullSequenceCompleted, featureOff, indirectOnly, graphicsUVStartsAtTop;
        public string format = "R32G32B32A32_SFloat Linear; raw little-endian RGBA32F, unflipped GPU rows",
            png = "Preview only: max(0,RGB)/(1+max(0,RGB)), then LinearToGammaSpace; no row flip",
            timing = "FrameTimingManager whole-frame samples, potentially delayed/repeated, capture/IO contaminated; zero or nonfinite is missing, not GI timing",
            scope = "Collection only; not image quality, successful GI passes, DXR execution, or performance acceptance";
        public float ambientIntensity, reflectionIntensity;
        public Color ambientLight;
        public bool fog, skybox;
    }
    [Serializable] sealed class Frame
    {
        public int logicalFrame, engineFrame;
        public string stage, diagnosticsStatus, diagnosticsJson, timingTimestamp, raw, exr, png;
        public Vector3 cameraPosition, doorLocalPosition;
        public Quaternion cameraRotation;
        public Matrix4x4 projection;
        public LightState[] lights;
        public double cpuFrameMs, gpuFrameMs, meanLuminance, maxRgb;
        public bool cpuTimingValid, gpuTimingValid, timingFresh, captured;
    }
    [Serializable] sealed class LightState
    { public string name, type; public bool enabled; public float intensity, range; public Color color; public Vector3 position; public Quaternion rotation; }
    [Serializable] sealed class Log { public string utc, type, message, stack; public int logicalFrame, engineFrame; }
    Run run = new Run(); StreamWriter frames, logs; string directory, featureJson;
    RenderTexture target, oldTarget; UniversalAdditionalCameraData data;
    Vector3 oldPosition, doorOrigin; Quaternion oldRotation; bool[] oldLights;
    bool oldHdr, oldMsaa, oldDynamic, oldPost, oldEnabled, oldBackground, configured, running, closing, receipt, pending;
    int logicalFrame, appliedEngine, lastEngine = -1; ulong lastTimingTimestamp; double startupTime;
    AsyncGPUReadbackRequest readback; readonly FrameTiming[] timings = new FrameTiming[1];
    void Start()
    {
        try
        {
            if (string.IsNullOrWhiteSpace(outputRoot) || !Path.IsPathRooted(outputRoot)) throw new Exception("Set an absolute outputRoot.");
            string root = Path.GetFullPath(outputRoot);
            directory = Path.Combine(root, DateTime.UtcNow.ToString("yyyyMMdd-HHmmss") + "-" + Guid.NewGuid().ToString("N")); Directory.CreateDirectory(directory);
            frames = new StreamWriter(Path.Combine(directory, "frames.jsonl"), false, new UTF8Encoding(false)) { AutoFlush = true };
            logs = new StreamWriter(Path.Combine(directory, "unity-log.jsonl"), false, new UTF8Encoding(false)) { AutoFlush = true };
            Application.logMessageReceived += OnLog;
            if (!camera || !feature || !door || !colorView || !thinView || !blackView || lights == null || totalFrames < 1 || totalFrames > 720) throw new Exception("Missing scene references or invalid totalFrames (1..720).");
            if (feature.isActive == featureOff) throw new Exception("Feature active state differs from featureOff; configure it before Play.");
            if (QualitySettings.activeColorSpace != ColorSpace.Linear || !BitConverter.IsLittleEndian || !SystemInfo.supportsAsyncGPUReadback) throw new Exception("Requires Linear, little-endian, and GPU readback support.");
            data = camera.GetUniversalAdditionalCameraData();
            if (camera.stereoEnabled || data.renderType != CameraRenderType.Base || (data.cameraStack != null && data.cameraStack.Count != 0)) throw new Exception("Requires a single non-XR Base camera.");
            run.label = label; run.requestedFrames = totalFrames; run.featureOff = featureOff; run.indirectOnly = indirectOnly; run.startedUtc = DateTime.UtcNow.ToString("o");
            run.unity = Application.unityVersion; run.urpAssembly = typeof(UniversalRenderPipeline).Assembly.GetName().Version.ToString();
            run.api = SystemInfo.graphicsDeviceType.ToString(); run.gpu = SystemInfo.graphicsDeviceName; run.driver = SystemInfo.graphicsDeviceVersion;
            run.graphicsUVStartsAtTop = SystemInfo.graphicsUVStartsAtTop; run.featureType = feature.GetType().FullName; run.scene = camera.gameObject.scene.path;
            run.actualMode = (Member(Member(feature, "settings"), "debugView") ?? Member(feature, "debugView"))?.ToString() ?? "unknown";
            if (!featureOff && run.actualMode != "unknown" && run.actualMode != (indirectOnly ? "IndirectOnly" : "Final")) throw new Exception("Requested output mode differs from feature debugView.");
            run.ambientIntensity = RenderSettings.ambientIntensity; run.reflectionIntensity = RenderSettings.reflectionIntensity; run.ambientLight = RenderSettings.ambientLight; run.fog = RenderSettings.fog; run.skybox = RenderSettings.skybox != null;
            featureJson = JsonUtility.ToJson(feature, true); File.WriteAllText(Path.Combine(directory, "feature.json"), featureJson);
            oldTarget = camera.targetTexture; oldHdr = camera.allowHDR; oldMsaa = camera.allowMSAA; oldDynamic = camera.allowDynamicResolution; oldPost = data.renderPostProcessing; oldEnabled = camera.enabled;
            oldPosition = camera.transform.position; oldRotation = camera.transform.rotation; doorOrigin = door.localPosition;
            oldLights = new bool[lights.Length]; for (int i = 0; i < lights.Length; i++) { if (!lights[i]) throw new Exception("Null selected light."); oldLights[i] = lights[i].enabled; }
            oldBackground = Application.runInBackground; configured = true; Application.runInBackground = true;
            target = new RenderTexture(Width, Height, 24, RenderTextureFormat.ARGBFloat, RenderTextureReadWrite.Linear) { name = "Comparison Linear HDR", antiAliasing = 1, useMipMap = false, autoGenerateMips = false, useDynamicScale = false };
            if (!target.Create() || target.sRGB || target.graphicsFormat != GraphicsFormat.R32G32B32A32_SFloat) throw new Exception("Exact capture RT creation failed.");
            camera.targetTexture = target; camera.allowHDR = true; camera.allowMSAA = false; camera.allowDynamicResolution = false; camera.enabled = true; data.renderPostProcessing = false;
            startupTime = Time.realtimeSinceStartupAsDouble; run.startupEngineFrame = Time.frameCount;
            running = true; Apply(); SaveRun(); RenderPipelineManager.endCameraRendering += Rendered;
        }
        catch (Exception e) { Fail(e.ToString()); Finish(false); }
    }
    void Update()
    {
        if (!running) return;
        if (run.errors != 0) { Finish(false); return; }
        if (!receipt)
        {
            // Player initialization may advance engine frames before its first render.
            // Keep logical frame zero fixed; this grace never applies after a receipt.
            if (lastEngine < 0)
            {
                if (Time.frameCount - run.startupEngineFrame > run.startupFrameLimit || Time.realtimeSinceStartupAsDouble - startupTime > run.startupSecondsLimit)
                { Fail("Timed out waiting for first target-camera render receipt."); Finish(false); }
            }
            else if (Time.frameCount > appliedEngine) { Fail("Missing target-camera render receipt."); Finish(false); }
            return;
        }
        if (logicalFrame == totalFrames - 1) { Finish(true); return; }
        logicalFrame++; receipt = false; Apply();
    }
    void Apply()
    {
        appliedEngine = Time.frameCount;
        if(DeformationEventMode.Requested)
        {
            try{DeformationEventMode.Apply(logicalFrame);}catch(Exception e){HybridLumenGI.DeformationEventTap.Abort(e);Fail(e.ToString());Finish(false);}
            return;
        }
        float t = logicalFrame < 120 || logicalFrame >= 240 ? 0 : logicalFrame < 180 ? (logicalFrame - 120) / 59f : logicalFrame < 210 ? 1 : 1 - (logicalFrame - 210) / 29f;
        door.localPosition = doorOrigin + doorOffset * t;
        for (int i = 0; i < lights.Length; i++) lights[i].enabled = oldLights[i] && (logicalFrame < 240 || logicalFrame >= 300);
        Transform view = logicalFrame < 360 ? colorView : logicalFrame < 420 ? thinView : blackView; camera.transform.SetPositionAndRotation(view.position, view.rotation);
        FrameTimingManager.CaptureFrameTimings();
    }
    void Rendered(ScriptableRenderContext context, Camera renderedCamera)
    {
        if (!running || renderedCamera != camera) return;
        try
        {
            if (receipt || lastEngine == Time.frameCount || (lastEngine >= 0 && Time.frameCount != lastEngine + 1)) throw new Exception("Duplicate/skipped camera receipt.");
            if (camera.targetTexture != target || featureJson != JsonUtility.ToJson(feature, true)) throw new Exception("Capture target or feature settings changed.");
            if (lastEngine < 0)
            {
                double waited = Time.realtimeSinceStartupAsDouble - startupTime;
                if (Time.frameCount - run.startupEngineFrame > run.startupFrameLimit || waited > run.startupSecondsLimit) throw new Exception("First target-camera receipt exceeded startup limit.");
                run.firstRenderEngineFrame = Time.frameCount; run.firstRenderWaitSeconds = waited;
            }
            var f = new Frame { logicalFrame = logicalFrame, engineFrame = Time.frameCount, cameraPosition = camera.transform.position, cameraRotation = camera.transform.rotation, projection = camera.projectionMatrix, doorLocalPosition = door.localPosition,
                stage = logicalFrame < 120 ? "color-static" : logicalFrame < 240 ? "moving-door" : logicalFrame < 300 ? "lights-off" : logicalFrame < 360 ? "lights-restored" : logicalFrame < 420 ? "thin-wall-cut" : "sealed-room-cut", lights = new LightState[lights.Length] };
            for (int i = 0; i < lights.Length; i++) { var l = lights[i]; f.lights[i] = new LightState { name = l.name, type = l.type.ToString(), enabled = l.enabled, intensity = l.intensity, range = l.range, color = l.color, position = l.transform.position, rotation = l.transform.rotation }; }
            Diagnostics(f);
            if (FrameTimingManager.GetLatestTimings(1, timings) != 0)
            {
                var v = timings[0]; f.timingTimestamp = v.frameStartTimestamp.ToString(); f.timingFresh = v.frameStartTimestamp != 0 && v.frameStartTimestamp != lastTimingTimestamp; lastTimingTimestamp = v.frameStartTimestamp;
                f.cpuTimingValid = Finite(v.cpuFrameTime) && v.cpuFrameTime > 0; f.gpuTimingValid = Finite(v.gpuFrameTime) && v.gpuFrameTime > 0;
                f.cpuFrameMs = f.cpuTimingValid ? v.cpuFrameTime : 0; f.gpuFrameMs = f.gpuTimingValid ? v.gpuFrameTime : 0;
            }
            if (DeformationEventMode.Requested ? (logicalFrame==159||logicalFrame==160||logicalFrame==175||logicalFrame==255) : (CaptureAt(logicalFrame)||logicalFrame==totalFrames-1)) Capture(f);
            frames.WriteLine(JsonUtility.ToJson(f)); lastEngine = Time.frameCount; receipt = true; run.renderedFrames++; if(DeformationEventMode.Requested)DeformationEventMode.Rendered(logicalFrame,Time.frameCount); SaveRun();
        }
        catch (Exception e) { Fail(e.ToString()); if(DeformationEventMode.Requested){HybridLumenGI.DeformationEventTap.Abort(e);return;} Finish(false); }
    }
    static bool CaptureAt(int n) => n % 30 == 0 || n == 119 || n == 179 || n == 209 || n == 239 || n == 299 || n == 359 || n == 419 || n == 719;
    void Capture(Frame f)
    {
        readback = AsyncGPUReadback.Request(target, 0, TextureFormat.RGBAFloat); pending = true;
        readback.WaitForCompletion(); if (!readback.done) throw new Exception("Readback completion unproven."); pending = false;
        if (readback.hasError) throw new Exception("GPU readback failed.");
        var values = readback.GetData<float>(); if (values.Length != Width * Height * 4) throw new Exception("Readback dimensions differ.");
        var pixels = new float[values.Length]; values.CopyTo(pixels); var raw = new byte[pixels.Length * 4]; var preview = new byte[pixels.Length];
        double sum = 0, maximum = double.NegativeInfinity;
        for (int i = 0; i < pixels.Length; i++)
        {
            if (!Finite(pixels[i])) throw new Exception("Nonfinite captured component at " + i);
            float c = Mathf.Max(0, pixels[i]); preview[i] = (i & 3) == 3 ? (byte)255 : (byte)Mathf.RoundToInt(255 * Mathf.Clamp01(Mathf.LinearToGammaSpace(c / (1 + c))));
            if ((i & 3) != 3) maximum = Math.Max(maximum, pixels[i]);
        }
        for (int i = 0; i < pixels.Length; i += 4) sum += .2126 * pixels[i] + .7152 * pixels[i + 1] + .0722 * pixels[i + 2];
        Buffer.BlockCopy(pixels, 0, raw, 0, raw.Length); string stem = "frame-" + logicalFrame.ToString("D4");
        f.raw = stem + ".rgba32f"; f.exr = stem + ".exr"; f.png = stem + ".png";
        byte[] exr = ImageConversion.EncodeArrayToEXR(raw, GraphicsFormat.R32G32B32A32_SFloat, Width, Height, Width * 16, Texture2D.EXRFlags.OutputAsFloat);
        byte[] png = ImageConversion.EncodeArrayToPNG(preview, GraphicsFormat.R8G8B8A8_UNorm, Width, Height, Width * 4);
        if (exr == null || exr.Length == 0 || png == null || png.Length == 0) throw new Exception("Image encoding produced no bytes.");
        File.WriteAllBytes(Path.Combine(directory, f.raw), raw); File.WriteAllBytes(Path.Combine(directory, f.exr), exr); File.WriteAllBytes(Path.Combine(directory, f.png), png);
        f.meanLuminance = sum / (Width * Height); f.maxRgb = maximum; f.captured = true;
        File.WriteAllText(Path.Combine(directory, stem + ".json"), JsonUtility.ToJson(f, true)); run.captures++;
    }
    static object Member(object o, string name) { if (o == null) return null; const BindingFlags b = BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic; return o.GetType().GetField(name, b)?.GetValue(o) ?? o.GetType().GetProperty(name, b)?.GetValue(o); }
    void Diagnostics(Frame f)
    {
        f.diagnosticsStatus = featureOff ? "feature-disabled" : "unavailable"; if (featureOff) return;
        var method = feature.GetType().GetMethod("GetDiagnostics", BindingFlags.Instance | BindingFlags.Public, null, Type.EmptyTypes, null); if (method == null) return;
        var entries = method.Invoke(feature, null) as IEnumerable; if (entries == null) return; object found = null;
        foreach (var entry in entries) if (Member(entry, "camera")?.ToString() == camera.name) { if (found != null) throw new Exception("Ambiguous diagnostic camera name."); found = entry; }
        if (found != null) { f.diagnosticsStatus = "reported-not-execution-proof"; f.diagnosticsJson = JsonUtility.ToJson(found); }
    }
    static bool Finite(double x) => !double.IsNaN(x) && !double.IsInfinity(x);
    void Fail(string error) { run.errors++; run.error = error; }
    void OnLog(string message, string stack, LogType type)
    {
        if (type == LogType.Error || type == LogType.Exception || type == LogType.Assert) Fail("Unity " + type + ": " + message);
        try { logs?.WriteLine(JsonUtility.ToJson(new Log { utc = DateTime.UtcNow.ToString("o"), type = type.ToString(), message = message, stack = stack, logicalFrame = logicalFrame, engineFrame = Time.frameCount })); } catch (Exception e) { Fail("Log IO: " + e.Message); }
    }
    void SaveRun() { if (directory != null) File.WriteAllText(Path.Combine(directory, "run.json"), JsonUtility.ToJson(run, true)); }
    public bool AuditOpen=>running && !closing;
    public bool AuditReceipt(int frame,int engine)=>AuditOpen && receipt && logicalFrame==frame && lastEngine==engine;
    void Finish(bool collected)
    {
        if (closing) return; closing = true; running = false; RenderPipelineManager.endCameraRendering -= Rendered;
        try
        {
            try{if(DeformationEventMode.Requested)DeformationEventMode.Close(collected);}catch(Exception e){Fail("Material close: "+e);}
            if (pending) { readback.WaitForCompletion(); pending = !readback.done; if (pending || readback.hasError) Fail("Readback shutdown failed."); }
            if (configured)
            {
                camera.targetTexture = oldTarget; camera.allowHDR = oldHdr; camera.allowMSAA = oldMsaa; camera.allowDynamicResolution = oldDynamic; camera.enabled = DeformationEventMode.Requested?false:oldEnabled; data.renderPostProcessing = oldPost;
                camera.transform.SetPositionAndRotation(oldPosition, oldRotation); door.localPosition = doorOrigin; Application.runInBackground = oldBackground;
                for (int i = 0; i < lights.Length; i++) lights[i].enabled = oldLights[i];
            }
            if (target && !pending) { target.Release(); Destroy(target); target = null; }
        }
        catch (Exception e) { Fail("Shutdown: " + e); }
        try { frames?.Dispose(); logs?.Dispose(); } catch (Exception e) { Fail("Writer close: " + e); }
        Application.logMessageReceived -= OnLog;
        bool ok = collected && run.errors == 0 && run.renderedFrames == totalFrames;
        run.fullSequenceCompleted = ok && totalFrames == 720; run.status = ok ? (totalFrames == 720 ? "completed" : "incomplete-probe") : "failed"; run.completedUtc = DateTime.UtcNow.ToString("o");
        try { SaveRun(); } catch (Exception e) { ok = false; run.status = "failed"; Debug.LogError("Comparison manifest write failed: " + e); }
        if (!ok) Debug.LogError("Comparison failed: " + run.error);
        if (!quitWhenComplete) return;
#if UNITY_EDITOR
        UnityEditor.EditorApplication.Exit(ok ? 0 : 1);
#else
        Application.Quit(ok ? 0 : 1);
#endif
    }
    void OnDisable() { if (!closing && running) { Fail("Capture component disabled before completion."); Finish(false); } }
}



