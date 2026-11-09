using System;
using System.Collections.Generic;

namespace HybridLumenGI
{
    /// <summary>
    /// Main-thread scheduler for independently addressable asset pages. Byte limits are declared
    /// logical resource/admission limits, not estimates of driver or Unity decompressor memory.
    /// A provider operation is never cancelled by forgetting its handle. Dependencies and leases
    /// retain their reservations until an actual release operation completes.
    /// </summary>
    public sealed class HybridLumenGIAssetPageStreaming
    {
        public enum Kind { Geometry, Sdf, SurfaceCharts, Material, Texture }
        [Serializable]
        public sealed class Definition
        {
            public string id, bundlePath, assetName;
            public Kind kind;
            public uint crc;
            public long fileBytes, residentBytes, uploadBytes;
            public string[] dependencies = Array.Empty<string>();
        }
        [Serializable]
        public struct Budgets
        {
            public long ioBytesPerStep, maxIoBytesInFlight, maxBundleBytes, maxResidentBytes, uploadBytesPerStep;
            public int concurrentOperations, startsPerStep;
            public static Budgets Default => new Budgets { ioBytesPerStep=64L<<20, maxIoBytesInFlight=128L<<20,
                maxBundleBytes=256L<<20, maxResidentBytes=512L<<20, uploadBytesPerStep=64L<<20,
                concurrentOperations=2, startsPerStep=2 };
            internal bool Valid => ioBytesPerStep>=0 && maxIoBytesInFlight>=0 && maxBundleBytes>=0 &&
                maxResidentBytes>=0 && uploadBytesPerStep>=0 && concurrentOperations>=0 && startsPerStep>=0;
        }
        public interface ICompletion { bool IsComplete { get; } }
        public interface IOperation
        {
            bool IsDone { get; }
            string Error { get; }
            object Result { get; }
        }
        public interface IProvider
        {
            // Throwing must mean no operation was started. Once started, return its handle and
            // report failure from that operation; unknown completion must remain pending.
            IOperation LoadBundle(Definition definition);
            IOperation LoadAsset(Definition definition, object bundle);
            IOperation Release(Definition definition, object bundle, object asset);
        }
        public enum Phase { Unloaded, LoadingBundle, BundleReady, LoadingAsset, Ready, Releasing, Failed, ReleaseFailed }
        public sealed class State
        {
            internal Definition definition;
            internal State[] dependencies;
            internal IOperation operation;
            internal object bundle, asset;
            internal bool requested, bundleReserved, residentReserved;
            internal int referenceCount, releasePins;
            internal long priority, requestedPriority, requestedAt, retryAt;
            public string Id => definition.id;
            public Kind PageKind => definition.kind;
            public uint Generation { get; internal set; }
            public Phase Status { get; internal set; }
            public bool Wanted { get; internal set; }
            public int ConsumerReferences => referenceCount;
            public string LastError { get; internal set; }
        }
        public sealed class Lease
        {
            internal readonly HybridLumenGIAssetPageStreaming owner;
            internal readonly State state;
            internal bool released;
            internal ICompletion completion;
            public uint Generation { get; }
            public string Id => state.Id;
            public object Asset => !released && state.Generation==Generation ? state.asset : null;
            internal Lease(HybridLumenGIAssetPageStreaming owner, State state)
            { this.owner=owner;this.state=state;Generation=state.Generation; }
        }
        private readonly IProvider provider;
        private readonly State[] states, ordered;
        private readonly Dictionary<string,State> byId = new Dictionary<string,State>(StringComparer.Ordinal);
        private readonly List<Lease> retiring = new List<Lease>();
        private long tick;
        private long NextStepTick => tick < long.MaxValue ? tick + 1 : tick;
        private uint generation;
        public IReadOnlyList<State> States => states;
        public long IoBytesInFlight { get; private set; }
        public long BundleBytes { get; private set; }
        public long ResidentBytes { get; private set; }
        public long IoBytesStarted { get; private set; }
        public long UploadBytesStarted { get; private set; }
        public int ActiveOperations { get; private set; }
        public int OperationsStarted { get; private set; }
        public int BudgetBlocked { get; private set; }
        public int RetiringLeases => retiring.Count;

