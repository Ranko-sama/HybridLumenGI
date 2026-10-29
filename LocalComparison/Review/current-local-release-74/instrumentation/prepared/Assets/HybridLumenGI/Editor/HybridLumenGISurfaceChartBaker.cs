using System;
using System.IO;
using UnityEditor;
using UnityEngine;
using HybridLumenGI;

/// <summary>Deterministic offline material chart bake for selected static renderer geometry.</summary>
public sealed class HybridLumenGISurfaceChartBaker : EditorWindow
{
    private readonly HybridLumenGISurfaceCharts.BakeSettings settings = new HybridLumenGISurfaceCharts.BakeSettings();

    [MenuItem("Tools/Hybrid Lumen GI/Bake Surface Charts")]
    private static void Open() => GetWindow<HybridLumenGISurfaceChartBaker>("Surface Charts");

    private void OnGUI()
    {
        EditorGUILayout.HelpBox("Bake connected triangle charts with bounded normal cones and no positive projected overlap. " +
            "All nondegenerate triangles are retained even when the advisory card budget is exceeded. " +
            "Static MeshRenderer sources only; source vertex streams and materials are not modified.", MessageType.Info);
        settings.maxNormalAngleDegrees = EditorGUILayout.Slider("Normal cone half angle", settings.maxNormalAngleDegrees, 0, 75);
        settings.maxTrianglesPerChart = Mathf.Max(1, EditorGUILayout.IntField("Max triangles per chart", settings.maxTrianglesPerChart));
        settings.chartBudget = Mathf.Max(0, EditorGUILayout.IntField("Advisory chart budget", settings.chartBudget));
        settings.paddingFraction = EditorGUILayout.Slider("Projection margin", settings.paddingFraction, 0.005f, 0.1f);
        GameObject selected = Selection.activeGameObject;
        HybridLumenGIProxy proxy = selected != null ? selected.GetComponent<HybridLumenGIProxy>() : null;
        Renderer renderer = proxy != null && proxy.SourceRenderer != null ? proxy.SourceRenderer : selected != null ? selected.GetComponent<Renderer>() : null;
        MeshFilter filter = renderer != null ? renderer.GetComponent<MeshFilter>() : null;
        bool supported = renderer is MeshRenderer && filter != null && filter.sharedMesh != null;
        if (renderer is SkinnedMeshRenderer) EditorGUILayout.HelpBox("Animated/deformed meshes need a separate chart and tracing update contract. This baker does not bake skinned poses.", MessageType.Warning);
        using (new EditorGUI.DisabledScope(!supported))
            if (GUILayout.Button("Bake selected source and assign proxy")) BakeSelection(renderer, filter.sharedMesh, proxy);
    }

    private void BakeSelection(Renderer renderer, Mesh mesh, HybridLumenGIProxy proxy)
    {
        if (!mesh.isReadable) { Debug.LogError("[HybridLumenGI] Surface chart baking requires Read/Write enabled.", mesh); return; }
        string path = EditorUtility.SaveFilePanelInProject("Save surface charts", mesh.name + "_SurfaceCharts", "asset", "Choose a new asset path.");
        if (string.IsNullOrEmpty(path)) return;
        if (AssetDatabase.LoadMainAssetAtPath(path) != null || File.Exists(path))
        { Debug.LogError("[HybridLumenGI] Choose a new path; existing assets are never overwritten."); return; }
        Mesh capture = null; HybridLumenGISurfaceCharts asset = null; bool created = false, complete = false;
        try
        {
            var charts = HybridLumenGISurfaceCharts.Bake(mesh, settings, out var report, (done, total) =>
                !EditorUtility.DisplayCancelableProgressBar("Hybrid GI: surface charts", $"Triangle {done + 1}/{total}", (float)done / Mathf.Max(1, total)));
            if (charts.Length == 0) throw new InvalidOperationException("The mesh has no valid triangle surface to capture.");
            capture = HybridLumenGISurfaceCharts.CreateCaptureMesh(mesh, charts);
            asset = CreateInstance<HybridLumenGISurfaceCharts>(); asset.SetBakedData(mesh, capture, charts);
            AssetDatabase.CreateAsset(asset, path); created = true;
            AssetDatabase.AddObjectToAsset(capture, asset);
            AssetDatabase.SaveAssets();
            if (proxy == null) proxy = renderer.GetComponent<HybridLumenGIProxy>();
            if (proxy == null) proxy = Undo.AddComponent<HybridLumenGIProxy>(renderer.gameObject);
            Undo.RecordObject(proxy, "Assign surface charts");
            proxy.SetSources(renderer, renderer.GetComponent<Collider>());
            proxy.SetSurfaceCharts(asset);
            EditorUtility.SetDirty(proxy); complete = true;
            Debug.Log($"[HybridLumenGI] Baked {report.validTriangles}/{report.inputTriangles} nondegenerate triangles into {charts.Length} charts; " +
                $"degenerate={report.degenerateTriangles}, nontriangle submeshes={report.nonTriangleSubmeshes}, overlap rejections={report.overlapRejections}, precision splits={report.precisionSplits}. " +
                "The source mesh was not modified. Material capture/GPU coverage still requires Unity validation.", asset);
            if (report.capacityExceeded) Debug.LogWarning($"[HybridLumenGI] All {charts.Length} charts were retained, exceeding the advisory budget {settings.chartBudget}. " +
                "Increase residency capacity or split the asset; do not interpret partial residency as complete coverage.", asset);
        }
        catch (OperationCanceledException) { Debug.Log("[HybridLumenGI] Surface chart bake cancelled; no partial asset retained."); }
        catch (Exception error) { Debug.LogException(error); }
        finally
        {
            EditorUtility.ClearProgressBar();
            if (!complete)
            {
                if (created) AssetDatabase.DeleteAsset(path);
                else { if (capture != null) DestroyImmediate(capture); if (asset != null) DestroyImmediate(asset); }
            }
        }
    }
}
