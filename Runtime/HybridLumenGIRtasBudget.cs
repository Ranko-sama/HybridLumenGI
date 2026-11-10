using System;
using System.Collections.Generic;
using System.Diagnostics;

namespace HybridLumenGI
{
    /// <summary>
    /// Main-thread, all-camera RTAS admission. Work credits are counters, not GPU milliseconds.
    /// Unity provides no prebuild allocation upper bound: estimates and observed GetSize high-water
    /// values are reported separately. A reservation remains counted until its native object was
    /// actually destroyed after a completion fence. Demand expiry never releases GPU resources.
    /// </summary>
    public static class HybridLumenGIRtasBudget
    {
        public struct Settings
        {
            public long MemoryBudgetBytes,TriangleWorkPerFrame,InstanceWorkPerFrame,TriangleBurstCapacity,InstanceBurstCapacity;
            public long BaseEstimateBytes,BytesPerTriangle,BytesPerInstance;
            public int MaxBuildsPerFrame;
            public float BuildRecordingCpuBudgetMilliseconds;
            public static Settings Default=>new Settings{MemoryBudgetBytes=256L*1024*1024,MaxBuildsPerFrame=4,
                TriangleWorkPerFrame=250000,InstanceWorkPerFrame=4096,TriangleBurstCapacity=1000000,InstanceBurstCapacity=16384,
                BaseEstimateBytes=65536,BytesPerTriangle=192,BytesPerInstance=1024};
        }
        public sealed class Reservation
        {
            internal bool retired,released;
            public long EstimatedBytes { get; internal set; }
            public long MeasuredHighWaterBytes { get; internal set; }
            public long AccountedBytes=>Math.Max(EstimatedBytes,MeasuredHighWaterBytes);
            public bool IsRetired=>retired;
        }
        private sealed class Demand
        {internal object owner;internal long sequence;internal int lastFrame;internal long reservedFrame,triangles,instances;}
        private static readonly List<Reservation> reservations=new List<Reservation>();
        private static readonly List<Demand> demands=new List<Demand>();
        private static Settings settings=Settings.Default;
        private static bool initialized;
        private static long triangleCredits,instanceCredits,sequence,buildRecordingTicks;
        public static int Frame { get; private set; }=int.MinValue;
        public static int BuildsThisFrame { get; private set; }
        public static long TriangleWorkThisFrame { get; private set; }
        public static long InstanceWorkThisFrame { get; private set; }
        public static long TriangleCredits=>triangleCredits;
        public static long InstanceCredits=>instanceCredits;
        public static int PendingDemands=>demands.Count;
        private static bool BuildRecordingBudgetSpent => buildRecordingTicks >=
            Math.Max(1d, settings.BuildRecordingCpuBudgetMilliseconds * (Stopwatch.Frequency / 1000d));
        // Check the current queue without adding a demand for a speculative handoff.
        internal static bool IsBuildTurnBlocked(object owner)
        {
            // A handoff that needs RTAS work requires at least one triangle and one instance.
            // Only wait when that minimum can still be admitted on a future turn.
            if (!CanScheduleBuild(1, 1, out _)) return false;
            if (BuildsThisFrame >= settings.MaxBuildsPerFrame || triangleCredits == 0 || instanceCredits == 0 ||
                BuildRecordingBudgetSpent) return true;
            Demand oldest = OldestActiveDemand();
            return oldest != null && !ReferenceEquals(oldest.owner, owner);
        }
        public static long AccountedBytes {get{long n=0;foreach(var r in reservations)n=Add(n,r.AccountedBytes);return n;}}
        public static long EstimatedBytes {get{long n=0;foreach(var r in reservations)n=Add(n,r.EstimatedBytes);return n;}}
        public static long MeasuredHighWaterBytes {get{long n=0;foreach(var r in reservations)n=Add(n,r.MeasuredHighWaterBytes);return n;}}
        public static long RetiredBytes {get{long n=0;foreach(var r in reservations)if(r.retired)n=Add(n,r.AccountedBytes);return n;}}
        public static bool MemoryWithinBudget=>AccountedBytes<=settings.MemoryBudgetBytes;
        private static long Add(long a,long b)=>b>long.MaxValue-a?long.MaxValue:a+b;
        private static long Multiply(long a,long b)=>a==0 || b==0?0:a>long.MaxValue/b?long.MaxValue:a*b;
        private static Settings Normalize(Settings s)
        {
            s.MemoryBudgetBytes=Math.Max(0,s.MemoryBudgetBytes);s.MaxBuildsPerFrame=Math.Max(0,s.MaxBuildsPerFrame);
            s.TriangleWorkPerFrame=Math.Max(0,s.TriangleWorkPerFrame);s.InstanceWorkPerFrame=Math.Max(0,s.InstanceWorkPerFrame);
            s.TriangleBurstCapacity=Math.Max(0,s.TriangleBurstCapacity);s.InstanceBurstCapacity=Math.Max(0,s.InstanceBurstCapacity);
            s.BaseEstimateBytes=Math.Max(1,s.BaseEstimateBytes);s.BytesPerTriangle=Math.Max(1,s.BytesPerTriangle);s.BytesPerInstance=Math.Max(1,s.BytesPerInstance);
            if (!(s.BuildRecordingCpuBudgetMilliseconds > 0f)) s.BuildRecordingCpuBudgetMilliseconds = float.PositiveInfinity;
            return s;
        }
        private static Settings Stricter(Settings a,Settings b)=>new Settings{
            MemoryBudgetBytes=Math.Min(a.MemoryBudgetBytes,b.MemoryBudgetBytes),MaxBuildsPerFrame=Math.Min(a.MaxBuildsPerFrame,b.MaxBuildsPerFrame),
            TriangleWorkPerFrame=Math.Min(a.TriangleWorkPerFrame,b.TriangleWorkPerFrame),InstanceWorkPerFrame=Math.Min(a.InstanceWorkPerFrame,b.InstanceWorkPerFrame),
            TriangleBurstCapacity=Math.Min(a.TriangleBurstCapacity,b.TriangleBurstCapacity),InstanceBurstCapacity=Math.Min(a.InstanceBurstCapacity,b.InstanceBurstCapacity),
            BuildRecordingCpuBudgetMilliseconds=Math.Min(a.BuildRecordingCpuBudgetMilliseconds,b.BuildRecordingCpuBudgetMilliseconds),
            BaseEstimateBytes=Math.Max(a.BaseEstimateBytes,b.BaseEstimateBytes),BytesPerTriangle=Math.Max(a.BytesPerTriangle,b.BytesPerTriangle),BytesPerInstance=Math.Max(a.BytesPerInstance,b.BytesPerInstance)};

