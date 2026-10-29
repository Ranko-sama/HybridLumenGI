using System;
using System.Collections.Generic;
using System.IO;
using System.Runtime.CompilerServices;
using System.Security.Cryptography;
using HybridLumenGI;
using UnityEngine;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

/// <summary>Temporary, bounded native exercise of the ordinary sample controller, not a GI quality oracle.</summary>
[DefaultExecutionOrder(20000)]
public sealed class UnifiedSampleHost : MonoBehaviour
{
    public const int Width = 640, Height = 360, MaximumRequests = 1200;
    public const double MaximumSeconds = 1800;
    [SerializeField] Camera targetCamera;
    [SerializeField] HybridLumenGIUnifiedSample controller;
    [SerializeField] HybridLumenGIRendererFeature feature;
    [SerializeField] HybridLumenGIAssetPageStreamer streamer;
    [SerializeField] HybridLumenGIStreamedRepresentation[] ownedBindings;
    [SerializeField] string outputDirectory;
    static readonly string[] Stages = {
        "cold-near-details", "far-aggregate-software", "far-aggregate-dxr-reported",
        "far-aggregate-software-return", "controller-disabled-release", "reenabled-near-details", "leave-release"
    };
    HybridLumenGIStreamedRepresentation aggregate;
    readonly List<HybridLumenGIProxy> published = new List<HybridLumenGIProxy>();
    readonly List<HybridLumenGIProxy> targetMembers = new List<HybridLumenGIProxy>();
    RenderTexture target, previousTarget;
    RenderPipeline.StandardRequest request;
    object readyPipeline;
    int stablePipelineUpdates, stage = -1, stableConditions, lastRequestEngine = -1;
    bool started, admitted, insideRequest, finished, pendingReadback, advancePending, successPending;
    bool previousHardwarePreference, previousHdr, previousMsaa, cameraStateSaved;
    float previousAspect;
    double startSeconds;
    string firstError;
    StreamWriter events;
    AsyncGPUReadbackRequest readback;
    BindingRow[] beforeDraw;
    FrameRow selected;
    Receipt result;

    [Serializable] public sealed class Receipt
    {
        public string status = "running", error, outputDirectory, unity, api, gpu, scene;
        public string scope = "Finite sample integration and finite HDR readback only; reported backend is CPU state, not per-ray GPU backend verification. No physical-quality or performance verdict.";
        public string environment = "The user reported exiting the game before this run. GPU load is unmeasured; capture elapsed time is not a performance comparison.";
        public int renderedFrames, requests, cameraBegins, cameraEnds, contextBegins, contextEnds, completedStages;
        public bool readbacksDrained, coldBindingsObserved, targetRetirementQueued;
        public double elapsedSeconds;
        public List<StageReceipt> stages = new List<StageReceipt>();
    }
    [Serializable] public sealed class BindingRow
    {
        public string name, error;
        public int stableId, revision, parentStableId, materialSlots;
        public uint generation;
        public bool bound, proxyEnabled, rendererEnabled, forceRenderingOff, visible, meshBound, sdfBound, chartsBound;
    }
    [Serializable] public sealed class PageRow
    { public string id, phase, error; public uint generation; public bool wanted; public int consumerReferences; }
    [Serializable] public sealed class PublicationRow
    {
        public bool available, current, transitioning, capacityFallback;
        public string phase;
        public int preparedEngineFrame = -1, preparedWorkFrame = -1, sceneRevision, targetWarmingCount, targetUnknownCount;
        public int[] publishedIds, targetIds;
    }
    [Serializable] public sealed class FrameRow
    {
        public string eventType, stage;
        public int request, engineFrame, pipelineIdentity, consecutiveConditions;
        public double seconds;
        public bool controllerEnabled, requestedHardware, phaseCondition;
        public Vector3 cameraPosition;
        public Quaternion cameraRotation;
        public BindingRow[] beforeDraw, afterCamera;
        public PageRow[] pages;
        public PublicationRow publication;
        public HybridLumenGIUnifiedSample.Ledger ledger;
    }
    [Serializable] public sealed class StageReceipt
    {
        public string stage, rawFile, rawSha256, exrFile, exrSha256, previewFile, previewSha256;
        public string signal = "Final camera target after RenderPipeline.StandardRequest returned; ordinary variant renderer/post-processing configuration. Not a pre/post HLGI decomposition.";
        public string format = "rgba32f-le", rowOrder = "native-texture-memory-order; not orientation-normalized for comparison";
        public int request, engineFrame, width = Width, height = Height, finiteValues, positiveRgbPixels, minimumConsecutiveConditions = 3;
        public float minimum, maximum;
        public FrameRow frame;
    }
    sealed class ReadbackCompletion : HybridLumenGIAssetPageStreaming.ICompletion
    {
        readonly AsyncGPUReadbackRequest value;
        public ReadbackCompletion(AsyncGPUReadbackRequest requestValue) { value = requestValue; }
        public bool IsComplete => value.done;
    }

