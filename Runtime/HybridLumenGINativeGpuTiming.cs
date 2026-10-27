using System;
using System.Runtime.InteropServices;
using System.Threading;
using UnityEngine;
using UnityEngine.Rendering;

namespace HybridLumenGI
{
    /// <summary>
    /// Optional DX12 timestamp bridge. Plugin data is an opaque positive integer, never a
    /// managed/native payload pointer. Native cancellation must retire GPU query storage
    /// behind its fence even after this managed owner has been disposed.
    /// </summary>
    public sealed class HybridLumenGINativeGpuTiming : IDisposable
    {
        public enum Scope { ReceiverCapture, Transport, Composite }
        public enum TimingStatus
        {
            Disabled, Unsupported, Unavailable, IncompatibleApi, Uninitialized, AllocationFailure,
            RetiredLimit, DeviceLost, Pending, Ready, RingFull, InvalidResult, InvalidSequence,
            RepeatedFrame, InvalidFrame, Invalidated, Disposed
        }
        public readonly struct FrameToken
        {
            public readonly int EngineFrame, Generation;
            internal readonly ulong Id, Owner, DeviceEpoch;
            internal readonly long Epoch;
            internal FrameToken(ulong id, ulong owner, ulong deviceEpoch, int frame, int generation, long epoch)
            { Id=id;Owner=owner;DeviceEpoch=deviceEpoch;EngineFrame=frame;Generation=generation;Epoch=epoch; }
            public bool IsValid => Id>0 && Id<=long.MaxValue;
        }
        public readonly struct PluginEvent
        {
            public readonly IntPtr Callback, Data;
            public readonly int EventId;
            internal PluginEvent(IntPtr callback, int eventId, ulong token)
            { Callback=callback;EventId=eventId;Data=new IntPtr((long)token); }
        }

        [StructLayout(LayoutKind.Sequential, Pack=8)]
        internal struct ApiInfo
        {
            internal uint abiVersion,structSize,status,capacity;
            internal int eventBase;
            internal uint reserved;
            internal ulong deviceEpoch,frequency;
            internal IntPtr callback;
        }
        [StructLayout(LayoutKind.Sequential, Pack=8)]
        internal struct Result
        {
            internal ulong token,owner,generation,deviceEpoch;
            internal long engineFrame;
            internal ulong frequency;
            internal ulong begin0,end0,begin1,end1,begin2,end2;
        }
        internal interface INativeApi
        {
            bool IsSupported { get; }
            int GetInfo(out ApiInfo info, uint size);
            ulong Acquire(ulong owner, ulong generation, long frame);
            int Poll(ulong token, out Result result, uint size);
            void Cancel(ulong token);
        }
        private sealed class NativeApi : INativeApi
        {
            private const string Library="HybridLumenGIGpuTiming";
            public bool IsSupported => IntPtr.Size==8 &&
                (Application.platform==RuntimePlatform.WindowsEditor || Application.platform==RuntimePlatform.WindowsPlayer) &&
                SystemInfo.graphicsDeviceType==GraphicsDeviceType.Direct3D12;
            [DllImport(Library,CallingConvention=CallingConvention.Cdecl,ExactSpelling=true)]
            private static extern int HLGI_Timing_GetInfo(out ApiInfo info,uint size);
            [DllImport(Library,CallingConvention=CallingConvention.Cdecl,ExactSpelling=true)]
            private static extern ulong HLGI_Timing_Acquire(ulong owner,ulong generation,long frame);
            [DllImport(Library,CallingConvention=CallingConvention.Cdecl,ExactSpelling=true)]
            private static extern int HLGI_Timing_Poll(ulong token,out Result result,uint size);
            [DllImport(Library,CallingConvention=CallingConvention.Cdecl,ExactSpelling=true)]
            private static extern void HLGI_Timing_Cancel(ulong token);
            public int GetInfo(out ApiInfo info,uint size) => HLGI_Timing_GetInfo(out info,size);
            public ulong Acquire(ulong owner,ulong generation,long frame) => HLGI_Timing_Acquire(owner,generation,frame);
            public int Poll(ulong token,out Result result,uint size) => HLGI_Timing_Poll(token,out result,size);
            public void Cancel(ulong token) => HLGI_Timing_Cancel(token);
        }
        private struct PendingSubmission
        {
            internal FrameToken Token;
            internal byte Begun,Ended;
            internal bool Resolved;
        }
        public const int MaximumPendingSubmissions=32,MaximumResultAgeFrames=32;
        private const uint ApiSize=48,ResultSize=96;
        private static long nextOwner;
        private readonly ulong owner=(ulong)Interlocked.Increment(ref nextOwner);
        private readonly INativeApi api;
        private readonly PendingSubmission[] pending=new PendingSubmission[MaximumPendingSubmissions];
        private ApiInfo info;
        private long epoch=1;
        private int lastFrame,generation,lastAcceptedSourceFrame=-1;
        private ulong lastIssuedId,lastAcceptedId;
        private bool hasFrame,disposed,interopUnavailable;

