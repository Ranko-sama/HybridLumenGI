using System;
using System.Collections.Generic;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;
using UnityEngine;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.Universal;

namespace HybridLumenGI
{
    /// <summary>Bounded experimental diffuse transport. See Documentation/ProductionPlan.md for release gates.</summary>
    public sealed class HybridLumenGIRendererFeature : ScriptableRendererFeature
    {
        public enum DebugView { Final, IndirectOnly, Confidence, SpatialVariance, DiffuseReflectance }
        public enum CompositionMode { Additive, ReplaceNativeDiffuseGI }
        [Serializable] public sealed class CameraDiagnostics
        {
            public string camera;
            // Last successful CPU transport recording for this camera, after runtime fallback.
            public string recordedTransportBackend;
            public int transportRecordedEngineFrame = -1, transportRecordedWorkFrame = -1;
            public bool transportMatchesBackendRequest;
            public long sceneLightingPolicyBytes;
            public int frame,publishedInstances,warmingInstances,pendingCapacity,bvhNodes;
            public int readyCards,pendingCards,warmupBudgetBlockedCards,cachePatchesScheduled;
            public int chartedOwners,approximateOwners,requiredSurfaceCards;
            public int rejectedSdfSources;
            public int receiverTrackedSubmeshes,receiverUntrackedRenderers,receiverFingerprintMeshes;
            public long receiverFingerprintBytes;
            public bool receiverSourcesPublished;
            public bool receiverIdentityEnabled;
            public string receiverIdentityStatus;
            public int receiverIdentityDraws,receiverUnknownRectangles;
            public long receiverIdentityBufferBytes;
            public long changeRegionBytes;
            public int lightCandidates,lightOutsideDomain,lightSelected,lightCapacityOmitted;
            public bool lightDomainValid;
            public string lightSelectionStatus;
            // Effective configured proposal budget, not a readback of the GPU-selected count.
            public int proposalCapacity,proposalBudget;
            public int globalReadyBricks,globalPendingBricks,globalUpdatedBricks;
            public int completedHlodReadbacks,failedHlodReadbacks,acceptedInitializationTickets;
            public HybridLumenGIHlodReadback.CoverageBlock lastHlodCoverageBlock;
            public bool hlodReadbackPending,hardwareBackend;
            public int hardwareMeshes,hardwareFallbacks,hardwareSceneRebuilds,hardwareTransformUpdates,hardwareTriangleUploads,hardwareBindingUploads;
            public string hardwareMaterialStatus;
            public int hardwareMaterialUnknownRecords;
            public long hardwareMaterialFrameBytes,hardwareMaterialGlobalAllocatedBytes;
            public bool exactSoftwareGeometry;
            public long softwareGeometryBytes,areaEmitterBytes;
            public long rtasGlobalAccountedBytes,rtasGlobalEstimatedBytes,rtasGlobalMeasuredHighWaterBytes,rtasGlobalRetiredBytes;
            public int rtasPendingDemands,rtasBuildsThisFrame;
            public long rtasTriangleWorkThisFrame,rtasInstanceWorkThisFrame;
            public string rtasBudgetStatus;
            public int materialUploadEngineFrame;
            public long materialUploadBudgetBytes,materialUploadBytesUsed;
            public long screenTextureEstimateBytes,worldMaterialBytes,objectSdfBytes,globalSdfBytes,worldCacheBytes,hardwareAttributeBytes,proposalBufferBytes,surfaceTriangleMappingCpuBytes;
            public string gpuTimingStatus;
            public string gpuTimingProvider,nativeGpuTimingStatus;
            // Coverage required for the current configuration, not proof of a valid observation.
            public bool gpuTimingRequiresIdentity;
            public int nativeGpuPendingSubmissions,nativeGpuMeasuredSourceFrame;
            public bool gpuObservationValid,gpuFeedbackActive,gpuMinimumWorkOverBudget;
            public int gpuStableCompletedFrames,gpuLastObservationConsumedFrame,effectiveCachePatchBudget,effectiveSurfaceCaptureBudget,effectiveGlobalBrickBudget;
            public long gpuAcceptedObservations,gpuRejectedObservations;
            public double gpuLastObservedMilliseconds,gpuSmoothedMilliseconds,gpuWorkScale;
        }
        [Serializable] private sealed class DiagnosticReport
        { public string scope="CPU resource estimates plus optional delayed GPU observations for the three GI render passes; excludes preparation uploads outside those passes and RTAS/driver allocation; not a hard GPU deadline";public CameraDiagnostics[] cameras; }
        public CameraDiagnostics[] GetDiagnostics() => pass!=null?pass.GetDiagnostics():Array.Empty<CameraDiagnostics>();
        internal CameraDiagnostics GetCameraDiagnostics(Camera camera) => pass?.GetCameraDiagnostics(camera);
        /// <summary>Read-only latest Prepare snapshot for this exact camera and proxy, on the main thread.
        /// A snapshot is not page readiness, GPU completion, or permission to unload resources.</summary>
        public bool TryGetPublication(Camera camera, HybridLumenGIProxy proxy, out HybridLumenGIScene.PublicationSnapshot value)
        {
            value = new HybridLumenGIScene.PublicationSnapshot { preparedEngineFrame = -1, preparedWorkFrame = -1 };
            return isActive && pass != null && pass.TryGetPublication(camera, proxy, out value);
        }
        /// <summary>Read-only atomic HLOD selection. Caller-owned lists are cleared, then filled only
        /// for a valid group. Published may remain the old representation while target is warming.
        /// Lists are unordered; keep proxies enabled and do not use this result as a retirement fence.</summary>
        public bool TryGetHlodPublication(Camera camera, HybridLumenGIProxy root, List<HybridLumenGIProxy> published,
            List<HybridLumenGIProxy> target, out HybridLumenGIScene.HlodPublicationSnapshot value)
        {
            if (published == null) throw new ArgumentNullException(nameof(published));
            if (target == null) throw new ArgumentNullException(nameof(target));
            if (ReferenceEquals(published, target)) throw new ArgumentException("Published and target lists must be distinct.");
            published.Clear(); target.Clear();
            value = new HybridLumenGIScene.HlodPublicationSnapshot { preparedEngineFrame = -1, preparedWorkFrame = -1 };
            return isActive && pass != null && pass.TryGetHlodPublication(camera, root, published, target, out value);
        }
        [ContextMenu("Log Runtime Diagnostics")]
        public void LogRuntimeDiagnostics() => Debug.Log(JsonUtility.ToJson(new DiagnosticReport{cameras=GetDiagnostics()},true),this);
        [Serializable]
        public sealed class Settings
        {
            [Range(0.25f,1)] public float resolutionScale=0.5f;
            [Range(1,8)] public int raysPerPixel=2;
            [Range(0,64)] public int screenSteps=24;
            [Min(1)] public float traceDistance=50;
            [Min(1),Tooltip("Directional-light visibility distance, still limited by resident scene coverage.")] public float shadowDistance=200;
            [Min(0.001f)] public float rayBias=0.03f;
            [Min(0.001f)] public float screenThickness=0.15f;
            [Range(32,256)] public int residentProxies=128;
            [Min(1)] public float nearDistance=30;
            public bool globalSdfEnabled=true;
            [Range(2,4)] public int globalSdfLevels=4;
            [Range(4,16)] public int globalSdfBricksPerAxis=8;
            [Min(0.1f)] public float globalSdfBaseVoxelSize=1;
            [Range(1,128)] public int globalSdfBricksPerFrame=16;
            [Min(1)] public float farDistance=150;
            [Min(1)] public float chunkSize=16;
            [Range(1,256)] public int proxyUploadsPerFrame=16;
            [UnityEngine.Serialization.FormerlySerializedAs("cacheFacesPerFrame")]
            [Range(1,4096)] public int cachePatchesPerFrame=256;
            [Range(1,4)] public int cachePatchGrid=4;
            [Range(1,32)] public int cacheRaysPerFace=8;
            [Range(0,0.8f)] public float guidedSamplingWeight=0.35f;
            [Range(0,0.8f),Tooltip("Bias GI ray directions toward captured emissive surfaces. Zero disables this sampling strategy without disabling emitted light.")]
            public float emissiveSamplingWeight=0.5f;
            [Range(0,32),Tooltip("Maximum emissive sampling candidates. More candidates increase per-ray probability evaluation cost; zero disables this sampling strategy.")]
            public int maxEmissiveProposals=16;
            [Range(0,262144),Tooltip("Maximum exact emitter triangles for one area-light sample paired with every direction sample. Zero disables area NEE; omitted triangles retain their direction estimator.")]
            public int maxAreaEmitterTriangles=16384;
            [Range(16,128)] public int surfaceTileResolution=32;
            [Range(6,1536)] public int residentSurfaceCards=384;
            [Range(1,96)] public int surfaceCapturesPerFrame=24;
            [Range(1,1024)] public int surfaceDrawsPerFrame=256;
            [Min(0),Tooltip("CPU milliseconds for recording surface cards per camera render. Finishes the current card before deferring the rest. Zero disables the time limit.")]
            public float surfaceCaptureRecordingCpuBudgetMilliseconds;
            [Min(1)] public int surfaceAtlasBudgetMiB=64;
            [Min(0),Tooltip("Shared CPU milliseconds for object SDF volume uploads per engine frame. Finishes an upload already started. Zero disables this time limit.")]
            public float objectSdfUploadCpuBudgetMilliseconds;
            [Range(0,1)] public float bounceFeedback=1;
            [Range(1,32)] public int maxLights=16;
            [Tooltip("Experimental: only when capacity overflows, exclude local lights proven outside the complete finite screen/world transport domain. Unknown coverage retains legacy admission.")]
            public bool spatialLightSelection;
            [ColorUsage(false,true)] public Color environmentRadiance=Color.black;
            [Tooltip("Optional static, unencoded linear RGBAHalf/RGBAFloat radiance cube. Replaces the constant environment; contents must remain immutable while in use.")]
            public Cubemap environmentCubemap;
            [Min(0)] public float indirectIntensity=1;
            [Tooltip("Biased luminance clamp. Zero disables it.")][Min(0)] public float radianceClamp=0;
            public bool temporalAccumulation=true;
            [Tooltip("Build bounded CPU receiver-source snapshots. Object history also enables this tracking.")]
            public bool receiverSourceTracking;
            [Tooltip("Experimental per-pixel source/primitive identity and rigid-object history. Requires single-sample DX12 and validated stock Lit coverage; unknown pixels retain current GI.")]
            public bool receiverObjectHistory;
            [Range(1,16384)] public int receiverSourceCapacity=1024;
            [Min(0),Tooltip("Optional CPU milliseconds for receiver discovery and its rechecks in one camera render. Zero disables the allowance. Unity source calls already in progress finish normally.")]
            public float receiverDiscoveryCpuBudgetMilliseconds;
            [Min(1),Tooltip("Logical mesh bytes fingerprinted per source preparation or capture validation; not a CPU time or peak-memory limit.")]
            public int receiverFingerprintBudgetMiB=16;
            [Range(0.02f,1)] public float temporalCurrentWeight=0.08f;
            [Range(1,64)] public int maxHistory=32;
            [Range(0.001f,0.1f)] public float relativeDepthThreshold=0.015f;
            [Range(0,1)] public float normalThreshold=0.9f;
            [Range(0,4)] public int filterIterations=3;
            public bool normalsOctEncoded;
            public bool includeSceneView;
            public bool preferHardwareTracing;
            public bool exactSoftwareTracing=true;
            [Range(1024,1000000)] public int meshTriangleBudget=250000;
            [Min(1),Tooltip("Software exact mesh attributes and BVH GPU byte estimate. Whole owners exceeding the triangle/byte quota retain their SDF representation.")]
            public int softwareGeometryBudgetMiB=128;
            [Min(1),Tooltip("Per-camera exact hardware mesh attribute buffers, including old allocations awaiting their GPU retirement fence. RTAS memory has a separate shared budget.")]
            public int hardwareGeometryBudgetMiB=128;
            [Min(1),Tooltip("Shared RTAS admission reservation plus measured allocation high-water. The prebuild estimate is not a driver VRAM upper bound.")]
            public int rtasMemoryBudgetMiB=256;
            [Min(0)] public int rtasBuildsPerFrame=4;
            [Min(0)] public int rtasTriangleWorkPerFrame=250000;
            [Min(0)] public int rtasInstanceWorkPerFrame=4096;
            [Min(1),Tooltip("Deferred large builds accumulate tokens up to this capacity; larger requests explicitly fall back.")]
            public int rtasTriangleBurstCapacity=1000000;
            [Min(1)] public int rtasInstanceBurstCapacity=16384;
            [Min(1),Tooltip("Global hardware hit-material buffers and copied source texels, including every camera and resources awaiting a GPU fence. Excludes RTAS and triangle attributes. Exceeding this limit selects software tracing.")]
            public int hardwareMaterialBudgetMiB=256;
            [Min(1),Tooltip("Shared bytes of original-texture copies admitted during actual GPU command recording each engine frame. Stable pages can finish over several frames.")]
            public int materialTextureUploadMiBPerFrame=16;
            [Min(0), Tooltip("CPU milliseconds before deferring the next texture page or page range in this camera's hit-material batch. Zero disables this limit. An upload that has started records to completion.")]
            public float materialTextureRecordingCpuBudgetMilliseconds;
            [Tooltip("Additive keeps URP ambient and baked diffuse. Choose Replace Native Diffuse GI to substitute HLGI for that term on opaque stock Lit receivers. Requires Forward/Forward+, signed RGBA float HDR and MSAA off. Zero indirect intensity removes the captured native term.")]
            public CompositionMode composition=CompositionMode.Additive;
            [Tooltip("Only standard opaque URP Lit material layers are supported.")]
            public LayerMask materialLayers=-1;
            [Tooltip("Per-camera screen textures and identity-buffer estimate; excludes driver/RTAS allocations. Scale decreases to fit.")]
            [Min(32)] public int textureBudgetMiB=128;
            [Range(1,4)] public int maxCameras=2;
            [Tooltip("Opt-in feedback from valid GPU timings. Set a positive target; unavailable timings retain static update budgets.")]
            public bool adaptiveGpuBudget;
            [Tooltip("Observe GPU cost and retain bounded native completion records without enabling budget feedback. A positive target is not required. Default off.")]
            public bool measureGpuCost;
            [Tooltip("Prefer the optional Windows x64 native DX12 timestamp plugin when installed and ready; otherwise use the Recorder fallback.")]
            public bool preferNativeGpuTiming=true;
            [Min(0),Tooltip("Target milliseconds for the three GI render passes per camera, excluding preparation uploads outside the passes. Zero disables feedback; choose a target from measurements on the target device.")]
            public float targetGpuMilliseconds;
            [Range(0.01f,1),Tooltip("Minimum fraction of configured patch/capture/brick update limits. Does not change resource capacity, ray counts or the surface draw limit.")]
            public float minimumGpuWorkFraction=0.125f;
            public DebugView debugView;

            internal string TransportSettingsJson()
            {
                // Composite controls, monitoring and update quotas do not change
                // transport inputs. Future fields stay in the comparison by default.
                var transport=(Settings)MemberwiseClone();
                transport.indirectIntensity=1f;
                transport.debugView=DebugView.Final;
                transport.adaptiveGpuBudget=false;
                transport.measureGpuCost=false;
                transport.preferNativeGpuTiming=false;
                transport.targetGpuMilliseconds=0;
                transport.minimumGpuWorkFraction=0;
                transport.receiverDiscoveryCpuBudgetMilliseconds=0;
                transport.surfaceCaptureRecordingCpuBudgetMilliseconds=0;
                transport.objectSdfUploadCpuBudgetMilliseconds=0;
                return JsonUtility.ToJson(transport);
            }
        }
        [SerializeField] private Settings settings=new Settings();
        /// <summary>Requested preference, not proof that this camera is using hardware tracing.</summary>
        public bool RequestedPreferHardwareTracing => settings.preferHardwareTracing;
        /// <summary>
        /// Call on the Unity main thread before camera preparation. The existing render path
        /// applies configuration/backend invalidation and retains normal software fallback.
        /// </summary>
        public void SetPreferHardwareTracing(bool value)
        {
            if (settings.preferHardwareTracing == value) return;
            settings.preferHardwareTracing = value;
            pass?.BackendRequestChanged();
        }
        /// <summary>Start a fresh HLGI screen history for an explicit camera cut. Call on the main thread before preparing that camera.</summary>
        public void ResetCameraHistory(Camera camera) => pass?.ResetCameraHistory(camera);
        public float RequestedIndirectIntensity => settings.indirectIntensity;
        public DebugView RequestedDebugView => settings.debugView;
        /// <summary>Set the composite intensity before camera preparation, preserving accumulated GI.</summary>
        public bool SetIndirectIntensity(float value)
        {
            if(float.IsNaN(value) || float.IsInfinity(value) || value<0f) return false;
            settings.indirectIntensity=value;
            return true;
        }
        /// <summary>Select a composite view before camera preparation, preserving accumulated GI.</summary>
        public bool SetDebugView(DebugView value)
        {
            if((uint)value>(uint)DebugView.DiffuseReflectance) return false;
            settings.debugView=value;
            return true;
        }
        public bool RequestedMeasureGpuCost => settings.measureGpuCost;
        public bool RequestedAdaptiveGpuBudget => settings.adaptiveGpuBudget;
        public float RequestedTargetGpuMilliseconds => settings.targetGpuMilliseconds;
        /// <summary>
        /// Configure the existing per-camera GI-pass timing/feedback on the Unity main thread,
        /// before camera preparation. Invalid input leaves all settings unchanged. These are
        /// feature-wide requests, not a hard deadline or the application's total GPU budget.
        /// Timing/controller state is refreshed independently; these controls alone
        /// preserve lighting history and HLOD readiness.
        /// </summary>
        public bool TryConfigureGpuBudget(bool measureCost,bool feedback,float targetMilliseconds)
        {
            if(float.IsNaN(targetMilliseconds) || float.IsInfinity(targetMilliseconds) ||
                targetMilliseconds<0 || (feedback && targetMilliseconds<=0)) return false;
            settings.measureGpuCost=measureCost;
            settings.adaptiveGpuBudget=feedback;
            settings.targetGpuMilliseconds=targetMilliseconds;
            return true;
        }
        [SerializeField] private ComputeShader traceCompute;
        [SerializeField] private Shader compositeShader;
        [SerializeField] private Shader surfaceShader;
        [SerializeField] private Shader nativeDiffuseShader;
        private Material composite;
        internal static bool IsSupportedEnvironmentCubemap(Cubemap cube)
        {
            return cube!=null && (cube.format==TextureFormat.RGBAHalf || cube.format==TextureFormat.RGBAFloat) &&
                !GraphicsFormatUtility.IsSRGBFormat(cube.graphicsFormat);
        }
        private TransportPass pass;
        // Keep both geometry budgets with the camera across state eviction and pass replacement.
        private readonly ConditionalWeakTable<Camera, CameraGeometryAllocations> cameraGeometry =
            new ConditionalWeakTable<Camera, CameraGeometryAllocations>();
        private bool warnedPlatform;
        private readonly List<HybridLumenGIStreamedRepresentation> visibleHlodBindings = new List<HybridLumenGIStreamedRepresentation>();
        private Camera hlodRasterCamera;
        public override void Create()
        {
            HybridLumenGIResourceRetirement.RegisterShutdownOwner(WithdrawForShutdown);
            if(HybridLumenGIResourceRetirement.AdmissionClosed){WithdrawForShutdown();return;}
            WithdrawForShutdown();
            traceCompute=traceCompute!=null?traceCompute:Resources.Load<ComputeShader>("HybridLumenGI/HybridLumenGI");
            compositeShader=compositeShader!=null?compositeShader:Resources.Load<Shader>("HybridLumenGI/HybridLumenGIComposite");
            surfaceShader=surfaceShader!=null?surfaceShader:Resources.Load<Shader>("HybridLumenGI/HybridLumenGISurface");
            nativeDiffuseShader=nativeDiffuseShader!=null?nativeDiffuseShader:Resources.Load<Shader>("HybridLumenGI/HybridLumenGINativeDiffuseCapture");
            composite=compositeShader!=null?CoreUtils.CreateEngineMaterial(compositeShader):null;
            pass=new TransportPass(traceCompute,composite,surfaceShader,nativeDiffuseShader,settings,()=>isActive,this);
            RenderPipelineManager.endCameraRendering += EndHlodRaster;
        }
        public override void AddRenderPasses(ScriptableRenderer renderer,ref RenderingData renderingData)
        {
            if(HybridLumenGIResourceRetirement.AdmissionClosed)return;
            var camera=renderingData.cameraData;
            if(SystemInfo.graphicsDeviceType!=GraphicsDeviceType.Direct3D12 || QualitySettings.activeColorSpace!=ColorSpace.Linear)
            {
                if(!warnedPlatform) { Debug.LogWarning("[HybridLumenGI] This research build requires DX12 and Linear color space. Other API paths are not validated and are disabled.");warnedPlatform=true; }
                return;
            }
            if (AcceptsCamera(in camera)) renderer.EnqueuePass(pass);
        }
        private bool AcceptsCamera(in CameraData camera) => pass != null && traceCompute != null && composite != null &&
            surfaceShader != null && SystemInfo.supportsComputeShaders && camera.renderType == CameraRenderType.Base &&
            !camera.camera.stereoEnabled && camera.cameraTargetDescriptor.dimension == TextureDimension.Tex2D &&
            (camera.cameraType == CameraType.Game || (settings.includeSceneView && camera.cameraType == CameraType.SceneView));

