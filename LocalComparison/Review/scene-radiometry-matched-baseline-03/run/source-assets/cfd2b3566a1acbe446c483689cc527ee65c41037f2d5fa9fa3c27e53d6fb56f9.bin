using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;

namespace HybridLumenGI
{
    /// <summary>
    /// Explicit identity-only draws; the ordinary Lit renderer list remains owned by the caller.
    /// Buffer/texture lifetimes belong to RenderGraph. Fences below retain only private material
    /// and property blocks, and do not constitute a successful camera-history receipt.
    /// Main-thread recording/collection only. Unity/DX12 execution still requires target validation.
    /// </summary>
    public sealed class HybridLumenGIReceiverIdentityPass : IDisposable
    {
        public const int CandidateStride = 12;
        public const int MaxPendingFrames = 32;
        public const int MaxMaterialOwners = 16;
        private const string ShaderName = "Hidden/HybridLumenGI/ReceiverIdentity";
        private const string ComputePath = "HybridLumenGI/HybridLumenGIReceiverIdentity";
        private static readonly int CandidatesId = Shader.PropertyToID("_HLGI_IdentityCandidates");
        private static readonly int ObjectsId = Shader.PropertyToID("_HLGI_IdentityObjects");
        private static readonly int OutputId = Shader.PropertyToID("_HLGI_IdentityOutput");
        private static readonly int FullSizeId = Shader.PropertyToID("_HLGI_IdentityFullSize");
        private static readonly int GiSizeId = Shader.PropertyToID("_HLGI_IdentityGiSize");
        private static readonly int ObjectCountId = Shader.PropertyToID("_HLGI_IdentityObjectCount");
        private static readonly int UnknownRectId = Shader.PropertyToID("_HLGI_IdentityUnknownRect");
        private static readonly int CameraDepthId = Shader.PropertyToID("_HLGI_IdentityCameraDepth");
        private static readonly int CaptureDepthId = Shader.PropertyToID("_HLGI_IdentityCaptureDepth");
        private static readonly int OwnerId = Shader.PropertyToID("_HLGI_IdentityOwnerIndexPlusOne");
        private static readonly int ObjectMatrixId = Shader.PropertyToID("_HLGI_IdentityObjectToWorld");
        private static readonly int ViewProjectionId = Shader.PropertyToID("_HLGI_IdentityViewProjection");
        private static readonly int BaseMapId = Shader.PropertyToID("_HLGI_IdentityBaseMap");
        private static readonly int BaseMapStId = Shader.PropertyToID("_HLGI_IdentityBaseMapST");
        private static readonly int AlphaId = Shader.PropertyToID("_HLGI_IdentityAlphaParams");
        private static readonly int HasBaseMapId = Shader.PropertyToID("_HLGI_IdentityHasBaseMap");
        private static readonly List<MaterialOwner> Owners = new List<MaterialOwner>(MaxMaterialOwners);
        private static bool collectionRegistered;

        private sealed class MaterialOwner
        {
            internal Material Material;
            internal bool Retiring;
            internal readonly List<Lease> Leases = new List<Lease>(MaxPendingFrames);
        }
        private sealed class Lease
        {
            internal MaterialPropertyBlock[] Blocks;
            internal bool GpuAttempted, HasFence, Canceled;
            internal int EngineFrame;
            internal GraphicsFence Fence;
        }
        private sealed class State
        {
            internal HybridLumenGIReceiverIdentityPass Owner;
            internal MaterialOwner Material;
            internal Lease Lease;
            internal HybridLumenGIReceiverIdentityFrame Frame;
            internal HybridLumenGIReceiverIdentityFrame.Row[] Rows;
            internal BufferHandle Candidates, Objects;
            internal TextureHandle CameraDepth, CaptureDepth, Dummy, Output;
            internal int FullWidth, FullHeight, GiWidth, GiHeight, ObjectCount;
            internal Func<bool> Validate;
            internal Action<bool> Recorded;
            internal bool Initialized, Captured, CaptureAttempted, Failed, Notified;
            internal Action<CommandBuffer, int, bool> TimingBoundary;
            internal Action TimingInvalidated;
            internal int EngineFrame, NextTimingStage;
            internal bool TimingArmed, TimingRejected, TimingInvalidationNotified;
        }
        private sealed class PassData { internal State State; }

