using System;
using System.Collections.Generic;

namespace HybridLumenGI
{
    /// <summary>
    /// Per-camera CPU receiver-source receipts. Published means the owning capture
    /// callbacks recorded, not GPU completion or proven per-pixel identity.
    /// </summary>
    public sealed class HybridLumenGIReceiverHistory
    {
        private HybridLumenGIHistoryLifecycle.FrameToken pendingToken,completedToken,lastBeginToken;
        private HybridLumenGIReceiverRegistry.Snapshot pending,completed,previous;
        private readonly Dictionary<ulong,HybridLumenGIReceiverRegistry.Record> previousRecords=new Dictionary<ulong,HybridLumenGIReceiverRegistry.Record>();
        private readonly Dictionary<ulong,HybridLumenGIReceiverRegistry.Record> pendingRecords=new Dictionary<ulong,HybridLumenGIReceiverRegistry.Record>();
        private bool recorded;
        private object cameraOwner;
        private HybridLumenGIHistoryLifecycle lifecycleOwner;
        private bool bound;
        public int PendingRecords => pending==null?0:pending.Records.Count;
        public int CompletedRecords => IsPublished?completed.Records.Count:0;
        public bool IsPublished => completed!=null && completedToken.Owner!=null && completedToken.Owner.IsCompleted(completedToken);
        public HybridLumenGIReceiverRegistry.Snapshot PendingSnapshot => pending;

        public bool Begin(HybridLumenGIHistoryLifecycle.FrameToken token,HybridLumenGIReceiverRegistry.Snapshot snapshot)
        {
            if(token.IsValid && ReferenceEquals(lastBeginToken.Owner,token.Owner) && lastBeginToken.Sequence==token.Sequence)
            { Invalidate();return false; }
            previousRecords.Clear();previous=null;
            if(token.Owner==null || !token.Owner.IsCurrent(token) || snapshot==null) { Invalidate();return false; }
            object camera=snapshot.Discovery==null?null:snapshot.Discovery.Camera;
            if(camera==null || (bound && (!ReferenceEquals(cameraOwner,camera) || !ReferenceEquals(lifecycleOwner,token.Owner))))
            { Invalidate();return false; }
            if(!bound) { bound=true;cameraOwner=camera;lifecycleOwner=token.Owner; }
            lastBeginToken=token;
            // BeginFrame already consumes the previous lifecycle receipt. Compare the
            // saved source receipt itself and use that lifecycle's captured reuse bit.
            if(completed!=null && ReferenceEquals(completedToken.Owner,token.Owner) &&
                ReferenceEquals(completed.Owner,snapshot.Owner) && token.Owner.CanReuseHistory(token) &&
                (long)completedToken.EngineFrame+1==token.EngineFrame)
            {
                previous=completed;
                foreach(var record in previous.Records) previousRecords.Add(record.Token,record);
            }
            pendingRecords.Clear();
            foreach(var record in snapshot.Records)
            {
                if(pendingRecords.ContainsKey(record.Token)) { Invalidate();return false; }
                pendingRecords.Add(record.Token,record);
            }
            completed=null;completedToken=default;pending=snapshot;pendingToken=token;recorded=false;
            return true;
        }

        public bool TryGetPrevious(HybridLumenGIReceiverRegistry.Record current,out HybridLumenGIReceiverRegistry.Record old)
        {
            old=null;
            if(pending==null || current==null || pendingToken.Owner==null || !pendingToken.Owner.IsCurrent(pendingToken) ||
                !pendingRecords.TryGetValue(current.Token,out var pendingRecord) || !ReferenceEquals(pendingRecord,current) ||
                !previousRecords.TryGetValue(current.Token,out var value) || !current.SameSource(value)) return false;
            // A caller cannot substitute a record from another snapshot/registry that
            // happens to use the same numeric token.
            old=value;return true;
        }

        public bool MarkCaptureRecorded(HybridLumenGIHistoryLifecycle.FrameToken token,bool sourcesCurrent)
        {
            if(!MatchesPending(token) || !token.Owner.IsCurrent(token)) return false;
            recorded=sourcesCurrent;
            if(!sourcesCurrent) { pending=null;previous=null;previousRecords.Clear();pendingRecords.Clear(); }
            return sourcesCurrent;
        }

        /// <summary>Call only after HistoryLifecycle.Complete accepted this exact receipt.</summary>
        public bool Complete(HybridLumenGIHistoryLifecycle.FrameToken token)
        {
            if(!MatchesPending(token) || !recorded || !token.Owner.IsCompleted(token)) return false;
            completed=pending;completedToken=token;pending=null;pendingToken=default;recorded=false;
            previous=null;previousRecords.Clear();pendingRecords.Clear();return true;
        }

        private bool MatchesPending(HybridLumenGIHistoryLifecycle.FrameToken token) => pending!=null &&
            ReferenceEquals(token.Owner,pendingToken.Owner) && token.IsValid && token.Sequence==pendingToken.Sequence;

        public void Invalidate()
        { pending=completed=previous=null;pendingToken=completedToken=default;recorded=false;previousRecords.Clear();pendingRecords.Clear(); }
    }
}