        public override void OnCameraPreCull(ScriptableRenderer renderer, in CameraData cameraData)
        {
            HideHlodRaster();
            if (HybridLumenGIResourceRetirement.AdmissionClosed || !AcceptsCamera(in cameraData)) return;
            pass.CollectHlodRaster(cameraData.camera, visibleHlodBindings);
            if (visibleHlodBindings.Count == 0) return;
            hlodRasterCamera = cameraData.camera;
            foreach (var binding in visibleHlodBindings) binding.SetHlodRasterVisible(true);
        }
        private void EndHlodRaster(ScriptableRenderContext context, Camera camera)
        {
            if (ReferenceEquals(hlodRasterCamera, camera)) HideHlodRaster();
        }
        private void HideHlodRaster()
        {
            foreach (var binding in visibleHlodBindings)
                if (binding != null) binding.SetHlodRasterVisible(false);
            visibleHlodBindings.Clear();
            hlodRasterCamera = null;
        }
        private void WithdrawForShutdown()
        {
            RenderPipelineManager.endCameraRendering -= EndHlodRaster;
            HideHlodRaster();
            var oldPass=pass;var oldComposite=composite;pass=null;composite=null;
            oldPass?.StopAdmission();
            if(oldPass==null && oldComposite==null)return;
            // Already recorded graph callbacks retain the entire pass/state. Direct texture
            // and cache destruction inside Dispose is deferred until those readers finish.
            HybridLumenGIResourceRetirement.RetireDetachedPass(()=>{oldPass?.Dispose();CoreUtils.Destroy(oldComposite);});
        }
        protected override void Dispose(bool disposing)
        {
            HybridLumenGIResourceRetirement.UnregisterShutdownOwner(WithdrawForShutdown);
            WithdrawForShutdown();
        }

