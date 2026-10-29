using System;
using System.Threading;
using UnityEngine;
using UnityEngine.Profiling;

namespace HybridLumenGI
{
    /// <summary>
    /// Conservative per-camera GPU timing feedback. Recorder exposes neither a
    /// query ID nor an atomic elapsed/count pair: the frame association below is
    /// a heuristic based on Unity's documented three-frame GPU-recorder delay.
    /// A caller must retain hard work caps and reset its controller on invalidation.
    /// </summary>
    public sealed class HybridLumenGIGpuTiming : IDisposable
    {
        public enum Scope
        {
            ReceiverCapture=0, Transport=1, Composite=2,
            IdentityClear=3, IdentityMask=4, IdentityCapture=5, IdentityResolve=6
        }
        public enum TimingStatus
        {
            Disabled, Unsupported, Unavailable, WarmingUp, Ready, MissingGpuSample,
            AmbiguousGpuSample, Discontinuous, RepeatedFrame, IncompleteSubmission,
            Invalidated, ChannelLimitReached, Disposed, CommandRecordingFailure
        }

        public readonly struct FrameToken
        {
            public readonly int EngineFrame, Generation;
            public readonly int ActiveScopeMask;
            internal readonly long Owner, Epoch;
            internal FrameToken(int frame, int generation, long owner, long epoch, int activeScopeMask)
            { EngineFrame=frame;Generation=generation;Owner=owner;Epoch=epoch;ActiveScopeMask=activeScopeMask; }
            public bool IsValid => Owner!=0;
        }

        struct Submission
        {
            public FrameToken Token;
            public int Begun, Ended;
            public bool Complete => Token.IsValid && Begun==Token.ActiveScopeMask && Ended==Token.ActiveScopeMask;
        }

        public const int GpuFrameDelay=3;
        public const int RequiredStableFrames=8;
        // CustomSampler has no native marker destruction API. Until retirement can
        // be proven with a native completion/query identity, never reuse a channel
        // for another camera lifetime. Exhaustion explicitly retains static budgets.
        public const int MaximumLifetimeChannels=32;
        const int ScopeCount=7,BaseScopes=7,AllScopes=(1<<ScopeCount)-1,HistoryCapacity=16;
        static long nextOwner;
        static int allocatedChannels;
        readonly long owner=Interlocked.Increment(ref nextOwner);
        readonly CustomSampler[] samplers=new CustomSampler[ScopeCount];
        readonly Recorder[] recorders=new Recorder[ScopeCount];
        readonly bool[] markerCreationAttempted=new bool[ScopeCount];
        readonly Submission[] history=new Submission[HistoryCapacity];
        readonly FrameToken[] openTokens=new FrameToken[ScopeCount];
        readonly bool[] openScopes=new bool[ScopeCount];
        long epoch=1;
        int channel=-1;
        int lastFrame,lastCompletedFrame,generation,stableCompleted,activeScopeMask;
        bool hasFrame,hasCompleted,requestedEnabled,creationAttempted,disposed,currentAllowed,commandRecordingFailed;

        public TimingStatus Status { get; private set; }=TimingStatus.Disabled;
        public FrameToken CurrentFrameToken { get; private set; }
        public int StableCompletedFrames => stableCompleted;
        public double LastMilliseconds { get; private set; }
        /// <summary>Expected f-3 source frame only, not a returned native query/frame ID.</summary>
        public int LastExpectedSourceFrame { get; private set; }=-1;
        public int CameraId { get; }
        public int MarkerChannel => channel;
        public static int AllocatedLifetimeChannels => Volatile.Read(ref allocatedChannels);

        public HybridLumenGIGpuTiming(int cameraId)
        {
            CameraId=cameraId;
        }

