using System;
using HybridLumenGI;
using UnityEngine;

// Staged in Editor/ for the build only. Exercise the same methods as the C button.
public static class WallColorBuildCheck
{
    public static void Run()
    {
        var obj = new GameObject("Unified sample wall color check");
        var material = new Material(Shader.Find("Universal Render Pipeline/Lit"));
        try
        {
            var wall = obj.AddComponent<MeshRenderer>();
            wall.sharedMaterials = new[] { material, material };
            var block = new MaterialPropertyBlock();
            block.SetColor("_BaseColor", Color.red);
            wall.SetPropertyBlock(block);
            block.Clear();
            block.SetFloat("_Metallic", .375f);
            wall.SetPropertyBlock(block, 0);

            var interaction = obj.AddComponent<HybridLumenGIUnifiedSampleInteraction>();
            interaction.Configure(obj.AddComponent<Camera>(), obj.AddComponent<HybridLumenGIUnifiedSample>(), null, wall, null);
            obj.SendMessage("Start");
            interaction.SetColorChanged(true);

            var blue = new Color(.05f, .15f, .8f, 1);
            wall.GetPropertyBlock(block);
            Require(interaction.ColorChanged && block.GetColor("_BaseColor") == blue, "Renderer color did not change.");
            wall.GetPropertyBlock(block, 0);
            Require(block.GetColor("_BaseColor") == blue && block.GetFloat("_Metallic") == .375f,
                "The indexed slot must turn blue and keep its metallic override.");
            wall.GetPropertyBlock(block, 1);
            Require(block.isEmpty, "The inheriting slot gained an override.");

            interaction.SetColorChanged(false);
            wall.GetPropertyBlock(block);
            Require(!interaction.ColorChanged && block.GetColor("_BaseColor") == Color.red, "Renderer color was not restored.");
            wall.GetPropertyBlock(block, 0);
            Require(!block.HasProperty("_BaseColor") && block.GetFloat("_Metallic") == .375f,
                "The original indexed block was not restored.");
            wall.GetPropertyBlock(block, 1);
            Require(block.isEmpty, "The restored inheriting slot gained an override.");
            Debug.Log("HLGI_WALL_COLOR: C switched and restored the renderer and the indexed block; the other slot still inherits.");
        }
        finally
        {
            UnityEngine.Object.DestroyImmediate(obj);
            UnityEngine.Object.DestroyImmediate(material);
        }
        HybridLumenGI.Editor.HybridLumenGIPlayerBuild.Build();
    }

    private static void Require(bool condition, string message)
    {
        if (!condition) throw new InvalidOperationException(message);
    }
}
