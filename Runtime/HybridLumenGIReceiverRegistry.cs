using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Runtime.CompilerServices;
using UnityEngine;

namespace HybridLumenGI
{
    /// <summary>
    /// CPU source identities for ordinary opaque receivers, independent of GI scene
    /// residency. These records do not identify a screen pixel: a unique, validated
    /// identity capture is still required before enabling object-motion history.
    /// Main-thread only. Readable mesh fingerprints are checked under a byte budget.
    /// </summary>
    public sealed class HybridLumenGIReceiverRegistry
    {
        public sealed class Record
        {
            public readonly ulong Token, GeometryGeneration, MaterialGeneration;
            public readonly Renderer Renderer;
            public readonly Mesh Mesh;
            public readonly int Submesh;
            public readonly Matrix4x4 LocalToWorld;
            public readonly HybridLumenGIMaterialSource.Snapshot Material;
            internal readonly HybridLumenGIMeshSource.Version MeshVersion;
            internal readonly string Fingerprint;
            internal readonly ReceiverContext Context;
            internal readonly HybridLumenGIReceiverSkinPose SkinPose;
            internal Record(ulong token, ulong geometry, ulong material, Renderer renderer, Mesh mesh,
                int submesh, Matrix4x4 matrix, HybridLumenGIMaterialSource.Snapshot source,
                HybridLumenGIMeshSource.Version version, string fingerprint,ReceiverContext context,
                HybridLumenGIReceiverSkinPose skinPose=null)
            {
                Token=token;GeometryGeneration=geometry;MaterialGeneration=material;
                Renderer=renderer;Mesh=mesh;Submesh=submesh;LocalToWorld=matrix;
                Material=source;MeshVersion=version;Fingerprint=fingerprint;Context=context;SkinPose=skinPose;
            }
            public bool SameSource(Record other) => other!=null && Token==other.Token &&
                GeometryGeneration==other.GeometryGeneration && MaterialGeneration==other.MaterialGeneration &&
                ReferenceEquals(Renderer,other.Renderer) && ReferenceEquals(Mesh,other.Mesh) && Submesh==other.Submesh &&
                Context.Equals(other.Context) && SameSkinPose(SkinPose,other.SkinPose) &&
                Material.CanReuseHistory && other.Material.CanReuseHistory;
        }

        // Per-renderer policy and baked-lighting inputs are not Material properties.
        // Dynamic probes/global lighting remain a separate lighting-invalidation contract.
        internal readonly struct ReceiverContext : IEquatable<ReceiverContext>
        {
            private readonly int layer,lightmap,realtimeLightmap;
            private readonly uint renderingLayers;
            private readonly bool receiveShadows;
            private readonly Vector4 lightmapST,realtimeST;
            internal ReceiverContext(Renderer renderer)
            {
                layer=renderer.gameObject.layer;renderingLayers=renderer.renderingLayerMask;receiveShadows=renderer.receiveShadows;
                lightmap=renderer.lightmapIndex;realtimeLightmap=renderer.realtimeLightmapIndex;
                lightmapST=renderer.lightmapScaleOffset;realtimeST=renderer.realtimeLightmapScaleOffset;
            }
            internal bool IsValid => layer>=0 && layer<32 && Finite(lightmapST) && Finite(realtimeST);
            private static bool Finite(Vector4 value)
            { for(int i=0;i<4;i++) if(float.IsNaN(value[i]) || float.IsInfinity(value[i])) return false;return true; }
            public bool Equals(ReceiverContext other) => layer==other.layer && renderingLayers==other.renderingLayers &&
                receiveShadows==other.receiveShadows && lightmap==other.lightmap && realtimeLightmap==other.realtimeLightmap &&
                lightmapST.Equals(other.lightmapST) && realtimeST.Equals(other.realtimeST);
        }

        public sealed class Snapshot
        {
            public readonly ReadOnlyCollection<Record> Records;
            public readonly bool HasUnknownSources;
            public readonly int UntrackedRenderers;
            public readonly long FingerprintBytes;
            public readonly int FingerprintedMeshes;
            internal readonly HybridLumenGIReceiverRegistry Owner;
            internal readonly HybridLumenGIReceiverDiscovery.Snapshot Discovery;
            internal Snapshot(HybridLumenGIReceiverRegistry owner, HybridLumenGIReceiverDiscovery.Snapshot discovery,
                List<Record> records, int untracked, long bytes, int meshes)
            {
                Owner=owner;Discovery=discovery;Records=Array.AsReadOnly(records.ToArray());
                UntrackedRenderers=untracked;FingerprintBytes=bytes;FingerprintedMeshes=meshes;
                HasUnknownSources=discovery==null || !discovery.ScanComplete || discovery.HasUnknownSources || untracked!=0;
            }
        }

