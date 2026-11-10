using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using UnityEngine;
using UnityEngine.Rendering;
using Stopwatch = System.Diagnostics.Stopwatch;

namespace HybridLumenGI
{
    /// <summary>
    /// Budgeted immutable GI snapshots of skinning or explicitly dirtied readable meshes.
    /// Mesh/SDF/charts publish together; the visible renderer continues to use its original mesh.
    /// Workers only access copied arrays. GPU/custom deformation producers must first supply a
    /// readable mesh snapshot and call RequestCapture; GPU vertex-buffer writes are not inferred.
    /// </summary>
    [DisallowMultipleComponent,RequireComponent(typeof(HybridLumenGIProxy))]
    public sealed class HybridLumenGIDeformedMesh : MonoBehaviour
    {
        [Range(16,64)] public int sdfResolution=32;
        [Min(1)] public int updateIntervalFrames=4;
        [Min(3)] public int maximumVertices=65536;
        [Min(1)] public int maximumTriangles=100000;
        public HybridLumenGISurfaceCharts.BakeSettings chartSettings=new HybridLumenGISurfaceCharts.BakeSettings();
        public string Status { get; private set; }="Waiting for a GI geometry snapshot";
        public int PublishedFrame { get; private set; }=-1;
        public int PendingFrame { get; private set; }=-1;
        // Shared across instances/cameras. Reserved bytes include old snapshots awaiting fences
        // and cancelled workers until they actually finish; these are logical byte estimates.
        public static int VertexBudgetPerFrame=65536,MaximumWorkers=2;
        public static long MemoryBudgetBytes=128L*1024*1024,UploadBudgetBytesPerFrame=8L*1024*1024;
        /// <summary>
        /// Optional shared elapsed-time allowance for main-thread capture per engine frame. Zero, negative or
        /// nonfinite values disable it. After complete synchronous capture attempts
        /// consume this time, defer starting another capture without advancing its turn.
        /// Includes copy/BakeMesh, captured-content checks, job setup and failed/unchanged
        /// attempt cleanup; excludes scheduling scans, completed-job publication and workers.
        /// A single capture is not preemptible and may exceed this allowance.
        /// </summary>
        public static double CaptureBudgetMillisecondsPerFrame;
        /// <summary>
        /// Optional shared elapsed-time allowance for starting synchronous snapshot publications per engine frame.
        /// Zero, negative or nonfinite values disable it. Each admitted attempt runs to completion.
        /// Ready snapshots deferred by this allowance keep their queue order and memory reservation.
        /// </summary>
        public static double PublicationBudgetMillisecondsPerFrame;
        public static long ReservedBytes { get; private set; }
        public static int PendingWorkerCount=>Jobs.Count;
        public static int PublishedSnapshotCount=>Published.Count;
        public static int FailedCleanupCount {get{int n=0;foreach(var job in Jobs)if(job.cleanupFailed)n++;return n;}}
        private static readonly List<HybridLumenGIDeformedMesh> Active=new List<HybridLumenGIDeformedMesh>();
        private static readonly List<Job> Jobs=new List<Job>();
        private static readonly Dictionary<Renderer,Snapshot> Published=new Dictionary<Renderer,Snapshot>();
        private static int cursor,lastFrame=-1;
        private static bool subscribed;
        private HybridLumenGIProxy proxy;
        private Renderer source;
        private Mesh explicitSource;
        private uint generation=1;
        private bool requested=true;
        private int lastCapture=-1000000;

