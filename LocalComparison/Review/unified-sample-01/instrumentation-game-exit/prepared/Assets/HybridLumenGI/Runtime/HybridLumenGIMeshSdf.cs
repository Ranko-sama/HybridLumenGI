using System;
using System.IO;
using System.Security.Cryptography;
using UnityEngine;

namespace HybridLumenGI
{
    /// <summary>A baked, object-space signed-distance volume for one static mesh topology.</summary>
    public sealed class HybridLumenGIMeshSdf : ScriptableObject
    {
        [SerializeField] private Mesh sourceMesh;
        [SerializeField] private Texture3D distanceTexture;
        [SerializeField] private Bounds localBounds;
        [SerializeField] private int resolution;
        [SerializeField] private bool watertight;
        [SerializeField] private float interpolationError;
        [SerializeField] private int fingerprintVersion;
        [SerializeField] private string geometryFingerprint;
        private const int GeometryFingerprintVersion = 1;
        [NonSerialized] private bool sourceChecked, sourceMatches;
        [NonSerialized] private HybridLumenGIMeshSource.Version checkedStamp;
        [NonSerialized] private int checkedVertices, checkedSubmeshes;
        [NonSerialized] private Bounds checkedBounds;

        public Mesh SourceMesh => sourceMesh;
        public Texture3D DistanceTexture => distanceTexture;
        public Bounds LocalBounds => localBounds;
        public int Resolution => resolution;
        public bool Watertight => watertight;
        // Subtract this conservative spatial interpolation error before a sphere-tracing step.
        public float InterpolationError => interpolationError;
        public Vector3 VoxelSize => resolution > 0 ? localBounds.size / resolution : Vector3.zero;
        public bool HasSourceFingerprint => fingerprintVersion == GeometryFingerprintVersion && !string.IsNullOrEmpty(geometryFingerprint);
        public bool IsValid => sourceMesh != null && distanceTexture != null && resolution >= 16 && resolution <= 64 && HasSourceFingerprint;

        private void OnEnable() { InvalidateSourceValidation(); }
        private void OnValidate() { InvalidateSourceValidation(); } // No Mesh API on this callback.
        public void InvalidateSourceValidation() { sourceChecked = sourceMatches = false; checkedStamp = null; }

        /// <summary>Compatibility entry point; also invalidates receivers without an SDF or Proxy.</summary>
        public static void NotifyGeometryChanged(Mesh mesh) => HybridLumenGIMeshSource.NotifyGeometryChanged(mesh);

        /// <summary>Main-thread source check. Hash once after loading or notified edits, not on rigid motion.</summary>
        public bool MatchesSource(Mesh mesh)
        {
            if (!IsValid || mesh == null || mesh != sourceMesh || !mesh.isReadable)
            { InvalidateSourceValidation(); return false; }
            HybridLumenGIMeshSource.Version stamp = HybridLumenGIMeshSource.GetVersion(mesh);
            int vertices = mesh.vertexCount, submeshes = mesh.subMeshCount;
            Bounds bounds = mesh.bounds;
            if (sourceChecked && ReferenceEquals(checkedStamp, stamp) && checkedVertices == vertices &&
                checkedSubmeshes == submeshes && checkedBounds.Equals(bounds)) return sourceMatches;
            bool matches;
            try { matches = string.Equals(geometryFingerprint, ComputeGeometryFingerprint(mesh), StringComparison.Ordinal); }
            catch (Exception) { matches = false; }
            checkedStamp = stamp; checkedVertices = vertices; checkedSubmeshes = submeshes; checkedBounds = bounds;
            sourceChecked = true; sourceMatches = matches;
            return matches;
        }

        /// <summary>Geometry-only hash of the exact vertex/index inputs consumed by the SDF baker.</summary>
        public static string ComputeGeometryFingerprint(Mesh mesh)
        {
            if (mesh == null || !mesh.isReadable) throw new ArgumentException("A readable source mesh is required.", nameof(mesh));
            Vector3[] vertices = mesh.vertices;
            int[] triangles = mesh.triangles;
            if (vertices == null || vertices.Length < 3 || triangles == null || triangles.Length < 3 || triangles.Length % 3 != 0)
                throw new ArgumentException("Source mesh has no complete triangle geometry.", nameof(mesh));
            using (var stream = new MemoryStream())
            using (var writer = new BinaryWriter(stream))
            using (var sha = SHA256.Create())
            {
                writer.Write(GeometryFingerprintVersion); writer.Write(vertices.Length);
                foreach (Vector3 vertex in vertices)
                {
                    if (float.IsNaN(vertex.x) || float.IsInfinity(vertex.x) || float.IsNaN(vertex.y) ||
                        float.IsInfinity(vertex.y) || float.IsNaN(vertex.z) || float.IsInfinity(vertex.z))
                        throw new ArgumentException("Source mesh positions must be finite.", nameof(mesh));
                    writer.Write(vertex.x); writer.Write(vertex.y); writer.Write(vertex.z);
                }
                writer.Write(triangles.Length);
                foreach (int index in triangles)
                {
                    if ((uint)index >= (uint)vertices.Length) throw new ArgumentException("Invalid source triangle index.", nameof(mesh));
                    writer.Write(index);
                }
                writer.Flush(); stream.Position = 0;
                return BitConverter.ToString(sha.ComputeHash(stream)).Replace("-", string.Empty);
            }
        }

        public void SetBakedData(Mesh mesh, Texture3D texture, Bounds bounds, int size, bool closed, string expectedGeometryFingerprint = null)
        {
            string fingerprint = ComputeGeometryFingerprint(mesh);
            if (expectedGeometryFingerprint != null && !string.Equals(expectedGeometryFingerprint, fingerprint, StringComparison.Ordinal))
                throw new InvalidOperationException("Source geometry changed during SDF baking. Discard the result and rebake.");
            sourceMesh = mesh;
            distanceTexture = texture;
            localBounds = bounds;
            resolution = size;
            watertight = closed;
            // A full voxel diagonal bounds trilinear interpolation error of a 1-Lipschitz distance field.
            interpolationError = (bounds.size / Mathf.Max(1, size)).magnitude;
            geometryFingerprint = fingerprint; fingerprintVersion = GeometryFingerprintVersion;
            NotifyGeometryChanged(mesh);
            InvalidateSourceValidation();
        }
    }
}