        public readonly struct Result
        {
            public readonly BufferHandle Candidates, Objects;
            public readonly int ObjectCount;
            public bool IsValid => Candidates.IsValid() && Objects.IsValid();
            internal Result(BufferHandle candidates, BufferHandle objects, int count)
            { Candidates = candidates; Objects = objects; ObjectCount = count; }
        }

        private MaterialOwner materialOwner;
        private ComputeShader compute;
        private int clearKernel, maskKernel, resolveKernel;
        private bool disposed;
        public string Status { get; private set; } = "Not initialized.";
        public bool IsAvailable => EnsureResources();
        public int PendingFrames => materialOwner != null ? materialOwner.Leases.Count : 0;

        /// <summary>
        /// Caller rejects unsupported camera/MSAA/debug/alpha-to-coverage state and revalidates
        /// these together with source snapshot/token in validateSources immediately before draws.
        /// recorded(true) means the resolve commands were recorded, never GPU completion.
        /// The returned handles must also be declared by every downstream RenderGraph consumer.
        /// Timing stages are clear/upload=0, unknown mask=1, capture=2 and resolve=3.
        /// Each executed stage pairs begin/end locally, including early returns and cleanup.
        /// Timing observers cannot change identity success or propagate an exception to GI.
        /// </summary>
        public Result Record(RenderGraph graph, HybridLumenGIReceiverIdentityFrame frame,
            TextureHandle cameraDepth, TextureHandle captureDepth, TextureHandle output,
            int fullWidth, int fullHeight, int giWidth, int giHeight, Matrix4x4 gpuViewProjection,
            Func<bool> validateSources, Action<bool> recorded,
            Action<CommandBuffer, int, bool> timingBoundary = null, Action timingInvalidated = null)
        {
            if (graph == null || frame == null || validateSources == null || !cameraDepth.IsValid() ||
                !captureDepth.IsValid() || !output.IsValid() || fullWidth < 1 || fullHeight < 1 ||
                fullWidth > 16384 || fullHeight > 16384 || giWidth < 1 || giHeight < 1 ||
                giWidth > fullWidth || giHeight > fullHeight || !Finite(gpuViewProjection))
            { Status = "Invalid identity capture inputs."; NotifyTimingInvalidated(timingInvalidated); Notify(recorded, false); return default; }
            if (!EnsureResources()) { NotifyTimingInvalidated(timingInvalidated); Notify(recorded, false); return default; }
            var state = new State
            {
                Owner = this, Material = materialOwner, Frame = frame,
                CameraDepth = cameraDepth, CaptureDepth = captureDepth, Output = output,
                FullWidth = fullWidth, FullHeight = fullHeight, GiWidth = giWidth, GiHeight = giHeight,
                ObjectCount = frame.Rows.Count, Validate = validateSources, Recorded = recorded,
                TimingBoundary = timingBoundary, TimingInvalidated = timingInvalidated, EngineFrame = Time.frameCount
            };
            state.Rows = new HybridLumenGIReceiverIdentityFrame.Row[Math.Max(1, frame.Rows.Count)];
            frame.Rows.CopyTo(state.Rows, 0);
            if (materialOwner.Leases.Count < MaxPendingFrames)
            {
                state.Lease = new Lease { Blocks = new MaterialPropertyBlock[frame.Draws.Count], EngineFrame = Time.frameCount };
                materialOwner.Leases.Add(state.Lease);
                try
                {
                    for (int i = 0; i < frame.Draws.Count; i++)
                    {
                        var draw = frame.Draws[i];
                        if (draw.Record == null || draw.Record.Mesh == null || draw.RowIndex < 0 ||
                            draw.RowIndex >= frame.Rows.Count || !draw.Coverage.Supported ||
                            draw.Coverage.SourceCull < 0 || draw.Coverage.SourceCull > 2)
                            throw new InvalidOperationException("Invalid frozen identity draw.");
                        var block = new MaterialPropertyBlock();
                        block.SetInteger(OwnerId, checked(draw.RowIndex + 1));
                        block.SetMatrix(ObjectMatrixId, draw.Record.LocalToWorld);
                        block.SetMatrix(ViewProjectionId, gpuViewProjection);
                        block.SetVector(FullSizeId, new Vector4(fullWidth, fullHeight, 0, 0));
                        block.SetVector(BaseMapStId, draw.Coverage.BaseMapST);
                        block.SetVector(AlphaId, new Vector4(draw.Coverage.BaseColorAlpha, draw.Coverage.Cutoff,
                            draw.Coverage.AlphaTest ? 1 : 0, draw.Coverage.SmoothnessFromAlbedoAlpha ? 1 : 0));
                        bool sampleAlpha = draw.Coverage.AlphaTest && !draw.Coverage.SmoothnessFromAlbedoAlpha && draw.Coverage.BaseMap != null;
                        block.SetFloat(HasBaseMapId, sampleAlpha ? 1 : 0);
                        block.SetTexture(BaseMapId, sampleAlpha ? draw.Coverage.BaseMap : Texture2D.whiteTexture);
                        state.Lease.Blocks[i] = block;
                    }
                }
                catch { state.Failed = true; Status = "Frozen identity draw setup failed."; }
            }
            else { state.Failed = true; Status = "Identity material retirement capacity reached; current-frame GI retained."; }

            try
            {
            state.Candidates = graph.CreateBuffer(new BufferDesc(checked(fullWidth * fullHeight), CandidateStride)
                { name = "HLGI receiver identity candidates" });
            state.Objects = graph.CreateBuffer(new BufferDesc(state.Rows.Length, HybridLumenGIReceiverIdentityFrame.RowStride)
                { name = "HLGI receiver identity objects" });
            state.Dummy = graph.CreateTexture(new TextureDesc(fullWidth, fullHeight)
                { name = "HLGI receiver identity raster", colorFormat = GraphicsFormat.R8G8B8A8_UNorm,
                    clearBuffer = false, enableRandomWrite = false, filterMode = FilterMode.Point });

            using (var builder = graph.AddUnsafePass<PassData>("HLGI Identity clear and upload", out var pass))
            {
                pass.State = state;
                builder.UseBuffer(state.Candidates, AccessFlags.Write); builder.UseBuffer(state.Objects, AccessFlags.Write);
                // The capture scope may extend through identity resolve. Establish an actual
                // resource edge before its first identity command, not only before the draws.
                builder.UseTexture(captureDepth, AccessFlags.Read);
                builder.AllowPassCulling(false);
                builder.SetRenderFunc(static (PassData d, UnsafeGraphContext ctx) => ExecuteTimed(d.State, CommandBufferHelpers.GetNativeCommandBuffer(ctx.cmd), 0, Initialize));
            }
            using (var builder = graph.AddUnsafePass<PassData>("HLGI Identity unknown coverage", out var pass))
            {
                pass.State = state; builder.UseBuffer(state.Candidates, AccessFlags.ReadWrite);
                builder.AllowPassCulling(false);
                builder.SetRenderFunc(static (PassData d, UnsafeGraphContext ctx) => ExecuteTimed(d.State, CommandBufferHelpers.GetNativeCommandBuffer(ctx.cmd), 1, MaskUnknown));
            }
            using (var builder = graph.AddUnsafePass<PassData>("HLGI Identity capture", out var pass))
            {
                pass.State = state; builder.UseBuffer(state.Candidates, AccessFlags.ReadWrite);
                builder.UseTexture(cameraDepth, AccessFlags.Read); builder.UseTexture(captureDepth, AccessFlags.Read);
                builder.UseTexture(state.Dummy, AccessFlags.Write);
                builder.AllowPassCulling(false); builder.AllowGlobalStateModification(true);
                builder.SetRenderFunc(static (PassData d, UnsafeGraphContext ctx) => ExecuteTimed(d.State, CommandBufferHelpers.GetNativeCommandBuffer(ctx.cmd), 2, Capture));
            }
            using (var builder = graph.AddUnsafePass<PassData>("HLGI Identity resolve", out var pass))
            {
                pass.State = state; builder.UseBuffer(state.Candidates, AccessFlags.Read);
                builder.UseBuffer(state.Objects, AccessFlags.Read); builder.UseTexture(output, AccessFlags.Write);
                builder.AllowPassCulling(false); builder.AllowGlobalStateModification(true);
                builder.SetRenderFunc(static (PassData d, UnsafeGraphContext ctx) => ExecuteTimed(d.State, CommandBufferHelpers.GetNativeCommandBuffer(ctx.cmd), 3, Resolve));
            }
            // Earlier passes can remain in a partially constructed graph after an exception.
            // Never let those callbacks publish a partial but apparently valid observation.
            state.TimingArmed = true;
            return new Result(state.Candidates, state.Objects, state.ObjectCount);
            }
            catch
            {
                state.Failed = true; state.Notified = true;
                RejectTiming(state);
                if (state.Lease != null)
                { state.Lease.Canceled = true; state.Lease.Blocks = null; state.Material.Leases.Remove(state.Lease); }
                Status = "Identity graph construction failed; current-frame GI retained.";
                Notify(recorded, false);
                return default;
            }
        }

