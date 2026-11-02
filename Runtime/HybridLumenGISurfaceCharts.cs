using System;
using System.Collections.Generic;
using System.IO;
using System.Security.Cryptography;
using Unity.Collections;
using UnityEngine;

namespace HybridLumenGI
{
    /// <summary>Immutable baked material charts for a readable, undeformed source mesh.</summary>
    public sealed class HybridLumenGISurfaceCharts : ScriptableObject
    {
        [Serializable]
        public sealed class Chart
        {
            public uint stableId;
            public int sourceSubmesh;
            public Matrix4x4 localToCard;
            public Vector3 direction;
            public Bounds localBounds;
            // Triangle ordinals within sourceSubmesh, NOT vertex indices.
            public int[] triangleIndices;
        }

        [Serializable]
        public sealed class BakeSettings
        {
            public float maxNormalAngleDegrees = 30;
            public float paddingFraction = 0.02f;
            public float minimumPadding = 0.000001f;
            public int maxTrianglesPerChart = 256;
            // Advisory only: exceeding this never removes geometry.
            public int chartBudget = 384;
        }

        public sealed class BakeReport
        {
            public int inputTriangles, validTriangles, degenerateTriangles, requiredCharts;
            public int normalRejections, overlapRejections, precisionSplits, nonTriangleSubmeshes;
            public bool capacityExceeded;
        }

        [SerializeField] private Mesh sourceMesh, captureMesh;
        [SerializeField] private Chart[] charts = Array.Empty<Chart>();
        [SerializeField] private uint contentVersion;
        [SerializeField] private int fingerprintVersion;
        [SerializeField] private string sourceFingerprint;
        private const int FingerprintVersion = 1;
        [NonSerialized] private bool validationAttempted, validationPassed;

        public Mesh SourceMesh => sourceMesh;
        public Mesh CaptureMesh => captureMesh;
        public Chart[] Charts => charts;
        public uint ContentVersion => contentVersion;
        // Call from the main thread: a loaded asset is validated once before any
        // chart reaches the GPU. Never trust a serialized "valid" flag.
        public bool IsValid
        {
            get
            {
                if (sourceMesh == null || captureMesh == null || contentVersion == 0 ||
                    fingerprintVersion != FingerprintVersion || string.IsNullOrEmpty(sourceFingerprint)) return false;
                if (!validationAttempted)
                {
                    validationAttempted = true;
                    try { ValidateBakedData(sourceMesh, captureMesh, charts); validationPassed = true; }
                    catch (Exception) { validationPassed = false; }
                }
                return validationPassed;
            }
        }

        private void OnEnable() { validationAttempted = validationPassed = false; }
        private void OnValidate()
        {
            // Unity may invoke OnValidate off the main thread. Do not query any
            // Mesh API here; the next main-thread IsValid performs validation.
            contentVersion = NextVersion(contentVersion);
            validationAttempted = validationPassed = false;
        }
        private static uint NextVersion(uint value) => value == uint.MaxValue ? 1u : value + 1u;

        /// <summary>Expensive complete content check; call when the source revision changes, not per frame.</summary>
        public bool MatchesSource(Mesh mesh)
        {
            if (!IsValid || mesh == null || mesh != sourceMesh || !mesh.isReadable) return false;
            return string.Equals(sourceFingerprint, ComputeContentFingerprint(mesh), StringComparison.Ordinal);
        }

        public void SetBakedData(Mesh source, Mesh capture, Chart[] value)
        {
            ValidateBakedData(source, capture, value);
            string fingerprint = ComputeContentFingerprint(source);
            sourceMesh = source; captureMesh = capture; charts = value;
            sourceFingerprint = fingerprint; fingerprintVersion = FingerprintVersion;
            contentVersion = NextVersion(contentVersion);
            validationAttempted = validationPassed = true;
        }