        private sealed class Slot
        {
            internal ulong token,geometryGeneration,materialGeneration;
            internal HybridLumenGIMeshSource.Version version;
            internal HybridLumenGIMaterialSource.Snapshot material;
            internal ReceiverContext context;
            internal HybridLumenGIReceiverSkinPose skinPose;
        }
        private sealed class Receiver { internal Mesh mesh;internal Slot[] slots=Array.Empty<Slot>(); }
        private sealed class Geometry
        {
            internal string fingerprint;
            internal HybridLumenGIMeshSource.Version version;
        }
        private sealed class ReferenceComparer<T> : IEqualityComparer<T> where T:class
        {
            internal static readonly ReferenceComparer<T> Instance=new ReferenceComparer<T>();
            public bool Equals(T a,T b) => ReferenceEquals(a,b);
            public int GetHashCode(T value) => RuntimeHelpers.GetHashCode(value);
        }

        private readonly ConditionalWeakTable<Renderer,Receiver> receivers=new ConditionalWeakTable<Renderer,Receiver>();
        private readonly ConditionalWeakTable<Mesh,Geometry> geometries=new ConditionalWeakTable<Mesh,Geometry>();
        private readonly HybridLumenGIMaterialSource materials=new HybridLumenGIMaterialSource();
        private ulong nextIdentity=1,nextGeneration=1;

        // Exhaustion fails closed instead of reusing a lifetime or source generation.
        private static ulong Allocate(ref ulong next)
        { if(next==0) return 0;ulong result=next;next=result==ulong.MaxValue?0:result+1;return result; }

        public Snapshot Prepare(HybridLumenGIReceiverDiscovery.Snapshot discovery, int maxRecords, long fingerprintByteBudget)
        {
            int capacity=Math.Max(0,Math.Min(16384,maxRecords));
            long remaining=Math.Max(0,fingerprintByteBudget),initial=remaining;
            var records=new List<Record>(Math.Min(capacity,256));
            var checkedMeshes=new Dictionary<Mesh,Geometry>(ReferenceComparer<Mesh>.Instance);
            int untracked=0,fingerprinted=0;
            if(discovery==null || !discovery.ScanComplete)
                return new Snapshot(this,discovery,records,discovery==null?0:discovery.Candidates.Count,0,0);
            foreach(var candidate in discovery.Candidates)
            {
                try
                {
                Renderer renderer=candidate.Renderer;Mesh mesh=candidate.Mesh;
                if(renderer==null || mesh==null || candidate.IdentityIssues!=HybridLumenGIReceiverDiscovery.IdentityIssues.None ||
                    !ValidMatrix(candidate.LocalToWorld) || candidate.Materials.Count==0 ||
                    candidate.Materials.Count!=mesh.subMeshCount || mesh.subMeshCount>capacity-records.Count)
                { untracked++;continue; }
                if(!checkedMeshes.TryGetValue(mesh,out Geometry geometry))
                {
                    geometry=ReadGeometry(mesh,ref remaining);
                    if(geometry!=null) fingerprinted++;
                    checkedMeshes.Add(mesh,geometry); // Remember budget/rejection too; never repeatedly hash shared instances.
                }
                if(geometry==null) { untracked++;continue; }
                HybridLumenGIReceiverSkinPose skinPose=null;
                if(renderer is SkinnedMeshRenderer skinned)
                {
                    if(!HybridLumenGIReceiverSkinPose.TryCapture(skinned,mesh,candidate.LocalToWorld,out skinPose) ||
                        skinPose.LogicalBytes>remaining) { untracked++;continue; }
                    remaining-=skinPose.LogicalBytes;
                }
                var snapshots=new HybridLumenGIMaterialSource.Snapshot[candidate.Materials.Count];
                bool supported=true;
                for(int i=0;i<snapshots.Length;i++)
                    if(mesh.GetTopology(i)!=MeshTopology.Triangles ||
                        !materials.TryCapture(renderer,i,candidate.Materials[i],out snapshots[i],out _) ||
                        !snapshots[i].CanReuseHistory) { supported=false;break; }
                if(!supported) { untracked++;continue; }
                var context=new ReceiverContext(renderer);
                if(!context.IsValid) { untracked++;continue; }
                Receiver receiver=receivers.GetValue(renderer,_=>new Receiver());
                if(!ReferenceEquals(receiver.mesh,mesh) || receiver.slots.Length!=snapshots.Length)
                { receiver.mesh=mesh;receiver.slots=new Slot[snapshots.Length]; }
                var additions=new List<Record>(snapshots.Length);
                for(int i=0;i<snapshots.Length;i++)
                {
                    Slot slot=receiver.slots[i];
                    if(slot==null) receiver.slots[i]=slot=new Slot{token=Allocate(ref nextIdentity)};
                    if(!ReferenceEquals(slot.version,geometry.version) || !SameSkinPose(slot.skinPose,skinPose))
                    { slot.version=geometry.version;slot.geometryGeneration=Allocate(ref nextGeneration); }
                    slot.skinPose=skinPose;
                    if(slot.material==null || !slot.material.Equals(snapshots[i]) || !slot.context.Equals(context))
                    { slot.material=snapshots[i];slot.context=context;slot.materialGeneration=Allocate(ref nextGeneration); }
                    if(slot.token==0 || slot.geometryGeneration==0 || slot.materialGeneration==0) { supported=false;break; }
                    additions.Add(new Record(slot.token,slot.geometryGeneration,slot.materialGeneration,renderer,mesh,i,
                        candidate.LocalToWorld,snapshots[i],geometry.version,geometry.fingerprint,context,skinPose));
                }
                if(supported) records.AddRange(additions); else untracked++;
                }
                catch(Exception) { untracked++; } // A mutable/destroyed source must not cancel current GI.
            }
            return new Snapshot(this,discovery,records,untracked,initial-remaining,fingerprinted);
        }

