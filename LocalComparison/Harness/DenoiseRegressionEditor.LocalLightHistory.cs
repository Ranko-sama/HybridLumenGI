using System;
using System.IO;
using System.Reflection;
using HybridLumenGI;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;

public static partial class DenoiseRegressionEditor
{
    [Serializable] sealed class LocalLightHistoryLane
    {
        public string kernel;
        public bool qualified;
        public float knownAge, pendingAge, poseAge, outsideAge, held, persistentAge, persistent;
        public float filtered, filteredConfidence, mixedResolve, mixedAfterFilter, resolvedCoverage, heldAfterFilter;
        public float restored, restoredAge;
    }

    [Serializable] sealed class LocalLightHistoryReport
    {
        public string unity, gpu, api;
        public bool passed;
        public LocalLightHistoryLane[] baseline, candidate;
    }

    static LocalLightHistoryLane ObserveLocalLightHistory(ComputeShader compute, Shader composite, bool identity, bool fixedProduct)
    {
        const int full = Fixture.Size * 2;
        const int boundary = (17 * full + 18) * 4;
        const int pending = (8 * Fixture.Size + 10) * 4;
        const int poseOnly = (8 * Fixture.Size + 14) * 4;
        const int outside = (8 * Fixture.Size + 16) * 4;
        using var f = new Fixture(identity, source: compute);
        f.shader.SetVector("_HLGI_JitterDelta", Vector4.zero);
        var input = Fixture.Fill(Fixture.Gray(0));
        for (int y = 0; y < Fixture.Size; y++)
            for (int x = 9; x <= 11; x++) input[y * Fixture.Size + x] = Fixture.Gray(.02f);
        Fixture.Set(f.input, input);
        f.Step(false); f.Step(true); f.Step(true);
        float old = f.last[pending];

        for (int y = 0; y < Fixture.Size; y++)
            for (int x = 9; x <= 11; x++) input[y * Fixture.Size + x] = Fixture.Gray(0, -1);
        input[poseOnly / 4] = input[outside / 4] = Fixture.Gray(0, -1);
        Fixture.Set(f.input, input);
        using var changes = new HybridLumenGIChangeRegions();
        // The wider pose reach shares these bounds. The tested samples are outside
        // the hard geometry box, so the two independent influence radii decide.
        var bounds = new Bounds(new Vector3(.18f, 0, .5f), new Vector3(.1f, 2, 1));
        changes.AddTransform(bounds, .55f);
        var markLight = typeof(HybridLumenGIChangeRegions).GetMethod("AddAnalyticLightChange", BindingFlags.Instance | BindingFlags.NonPublic);
        markLight.Invoke(changes, new object[] { bounds, .20f });
        changes.Upload();
        f.Step(true, changeRegions: changes);
        var direct = f.RenderComposite(1, full, source: composite);
        float[] filtered = null;
        for (int i = 0; i < 4; i++) filtered = f.Filter(1 << i, i);
        var combined = f.RenderComposite(1, full, f.filtered[1], composite);
        var lane = new LocalLightHistoryLane
        {
            kernel = identity ? "CSTemporalIdentity" : "CSTemporal",
            knownAge = f.lastMoments[Fixture.Center + 2], pendingAge = f.lastMoments[pending + 2],
            poseAge = f.lastMoments[poseOnly + 2], outsideAge = f.lastMoments[outside + 2], held = f.last[pending],
            filtered = filtered[Fixture.Center], filteredConfidence = filtered[Fixture.Center + 3],
            mixedResolve = direct[boundary], mixedAfterFilter = combined[boundary], resolvedCoverage = combined[boundary + 3],
            heldAfterFilter = filtered[pending]
        };
        bool trustedBlack = f.last[Fixture.Center] == 0 && f.last[Fixture.Center + 3] == 1 && f.last[pending + 3] == 1;
        f.shader.SetInt("_HLGI_ChangeCount", 0);
        f.Step(true);
        lane.persistentAge = f.lastMoments[pending + 2];
        lane.persistent = f.last[pending];
        Fixture.Set(f.input, Fixture.Fill(Fixture.Gray(0)));
        f.Step(true);
        lane.restored = f.last[pending];
        lane.restoredAge = f.lastMoments[pending + 2];

        lane.qualified = trustedBlack && old > .019f && lane.held == old && lane.persistent == old &&
            lane.knownAge == 2 && lane.poseAge == 2 && lane.outsideAge == 3 &&
            lane.filteredConfidence == 1 && lane.resolvedCoverage == 1 &&
            (fixedProduct
                ? lane.pendingAge == .5f && lane.persistentAge == .5f && lane.filtered == 0 &&
                    lane.heldAfterFilter == old && lane.mixedResolve == 0 && lane.mixedAfterFilter == 0 &&
                    lane.restoredAge == 1 && lane.restored == 0
                : lane.pendingAge == 2 && lane.persistentAge == 2 && lane.filtered > .001f &&
                    lane.mixedResolve > .001f && lane.mixedAfterFilter > .001f &&
                    lane.restoredAge == 3 && lane.restored > .01f);
        return lane;
    }

    public static void RunLocalLightHistory()
    {
        string output = Arg("-hlgiLocalLightHistoryReport", null);
        if (string.IsNullOrWhiteSpace(output) || !Path.IsPathRooted(output) || File.Exists(output) ||
            SystemInfo.graphicsDeviceType != GraphicsDeviceType.Direct3D12)
            throw new InvalidOperationException("Expected a fresh report path and DX12.");
        var baseline = AssetDatabase.LoadAssetAtPath<ComputeShader>("Assets/ComparisonHarness/LocalLightBaseline/HybridLumenGI.compute");
        var candidate = Resources.Load<ComputeShader>("HybridLumenGI/HybridLumenGI");
        var composite = Shader.Find("Hidden/HybridLumenGI/Composite");
        if (!baseline || !candidate || !composite || !composite.isSupported)
            throw new InvalidOperationException("The production shader entry points are unavailable.");
        var report = new LocalLightHistoryReport
        {
            unity = Application.unityVersion, api = SystemInfo.graphicsDeviceType.ToString(), gpu = SystemInfo.graphicsDeviceName,
            baseline = new[] { ObserveLocalLightHistory(baseline, composite, false, false), ObserveLocalLightHistory(baseline, composite, true, false) },
            candidate = new[] { ObserveLocalLightHistory(candidate, composite, false, true), ObserveLocalLightHistory(candidate, composite, true, true) }
        };
        report.passed = Array.TrueForAll(report.baseline, x => x.qualified) && Array.TrueForAll(report.candidate, x => x.qualified);
        File.WriteAllText(output, JsonUtility.ToJson(report, true));
        if (!report.passed) throw new InvalidOperationException("The fixed local-light history comparison failed.");
    }
}