    public void Configure(Camera camera, HybridLumenGIUnifiedSample sample, HybridLumenGIRendererFeature rendererFeature,
        HybridLumenGIAssetPageStreamer pages, HybridLumenGIStreamedRepresentation[] bindings, string directory)
    {
        if (Application.isPlaying) throw new InvalidOperationException("Configure the saved Host before Play.");
        if (camera == null || sample == null || rendererFeature == null || pages == null || bindings == null || bindings.Length != 4 || string.IsNullOrWhiteSpace(directory))
            throw new ArgumentException("One camera, controller, feature, streamer, one root plus three details and an output path are required.");
        targetCamera = camera; controller = sample; feature = rendererFeature; streamer = pages;
        ownedBindings = (HybridLumenGIStreamedRepresentation[])bindings.Clone(); outputDirectory = Path.GetFullPath(directory);
        targetCamera.enabled = false;
    }
    static void Require(bool value, string message) { if (!value) throw new InvalidOperationException(message); }
    public void PrepareRuntimeVerification(string directory)
    {
        Require(Application.isPlaying && !enabled && !started && !finished, "Only a dormant Player Host can enter finite verification.");
        Require(Path.IsPathRooted(directory) && !Directory.Exists(directory) && !File.Exists(directory), "Fresh absolute verification output required.");
        outputDirectory = directory; targetCamera.enabled = false; enabled = true;
    }
    static bool Finite(float value) => !float.IsNaN(value) && !float.IsInfinity(value);
    static string Hash(byte[] bytes)
    { using (var sha = SHA256.Create()) return BitConverter.ToString(sha.ComputeHash(bytes)).Replace("-", "").ToLowerInvariant(); }

