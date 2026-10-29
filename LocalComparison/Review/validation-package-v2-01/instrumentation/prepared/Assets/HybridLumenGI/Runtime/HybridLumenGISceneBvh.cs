using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using UnityEngine;
using UnityEngine.Rendering;

namespace HybridLumenGI
{
    /// <summary>Stackless broad phase over resident instance bounds. Leaf slots refer to the stable scene table.</summary>
    public sealed class HybridLumenGISceneBvh : IDisposable
    {
        [StructLayout(LayoutKind.Sequential)]
        public struct Node
        {
            public Vector3 minimum;
            public uint skipIndex; // Absolute first node after this subtree; NodeCount terminates traversal.
            public Vector3 maximum;
            public int proxySlot; // -1 for an internal node; bounds alone never represent a surface hit.
        }
        private struct Leaf { public Bounds bounds; public int slot; }
        private sealed class LeafComparer : IComparer<Leaf>
        {
            public int axis;
            public int Compare(Leaf a, Leaf b)
            {
                int value = a.bounds.center[axis].CompareTo(b.bounds.center[axis]);
                return value != 0 ? value : a.slot.CompareTo(b.slot);
            }
        }

        public const int Stride = 32;
        public ComputeBuffer Buffer { get; private set; }
        public Node[] Nodes { get; private set; } = Array.Empty<Node>();
        public int NodeCount { get; private set; }
        public int RebuildCount { get; private set; }
        public int RefitCount { get; private set; }
        private bool[] previousActive = Array.Empty<bool>();
        private Bounds[] previousBounds = Array.Empty<Bounds>();
        private Leaf[] leaves = Array.Empty<Leaf>();
        private readonly LeafComparer comparer = new LeafComparer();
        private float baselineArea;
        private bool pendingUpload;
        private static readonly int BufferId = Shader.PropertyToID("_HLGI_SceneBvh");
        private static readonly int CountId = Shader.PropertyToID("_HLGI_SceneBvhCount");

        /// <summary>Rebuilds on membership changes, otherwise refits changed bounds. Does no geometry intersection.</summary>
        public bool Update(Bounds[] bounds, bool[] active, int count, bool upload = true)
        {
            if (bounds == null || active == null || count < 0 || count > bounds.Length || count > active.Length)
                throw new ArgumentException("BVH bounds/active arrays do not cover the requested slot count.");
            bool rebuild = previousActive.Length != count;
            if (rebuild)
            {
                previousActive = new bool[count]; previousBounds = new Bounds[count]; leaves = new Leaf[count];
                Nodes = new Node[Mathf.Max(1, count * 2 - 1)];
                Buffer?.Release(); Buffer = null;
            }
            bool changed = rebuild;
            int leafCount = 0;
            for (int slot = 0; slot < count; slot++)
            {
                bool enabled = active[slot] && IsFinite(bounds[slot]);
                if (enabled != previousActive[slot]) rebuild = changed = true;
                if (enabled && !bounds[slot].Equals(previousBounds[slot])) changed = true;
                if (enabled) leaves[leafCount++] = new Leaf { bounds = bounds[slot], slot = slot };
                previousActive[slot] = enabled;
                previousBounds[slot] = bounds[slot];
            }
            if (changed)
            {
                pendingUpload = true;
                if (!rebuild && leafCount > 0)
                {
                    Refit();
                    RefitCount++;
                    // Large motion can destroy the quality of a fixed topology; rebuild when overlap cost grows.
                    rebuild = TotalInternalArea() > Mathf.Max(baselineArea * 1.75f, 1e-5f);
                }
                if (rebuild || leafCount == 0)
                {
                    NodeCount = 0;
                    if (leafCount > 0) Build(0, leafCount);
                    baselineArea = TotalInternalArea();
                    RebuildCount++;
                }
            }
            if (upload && (pendingUpload || Buffer == null))
            {
                if (Buffer == null) Buffer = new ComputeBuffer(Mathf.Max(1, Nodes.Length), Stride, ComputeBufferType.Structured) { name = "Hybrid GI Scene BVH" };
                if (NodeCount > 0) Buffer.SetData(Nodes, 0, 0, NodeCount);
                else Buffer.SetData(new Node[1]);
                pendingUpload = false;
            }
            return changed;
        }

