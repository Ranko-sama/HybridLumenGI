using System;
using UnityEditor;
using UnityEngine;

/// <summary>Deterministic numerical checks callable from an editor menu or Unity -executeMethod.</summary>
public static class HybridLumenGIMeshSdfValidation
{
    [MenuItem("Tools/Hybrid Lumen GI/Validate Mesh SDF Numerics")]
    public static void Run()
    {
        GameObject cube = null;
        GameObject plane = null;
        try
        {
            cube = GameObject.CreatePrimitive(PrimitiveType.Cube);
            cube.hideFlags = HideFlags.HideAndDontSave;
            Mesh mesh = cube.GetComponent<MeshFilter>().sharedMesh;
            const int size = 16;
            float[] values = HybridLumenGIMeshSdfBaker.Bake(mesh, size, null, out Bounds bounds, out bool closed);
            if (!closed) throw new Exception("Cube with duplicated seam vertices must be detected as watertight.");
            float maxError = 0f;
            int negative = 0;
            for (int z = 0; z < size; z++)
            for (int y = 0; y < size; y++)
            for (int x = 0; x < size; x++)
            {
                Vector3 p = bounds.min + Vector3.Scale(new Vector3(x + 0.5f, y + 0.5f, z + 0.5f), bounds.size / size);
                Vector3 q = new Vector3(Mathf.Abs(p.x), Mathf.Abs(p.y), Mathf.Abs(p.z)) - Vector3.one * 0.5f;
                float analytic = new Vector3(Mathf.Max(q.x, 0f), Mathf.Max(q.y, 0f), Mathf.Max(q.z, 0f)).magnitude +
                    Mathf.Min(Mathf.Max(q.x, q.y, q.z), 0f);
                float sample = values[x + size * (y + size * z)];
                if (sample < 0f) negative++;
                maxError = Mathf.Max(maxError, Mathf.Abs(sample - analytic));
            }
            if (negative == 0 || maxError > 1e-4f)
                throw new Exception($"Cube signed distance mismatch. Negative voxels={negative}, maximum error={maxError}.");
            if (HybridLumenGIMeshSdfBaker.Bake(mesh, size, (slice, total) => false, out _, out _) != null)
                throw new Exception("Cancelled bake must return null.");

            plane = GameObject.CreatePrimitive(PrimitiveType.Plane);
            plane.hideFlags = HideFlags.HideAndDontSave;
            float[] shell = HybridLumenGIMeshSdfBaker.Bake(plane.GetComponent<MeshFilter>().sharedMesh,
                size, null, out _, out bool planeClosed);
            if (planeClosed) throw new Exception("An open plane must not be classified as watertight.");
            for (int i = 0; i < shell.Length; i++)
                if (shell[i] < 0f || float.IsNaN(shell[i]) || float.IsInfinity(shell[i]))
                    throw new Exception("Open-mesh unsigned shell contains an invalid distance.");
            Debug.Log($"[HybridLumenGI] Mesh SDF numerical checks passed: cube sign/distance, seam welding, cancellation, open shell. Maximum cube error={maxError:G5}.");
        }
        finally
        {
            if (cube != null) UnityEngine.Object.DestroyImmediate(cube);
            if (plane != null) UnityEngine.Object.DestroyImmediate(plane);
        }
    }
}
