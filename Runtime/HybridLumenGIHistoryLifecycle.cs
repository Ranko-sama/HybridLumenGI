using System;

namespace HybridLumenGI
{
    /// <summary>
    /// Per-camera screen-history provenance. URP motion describes the preceding engine
    /// frame, not an arbitrary previous GI render. Completion means all owning render
    /// callbacks recorded successfully on the ordered graphics queue, not a GPU fence.
    /// </summary>
    public sealed class HybridLumenGIHistoryLifecycle
    {
        /// <summary>
        /// Image-coordinate provenance, independent of camera motion and per-frame jitter.
        /// Viewport coordinates are compared exactly; finite offsets outside the target
        /// are allowed. The optional key identifies a projection convention, not a matrix.
        /// Target-object identity is guarded by the owning camera state.
        /// </summary>
        public readonly struct FrameContext : IEquatable<FrameContext>
        {
            public readonly int FullWidth, FullHeight, GiWidth, GiHeight;
            public readonly float ViewportX, ViewportY, ViewportWidth, ViewportHeight;
            public readonly ulong ProjectionContextKey;

            public FrameContext(int fullWidth, int fullHeight, int giWidth, int giHeight,
                float viewportX, float viewportY, float viewportWidth, float viewportHeight,
                ulong projectionContextKey = 0)
            {
                FullWidth=fullWidth;FullHeight=fullHeight;GiWidth=giWidth;GiHeight=giHeight;
                ViewportX=viewportX;ViewportY=viewportY;ViewportWidth=viewportWidth;ViewportHeight=viewportHeight;
                ProjectionContextKey=projectionContextKey;
            }

            public bool IsValid => FullWidth>0 && FullHeight>0 && GiWidth>0 && GiHeight>0 &&
                Finite(ViewportX) && Finite(ViewportY) && Finite(ViewportWidth) && Finite(ViewportHeight) &&
                ViewportWidth>0 && ViewportHeight>0;
            private static bool Finite(float value) => !float.IsNaN(value) && !float.IsInfinity(value);

            public bool Equals(FrameContext other) => FullWidth==other.FullWidth && FullHeight==other.FullHeight &&
                GiWidth==other.GiWidth && GiHeight==other.GiHeight && ViewportX.Equals(other.ViewportX) &&
                ViewportY.Equals(other.ViewportY) && ViewportWidth.Equals(other.ViewportWidth) &&
                ViewportHeight.Equals(other.ViewportHeight) && ProjectionContextKey==other.ProjectionContextKey;
            public override bool Equals(object obj) => obj is FrameContext other && Equals(other);
            public override int GetHashCode()
            {
                unchecked
                {
                    int hash=FullWidth;
                    hash=hash*397^FullHeight;hash=hash*397^GiWidth;hash=hash*397^GiHeight;
                    hash=hash*397^ViewportX.GetHashCode();hash=hash*397^ViewportY.GetHashCode();
                    hash=hash*397^ViewportWidth.GetHashCode();hash=hash*397^ViewportHeight.GetHashCode();
                    return hash*397^ProjectionContextKey.GetHashCode();
                }
            }
        }

        public readonly struct FrameToken
        {
            internal readonly HybridLumenGIHistoryLifecycle Owner;
            internal readonly ulong Sequence;
            internal readonly bool Reusable;
            internal readonly bool HasContext;
            internal readonly FrameContext Context;
            public readonly int EngineFrame;
            internal FrameToken(HybridLumenGIHistoryLifecycle owner, ulong sequence, int frame, bool reusable,
                bool hasContext, FrameContext context)
            { Owner=owner;Sequence=sequence;EngineFrame=frame;Reusable=reusable;HasContext=hasContext;Context=context; }
            public bool IsValid => Owner!=null && Sequence!=0;
        }

        private ulong sequence;
        private bool pending;
        private bool completedHasContext;
        private FrameContext completedContext;
        public bool HasCompletedHistory { get; private set; }
        public int LastCompletedFrame { get; private set; }=-1;

        /// <summary>
        /// Starting a render consumes the prior history receipt. An unfinished, skipped,
        /// repeated or backwards render cannot claim the previous engine frame's history.
        /// No configuration or GPU timing capability is involved in this decision.
        /// </summary>
        public FrameToken BeginFrame(int engineFrame) => BeginFrameCore(engineFrame,false,default);

        /// <summary>
        /// Reuse additionally requires the exact successfully completed image context.
        /// Invalid input revokes history and cannot create a completable receipt. Switching
        /// between context-aware and legacy callers also starts a fresh history.
        /// </summary>
        public FrameToken BeginFrame(int engineFrame, FrameContext context) => BeginFrameCore(engineFrame,true,context);

        private FrameToken BeginFrameCore(int engineFrame, bool hasContext, FrameContext context)
        {
            bool contextValid=!hasContext || context.IsValid;
            bool reuse=engineFrame>=0 && contextValid && HasCompletedHistory && !pending &&
                (long)LastCompletedFrame+1==engineFrame && completedHasContext==hasContext &&
                (!hasContext || completedContext.Equals(context));
            Invalidate();
            if(engineFrame<0 || !contextValid || sequence==ulong.MaxValue) return default;
            pending=true;
            return new FrameToken(this,sequence,engineFrame,reuse,hasContext,context);
        }

        public bool IsCurrent(FrameToken token) => pending && ReferenceEquals(token.Owner,this) &&
            token.Sequence==sequence && token.IsValid;
        public bool CanReuseHistory(FrameToken token) => IsCurrent(token) && token.Reusable;
        /// <summary>Exact successfully published receipt; a frame number alone is not sufficient.</summary>
        public bool IsCompleted(FrameToken token) => HasCompletedHistory && !pending && token.IsValid &&
            ReferenceEquals(token.Owner,this) && token.Sequence==sequence && token.EngineFrame==LastCompletedFrame;

        /// <summary>Only the current render may publish its successfully recorded output once.</summary>
        public bool Complete(FrameToken token)
        {
            if(!IsCurrent(token)) return false;
            pending=false;HasCompletedHistory=true;LastCompletedFrame=token.EngineFrame;
            completedHasContext=token.HasContext;completedContext=token.Context;
            return true;
        }

        /// <summary>Reset/failure revokes both completed history and all outstanding callbacks.</summary>
        public void Invalidate()
        {
            pending=false;HasCompletedHistory=false;LastCompletedFrame=-1;completedHasContext=false;
            if(sequence<ulong.MaxValue) sequence++;
        }
    }
}
