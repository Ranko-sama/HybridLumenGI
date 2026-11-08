using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using UnityEngine;
using UnityEngine.Rendering;

namespace HybridLumenGI
{
    /// <summary>
    /// Optional inline-DXR traversal of registered, readable meshes with opaque or alpha-clipped Lit materials.
    /// Every triangle is evaluated as a non-opaque candidate against the frozen UV material batch.
    /// Unsupported instances retain the software representation; arbitrary material graphs are not evaluated.
    /// </summary>
    public sealed class HybridLumenGIHardwareBackend : IDisposable, HybridLumenGIAreaEmission.ITriangleProvider
    {
        [StructLayout(LayoutKind.Sequential)]
        private struct TriangleNormals
        {
            public Vector4 a, b, c, face, uvY; // Object-space normals; a/b/c.w hold UV.x.
        }

        [StructLayout(LayoutKind.Sequential, Pack=4)]
        private struct TriangleSurface
        {
            // Raw object positions (w=finite-valid) and unnormalized source tangents/sign.
            // Addressed with the same normalOffset + native PrimitiveIndex as TriangleNormals.
            public Vector4 p0, p1, p2, t0, t1, t2;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct InstanceData
        {
            public Matrix4x4 normalToWorld;
            public uint slot, normalOffset, triangleCount, submesh;
            public uint stableId, ownerRevision, geometryRevision, cullMode;
            public Vector4 diffuse, emission;
        }

        private sealed class MeshState
        {
            public Mesh mesh;
            public Renderer renderer;
            public Matrix4x4 matrix;
            public int stableId, vertexCount, subMeshCount, firstInstance, instanceCount;
            public uint geometryRevision, layoutGeneration;
            public long indexCount;
            public readonly List<int> handles = new List<int>();
        }

        private static readonly int AccelerationId = UnityEngine.Shader.PropertyToID("_HLGI_AccelerationStructure");
        private static readonly int FlagsId = UnityEngine.Shader.PropertyToID("_HLGI_HardwareMeshFlags");
        private static readonly int CoversPublishedId = UnityEngine.Shader.PropertyToID("_HLGI_ExactCoversPublished");
        private static readonly int InstancesId = UnityEngine.Shader.PropertyToID("_HLGI_HardwareInstances");
        private static readonly int NormalsId = UnityEngine.Shader.PropertyToID("_HLGI_HardwareTriangleNormals");
        private static readonly int SurfaceId = UnityEngine.Shader.PropertyToID("_HLGI_HardwareTriangleSurface");
        private static readonly int BindingsId = UnityEngine.Shader.PropertyToID("_HLGI_HardwareTriangleBindings");
        private static readonly int ObjectToWorldId = UnityEngine.Shader.PropertyToID("_HLGI_HardwareObjectToWorld");
        private readonly List<TriangleNormals> normals = new List<TriangleNormals>();
        private readonly List<TriangleSurface> surfaces = new List<TriangleSurface>();
        private readonly List<InstanceData> instances = new List<InstanceData>();
        private readonly List<Matrix4x4> objectToWorld=new List<Matrix4x4>();
        internal sealed class GeometryAllocations
        {
            internal long AttributeBytes, BvhBytes;
            internal long TotalBytes => AttributeBytes + BvhBytes;
        }
        private readonly GeometryAllocations geometryAllocations;
        private readonly bool softwareOnly;
        public HybridLumenGIHardwareBackend(bool softwareOnly=false)
            : this(new GeometryAllocations(), softwareOnly) { }
        internal HybridLumenGIHardwareBackend(GeometryAllocations geometryAllocations, bool softwareOnly=false)
        {
            this.geometryAllocations = geometryAllocations;
            this.softwareOnly = softwareOnly;
        }
        private readonly List<HybridLumenGISurfaceCache.TriangleChartBinding> bindings = new List<HybridLumenGISurfaceCache.TriangleChartBinding>();
        private readonly List<Vector3> vertices = new List<Vector3>();
        private readonly List<Vector3> vertexNormals = new List<Vector3>();
        private readonly List<Vector2> vertexUVs = new List<Vector2>();
        // Multiple registered renderers may share a Mesh. Read its tangent channel only once
        // per full attribute rebuild, never on a retained-instance pose/material update.
        private readonly Dictionary<Mesh,List<Vector4>> meshTangents = new Dictionary<Mesh,List<Vector4>>();
        private readonly List<Material> sharedMaterials = new List<Material>();
        private readonly List<int> indices = new List<int>();
        private readonly HybridLumenGIMaterialSource hitMaterialSource = new HybridLumenGIMaterialSource();
        private MeshState[] meshStates = Array.Empty<MeshState>();
        private RayTracingAccelerationStructure acceleration;
        private ComputeBuffer flagsBuffer, instancesBuffer, normalsBuffer, surfaceBuffer, bindingsBuffer, objectToWorldBuffer;
        private HybridLumenGISurfaceCache preparedSurfaceCache;
        private uint[] meshFlags = Array.Empty<uint>();
        private int preparedRevision = -1;
        private int preparedBudget;
        private bool buildPending, failed, loggedFailure;
        private readonly object budgetOwner=new object();
        private HybridLumenGIRtasBudget.Reservation reservation;
        private int preparedRtasFrame=int.MinValue;
        private long retiredAttributeBytes;