        private static void ValidateBakedData(Mesh source, Mesh capture, Chart[] value)
        {
            if (source == null || capture == null || source == capture || value == null || value.Length == 0 ||
                !source.isReadable || !capture.isReadable || capture.subMeshCount != value.Length || capture.vertexCount != source.vertexCount)
                throw new ArgumentException("Charts require a distinct source-mesh clone with one capture submesh per chart.");
            if (!string.Equals(VertexFingerprint(source), VertexFingerprint(capture), StringComparison.Ordinal))
                throw new ArgumentException("Capture mesh vertex streams/layout must exactly match the source mesh.");
            var positions = source.vertices;
            foreach (Vector3 position in positions)
                if (!Finite(position.x) || !Finite(position.y) || !Finite(position.z)) throw new ArgumentException("Source positions must be finite.");
            var originals = new int[source.subMeshCount][];
            var ownership = new bool[source.subMeshCount][];
            for (int submesh = 0; submesh < source.subMeshCount; submesh++)
            {
                originals[submesh] = source.GetTopology(submesh) == MeshTopology.Triangles ? source.GetIndices(submesh, true) : Array.Empty<int>();
                if (originals[submesh].Length % 3 != 0) throw new ArgumentException("Malformed source triangle indices.");
                foreach (int index in originals[submesh]) if ((uint)index >= positions.Length) throw new ArgumentException("Invalid source vertex index.");
                ownership[submesh] = new bool[originals[submesh].Length / 3];
            }
            var ids = new HashSet<uint>();
            for (int i = 0; i < value.Length; i++)
            {
                if (value[i] == null || value[i].stableId == 0 || !ids.Add(value[i].stableId) ||
                    value[i].sourceSubmesh < 0 || value[i].sourceSubmesh >= source.subMeshCount ||
                    value[i].triangleIndices == null || value[i].triangleIndices.Length == 0 ||
                    capture.GetTopology(i) != MeshTopology.Triangles || capture.GetIndexCount(i) != (uint)value[i].triangleIndices.Length * 3u)
                    throw new ArgumentException("Invalid chart identity, source submesh, or capture index range.");
                Chart chart = value[i]; ValidateProjection(chart);
                int[] sourceIndices = originals[chart.sourceSubmesh], captureIndices = capture.GetIndices(i, true);
                var triangles = new List<Triangle>(); var members = new List<int>();
                for (int t = 0; t < chart.triangleIndices.Length; t++)
                {
                    int ordinal = chart.triangleIndices[t];
                    if ((uint)ordinal >= ownership[chart.sourceSubmesh].Length || ownership[chart.sourceSubmesh][ordinal])
                        throw new ArgumentException("A source triangle must belong to exactly one chart; ordinal is duplicate or out of range.");
                    ownership[chart.sourceSubmesh][ordinal] = true;
                    int a = sourceIndices[ordinal * 3], b = sourceIndices[ordinal * 3 + 1], c = sourceIndices[ordinal * 3 + 2];
                    if (captureIndices[t * 3] != a || captureIndices[t * 3 + 1] != b || captureIndices[t * 3 + 2] != c)
                        throw new ArgumentException("Capture indices do not match the declared source triangles.");
                    D3 normal = D3.Cross(new D3(positions[b]) - new D3(positions[a]), new D3(positions[c]) - new D3(positions[a]));
                    double length = Math.Sqrt(D3.Dot(normal, normal));
                    if (length == 0 || D3.Dot(normal / length, new D3(chart.direction)) < Math.Cos(75 * Math.PI / 180) - 0.00001)
                        throw new ArgumentException("Chart contains a degenerate or backward-facing source triangle.");
                    members.Add(triangles.Count); triangles.Add(new Triangle { a = a, b = b, c = c });
                }
                if (!ProjectionValid(chart.localToCard, members, triangles, positions))
                    throw new ArgumentException("Chart projection is outside its tile, degenerate, or has positive-area overlap.");
            }
            for (int submesh = 0; submesh < originals.Length; submesh++)
                for (int t = 0; t < ownership[submesh].Length; t++)
                {
                    int[] index = originals[submesh];
                    D3 normal = D3.Cross(new D3(positions[index[t * 3 + 1]]) - new D3(positions[index[t * 3]]),
                        new D3(positions[index[t * 3 + 2]]) - new D3(positions[index[t * 3]]));
                    if ((D3.Dot(normal, normal) != 0) != ownership[submesh][t])
                        throw new ArgumentException("Every valid source triangle must be assigned exactly once; zero-area triangles must be excluded.");
                }
        }