        internal static void ResetFrameAdmission()
        {
            initialized = false;
            Frame = int.MinValue;
            triangleCredits = instanceCredits = 0;
            BuildsThisFrame = 0;
            TriangleWorkThisFrame = InstanceWorkThisFrame = buildRecordingTicks = 0;
            demands.Clear();
        }

        /// <summary>Call before Prepare for each camera. Repeated same-frame calls cannot refill or relax limits.</summary>
        public static void BeginFrame(int engineFrame,Settings requested)
        {
            requested=Normalize(requested);
            if(initialized && engineFrame<Frame)return; // Late callbacks cannot rewind the shared scheduler.
            if(initialized && engineFrame==Frame)
            {
                Settings previous=settings;settings=Stricter(settings,requested);
                triangleCredits=Math.Min(triangleCredits,settings.TriangleBurstCapacity);
                instanceCredits=Math.Min(instanceCredits,settings.InstanceBurstCapacity);
                // A more restrictive feature cannot introduce fresh credits into this frame.
                if(settings.TriangleWorkPerFrame<previous.TriangleWorkPerFrame)triangleCredits=Math.Min(triangleCredits,Math.Max(0,settings.TriangleWorkPerFrame-TriangleWorkThisFrame));
                if(settings.InstanceWorkPerFrame<previous.InstanceWorkPerFrame)instanceCredits=Math.Min(instanceCredits,Math.Max(0,settings.InstanceWorkPerFrame-InstanceWorkThisFrame));
                return;
            }
            long elapsed=initialized?(long)engineFrame-Frame:1;
            initialized=true;Frame=engineFrame;settings=requested;
            triangleCredits=Math.Min(settings.TriangleBurstCapacity,Add(triangleCredits,Multiply(elapsed,settings.TriangleWorkPerFrame)));
            instanceCredits=Math.Min(settings.InstanceBurstCapacity,Add(instanceCredits,Multiply(elapsed,settings.InstanceWorkPerFrame)));
            BuildsThisFrame=0;TriangleWorkThisFrame=InstanceWorkThisFrame=buildRecordingTicks=0;
            for(int i=demands.Count-1;i>=0;i--)if(demands[i].reservedFrame<Frame)demands.RemoveAt(i);
        }
        private static void EnsureFrame(){if(!initialized)BeginFrame(0,Settings.Default);}
        public static long Estimate(long triangles,long instances)
        {EnsureFrame();return Add(settings.BaseEstimateBytes,Add(Multiply(Math.Max(0,triangles),settings.BytesPerTriangle),Multiply(Math.Max(0,instances),settings.BytesPerInstance)));}
        internal static bool EstimateFitsMemory(long triangles,long instances)
            => Estimate(triangles,instances)<=settings.MemoryBudgetBytes;
        internal static bool TryReserve(long triangles,long instances,Reservation current,out Reservation result,out string reason)
        {
            EnsureFrame();result=current;reason=null;
            if(triangles<0 || instances<0 || (current!=null && (current.retired || current.released)))
            {reason="RTAS reservation source is invalid.";return false;}
            long estimate=Estimate(triangles,instances),old=current?.AccountedBytes??0;
            long next=Math.Max(estimate,old),total=AccountedBytes;
            if(next>settings.MemoryBudgetBytes || total>settings.MemoryBudgetBytes-(next-old))
            {reason="RTAS memory estimate/retirement quota deferred this geometry.";return false;}
            if(current==null){current=new Reservation();reservations.Add(current);result=current;}
            current.EstimatedBytes=Math.Max(current.EstimatedBytes,estimate);return true;
        }
        internal static bool Observe(Reservation reservation,ulong measured)
        {
            if(reservation==null || reservation.released)return false;
            long bytes=measured>long.MaxValue?long.MaxValue:(long)measured;
            reservation.MeasuredHighWaterBytes=Math.Max(reservation.MeasuredHighWaterBytes,bytes);
            return MemoryWithinBudget;
        }
        internal static void Retire(Reservation reservation){if(reservation!=null&&!reservation.released)reservation.retired=true;}
        // Only the successful native-destruction callback calls this. A missing fence,
        // failed destruction, expiry of work demand or frame age is never sufficient.
        internal static void ReleaseDestroyed(Reservation reservation)
        {if(reservation==null||reservation.released)return;reservation.released=true;reservations.Remove(reservation);}
        public static void CancelBuildDemand(object owner)
        {for(int i=demands.Count-1;i>=0;i--)if(ReferenceEquals(demands[i].owner,owner))demands.RemoveAt(i);}

