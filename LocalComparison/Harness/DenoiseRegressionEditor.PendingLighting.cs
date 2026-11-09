using System;
using System.IO;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;

public static partial class DenoiseRegressionEditor
{
    [Serializable] sealed class PendingLightingLane
    {
        public bool finite;
        public float currentAge, pendingAge, currentTemporal, pendingTemporal, currentConfidence, pendingConfidence;
        public float trustedFilter, trustedResolve, currentFilter, pendingFilter;
        public float mixedResolve, pendingResolve, mixedAfterFilter;
        public float currentFilterConfidence, mixedResolveCoverage, mixedAfterFilterCoverage;
    }

    [Serializable] sealed class PendingLightingReport
    {
        public string unity, gpu, api;
        public bool passed, baselineReused;
        public PendingLightingLane baseline, candidate;
    }

    static PendingLightingLane ObservePendingLighting(ComputeShader compute, Shader composite)
    {
        const float oldLight = .02f;
        const int fullSize = Fixture.Size * 2;
        const int boundary = (17 * fullSize + 18) * 4;
        const int pendingFullPixel = (17 * fullSize + 26) * 4;
        const int pendingGiPixel = (8 * Fixture.Size + 12) * 4;
        using var f = new Fixture(true, source: compute);
        f.shader.SetVector("_HLGI_JitterDelta", Vector4.zero);
        var input = Fixture.Fill(Fixture.Gray(0));
        for (int y = 0; y < Fixture.Size; y++)
            for (int x = 9; x < Fixture.Size; x++)
                input[y * Fixture.Size + x] = Fixture.Gray(oldLight);
        Fixture.Set(f.input, input);
        f.Step(false);
        float[] trustedFilter = f.Filter(1, 0);
        float[] trustedResolve = f.RenderComposite(1, fullSize, source: composite);

        f.Reset();
        Fixture.Set(f.input, Fixture.Fill(Fixture.Gray(oldLight)));
        f.Step(false);
        for (int y = 0; y < Fixture.Size; y++)
            for (int x = 9; x < Fixture.Size; x++)
                input[y * Fixture.Size + x] = Fixture.Gray(0, -1);
        Fixture.Set(f.input, input);
        f.shader.SetFloat("_HLGI_GlobalReactive", 1);
        f.Step(true);
        // Run the actual full-resolution resolve on unfiltered history first to isolate its tap selection.
        float[] resolved = f.RenderComposite(1, fullSize, source: composite);
        float[] filtered = f.Filter(1, 0);
        for (int pass = 1; pass < 4; pass++) filtered = f.Filter(1 << pass, pass);
        float[] final = f.RenderComposite(1, fullSize, f.filtered[1], composite);
        return new PendingLightingLane
        {
            finite = Finite(f.last) && Finite(f.lastMoments) && Finite(filtered) && Finite(resolved) && Finite(final),
            currentAge = f.lastMoments[Fixture.Center + 2], pendingAge = f.lastMoments[pendingGiPixel + 2],
            currentTemporal = f.last[Fixture.Center], pendingTemporal = f.last[pendingGiPixel],
            currentConfidence = f.last[Fixture.Center + 3], pendingConfidence = f.last[pendingGiPixel + 3],
            trustedFilter = trustedFilter[Fixture.Center], trustedResolve = trustedResolve[boundary],
            currentFilter = filtered[Fixture.Center], pendingFilter = filtered[pendingGiPixel],
            mixedResolve = resolved[boundary], pendingResolve = resolved[pendingFullPixel], mixedAfterFilter = final[boundary],
            currentFilterConfidence = filtered[Fixture.Center + 3], mixedResolveCoverage = resolved[boundary + 3],
            mixedAfterFilterCoverage = final[boundary + 3]
        };
    }

    public static void RunPendingLightingSpatial()
    {
        const string baselinePath = "Assets/ComparisonHarness/PendingLightingBaseline/";
        const string candidatePath = "Assets/HybridLumenGI/Runtime/Resources/HybridLumenGI/";
        string output = Arg("-hlgiPendingLightingReport", null);
        if (string.IsNullOrEmpty(output) || SystemInfo.graphicsDeviceType != GraphicsDeviceType.Direct3D12)
            throw new InvalidOperationException("The pending lighting comparison needs a report path and real DX12 execution.");
        PendingLightingLane ReadLane(string path)
        {
            var compute = AssetDatabase.LoadAssetAtPath<ComputeShader>(path + "HybridLumenGI.compute");
            var composite = AssetDatabase.LoadAssetAtPath<Shader>(path + "HybridLumenGIComposite.shader");
            if (compute == null || composite == null || !composite.isSupported)
                throw new InvalidOperationException("Missing shader entry points in " + path);
            return ObservePendingLighting(compute, composite);
        }

        string previousPath = Arg("-hlgiPendingLightingBaselineReport", null);
        PendingLightingLane a;
        if (string.IsNullOrEmpty(previousPath))
            a = ReadLane(baselinePath);
        else
        {
            var previous = JsonUtility.FromJson<PendingLightingReport>(File.ReadAllText(previousPath));
            if (previous?.baseline == null || previous.api != SystemInfo.graphicsDeviceType.ToString() ||
                previous.unity != Application.unityVersion || previous.gpu != SystemInfo.graphicsDeviceName)
                throw new InvalidOperationException("The recorded baseline does not match this Unity or GPU.");
            a = previous.baseline;
            // The first comparison recorded RGB only at the spatial outputs.
            a.currentFilterConfidence = a.mixedResolveCoverage = a.mixedAfterFilterCoverage = -1;
        }
        var b = ReadLane(candidatePath);
        bool TemporalQualified(PendingLightingLane x) => x.finite && x.currentAge == 1 && x.pendingAge == .5f &&
            x.currentTemporal == 0 && x.pendingTemporal > .019f && x.currentConfidence == 1 && x.pendingConfidence == 1;
        bool passed = TemporalQualified(a) && TemporalQualified(b) && a.currentFilter > .001f &&
            a.mixedResolve > .001f && a.mixedAfterFilter > .001f && b.currentFilter == 0 &&
            b.currentFilterConfidence == 1 && b.mixedResolveCoverage == 1 && b.mixedAfterFilterCoverage == 1 &&
            b.mixedResolve == 0 && b.mixedAfterFilter == 0 && Math.Abs(b.pendingFilter - b.pendingTemporal) < .00002f &&
            b.pendingResolve > .009f && Math.Abs(a.pendingResolve - b.pendingResolve) < .00002f &&
            a.trustedFilter > .001f && a.trustedResolve > .001f &&
            Math.Abs(a.trustedFilter - b.trustedFilter) < .00002f && Math.Abs(a.trustedResolve - b.trustedResolve) < .00002f;
        var report = new PendingLightingReport
        {
            unity = Application.unityVersion, gpu = SystemInfo.graphicsDeviceName, api = SystemInfo.graphicsDeviceType.ToString(),
            passed = passed, baselineReused = !string.IsNullOrEmpty(previousPath), baseline = a, candidate = b
        };
        File.WriteAllText(output, JsonUtility.ToJson(report, true));
        if (!passed) throw new InvalidOperationException("Pending lighting comparison did not meet the fixed spatial contract. " + output);
    }
}
