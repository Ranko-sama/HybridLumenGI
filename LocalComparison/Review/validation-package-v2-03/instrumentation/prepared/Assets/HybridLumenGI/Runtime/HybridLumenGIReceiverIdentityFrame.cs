using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;
using UnityEngine;

namespace HybridLumenGI
{
    /// <summary>
    /// Frozen CPU inputs for a separate receiver identity draw. Does not establish pixel
    /// ownership or GPU completion. Revalidate sources immediately before recording.
    /// No live renderer, mesh or material properties are read by this builder.
    /// </summary>
    public sealed class HybridLumenGIReceiverIdentityFrame
    {
        public const int RowStride=80;
        public const double RelativeTolerance=1e-5;
        public const double ProjectionWEpsilon=1e-6;

        [StructLayout(LayoutKind.Sequential)]
        public readonly struct Row
        {
            public readonly Matrix4x4 currentToPrevious;
            // ABI name retained: reserved is the current-frame Renderer group, not
            // persistent identity. Every submesh shares its first record index+1.
            public readonly uint keyLow,keyHigh,flags,reserved;
            internal Row(ulong key,Matrix4x4 transform,bool reusable,uint rendererGroup)
            { currentToPrevious=transform;keyLow=(uint)key;keyHigh=(uint)(key>>32);flags=reusable?1u:0u;reserved=rendererGroup; }
        }

        public readonly struct Draw
        {
            public readonly HybridLumenGIReceiverRegistry.Record Record;
            public readonly int RowIndex;
            public readonly HybridLumenGIMaterialSource.IdentityCoverageData Coverage;
            internal Draw(HybridLumenGIReceiverRegistry.Record record,int row)
            { Record=record;RowIndex=row;Coverage=record.Material.IdentityCoverage; }
        }

        public readonly struct MotionBounds
        {
            public readonly Bounds Current,Previous;
            public readonly Renderer SourceRenderer;
            internal MotionBounds(Bounds current,Bounds previous,Renderer sourceRenderer)
            { Current=current;Previous=previous;SourceRenderer=sourceRenderer; }
        }

        public ReadOnlyCollection<Row> Rows { get; }
        public ReadOnlyCollection<Draw> Draws { get; }
        public ReadOnlyCollection<RectInt> UnknownRects { get; }
        public ReadOnlyCollection<MotionBounds> MovedBounds { get; }
        private readonly Dictionary<Renderer,uint> receiverGroups;
        /// <summary>Current-frame group of an actual source reference; zero if unknown.
        /// This is not a persistent key or proof of a visible/captured pixel.</summary>
        public uint GetReceiverGroup(Renderer renderer) => !ReferenceEquals(renderer,null) &&
            receiverGroups.TryGetValue(renderer,out uint group)?group:0;

        private HybridLumenGIReceiverIdentityFrame(Row[] rows,Draw[] draws,RectInt[] unknown,MotionBounds[] moved,Dictionary<Renderer,uint> groups)
        { Rows=Array.AsReadOnly(rows);Draws=Array.AsReadOnly(draws);UnknownRects=Array.AsReadOnly(unknown);MovedBounds=Array.AsReadOnly(moved);receiverGroups=groups; }

        private sealed class CandidateState
        {
            internal HybridLumenGIReceiverDiscovery.Candidate candidate;
            internal bool invalid;
            internal readonly HashSet<int> submeshes=new HashSet<int>();
        }
        private sealed class ReferenceComparer<T>:IEqualityComparer<T> where T:class
        {
            internal static readonly ReferenceComparer<T> Instance=new ReferenceComparer<T>();
            public bool Equals(T a,T b)=>ReferenceEquals(a,b);
            public int GetHashCode(T value)=>RuntimeHelpers.GetHashCode(value);
        }

