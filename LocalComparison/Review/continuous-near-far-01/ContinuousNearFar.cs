// Opt-in, one ordinary Player session. CPU submission/publication observations, not pixel or GPU completion evidence.
using System;
using System.Collections.Generic;
using System.IO;
using System.Reflection;
using HybridLumenGI;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

[DefaultExecutionOrder(-30000)]
public sealed class ContinuousNearFar : MonoBehaviour
{
    const int RoundTrips = 10, ReadyFrames = 16, MaxCallbacks = 4096;
    const double Speed = 20, WarmLimit = 30, SettleLimit = 30;
    const string ExpectedScene = "Assets/UnifiedRelease74/Generated/Variant/UnifiedSample.unity";
    const BindingFlags Fields = BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic;
    HybridLumenGIUnifiedSample sample;
    HybridLumenGIRendererFeature feature;
    HybridLumenGIRendererFeature.Settings settings;
    HybridLumenGIAssetPageStreamer streamer;
    HybridLumenGIStreamedRepresentation[] members;
    Camera targetCamera;
    HybridLumenGIUnifiedSampleInteraction[] inputs;
    readonly List<HybridLumenGIProxy> published = new List<HybridLumenGIProxy>();
    readonly List<HybridLumenGIProxy> target = new List<HybridLumenGIProxy>();
    readonly List<Frame> records = new List<Frame>();
    Vector3 nearPosition, farPosition;
    Quaternion nearRotation, farRotation;
    Bounds groupBounds;
    Matrix4x4 projection;
    double startTime, motionStart, settleStart, distance, duration, pathSeconds;
    float farDistance, pathFraction;
    int readyStreak, beginCount, endCount, lastBegin = -1, leg, targetChanges, publicationChanges;
    int[] previousTarget, previousPublished;
    string directory, settingsJson, failure, phase = "warmup";
    bool initialized, subscribed, startMoving, finishing, finished, motionIoObserved;
    Frame pending;
    HybridLumenGIUnifiedSample.Ledger startLedger, endLedger;