        internal static bool CanScheduleBuild(long triangles, long instances, out string reason)
        {
            EnsureFrame();
            if (settings.MaxBuildsPerFrame == 0)
                reason = "RTAS builds are disabled by the shared frame quota.";
            else if (triangles > settings.TriangleBurstCapacity || instances > settings.InstanceBurstCapacity)
                reason = "RTAS build exceeds the configured burst cap; increase the explicit cap or use software.";
            else if ((settings.TriangleWorkPerFrame == 0 && triangles > triangleCredits) ||
                     (settings.InstanceWorkPerFrame == 0 && instances > instanceCredits))
                reason = "RTAS build exceeds the remaining shared work credits with no replenishment.";
            else reason = null;
            return reason == null;
        }

        internal static bool RequestBuild(object owner,int frame,long triangles,long instances,out string reason,long prepareInterval=1)
        {
            EnsureFrame();reason=null;
            if(owner==null || frame!=Frame || triangles<0 || instances<0){reason="RTAS build demand belongs to a stale frame.";return false;}
            if(!CanScheduleBuild(triangles,instances,out reason))
            {CancelBuildDemand(owner);return false;}
            Demand demand=null;foreach(var d in demands)if(ReferenceEquals(d.owner,owner)){demand=d;break;}
            if(demand==null){if(sequence==long.MaxValue){reason="RTAS demand sequence exhausted.";return false;}demand=new Demand{owner=owner,sequence=++sequence};demands.Add(demand);}
            demand.lastFrame=frame;
            // A periodic camera retains its age, with a turn only on its expected return.
            demand.reservedFrame=(long)frame+Math.Max(1,prepareInterval);
            demand.triangles=triangles;demand.instances=instances;return true;
        }
        internal static bool TryConsumeBuild(object owner,int frame,long triangles,long instances,out string reason,long prepareInterval=1)
        {
            if(!RequestBuild(owner,frame,triangles,instances,out reason,prepareInterval))return false;
            Demand oldest=OldestActiveDemand();
            if(oldest==null || !ReferenceEquals(oldest.owner,owner)) {reason="RTAS build deferred behind an older active camera demand.";return false;}
            if(BuildsThisFrame>=settings.MaxBuildsPerFrame || triangleCredits<triangles || instanceCredits<instances)
            {reason="RTAS build deferred while shared work credits accumulate.";return false;}
            if (BuildRecordingBudgetSpent)
            {reason="RTAS build deferred by the shared CPU recording time limit.";return false;}
            triangleCredits-=triangles;instanceCredits-=instances;BuildsThisFrame++;
            TriangleWorkThisFrame=Add(TriangleWorkThisFrame,triangles);InstanceWorkThisFrame=Add(InstanceWorkThisFrame,instances);
            CancelBuildDemand(owner);return true;
        }

        internal static void AccountBuildRecording(int frame, long started)
        {
            if (frame != Frame) return;
            long elapsed = Stopwatch.GetTimestamp() - started;
            if (elapsed > 0) buildRecordingTicks = Add(buildRecordingTicks, elapsed);
        }

        private static Demand OldestActiveDemand()
        {
            Demand oldest = null;
            // Use the effective limits for this turn. A later camera may have tightened
            // them just for this frame, so preserve the other owners' waiting order.
            foreach (var demand in demands)
                if ((demand.lastFrame == Frame || demand.reservedFrame == Frame) && (oldest == null || demand.sequence < oldest.sequence) &&
                    CanScheduleBuild(demand.triangles, demand.instances, out _))
                    oldest = demand;
            return oldest;
        }
    }
}
