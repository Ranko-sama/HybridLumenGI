using System;
using System.Runtime.InteropServices;
using UnityEngine;
using UnityEngine.Rendering;

namespace HybridLumenGI
{
    /// <summary>
    /// Optional CPU sampling of this process's DXGI video-memory usage and budget.
    /// Values are not GI-exclusive, cannot be added across cameras, and do not
    /// measure whole-machine usage. Peaks are sampled maxima, not instantaneous peaks.
    /// </summary>
    public sealed class HybridLumenGIVideoMemory
    {
        [Serializable]
        public struct Snapshot
        {
            public bool valid, hasSamples;
            public string status, adapterLuid;
            public int attemptFrame, sampleFrame, windowFirstFrame;
            public long samples, failedSamples;
            public ulong deviceEpoch;
            public ulong localUsageBytes, localBudgetBytes, nonlocalUsageBytes, nonlocalBudgetBytes;
            public ulong peakLocalUsageBytes, peakNonlocalUsageBytes;
        }

        [StructLayout(LayoutKind.Sequential, Pack = 8)]
        private struct NativeInfo
        {
            public uint abiVersion, structSize;
            public ulong deviceEpoch, adapterLuid;
            public ulong localUsage, localBudget, nonlocalUsage, nonlocalBudget;
        }

        private const uint AbiVersion = 1, NativeInfoSize = 56;
        [DllImport("HybridLumenGIGpuTiming", CallingConvention = CallingConvention.Cdecl, ExactSpelling = true)]
        private static extern int HLGI_Memory_Query(out NativeInfo info, uint size);

        private Snapshot current = Empty("Disabled");
        private bool enabledPreviously, hasObservedFrame, hasAttemptFrame;
        private int lastObservedFrame, lastAttemptFrame;
        private ulong windowAdapterLuid;
        private string interopUnavailable;

        /// <summary>Returns a value copy. Current usage/budget fields are zero when invalid.</summary>
        public Snapshot Current => current;

        /// <summary>Call on the main thread. Disabled sampling never probes the DLL.</summary>
        public void Sample(int engineFrame, bool enabled)
        {
            if (hasObservedFrame && engineFrame < lastObservedFrame)
            {
                enabledPreviously = false;
                hasAttemptFrame = false;
            }
            hasObservedFrame = true;
            lastObservedFrame = engineFrame;

            if (!enabled)
            {
                current = Empty("Disabled");
                windowAdapterLuid = 0;
                enabledPreviously = false;
                return;
            }
            if (!enabledPreviously)
            {
                BeginWindow(engineFrame);
                enabledPreviously = true;
            }
            // Keep this guard across disable/re-enable within the same engine frame.
            if (hasAttemptFrame && lastAttemptFrame == engineFrame) return;
            hasAttemptFrame = true;
            lastAttemptFrame = engineFrame;
            current.attemptFrame = engineFrame;

            if (IntPtr.Size != 8 ||
                (Application.platform != RuntimePlatform.WindowsEditor && Application.platform != RuntimePlatform.WindowsPlayer) ||
                SystemInfo.graphicsDeviceType != GraphicsDeviceType.Direct3D12)
            {
                Fail("Unsupported: Windows64 Direct3D12 required");
                return;
            }
            if (interopUnavailable != null) { Fail(interopUnavailable); return; }

            NativeInfo info;
            int result;
            try { result = HLGI_Memory_Query(out info, NativeInfoSize); }
            catch (DllNotFoundException) { Unavailable("Unavailable: DLL missing"); return; }
            catch (EntryPointNotFoundException) { Unavailable("Unavailable: memory entry point missing"); return; }
            catch (BadImageFormatException) { Unavailable("Unavailable: incompatible DLL image"); return; }

            if (result != 1)
            {
                Fail(result == -2 ? "DeviceLost" : result == 0 ? "Unavailable" : "InvalidResult");
                return;
            }
            if (info.abiVersion != AbiVersion || info.structSize != NativeInfoSize)
            {
                Unavailable("Unavailable: incompatible memory ABI");
                return;
            }
            if (current.hasSamples && (info.deviceEpoch != current.deviceEpoch || info.adapterLuid != windowAdapterLuid))
            {
                BeginWindow(engineFrame);
                current.attemptFrame = engineFrame;
            }

            if (!current.hasSamples || windowAdapterLuid != info.adapterLuid)
                current.adapterLuid = "0x" + info.adapterLuid.ToString("X16");
            windowAdapterLuid = info.adapterLuid;
            current.deviceEpoch = info.deviceEpoch;
            current.localUsageBytes = info.localUsage;
            current.localBudgetBytes = info.localBudget;
            current.nonlocalUsageBytes = info.nonlocalUsage;
            current.nonlocalBudgetBytes = info.nonlocalBudget;
            current.peakLocalUsageBytes = Math.Max(current.peakLocalUsageBytes, info.localUsage);
            current.peakNonlocalUsageBytes = Math.Max(current.peakNonlocalUsageBytes, info.nonlocalUsage);
            current.samples++;
            current.sampleFrame = engineFrame;
            current.hasSamples = current.valid = true;
            current.status = "Ready";
        }

        private static Snapshot Empty(string status) => new Snapshot
        {
            status = status, adapterLuid = "", attemptFrame = -1, sampleFrame = -1, windowFirstFrame = -1
        };
        private void BeginWindow(int engineFrame)
        {
            current = Empty("Pending");
            current.windowFirstFrame = engineFrame;
            windowAdapterLuid = 0;
        }
        private void Unavailable(string reason)
        {
            // A missing/old optional DLL must not throw again every frame or affect GI.
            interopUnavailable = reason;
            Fail(reason);
        }
        private void Fail(string reason)
        {
            current.valid = false;
            current.status = reason;
            current.failedSamples++;
            current.localUsageBytes = current.localBudgetBytes = 0;
            current.nonlocalUsageBytes = current.nonlocalBudgetBytes = 0;
            // sampleFrame, identity and peaks describe the last successful window sample.
        }
    }
}