        private sealed class Snapshot
        {
            internal HybridLumenGIDeformedMesh owner;
            internal Mesh mesh,capture;
            internal Mesh bakedSourceMesh;
            internal HybridLumenGIMeshSource.Version bakedSourceVersion;
            internal Texture3D texture;
            internal HybridLumenGIMeshSdf sdf;
            internal HybridLumenGISurfaceCharts charts;
            internal long reservation,uploadBytes;
            internal string contentFingerprint;
            internal int sdfSize;
            internal HybridLumenGISurfaceCharts.BakeSettings capturedSettings;
            internal void Destroy()
            {
                CoreUtils.Destroy(charts);CoreUtils.Destroy(sdf);CoreUtils.Destroy(texture);
                CoreUtils.Destroy(capture);CoreUtils.Destroy(mesh);
                ReservedBytes-=reservation;reservation=0;
            }
        }
        private sealed class Result
        {
            internal float[] distances;
            internal Bounds bounds;
            internal bool closed;
            internal HybridLumenGISurfaceCharts.Chart[] charts;
        }
        private sealed class Job
        {
            internal HybridLumenGIDeformedMesh owner;
            internal Renderer source;
            internal uint generation;
            internal int frame,size;
            internal Snapshot snapshot;
            internal CancellationTokenSource cancellation=new CancellationTokenSource();
            internal Task<Result> work;
            internal int workerSlots = 1;
            internal bool cleanupFailed;
        }

        private static bool SameCapturedContent(Snapshot next,Snapshot published)
        {
            var a=next.capturedSettings;var b=published.capturedSettings;
            return ReferenceEquals(next.owner,published.owner) && !string.IsNullOrEmpty(next.contentFingerprint) &&
                ReferenceEquals(next.bakedSourceVersion,published.bakedSourceVersion) &&
                string.Equals(next.contentFingerprint,published.contentFingerprint,StringComparison.Ordinal) && next.sdfSize==published.sdfSize &&
                a!=null && b!=null && a.maxNormalAngleDegrees==b.maxNormalAngleDegrees && a.paddingFraction==b.paddingFraction &&
                a.minimumPadding==b.minimumPadding && a.maxTrianglesPerChart==b.maxTrianglesPerChart && a.chartBudget==b.chartBudget;
        }

        private static bool BakedSourceIsCurrent(Snapshot snapshot,Renderer renderer)
        {
            // Explicit producer meshes have their own request and cancellation contract.
            Mesh captured=snapshot.bakedSourceMesh;
            return ReferenceEquals(captured,null) || (captured!=null && renderer!=null &&
                renderer is SkinnedMeshRenderer skin && ReferenceEquals(skin.sharedMesh,captured) &&
                ReferenceEquals(snapshot.bakedSourceVersion,HybridLumenGIMeshSource.GetVersion(captured)));
        }

