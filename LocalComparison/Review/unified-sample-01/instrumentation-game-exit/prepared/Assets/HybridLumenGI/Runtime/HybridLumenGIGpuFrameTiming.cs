using System;
using UnityEngine.Profiling;
using UnityEngine.Rendering;

namespace HybridLumenGI
{
    /// <summary>
    /// One frozen frame's optional timing commands. Recorder markers are local to a
    /// pass; native ABI1 brackets the complete receiver capture/identity chain.
    /// Timing failures never escape into rendering. This does not establish GPU
    /// execution or remove Recorder's delayed, unidentified-sample limitations.
    /// </summary>
    public sealed class HybridLumenGIGpuFrameTiming
    {
        public enum Phase
        {
            ReceiverCapture, IdentityClear, IdentityMask, IdentityCapture,
            IdentityResolve, Transport, Composite
        }

        readonly HybridLumenGIGpuTiming recorder;
        readonly HybridLumenGINativeGpuTiming native;
        readonly HybridLumenGIGpuTiming.FrameToken recorderToken;
        readonly HybridLumenGINativeGpuTiming.FrameToken nativeToken;
        readonly bool useNative, includeIdentity, enabled;
        readonly Action invalidateFeedback;
        readonly int required;
        readonly CustomSampler[] opened = new CustomSampler[7];
        int next, active = -1, ended;
        bool invalid, resolved, notified, diagnosticFailed;

        public HybridLumenGIGpuFrameTiming(HybridLumenGIGpuTiming recorder,
            HybridLumenGINativeGpuTiming native, bool useNative, bool includeIdentity,
            Action invalidateFeedback)
        {
            this.recorder = recorder; this.native = native; this.useNative = useNative;
            this.includeIdentity = includeIdentity; this.invalidateFeedback = invalidateFeedback;
            recorderToken = recorder == null ? default : recorder.CurrentFrameToken;
            nativeToken = native == null ? default : native.CurrentFrameToken;
            enabled = useNative ? nativeToken.IsValid : recorderToken.IsValid;
            required = includeIdentity ? 0x7f : 0x61;
        }

        // Fixed Core/Graphics feb4de2d exposes GetNativeCommandBuffer only for
        // UnsafeCommandBuffer. RasterCommandBuffer exposes these three operations
        // directly; never cast/extract its internal wrapped native buffer.
        public void Begin(Phase phase, CommandBuffer cmd) => BeginCore(phase, new Commands(cmd));
        public void End(Phase phase, CommandBuffer cmd) => EndCore(phase, new Commands(cmd));
        public void Begin(Phase phase, RasterCommandBuffer cmd) => BeginCore(phase, new Commands(cmd));
        public void End(Phase phase, RasterCommandBuffer cmd) => EndCore(phase, new Commands(cmd));

        /// <summary>
        /// Optional diagnostic markers remain available with feedback disabled.
        /// Marker errors are isolated from the using body. The returned value type
        /// must not be copied and disposed independently; a normal using scope does
        /// not box or allocate it, and repeated Dispose on one instance is harmless.
        /// </summary>
        public DiagnosticScope Profile(CommandBuffer cmd, string name)
        {
            if (diagnosticFailed) return default;
            try
            {
                cmd.BeginSample(name);
                return new DiagnosticScope(this, cmd, name);
            }
            catch
            {
                Invalidate();
                RejectRecorderCommand();
                return default;
            }
        }

        public struct DiagnosticScope : IDisposable
        {
            readonly HybridLumenGIGpuFrameTiming owner;
            readonly CommandBuffer cmd;
            readonly string name;
            bool disposed;
            internal DiagnosticScope(HybridLumenGIGpuFrameTiming owner, CommandBuffer cmd, string name)
            { this.owner = owner; this.cmd = cmd; this.name = name; disposed = false; }
            public void Dispose()
            {
                if (disposed || owner == null) return;
                disposed = true;
                try { cmd.EndSample(name); }
                catch
                {
                    owner.Invalidate();
                    owner.RejectRecorderCommand();
                }
            }
        }

