using System;
using System.Runtime.InteropServices;
using UnityEngine;
using UnityEngine.Rendering;

namespace HybridLumenGI
{
    /// <summary>
    /// Per-camera GPU directional-proposal storage. Capture/descriptor writes, RecordBuild
    /// and all Bind consumers must execute in order on the same graphics queue.
    /// A recorded build is not evidence of GPU completion or a CPU-visible emitter count.
    /// </summary>
    public sealed class HybridLumenGIEmissiveSampling : IDisposable
    {
        public const int ProposalCapacity = 32;
        public const int RecordCount = ProposalCapacity + 1;
        public const int RecordStride = 32;
        private const string ResourcePath = "HybridLumenGI/HybridLumenGIEmissiveProposals";
        private const string KernelName = "CSBuildEmissiveProposals";
        private static readonly int ProposalsId = Shader.PropertyToID("_HLGI_EmissiveProposals");
        private static readonly int ProxiesId = Shader.PropertyToID("_HLGI_Proxies");
        private static readonly int ProxyCountId = Shader.PropertyToID("_HLGI_ProxyCount");
        private static readonly int BudgetId = Shader.PropertyToID("_HLGI_EmitterBudget");
        [StructLayout(LayoutKind.Sequential)] private struct ProposalRecord { public Vector4 sphere, data; }
        private static readonly ProposalRecord[] ClearedRecords = new ProposalRecord[RecordCount];
        private ComputeShader builder;
        private int buildKernel = -1;
        private bool disposed;

        public ComputeBuffer Buffer { get; private set; }
        public long AllocatedBytes => Buffer != null ? (long)RecordCount * RecordStride : 0;
        public bool BuildRecorded { get; private set; }

        /// <summary>
        /// Returns whether a build dispatch was recorded, including a zero-budget clear.
        /// Missing/unsupported builders retain and clear a valid dummy table for consumers.
        /// No CPU material selection or cache/lighting invalidation occurs here.
        /// </summary>
        public bool RecordBuild(CommandBuffer command, HybridLumenGIScene scene, HybridLumenGISurfaceCache surface, int budget)
        {
            if (command == null) throw new ArgumentNullException(nameof(command));
            if (scene == null) throw new ArgumentNullException(nameof(scene));
            if (surface == null) throw new ArgumentNullException(nameof(surface));
            if (disposed) throw new ObjectDisposedException(nameof(HybridLumenGIEmissiveSampling));
            BuildRecorded = false;
            EnsureBuffer();
            if (!SystemInfo.supportsComputeShaders)
            {
                command.SetBufferData(Buffer, ClearedRecords);
                return false;
            }
            try
            {
                if (builder == null)
                {
                    builder = Resources.Load<ComputeShader>(ResourcePath);
                    buildKernel = -1;
                }
                if (builder == null)
                {
                    command.SetBufferData(Buffer, ClearedRecords);
                    return false;
                }
                if (buildKernel < 0) buildKernel = builder.FindKernel(KernelName);
                if (scene.Buffer == null) throw new InvalidOperationException("Prepare scene resources before emissive proposals.");
                command.SetComputeBufferParam(builder, buildKernel, ProxiesId, scene.Buffer);
                command.SetComputeIntParam(builder, ProxyCountId, scene.Capacity);
                surface.BindCompute(command, builder, buildKernel);
                surface.BindEmitters(command, builder, buildKernel);
                command.SetComputeBufferParam(builder, buildKernel, ProposalsId, Buffer);
                command.SetComputeIntParam(builder, BudgetId, Mathf.Clamp(budget, 0, ProposalCapacity));
                // The builder clears all records, even at budget zero, and filters published
                // owners using current GPU metadata before writing the final header.
                command.DispatchCompute(builder, buildKernel, 1, 1, 1);
                BuildRecorded = true;
                return true;
            }
            catch (Exception)
            {
                // Preserve graphics-stream ordering. Immediate SetData here could overwrite
                // an earlier camera/frame's in-flight table. Failure to record this clear
                // itself must propagate: a stale table cannot safely be advertised as empty.
                command.SetBufferData(Buffer, ClearedRecords);
                return false;
            }
        }

        /// <summary>Bind the same per-camera output to each software or hardware transport kernel.</summary>
        public bool Bind(CommandBuffer command, ComputeShader compute, int kernel)
        {
            if (command == null) throw new ArgumentNullException(nameof(command));
            if (compute == null) throw new ArgumentNullException(nameof(compute));
            if (disposed) return false;
            EnsureBuffer(); // A consumer before the first build receives an explicitly zero table.
            command.SetComputeBufferParam(compute, kernel, ProposalsId, Buffer);
            return true;
        }

        private void EnsureBuffer()
        {
            if (Buffer != null) return;
            Buffer = new ComputeBuffer(RecordCount, RecordStride, ComputeBufferType.Structured) { name = "Hybrid GI Emissive Proposals" };
            // Safe only at allocation: this new buffer has never been submitted to the GPU.
            Buffer.SetData(ClearedRecords);
        }

        public void Dispose()
        {
            if (disposed) return;
            disposed = true;
            Buffer?.Release(); Buffer = null;
            builder = null; buildKernel = -1; BuildRecorded = false;
        }
    }
}