        private const int CacheEntryStride = 96;
        [StructLayout(LayoutKind.Sequential)] private struct CacheData
        { public Vector4 irradiance,tag,anchor,normal,guide,nonAnalyticIrradiance; }
        private sealed class CameraGeometryAllocations
        {
            internal readonly HybridLumenGIHardwareBackend.GeometryAllocations Hardware = new HybridLumenGIHardwareBackend.GeometryAllocations();
            internal readonly HybridLumenGIHardwareBackend.GeometryAllocations Software = new HybridLumenGIHardwareBackend.GeometryAllocations();
        }
        private struct ExactMaterialObservation
        {
            internal HybridLumenGIMaterialSource.Snapshot cardlessSource;
            internal HybridLumenGIHitMaterialLayout.ShadowCoverage shadowCoverage;
            internal bool? shadowMapUploadRecorded;
        }
        private sealed class CameraState : IDisposable
        {
            internal int scenePreparedEngineFrame = -1, scenePreparedWorkFrame = -1;
            internal ScriptableRenderer scenePreparedRenderer;
            internal readonly Camera camera;
            internal readonly HybridLumenGIScene scene=new HybridLumenGIScene();
            internal readonly HybridLumenGIHardwareBackend hardware;
            internal readonly HybridLumenGIHardwareBackend softwareGeometry;
            private readonly HybridLumenGIHardwareBackend.GeometryAllocations softwareAllocations;
            internal readonly HybridLumenGIAreaEmission.Cache areaEmissionCache=new HybridLumenGIAreaEmission.Cache();
            internal long areaEmitterBytes;
            internal bool exactSoftwareGeometry;
            private HybridLumenGISoftwareTriangleBvh.Layout retainedSoftwareLayout;
            private ulong retainedSoftwareVersion,uploadedSoftwareVersion;
            private GraphicsBuffer retainedSoftwareNodes,retainedSoftwareLeaves;
            internal readonly HybridLumenGISdfAtlas sdf=new HybridLumenGISdfAtlas();
            internal readonly HybridLumenGIGlobalSdf globalSdf=new HybridLumenGIGlobalSdf();
            internal readonly HybridLumenGISurfaceCache surfaceCache=new HybridLumenGISurfaceCache();
            internal readonly HybridLumenGIChangeRegions changes=new HybridLumenGIChangeRegions();
            internal readonly HybridLumenGICacheScheduler scheduler=new HybridLumenGICacheScheduler();
            internal readonly HybridLumenGIHlodReadback readiness=new HybridLumenGIHlodReadback();
            internal readonly HybridLumenGIEmissiveSampling emissiveSampling=new HybridLumenGIEmissiveSampling();
            internal readonly HybridLumenGIHistoryLifecycle historyLifecycle=new HybridLumenGIHistoryLifecycle();
            internal readonly HybridLumenGIReceiverHistory receiverHistory=new HybridLumenGIReceiverHistory();
            internal int receiverTrackedSubmeshes,receiverUntrackedRenderers,receiverFingerprintMeshes;
            internal long receiverFingerprintBytes;
            internal bool receiverIdentityEnabled;
            internal string receiverIdentityStatus;
            internal int receiverIdentityDraws,receiverUnknownRectangles,lowPixelBytes;
            internal long receiverIdentityBufferBytes;
            internal string hardwareMaterialStatus="Hardware materials inactive";
            internal int hardwareMaterialUnknownRecords;
            internal long hardwareMaterialFrameBytes;
            internal readonly HybridLumenGIGpuTiming gpuTiming;
            internal readonly HybridLumenGINativeGpuTiming nativeGpuTiming;
            internal bool useNativeGpuTiming;
            internal readonly HybridLumenGIGpuBudgetController gpuBudget=new HybridLumenGIGpuBudgetController();
            internal HybridLumenGIGpuBudgetController.Budget effectiveBudget;
            internal bool gpuObservationValid;
            internal double gpuLastObservedMilliseconds;
            internal int gpuLastObservationFrame=-1;
            private string gpuSettings;
            private int gpuGeneration=1,gpuFullWidth,gpuFullHeight,gpuWidth,gpuHeight,lastBudgetFrame=int.MinValue;
            private bool gpuBackend,gpuIdentity;
            private ulong selectedNativeEpoch;
            internal readonly RTHandle[] history=new RTHandle[2], geometry=new RTHandle[2], material=new RTHandle[2], moments=new RTHandle[2];
            internal readonly RTHandle[] receiverIdentity=new RTHandle[2];
            internal readonly ComputeBuffer[] cache=new ComputeBuffer[2];
            internal ComputeBuffer lights;
            internal readonly HybridLumenGILights.Data[] lightData=new HybridLumenGILights.Data[32];
            internal readonly HybridLumenGILights.Data[] recordedLightData=new HybridLumenGILights.Data[32];
            internal int recordedLightCount,recordedLightEpoch;
            internal readonly List<HybridLumenGILights.Data> lightChanges=new List<HybridLumenGILights.Data>(64);
            internal readonly List<Bounds> localLightingChangeBounds=new List<Bounds>(64);
            internal HybridLumenGILights.SelectionDiagnostics lightSelection;
            internal HybridLumenGILightRelevance.Domain lightDomain;
            internal string lightDomainReason;
            internal int width,height,capacity,readIndex,cacheRead,frame,epoch=1,cacheCursor,lastUsed,lastLightHash;
            internal string lastSettingsJson,lastTransportSettingsJson;
            internal int patchGrid,cacheEntryCount,previousLightCount;
            internal int fullWidth,fullHeight,fullPixelBytes;
            internal bool valid,lastHardware,lightingChanged;
            private bool worldPreparationPending;
            internal Dictionary<ulong, ExactMaterialObservation> exactMaterialObservations;
            internal int[] recordedTraceOwners;
            internal string recordedTransportBackend;
            internal int transportRecordedEngineFrame = -1, transportRecordedWorkFrame = -1;
            internal ulong recordedBackendRequest;
            internal bool recordedHardwarePreference;
            private (Texture2D texture,uint version)[] shadowmaskSlots;
            internal Matrix4x4 previousVP=Matrix4x4.identity,previousInvVP=Matrix4x4.identity;
            internal Vector2 previousJitter;
            internal Vector3 previousPosition;
            internal Quaternion previousRotation;
            private RenderTexture historyTarget;
            private bool hasHistoryTarget;
            internal bool RefreshShadowmaskHistory(LightmapData[] maps)
            {
                bool changed=(maps==null)!=(shadowmaskSlots==null);
                if(maps==null) { shadowmaskSlots=null;return changed; }
                // LightmapSettings may return a fresh array for unchanged inputs.
                // A screen hit can use a lightmapped renderer with no GI proxy.
                if(shadowmaskSlots==null || shadowmaskSlots.Length!=maps.Length)
                {
                    if(shadowmaskSlots!=null)
                        for(int i=maps.Length;i<shadowmaskSlots.Length;i++)
                            changed|=!ReferenceEquals(shadowmaskSlots[i].texture,null);
                    Array.Resize(ref shadowmaskSlots,maps.Length);
                }
                for(int i=0;i<maps.Length;i++)
                {
                    Texture2D texture=maps[i]?.lightmapColor!=null?maps[i].shadowMask:null;
                    if(!texture) texture=null; // Normalize Unity's destroyed-object reference.
                    uint version=texture!=null?texture.updateCount:0;
                    changed|=!ReferenceEquals(shadowmaskSlots[i].texture,texture) || shadowmaskSlots[i].version!=version;
                    shadowmaskSlots[i]=(texture,version);
                }
                return changed;
            }
            internal readonly MaterialPropertyBlock properties=new MaterialPropertyBlock();
            internal CameraState(Camera camera, CameraGeometryAllocations allocations)
            {
                hardware = new HybridLumenGIHardwareBackend(allocations.Hardware);
                softwareAllocations = allocations.Software;
                softwareGeometry = new HybridLumenGIHardwareBackend(softwareAllocations, softwareOnly: true);
                this.camera=camera;lights=new ComputeBuffer(32,HybridLumenGILights.Stride);gpuTiming=new HybridLumenGIGpuTiming(camera.GetInstanceID());
                nativeGpuTiming=new HybridLumenGINativeGpuTiming(camera.GetInstanceID());
            }
            internal void InvalidateGpuFeedback()
            {
                gpuTiming.Invalidate();nativeGpuTiming.Invalidate();gpuBudget.Reset();gpuObservationValid=false;
                gpuGeneration=gpuGeneration==int.MaxValue?1:gpuGeneration+1;
            }
            internal void InvalidateScreenHistory()
            { valid=false;historyLifecycle.Invalidate();receiverHistory.Invalidate(); }
            internal void InvalidateWorldHistory()
            {
                epoch=epoch%8000000+1;
                scene.InvalidateReadiness();readiness.Invalidate();
                hardware.CancelDeferredHlodBuild();
            }
            internal void InvalidateFailedRender()
            { uploadedSoftwareVersion=0;globalSdf.InvalidateAll();surfaceCache.InvalidateRecordedCapture();InvalidateScreenHistory();InvalidateGpuFeedback(); }
            internal void BeginWorldPreparation()
            {
                // A discarded graph may already have consumed CPU-side source changes.
                if (worldPreparationPending) DiscardWorldPreparation();
                worldPreparationPending = true;
            }
            internal void DiscardWorldPreparation()
            {
                worldPreparationPending = false;
                InvalidateFailedRender();
                InvalidateWorldHistory();
            }
            internal void CompleteWorldRecording(int write)
            {
                cacheRead = write;
                worldPreparationPending = false;
            }
            internal void PrepareHistoryTarget(RenderTexture target)
            {
                // Numeric native IDs can be reused after destruction; reference identity
                // also distinguishes a new target with identical dimensions.
                if(hasHistoryTarget && ReferenceEquals(historyTarget,target)) return;
                historyTarget=target;hasHistoryTarget=true;InvalidateScreenHistory();
            }
            internal void CompleteScreenHistory(HybridLumenGIHistoryLifecycle.FrameToken token,
                Matrix4x4 vp,Matrix4x4 invVP,Vector2 jitter,Vector3 position,Quaternion rotation)
            {
                if(!historyLifecycle.Complete(token)) return;
                receiverHistory.Complete(token);
                previousVP=vp;previousInvVP=invVP;previousJitter=jitter;
                previousPosition=position;previousRotation=rotation;valid=true;
            }
            internal void PrepareGpuBudget(Settings settings,string serializedSettings,int engineFrame)
            {
                // Compare the configuration itself, not only its hash. Adaptive work quotas
                // never write Settings, resize resources, or advance the lighting epoch.
                if(gpuSettings!=serializedSettings || gpuFullWidth!=fullWidth || gpuFullHeight!=fullHeight ||
                    gpuWidth!=width || gpuHeight!=height || gpuBackend!=lastHardware ||
                    gpuIdentity!=receiverIdentityEnabled || engineFrame<=lastBudgetFrame)
                {
                    InvalidateGpuFeedback();gpuSettings=serializedSettings;gpuFullWidth=fullWidth;gpuFullHeight=fullHeight;
                    gpuWidth=width;gpuHeight=height;gpuBackend=lastHardware;gpuIdentity=receiverIdentityEnabled;
                }
                lastBudgetFrame=engineFrame;
                bool feedbackEnabled=settings.adaptiveGpuBudget && settings.targetGpuMilliseconds>0 &&
                    !float.IsNaN(settings.targetGpuMilliseconds) && !float.IsInfinity(settings.targetGpuMilliseconds);
                bool enabled=settings.measureGpuCost || feedbackEnabled;
                nativeGpuTiming.EnableCompletedRecords(settings.measureGpuCost);
                bool nativeValid=nativeGpuTiming.BeginFrame(engineFrame,gpuGeneration,enabled && settings.preferNativeGpuTiming,out double nativeMs);
                bool selectNative=enabled && settings.preferNativeGpuTiming && nativeGpuTiming.Available;
                if(selectNative!=useNativeGpuTiming || (selectNative && selectedNativeEpoch!=nativeGpuTiming.DeviceEpoch))
                {
                    // Provider changes cannot blend incompatible observation histories.
                    // Keep the native ticket just reserved for this frame; only reset feedback.
                    gpuBudget.Reset();gpuTiming.Invalidate();gpuLastObservedMilliseconds=0;gpuLastObservationFrame=-1;
                    useNativeGpuTiming=selectNative;
                    selectedNativeEpoch=selectNative?nativeGpuTiming.DeviceEpoch:0;
                }
                bool recorderValid=gpuTiming.BeginFrame(engineFrame,gpuGeneration,enabled && !selectNative,out double recorderMs,
                    includeReceiverIdentity:receiverIdentityEnabled);
                double milliseconds=selectNative?nativeMs:recorderMs;
                gpuObservationValid=selectNative?nativeValid:recorderValid;
                if(gpuObservationValid) { gpuLastObservedMilliseconds=milliseconds;gpuLastObservationFrame=engineFrame; }
                var config=new HybridLumenGIGpuBudgetController.Configuration(feedbackEnabled,settings.targetGpuMilliseconds,
                    settings.minimumGpuWorkFraction,Mathf.Clamp(settings.cachePatchesPerFrame,1,4096),
                    Mathf.Clamp(settings.surfaceCapturesPerFrame,1,96),settings.globalSdfEnabled?Mathf.Clamp(settings.globalSdfBricksPerFrame,1,128):0);
                effectiveBudget=gpuBudget.Step(engineFrame,(ulong)gpuGeneration,gpuObservationValid,milliseconds,config,
                    measurementSourceFrame:selectNative?nativeGpuTiming.LastMeasuredSourceFrame:-1);
            }
            internal void Ensure(int w,int h,bool identityEnabled=false)
            {
                if(width!=w || height!=h || receiverIdentityEnabled!=identityEnabled)
                {
                    ReleaseTextures(); width=w; height=h; InvalidateScreenHistory();
                    receiverIdentityEnabled=identityEnabled;
                    for(int i=0;i<2;i++)
                    {
                        history[i]=Allocate(w,h,GraphicsFormat.R16G16B16A16_SFloat,"HLGI history "+i);
                        geometry[i]=Allocate(w,h,GraphicsFormat.R32G32B32A32_SFloat,"HLGI geometry "+i);
                        material[i]=Allocate(w,h,GraphicsFormat.R8G8B8A8_UNorm,"HLGI material "+i);
                        // A finite half-float radiance can have a second moment above 65504.
                        moments[i]=Allocate(w,h,GraphicsFormat.R32G32B32A32_SFloat,"HLGI moments "+i);
                        if(identityEnabled) receiverIdentity[i]=Allocate(w,h,GraphicsFormat.R32G32B32A32_UInt,"HLGI receiver identity "+i);
                    }
                }
            }
            internal void EnsureCache(int slots,int grid,int cards)
            {
                int entries=Mathf.Max(1,cards)*grid*grid;
                if(capacity!=slots || patchGrid!=grid || cacheEntryCount!=entries)
                {
                    capacity=slots;patchGrid=grid;cacheEntryCount=entries;epoch++;InvalidateScreenHistory();cacheCursor=0;
                    readiness.Invalidate();scene.InvalidateReadiness();
                    for(int i=0;i<2;i++) { cache[i]?.Release();cache[i]=new ComputeBuffer(cacheEntryCount,CacheEntryStride);cache[i].SetData(new CacheData[cacheEntryCount]); }
                }
            }
            private static RTHandle Allocate(int w,int h,GraphicsFormat format,string name)
            {
                return RTHandles.Alloc(w,h,colorFormat:format,enableRandomWrite:true,filterMode:FilterMode.Point,
                    wrapMode:TextureWrapMode.Clamp,name:name);
            }
            internal bool PrepareSoftwareGeometry(RenderGraph graph,int triangleLimit,long byteLimit,
                out HybridLumenGISoftwareTriangleBvh.Layout layout,out BufferHandle nodes,out BufferHandle leaves,out string reason)
            {
                layout=null;nodes=leaves=default;reason=null;
                // The prepared snapshot supplies one leaf per triangle. Admit its buffers before building the CPU tree.
                int triangleCount=softwareGeometry.TriangleCount;
                int nodeCount=Math.Max(1,HybridLumenGISoftwareTriangleBvh.NodeCountForTriangles(triangleCount));
                int leafCount=Math.Max(1,triangleCount);
                bool grow=retainedSoftwareNodes==null || retainedSoftwareNodes.count<nodeCount || retainedSoftwareLeaves.count<leafCount;
                long extra = grow ? HybridLumenGISoftwareTriangleBvh.BufferBytes(nodeCount,leafCount) : 0;
                if(softwareAllocations.TotalBytes + extra > byteLimit)
                {
                    // Release obsolete capacity through a real end-context ticket. A later frame
                    // can admit the replacement; never silently exceed the quota to resize.
                    if(grow && retainedSoftwareNodes!=null)RetireSoftwareBuffers();
                    reason="Software geometry buffer budget awaits retirement";return false;
                }
                if(retainedSoftwareLayout==null || retainedSoftwareVersion!=softwareGeometry.GeometryVersion)
                {
                    if(!HybridLumenGISoftwareTriangleBvh.TryBuild(softwareGeometry,softwareGeometry.InstanceCount,
                        Math.Min(HybridLumenGISoftwareTriangleBvh.MaxTriangles,Math.Max(0,triangleLimit)),out var next,out reason))return false;
                    retainedSoftwareLayout=next;retainedSoftwareVersion=softwareGeometry.GeometryVersion;
                }
                if(grow)
                {
                    GraphicsBuffer newNodes=null,newLeaves=null;
                    try
                    {
                        newNodes=AllocateSoftwareBuffer(nodeCount,HybridLumenGISoftwareTriangleBvh.NodeStride);
                        newLeaves=AllocateSoftwareBuffer(leafCount,HybridLumenGISoftwareTriangleBvh.LeafStride);
                    }
                    catch(Exception ex)
                    {
                        ReleaseSoftwareBuffer(newNodes);
                        ReleaseSoftwareBuffer(newLeaves);
                        reason="Software geometry allocation failed: "+ex.GetType().Name;return false;
                    }
                    RetireSoftwareBuffers();retainedSoftwareNodes=newNodes;retainedSoftwareLeaves=newLeaves;uploadedSoftwareVersion=0;
                }
                layout=retainedSoftwareLayout;nodes=graph.ImportBuffer(retainedSoftwareNodes);leaves=graph.ImportBuffer(retainedSoftwareLeaves);
                return true;
            }
            internal long SoftwareResidentBytes => softwareAllocations.TotalBytes;
            internal bool PrepareSoftwareAttributes(int triangleLimit,long byteLimit)
            {
                if(softwareGeometry.Prepare(scene,scene.Revision,triangleLimit,surfaceCache,byteLimit))return true;
                // The old BVH cannot trace this scene without its attributes. If we keep it,
                // its capacity can prevent even a smaller replacement from ever being admitted.
                RetireSoftwareBuffers();
                retainedSoftwareLayout=null;
                return false;
            }
            internal void RecordSoftwareGeometry(CommandBuffer cmd,ulong version,HybridLumenGISoftwareTriangleBvh.Layout layout,
                BufferHandle nodes,BufferHandle leaves)
            {
                if(uploadedSoftwareVersion==version)return;
                cmd.SetBufferData((GraphicsBuffer)nodes,layout.CopyNodes());cmd.SetBufferData((GraphicsBuffer)leaves,layout.CopyLeaves());
                uploadedSoftwareVersion=version; // Ordered graphics-queue write, not a completion/readiness claim.
            }
            internal void DeactivateSoftwareGeometry()
            {
                if (retainedSoftwareLayout == null && retainedSoftwareNodes == null && softwareGeometry.MeshCount == 0) return;
                softwareGeometry.Deactivate();
                RetireSoftwareBuffers();
                retainedSoftwareLayout = null;
            }
            private void RetireSoftwareBuffers()
            {
                var nodes=retainedSoftwareNodes;var leaves=retainedSoftwareLeaves;if(nodes==null)return;
                retainedSoftwareNodes=retainedSoftwareLeaves=null;uploadedSoftwareVersion=0;
                HybridLumenGIResourceRetirement.Retire(() =>
                {
                    ReleaseSoftwareBuffer(nodes);
                    ReleaseSoftwareBuffer(leaves);
                });
            }
            private GraphicsBuffer AllocateSoftwareBuffer(int count, int stride)
            {
                var buffer = new GraphicsBuffer(GraphicsBuffer.Target.Structured, count, stride);
                softwareAllocations.BvhBytes += (long)count * stride;
                return buffer;
            }
            private void ReleaseSoftwareBuffer(GraphicsBuffer buffer)
            {
                if (buffer == null) return;
                long bytes = (long)buffer.count * buffer.stride;
                buffer.Release();
                softwareAllocations.BvhBytes -= bytes;
            }
            private void ReleaseTextures()
            {
                for(int i=0;i<2;i++)
                {
                    history[i]?.Release(); geometry[i]?.Release(); material[i]?.Release(); moments[i]?.Release();
                    receiverIdentity[i]?.Release();receiverIdentity[i]=null;
                }
            }
            public void Dispose()
            {
                areaEmissionCache.Clear();
                RetireSoftwareBuffers();retainedSoftwareLayout=null;
                InvalidateScreenHistory();
                ReleaseTextures();foreach(var b in cache) b?.Release();lights?.Release();scene.Dispose();hardware.Dispose();softwareGeometry.Dispose();sdf.Dispose();
                readiness.Dispose();emissiveSampling.Dispose();surfaceCache.Dispose();changes.Dispose();scheduler.Dispose();globalSdf.Dispose();gpuTiming.Dispose();nativeGpuTiming.Dispose();
            }
        }
        private sealed class TransportPass : ScriptableRenderPass,IDisposable
        {
            private readonly ComputeShader software;
            private readonly ComputeShader exactSoftware;
            private readonly Material composite;
            private readonly Shader surface;
            private readonly Shader nativeDiffuse;
            private readonly HybridLumenGILitQualification litQualification=new HybridLumenGILitQualification();
            private readonly HybridLumenGIReceiverDiscovery receiverDiscovery=new HybridLumenGIReceiverDiscovery();
            private readonly HybridLumenGIReceiverRegistry receiverRegistry=new HybridLumenGIReceiverRegistry();
            private readonly HybridLumenGIReceiverIdentityPass receiverIdentityPass=new HybridLumenGIReceiverIdentityPass();
            private readonly Settings s;
            private readonly Func<bool> featureActive;
            private readonly HybridLumenGIRendererFeature validationOwner;
            private int EffectiveEmissiveBudget => s.emissiveSamplingWeight>0 ? Mathf.Clamp(s.maxEmissiveProposals,0,HybridLumenGIEmissiveSampling.ProposalCapacity) : 0;
            private readonly Dictionary<int,CameraState> cameras=new Dictionary<int,CameraState>();
            private readonly List<int> retire=new List<int>();
            // Graphs abandoned before their callback retain pristine batches until feature
            // teardown. Never guess completion from frame age; the global budget bounds them.
            private readonly HashSet<HybridLumenGIHitMaterialPass> materialPasses=new HashSet<HybridLumenGIHitMaterialPass>();
            private readonly List<ShaderTagId> tags=new List<ShaderTagId>{new ShaderTagId("UniversalForward"),new ShaderTagId("UniversalForwardOnly"),new ShaderTagId("UniversalGBuffer")};
            private readonly HybridLumenGILights worldLights=new HybridLumenGILights();
            private bool warnedBudget,warnedComposition,admissionStopped;
            private ulong backendRequest;
            internal void BackendRequestChanged() { unchecked { backendRequest++; } }
            private Cubemap rejectedEnvironment;
            internal void StopAdmission()
            {
                admissionStopped=true;
                HybridLumenGIResourceRetirement.CollectIdleRetirements-=RetireIdleCameraStates;
            }
            internal TransportPass(ComputeShader shader,Material composite,Shader surface,Shader nativeDiffuse,Settings settings,Func<bool> featureActive,HybridLumenGIRendererFeature validationOwner)
            {
                software=shader; this.composite=composite; this.surface=surface;this.nativeDiffuse=nativeDiffuse;s=settings;
                exactSoftware=Resources.Load<ComputeShader>("HybridLumenGI/HybridLumenGIExactSoftware");
                this.featureActive=featureActive;
                this.validationOwner=validationOwner;
                // After scheduled depth/motion copies, before URP's AfterOpaque SSAO multiply at 450.
                renderPassEvent=(RenderPassEvent)((int)RenderPassEvent.AfterRenderingSkybox+1);
                ConfigureInput(ScriptableRenderPassInput.Depth|ScriptableRenderPassInput.Normal|ScriptableRenderPassInput.Motion);
                requiresIntermediateTexture=true;
                HybridLumenGIResourceRetirement.Register(RequiresRepresentation);
                HybridLumenGIResourceRetirement.CollectIdleRetirements+=RetireIdleCameraStates;
            }
            private bool RequiresRepresentation(HybridLumenGIProxy proxy)
            {
                if(admissionStopped || featureActive==null || !featureActive())return false;
                foreach(var state in cameras.Values)
                {
                    if(state.camera==null || !state.camera.isActiveAndEnabled)continue;
                    for(int slot=0;slot<state.scene.Capacity;slot++)
                        if(ReferenceEquals(state.scene.GetProxy(slot),proxy) &&
                            (state.scene.IsPublished(slot) || state.scene.IsWarming(slot)))
                        {
                            if (UsesPreparedRenderer(state)) return true;
                            break;
                        }
                }
                return false;
            }
            private static bool UsesPreparedRenderer(CameraState state)
            {
                var pipeline = UniversalRenderPipeline.asset;
                return pipeline != null && state.scenePreparedRenderer != null &&
                    ReferenceEquals(SelectedBaseRenderer(pipeline, state.camera), state.scenePreparedRenderer);
            }
            private static ScriptableRenderer SelectedBaseRenderer(UniversalRenderPipelineAsset pipeline, Camera camera)
            {
                ScriptableRenderer renderer = null;
                // Match URP's default Renderer and forced Base rules for Scene View.
                if (camera.cameraType != CameraType.SceneView &&
                    camera.TryGetComponent<UniversalAdditionalCameraData>(out var cameraData))
                {
                    if (cameraData.renderType != CameraRenderType.Base) return null;
                    renderer = cameraData.scriptableRenderer;
                }
                return renderer ?? pipeline.scriptableRenderer;
            }
            private bool IsReassignedCamera(CameraState state)
            {
                var pipeline = UniversalRenderPipeline.asset;
                var prepared = state.scenePreparedRenderer;
                if (admissionStopped || pipeline == null || prepared == null) return false;
                var selected = SelectedBaseRenderer(pipeline, state.camera);
                if (admissionStopped || selected == null || ReferenceEquals(selected, prepared)) return false;

                // Both renderers must still belong to this pipeline. Asset replacement
                // and renderer recreation have their own pass-disposal lifecycle.
                var renderers = pipeline.renderers;
                var data = pipeline.rendererDataList;
                bool hasPrepared = false;
                int selectedIndex = -1;
                for (int i = 0; i < Math.Min(renderers.Length, data.Length); i++)
                {
                    if (ReferenceEquals(renderers[i], prepared)) hasPrepared = true;
                    if (ReferenceEquals(renderers[i], selected)) selectedIndex = i;
                }
                if (!hasPrepared || selectedIndex < 0 || data[selectedIndex] == null) return false;
                var features = data[selectedIndex].rendererFeatures;
                return features != null && !features.Contains(validationOwner);
            }
            private sealed class SurfacePassData
            {
                internal RendererListHandle[] renderers;internal int[] layers;internal CameraState state;internal HybridLumenGIGpuFrameTiming frameTiming;
                internal TransportPass owner;
                internal HybridLumenGIHistoryLifecycle.FrameToken historyToken;
                internal HybridLumenGIReceiverRegistry.Snapshot receiverSources;
                internal HybridLumenGIReceiverDiscovery.ScanBudget discoveryBudget;
                internal long fingerprintBudget;
                internal LayerMask materialLayers;
                internal ReceiverCaptureReceipt receiverReceipt;
                internal bool identityExpected,staticShadowmask;
            }
            private sealed class ReceiverCaptureReceipt { internal bool sourcesCurrent,identityRecorded; }
            private sealed class NativeResolveData
            { internal HybridLumenGIGpuFrameTiming frameTiming; }
            private sealed class Work
            {
                internal CameraState state;
                internal TransportPass owner;
                internal ComputeShader compute;
                internal HybridLumenGIHitMaterialPass hitMaterials;
                internal HybridLumenGIHardwareBackend geometry;
                internal bool ExactSoftware => geometry!=null && !hardware;
                internal bool sourceUncertain;
                internal HybridLumenGIValidationCapture.Ticket validationTicket;
                internal ulong geometryVersion;
                internal HybridLumenGISoftwareTriangleBvh.Layout softwareLayout;
                internal BufferHandle softwareNodes,softwareLeaves;
                internal BufferHandle areaEmitters;
                internal HybridLumenGIAreaEmission.Layout areaLayout;
                internal Dictionary<ulong, ExactMaterialObservation> exactMaterialObservations;
                internal int[] traceOwners;
                internal TextureHandle depth,captureDepth,normals,motion,diffuse,emission,receiverPolicy,raw,tempA;
                // Temporal consumes raw before the first filter dispatch. It can then serve as destination B.
                internal TextureHandle tempB => raw;
                internal TextureHandle historyRead,historyWrite,geometryRead,geometryWrite,materialRead,materialWrite,momentsRead,momentsWrite;
                internal Matrix4x4 vp,invVP,view,previousVP,previousInvVP;
                internal Vector4 materialView;
                internal Vector2 jitterDelta;
                internal int read,cacheRead,cacheStart,frame,epoch,lightCount,filterIterations;
                internal int nonAnalyticOnlyChannels;
                internal bool valid,hasMotion,hardware,staticShadowmask;
                internal ulong backendRequest;
                internal bool hardwarePreference,waitForHlodBuildTurn;
                internal Rect viewport;
                internal HybridLumenGIGpuFrameTiming frameTiming;
                internal HybridLumenGIHistoryLifecycle.FrameToken historyToken;
                internal int cachePatchBudget;
                internal TextureHandle identityRead,identityWrite;
                internal HybridLumenGIReceiverIdentityPass.Result identity;
                internal bool useIdentity;
                internal ReceiverCaptureReceipt receiverReceipt;
            }
            private sealed class CompositeData
            {
                internal Material material;
                internal CameraState state;
                internal TextureHandle gi,geometry,diffuse,emission,depth,captureDepth,normals,moments,nativeDiffuseFog;
                internal Matrix4x4 invVP;
                internal Matrix4x4 completedVP;
                internal Vector2 completedJitter;
                internal Vector3 completedPosition;
                internal Quaternion completedRotation;
                internal float intensity,depthThreshold;
                internal int debug,normalsOct,composition;
                internal HybridLumenGIGpuFrameTiming frameTiming;
                internal HybridLumenGIHistoryLifecycle.FrameToken historyToken;
            }
            public override void RecordRenderGraph(RenderGraph graph,ContextContainer frameData)
            {
                if(admissionStopped || HybridLumenGIResourceRetirement.AdmissionClosed)return;
                HybridLumenGIHitMaterialPass.PollRetired();
                var resources=frameData.Get<UniversalResourceData>();
                var cameraData=frameData.Get<UniversalCameraData>();
                var rendering=frameData.Get<UniversalRenderingData>();
                var lightData=frameData.Get<UniversalLightData>();
                if(resources.isActiveTargetBackBuffer || !resources.cameraDepthTexture.IsValid() || !resources.cameraNormalsTexture.IsValid()) return;
                bool replace=s.composition==CompositionMode.ReplaceNativeDiffuseGI;
                // One initial discovery feeds both native-Lit qualification and source
                // identity tracking. Each consumer retains its separate eligibility rules.
                bool trackSources=s.receiverSourceTracking || s.receiverObjectHistory;
                bool discoverReceivers=replace || trackSources;
                var discoveryBudget=discoverReceivers?HybridLumenGIReceiverDiscovery.ScanBudget.FromMilliseconds(s.receiverDiscoveryCpuBudgetMilliseconds):null;
                var discovered=discoverReceivers?receiverDiscovery.Scan(cameraData.camera,s.materialLayers,discoveryBudget):null;
                if(replace)
                {
                    bool deferred=false;
                    if(resources.gBuffer!=null) foreach(var attachment in resources.gBuffer) deferred|=attachment.IsValid();
                    GraphicsFormat target=cameraData.cameraTargetDescriptor.graphicsFormat;
                    bool signedHDR=target==GraphicsFormat.R16G16B16A16_SFloat || target==GraphicsFormat.R32G32B32A32_SFloat;
                    if(nativeDiffuse==null || !(cameraData.renderer is UniversalRenderer) || deferred || !signedHDR || cameraData.cameraTargetDescriptor.msaaSamples>1)
                    {
                        if(!warnedComposition)
                        {
                            Debug.LogWarning($"[HybridLumenGI] Native diffuse replacement skipped for {cameraData.camera.name} " +
                                $"(target {target}, MSAA {cameraData.cameraTargetDescriptor.msaaSamples}x). " +
                                "Use Universal Renderer Forward/Forward+, MSAA off and the native capture shader. " +
                                "For the camera buffer, enable HDR and set the URP Asset's HDR Precision to 64 Bits. " +
                                "For a target texture, use RGBA16F or RGBA32F.");
                            warnedComposition=true;
                        }
                        return;
                    }
                    if(!litQualification.Validate(discovered,out string reason))
                    {
                        if(!warnedComposition) { Debug.LogWarning("[HybridLumenGI] Native diffuse replacement skipped: "+reason);warnedComposition=true; }
                        return;
                    }
                }
                var maps=HybridLumenGIShadowmask.ActiveMaps();
                bool staticShadowmask=maps!=null;
                var policyFormat=staticShadowmask?GraphicsFormat.R32G32B32A32_UInt:GraphicsFormat.R32G32_UInt;
                if(!SystemInfo.IsFormatSupported(GraphicsFormat.R16G16B16A16_SFloat,GraphicsFormatUsage.LoadStore) ||
                    !SystemInfo.IsFormatSupported(GraphicsFormat.R32G32B32A32_SFloat,GraphicsFormatUsage.LoadStore) ||
                    !SystemInfo.IsFormatSupported(GraphicsFormat.R8G8B8A8_UNorm,GraphicsFormatUsage.LoadStore) ||
                    !SystemInfo.IsFormatSupported(policyFormat,GraphicsFormatUsage.Render) ||
                    !SystemInfo.IsFormatSupported(policyFormat,GraphicsFormatUsage.LoadStore) ||
                    // The optional world mask is the fifth surface-card attachment.
                    SystemInfo.supportedRenderTargetCount<(staticShadowmask?5:replace?4:3)) return;
                var camera=cameraData.camera;
                var state=GetCameraState(camera);
                state.surfaceCache.SetShadowmaskSources(maps);
                state.PrepareHistoryTarget(camera.targetTexture);
                state.lastUsed=Time.frameCount;
                int fullW=cameraData.cameraTargetDescriptor.width,fullH=cameraData.cameraTargetDescriptor.height;
                bool identityEnabled=s.receiverObjectHistory && cameraData.cameraTargetDescriptor.msaaSamples==1 &&
                    camera.rect.Equals(new Rect(0,0,1,1)) &&
                    fullW>0 && fullH>0 && fullW<=16384 && fullH<=16384 &&
                    SystemInfo.IsFormatSupported(GraphicsFormat.R32G32B32A32_UInt,GraphicsFormatUsage.LoadStore) &&
                    // Identity is UAV-written and read with Texture2D<uint4>.Load.
                    receiverIdentityPass.IsAvailable;
                state.receiverIdentityStatus=!s.receiverObjectHistory?"Disabled":identityEnabled?"Capture scheduled; runtime receipt pending":
                    "Unavailable camera/format/platform: "+receiverIdentityPass.Status;
                state.receiverIdentityDraws=state.receiverUnknownRectangles=0;
                // Optional identity must not consume the baseline's ability to render current GI.
                // The helper first reserves all identity resources, then retries without them.
                int filterIterations=Mathf.Clamp(s.filterIterations,0,4);
                var screenBudget=HybridLumenGIScreenBudget.Plan(fullW,fullH,s.resolutionScale,
                    (long)Math.Max(32,s.textureBudgetMiB)*1024*1024,replace,identityEnabled,s.receiverSourceCapacity,filterIterations,staticShadowmask);
                identityEnabled=screenBudget.IdentityEnabled && screenBudget.Fits;
                if(screenBudget.IdentityBudgetFallback)
                    state.receiverIdentityStatus="Identity budget fallback: object history disabled; baseline current GI retained when affordable.";
                state.fullWidth=fullW;state.fullHeight=fullH;state.fullPixelBytes=screenBudget.FullPixelBytes;
                state.lowPixelBytes=screenBudget.LowPixelBytes;
                state.receiverIdentityBufferBytes=screenBudget.IdentityBufferBytes;
                if(!screenBudget.Fits)
                {
                    if(!warnedBudget) { Debug.LogWarning("[HybridLumenGI] Texture budget cannot fit the capture buffers; this camera is skipped."); warnedBudget=true; }
                    return;
                }
                int w=screenBudget.Width,h=screenBudget.Height;
                int slots=Mathf.Clamp(s.residentProxies,32,256);
                state.BeginWorldPreparation();
                state.Ensure(w,h,identityEnabled);
                string serializedSettings=JsonUtility.ToJson(s);
                bool shadowmaskChanged=state.RefreshShadowmaskHistory(maps);
                if(serializedSettings!=state.lastSettingsJson || shadowmaskChanged)
                {
                    string transportSettings=s.TransportSettingsJson();
                    if(transportSettings!=state.lastTransportSettingsJson || shadowmaskChanged)
                    {
                        state.epoch=state.epoch%8000000+1;state.InvalidateScreenHistory();
                        state.scene.InvalidateReadiness();state.readiness.Invalidate();
                    }
                    state.lastSettingsJson=serializedSettings;state.lastTransportSettingsJson=transportSettings;
                }
                state.PrepareGpuBudget(s,serializedSettings,Time.frameCount);
                long fingerprintBudget=(long)Math.Max(1,Math.Min(1024,s.receiverFingerprintBudgetMiB))*1024*1024;
                // Detect readable in-place edits before scene/SDF readiness can publish
                // them. Unknown/over-budget receivers retain current GI without a receipt.
                var receiverSources=trackSources?
                    receiverRegistry.Prepare(discovered,s.receiverSourceCapacity,fingerprintBudget):null;
                state.receiverTrackedSubmeshes=receiverSources==null?0:receiverSources.Records.Count;
                state.receiverUntrackedRenderers=receiverSources==null?0:receiverSources.UntrackedRenderers;
                state.receiverFingerprintMeshes=receiverSources==null?0:receiverSources.FingerprintedMeshes;
                state.receiverFingerprintBytes=receiverSources==null?0:receiverSources.FingerprintBytes;
                // Consume mesh changes from camera callbacks and receiver source checks
                // before the readiness gate or world preparation can read an old snapshot.
                HybridLumenGIDeformedMesh.RefreshRenderSources();
                RevokeStaleHlodReadiness(state);
                HybridLumenGIRtasBudget.BeginFrame(Time.frameCount,new HybridLumenGIRtasBudget.Settings
                {
                    MemoryBudgetBytes=Math.Max(1L,s.rtasMemoryBudgetMiB)*1024*1024,MaxBuildsPerFrame=Math.Max(0,s.rtasBuildsPerFrame),
                    TriangleWorkPerFrame=Math.Max(0,s.rtasTriangleWorkPerFrame),InstanceWorkPerFrame=Math.Max(0,s.rtasInstanceWorkPerFrame),
                    TriangleBurstCapacity=Math.Max(1,s.rtasTriangleBurstCapacity),InstanceBurstCapacity=Math.Max(1,s.rtasInstanceBurstCapacity),
                    BaseEstimateBytes=65536,BytesPerTriangle=192,BytesPerInstance=1024
                });
                int hardwareTriangleLimit = Mathf.Clamp(s.meshTriangleBudget, 1024, 1000000);
                bool canDeferHlodBuild = state.lastHardware && s.preferHardwareTracing && state.hardware.CanDispatch;
                bool buildTurnBlocked = canDeferHlodBuild && state.hardware.IsBuildTurnBlocked;
                bool readyExactReplacement = false;
                Predicate<int> preparedExact = null;
                Func<int, bool, bool> exactHlodTarget = null;
                Func<int, bool, bool> deferExactHlodTarget = null;
                if (canDeferHlodBuild && (buildTurnBlocked || state.hardware.HasDeferredHlodBuild))
                {
                    preparedExact = state.hardware.HasPreparedTriangles;
                    exactHlodTarget = (slot, removesExact) => state.hardware.IsHlodTargetEligible(state.scene,
                        state.surfaceCache, slot, hardwareTriangleLimit, removesExact);
                    deferExactHlodTarget = (slot, removesExact) =>
                    {
                        if (!exactHlodTarget(slot, removesExact)) return false;
                        readyExactReplacement = true;
                        return buildTurnBlocked;
                    };
                }
                state.scenePreparedEngineFrame = state.scenePreparedWorkFrame = -1;
                state.scene.Prepare(camera.transform.position,slots,s.nearDistance,Mathf.Max(s.nearDistance,s.farDistance),
                    s.chunkSize,s.proxyUploadsPerFrame,maps,preparedExact,deferExactHlodTarget);
                if (!readyExactReplacement) state.hardware.CancelDeferredHlodBuild();
                state.scenePreparedRenderer = cameraData.renderer;
                state.scenePreparedEngineFrame = Time.frameCount; state.scenePreparedWorkFrame = state.frame;
                state.sdf.PrepareForFrame(state.scene, Time.frameCount, s.objectSdfUploadCpuBudgetMilliseconds);
                if (s.globalSdfEnabled)
                    state.globalSdf.Prepare(state.scene,state.sdf,camera.transform.position,new HybridLumenGIGlobalSdf.Configuration
                    {
                        LevelCount=s.globalSdfLevels,BricksPerAxis=s.globalSdfBricksPerAxis,
                        BaseVoxelSize=s.globalSdfBaseVoxelSize,MaxDistanceInBricks=2,UpdateBrickBudget=state.effectiveBudget.GlobalBricks
                    });
                else state.globalSdf.PrepareDisabled();
                state.changes.Begin(state.scene,Mathf.Max(s.shadowDistance,s.traceDistance)+Mathf.Max(1,s.traceDistance),
                    (slot,id)=>
                    {
                        var proxy=state.scene.GetProxy(slot);
                        return proxy!=null && proxy.StableId==id?proxy.SourceRenderer:null;
                    });
                foreach(Bounds bounds in state.sdf.RepresentationChangedBounds)
                    state.changes.Add(bounds,false,Mathf.Max(s.shadowDistance,s.traceDistance)+Mathf.Max(1,s.traceDistance));
                // A prepared HLOD publication changes visibility but must retain its warm
                // lighting. Actual SDF content/fallback changes still reject geometry history.
                foreach(Bounds bounds in state.sdf.GeometryChangedBounds)
                    state.changes.Add(bounds,true,Mathf.Max(s.shadowDistance,s.traceDistance)+Mathf.Max(1,s.traceDistance));
                foreach(var change in state.sdf.TransformChanges)
                    state.changes.AddTransform(change.Bounds,Mathf.Max(s.shadowDistance,s.traceDistance)+Mathf.Max(1,s.traceDistance),change.SourceRenderer);
                state.surfaceCache.Prepare(state.scene,new HybridLumenGISurfaceCache.Config
                {
                    tileResolution=s.surfaceTileResolution,maxResidentCards=s.residentSurfaceCards,capturesPerFrame=state.effectiveBudget.SurfaceCaptures,
                    maxDrawsPerFrame=s.surfaceDrawsPerFrame,maxAtlasMiB=s.surfaceAtlasBudgetMiB,layerMask=s.materialLayers,referencePosition=camera.transform.position,
                    captureRecordingCpuBudgetMilliseconds=s.surfaceCaptureRecordingCpuBudgetMilliseconds,
                    patchGrid=Mathf.Clamp(s.cachePatchGrid,1,4)
                });
                state.EnsureCache(slots,Mathf.Clamp(s.cachePatchGrid,1,4),state.surfaceCache.CardCount);
                bool waitForHlodBuildTurn = buildTurnBlocked && readyExactReplacement;
                if (waitForHlodBuildTurn)
                {
                    // Admission can evict a staged page after Scene selection. Only retain
                    // queue priority for a handoff that still has its ready staging set.
                    RevokeStaleHlodReadiness(state);
                    waitForHlodBuildTurn = state.scene.HasReadyExactHlodReplacement(preparedExact, exactHlodTarget);
                    if (!waitForHlodBuildTurn) state.hardware.CancelDeferredHlodBuild();
                }
                // Freeze exactly the matrices later uploaded to transport. Relevance
                // must cover its reconstruction, including the current URP jitter.
                Matrix4x4 view=cameraData.GetViewMatrix(),vp=GL.GetGPUProjectionMatrix(cameraData.GetProjectionMatrix(),true)*view;
                Matrix4x4 invVP=vp.inverse;
                Light mainLight=staticShadowmask && lightData.mainLightIndex>=0 ? lightData.visibleLights[lightData.mainLightIndex].light : null;
                int lightCount=UpdateLights(state,lightData.supportsLightLayers,cameraData,view,invVP,
                    mainLight,!staticShadowmask || frameData.Get<UniversalShadowData>().supportsAdditionalLightShadows,
                    out int nonAnalyticOnlyChannels);
                AddShadowCasterChanges(state, lightCount);
                foreach(Bounds bounds in state.surfaceCache.ChangedBounds)
                    state.changes.Add(bounds,false,Mathf.Max(1,s.traceDistance));
                state.lightingChanged|=state.surfaceCache.ChangedBounds.Count>0 || state.sdf.RepresentationChangedBounds.Count>0;
                bool changed=state.scene.RequiresFullInvalidation;
                if(changed) { state.epoch=state.epoch%8000000+1; state.InvalidateScreenHistory(); }
                bool hardwarePreference=s.preferHardwareTracing;
                ulong preparedBackendRequest=backendRequest;
                if(!hardwarePreference)state.hardware.Deactivate();
                bool hardware=hardwarePreference && state.hardware.Prepare(state.scene,state.scene.Revision,
                    hardwareTriangleLimit,state.surfaceCache,
                    Math.Max(1L,s.hardwareGeometryBudgetMiB)*1024*1024);
                // The prepared set can reuse the RTAS if staging lost eligibility before build preparation.
                if (!waitForHlodBuildTurn && state.hardware.CanDispatch) state.hardware.CancelDeferredHlodBuild();
                int softwareTriangles=(int)Math.Min(Mathf.Clamp(s.meshTriangleBudget,1024,HybridLumenGISoftwareTriangleBvh.MaxTriangles),
                    Math.Max(1024,(Math.Max(1L,s.softwareGeometryBudgetMiB)*1024*1024-4096)/512));
                bool softwareExact=!hardware && s.exactSoftwareTracing && exactSoftware!=null &&
                    state.PrepareSoftwareAttributes(softwareTriangles,Math.Max(1L,s.softwareGeometryBudgetMiB)*1024*1024);
                // Freeze the observer with this graph's camera matrices. In view
                // space +Z points toward the viewer; orthographic rays share it.
                Vector4 materialView=view.inverse.GetColumn(camera.orthographic?2:3);
                materialView.w=camera.orthographic?0:1;
                bool cut=(camera.transform.position-state.previousPosition).sqrMagnitude>9 || Quaternion.Angle(camera.transform.rotation,state.previousRotation)>45;
                Vector2 jitter=GetJitter(cameraData);
                // URP motion is f -> f-1 even when this camera's GI was skipped or
                // rendered twice. A separate receipt gates the exact screen-history source.
                bool historyValid=state.valid;
                state.valid=false;
                Rect cameraViewport=camera.pixelRect;
                int cameraCullingMask=camera.cullingMask;
                var historyContext=new HybridLumenGIHistoryLifecycle.FrameContext(fullW,fullH,w,h,
                    cameraViewport.x,cameraViewport.y,cameraViewport.width,cameraViewport.height,
                    projectionContextKey:0,cullingMask:cameraCullingMask);
                var historyToken=state.historyLifecycle.BeginFrame(Time.frameCount,historyContext);
                if(!historyToken.IsValid) return;
                if(receiverSources!=null) state.receiverHistory.Begin(historyToken,receiverSources);
                else state.receiverHistory.Invalidate();
                var identityFrame=identityEnabled?HybridLumenGIReceiverIdentityFrame.Build(receiverSources,state.receiverHistory,vp,fullW,fullH,
                    uvStartsAtTop:SystemInfo.graphicsUVStartsAtTop):null;
                if(identityFrame!=null)
                {
                    state.receiverIdentityDraws=identityFrame.Draws.Count;state.receiverUnknownRectangles=identityFrame.UnknownRects.Count;
                    state.receiverIdentityBufferBytes=(long)fullW*fullH*12+Math.Max(1,identityFrame.Rows.Count)*80L;
                    foreach(var moved in identityFrame.MovedBounds)
                    {
                        float influence=Mathf.Max(s.shadowDistance,s.traceDistance)+Mathf.Max(1,s.traceDistance);
                        state.changes.AddTransform(moved.Previous,influence,moved.SourceRenderer);
                        state.changes.AddTransform(moved.Current,influence,moved.SourceRenderer);
                    }
                }
                var receiverReceipt=new ReceiverCaptureReceipt();
                var frameTiming=new HybridLumenGIGpuFrameTiming(state.gpuTiming,state.nativeGpuTiming,
                    state.useNativeGpuTiming,identityEnabled,state.InvalidateGpuFeedback);
                int write=1-state.readIndex;
                var diffuse=CreateTexture(graph,fullW,fullH,replace?GraphicsFormat.R16G16B16A16_SFloat:GraphicsFormat.R8G8B8A8_UNorm,"HLGI surface diffuse",false);
                var emission=CreateTexture(graph,fullW,fullH,GraphicsFormat.R16G16B16A16_SFloat,"HLGI surface emission",false);
                var receiverPolicy=CreateTexture(graph,fullW,fullH,policyFormat,"HLGI receiver lighting policy",false);
                var nativeDiffuseFog=replace?CreateTexture(graph,fullW,fullH,GraphicsFormat.R16G16B16A16_SFloat,"HLGI native diffuse and fog",false):emission;
                var captureDepth=graph.CreateTexture(new TextureDesc(fullW,fullH){name="HLGI capture depth",depthBufferBits=DepthBits.Depth32,clearBuffer=true});
                var drawing=RenderingUtils.CreateDrawingSettings(tags,rendering,cameraData,lightData,cameraData.defaultOpaqueSortFlags);
                if(staticShadowmask) drawing.perObjectData|=PerObjectData.Lightmaps|PerObjectData.ShadowMask;
                drawing.overrideShader=replace?nativeDiffuse:surface; drawing.overrideShaderPassIndex=0;
                // UnityPerDraw exposes rendering layers, but not the GameObject layer.
                // Disjoint renderer lists provide that identity without modifying renderers/MPBs.
                var receiverLists=new List<RendererListHandle>();var receiverLayers=new List<int>();
                int receiverMask=s.materialLayers.value & cameraCullingMask;
                for(int layer=0;layer<32;layer++) if((receiverMask & (1<<layer))!=0)
                {
                    var filtering=new FilteringSettings(RenderQueueRange.opaque,1<<layer);
                    receiverLists.Add(graph.CreateRendererList(new RendererListParams(rendering.cullResults,drawing,filtering)));
                    receiverLayers.Add(layer);
                }
                using(var builder=graph.AddRasterRenderPass<SurfacePassData>("HLGI Material capture",out var data))
                {
                    data.renderers=receiverLists.ToArray();data.layers=receiverLayers.ToArray();data.state=state;data.frameTiming=frameTiming;
                    data.owner=this;data.historyToken=historyToken;data.receiverSources=receiverSources;
                    data.discoveryBudget=discoveryBudget;
                    data.fingerprintBudget=fingerprintBudget;data.materialLayers=s.materialLayers;
                    data.receiverReceipt=receiverReceipt;data.identityExpected=identityEnabled;
                    data.staticShadowmask=staticShadowmask;
                    foreach(var list in data.renderers) builder.UseRendererList(list);
                    builder.SetRenderAttachment(diffuse,0,AccessFlags.Write); builder.SetRenderAttachment(emission,1,AccessFlags.Write);
                    if(replace) builder.SetRenderAttachment(nativeDiffuseFog,2,AccessFlags.Write);
                    if(replace || staticShadowmask) builder.UseAllGlobalTextures(true);
                    builder.SetRenderAttachment(receiverPolicy,replace?3:2,AccessFlags.Write);
                    builder.AllowGlobalStateModification(true);
                    builder.SetRenderAttachmentDepth(captureDepth,AccessFlags.Write);
                    builder.SetRenderFunc(static(SurfacePassData d,RasterGraphContext ctx)=>
                    {
                        d.frameTiming.Begin(HybridLumenGIGpuFrameTiming.Phase.ReceiverCapture,ctx.cmd);
                        try
                        {
                            bool sourceInputsCurrent=false;
                            if(d.receiverSources!=null && d.state.historyLifecycle.IsCurrent(d.historyToken))
                                sourceInputsCurrent=d.owner.receiverRegistry.IsCurrent(d.receiverSources,
                                    d.owner.receiverDiscovery.Scan(d.state.camera,d.materialLayers,d.discoveryBudget),d.fingerprintBudget);
                            ctx.cmd.SetGlobalInt("_HLGI_CaptureStaticShadowmask",d.staticShadowmask?1:0);
                            for(int i=0;i<d.renderers.Length;i++)
                            {
                                ctx.cmd.SetGlobalFloat("_HLGI_ReceiverLayerIndex",d.layers[i]);
                                ctx.cmd.DrawRendererList(d.renderers[i]);
                            }
                            d.receiverReceipt.sourcesCurrent=sourceInputsCurrent;
                            if(!d.identityExpected) d.state.receiverHistory.MarkCaptureRecorded(d.historyToken,sourceInputsCurrent);
                        }
                        catch { d.state.InvalidateFailedRender();throw; }
                        finally
                        {
                            ctx.cmd.SetGlobalInt("_HLGI_CaptureStaticShadowmask",0);
                            d.frameTiming.End(HybridLumenGIGpuFrameTiming.Phase.ReceiverCapture,ctx.cmd);
                        }
                    });
                }
                TextureHandle identityRead=default,identityWrite=default;
                HybridLumenGIReceiverIdentityPass.Result identity=default;
                if(identityEnabled)
                {
                    identityRead=graph.ImportTexture(state.receiverIdentity[state.readIndex]);
                    identityWrite=graph.ImportTexture(state.receiverIdentity[write]);
                    LayerMask identityLayers=s.materialLayers;
                    identity=receiverIdentityPass.Record(graph,identityFrame,resources.cameraDepthTexture,captureDepth,identityWrite,
                        fullW,fullH,w,h,vp,
                        ()=>receiverReceipt.sourcesCurrent && state.historyLifecycle.IsCurrent(historyToken) &&
                            IdentityCoverageGlobalsSupported() && receiverRegistry.IsCurrent(receiverSources,
                                receiverDiscovery.Scan(camera,identityLayers,discoveryBudget),fingerprintBudget),
                        recorded=>
                        {
                            bool accepted=state.receiverHistory.MarkCaptureRecorded(historyToken,recorded && receiverReceipt.sourcesCurrent);
                            receiverReceipt.identityRecorded=accepted;
                            state.receiverIdentityStatus=accepted?"Identity resolve recorded; GPU completion not implied":"Identity receipt rejected; current GI retained";
                        },
                        (cmd,stage,begin)=>
                        {
                            var phase=(HybridLumenGIGpuFrameTiming.Phase)(stage+1);
                            if(begin) frameTiming.Begin(phase,cmd);else frameTiming.End(phase,cmd);
                        },frameTiming.Invalidate);
                    // A partially constructed identity graph may still execute clear/upload.
                    // Its incomplete measured chain must never become budget feedback.
                    if(!identity.IsValid) frameTiming.Invalidate();
                }
                var raw=CreateTexture(graph,w,h,GraphicsFormat.R16G16B16A16_SFloat,"HLGI raw");
                var work=new Work
                {
                    owner=this,state=state,compute=hardware?state.hardware.Shader:softwareExact?exactSoftware:software,hardware=hardware,
                    backendRequest=preparedBackendRequest,hardwarePreference=hardwarePreference,waitForHlodBuildTurn=waitForHlodBuildTurn,
                    geometry=hardware?state.hardware:softwareExact?state.softwareGeometry:null,
                    depth=resources.cameraDepthTexture,captureDepth=captureDepth,normals=resources.cameraNormalsTexture,
                    motion=resources.motionVectorColor.IsValid()?resources.motionVectorColor:resources.cameraNormalsTexture,
                    hasMotion=resources.motionVectorColor.IsValid(),diffuse=diffuse,emission=emission,receiverPolicy=receiverPolicy,staticShadowmask=staticShadowmask,
                    raw=raw,filterIterations=filterIterations,
                    tempA=filterIterations>1?CreateTexture(graph,w,h,GraphicsFormat.R16G16B16A16_SFloat,"HLGI filter A"):raw,
                    historyRead=graph.ImportTexture(state.history[state.readIndex]),historyWrite=graph.ImportTexture(state.history[write]),
                    geometryRead=graph.ImportTexture(state.geometry[state.readIndex]),geometryWrite=graph.ImportTexture(state.geometry[write]),
                    materialRead=graph.ImportTexture(state.material[state.readIndex]),materialWrite=graph.ImportTexture(state.material[write]),
                    momentsRead=graph.ImportTexture(state.moments[state.readIndex]),momentsWrite=graph.ImportTexture(state.moments[write]),
                    read=state.readIndex,cacheRead=state.cacheRead,cacheStart=state.cacheCursor,frame=state.frame,epoch=state.epoch,lightCount=lightCount,
                    nonAnalyticOnlyChannels=nonAnalyticOnlyChannels,
                    valid=historyValid && state.historyLifecycle.CanReuseHistory(historyToken) && !cut && s.temporalAccumulation &&
                        (!s.receiverObjectHistory || (identityEnabled && identity.IsValid)),
                    useIdentity=identityEnabled && identity.IsValid,identity=identity,identityRead=identityRead,identityWrite=identityWrite,
                    receiverReceipt=receiverReceipt,
                    historyToken=historyToken,view=view,vp=vp,invVP=invVP,materialView=materialView,
                    previousVP=state.previousVP,previousInvVP=state.previousInvVP,jitterDelta=state.previousJitter-jitter
                    ,viewport=new Rect(0,0,fullW,fullH),frameTiming=frameTiming,
                    cachePatchBudget=state.effectiveBudget.CachePatches
                };
                PrepareHardwareMaterials(graph,work);
                AddSdfShadowChanges(work);
                if(identityFrame!=null) state.changes.ResolveReceiverGroups(identityFrame.GetReceiverGroup);
                if(!state.surfaceCache.LimitsCaptureRecording) state.changes.Upload();
                // Bind a real transient buffer even when the table is empty; an unbound SRV
                // is not portable merely because a runtime count happens to be zero.
                work.areaEmitters=graph.CreateBuffer(new BufferDesc(Math.Max(1,work.areaLayout?.Count??0),HybridLumenGIAreaEmission.Stride)
                    {name="HLGI exact area emitters"});
                HybridLumenGIValidationCapture.TryClaim(camera,validationOwner,Time.frameCount,work.frame,work.epoch,
                    cameraData.cameraTargetDescriptor,resources.isActiveTargetBackBuffer,camera.stereoEnabled,out work.validationTicket);
                using(var builder=graph.AddUnsafePass<Work>("HLGI Cache, trace and denoise",out var data))
                {
                    Copy(work,data);
                    builder.UseBuffer(work.areaEmitters,AccessFlags.ReadWrite);
                    if(work.softwareLayout!=null)
                    { builder.UseBuffer(work.softwareNodes,AccessFlags.ReadWrite);builder.UseBuffer(work.softwareLeaves,AccessFlags.ReadWrite); }
                    foreach(var t in new[]{work.depth,captureDepth,work.normals,work.motion,diffuse,emission,receiverPolicy,work.historyRead,work.geometryRead,work.materialRead,work.momentsRead}) builder.UseTexture(t,AccessFlags.Read);
                    foreach(var t in new[]{work.raw,work.historyWrite,work.geometryWrite,work.materialWrite,work.momentsWrite}) builder.UseTexture(t,AccessFlags.ReadWrite);
                    if(filterIterations>1) builder.UseTexture(work.tempA,AccessFlags.ReadWrite);
                    if(work.useIdentity)
                    {
                        builder.UseTexture(identityRead,AccessFlags.Read);builder.UseTexture(identityWrite,AccessFlags.Read);
                        builder.UseBuffer(identity.Candidates,AccessFlags.Read);builder.UseBuffer(identity.Objects,AccessFlags.Read);
                    }
                    foreach(var atlas in new[]{state.surfaceCache.DiffuseAtlas,state.surfaceCache.EmissionAtlas,state.surfaceCache.PositionAtlas,state.surfaceCache.NormalAtlas,state.surfaceCache.DepthAtlas})
                        builder.UseTexture(graph.ImportTexture(atlas),AccessFlags.ReadWrite);
                    if(state.surfaceCache.ShadowmaskAtlas!=null)
                        builder.UseTexture(graph.ImportTexture(state.surfaceCache.ShadowmaskAtlas),AccessFlags.ReadWrite);
                    if(work.hitMaterials!=null)
                    {
                        foreach(var buffer in work.hitMaterials.Buffers)builder.UseBuffer(buffer,AccessFlags.ReadWrite);
                        foreach(var texture in work.hitMaterials.SourceTextures)builder.UseTexture(texture,AccessFlags.Read);
                    }
                    builder.AllowPassCulling(false);
                    // Card capture and inline RT binding set owned global shader properties.
                    builder.AllowGlobalStateModification(true);
                    builder.SetRenderFunc(static(Work d,UnsafeGraphContext ctx)=>d.owner.Execute(d,CommandBufferHelpers.GetNativeCommandBuffer(ctx.cmd)));
                }
                TextureHandle filtered=filterIterations==0?work.historyWrite:(filterIterations%2==1?work.tempA:work.tempB);
                var validationTicket=work.validationTicket;
                if(validationTicket!=null)
                {
                    validationTicket.SetCamera(HybridLumenGIValidationSourceState.CameraDescriptor.FromMatrices(
                        view,GL.GetGPUProjectionMatrix(cameraData.GetProjectionMatrix(),true),jitter,fullW,fullH));
                    validationTicket.SetComposite(new HybridLumenGIValidationCapture.CompositeConstants
                    {
                        intensity=s.indirectIntensity,depthThreshold=s.relativeDepthThreshold,debug=(int)s.debugView,
                        normalsOct=s.normalsOctEncoded?1:0,composition=replace?1:0,invVP=work.invVP,
                        giSize=new Vector2Int(state.width,state.height)
                    });
                    HybridLumenGIValidationCapture.RecordBefore(graph,validationTicket,resources.activeColorTexture,
                        new HybridLumenGIValidationCapture.SupportTextures
                        {
                            filteredD=filtered,geometry=work.geometryWrite,material=diffuse,depth=work.depth,
                            captureDepth=captureDepth,emissionValidity=emission,normals=work.normals,moments=work.momentsWrite,
                            nativeDiffuseFog=replace?nativeDiffuseFog:default
                        });
                }
                using(var builder=graph.AddRasterRenderPass<CompositeData>("HLGI Bilateral composite",out var data))
                {
                    data.material=composite; data.state=state; data.gi=filtered; data.geometry=work.geometryWrite;
                    data.diffuse=diffuse; data.emission=emission; data.depth=work.depth; data.captureDepth=captureDepth; data.normals=work.normals; data.moments=work.momentsWrite;
                    data.invVP=work.invVP; data.intensity=s.indirectIntensity; data.debug=(int)s.debugView;
                    data.depthThreshold=s.relativeDepthThreshold; data.normalsOct=s.normalsOctEncoded?1:0;
                    data.nativeDiffuseFog=nativeDiffuseFog;data.composition=replace?1:0;
                    data.frameTiming=frameTiming;data.historyToken=work.historyToken;
                    data.completedVP=vp;data.completedJitter=jitter;
                    data.completedPosition=camera.transform.position;data.completedRotation=camera.transform.rotation;
                    foreach(var t in new[]{filtered,work.geometryWrite,diffuse,emission,work.depth,captureDepth,work.normals,work.momentsWrite}) builder.UseTexture(t,AccessFlags.Read);
                    if(replace) builder.UseTexture(nativeDiffuseFog,AccessFlags.Read);
                    builder.SetRenderAttachment(resources.activeColorTexture,0,AccessFlags.ReadWrite);
                    builder.SetRenderFunc(static(CompositeData d,RasterGraphContext ctx)=>
                    {
                        d.frameTiming.Begin(HybridLumenGIGpuFrameTiming.Phase.Composite,ctx.cmd);
                        try
                        {
                        var p=d.state.properties; p.Clear();
                        p.SetTexture("_HLGI_GITexture",(RTHandle)d.gi); p.SetTexture("_HLGI_Geometry",(RTHandle)d.geometry);
                        p.SetTexture("_HLGI_Diffuse",(RTHandle)d.diffuse); p.SetTexture("_HLGI_Emission",(RTHandle)d.emission);
                        p.SetTexture("_HLGI_Depth",(RTHandle)d.depth); p.SetTexture("_HLGI_Normals",(RTHandle)d.normals); p.SetTexture("_HLGI_Moments",(RTHandle)d.moments);
                        p.SetTexture("_HLGI_CaptureDepth",(RTHandle)d.captureDepth);
                        p.SetTexture("_HLGI_NativeDiffuseFog",(RTHandle)d.nativeDiffuseFog);p.SetInt("_HLGI_Composition",d.composition);
                        p.SetVector("_HLGI_Size",new Vector4(d.state.width,d.state.height,1f/d.state.width,1f/d.state.height));
                        p.SetMatrix("_HLGI_InvVP",d.invVP); p.SetFloat("_HLGI_Intensity",d.intensity); p.SetFloat("_HLGI_DepthThreshold",d.depthThreshold);
                        p.SetInt("_HLGI_Debug",d.debug); p.SetInt("_HLGI_NormalsOct",d.normalsOct);
                        ctx.cmd.DrawProcedural(Matrix4x4.identity,d.material,d.debug==0?0:1,MeshTopology.Triangles,3,1,p);
                        }
                        catch { d.state.InvalidateFailedRender();throw; }
                        finally
                        {
                            d.frameTiming.End(HybridLumenGIGpuFrameTiming.Phase.Composite,ctx.cmd);
                        }
                        // Publishing at graph construction would accept history even when a
                        // callback later fails. This receipt is ordered recording, not a GPU fence.
                        d.state.CompleteScreenHistory(d.historyToken,d.completedVP,d.invVP,d.completedJitter,d.completedPosition,d.completedRotation);
                    });
                }
                if(validationTicket!=null)
                    HybridLumenGIValidationCapture.RecordAfter(graph,validationTicket,resources.activeColorTexture);
                if(state.useNativeGpuTiming && state.nativeGpuTiming.CurrentFrameToken.IsValid)
                {
                    // D3D12 ResolveQueryData is forbidden inside native render passes.
                    // This explicit dependency ends the raster phase before resolving all
                    // six timestamps. The plugin independently rejects incomplete tickets.
                    using(var builder=graph.AddUnsafePass<NativeResolveData>("HLGI Native timestamp resolve",out var data))
                    {
                        data.frameTiming=frameTiming;
                        builder.UseTexture(resources.activeColorTexture,AccessFlags.Read);
                        builder.AllowPassCulling(false);builder.AllowGlobalStateModification(true);
                        builder.SetRenderFunc(static(NativeResolveData d,UnsafeGraphContext ctx)=>
                        {
                            d.frameTiming.Resolve(CommandBufferHelpers.GetNativeCommandBuffer(ctx.cmd));
                        });
                    }
                }
                state.readIndex=write; state.frame++;
            }
            private static TextureHandle CreateTexture(RenderGraph graph,int w,int h,GraphicsFormat format,string name,bool randomWrite=true)
            { return graph.CreateTexture(new TextureDesc(w,h){name=name,colorFormat=format,enableRandomWrite=randomWrite,clearBuffer=true,filterMode=FilterMode.Point}); }
            private static Vector2 GetJitter(UniversalCameraData c)
            {
                // In this URP version non-XR Base cameras store camera.projectionMatrix
                // before applying their separate jitter matrix. Keep the GPU-space delta
                // without querying the null RenderGraph compatibility color target.
                Matrix4x4 jittered=GL.GetGPUProjectionMatrix(c.GetProjectionMatrix(),true);
                Matrix4x4 unjittered=GL.GetGPUProjectionMatrix(c.camera.projectionMatrix,true);
                Matrix4x4 delta=jittered*unjittered.inverse;
                // Derive UV translation in GPU space for both orthographic and perspective cameras.
                return new Vector2(delta.m03*0.5f,delta.m13*(SystemInfo.graphicsUVStartsAtTop?-0.5f:0.5f));
            }
            private static bool IdentityCoverageGlobalsSupported()
            {
                // These globals change ordinary Lit alpha coverage outside the
                // immutable material snapshot. Check at the actual draw callback.
                return !Shader.IsKeywordEnabled("DEBUG_DISPLAY") && Shader.GetGlobalFloat("_AlphaToMaskAvailable")==0;
            }
            private static void Copy(Work a,Work b)
            {
                b.hitMaterials=a.hitMaterials;
                b.sourceUncertain=a.sourceUncertain;b.validationTicket=a.validationTicket;
                b.backendRequest=a.backendRequest;b.hardwarePreference=a.hardwarePreference;b.waitForHlodBuildTurn=a.waitForHlodBuildTurn;
                b.geometry=a.geometry;b.softwareLayout=a.softwareLayout;b.softwareNodes=a.softwareNodes;b.softwareLeaves=a.softwareLeaves;
                b.geometryVersion=a.geometryVersion;
                b.areaEmitters=a.areaEmitters;b.areaLayout=a.areaLayout;
                b.exactMaterialObservations=a.exactMaterialObservations;
                b.traceOwners=a.traceOwners;
                b.owner=a.owner;b.state=a.state;b.compute=a.compute;b.hardware=a.hardware;b.depth=a.depth;b.captureDepth=a.captureDepth;b.normals=a.normals;b.motion=a.motion;b.diffuse=a.diffuse;b.emission=a.emission;b.receiverPolicy=a.receiverPolicy;
                b.raw=a.raw;b.tempA=a.tempA;b.filterIterations=a.filterIterations;b.historyRead=a.historyRead;b.historyWrite=a.historyWrite;b.geometryRead=a.geometryRead;b.geometryWrite=a.geometryWrite;
                b.materialRead=a.materialRead;b.materialWrite=a.materialWrite;b.momentsRead=a.momentsRead;b.momentsWrite=a.momentsWrite;b.vp=a.vp;b.invVP=a.invVP;b.view=a.view;
                b.previousVP=a.previousVP;b.previousInvVP=a.previousInvVP;b.materialView=a.materialView;b.jitterDelta=a.jitterDelta;b.read=a.read;b.cacheRead=a.cacheRead;b.cacheStart=a.cacheStart;b.frame=a.frame;
                b.epoch=a.epoch;b.lightCount=a.lightCount;b.valid=a.valid;b.hasMotion=a.hasMotion;b.staticShadowmask=a.staticShadowmask;
                b.nonAnalyticOnlyChannels=a.nonAnalyticOnlyChannels;
                b.viewport=a.viewport;
                b.frameTiming=a.frameTiming;b.historyToken=a.historyToken;b.cachePatchBudget=a.cachePatchBudget;
                b.useIdentity=a.useIdentity;b.identity=a.identity;b.identityRead=a.identityRead;b.identityWrite=a.identityWrite;
                b.receiverReceipt=a.receiverReceipt;
            }
            private void Execute(Work d,CommandBuffer cmd)
            {
                var state=d.state;
                bool current=state.scenePreparedEngineFrame==d.historyToken.EngineFrame && state.scenePreparedWorkFrame==d.frame;
                d.frameTiming.Begin(HybridLumenGIGpuFrameTiming.Phase.Transport,cmd);
                try
                {
                    try { ExecuteTransport(d,cmd,current); }
                    finally
                    {
                        try
                        {
                            if(d.hitMaterials!=null)
                            {
                                if(!d.hitMaterials.Finish(cmd,out string reason))state.hardwareMaterialStatus=reason;
                                materialPasses.Remove(d.hitMaterials);
                            }
                        }
                        finally { d.frameTiming.End(HybridLumenGIGpuFrameTiming.Phase.Transport,cmd); }
                    }
                }
                catch
                {
                    if(current) state.DiscardWorldPreparation();
                    throw;
                }
                if(!current)return;
                state.CompleteWorldRecording(1-d.cacheRead);
                Array.Copy(state.lightData,state.recordedLightData,d.lightCount);
                state.recordedLightCount=d.lightCount;
                state.recordedLightEpoch=d.epoch;
                state.exactMaterialObservations=d.geometry!=null ? d.exactMaterialObservations : null;
                state.recordedTraceOwners=d.geometry!=null ? d.traceOwners : null;
                state.lastHardware=d.hardware;state.exactSoftwareGeometry=d.ExactSoftware;
                state.recordedTransportBackend = d.hardware ? "DXR" : d.ExactSoftware ? "exact software" : "SDF/analytic software";
                state.transportRecordedEngineFrame = d.historyToken.EngineFrame;
                state.transportRecordedWorkFrame = d.frame;
                state.recordedBackendRequest = d.backendRequest;
                state.recordedHardwarePreference = d.hardwarePreference;
                // Use the recorded backend after any preparation or recording fallback.
                if (d.hardware || !s.exactSoftwareTracing) state.DeactivateSoftwareGeometry();
                if (d.hardware && d.waitForHlodBuildTurn) state.hardware.QueueDeferredHlodBuild(d.historyToken.EngineFrame);
            }