        public bool Available { get; private set; }
        public ulong DeviceEpoch => info.deviceEpoch;
        public TimingStatus Status { get; private set; }=TimingStatus.Disabled;
        public FrameToken CurrentFrameToken { get; private set; }
        public int PendingCount { get; private set; }
        public int LastMeasuredSourceFrame { get; private set; }=-1;
        public double LastMilliseconds { get; private set; }
        public ulong AcceptedResults { get; private set; }
        public ulong RejectedResults { get; private set; }
        public HybridLumenGINativeGpuTiming(int cameraId) : this(new NativeApi()) { }
        internal HybridLumenGINativeGpuTiming(INativeApi nativeApi)
        { api=nativeApi??throw new ArgumentNullException(nameof(nativeApi)); }

        /// <summary>
        /// Poll completed native submissions once, then reserve the current one. A full
        /// ring or absent result does not change Available and must not switch providers.
        /// Result identity is checked against the exact reserved ticket, not a frame delay.
        /// </summary>
        public bool BeginFrame(int engineFrame,int frameGeneration,bool enabled,out double milliseconds)
        {
            milliseconds=0;LastMilliseconds=0;LastMeasuredSourceFrame=-1;
            if(disposed) { Available=false;Status=TimingStatus.Disposed;return false; }
            if(!enabled)
            { ClearPending();hasFrame=false;Available=false;Status=TimingStatus.Disabled;return false; }
            if(!RefreshInfo()) return false;
            if(engineFrame<0)
            { ClearPending();hasFrame=false;Status=TimingStatus.InvalidFrame;return false; }
            if(hasFrame && engineFrame==lastFrame)
            { ClearPending();Status=TimingStatus.RepeatedFrame;return false; }
            if(!hasFrame || generation!=frameGeneration || engineFrame!=(long)lastFrame+1)
                ClearPending();
            else if(CurrentFrameToken.IsValid)
            {
                int previous=Find(CurrentFrameToken);
                if(previous>=0 && !pending[previous].Resolved) ClearPending();
            }
            if(interopUnavailable) { FailInterop();return false; }
            hasFrame=true;lastFrame=engineFrame;generation=frameGeneration;CurrentFrameToken=default;

            bool accepted=false;
            int newestFrame=-1;
            ulong newestId=0;
            Status=TimingStatus.Pending;
            for(int i=0;i<pending.Length;i++)
            {
                PendingSubmission submission=pending[i];
                if(!submission.Token.IsValid) continue;
                long age=(long)engineFrame-submission.Token.EngineFrame;
                if(age<0 || age>MaximumResultAgeFrames)
                { CancelAt(i);continue; }
                Result result;
                int code;
                try { code=api.Poll(submission.Token.Id,out result,ResultSize); }
                catch(Exception) { FailInterop();return false; }
                if(code==0) continue;
                if(code==-2)
                { ClearPending();Available=false;Status=TimingStatus.DeviceLost;return false; }
                // Success and -3 consume their native result. Unknown errors are cancelled.
                if(code!=1 && code!=-3 && code!=-1) CancelAt(i);
                else RemoveAt(i);
                if(code!=1 || !Validate(submission,result,engineFrame,out double value) ||
                    result.engineFrame<=lastAcceptedSourceFrame || result.token<=lastAcceptedId)
                { Reject();Status=TimingStatus.InvalidResult;continue; }
                if(result.engineFrame>newestFrame || (result.engineFrame==newestFrame && result.token>newestId))
                { accepted=true;newestFrame=(int)result.engineFrame;newestId=result.token;milliseconds=value; }
            }
            if(interopUnavailable) { FailInterop();milliseconds=0;return false; }
            if(accepted)
            {
                lastAcceptedSourceFrame=newestFrame;lastAcceptedId=newestId;
                LastMeasuredSourceFrame=newestFrame;LastMilliseconds=milliseconds;
                if(AcceptedResults<ulong.MaxValue) AcceptedResults++;
                Status=TimingStatus.Ready;
            }

            // CPU tracking stays bounded even when native submissions never complete.
            if(PendingCount==pending.Length)
            {
                int oldest=0;
                for(int i=1;i<pending.Length;i++)
                    if(pending[i].Token.EngineFrame<pending[oldest].Token.EngineFrame) oldest=i;
                CancelAt(oldest);
            }
            if(interopUnavailable) { FailInterop();milliseconds=0;return false; }
            ulong id;
            try { id=api.Acquire(owner,(ulong)(uint)frameGeneration,engineFrame); }
            catch(Exception) { FailInterop();milliseconds=0;return false; }
            if(id==0) { Status=TimingStatus.RingFull;return accepted; }
            if(id>long.MaxValue || id<=lastIssuedId)
            {
                TryCancel(id);ClearPending();interopUnavailable=true;Available=false;Status=TimingStatus.IncompatibleApi;
                milliseconds=0;return false;
            }
            lastIssuedId=id;
            CurrentFrameToken=new FrameToken(id,owner,info.deviceEpoch,engineFrame,frameGeneration,epoch);
            for(int i=0;i<pending.Length;i++) if(!pending[i].Token.IsValid)
            { pending[i]=new PendingSubmission { Token=CurrentFrameToken };PendingCount++;break; }
            return accepted;
        }

