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
        private readonly Dictionary<object,RequestSet> requests=new Dictionary<object,RequestSet>();
        private bool failed, destroyed;
        private sealed class RequestSet { internal string[] ids;internal int priority;internal long requestedAt,sequence; }
        private long tick,nextRequest;
        public HybridLumenGIAssetPageStreaming State { get; private set; }
        public HybridLumenGIAssetPageManifest Manifest => manifest;
        public bool Available => State!=null && !failed && !destroyed && ReferenceEquals(owner,this);
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
            if(!ReferenceEquals(owner,null) && !ReferenceEquals(owner,this)){failed=true;Debug.LogError("Only one HybridLumenGI asset-page driver may own the global asset IO budget.",this);return;}
            failed=false;
            if(State!=null)return;
            if(manifest==null){failed=true;return;}
            try
            {
                string root=ContainedPath(Application.streamingAssetsPath,manifest.RelativeRoot);
                State=new HybridLumenGIAssetPageStreaming(manifest.Pages,new BundleProvider(root));
                owner=this;
                HybridLumenGIAssetPageRetirementPump.EnsureExists();
            }
            catch(Exception error){failed=true;Debug.LogException(error,this);}
        }
        internal static void Pump()
        {
            if(ReferenceEquals(owner,null))return;
            owner.Drive();
            if(owner.destroyed && (owner.State==null || (owner.State.BundleBytes==0 && owner.State.RetiringLeases==0)))owner=null;
        }
        private void Drive()
        {
            if(State==null || failed)return;
            if(!budgets.Valid)return; // Inspector edits can temporarily contain an invalid value.
            if(tick<long.MaxValue)tick++;
            BudgetBlockedGroups=0;
            var priorities=new Dictionary<string,int>(StringComparer.Ordinal);
            var ordered=new List<RequestSet>(requests.Values);
            ordered.Sort((a,b)=>
            {
                long scoreA=(long)a.priority+(tick-a.requestedAt)/60,scoreB=(long)b.priority+(tick-b.requestedAt)/60;
                int rank=scoreB.CompareTo(scoreA);return rank!=0?rank:a.sequence.CompareTo(b.sequence);
            });
            var admitted=new HashSet<string>(StringComparer.Ordinal);
            foreach(var request in ordered)
            {
                if(!State.TryAdmitGroup(request.ids,budgets,admitted)){BudgetBlockedGroups++;continue;}
                foreach(var id in request.ids)
                    priorities[id]=priorities.TryGetValue(id,out int previous)?Math.Max(previous,request.priority):request.priority;
            }
            foreach(var state in State.States)
                State.Request(state.Id,priorities.TryGetValue(state.Id,out int priority),priority);
            HybridLumenGIRayTexturePool.PollRetired();
            State.Step(budgets);
        }
        public bool SetRequests(object requester,IReadOnlyList<string> ids,int priority=0)
        {
            if(requester==null || !Available || ids==null)return false;
            var unique=new HashSet<string>(StringComparer.Ordinal);
            foreach(string id in ids)if(!string.IsNullOrEmpty(id))
            {if(State.GetState(id)==null)return false;unique.Add(id);}
            if(requests.TryGetValue(requester,out var previous) && unique.SetEquals(previous.ids))
            {previous.priority=priority;return true;}
            var array=new string[unique.Count];unique.CopyTo(array);
            requests[requester]=new RequestSet{ids=array,priority=priority,requestedAt=tick,sequence=nextRequest++};return true;
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
