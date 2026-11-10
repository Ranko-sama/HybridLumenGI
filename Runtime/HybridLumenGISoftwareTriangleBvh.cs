using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Runtime.InteropServices;
using UnityEngine;

namespace HybridLumenGI
{
    /// <summary>Complete immutable exact-triangle broad phase for one prepared geometry snapshot.</summary>
    public static class HybridLumenGISoftwareTriangleBvh
    {
        public const int NodeStride=32,LeafStride=64,MaxTriangles=262144;
        private const int SplitBucketCount = 12;
        internal static int NodeCountForTriangles(int triangleCount) => triangleCount == 0 ? 0 : triangleCount * 2 - 1;
        internal static long BufferBytes(int nodeCount, int leafCount) =>
            (long)Math.Max(1,nodeCount)*NodeStride+(long)Math.Max(1,leafCount)*LeafStride;
        [StructLayout(LayoutKind.Sequential,Pack=4)]
        public struct Node { public Vector3 minimum;public uint skipIndex;public Vector3 maximum;public int leaf; }
        [StructLayout(LayoutKind.Sequential,Pack=4)]
        public struct Leaf
        {
            public Vector4 p0,p1,p2;
            public HybridLumenGIHitMaterialUInt4 identity; // prepared instance, primitive, reserved zeros
        }
        public sealed class Layout
        {
            private readonly Node[] nodes;private readonly Leaf[] leaves;
            public ReadOnlyCollection<Node> Nodes { get; }
            public ReadOnlyCollection<Leaf> Leaves { get; }
            public int NodeCount=>nodes.Length;public int LeafCount=>leaves.Length;
            public long ByteCount=>BufferBytes(NodeCount,LeafCount);
            internal Layout(Node[] nodes,Leaf[] leaves){this.nodes=nodes;this.leaves=leaves;Nodes=Array.AsReadOnly(nodes);Leaves=Array.AsReadOnly(leaves);}
            public Node[] CopyNodes()=>(Node[])nodes.Clone();public Leaf[] CopyLeaves()=>(Leaf[])leaves.Clone();
        }
        private struct BoundsRecord { public Vector3 minimum,maximum;public int leaf; }
        private struct SplitBucket
        {
            public int count;
            private Vector3 minimum, maximum;

            public void Include(Vector3 low, Vector3 high, int items)
            {
                if (items == 0) return;
                minimum = count == 0 ? low : Min(minimum, low);
                maximum = count == 0 ? high : Max(maximum, high);
                count += items;
            }

            public void Include(SplitBucket other) => Include(other.minimum, other.maximum, other.count);

            public double Cost
            {
                get
                {
                    double x = (double)maximum.x - minimum.x;
                    double y = (double)maximum.y - minimum.y;
                    double z = (double)maximum.z - minimum.z;
                    return count * (x * y + y * z + z * x);
                }
            }
        }
        private sealed class CenterComparer:IComparer<BoundsRecord>
        {
            public int axis;
            public int Compare(BoundsRecord a,BoundsRecord b)
            {
                double x=(double)At(a.minimum,axis)+At(a.maximum,axis),y=(double)At(b.minimum,axis)+At(b.maximum,axis);
                int order=x.CompareTo(y);return order!=0?order:a.leaf.CompareTo(b.leaf);
            }
        }
        private static float At(Vector3 v,int axis)=>axis==0?v.x:axis==1?v.y:v.z;
        private static Vector3 Min(Vector3 a,Vector3 b)=>new Vector3(Math.Min(a.x,b.x),Math.Min(a.y,b.y),Math.Min(a.z,b.z));
        private static Vector3 Max(Vector3 a,Vector3 b)=>new Vector3(Math.Max(a.x,b.x),Math.Max(a.y,b.y),Math.Max(a.z,b.z));
        private static bool Finite(Vector3 v)=>!float.IsNaN(v.x)&&!float.IsInfinity(v.x)&&!float.IsNaN(v.y)&&!float.IsInfinity(v.y)&&!float.IsNaN(v.z)&&!float.IsInfinity(v.z);

        private static int LongestAxis(Vector3 minimum, Vector3 maximum)
        {
            double x = (double)maximum.x - minimum.x;
            double y = (double)maximum.y - minimum.y;
            double z = (double)maximum.z - minimum.z;
            return x >= y && x >= z ? 0 : y >= z ? 1 : 2;
        }

        private static Vector3 Center(in BoundsRecord bounds) => bounds.minimum * 0.5f + bounds.maximum * 0.5f;

        private static int BucketIndex(in BoundsRecord bounds, int axis, double first, double scale)
            => Math.Min(SplitBucketCount - 1, (int)((At(Center(in bounds), axis) - first) * scale));