        public bool TryRecordBegin(Scope scope,FrameToken token,out PluginEvent pluginEvent)
        {
            pluginEvent=default;int value=(int)scope,index=FindCurrent(token);
            if(value<0 || value>2 || index<0) return false;
            int bit=1<<value;
            if(pending[index].Begun!=(bit-1) || pending[index].Ended!=(bit-1) || pending[index].Resolved)
                return RejectSequence();
            pending[index].Begun|=(byte)bit;
            pluginEvent=new PluginEvent(info.callback,info.eventBase+value*2,token.Id);return true;
        }
        public bool TryRecordEnd(Scope scope,FrameToken token,out PluginEvent pluginEvent)
        {
            pluginEvent=default;int value=(int)scope,index=FindCurrent(token);
            if(value<0 || value>2 || index<0) return false;
            int bit=1<<value;
            if(pending[index].Begun!=((bit<<1)-1) || pending[index].Ended!=(bit-1) || pending[index].Resolved)
                return RejectSequence();
            pending[index].Ended|=(byte)bit;
            pluginEvent=new PluginEvent(info.callback,info.eventBase+value*2+1,token.Id);return true;
        }
        /// <summary>Record this event outside native raster passes, after all three scopes.</summary>
        public bool TryResolve(FrameToken token,out PluginEvent pluginEvent)
        {
            pluginEvent=default;int index=FindCurrent(token);
            if(index<0) return false;
            if(pending[index].Begun!=7 || pending[index].Ended!=7 || pending[index].Resolved) return RejectSequence();
            pending[index].Resolved=true;
            pluginEvent=new PluginEvent(info.callback,info.eventBase+6,token.Id);return true;
        }

