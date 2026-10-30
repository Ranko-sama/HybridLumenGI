"""Apply the predeclared retention rule to existing complete timing windows."""
import json
import statistics
from pathlib import Path

HERE = Path(__file__).resolve().parent


def load(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def summarize(path):
    result = load(path)
    native = result["native"]
    if not native["completeMeasurement"]:
        raise ValueError("Incomplete native window")
    start, end = native["window"]["sourceStart"], native["window"]["sourceEnd"]
    rows = [json.loads(line) for line in (Path(native["runDirectory"]) / "completions.jsonl").read_text(encoding="utf-8-sig").splitlines() if line.strip()]
    rows = sorted((row for row in rows if start <= row["sourceFrame"] <= end), key=lambda row: row["sourceFrame"])
    if len(rows) != 512:
        raise ValueError("Expected the already validated 512-source window")
    values = [sum((row[f"end{i}"] - row[f"begin{i}"]) * 1000 / row["frequency"] for i in range(3)) for row in rows]
    blocks = [statistics.median(values[i:i + 128]) for i in range(0, 512, 128)]
    return result, dict(intervals=native["intervalStatistics"]["perSourceSum"],
                        consecutive128FrameBlockMediansMs=blocks, blockMedianRangeMs=max(blocks) - min(blocks))


output = HERE / "retention.json"
if output.exists():
    raise RuntimeError("Preserve the first retention decision")
baseline, old = summarize(HERE / "../four-pass-local-quality-01/performance/result.json")
candidate, new = summarize(HERE / "result.json")
if baseline["settings"] != candidate["settings"]:
    raise ValueError("Quality settings differ")
saving = old["intervals"]["medianMs"] - new["intervals"]["medianMs"]
variation = max(old["blockMedianRangeMs"], new["blockMedianRangeMs"])
budget = candidate["startingBudgetDecision"]
result = dict(baseline=old, candidate=new, medianSavingMs=saving, largerBlockMedianRangeMs=variation,
              savingExceedsObservedBlockVariation=saving > variation,
              p95NoHigherThanBaseline=new["intervals"]["p95Ms"] <= old["intervals"]["p95Ms"],
              startingBudgetsPass=budget["giThreeRangesPass"] and budget["processLocalSampledPeakPass"],
              scope="Frozen descriptive retention rule for two finite static windows, not a population confidence bound, image comparison or whole-app performance acceptance.")
result["retainCandidate"] = all(result[key] for key in ("savingExceedsObservedBlockVariation", "p95NoHigherThanBaseline", "startingBudgetsPass"))
output.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
print(json.dumps(result, ensure_ascii=False, indent=2))