        public ComputeShader Shader { get; private set; }
        public bool IsReady { get; private set; }
        public int MeshCount { get; private set; }
        public int TriangleCount => normals.Count;
        public int InstanceCount => instances.Count;
        internal bool HasPreparedTriangles(int slot) => slot >= 0 && slot < meshFlags.Length && meshFlags[slot] != 0;
        public ulong GeometryVersion { get; private set; }
        public int FallbackCount { get; private set; }
        // Count allocations, including dummy elements and old buffers still referenced by
        // queued GPU work. CPU list lengths are not a resource lifetime accounting signal.
        public long CurrentAttributeBytes=>BufferBytes(flagsBuffer)+BufferBytes(instancesBuffer)+BufferBytes(normalsBuffer)+
            BufferBytes(surfaceBuffer)+BufferBytes(bindingsBuffer)+BufferBytes(objectToWorldBuffer);
        public long RetiredAttributeBytes=>retiredAttributeBytes;
        // Camera states can share one allowance across their current and detached backends.
        public long AttributeBytes=>geometryAllocations.AttributeBytes;
        public int SceneRebuildCount { get; private set; }
        public int TransformUpdateCount { get; private set; }
        public int TriangleUploadCount { get; private set; }
        public int BindingUploadCount { get; private set; }
        public string BudgetStatus { get; private set; }="Not prepared";
        public bool CanDispatch=>IsReady && (softwareOnly || (!buildPending && reservation!=null && !reservation.IsRetired));
        public long EstimatedAccelerationBytes=>reservation?.EstimatedBytes??0;
        public long MeasuredAccelerationBytes=>reservation?.MeasuredHighWaterBytes??0;
        public long ReservedAccelerationBytes=>reservation?.AccountedBytes??0;
        public ulong AccelerationBytes => buildPending?0:(ulong)MeasuredAccelerationBytes;

        // Read the same immutable attributes and instance transform that Prepare supplied to RTAS.
        // Do not reread a live Mesh here: an emitter sampled from newer vertices would have a
        // different endpoint/PDF than the triangles queried by this prepared backend.
        public int GetTriangleCount(int instance) => IsReady && !failed && instance>=0 && instance<instances.Count
            ? (int)instances[instance].triangleCount : 0;

        public bool TryGetTriangle(int instance,int primitive,out HybridLumenGIAreaEmission.Triangle triangle)
        {
            triangle=default;
            if(primitive<0 || primitive>=GetTriangleCount(instance)) return false;
            InstanceData data=instances[instance];
            if(data.slot>=(uint)meshStates.Length) return false;
            MeshState state=meshStates[(int)data.slot];
            long index=(long)data.normalOffset+primitive;
            if(state==null || instance<state.firstInstance || instance>=state.firstInstance+state.instanceCount ||
                index<0 || index>=surfaces.Count || index>=normals.Count) return false;
            TriangleSurface surface=surfaces[(int)index];
            if(surface.p0.w<0.5f || surface.p1.w<0.5f || surface.p2.w<0.5f) return false;
            Vector3 p0=state.matrix.MultiplyPoint3x4(new Vector3(surface.p0.x,surface.p0.y,surface.p0.z));
            Vector3 p1=state.matrix.MultiplyPoint3x4(new Vector3(surface.p1.x,surface.p1.y,surface.p1.z));
            Vector3 p2=state.matrix.MultiplyPoint3x4(new Vector3(surface.p2.x,surface.p2.y,surface.p2.z));
            Vector4 face=normals[(int)index].face;
            Vector3 raw=data.normalToWorld.MultiplyVector(new Vector3(face.x,face.y,face.z));
            if(!Finite(p0.x)||!Finite(p0.y)||!Finite(p0.z)||!Finite(p1.x)||!Finite(p1.y)||!Finite(p1.z)||
                !Finite(p2.x)||!Finite(p2.y)||!Finite(p2.z)||!Finite(raw.x)||!Finite(raw.y)||!Finite(raw.z)) return false;
            float scale=Mathf.Max(Mathf.Abs(raw.x),Mathf.Max(Mathf.Abs(raw.y),Mathf.Abs(raw.z)));
            if(!(scale>0)) return false;
            float x=raw.x/scale,y=raw.y/scale,z=raw.z/scale;
            float length=Mathf.Sqrt(x*x+y*y+z*z);
            triangle=new HybridLumenGIAreaEmission.Triangle
            {
                P0=p0,P1=p1,P2=p2,RawNg=new Vector3(x/length,y/length,z/length),
                OwnerSlot=data.slot,StableId=data.stableId,OwnerRevision=data.ownerRevision,
                GeometryRevision=data.geometryRevision,Instance=(uint)instance,Submesh=data.submesh,
                Primitive=(uint)primitive,Cull=data.cullMode
            };
            return true;
        }

        /// <summary>
        /// Captures the original renderer/material slot for each retained native instance, in
        /// instance-ID order (empty submeshes remain absent). A mismatch rejects the complete
        /// table. Current-frame RT inputs are allowed; historical reuse is a separate contract.
        /// The material batch must revalidate these frozen snapshots immediately before upload.
        /// </summary>
        public bool TryCaptureHitMaterialSources(HybridLumenGIScene scene,
            out HybridLumenGIHitMaterialBatch.Source[] sources, out string reason)
        {
            sources=null;reason=null;
            if(!IsReady || failed || scene==null || preparedSurfaceCache==null ||
                meshStates.Length!=scene.Capacity || instances.Count==0)
            { reason="Hardware material source table has no current prepared instances.";return false; }
            var captured=new HybridLumenGIHitMaterialBatch.Source[instances.Count];
            try
            {
                for(int i=0;i<instances.Count;i++)
                {
                    if(!TryGetHitMaterialSource(scene,i,out var renderer,out var material,out var tint,out var emission,out reason))return false;
                    InstanceData instance=instances[i];
                    if(!hitMaterialSource.TryCapture(renderer,(int)instance.submesh,material,out var snapshot,out reason) || snapshot==null)
                    { reason=reason??"The original submesh material could not be frozen.";return false; }
                    if(!ReferenceEquals(snapshot.SourceRenderer,renderer) || !ReferenceEquals(snapshot.SourceMaterial,material) ||
                        snapshot.MaterialIndex!=(int)instance.submesh)
                    { reason="Material snapshot identity does not match its native instance.";return false; }
                    captured[i]=new HybridLumenGIHitMaterialBatch.Source(snapshot,instance.stableId,instance.ownerRevision,
                        instance.geometryRevision,instance.submesh,tint,emission);
                }
                // A source callback can change an earlier owner while a later slot is captured.
                // Recheck geometry/owner/binding/proxy parameters before publishing any rows.
                for(int i=0;i<captured.Length;i++)
                {
                    if(!TryGetHitMaterialSource(scene,i,out var renderer,out var material,out var tint,out var emission,out reason))return false;
                    var source=captured[i];
                    if(!ReferenceEquals(renderer,source.Snapshot.SourceRenderer) || !ReferenceEquals(material,source.Snapshot.SourceMaterial) ||
                        !tint.Equals(source.LinearProxyTint) || !emission.Equals(source.LinearProxyEmission))
                    { reason="Hardware material source changed during table capture.";return false; }
                }
            }
            catch(Exception ex) { reason="Hardware material source capture failed: "+ex.GetType().Name;return false; }
            sources=captured;return true;
        }