        /// <summary>
        /// Rows[i] always belongs to source.Records[i]; Draw.RowIndex is zero based,
        /// and the GPU owner encoding is RowIndex+1. Unsupported entries never compact
        /// later indices. gpuViewProjection must map into the full target's clip space,
        /// including any caller-owned viewport transform. uvStartsAtTop applies the same
        /// post-projection Y flip as the transport ProjectUV convention (DX12: true).
        /// </summary>
        public static HybridLumenGIReceiverIdentityFrame Build(HybridLumenGIReceiverRegistry.Snapshot source,
            HybridLumenGIReceiverHistory history,Matrix4x4 gpuViewProjection,int fullWidth,int fullHeight,int maxUnknownRects=1024,bool uvStartsAtTop=true)
        {
            int count=source==null?0:source.Records.Count;
            try
            {
                if(source==null || source.Discovery==null || !source.Discovery.ScanComplete ||
                    fullWidth<=0 || fullHeight<=0 || !Finite(gpuViewProjection)) return Failed(count,fullWidth,fullHeight);
                var rows=new Row[count];
                var draws=new List<Draw>(count);
                var unknown=new List<RectInt>();
                var moved=new List<MotionBounds>();
                var candidates=new Dictionary<Renderer,CandidateState>(ReferenceComparer<Renderer>.Instance);
                var groups=new Dictionary<Renderer,uint>(ReferenceComparer<Renderer>.Instance);
                var movedRenderers=new HashSet<Renderer>(ReferenceComparer<Renderer>.Instance);
                var keys=new HashSet<ulong>();
                foreach(var candidate in source.Discovery.Candidates)
                {
                    if(candidate==null || ReferenceEquals(candidate.Renderer,null) || candidates.ContainsKey(candidate.Renderer))
                        return Failed(count,fullWidth,fullHeight);
                    candidates.Add(candidate.Renderer,new CandidateState{candidate=candidate,
                        invalid=candidate.IdentityIssues!=HybridLumenGIReceiverDiscovery.IdentityIssues.None || candidate.Materials.Count==0});
                }
                for(int i=0;i<count;i++)
                {
                    var record=source.Records[i];
                    if(record==null) return Failed(count,fullWidth,fullHeight);
                    ulong key=Math.Max(record.GeometryGeneration,record.MaterialGeneration);
                    if(ReferenceEquals(record.Renderer,null) || !candidates.TryGetValue(record.Renderer,out var state))
                        return Failed(count,fullWidth,fullHeight);
                    if(!groups.TryGetValue(record.Renderer,out uint group))
                    { group=(uint)i+1u;groups.Add(record.Renderer,group); }
                    rows[i]=new Row(key,Matrix4x4.identity,false,group);
                    var candidate=state.candidate;
                    bool normal=record.Token!=0 && record.GeometryGeneration!=0 && record.MaterialGeneration!=0 && keys.Add(key) &&
                        ReferenceEquals(record.Mesh,candidate.Mesh) && !ReferenceEquals(record.Mesh,null) &&
                        record.LocalToWorld.Equals(candidate.LocalToWorld) && ValidAffine(record.LocalToWorld) &&
                        record.Submesh>=0 && record.Submesh<candidate.Materials.Count && record.Material!=null &&
                        ReferenceEquals(record.Material.SourceRenderer,record.Renderer) && record.Material.MaterialIndex==record.Submesh &&
                        ReferenceEquals(record.Material.SourceMaterial,candidate.Materials[record.Submesh]) &&
                        record.Material.CanReuseHistory && record.Material.IdentityCoverage.Supported;
                    if(!normal || state.invalid || !state.submeshes.Add(record.Submesh)) { state.invalid=true;continue; }
                    bool reusable=false;
                    Matrix4x4 relative=Matrix4x4.identity;
                    if(history!=null && history.TryGetPrevious(record,out var old) &&
                        TryRelative(record.LocalToWorld,old.LocalToWorld,out relative))
                    {
                        reusable=PositiveSimilarity(relative);
                        if(!record.LocalToWorld.Equals(old.LocalToWorld) && movedRenderers.Add(record.Renderer))
                        {
                            if(!TryTransformBounds(candidate.Bounds,relative,out Bounds previous)) return Failed(count,fullWidth,fullHeight);
                            moved.Add(new MotionBounds(candidate.Bounds,previous,record.Renderer));
                        }
                    }
                    rows[i]=new Row(key,reusable?relative:Matrix4x4.identity,reusable,group);
                    draws.Add(new Draw(record,i));
                }
                int cap=Math.Max(0,maxUnknownRects);
                foreach(var state in candidates.Values)
                {
                    if(!state.invalid && state.submeshes.Count==state.candidate.Materials.Count) continue;
                    if(!TryProject(state.candidate.Bounds,gpuViewProjection,fullWidth,fullHeight,uvStartsAtTop,out RectInt rect))
                    { unknown.Clear();unknown.Add(Full(fullWidth,fullHeight));break; }
                    if(rect.width<=0 || rect.height<=0) continue;
                    if(unknown.Count>=cap) { unknown.Clear();unknown.Add(Full(fullWidth,fullHeight));break; }
                    unknown.Add(rect);
                }
                return new HybridLumenGIReceiverIdentityFrame(rows,draws.ToArray(),unknown.ToArray(),moved.ToArray(),groups);
            }
            catch(Exception) { return Failed(count,fullWidth,fullHeight); }
        }