        private static void ValidateProjection(Chart chart)
        {
            Matrix4x4 m = chart.localToCard;
            for (int i = 0; i < 16; i++) if (!Finite(m[i])) throw new ArgumentException("Chart matrix must be finite.");
            if (m[3, 0] != 0 || m[3, 1] != 0 || m[3, 2] != 0 || m[3, 3] != 1)
                throw new ArgumentException("Chart projection must be affine.");
            D3 x = new D3(m[0, 0], m[0, 1], m[0, 2]), y = new D3(m[1, 0], m[1, 1], m[1, 2]), z = new D3(m[2, 0], m[2, 1], m[2, 2]);
            double determinant = D3.Dot(x, D3.Cross(y, z));
            if (determinant == 0 || double.IsNaN(determinant) || double.IsInfinity(determinant))
                throw new ArgumentException("Chart projection must be invertible.");
            // The inverse is used to recover card texels in local/world space.
            // Test the representability of its columns and translation, too.
            D3[] columns = { D3.Cross(y, z) / determinant, D3.Cross(z, x) / determinant, D3.Cross(x, y) / determinant };
            foreach (D3 column in columns) if (!Finite((float)column.x) || !Finite((float)column.y) || !Finite((float)column.z))
                throw new ArgumentException("Chart inverse exceeds float range.");
            D3 translation = columns[0] * -m[0, 3] - columns[1] * m[1, 3] - columns[2] * m[2, 3];
            if (!Finite((float)translation.x) || !Finite((float)translation.y) || !Finite((float)translation.z))
                throw new ArgumentException("Chart inverse translation exceeds float range.");
            D3 direction = new D3(chart.direction); double magnitude = D3.Dot(direction, direction);
            if (double.IsNaN(magnitude) || Math.Abs(magnitude - 1) > 0.001 || D3.Dot(z, direction) >= 0)
                throw new ArgumentException("Chart outward direction must be finite, unit length, and opposite increasing card depth.");
            Bounds bounds = chart.localBounds;
            if (!Finite(bounds.center.x) || !Finite(bounds.center.y) || !Finite(bounds.center.z) ||
                !Finite(bounds.size.x) || !Finite(bounds.size.y) || !Finite(bounds.size.z) || bounds.size.x < 0 || bounds.size.y < 0 || bounds.size.z < 0)
                throw new ArgumentException("Chart bounds must be finite and nonnegative.");
        }

        private static string VertexFingerprint(Mesh mesh)
        {
            using (var hash = SHA256.Create())
            {
                using (var sink = new CryptoStream(Stream.Null, hash, CryptoStreamMode.Write))
                using (var writer = new BinaryWriter(sink))
                {
                    writer.Write(mesh.vertexCount);
                    var attributes = mesh.GetVertexAttributes(); writer.Write(attributes.Length);
                    foreach (var attribute in attributes)
                    { writer.Write((int)attribute.attribute); writer.Write((int)attribute.format); writer.Write(attribute.dimension); writer.Write(attribute.stream); }
                    using (var snapshot = Mesh.AcquireReadOnlyMeshData(mesh))
                    {
                        var data = snapshot[0]; writer.Write(data.vertexBufferCount); byte[] buffer = new byte[65536];
                        for (int stream = 0; stream < data.vertexBufferCount; stream++) Write(writer, data.GetVertexData<byte>(stream), buffer);
                    }
                }
                return BitConverter.ToString(hash.Hash).Replace("-", "");
            }
        }

        /// <summary>Offline clone: vertex streams are unchanged; only chart submesh indices are rebuilt.</summary>
        public static Mesh CreateCaptureMesh(Mesh source, Chart[] value)
        {
            if (source == null || !source.isReadable || value == null || value.Length == 0) throw new ArgumentException("A readable mesh and nonempty charts are required.");
            Mesh capture = UnityEngine.Object.Instantiate(source);
            try
            {
                capture.name = source.name + "_SurfaceChartCapture";
                capture.indexFormat = UnityEngine.Rendering.IndexFormat.UInt32;
                capture.subMeshCount = value.Length;
                var sourceIndices = new Dictionary<int, int[]>();
                for (int i = 0; i < value.Length; i++)
                {
                    Chart chart = value[i];
                    if (chart == null || chart.triangleIndices == null || chart.sourceSubmesh < 0 || chart.sourceSubmesh >= source.subMeshCount ||
                        source.GetTopology(chart.sourceSubmesh) != MeshTopology.Triangles) throw new ArgumentException("Invalid source chart.");
                    if (!sourceIndices.TryGetValue(chart.sourceSubmesh, out int[] original))
                    { original = source.GetIndices(chart.sourceSubmesh, true); sourceIndices.Add(chart.sourceSubmesh, original); }
                    var indices = new int[checked(chart.triangleIndices.Length * 3)];
                    for (int triangle = 0; triangle < chart.triangleIndices.Length; triangle++)
                    {
                        int ordinal = chart.triangleIndices[triangle];
                        if (ordinal < 0 || ordinal >= original.Length / 3) throw new ArgumentException("Chart triangle ordinal is outside its source submesh.");
                        Array.Copy(original, ordinal * 3, indices, triangle * 3, 3);
                    }
                    capture.SetIndices(indices, MeshTopology.Triangles, i, false, 0);
                }
                capture.bounds = source.bounds;
                return capture;
            }
            catch { UnityEngine.Object.DestroyImmediate(capture); throw; }
        }