    void Start()
    {
        startSeconds = Time.realtimeSinceStartupAsDouble;
        result = new Receipt { outputDirectory = outputDirectory, unity = Application.unityVersion,
            api = SystemInfo.graphicsDeviceType.ToString(), gpu = SystemInfo.graphicsDeviceName, scene = gameObject.scene.path };
        try
        {
            Require(!string.IsNullOrWhiteSpace(outputDirectory), "Missing output directory.");
            Directory.CreateDirectory(outputDirectory);
            Require(!File.Exists(Path.Combine(outputDirectory, "host-result.json")), "Host result already exists; refuse to overwrite.");
            events = new StreamWriter(new FileStream(Path.Combine(outputDirectory, "events.jsonl"), FileMode.CreateNew, FileAccess.Write, FileShare.Read));
            Require(targetCamera != null && controller != null && feature != null && streamer != null && controller.isActiveAndEnabled && feature.isActive, "Missing/disabled configured component.");
            Require(ownedBindings != null && ownedBindings.Length == 4, "Expected exactly four owned bindings.");
            var unique = new HashSet<HybridLumenGIStreamedRepresentation>();
            foreach (var binding in ownedBindings)
            {
                Require(binding != null && unique.Add(binding) && binding.Proxy != null && binding.SourceRenderer != null, "Invalid/duplicate binding.");
                if (binding.Proxy.HLODParent == null) { Require(aggregate == null, "More than one root binding."); aggregate = binding; }
                Require(!binding.HasBoundAssets, "Cold start already has a bound sample representation.");
            }
            Require(aggregate != null, "No aggregate binding.");
            foreach (var binding in ownedBindings) Require(binding == aggregate || binding.Proxy.HLODParent == aggregate.Proxy, "Detail does not belong to the aggregate.");
            Require(streamer.Available && streamer.State != null, "Page driver is not available at Host start.");
            Require(AllPagesReleased(), "Cold start already owns page assets, requests or leases.");
            result.coldBindingsObserved = true;
            Require(!targetCamera.enabled && targetCamera.gameObject.activeInHierarchy && targetCamera.GetUniversalAdditionalCameraData().renderType == CameraRenderType.Base, "Host needs an active, automatically disabled Base camera.");
            Require(targetCamera.rect.Equals(new Rect(0, 0, 1, 1)) && !targetCamera.stereoEnabled && !targetCamera.allowDynamicResolution, "Unsupported camera viewport/XR/dynamic resolution.");
            Require(SystemInfo.supportsAsyncGPUReadback && SystemInfo.IsFormatSupported(GraphicsFormat.R16G16B16A16_SFloat, GraphicsFormatUsage.Render) && SystemInfo.IsFormatSupported(GraphicsFormat.R32G32B32A32_SFloat, GraphicsFormatUsage.ReadPixels), "Required HDR render/readback formats unavailable.");
            previousTarget = targetCamera.targetTexture; previousAspect = targetCamera.aspect;
            previousHdr = targetCamera.allowHDR; previousMsaa = targetCamera.allowMSAA; previousHardwarePreference = feature.RequestedPreferHardwareTracing;
            cameraStateSaved = true;
            target = new RenderTexture(Width, Height, 24, RenderTextureFormat.ARGBHalf, RenderTextureReadWrite.Linear)
            { name = "Unified sample Host owned HDR", antiAliasing = 1, useMipMap = false, autoGenerateMips = false, useDynamicScale = false };
            Require(target.Create(), "Could not create the owned HDR target.");
            targetCamera.targetTexture = target; targetCamera.aspect = (float)Width / Height; targetCamera.allowHDR = true; targetCamera.allowMSAA = false;
            request = new RenderPipeline.StandardRequest { destination = target, mipLevel = 0, slice = 0, face = CubemapFace.Unknown };
            Application.runInBackground = true;
            Application.logMessageReceived += OnLog;
            RenderPipelineManager.beginContextRendering += ContextBegan; RenderPipelineManager.endContextRendering += ContextEnded;
            RenderPipelineManager.beginCameraRendering += CameraBegan; RenderPipelineManager.endCameraRendering += CameraEnded;
            started = true;
            WriteEvent(Snapshot("cold-start", null)); Save();
        }
        catch (Exception error) { firstError = error.ToString(); }
    }
    void OnLog(string message, string stack, LogType type)
    { if (type == LogType.Error || type == LogType.Exception || type == LogType.Assert) firstError = firstError ?? message + "\n" + stack; }
    void ContextBegan(ScriptableRenderContext context, List<Camera> cameras)
    { if (cameras.Contains(targetCamera)) result.contextBegins++; }
    void ContextEnded(ScriptableRenderContext context, List<Camera> cameras)
    { if (cameras.Contains(targetCamera)) result.contextEnds++; }
    void CameraBegan(ScriptableRenderContext context, Camera camera)
    {
        if (camera != targetCamera) return;
        result.cameraBegins++;
        try { Require(insideRequest, "An unrequested camera render occurred."); beforeDraw = ReadBindings(); CheckAtomic(beforeDraw); }
        catch (Exception error) { firstError = firstError ?? error.ToString(); }
    }
    void CameraEnded(ScriptableRenderContext context, Camera camera)
    { if (camera == targetCamera) { result.cameraEnds++; if (!insideRequest) firstError = firstError ?? "Unrequested camera end."; } }