        private int Build(int start, int count)
        {
            Bounds bounds = leaves[start].bounds;
            Vector3 minimum = bounds.min, maximum = bounds.max;
            Bounds centers = new Bounds(bounds.center, Vector3.zero);
            for (int i = start + 1; i < start + count; i++)
            {
                // Keep explicit min/max: repeated Bounds center/extent conversion can round a
                // parent inward and cull a ray exactly on a child's boundary.
                minimum = Vector3.Min(minimum, leaves[i].bounds.min);
                maximum = Vector3.Max(maximum, leaves[i].bounds.max);
                centers.Encapsulate(leaves[i].bounds.center);
            }
            int index = NodeCount++;
            if (count == 1)
            {
                Nodes[index] = new Node { minimum = minimum, maximum = maximum, skipIndex = (uint)NodeCount, proxySlot = leaves[start].slot };
                return index;
            }
            Vector3 extent = centers.size;
            comparer.axis = extent.x >= extent.y && extent.x >= extent.z ? 0 : extent.y >= extent.z ? 1 : 2;
            Array.Sort(leaves, start, count, comparer);
            int half = count / 2;
            Build(start, half); Build(start + half, count - half);
            Nodes[index] = new Node { minimum = minimum, maximum = maximum, skipIndex = (uint)NodeCount, proxySlot = -1 };
            return index;
        }

        private void Refit()
        {
            for (int i = NodeCount - 1; i >= 0; i--)
            {
                Node node = Nodes[i];
                if (node.proxySlot >= 0)
                { node.minimum = previousBounds[node.proxySlot].min; node.maximum = previousBounds[node.proxySlot].max; }
                else
                {
                    Node left = Nodes[i + 1], right = Nodes[(int)Nodes[i + 1].skipIndex];
                    node.minimum = Vector3.Min(left.minimum, right.minimum);
                    node.maximum = Vector3.Max(left.maximum, right.maximum);
                }
                Nodes[i] = node;
            }
        }

        private float TotalInternalArea()
        {
            float area = 0f;
            for (int i = 0; i < NodeCount; i++)
            {
                if (Nodes[i].proxySlot >= 0) continue;
                Vector3 size = Nodes[i].maximum - Nodes[i].minimum;
                area += size.x * size.y + size.y * size.z + size.z * size.x;
            }
            return area;
        }

        /// <summary>CPU counterpart of the shader iterator, used by deterministic traversal/fuzz tests.</summary>
        public int NextLeaf(ref int cursor, Vector3 origin, Vector3 direction, float limit, ref int visited)
        {
            while (cursor >= 0 && cursor < NodeCount)
            {
                Node node = Nodes[cursor]; visited++;
                if (!IntersectsBounds(origin, direction, node.minimum, node.maximum, limit))
                { cursor = Mathf.Max(cursor + 1, (int)node.skipIndex); continue; }
                cursor++;
                if (node.proxySlot >= 0) return node.proxySlot;
            }
            return -1;
        }

        public static bool IntersectsBounds(Vector3 origin, Vector3 direction, Vector3 minimum, Vector3 maximum, float limit)
        {
            float enter = 0f, leave = limit;
            if (limit < 0f) return false;
            for (int axis = 0; axis < 3; axis++)
            {
                if (Mathf.Abs(direction[axis]) < 1e-12f)
                {
                    if (origin[axis] < minimum[axis] || origin[axis] > maximum[axis]) return false;
                    continue;
                }
                float a = (minimum[axis] - origin[axis]) / direction[axis];
                float b = (maximum[axis] - origin[axis]) / direction[axis];
                enter = Mathf.Max(enter, Mathf.Min(a, b)); leave = Mathf.Min(leave, Mathf.Max(a, b));
                if (leave < enter) return false;
            }
            return true;
        }
        private static bool IsFinite(Bounds bounds)
        {
            Vector3 center = bounds.center, extent = bounds.extents;
            for (int i = 0; i < 3; i++)
                if (float.IsNaN(center[i]) || float.IsInfinity(center[i]) || float.IsNaN(extent[i]) || float.IsInfinity(extent[i]) || extent[i] < 0f) return false;
            return true;
        }
        public void Bind(CommandBuffer command, ComputeShader compute, int kernel)
        {
            if (Buffer == null) throw new InvalidOperationException("Update/upload the scene BVH before binding.");
            command.SetComputeBufferParam(compute, kernel, BufferId, Buffer);
            command.SetComputeIntParam(compute, CountId, NodeCount);
        }
        public void Dispose()
        {
            Buffer?.Release(); Buffer = null; Nodes = Array.Empty<Node>(); leaves = Array.Empty<Leaf>();
            previousActive = Array.Empty<bool>(); previousBounds = Array.Empty<Bounds>(); NodeCount = 0; baselineArea = 0;
            pendingUpload = false;
        }
    }
}
