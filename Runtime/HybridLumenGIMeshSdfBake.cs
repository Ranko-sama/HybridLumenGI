using System;
using System.Collections.Generic;
using UnityEngine;
namespace HybridLumenGI
{
public static class HybridLumenGIMeshSdfBake
{
    public static float[] Bake(Mesh mesh, int size, Func<int, int, bool> continueSlice,
        out Bounds bounds, out bool closed)
    {
        if (mesh == null || !mesh.isReadable) throw new ArgumentException("A readable mesh is required.", nameof(mesh));
        if (size < 16 || size > 64) throw new ArgumentOutOfRangeException(nameof(size), "Resolution must be between 16 and 64.");
        return Bake(mesh.vertices,mesh.triangles,size,continueSlice,out bounds,out closed);
    }

    /// <summary>Pure copied-array kernel; safe for a worker without Unity object access.</summary>
    public static float[] Bake(Vector3[] positions,int[] indices,int size,Func<int,int,bool> continueSlice,
        out Bounds bounds,out bool closed)
    {
        if(positions==null || indices==null || indices.Length%3!=0)throw new ArgumentException("Invalid triangle arrays.");
        if(size<16 || size>64)throw new ArgumentOutOfRangeException(nameof(size));
        foreach(var p in positions)
            if(float.IsNaN(p.x)||float.IsInfinity(p.x)||float.IsNaN(p.y)||float.IsInfinity(p.y)||float.IsNaN(p.z)||float.IsInfinity(p.z))
                throw new ArgumentException("Nonfinite position.");
        foreach(int index in indices)if((uint)index>=(uint)positions.Length)throw new ArgumentException("Triangle index outside positions.");
        var geometry = new TriangleBvh(positions,indices);
        bounds = geometry.Bounds;
        closed = geometry.Watertight;
        float longest = Mathf.Max(bounds.size.x, bounds.size.y, bounds.size.z);
        if (longest <= 1e-6f) throw new ArgumentException("Mesh bounds are degenerate.", nameof(positions));
        // Two empty border voxels give interpolation/gradient queries room outside the geometry.
        float margin = 2f * longest / Mathf.Max(1, size - 4);
        Vector3 originalSize = bounds.size;
        bounds.size = new Vector3(Mathf.Max(originalSize.x, longest / size),
            Mathf.Max(originalSize.y, longest / size), Mathf.Max(originalSize.z, longest / size)) + Vector3.one * (2f * margin);
        Vector3 step = bounds.size / size;
        Vector3 minimum = bounds.min;
        float[] result = new float[size * size * size];
        for (int z = 0; z < size; z++)
        {
            if (continueSlice != null && !continueSlice(z, size)) return null;
            for (int y = 0; y < size; y++)
            for (int x = 0; x < size; x++)
            {
                Vector3 point = minimum + Vector3.Scale(new Vector3(x + 0.5f, y + 0.5f, z + 0.5f), step);
                float distance = Mathf.Sqrt(geometry.NearestDistanceSquared(point));
                if (closed && geometry.IsInside(point)) distance = -distance;
                result[x + size * (y + size * z)] = distance;
            }
        }
        return result;
    }

    private sealed class TriangleBvh
    {
        private struct Triangle
        {
            public Vector3 a, b, c, ab, ac, centroid;
            public Bounds bounds;
        }
        private struct ParityTriangle
        {
            public Vector3 perpendicular;
            public float inverseDeterminant;
            public bool usable;
        }
        private struct Node
        {
            public Bounds bounds;
            public int left, right, start, count;
        }
        private sealed class TriangleComparer : IComparer<Triangle>
        {
            public int axis;
            public int Compare(Triangle a, Triangle b) => a.centroid[axis].CompareTo(b.centroid[axis]);
        }
        private readonly Triangle[] triangles;
        private readonly ParityTriangle[] parityA, parityB, parityC;
        private readonly List<Node> nodes = new List<Node>();
        private readonly TriangleComparer comparer = new TriangleComparer();
        private static readonly Vector3 DirectionA = new Vector3(1f, 0.37213f, 0.69431f).normalized;
        private static readonly Vector3 DirectionB = new Vector3(-0.73181f, 1f, 0.25891f).normalized;
        private static readonly Vector3 DirectionC = new Vector3(0.19337f, -0.68211f, 1f).normalized;
        public Bounds Bounds { get; }
        public bool Watertight { get; }