        /// <summary>
        /// SHA256 of raw vertex streams/layout, raw index buffer, all submesh
        /// descriptors, bounds, bind poses, full bone weights and blend-shape
        /// frame deltas. This is not a vertex-count or instance-ID fingerprint.
        /// Returned mesh-owned bone arrays are not disposed by the caller.
        /// </summary>
        public static string ComputeContentFingerprint(Mesh mesh)
        {
            if (mesh == null || !mesh.isReadable) throw new ArgumentException("A readable source mesh is required.");
            using (var hash = SHA256.Create())
            {
                using (var sink = new CryptoStream(Stream.Null, hash, CryptoStreamMode.Write))
                using (var writer = new BinaryWriter(sink))
                {
                    writer.Write(FingerprintVersion); writer.Write(mesh.vertexCount); Write(writer, mesh.bounds);
                    var attributes = mesh.GetVertexAttributes(); writer.Write(attributes.Length);
                    foreach (var attribute in attributes)
                    { writer.Write((int)attribute.attribute); writer.Write((int)attribute.format); writer.Write(attribute.dimension); writer.Write(attribute.stream); }
                    byte[] buffer = new byte[65536];
                    using (var snapshot = Mesh.AcquireReadOnlyMeshData(mesh))
                    {
                        var data = snapshot[0]; writer.Write(data.vertexBufferCount);
                        for (int stream = 0; stream < data.vertexBufferCount; stream++) Write(writer, data.GetVertexData<byte>(stream), buffer);
                        writer.Write((int)mesh.indexFormat); Write(writer, data.GetIndexData<byte>(), buffer);
                        writer.Write(data.subMeshCount);
                        for (int submesh = 0; submesh < data.subMeshCount; submesh++)
                        {
                            var descriptor = data.GetSubMesh(submesh);
                            writer.Write(descriptor.indexStart); writer.Write(descriptor.indexCount); writer.Write(descriptor.baseVertex);
                            writer.Write(descriptor.firstVertex); writer.Write(descriptor.vertexCount); writer.Write((int)descriptor.topology);
                            Write(writer, descriptor.bounds);
                        }
                    }
                    Matrix4x4[] bindposes = mesh.bindposes; writer.Write(bindposes.Length);
                    foreach (Matrix4x4 matrix in bindposes) for (int i = 0; i < 16; i++) writer.Write(matrix[i]);
                    var boneCounts = mesh.GetBonesPerVertex(); Write(writer, boneCounts, buffer);
                    var weights = mesh.GetAllBoneWeights(); writer.Write(weights.Length);
                    for (int i = 0; i < weights.Length; i++) { writer.Write(weights[i].boneIndex); writer.Write(weights[i].weight); }
                    writer.Write(mesh.blendShapeCount);
                    if (mesh.blendShapeCount > 0)
                    {
                        var positions = new Vector3[mesh.vertexCount]; var normals = new Vector3[mesh.vertexCount]; var tangents = new Vector3[mesh.vertexCount];
                        for (int shape = 0; shape < mesh.blendShapeCount; shape++)
                        {
                            writer.Write(mesh.GetBlendShapeName(shape)); int frames = mesh.GetBlendShapeFrameCount(shape); writer.Write(frames);
                            for (int frame = 0; frame < frames; frame++)
                            {
                                writer.Write(mesh.GetBlendShapeFrameWeight(shape, frame));
                                mesh.GetBlendShapeFrameVertices(shape, frame, positions, normals, tangents);
                                for (int i = 0; i < positions.Length; i++) { Write(writer, positions[i]); Write(writer, normals[i]); Write(writer, tangents[i]); }
                            }
                        }
                    }
                }
                return BitConverter.ToString(hash.Hash).Replace("-", "");
            }
        }

