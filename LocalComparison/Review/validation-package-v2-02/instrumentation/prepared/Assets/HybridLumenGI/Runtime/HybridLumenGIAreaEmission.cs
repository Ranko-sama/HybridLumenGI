using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Runtime.InteropServices;
using UnityEngine;

namespace HybridLumenGI
{
    /// <summary>
    /// Builds an immutable area distribution over prepared, exact emitter triangles. This class
    /// owns no GPU objects. Upload the result to a RenderGraph transient buffer only with the
    /// matching material batch, and publish its count only after that batch's source revalidation.
    /// Missing, capped, or unrepresentable triangles retain the original direction estimator.
    /// </summary>
    public static class HybridLumenGIAreaEmission
    {
        public const int Stride=96,MaxTriangles=262144;

        public struct Triangle
        {
            public Vector3 P0,P1,P2,RawNg;
            public uint OwnerSlot,StableId,OwnerRevision,GeometryRevision,Instance,Submesh,Primitive,Cull;
        }

        /// <summary>Prepared tracing geometry, never a second read of mutable source mesh arrays.</summary>
        public interface ITriangleProvider
        {
            int GetTriangleCount(int instance);
            bool TryGetTriangle(int instance,int primitive,out Triangle triangle);
        }

        [StructLayout(LayoutKind.Sequential,Pack=4)]
        public struct GpuRecord
        {
            public Vector4 p0,p1,p2,rawNg; // xyz positions; w = area, CDF lower, CDF upper, zero
            public HybridLumenGIHitMaterialUInt4 identity; // owner, stable ID, owner revision, geometry revision
            public HybridLumenGIHitMaterialUInt4 geometry; // instance, submesh, primitive, material generation
        }

        public sealed class Layout
        {
            private readonly GpuRecord[] records;
            public ReadOnlyCollection<GpuRecord> Records { get; }
            public int Count => records.Length;
            public uint MaterialGeneration { get; }
            public long ByteCount => (long)Math.Max(1,Count)*Stride;
            public bool CapacityLimited { get; }
            internal Layout(GpuRecord[] records,uint generation,bool limited)
            { this.records=records;Records=Array.AsReadOnly(records);MaterialGeneration=generation;CapacityLimited=limited; }
            public GpuRecord[] CopyRecords() => (GpuRecord[])records.Clone();
            internal Layout WithMaterialGeneration(uint generation)
            {
                var copy=CopyRecords();
                for(int i=0;i<copy.Length;i++)copy[i].geometry.w=generation;
                return new Layout(copy,generation,CapacityLimited);
            }
        }

        /// <summary>
        /// One camera's CPU-only prepared distribution. The provider/version must identify
        /// immutable prepared geometry; zero disables reuse. Source identities independently
        /// cover changes that need not increment the backend's geometry version.
        /// </summary>
        public sealed class Cache
        {
            [StructLayout(LayoutKind.Sequential,Pack=4)]
            private readonly struct SourceKey
            {
                private readonly uint stable,owner,geometry,submesh,emitter;
                internal SourceKey(HybridLumenGIHitMaterialBatch.Source source)
                {
                    stable=source.StableId;owner=source.OwnerRevision;geometry=source.GeometryRevision;
                    submesh=source.Submesh;emitter=PotentialEmitter(source)?1u:0u;
                }
                internal bool Matches(HybridLumenGIHitMaterialBatch.Source source) =>
                    stable==source.StableId && owner==source.OwnerRevision && geometry==source.GeometryRevision &&
                    submesh==source.Submesh && emitter==(PotentialEmitter(source)?1u:0u);
            }
            private ITriangleProvider provider;
            private ulong geometryVersion;
            private int capacity;
            private SourceKey[] keys;
            private Layout retained;

            public void Clear(){provider=null;geometryVersion=0;capacity=0;keys=null;retained=null;}

