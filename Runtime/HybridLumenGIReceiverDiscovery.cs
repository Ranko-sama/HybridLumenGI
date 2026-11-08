using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using Stopwatch = System.Diagnostics.Stopwatch;

namespace HybridLumenGI
{
    /// <summary>Current-camera discovery of ordinary opaque receivers, independent of
    /// proxies/GPU residency. Not proof of a pixel owner, final LOD, or BRG visibility.</summary>
    public sealed class HybridLumenGIReceiverDiscovery
    {
        [Flags]
        public enum IdentityIssues
        {
            None = 0, InvalidBounds = 1 << 0, InvalidTransform = 1 << 1,
            MissingMesh = 1 << 2, MeshSubmeshMismatch = 1 << 3, NonTriangleTopology = 1 << 4,
            NonMeshRenderer = 1 << 5, StaticBatch = 1 << 6, AdditionalVertexStreams = 1 << 7,
            EnlightenVertexStream = 1 << 8, LodMembership = 1 << 9, MissingMaterial = 1 << 10,
            UnsupportedMaterial = 1 << 11, SourceReadFailure = 1 << 12
        }

        public sealed class Candidate
        {
            public Renderer Renderer { get; }
            public Mesh Mesh { get; }
            public IReadOnlyList<Material> Materials { get; }
            public Bounds Bounds { get; }
            public Matrix4x4 LocalToWorld { get; }
            public IdentityIssues IdentityIssues { get; }
            public bool HasOpaqueMaterials { get; }
            internal Candidate(Renderer renderer, Mesh mesh, Material[] materials, Bounds bounds,
                Matrix4x4 matrix, IdentityIssues issues, bool hasOpaqueMaterials)
            {
                Renderer=renderer; Mesh=mesh; Materials=Array.AsReadOnly(materials); Bounds=bounds;
                LocalToWorld=matrix; IdentityIssues=issues; HasOpaqueMaterials=hasOpaqueMaterials;
            }
        }

        /// <summary>Owned collection/value snapshot; Unity object references remain live.
        /// Source-version tracking separately freezes their content contract.</summary>
        public sealed class Snapshot
        {
            public Camera Camera { get; }
            public LayerMask SelectedLayers { get; }
            public Matrix4x4 CullingMatrix { get; }
            public int CameraCullingMask { get; }
            public int EffectiveLayerMask { get; }
            public IReadOnlyList<Candidate> Candidates { get; }
            public int ScannedRenderers { get; }
            public int CandidateRenderers { get; }
            public int CheckedMaterials { get; }
            public bool ScanComplete { get; }
            public bool NativeDiffuseCompatible { get; }
            public string NativeDiffuseReason { get; }
            public bool HasUnknownSources { get; }
            internal Snapshot(Camera camera,LayerMask selectedLayers,Matrix4x4 cullingMatrix,int cameraCullingMask,
                List<Candidate> candidates,int scanned,int checkedMaterials,
                bool complete,string nativeReason,bool unknown)
            {
                Camera=camera; SelectedLayers=selectedLayers; CullingMatrix=cullingMatrix;
                CameraCullingMask=cameraCullingMask; EffectiveLayerMask=cameraCullingMask & selectedLayers.value;
                Candidates=Array.AsReadOnly(candidates.ToArray());
                ScannedRenderers=scanned; CandidateRenderers=candidates.Count; CheckedMaterials=checkedMaterials;
                ScanComplete=complete; NativeDiffuseCompatible=complete && nativeReason==null;
                NativeDiffuseReason=nativeReason ?? (complete?null:"Receiver discovery could not read every source.");
                HasUnknownSources=unknown || !complete;
            }
        }

        private const string LitShaderName="Universal Render Pipeline/Lit";

        // One allowance belongs to a render graph. Only time spent inside its
        // discovery calls is charged, including source reads that cannot be interrupted.
        internal sealed class ScanBudget
        {
            private readonly Func<long> timestamp;
            private double remainingTicks;

            internal ScanBudget(double ticks, Func<long> timestamp)
            {
                remainingTicks = ticks;
                this.timestamp = timestamp;
            }

            internal static ScanBudget FromMilliseconds(float milliseconds)
            {
                if (!(milliseconds > 0) || float.IsInfinity(milliseconds)) return null;
                return new ScanBudget(Math.Max(1, milliseconds * (Stopwatch.Frequency / 1000.0)), Stopwatch.GetTimestamp);
            }

            internal long Timestamp() => timestamp();
            internal bool IsExhausted(long started) => Timestamp() - started >= remainingTicks;
            internal void Charge(long started) => remainingTicks = Math.Max(0, remainingTicks - (Timestamp() - started));
        }

        /// <summary>Main-thread scan per camera capture, including Additive. No frame-number
        /// cache: sources can change between renders in one frame. Unsupported sources
        /// never end the scan or suppress another receiver.</summary>
        public Snapshot Scan(Camera camera,LayerMask selectedLayers) => Scan(camera, selectedLayers, null);

