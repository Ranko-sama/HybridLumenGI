using System;
using System.Collections.Generic;
using System.IO;
using System.Security.Cryptography;
using System.Text;
using UnityEngine;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;

namespace HybridLumenGI
{
    /// <summary>
    /// Explicitly requested, same-render observations. Nothing is registered or allocated
    /// until Begin/Request. Completion describes capture, never transport correctness.
    /// All public methods must be called on Unity's main/render-recording thread.
    /// </summary>
    public static class HybridLumenGIValidationCapture
    {
        [Serializable] public sealed class FileReference { public string file, sha256; }
        [Serializable] public sealed class Validity
        { public string file, sha256, format = "uint8", basis = "measurement-state"; }
        [Serializable] public sealed class Sample
        {
            public string signalId, status = "uncovered", stage, quantity;
            public string[] reasons = new[] { "Capture has not completed." };
            public int width, height, invalidPixels;
            public string format = "rgba32f-le", rowOrder = "top-to-bottom", sourceFormat, encoding;
            public FileReference data;
            public Validity validity;
        }
        [Serializable] public sealed class Support
        {
            public string file, sha256, role, stage, sourceFormat, encoding;
            public int width, height, invalidPixels;
            public string format = "rgba32f-le", rowOrder = "top-to-bottom";
            public Validity validity;
        }
        [Serializable] public sealed class Receipt
        {
            public int logicalFrame, engineFrame, workFrame = -1, epoch = -1, cameraInstanceId, featureInstanceId;
            public long ticketId, retainedBytes;
            public string cameraName, status = "requested", error = "", rowOrder = "top-to-bottom";
            public bool beforeRecorded, afterRecorded, cameraEnded, readbacksCompleted;
            public string boundary = "same-render pre/post HLGI composite at AfterRenderingSkybox+1; before transparent rendering and subsequent URP effects, not endCamera output";
            public string nativeDiffuseFogStatus = "not-applicable";
            public CompositeConstants composite;
            public Sample[] samples = Array.Empty<Sample>();
            public Support[] support = Array.Empty<Support>();
        }
        public struct SupportTextures
        {
            public TextureHandle filteredD, geometry, material, depth, captureDepth, emissionValidity, normals, moments, nativeDiffuseFog;
        }
        [Serializable] public struct CompositeConstants
        {
            public float intensity, depthThreshold;
            public int debug, normalsOct, composition;
            public Matrix4x4 invVP;
            public Vector2Int giSize;
        }

        // Kept even after Close while a request's submission/completion is unknown.
        // We never clear this list on Play initialization with domain reload disabled.
        private static List<Session> sessions;
        private static long nextTicket;
        private static bool hooks;

        public static Session Begin(Camera camera, HybridLumenGIRendererFeature feature,
            string absoluteDirectory, int maximumPending = 2, long maximumBytes = 128L * 1024 * 1024)
        {
            if (camera == null || feature == null) throw new ArgumentNullException("Capture requires a camera and feature instance.");
            if (!Path.IsPathRooted(absoluteDirectory)) throw new ArgumentException("Capture directory must be absolute.");
            if (maximumPending < 1 || maximumBytes < 1) throw new ArgumentOutOfRangeException("Capture limits must be positive.");
            if (sessions == null) sessions = new List<Session>();
            foreach (var s in sessions)
                if (!s.closed && s.camera == camera && s.feature == feature)
                    throw new InvalidOperationException("This camera/feature already has a capture owner.");
            var result = new Session(camera, feature, Path.GetFullPath(absoluteDirectory), maximumPending, maximumBytes);
            Directory.CreateDirectory(result.directory);
            sessions.Add(result);
            if (!hooks)
            {
                hooks = true; Application.quitting += CloseAll;
                RenderPipelineManager.endCameraRendering += CameraEnded;
#if UNITY_EDITOR
                UnityEditor.AssemblyReloadEvents.beforeAssemblyReload += CloseAll;
#endif
            }
            return result;
        }
        private static void CloseAll()
        { if (sessions != null) foreach (var s in sessions.ToArray()) s.Close("Capture owner is shutting down."); }
        private static void CameraEnded(ScriptableRenderContext context, Camera camera)
        {
            if (sessions == null) return;
            foreach (var session in sessions.ToArray())
                if (ReferenceEquals(session.camera, camera)) session.EndCamera(Time.frameCount);
        }
        private static void UnhookIfIdle()
        {
            if (!hooks || sessions.Count != 0) return;
            hooks = false; Application.quitting -= CloseAll;
            RenderPipelineManager.endCameraRendering -= CameraEnded;
#if UNITY_EDITOR
            UnityEditor.AssemblyReloadEvents.beforeAssemblyReload -= CloseAll;
#endif
        }

