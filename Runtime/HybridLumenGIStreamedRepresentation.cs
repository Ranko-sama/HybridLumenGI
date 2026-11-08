using System;
using System.Collections.Generic;
using UnityEngine;

namespace HybridLumenGI
{
    /// <summary>
    /// Publishes a complete mesh/material/SDF/chart group after asynchronous page acquisition.
    /// Publication starts normal GI warmup; it is not evidence of HLOD/GPU readiness. The renderer
    /// integration acknowledges safe replacement and supplies the final-frame consumer ticket.
    /// </summary>
    [DisallowMultipleComponent]
    public sealed class HybridLumenGIStreamedRepresentation : MonoBehaviour
    {
        [SerializeField] private HybridLumenGIAssetPageStreamer streamer;
        [SerializeField] private HybridLumenGIProxy proxy;
        [SerializeField] private MeshFilter meshFilter;
        [SerializeField] private MeshRenderer targetRenderer;
        [SerializeField] private string geometryPage,sdfPage,chartPage;
        [SerializeField] private string[] materialPages=Array.Empty<string>();
        [SerializeField] private Bounds localBounds=new Bounds(Vector3.zero,Vector3.one);
        [SerializeField,Tooltip("Use the camera's Hybrid Lumen GI publication to show this HLOD member in ordinary rendering.")]
        private bool useHlodRasterVisibility;
        [SerializeField] private Transform observer;
        [SerializeField,Tooltip("Explicit additional distance-demand viewpoints. The legacy observer or main camera remains included; camera eligibility is controlled by the application.")]
        private Transform[] additionalObservers=Array.Empty<Transform>();
        [SerializeField,Min(0f)] private float loadDistance=60f,unloadDistance=90f;
        [SerializeField] private int priority;
        private static readonly List<HybridLumenGIStreamedRepresentation> active=new List<HybridLumenGIStreamedRepresentation>();
        private readonly List<HybridLumenGIAssetPageStreaming.Lease> leases=new List<HybridLumenGIAssetPageStreaming.Lease>();
        private HybridLumenGIAssetPageStreaming pageState;
        private Mesh loadedMesh;
        private Material[] loadedMaterials;
        private HybridLumenGIMeshSdf loadedSdf;
        private HybridLumenGISurfaceCharts loadedCharts;
        private RetireCompletion retirement;
        private string[] pageIds;
        private bool wanted,manualWanted,manualPrefetch,manualMode,unavailable,bound,failed;
        public static IReadOnlyList<HybridLumenGIStreamedRepresentation> Active=>active;
        public uint Generation { get; private set; }
        public bool WantsUnload=>bound && (!wanted || unavailable);
        public bool HasBoundAssets=>bound;
        public bool IsUnavailable=>unavailable;
        public HybridLumenGIProxy Proxy=>proxy;
        public Renderer SourceRenderer=>targetRenderer;
        public string LastError { get; private set; }
        internal bool UsesHlodRasterVisibility => useHlodRasterVisibility;
        internal bool CanSubmitHlodRaster => useHlodRasterVisibility && bound && !unavailable &&
            targetRenderer != null && targetRenderer.enabled && targetRenderer.gameObject.activeInHierarchy;
        public void Configure(HybridLumenGIAssetPageStreamer owner,HybridLumenGIProxy source,MeshFilter filter,MeshRenderer renderer,
            string mesh,string sdf,string charts,string[] materials,Bounds bounds)
        {
            if(bound || leases.Count!=0)throw new InvalidOperationException("Cannot reconfigure a resident representation.");
            streamer=owner;proxy=source;meshFilter=filter;targetRenderer=renderer;
            geometryPage=mesh;sdfPage=sdf;chartPage=charts;materialPages=materials??Array.Empty<string>();localBounds=bounds;pageIds=null;
        }
        /// <summary>Configure all members of an authored group before enabling its streamed rig.</summary>
        public void UseHlodPublicationForRendering(bool value)
        {
            if (useHlodRasterVisibility == value) return;
            useHlodRasterVisibility = value;
            if (targetRenderer != null) targetRenderer.forceRenderingOff = value;
        }
        internal void SetHlodRasterVisible(bool visible)
        {
            if (useHlodRasterVisibility && targetRenderer != null) targetRenderer.forceRenderingOff = !visible;
        }
        public void SetWanted(bool value)=>SetWanted(value,false);
        internal void SetWanted(bool value,bool prefetchPages)
        {manualMode=true;manualWanted=value;manualPrefetch=prefetchPages && !value;}
        public void UseDistanceRequests(){manualMode=false;}
        /// <summary>Copies additional viewpoints without changing manual-mode priority.
        /// Null/empty removes the additions, retaining the legacy observer/main-camera behavior.</summary>
        public void SetAdditionalObservers(params Transform[] value)
        {additionalObservers=value==null || value.Length==0?Array.Empty<Transform>():(Transform[])value.Clone();}
        public void ConfigureDistances(float load,float unload)
        {loadDistance=Mathf.Max(0f,load);unloadDistance=Mathf.Max(loadDistance,unload);}
        private void OnEnable()
        {
            if (!Application.isPlaying) return;
            SetHlodRasterVisible(false);
            unavailable = false;
            if (!active.Contains(this)) active.Add(this);
            HybridLumenGIResourceRetirement.EnsureRegistered();
        }
        private void OnDisable()
        {
            SetHlodRasterVisible(false);
            unavailable = true;
            wanted = false;
            if (bound) HybridLumenGIResourceRetirement.RequestUnavailableRepresentationRetirement();
            else RemoveRequests();
        }
        private void OnDestroy()
        {
            unavailable = true;
            wanted = false;
            RemoveRequests();
            if (bound) HybridLumenGIResourceRetirement.RequestUnavailableRepresentationRetirement();
            else if (retirement == null) active.Remove(this);
        }
        private void Update()
        {
            if(unavailable || failed || retirement!=null)return;
            bool pagesAvailable = streamer != null && streamer.Available;
            // A bound representation can still withdraw its demand after the driver is destroyed.
            if (!pagesAvailable && !bound) return;
            if(proxy==null || meshFilter==null || targetRenderer==null || meshFilter.gameObject!=targetRenderer.gameObject)
            {Fail("A representation requires a proxy and a MeshFilter/MeshRenderer pair.");return;}
            if(pageIds==null)
            {
                // An empty destination prevents hidden strong references to the complete source
                // scene from defeating streaming. The exporter creates this destination for you.
                if(meshFilter.sharedMesh!=null || targetRenderer.sharedMaterials.Length!=0 || proxy.MeshSdf!=null || proxy.SurfaceCharts!=null)
                {Fail("Streamed destinations must start with empty mesh/material/SDF/chart bindings.");return;}
                var ids=new HashSet<string>(StringComparer.Ordinal);
                if(string.IsNullOrEmpty(geometryPage) || materialPages.Length==0){Fail("Geometry and material pages are required.");return;}
                ids.Add(geometryPage);if(!string.IsNullOrEmpty(sdfPage))ids.Add(sdfPage);if(!string.IsNullOrEmpty(chartPage))ids.Add(chartPage);
                foreach(string id in materialPages){if(string.IsNullOrEmpty(id)){Fail("Every material slot needs a page.");return;}ids.Add(id);}
                pageIds=new string[ids.Count];ids.CopyTo(pageIds);targetRenderer.enabled=false;proxy.enabled=false;
            }
            if(manualMode)wanted=manualWanted;
            else
            {
                Transform target=observer!=null?observer:Camera.main!=null?Camera.main.transform:null;
                int count=additionalObservers?.Length??0;
                if(target!=null || count>0)
                {
                    Bounds bounds=GetWorldBounds();
                    bool hasObserver=false;float nearestSquared=float.PositiveInfinity;
                    for(int i=-1;i<count;i++)
                    {
                        Transform current=i<0?target:additionalObservers[i];
                        if(current==null)continue;
                        hasObserver=true;nearestSquared=Mathf.Min(nearestSquared,bounds.SqrDistance(current.position));
                    }
                    // No live viewpoint retains the existing state, as in legacy single-view mode.
                    if(hasObserver)
                    {
                        float distance=wanted?Mathf.Max(loadDistance,unloadDistance):loadDistance;
                        wanted=nearestSquared<=distance*distance;
                    }
                }
            }
            if (!pagesAvailable) return;
            bool prefetchOnly=manualMode && manualPrefetch && !wanted && !bound;
            if(!wanted && !prefetchOnly){if(!bound)RemoveRequests();return;}
            if(!streamer.SetRequests(this,pageIds,prefetchOnly?int.MinValue:priority)){Fail("A requested asset page is absent from the manifest.");return;}
            // Speculative demand may load pages. Only current demand acquires leases and binds the renderer.
            if(prefetchOnly || bound)return;
            pageState=streamer.State;
            // Acquire only when the entire group is ready. No partial renderer is ever visible.
            foreach(string id in pageIds)if(pageState.GetState(id)?.Status!=HybridLumenGIAssetPageStreaming.Phase.Ready)return;
            foreach(string id in pageIds)
            {
                if(!streamer.TryAcquire(id,out var lease)){ReleaseUnpublished();return;}
                leases.Add(lease);
            }
            loadedMesh=Find(geometryPage) as Mesh;loadedSdf=Find(sdfPage) as HybridLumenGIMeshSdf;loadedCharts=Find(chartPage) as HybridLumenGISurfaceCharts;
            loadedMaterials=new Material[materialPages.Length];for(int i=0;i<materialPages.Length;i++)loadedMaterials[i]=Find(materialPages[i]) as Material;
            if(loadedMesh==null || loadedMesh.subMeshCount!=loadedMaterials.Length || Array.Exists(loadedMaterials,m=>m==null) ||
                (!string.IsNullOrEmpty(sdfPage) && (loadedSdf==null || loadedSdf.SourceMesh!=loadedMesh)) ||
                (!string.IsNullOrEmpty(chartPage) && (loadedCharts==null || loadedCharts.SourceMesh!=loadedMesh)))
            {ReleaseUnpublished();Fail("Page types, source mesh identities or material/submesh slots do not agree.");return;}
            if(Generation==uint.MaxValue){ReleaseUnpublished();Fail("Representation generation space exhausted.");return;}
            Generation++;meshFilter.sharedMesh=loadedMesh;targetRenderer.sharedMaterials=loadedMaterials;
            proxy.SetSources(targetRenderer,null);proxy.SetMeshSdf(loadedSdf);proxy.SetSurfaceCharts(loadedCharts);
            targetRenderer.enabled=true;proxy.enabled=true;proxy.MarkDirty();bound=true;
        }
        internal Bounds GetWorldBounds()
        {
            Matrix4x4 matrix = transform.localToWorldMatrix;
            Vector3 x = matrix.MultiplyVector(new Vector3(localBounds.extents.x, 0, 0));
            Vector3 y = matrix.MultiplyVector(new Vector3(0, localBounds.extents.y, 0));
            Vector3 z = matrix.MultiplyVector(new Vector3(0, 0, localBounds.extents.z));
            var extents = new Vector3(Mathf.Abs(x.x) + Mathf.Abs(y.x) + Mathf.Abs(z.x),
                Mathf.Abs(x.y) + Mathf.Abs(y.y) + Mathf.Abs(z.y), Mathf.Abs(x.z) + Mathf.Abs(y.z) + Mathf.Abs(z.z));
            return new Bounds(matrix.MultiplyPoint3x4(localBounds.center), extents * 2f);
        }
        private object Find(string id)
        {foreach(var lease in leases)if(lease.Id==id)return lease.Asset;return null;}
        private void RemoveRequests(){if(!ReferenceEquals(streamer,null))streamer.RemoveRequests(this);}
        private void Fail(string error){failed=true;LastError=error;RemoveRequests();Debug.LogError("HybridLumenGI asset representation: "+error,this);}
        private sealed class Complete : HybridLumenGIAssetPageStreaming.ICompletion
        {internal static readonly Complete Instance=new Complete();public bool IsComplete=>true;}
        private void ReleaseUnpublished()
        {
            foreach(var lease in leases)pageState.ReleaseAfter(lease,Complete.Instance);
            leases.Clear();loadedMesh=null;loadedMaterials=null;loadedSdf=null;loadedCharts=null;
        }
        private sealed class RetireCompletion : HybridLumenGIAssetPageStreaming.ICompletion
        {
            internal HybridLumenGIAssetPageStreaming.ICompletion frame;
            public bool IsComplete
            {
                get=>frame.IsComplete;
            }
        }
        /// <summary>
        /// Must be called only after every camera stopped using this representation and any
        /// required HLOD replacement is published. Detaches now; completion must cover subsequent
        /// end-of-frame submission (including ordinary URP consumers after the GI pass).
        /// </summary>
        public bool ReportUnloadSafe(uint generation,HybridLumenGIAssetPageStreaming.ICompletion completion)
        {
            if(!WantsUnload || generation!=Generation || completion==null || retirement!=null)return false;
            if(targetRenderer!=null){targetRenderer.enabled=false;targetRenderer.sharedMaterials=Array.Empty<Material>();}
            if(meshFilter!=null)meshFilter.sharedMesh=null;
            if(proxy!=null){proxy.enabled=false;proxy.SetMeshSdf(null);proxy.SetSurfaceCharts(null);proxy.MarkDirty();}
            RemoveRequests();retirement=new RetireCompletion{frame=completion};
            foreach(var lease in leases)pageState.ReleaseAfter(lease,retirement);
            leases.Clear();bound=false;loadedMesh=null;loadedMaterials=null;loadedSdf=null;loadedCharts=null;
            return true;
        }
        internal static void PollRetirements()
        {
            for(int i=active.Count-1;i>=0;i--)
            {
                var item=active[i];if(item.retirement==null)continue;
                bool complete=false;try{complete=item.retirement.IsComplete;}catch(Exception){ }
                if(!complete)continue;item.retirement=null;
                if(item==null || item.unavailable)active.RemoveAt(i);
            }
        }
    }
}