    void Update()
    {
        if (finished || result == null) return;
        try
        {
            Require(firstError == null, firstError);
            Require(Time.realtimeSinceStartupAsDouble - startSeconds <= MaximumSeconds, "1800 second whole-run deadline exceeded; resource contention is not an algorithm verdict.");
            if (pendingReadback)
            {
                if (!readback.done) return;
                CompleteReadback(); pendingReadback = false; advancePending = true; Save();
            }
            if (successPending) { Finish(true); return; }
            if (advancePending) { advancePending = false; EnterStage(stage + 1); }
            if (!started) return;
            if (!admitted)
            {
                if (!RenderPipeline.SupportsRenderRequest(targetCamera, request)) return;
                object current = RenderPipelineManager.currentPipeline;
                if (!ReferenceEquals(readyPipeline, current)) { readyPipeline = current; stablePipelineUpdates = 0; WriteEvent(Snapshot("pipeline-ready-candidate", null)); return; }
                if (++stablePipelineUpdates < 2) return;
                admitted = true; EnterStage(0); // No camera submission or GI warmup preceded this point.
            }
        }
        catch (Exception error) { firstError = firstError ?? error.ToString(); Finish(false); }
    }
    void LateUpdate()
    {
        if (!started || !admitted || finished || pendingReadback || advancePending || successPending || firstError != null) return;
        try
        {
            Require(result.requests < MaximumRequests, "1200 camera-request limit reached before all stages completed.");
            Require(ReferenceEquals(readyPipeline, RenderPipelineManager.currentPipeline), "The pipeline changed after cold admission.");
            Require(!targetCamera.enabled && targetCamera.targetTexture == target && target.IsCreated() && feature.isActive, "Explicit camera/target/feature state changed.");
            foreach (var camera in Camera.allCameras) Require(camera == targetCamera || !camera.isActiveAndEnabled || camera.cameraType != CameraType.Game, "Another automatic Game camera is active.");
            Require(lastRequestEngine != Time.frameCount, "More than one request in this engine frame."); lastRequestEngine = Time.frameCount;
            beforeDraw = null; result.requests++; insideRequest = true;
            try { RenderPipeline.SubmitRenderRequest(targetCamera, request); }
            finally { insideRequest = false; }
            // Evaluate after the complete request, never from endCamera while URP still restores its target.
            Require(firstError == null, firstError);
            Require(result.cameraBegins == result.requests && result.cameraEnds == result.requests && result.contextBegins == result.requests && result.contextEnds == result.requests, "Request did not produce exactly one complete camera/context pair.");
            result.renderedFrames = result.cameraEnds;
            var row = Snapshot("camera-complete", beforeDraw); CheckAtomic(row.afterCamera);
            Require(row.ledger.cameraGi != null && row.ledger.cameraGi.frame == result.requests,
                "GI did not record exactly once for each explicit camera request.");
            bool condition = PhaseCondition(row);
            stableConditions = condition ? stableConditions + 1 : 0;
            row.phaseCondition = condition; row.consecutiveConditions = stableConditions;
            WriteEvent(row); Save();
            // Three complete matching renders include two additional renders after the first match.
            // Both pre-draw renderer flags and post-camera publication must match; an endCamera switch alone cannot qualify its image.
            if (stableConditions >= 3)
            {
                selected = row; readback = AsyncGPUReadback.Request(target, 0, TextureFormat.RGBAFloat); pendingReadback = true;
            }
        }
        catch (Exception error) { firstError = firstError ?? error.ToString(); } // Finish is deferred to the next Update.
    }
    void EnterStage(int value)
    {
        if (value == Stages.Length) { successPending = true; return; }
        stage = value; stableConditions = 0;
        switch (stage)
        {
            case 0: controller.SetHardwarePreference(false); controller.GoNear(); break;
            case 1: controller.GoFar(); break;
            case 2:
                Require(HybridLumenGIHardwareBackend.IsSupported, "DXR/inline ray tracing capability unsupported; the hardware stage is uncovered.");
                controller.SetHardwarePreference(true); break;
            case 3: controller.SetHardwarePreference(false); break;
            case 4: controller.enabled = false; break; // Camera stays at the in-domain Far view: a real disable-release regression.
            case 5: controller.enabled = true; controller.GoNear(); break;
            case 6: controller.Leave(); break;
        }
        WriteEvent(Snapshot("stage-enter", null)); Save();
    }