        public sealed class Session : IDisposable
        {
            internal readonly Camera camera;
            internal readonly HybridLumenGIRendererFeature feature;
            internal readonly string directory;
            internal readonly int maximumPending;
            internal readonly long maximumBytes;
            internal readonly List<Ticket> tickets = new List<Ticket>();
            internal bool closed;
            internal long retainedBytes;
            public event Action Changed;
            public bool IsClosed => closed;
            public long RetainedBytes => retainedBytes;
            public int PendingCount { get { int n = 0; foreach (var t in tickets) if (!t.IsComplete) n++; return n; } }
            public bool IsDrained => PendingCount == 0 && retainedBytes == 0;
            internal Session(Camera c, HybridLumenGIRendererFeature f, string d, int count, long bytes)
            { camera = c; feature = f; directory = d; maximumPending = count; maximumBytes = bytes; }

            public Ticket Request(int logicalFrame, int engineFrame)
            {
                if (closed) throw new InvalidOperationException("Capture is closed.");
                if (logicalFrame < 0 || engineFrame < 0) throw new ArgumentOutOfRangeException("Frame identifiers must be nonnegative.");
                foreach (var previous in tickets)
                    if (previous.receipt.logicalFrame == logicalFrame || previous.receipt.engineFrame == engineFrame)
                        throw new InvalidOperationException("A logical/engine frame cannot be requested twice.");
                var ticket = new Ticket(this, logicalFrame, engineFrame); tickets.Add(ticket);
                if (PendingCount > maximumPending) ticket.Cancel("Capture capacity reached; the requested frame was not deferred.");
                return ticket;
            }

            /// <summary>Idempotent exact-camera boundary; the Session also retains its own endCamera subscription.</summary>
            public void EndCamera(int engineFrame)
            {
                foreach (var t in tickets)
                    if (!t.IsComplete && t.receipt.engineFrame == engineFrame)
                    {
                        t.receipt.cameraEnded = true;
                        // This boundary ends graph resolution, not GPU work. An
                        // unused imported target may still have RG barriers: hand it
                        // to the existing retirement fence, never release it here.
                        foreach (var plane in t.planes) if (!plane.started) plane.Release();
                        if (!t.claimed || !t.receipt.beforeRecorded || !t.receipt.afterRecorded)
                            t.Cancel("The requested same-camera render did not record both capture boundaries.");
                        t.FinishIfReady();
                    }
            }
            /// <summary>Also call when no target camera rendered, to reject missed requests.</summary>
            public void ExpireBefore(int engineFrame)
            { foreach (var t in tickets) if (!t.IsComplete && t.receipt.engineFrame < engineFrame && !t.receipt.cameraEnded) t.Cancel("Requested engine frame ended without a complete camera receipt."); }
            public void Close(string reason = "Capture was closed before completion.")
            {
                if (closed) return; closed = true;
                foreach (var t in tickets) if (!t.IsComplete) t.Cancel(reason);
                DetachIfDrained();
                NotifyChanged();
                if (!IsDrained) Debug.LogWarning("HLGI capture retains " + retainedBytes + " owned bytes until its readbacks complete; no global GPU wait or assumed completion.");
            }
            /// <summary>Normal sequence end: stop admission without cancelling recorded readbacks.</summary>
            public void Seal()
            {
                if (closed) return; closed = true;
                foreach (var t in tickets)
                    if (!t.IsComplete && (!t.claimed || !t.receipt.beforeRecorded || !t.receipt.afterRecorded || !t.receipt.cameraEnded))
                        t.Cancel("Sequence ended before this capture completed both same-camera recording boundaries.");
                DetachIfDrained(); NotifyChanged();
            }
            public void Dispose() => Close();
            internal void DetachIfDrained() { if (closed && IsDrained) { sessions.Remove(this); UnhookIfIdle(); } }
            internal void NotifyChanged()
            {
                var changed = Changed; if (changed == null) return;
                foreach (Action listener in changed.GetInvocationList())
                    try { listener(); } catch (Exception error) { Debug.LogException(error); }
            }
        }

