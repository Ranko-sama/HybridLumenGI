using System;
using System.Collections.Generic;
using System.IO;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;

namespace HybridLumenGI.Editor
{
    /// <summary>
    /// Explicit, tiny GPU probe for native Material color conversion on the friend's Unity build.
    /// This file has not been executed in Unity in the offline development environment.
    /// </summary>
    public static class HybridLumenGIColorContractValidation
    {
        [Serializable] private sealed class Measurement
        {
            public string source, property, propertyFlags;
            public Color setColorArgument, cpuRaw, cpuLinear, gpuLitInput;
            public float rawMaxError, linearMaxError;
            public string observedAgreement;
        }
        [Serializable] private sealed class Report
        {
            public string utc, unityVersion, pipeline, graphicsApi, device, colorSpace;
            public string scope = "Native property upload with URP LitInput, RGBAFloat linear readback; not full Lit shading, GI or performance validation.";
            public bool finiteReadbacks;
            public List<Measurement> measurements = new List<Measurement>();
        }

        [MenuItem("Tools/Hybrid Lumen GI/Validation/Probe CPU and GPU Color Contract")]
        public static void Run()
        {
            if (QualitySettings.activeColorSpace != ColorSpace.Linear)
                throw new InvalidOperationException("The HybridLumenGI color probe requires a Linear color-space project. No project settings were changed.");
            if (!SystemInfo.SupportsRenderTextureFormat(RenderTextureFormat.ARGBFloat) || !SystemInfo.SupportsTextureFormat(TextureFormat.RGBAFloat))
                throw new InvalidOperationException("RGBAFloat render/readback is unavailable on this graphics device.");
            Shader litShader = Shader.Find("Universal Render Pipeline/Lit");
            Shader probeShader = Resources.Load<Shader>("HybridLumenGI/HybridLumenGIColorContractProbe");
            if (litShader == null || probeShader == null || !probeShader.isSupported)
                throw new InvalidOperationException("URP Lit or the color-contract probe shader is missing/unsupported. Resolve shader import errors before running the probe.");

            var report = new Report
            {
                utc = DateTime.UtcNow.ToString("O"), unityVersion = Application.unityVersion,
                pipeline = GraphicsSettings.currentRenderPipeline != null ? GraphicsSettings.currentRenderPipeline.GetType().FullName : "none",
                graphicsApi = SystemInfo.graphicsDeviceType.ToString(), device = SystemInfo.graphicsDeviceName,
                colorSpace = QualitySettings.activeColorSpace.ToString(), finiteReadbacks = true
            };
            RenderTexture previous = RenderTexture.active;
            bool previousSrgbWrite = GL.sRGBWrite;
            var target = new RenderTexture(2, 2, 0, RenderTextureFormat.ARGBFloat, RenderTextureReadWrite.Linear)
            { name = "HLGI temporary color-contract target", hideFlags = HideFlags.HideAndDontSave };
            var readback = new Texture2D(2, 2, TextureFormat.RGBAFloat, false, true)
            { hideFlags = HideFlags.HideAndDontSave };
            var source = new Material(litShader) { hideFlags = HideFlags.HideAndDontSave };
            var probe = new Material(probeShader) { hideFlags = HideFlags.HideAndDontSave };
            try
            {
                if (!target.Create()) throw new InvalidOperationException("Could not allocate the probe render target.");
                var properties = new[] { "_BaseColor", "_SpecColor", "_EmissionColor" };
                var values = new[] { new Color(0.02f, 0.5f, 0.9f, 1f), new Color(1.25f, 2f, 8f, 1f) };
                for (int valueIndex = 0; valueIndex < values.Length; valueIndex++)
                    for (int propertyIndex = 0; propertyIndex < properties.Length; propertyIndex++)
                    {
                        string property = properties[propertyIndex];
                        source.SetColor(property, values[valueIndex]);
                        Measure(report, source, probe, target, readback, property, propertyIndex,
                            valueIndex == 0 ? "URP Lit created with SetColor: low range" : "URP Lit created with SetColor: HDR range", values[valueIndex]);
                    }
                // Read an existing asset without modifying it; this covers values authored in the inspector.
                if (Selection.activeObject is Material selected && selected.shader == litShader)
                    for (int i = 0; i < properties.Length; i++)
                        Measure(report, selected, probe, target, readback, properties[i], i,
                            "Selected URP Lit asset: " + AssetDatabase.GetAssetPath(selected), Color.clear);

                string folder = Path.GetFullPath(Path.Combine(Application.dataPath, "../Logs"));
                Directory.CreateDirectory(folder);
                string path = Path.Combine(folder, "HybridLumenGI-color-contract.json");
                File.WriteAllText(path, JsonUtility.ToJson(report, true));
                Debug.Log("[HybridLumenGI] Color-contract probe recorded " + report.measurements.Count +
                    " GPU measurements at " + path + ". Compare observedAgreement per property; this is not a full URP Lit render or GI validation.");
                foreach (Measurement m in report.measurements)
                    Debug.Log("[HybridLumenGI] " + m.source + " / " + m.property + ": GPU agrees with " +
                        m.observedAgreement + "; raw error=" + m.rawMaxError.ToString("G6") + ", linear error=" + m.linearMaxError.ToString("G6"));
                if (!report.finiteReadbacks)
                    throw new InvalidOperationException("A color-property GPU readback was non-finite. See the exported report and shader/device errors.");
            }
            finally
            {
                RenderTexture.active = previous;
                GL.sRGBWrite = previousSrgbWrite;
                target.Release();
                UnityEngine.Object.DestroyImmediate(target);
                UnityEngine.Object.DestroyImmediate(readback);
                UnityEngine.Object.DestroyImmediate(source);
                UnityEngine.Object.DestroyImmediate(probe);
            }
        }