    BindingRow[] ReadBindings()
    {
        var rows = new BindingRow[ownedBindings.Length];
        for (int i = 0; i < rows.Length; i++)
        {
            var binding = ownedBindings[i]; Require(binding != null && binding.Proxy != null && binding.SourceRenderer != null, "Owned binding was destroyed.");
            var proxy = binding.Proxy; var renderer = binding.SourceRenderer;
            rows[i] = new BindingRow { name = binding.name, stableId = proxy.StableId, revision = proxy.Revision,
                parentStableId = proxy.HLODParent != null ? proxy.HLODParent.StableId : 0, generation = binding.Generation,
                bound = binding.HasBoundAssets, proxyEnabled = proxy.isActiveAndEnabled, rendererEnabled = renderer.enabled,
                forceRenderingOff = renderer.forceRenderingOff, visible = renderer.enabled && renderer.gameObject.activeInHierarchy && !renderer.forceRenderingOff,
                meshBound = proxy.SourceMesh != null, sdfBound = proxy.MeshSdf != null, chartsBound = proxy.SurfaceCharts != null,
                materialSlots = renderer.sharedMaterials.Length, error = binding.LastError };
        }
        return rows;
    }
    void CheckAtomic(BindingRow[] rows)
    {
        Require(rows != null && rows.Length == 4, "Missing pre-draw binding observation.");
        int roots = 0, details = 0;
        foreach (var row in rows)
        {
            Require(string.IsNullOrEmpty(row.error), "Binding failed: " + row.name + ": " + row.error);
            if (!row.visible) continue;
            Require(row.bound && row.meshBound && row.materialSlots > 0 && row.sdfBound && row.chartsBound, "Visible representation has incomplete bindings.");
            if (row.stableId == aggregate.Proxy.StableId) roots++; else details++;
        }
        Require((roots == 0 && details == 0) || (roots == 1 && details == 0) || (roots == 0 && details == 3), "Visible HLOD group is partial or overlaps aggregate and detail.");
    }
    static int[] Ids(List<HybridLumenGIProxy> values)
    { var ids = new int[values.Count]; for (int i = 0; i < ids.Length; i++) ids[i] = values[i].StableId; Array.Sort(ids); return ids; }
    FrameRow Snapshot(string kind, BindingRow[] before)
    {
        bool available = feature.TryGetHlodPublication(targetCamera, aggregate.Proxy, published, targetMembers, out var info);
        var pages = new List<PageRow>();
        foreach (var page in streamer.State.States) pages.Add(new PageRow { id = page.Id, phase = page.Status.ToString(), generation = page.Generation, wanted = page.Wanted, consumerReferences = page.ConsumerReferences, error = page.LastError });
        return new FrameRow { eventType = kind, stage = stage >= 0 ? Stages[stage] : "pipeline-startup", request = result.requests,
            engineFrame = Time.frameCount, pipelineIdentity = RenderPipelineManager.currentPipeline == null ? 0 : RuntimeHelpers.GetHashCode(RenderPipelineManager.currentPipeline), seconds = Time.realtimeSinceStartupAsDouble - startSeconds,
            controllerEnabled = controller.isActiveAndEnabled, requestedHardware = feature.RequestedPreferHardwareTracing,
            cameraPosition = targetCamera.transform.position, cameraRotation = targetCamera.transform.rotation, beforeDraw = before,
            afterCamera = ReadBindings(), pages = pages.ToArray(), ledger = controller.CaptureLedger(),
            publication = new PublicationRow { available = available, current = available && info.preparedEngineFrame == Time.frameCount, phase = info.phase.ToString(),
                preparedEngineFrame = info.preparedEngineFrame, preparedWorkFrame = info.preparedWorkFrame, sceneRevision = info.sceneRevision,
                transitioning = info.transitioning, capacityFallback = info.capacityFallback, targetWarmingCount = info.targetWarmingCount,
                targetUnknownCount = info.targetUnknownCount, publishedIds = Ids(published), targetIds = Ids(targetMembers) } };
    }
    bool VisibleEquals(BindingRow[] rows, bool detail)
    {
        if (rows == null) return false;
        foreach (var row in rows)
        {
            bool expected = detail ? row.stableId != aggregate.Proxy.StableId : row.stableId == aggregate.Proxy.StableId;
            if (row.visible != expected || (expected && !row.bound)) return false;
        }
        return true;
    }
    bool PhaseCondition(FrameRow row)
    {
        Require(row.ledger.pagesFailed == 0, "A page entered Failed/ReleaseFailed.");
        Require(!row.ledger.retirementSubmissionUncertain && row.ledger.retirementFailed == 0, "Retirement submission/failure prevents safe acceptance.");
        if (stage == 4 || stage == 6)
        {
            if (row.controllerEnabled != (stage == 6)) return false;
            foreach (var binding in row.afterCamera) if (binding.bound || binding.visible || binding.meshBound || binding.materialSlots != 0 || binding.sdfBound || binding.chartsBound) return false;
            foreach (var binding in row.beforeDraw) if (binding.visible) return false;
            return AllPagesReleased();
        }
        bool detail = stage == 0 || stage == 5, hardware = stage == 2;
        if (!row.controllerEnabled || row.requestedHardware != hardware || row.ledger.cameraGi == null || row.ledger.cameraGi.hardwareBackend != hardware) return false;
        if (!row.publication.current || row.publication.phase != "Published" || row.publication.transitioning || row.publication.capacityFallback || row.publication.targetUnknownCount != 0 || row.publication.targetWarmingCount != 0) return false;
        // Match the current preparation to this completed GI recording; epochs and
        // backend invalidation do not reset the per-camera recording counter.
        if (row.ledger.cameraGi.frame != row.publication.preparedWorkFrame + 1) return false;
        if (!VisibleEquals(row.beforeDraw, detail) || !VisibleEquals(row.afterCamera, detail)) return false;
        var expected = new List<int>();
        foreach (var binding in row.afterCamera)
        {
            if (detail ? binding.stableId != aggregate.Proxy.StableId : binding.stableId == aggregate.Proxy.StableId) expected.Add(binding.stableId);
            if (!detail && binding.stableId != aggregate.Proxy.StableId && binding.bound) return false;
        }
        expected.Sort();
        return EqualIds(expected, row.publication.publishedIds) && EqualIds(expected, row.publication.targetIds);
    }
    static bool EqualIds(List<int> expected, int[] actual)
    { if (actual == null || actual.Length != expected.Count) return false; for (int i = 0; i < actual.Length; i++) if (actual[i] != expected[i]) return false; return true; }
    bool AllPagesReleased()
    {
        var state = streamer.State; if (state == null || state.BundleBytes != 0 || state.ResidentBytes != 0 || state.IoBytesInFlight != 0 || state.ActiveOperations != 0 || state.RetiringLeases != 0) return false;
        foreach (var page in state.States) if (page.Status != HybridLumenGIAssetPageStreaming.Phase.Unloaded || page.Wanted || page.ConsumerReferences != 0) return false;
        return true;
    }
    void CompleteReadback()
    {
        Require(readback.done && !readback.hasError, "Own stage HDR readback failed.");
        var values = readback.GetData<float>(); Require(values.Length == Width * Height * 4, "Stage HDR shape differs.");
        var receipt = new StageReceipt { stage = Stages[stage], request = selected.request, engineFrame = selected.engineFrame, frame = selected,
            minimum = float.PositiveInfinity, maximum = float.NegativeInfinity };
        byte[] preview = new byte[values.Length];
        for (int pixel = 0; pixel < Width * Height; pixel++)
        {
            bool positive = false;
            for (int channel = 0; channel < 4; channel++)
            {
                float value = values[pixel * 4 + channel]; Require(Finite(value), "Nonfinite stage HDR value."); receipt.finiteValues++;
                receipt.minimum = Mathf.Min(receipt.minimum, value); receipt.maximum = Mathf.Max(receipt.maximum, value);
                if (channel < 3) positive |= value > 0;
                float radiance = Mathf.Max(0, value);
                preview[pixel * 4 + channel] = channel == 3 ? (byte)255 : (byte)Mathf.RoundToInt(Mathf.Clamp01(Mathf.LinearToGammaSpace(radiance / (1 + radiance))) * 255);
            }
            if (positive) receipt.positiveRgbPixels++;
        }
        byte[] raw = readback.GetData<byte>().ToArray();
        byte[] exr = ImageConversion.EncodeArrayToEXR(raw, GraphicsFormat.R32G32B32A32_SFloat, Width, Height, Width * 16, Texture2D.EXRFlags.OutputAsFloat);
        byte[] png = ImageConversion.EncodeArrayToPNG(preview, GraphicsFormat.R8G8B8A8_UNorm, Width, Height, Width * 4);
        string prefix = "stage-" + stage.ToString("00") + "-" + Stages[stage];
        receipt.rawFile = prefix + ".rgba32f"; receipt.rawSha256 = WriteBytes(receipt.rawFile, raw);
        receipt.exrFile = prefix + ".exr"; receipt.exrSha256 = WriteBytes(receipt.exrFile, exr);
        receipt.previewFile = prefix + ".png"; receipt.previewSha256 = WriteBytes(receipt.previewFile, png);
        File.WriteAllText(Path.Combine(outputDirectory, prefix + ".json"), JsonUtility.ToJson(receipt, true));
        result.stages.Add(receipt); result.completedStages = result.stages.Count;
    }
    string WriteBytes(string filename, byte[] bytes)
    { using (var file = new FileStream(Path.Combine(outputDirectory, filename), FileMode.CreateNew, FileAccess.Write)) file.Write(bytes, 0, bytes.Length); return Hash(bytes); }
    void WriteEvent(FrameRow row) { events.WriteLine(JsonUtility.ToJson(row)); events.Flush(); }
    void Save()
    {
        result.elapsedSeconds = Time.realtimeSinceStartupAsDouble - startSeconds;
        File.WriteAllText(Path.Combine(outputDirectory, "host-result.json"), JsonUtility.ToJson(result, true));
    }
    void Finish(bool success)
    {
        if (finished || insideRequest) return; finished = true;
        Application.logMessageReceived -= OnLog;
        RenderPipelineManager.beginContextRendering -= ContextBegan; RenderPipelineManager.endContextRendering -= ContextEnded;
        RenderPipelineManager.beginCameraRendering -= CameraBegan; RenderPipelineManager.endCameraRendering -= CameraEnded;
        try
        {
            if (controller != null) controller.enabled = false;
            if (targetCamera != null && cameraStateSaved)
            {
                targetCamera.enabled = false;
                if (targetCamera.targetTexture == target) targetCamera.targetTexture = previousTarget;
                targetCamera.aspect = previousAspect; targetCamera.allowHDR = previousHdr; targetCamera.allowMSAA = previousMsaa;
            }
            if (feature != null && started) feature.SetPreferHardwareTracing(previousHardwarePreference);
            events?.Dispose(); events = null;
            result.readbacksDrained = !pendingReadback || readback.done;
            if (target != null)
            {
                var retiredTarget = target; target = null;
                var prerequisite = pendingReadback ? new ReadbackCompletion(readback) : null;
                // EndCamera is not a fence. Existing retirement owns final queue completion;
                // an unfinished own readback additionally remains an explicit prerequisite.
                HybridLumenGIResourceRetirement.Retire(() => { if (retiredTarget != null) { retiredTarget.Release(); Destroy(retiredTarget); } }, prerequisite);
                result.targetRetirementQueued = true;
            }
        }
        catch (Exception error) { firstError = firstError ?? error.ToString(); }
        result.status = success && firstError == null && result.completedStages == Stages.Length && result.readbacksDrained ? "collected" : "failed";
        result.error = firstError;
        try { if (!string.IsNullOrWhiteSpace(outputDirectory) && Directory.Exists(outputDirectory)) Save(); }
        catch (Exception error) { Debug.LogException(error); }
        Debug.Log("UNIFIED_SAMPLE_HOST_RESULT " + JsonUtility.ToJson(result));
#if UNITY_EDITOR
        UnityEditor.EditorApplication.isPlaying = false;
#else
        Application.Quit(result.status == "collected" ? 0 : 1);
#endif
    }
    void OnDestroy()
    {
        if (finished || result == null) return;
        firstError = firstError ?? "Host destroyed before bounded sequence completion.";
        // Normal Finish is deferred out of all camera callbacks; external destruction is a failed run.
        if (!insideRequest) Finish(false);
    }
}