            private static void RevokeStaleHlodReadiness(CameraState state)
            {
                // Texture/MPB or SDF content can change without the proxy's revision.
                for (int slot = 0; slot < state.scene.Capacity; slot++)
                {
                    if (!state.scene.IsWarming(slot)) continue;
                    var identity = state.scene.Data[slot].identity;
                    var proxy = state.scene.GetProxy(slot);
                    int id = (int)identity.x, revision = (int)identity.y;
                    bool geometryCurrent = proxy != null && proxy.Revision == revision &&
                        (proxy.MeshSdf == null || state.sdf.IsSourceCurrent(slot, proxy, id, revision));
                    if (!geometryCurrent || !state.surfaceCache.IsSlotSourceCurrent(slot, id, revision))
                        state.scene.ReportReadiness(id, revision, false, false, false);
                }
            }

            private void PrepareHardwareMaterials(RenderGraph graph,Work d)
            {
                var state=d.state;
                state.hardwareMaterialFrameBytes=0;state.hardwareMaterialUnknownRecords=0;
                state.areaEmitterBytes=0;
                state.hardwareMaterialStatus=d.geometry!=null?"Preparing immutable hit materials":"SDF/analytic software tracing";
                if(d.geometry==null){state.areaEmissionCache.Clear();return;}
                if(!d.geometry.TryCaptureHitMaterialSources(state.scene,out var sources,out string reason))
                { FallBackToSoftware(d,reason,sourceUncertain:true);return; }
                if(!HybridLumenGIHitMaterialPass.TryCreate(graph,sources,Math.Max(1L,s.hardwareMaterialBudgetMiB)*1024*1024,
                        out d.hitMaterials,out reason))
                { FallBackToSoftware(d,reason);return; }
                materialPasses.Add(d.hitMaterials);
                d.geometryVersion=d.geometry.GeometryVersion;
                if(!d.hardware)
                {
                    if(!state.PrepareSoftwareGeometry(graph,s.meshTriangleBudget,Math.Max(1L,s.softwareGeometryBudgetMiB)*1024*1024,
                        out d.softwareLayout,out d.softwareNodes,out d.softwareLeaves,out reason))
                    { FallBackToSoftware(d,reason);return; }
                }
                if(!state.areaEmissionCache.TryBuild(sources,d.geometry,d.geometryVersion,d.hitMaterials.Generation,
                    Mathf.Clamp(s.maxAreaEmitterTriangles,0,HybridLumenGIAreaEmission.MaxTriangles),out d.areaLayout,out reason))
                    d.areaLayout=null; // A missing proposal never removes the original direction estimator.
                PrepareTraceRepresentationChanges(d);
                PrepareExactMaterialChanges(d,sources);
                state.hardwareMaterialFrameBytes=d.hitMaterials.ByteCount;
                state.hardwareMaterialStatus="Prepared; GPU upload not yet recorded";
            }