        private bool TryGetHitMaterialSource(HybridLumenGIScene scene,int instanceIndex,out Renderer renderer,
            out Material material,out Vector4 tint,out Vector4 emission,out string reason)
        {
            renderer=null;material=null;tint=emission=default;reason=null;
            InstanceData instance=instances[instanceIndex];
            if(instance.slot>=(uint)meshStates.Length || instance.submesh>int.MaxValue)
            { reason="Hardware instance indices are outside the prepared source table.";return false; }
            int slot=(int)instance.slot,submesh=(int)instance.submesh;MeshState state=meshStates[slot];
            Vector4 identity=scene.Data[slot].identity;var proxy=scene.GetProxy(slot);
            renderer=scene.GetRenderer(slot);
            Mesh mesh=HybridLumenGIDeformedMesh.GetSourceMesh(renderer);
            if(state==null || proxy==null || !proxy.isActiveAndEnabled || !ExactSource(renderer) || !renderer.enabled ||
                !renderer.gameObject.activeInHierarchy || !ReferenceEquals(proxy.SourceRenderer,renderer) ||
                !ReferenceEquals(state.renderer,renderer) || !ReferenceEquals(state.mesh,mesh) || mesh==null || !mesh.isReadable ||
                !renderer.localToWorldMatrix.Equals(state.matrix) || instanceIndex<state.firstInstance ||
                instanceIndex-state.firstInstance>=state.instanceCount || state.vertexCount!=mesh.vertexCount || state.subMeshCount!=mesh.subMeshCount ||
                submesh>=mesh.subMeshCount || mesh.GetTopology(submesh)!=MeshTopology.Triangles ||
                mesh.GetIndexCount(submesh)!=(ulong)instance.triangleCount*3 || !Published(identity.w) ||
                !Finite(identity) || (double)identity.x!=instance.stableId || (double)identity.y!=instance.ownerRevision ||
                proxy.StableId<=0 || proxy.Revision<=0 || proxy.GeometryContentRevision<=0 ||
                (uint)proxy.StableId!=instance.stableId || (uint)proxy.Revision!=instance.ownerRevision ||
                state.stableId!=proxy.StableId || (uint)proxy.GeometryContentRevision!=instance.geometryRevision ||
                state.geometryRevision!=instance.geometryRevision || preparedSurfaceCache.GetGeometryRevision(slot)!=instance.geometryRevision)
            { reason="Hardware owner, renderer, mesh, pose or geometry identity is stale.";return false; }
            renderer.GetSharedMaterials(sharedMaterials);
            if(submesh>=sharedMaterials.Count || sharedMaterials[submesh]==null)
            { reason="Original hardware submesh material is missing.";return false; }
            material=sharedMaterials[submesh];
            Color linearTint=proxy.AlbedoTint.linear,linearEmission=proxy.EmissionOverride.linear;
            tint=new Vector4(linearTint.r,linearTint.g,linearTint.b,1);
            emission=new Vector4(linearEmission.r,linearEmission.g,linearEmission.b,proxy.EmissionIntensity);
            if(!Finite(tint) || !Finite(emission) || emission.w<0)
            { reason="Proxy tint/emission parameters are invalid.";return false; }
            return true;
        }

        // A capability gate, not a claim of validated support on every driver reporting DXR.
        public static bool IsSupported => SystemInfo.supportsComputeShaders &&
            SystemInfo.graphicsDeviceType == GraphicsDeviceType.Direct3D12 && SystemInfo.supportsInlineRayTracing;