        /// <summary>
        /// Re-read the actual source set immediately before capture recording. A fresh
        /// discovery catches new/activated objects; checking only old entries cannot.
        /// Failure revokes this source snapshot, not the current GI contribution.
        /// </summary>
        public bool IsCurrent(Snapshot snapshot, HybridLumenGIReceiverDiscovery.Snapshot fresh, long fingerprintByteBudget)
        {
            try { return IsCurrentCore(snapshot,fresh,fingerprintByteBudget); }
            catch(Exception) { return false; }
        }

        private bool IsCurrentCore(Snapshot snapshot, HybridLumenGIReceiverDiscovery.Snapshot fresh, long fingerprintByteBudget)
        {
            if(snapshot==null || !ReferenceEquals(snapshot.Owner,this) || !SameDiscovery(snapshot.Discovery,fresh)) return false;
            long remaining=Math.Max(0,fingerprintByteBudget);
            var checkedMeshes=new Dictionary<Mesh,Geometry>(ReferenceComparer<Mesh>.Instance);
            var checkedSkin=new Dictionary<Renderer,HybridLumenGIReceiverSkinPose>(ReferenceComparer<Renderer>.Instance);
            foreach(Record record in snapshot.Records)
            {
                if(record.Renderer==null || record.Mesh==null || !record.Renderer.localToWorldMatrix.Equals(record.LocalToWorld)) return false;
                var context=new ReceiverContext(record.Renderer);
                if(!context.IsValid || !record.Context.Equals(context)) return false;
                if(!checkedMeshes.TryGetValue(record.Mesh,out Geometry geometry))
                { geometry=ReadGeometry(record.Mesh,ref remaining);checkedMeshes.Add(record.Mesh,geometry); }
                if(geometry==null || !ReferenceEquals(record.MeshVersion,geometry.version) ||
                    !string.Equals(record.Fingerprint,geometry.fingerprint,StringComparison.Ordinal) ||
                    !materials.IsCurrent(record.Renderer,record.Submesh,record.Material)) return false;
                if(record.Renderer is SkinnedMeshRenderer skinned)
                {
                    if(!checkedSkin.TryGetValue(record.Renderer,out var pose))
                    {
                        if(!HybridLumenGIReceiverSkinPose.TryCapture(skinned,record.Mesh,record.LocalToWorld,out pose) ||
                            pose.LogicalBytes>remaining) return false;
                        remaining-=pose.LogicalBytes;checkedSkin.Add(record.Renderer,pose);
                    }
                    if(record.SkinPose==null || !record.SkinPose.SamePose(pose)) return false;
                }
                else if(record.SkinPose!=null) return false;
            }
            return true;
        }

        private static bool SameSkinPose(HybridLumenGIReceiverSkinPose a,HybridLumenGIReceiverSkinPose b)
            => ReferenceEquals(a,b) || (a!=null && a.SamePose(b));