        private static void Measure(Report report, Material source, Material probe, RenderTexture target,
            Texture2D readback, string property, int pass, string label, Color argument)
        {
            // Both shaders declare matching Color/HDR flags for these three properties.
            // Copy native values; do not round-trip through SetColor(GetColor(...)).
            probe.CopyPropertiesFromMaterial(source);
            Graphics.SetRenderTarget(target);
            GL.sRGBWrite = false;
            GL.Clear(false, true, new Color(float.NaN, float.NaN, float.NaN, float.NaN));
            if (!probe.SetPass(pass)) throw new InvalidOperationException("Probe shader pass was not available: " + pass);
            Graphics.DrawProceduralNow(MeshTopology.Triangles, 3, 1);
            readback.ReadPixels(new Rect(0, 0, 2, 2), 0, 0, false);
            readback.Apply(false, false);
            Color gpu = readback.GetPixel(1, 1);
            Color raw = source.GetColor(property), linear = raw.linear;
            int index = source.shader.FindPropertyIndex(property);
            float rawError = Error(raw, gpu), linearError = Error(linear, gpu);
            // No assertion chooses a CPU color convention: this is the evidence being collected.
            float tolerance = 0.002f * Mathf.Max(1f, gpu.maxColorComponent);
            string agreement = rawError <= tolerance && linearError <= tolerance ? "both (ambiguous sample)" :
                rawError <= tolerance ? "GetColor raw" : linearError <= tolerance ? "GetColor.linear" : "neither; investigate property upload";
            report.finiteReadbacks &= Finite(gpu);
            report.measurements.Add(new Measurement
            {
                source = label, property = property, propertyFlags = source.shader.GetPropertyFlags(index).ToString(),
                setColorArgument = argument, cpuRaw = raw, cpuLinear = linear, gpuLitInput = gpu,
                rawMaxError = rawError, linearMaxError = linearError, observedAgreement = agreement
            });
        }
        private static float Error(Color a, Color b) => Mathf.Max(Mathf.Abs(a.r - b.r), Mathf.Max(Mathf.Abs(a.g - b.g), Mathf.Abs(a.b - b.b)));
        private static bool Finite(Color c) => !float.IsNaN(c.r) && !float.IsNaN(c.g) && !float.IsNaN(c.b) && !float.IsNaN(c.a) &&
            !float.IsInfinity(c.r) && !float.IsInfinity(c.g) && !float.IsInfinity(c.b) && !float.IsInfinity(c.a);
    }
}