            public bool TryBuild(IReadOnlyList<HybridLumenGIHitMaterialBatch.Source> sources,
                ITriangleProvider preparedProvider,ulong preparedGeometryVersion,uint materialGeneration,
                int maximumTriangles,out Layout layout,out string reason)
            {
                layout=null;reason=null;
                try
                {
                    if(preparedGeometryVersion==0 || sources==null || preparedProvider==null || materialGeneration==0 ||
                        maximumTriangles<0 || maximumTriangles>MaxTriangles || sources.Count>HybridLumenGIHitMaterialBatch.MaxMaterials)
                    {
                        Clear();
                        return HybridLumenGIAreaEmission.TryBuild(sources,preparedProvider,materialGeneration,maximumTriangles,out layout,out reason);
                    }
                    bool match=retained!=null && ReferenceEquals(provider,preparedProvider) &&
                        geometryVersion==preparedGeometryVersion && capacity==maximumTriangles && keys.Length==sources.Count;
                    if(match)
                        for(int i=0;i<keys.Length;i++)if(!keys[i].Matches(sources[i])){match=false;break;}
                    if(match)
                    {
                        // An earlier Work may still own the old array. Never update it in place.
                        layout=retained.WithMaterialGeneration(materialGeneration);retained=layout;return true;
                    }
                    Clear();
                    if(!HybridLumenGIAreaEmission.TryBuild(sources,preparedProvider,materialGeneration,maximumTriangles,out layout,out reason))return false;
                    var captured=new SourceKey[sources.Count];
                    for(int i=0;i<captured.Length;i++)captured[i]=new SourceKey(sources[i]);
                    provider=preparedProvider;geometryVersion=preparedGeometryVersion;capacity=maximumTriangles;
                    keys=captured;retained=layout;return true;
                }
                catch(Exception ex)
                {
                    Clear();layout=null;reason="Prepared emitter reuse failed: "+ex.GetType().Name;return false;
                }
            }
        }

        private static bool Finite(float x) => !float.IsNaN(x) && !float.IsInfinity(x);
        private static bool Finite(Vector3 v) => Finite(v.x)&&Finite(v.y)&&Finite(v.z);
        private static bool Finite(Vector4 v) => Finite(v.x)&&Finite(v.y)&&Finite(v.z)&&Finite(v.w);

        private static bool PotentialEmitter(HybridLumenGIHitMaterialBatch.Source source)
        {
            if(source.Snapshot==null || source.Snapshot.HitMaterial==null || source.StableId==0 ||
                source.OwnerRevision==0 || source.GeometryRevision==0 || source.Snapshot.MaterialIndex<0 ||
                (uint)source.Snapshot.MaterialIndex!=source.Submesh || !Finite(source.LinearProxyEmission) ||
                source.LinearProxyEmission.w<=0) return false;
            // Do not inspect a CPU texture average or require a nonzero constant emission color.
            // The actual UV material/alpha query decides Le and coverage after selecting a point.
            return source.Snapshot.HitMaterial.IsKeywordEnabled("_EMISSION") ||
                source.LinearProxyEmission.x>0 || source.LinearProxyEmission.y>0 || source.LinearProxyEmission.z>0;
        }