        private static int PartitionBySurfaceArea(BoundsRecord[] bounds, int start, int count,
            SplitBucket[] buckets, double[] leftCosts)
        {
            Vector3 low = Center(in bounds[start]), high = low;
            int end = start + count;
            for (int i = start + 1; i < end; i++)
            {
                Vector3 center = Center(in bounds[i]);
                low = Min(low, center);
                high = Max(high, center);
            }
            int axis = LongestAxis(low, high);
            double first = At(low, axis);
            double extent = At(high, axis) - first;
            if (extent <= 0) return 0;

            double scale = SplitBucketCount / extent;
            Array.Clear(buckets, 0, buckets.Length);
            for (int i = start; i < end; i++)
            {
                int bucket = BucketIndex(in bounds[i], axis, first, scale);
                buckets[bucket].Include(bounds[i].minimum, bounds[i].maximum, 1);
            }
            // Bound the recursion and worst-case rebuild work for highly skewed distributions.
            int minimumChildCount = Math.Max(1, count / 8);
            SplitBucket left = default;
            for (int i = 0; i < leftCosts.Length; i++)
            {
                left.Include(buckets[i]);
                leftCosts[i] = left.count >= minimumChildCount ? left.Cost : double.PositiveInfinity;
            }
            SplitBucket right = default;
            int split = -1;
            double bestCost = double.PositiveInfinity;
            for (int i = leftCosts.Length - 1; i >= 0; i--)
            {
                right.Include(buckets[i + 1]);
                double cost = leftCosts[i] + right.Cost;
                if (right.count < minimumChildCount || cost >= bestCost) continue;
                split = i;
                bestCost = cost;
            }
            if (split < 0) return 0;

            int middle = start;
            for (int i = start; i < end; i++)
            {
                if (BucketIndex(in bounds[i], axis, first, scale) > split) continue;
                BoundsRecord saved = bounds[middle];
                bounds[middle++] = bounds[i];
                bounds[i] = saved;
            }
            return middle - start;
        }

        private static int Build(BoundsRecord[] bounds,int start,int count,List<Node> nodes,CenterComparer comparer,
            SplitBucket[] buckets, double[] leftCosts)
        {
            Vector3 minimum=bounds[start].minimum,maximum=bounds[start].maximum;
            for(int i=start+1;i<start+count;i++){minimum=Min(minimum,bounds[i].minimum);maximum=Max(maximum,bounds[i].maximum);}
            int index=nodes.Count;nodes.Add(default);
            if(count==1){nodes[index]=new Node{minimum=minimum,maximum=maximum,skipIndex=(uint)nodes.Count,leaf=bounds[start].leaf};return index;}
            int leftCount = count >= 4 ? PartitionBySurfaceArea(bounds, start, count, buckets, leftCosts) : 0;
            if (leftCount == 0)
            {
                comparer.axis = LongestAxis(minimum, maximum);
                Array.Sort(bounds, start, count, comparer);
                leftCount = count / 2;
            }
            Build(bounds,start,leftCount,nodes,comparer,buckets,leftCosts);
            Build(bounds,start+leftCount,count-leftCount,nodes,comparer,buckets,leftCosts);
            nodes[index]=new Node{minimum=minimum,maximum=maximum,skipIndex=(uint)nodes.Count,leaf=-1};return index;
        }
        /// <summary>
        /// All prepared triangles are required. Capacity/source failure rejects the whole table,
        /// allowing the caller to keep every owner's previous software/SDF representation.
        /// Stored world positions are identical to the area provider, so GPU transforms cannot
        /// move an intersection outside CPU bounds through different floating-point rounding.
        /// </summary>
        public static bool TryBuild(HybridLumenGIAreaEmission.ITriangleProvider provider,int instanceCount,
            int triangleCapacity,out Layout layout,out string reason)
        {
            layout=null;reason=null;
            if(provider==null || instanceCount<0 || instanceCount>4096 || triangleCapacity<0 || triangleCapacity>MaxTriangles)
            {reason="Invalid prepared triangle provider, instance count or capacity.";return false;}
            try
            {
                var counts=new int[instanceCount];long total=0;
                for(int i=0;i<instanceCount;i++){counts[i]=provider.GetTriangleCount(i);if(counts[i]<0){reason="Negative prepared primitive count.";return false;}total+=counts[i];}
                if(total>triangleCapacity){reason="Complete prepared triangle table exceeds the software BVH budget.";return false;}
                var leaves=new Leaf[(int)total];var bounds=new BoundsRecord[(int)total];int cursor=0;
                for(int i=0;i<instanceCount;i++)for(int primitive=0;primitive<counts[i];primitive++)
                {
                    if(!provider.TryGetTriangle(i,primitive,out var t) || t.Instance!=(uint)i || t.Primitive!=(uint)primitive ||
                        !Finite(t.P0)||!Finite(t.P1)||!Finite(t.P2))
                    {reason="Prepared triangle source is incomplete or changed identity.";return false;}
                    leaves[cursor]=new Leaf{p0=new Vector4(t.P0.x,t.P0.y,t.P0.z,1),p1=new Vector4(t.P1.x,t.P1.y,t.P1.z,1),p2=new Vector4(t.P2.x,t.P2.y,t.P2.z,1),
                        identity=new HybridLumenGIHitMaterialUInt4((uint)i,(uint)primitive,0,0)};
                    bounds[cursor]=new BoundsRecord{minimum=Min(Min(t.P0,t.P1),t.P2),maximum=Max(Max(t.P0,t.P1),t.P2),leaf=cursor};cursor++;
                }
                var nodes=new List<Node>(NodeCountForTriangles((int)total));
                if(total>0)Build(bounds,0,bounds.Length,nodes,new CenterComparer(),
                    new SplitBucket[SplitBucketCount], new double[SplitBucketCount - 1]);
                layout=new Layout(nodes.ToArray(),leaves);return true;
            }
            catch(Exception ex){reason="Software triangle BVH capture failed: "+ex.GetType().Name;return false;}
        }
    }
}