        public TriangleBvh(Vector3[] vertices, int[] indices)
        {
            if (vertices.Length < 3 || indices.Length < 3) throw new ArgumentException("Mesh contains no triangles.");
            Bounds bounds = new Bounds(vertices[0], Vector3.zero);
            for (int i = 1; i < vertices.Length; i++) bounds.Encapsulate(vertices[i]);
            Bounds = bounds;
            Watertight = IsWatertight(vertices, indices, bounds);
            var valid = new List<Triangle>(indices.Length / 3);
            for (int i = 0; i + 2 < indices.Length; i += 3)
            {
                Vector3 a = vertices[indices[i]], b = vertices[indices[i + 1]], c = vertices[indices[i + 2]];
                Vector3 ab = b - a, ac = c - a;
                if (Vector3.Cross(ab, ac).sqrMagnitude < 1e-20f) continue;
                Bounds triangleBounds = new Bounds(a, Vector3.zero);
                triangleBounds.Encapsulate(b);
                triangleBounds.Encapsulate(c);
                valid.Add(new Triangle { a = a, b = b, c = c, ab = ab, ac = ac,
                    centroid = (a + b + c) / 3f, bounds = triangleBounds });
            }
            if (valid.Count == 0) throw new ArgumentException("Mesh only contains degenerate triangles.");
            triangles = valid.ToArray();
            Build(0, triangles.Length);
            if (Watertight)
            {
                // Prepare after sorting so each coefficient uses the final leaf index.
                parityA = PrepareParity(DirectionA);
                parityB = PrepareParity(DirectionB);
                parityC = PrepareParity(DirectionC);
            }
        }

        private int Build(int start, int count)
        {
            Bounds bounds = triangles[start].bounds;
            Bounds centroidBounds = new Bounds(triangles[start].centroid, Vector3.zero);
            for (int i = start + 1; i < start + count; i++)
            {
                bounds.Encapsulate(triangles[i].bounds);
                centroidBounds.Encapsulate(triangles[i].centroid);
            }
            int index = nodes.Count;
            nodes.Add(new Node { bounds = bounds, start = start, count = count, left = -1, right = -1 });
            if (count <= 8) return index;
            Vector3 extent = centroidBounds.size;
            comparer.axis = extent.x >= extent.y && extent.x >= extent.z ? 0 : extent.y >= extent.z ? 1 : 2;
            Array.Sort(triangles, start, count, comparer);
            int half = count / 2;
            int left = Build(start, half);
            int right = Build(start + half, count - half);
            nodes[index] = new Node { bounds = bounds, left = left, right = right, start = start, count = 0 };
            return index;
        }

        public float NearestDistanceSquared(Vector3 point) =>
            Nearest(0, point, float.PositiveInfinity, nodes[0].bounds.SqrDistance(point));

        private float Nearest(int index, Vector3 point, float best, float boundDistance)
        {
            if (boundDistance >= best) return best;
            Node node = nodes[index];
            if (node.count != 0)
            {
                for (int i = node.start; i < node.start + node.count; i++)
                    best = Mathf.Min(best, TriangleDistanceSquared(point, in triangles[i]));
                return best;
            }
            float leftDistance = nodes[node.left].bounds.SqrDistance(point);
            float rightDistance = nodes[node.right].bounds.SqrDistance(point);
            if (leftDistance > rightDistance)
                return Nearest(node.left, point, Nearest(node.right, point, best, rightDistance), leftDistance);
            return Nearest(node.right, point, Nearest(node.left, point, best, leftDistance), rightDistance);
        }

        public bool IsInside(Vector3 point)
        {
            // Majority parity reduces shared-edge/vertex degeneracy from any single ray direction.
            int votes = (Crossings(0, point, DirectionA, parityA) & 1) + (Crossings(0, point, DirectionB, parityB) & 1);
            if (votes == 0) return false;
            if (votes == 2) return true;
            return (Crossings(0, point, DirectionC, parityC) & 1) != 0;
        }

        private ParityTriangle[] PrepareParity(Vector3 direction)
        {
            var prepared = new ParityTriangle[triangles.Length];
            for (int i = 0; i < triangles.Length; i++)
            {
                ref readonly Triangle triangle = ref triangles[i];
                Vector3 perpendicular = Vector3.Cross(direction, triangle.ac);
                float determinant = Vector3.Dot(triangle.ab, perpendicular);
                if (Mathf.Abs(determinant) < 1e-12f) continue;
                prepared[i] = new ParityTriangle { perpendicular = perpendicular,
                    inverseDeterminant = 1f / determinant, usable = true };
            }
            return prepared;
        }

        private int Crossings(int index, Vector3 origin, Vector3 direction, ParityTriangle[] parity)
        {
            Node node = nodes[index];
            if (!RayBounds(origin, direction, node.bounds)) return 0;
            if (node.count == 0)
                return Crossings(node.left, origin, direction, parity) + Crossings(node.right, origin, direction, parity);
            int count = 0;
            for (int i = node.start; i < node.start + node.count; i++)
                if (RayTriangle(origin, direction, in triangles[i], in parity[i])) count++;
            return count;
        }