        internal Snapshot Scan(Camera camera, LayerMask selectedLayers, ScanBudget budget)
        {
            long started = budget?.Timestamp() ?? 0;
            try { return Scan(camera, selectedLayers, budget, started); }
            finally { budget?.Charge(started); }
        }

        private Snapshot Scan(Camera camera, LayerMask selectedLayers, ScanBudget budget, long started)
        {
            var candidates=new List<Candidate>();
            int scanned=0,checkedMaterials=0;
            bool complete=true,unknown=false;
            string nativeReason=null;
            if(camera==null) return new Snapshot(camera,selectedLayers,default,0,candidates,0,0,false,"Native diffuse replacement has no camera.",true);
            int cameraCullingMask=camera.cullingMask;
            int mask=cameraCullingMask & selectedLayers.value;
            Matrix4x4 cullingMatrix=default;
            bool OutOfTime() => budget != null && budget.IsExhausted(started);
            Snapshot Deferred() => new Snapshot(camera, selectedLayers, cullingMatrix, cameraCullingMask,
                candidates, scanned, checkedMaterials, false, "Receiver discovery CPU allowance exhausted.", true);
            if (mask != 0 && OutOfTime()) return Deferred();
            var planes=new Plane[6];
            bool canCull=false;
            try
            {
                cullingMatrix=camera.cullingMatrix;
                if(mask==0) return new Snapshot(camera,selectedLayers,cullingMatrix,cameraCullingMask,candidates,0,0,true,null,false);
                if(!Finite(cullingMatrix)) nativeReason="Camera culling matrix is not finite.";
                else
                {
                    GeometryUtility.CalculateFrustumPlanes(cullingMatrix,planes);
                    canCull=true;
                    foreach(Plane plane in planes)
                        if(!Finite(plane.normal)||!Finite(plane.distance)||plane.normal.sqrMagnitude<1e-12f) canCull=false;
                    if(!canCull) nativeReason="Camera culling planes are degenerate or not finite.";
                }
            }
            catch(Exception) { nativeReason="Camera culling context could not be read."; }
            if(!canCull) { complete=false;unknown=true; }

            // Explicit LOD renderer references need not be inferred from parents.
            // Membership does not tell us the final LOD selected for this camera.
            if (OutOfTime()) return Deferred();
            var lodRenderers=new HashSet<Renderer>(ReferenceComparer<Renderer>.Instance);
            try
            {
                foreach(LODGroup group in Resources.FindObjectsOfTypeAll<LODGroup>())
                {
                    if (OutOfTime()) return Deferred();
                    if(group==null) continue;
                    try
                    {
                        GameObject go=group.gameObject;
                        if(go==null||!go.scene.IsValid()||!go.scene.isLoaded) continue;
                        foreach (LOD lod in group.GetLODs())
                        {
                            if (OutOfTime()) return Deferred();
                            if (lod.renderers == null) continue;
                            foreach (Renderer renderer in lod.renderers)
                            {
                                if (OutOfTime()) return Deferred();
                                if (renderer != null) lodRenderers.Add(renderer);
                            }
                        }
                    }
                    catch(Exception) { complete=false;unknown=true; }
                }
            }
            catch(Exception) { complete=false;unknown=true; }

            if (OutOfTime()) return Deferred();
            Renderer[] renderers;
            try { renderers=Resources.FindObjectsOfTypeAll<Renderer>(); }
            catch(Exception) { return new Snapshot(camera,selectedLayers,cullingMatrix,cameraCullingMask,candidates,0,0,false,nativeReason??"Loaded Renderer discovery failed.",true); }
            var seen=new HashSet<Renderer>(ReferenceComparer<Renderer>.Instance);
            RenderQueueRange opaque=RenderQueueRange.opaque;
            foreach(Renderer renderer in renderers)
            {
                if (OutOfTime()) return Deferred();
                scanned++;
                if(renderer==null||!seen.Add(renderer)) continue;
                var materials=new List<Material>();
                Bounds bounds=default;
                Matrix4x4 matrix=default;
                Mesh mesh=null;
                IdentityIssues issues=IdentityIssues.None;
                bool hasOpaque=false,unknownMaterial=false;
                try
                {
                    if(!renderer.enabled||renderer.forceRenderingOff) continue;
                    GameObject go=renderer.gameObject;
                    if(go==null||!go.activeInHierarchy||!go.scene.IsValid()||!go.scene.isLoaded||(mask&(1<<go.layer))==0) continue;
                    // DontSave/HideInHierarchy do not prove a live renderer invisible.
                    bounds=renderer.bounds;
                    bool validBounds=Finite(bounds.center)&&Finite(bounds.extents)&&bounds.extents.x>=0&&bounds.extents.y>=0&&bounds.extents.z>=0;
                    if(!validBounds)
                    {
                        issues|=IdentityIssues.InvalidBounds;
                        nativeReason=nativeReason??"Renderer '"+renderer.name+"' has unverifiable culling bounds.";
                        unknown=true;
                    }
                    else if(canCull&&!GeometryUtility.TestPlanesAABB(planes,bounds)) continue;
                    renderer.GetSharedMaterials(materials);
                    for(int slot=0;slot<materials.Count;slot++)
                    {
                        if (OutOfTime()) return Deferred();
                        Material material=materials[slot];
                        if(material==null||material.shader==null)
                        {
                            issues|=IdentityIssues.MissingMaterial;unknownMaterial=true;
                            nativeReason=nativeReason??"Renderer '"+renderer.name+"' has a missing material/shader in slot "+slot+".";
                            continue;
                        }
                        int queue=material.renderQueue;
                        if(queue<0) queue=material.shader.renderQueue;
                        if(queue<opaque.lowerBound||queue>opaque.upperBound) continue;
                        hasOpaque=true;checkedMaterials++;
                        if(!string.Equals(material.shader.name,LitShaderName,StringComparison.Ordinal))
                        {
                            issues|=IdentityIssues.UnsupportedMaterial;
                            nativeReason=nativeReason??"Renderer '"+renderer.name+"' opaque material '"+material.name+
                                "' uses '"+material.shader.name+"'; native diffuse replacement requires '"+LitShaderName+"'.";
                        }
                    }
                    // Transparent-only is known not to supply opaque identity.
                    // Missing slots and empty mappings remain explicit unknowns.
                    if(!hasOpaque&&!unknownMaterial&&materials.Count>0) continue;
                    matrix=renderer.localToWorldMatrix;
                    float determinant=matrix.determinant;
                    if(!Finite(matrix)||!Finite(determinant)||determinant==0f||!Finite(matrix.inverse)) issues|=IdentityIssues.InvalidTransform;
                    if(renderer.isPartOfStaticBatch) issues|=IdentityIssues.StaticBatch;
                    if(lodRenderers.Contains(renderer)) issues|=IdentityIssues.LodMembership;
                    if(renderer is MeshRenderer meshRenderer)
                    {
                        if(meshRenderer.additionalVertexStreams!=null) issues|=IdentityIssues.AdditionalVertexStreams;
                        if(meshRenderer.enlightenVertexStream!=null) issues|=IdentityIssues.EnlightenVertexStream;
                        MeshFilter filter=renderer.GetComponent<MeshFilter>();
                        mesh=filter!=null?filter.sharedMesh:null;
                    }
                    else if(renderer is SkinnedMeshRenderer skinned)
                    {
                        // The registry additionally freezes the actual bone pose. Identity
                        // capture draws this Renderer, never its undeformed source mesh.
                        mesh=skinned.sharedMesh;
                    }
                    else issues|=IdentityIssues.NonMeshRenderer;
                    if(renderer is MeshRenderer || renderer is SkinnedMeshRenderer)
                    {
                        if(mesh==null) issues|=IdentityIssues.MissingMesh;
                        else
                        {
                            if(mesh.subMeshCount<=0||mesh.subMeshCount!=materials.Count) issues|=IdentityIssues.MeshSubmeshMismatch;
                            for (int submesh = 0; submesh < mesh.subMeshCount; submesh++)
                            {
                                if (OutOfTime()) return Deferred();
                                if (mesh.GetTopology(submesh) != MeshTopology.Triangles) issues |= IdentityIssues.NonTriangleTopology;
                            }
                        }
                    }
                }
                catch(Exception)
                {
                    // Failed source reads cannot silently remove a possible owner.
                    issues|=IdentityIssues.SourceReadFailure;complete=false;
                    nativeReason=nativeReason??"A receiver source could not be read completely.";
                }
                unknown|=issues!=IdentityIssues.None;
                candidates.Add(new Candidate(renderer,mesh,materials.ToArray(),bounds,matrix,issues,hasOpaque));
            }
            return new Snapshot(camera,selectedLayers,cullingMatrix,cameraCullingMask,candidates,scanned,checkedMaterials,complete,nativeReason,unknown);
        }

        private static bool Finite(float value)=>!float.IsNaN(value)&&!float.IsInfinity(value);
        private static bool Finite(Vector3 value)=>Finite(value.x)&&Finite(value.y)&&Finite(value.z);
        private static bool Finite(Matrix4x4 value)
        { for(int i=0;i<16;i++) if(!Finite(value[i])) return false;return true; }
        private sealed class ReferenceComparer<T>:IEqualityComparer<T> where T:class
        {
            internal static readonly ReferenceComparer<T> Instance=new ReferenceComparer<T>();
            public bool Equals(T a,T b)=>ReferenceEquals(a,b);
            public int GetHashCode(T value)=>System.Runtime.CompilerServices.RuntimeHelpers.GetHashCode(value);
        }
    }
}