        private static bool TryRecord(Triangle t,HybridLumenGIHitMaterialBatch.Source source,
            int instance,int primitive,uint materialGeneration,out GpuRecord record)
        {
            record=default;
            if(t.Instance!=(uint)instance || t.Primitive!=(uint)primitive || t.Submesh!=source.Submesh ||
                t.StableId!=source.StableId || t.OwnerRevision!=source.OwnerRevision ||
                t.GeometryRevision!=source.GeometryRevision || t.OwnerSlot==uint.MaxValue || t.Cull>2 ||
                !Finite(t.P0)||!Finite(t.P1)||!Finite(t.P2)||!Finite(t.RawNg)) return false;
            double ax=(double)t.P1.x-t.P0.x,ay=(double)t.P1.y-t.P0.y,az=(double)t.P1.z-t.P0.z;
            double bx=(double)t.P2.x-t.P0.x,by=(double)t.P2.y-t.P0.y,bz=(double)t.P2.z-t.P0.z;
            double cx=ay*bz-az*by,cy=az*bx-ax*bz,cz=ax*by-ay*bx;
            double twiceArea=Math.Sqrt(cx*cx+cy*cy+cz*cz);
            double length=Math.Sqrt((double)t.RawNg.x*t.RawNg.x+(double)t.RawNg.y*t.RawNg.y+(double)t.RawNg.z*t.RawNg.z);
            float area=(float)(twiceArea*.5);
            if(!Finite(area)||area<=0 || !(length>0) || double.IsInfinity(length) ||
                Math.Abs(cx*t.RawNg.x+cy*t.RawNg.y+cz*t.RawNg.z)<.999*twiceArea*length) return false;
            // Authored inverse-transpose Ng is preserved. Mirroring must not silently change Cull.
            record=new GpuRecord {
                p0=new Vector4(t.P0.x,t.P0.y,t.P0.z,area),p1=new Vector4(t.P1.x,t.P1.y,t.P1.z,0),
                p2=new Vector4(t.P2.x,t.P2.y,t.P2.z,0),
                rawNg=new Vector4((float)(t.RawNg.x/length),(float)(t.RawNg.y/length),(float)(t.RawNg.z/length),0),
                identity=new HybridLumenGIHitMaterialUInt4(t.OwnerSlot,t.StableId,t.OwnerRevision,t.GeometryRevision),
                geometry=new HybridLumenGIHitMaterialUInt4(t.Instance,t.Submesh,t.Primitive,materialGeneration)
            };
            return true;
        }

        /// <summary>
        /// Uniform world-area importance, with exact represented float32 CDF interval probabilities.
        /// A deterministic capacity subset is valid: omitted endpoints have light PDF zero and keep
        /// direction weight one. Empty layouts are successful and explicitly disable area NEE.
        /// </summary>
        public static bool TryBuild(IReadOnlyList<HybridLumenGIHitMaterialBatch.Source> sources,
            ITriangleProvider provider,uint materialGeneration,int maximumTriangles,out Layout layout,out string reason)
        {
            layout=null;reason=null;
            if(sources==null || provider==null || materialGeneration==0 || maximumTriangles<0 || maximumTriangles>MaxTriangles)
            { reason="Invalid sources, prepared geometry provider, generation or triangle capacity.";return false; }
            try
            {
                if(sources.Count>HybridLumenGIHitMaterialBatch.MaxMaterials)
                { reason="Material source count exceeds the matching material table capacity.";return false; }
                var candidates=new List<GpuRecord>(Math.Min(maximumTriangles,1024));bool limited=false;
                for(int instance=0;instance<sources.Count;instance++)
                {
                    var source=sources[instance];if(!PotentialEmitter(source))continue;
                    int count=provider.GetTriangleCount(instance);
                    if(count<0) { reason="Prepared triangle count is invalid.";return false; }
                    for(int primitive=0;primitive<count;primitive++)
                    {
                        if(candidates.Count>=maximumTriangles) { limited=true;break; }
                        if(provider.TryGetTriangle(instance,primitive,out var t) &&
                            TryRecord(t,source,instance,primitive,materialGeneration,out var record)) candidates.Add(record);
                    }
                    if(limited)break;
                }
                double total=0;foreach(var record in candidates) total+=record.p0.w;
                if(double.IsNaN(total)||double.IsInfinity(total)) { reason="Emitter area sum is not finite.";return false; }
                var compact=new List<GpuRecord>(candidates.Count);double prefix=0;float lower=0;
                for(int i=0;i<candidates.Count;i++)
                {
                    var record=candidates[i];prefix+=record.p0.w;
                    float upper=i==candidates.Count-1?1:(float)(prefix/total);
                    if(upper<=lower)continue; // Empty float32 intervals are never candidates.
                    record.p1.w=lower;record.p2.w=upper;compact.Add(record);lower=upper;
                }
                layout=new Layout(compact.ToArray(),materialGeneration,limited);return true;
            }
            catch(Exception ex) { reason="Prepared emitter capture failed: "+ex.GetType().Name;return false; }
        }
    }
}
