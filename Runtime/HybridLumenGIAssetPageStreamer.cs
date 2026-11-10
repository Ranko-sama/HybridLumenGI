using System;
using System.Collections.Generic;
using System.IO;
using UnityEngine;

namespace HybridLumenGI
{
    /// <summary>Actual local-file AssetBundle IO for geometry, SDF, chart and material/texture pages.</summary>
    [DisallowMultipleComponent]
    public sealed class HybridLumenGIAssetPageStreamer : MonoBehaviour
    {
        [SerializeField] private HybridLumenGIAssetPageManifest manifest;
        [SerializeField] private HybridLumenGIAssetPageStreaming.Budgets budgets=HybridLumenGIAssetPageStreaming.Budgets.Default;
        private static HybridLumenGIAssetPageStreamer owner;
#if UNITY_EDITOR
        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.BeforeSceneLoad)]
        private static void ResumeRetirement()
        {
            // Disabling domain reload can preserve an old managed owner whose
            // native requests or leases still need the next Play loop to drain.
            if (!ReferenceEquals(owner, null)) HybridLumenGIAssetPageRetirementPump.EnsureExists();
        }
#endif
        private readonly Dictionary<object,RequestSet> requests=new Dictionary<object,RequestSet>();
        private bool failed, destroyed, waitingForOwner;
        private sealed class RequestSet
        {
            internal string[] ids;
            internal HybridLumenGIStreamedRepresentation binding;
            internal string[] admittedHlodIds;
            internal int priority;
            internal long requestedAt,sequence;
            internal long Score(long now) => (long)priority+(now-requestedAt)/60;
        }
        private long tick,nextRequest;
        public HybridLumenGIAssetPageStreaming State { get; private set; }
        public HybridLumenGIAssetPageManifest Manifest => manifest;
        private bool Draining => destroyed || !isActiveAndEnabled;
        public bool Available => State!=null && !failed && ReferenceEquals(owner,this) && !Draining;
        public int BudgetBlockedGroups { get; private set; }
        public void Configure(HybridLumenGIAssetPageManifest value)
        {
            if(State!=null)throw new InvalidOperationException("Cannot replace an initialized page manifest.");manifest=value;
            if(Application.isPlaying && isActiveAndEnabled)OnEnable();
        }
        public void SetBudgets(HybridLumenGIAssetPageStreaming.Budgets value)
        {if(!value.Valid)throw new ArgumentException("Negative page budget.");budgets=value;}
        // One global driver ensures the declared IO/resource limits cannot be multiplied by cameras.
        private void OnEnable()
        {
            if(!Application.isPlaying)return;
            if(!ReferenceEquals(owner,null) && !ReferenceEquals(owner,this))
            {
                // A stopped owner still holds the budget while native work or
                // reader leases are outstanding. Resume admission after its drain.
                waitingForOwner = owner.Draining;
                failed = !waitingForOwner;
                if(failed)Debug.LogError("Only one HybridLumenGI asset-page driver may own the global asset IO budget.",this);
                return;
            }
            waitingForOwner=false;
            failed=false;
            if(State==null && manifest==null){failed=true;return;}
            try
            {
                if(State==null)
                {
                    string root=ContainedPath(Application.streamingAssetsPath,manifest.RelativeRoot);
                    State=new HybridLumenGIAssetPageStreaming(manifest.Pages,new BundleProvider(root));
                }
                HybridLumenGIAssetPageRetirementPump.EnsureExists();
                owner=this;
            }
            catch(Exception error){failed=true;Debug.LogException(error,this);}
        }
        private void Update()
        {
            if(waitingForOwner && ReferenceEquals(owner,null))OnEnable();
        }
        internal static void Pump()
        {
            if(ReferenceEquals(owner,null))return;
            owner.Drive();
            var state=owner.State;
            if(owner.Draining && (state==null || (state.BundleBytes==0 && state.ResidentBytes==0 &&
                state.IoBytesInFlight==0 && state.ActiveOperations==0 && state.RetiringLeases==0)))owner=null;
        }
        private void Drive()
        {
            if(State==null || failed)return;
            bool draining=Draining;
            var stepBudgets = budgets;
            if (draining)
            {
                // Suspend requests while disabled, retaining them for re-enable.
                // Only releases get an allowance during the drain, even if paused.
                stepBudgets = new HybridLumenGIAssetPageStreaming.Budgets
                {
                    concurrentOperations = Math.Max(1, budgets.concurrentOperations),
                    startsPerStep = Math.Max(1, budgets.startsPerStep)
                };
            }
            if(!stepBudgets.Valid)return; // Inspector edits can temporarily contain an invalid value.
            if(tick<long.MaxValue)tick++;
            BudgetBlockedGroups=0;
            var priorities=new Dictionary<string,long>(StringComparer.Ordinal);
            var ordered=draining?new List<RequestSet>():new List<RequestSet>(requests.Values);
            ordered.Sort((a,b)=>
            {
                int rank=b.Score(tick).CompareTo(a.Score(tick));return rank!=0?rank:a.sequence.CompareTo(b.sequence);
            });
            var admitted=new HashSet<string>(StringComparer.Ordinal);
            HashSet<IReadOnlyList<HybridLumenGIStreamedRepresentation>> processedHlodGroups = null;
            List<RequestSet> detailRequests = null;
            foreach (var request in requests.Values) request.admittedHlodIds = null;
            foreach(var request in ordered)
            {
                var ids = request.ids;
                var details = request.binding != null ? request.binding.AutomaticHlodDetails() : null;
                if (details != null)
                {
                    processedHlodGroups ??= new HashSet<IReadOnlyList<HybridLumenGIStreamedRepresentation>>();
                    if (!processedHlodGroups.Add(details)) continue;
                    detailRequests ??= new List<RequestSet>();
                    detailRequests.Clear();
                    foreach (var detail in details)
                    {
                        if (!detail.HasActivePageDemand || !requests.TryGetValue(detail, out var member) || member.binding != detail) break;
                        detailRequests.Add(member);
                    }
                    if (detailRequests.Count != details.Count) continue;
                    // A partial HLOD target cannot publish. Reserve its whole authored leaf set at once.
                    var detailIds = new HashSet<string>(StringComparer.Ordinal);
                    foreach (var member in detailRequests) detailIds.UnionWith(member.ids);
                    ids = new string[detailIds.Count];
                    detailIds.CopyTo(ids);
                }
                if (!State.TryAdmitGroup(ids, stepBudgets, admitted, checkRetry: true, out bool waitingForRetry))
                {
                    if (!waitingForRetry) BudgetBlockedGroups++;
                    continue;
                }
                if (details != null)
                    foreach (var member in detailRequests) member.admittedHlodIds = ids;
                long score=request.Score(tick);
                foreach(var id in ids)
                    priorities[id]=priorities.TryGetValue(id,out long previous)?Math.Max(previous,score):score;
            }
            foreach(var state in State.States)
                State.Request(state.Id,priorities.TryGetValue(state.Id,out long priority),priority);
            HybridLumenGIRayTexturePool.PollRetired();
            State.Step(stepBudgets);
        }
        public bool SetRequests(object requester,IReadOnlyList<string> ids,int priority=0)
            => SetRequests(requester, ids, priority, null);

        internal bool SetRepresentationRequests(HybridLumenGIStreamedRepresentation binding, IReadOnlyList<string> ids, int priority)
            => SetRequests(binding, ids, priority, binding);

        private bool SetRequests(object requester, IReadOnlyList<string> ids, int priority, HybridLumenGIStreamedRepresentation binding)
        {
            if(requester==null || !Available || ids==null)return false;
            var unique=new HashSet<string>(StringComparer.Ordinal);
            foreach(string id in ids)if(!string.IsNullOrEmpty(id))
            {if(State.GetState(id)==null)return false;unique.Add(id);}
            if(requests.TryGetValue(requester,out var previous) && ReferenceEquals(previous.binding, binding) && unique.SetEquals(previous.ids))
            {previous.priority=priority;return true;}
            var array=new string[unique.Count];unique.CopyTo(array);
            requests[requester]=new RequestSet{ids=array,binding=binding,priority=priority,requestedAt=tick,sequence=nextRequest++};return true;
        }

        internal bool CanBindHlodDetails(HybridLumenGIStreamedRepresentation binding,
            IReadOnlyList<HybridLumenGIStreamedRepresentation> details)
        {
            if (!requests.TryGetValue(binding, out var request) || request.admittedHlodIds == null) return false;
            foreach (var detail in details)
                if (!detail.HasActivePageDemand || !requests.TryGetValue(detail, out var member) ||
                    !ReferenceEquals(member.admittedHlodIds, request.admittedHlodIds)) return false;
            foreach (var id in request.admittedHlodIds)
                if (State.GetState(id).Status != HybridLumenGIAssetPageStreaming.Phase.Ready) return false;
            return true;
        }
        public void RemoveRequests(object requester){if(requester!=null)requests.Remove(requester);}
        public bool TryAcquire(string id,out HybridLumenGIAssetPageStreaming.Lease lease)
        {lease=null;return Available && State.TryAcquire(id,out lease);}
        private void OnDestroy()
        {
            destroyed=true;requests.Clear();
            // The hidden main-thread pump keeps this managed owner/provider reachable even after
            // Unity destroys the component. Retained GPU work is never forgotten or aged out.
        }
        internal static string ContainedPath(string root,string relative)
        {
            if(!HybridLumenGIAssetPageStreaming.RelativePath(relative))throw new ArgumentException("Asset page paths must be relative without parent traversal.");
            string fullRoot=Path.GetFullPath(root).TrimEnd(Path.DirectorySeparatorChar,Path.AltDirectorySeparatorChar)+Path.DirectorySeparatorChar;
            string full=Path.GetFullPath(Path.Combine(fullRoot,relative));
            if(!full.StartsWith(fullRoot,StringComparison.OrdinalIgnoreCase))throw new ArgumentException("Asset page escaped its configured root.");
            return full;
        }
        private sealed class BundleHandle { internal AssetBundle bundle;internal AsyncOperation unload;internal bool unloadStarted; }
        private sealed class BundleLoad : HybridLumenGIAssetPageStreaming.IOperation
        {
            private readonly AssetBundleCreateRequest request;
            private BundleHandle handle;
            internal BundleLoad(AssetBundleCreateRequest request){this.request=request;}
            public bool IsDone => request.isDone;
            public string Error => request.isDone && request.assetBundle==null?"AssetBundle file failed to load or CRC did not match.":null;
            public object Result => request.isDone && request.assetBundle!=null?(handle??(handle=new BundleHandle{bundle=request.assetBundle})):null;
        }
        private sealed class AssetLoad : HybridLumenGIAssetPageStreaming.IOperation
        {
            private readonly AssetBundleRequest request;
            private readonly Type expected;
            internal AssetLoad(AssetBundleRequest request,Type expected){this.request=request;this.expected=expected;}
            public bool IsDone => request.isDone;
            public string Error => request.isDone && (request.asset==null || !expected.IsInstanceOfType(request.asset))?"Missing or incorrectly typed asset page.":null;
            public object Result => request.isDone && Error==null?request.asset:null;
        }
        private sealed class Release : HybridLumenGIAssetPageStreaming.IOperation
        {
            private readonly BundleHandle handle;
            private readonly UnityEngine.Object asset;
            private bool done;
            private string error;
            private bool invalidated;
            internal Release(BundleHandle handle,UnityEngine.Object asset)
            {
                this.handle=handle;this.asset=asset;
            }
            public bool IsDone
            {
                get
                {
                    if(done)return true;
                    try
                    {
                        // A texture may still have GPU material-cache readers after its renderer
                        // lease retires. Invalidate only once no other page depends on this page;
                        // retiring one instance must not invalidate a shared resident texture.
                        if(asset is Texture texture && texture!=null)
                        {
                            if(!invalidated){HybridLumenGIRayTexturePool.InvalidateSource(texture);invalidated=true;}
                            if(HybridLumenGIRayTexturePool.IsSourceReferenced(texture))return false;
                        }
                        if(!handle.unloadStarted && handle.bundle!=null)
                        {handle.unload=handle.bundle.UnloadAsync(false);handle.unloadStarted=true;}
                        if(handle.unload!=null && !handle.unload.isDone)return false;
                        handle.bundle=null;
                        // This is reached only after all page leases/consumers and dependent pages
                        // were retired. Unload(false) alone would leak the explicitly owned asset.
                        if(asset!=null)Resources.UnloadAsset(asset);
                    }
                    catch(Exception ex){error="Asset release failed: "+ex.Message;}
                    done=true;return true;
                }
            }
            public string Error => error;
            public object Result => null;
        }
        private sealed class BundleProvider : HybridLumenGIAssetPageStreaming.IProvider
        {
            private readonly string root;
            internal BundleProvider(string root){this.root=root;}
            public HybridLumenGIAssetPageStreaming.IOperation LoadBundle(HybridLumenGIAssetPageStreaming.Definition definition)
            {
                string path=ContainedPath(root,definition.bundlePath);
                if(new FileInfo(path).Length!=definition.fileBytes)throw new InvalidOperationException("AssetBundle file size differs from its built manifest.");
                var request=AssetBundle.LoadFromFileAsync(path,definition.crc);
                return request!=null?new BundleLoad(request):throw new InvalidOperationException("AssetBundle IO returned no request.");
            }
            public HybridLumenGIAssetPageStreaming.IOperation LoadAsset(HybridLumenGIAssetPageStreaming.Definition definition,object bundle)
            {
                var handle=(BundleHandle)bundle;
                if(handle.unloadStarted || handle.bundle==null)throw new InvalidOperationException("AssetBundle is no longer loadable.");
                Type type=definition.kind==HybridLumenGIAssetPageStreaming.Kind.Geometry?typeof(Mesh):
                    definition.kind==HybridLumenGIAssetPageStreaming.Kind.Sdf?typeof(HybridLumenGIMeshSdf):
                    definition.kind==HybridLumenGIAssetPageStreaming.Kind.SurfaceCharts?typeof(HybridLumenGISurfaceCharts):
                    definition.kind==HybridLumenGIAssetPageStreaming.Kind.Material?typeof(Material):typeof(Texture);
                var request=handle.bundle.LoadAssetAsync(definition.assetName,type);
                return request!=null?new AssetLoad(request,type):throw new InvalidOperationException("Asset loading returned no request.");
            }
            public HybridLumenGIAssetPageStreaming.IOperation Release(HybridLumenGIAssetPageStreaming.Definition definition,object bundle,object asset)
                => new Release((BundleHandle)bundle,asset as UnityEngine.Object);
        }
    }
}
