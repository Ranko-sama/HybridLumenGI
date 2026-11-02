using System;
using System.Collections.Generic;
using System.Globalization;
using UnityEngine;
using UnityEngine.Rendering;

namespace HybridLumenGI
{
    /// <summary>Single-camera sample orchestration. It never supplies an unload completion ticket.</summary>
    [DefaultExecutionOrder(10000), DisallowMultipleComponent]
    public sealed class HybridLumenGIUnifiedSample : MonoBehaviour
    {
        [SerializeField] private Camera targetCamera;
        [SerializeField] private HybridLumenGIRendererFeature feature;
        [SerializeField] private HybridLumenGIAssetPageStreamer streamer;
        [SerializeField] private HybridLumenGIStreamedRepresentation aggregate;
        [SerializeField] private HybridLumenGIStreamedRepresentation[] details = Array.Empty<HybridLumenGIStreamedRepresentation>();
        [SerializeField] private Bounds groupBounds;
        [SerializeField] private float nearDistance, farDistance;
        [SerializeField] private Vector3 nearPosition, farPosition, outsidePosition;
        [SerializeField] private Quaternion nearRotation, farRotation, outsideRotation;
        [SerializeField] private bool showControls = true;
        [SerializeField, Tooltip("Optional DXGI process usage on the Unity adapter. Samples once per LateUpdate; does not change GI budgets.")]
        private bool measureVideoMemory;
        private readonly HybridLumenGIVideoMemory videoMemory = new HybridLumenGIVideoMemory();
        private readonly List<HybridLumenGIProxy> published = new List<HybridLumenGIProxy>();
        private readonly List<HybridLumenGIProxy> target = new List<HybridLumenGIProxy>();
        private readonly HashSet<HybridLumenGIProxy> visible = new HashSet<HybridLumenGIProxy>();
        private HybridLumenGIScene.HlodPublicationSnapshot publication;
        private string status = "cold: waiting for complete page bindings and GI publication";
        private int lastReceiptEngine = -1, lastReceiptWork = -1;
        private bool subscribed, detailsWanted, singleCameraSupported = true;
        private bool residentWanted;
        private int requestEngineFrame = -1;
        private double nextOverlay;
        private string overlay;
        private bool showGpuControls, gpuTargetFocused;
        private string gpuTargetText = "", gpuTargetControlName, gpuInputMessage, gpuOverlay;
        private Vector2 controlsScroll;
        public bool ShowControls
        {
            get => showControls;
            set { showControls = value; if (!value) gpuTargetFocused = false; }
        }
        public bool MeasureVideoMemory { get => measureVideoMemory; set => measureVideoMemory = value; }
        public bool IsEditingGpuTarget => isActiveAndEnabled && subscribed && showControls &&
            showGpuControls && Application.isFocused && gpuTargetFocused;

        public void Configure(Camera camera, HybridLumenGIRendererFeature rendererFeature,
            HybridLumenGIAssetPageStreamer pages, HybridLumenGIStreamedRepresentation root,
            HybridLumenGIStreamedRepresentation[] members, Bounds bounds, float near, float far)
        {
            if (Application.isPlaying) throw new InvalidOperationException("Configure the inactive authored sample before Play.");
            if (camera == null || rendererFeature == null || pages == null || root == null || members == null || members.Length == 0)
                throw new ArgumentException("A camera, feature, page driver and complete detail/root group are required.");
            targetCamera = camera; feature = rendererFeature; streamer = pages; aggregate = root;
            details = (HybridLumenGIStreamedRepresentation[])members.Clone(); groupBounds = bounds;
            nearDistance = Mathf.Max(.1f, near); farDistance = Mathf.Max(nearDistance, far);
            nearPosition = camera.transform.position; nearRotation = camera.transform.rotation;
            Vector3 outward = (nearPosition - bounds.center).normalized;
            if (outward.sqrMagnitude < .5f) outward = Vector3.back;
            float radius = bounds.extents.magnitude;
            farPosition = bounds.center + outward * (radius + nearDistance * 1.5f);
            outsidePosition = bounds.center + outward * (radius + farDistance + 20f);
            farRotation = Quaternion.LookRotation(bounds.center - farPosition, Vector3.up);
            outsideRotation = Quaternion.LookRotation(bounds.center - outsidePosition, Vector3.up);
            foreach (var binding in Bindings()) { binding.SetWanted(false); binding.SourceRenderer.forceRenderingOff = true; }
        }