            private void PrepareTraceRepresentationChanges(Work work)
            {
                var state = work.state;
                var scene = state.scene;
                int[] previous = state.recordedTraceOwners;
                int[] current = work.traceOwners = new int[scene.Capacity];
                bool comparable = previous != null && previous.Length == current.Length && work.hardware == state.lastHardware;
                float traceReach = Mathf.Max(1, s.traceDistance);
                float influence = Mathf.Max(s.shadowDistance, s.traceDistance) + traceReach;
                for (int slot = 0; slot < current.Length; slot++)
                {
                    if (!scene.IsPublished(slot)) continue;
                    int owner = (int)scene.Data[slot].identity.x;
                    // Positive is exact, negative is fallback, and zero is unpublished.
                    // Compare only the same published owner, leaving entry/exit to Scene.
                    int representation = work.geometry.HasPreparedTriangles(slot) ? owner : -owner;
                    current[slot] = representation;
                    if (!comparable || previous[slot] != -representation ||
                        !scene.TryGetPreparedTraversalBounds(slot, out Bounds bounds)) continue;
                    state.changes.Add(bounds, true, influence);
                    state.surfaceCache.AddChangedBounds(bounds);

                    // Exact coverage can change the shadow even when the scene owner did not move.
                    float shadowReach = CasterShadowReach(state, work.lightCount, scene.LightingPolicies[slot]);
                    if (shadowReach > 0) AddLocalLightingChange(state, bounds, shadowReach + traceReach);
                }
            }

