using System;
using System.Collections.Generic;
using System.IO;
using HybridLumenGI;
using UnityEditor;
using UnityEngine;
using Object = UnityEngine.Object;

public static class AssetPageMpbExportCheck
{
    [Serializable] private sealed class Observation
    {
        public string input, rejection;
        public bool rejectedBeforeOutputs, sourcePreserved;
    }
    [Serializable] private sealed class Result
    {
        public string status = "failed", error, unity;
        public List<Observation> observations = new List<Observation>();
    }

    public static void Run()
    {
        string[] args = Environment.GetCommandLineArgs();
        int index = Array.IndexOf(args, "-mpbExportResult");
        if (index < 0 || index + 1 >= args.Length) throw new ArgumentException("Missing result path.");
        string resultPath = args[index + 1];
        if (File.Exists(resultPath)) throw new IOException("Preserve existing result.");
        var result = new Result { unity = Application.unityVersion };
        GameObject source = null; Material material = null;
        try
        {
            source = GameObject.CreatePrimitive(PrimitiveType.Cube);
            source.name = "MPB export source";
            var renderer = source.GetComponent<MeshRenderer>();
            Shader shader = Shader.Find("Universal Render Pipeline/Lit");
            if (!shader) throw new InvalidOperationException("URP Lit unavailable.");
            material = new Material(shader); material.SetColor("_BaseColor", Color.white);
            renderer.sharedMaterial = material;
            var proxy = source.AddComponent<HybridLumenGIProxy>();
            proxy.SetSources(renderer, source.GetComponent<Collider>());
            Mesh mesh = source.GetComponent<MeshFilter>().sharedMesh;
            var block = new MaterialPropertyBlock();
            Color overrideColor = new Color(.05f, .15f, .8f, 1f);
            block.SetColor("_BaseColor", overrideColor);
            for (int slot = -1; slot <= 0; slot++)
            {
                renderer.SetPropertyBlock(null); renderer.SetPropertyBlock(null, 0);
                if (slot < 0) renderer.SetPropertyBlock(block); else renderer.SetPropertyBlock(block, slot);
                string suffix = Guid.NewGuid().ToString("N");
                string assets = "Assets/HLGIMpbExportCheck-" + suffix;
                string bundles = "Assets/StreamingAssets/HLGIMpbExportCheck-" + suffix;
                int bindings = Object.FindObjectsByType<HybridLumenGIStreamedRepresentation>(FindObjectsInactive.Include, FindObjectsSortMode.None).Length;
                var row = new Observation { input = slot < 0 ? "renderer MPB" : "material-slot-only MPB" };
                try { HybridLumenGIAssetPageBuilder.Export(new[] { proxy }, assets, bundles); }
                catch (InvalidOperationException error) { row.rejection = error.Message; }
                row.rejectedBeforeOutputs = row.rejection != null && row.rejection.Contains("does not serialize Renderer MaterialPropertyBlocks") &&
                    !Directory.Exists(assets) && !Directory.Exists(bundles) && !File.Exists(assets + ".meta") && !File.Exists(bundles + ".meta") &&
                    Object.FindObjectsByType<HybridLumenGIStreamedRepresentation>(FindObjectsInactive.Include, FindObjectsSortMode.None).Length == bindings;
                var observed = new MaterialPropertyBlock();
                if (slot < 0) renderer.GetPropertyBlock(observed); else renderer.GetPropertyBlock(observed, slot);
                row.sourcePreserved = renderer.sharedMaterial == material && material.GetColor("_BaseColor") == Color.white &&
                    observed.GetColor("_BaseColor") == overrideColor && source.GetComponent<MeshFilter>().sharedMesh == mesh &&
                    proxy.SourceRenderer == renderer;
                result.observations.Add(row);
                if (!row.rejectedBeforeOutputs || !row.sourcePreserved) throw new InvalidOperationException("Export protection failed for " + row.input);
            }
            result.status = "passed";
        }
        catch (Exception error) { result.error = error.ToString(); }
        finally
        {
            if (source) Object.DestroyImmediate(source);
            if (material) Object.DestroyImmediate(material);
            File.WriteAllText(resultPath, JsonUtility.ToJson(result, true));
        }
        if (result.status != "passed") throw new InvalidOperationException(result.error);
        Debug.Log("HLGI_MPB_EXPORT_PROTECTION " + JsonUtility.ToJson(result));
    }
}