        /// <summary>
        /// Call once while preparing this camera's frame, before recording passes.
        /// Store CurrentFrameToken in each pass's data. Only completed previous
        /// submissions contribute to warmup; missing timings are never zero cost.
        /// </summary>
        public bool BeginFrame(int engineFrame,int frameGeneration,bool enabled,out double milliseconds,bool includeReceiverIdentity=false)
        {
            milliseconds=0;LastMilliseconds=0;LastExpectedSourceFrame=-1;
            int requestedScopes=includeReceiverIdentity?AllScopes:BaseScopes;
            if(disposed) { Status=TimingStatus.Disposed;return false; }
            // A throwing BeginSample/EndSample can have appended a native marker
            // before the exception. No public API proves that marker has retired.
            // Never reuse this channel, even after disable/re-enable or warmup.
            if(commandRecordingFailed) { Status=TimingStatus.CommandRecordingFailure;return false; }
            if(hasFrame && engineFrame==lastFrame)
            {
                ClearHistory(TimingStatus.RepeatedFrame);currentAllowed=false;
                // The first call cannot predict a later second render. Its caller
                // must reset a controller that already consumed the earlier result.
                return false;
            }

            TimingStatus resetReason=TimingStatus.WarmingUp;
            bool reset=!hasFrame || requestedEnabled!=enabled || generation!=frameGeneration || activeScopeMask!=requestedScopes;
            if(hasFrame && !reset && engineFrame!=(long)lastFrame+1)
            { reset=true;resetReason=TimingStatus.Discontinuous; }
            if(hasFrame && !reset && currentAllowed && !GetSubmission(CurrentFrameToken).Complete)
            { reset=true;resetReason=TimingStatus.IncompleteSubmission; }
            if(reset) ClearHistory(resetReason);
            hasFrame=true;lastFrame=engineFrame;generation=frameGeneration;requestedEnabled=enabled;
            activeScopeMask=requestedScopes;
            currentAllowed=false;CurrentFrameToken=default;
            if(!enabled)
            { DisableRecorders();ClearHistory(TimingStatus.Disabled);return false; }
            if(!SystemInfo.supportsGpuRecorder)
            { DisableRecorders();ClearHistory(TimingStatus.Unsupported);return false; }
            if(!EnsureRecorders())
            { DisableRecorders();ClearHistory(creationAttempted && channel<0?TimingStatus.ChannelLimitReached:TimingStatus.Unavailable);return false; }

            bool accepted=false;
            if(stableCompleted>=RequiredStableFrames && engineFrame>=GpuFrameDelay)
            {
                int sourceFrame=engineFrame-GpuFrameDelay;
                Submission source=history[Index(sourceFrame)];
                if(source.Complete && source.Token.Owner==owner && source.Token.Epoch==epoch &&
                    source.Token.Generation==generation && source.Token.EngineFrame==sourceFrame &&
                    source.Token.ActiveScopeMask==activeScopeMask)
                {
                    TimingStatus result=ReadMilliseconds(source.Token.ActiveScopeMask,out milliseconds);
                    if(result==TimingStatus.Ready)
                    {
                        accepted=true;LastMilliseconds=milliseconds;LastExpectedSourceFrame=sourceFrame;Status=result;
                    }
                    else
                    {
                        // A lost/ambiguous result has no query identity. Re-establish
                        // a continuous history before reusing this delayed feedback.
                        ClearHistory(result);milliseconds=0;
                    }
                }
                else ClearHistory(TimingStatus.IncompleteSubmission);
            }
            else if(!reset) Status=TimingStatus.WarmingUp;

            CurrentFrameToken=new FrameToken(engineFrame,generation,owner,epoch,activeScopeMask);
            history[Index(engineFrame)]=new Submission { Token=CurrentFrameToken };
            currentAllowed=true;
            return accepted;
        }

        /// <summary>
        /// In a render-function callback, pass the non-null result directly to
        /// CommandBuffer/RasterCommandBuffer.BeginSample(CustomSampler).
        /// Always pair it with RecordEnd and EndSample in a finally block.
        /// </summary>
        public CustomSampler RecordBegin(Scope scope,FrameToken ticket)
        {
            int index=(int)scope;
            if(index<0 || index>=ScopeCount || (ticket.ActiveScopeMask&(1<<index))==0 || !Accepts(ticket)) return null;
            int slot=Index(ticket.EngineFrame),bit=1<<index;
            Submission submission=history[slot];
            if(openScopes[index] || (submission.Begun&bit)!=0)
            { ClearHistory(TimingStatus.RepeatedFrame);return null; }
            submission.Begun|=bit;history[slot]=submission;
            openScopes[index]=true;openTokens[index]=ticket;
            return samplers[index];
        }

        /// <summary>
        /// End an actually opened marker even after Invalidate/Dispose, but never
        /// publish its stale submission as valid timing history.
        /// </summary>
        public CustomSampler RecordEnd(Scope scope,FrameToken ticket)
        {
            int index=(int)scope;
            if(index<0 || index>=ScopeCount || !openScopes[index] || !Same(openTokens[index],ticket)) return null;
            openScopes[index]=false;
            if(Accepts(ticket))
            {
                int slot=Index(ticket.EngineFrame);
                Submission submission=history[slot];submission.Ended|=1<<index;history[slot]=submission;
                if(submission.Complete)
                {
                    stableCompleted=hasCompleted && ticket.EngineFrame==(long)lastCompletedFrame+1?
                        Math.Min(stableCompleted+1,RequiredStableFrames):1;
                    lastCompletedFrame=ticket.EngineFrame;hasCompleted=true;
                }
            }
            return samplers[index];
        }

        /// <summary>Reject pending feedback, e.g. after an actual backend fallback.</summary>
        public void Invalidate()
        {
            if(!disposed) ClearHistory(commandRecordingFailed?TimingStatus.CommandRecordingFailure:TimingStatus.Invalidated);
        }

        /// <summary>
        /// Permanently reject this channel after a CustomSampler command emission
        /// throws. This is not for canceled graphs or missing GPU observations.
        /// Existing open markers may still be paired by RecordEnd, but this instance
        /// can never submit or read feedback again. Its lifetime channel stays leased.
        /// </summary>
        public void RejectCommandRecording()
        {
            if(disposed || commandRecordingFailed) return;
            commandRecordingFailed=true;DisableRecorders();ClearHistory(TimingStatus.CommandRecordingFailure);
        }