        void BeginCore(Phase phase, Commands commands)
        {
            if (!enabled || invalid || !IsCurrent()) return;
            int value = (int)phase;
            if (resolved || value < 0 || value > 6 || (required & (1 << value)) == 0 ||
                value != next || active != -1)
            { Invalidate(); return; }
            active = value;
            CustomSampler sampler = null;
            try
            {
                if (useNative)
                {
                    if (NativeScope(phase, out var scope))
                    {
                        if (!native.TryRecordBegin(scope, nativeToken, out var command))
                        { Invalidate(); return; }
                        commands.Event(command);
                    }
                }
                else
                {
                    sampler = recorder.RecordBegin(RecorderScope(phase), recorderToken);
                    if (sampler == null) { Invalidate(); return; }
                    try { commands.Begin(sampler); }
                    catch
                    {
                        try { recorder.RecordEnd(RecorderScope(phase), recorderToken); }
                        catch { }
                        Invalidate();
                        RejectRecorderCommand();
                        return;
                    }
                    // Only a returned BeginSample is known to have recorded a marker.
                    // A throwing command invalidates feedback; do not invent an End
                    // for a marker whose native recording outcome is unknown.
                    opened[value] = sampler;
                }
            }
            catch
            {
                if (sampler != null && opened[value] == null)
                {
                    try { recorder.RecordEnd(RecorderScope(phase), recorderToken); }
                    catch { /* Only release the CPU open-marker bookkeeping. */ }
                }
                Invalidate();
            }
        }

        void EndCore(Phase phase, Commands commands)
        {
            if (!enabled) return;
            int value = (int)phase;
            if (value < 0 || value > 6) { Invalidate(); return; }
            // Cleanup is deliberately before the current-token/invalid guard:
            // an opened Recorder marker needs its same-pass End even after reset.
            // Remove it first so exceptions and repeated finally calls cannot retry.
            CustomSampler sampler = opened[value];
            if (sampler != null)
            {
                opened[value] = null;
                CustomSampler endedSampler = null;
                bool failed = false, commandFailed = false;
                try { endedSampler = recorder.RecordEnd(RecorderScope(phase), recorderToken); }
                catch { failed = true; }
                try { commands.End(sampler); }
                catch { failed = true; commandFailed = true; }
                if (failed || !ReferenceEquals(endedSampler, sampler)) Invalidate();
                if (commandFailed) RejectRecorderCommand();
            }
            if (invalid || !IsCurrent()) return;
            if (resolved || value != next || active != value || (required & (1 << value)) == 0)
            { Invalidate(); return; }
            try
            {
                if (useNative)
                {
                    bool emit = NativeScope(phase, out var scope);
                    if (phase == Phase.ReceiverCapture && includeIdentity) emit = false;
                    if (phase == Phase.IdentityResolve)
                    { scope = HybridLumenGINativeGpuTiming.Scope.ReceiverCapture; emit = true; }
                    if (emit)
                    {
                        if (!native.TryRecordEnd(scope, nativeToken, out var command))
                        { Invalidate(); return; }
                        commands.Event(command);
                    }
                }
                else if (sampler == null) { Invalidate(); return; }
                ended |= 1 << value;
                active = -1;
                do { next++; } while (next < 7 && (required & (1 << next)) == 0);
            }
            catch { Invalidate(); }
        }

        /// <summary>Native query resolution must be in a separate Unsafe pass.</summary>
        public void Resolve(CommandBuffer cmd)
        {
            if (!enabled || invalid || !IsCurrent()) return;
            if (resolved || active != -1 || ended != required || next != 7)
            { Invalidate(); return; }
            resolved = true;
            if (!useNative) return;
            try
            {
                if (!native.TryResolve(nativeToken, out var command)) { Invalidate(); return; }
                new Commands(cmd).Event(command);
            }
            catch { Invalidate(); }
        }