        private IEnumerable<HybridLumenGIStreamedRepresentation> Bindings()
        { if (aggregate != null) yield return aggregate; foreach (var item in details) if (item != null) yield return item; }
        private bool HasInputs()
        {
            if (targetCamera == null || feature == null || streamer == null || aggregate == null || aggregate.Proxy == null ||
                aggregate.SourceRenderer == null || details == null || details.Length == 0) return false;
            foreach (var item in details) if (item == null || item.Proxy == null || item.SourceRenderer == null) return false;
            return true;
        }
        private bool KeepRunning()
        {
            if (HasInputs()) return true;
            status = "sample input was destroyed or detached"; enabled = false; return false;
        }

        private void OnEnable()
        {
            if (!Application.isPlaying) return;
            if (!HasInputs())
            { status = "invalid sample configuration"; enabled = false; return; }
            float requestedTarget = feature.RequestedTargetGpuMilliseconds;
            gpuTargetText = requestedTarget > 0 && !float.IsInfinity(requestedTarget)
                ? requestedTarget.ToString("R", CultureInfo.InvariantCulture) : "";
            gpuTargetControlName = "HLGI GPU target " + GetInstanceID();
            gpuTargetFocused = false; gpuInputMessage = null; nextOverlay = 0;
            requestEngineFrame = -1; residentWanted = false;
            HybridLumenGIResourceRetirement.Register(RequiresVisible);
            RenderPipelineManager.beginCameraRendering += BeforeCamera;
            RenderPipelineManager.endCameraRendering += AfterCamera;
            subscribed = true;
            ApplyVisibility();
        }
        private void OnDisable()
        {
            gpuTargetFocused = false;
            residentWanted = false; requestEngineFrame = Time.frameCount;
            videoMemory.Sample(Time.frameCount, false);
            if (!subscribed) return;
            RenderPipelineManager.beginCameraRendering -= BeforeCamera;
            RenderPipelineManager.endCameraRendering -= AfterCamera;
            visible.Clear(); ApplyVisibility();
            foreach (var binding in Bindings())
            {
                binding.SetWanted(false);
                // Withdraw this sample from new GI readers, then let ordinary retirement detach/fence its pages.
                if (binding.Proxy != null) binding.Proxy.enabled = false;
            }
            HybridLumenGIResourceRetirement.Unregister(RequiresVisible); subscribed = false;
        }
        private bool RequiresVisible(HybridLumenGIProxy proxy) => visible.Contains(proxy);
        private void Update()
        {
            if (!subscribed || !KeepRunning()) return;
            float distance = Mathf.Sqrt(groupBounds.SqrDistance(targetCamera.transform.position));
            residentWanted = distance <= farDistance + 5f;
            if (!residentWanted) detailsWanted = false;
            else if (distance < nearDistance * 1.2f) detailsWanted = true;
            else if (distance > nearDistance * 1.4f) detailsWanted = false;
            aggregate.SetWanted(residentWanted);
            foreach (var item in details) item.SetWanted(residentWanted && detailsWanted);
            requestEngineFrame = Time.frameCount;
        }
        private void LateUpdate()
        {
            if (!subscribed || !KeepRunning()) return;
            videoMemory.Sample(Time.frameCount, measureVideoMemory);
            if (aggregate.Proxy != null) aggregate.Proxy.enabled = aggregate.HasBoundAssets;
            // Binding is per representation. Do not expose a partial authored detail set to Scene.Prepare.
            bool complete = aggregate.HasBoundAssets;
            foreach (var item in details) complete &= item.HasBoundAssets;
            foreach (var item in details)
                if (item.HasBoundAssets) item.Proxy.enabled = complete;
            ApplyVisibility();
        }
        private void BeforeCamera(ScriptableRenderContext context, Camera camera)
        {
            if (camera != targetCamera || !KeepRunning()) return;
            singleCameraSupported = true;
            // forceRenderingOff is renderer-wide, so this sample has one enabled Game camera.
            foreach (Camera other in Camera.allCameras)
                if (other != camera && other.isActiveAndEnabled && other.cameraType == CameraType.Game)
                { singleCameraSupported = false; status = "unsupported: another Game camera is enabled"; visible.Clear(); ApplyVisibility(); return; }
            ApplyVisibility();
        }
        private void AfterCamera(ScriptableRenderContext context, Camera camera)
        {
            if (camera != targetCamera || !KeepRunning()) return;
            if (!singleCameraSupported) return;
            if (!feature.TryGetHlodPublication(camera, aggregate.Proxy, published, target, out publication) ||
                publication.preparedEngineFrame != Time.frameCount)
            {
                status = "waiting: no current complete publication; previous visible set retained while bound";
                // Outside the GI domain there is deliberately no visible representation and no visual consumer.
                if (groupBounds.SqrDistance(camera.transform.position) > farDistance * farDistance) visible.Clear();
                ApplyVisibility(); return;
            }
            lastReceiptEngine = publication.preparedEngineFrame; lastReceiptWork = publication.preparedWorkFrame;
            bool rootPublished = published.Count == 1 && published[0] == aggregate.Proxy && aggregate.HasBoundAssets;
            bool detailPublished = published.Count == details.Length;
            foreach (var item in details) detailPublished &= item.HasBoundAssets && published.Contains(item.Proxy);
            if (publication.phase == HybridLumenGIScene.PublicationPhase.Published && (rootPublished || detailPublished))
            {
                visible.Clear(); foreach (var proxy in published) visible.Add(proxy);
                status = rootPublished ? "aggregate published" : "complete details published";
                if (publication.transitioning) status += "; replacement warming";
            }
            else status = "waiting: publication does not equal the complete authored root/detail set";
            // This applies at the completed camera boundary, before retirement examines ordinary URP consumers.
            ApplyVisibility();
        }
        private void ApplyVisibility()
        {
            foreach (var item in Bindings())
                if (item.SourceRenderer != null)
                    item.SourceRenderer.forceRenderingOff = !item.HasBoundAssets || !visible.Contains(item.Proxy);
        }
        public void SetHardwarePreference(bool value) => feature.SetPreferHardwareTracing(value);
        public void GoNear() => targetCamera.transform.SetPositionAndRotation(nearPosition, nearRotation);
        public void GoFar() => targetCamera.transform.SetPositionAndRotation(farPosition, farRotation);
        public void Leave() => targetCamera.transform.SetPositionAndRotation(outsidePosition, outsideRotation);