        private static bool RayBounds(Vector3 origin, Vector3 direction, Bounds bounds)
        {
            Vector3 a = bounds.min - origin, b = bounds.max - origin;
            float x0 = a.x / direction.x, x1 = b.x / direction.x;
            float y0 = a.y / direction.y, y1 = b.y / direction.y;
            float z0 = a.z / direction.z, z1 = b.z / direction.z;
            float near = Mathf.Max(Mathf.Min(x0, x1), Mathf.Min(y0, y1), Mathf.Min(z0, z1));
            float far = Mathf.Min(Mathf.Max(x0, x1), Mathf.Max(y0, y1), Mathf.Max(z0, z1));
            return far >= Mathf.Max(near, 0f);
        }

        private static bool RayTriangle(Vector3 origin, Vector3 direction, in Triangle triangle, in ParityTriangle parity)
        {
            if (!parity.usable) return false;
            float inverse = parity.inverseDeterminant;
            Vector3 t = origin - triangle.a;
            float u = Vector3.Dot(t, parity.perpendicular) * inverse;
            if (u < 0f || u > 1f) return false;
            Vector3 q = Vector3.Cross(t, triangle.ab);
            float v = Vector3.Dot(direction, q) * inverse;
            return v >= 0f && u + v <= 1f && Vector3.Dot(triangle.ac, q) * inverse > 1e-7f;
        }

        // Closest point regions from Ericson, Real-Time Collision Detection, section 5.1.5.
        private static float TriangleDistanceSquared(Vector3 point, in Triangle triangle)
        {
            Vector3 a = triangle.a, b = triangle.b, c = triangle.c;
            Vector3 ab = triangle.ab, ac = triangle.ac, ap = point - a;
            float d1 = Vector3.Dot(ab, ap), d2 = Vector3.Dot(ac, ap);
            if (d1 <= 0f && d2 <= 0f) return ap.sqrMagnitude;
            Vector3 bp = point - b;
            float d3 = Vector3.Dot(ab, bp), d4 = Vector3.Dot(ac, bp);
            if (d3 >= 0f && d4 <= d3) return bp.sqrMagnitude;
            float vc = d1 * d4 - d3 * d2;
            if (vc <= 0f && d1 >= 0f && d3 <= 0f) return (point - (a + ab * (d1 / (d1 - d3)))).sqrMagnitude;
            Vector3 cp = point - c;
            float d5 = Vector3.Dot(ab, cp), d6 = Vector3.Dot(ac, cp);
            if (d6 >= 0f && d5 <= d6) return cp.sqrMagnitude;
            float vb = d5 * d2 - d1 * d6;
            if (vb <= 0f && d2 >= 0f && d6 <= 0f) return (point - (a + ac * (d2 / (d2 - d6)))).sqrMagnitude;
            float va = d3 * d6 - d5 * d4;
            if (va <= 0f && d4 - d3 >= 0f && d5 - d6 >= 0f)
                return (point - (b + (c - b) * ((d4 - d3) / ((d4 - d3) + (d5 - d6))))).sqrMagnitude;
            float denominator = 1f / (va + vb + vc);
            return (point - (a + ab * (vb * denominator) + ac * (vc * denominator))).sqrMagnitude;
        }

        private static bool IsWatertight(Vector3[] vertices, int[] indices, Bounds bounds)
        {
            float epsilon = Mathf.Max(1e-7f, Mathf.Max(bounds.size.x, bounds.size.y, bounds.size.z) * 1e-6f);
            var welded = new Dictionary<Vector3Int, int>();
            var remap = new int[vertices.Length];
            for (int i = 0; i < vertices.Length; i++)
            {
                Vector3 p = (vertices[i] - bounds.center) / epsilon;
                var key = new Vector3Int(Mathf.RoundToInt(p.x), Mathf.RoundToInt(p.y), Mathf.RoundToInt(p.z));
                if (!welded.TryGetValue(key, out int id)) { id = welded.Count; welded.Add(key, id); }
                remap[i] = id;
            }
            var edges = new Dictionary<ulong, int>();
            for (int i = 0; i + 2 < indices.Length; i += 3)
            {
                int a = remap[indices[i]], b = remap[indices[i + 1]], c = remap[indices[i + 2]];
                if (a == b || b == c || c == a) return false;
                CountEdge(edges, a, b); CountEdge(edges, b, c); CountEdge(edges, c, a);
            }
            foreach (int count in edges.Values) if (count != 2) return false;
            return edges.Count > 0;
        }

        private static void CountEdge(Dictionary<ulong, int> edges, int a, int b)
        {
            ulong key = ((ulong)(uint)Mathf.Min(a, b) << 32) | (uint)Mathf.Max(a, b);
            edges.TryGetValue(key, out int count);
            edges[key] = count + 1;
        }
    }
}

}