        public void Invalidate()
        {
            if (invalid) return;
            invalid = true;
            // Never revoke another frame after an old RenderGraph callback arrives.
            if (!enabled || notified || !IsCurrent()) return;
            notified = true;
            try
            {
                if (invalidateFeedback != null) invalidateFeedback();
                // A callback can reset the owner's controller and both providers.
                // A no-op callback must not leave an already completed sample live.
                if (IsCurrent()) InvalidateProvider();
            }
            catch { try { if (IsCurrent()) InvalidateProvider(); } catch { } }
        }

        void InvalidateProvider()
        {
            if (useNative) native.Invalidate();
            else recorder.Invalidate();
        }

        void RejectRecorderCommand()
        {
            diagnosticFailed = true;
            // A throwing native marker command may already have appended work.
            // Never reuse this Recorder's channel, even when an old marker's late
            // End failed after the frame advanced. Do not revoke the new owner's
            // controller through the old frame callback; only retire the channel.
            try { recorder.RejectCommandRecording(); } catch { }
        }

        bool IsCurrent()
        {
            if (useNative)
            {
                var token = native.CurrentFrameToken;
                return token.IsValid && token.Id == nativeToken.Id && token.Owner == nativeToken.Owner &&
                    token.DeviceEpoch == nativeToken.DeviceEpoch && token.Epoch == nativeToken.Epoch &&
                    token.EngineFrame == nativeToken.EngineFrame && token.Generation == nativeToken.Generation;
            }
            var current = recorder.CurrentFrameToken;
            return current.IsValid && current.Owner == recorderToken.Owner && current.Epoch == recorderToken.Epoch &&
                current.EngineFrame == recorderToken.EngineFrame && current.Generation == recorderToken.Generation &&
                current.ActiveScopeMask == recorderToken.ActiveScopeMask;
        }

        static HybridLumenGIGpuTiming.Scope RecorderScope(Phase phase)
        {
            switch (phase)
            {
                case Phase.ReceiverCapture: return HybridLumenGIGpuTiming.Scope.ReceiverCapture;
                case Phase.Transport: return HybridLumenGIGpuTiming.Scope.Transport;
                case Phase.Composite: return HybridLumenGIGpuTiming.Scope.Composite;
                case Phase.IdentityClear: return HybridLumenGIGpuTiming.Scope.IdentityClear;
                case Phase.IdentityMask: return HybridLumenGIGpuTiming.Scope.IdentityMask;
                case Phase.IdentityCapture: return HybridLumenGIGpuTiming.Scope.IdentityCapture;
                default: return HybridLumenGIGpuTiming.Scope.IdentityResolve;
            }
        }

        static bool NativeScope(Phase phase, out HybridLumenGINativeGpuTiming.Scope scope)
        {
            scope = phase == Phase.Transport ? HybridLumenGINativeGpuTiming.Scope.Transport :
                phase == Phase.Composite ? HybridLumenGINativeGpuTiming.Scope.Composite :
                HybridLumenGINativeGpuTiming.Scope.ReceiverCapture;
            return phase == Phase.ReceiverCapture || phase == Phase.Transport || phase == Phase.Composite;
        }

        readonly struct Commands
        {
            readonly CommandBuffer raw;
            readonly RasterCommandBuffer raster;
            public Commands(CommandBuffer cmd) { raw = cmd; raster = null; }
            public Commands(RasterCommandBuffer cmd) { raw = null; raster = cmd; }
            public void Begin(CustomSampler sampler)
            { if (raw != null) raw.BeginSample(sampler); else raster.BeginSample(sampler); }
            public void End(CustomSampler sampler)
            { if (raw != null) raw.EndSample(sampler); else raster.EndSample(sampler); }
            public void Event(HybridLumenGINativeGpuTiming.PluginEvent command)
            {
                if (raw != null) raw.IssuePluginEventAndData(command.Callback, command.EventId, command.Data);
                else raster.IssuePluginEventAndData(command.Callback, command.EventId, command.Data);
            }
        }
    }
}