        public HybridLumenGIAssetPageStreaming(IReadOnlyList<Definition> definitions, IProvider provider)
        {
            this.provider=provider ?? throw new ArgumentNullException(nameof(provider));
            if(definitions==null || definitions.Count>16384) throw new ArgumentException("Invalid page manifest.");
            states=new State[definitions.Count];ordered=new State[definitions.Count];
            var paths=new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            for(int i=0;i<states.Length;i++)
            {
                Definition source=definitions[i];
                if(source==null || string.IsNullOrWhiteSpace(source.id) || !RelativePath(source.bundlePath) ||
                    string.IsNullOrWhiteSpace(source.assetName) || source.fileBytes<=0 || source.residentBytes<=0 ||
                    source.uploadBytes<0 || !Enum.IsDefined(typeof(Kind),source.kind) ||
                    byId.ContainsKey(source.id) || !paths.Add(source.bundlePath))
                    throw new ArgumentException("Page identity, bundle path, cost or kind is invalid/duplicated.");
                var definition=new Definition { id=source.id,bundlePath=source.bundlePath,assetName=source.assetName,
                    kind=source.kind,crc=source.crc,fileBytes=source.fileBytes,residentBytes=source.residentBytes,
                    uploadBytes=source.uploadBytes,dependencies=source.dependencies==null?Array.Empty<string>():(string[])source.dependencies.Clone() };
                var state=new State { definition=definition };
                states[i]=ordered[i]=state;byId.Add(state.Id,state);
            }
            foreach(var state in states)
            {
                var unique=new HashSet<string>(StringComparer.Ordinal);
                state.dependencies=new State[state.definition.dependencies.Length];
                for(int i=0;i<state.dependencies.Length;i++)
                    if(!unique.Add(state.definition.dependencies[i]) || !byId.TryGetValue(state.definition.dependencies[i],out state.dependencies[i]))
                        throw new ArgumentException("Unknown or duplicate page dependency.");
            }
            var colors=new Dictionary<State,int>();foreach(var state in states)CheckDag(state,colors,0);
        }
        public static bool RelativePath(string path)
        {
            if(string.IsNullOrWhiteSpace(path) || path[0]=='/' || path[0]=='\\' || path.Contains(":") || path.Contains("\\")) return false;
            foreach(string part in path.Split('/'))if(part.Length==0 || part=="." || part=="..")return false;
            return true;
        }
        private static void CheckDag(State state, Dictionary<State,int> colors,int depth)
        {
            if(depth>128)throw new ArgumentException("Page dependency chain exceeds 128 levels.");
            if(colors.TryGetValue(state,out int color)){if(color==1)throw new ArgumentException("Cyclic page dependencies.");return;}
            colors[state]=1;foreach(var dependency in state.dependencies)CheckDag(dependency,colors,depth+1);colors[state]=2;
        }
        public State GetState(string id) => id!=null && byId.TryGetValue(id,out var state)?state:null;
        /// <summary>
        /// Whole-group admission prevents several incomplete representations from consuming the
        /// budget with meshes while none has room for its materials. Keep one admitted set for a
        /// scheduler step. Existing reservations (including pending/failed retirement) always count.
        /// </summary>
        public bool TryAdmitGroup(IReadOnlyList<string> ids,Budgets budgets,HashSet<string> admitted)
            => TryAdmitGroup(ids, budgets, admitted, checkRetry: false, out _);