        private static void Write(BinaryWriter writer, Vector3 value) { writer.Write(value.x); writer.Write(value.y); writer.Write(value.z); }
        private static void Write(BinaryWriter writer, Bounds value) { Write(writer, value.center); Write(writer, value.size); }
        private static void Write(BinaryWriter writer, NativeArray<byte> data, byte[] buffer)
        {
            writer.Write(data.Length);
            for (int offset = 0; offset < data.Length;)
            {
                int count = Math.Min(buffer.Length, data.Length - offset);
                for (int i = 0; i < count; i++) buffer[i] = data[offset + i];
                writer.Write(buffer, 0, count); offset += count;
            }
        }

        public static Chart[] Bake(Mesh mesh, BakeSettings settings, out BakeReport report, Func<int, int, bool> progress = null)
        {
            if (mesh == null || !mesh.isReadable) throw new ArgumentException("Enable Read/Write on the source mesh before baking.");
            var indices = new int[mesh.subMeshCount][]; int unsupported = 0;
            for (int i = 0; i < indices.Length; i++)
            {
                bool triangles = mesh.GetTopology(i) == MeshTopology.Triangles;
                indices[i] = triangles ? mesh.GetIndices(i, true) : Array.Empty<int>();
                if (!triangles) unsupported++;
            }
            Chart[] result = BakeTriangles(mesh.vertices, indices, settings, out report, progress);
            report.nonTriangleSubmeshes = unsupported;
            return result;
        }