        public bool Prepare(HybridLumenGIScene scene, int revision, int triangleBudget = 250000, HybridLumenGISurfaceCache surfaceCache = null,
            long attributeBudgetBytes=long.MaxValue)
        {
            // Source-compatible optional argument, but no implicit first-material/side guess.
            if(surfaceCache == null) { IsReady=buildPending=false;preparedSurfaceCache=null;CancelBuildDemand();return false; }
            if (failed || (!softwareOnly && !IsSupported) || !SystemInfo.supportsComputeShaders || scene == null)
            { IsReady=false;CancelBuildDemand();return false; }
            triangleBudget = Mathf.Clamp(triangleBudget, 1024, 1000000);
            if (!softwareOnly && Shader == null) Shader = Resources.Load<ComputeShader>("HybridLumenGI/HybridLumenGIHardware");
            if (!softwareOnly && Shader == null) return false;
            try
            {
                long planTriangles=0,planInstances=0;
                int publishedCount=0;
                for(int slot=0;slot<scene.Capacity;slot++)
                {
                    if(!Published(scene.Data[slot].identity.w))continue;
                    publishedCount++;
                    Renderer candidate=scene.GetRenderer(slot);Mesh source=HybridLumenGIDeformedMesh.GetSourceMesh(candidate);
                    if(!Eligible(source,candidate,slot,surfaceCache,out long total) || total>triangleBudget-planTriangles)continue;
                    planTriangles+=total;
                    for(int submesh=0;submesh<source.subMeshCount;submesh++)if(source.GetIndexCount(submesh)>=3)planInstances++;
                }
                if(planInstances==0)
                {
                    // An empty plan uses the existing software fallback. Do not allocate an
                    // empty RTAS and dummy attributes just to retire them again this frame.
                    // Keep scanning eligibility above so returning/newly supported geometry
                    // can rebuild normally, even without a proxy revision change.
                    Deactivate();
                    FallbackCount=publishedCount;
                    preparedRevision=revision;
                    BudgetStatus="No eligible triangle geometry; using software fallback";
                    return false;
                }
                // Reserve the complete replacement peak before changing identities or allocating
                // any attributes. Old buffers remain counted until their Release succeeds.
                if(!AttributesFit(scene.Capacity,(int)planTriangles,(int)planInstances,attributeBudgetBytes))
                {DeferAttributes("Geometry attribute budget deferred current plus retiring/replacement buffers");return false;}
                // Revalidate retained membership even on a material-only change. An
                // already-built RTAS at the current pose does not need a new build ticket.
                bool poseChanged = false;
                bool reuseGeometry = (softwareOnly || acceleration != null) && triangleBudget == preparedBudget &&
                    preparedSurfaceCache == surfaceCache && MatchesPreparedGeometry(scene, surfaceCache, out poseChanged);
                if(!softwareOnly)
                {
                    long buildTriangles = reuseGeometry ? TriangleCount : planTriangles;
                    long buildInstances = reuseGeometry ? InstanceCount : planInstances;
                    if ((!reuseGeometry || poseChanged || buildPending) &&
                        !HybridLumenGIRtasBudget.FitsBuildBurst(buildTriangles, buildInstances, out var burstReason))
                    {
                        Deactivate();
                        FallbackCount = publishedCount;
                        BudgetStatus = burstReason;
                        return false;
                    }
                    // Measured values never lower the retained high-water reservation. Old GPU
                    // readers and Unity's opaque scratch allocation cannot be disproved by age.
                    if(acceleration!=null && reservation!=null && !buildPending)
                        HybridLumenGIRtasBudget.Observe(reservation,acceleration.GetSize());
                    if(!HybridLumenGIRtasBudget.TryReserve(planTriangles,planInstances,reservation,out var admitted,out string reason))
                    {
                        BudgetStatus=reason;IsReady=false;CancelBuildDemand();
                        if(reservation!=null && !HybridLumenGIRtasBudget.MemoryWithinBudget)RetireResources();
                        return false;
                    }
                    reservation=admitted;preparedRtasFrame=HybridLumenGIRtasBudget.Frame;
                    BudgetStatus="RTAS estimate reserved; pending build work is admitted at command recording";
                }
                else BudgetStatus="Software geometry; no RTAS work or memory reservation";
                if (reuseGeometry)
                {
                    UpdatePreparedGeometry(scene, surfaceCache);
                    preparedRevision=revision;
                    IsReady=MeshCount>0;
                    return IsReady;
                }
                // One owner per camera. All preceding work for that camera must have executed
                // before Prepare mutates the acceleration structure for its next render.
                if(!softwareOnly) { acceleration ??= new RayTracingAccelerationStructure();acceleration.ClearInstances(); }
                normals.Clear();
                surfaces.Clear();
                meshTangents.Clear();
                instances.Clear();
                objectToWorld.Clear();
                bindings.Clear();
                MeshState[] previousStates=meshStates;
                meshStates = new MeshState[scene.Capacity];
                if (meshFlags.Length != scene.Capacity) meshFlags = new uint[scene.Capacity];
                else Array.Clear(meshFlags, 0, meshFlags.Length);
                MeshCount = FallbackCount = 0;

                for (int slot = 0; slot < scene.Capacity; slot++)
                {
                    if (!Published(scene.Data[slot].identity.w)) continue;
                    Renderer renderer = scene.GetRenderer(slot);
                    Mesh mesh = HybridLumenGIDeformedMesh.GetSourceMesh(renderer);
                    MeshState previous=slot<previousStates.Length?previousStates[slot]:null;
                    bool sourceChanged=previous!=null && previous.mesh==mesh &&
                        previous.geometryRevision!=surfaceCache.GetGeometryRevision(slot);
                    if (!ExactSource(renderer) || !renderer.enabled || mesh == null || !mesh.isReadable ||
                        !TryAddMesh(mesh, renderer, slot, scene, surfaceCache, triangleBudget, GeometryChanged(scene,slot)||sourceChanged))
                    {
                        FallbackCount++;
                        continue;
                    }
                    meshFlags[slot] = 1;
                    MeshCount++;
                }

                // Source callbacks may reject an owner after the preflight. Recheck exact
                // counts before the first allocation; a smaller, differently sized table can
                // still require a replacement where the preflight anticipated buffer reuse.
                if(!AttributesFit(meshFlags.Length,normals.Count,instances.Count,attributeBudgetBytes))
                {
                    DeferAttributes("Geometry attribute budget deferred actual replacement buffers");return false;
                }
                Upload(ref flagsBuffer, meshFlags.Length, 4, meshFlags);
                Upload(ref instancesBuffer, instances.Count, 128, instances);
                Upload(ref objectToWorldBuffer,objectToWorld.Count,64,objectToWorld);
                Upload(ref normalsBuffer, normals.Count, 80, normals);
                Upload(ref surfaceBuffer, surfaces.Count, 96, surfaces);
                Upload(ref bindingsBuffer, bindings.Count, 16, bindings);
                BindingUploadCount++;
                SceneRebuildCount++;TriangleUploadCount++;
                GeometryVersion++;
                preparedRevision = revision;
                preparedBudget = triangleBudget;
                preparedSurfaceCache=surfaceCache;
                IsReady = MeshCount > 0;
                buildPending = IsReady && !softwareOnly;
                if(!IsReady){CancelBuildDemand();RetireResources();}
                return IsReady;
            }
            catch (Exception exception)
            {
                DisableAfterFailure(exception);
                return false;
            }
        }