            private void PrepareExactMaterialChanges(Work work,IReadOnlyList<HybridLumenGIHitMaterialBatch.Source> sources)
            {
                var state = work.state;
                float traceReach = Mathf.Max(1, s.traceDistance);
                float shadowReach = 0;
                for (int i = 0; i < work.lightCount; i++)
                    shadowReach = Mathf.Max(shadowReach, ShadowReach(state.lightData[i]));
                foreach (var source in sources)
                {
                    if (!state.scene.TryGetPublishedSlot((int)source.StableId, out int slot)) continue;
                    bool cardless = state.surfaceCache.GetCardCount(slot) == 0;
                    ulong key = source.MaterialKey;
                    var snapshot = source.Snapshot;
                    var coverage = new HybridLumenGIHitMaterialLayout.ShadowCoverage(snapshot.HitMaterial);
                    ExactMaterialObservation previous = default;
                    bool hasPrevious = state.exactMaterialObservations != null &&
                        state.exactMaterialObservations.TryGetValue(key, out previous);
                    bool sameCoverage = hasPrevious && coverage.Matches(previous.shadowCoverage);
                    (work.exactMaterialObservations ??= new Dictionary<ulong, ExactMaterialObservation>())[key] =
                        new ExactMaterialObservation
                        {
                            cardlessSource = cardless ? snapshot : null, shadowCoverage = coverage,
                            shadowMapUploadRecorded = sameCoverage ? previous.shadowMapUploadRecorded : null
                        };
                    if (!hasPrevious) continue;

                    // Card owners already report changes to their outgoing material. Exact
                    // shadow coverage can also change the lighting of more distant receivers.
                    bool nearby = cardless && previous.cardlessSource != null &&
                        (!snapshot.CanReuseHistory || !snapshot.Equals(previous.cardlessSource));
                    bool shadow = shadowReach > 0 && state.scene.LightingPolicies[slot].shadowCastingMode != (uint)ShadowCastingMode.Off &&
                        !sameCoverage;
                    if ((!nearby && !shadow) || !state.scene.TryGetPreparedTraversalBounds(slot, out Bounds bounds)) continue;
                    if (nearby) state.surfaceCache.AddChangedBounds(bounds);
                    if (shadow) AddLocalLightingChange(state, bounds, shadowReach + traceReach);
                    else state.changes.Add(bounds, false, traceReach);
                }
            }

            private bool AddRecordedShadowMapChanges(Work work)
            {
                var observations = work.exactMaterialObservations;
                var uploads = work.hitMaterials.ShadowMapUploads;
                if (observations == null || uploads == null) return false;
                var state = work.state;
                float traceReach = Mathf.Max(1, s.traceDistance);
                bool changed = false;
                foreach (var upload in uploads)
                {
                    if (!observations.TryGetValue(upload.Key, out var observation)) continue;
                    bool becameRecorded = upload.Value && observation.shadowMapUploadRecorded == false;
                    observation.shadowMapUploadRecorded = upload.Value;
                    observations[upload.Key] = observation;
                    // The source change may have been serviced while its alpha was still unknown.
                    if (!becameRecorded || !state.scene.TryGetPublishedSlot((int)(upload.Key >> 32), out int slot)) continue;
                    float reach = CasterShadowReach(state, work.lightCount, state.scene.LightingPolicies[slot]);
                    if (reach <= 0 || !state.scene.TryGetPreparedTraversalBounds(slot, out Bounds bounds)) continue;
                    AddLocalLightingChange(state, bounds, reach + traceReach);
                    changed = true;
                }
                return changed;
            }