        public static bool HasSnapshot(Renderer renderer) => renderer!=null && Published.ContainsKey(renderer);
        public static Mesh GetSourceMesh(Renderer renderer)
        {
            if(renderer==null)return null;
            if(Published.TryGetValue(renderer,out var snapshot))return snapshot.mesh;
            if(renderer is SkinnedMeshRenderer skin)return skin.sharedMesh;
            return renderer.GetComponent<MeshFilter>()?.sharedMesh;
        }
        internal static HybridLumenGIMeshSdf GetSdf(Renderer renderer,HybridLumenGIMeshSdf authored)
            => renderer!=null && Published.TryGetValue(renderer,out var snapshot)?snapshot.sdf:authored;
        internal static HybridLumenGISurfaceCharts GetCharts(Renderer renderer,HybridLumenGISurfaceCharts authored)
            => renderer!=null && Published.TryGetValue(renderer,out var snapshot)?snapshot.charts:authored;
        internal static Bounds BoundsOf(Renderer renderer)
        {
            Mesh mesh=GetSourceMesh(renderer);
            if(mesh==null)return renderer.bounds;
            var b=mesh.bounds;var m=renderer.localToWorldMatrix;
            Vector3 x=m.MultiplyVector(new Vector3(b.extents.x,0,0)),y=m.MultiplyVector(new Vector3(0,b.extents.y,0)),z=m.MultiplyVector(new Vector3(0,0,b.extents.z));
            return new Bounds(m.MultiplyPoint3x4(b.center),new Vector3(Mathf.Abs(x.x)+Mathf.Abs(y.x)+Mathf.Abs(z.x),
                Mathf.Abs(x.y)+Mathf.Abs(y.y)+Mathf.Abs(z.y),Mathf.Abs(x.z)+Mathf.Abs(y.z)+Mathf.Abs(z.z))*2);
        }
        private void OnEnable()
        {
            proxy=GetComponent<HybridLumenGIProxy>();source=proxy.SourceRenderer;
            if(source==null)source=GetComponent<Renderer>();
            HybridLumenGIResourceRetirement.RegisterShutdownOwner(WithdrawForShutdown);
            if(HybridLumenGIResourceRetirement.AdmissionClosed){WithdrawForShutdown();return;}
            if(!Active.Contains(this))Active.Add(this);
            requested=true;
            if(!subscribed) { RenderPipelineManager.beginContextRendering+=BeginContext;subscribed=true; }
        }
        private void OnDisable()
        {
            HybridLumenGIResourceRetirement.UnregisterShutdownOwner(WithdrawForShutdown);
            Active.Remove(this);generation++;
            foreach(var job in Jobs)if(ReferenceEquals(job.owner,this))job.cancellation.Cancel();
            Withdraw();
        }
        private void WithdrawForShutdown()
        {
            Active.Remove(this);generation++;requested=false;
            foreach(var job in Jobs)if(ReferenceEquals(job.owner,this))job.cancellation.Cancel();
            Withdraw();
        }
        internal static bool PollShutdownWork()
        {
            bool cancelledWorkerRunning=false;
            for(int i=Jobs.Count-1;i>=0;i--)
            {
                var job=Jobs[i];if(job.cleanupFailed || !job.cancellation.IsCancellationRequested)continue;
                if(!job.work.IsCompleted){cancelledWorkerRunning=true;continue;}
                // Workers only read copied CPU arrays. An unpublished snapshot has no GPU
                // readers, but it cannot be destroyed while its worker is still running.
                try{job.work.GetAwaiter().GetResult();}catch(Exception){ }
                try{job.snapshot.Destroy();job.cancellation.Dispose();Jobs.RemoveAt(i);}
                catch(Exception error){job.cleanupFailed=true;Debug.LogException(error);}
            }
            return cancelledWorkerRunning;
        }
        private void Withdraw()
        {
            if(!ReferenceEquals(source,null) && Published.TryGetValue(source,out var old) && ReferenceEquals(old.owner,this))
            {
                Published.Remove(source);
                if(proxy!=null)proxy.MarkGeometryRepresentationChanged();
                HybridLumenGIResourceRetirement.Retire(old.Destroy);
            }
        }
        /// <summary>Main thread: optionally supplies a producer-owned readable snapshot, copied at capture.</summary>
        public void RequestCapture(Mesh readableSnapshot=null)
        {
            explicitSource=readableSnapshot;requested=true;generation++;
            foreach(var job in Jobs)if(ReferenceEquals(job.owner,this))job.cancellation.Cancel();
        }
        /// <summary>Main thread: keeps only the latest next-capture demand without cancelling
        /// an already captured snapshot. Input is borrowed and copied at actual capture, not
        /// at this call; intermediate requests may merge. Existing budgets and revocation apply.</summary>
        public void RequestCoalescedCapture(Mesh readableSnapshot=null)
        {
            explicitSource=readableSnapshot;requested=true;
        }
        /// <summary>Recheck snapshot ownership before a camera consumes the world representation.</summary>
        internal static void RefreshRenderSources()
        {
            foreach(var owner in Active)
            {
                if(owner==null || owner.proxy==null)continue;
                Renderer current=owner.proxy.SourceRenderer;
                if(current==null)current=owner.GetComponent<Renderer>();
                if(ReferenceEquals(current,owner.source))
                {
                    if(current is SkinnedMeshRenderer && Published.TryGetValue(current,out var snapshot) &&
                        ReferenceEquals(snapshot.owner,owner) && !BakedSourceIsCurrent(snapshot,current)) owner.Withdraw();
                    continue;
                }
                owner.Withdraw();owner.source=current;owner.generation++;owner.requested=true;
                foreach(var job in Jobs)if(ReferenceEquals(job.owner,owner))job.cancellation.Cancel();
            }
            foreach (var job in Jobs)
                if (!job.cleanupFailed && !job.cancellation.IsCancellationRequested && !BakedSourceIsCurrent(job.snapshot, job.source))
                    job.cancellation.Cancel();
        }

