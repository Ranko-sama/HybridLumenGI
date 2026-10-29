using System;
using System.Collections.Generic;
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
        private readonly List<HybridLumenGIProxy> published = new List<HybridLumenGIProxy>();
        private readonly List<HybridLumenGIProxy> target = new List<HybridLumenGIProxy>();
        private readonly HashSet<HybridLumenGIProxy> visible = new HashSet<HybridLumenGIProxy>();
        private HybridLumenGIScene.HlodPublicationSnapshot publication;
        private string status = "cold: waiting for complete page bindings and GI publication";
        private int lastReceiptEngine = -1, lastReceiptWork = -1;
        private bool subscribed, detailsWanted, singleCameraSupported = true;
        private double nextOverlay;
        private string overlay;

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
            HybridLumenGIResourceRetirement.Register(RequiresVisible);
            RenderPipelineManager.beginCameraRendering += BeforeCamera;
            RenderPipelineManager.endCameraRendering += AfterCamera;
            subscribed = true;
            ApplyVisibility();
        }
        private void OnDisable()
        {
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
            bool residentWanted = distance <= farDistance + 5f;
            if (!residentWanted) detailsWanted = false;
            else if (distance < nearDistance * 1.2f) detailsWanted = true;
            else if (distance > nearDistance * 1.4f) detailsWanted = false;
            aggregate.SetWanted(residentWanted);
            foreach (var item in details) item.SetWanted(residentWanted && detailsWanted);
        }
        private void LateUpdate()
        {
            if (!subscribed || !KeepRunning()) return;
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
            public int engineFrame, publicationEngineFrame, publicationWorkFrame, visibleMembers, boundMembers;
            public int pagesReady, pagesLoading, pagesReleasing, pagesFailed, pageConsumerReferences, budgetBlockedGroups;
            public long pageBundleBytes, pageResidentBytes, pageIoBytesInFlight, pageIoBytesStartedThisStep, pageUploadBytesStartedThisStep;
            public int pageActiveOperations, pageRetiringLeases, pageOperationsStartedThisStep, pageBudgetBlockedThisStep;
            public HybridLumenGIRendererFeature.CameraDiagnostics cameraGi;
            public int retirementPending, retirementOwned, retirementFailed, retirementUnknownSubmissions;
            public bool featureEnabled, retirementSubmissionUncertain;
        }
        public Ledger CaptureLedger()
        {
            var result = new Ledger { status = status, engineFrame = Time.frameCount,
                publicationEngineFrame = lastReceiptEngine, publicationWorkFrame = lastReceiptWork,
                visibleMembers = visible.Count, requestedBackend = feature.RequestedPreferHardwareTracing ? "prefer DXR" : "software",
                actualBackend = "unknown", diagnosticsStatus = "no camera diagnostic", budgetBlockedGroups = streamer.BudgetBlockedGroups,
                featureEnabled = feature.isActive,
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
            return result;
        }
        public void LogLedger() => Debug.Log("HLGI_UNIFIED_SAMPLE " + JsonUtility.ToJson(CaptureLedger()), this);
        private void OnGUI()
        {
            if (!Application.isPlaying || !showControls || !subscribed) return;
            if (Time.realtimeSinceStartupAsDouble >= nextOverlay)
            {
                nextOverlay = Time.realtimeSinceStartupAsDouble + .5;
                var row = CaptureLedger();
                overlay = row.status + "\nRequested " + row.requestedBackend + "; actual " + row.actualBackend +
                    "\nVisible/bound " + row.visibleMembers + "/" + row.boundMembers +
                    "; pages ready/loading/releasing/failed " + row.pagesReady + "/" + row.pagesLoading + "/" + row.pagesReleasing + "/" + row.pagesFailed +
                    "\nPage resident/bundle/IO-inflight estimates (bytes): " + row.pageResidentBytes + "/" + row.pageBundleBytes + "/" + row.pageIoBytesInFlight +
                    "\nRetirement pending/owned/failed/unknown: " + row.retirementPending + "/" + row.retirementOwned + "/" + row.retirementFailed + "/" + row.retirementUnknownSubmissions +
                    "\nNo total-VRAM or performance claim. Log includes GI/global account fields.";
            }
            GUILayout.BeginArea(new Rect(12, 12, 680, 230), GUI.skin.box);
            GUILayout.Label(overlay); GUILayout.BeginHorizontal();
            if (GUILayout.Button("Near / details")) GoNear();
            if (GUILayout.Button("Far / aggregate")) GoFar();
            if (GUILayout.Button("Leave / release")) Leave();
            if (GUILayout.Button("Software")) SetHardwarePreference(false);
            if (GUILayout.Button("Prefer DXR")) SetHardwarePreference(true);
            if (GUILayout.Button("Log ledger")) LogLedger();
            GUILayout.EndHorizontal(); GUILayout.EndArea();
        }
    }
}