        private static HybridLumenGIReceiverIdentityFrame Failed(int count,int width,int height) =>
            new HybridLumenGIReceiverIdentityFrame(new Row[Math.Max(0,count)],Array.Empty<Draw>(),
                new[]{Full(width,height)},Array.Empty<MotionBounds>(),new Dictionary<Renderer,uint>(ReferenceComparer<Renderer>.Instance));
        private static RectInt Full(int width,int height)=>new RectInt(0,0,Math.Max(1,width),Math.Max(1,height));
        private static bool Finite(double x)=>!double.IsNaN(x)&&!double.IsInfinity(x);
        private static bool Finite(Matrix4x4 m)
        { for(int i=0;i<16;i++) if(!Finite(m[i])) return false;return true; }
        private static double Determinant(Matrix4x4 m)=>
            (double)m.m00*((double)m.m11*m.m22-(double)m.m12*m.m21)-
            (double)m.m01*((double)m.m10*m.m22-(double)m.m12*m.m20)+
            (double)m.m02*((double)m.m10*m.m21-(double)m.m11*m.m20);
        private static bool ValidAffine(Matrix4x4 m)=>Finite(m) && m.m30==0 && m.m31==0 && m.m32==0 && m.m33==1 && Determinant(m)!=0;

        // Invert and compose in double precision to avoid an intermediate float inverse
        // overflowing for an otherwise representable relative transform. No Unity inverse
        // failure convention (zero/identity matrix) is trusted.
        private static bool TryRelative(Matrix4x4 current,Matrix4x4 previous,out Matrix4x4 result)
        {
            result=Matrix4x4.identity;
            if(!ValidAffine(current) || !ValidAffine(previous)) return false;
            if(current.Equals(previous)) return true;
            double d=Determinant(current);
            double i00=((double)current.m11*current.m22-(double)current.m12*current.m21)/d;
            double i01=((double)current.m02*current.m21-(double)current.m01*current.m22)/d;
            double i02=((double)current.m01*current.m12-(double)current.m02*current.m11)/d;
            double i10=((double)current.m12*current.m20-(double)current.m10*current.m22)/d;
            double i11=((double)current.m00*current.m22-(double)current.m02*current.m20)/d;
            double i12=((double)current.m02*current.m10-(double)current.m00*current.m12)/d;
            double i20=((double)current.m10*current.m21-(double)current.m11*current.m20)/d;
            double i21=((double)current.m01*current.m20-(double)current.m00*current.m21)/d;
            double i22=((double)current.m00*current.m11-(double)current.m01*current.m10)/d;
            for(int r=0;r<3;r++)
            {
                double a=previous[r,0]*i00+previous[r,1]*i10+previous[r,2]*i20;
                double b=previous[r,0]*i01+previous[r,1]*i11+previous[r,2]*i21;
                double c=previous[r,0]*i02+previous[r,1]*i12+previous[r,2]*i22;
                result[r,0]=(float)a;result[r,1]=(float)b;result[r,2]=(float)c;
                result[r,3]=(float)(previous[r,3]-a*current.m03-b*current.m13-c*current.m23);
            }
            return Finite(result);
        }

        // Squared column lengths differ by at most tolerance * maximum length^2;
        // normalized cross-column dot products are bounded by the same tolerance.
        // Positive determinant excludes relative reflection. A constant mirrored or
        // nonuniform source has identity relative motion and remains eligible.
        private static bool PositiveSimilarity(Matrix4x4 m)
        {
            if(!ValidAffine(m) || Determinant(m)<=0) return false;
            double x=(double)m.m00*m.m00+(double)m.m10*m.m10+(double)m.m20*m.m20;
            double y=(double)m.m01*m.m01+(double)m.m11*m.m11+(double)m.m21*m.m21;
            double z=(double)m.m02*m.m02+(double)m.m12*m.m12+(double)m.m22*m.m22;
            double largest=Math.Max(x,Math.Max(y,z)),smallest=Math.Min(x,Math.Min(y,z));
            if(smallest<=0 || largest-smallest>RelativeTolerance*largest) return false;
            double xy=(double)m.m00*m.m01+(double)m.m10*m.m11+(double)m.m20*m.m21;
            double xz=(double)m.m00*m.m02+(double)m.m10*m.m12+(double)m.m20*m.m22;
            double yz=(double)m.m01*m.m02+(double)m.m11*m.m12+(double)m.m21*m.m22;
            return Math.Abs(xy)<=RelativeTolerance*Math.Sqrt(x*y) && Math.Abs(xz)<=RelativeTolerance*Math.Sqrt(x*z) &&
                Math.Abs(yz)<=RelativeTolerance*Math.Sqrt(y*z);
        }