        private static void BeginContext(ScriptableRenderContext context,List<Camera> cameras)
        {
            if(HybridLumenGIResourceRetirement.AdmissionClosed){PollShutdownWork();return;}
            if(lastFrame==Time.frameCount)return;
            lastFrame=Time.frameCount;
            RefreshRenderSources();
            long uploadBudget = Math.Max(0, UploadBudgetBytesPerFrame);
            long uploadLeft = uploadBudget;
            double publicationBudget = PublicationBudgetMillisecondsPerFrame;
            bool publicationTimeLimited = publicationBudget > 0 && !double.IsNaN(publicationBudget) && !double.IsInfinity(publicationBudget);
            double publicationMilliseconds = 0;
            int occupiedCaptureSlots = 0;
            // Spend publication quota in capture order so repeated new completions
            // cannot starve an older ready snapshot. Unfinished work is still skipped.
            for(int i=0;i<Jobs.Count;i++)
            {
                Job job=Jobs[i];
                // A failed cleanup retains ownership and bytes, but the worker has finished.
                if(job.cleanupFailed)continue;
                if(!job.work.IsCompleted)
                {
                    occupiedCaptureSlots += job.workerSlots;
                    continue;
                }
                bool current=job.owner!=null && job.owner.isActiveAndEnabled && job.owner.generation==job.generation &&
                    job.source!=null && ReferenceEquals(job.owner.source,job.source) && !job.cancellation.IsCancellationRequested &&
                    BakedSourceIsCurrent(job.snapshot,job.source);
                Result result=null;
                try { result=job.work.GetAwaiter().GetResult(); }
                catch(Exception ex) { if(current)job.owner.Status="Geometry bake failed: "+ex.GetType().Name; }
                long upload=job.snapshot.uploadBytes;
                if (current && result != null && upload > uploadLeft)
                {
                    // Keep the snapshot and its memory reservation. A finished job that
                    // cannot fit even in a fresh frame need not occupy a capture slot.
                    if (upload <= uploadBudget) occupiedCaptureSlots++;
                    job.owner.Status = "Snapshot ready; upload budget pending";
                    continue;
                }
                if(!current || result==null)
                {
                    // A cancelled old-session worker can finish between IdleUpdate and
                    // this callback. Preserve ownership if native cleanup fails here too.
                    try{job.snapshot.Destroy();job.cancellation.Dispose();Jobs.RemoveAt(i--);}
                    catch(Exception error){job.cleanupFailed=true;Debug.LogException(error);}
                    continue;
                }
                if (publicationTimeLimited && publicationMilliseconds >= publicationBudget)
                {
                    occupiedCaptureSlots++;
                    job.owner.Status = "Snapshot ready, publication time budget pending";
                    continue;
                }
                Snapshot old=null;
                long publicationStarted = publicationTimeLimited ? Stopwatch.GetTimestamp() : 0;
                try
                {
                    uploadLeft-=upload;
                    Snapshot next=job.snapshot;
                    next.texture=new Texture3D(job.size,job.size,job.size,TextureFormat.RFloat,false)
                        {name="HLGI deformed SDF",hideFlags=HideFlags.HideAndDontSave,wrapMode=TextureWrapMode.Clamp,filterMode=FilterMode.Bilinear};
                    next.texture.SetPixelData(result.distances,0);next.texture.Apply(false,false);
                    next.sdf=ScriptableObject.CreateInstance<HybridLumenGIMeshSdf>();next.sdf.hideFlags=HideFlags.HideAndDontSave;
                    next.sdf.SetBakedData(next.mesh,next.texture,result.bounds,job.size,result.closed);
                    next.capture=HybridLumenGISurfaceCharts.CreateCaptureMesh(next.mesh,result.charts);next.capture.hideFlags=HideFlags.HideAndDontSave;
                    next.charts=ScriptableObject.CreateInstance<HybridLumenGISurfaceCharts>();next.charts.hideFlags=HideFlags.HideAndDontSave;
                    next.charts.SetBakedData(next.mesh,next.capture,result.charts);
                    if(Published.TryGetValue(job.source,out old) && !ReferenceEquals(old.owner,job.owner))
                        throw new InvalidOperationException("A second component owns this renderer's geometry snapshot.");
                    Published[job.source]=next;
                    job.owner.proxy.MarkDirty();job.owner.PublishedFrame=job.frame;job.owner.PendingFrame=-1;
                    job.owner.Status="Mesh, SDF and charts published together; GPU residency pending";
                    if(old!=null)HybridLumenGIResourceRetirement.Retire(old.Destroy);
                }
                catch(Exception ex)
                {
                    // Never leave a published reference to an object being destroyed.
                    if(Published.TryGetValue(job.source,out var live) && ReferenceEquals(live,job.snapshot))
                    { if(old!=null)Published[job.source]=old;else Published.Remove(job.source); }
                    job.owner.Status="Snapshot publication failed: "+ex.GetType().Name;
                    try{job.snapshot.Destroy();}
                    catch(Exception cleanupError)
                    {
                        // Destruction may be partial. Keep the private owner and reservation,
                        // including its live cancellation source, without automatically retrying.
                        job.cleanupFailed=true;job.owner.Status+="; cleanup failed; snapshot retained";
                        Debug.LogException(ex);Debug.LogException(cleanupError);continue;
                    }
                }
                finally
                {
                    if (publicationTimeLimited)
                        publicationMilliseconds += (Stopwatch.GetTimestamp() - publicationStarted) * (1000.0 / Stopwatch.Frequency);
                }
                // Ownership is now transferred to Published or private cleanup succeeded.
                job.cancellation.Dispose();Jobs.RemoveAt(i--);
            }
            double captureBudget=CaptureBudgetMillisecondsPerFrame;
            bool captureTimeLimited=captureBudget>0 && !double.IsNaN(captureBudget) && !double.IsInfinity(captureBudget);
            double captureMilliseconds=0;
            int vertexBudget=Math.Max(0,VertexBudgetPerFrame);
            int verticesLeft=vertexBudget,visits=Active.Count,firstVertexWaiter=-1;
            while (visits-- > 0 && Active.Count > 0 && occupiedCaptureSlots < Math.Max(0, MaximumWorkers))
            {
                // Leave the next owner's turn and demand untouched. At least one
                // otherwise eligible capture can start even with a very small allowance.
                if(captureTimeLimited && captureMilliseconds>=captureBudget)break;
                cursor%=Active.Count;var owner=Active[cursor++];
                if(owner==null || !owner.isActiveAndEnabled || owner.source==null || owner.proxy==null)continue;
                bool pending=false;foreach(var job in Jobs)pending|=ReferenceEquals(job.owner,owner);
                if(pending || Time.frameCount-owner.lastCapture<Math.Max(1,owner.updateIntervalFrames))continue;
                Mesh original=owner.explicitSource;
                var skin=owner.source as SkinnedMeshRenderer;
                // Only a cleared managed reference selects automatic skin capture.
                bool skinCapture=ReferenceEquals(original,null) && skin!=null;
                if(!owner.requested && !skinCapture)continue;
                original??=skinCapture?skin.sharedMesh:owner.source.GetComponent<MeshFilter>()?.sharedMesh;
                if(original==null || original.vertexCount<3 || original.vertexCount>Math.Max(3,owner.maximumVertices))
                { owner.Status="No source mesh within the vertex limit";continue; }
                int vertices=original.vertexCount;long indices=0;
                for(int sub=0;sub<original.subMeshCount;sub++)indices+=(long)original.GetIndexCount(sub);
                if(indices/3>Math.Max(1,owner.maximumTriangles)) { owner.Status="Source exceeds triangle limit";continue; }
                if(vertices>vertexBudget) { owner.Status="Capture vertex budget pending";continue; }
                int size=Mathf.Clamp(owner.sdfResolution,16,64);
                // Includes copied streams, two owned meshes, output volume and conservative
                // triangle/chart working storage. Driver/Unity allocator overhead is not measured.
                long vertexBytes=0;
                for(int stream=0;stream<original.vertexBufferCount;stream++)vertexBytes+=vertices*(long)original.GetVertexBufferStride(stream);
                long reservation=checked(vertexBytes*4+vertices*192L+indices*192L+size*(long)size*size*8+4096);
                long uploadBytes=checked(Math.Max(vertexBytes*2,vertices*96L)+indices*8L+size*(long)size*size*4);
                if(uploadBytes>Math.Max(0,UploadBudgetBytesPerFrame)) { owner.Status="Snapshot exceeds per-frame publication byte budget";continue; }
                if(reservation>Math.Max(0,MemoryBudgetBytes)-ReservedBytes) { owner.Status="Geometry memory budget pending";continue; }
                if(vertices>verticesLeft)
                {
                    owner.Status="Capture vertex budget pending";
                    // Keep the first eligible turn while smaller captures use the remaining vertices.
                    if(firstVertexWaiter<0)firstVertexWaiter=cursor-1;
                    continue;
                }
                var next=new Snapshot{owner=owner,reservation=reservation,uploadBytes=uploadBytes};ReservedBytes+=reservation;
                // Failed capture attempts consume the same frame quota and retry interval.
                verticesLeft-=vertices;owner.lastCapture=Time.frameCount;
                long captureStarted=captureTimeLimited?Stopwatch.GetTimestamp():0;
                try
                {
                    bool automaticSkinCapture=skinCapture && !owner.requested;
                    if(skinCapture)
                    {
                        next.bakedSourceMesh=original;
                        next.bakedSourceVersion=HybridLumenGIMeshSource.GetVersion(original);
                        next.mesh=new Mesh{name="HLGI baked deformation",hideFlags=HideFlags.HideAndDontSave};
                        skin.BakeMesh(next.mesh,false); // Local positions; renderer transform is applied once.
                    }
                    else
                    {
                        if(!original.isReadable)throw new InvalidOperationException("The supplied mesh must be readable.");
                        // The GI snapshot needs these streams only. Do not clone arbitrary
                        // blend-shape/bone/custom streams that its byte quota did not reserve.
                        next.mesh=new Mesh{name="HLGI readable deformation",hideFlags=HideFlags.HideAndDontSave,
                            indexFormat=IndexFormat.UInt32,vertices=original.vertices,normals=original.normals,tangents=original.tangents,uv=original.uv};
                        next.mesh.subMeshCount=original.subMeshCount;
                        for(int sub=0;sub<original.subMeshCount;sub++)next.mesh.SetIndices(original.GetIndices(sub,true),original.GetTopology(sub),sub,false);
                        next.mesh.bounds=original.bounds;
                    }
                    Vector3[] positions=next.mesh.vertices;var submeshes=new int[next.mesh.subMeshCount][];
                    var flat=new List<int>((int)Math.Min(indices,int.MaxValue));
                    for(int sub=0;sub<submeshes.Length;sub++)
                    {
                        if(next.mesh.GetTopology(sub)!=MeshTopology.Triangles)throw new InvalidOperationException("Triangle submeshes required.");
                        submeshes[sub]=next.mesh.GetIndices(sub,true);flat.AddRange(submeshes[sub]);
                    }
                    var settings=owner.chartSettings??new HybridLumenGISurfaceCharts.BakeSettings();
                    var frozenSettings=new HybridLumenGISurfaceCharts.BakeSettings{maxNormalAngleDegrees=settings.maxNormalAngleDegrees,
                        paddingFraction=settings.paddingFraction,minimumPadding=settings.minimumPadding,maxTrianglesPerChart=settings.maxTrianglesPerChart,chartBudget=settings.chartBudget};
                    next.sdfSize=size;next.capturedSettings=frozenSettings;
                    // Compare actual captured streams/layout, never bone matrices or source counts.
                    // Metadata on a private/in-flight candidate is not reuse authority: only Published is.
                    if(skinCapture)next.contentFingerprint=HybridLumenGISurfaceCharts.ComputeContentFingerprint(next.mesh);
                    if(automaticSkinCapture && Published.TryGetValue(owner.source,out var published) && SameCapturedContent(next,published))
                    {
                        owner.Status="Unchanged automatic capture; published snapshot retained";
                        try{next.Destroy();}
                        catch(Exception cleanupError)
                        {
                            // This private mesh had no worker or GPU readers. Retain failed ownership
                            // through the existing failure policy; do not fall into the outer Destroy.
                            Jobs.Add(new Job{owner=owner,source=owner.source,generation=owner.generation,frame=Time.frameCount,size=size,
                                snapshot=next,work=Task.FromResult<Result>(null),cleanupFailed=true});
                            owner.Status="Unchanged capture cleanup failed; private snapshot retained";Debug.LogException(cleanupError);
                        }
                        continue;
                    }
                    // A sole source can borrow a spare slot for the SDF slices. Count it
                    // until the whole task joins so a newly active owner cannot overbook it.
                    int availableWorkers = Math.Max(0, MaximumWorkers) - occupiedCaptureSlots;
                    bool useTwoWorkers = Active.Count == 1 && availableWorkers >= 2 && Environment.ProcessorCount > 1;
                    var job=new Job{owner=owner,source=owner.source,generation=owner.generation,frame=Time.frameCount,size=size,
                        snapshot=next,workerSlots=useTwoWorkers ? 2 : 1};
                    int[] triangles=flat.ToArray();var cancellation=job.cancellation.Token;
                    job.work=Task.Run(()=>
                    {
                        bool Continue(int _,int __)=>!cancellation.IsCancellationRequested;
                        var result=new Result();
                        result.distances=HybridLumenGIMeshSdfBake.BakeWorker(positions,triangles,size,Continue,useTwoWorkers,out result.bounds,out result.closed);
                        if(result.distances==null || cancellation.IsCancellationRequested)return null;
                        result.charts=HybridLumenGISurfaceCharts.BakeTriangles(positions,submeshes,frozenSettings,out _,Continue);
                        return cancellation.IsCancellationRequested?null:result;
                    });
                    Jobs.Add(job);occupiedCaptureSlots+=job.workerSlots;owner.PendingFrame=Time.frameCount;
                    owner.requested=false;owner.Status="Captured; SDF/chart worker pending";
                }
                catch(Exception ex) { next.Destroy();owner.Status="Geometry capture failed: "+ex.GetType().Name; }
                finally
                {
                    // Finally also accounts for failed attempts and the unchanged-skin
                    // early continue; neither can bypass the next-capture allowance.
                    if(captureTimeLimited)
                        captureMilliseconds+=(Stopwatch.GetTimestamp()-captureStarted)*(1000.0/Stopwatch.Frequency);
                }
            }
            if(firstVertexWaiter>=0)cursor=firstVertexWaiter;
        }
    }
}