        private static void ExecuteTimed(State state, CommandBuffer cmd, int stage, Action<State, CommandBuffer> body)
        {
            bool beginAttempted = false;
            try
            {
                if (!state.TimingArmed || state.TimingRejected || state.Owner.disposed ||
                    state.EngineFrame != Time.frameCount || (state.Lease != null && state.Lease.Canceled) ||
                    state.NextTimingStage != stage)
                    RejectTiming(state);
                else
                {
                    // Advance before the observer to reject duplicate/reentrant callbacks.
                    // Failed source coverage is still real executed work, not missing timing.
                    state.NextTimingStage++;
                    beginAttempted = state.TimingBoundary != null;
                    if (beginAttempted) ObserveTiming(state, cmd, stage, true);
                }
                body(state, cmd);
            }
            finally
            {
                // An observer may have queued Begin before throwing, or the body may cancel
                // a zero-draw lease. Always offer that same stage its local End for cleanup.
                if (beginAttempted) ObserveTiming(state, cmd, stage, false);
            }
        }

        private static void ObserveTiming(State state, CommandBuffer cmd, int stage, bool begin)
        {
            try { state.TimingBoundary(cmd, stage, begin); }
            catch { RejectTiming(state); }
        }
        private static void RejectTiming(State state)
        {
            state.TimingRejected = true;
            if (state.TimingInvalidationNotified) return;
            state.TimingInvalidationNotified = true;
            NotifyTimingInvalidated(state.TimingInvalidated);
        }
        private static void NotifyTimingInvalidated(Action callback) { try { callback?.Invoke(); } catch { } }