        private Geometry ReadGeometry(Mesh mesh,ref long remaining)
        {
            try
            {
                if(mesh==null || !mesh.isReadable || mesh.blendShapeCount!=0) return null;
                long cost=FingerprintCost(mesh);
                if(cost<0 || cost>remaining) return null;
                remaining-=cost;
                string fingerprint=HybridLumenGISurfaceCharts.ComputeContentFingerprint(mesh);
                if(string.IsNullOrEmpty(fingerprint)) return null;
                Geometry previous=geometries.GetValue(mesh,_=>new Geometry());
                // The first verified observation must also revoke prior SDF/chart
                // positives: an unnotified edit may predate this registry/budget.
                if(previous.fingerprint==null || !string.Equals(previous.fingerprint,fingerprint,StringComparison.Ordinal))
                    HybridLumenGIMeshSource.NotifyGeometryChanged(mesh);
                previous.fingerprint=fingerprint;
                previous.version=HybridLumenGIMeshSource.GetVersion(mesh);
                // Return a value snapshot; future scans must not mutate old records.
                return previous.version==null?null:new Geometry{fingerprint=fingerprint,version=previous.version};
            }
            catch(Exception) { return null; }
        }

        // Bound the logical bytes consumed by the existing complete fingerprint.
        // This is not a wall-time limit or peak allocation measurement. Mesh-owned
        // bone arrays are borrowed and must not be disposed. Blend shapes are rejected
        // until the deformation/previous-vertex contract is implemented.
        private static long FingerprintCost(Mesh mesh)
        {
            checked
            {
                long bytes=1024L+mesh.GetVertexAttributes().Length*16L;
                using(var snapshot=Mesh.AcquireReadOnlyMeshData(mesh))
                {
                    var data=snapshot[0];
                    for(int stream=0;stream<data.vertexBufferCount;stream++) bytes+=data.GetVertexData<byte>(stream).Length;
                    bytes+=data.GetIndexData<byte>().Length+data.subMeshCount*64L;
                }
                bytes+=mesh.bindposes.Length*64L+mesh.GetBonesPerVertex().Length+mesh.GetAllBoneWeights().Length*8L;
                return bytes;
            }
        }

        private static bool SameDiscovery(HybridLumenGIReceiverDiscovery.Snapshot old,HybridLumenGIReceiverDiscovery.Snapshot fresh)
        {
            if(old==null || fresh==null || !old.ScanComplete || !fresh.ScanComplete ||
                old.HasUnknownSources!=fresh.HasUnknownSources ||
                !ReferenceEquals(old.Camera,fresh.Camera) || old.SelectedLayers.value!=fresh.SelectedLayers.value ||
                old.CameraCullingMask!=fresh.CameraCullingMask || old.EffectiveLayerMask!=fresh.EffectiveLayerMask ||
                !old.CullingMatrix.Equals(fresh.CullingMatrix) || old.Candidates.Count!=fresh.Candidates.Count) return false;
            var candidates=new Dictionary<Renderer,HybridLumenGIReceiverDiscovery.Candidate>(ReferenceComparer<Renderer>.Instance);
            foreach(var candidate in old.Candidates)
            { if(candidate.Renderer==null || candidates.ContainsKey(candidate.Renderer)) return false;candidates.Add(candidate.Renderer,candidate); }
            foreach(var candidate in fresh.Candidates)
            {
                if(candidate.Renderer==null || !candidates.TryGetValue(candidate.Renderer,out var previous) ||
                    !ReferenceEquals(previous.Mesh,candidate.Mesh) || previous.IdentityIssues!=candidate.IdentityIssues ||
                    !previous.LocalToWorld.Equals(candidate.LocalToWorld) || !previous.Bounds.Equals(candidate.Bounds) ||
                    previous.Materials.Count!=candidate.Materials.Count) return false;
                for(int i=0;i<previous.Materials.Count;i++) if(!ReferenceEquals(previous.Materials[i],candidate.Materials[i])) return false;
                candidates.Remove(candidate.Renderer);
            }
            return candidates.Count==0;
        }

        private static bool ValidMatrix(Matrix4x4 matrix)
        {
            float determinant=matrix.determinant;
            if(float.IsNaN(determinant) || float.IsInfinity(determinant) || determinant==0) return false;
            Matrix4x4 inverse=matrix.inverse;
            for(int i=0;i<16;i++) if(float.IsNaN(matrix[i]) || float.IsInfinity(matrix[i]) ||
                float.IsNaN(inverse[i]) || float.IsInfinity(inverse[i])) return false;
            return true;
        }
    }
}