            private void FallBackToSoftware(Work d,string reason,bool sourceUncertain=false)
            {
                var state=d.state;
                state.areaEmissionCache.Clear();
                state.hardwareMaterialStatus=string.IsNullOrEmpty(reason)?"Hardware preparation failed; software tracing":reason;
                d.compute=software;d.hardware=false;d.geometry=null;d.softwareLayout=null;
                d.sourceUncertain=sourceUncertain;
            }
            private void ExecuteTransport(Work d,CommandBuffer cmd,bool current)
            {
                var c=d.compute; var state=d.state;
                HybridLumenGIRayTexturePool.BeginFrame(Time.frameCount,Math.Max(1L,s.materialTextureUploadMiBPerFrame)*1024*1024);
                // A failure or newer render may revoke this snapshot after graph construction.
                d.valid &= state.historyLifecycle.CanReuseHistory(d.historyToken);
                // An unsuccessful resolve can leave the imported identity texture
                // unwritten. CPU recording failure must therefore gate reuse too.
                if(d.useIdentity && !d.receiverReceipt.identityRecorded) d.valid=false;
                bool globalSdfPrepared = state.globalSdf.LevelCount > 0;
                if(globalSdfPrepared)
                {
                    using(d.frameTiming.Profile(cmd,"HLGI Global SDF dirty bricks")) state.globalSdf.RecordUpdate(cmd);
                }
                int previousSurfaceChanges = state.surfaceCache.ChangedBounds.Count;
                using(d.frameTiming.Profile(cmd,"HLGI World material capture")) state.surfaceCache.RecordCapture(cmd,d.viewport);
                bool uploadChanges = state.surfaceCache.LimitsCaptureRecording;
                if (uploadChanges)
                {
                    var changedBounds = state.surfaceCache.ChangedBounds;
                    for (int i = previousSurfaceChanges; i < changedBounds.Count; i++)
                        state.changes.Add(changedBounds[i], false, Mathf.Max(1, s.traceDistance));
                    state.lightingChanged |= changedBounds.Count > previousSurfaceChanges;
                }
                // This distribution changes sampling only. Do not mark lighting dirty or reset
                // the cache when rebuilding it; all consumers use the same ordered GPU table.
                bool emissiveBuilt;
                using(d.frameTiming.Profile(cmd,"HLGI Emissive proposals"))
                    emissiveBuilt=state.emissiveSampling.RecordBuild(cmd,state.scene,state.surfaceCache,EffectiveEmissiveBudget);
                if(d.geometry!=null)
                {
                    string reason=null;
                    bool materialsCurrent=d.hitMaterials!=null && d.geometry.GeometryVersion==d.geometryVersion &&
                        d.geometry.TryCaptureHitMaterialSources(state.scene,out var currentSources,out reason) &&
                        d.hitMaterials.MatchesSources(currentSources);
                    if(!materialsCurrent)FallBackToSoftware(d,reason??"Hardware geometry or material sources changed before recording",sourceUncertain:true);
                    else if(!d.geometry.RecordBuild(cmd,out bool deferred))FallBackToSoftware(d,"Exact geometry recording deferred or failed: "+d.geometry.BudgetStatus,sourceUncertain:!deferred);
                    else
                    {
                        int hardwareUpdate=c.FindKernel("CSUpdateCache"),hardwareTrace=c.FindKernel("CSTrace");
                        if(!d.hitMaterials.RecordAndBind(cmd,c,hardwareUpdate,hardwareTrace,out reason,state.camera,
                            s.materialTextureRecordingCpuBudgetMilliseconds))FallBackToSoftware(d,reason,sourceUncertain:true);
                        else
                        {
                            state.hardwareMaterialUnknownRecords=d.hitMaterials.UnknownRecords;
                            state.hardwareMaterialStatus="Uploads and both consumers bound; GPU completion unproven";
                            if(current && AddRecordedShadowMapChanges(d))uploadChanges=true;
                        }
                    }
                    c=d.compute;
                }
                if (uploadChanges) state.changes.RecordUpload(cmd);
                // Newly captured cards and the shadows they receive must be eligible in this frame.
                state.scheduler.Prepare(state.scene,state.surfaceCache,state.patchGrid,d.frame,Mathf.Clamp(d.cachePatchBudget,1,state.cacheEntryCount),
                    state.lightingChanged,Mathf.Max(s.shadowDistance,s.traceDistance)+Mathf.Max(1,s.traceDistance),
                    upload:true,localLightChanges:state.localLightingChangeBounds,changedSurfaces:state.surfaceCache.ChangedBounds,
                    surfaceInfluenceRadius:Mathf.Max(1,s.traceDistance));
                // Compare the representation that will actually trace against the last successful
                // recording. A rejected material allocation can select the same fallback every frame.
                if(!current)
                {
                    d.valid=false;d.epoch=0; // Superseded work cannot publish cache entries in the active epoch.
                }
                else if(d.sourceUncertain || state.lastHardware!=d.hardware || state.exactSoftwareGeometry!=d.ExactSoftware)
                {
                    d.valid=false;
                    // A normal switch can publish this frame's fresh output. A source that
                    // changed before recording also revokes the current receiver/history receipt.
                    if(d.sourceUncertain)state.InvalidateScreenHistory();
                    state.InvalidateWorldHistory();d.epoch=state.epoch;
                    state.InvalidateGpuFeedback();d.frameTiming.Invalidate();
                }
                if(d.validationTicket!=null && !d.validationTicket.IsComplete)d.validationTicket.receipt.epoch=d.epoch;
                int update=c.FindKernel("CSUpdateCache"),trace=c.FindKernel("CSTrace"),
                    temporal=c.FindKernel(d.useIdentity?"CSTemporalIdentity":"CSTemporal"),filter=c.FindKernel("CSFilter");
                if(d.ExactSoftware)
                {
                    state.RecordSoftwareGeometry(cmd,d.geometryVersion,d.softwareLayout,d.softwareNodes,d.softwareLeaves);
                    cmd.SetComputeIntParam(c,"_HLGI_SoftwareBvhNodeCount",d.softwareLayout.NodeCount);
                    cmd.SetComputeIntParam(c,"_HLGI_SoftwareBvhLeafCount",d.softwareLayout.LeafCount);
                }
                bool areaReady=d.geometry!=null && d.areaLayout!=null && d.areaLayout.Count>0;
                state.areaEmitterBytes=areaReady?d.areaLayout.ByteCount:HybridLumenGIAreaEmission.Stride;
                cmd.SetBufferData((GraphicsBuffer)d.areaEmitters,areaReady?d.areaLayout.CopyRecords():new HybridLumenGIAreaEmission.GpuRecord[1]);
                cmd.SetComputeIntParam(c,"_HLGI_AreaEmitterCount",areaReady?d.areaLayout.Count:0);
                cmd.SetComputeIntParam(c,"_HLGI_AreaMaterialGeneration",areaReady?unchecked((int)d.areaLayout.MaterialGeneration):0);
                cmd.SetComputeMatrixParam(c,"_HLGI_VP",d.vp);cmd.SetComputeMatrixParam(c,"_HLGI_InvVP",d.invVP);cmd.SetComputeMatrixParam(c,"_HLGI_View",d.view);
                cmd.SetComputeVectorParam(c,"_HLGI_MaterialView",d.materialView);
                cmd.SetComputeMatrixParam(c,"_HLGI_PreviousVP",d.previousVP);cmd.SetComputeMatrixParam(c,"_HLGI_PreviousInvVP",d.previousInvVP);
                cmd.SetComputeVectorParam(c,"_HLGI_JitterDelta",d.jitterDelta);
                cmd.SetComputeVectorParam(c,"_HLGI_Size",new Vector4(state.width,state.height,1f/state.width,1f/state.height));
                cmd.SetComputeVectorParam(c,"_HLGI_FullSize",new Vector4(d.viewport.width,d.viewport.height,1f/d.viewport.width,1f/d.viewport.height));
                cmd.SetComputeIntParam(c,"_HLGI_ProxyCount",state.scene.Capacity);cmd.SetComputeIntParam(c,"_HLGI_LightCount",d.lightCount);
                cmd.SetComputeIntParam(c,"_HLGI_NonAnalyticOnlyChannels",d.nonAnalyticOnlyChannels);
                Vector4 dimScale=Vector4.one;
                int refreshChannels=0;
                if(current && d.epoch==state.epoch && state.recordedLightEpoch==d.epoch &&
                    state.lightChanges.Count>0)
                {
                    if(d.lightCount==state.recordedLightCount)
                    {
                        for(int channel=0;channel<3;channel++)
                        {
                            dimScale[channel]=PointLightChannelDimScale(state.recordedLightData,state.lightData,d.lightCount,channel,
                                out bool refresh);
                            if(refresh)refreshChannels|=1<<channel;
                        }
                    }
                    else if(d.lightCount>0 && d.lightCount<state.recordedLightCount)
                        refreshChannels=RemovedPointLightRefreshChannels(state.recordedLightData,state.recordedLightCount,
                            state.lightData,d.lightCount)&~d.nonAnalyticOnlyChannels;
                }
                cmd.SetComputeVectorParam(c,"_HLGI_PointLightDimScale",dimScale);
                cmd.SetComputeIntParam(c,"_HLGI_PointLightRefreshChannels",refreshChannels);
                cmd.SetComputeIntParam(c,"_HLGI_Epoch",d.epoch);cmd.SetComputeIntParam(c,"_HLGI_FrameIndex",d.frame);
                cmd.SetComputeIntParam(c,"_HLGI_CacheGrid",state.patchGrid);
                cmd.SetComputeFloatParam(c,"_HLGI_GuideWeight",Mathf.Clamp(s.guidedSamplingWeight,0,0.8f));
                cmd.SetComputeFloatParam(c,"_HLGI_EmissiveWeight",emissiveBuilt?Mathf.Clamp(s.emissiveSamplingWeight,0,0.8f):0);
                cmd.SetComputeFloatParam(c,"_HLGI_DetailTraceDistance",Mathf.Max(1,s.nearDistance));
                cmd.SetComputeIntParam(c,"_HLGI_GlobalSdfEnabled",globalSdfPrepared?1:0);
                cmd.SetComputeIntParam(c,"_HLGI_NativeComposition",s.composition==CompositionMode.ReplaceNativeDiffuseGI?1:0);
                cmd.SetComputeIntParam(c,"_HLGI_CacheRays",Mathf.Clamp(s.cacheRaysPerFace,1,32));
                cmd.SetComputeIntParam(c,"_HLGI_Rays",Mathf.Clamp(s.raysPerPixel,1,8));cmd.SetComputeIntParam(c,"_HLGI_ScreenSteps",Mathf.Clamp(s.screenSteps,0,64));
                cmd.SetComputeIntParam(c,"_HLGI_HistoryValid",d.valid?1:0);cmd.SetComputeIntParam(c,"_HLGI_HasMotion",d.hasMotion?1:0);
                cmd.SetComputeIntParam(c,"_HLGI_NormalsOct",s.normalsOctEncoded?1:0);cmd.SetComputeIntParam(c,"_HLGI_MaxHistory",Mathf.Clamp(s.maxHistory,1,64));
                cmd.SetComputeFloatParam(c,"_HLGI_MaxDistance",Mathf.Max(1,s.traceDistance));cmd.SetComputeFloatParam(c,"_HLGI_RayBias",Mathf.Max(0.001f,s.rayBias));
                cmd.SetComputeFloatParam(c,"_HLGI_ShadowDistance",Mathf.Max(1,s.shadowDistance));
                cmd.SetComputeFloatParam(c,"_HLGI_Thickness",Mathf.Max(0.001f,s.screenThickness));cmd.SetComputeFloatParam(c,"_HLGI_BounceFeedback",Mathf.Clamp01(s.bounceFeedback));
                cmd.SetComputeFloatParam(c,"_HLGI_DepthThreshold",s.relativeDepthThreshold);cmd.SetComputeFloatParam(c,"_HLGI_NormalThreshold",s.normalThreshold);
                cmd.SetComputeFloatParam(c,"_HLGI_CurrentWeight",s.temporalAccumulation?s.temporalCurrentWeight:1);cmd.SetComputeFloatParam(c,"_HLGI_RadianceClamp",s.radianceClamp);
                cmd.SetComputeVectorParam(c,"_HLGI_Environment",s.environmentRadiance.linear);
                Cubemap environment=s.environmentCubemap;
                bool useEnvironmentCube=IsSupportedEnvironmentCubemap(environment);
                if(environment!=null && !useEnvironmentCube)
                {
                    if(rejectedEnvironment!=environment)
                        Debug.LogWarning("[HybridLumenGI] Environment Cubemap requires unencoded linear RGBAHalf/RGBAFloat radiance. Using the constant environment instead.");
                    rejectedEnvironment=environment;
                }
                else rejectedEnvironment=null;
                cmd.SetComputeIntParam(c,"_HLGI_EnvironmentCubeEnabled",useEnvironmentCube?1:0);
                Cubemap environmentTexture=useEnvironmentCube?environment:CoreUtils.blackCubeTexture;
                foreach(int k in new[]{update,trace})
                {
                    cmd.SetComputeTextureParam(c,k,"_HLGI_EnvironmentCube",environmentTexture);
                    cmd.SetComputeBufferParam(c,k,"_HLGI_Proxies",state.scene.Buffer);cmd.SetComputeBufferParam(c,k,"_HLGI_Lights",state.lights);
                    cmd.SetComputeBufferParam(c,k,"_HLGI_LightingPolicies",state.scene.LightingPolicyBuffer);
                    cmd.SetComputeBufferParam(c,k,"_HLGI_CacheRead",state.cache[d.cacheRead]);state.sdf.Bind(cmd,c,k);state.scene.Bvh.Bind(cmd,c,k);
                    state.surfaceCache.BindCompute(cmd,c,k);state.changes.Bind(cmd,c,k);
                    state.emissiveSampling.Bind(cmd,c,k);
                    cmd.SetComputeBufferParam(c,k,"_HLGI_AreaEmitters",(GraphicsBuffer)d.areaEmitters);
                    state.globalSdf.Bind(cmd,c,k);
                    if(d.geometry!=null)d.geometry.Bind(cmd,c,k);
                    if(d.ExactSoftware)
                    {
                        cmd.SetComputeBufferParam(c,k,"_HLGI_SoftwareTriangleNodes",(GraphicsBuffer)d.softwareNodes);
                        cmd.SetComputeBufferParam(c,k,"_HLGI_SoftwareTriangleLeaves",(GraphicsBuffer)d.softwareLeaves);
                    }
                }
                using(d.frameTiming.Profile(cmd,"HLGI World cache"))
                {
                    cmd.SetComputeBufferParam(c,update,"_HLGI_CacheWrite",state.cache[1-d.cacheRead]);
                    cmd.SetComputeBufferParam(c,update,"_HLGI_CacheUpdateMask",state.scheduler.UpdateMask);
                    cmd.DispatchCompute(c,update,(state.cacheEntryCount+63)/64,1,1);
                }
                // Gather from completed current cache, while cache iteration itself read only last frame.
                cmd.SetComputeBufferParam(c,trace,"_HLGI_CacheRead",state.cache[1-d.cacheRead]);
                SetTexture(cmd,c,trace,"_HLGI_Depth",d.depth);SetTexture(cmd,c,trace,"_HLGI_Normals",d.normals);
                SetTexture(cmd,c,trace,"_HLGI_CaptureDepth",d.captureDepth);
                SetTexture(cmd,c,trace,"_HLGI_Diffuse",d.diffuse);SetTexture(cmd,c,trace,"_HLGI_Emission",d.emission);
                SetTexture(cmd,c,trace,"_HLGI_ReceiverPolicy",d.receiverPolicy);
                cmd.SetComputeIntParam(c,"_HLGI_ScreenStaticShadowmask",d.staticShadowmask?1:0);
                SetTexture(cmd,c,trace,"_HLGI_Output",d.raw);SetTexture(cmd,c,trace,"_HLGI_GeometryOut",d.geometryWrite);SetTexture(cmd,c,trace,"_HLGI_MaterialOut",d.materialWrite);
                using(d.frameTiming.Profile(cmd,"HLGI Gather")) Dispatch(cmd,c,trace,state);
                SetTexture(cmd,c,temporal,"_HLGI_Input",d.raw);SetTexture(cmd,c,temporal,"_HLGI_Geometry",d.geometryWrite);SetTexture(cmd,c,temporal,"_HLGI_Material",d.materialWrite);
                SetTexture(cmd,c,temporal,"_HLGI_Motion",d.motion);SetTexture(cmd,c,temporal,"_HLGI_History",d.historyRead);
                SetTexture(cmd,c,temporal,"_HLGI_PreviousGeometry",d.geometryRead);SetTexture(cmd,c,temporal,"_HLGI_PreviousMaterial",d.materialRead);SetTexture(cmd,c,temporal,"_HLGI_PreviousMoments",d.momentsRead);
                SetTexture(cmd,c,temporal,"_HLGI_Output",d.historyWrite);SetTexture(cmd,c,temporal,"_HLGI_MomentsOut",d.momentsWrite);
                if(d.useIdentity)
                {
                    SetTexture(cmd,c,temporal,"_HLGI_IdentityCurrent",d.identityWrite);SetTexture(cmd,c,temporal,"_HLGI_IdentityPrevious",d.identityRead);
                    cmd.SetComputeBufferParam(c,temporal,"_HLGI_IdentityCandidates",(GraphicsBuffer)d.identity.Candidates);
                    cmd.SetComputeBufferParam(c,temporal,"_HLGI_IdentityObjects",(GraphicsBuffer)d.identity.Objects);
                    cmd.SetComputeIntParam(c,"_HLGI_IdentityObjectCount",d.identity.ObjectCount);
                }
                state.changes.Bind(cmd,c,temporal);
                using(d.frameTiming.Profile(cmd,"HLGI Temporal")) Dispatch(cmd,c,temporal,state);
                SetTexture(cmd,c,filter,"_HLGI_Geometry",d.geometryWrite);SetTexture(cmd,c,filter,"_HLGI_Material",d.materialWrite);SetTexture(cmd,c,filter,"_HLGI_Moments",d.momentsWrite);
                using(d.frameTiming.Profile(cmd,"HLGI Atrous"))
                {
                    for(int i=0;i<d.filterIterations;i++)
                    {
                        SetTexture(cmd,c,filter,"_HLGI_Input",i==0?d.historyWrite:(i%2==1?d.tempA:d.tempB));
                        SetTexture(cmd,c,filter,"_HLGI_Output",i%2==0?d.tempA:d.tempB);cmd.SetComputeIntParam(c,"_HLGI_FilterStep",1<<i);Dispatch(cmd,c,filter,state);
                    }
                }
                if(current)state.readiness.Record(cmd,state.scene,state.sdf,state.surfaceCache,state.cache[1-d.cacheRead],state.patchGrid,d.epoch,d.frame,state.scheduler);
            }
            private static void SetTexture(CommandBuffer cmd,ComputeShader c,int kernel,string name,TextureHandle handle)
            { RTHandle rt=handle;cmd.SetComputeTextureParam(c,kernel,name,rt.nameID); }
            private static void Dispatch(CommandBuffer cmd,ComputeShader c,int k,CameraState state)
            { cmd.DispatchCompute(c,k,(state.width+7)/8,(state.height+7)/8,1); }
            private static int RemovedPointLightRefreshChannels(HybridLumenGILights.Data[] recorded,int recordedCount,
                HybridLumenGILights.Data[] prepared,int preparedCount)
            {
                // Selection preserves InstanceID order. Match the whole surviving
                // row, including its color and shadow policy, across compaction.
                int next=0, channels=0;
                for(int i=0;i<recordedCount;i++)
                {
                    var before=recorded[i];
                    if(next<preparedCount && before.Equals(prepared[next]))
                    {
                        next++;
                        continue;
                    }
                    if(before.positionType.w!=1 || before.spot.w!=0) return 0;
                    for(int channel=0;channel<3;channel++)
                        if(before.color[channel]>0)channels|=1<<channel;
                }
                return next==preparedCount?channels:0;
            }
            private static float PointLightChannelDimScale(HybridLumenGILights.Data[] recorded,
                HybridLumenGILights.Data[] prepared,int count,int channel,out bool refresh)
            {
                refresh=false;
                // A common ratio scales the sum. Mixed ratios require a fresh estimate,
                // including a light losing this channel while other lights still supply it.
                float scale=1;
                bool hasContributor=false, mixedRatios=false;
                for(int i=0;i<count;i++)
                {
                    var before=recorded[i];var after=prepared[i];
                    float oldValue=before.color[channel],newValue=after.color[channel];
                    if(oldValue==0 && newValue==0) continue;
                    if(oldValue<=0 || newValue<0 || newValue>oldValue || before.positionType.w!=1 || before.spot.w!=0 ||
                        !before.positionType.Equals(after.positionType) || !before.directionRange.Equals(after.directionRange) ||
                        !before.spot.Equals(after.spot) || before.cullingMask!=after.cullingMask ||
                        before.renderingLayers!=after.renderingLayers || before.shadowRenderingLayers!=after.shadowRenderingLayers ||
                        before.flags!=after.flags) return 1;
                    if(!hasContributor)
                    {
                        scale=newValue/oldValue;
                        hasContributor=true;
                    }
                    else if(oldValue*scale!=newValue) mixedRatios=true;
                }
                refresh=mixedRatios;
                return mixedRatios || scale<=0 ? 1 : scale;
            }
            private int UpdateLights(CameraState state,bool useRenderingLayers,UniversalCameraData cameraData,Matrix4x4 view,Matrix4x4 invVP,
                Light mainLight,bool additionalRealtimeShadows,out int nonAnalyticOnlyChannels)
            {
                state.lightDomain=default;state.lightDomainReason="Disabled";
                if(s.spatialLightSelection) TryLightDomain(state,cameraData,view,invVP,out state.lightDomain,out state.lightDomainReason);
                state.localLightingChangeBounds.Clear();
                int count=worldLights.Update(Time.frameCount,useRenderingLayers,state.lightData,Mathf.Clamp(s.maxLights,1,32),
                    state.previousLightCount,state.lightChanges,out int hash,s.spatialLightSelection,state.lightDomain,out state.lightSelection,
                    mainLight,additionalRealtimeShadows);
                state.lightingChanged=state.lightChanges.Count>0;
                foreach(var changed in state.lightChanges) AddLightChange(state,changed);
                state.previousLightCount=count;state.lastLightHash=hash;
                // A channel with no analytic source has only emission/environment transport.
                nonAnalyticOnlyChannels=7;
                for(int i=0;i<count && nonAnalyticOnlyChannels!=0;i++)
                {
                    Vector4 color=state.lightData[i].color;
                    if(color.x!=0) nonAnalyticOnlyChannels&=~1;
                    if(color.y!=0) nonAnalyticOnlyChannels&=~2;
                    if(color.z!=0) nonAnalyticOnlyChannels&=~4;
                }
                if(count>0) state.lights.SetData(state.lightData,0,0,count);
                return count;
            }
            private static bool TryLightDomain(CameraState state,UniversalCameraData data,Matrix4x4 view,Matrix4x4 invVP,
                out HybridLumenGILightRelevance.Domain domain,out string reason)
            {
                domain=default;reason="Unsupported camera projection/view";
                Camera camera=data.camera;
                float near=camera.nearClipPlane,far=camera.farClipPlane,aspect=camera.aspect;
                if(SystemInfo.graphicsDeviceType!=GraphicsDeviceType.Direct3D12 || camera.stereoEnabled || camera.usePhysicalProperties ||
                    camera.lensShift!=Vector2.zero || camera.rect!=new Rect(0,0,1,1) ||
                    !Finite(near) || !Finite(far) || !Finite(aspect) || !(near>0 && far>near && aspect>0)) return false;
                Matrix4x4 expected;
                if(camera.orthographic)
                {
                    float height=camera.orthographicSize;
                    if(!Finite(height) || height<=0 || !Finite(height*aspect)) return false;
                    expected=Matrix4x4.Ortho(-height*aspect,height*aspect,-height,height,near,far);
                }
                else
                {
                    float fov=camera.fieldOfView;
                    if(!Finite(fov) || fov<=0 || fov>=180) return false;
                    expected=Matrix4x4.Perspective(fov,aspect,near,far);
                }
                Matrix4x4 expectedView=Matrix4x4.Scale(new Vector3(1,1,-1))*camera.transform.worldToLocalMatrix;
                if(!HybridLumenGILightRelevance.StandardMatrixMatches(camera.projectionMatrix,expected) ||
                    !HybridLumenGILightRelevance.StandardMatrixMatches(view,expectedView)) return false;
                reason="Screen homogeneous interval is unknown";
                if(!HybridLumenGILightRelevance.TryScreenDomain(invVP,out var combined)) return false;
                for(int slot=0;slot<state.scene.Capacity;slot++)
                {
                    if(!state.scene.IsPublished(slot) && !state.scene.IsWarming(slot)) continue;
                    reason="Prepared world traversal bounds are unknown";
                    if(!state.scene.TryGetPreparedTraversalBounds(slot,out Bounds bounds) ||
                        !combined.TryInclude(bounds.min,bounds.max,out combined)) return false;
                    // DrawMesh warming captures may outgrow stale Renderer.bounds.
                    // Include the already-prepared capture extent, not just BVH bounds.
                    if(state.surfaceCache.GetCardCount(slot)>0)
                    {
                        reason="Prepared surface capture bounds are unknown";
                        if(!state.surfaceCache.TryGetPreparedCaptureBounds(slot,out Bounds captureBounds) ||
                            !combined.TryInclude(captureBounds.min,captureBounds.max,out combined)) return false;
                    }
                }
                domain=combined;reason="Finite screen and prepared traversal/capture domain";return true;
            }
            private static bool Finite(float value)=>!float.IsNaN(value)&&!float.IsInfinity(value);
            private void AddLightChange(CameraState state,HybridLumenGILights.Data light)
            {
                if(light.positionType.w<0.5f) state.changes.MarkGlobalLightingChange();
                else
                {
                    var bounds=new Bounds((Vector3)light.positionType,Vector3.one*Mathf.Max(0,light.directionRange.w)*2);
                    AddLocalLightingChange(state, bounds, Mathf.Max(1, s.traceDistance));
                }
            }
            private float ShadowReach(HybridLumenGILights.Data light) => light.spot.z > 0
                ? (light.positionType.w < .5f ? Mathf.Max(1, s.shadowDistance) : light.directionRange.w) : 0;