        private static void Initialize(State state, CommandBuffer cmd)
        {
            try
            {
                cmd.SetBufferData((GraphicsBuffer)state.Objects, state.Rows);
                cmd.SetComputeIntParams(state.Owner.compute, FullSizeId, state.FullWidth, state.FullHeight);
                cmd.SetComputeBufferParam(state.Owner.compute, state.Owner.clearKernel, CandidatesId, (GraphicsBuffer)state.Candidates);
                cmd.DispatchCompute(state.Owner.compute, state.Owner.clearKernel, Groups(state.FullWidth), Groups(state.FullHeight), 1);
                state.Initialized = true;
            }
            catch { state.Failed = true; state.Owner.Status = "Identity initialization commands failed."; }
        }
        private static void MaskUnknown(State state, CommandBuffer cmd)
        {
            if (!state.Initialized || state.Failed) return;
            try
            {
                cmd.SetComputeIntParams(state.Owner.compute, FullSizeId, state.FullWidth, state.FullHeight);
                cmd.SetComputeBufferParam(state.Owner.compute, state.Owner.maskKernel, CandidatesId, (GraphicsBuffer)state.Candidates);
                foreach (RectInt rect in state.Frame.UnknownRects)
                {
                    int x = Mathf.Clamp(rect.xMin, 0, state.FullWidth), y = Mathf.Clamp(rect.yMin, 0, state.FullHeight);
                    int right = Mathf.Clamp(rect.xMax, 0, state.FullWidth), top = Mathf.Clamp(rect.yMax, 0, state.FullHeight);
                    if (right <= x || top <= y) continue;
                    cmd.SetComputeIntParams(state.Owner.compute, UnknownRectId, x, y, right, top);
                    cmd.DispatchCompute(state.Owner.compute, state.Owner.maskKernel, Groups(right - x), Groups(top - y), 1);
                }
            }
            catch { state.Failed = true; state.Owner.Status = "Identity unknown-coverage commands failed."; }
        }
        private static void Capture(State state, CommandBuffer cmd)
        {
            try
            {
                if (state.CaptureAttempted || !state.Initialized || state.Failed || state.Owner.disposed ||
                    state.Lease == null || state.Lease.Canceled || state.Lease.EngineFrame != Time.frameCount || !state.Validate())
                { state.Failed = true; return; }
                state.CaptureAttempted = true;
                cmd.ClearRandomWriteTargets();
                cmd.SetRenderTarget((RenderTargetIdentifier)state.Dummy);
                cmd.SetViewport(new Rect(0, 0, state.FullWidth, state.FullHeight));
                cmd.SetRandomWriteTarget(1, (GraphicsBuffer)state.Candidates);
                for (int i = 0; i < state.Frame.Draws.Count; i++)
                {
                    var draw = state.Frame.Draws[i];
                    var block = state.Lease.Blocks[i];
                    block.SetTexture(CameraDepthId, (Texture)state.CameraDepth);
                    block.SetTexture(CaptureDepthId, (Texture)state.CaptureDepth);
                    state.Lease.GpuAttempted = true;
                    cmd.DrawMesh(draw.Record.Mesh, draw.Record.LocalToWorld, state.Material.Material,
                        draw.Record.Submesh, draw.Coverage.SourceCull, block);
                }
                state.Captured = true;
            }
            catch { state.Failed = true; state.Owner.Status = "Identity source validation or draw recording failed."; }
            finally
            {
                try { cmd.ClearRandomWriteTargets(); }
                catch { state.Failed = true; state.Owner.Status = "Identity UAV cleanup failed."; }
            }
        }
        private static void Resolve(State state, CommandBuffer cmd)
        {
            if (state.Notified) return;
            bool resolved = false;
            try
            {
                bool accept = state.Initialized && state.Captured && !state.Failed && !state.Owner.disposed;
                cmd.SetComputeIntParams(state.Owner.compute, FullSizeId, state.FullWidth, state.FullHeight);
                cmd.SetComputeIntParams(state.Owner.compute, GiSizeId, state.GiWidth, state.GiHeight);
                cmd.SetComputeIntParam(state.Owner.compute, ObjectCountId, accept ? state.ObjectCount : 0);
                cmd.SetComputeBufferParam(state.Owner.compute, state.Owner.resolveKernel, CandidatesId, (GraphicsBuffer)state.Candidates);
                cmd.SetComputeBufferParam(state.Owner.compute, state.Owner.resolveKernel, ObjectsId, (GraphicsBuffer)state.Objects);
                cmd.SetComputeTextureParam(state.Owner.compute, state.Owner.resolveKernel, OutputId, (RenderTargetIdentifier)state.Output);
                cmd.DispatchCompute(state.Owner.compute, state.Owner.resolveKernel, Groups(state.GiWidth), Groups(state.GiHeight), 1);
                resolved = accept;
            }
            catch { state.Owner.Status = "Identity resolve recording failed."; }
            finally
            {
                if (state.Lease != null)
                {
                    if (state.Lease.GpuAttempted)
                    {
                        try
                        {
                            state.Lease.Fence = cmd.CreateGraphicsFence(GraphicsFenceType.AsyncQueueSynchronisation,
                                SynchronisationStageFlags.AllGPUOperations);
                            state.Lease.HasFence = true;
                        }
                        catch { resolved = false; state.Owner.Status = "Identity retirement fence unavailable; private resources retained."; }
                    }
                    else { state.Material.Leases.Remove(state.Lease); state.Lease.Blocks = null; state.Lease.Canceled = true; }
                }
                if (!state.Notified) { state.Notified = true; Notify(state.Recorded, resolved); }
                CollectRetired();
            }
        }

