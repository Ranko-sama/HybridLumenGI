using UnityEditor;
using UnityEngine;
using HybridLumenGI;

public sealed class HybridLumenGISetupWindow : EditorWindow
{
    [MenuItem("Tools/Hybrid Lumen GI/Setup & Proxies")]
    private static void Open() => GetWindow<HybridLumenGISetupWindow>("Hybrid Lumen GI");

    private bool includeInactive;

    private void OnGUI()
    {
        EditorGUILayout.LabelField("Hybrid Lumen GI", EditorStyles.boldLabel);
        EditorGUILayout.HelpBox(
            "Experimental Unity 6 / URP diffuse transport. See Documentation/ProductionPlan.md for uncompleted production gates. " +
            "Bake mesh distance fields for registered meshes; missing assets retain analytic proxy fallback.",
            MessageType.Info);

        EditorGUILayout.LabelField("Required setup", EditorStyles.boldLabel);
        EditorGUILayout.LabelField("1. Add HybridLumenGIRendererFeature to the active Universal Renderer Data.");
        EditorGUILayout.LabelField("2. Assign Runtime/Resources/HybridLumenGI/HybridLumenGI.compute (auto-loaded by default).");
        EditorGUILayout.LabelField("3. Assign Runtime/Resources/HybridLumenGI/HybridLumenGIComposite.shader (auto-loaded by default).");
        EditorGUILayout.LabelField("4. Use DX12, Linear color space and Render Graph. Depth, normals and motion vectors are requested by the feature.");
        EditorGUILayout.LabelField("5. Add GI proxies to walls, floors, large furniture, and other important occluders.");

        EditorGUILayout.Space();
        includeInactive = EditorGUILayout.Toggle("Include inactive objects", includeInactive);

        using (new EditorGUILayout.HorizontalScope())
        {
            if (GUILayout.Button("Add proxies to selected objects"))
                AddToSelection();
            if (GUILayout.Button("Add proxies to scene colliders"))
                AddToScene();
        }

        if (GUILayout.Button("Validate shader assets"))
        {
            ComputeShader compute = Resources.Load<ComputeShader>("HybridLumenGI/HybridLumenGI");
            Shader composite = Resources.Load<Shader>("HybridLumenGI/HybridLumenGIComposite");
            Shader surface = Resources.Load<Shader>("HybridLumenGI/HybridLumenGISurface");
            bool valid = compute != null && composite != null && surface != null;
            foreach (string kernel in new[] { "CSUpdateCache", "CSTrace", "CSTemporal", "CSFilter" })
                valid &= compute != null && compute.HasKernel(kernel);
            if (valid) Debug.Log("[HybridLumenGI] Resource assets and four compute kernels are available. Runtime/GPU validation is still required.");
            else Debug.LogError("[HybridLumenGI] Missing shader resource or compute kernel. Check the Unity shader compiler log.");
        }

        EditorGUILayout.Space();
        EditorGUILayout.HelpBox(
            "Unbaked objects use bounds proxies. Use Bake Mesh Distance Field for readable mesh assets. " +
            "The coarse six-anchor world cache, material coverage, HLOD residency and optional DXR backend require the documented scene tests.",
            MessageType.Warning);
    }

    private static void AddToSelection()
    {
        int added = 0;
        foreach (GameObject go in Selection.gameObjects)
        {
            if (go == null || go.GetComponent<HybridLumenGIProxy>() != null) continue;
            Renderer renderer = go.GetComponent<Renderer>();
            Collider collider = go.GetComponent<Collider>();
            if (renderer == null && collider == null) continue;
            var proxy = Undo.AddComponent<HybridLumenGIProxy>(go);
            proxy.SetSources(renderer, collider);
            EditorUtility.SetDirty(go);
            added++;
        }
        Debug.Log($"[HybridLumenGI] Added {added} proxy component(s) to selected objects.");
    }

    private void AddToScene()
    {
        int added = 0;
        Collider[] colliders = FindObjectsByType<Collider>(
            includeInactive ? FindObjectsInactive.Include : FindObjectsInactive.Exclude, FindObjectsSortMode.None);
        foreach (Collider collider in colliders)
        {
            if (collider == null || collider.isTrigger || collider.GetComponent<HybridLumenGIProxy>() != null) continue;
            Renderer renderer = collider.GetComponent<Renderer>();
            if (renderer == null) continue;
            var proxy = Undo.AddComponent<HybridLumenGIProxy>(collider.gameObject);
            proxy.SetSources(renderer, collider);
            EditorUtility.SetDirty(collider.gameObject);
            added++;
        }
        Debug.Log($"[HybridLumenGI] Added {added} proxy component(s) to scene colliders.");
    }
}