            private static uint EffectiveShadowMode(HybridLumenGIScene.LightingPolicyData policy, HybridLumenGILights.Data light)
            {
                if (policy.shadowCastingMode == 0 || (policy.objectLayerBit & light.cullingMask) == 0 ||
                    ((light.flags & 1u) != 0 && (policy.renderingLayerMask & light.shadowRenderingLayers) == 0)) return 0;
                return policy.shadowCastingMode == (uint)ShadowCastingMode.TwoSided ? 2u : 1u;
            }

            private float CasterShadowReach(CameraState state, int lightCount, HybridLumenGIScene.LightingPolicyData policy)
            {
                float reach = 0;
                for (int i = 0; i < lightCount; i++)
                {
                    var light = state.lightData[i];
                    if (EffectiveShadowMode(policy, light) != 0)
                        reach = Mathf.Max(reach, ShadowReach(light));
                }
                return reach;
            }

            private void AddSdfShadowChanges(Work work)
            {
                var state = work.state;
                float traceReach = Mathf.Max(1, s.traceDistance);
                foreach (var change in state.sdf.PublishedGeometryChanges)
                {
                    if (work.geometry != null && work.geometry.HasPreparedTriangles(change.Slot)) continue;
                    float reach = CasterShadowReach(state, work.lightCount, state.scene.LightingPolicies[change.Slot]);
                    if (reach <= 0) continue;
                    AddLocalLightingChange(state, change.PreviousBounds, reach + traceReach);
                    if (!change.CurrentBounds.Equals(change.PreviousBounds))
                        AddLocalLightingChange(state, change.CurrentBounds, reach + traceReach);
                }
            }

            private void AddShadowCasterChanges(CameraState state, int lightCount)
            {
                const HybridLumenGIScene.ChangeKind geometry = HybridLumenGIScene.ChangeKind.Added | HybridLumenGIScene.ChangeKind.Removed |
                    HybridLumenGIScene.ChangeKind.Transform | HybridLumenGIScene.ChangeKind.Topology;
                float baselineReach = Mathf.Max(s.shadowDistance, s.traceDistance);
                float traceReach = Mathf.Max(1, s.traceDistance);
                foreach (var change in state.scene.DirtyRegions)
                {
                    bool geometryChanged = (change.Kind & geometry) != 0;
                    // A manual revision can clear the old caster before its replacement earns an upload.
                    // The recorded current bounds are only a candidate until the scene publishes it.
                    bool deferredWithdrawal = !geometryChanged && change.HasPrevious &&
                        (change.Kind & HybridLumenGIScene.ChangeKind.Manual) != 0 &&
                        !state.scene.TryGetPublishedSlot(change.StableId, out _);
                    if (!geometryChanged && !deferredWithdrawal && (change.Kind & HybridLumenGIScene.ChangeKind.Lighting) == 0) continue;
                    bool hasCurrent = change.HasCurrent && !deferredWithdrawal;
                    float previousReach = baselineReach, currentReach = baselineReach;
                    for (int i = 0; i < lightCount; i++)
                    {
                        var light = state.lightData[i];
                        float reach = ShadowReach(light);
                        if (reach <= previousReach && reach <= currentReach) continue;
                        uint previous = change.HasPrevious ? EffectiveShadowMode(change.PreviousLighting, light) : 0;
                        uint current = hasCurrent ? EffectiveShadowMode(change.CurrentLighting, light) : 0;
                        if (!geometryChanged && previous == current) continue;
                        if (previous != 0) previousReach = Mathf.Max(previousReach, reach);
                        if (current != 0) currentReach = Mathf.Max(currentReach, reach);
                    }
                    if (change.HasPrevious && hasCurrent && change.CurrentBounds.Equals(change.PreviousBounds))
                    {
                        previousReach = Mathf.Max(previousReach, currentReach);
                        currentReach = baselineReach;
                    }
                    if (previousReach > baselineReach) AddLocalLightingChange(state, change.PreviousBounds, previousReach + traceReach);
                    if (currentReach > baselineReach) AddLocalLightingChange(state, change.CurrentBounds, currentReach + traceReach);
                }
            }

            private static void AddLocalLightingChange(CameraState state, Bounds bounds, float influence)
            {
                state.changes.Add(bounds, false, influence);
                // This conservative expansion affects priority, never eligibility.
                bounds.Expand(influence * 2);
                state.localLightingChangeBounds.Add(bounds);
            }
            private bool TryGetPreparedCamera(Camera camera, out CameraState state)
            {
                state = null;
                return !admissionStopped && !HybridLumenGIResourceRetirement.AdmissionClosed && camera != null &&
                    cameras.TryGetValue(camera.GetInstanceID(), out state) && ReferenceEquals(state.camera, camera) &&
                    state.scenePreparedEngineFrame >= 0;
            }
            internal bool TryGetPublication(Camera camera, HybridLumenGIProxy proxy, out HybridLumenGIScene.PublicationSnapshot value)
            {
                value = new HybridLumenGIScene.PublicationSnapshot { preparedEngineFrame = -1, preparedWorkFrame = -1 };
                if (!TryGetPreparedCamera(camera, out var state)) return false;
                bool known = state.scene.TryGetPublication(proxy, out value);
                value.preparedEngineFrame = state.scenePreparedEngineFrame; value.preparedWorkFrame = state.scenePreparedWorkFrame;
                return known;
            }
            internal bool TryGetHlodPublication(Camera camera, HybridLumenGIProxy root, List<HybridLumenGIProxy> published,
                List<HybridLumenGIProxy> target, out HybridLumenGIScene.HlodPublicationSnapshot value)
            {
                value = new HybridLumenGIScene.HlodPublicationSnapshot { preparedEngineFrame = -1, preparedWorkFrame = -1 };
                if (!TryGetPreparedCamera(camera, out var state)) return false;
                bool known = state.scene.TryGetHlodPublication(root, published, target, out value);
                value.preparedEngineFrame = state.scenePreparedEngineFrame; value.preparedWorkFrame = state.scenePreparedWorkFrame;
                return known;
            }
            internal void CollectHlodRaster(Camera camera, List<HybridLumenGIStreamedRepresentation> visible)
            {
                if (!TryGetPreparedCamera(camera, out var state)) return;
                float farDistance = Mathf.Max(Mathf.Max(0.1f, s.nearDistance), s.farDistance);
                state.scene.CollectHlodRaster(camera.transform.position, farDistance, visible);
            }
            internal void ResetCameraHistory(Camera camera)
            {
                if (camera != null && cameras.TryGetValue(camera.GetInstanceID(), out var state) && ReferenceEquals(state.camera, camera))
                    state.InvalidateScreenHistory();
            }
            private CameraState GetCameraState(Camera camera)
            {
                RetireCameraStates(includeReassigned: false);
                int id=camera.GetInstanceID();Evict(id);
                if(cameras.TryGetValue(id,out var state) && !ReferenceEquals(state.camera,camera))
                {
                    state.Dispose();cameras.Remove(id);state=null;
                }
                if(state==null)
                {
                    var allocations = validationOwner.cameraGeometry.GetValue(camera, static _ => new CameraGeometryAllocations());
                    state = new CameraState(camera, allocations);
                    cameras.Add(id, state);
                }
                return state;
            }
            private void RetireIdleCameraStates() => RetireCameraStates(includeReassigned: true);
            private void RetireCameraStates(bool includeReassigned)
            {
                retire.Clear();
                foreach (var entry in cameras)
                    if (entry.Value.camera == null || (includeReassigned && IsReassignedCamera(entry.Value)))
                        retire.Add(entry.Key);
                foreach (int id in retire)
                {
                    var state = cameras[id];
                    cameras.Remove(id);
                    // Recorded work may still read the detached state's textures and buffers.
                    HybridLumenGIResourceRetirement.Retire(state.Dispose);
                }
            }
            private void Evict(int current)
            {
                retire.Clear();
                foreach(var entry in cameras) if(entry.Key!=current && Time.frameCount-entry.Value.lastUsed>120) retire.Add(entry.Key);
                foreach(int key in retire) { cameras[key].Dispose();cameras.Remove(key); }
                if(!cameras.ContainsKey(current) && cameras.Count>=Mathf.Clamp(s.maxCameras,1,4))
                {
                    int oldest=0,frame=int.MaxValue;
                    foreach(var entry in cameras) if(entry.Value.lastUsed<frame) { oldest=entry.Key;frame=entry.Value.lastUsed; }
                    cameras[oldest].Dispose();cameras.Remove(oldest);
                }
            }
            internal CameraDiagnostics[] GetDiagnostics()
            {
                var values=new CameraDiagnostics[cameras.Count];int i=0;
                foreach(var state in cameras.Values) values[i++]=DescribeCamera(state);
                return values;
            }
            internal CameraDiagnostics GetCameraDiagnostics(Camera camera)
            {
                return camera!=null && cameras.TryGetValue(camera.GetInstanceID(),out var state) && ReferenceEquals(state.camera,camera)
                    ? DescribeCamera(state) : null;
            }
            private CameraDiagnostics DescribeCamera(CameraState c)
            {
                return new CameraDiagnostics
                    {
                        camera=c.camera!=null?c.camera.name:"destroyed",frame=c.frame,
                        recordedTransportBackend=c.recordedTransportBackend,transportRecordedEngineFrame=c.transportRecordedEngineFrame,
                        transportRecordedWorkFrame=c.transportRecordedWorkFrame,
                        transportMatchesBackendRequest=c.transportRecordedEngineFrame>=0 && c.recordedBackendRequest==backendRequest &&
                            c.recordedHardwarePreference==s.preferHardwareTracing,
                        sceneLightingPolicyBytes=(long)c.scene.Capacity*HybridLumenGIScene.LightingPolicyStride,
                        publishedInstances=c.scene.PublishedCount,warmingInstances=c.scene.WarmingCount,pendingCapacity=c.scene.PendingCapacity,bvhNodes=c.scene.Bvh.NodeCount,
                        readyCards=c.surfaceCache.ReadyCards,pendingCards=c.surfaceCache.PendingCards,warmupBudgetBlockedCards=c.surfaceCache.WarmupBudgetBlockedCards,
                        chartedOwners=c.surfaceCache.ChartedOwners,approximateOwners=c.surfaceCache.ApproximateOwners,requiredSurfaceCards=c.surfaceCache.RequiredCards,
                        rejectedSdfSources=c.sdf.RejectedSourceCount,
                        receiverTrackedSubmeshes=c.receiverTrackedSubmeshes,receiverUntrackedRenderers=c.receiverUntrackedRenderers,
                        receiverFingerprintMeshes=c.receiverFingerprintMeshes,receiverFingerprintBytes=c.receiverFingerprintBytes,
                        receiverSourcesPublished=c.receiverHistory.IsPublished,
                        receiverIdentityEnabled=c.receiverIdentityEnabled,receiverIdentityStatus=c.receiverIdentityStatus,
                        receiverIdentityDraws=c.receiverIdentityDraws,receiverUnknownRectangles=c.receiverUnknownRectangles,
                        receiverIdentityBufferBytes=c.receiverIdentityBufferBytes,
                        changeRegionBytes=c.changes.AllocatedBytes,
                        lightCandidates=c.lightSelection.ValidCandidates,lightOutsideDomain=c.lightSelection.OutsideDomain,
                        lightSelected=c.lightSelection.Selected,lightCapacityOmitted=c.lightSelection.CapacityOmitted,
                        lightDomainValid=c.lightSelection.DomainValid,
                        lightSelectionStatus=c.lightSelection.Status+"; "+c.lightDomainReason,
                        proposalCapacity=HybridLumenGIEmissiveSampling.ProposalCapacity,proposalBudget=EffectiveEmissiveBudget,
                        cachePatchesScheduled=c.scheduler.SelectedCount,globalReadyBricks=c.globalSdf.ReadyBrickCount,globalPendingBricks=c.globalSdf.PendingBrickCount,globalUpdatedBricks=c.globalSdf.UpdatedBrickCount,
                        completedHlodReadbacks=c.readiness.CompletedReadbacks,failedHlodReadbacks=c.readiness.FailedReadbacks,acceptedInitializationTickets=c.readiness.AcceptedTickets,hlodReadbackPending=c.readiness.Pending,
                        lastHlodCoverageBlock=c.readiness.LastCoverageBlock,
                        hardwareBackend=c.lastHardware,hardwareMeshes=c.hardware.MeshCount,hardwareFallbacks=c.hardware.FallbackCount,
                        hardwareSceneRebuilds=c.hardware.SceneRebuildCount,hardwareTransformUpdates=c.hardware.TransformUpdateCount,hardwareTriangleUploads=c.hardware.TriangleUploadCount,
                        hardwareBindingUploads=c.hardware.BindingUploadCount,surfaceTriangleMappingCpuBytes=c.surfaceCache.TriangleMappingBytes,
                        hardwareMaterialStatus=c.hardwareMaterialStatus,hardwareMaterialUnknownRecords=c.hardwareMaterialUnknownRecords,
                        hardwareMaterialFrameBytes=c.hardwareMaterialFrameBytes,hardwareMaterialGlobalAllocatedBytes=HybridLumenGIHitMaterialBatch.TotalAllocatedBytes,
                        exactSoftwareGeometry=c.exactSoftwareGeometry,softwareGeometryBytes=c.SoftwareResidentBytes,areaEmitterBytes=c.areaEmitterBytes,
                        rtasGlobalAccountedBytes=HybridLumenGIRtasBudget.AccountedBytes,rtasGlobalEstimatedBytes=HybridLumenGIRtasBudget.EstimatedBytes,
                        rtasGlobalMeasuredHighWaterBytes=HybridLumenGIRtasBudget.MeasuredHighWaterBytes,rtasGlobalRetiredBytes=HybridLumenGIRtasBudget.RetiredBytes,
                        rtasPendingDemands=HybridLumenGIRtasBudget.PendingDemands,rtasBuildsThisFrame=HybridLumenGIRtasBudget.BuildsThisFrame,
                        rtasTriangleWorkThisFrame=HybridLumenGIRtasBudget.TriangleWorkThisFrame,rtasInstanceWorkThisFrame=HybridLumenGIRtasBudget.InstanceWorkThisFrame,
                        rtasBudgetStatus=c.hardware.BudgetStatus.ToString(),
                        materialUploadEngineFrame=HybridLumenGIRayTexturePool.UploadFrame,
                        materialUploadBudgetBytes=HybridLumenGIRayTexturePool.UploadBudgetBytes,materialUploadBytesUsed=HybridLumenGIRayTexturePool.UploadBytesUsed,
                        screenTextureEstimateBytes=(long)c.fullWidth*c.fullHeight*c.fullPixelBytes+(long)c.width*c.height*c.lowPixelBytes,
                        worldMaterialBytes=c.surfaceCache.AllocatedBytes,objectSdfBytes=c.sdf.AllocatedBytes,globalSdfBytes=c.globalSdf.AllocatedBytes,
                        worldCacheBytes=(long)c.cacheEntryCount*CacheEntryStride*2,hardwareAttributeBytes=c.hardware.AttributeBytes,proposalBufferBytes=c.emissiveSampling.AllocatedBytes,
                        gpuTimingStatus=c.useNativeGpuTiming?c.nativeGpuTiming.Status.ToString():c.gpuTiming.Status.ToString(),gpuObservationValid=c.gpuObservationValid,gpuFeedbackActive=c.gpuBudget.FeedbackActive,
                        gpuTimingProvider=c.useNativeGpuTiming?"NativeDX12":"Recorder",nativeGpuTimingStatus=c.nativeGpuTiming.Status.ToString(),
                        gpuTimingRequiresIdentity=c.receiverIdentityEnabled,
                        nativeGpuPendingSubmissions=c.nativeGpuTiming.PendingCount,nativeGpuMeasuredSourceFrame=c.nativeGpuTiming.LastMeasuredSourceFrame,
                        gpuStableCompletedFrames=c.gpuTiming.StableCompletedFrames,gpuLastObservationConsumedFrame=c.gpuLastObservationFrame,
                        gpuLastObservedMilliseconds=c.gpuLastObservedMilliseconds,gpuSmoothedMilliseconds=c.gpuBudget.SmoothedMs,
                        gpuWorkScale=c.effectiveBudget.Scale,gpuMinimumWorkOverBudget=c.gpuBudget.MinimumWorkOverBudget,
                        effectiveCachePatchBudget=c.effectiveBudget.CachePatches,effectiveSurfaceCaptureBudget=c.effectiveBudget.SurfaceCaptures,
                        effectiveGlobalBrickBudget=c.effectiveBudget.GlobalBricks,gpuAcceptedObservations=(long)Math.Min(c.gpuBudget.AcceptedSamples,(ulong)long.MaxValue),
                        gpuRejectedObservations=(long)Math.Min(c.gpuBudget.RejectedSamples,(ulong)long.MaxValue)
                    };
            }
            public void Dispose()
            {
                HybridLumenGIResourceRetirement.Unregister(RequiresRepresentation);
                StopAdmission();
                foreach(var materialPass in materialPasses)materialPass.Dispose();materialPasses.Clear();
                HybridLumenGIHitMaterialPass.PollRetired();
                foreach(var state in cameras.Values)state.Dispose();cameras.Clear();receiverIdentityPass.Dispose();
            }
        }
    }
}