        /// <summary>
        /// Deterministic charting kernel. Welds exact positions for adjacency,
        /// retains original vertex indices/UV seams for capture, constrains source
        /// submesh and a fixed-seed normal cone, and rejects positive projected
        /// overlap. Nonzero-area triangles are never discarded for a chart budget.
        /// </summary>
        public static Chart[] BakeTriangles(Vector3[] positions, int[][] submeshIndices, BakeSettings settings,
            out BakeReport report, Func<int, int, bool> progress = null)
        {
            if (positions == null || submeshIndices == null) throw new ArgumentNullException();
            settings = settings ?? new BakeSettings();
            if (!Finite(settings.maxNormalAngleDegrees) || !Finite(settings.paddingFraction) || !Finite(settings.minimumPadding) ||
                settings.paddingFraction < 0.0001f || settings.paddingFraction > 0.25f || settings.minimumPadding <= 0 || settings.maxTrianglesPerChart < 1)
                throw new ArgumentException("Invalid chart bake settings.");
            double cosine = Math.Cos(Math.Max(0, Math.Min(75, settings.maxNormalAngleDegrees)) * Math.PI / 180);
            report = new BakeReport();
            var welded = new Dictionary<PositionKey, int>(); var vertexIds = new int[positions.Length];
            for (int i = 0; i < positions.Length; i++)
            {
                Vector3 p = positions[i]; if (!Finite(p.x) || !Finite(p.y) || !Finite(p.z)) throw new ArgumentException("Source mesh has a non-finite position.");
                var key = new PositionKey(p);
                if (!welded.TryGetValue(key, out int id)) { id = welded.Count; welded.Add(key, id); }
                vertexIds[i] = id;
            }
            var triangles = new List<Triangle>(); var edges = new Dictionary<Edge, List<int>>();
            for (int submesh = 0; submesh < submeshIndices.Length; submesh++)
            {
                int[] indices = submeshIndices[submesh] ?? Array.Empty<int>();
                if (indices.Length % 3 != 0) throw new ArgumentException("Triangle index count must be divisible by three.");
                for (int offset = 0; offset < indices.Length; offset += 3)
                {
                    int ordinal = report.inputTriangles++;
                    int a = indices[offset], b = indices[offset + 1], c = indices[offset + 2];
                    if ((uint)a >= positions.Length || (uint)b >= positions.Length || (uint)c >= positions.Length) throw new ArgumentException("Triangle index is outside the source vertex buffer.");
                    D3 normal = D3.Cross(new D3(positions[b]) - new D3(positions[a]), new D3(positions[c]) - new D3(positions[a]));
                    double length = Math.Sqrt(D3.Dot(normal, normal));
                    if (length == 0) { report.degenerateTriangles++; continue; }
                    int index = triangles.Count;
                    var triangle = new Triangle { a = a, b = b, c = c, submesh = submesh, ordinal = offset / 3, stableId = (uint)ordinal + 1u, normal = normal / length };
                    triangles.Add(triangle);
                    AddEdge(edges, new Edge(vertexIds[a], vertexIds[b], submesh), index);
                    AddEdge(edges, new Edge(vertexIds[b], vertexIds[c], submesh), index);
                    AddEdge(edges, new Edge(vertexIds[c], vertexIds[a], submesh), index);
                }
            }
            report.validTriangles = triangles.Count;
            var assigned = new bool[triangles.Count]; var result = new List<Chart>();
            for (int seed = 0; seed < triangles.Count; seed++)
            {
                if (assigned[seed]) continue;
                if (progress != null && !progress(seed, triangles.Count)) throw new OperationCanceledException();
                Triangle first = triangles[seed]; Basis basis = MakeBasis(first, positions);
                var members = new List<int> { seed }; var pending = new SortedSet<int>(); assigned[seed] = true;
                AddNeighbours(first, vertexIds, edges, pending);
                while (pending.Count > 0 && members.Count < settings.maxTrianglesPerChart)
                {
                    int candidate = pending.Min; pending.Remove(candidate);
                    if (assigned[candidate]) continue;
                    Triangle triangle = triangles[candidate];
                    if (D3.Dot(first.normal, triangle.normal) < cosine) { report.normalRejections++; continue; }
                    P2[] projected = Project(triangle, positions, basis); bool overlaps = false;
                    foreach (int member in members)
                        if (PositiveOverlap(projected, Project(triangles[member], positions, basis))) { overlaps = true; break; }
                    if (overlaps) { report.overlapRejections++; continue; }
                    assigned[candidate] = true; members.Add(candidate); AddNeighbours(triangle, vertexIds, edges, pending);
                }
                Chart chart = MakeChart(first, members, triangles, positions, basis, settings);
                // Validate the final serialized float matrix too. Quantization may
                // perturb a nearly touching projection. Conservatively split the
                // entire group back to its seed rather than accepting overlap.
                bool valid = ProjectionValid(chart.localToCard, members, triangles, positions);
                if (!valid && members.Count > 1)
                {
                    for (int i = 1; i < members.Count; i++) assigned[members[i]] = false;
                    members.RemoveRange(1, members.Count - 1); report.precisionSplits++;
                    chart = MakeChart(first, members, triangles, positions, basis, settings);
                }
                if (!ProjectionValid(chart.localToCard, members, triangles, positions))
                    throw new InvalidOperationException("A valid source triangle cannot be represented by a finite float chart projection. Rescale/rebase the source mesh; no partial bake was produced.");
                result.Add(chart);
            }
            report.requiredCharts = result.Count;
            report.capacityExceeded = settings.chartBudget > 0 && result.Count > settings.chartBudget;
            return result.ToArray();
        }