        public sealed class Ticket
        {
            internal readonly Session owner;
            internal readonly Receipt receipt;
            internal readonly List<Plane> planes = new List<Plane>();
            internal bool claimed, beforeScheduled, afterScheduled, cancelled, finalized, hasComposite;
            internal ComputeShader depthCopy;
            internal int depthKernel;
            internal int fullWidth, fullHeight;
            public Receipt Result => receipt;
            public bool IsComplete => finalized;
            public bool Succeeded => finalized && receipt.status == "complete";
            public string Failure => receipt.error;
            public string ReceiptPath => Path.Combine(owner.directory, "frame-" + receipt.logicalFrame.ToString("D4") + "-capture.json");
            // Camera descriptor is supplied once by the Feature from its actual cameraData.
            public HybridLumenGIValidationSourceState.CameraDescriptor Camera { get; private set; }
            public void SetCamera(HybridLumenGIValidationSourceState.CameraDescriptor camera)
            {
                if (!claimed || Camera != null || camera == null) throw new InvalidOperationException("Capture camera descriptor must be set exactly once after claim.");
                if (beforeScheduled || camera.view == null || camera.view.Length != 16 || camera.projection == null || camera.projection.Length != 16 ||
                    camera.jitter == null || camera.jitter.Length != 2 || camera.viewport == null || camera.viewport.Length != 4)
                    throw new InvalidOperationException("Actual camera descriptor is incomplete or late.");
                camera.Validate();
                if (camera.viewport[2] != fullWidth || camera.viewport[3] != fullHeight)
                    throw new InvalidOperationException("Actual camera descriptor dimensions differ from this render.");
                Camera = new HybridLumenGIValidationSourceState.CameraDescriptor { matrixOrder = camera.matrixOrder,
                    view = (float[])camera.view.Clone(), projection = (float[])camera.projection.Clone(), jitter = (float[])camera.jitter.Clone(),
                    viewport = (int[])camera.viewport.Clone(), rowOrder = camera.rowOrder, uvOrigin = camera.uvOrigin,
                    clipDepth = camera.clipDepth, reversedZ = camera.reversedZ, pixelCenter = camera.pixelCenter };
            }
            public void SetComposite(CompositeConstants constants)
            {
                if (!claimed || hasComposite || beforeScheduled || constants.giSize.x < 1 || constants.giSize.y < 1)
                    throw new InvalidOperationException("Actual composite constants must be set once before scheduling.");
                receipt.composite = constants; hasComposite = true;
            }
            internal Ticket(Session s, int logical, int engine)
            {
                owner = s;
                receipt = new Receipt { logicalFrame = logical, engineFrame = engine, ticketId = ++nextTicket,
                    cameraInstanceId = s.camera.GetInstanceID(), featureInstanceId = s.feature.GetInstanceID(), cameraName = s.camera.name };
            }
            internal void Error(string reason)
            { if (string.IsNullOrEmpty(receipt.error)) receipt.error = reason; receipt.status = "incomplete"; }
            internal void Cancel(string reason)
            {
                cancelled = true; Error(reason);
                foreach (var plane in planes) if (!plane.started) plane.Release();
                FinishIfReady();
                owner.NotifyChanged();
            }
            internal void FinishIfReady()
            {
                if (finalized) return;
                foreach (var plane in planes) if (!plane.released) { receipt.retainedBytes = Bytes(); return; }
                if (!cancelled && (!receipt.cameraEnded || !receipt.afterRecorded)) return;
                if (!cancelled && Camera == null) Error("Actual camera descriptor was not provided.");
                if (!cancelled && !hasComposite) Error("Actual composite constants were not provided.");
                receipt.readbacksCompleted = !cancelled || (receipt.beforeRecorded && receipt.afterRecorded && AllReadbacksCompleted());
                receipt.retainedBytes = 0;
                receipt.status = !cancelled && string.IsNullOrEmpty(receipt.error) ? "complete" : "incomplete";
                foreach (var sample in receipt.samples)
                    if (sample.status != "available") sample.reasons = new[] { string.IsNullOrEmpty(receipt.error) ? "Capture did not produce this signal." : receipt.error };
                finalized = true;
                try { WriteNew(ReceiptPath, Encoding.UTF8.GetBytes(JsonUtility.ToJson(receipt, true) + "\n")); }
                catch (Exception error) { Error("Capture receipt IO: " + error.Message); Debug.LogError(receipt.error); }
                owner.DetachIfDrained();
                owner.NotifyChanged();
            }
            internal long Bytes() { long total = 0; foreach (var p in planes) if (!p.released) total += p.reservedBytes; return total; }
            private bool AllReadbacksCompleted() { foreach (var p in planes) if (!p.completed) return false; return true; }
        }