        private static bool ValidBounds(Bounds bounds)=>Finite(bounds.center.x)&&Finite(bounds.center.y)&&Finite(bounds.center.z)&&
            Finite(bounds.extents.x)&&Finite(bounds.extents.y)&&Finite(bounds.extents.z)&&
            bounds.extents.x>=0&&bounds.extents.y>=0&&bounds.extents.z>=0;

        private static bool TryProject(Bounds bounds,Matrix4x4 vp,int width,int height,bool uvStartsAtTop,out RectInt rect)
        {
            rect=default;if(!ValidBounds(bounds)) return false;
            double minX=double.PositiveInfinity,minY=minX,maxX=double.NegativeInfinity,maxY=maxX;
            for(int i=0;i<8;i++)
            {
                double x=(double)bounds.center.x+((i&1)==0?-1:1)*bounds.extents.x;
                double y=(double)bounds.center.y+((i&2)==0?-1:1)*bounds.extents.y;
                double z=(double)bounds.center.z+((i&4)==0?-1:1)*bounds.extents.z;
                double cx=vp.m00*x+vp.m01*y+vp.m02*z+vp.m03,cy=vp.m10*x+vp.m11*y+vp.m12*z+vp.m13;
                double cz=vp.m20*x+vp.m21*y+vp.m22*z+vp.m23,cw=vp.m30*x+vp.m31*y+vp.m32*z+vp.m33;
                if(!Finite(cx)||!Finite(cy)||!Finite(cz)||!Finite(cw)||cw<=ProjectionWEpsilon) return false;
                double v=cy/cw*.5+.5;
                double px=(cx/cw*.5+.5)*width,py=(uvStartsAtTop?1-v:v)*height;
                if(!Finite(px)||!Finite(py)) return false;
                minX=Math.Min(minX,px);maxX=Math.Max(maxX,px);minY=Math.Min(minY,py);maxY=Math.Max(maxY,py);
            }
            int left=(int)Math.Max(0,Math.Min(width,Math.Floor(minX)-1)),right=(int)Math.Max(0,Math.Min(width,Math.Ceiling(maxX)+1));
            int bottom=(int)Math.Max(0,Math.Min(height,Math.Floor(minY)-1)),top=(int)Math.Max(0,Math.Min(height,Math.Ceiling(maxY)+1));
            rect=new RectInt(left,bottom,Math.Max(0,right-left),Math.Max(0,top-bottom));return true;
        }

        private static bool TryTransformBounds(Bounds bounds,Matrix4x4 transform,out Bounds previous)
        {
            previous=default;if(!ValidBounds(bounds)) return false;
            Vector3 low=default,high=default;
            for(int axis=0;axis<3;axis++)
            {
                double center=transform[axis,0]*(double)bounds.center.x+transform[axis,1]*(double)bounds.center.y+
                    transform[axis,2]*(double)bounds.center.z+transform[axis,3];
                double extent=Math.Abs(transform[axis,0])*(double)bounds.extents.x+Math.Abs(transform[axis,1])*(double)bounds.extents.y+
                    Math.Abs(transform[axis,2])*(double)bounds.extents.z;
                // Outward padding covers the float bounds representation and composition
                // roundoff; center/extents is the affine equivalent of all eight corners.
                double pad=Math.Max(1e-5,Math.Max(Math.Abs(center),extent)*2e-6);
                low[axis]=(float)(center-extent-pad);high[axis]=(float)(center+extent+pad);
                if(!Finite(low[axis]) || !Finite(high[axis])) return false;
            }
            previous.SetMinMax(low,high);return ValidBounds(previous);
        }
    }
}