        private static bool Published(float state) => state>0.5f && state<1.5f;
        private static bool ExactSource(Renderer renderer) => renderer is MeshRenderer || HybridLumenGIDeformedMesh.HasSnapshot(renderer);

        private static bool GeometryChanged(HybridLumenGIScene scene,int slot)
        {
            foreach(var change in scene.DirtyRegions)
                if(change.Slot==slot && (change.Kind & (HybridLumenGIScene.ChangeKind.Topology|HybridLumenGIScene.ChangeKind.Manual))!=0) return true;
            return false;
        }

        private bool Eligible(Mesh mesh,Renderer renderer,int slot,HybridLumenGISurfaceCache surfaceCache,out long total)
        {
            total=0;
            if (!ExactSource(renderer) || !renderer.enabled || mesh==null || !mesh.isReadable || mesh.subMeshCount==0) return false;
            if(surfaceCache.GetGeometryRevision(slot)==0) return false;
            renderer.GetSharedMaterials(sharedMaterials);
            if(sharedMaterials.Count<mesh.subMeshCount) return false;
            for (int submesh = 0; submesh < mesh.subMeshCount; submesh++)
            {
                Material material = sharedMaterials[submesh];
                // Cutout Lit is admitted: HardwareTrace forces non-opaque candidates and resolves
                // source-UV coverage before commit. Unknown coverage remains an occluder. A missing
                // material batch disables the entire hardware dispatch at the renderer boundary.
                // Transmissive surfaces still cannot silently become opaque geometry.
                if (mesh.GetTopology(submesh) != MeshTopology.Triangles || material == null ||
                    material.renderQueue > 2500 ||
                    (material.HasProperty("_Surface") && material.GetFloat("_Surface") > 0.5f)) return false;
                if(!surfaceCache.TryGetHardwareMaterial(slot,mesh,submesh,out var effective) ||
                    effective.cullMode>2u || !Finite(effective.diffuse) || !Finite(effective.emission)) return false;
                total += (long)mesh.GetIndexCount(submesh) / 3;
            }
            return total>0 && Mathf.Abs(renderer.localToWorldMatrix.determinant)>1e-12f;
        }

        private bool MatchesPreparedGeometry(HybridLumenGIScene scene, HybridLumenGISurfaceCache surfaceCache, out bool poseChanged)
        {
            poseChanged = false;
            if(meshStates.Length!=scene.Capacity) return false;
            // Validate the entire membership before mutating any retained native handles.
            for(int slot=0;slot<scene.Capacity;slot++)
            {
                MeshState previous=meshStates[slot];
                Renderer renderer=Published(scene.Data[slot].identity.w)?scene.GetRenderer(slot):null;
                Mesh mesh=HybridLumenGIDeformedMesh.GetSourceMesh(renderer);
                bool eligible=Eligible(mesh,renderer,slot,surfaceCache,out long triangles);
                if(previous==null)
                {
                    // An over-budget mesh stays on software until a membership/budget rebuild.
                    if(eligible && (slot>=meshFlags.Length || meshFlags[slot]!=0 || normals.Count+triangles<=preparedBudget)) return false;
                    continue;
                }
                if(!eligible || previous.renderer!=renderer || previous.mesh!=mesh ||
                    previous.stableId!=(int)scene.Data[slot].identity.x || previous.vertexCount!=mesh.vertexCount ||
                    previous.subMeshCount!=mesh.subMeshCount || previous.indexCount!=triangles*3 ||
                    previous.geometryRevision!=surfaceCache.GetGeometryRevision(slot) || GeometryChanged(scene,slot)) return false;
                if (!softwareOnly && !poseChanged) poseChanged = !previous.matrix.Equals(renderer.localToWorldMatrix);
            }
            return true;
        }

        private void UpdatePreparedGeometry(HybridLumenGIScene scene, HybridLumenGISurfaceCache surfaceCache)
        {
            bool changed=false,instanceChanged=false,bindingChanged=false;
            FallbackCount=0;
            for(int slot=0;slot<scene.Capacity;slot++) if(Published(scene.Data[slot].identity.w) && meshStates[slot]==null) FallbackCount++;
            for(int slot=0;slot<meshStates.Length;slot++)
            {
                MeshState state=meshStates[slot];if(state==null) continue;
                Matrix4x4 matrix=state.renderer.localToWorldMatrix;
                bool moved=!matrix.Equals(state.matrix);
                uint layoutGeneration=surfaceCache.GetLayoutGeneration(slot);
                bool refreshBindings=state.layoutGeneration!=layoutGeneration;
                Matrix4x4 normalToWorld=matrix.inverse.transpose;
                for(int i=0;i<state.instanceCount;i++)
                {
                    if(moved && !softwareOnly) acceleration.UpdateInstanceTransform(state.handles[i],matrix);
                    int index=state.firstInstance+i;InstanceData previous=instances[index],value=previous;
                    if(moved)objectToWorld[index]=matrix;
                    value.normalToWorld=normalToWorld;
                    if(!SetMaterialIdentity(ref value,slot,state.mesh,scene,surfaceCache))
                        throw new InvalidOperationException("Hardware material identity changed during preparation.");
                    if(!value.Equals(previous)) { instances[index]=value;instanceChanged=true; }
                    for(uint triangle=0;refreshBindings && triangle<value.triangleCount;triangle++)
                    {
                        var binding=GetBinding(surfaceCache,slot,state.mesh,(int)value.submesh,(int)triangle,value.geometryRevision);
                        int address=(int)(value.normalOffset+triangle);
                        if(!SameBinding(bindings[address],binding)) { bindings[address]=binding;bindingChanged=true; }
                    }
                }
                state.layoutGeneration=layoutGeneration;
                if(moved) { state.matrix=matrix;changed=true;TransformUpdateCount++; }
            }
            if(instanceChanged && instances.Count>0) instancesBuffer.SetData(instances);
            if(bindingChanged && bindings.Count>0) { bindingsBuffer.SetData(bindings);BindingUploadCount++; }
            if(changed) { objectToWorldBuffer.SetData(objectToWorld);buildPending=MeshCount>0 && !softwareOnly;GeometryVersion++; }
        }