        /// <summary>Returns false without allocations when no matching request exists.</summary>
        public static bool TryClaim(Camera camera, HybridLumenGIRendererFeature feature, int engineFrame,
            int workFrame, int epoch, RenderTextureDescriptor target, bool backbuffer, bool xr, out Ticket ticket)
        {
            ticket = null;
            if (sessions == null) return false;
            foreach (var session in sessions)
            {
                if (session.closed || session.camera != camera || session.feature != feature) continue;
                foreach (var request in session.tickets)
                {
                    if (request.IsComplete || request.claimed || request.receipt.engineFrame != engineFrame) continue;
                    ticket = request; request.claimed = true;
                    request.receipt.workFrame = workFrame; request.receipt.epoch = epoch;
                    request.fullWidth = target.width; request.fullHeight = target.height;
                    if (backbuffer || xr || target.dimension != TextureDimension.Tex2D || target.volumeDepth != 1 || target.msaaSamples != 1 ||
                        target.useDynamicScale || target.width < 1 || target.height < 1 || camera.rect != new Rect(0, 0, 1, 1) ||
                        SystemInfo.graphicsDeviceType != GraphicsDeviceType.Direct3D12 || !SystemInfo.graphicsUVStartsAtTop ||
                        QualitySettings.activeColorSpace != ColorSpace.Linear || !SystemInfo.supportsAsyncGPUReadback || !BitConverter.IsLittleEndian)
                    { request.Cancel("Capture requires a full-viewport, fixed-resolution, single-sample, non-XR DX12 linear offscreen camera and async readback."); ticket = null; return false; }
                    try
                    {
                        // This happens only for an explicitly claimed request. The normal
                        // render path does not load a shader or allocate capture resources.
                        request.depthCopy = Resources.Load<ComputeShader>("HybridLumenGI/HybridLumenGIValidationCopy");
                        if (request.depthCopy == null) throw new InvalidOperationException("Validation depth copy shader is unavailable.");
                        request.depthKernel = request.depthCopy.FindKernel("CopyDepth");
                    }
                    catch (Exception error) { request.Cancel(error.Message); ticket = null; return false; }
                    request.receipt.status = "claimed"; return true;
                }
            }
            return false;
        }