        [Serializable] public sealed class Ledger
        {
            public string scope = "Page admission estimates; per-camera GI estimates; global RTAS/material pool and retirement once. Not total VRAM and not additive.";
            public string status, requestedBackend, actualBackend, diagnosticsStatus;
            // Request is the latest sample Update; availability uses the current
            // renderer flags of the retained publication-based visible set.
            public string representationScope = "Sample request and renderer-submittable group; not pixel coverage or GPU completion.";
            public string requestedRepresentation, availableRepresentation, representationStatus;
            public int requestEngineFrame;
            public Vector3 cameraPosition;
            public int engineFrame, publicationEngineFrame, publicationWorkFrame, visibleMembers, boundMembers;
            public int pagesReady, pagesLoading, pagesReleasing, pagesFailed, pageConsumerReferences, budgetBlockedGroups;
            public long pageBundleBytes, pageResidentBytes, pageIoBytesInFlight, pageIoBytesStartedThisStep, pageUploadBytesStartedThisStep;
            public int pageActiveOperations, pageRetiringLeases, pageOperationsStartedThisStep, pageBudgetBlockedThisStep;
            public HybridLumenGIRendererFeature.CameraDiagnostics cameraGi;
            public bool requestedMeasureGpuCost, requestedAdaptiveGpuBudget;
            public float requestedTargetGpuMilliseconds;
            // Process-wide values observed in this sample's enabled window; never sum across cameras.
            public HybridLumenGIVideoMemory.Snapshot processVideoMemory;
            public int retirementPending, retirementOwned, retirementFailed, retirementUnknownSubmissions;
            public bool featureEnabled, retirementSubmissionUncertain;
        }
        public Ledger CaptureLedger()
        {
            var result = new Ledger { status = status, engineFrame = Time.frameCount,
                cameraPosition = targetCamera ? targetCamera.transform.position : default,
                processVideoMemory = videoMemory.Current,
                publicationEngineFrame = lastReceiptEngine, publicationWorkFrame = lastReceiptWork,
                visibleMembers = visible.Count, requestedBackend = feature.RequestedPreferHardwareTracing ? "prefer DXR" : "software",
                actualBackend = "unknown", diagnosticsStatus = "no camera diagnostic", budgetBlockedGroups = streamer.BudgetBlockedGroups,
                featureEnabled = feature.isActive,
                requestedMeasureGpuCost = feature.RequestedMeasureGpuCost,
                requestedAdaptiveGpuBudget = feature.RequestedAdaptiveGpuBudget,
                requestedTargetGpuMilliseconds = feature.RequestedTargetGpuMilliseconds,
                retirementPending = HybridLumenGIResourceRetirement.PendingCount, retirementOwned = HybridLumenGIResourceRetirement.OwnedCount,
                retirementFailed = HybridLumenGIResourceRetirement.FailedCount, retirementUnknownSubmissions = HybridLumenGIResourceRetirement.UnknownSubmissionCount,
                retirementSubmissionUncertain = HybridLumenGIResourceRetirement.SubmissionUncertain };
            foreach (var item in Bindings()) if (item.HasBoundAssets) result.boundMembers++;
            var pages = streamer.State;
            if (pages != null)
            {
                result.pageBundleBytes = pages.BundleBytes; result.pageResidentBytes = pages.ResidentBytes;
                result.pageIoBytesInFlight = pages.IoBytesInFlight; result.pageIoBytesStartedThisStep = pages.IoBytesStarted;
                result.pageUploadBytesStartedThisStep = pages.UploadBytesStarted; result.pageActiveOperations = pages.ActiveOperations;
                result.pageOperationsStartedThisStep = pages.OperationsStarted; result.pageBudgetBlockedThisStep = pages.BudgetBlocked;
                result.pageRetiringLeases = pages.RetiringLeases;
                foreach (var page in pages.States)
                {
                    result.pageConsumerReferences += page.ConsumerReferences;
                    switch (page.Status)
                    {
                        case HybridLumenGIAssetPageStreaming.Phase.Ready: result.pagesReady++; break;
                        case HybridLumenGIAssetPageStreaming.Phase.LoadingBundle:
                        case HybridLumenGIAssetPageStreaming.Phase.BundleReady:
                        case HybridLumenGIAssetPageStreaming.Phase.LoadingAsset: result.pagesLoading++; break;
                        case HybridLumenGIAssetPageStreaming.Phase.Releasing: result.pagesReleasing++; break;
                        case HybridLumenGIAssetPageStreaming.Phase.Failed:
                        case HybridLumenGIAssetPageStreaming.Phase.ReleaseFailed: result.pagesFailed++; break;
                    }
                }
            }
            // Existing diagnostics identify cameras by name. Ambiguous names remain unknown.
            int matches = 0;
            foreach (var row in feature.GetDiagnostics()) if (row.camera == targetCamera.name) { result.cameraGi = row; matches++; }
            if (matches == 1)
            {
                result.diagnosticsStatus = "latest CPU diagnostic; not GPU completion";
                result.actualBackend = !feature.isActive ? "GI disabled" : result.cameraGi.hardwareBackend ? "DXR" : result.cameraGi.exactSoftwareGeometry ? "exact software" : "SDF/analytic software";
            }
            else { result.cameraGi = null; if (matches > 1) result.diagnosticsStatus = "ambiguous camera name"; }
            CaptureRepresentationState(result);
            return result;
        }
        private void CaptureRepresentationState(Ledger result)
        {
            result.requestEngineFrame = requestEngineFrame;
            result.requestedRepresentation = !subscribed || !isActiveAndEnabled ? "none" :
                requestEngineFrame < 0 ? "not evaluated" : residentWanted ? (detailsWanted ? "details" : "aggregate") : "none";
            result.availableRepresentation = "unknown";
            if (HasInputs() && singleCameraSupported)
            {
                int submitted = 0, submittedDetails = 0; bool rootSubmitted = false, invalid = false;
                var sources = new HashSet<Renderer>();
                var proxies = new HashSet<HybridLumenGIProxy>();
                foreach (var item in Bindings())
                {
                    Renderer renderer = item.SourceRenderer;
                    if (!renderer.enabled || !renderer.gameObject.activeInHierarchy || renderer.forceRenderingOff) continue;
                    submitted++;
                    invalid |= !sources.Add(renderer) || !proxies.Add(item.Proxy) ||
                        !item.HasBoundAssets || !visible.Contains(item.Proxy) || item.Proxy.SourceRenderer != renderer;
                    if (item == aggregate) rootSubmitted = true;
                    else submittedDetails++;
                }
                // Identity comes from the authored root/detail bindings, not a
                // global renderer count. Incomplete/mixed sets remain unknown.
                if (!invalid)
                    result.availableRepresentation = submitted == 0 ? "none" : rootSubmitted && submitted == 1 ? "aggregate" :
                        !rootSubmitted && submittedDetails == details.Length && submitted == details.Length ? "details" : "unknown";
            }
            if (result.requestedRepresentation == "not evaluated")
                result.representationStatus = "Representation request not evaluated yet";
            else if (result.availableRepresentation == "unknown")
                result.representationStatus = "Representation availability unknown";
            else if (result.requestedRepresentation == "none")
                result.representationStatus = result.availableRepresentation == "none" ? "No representation requested" : "Request withdrawn; previous representation still available";
            else if (result.availableRepresentation == "none")
                result.representationStatus = "Representation requested; no complete renderer group available";
            else if (result.requestedRepresentation == result.availableRepresentation)
                result.representationStatus = "Requested representation available";
            else
                result.representationStatus = result.availableRepresentation == "aggregate" ?
                    "Aggregate available; details requested" : "Details retained; aggregate requested";
        }
        public void LogLedger() => Debug.Log("HLGI_UNIFIED_SAMPLE " + JsonUtility.ToJson(CaptureLedger()), this);
        private void OnGUI()
        {
            if (!Application.isPlaying || !showControls || !subscribed)
            { gpuTargetFocused = false; return; }
            if (Time.realtimeSinceStartupAsDouble >= nextOverlay)
            {
                nextOverlay = Time.realtimeSinceStartupAsDouble + .5;
                var row = CaptureLedger();
                overlay = row.status + "\nRequested " + row.requestedBackend + "; actual " + row.actualBackend +
                    "\nGroup request/available: " + row.requestedRepresentation + "/" + row.availableRepresentation +
                    "; " + row.representationStatus +
                    "\nVisible/bound " + row.visibleMembers + "/" + row.boundMembers +
                    "; pages ready/loading/releasing/failed " + row.pagesReady + "/" + row.pagesLoading + "/" + row.pagesReleasing + "/" + row.pagesFailed +
                    "\nPage resident/bundle/IO-inflight estimates (bytes): " + row.pageResidentBytes + "/" + row.pageBundleBytes + "/" + row.pageIoBytesInFlight +
                    "\nRetirement pending/owned/failed/unknown: " + row.retirementPending + "/" + row.retirementOwned + "/" + row.retirementFailed + "/" + row.retirementUnknownSubmissions +
                    "\n" + VideoMemoryLabel(row.processVideoMemory);
                gpuOverlay = GpuTimingLabel(row.cameraGi);
            }
            float desiredHeight = showGpuControls ? 400 : measureVideoMemory ? 335 : 295;
            // The ordinary interaction strip starts at Screen.height - 115.
            float height = Mathf.Min(desiredHeight, Mathf.Max(80, Screen.height - 139));
            GUILayout.BeginArea(new Rect(12, 12, Mathf.Min(760, Screen.width - 24), height), GUI.skin.box);
            controlsScroll = GUILayout.BeginScrollView(controlsScroll);
            GUILayout.Label(overlay); GUILayout.BeginHorizontal();
            if (GUILayout.Button("Near / details")) GoNear();
            if (GUILayout.Button("Far / aggregate")) GoFar();
            if (GUILayout.Button("Leave / release")) Leave();
            if (GUILayout.Button("Software")) SetHardwarePreference(false);
            if (GUILayout.Button("Prefer DXR")) SetHardwarePreference(true);
            if (GUILayout.Button("Log ledger")) LogLedger();
            if (GUILayout.Button(measureVideoMemory ? "Memory: on" : "Memory: off"))
            { measureVideoMemory = !measureVideoMemory; nextOverlay = 0; }
            GUILayout.EndHorizontal();
            bool expanded = GUILayout.Toggle(showGpuControls, "GPU time / update budget", GUI.skin.button);
            if (expanded != showGpuControls)
            {
                showGpuControls = expanded;
                if (!expanded) { GUI.FocusControl(null); gpuTargetFocused = false; }
            }
            if (showGpuControls) DrawGpuControls();
            else gpuTargetFocused = false;
            GUILayout.EndScrollView(); GUILayout.EndArea();
        }
        private void DrawGpuControls()
        {
            string requestedMode = feature.RequestedAdaptiveGpuBudget ? "feedback" :
                feature.RequestedMeasureGpuCost ? "measure only" : "off";
            GUILayout.Label("Requested: " + requestedMode + "; configured target " +
                feature.RequestedTargetGpuMilliseconds.ToString("R", CultureInfo.InvariantCulture) +
                " ms. GI passes only; excludes CPU, some uploads and the rest of the application.");
            GUILayout.BeginHorizontal();
            if (GUILayout.Button("Off")) ConfigureGpuMode(false, false, feature.RequestedTargetGpuMilliseconds);
            if (GUILayout.Button("Measure only")) ConfigureGpuMode(true, false, feature.RequestedTargetGpuMilliseconds);
            GUILayout.Label("Target ms (decimal point):", GUILayout.Width(165));
            GUI.SetNextControlName(gpuTargetControlName);
            gpuTargetText = GUILayout.TextField(gpuTargetText, 32, GUILayout.Width(95));
            if (GUILayout.Button("Apply feedback"))
            {
                if (!float.TryParse(gpuTargetText, NumberStyles.Float, CultureInfo.InvariantCulture, out float targetMs) ||
                    float.IsNaN(targetMs) || float.IsInfinity(targetMs) || targetMs <= 0)
                    gpuInputMessage = "Enter a finite target greater than zero. Configuration unchanged.";
                else ConfigureGpuMode(feature.RequestedMeasureGpuCost, true, targetMs);
            }
            GUILayout.EndHorizontal();
            gpuTargetFocused = GUI.GetNameOfFocusedControl() == gpuTargetControlName;
            if (!string.IsNullOrEmpty(gpuInputMessage)) GUILayout.Label(gpuInputMessage);
            GUILayout.Label(gpuOverlay ?? "GPU timing: no camera diagnostic yet.");
            GUILayout.Label("The target guides GI updates. Changing these controls resets timing and feedback while preserving lighting history.");
        }
        private void ConfigureGpuMode(bool measure, bool feedback, float targetMs)
        {
            if (!feature.TryConfigureGpuBudget(measure, feedback, targetMs))
            { gpuInputMessage = "Invalid target. Configuration unchanged."; return; }
            gpuInputMessage = null; nextOverlay = 0;
            GUI.FocusControl(null); gpuTargetFocused = false;
        }
        private static string GpuTimingLabel(HybridLumenGIRendererFeature.CameraDiagnostics timing)
        {
            if (timing == null) return "GPU timing: no unambiguous camera diagnostic; cost unavailable.";
            bool hasObservation = timing.gpuLastObservationConsumedFrame >= 0 &&
                !double.IsNaN(timing.gpuLastObservedMilliseconds) && !double.IsInfinity(timing.gpuLastObservedMilliseconds) &&
                timing.gpuLastObservedMilliseconds >= 0;
            string observation = "No valid timing sample; cost unavailable.";
            if (hasObservation)
            {
                string source = timing.gpuTimingProvider == "NativeDX12"
                    ? timing.nativeGpuMeasuredSourceFrame >= 0
                        ? timing.nativeGpuMeasuredSourceFrame.ToString(CultureInfo.InvariantCulture) : "unavailable"
                    : "unknown (Recorder)";
                observation = (timing.gpuObservationValid ? "Valid observation: " : "Historical observation (previous configuration possible): ") +
                    timing.gpuLastObservedMilliseconds.ToString("F3", CultureInfo.InvariantCulture) + " ms; source frame " + source +
                    "; consumed frame " + timing.gpuLastObservationConsumedFrame + ".";
            }
            return "Last camera CPU snapshot: " + timing.gpuTimingProvider + " / " + timing.gpuTimingStatus +
                "\n" + observation +
                "\nFeedback active: " + timing.gpuFeedbackActive + "; scale " + timing.gpuWorkScale.ToString("F3", CultureInfo.InvariantCulture) +
                "; effective patches/captures/bricks " + timing.effectiveCachePatchBudget + "/" +
                timing.effectiveSurfaceCaptureBudget + "/" + timing.effectiveGlobalBrickBudget +
                (timing.gpuMinimumWorkOverBudget ? "; minimum work remains over target." : ".");
        }
        private static string VideoMemoryLabel(HybridLumenGIVideoMemory.Snapshot memory)
        {
            if (!memory.valid) return "Process video memory: " + memory.status + ". Resource estimates are not total VRAM.";
            const double mib = 1024.0 * 1024.0;
            return "Process memory MiB - local usage / sampled peak / OS budget: " +
                (memory.localUsageBytes / mib).ToString("F1") + " / " + (memory.peakLocalUsageBytes / mib).ToString("F1") + " / " + (memory.localBudgetBytes / mib).ToString("F1") +
                "\nNonlocal: " + (memory.nonlocalUsageBytes / mib).ToString("F1") + " / " + (memory.peakNonlocalUsageBytes / mib).ToString("F1") + " / " + (memory.nonlocalBudgetBytes / mib).ToString("F1") +
                "\nCPU samples, not instantaneous peaks or GI-only memory; samples " + memory.samples + ", unavailable " + memory.failedSamples + ".";
        }
    }
}
