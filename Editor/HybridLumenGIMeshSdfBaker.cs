using System;
using System.IO;
using UnityEditor;
using UnityEngine;
using HybridLumenGI;

/// <summary>Offline CPU mesh-SDF baker with a triangle BVH. Never bakes an AABB as mesh geometry.</summary>
public sealed class HybridLumenGIMeshSdfBaker : EditorWindow
{
    private int resolution = 32;

    [MenuItem("Tools/Hybrid Lumen GI/Bake Mesh Distance Field")]
    private static void Open() => GetWindow<HybridLumenGIMeshSdfBaker>("Mesh Distance Field");

    private void OnGUI()
    {
        EditorGUILayout.HelpBox("Bake the selected MeshFilter's triangle mesh into an object-space RFloat volume. " +
            "Use closed meshes for a signed field. Open meshes produce an unsigned shell and report a warning. " +
            "Rebake after topology changes; rigid transforms reuse the volume.", MessageType.Info);
        resolution = EditorGUILayout.IntPopup("Resolution", resolution, new[] { "16", "32", "64" }, new[] { 16, 32, 64 });
        EditorGUILayout.LabelField("Uncompressed volume", $"{resolution * resolution * resolution * 4 / 1024} KiB");
        MeshFilter filter = Selection.activeGameObject != null ? Selection.activeGameObject.GetComponent<MeshFilter>() : null;
        using (new EditorGUI.DisabledScope(filter == null || filter.sharedMesh == null))
            if (GUILayout.Button("Bake selected mesh and assign proxy")) BakeSelection(filter, resolution);
    }

    private static void BakeSelection(MeshFilter filter, int size)
    {
        Mesh mesh = filter.sharedMesh;
        if (!mesh.isReadable)
        {
            Debug.LogError("[HybridLumenGI] Mesh SDF baking needs Read/Write enabled on the mesh import settings.", mesh);
            return;
        }
        string path = EditorUtility.SaveFilePanelInProject("Save mesh distance field", mesh.name + "_SDF", "asset", "Choose a new mesh-SDF asset path.");
        if (string.IsNullOrEmpty(path)) return;
        if (File.Exists(path) || AssetDatabase.LoadMainAssetAtPath(path) != null)
        {
            Debug.LogError("[HybridLumenGI] Choose a new asset path to preserve existing baked data.");
            return;
        }
        Texture3D texture = null;
        HybridLumenGIMeshSdf asset = null;
        bool persisted = false;
        try
        {
            string sourceFingerprint = HybridLumenGIMeshSdf.ComputeGeometryFingerprint(mesh);
            float[] distances = Bake(mesh, size, (slice, total) =>
                !EditorUtility.DisplayCancelableProgressBar("Hybrid GI: mesh SDF", $"Slice {slice + 1}/{total}", (float)slice / total),
                out Bounds bounds, out bool closed);
            if (distances == null) return;
            texture = new Texture3D(size, size, size, TextureFormat.RFloat, false)
            {
                name = mesh.name + "_Distance",
                wrapMode = TextureWrapMode.Clamp,
                filterMode = FilterMode.Bilinear
            };
            texture.SetPixelData(distances, 0);
            // Keep readable so a residency uploader can copy voxels into an atlas without GPU readback.
            texture.Apply(false, false);
            asset = CreateInstance<HybridLumenGIMeshSdf>();
            asset.SetBakedData(mesh, texture, bounds, size, closed, sourceFingerprint);
            AssetDatabase.CreateAsset(asset, path);
            persisted = true;
            AssetDatabase.AddObjectToAsset(texture, asset);
            AssetDatabase.SaveAssets();
            Renderer renderer = filter.GetComponent<Renderer>();
            HybridLumenGIProxy proxy = filter.GetComponent<HybridLumenGIProxy>();
            if (proxy == null) proxy = Undo.AddComponent<HybridLumenGIProxy>(filter.gameObject);
            Undo.RecordObject(proxy, "Assign baked mesh distance field");
            proxy.SetSources(renderer, filter.GetComponent<Collider>());
            proxy.SetMeshSdf(asset);
            EditorUtility.SetDirty(proxy);
            Debug.Log($"[HybridLumenGI] Baked {size}³ {(closed ? "signed" : "unsigned shell")} mesh SDF: {path}. " +
                "Validate thin features and trace-step settings at this voxel size.", asset);
            if (!closed) Debug.LogWarning("[HybridLumenGI] The welded mesh has boundary/non-manifold edges. " +
                "Its volume is unsigned; repair or thicken the mesh for dependable inside/outside classification.", mesh);
        }
        catch (Exception exception)
        {
            Debug.LogException(exception);
        }
        finally
        {
            EditorUtility.ClearProgressBar();
            if (!persisted)
            {
                if (texture != null) DestroyImmediate(texture);
                if (asset != null) DestroyImmediate(asset);
            }
        }
    }

    /// <summary>Returns signed local-space voxel-center distances, or null if cancellation was requested.</summary>
    public static float[] Bake(Mesh mesh,int size,Func<int,int,bool> continueSlice,out Bounds bounds,out bool closed)
        => HybridLumenGIMeshSdfBake.Bake(mesh,size,continueSlice,out bounds,out closed);
}