    [Serializable] sealed class Member
    {
        public string role, name;
        public int bindingId, proxyId, stableId, rendererId;
        public bool rendererEnabled, active, forceRenderingOff, hasBoundAssets, proxyEnabled, sourceMatches, canSubmit;
    }
    [Serializable] sealed class Frame
    {
        public int index, engineFrame, endEngineFrame = -1, leg;
        public string phase, beginGroup, publishedGroup, targetGroup, error;
        public double pathSeconds, beginSeconds, endSeconds;
        public float pathFraction;
        public Vector3 position;
        public Quaternion rotation;
        public Member[] beginMembers, endMembers;
        public bool ended, publicationKnown, publicationCurrent, publishedBound;
        public int[] publishedIds, targetIds;
        public string publicationPhase;
        public int rootStableId, preparedEngineFrame, preparedWorkFrame, sceneRevision;
        public int targetWarmingCount, targetUnknownCount, pagePending;
        public bool transitioning, capacityFallback;
        public HybridLumenGIUnifiedSample.Ledger ledger;
    }
    [Serializable] sealed class Run
    {
        public string outcome, error, scene, unity, gpu, api, settings, coverage;
        public string scope = "Target-camera CPU renderer submission flags and HLOD publication/target identities. Not pixel coverage, GPU completion, image quality, timing or memory acceptance.";
        public int roundTrips = RoundTrips, readyFrames = ReadyFrames, maxCallbacks = MaxCallbacks;
        public double worldUnitsPerSecond = Speed, warmLimitSeconds = WarmLimit, settleLimitSeconds = SettleLimit;
        public double oneWayDistance, plannedMotionSeconds;
        public Vector3 nearPosition, farPosition;
        public Quaternion nearRotation, farRotation;
        public Bounds groupBounds;
        public float farDistance;
        public int beginCallbacks, endCallbacks, targetChanges, publicationChanges;
        public bool actualMotionIoObserved, returnedNear, completeNearRecovered;
        public HybridLumenGIUnifiedSample.Ledger start, end;
        public Frame[] frames;
    }
    static T Field<T>(object value, string name)
    {
        var field = value.GetType().GetField(name, Fields);
        if (field == null) throw new InvalidOperationException("Missing sample field: " + name);
        return (T)field.GetValue(value);
    }
    static void Require(bool value, string message) { if (!value) throw new InvalidOperationException(message); }
    static bool Finite(double value) => !double.IsNaN(value) && !double.IsInfinity(value);

    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
    static void Install()
    {
        string[] args = Environment.GetCommandLineArgs();
        int index = Array.IndexOf(args, "-continuousNearFarOutput");
        if (index < 0) return;
        var host = new GameObject("Continuous near/far observer").AddComponent<ContinuousNearFar>();
        DontDestroyOnLoad(host.gameObject);
        host.directory = index + 1 < args.Length ? args[index + 1] : null;
        Application.runInBackground = true;
        try
        {
            var samples = UnityEngine.Object.FindObjectsByType<HybridLumenGIUnifiedSample>(FindObjectsSortMode.None);
            Require(samples.Length == 1, "Exactly one existing UnifiedSample is required.");
            host.sample = samples[0];
            host.inputs = UnityEngine.Object.FindObjectsByType<HybridLumenGIUnifiedSampleInteraction>(FindObjectsSortMode.None);
            // Before Start: do not initialize the ordinary deformation/input producer.
            foreach (var input in host.inputs) input.enabled = false;
            host.sample.ShowControls = false;
            host.sample.MeasureVideoMemory = false;
        }
        catch (Exception error) { host.Fail(error.ToString()); }
    }
    void Start()
    {
        try
        {
            Require(!string.IsNullOrWhiteSpace(directory) && Path.IsPathRooted(directory) && Directory.Exists(directory),
                "An existing absolute -continuousNearFarOutput directory is required.");
            Require(!File.Exists(Path.Combine(directory, "run.json")), "Refusing to overwrite run.json.");
            if (failure != null) return;
            Require(sample && sample.isActiveAndEnabled && sample.gameObject.scene.path == ExpectedScene, "Expected active saved sample required.");
            targetCamera = Field<Camera>(sample, "targetCamera");
            feature = Field<HybridLumenGIRendererFeature>(sample, "feature");
            streamer = Field<HybridLumenGIAssetPageStreamer>(sample, "streamer");
            var root = Field<HybridLumenGIStreamedRepresentation>(sample, "aggregate");
            var details = Field<HybridLumenGIStreamedRepresentation[]>(sample, "details");
            Require(targetCamera && feature && feature.isActive && streamer && root && details != null && details.Length == 3,
                "Existing camera, feature, streamer, aggregate and three details required.");
            members = new[] { root, details[0], details[1], details[2] };
            var uniqueProxies = new HashSet<HybridLumenGIProxy>();
            var uniqueRenderers = new HashSet<Renderer>();
            foreach (var member in members)
                Require(member && member.Proxy && member.SourceRenderer && uniqueProxies.Add(member.Proxy) && uniqueRenderers.Add(member.SourceRenderer),
                    "Representation identities must be present and distinct.");
            nearPosition = Field<Vector3>(sample, "nearPosition"); farPosition = Field<Vector3>(sample, "farPosition");
            nearRotation = Field<Quaternion>(sample, "nearRotation"); farRotation = Field<Quaternion>(sample, "farRotation");
            groupBounds = Field<Bounds>(sample, "groupBounds"); farDistance = Field<float>(sample, "farDistance");
            distance = Vector3.Distance(nearPosition, farPosition); duration = distance * (2 * RoundTrips) / Speed;
            Require(Finite(distance) && distance > 0 && Finite(farDistance) && farDistance > 0 &&
                groupBounds.SqrDistance(nearPosition) <= farDistance * farDistance && groupBounds.SqrDistance(farPosition) <= farDistance * farDistance,
                "Finite distinct Near/Far endpoints must stay inside the existing resident domain.");
            settings = Field<HybridLumenGIRendererFeature.Settings>(feature, "settings");
            Require(settings != null && settings.preferHardwareTracing && settings.raysPerPixel == 2 && settings.resolutionScale == .5f &&
                !settings.measureGpuCost && !settings.adaptiveGpuBudget, "Expected 2-ray half-resolution DXR preference with measurement/feedback off.");
            settingsJson = JsonUtility.ToJson(settings);
            Require(SystemInfo.graphicsDeviceType == GraphicsDeviceType.Direct3D12, "Existing DX12 Player required.");
            var data = targetCamera.GetUniversalAdditionalCameraData();
            Require(targetCamera.isActiveAndEnabled && targetCamera.targetTexture == null && !targetCamera.stereoEnabled &&
                data.renderType == CameraRenderType.Base && data.cameraStack.Count == 0, "Ordinary enabled Base backbuffer camera required.");
            Require(Screen.width == 960 && Screen.height == 540 && targetCamera.pixelWidth == 960 && targetCamera.pixelHeight == 540,
                "Launch at 960x540; observer does not resize.");
            projection = targetCamera.projectionMatrix;
            targetCamera.transform.SetPositionAndRotation(nearPosition, nearRotation);
            startTime = Time.realtimeSinceStartupAsDouble;
            // Start follows scene OnEnable, so sample.BeforeCamera/AfterCamera run before these observations.
            RenderPipelineManager.beginCameraRendering += Began;
            RenderPipelineManager.endCameraRendering += Ended;
            Application.logMessageReceived += Log;
            subscribed = true; initialized = true;
        }
        catch (Exception error) { Fail(error.ToString()); }
    }
    void Update()
    {
        if (finished) return;
        if (finishing) { Finish(); return; }
        if (!initialized) return;
        try
        {
            double now = Time.realtimeSinceStartupAsDouble;
            if (startMoving) { startMoving = false; phase = "moving"; motionStart = now; }
            if (phase == "warmup") Require(now - startTime <= WarmLimit, "Initial complete Near readiness exceeded 30 seconds.");
            else if (phase == "moving")
            {
                pathSeconds = Math.Min(now - motionStart, duration);
                double travel = pathSeconds * Speed / distance;
                leg = Math.Min(2 * RoundTrips, (int)Math.Floor(travel));
                pathFraction = (float)(travel % 2 <= 1 ? travel % 2 : 2 - travel % 2);
                if (pathSeconds >= duration) { phase = "settling"; settleStart = now; pathFraction = 0; leg = 2 * RoundTrips; }
                targetCamera.transform.SetPositionAndRotation(Vector3.Lerp(nearPosition, farPosition, pathFraction), Quaternion.Slerp(nearRotation, farRotation, pathFraction));
            }
            else Require(now - settleStart <= SettleLimit, "Near recovery exceeded 30 seconds.");
        }
        catch (Exception error) { Fail(error.ToString()); }
    }
    Member[] ReadMembers()
    {
        var values = new Member[members.Length];
        for (int i = 0; i < members.Length; i++)
        {
            var member = members[i]; Require(member && member.Proxy && member.SourceRenderer, "An authored representation was destroyed.");
            var renderer = member.SourceRenderer;
            values[i] = new Member { role = i == 0 ? "root" : "detail" + (i - 1), name = member.name,
                bindingId = member.GetInstanceID(), proxyId = member.Proxy.GetInstanceID(), stableId = member.Proxy.StableId, rendererId = renderer.GetInstanceID(),
                rendererEnabled = renderer.enabled, active = renderer.gameObject.activeInHierarchy, forceRenderingOff = renderer.forceRenderingOff,
                hasBoundAssets = member.HasBoundAssets, proxyEnabled = member.Proxy.isActiveAndEnabled, sourceMatches = member.Proxy.SourceRenderer == renderer,
                canSubmit = renderer.enabled && renderer.gameObject.activeInHierarchy && !renderer.forceRenderingOff };
        }
        return values;
    }
    static string SubmissionGroup(Member[] values)
    {
        bool root = values[0].canSubmit, allDetails = true; int count = 0;
        for (int i = 0; i < values.Length; i++)
        {
            if (i > 0) allDetails &= values[i].canSubmit;
            if (!values[i].canSubmit) continue;
            count++;
            if (!values[i].hasBoundAssets || !values[i].sourceMatches) return "invalid-source";
        }
        return count == 0 ? "none" : root && count == 1 ? "root" : !root && allDetails && count == 3 ? "details" : "partial-or-double";
    }
    string Group(List<HybridLumenGIProxy> values)
    {
        if (values.Count == 0) return "none";
        if (values.Count == 1 && values[0] == members[0].Proxy) return "root";
        if (values.Count == 3 && values.Contains(members[1].Proxy) && values.Contains(members[2].Proxy) && values.Contains(members[3].Proxy)) return "details";
        return "partial-or-foreign";
    }
    static bool Complete(string group) => group == "root" || group == "details";
    static int[] Ids(List<HybridLumenGIProxy> values)
    {
        int[] ids = new int[values.Count]; for (int i = 0; i < ids.Length; i++) ids[i] = values[i] ? values[i].StableId : 0;
        Array.Sort(ids); return ids;
    }
    static bool Same(int[] a, int[] b)
    { if (a == null || b == null || a.Length != b.Length) return false; for (int i = 0; i < a.Length; i++) if (a[i] != b[i]) return false; return true; }
    void Began(ScriptableRenderContext context, Camera camera)
    {
        if (camera != targetCamera || finished || finishing) return;
        try
        {
            Require(pending == null && Time.frameCount > lastBegin && beginCount < MaxCallbacks, "Duplicate/unclosed target render or 4096-callback limit.");
            lastBegin = Time.frameCount; beginCount++;
            pending = new Frame { index = records.Count, engineFrame = Time.frameCount, phase = phase, leg = leg,
                pathSeconds = pathSeconds, beginSeconds = Time.realtimeSinceStartupAsDouble,
                pathFraction = pathFraction, position = camera.transform.position, rotation = camera.transform.rotation };
            records.Add(pending); // Keep even a begin-only or failing frame.
            pending.beginMembers = ReadMembers(); pending.beginGroup = SubmissionGroup(pending.beginMembers);
        }
        catch (Exception error) { if (pending != null) pending.error = error.ToString(); Fail(error.ToString()); }
    }
    void Ended(ScriptableRenderContext context, Camera camera)
    {
        if (camera != targetCamera || finished || pending == null) return;
        Frame row = pending; pending = null; endCount++;
        try
        {
            row.ended = true; row.endEngineFrame = Time.frameCount; row.endSeconds = Time.realtimeSinceStartupAsDouble;
            row.endMembers = ReadMembers();
            row.publicationKnown = feature.TryGetHlodPublication(camera, members[0].Proxy, published, target, out var publication);
            row.publicationCurrent = row.publicationKnown && publication.preparedEngineFrame == Time.frameCount;
            row.publicationPhase = publication.phase.ToString(); row.rootStableId = publication.rootStableId;
            row.preparedEngineFrame = publication.preparedEngineFrame; row.preparedWorkFrame = publication.preparedWorkFrame; row.sceneRevision = publication.sceneRevision;
            row.transitioning = publication.transitioning; row.capacityFallback = publication.capacityFallback;
            row.targetWarmingCount = publication.targetWarmingCount; row.targetUnknownCount = publication.targetUnknownCount;
            row.publishedIds = Ids(published); row.targetIds = Ids(target); row.publishedGroup = Group(published); row.targetGroup = Group(target);
            row.publishedBound = Complete(row.publishedGroup);
            foreach (var proxy in published)
            {
                bool bound = false;
                for (int i = 0; i < members.Length; i++) if (members[i].Proxy == proxy)
                    bound = members[i].HasBoundAssets && row.endMembers[i].sourceMatches && proxy.isActiveAndEnabled;
                row.publishedBound &= bound;
            }
            row.ledger = sample.CaptureLedger(); endLedger = row.ledger;
            var pages = streamer.State;
            row.pagePending = pages == null ? -1 : 0;
            if (pages != null) foreach (var page in pages.States)
                if ((page.Wanted && page.Status != HybridLumenGIAssetPageStreaming.Phase.Ready) ||
                    page.Status == HybridLumenGIAssetPageStreaming.Phase.LoadingBundle || page.Status == HybridLumenGIAssetPageStreaming.Phase.BundleReady ||
                    page.Status == HybridLumenGIAssetPageStreaming.Phase.LoadingAsset || page.Status == HybridLumenGIAssetPageStreaming.Phase.Releasing) row.pagePending++;
            Require(row.engineFrame == row.endEngineFrame, "Target begin/end engine frames differ.");
            Require(sample.isActiveAndEnabled && !sample.ShowControls && !sample.MeasureVideoMemory && feature.isActive &&
                JsonUtility.ToJson(settings) == settingsJson && camera.targetTexture == null && camera.projectionMatrix == projection &&
                camera.pixelWidth == 960 && camera.pixelHeight == 540, "Existing sample configuration changed.");
            foreach (var input in inputs) Require(!input || !input.enabled, "Ordinary interaction unexpectedly enabled.");
            bool complete = row.publicationCurrent && publication.phase == HybridLumenGIScene.PublicationPhase.Published && row.publishedBound;
            bool nearReady = row.beginGroup == "details" && complete && row.publishedGroup == "details" && row.targetGroup == "details" &&
                !row.transitioning && row.targetWarmingCount == 0 && row.targetUnknownCount == 0 && row.pagePending == 0 && streamer.Available &&
                row.ledger.pagesFailed == 0 && row.ledger.pageActiveOperations == 0 && row.ledger.pageIoBytesInFlight == 0 && row.ledger.pageRetiringLeases == 0;
            double now = Time.realtimeSinceStartupAsDouble;
            if (phase == "warmup")
            {
                Require(now - startTime <= WarmLimit, "Initial complete Near readiness exceeded 30 seconds.");
                readyStreak = nearReady ? readyStreak + 1 : 0;
                if (readyStreak == ReadyFrames)
                { startLedger = row.ledger; previousTarget = row.targetIds; previousPublished = row.publishedIds; startMoving = true; }
            }
            else
            {
                if (phase == "moving")
                {
                    if (!Same(previousTarget, row.targetIds)) targetChanges++;
                    if (!Same(previousPublished, row.publishedIds)) publicationChanges++;
                    motionIoObserved |= row.ledger.pageIoBytesStartedThisStep > 0 || row.ledger.pageIoBytesInFlight > 0;
                }
                previousTarget = row.targetIds; previousPublished = row.publishedIds;
                Require(Complete(row.beginGroup), "No complete bound root/details renderer submission group at beginCamera.");
                Require(complete, "No current complete bound root/details publication at endCamera.");
                if (phase == "settling")
                {
                    Require(now - settleStart <= SettleLimit, "Near recovery exceeded 30 seconds.");
                    if (nearReady) finishing = true;
                }
            }
            if (!finishing) Require(beginCount < MaxCallbacks, "4096 target-camera callback limit reached before completion.");
        }
        catch (Exception error) { row.error = error.ToString(); Fail(error.ToString()); }
    }
    void Log(string message, string stack, LogType type)
    { if (type == LogType.Error || type == LogType.Exception || type == LogType.Assert) Fail("Unity " + type + ": " + message); }
    void Fail(string error) { if (failure == null) failure = error; finishing = true; }
    void Finish()
    {
        if (finished) return;
        finished = true;
        if (subscribed)
        {
            RenderPipelineManager.beginCameraRendering -= Began; RenderPipelineManager.endCameraRendering -= Ended;
            Application.logMessageReceived -= Log; subscribed = false;
        }
        bool recovered = failure == null && phase == "settling" && records.Count > 0 && records[records.Count - 1].ended;
        if (!recovered && failure == null) failure = "Run ended without complete Near recovery.";
        int exit = failure == null ? 0 : 1;
        try
        {
            var run = new Run { outcome = failure != null ? "failed" : motionIoObserved && targetChanges > 0 ? "complete-limited-hot-route" : "complete-hot-route-scope-insufficient",
                error = failure, scene = sample ? sample.gameObject.scene.path : null, unity = Application.unityVersion,
                gpu = SystemInfo.graphicsDeviceName, api = SystemInfo.graphicsDeviceType.ToString(), settings = settingsJson,
                coverage = "Only this resident Near/Far route. IO/target/publication changes are observed CPU facts; absent activity does not trigger retries or establish cold/high-speed cross-region coverage.",
                oneWayDistance = distance, plannedMotionSeconds = duration, nearPosition = nearPosition, farPosition = farPosition,
                nearRotation = nearRotation, farRotation = farRotation, groupBounds = groupBounds, farDistance = farDistance,
                beginCallbacks = beginCount, endCallbacks = endCount, targetChanges = targetChanges, publicationChanges = publicationChanges,
                actualMotionIoObserved = motionIoObserved, returnedNear = phase == "settling", completeNearRecovered = recovered,
                start = startLedger, end = endLedger, frames = records.ToArray() };
            // CreateNew protects an earlier result, including failures. No per-frame file writes.
            using (var file = new FileStream(Path.Combine(directory, "run.json"), FileMode.CreateNew, FileAccess.Write))
            using (var writer = new StreamWriter(file)) writer.Write(JsonUtility.ToJson(run, true));
        }
        catch (Exception error) { exit = 1; Debug.LogError("ContinuousNearFar result write failed: " + error); }
        finally { Application.Quit(exit); }
    }
    void OnApplicationQuit()
    { if (!finished) { Fail("Player quit before the bounded route completed."); Finish(); } }
}