        private bool TryAddMesh(Mesh mesh, Renderer renderer, int slot, HybridLumenGIScene scene, HybridLumenGISurfaceCache surfaceCache, int triangleBudget, bool geometryChanged)
        {
            if(!Eligible(mesh,renderer,slot,surfaceCache,out long total)) return false;
            if (total == 0 || normals.Count + total > triangleBudget) return false;

            mesh.GetVertices(vertices);
            mesh.GetNormals(vertexNormals);
            mesh.GetUVs(0,vertexUVs);
            if(!meshTangents.TryGetValue(mesh,out var vertexTangents))
            {
                vertexTangents=new List<Vector4>();
                mesh.GetTangents(vertexTangents);
                meshTangents.Add(mesh,vertexTangents);
            }
            Matrix4x4 matrix = renderer.localToWorldMatrix;
            Matrix4x4 normalMatrix = matrix.inverse.transpose;
            bool hasNormals = vertexNormals.Count == vertices.Count;
            bool hasUV=vertexUVs.Count==vertices.Count;
            bool hasTangents=vertexTangents.Count==vertices.Count;
            var state=new MeshState{mesh=mesh,renderer=renderer,matrix=matrix,stableId=(int)scene.Data[slot].identity.x,
                geometryRevision=surfaceCache.GetGeometryRevision(slot),layoutGeneration=surfaceCache.GetLayoutGeneration(slot),vertexCount=mesh.vertexCount,
                subMeshCount=mesh.subMeshCount,indexCount=total*3,firstInstance=instances.Count};
            for (int submesh = 0; submesh < mesh.subMeshCount; submesh++)
            {
                mesh.GetTriangles(indices, submesh, true);
                if (indices.Count == 0) continue;
                int firstNormal = normals.Count;
                for (int triangle = 0; triangle < indices.Count; triangle += 3)
                {
                    int ia = indices[triangle], ib = indices[triangle + 1], ic = indices[triangle + 2];
                    Vector3 face = Vector3.Cross(vertices[ib] - vertices[ia], vertices[ic] - vertices[ia]);
                    Vector3 na = hasNormals ? vertexNormals[ia] : face;
                    Vector3 nb = hasNormals ? vertexNormals[ib] : face;
                    Vector3 nc = hasNormals ? vertexNormals[ic] : face;
                    Vector4 a=SafeNormal(na),b=SafeNormal(nb),c=SafeNormal(nc);
                    Vector4 faceData=SafeNormal(face);faceData.w=hasNormals?1:0;
                    if(hasUV) { a.w=vertexUVs[ia].x;b.w=vertexUVs[ib].x;c.w=vertexUVs[ic].x; }
                    normals.Add(new TriangleNormals
                    {
                        a=a,b=b,c=c,face=faceData,
                        uvY=hasUV?new Vector4(vertexUVs[ia].y,vertexUVs[ib].y,vertexUVs[ic].y,1):Vector4.zero
                    });
                    surfaces.Add(new TriangleSurface
                    {
                        p0=SafePosition(vertices[ia]),p1=SafePosition(vertices[ib]),p2=SafePosition(vertices[ic]),
                        t0=hasTangents?SafeTangent(vertexTangents[ia]):Vector4.zero,
                        t1=hasTangents?SafeTangent(vertexTangents[ib]):Vector4.zero,
                        t2=hasTangents?SafeTangent(vertexTangents[ic]):Vector4.zero
                    });
                    bindings.Add(GetBinding(surfaceCache,slot,mesh,submesh,triangle/3,state.geometryRevision));
                }
                var config = new RayTracingMeshInstanceConfig(mesh, (uint)submesh, sharedMaterials[submesh])
                {
                    enableTriangleCulling = false,
                    dynamicGeometry = geometryChanged,
                    mask = 0xff,
                    subMeshFlags = RayTracingSubMeshFlags.Enabled | RayTracingSubMeshFlags.ClosestHitOnly
                };
                // Each submesh is one instance, so PrimitiveIndex is unambiguously local to it.
                int handle=softwareOnly?1:acceleration.AddInstance(config, matrix, null, (uint)instances.Count);
                if(handle==0) throw new InvalidOperationException("Unity rejected a registered ray tracing mesh instance.");
                state.handles.Add(handle);
                var instance=new InstanceData
                {
                    normalToWorld=normalMatrix,
                    slot = (uint)slot,
                    normalOffset = (uint)firstNormal,
                    triangleCount = (uint)(indices.Count / 3),
                    submesh=(uint)submesh
                };
                if(!SetMaterialIdentity(ref instance,slot,mesh,scene,surfaceCache))
                    throw new InvalidOperationException("Hardware material identity changed during preparation.");
                instances.Add(instance);
                objectToWorld.Add(matrix);
            }
            state.instanceCount=instances.Count-state.firstInstance;meshStates[slot]=state;
            return true;
        }

        private static bool SetMaterialIdentity(ref InstanceData instance,int slot,Mesh mesh,
            HybridLumenGIScene scene,HybridLumenGISurfaceCache surfaceCache)
        {
            if(!surfaceCache.TryGetHardwareMaterial(slot,mesh,(int)instance.submesh,out var material) ||
                material.cullMode>2u || !Finite(material.diffuse) || !Finite(material.emission)) return false;
            instance.stableId=(uint)scene.Data[slot].identity.x;
            instance.ownerRevision=(uint)scene.Data[slot].identity.y;
            instance.geometryRevision=surfaceCache.GetGeometryRevision(slot);
            instance.cullMode=material.cullMode;instance.diffuse=material.diffuse;instance.emission=material.emission;
            return instance.geometryRevision!=0;
        }