        private bool EnsureResources()
        {
            CollectRetired();
            if (disposed) { Status = "Disposed."; return false; }
            if (!SystemInfo.supportsComputeShaders || !SystemInfo.supportsGraphicsFence || !SystemInfo.supportsAsyncCompute ||
                SystemInfo.supportedRandomWriteTargetCount < 2 || SystemInfo.graphicsDeviceType != GraphicsDeviceType.Direct3D12)
            { Status = "Requires DX12, compute, pixel UAV and graphics/async fence support."; return false; }
            if (materialOwner != null) return true;
            if (Owners.Count >= MaxMaterialOwners) { Status = "Private identity material retirement pool is full."; return false; }
            try
            {
                var shader = Shader.Find(ShaderName);
                compute = Resources.Load<ComputeShader>(ComputePath);
                if (shader == null || !shader.isSupported || compute == null)
                { Status = "Receiver identity shader/compute unavailable."; return false; }
                clearKernel = compute.FindKernel("CSClearIdentity"); maskKernel = compute.FindKernel("CSMaskUnknownIdentity");
                resolveKernel = compute.FindKernel("CSResolveIdentity");
                var material = CoreUtils.CreateEngineMaterial(shader);
                if (material == null) { Status = "Receiver identity material creation failed."; return false; }
                materialOwner = new MaterialOwner { Material = material };
                Owners.Add(materialOwner);
                if (!collectionRegistered)
                { RenderPipelineManager.endContextRendering += OnEndContext; collectionRegistered = true; }
                Status = "Available; Unity/DX12 identity execution remains unverified.";
                return true;
            }
            catch { Status = "Receiver identity resource setup failed."; return false; }
        }
        public void Dispose()
        {
            disposed = true;
            if (materialOwner != null)
            {
                materialOwner.Retiring = true;
                // Future callbacks test disposed before touching private draw resources.
                for (int i = materialOwner.Leases.Count - 1; i >= 0; i--)
                    if (!materialOwner.Leases[i].GpuAttempted)
                    { materialOwner.Leases[i].Blocks = null; materialOwner.Leases[i].Canceled = true; materialOwner.Leases.RemoveAt(i); }
            }
            CollectRetired(); Status = "Disposed; pending GPU private resources remain fence-protected.";
        }
        private static void OnEndContext(ScriptableRenderContext context, List<Camera> cameras) => CollectRetired();
        private static void CollectRetired()
        {
            for (int i = Owners.Count - 1; i >= 0; i--)
            {
                MaterialOwner owner = Owners[i];
                for (int j = owner.Leases.Count - 1; j >= 0; j--)
                {
                    Lease lease = owner.Leases[j];
                    // A graph can be constructed then abandoned. No GPU command may reference
                    // this lease yet; late callbacks check Canceled before using any private block.
                    if (!lease.GpuAttempted && lease.EngineFrame != Time.frameCount)
                    { lease.Canceled = true; lease.Blocks = null; owner.Leases.RemoveAt(j); continue; }
                    if (!lease.HasFence) continue;
                    bool passed = false;
                    try { passed = lease.Fence.passed; } catch { /* Unproven completion is never permission to recycle. */ }
                    if (passed) { lease.Canceled = true; lease.Blocks = null; owner.Leases.RemoveAt(j); }
                }
                if (owner.Retiring && owner.Leases.Count == 0)
                {
                    try { CoreUtils.Destroy(owner.Material); Owners.RemoveAt(i); }
                    catch { /* Retain the bounded owner when cleanup cannot establish success. */ }
                }
            }
            if (Owners.Count == 0 && collectionRegistered)
            { RenderPipelineManager.endContextRendering -= OnEndContext; collectionRegistered = false; }
        }
        private static void Notify(Action<bool> callback, bool value) { try { callback?.Invoke(value); } catch { } }
        private static int Groups(int value) => (value + 7) / 8;
        private static bool Finite(Matrix4x4 matrix)
        {
            for (int i = 0; i < 16; i++) if (float.IsNaN(matrix[i]) || float.IsInfinity(matrix[i])) return false;
            return true;
        }
    }
}
