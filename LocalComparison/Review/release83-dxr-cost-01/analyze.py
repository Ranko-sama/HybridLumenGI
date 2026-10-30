"""Use the existing native analysis, then describe cadence and memory separately."""
import importlib.util
import json
import math
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
spec = importlib.util.spec_from_file_location("existing_native_analysis", HERE / "native-analysis.py")
base = importlib.util.module_from_spec(spec)
spec.loader.exec_module(base)
folders = list(Path("I:/Unity test/Comparison/Release83DxrCost01/run").iterdir())
if len(folders) != 1 or (HERE / "result.json").exists():
    raise RuntimeError("Expected one run and no prior analysis result")
folder = folders[0]
native = base.analyze(folder, HERE / "native-exit.json")
result = dict(status="partial-baseline", product="Release83 / 0181ef2", native=native,
              formalTargets="User target960x540/30FPS; GI-only time and memory limits unset.",
              scope="One current960x540 actual-DXR static window. Backend cost/memory decision only; no equal-image speedup, displayed FPS, default change or lifetime peak claim.")
try:
    base.require(native["completeMeasurement"], "Native source window incomplete; no replacement or partial GPU percentile")
    meta = base.load(folder / "run.json")
    rows = {r["engineFrame"]: r for r in base.lines(folder / "frames.jsonl")}
    start, end = meta["sourceStart"], meta["sourceEnd"]
    times = [rows[i]["callbackSeconds"] for i in range(start - 1, end + 1)]
    base.require(len(times) == 513 and all(math.isfinite(x) for x in times), "Missing pre-window anchor/callback timestamp")
    intervals = [(b - a) * 1000 for a, b in zip(times, times[1:])]
    base.require(len(intervals) == 512 and all(x > 0 for x in intervals), "Invalid callback intervals")
    result["callbackCadence"] = dict(base.stats(intervals), meanMs=sum(intervals) / 512,
        frequencyHz=512 / (times[-1] - times[0]), elapsedSeconds=times[-1] - times[0],
        sourceStart=start, sourceEnd=end, precedingAnchorFrame=start - 1, timestampCount=513,
        interpretation="512 target-camera endCamera callback intervals using the immediately preceding stable anchor. Includes application scheduling/waits; not CPU busy time, actual Present FPS or whole-app GPU time.")
    memory = meta["memoryWindow"]
    complete = (meta.get("memoryWindowCaptured") and memory["valid"] and memory["hasSamples"] and
                memory["windowFirstFrame"] == start and memory["sampleFrame"] == end and memory["attemptFrame"] == end and
                memory["samples"] == 512 and memory["failedSamples"] == 0)
    result["processMemory"] = dict(completeWindow=bool(complete), snapshot=memory,
        localCurrentMiB=memory["localUsageBytes"] / 1048576 if memory["valid"] else None,
        nonlocalCurrentMiB=memory["nonlocalUsageBytes"] / 1048576 if memory["valid"] else None,
        localSampledPeakMiB=memory["peakLocalUsageBytes"] / 1048576 if memory["hasSamples"] else None,
        nonlocalSampledPeakMiB=memory["peakNonlocalUsageBytes"] / 1048576 if memory["hasSamples"] else None,
        interpretation="CPU DXGI samples of this process on the Unity adapter. local/nonlocal separate; not GI-only allocation, whole-machine usage or instantaneous/lifetime peak. GPU completion can lag this CPU sampling window; OS budget is not the product target.")
    result["status"] = "complete-limited-baseline" if complete else "partial-baseline-memory-unavailable-or-window-differs"
except Exception as error:
    result["error"] = repr(error)
(HERE / "result.json").write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
print(json.dumps({k: v for k, v in result.items() if k != "native"}, ensure_ascii=False, indent=2))
print(json.dumps(dict(gpu=native.get("intervalStatistics"), environment=native.get("environment"), window=native.get("window")), ensure_ascii=False, indent=2))