        private static Chart MakeChart(Triangle seed, List<int> members, List<Triangle> triangles, Vector3[] positions, Basis basis, BakeSettings settings)
        {
            double minX = double.PositiveInfinity, minY = minX, minZ = minX, maxX = double.NegativeInfinity, maxY = maxX, maxZ = maxX;
            Bounds bounds = new Bounds(positions[seed.a], Vector3.zero);
            var ordinals = new int[members.Count];
            for (int i = 0; i < members.Count; i++)
            {
                Triangle triangle = triangles[members[i]]; ordinals[i] = triangle.ordinal;
                for (int corner = 0; corner < 3; corner++)
                {
                    Vector3 p = positions[triangle.Vertex(corner)]; bounds.Encapsulate(p); D3 d = new D3(p) - basis.origin;
                    double x = D3.Dot(d, basis.right), y = D3.Dot(d, basis.up), z = D3.Dot(d, basis.normal);
                    minX = Math.Min(minX, x); maxX = Math.Max(maxX, x); minY = Math.Min(minY, y); maxY = Math.Max(maxY, y); minZ = Math.Min(minZ, z); maxZ = Math.Max(maxZ, z);
                }
            }
            // Normalize slender but valid triangles to useful raster area. An
            // absolute XY padding floor would erase sub-micrometre triangles.
            double padX = (maxX - minX) * settings.paddingFraction;
            double padY = (maxY - minY) * settings.paddingFraction;
            double padZ = Math.Max(settings.minimumPadding, Math.Max(maxX - minX, maxY - minY) * settings.paddingFraction);
            Matrix4x4 matrix = Matrix4x4.identity;
            SetRow(ref matrix, 0, basis.right, (maxX - minX) + 2 * padX, -D3.Dot(basis.origin, basis.right) - minX + padX);
            SetRow(ref matrix, 1, basis.up, (maxY - minY) + 2 * padY, -D3.Dot(basis.origin, basis.up) - minY + padY);
            SetRow(ref matrix, 2, basis.normal * -1, (maxZ - minZ) + 2 * padZ, D3.Dot(basis.origin, basis.normal) + maxZ + padZ);
            Array.Sort(ordinals);
            if (!Finite(bounds.center.x) || !Finite(bounds.center.y) || !Finite(bounds.center.z) ||
                !Finite(bounds.size.x) || !Finite(bounds.size.y) || !Finite(bounds.size.z))
                throw new InvalidOperationException("Chart bounds exceed float range. Rescale/rebase the source mesh.");
            return new Chart { stableId = seed.stableId, sourceSubmesh = seed.submesh, localToCard = matrix,
                direction = basis.normal.Float(), localBounds = bounds, triangleIndices = ordinals };
        }

        private static void SetRow(ref Matrix4x4 matrix, int row, D3 vector, double span, double offset)
        {
            matrix[row, 0] = (float)(vector.x / span); matrix[row, 1] = (float)(vector.y / span);
            matrix[row, 2] = (float)(vector.z / span); matrix[row, 3] = (float)(offset / span);
            for (int column = 0; column < 4; column++) if (!Finite(matrix[row, column])) throw new InvalidOperationException("Chart projection exceeds float range.");
        }

        private static bool ProjectionValid(Matrix4x4 matrix, List<int> members, List<Triangle> triangles, Vector3[] positions)
        {
            var projected = new List<P2[]>();
            foreach (int member in members)
            {
                Triangle triangle = triangles[member]; var p = new P2[3];
                for (int corner = 0; corner < 3; corner++)
                {
                    Vector3 v = positions[triangle.Vertex(corner)];
                    p[corner] = new P2 { x = (double)matrix[0, 0] * v.x + (double)matrix[0, 1] * v.y + (double)matrix[0, 2] * v.z + matrix[0, 3],
                        y = (double)matrix[1, 0] * v.x + (double)matrix[1, 1] * v.y + (double)matrix[1, 2] * v.z + matrix[1, 3] };
                    double z = (double)matrix[2, 0] * v.x + (double)matrix[2, 1] * v.y + (double)matrix[2, 2] * v.z + matrix[2, 3];
                    if (p[corner].x < -0.0001 || p[corner].x > 1.0001 || p[corner].y < -0.0001 || p[corner].y > 1.0001 || z < -0.0001 || z > 1.0001) return false;
                }
                if (Cross(p[0], p[1], p[2]) == 0) return false;
                // A longest-edge seed basis gives an unpadded triangle half of
                // its bounding rectangle. With <=25% margins a singleton must
                // still occupy >=20% of the tile in exact stored-matrix math.
                if (members.Count == 1 && Math.Abs(Cross(p[0], p[1], p[2])) * 0.5 < 0.2) return false;
                foreach (P2[] previous in projected) if (PositiveOverlap(p, previous)) return false;
                projected.Add(p);
            }
            return true;
        }

