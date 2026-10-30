"""Reuse Release83's observer and process wrapper for one candidate window."""
import importlib.util
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
BASE = HERE.parent / "release83-local-baseline-01"
spec = importlib.util.spec_from_file_location("analysis", ROOT / "LocalComparison/Implementation/analyze-unified-gpu-cost.py")
analysis = importlib.util.module_from_spec(spec)
spec.loader.exec_module(analysis)
baseline = analysis.load(BASE / "result.json")["native"]
assert baseline["completeMeasurement"]
folder = Path(baseline["runDirectory"])
start, end = baseline["window"]["sourceStart"], baseline["window"]["sourceEnd"]
samples = sorted((r for r in analysis.lines(folder / "completions.jsonl") if start <= r["sourceFrame"] <= end), key=lambda r: r["sourceFrame"])
values = [sum((r[f"end{i}"] - r[f"begin{i}"]) * 1000 / r["frequency"] for i in range(3)) for r in samples]
assert len(values) == 512
blocks = [analysis.percentile(values[i:i+64], .5) for i in range(0, 512, 64)]
criterion = dict(baseline=str(BASE / "result.json"), baselineSource="Release83 / 0181ef2",
    baselineMedianMs=baseline["intervalStatistics"]["perSourceSum"]["medianMs"],
    minimumRelativeReduction=.05, baseline64FrameBlockMediansMs=blocks,
    requires="Actual HLSL paired semantic check passes; same-configuration complete candidate window; median per-source GI sum reduction >=5%; every candidate 64-frame block median below every baseline block median; p95/p99 do not increase.",
    onFailure="Restore the candidate. No additional cost window, pass probes or parameter search.",
    scope="Finite engineering adoption rule, not statistical significance, actual Present FPS or production acceptance.")
if (HERE / "retention-criterion.json").exists():
    raise RuntimeError("Preserve the original adoption rule")
(HERE / "retention-criterion.json").write_text(json.dumps(criterion, indent=2), encoding="utf-8")
build = (BASE / "build.ps1").read_text(encoding="utf-8-sig")
build = build.replace("LocalRelease83Baseline", "UnusedDirectionWeight01")
build = build.replace("'UnifiedSampleGpuCost.cs'", "'../release83-local-baseline-01/UnifiedSampleGpuCost.cs'")
build = build.replace("hlgi-release83-baseline-", "hlgi-unused-direction-weight-")
(HERE / "build-cost.ps1").write_text(build, encoding="utf-8")
runner = (BASE / "run-player.py").read_text(encoding="utf-8-sig")
runner = runner.replace("LocalRelease83Baseline", "UnusedDirectionWeight01").replace("Release83LocalBaseline", "UnusedDirectionWeight01")
runner = runner.replace("Release83 product0181ef2;", "Release83 plus unused direction-weight candidate;")
(HERE / "run-cost.py").write_text(runner, encoding="utf-8")
print(json.dumps(criterion, indent=2))