        bool Accepts(FrameToken token) => !disposed && !commandRecordingFailed && currentAllowed && token.IsValid && Same(token,CurrentFrameToken);
        static bool Same(FrameToken a,FrameToken b) => a.Owner==b.Owner && a.Epoch==b.Epoch &&
            a.EngineFrame==b.EngineFrame && a.Generation==b.Generation && a.ActiveScopeMask==b.ActiveScopeMask;
        static int Index(int frame) => (int)((uint)frame%HistoryCapacity);
        Submission GetSubmission(FrameToken token)
        {
            Submission value=history[Index(token.EngineFrame)];
            return Same(value.Token,token)?value:default;
        }

        bool EnsureRecorders()
        {
            // No inactive GPU result is queried, and an unavailable optional marker
            // cannot make the baseline mode depend on that marker's native handle.
            for(int i=0;i<ScopeCount;i++) if((activeScopeMask&(1<<i))==0)
            {
                try { if(recorders[i]!=null) recorders[i].enabled=false; }
                catch(Exception) { /* No marker is emitted or sampled for this scope. */ }
            }
            try
            {
                if(!creationAttempted)
                {
                    creationAttempted=true;
                    channel=ClaimChannel();
                    if(channel<0) return false;
                }
                if(channel<0) return false;
                // At most seven names per lifetime channel (224 globally). Lazily
                // create only scopes used by this camera; never retry a failed name.
                for(int i=0;i<ScopeCount;i++)
                {
                    if((activeScopeMask&(1<<i))==0) continue;
                    if(!markerCreationAttempted[i])
                    {
                        markerCreationAttempted[i]=true;
                        samplers[i]=CustomSampler.Create("HLGI.GpuFeedback.Channel"+channel+"."+((Scope)i),true);
                        if(samplers[i]==null || !samplers[i].isValid) return false;
                        recorders[i]=samplers[i].GetRecorder();
                    }
                    if(samplers[i]==null || !samplers[i].isValid || recorders[i]==null || !recorders[i].isValid) return false;
                    if(!recorders[i].enabled) recorders[i].enabled=true;
                }
                return true;
            }
            catch(Exception) { return false; }
        }

        static int ClaimChannel()
        {
            while(true)
            {
                int current=Volatile.Read(ref allocatedChannels);
                if(current>=MaximumLifetimeChannels) return -1;
                if(Interlocked.CompareExchange(ref allocatedChannels,current+1,current)==current) return current;
            }
        }

        TimingStatus ReadMilliseconds(int mask,out double milliseconds)
        {
            milliseconds=0;
            try
            {
                double total=0,identityTotal=0;
                for(int i=0;i<ScopeCount;i++)
                {
                    if((mask&(1<<i))==0) continue;
                    Recorder recorder=recorders[i];
                    if(recorder==null || !recorder.isValid || !recorder.enabled) return TimingStatus.Unavailable;
                    int count=recorder.gpuSampleBlockCount;
                    if(count!=1) return count>1?TimingStatus.AmbiguousGpuSample:TimingStatus.MissingGpuSample;
                    long nanoseconds=recorder.gpuElapsedNanoseconds;
                    int countAfter=recorder.gpuSampleBlockCount;
                    // The second count read detects some torn/changed results;
                    // equal counts do not make these public properties atomic.
                    if(countAfter!=1) return TimingStatus.AmbiguousGpuSample;
                    if(nanoseconds<0 || (i<3 && nanoseconds==0)) return TimingStatus.MissingGpuSample;
                    if(i>=3) identityTotal+=nanoseconds;
                    total+=nanoseconds*1e-6;
                }
                // Individual empty mask/capture passes may round to zero. All four
                // must still have one sample, and their combined work must be visible.
                if(mask==AllScopes && identityTotal<=0) return TimingStatus.MissingGpuSample;
                milliseconds=total;return TimingStatus.Ready;
            }
            catch(Exception) { return TimingStatus.Unavailable; }
        }

        void ClearHistory(TimingStatus reason)
        {
            epoch++;Array.Clear(history,0,history.Length);stableCompleted=0;hasCompleted=false;
            currentAllowed=false;CurrentFrameToken=default;Status=reason;
            LastMilliseconds=0;LastExpectedSourceFrame=-1;
            // Do not erase openTokens: a previously emitted BeginSample still
            // requires an EndSample even though its timing history is now invalid.
        }

        void DisableRecorders()
        {
            for(int i=0;i<ScopeCount;i++)
            {
                try { if(recorders[i]!=null) recorders[i].enabled=false; }
                catch(Exception) { /* Unsupported/tearing-down native recorder. */ }
            }
        }

        public void Dispose()
        {
            if(disposed) return;
            disposed=true;DisableRecorders();ClearHistory(TimingStatus.Disposed);
            // Recorder has no public Dispose in Unity 6; disable it and let its
            // own finalizer release native recording handles. Sampler has no Dispose.
        }
    }
}