        private static P2[] Project(Triangle triangle, Vector3[] positions, Basis basis)
        {
            var p = new P2[3];
            for (int i = 0; i < 3; i++) { D3 d = new D3(positions[triangle.Vertex(i)]) - basis.origin; p[i] = new P2 { x = D3.Dot(d, basis.right), y = D3.Dot(d, basis.up) }; }
            return p;
        }
        // Strict separating-axis test: a shared edge/point has zero intersection
        // area and is allowed. No epsilon is used to forgive a positive overlap.
        private static bool PositiveOverlap(P2[] a, P2[] b) => !Separated(a, b) && !Separated(b, a);
        private static bool Separated(P2[] a, P2[] b)
        {
            for (int edge = 0; edge < 3; edge++)
            {
                P2 p = a[edge], q = a[(edge + 1) % 3];
                double minA = double.PositiveInfinity, maxA = double.NegativeInfinity, minB = minA, maxB = maxA;
                for (int i = 0; i < 3; i++)
                {
                    // Project relative to the edge so its two endpoints both evaluate to zero.
                    double av = Cross(p, q, a[i]), bv = Cross(p, q, b[i]);
                    minA = Math.Min(minA, av); maxA = Math.Max(maxA, av); minB = Math.Min(minB, bv); maxB = Math.Max(maxB, bv);
                }
                if (maxA <= minB || maxB <= minA) return true;
            }
            return false;
        }
        private static double Cross(P2 a, P2 b, P2 c) => (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x);
        private static Basis MakeBasis(Triangle triangle, Vector3[] positions)
        {
            D3 right = new D3(); double longest = -1;
            for (int corner = 0; corner < 3; corner++)
            {
                D3 edge = new D3(positions[triangle.Vertex((corner + 1) % 3)]) - new D3(positions[triangle.Vertex(corner)]);
                double length = D3.Dot(edge, edge);
                if (length > longest) { longest = length; right = edge; }
            }
            right = right / Math.Sqrt(longest);
            return new Basis { right = right, up = D3.Cross(triangle.normal, right), normal = triangle.normal, origin = new D3(positions[triangle.a]) };
        }
        private static void AddEdge(Dictionary<Edge, List<int>> edges, Edge edge, int triangle)
        {
            if (!edges.TryGetValue(edge, out List<int> members)) { members = new List<int>(); edges.Add(edge, members); }
            members.Add(triangle);
        }
        private static void AddNeighbours(Triangle triangle, int[] vertices, Dictionary<Edge, List<int>> edges, SortedSet<int> pending)
        {
            for (int corner = 0; corner < 3; corner++)
                foreach (int neighbour in edges[new Edge(vertices[triangle.Vertex(corner)], vertices[triangle.Vertex((corner + 1) % 3)], triangle.submesh)]) pending.Add(neighbour);
        }
        private static bool Finite(float value) => !float.IsNaN(value) && !float.IsInfinity(value);
        private struct Triangle
        {
            public int a, b, c, submesh, ordinal; public uint stableId; public D3 normal;
            public int Vertex(int corner) => corner == 0 ? a : corner == 1 ? b : c;
        }
        private struct Basis { public D3 origin, right, up, normal; }
        private struct P2 { public double x, y; }
        private struct D3
        {
            public double x, y, z;
            public D3(double x, double y, double z) { this.x = x; this.y = y; this.z = z; }
            public D3(Vector3 value) : this(value.x, value.y, value.z) { }
            public Vector3 Float() => new Vector3((float)x, (float)y, (float)z);
            public static D3 operator -(D3 a, D3 b) => new D3(a.x - b.x, a.y - b.y, a.z - b.z);
            public static D3 operator /(D3 a, double b) => new D3(a.x / b, a.y / b, a.z / b);
            public static D3 operator *(D3 a, double b) => new D3(a.x * b, a.y * b, a.z * b);
            public static double Dot(D3 a, D3 b) => a.x * b.x + a.y * b.y + a.z * b.z;
            public static D3 Cross(D3 a, D3 b) => new D3(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x);
        }
        private struct PositionKey : IEquatable<PositionKey>
        {
            private readonly float x, y, z;
            public PositionKey(Vector3 p) { x = p.x; y = p.y; z = p.z; }
            public bool Equals(PositionKey other) => x == other.x && y == other.y && z == other.z;
            public override bool Equals(object obj) => obj is PositionKey other && Equals(other);
            public override int GetHashCode() { unchecked { return (x.GetHashCode() * 397 ^ y.GetHashCode()) * 397 ^ z.GetHashCode(); } }
        }
        private struct Edge : IEquatable<Edge>
        {
            private readonly int a, b, material;
            public Edge(int a, int b, int material) { this.a = Math.Min(a, b); this.b = Math.Max(a, b); this.material = material; }
            public bool Equals(Edge other) => a == other.a && b == other.b && material == other.material;
            public override bool Equals(object obj) => obj is Edge other && Equals(other);
            public override int GetHashCode() { unchecked { return (a * 397 ^ b) * 397 ^ material; } }
        }
    }
}
