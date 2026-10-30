"""Apply the declared rule to the one native candidate window, without retry."""
import importlib.util
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
spec = importlib.util.spec_from_file_location("analysis", ROOT / "LocalComparison/Implementation/analyze-unified-gpu-cost.py")
a = importlib.util.module_from_spec(spec)
spec.loader.exec_module(a)
out = HERE / "cost-result.json"
if out.exists():
    raise RuntimeError("Preserve the first cost result")
folders = list(Path("I:/Unity test/Comparison/UnusedDirectionWeight01/run").iterdir())
assert len(folders) == 1
candidate = a.analyze(folders[0], HERE / "native-exit.json")
result = dict(status="not-adopted", candidate=candidate, productionAcceptance=False)
try:
    a.require(candidate["completeMeasurement"], "Candidate measurement incomplete")
    rule = a.load(HERE / "retention-criterion.json")
    baseline = a.load(Path(rule["baseline"]))["native"]
    for key in ("fullWidth", "fullHeight", "giWidth", "giHeight", "count", "sourceStart", "sourceEnd"):
        a.require(candidate["window"][key] == baseline["window"][key], "Configuration differs: " + key)
    for key in ("unity", "gpu", "api", "scene", "vSyncCount", "targetFrameRate"):
        a.require(candidate["environment"][key] == baseline["environment"][key], "Environment differs: " + key)
    for key in ("patchQuota", "captureQuota", "brickQuota"):
        a.require(candidate["frameCounters"]["last"][key] == baseline["frameCounters"]["last"][key], "Update quota differs: " + key)
    start, end = candidate["window"]["sourceStart"], candidate["window"]["sourceEnd"]
    rows = sorted((r for r in a.lines(folders[0] / "completions.jsonl") if start <= r["sourceFrame"] <= end), key=lambda r: r["sourceFrame"])
    values = [sum((r[f"end{i}"] - r[f"begin{i}"]) * 1000 / r["frequency"] for i in range(3)) for r in rows]
    blocks = [a.percentile(values[i:i+64], .5) for i in range(0, 512, 64)]
    before = baseline["intervalStatistics"]["perSourceSum"]
    after = candidate["intervalStatistics"]["perSourceSum"]
    reduction = (before["medianMs"] - after["medianMs"]) / before["medianMs"]
    gates = dict(median=reduction >= rule["minimumRelativeReduction"],
        blockSeparation=max(blocks) < min(rule["baseline64FrameBlockMediansMs"]),
        p95=after["p95Ms"] <= before["p95Ms"], p99=after["p99Ms"] <= before["p99Ms"])
    result.update(relativeMedianReduction=reduction, candidate64FrameBlockMediansMs=blocks, gates=gates,
        status="cost-rule-passed" if all(gates.values()) else "not-adopted")
except Exception as error:
    result["error"] = repr(error)
out.write_text(json.dumps(result, indent=2), encoding="utf-8")
print(json.dumps({k: v for k, v in result.items() if k != "candidate"}, indent=2))
print(json.dumps(candidate.get("intervalStatistics"), indent=2))