        internal bool TryAdmitGroup(IReadOnlyList<string> ids, Budgets budgets, HashSet<string> admitted,
            bool checkRetry, out bool waitingForRetry)
        {
            waitingForRetry = false;
            if(ids==null || admitted==null || !budgets.Valid)return false;
            foreach(var state in states)if(state.bundleReserved)admitted.Add(state.Id);
            var closure=new HashSet<State>();
            foreach(string id in ids){State state=GetState(id);if(state==null)return false;AddClosure(state,closure);}
            if (checkRetry)
            {
                // The driver plans for the next Step, which advances the clock before starting work.
                // Retained reservations above still count while this group waits for a load retry.
                long nextTick = NextStepTick;
                foreach (var state in closure)
                    if (state.Status == Phase.Failed && nextTick < state.retryAt)
                    {
                        waitingForRetry = true;
                        return false;
                    }
            }
            long bundleCost=0,residentCost=0;
            foreach(string id in admitted)
            {
                State state=GetState(id);if(state==null)return false;
                if(!Fits(state.definition.fileBytes,bundleCost,budgets.maxBundleBytes) ||
                    !Fits(state.definition.residentBytes,residentCost,budgets.maxResidentBytes))return false;
                bundleCost+=state.definition.fileBytes;residentCost+=state.definition.residentBytes;
            }
            foreach(var state in closure)
            {
                var page=state.definition;
                // Per-start limits apply only to work still to be started. Completed/shared
                // pages and native operations already in flight keep their reservations.
                // A releasing page must finish retirement and pass full load admission again.
                bool needsBundle=state.Status==Phase.Unloaded || state.Status==Phase.Releasing ||
                    state.Status==Phase.ReleaseFailed || (state.Status==Phase.Failed && !state.bundleReserved);
                bool needsUpload=state.Status!=Phase.Ready && state.Status!=Phase.LoadingAsset;
                if((needsBundle && (page.fileBytes>budgets.ioBytesPerStep || page.fileBytes>budgets.maxIoBytesInFlight)) ||
                    (needsUpload && page.uploadBytes>budgets.uploadBytesPerStep))return false;
                if(admitted.Contains(state.Id))continue;
                if(!Fits(page.fileBytes,bundleCost,budgets.maxBundleBytes) || !Fits(page.residentBytes,residentCost,budgets.maxResidentBytes))return false;
                bundleCost+=page.fileBytes;residentCost+=page.residentBytes;
            }
            foreach(var state in closure)admitted.Add(state.Id);return true;
        }
        private static void AddClosure(State state,HashSet<State> closure)
        {if(!closure.Add(state))return;foreach(var dependency in state.dependencies)AddClosure(dependency,closure);}
        public bool Request(string id,bool wanted,int priority=0)
            => Request(id,wanted,(long)priority);
        internal bool Request(string id,bool wanted,long priority)
        {
            if(id==null || !byId.TryGetValue(id,out var state))return false;
            if(wanted && !state.requested)state.requestedAt=tick;
            state.requested=wanted;state.requestedPriority=priority;return true;
        }
        public bool TryAcquire(string id,out Lease lease)
        {
            lease=null;State state=GetState(id);
            if(state==null || state.Status!=Phase.Ready || state.asset==null || state.referenceCount==int.MaxValue)return false;
            state.referenceCount++;lease=new Lease(this,state);return true;
        }
        /// <summary>Use only after detaching every reference which could submit another consumer.</summary>
        public bool ReleaseAfter(Lease lease,ICompletion completion)
        {
            if(lease==null || lease.owner!=this || lease.released || lease.completion!=null || completion==null ||
                lease.state.Generation!=lease.Generation)return false;
            lease.completion=completion;lease.state.releasePins++;retiring.Add(lease);return true;
        }
        private static bool Fits(long value,long used,long limit) => value>=0 && used>=0 && used<=limit && value<=limit-used;
        private void MarkWanted(State state,long priority)
        {
            if(state.Wanted && state.priority>=priority)return;
            // Dependencies inherit the demand that actually requires them, including negative scores.
            state.Wanted=true;state.priority=priority;
            foreach(var dependency in state.dependencies)MarkWanted(dependency,priority);
        }
        public void Step(Budgets budgets)
        {
            if(!budgets.Valid)throw new ArgumentException("Negative page budget.");
            tick = NextStepTick;
            IoBytesStarted=UploadBytesStarted=0;OperationsStarted=BudgetBlocked=0;
            for(int i=retiring.Count-1;i>=0;i--)
            {
                Lease lease=retiring[i];bool done=false;
                try{done=lease.completion.IsComplete;}catch(Exception){ /* Unproven consumers remain held. */ }
                if(!done)continue;
                lease.released=true;lease.state.referenceCount--;lease.state.releasePins--;retiring.RemoveAt(i);
            }
            foreach(var state in states)Poll(state);
            foreach(var state in states){state.Wanted=false;state.priority=state.requestedPriority;}
            foreach(var state in states)
                if(state.requested)MarkWanted(state,state.requestedPriority);
            // Retained operations keep unrequested pages alive without overriding
            // the priority already inherited from an admitted group.
            foreach(var state in states)
                if(!state.Wanted && (state.referenceCount>0 || state.operation!=null))MarkWanted(state,state.requestedPriority);
            // An already loaded parent keeps its dependencies until its own release completes.
            foreach(var state in states)
                if(state.bundleReserved)foreach(var dependency in state.dependencies)MarkWanted(dependency,state.priority);
            Array.Sort(ordered,(a,b)=>
            {
                int priority=b.priority.CompareTo(a.priority);if(priority!=0)return priority;
                int age=a.requestedAt.CompareTo(b.requestedAt);return age!=0?age:string.CompareOrdinal(a.Id,b.Id);
            });
            ActiveOperations=0;foreach(var state in states)if(state.operation!=null)ActiveOperations++;
            // Reclaim leaves before admitting new work. Pending or failed releases keep all budgets.
            foreach(var state in ordered)
            {
                if(!CanStart(budgets))break;
                if((state.Wanted && state.Status!=Phase.ReleaseFailed) || state.referenceCount!=0 || state.operation!=null || !state.bundleReserved || tick<state.retryAt)continue;
                OperationsStarted++;
                try {state.operation=provider.Release(state.definition,state.bundle,state.asset) ?? throw new InvalidOperationException("No page release operation.");state.Status=Phase.Releasing;ActiveOperations++;}
                catch(Exception ex){state.LastError=ex.Message;state.retryAt=tick+60;}
            }
            foreach(var state in ordered)
            {
                if(!CanStart(budgets))break;
                if(!state.Wanted || state.operation!=null || tick<state.retryAt || state.Status==Phase.ReleaseFailed)continue;
                if(state.Status==Phase.Unloaded || (state.Status==Phase.Failed && !state.bundleReserved))
                {
                    long bytes=state.definition.fileBytes;
                    if(!Fits(bytes,IoBytesStarted,budgets.ioBytesPerStep) || !Fits(bytes,IoBytesInFlight,budgets.maxIoBytesInFlight) ||
                        !Fits(bytes,BundleBytes,budgets.maxBundleBytes)){BudgetBlocked++;continue;}
                    if(generation==uint.MaxValue){state.LastError="Non-reusable page generation space exhausted.";continue;}
                    OperationsStarted++;IoBytesStarted+=bytes;IoBytesInFlight+=bytes;BundleBytes+=bytes;state.bundleReserved=true;state.Generation=++generation;
                    try {state.operation=provider.LoadBundle(state.definition) ?? throw new InvalidOperationException("No bundle load operation.");state.Status=Phase.LoadingBundle;state.LastError=null;ActiveOperations++;}
                    catch(Exception ex){IoBytesInFlight-=bytes;BundleBytes-=bytes;state.bundleReserved=false;Fail(state,ex.Message);}
                }
                else if(state.Status==Phase.BundleReady || (state.Status==Phase.Failed && state.bundle!=null))
                {
                    bool dependenciesReady=true;
                    foreach(var dependency in state.dependencies)dependenciesReady &= dependency.Status==Phase.Ready;
                    if(!dependenciesReady)continue;
                    long bytes=state.definition.residentBytes,upload=state.definition.uploadBytes;
                    if(!Fits(bytes,ResidentBytes,budgets.maxResidentBytes) || !Fits(upload,UploadBytesStarted,budgets.uploadBytesPerStep)){BudgetBlocked++;continue;}
                    OperationsStarted++;UploadBytesStarted+=upload;ResidentBytes+=bytes;state.residentReserved=true;
                    try {state.operation=provider.LoadAsset(state.definition,state.bundle) ?? throw new InvalidOperationException("No asset load operation.");state.Status=Phase.LoadingAsset;state.LastError=null;ActiveOperations++;}
                    catch(Exception ex){ResidentBytes-=bytes;state.residentReserved=false;Fail(state,ex.Message);}
                }
            }
        }
        private bool CanStart(Budgets budgets) => OperationsStarted<budgets.startsPerStep && ActiveOperations<budgets.concurrentOperations;
        private void Fail(State state,string message){state.LastError=message;state.Status=Phase.Failed;state.retryAt=tick+60;}
        private void Poll(State state)
        {
            if(state.operation==null)return;
            bool done;string error;object result;
            try{done=state.operation.IsDone;if(!done)return;error=state.operation.Error;result=state.operation.Result;}
            catch(Exception ex){state.LastError="Unproven operation completion: "+ex.Message;return;}
            Phase phase=state.Status;state.operation=null;
            if(phase==Phase.LoadingBundle)
            {
                IoBytesInFlight-=state.definition.fileBytes;
                if(error!=null || result==null){BundleBytes-=state.definition.fileBytes;state.bundleReserved=false;Fail(state,error??"Missing loaded bundle.");return;}
                state.bundle=result;state.Status=Phase.BundleReady;
            }
            else if(phase==Phase.LoadingAsset)
            {
                if(error!=null || result==null){ResidentBytes-=state.definition.residentBytes;state.residentReserved=false;Fail(state,error??"Missing loaded asset.");return;}
                state.asset=result;state.Status=Phase.Ready;
            }
            else if(phase==Phase.Releasing)
            {
                if(error!=null){state.LastError=error;state.Status=Phase.ReleaseFailed;state.retryAt=tick+60;return;}
                if(state.residentReserved)ResidentBytes-=state.definition.residentBytes;
                if(state.bundleReserved)BundleBytes-=state.definition.fileBytes;
                state.bundle=state.asset=null;state.residentReserved=state.bundleReserved=false;state.Status=Phase.Unloaded;
            }
        }
    }
}
