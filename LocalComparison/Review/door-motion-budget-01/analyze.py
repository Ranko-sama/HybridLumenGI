"""Analyze one ordinary moving-door window, including its stationary parts."""
import json
import math
from pathlib import Path
import runpy


HERE = Path(__file__).resolve().parent
RUN_PARENT = Path("I:/Unity test/Comparison/DoorMotionBudget01/run")
# Read the existing source-frame/token validator without importing into the archive.
BASE = runpy.run_path(str(HERE.parent / "release83-dxr-cost-01" / "native-analysis.py"))
load, require = BASE["load"], BASE["require"]


def analyze(folder):
    native = BASE["analyze"](folder, HERE / "native-exit.json")
    result = {
        "status": "incomplete", "native": native,
        "scope": "One ordinary moving-door window. GI time sums ReceiverCapture, Transport and Composite per source frame. No whole-application or Present timing. Process-local memory is a sampled peak on the Unity adapter.",
    }
    try:
        require(native["completeMeasurement"], "Incomplete native window; no motion budget decision")
        meta = load(folder / "run.json")
        settings = load(folder / "settings-measure.json")
        require(settings["raysPerPixel"] == 2 and settings["filterIterations"] == 4 and
                settings["preferHardwareTracing"] is True and settings["resolutionScale"] == .5 and
                (native["window"]["giWidth"], native["window"]["giHeight"]) == (480, 270),
                "Expected 960x540 / half-GI / 2-ray / four-pass DXR")
        result["settings"] = {k: settings[k] for k in
                              ("raysPerPixel", "resolutionScale", "filterIterations", "cacheRaysPerFace", "preferHardwareTracing")}
        start, end = meta["sourceStart"], meta["sourceEnd"]
        window = [r for r in BASE["lines"](folder / "frames.jsonl") if start <= r["engineFrame"] <= end]
        require(meta.get("doorMotion") is True and len(window) == 512 and all(r.get("doorMoving") is True for r in window),
                "Ordinary door motion was not enabled throughout the source window")
        positions = [tuple(r["doorPosition"][axis] for axis in "xyz") for r in window]
        require(all(type(v) in (float, int) and math.isfinite(v) for p in positions for v in p),
                "Missing finite door position")
        changed = sum(a != b for a, b in zip(positions, positions[1:]))
        result["motion"] = dict(sourceStart=start, sourceEnd=end, enabledFrames=len(window),
                                positionChanges=changed, firstXYZ=positions[0], lastXYZ=positions[-1],
                                minXYZ=[min(axis) for axis in zip(*positions)], maxXYZ=[max(axis) for axis in zip(*positions)])
        require(changed > 0, "The door position never changed in the measured window")

        p95 = native["intervalStatistics"]["perSourceSum"]["p95Ms"]
        result["giBudget"] = dict(perSourceSumP95Ms=p95, limitMs=25, withinLimit=p95 <= 25)
        memory = meta["memoryWindow"]
        complete = (meta.get("memoryWindowCaptured") is True and memory["valid"] is True and memory["hasSamples"] is True and
                    memory["windowFirstFrame"] == start and memory["sampleFrame"] == end and memory["attemptFrame"] == end and
                    memory["samples"] == 512 and memory["failedSamples"] == 0)
        result["processMemory"] = dict(completeWindow=complete, snapshot=memory,
                                       scope="DXGI local and nonlocal usage sampled on the source engine frames. Nonlocal is reported separately. No instantaneous peak or GI-only allocation claim.")
        require(complete, "Memory samples do not cover the same 512 source frames")
        local = BASE["integer"](memory, "peakLocalUsageBytes", 0)
        nonlocal_peak = BASE["integer"](memory, "peakNonlocalUsageBytes", 0)
        result["processMemory"].update(localSampledPeakMiB=local / 2**20, nonlocalSampledPeakMiB=nonlocal_peak / 2**20,
                                       localLimitBytes=2**30, withinLocalLimit=local <= 2**30)
        result["withinBothLimits"] = p95 <= 25 and local <= 2**30
        result["status"] = "complete-motion-window"
    except (OSError, KeyError, TypeError, ValueError, OverflowError) as error:
        result["error"] = str(error)
    return result


if __name__ == "__main__":
    output = HERE / "result.json"
    folders = list(RUN_PARENT.iterdir())
    if output.exists() or len(folders) != 1 or not folders[0].is_dir() or not (HERE / "native-exit.json").is_file():
        raise SystemExit("Expected one completed run, its native exit receipt and a fresh result path")
    report = analyze(folders[0])
    with output.open("x", encoding="utf-8") as stream:
        json.dump(report, stream, ensure_ascii=False, indent=2, allow_nan=False)
        stream.write("\n")
    print(json.dumps({key: value for key, value in report.items() if key != "native"}, ensure_ascii=False))
    raise SystemExit(0 if report["status"] == "complete-motion-window" else 1)