        private static HybridLumenGISurfaceCache.TriangleChartBinding GetBinding(HybridLumenGISurfaceCache surfaceCache,
            int slot,Mesh mesh,int submesh,int primitive,uint geometryRevision)
        {
            if(surfaceCache.TryGetTriangleBinding(slot,mesh,submesh,primitive,out var binding) &&
                binding.cardIndex!=uint.MaxValue && binding.chartId!=0 && binding.layoutGeneration!=0 && binding.geometryRevision==geometryRevision)
                return binding;
            return new HybridLumenGISurfaceCache.TriangleChartBinding{cardIndex=uint.MaxValue};
        }

        private static bool SameBinding(HybridLumenGISurfaceCache.TriangleChartBinding a,HybridLumenGISurfaceCache.TriangleChartBinding b) =>
            a.cardIndex==b.cardIndex && a.chartId==b.chartId && a.layoutGeneration==b.layoutGeneration && a.geometryRevision==b.geometryRevision;
        private static bool Finite(Vector4 value) => Finite(value.x)&&Finite(value.y)&&Finite(value.z)&&Finite(value.w);
        private static bool Finite(float value) => !float.IsNaN(value)&&!float.IsInfinity(value);

        private static Vector4 SafePosition(Vector3 position) => Finite(position.x)&&Finite(position.y)&&Finite(position.z)
            ? new Vector4(position.x,position.y,position.z,1) : Vector4.zero;

        private static Vector4 SafeTangent(Vector4 tangent)
        {
            if(!Finite(tangent) || (tangent.w!=1 && tangent.w!=-1) ||
                (tangent.x==0 && tangent.y==0 && tangent.z==0)) return Vector4.zero;
            // Preserve magnitude, sign and handedness. Do not normalize or apply the instance
            // matrix/determinant here; the hit evaluator owns the exact vertex/TBN convention.
            return tangent;
        }

        private static Vector4 SafeNormal(Vector3 normal)
        {
            if (!Finite(normal.x) || !Finite(normal.y) || !Finite(normal.z)) return Vector4.zero;
            float scale=Math.Max(Math.Abs(normal.x),Math.Max(Math.Abs(normal.y),Math.Abs(normal.z)));
            if(scale==0) return Vector4.zero;
            // Normalize after rescaling: valid tiny faces are not replaced by an
            // arbitrary direction, and large finite normals cannot overflow dot.
            normal.x/=scale;normal.y/=scale;normal.z/=scale;
            normal.Normalize();
            return new Vector4(normal.x, normal.y, normal.z, 0);
        }

        private static long BufferBytes(ComputeBuffer buffer)=>buffer==null?0:(long)buffer.count*buffer.stride;
        private static long NewBufferBytes(ComputeBuffer buffer,int count,int stride)
        {count=Mathf.Max(1,count);return buffer!=null && buffer.count==count && buffer.stride==stride?0:(long)count*stride;}
        private bool AttributesFit(int slots,int triangles,int instanceCount,long budget)
        {
            long extra=NewBufferBytes(flagsBuffer,slots,4)+NewBufferBytes(instancesBuffer,instanceCount,128)+
                NewBufferBytes(objectToWorldBuffer,instanceCount,64)+NewBufferBytes(normalsBuffer,triangles,80)+
                NewBufferBytes(surfaceBuffer,triangles,96)+NewBufferBytes(bindingsBuffer,triangles,16);
            long held = geometryAllocations.TotalBytes;
            return budget>=0 && held<=budget && extra<=budget-held;
        }
        private void DeferAttributes(string reason)
        {
            BudgetStatus=reason;IsReady=buildPending=false;preparedBudget=-1;preparedSurfaceCache=null;CancelBuildDemand();
            // Make forward progress when old and new allocations cannot coexist. Detach the
            // old representation now, retain its accounting until the fence, and retry later.
            RetireResources();
        }
        private void RetireAttributeBuffer(ComputeBuffer buffer)
        {
            if(buffer==null)return;
            long bytes=BufferBytes(buffer);retiredAttributeBytes+=bytes;
            HybridLumenGIResourceRetirement.Retire(() =>
            {
                buffer.Release();
                retiredAttributeBytes -= bytes;
                geometryAllocations.AttributeBytes -= bytes;
            });
        }

        private void Upload<T>(ref ComputeBuffer buffer, int count, int stride, List<T> values) where T : struct
        {
            EnsureBuffer(ref buffer, count, stride);
            if (count > 0) buffer.SetData(values);
        }

        private void Upload<T>(ref ComputeBuffer buffer, int count, int stride, T[] values) where T : struct
        {
            EnsureBuffer(ref buffer, count, stride);
            if (count > 0) buffer.SetData(values);
        }

        private void EnsureBuffer(ref ComputeBuffer buffer, int count, int stride)
        {
            count = Mathf.Max(1, count);
            if (buffer != null && buffer.count == count && buffer.stride==stride) return;
            if(buffer!=null){var old=buffer;buffer=null;RetireAttributeBuffer(old);}
            buffer = new ComputeBuffer(count, stride, ComputeBufferType.Structured);
            geometryAllocations.AttributeBytes += BufferBytes(buffer);
        }

        /// <summary>Record before the first hardware dispatch, on the graphics queue.</summary>
        public bool RecordBuild(CommandBuffer command) => RecordBuild(command,out _);