        private sealed class CopyPass { internal Ticket ticket; internal Plane[] planes; internal bool after; }
        internal sealed class Plane
        {
            internal Ticket ticket;
            internal TextureHandle source, imported;
            internal RTHandle staging;
            internal RenderTexture texture;
            internal string name, stage;
            internal Sample sample;
            internal Support support;
            internal int width, height;
            internal long reservedBytes;
            internal bool graphOwned, retirementQueued, retirementCompleted, started, completed, released, alphaValid, depthLoad;
            internal void Release()
            {
                if (released) return;
                if (!completed)
                {
                    if (started) return;
                    if (graphOwned && !retirementCompleted)
                    {
                        if (ticket.receipt.cameraEnded && !retirementQueued)
                        {
                            retirementQueued = true;
                            try
                            {
                                HybridLumenGIResourceRetirement.Retire(() =>
                                {
                                    retirementCompleted = true; Release(); ticket.FinishIfReady(); ticket.owner.NotifyChanged();
                                });
                            }
                            catch (Exception error) { ticket.Error("Capture retirement handoff failed; storage retained: " + error.Message); }
                        }
                        return;
                    }
                }
                try
                {
                    staging?.Release(); staging = null;
                    if (texture != null) { texture.Release(); CoreUtils.Destroy(texture); texture = null; }
                    released = true; ticket.owner.retainedBytes -= reservedBytes;
                }
                catch (Exception error) { ticket.Error("Capture storage release failed; ownership retained: " + error.Message); ticket.owner.NotifyChanged(); }
            }
        }
        public static void RecordBefore(RenderGraph graph, Ticket ticket, TextureHandle cameraColor, SupportTextures support)
        {
            if (ticket == null) return;
            if (!ticket.claimed || ticket.beforeScheduled) throw new InvalidOperationException("Before capture must be scheduled once after claim.");
            if (ticket.cancelled) return;
            ticket.beforeScheduled = true;
            try
            {
                if (ticket.Camera == null || !ticket.hasComposite) throw new InvalidOperationException("Actual camera/composite inputs must precede capture scheduling.");
                var planes = new List<Plane>();
                planes.Add(Reserve(graph, ticket, cameraColor, "cameraBeforeHLGI", "before-hlgi-composite-after-skybox", true, false, true));
                planes.Add(Reserve(graph, ticket, support.filteredD, "filteredD", "before-hlgi-composite-after-filter", true, true, false));
                planes.Add(Reserve(graph, ticket, support.geometry, "geometry", "before-hlgi-composite", false, false, false));
                planes.Add(Reserve(graph, ticket, support.material, "material", "before-hlgi-composite", false, false, true));
                planes.Add(Reserve(graph, ticket, support.depth, "depth", "before-hlgi-composite", false, false, true));
                planes.Add(Reserve(graph, ticket, support.captureDepth, "captureDepth", "before-hlgi-composite", false, false, true));
                planes.Add(Reserve(graph, ticket, support.emissionValidity, "emissionValidity", "before-hlgi-composite", false, false, true));
                planes.Add(Reserve(graph, ticket, support.normals, "normals", "before-hlgi-composite", false, false, true));
                planes.Add(Reserve(graph, ticket, support.moments, "moments", "before-hlgi-composite", false, false, false));
                if (support.nativeDiffuseFog.IsValid())
                {
                    planes.Add(Reserve(graph, ticket, support.nativeDiffuseFog, "nativeDiffuseFog", "before-hlgi-composite", false, false, true));
                    ticket.receipt.nativeDiffuseFogStatus = "available";
                }
                AddPass(graph, ticket, planes.ToArray(), false);
            }
            catch (Exception error) { ticket.Cancel("Before capture preparation: " + error.Message); }
        }
        public static void RecordAfter(RenderGraph graph, Ticket ticket, TextureHandle cameraColor)
        {
            if (ticket == null) return;
            if (!ticket.beforeScheduled || ticket.afterScheduled) throw new InvalidOperationException("After capture must follow Before once in this graph.");
            if (ticket.cancelled) return;
            ticket.afterScheduled = true;
            try { AddPass(graph, ticket, new[] { Reserve(graph, ticket, cameraColor, "cameraAfterHLGI", "after-hlgi-composite-before-transparents", true, false, true) }, true); }
            catch (Exception error) { ticket.Cancel("After capture preparation: " + error.Message); }
        }
        private static Plane Reserve(RenderGraph graph, Ticket ticket, TextureHandle source, string name, string stage, bool isSample, bool alphaValid, bool fullSize)
        {
            if (!source.IsValid()) throw new InvalidOperationException(name + " source is unavailable.");
            var desc = graph.GetTextureDesc(source);
            bool depthLoad = desc.format == GraphicsFormat.D32_SFloat;
            GraphicsFormat stagingFormat = depthLoad ? GraphicsFormat.R32G32B32A32_SFloat : desc.format;
            if (desc.sizeMode != TextureSizeMode.Explicit || desc.dimension != TextureDimension.Tex2D || desc.slices != 1 ||
                desc.msaaSamples != MSAASamples.None || desc.useDynamicScale || desc.useDynamicScaleExplicit || desc.width < 1 || desc.height < 1 ||
                desc.memoryless != RenderTextureMemoryless.None || GraphicsFormatUtility.IsSRGBFormat(desc.format) ||
                (GraphicsFormatUtility.IsDepthStencilFormat(desc.format) && !depthLoad) ||
                !SystemInfo.IsFormatSupported(stagingFormat, GraphicsFormatUsage.ReadPixels) ||
                (depthLoad && (!SystemInfo.IsFormatSupported(desc.format, GraphicsFormatUsage.Sample) ||
                    !SystemInfo.IsFormatSupported(stagingFormat, GraphicsFormatUsage.LoadStore))))
                throw new InvalidOperationException(name + " has an unsupported size/format/readback descriptor: " + desc.format);
            if (fullSize && (desc.width != ticket.fullWidth || desc.height != ticket.fullHeight)) throw new InvalidOperationException(name + " is not full camera resolution.");
            if (!fullSize && (desc.width != ticket.receipt.composite.giSize.x || desc.height != ticket.receipt.composite.giSize.y))
                throw new InvalidOperationException(name + " dimensions differ from the actual GI grid.");
            if (isSample && desc.format != GraphicsFormat.R16G16B16A16_SFloat && desc.format != GraphicsFormat.R32G32B32A32_SFloat)
                throw new InvalidOperationException(name + " requires a signed floating-point RGBA source.");
            if ((SystemInfo.copyTextureSupport & CopyTextureSupport.Basic) == 0) throw new InvalidOperationException("Exact same-format texture copy is unsupported.");
            long pixels = checked((long)desc.width * desc.height);
            // Logical ownership bound: staging + native RGBA32F readback + managed
            // RGBA32F write copy + uint8 mask. It is not a driver/GC VRAM guarantee.
            long bytes = checked(pixels * (GraphicsFormatUtility.GetBlockSize(stagingFormat) + 33L));
            if (bytes > ticket.owner.maximumBytes - ticket.owner.retainedBytes) throw new InvalidOperationException("Capture byte budget exhausted; no frame or size substitution.");
            var plane = new Plane { ticket = ticket, source = source, name = name, stage = stage, width = desc.width, height = desc.height, reservedBytes = bytes, alphaValid = alphaValid, depthLoad = depthLoad };
            ticket.owner.retainedBytes += bytes; ticket.planes.Add(plane);
            try
            {
                var rtDesc = new RenderTextureDescriptor(desc.width, desc.height) { msaaSamples = 1, volumeDepth = 1, dimension = TextureDimension.Tex2D,
                    graphicsFormat = stagingFormat, depthStencilFormat = GraphicsFormat.None,
                    useMipMap = false, autoGenerateMips = false, enableRandomWrite = depthLoad, useDynamicScale = false };
                plane.texture = new RenderTexture(rtDesc) { name = "HLGI validation " + ticket.receipt.ticketId + " " + name, filterMode = FilterMode.Point, hideFlags = HideFlags.HideAndDontSave };
                if (!plane.texture.Create()) throw new InvalidOperationException(name + " staging allocation failed.");
                plane.staging = RTHandles.Alloc(plane.texture);
                // Import/Use declarations remain meaningful even when a cancelled
                // pass body skips its commands. Keep the handle through graph exit.
                plane.graphOwned = true; plane.imported = graph.ImportTexture(plane.staging);
                string encoding = depthLoad ? "RGBA32F=(device-depth,0,0,1); same integer-pixel float32 Load; no linearization" : "same-format CopyTexture; AsyncGPUReadback RGBA32F numeric conversion; no resampling";
                if (isSample)
                    plane.sample = new Sample { signalId = name, stage = stage, quantity = alphaValid ? "indirect-irradiance-over-pi" : "camera-radiance", width = desc.width, height = desc.height, sourceFormat = desc.format.ToString(), encoding = encoding };
                else plane.support = new Support { role = name, stage = stage, width = desc.width, height = desc.height, sourceFormat = desc.format.ToString(), encoding = encoding };
                RefreshSamples(ticket); return plane;
            }
            catch { plane.Release(); throw; }
        }
        private static void RefreshSamples(Ticket ticket)
        {
            var samples = new List<Sample>(); var support = new List<Support>();
            foreach (var plane in ticket.planes) { if (plane.sample != null) samples.Add(plane.sample); if (plane.support != null) support.Add(plane.support); }
            ticket.receipt.samples = samples.ToArray(); ticket.receipt.support = support.ToArray();
        }
        private static void AddPass(RenderGraph graph, Ticket ticket, Plane[] planes, bool after)
        {
            using (var builder = graph.AddUnsafePass<CopyPass>(after ? "HLGI validation after composite" : "HLGI validation before composite", out var data))
            {
                data.ticket = ticket; data.planes = planes; data.after = after;
                foreach (var plane in planes) { builder.UseTexture(plane.source, AccessFlags.Read); builder.UseTexture(plane.imported, AccessFlags.ReadWrite); }
                builder.AllowPassCulling(false);
                builder.SetRenderFunc(static (CopyPass d, UnsafeGraphContext ctx) =>
                {
                    if (d.ticket.cancelled) return;
                    var cmd = CommandBufferHelpers.GetNativeCommandBuffer(ctx.cmd);
                    try
                    {
                        foreach (var plane in d.planes)
                        {
                            // Set before recording. An exception may leave an unknown partial
                            // submission: no callback means this storage remains owned.
                            plane.started = true;
                            if (plane.depthLoad)
                            {
                                var shader = d.ticket.depthCopy; int kernel = d.ticket.depthKernel;
                                cmd.SetComputeIntParams(shader, "_HLGI_ValidationCopySize", plane.width, plane.height);
                                cmd.SetComputeTextureParam(shader, kernel, "_HLGI_ValidationDepth", (RTHandle)plane.source);
                                cmd.SetComputeTextureParam(shader, kernel, "_HLGI_ValidationDepthCopy", plane.texture);
                                cmd.DispatchCompute(shader, kernel, (plane.width + 7) / 8, (plane.height + 7) / 8, 1);
                            }
                            else cmd.CopyTexture((RTHandle)plane.source, plane.staging);
                            cmd.RequestAsyncReadback(plane.texture, 0, TextureFormat.RGBAFloat, request => Complete(plane, request));
                        }
                        if (d.after) d.ticket.receipt.afterRecorded = true; else d.ticket.receipt.beforeRecorded = true;
                    }
                    catch (Exception error) { d.ticket.Cancel("Capture command recording failed; possible submitted storage retained: " + error.Message); }
                });
            }
        }
        private static void Complete(Plane plane, AsyncGPUReadbackRequest request)
        {
            if (plane.completed) return;
            try
            {
                if (!request.done) throw new InvalidOperationException("Readback callback did not prove completion.");
                plane.completed = true;
                if (request.hasError) throw new InvalidOperationException(plane.name + " GPU readback failed.");
                var values = request.GetData<float>();
                if (values.Length != checked(plane.width * plane.height * 4)) throw new InvalidOperationException("RGBA32F payload shape differs.");
                var mask = new byte[checked(plane.width * plane.height)]; int invalid = 0, nonfinite = 0;
                for (int p = 0; p < mask.Length; p++)
                {
                    bool valid = true;
                    for (int c = 0; c < 4; c++) { float v = values[p * 4 + c]; valid &= !float.IsNaN(v) && !float.IsInfinity(v); }
                    if (!valid) nonfinite++;
                    if (plane.alphaValid) valid &= values[p * 4 + 3] > 0;
                    mask[p] = valid ? (byte)1 : (byte)0; if (!valid) invalid++;
                }
                var bytes = request.GetData<byte>().ToArray();
                string stem = "frame-" + plane.ticket.receipt.logicalFrame.ToString("D4") + "-" + plane.name;
                var raw = Save(plane.ticket.owner, stem + ".rgba32f", bytes);
                var validity = Save(plane.ticket.owner, stem + ".validity.u8", mask);
                var vmeta = new Validity { file = validity.file, sha256 = validity.sha256 };
                if (plane.sample != null)
                { plane.sample.status = "available"; plane.sample.reasons = Array.Empty<string>(); plane.sample.data = raw; plane.sample.validity = vmeta; plane.sample.invalidPixels = invalid; }
                else
                { plane.support.file = raw.file; plane.support.sha256 = raw.sha256; plane.support.validity = vmeta; plane.support.invalidPixels = invalid; }
                if (nonfinite != 0) plane.ticket.Error(plane.name + " contains nonfinite measurements; raw and invalid mask retained.");
            }
            catch (Exception error) { plane.ticket.Error(plane.name + " completion: " + error.Message); }
            finally
            {
                // Only a completed request (including a completed error) authorizes
                // release. No timeout, Close, frame count or endCamera substitutes.
                if (plane.completed) plane.Release();
                plane.ticket.FinishIfReady();
                plane.ticket.owner.NotifyChanged();
            }
        }
        private static FileReference Save(Session owner, string name, byte[] data)
        {
            WriteNew(Path.Combine(owner.directory, name), data);
            using (var hash = SHA256.Create()) return new FileReference { file = name, sha256 = BitConverter.ToString(hash.ComputeHash(data)).Replace("-", "").ToLowerInvariant() };
        }
        private static void WriteNew(string path, byte[] data)
        { using (var stream = new FileStream(path, FileMode.CreateNew, FileAccess.Write, FileShare.Read)) stream.Write(data, 0, data.Length); }
    }
}
