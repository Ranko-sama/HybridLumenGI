using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using UnityEngine;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace HybridLumenGI
{
    /// <summary>Small, fixed visual regression capture. No quality verdict or GPU benchmark.</summary>
    [DefaultExecutionOrder(-500)]
    [AddComponentMenu("Rendering/Hybrid Lumen GI/Validation Sequence")]
    public sealed class HybridLumenGIValidationSequence : MonoBehaviour
    {
        public const int SequenceVersion = 1, TotalFrames = 720;
        public enum ExpectedBackend { Software, Hardware, FeatureDisabled }
        [SerializeField] private Camera targetCamera;
        [SerializeField] private HybridLumenGIRendererFeature feature;
        [SerializeField] private HybridLumenGIValidationMotion door;
        [SerializeField] private Light[] switchedLights = Array.Empty<Light>();
        [SerializeField] private Transform colorView, thinWallView, blackRoomView;
        [SerializeField] private bool runOnStart = true;
        [SerializeField] private ExpectedBackend expectedBackend;
        [SerializeField] private string runLabel = "validation";
        [SerializeField, Min(16)] private int width = 640, height = 360;
        [SerializeField, Min(1)] private int captureEvery = 30;
        [SerializeField, Tooltip("Empty uses Application.persistentDataPath/HybridLumenGIValidation. Each run gets a new folder.")]
        private string outputRoot = "";
        [SerializeField, Tooltip("Export source-matched HDR signals immediately before and after HLGI composition. This does not generate a reference image.")]
        private bool exportReferencePackage;
        [SerializeField, Tooltip("Directory containing an explicitly exported source.json and its assets. Required in Player; also avoids asset loading during an Editor capture.")]
        private string referenceSourcePackage = "";
        [SerializeField, Tooltip("Submit one URP StandardRequest per logical frame after the pipeline is ready. Useful for deterministic batch capture.")]
        private bool explicitRenderRequests;

        [Serializable] private sealed class RunInfo
        {
            public int sequenceVersion = SequenceVersion, totalLogicalFrames = TotalFrames;
            public int width, height, captureEvery, renderedFrames, capturesWritten, failures, backendMismatches;
            public int initialGiFrame = -1, firstRenderedGiFrame = -1, firstEngineFrame = -1;
            public string status = "running", referenceStatus = "reference-required", runLabel, expectedBackend, startedUtc, completedUtc;
            public string unityVersion, urpAssemblyVersion, graphicsApi, gpu, driver, colorSpace, rowOrder, targetFormat, scene;
            public bool graphicsUVStartsAtTop, targetSRGB, featureActive, postProcessing, fog;
            public string ambientMode, environmentNote, featureSnapshot = "feature.json", lastError;
            public string referencePackage;
            public bool explicitRequest;
            public string renderPath;
            public Color ambientLight;
            public float ambientIntensity, reflectionIntensity;
            public int lightmapCount;
            public bool hasSkybox;
            public LightInfo[] lights;
            public string limitation = "Capture completion is not a GI quality verdict, successful Feature execution, real DXR proof or GPU performance measurement.";
        }
        [Serializable] private sealed class LightInfo
        {
            public string name, type, shadows, bakeType;
            public Color color;
            public float intensity, range, spotAngle, innerSpotAngle;
            public Vector3 position;
            public Quaternion rotation;
            public bool enabled;
            public int cullingMask;
            public uint renderingLayerMask;
        }
        [Serializable] private sealed class FrameInfo
        {
            public int sequenceVersion = SequenceVersion, logicalFrame, engineFrame, giFrame = -1, width, height;
            public string stage, camera, reportedBackend = "unknown", status, error, rawFile, exrFile;
            public Vector3 cameraPosition, doorLocalPosition;
            public Quaternion cameraRotation;
            public Matrix4x4 cameraProjection;
            public bool lightsEnabled, diagnosticFresh, gpuReadbackCompleted;
            public double meanLuminance, maximumRgb;
            public int nonfiniteComponents;
            public HybridLumenGIRendererFeature.CameraDiagnostics diagnostics;
        }
        [Serializable] private sealed class LogLine
        { public string utc, type, message, stack; public int logicalFrame, engineFrame; }
        private sealed class Pending
        { public FrameInfo frame; public AsyncGPUReadbackRequest request; public bool issued, processed; }

        private readonly List<Pending> pending = new List<Pending>(2);
        private RenderTexture output, previousTarget;
        private UniversalAdditionalCameraData cameraData;
        private bool previousHDR, previousMSAA, previousDynamic, previousPost, previousEnabled;
        private Vector3 previousPosition;
        private Quaternion previousRotation;
        private bool[] previousLightStates;
        private string directory, featureJson;
        private StreamWriter receipts, log;
        private RunInfo run;
        private int logicalFrame, lastEngineFrame = -1, lastGiFrame = -1, awaitingEngineFrame;
        private bool running, rendered, closing, initialized;
        private HybridLumenGIValidationPackage validationPackage;
        private bool referenceFailureReported;
        private bool submittingRequest;
        private bool? deferredFinish;
        private RenderPipeline.StandardRequest renderRequest;
        public string OutputDirectory => directory;
        public string CaptureStatus => run != null ? run.status : "not-started";
        public int RenderedFrames => run != null ? run.renderedFrames : 0;
        public bool ReferenceCaptureDrained => validationPackage == null || validationPackage.IsDrained;

        public void Configure(Camera camera, HybridLumenGIValidationMotion motion, Light[] lights,
            Transform color, Transform thin, Transform black, HybridLumenGIRendererFeature selectedFeature)
        { targetCamera = camera; door = motion; switchedLights = lights; colorView = color; thinWallView = thin; blackRoomView = black; feature = selectedFeature; }

        public static bool IsCaptureFrame(int frame, int interval)
        {
            return frame >= 0 && frame < TotalFrames && (frame % Math.Max(1, interval) == 0 || frame == TotalFrames - 1 ||
                frame == 119 || frame == 120 || frame == 179 || frame == 180 || frame == 209 || frame == 210 ||
                frame == 239 || frame == 240 || frame == 299 || frame == 300 || frame == 359 || frame == 360 || frame == 419 || frame == 420);
        }
        public static string StageAtFrame(int frame) => frame < 120 ? "color-static" : frame < 240 ? "moving-door" :
            frame < 300 ? "lights-off" : frame < 360 ? "lights-restored" : frame < 420 ? "thin-wall-cut" : "sealed-room-cut";

        private void Start() { if (runOnStart) BeginCapture(); }

        [ContextMenu("Begin Fixed Validation Capture (Play Mode)")]
        public void BeginCapture()
        {
            if (!Application.isPlaying || running || closing || initialized) return;
            try
            {
                if (targetCamera == null || door == null || colorView == null || thinWallView == null || blackRoomView == null)
                    throw new InvalidOperationException("Assign the generated camera, door and all three view markers.");
                if (feature == null) throw new InvalidOperationException("Assign the HybridLumenGIRendererFeature used by this camera, including for the disabled baseline.");
                if (width < 16 || height < 16 || width > 4096 || height > 4096 || captureEvery < 1)
                    throw new InvalidOperationException("Capture dimensions must be 16..4096 and interval positive.");
                if (!BitConverter.IsLittleEndian || QualitySettings.activeColorSpace != ColorSpace.Linear || !SystemInfo.supportsAsyncGPUReadback ||
                    !SystemInfo.IsFormatSupported(GraphicsFormat.R32G32B32A32_SFloat, FormatUsage.Render) ||
                    !SystemInfo.IsFormatSupported(GraphicsFormat.R32G32B32A32_SFloat, FormatUsage.ReadPixels))
                    throw new InvalidOperationException("Capture requires Linear color, little-endian float data and RGBAFloat render/readback support.");
                cameraData = targetCamera.GetUniversalAdditionalCameraData();
                if (cameraData.renderType != CameraRenderType.Base || targetCamera.stereoEnabled ||
                    (cameraData.cameraStack != null && cameraData.cameraStack.Count != 0))
                    throw new InvalidOperationException("Use one non-XR Base camera without a camera stack.");
                if ((expectedBackend == ExpectedBackend.FeatureDisabled) != !feature.isActive)
                    throw new InvalidOperationException("Feature active state differs from Expected Backend. Set the renderer asset before running.");
                string root = string.IsNullOrWhiteSpace(outputRoot) ? Path.Combine(Application.persistentDataPath, "HybridLumenGIValidation") : Path.GetFullPath(outputRoot);
                directory = Path.Combine(root, DateTime.UtcNow.ToString("yyyyMMdd-HHmmss") + "-" + Guid.NewGuid().ToString("N"));
                Directory.CreateDirectory(directory);
                featureJson = JsonUtility.ToJson(feature, true);
                File.WriteAllText(Path.Combine(directory, "feature.json"), featureJson, new UTF8Encoding(false));
                run = new RunInfo { width = width, height = height, captureEvery = captureEvery, runLabel = runLabel, expectedBackend = expectedBackend.ToString(),
                    startedUtc = DateTime.UtcNow.ToString("o"), unityVersion = Application.unityVersion,
                    urpAssemblyVersion = typeof(UniversalRenderPipeline).Assembly.GetName().Version.ToString(), graphicsApi = SystemInfo.graphicsDeviceType.ToString(),
                    gpu = SystemInfo.graphicsDeviceName, driver = SystemInfo.graphicsDeviceVersion, colorSpace = QualitySettings.activeColorSpace.ToString(),
                    graphicsUVStartsAtTop = SystemInfo.graphicsUVStartsAtTop, rowOrder = "GPU readback order; no CPU flip; compare only matching API/orientation",
                    scene = targetCamera.gameObject.scene.path, featureActive = feature.isActive, fog = RenderSettings.fog,
                    ambientMode = RenderSettings.ambientMode.ToString(), ambientLight = RenderSettings.ambientLight, ambientIntensity = RenderSettings.ambientIntensity,
                    reflectionIntensity = RenderSettings.reflectionIntensity, hasSkybox = RenderSettings.skybox != null,
                    lightmapCount = LightmapSettings.lightmaps == null ? 0 : LightmapSettings.lightmaps.Length,
                    environmentNote = "Feature serialized fields are in feature.json. Probe/bake/other-feature contributions still need inspection in the real project." };
                receipts = new StreamWriter(Path.Combine(directory, "frames.jsonl"), false, new UTF8Encoding(false)) { AutoFlush = true };
                log = new StreamWriter(Path.Combine(directory, "unity-log.jsonl"), false, new UTF8Encoding(false)) { AutoFlush = true };
                Application.logMessageReceived += OnLog;
                previousTarget = targetCamera.targetTexture; previousHDR = targetCamera.allowHDR; previousMSAA = targetCamera.allowMSAA;
                previousDynamic = targetCamera.allowDynamicResolution; previousPost = cameraData.renderPostProcessing; previousEnabled = targetCamera.enabled;
                previousPosition = targetCamera.transform.position; previousRotation = targetCamera.transform.rotation;
                previousLightStates = new bool[switchedLights.Length];
                run.lights = new LightInfo[switchedLights.Length];
                for (int i = 0; i < switchedLights.Length; i++)
                {
                    Light light = switchedLights[i];
                    previousLightStates[i] = light != null && light.enabled;
                    if (light != null) run.lights[i] = new LightInfo { name = light.name, type = light.type.ToString(), shadows = light.shadows.ToString(),
                        bakeType = HybridLumenGILights.GetBakeType(light).ToString(), color = light.color, intensity = light.intensity, range = light.range,
                        spotAngle = light.spotAngle, innerSpotAngle = light.innerSpotAngle, position = light.transform.position,
                        rotation = light.transform.rotation, enabled = light.enabled, cullingMask = light.cullingMask, renderingLayerMask = unchecked((uint)light.renderingLayerMask) };
                }
                initialized = true;
                output = new RenderTexture(width, height, 24, RenderTextureFormat.ARGBFloat, RenderTextureReadWrite.Linear)
                { name = "HLGI fixed sequence linear HDR", antiAliasing = 1, useMipMap = false, autoGenerateMips = false, useDynamicScale = false };
                if (!output.Create() || output.sRGB || output.graphicsFormat != GraphicsFormat.R32G32B32A32_SFloat)
                    throw new InvalidOperationException("Could not create the exact linear RGBAFloat capture target.");
                targetCamera.targetTexture = output; targetCamera.allowHDR = true; targetCamera.allowMSAA = false;
                targetCamera.allowDynamicResolution = false; cameraData.renderPostProcessing = false; targetCamera.enabled = !explicitRenderRequests;
                renderRequest = explicitRenderRequests ? new RenderPipeline.StandardRequest { destination = output } : null;
                if (renderRequest != null && !RenderPipeline.SupportsRenderRequest(targetCamera, renderRequest))
                    throw new InvalidOperationException("Wait for the active URP pipeline before beginning explicit validation requests.");
                run.targetFormat = output.graphicsFormat.ToString(); run.targetSRGB = output.sRGB; run.postProcessing = false;
                run.explicitRequest = explicitRenderRequests;
                run.renderPath = explicitRenderRequests ? "RenderPipeline.StandardRequest; one request per logical frame" : "Automatic camera rendering";
                if (exportReferencePackage)
                {
                    validationPackage = new HybridLumenGIValidationPackage(targetCamera, feature, directory, captureEvery, referenceSourcePackage);
                    run.referencePackage = "candidate.json";
                }
                var before = FindDiagnostics(); if (before != null) lastGiFrame = before.frame;
                run.initialGiFrame = lastGiFrame;
                logicalFrame = 0; lastEngineFrame = -1; rendered = false; running = true;
                ApplyFrame(); WriteRun(); RenderPipelineManager.endCameraRendering += OnCameraRendered;
                SubmitFrame();
                Debug.Log("[HybridLumenGI] Fixed validation capture: " + directory + ". Reference images remain required; this is not a performance run.", this);
            }
            catch (Exception error) { Fail(error.Message); Finish(false); Debug.LogError("[HybridLumenGI] Validation capture could not start: " + error.Message, this); }
        }

        private void Update()
        {
            validationPackage?.Advance(Time.frameCount);
            if (!referenceFailureReported && validationPackage != null && !string.IsNullOrEmpty(validationPackage.Failure))
            {
                referenceFailureReported = true;
                Fail("Reference package export: " + validationPackage.Failure);
                if (running) Finish(false);
            }
            if (!running) return;
            // BeginCapture may submit frame zero from Start in this same engine frame.
            if (rendered && lastEngineFrame == Time.frameCount) return;
            if (!rendered)
            {
                if (Time.frameCount > awaitingEngineFrame)
                { Fail("Missing camera render receipt for an advancing engine frame."); Finish(false); }
                return;
            }
            if (logicalFrame == TotalFrames - 1) { Finish(true); return; }
            logicalFrame++; rendered = false; ApplyFrame();
            SubmitFrame();
        }
        private void SubmitFrame()
        {
            if (!running || renderRequest == null) return;
            submittingRequest = true;
            try
            {
                if (Time.frameCount != awaitingEngineFrame) throw new InvalidOperationException("Explicit request must use its frozen logical frame.");
                RenderPipeline.SubmitRenderRequest(targetCamera, renderRequest);
            }
            catch (Exception error) { Fail("Explicit render request: " + error.Message); Finish(false); }
            finally
            {
                submittingRequest = false;
                if (deferredFinish.HasValue)
                {
                    bool complete = deferredFinish.Value; deferredFinish = null;
                    Finish(complete);
                }
            }
        }
        private void ApplyFrame()
        {
            awaitingEngineFrame = Time.frameCount;
            door.ApplyFrame(logicalFrame);
            bool lightsOn = logicalFrame < 240 || logicalFrame >= 300;
            for (int i = 0; i < switchedLights.Length; i++) if (switchedLights[i] != null) switchedLights[i].enabled = lightsOn && previousLightStates[i];
            Transform view = logicalFrame < 360 ? colorView : logicalFrame < 420 ? thinWallView : blackRoomView;
            targetCamera.transform.SetPositionAndRotation(view.position, view.rotation);
            validationPackage?.RequestFrame(logicalFrame, Time.frameCount);
        }
        private HybridLumenGIRendererFeature.CameraDiagnostics FindDiagnostics()
        {
            HybridLumenGIRendererFeature.CameraDiagnostics match = null;
            foreach (var item in feature.GetDiagnostics())
                if (item.camera == targetCamera.name) { if (match != null) throw new InvalidOperationException("Ambiguous camera name in GI diagnostics."); match = item; }
            return match;
        }
        private void OnCameraRendered(ScriptableRenderContext context, Camera camera)
        {
            if (!running || !ReferenceEquals(camera, targetCamera)) return;
            try
            {
                if (rendered || lastEngineFrame == Time.frameCount || (lastEngineFrame >= 0 && Time.frameCount != lastEngineFrame + 1))
                    throw new InvalidOperationException("Repeated or skipped engine-frame camera receipt; restart this fixed run.");
                if (targetCamera.targetTexture != output || JsonUtility.ToJson(feature, true) != featureJson)
                    throw new InvalidOperationException("Capture target or feature serialized settings changed during the run.");
                var frame = new FrameInfo { logicalFrame = logicalFrame, engineFrame = Time.frameCount, stage = StageAtFrame(logicalFrame), camera = camera.name,
                    cameraPosition = camera.transform.position, cameraRotation = camera.transform.rotation, doorLocalPosition = door.transform.localPosition,
                    cameraProjection = camera.projectionMatrix,
                    width = width, height = height, lightsEnabled = logicalFrame < 240 || logicalFrame >= 300, status = "render-receipt" };
                if (expectedBackend == ExpectedBackend.FeatureDisabled) frame.reportedBackend = "feature-disabled";
                else
                {
                    frame.diagnostics = FindDiagnostics();
                    if (frame.diagnostics == null || frame.diagnostics.frame <= lastGiFrame ||
                        (lastGiFrame >= 0 && frame.diagnostics.frame != lastGiFrame + 1))
                        throw new InvalidOperationException("Missing, stale or skipped GI diagnostic counter (previous=" + lastGiFrame +
                            ", current=" + (frame.diagnostics != null ? frame.diagnostics.frame.ToString() : "missing") +
                            ", logical=" + logicalFrame + ", engine=" + Time.frameCount + "); no backend identity can be claimed.");
                    frame.giFrame = frame.diagnostics.frame; lastGiFrame = frame.giFrame; frame.diagnosticFresh = true;
                    frame.reportedBackend = frame.diagnostics.hardwareBackend ? "reported-hardware" : "reported-software";
                    if (frame.diagnostics.hardwareBackend != (expectedBackend == ExpectedBackend.Hardware)) run.backendMismatches++;
                }
                lastEngineFrame = Time.frameCount; rendered = true; run.renderedFrames++;
                validationPackage?.EndCamera(logicalFrame, Time.frameCount);
                if (run.renderedFrames == 1) { run.firstEngineFrame = Time.frameCount; run.firstRenderedGiFrame = frame.giFrame; }
                receipts.WriteLine(JsonUtility.ToJson(frame));
                if (!IsCaptureFrame(logicalFrame, captureEvery)) return;
                string stem = "frame-" + logicalFrame.ToString("D4"); frame.rawFile = stem + ".rgba32f"; frame.exrFile = stem + ".exr";
                if (pending.Count >= 2) { frame.status = "capture-failed"; frame.error = "Two readbacks already in flight; logical frames were not paused."; Fail(frame.error); SaveFrame(frame); return; }
                var ticket = new Pending { frame = frame }; pending.Add(ticket);
                try { ticket.request = AsyncGPUReadback.Request(output, 0, TextureFormat.RGBAFloat, result => Complete(ticket, result)); ticket.issued = true; }
                catch { pending.Remove(ticket); throw; }
            }
            catch (Exception error) { Fail(error.Message); Finish(false); Debug.LogError("[HybridLumenGI] Validation receipt rejected: " + error.Message, this); }
        }
        private void Complete(Pending ticket, AsyncGPUReadbackRequest request)
        {
            if (ticket.processed) return;
            ticket.processed = true;
            try
            {
                if (!request.done || request.hasError) throw new InvalidOperationException("GPU readback failed.");
                var data = request.GetData<float>();
                if (data.Length != checked(width * height * 4)) throw new InvalidOperationException("Readback dimensions/format differ from RGBAFloat.");
                var pixels = new float[data.Length]; data.CopyTo(pixels);
                var bytes = new byte[checked(pixels.Length * sizeof(float))]; Buffer.BlockCopy(pixels, 0, bytes, 0, bytes.Length);
                double luminance = 0, maximum = double.NegativeInfinity; int nonfinite = 0;
                for (int i = 0; i < pixels.Length; i++) if (float.IsNaN(pixels[i]) || float.IsInfinity(pixels[i])) nonfinite++;
                if (nonfinite == 0) for (int i = 0; i < pixels.Length; i += 4)
                { luminance += pixels[i] * 0.2126 + pixels[i + 1] * 0.7152 + pixels[i + 2] * 0.0722; maximum = Math.Max(maximum, Math.Max(pixels[i], Math.Max(pixels[i + 1], pixels[i + 2]))); }
                ticket.frame.meanLuminance = nonfinite == 0 ? luminance / (width * height) : 0;
                ticket.frame.maximumRgb = nonfinite == 0 ? maximum : 0; ticket.frame.nonfiniteComponents = nonfinite;
                File.WriteAllBytes(Path.Combine(directory, ticket.frame.rawFile), bytes);
                byte[] exr = ImageConversion.EncodeArrayToEXR(bytes, GraphicsFormat.R32G32B32A32_SFloat, (uint)width, (uint)height,
                    (uint)(width * 16), Texture2D.EXRFlags.OutputAsFloat);
                if (exr == null || exr.Length == 0) throw new InvalidOperationException("EXR encoding returned no bytes.");
                File.WriteAllBytes(Path.Combine(directory, ticket.frame.exrFile), exr);
                ticket.frame.gpuReadbackCompleted = true;
                if (nonfinite != 0) throw new InvalidOperationException("Nonfinite HDR components: " + nonfinite);
                ticket.frame.status = "captured"; run.capturesWritten++;
            }
            catch (Exception error) { ticket.frame.status = "capture-failed"; ticket.frame.error = error.Message; Fail(error.Message); }
            finally
            {
                pending.Remove(ticket); SaveFrame(ticket.frame);
                if (closing)
                {
                    ReleaseOutputIfSafe();
                    try { WriteRun(); } catch (Exception error) { Fail("Late manifest IO: " + error.Message); }
                }
            }
        }
        private void SaveFrame(FrameInfo frame)
        { try { File.WriteAllText(Path.Combine(directory, "frame-" + frame.logicalFrame.ToString("D4") + ".json"), JsonUtility.ToJson(frame, true), new UTF8Encoding(false)); } catch (Exception error) { Fail(error.Message); } }
        private void Fail(string reason)
        { if (run != null) { run.failures++; run.lastError = reason; if (closing) run.status = "failed"; } }
        private void OnLog(string message, string stack, LogType type)
        {
            if (type == LogType.Error || type == LogType.Exception || type == LogType.Assert) Fail("Unity " + type + ": " + message);
            try { log?.WriteLine(JsonUtility.ToJson(new LogLine { utc = DateTime.UtcNow.ToString("o"), type = type.ToString(), message = message, stack = stack, logicalFrame = logicalFrame, engineFrame = Time.frameCount })); }
            catch (Exception error) { Fail("Log IO: " + error.Message); }
        }
        private void WriteRun()
        {
            if (run == null) return;
            File.WriteAllText(Path.Combine(directory, "run.json"), JsonUtility.ToJson(run, true), new UTF8Encoding(false));
            if (closing && run.status != "running") validationPackage?.BindRunArtifacts(run.status == "completed");
        }
        private void Finish(bool complete)
        {
            // URP restores its original camera target after endCameraRendering.
            // Keep that target alive until the enclosing request has returned.
            if (submittingRequest)
            {
                deferredFinish = deferredFinish.HasValue ? deferredFinish.Value && complete : complete;
                running = false;
                return;
            }
            if (closing) return; closing = true; running = false;
            RenderPipelineManager.endCameraRendering -= OnCameraRendered;
            validationPackage?.Close(complete && run != null && run.failures == 0,
                "The fixed validation sequence ended before successful completion.");
            // Each request is owned by this capture. Wait only on shutdown, never
            // between logical frames, and never release its RT before completion.
            try
            {
                foreach (var ticket in pending.ToArray())
                {
                    try { if (ticket.issued) { ticket.request.WaitForCompletion(); Complete(ticket, ticket.request); } }
                    catch (Exception error) { Fail("Readback shutdown: " + error.Message); }
                }
                if (initialized)
                {
                    if (targetCamera != null)
                    {
                        targetCamera.targetTexture = previousTarget; targetCamera.allowHDR = previousHDR; targetCamera.allowMSAA = previousMSAA;
                        targetCamera.allowDynamicResolution = previousDynamic; targetCamera.enabled = previousEnabled;
                        targetCamera.transform.SetPositionAndRotation(previousPosition, previousRotation);
                    }
                    if (cameraData != null) cameraData.renderPostProcessing = previousPost;
                    for (int i = 0; i < switchedLights.Length; i++) if (switchedLights[i] != null) switchedLights[i].enabled = previousLightStates[i];
                    if (door != null) door.Restore();
                }
            }
            catch (Exception error) { Fail("Capture restore: " + error.Message); }
            finally
            {
                // Unknown in-flight requests retain their RT; a later callback can
                // release it. No request is treated as completed after a failed wait.
                ReleaseOutputIfSafe();
                Application.logMessageReceived -= OnLog;
                try { receipts?.Dispose(); } catch (Exception error) { Fail("Receipt close: " + error.Message); }
                finally { receipts = null; }
                try { log?.Dispose(); } catch (Exception error) { Fail("Log close: " + error.Message); }
                finally { log = null; }
                if (run != null)
                {
                    run.status = complete && run.renderedFrames == TotalFrames && run.failures == 0 ?
                        (run.backendMismatches == 0 ? "completed" : "completed-with-backend-mismatch") : "failed";
                    run.completedUtc = DateTime.UtcNow.ToString("o");
                    try { WriteRun(); } catch (Exception error) { Debug.LogError("[HybridLumenGI] Cannot save capture manifest: " + error.Message); }
                }
            }
        }
        private void ReleaseOutputIfSafe()
        {
            if (output == null || pending.Count != 0) return;
            try { output.Release(); Destroy(output); output = null; }
            catch (Exception error) { Fail("Capture target release: " + error.Message); }
        }
        private void OnDisable() { if (running || initialized) Finish(false); }
        private void OnDestroy() { if (running || initialized) Finish(false); }
    }
}