        private bool RefreshInfo()
        {
            if(interopUnavailable) { Available=false;Status=TimingStatus.Unavailable;return false; }
            ApiInfo next;
            try
            {
                if(!api.IsSupported) { ClearPending();Available=false;Status=TimingStatus.Unsupported;return false; }
                if(api.GetInfo(out next,ApiSize)!=1) { ClearPending();Available=false;Status=TimingStatus.Unavailable;return false; }
            }
            catch(Exception) { FailInterop();return false; }
            if(next.abiVersion!=1 || next.structSize!=ApiSize)
            { ClearPending();Available=false;Status=TimingStatus.IncompatibleApi;return false; }
            if(next.status!=1)
            {
                ClearPending();Available=false;
                Status=next.status==0?TimingStatus.Unsupported:next.status==2?TimingStatus.DeviceLost:
                    next.status==3?TimingStatus.AllocationFailure:next.status==4?TimingStatus.RetiredLimit:
                    next.status==5?TimingStatus.Uninitialized:TimingStatus.IncompatibleApi;
                return false;
            }
            if(next.capacity==0 || next.callback==IntPtr.Zero || next.frequency==0 || next.deviceEpoch==0 ||
                next.eventBase<0 || next.eventBase>int.MaxValue-6)
            { ClearPending();Available=false;Status=TimingStatus.IncompatibleApi;return false; }
            if(info.deviceEpoch!=next.deviceEpoch || info.frequency!=next.frequency || info.callback!=next.callback || info.eventBase!=next.eventBase)
                ClearPending();
            if(interopUnavailable) { Available=false;Status=TimingStatus.Unavailable;return false; }
            info=next;Available=true;return true;
        }
        private bool Validate(PendingSubmission submission,Result value,int engineFrame,out double milliseconds)
        {
            milliseconds=0;FrameToken token=submission.Token;
            if(!submission.Resolved || submission.Begun!=7 || submission.Ended!=7 ||
                value.token!=token.Id || value.owner!=token.Owner || value.generation!=(ulong)(uint)token.Generation ||
                value.deviceEpoch!=token.DeviceEpoch || value.deviceEpoch!=info.deviceEpoch || value.engineFrame!=token.EngineFrame ||
                value.frequency!=info.frequency || value.frequency==0 || (long)engineFrame-value.engineFrame>MaximumResultAgeFrames ||
                value.end0<value.begin0 || value.begin1<value.end0 || value.end1<value.begin1 ||
                value.begin2<value.end1 || value.end2<value.begin2) return false;
            milliseconds=((double)(value.end0-value.begin0)+(value.end1-value.begin1)+(value.end2-value.begin2))*1000.0/value.frequency;
            return milliseconds>0 && !double.IsNaN(milliseconds) && !double.IsInfinity(milliseconds);
        }
        private int Find(FrameToken token)
        {
            for(int i=0;i<pending.Length;i++)
            {
                FrameToken other=pending[i].Token;
                if(other.Id==token.Id && other.Owner==token.Owner && other.DeviceEpoch==token.DeviceEpoch &&
                    other.EngineFrame==token.EngineFrame && other.Generation==token.Generation && other.Epoch==token.Epoch) return i;
            }
            return -1;
        }
        private int FindCurrent(FrameToken token) => !disposed && Available && token.IsValid && token.Epoch==epoch &&
            token.Id==CurrentFrameToken.Id && token.Owner==owner ? Find(token) : -1;
        private bool RejectSequence() { ClearPending();Status=TimingStatus.InvalidSequence;return false; }
        private void Reject() { if(RejectedResults<ulong.MaxValue) RejectedResults++; }
        private void RemoveAt(int index) { pending[index]=default;PendingCount--; }
        private void CancelAt(int index) { TryCancel(pending[index].Token.Id);RemoveAt(index); }
        private void TryCancel(ulong token)
        {
            if(token==0) return;
            try { api.Cancel(token); }
            catch(Exception) { interopUnavailable=true;Available=false; }
        }
        private void ClearPending()
        {
            for(int i=0;i<pending.Length;i++) if(pending[i].Token.IsValid) CancelAt(i);
            CurrentFrameToken=default;epoch++;lastAcceptedSourceFrame=-1;
            LastMilliseconds=0;LastMeasuredSourceFrame=-1;
        }
        private void FailInterop()
        { ClearPending();interopUnavailable=true;Available=false;Status=TimingStatus.Unavailable; }
        public void Invalidate()
        { if(!disposed) { ClearPending();Status=interopUnavailable?TimingStatus.Unavailable:TimingStatus.Invalidated; } }
        public void Dispose()
        {
            if(disposed) return;
            ClearPending();disposed=true;Available=false;Status=TimingStatus.Disposed;
        }
    }
}