        internal bool RecordBuild(CommandBuffer command,out bool deferredByQuota)
        {
            deferredByQuota=false;
            if (!IsReady) return false;
            try
            {
                if (buildPending)
                {
                    // Charge every dirty build/refit, not only changes in GetSize. Use all
                    // prepared triangles/instances conservatively for Unity's opaque build work.
                    if(!HybridLumenGIRtasBudget.TryReserve(TriangleCount,InstanceCount,reservation,out var admitted,out string memoryReason))
                    {
                        BudgetStatus=memoryReason;
                        deferredByQuota=reservation!=null && !reservation.IsRetired;
                        return false;
                    }
                    reservation=admitted;
                    if(!HybridLumenGIRtasBudget.TryConsumeBuild(budgetOwner,preparedRtasFrame,TriangleCount,InstanceCount,out string reason))
                    {
                        BudgetStatus=reason;
                        deferredByQuota=preparedRtasFrame==HybridLumenGIRtasBudget.Frame;
                        return false;
                    }
                    command.BuildRayTracingAccelerationStructure(acceleration);
                    buildPending = false;
                    if(!HybridLumenGIRtasBudget.Observe(reservation,acceleration.GetSize()))
                    {
                        BudgetStatus="Measured RTAS memory exceeded quota; retained until fenced destruction, using software";
                        IsReady=false;RetireResources();return false;
                    }
                    BudgetStatus="RTAS build recorded within shared work quota; native completion unproven";
                }
                return CanDispatch;
            }
            catch (Exception exception)
            {
                DisableAfterFailure(exception);
                return false;
            }
        }

        /// <summary>Bind immediately inside the dispatch callback, never between camera recordings.</summary>
        public void Bind(ComputeShader compute, int kernel)
        {
            if (!CanDispatch) return;
            if(!softwareOnly)compute.SetRayTracingAccelerationStructure(kernel, AccelerationId, acceleration);
            compute.SetBuffer(kernel, FlagsId, flagsBuffer);
            compute.SetInt(CoversPublishedId, FallbackCount == 0 ? 1 : 0);
            compute.SetBuffer(kernel, InstancesId, instancesBuffer);
            compute.SetBuffer(kernel, NormalsId, normalsBuffer);
            compute.SetBuffer(kernel, SurfaceId, surfaceBuffer);
            compute.SetBuffer(kernel, BindingsId, bindingsBuffer);
            compute.SetBuffer(kernel,ObjectToWorldId,objectToWorldBuffer);
        }

        /// <summary>Preferred binding for Render Graph unsafe/native command dispatches.</summary>
        public void Bind(CommandBuffer command, ComputeShader compute, int kernel)
        {
            if (!CanDispatch) return;
            if(!softwareOnly)command.SetGlobalRayTracingAccelerationStructure(AccelerationId, acceleration);
            command.SetComputeBufferParam(compute, kernel, FlagsId, flagsBuffer);
            command.SetComputeIntParam(compute, CoversPublishedId, FallbackCount == 0 ? 1 : 0);
            command.SetComputeBufferParam(compute, kernel, InstancesId, instancesBuffer);
            command.SetComputeBufferParam(compute, kernel, NormalsId, normalsBuffer);
            command.SetComputeBufferParam(compute, kernel, SurfaceId, surfaceBuffer);
            command.SetComputeBufferParam(compute, kernel, BindingsId, bindingsBuffer);
            command.SetComputeBufferParam(compute,kernel,ObjectToWorldId,objectToWorldBuffer);
        }

        private void DisableAfterFailure(Exception exception)
        {
            failed = true;
            Deactivate();
            BudgetStatus = "Triangle backend disabled after an exception";
            if (loggedFailure) return;
            loggedFailure = true;
            Debug.LogWarning($"HybridLumenGI disabled its optional triangle DXR backend; software tracing remains available. {exception.Message}");
        }

        // A camera that explicitly stops using this backend must return its
        // reservation. Retiring GPU allocations still count until destruction.
        internal void Deactivate()
        {
            CancelBuildDemand();RetireResources();
            if(instances.Count>0)GeometryVersion++;
            normals.Clear();surfaces.Clear();instances.Clear();objectToWorld.Clear();bindings.Clear();
            meshTangents.Clear();sharedMaterials.Clear();
            meshStates=Array.Empty<MeshState>();meshFlags=Array.Empty<uint>();
            MeshCount=FallbackCount=0;
            preparedSurfaceCache=null;
            IsReady = buildPending = false;
            preparedRevision=preparedBudget=-1;
            BudgetStatus="Inactive";
        }

        public void Dispose() => Deactivate();

        /// <summary>Withdraw scheduling priority when this camera no longer requests hardware.</summary>
        public void CancelBuildDemand()
        {HybridLumenGIRtasBudget.CancelBuildDemand(budgetOwner);preparedRtasFrame=int.MinValue;}

        private void RetireResources()
        {
            var oldAcceleration=acceleration;var oldReservation=reservation;
            var oldFlags=flagsBuffer;var oldInstances=instancesBuffer;var oldNormals=normalsBuffer;
            var oldSurface=surfaceBuffer;var oldBindings=bindingsBuffer;var oldMatrices=objectToWorldBuffer;
            acceleration=null;reservation=null;
            flagsBuffer=instancesBuffer=normalsBuffer=surfaceBuffer=bindingsBuffer=objectToWorldBuffer=null;
            RetireAttributeBuffer(oldFlags);RetireAttributeBuffer(oldInstances);RetireAttributeBuffer(oldNormals);
            RetireAttributeBuffer(oldSurface);RetireAttributeBuffer(oldBindings);RetireAttributeBuffer(oldMatrices);
            HybridLumenGIRtasBudget.Retire(oldReservation);
            if(oldAcceleration==null)
            {HybridLumenGIRtasBudget.ReleaseDestroyed(oldReservation);return;}
            HybridLumenGIResourceRetirement.Retire(()=>
            {
                oldAcceleration.Dispose();
                // A thrown native destroy leaves the reservation held by the failed retirement.
                HybridLumenGIRtasBudget.ReleaseDestroyed(oldReservation);
            });
        }
    }
}
