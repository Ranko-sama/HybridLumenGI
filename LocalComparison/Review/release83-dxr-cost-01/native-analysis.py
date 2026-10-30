"""Read one finite UnifiedSampleGpuCost run; never fill missing native samples.

Usage: python analyze-unified-gpu-cost.py --run-dir RUN --native-exit EXIT.json
       --output NEW-result.json
EXIT.json is supplied by the process owner and must contain exitCode=0.
No build provenance, hashes, image reads, GPU work or shutdown inference occurs.
"""
import argparse
import json
import math
from pathlib import Path


def load(path):
    def invalid(value):
        raise ValueError("Nonfinite JSON constant: " + value)
    return json.loads(path.read_text(encoding="utf-8-sig"), parse_constant=invalid)


def lines(path):
    result = []
    for number, line in enumerate(path.read_text(encoding="utf-8-sig").splitlines(), 1):
        if not line.strip():
            continue
        value = json.loads(line, parse_constant=lambda value: (_ for _ in ()).throw(ValueError("Nonfinite JSON constant")))
        require(isinstance(value, dict), f"Non-object row {number}: {path.name}")
        result.append(value)
    return result


def require(condition, message):
    if not condition:
        raise ValueError(message)


def integer(row, key, minimum=None):
    value = row[key]
    require(type(value) is int and (minimum is None or value >= minimum), "Invalid integer " + key)
    return value


def percentile(values, q):
    ordered = sorted(values)
    position = (len(ordered) - 1) * q
    lower, upper = math.floor(position), math.ceil(position)
    return ordered[lower] + (ordered[upper] - ordered[lower]) * (position - lower)


def stats(values):
    return dict(count=len(values), medianMs=percentile(values, .5), p95Ms=percentile(values, .95),
                p99Ms=percentile(values, .99), maxMs=max(values))


COUNTERS = ("completed", "exported", "unexported", "invalid", "cancelled", "timedOut", "feedbackRejected",
            "buffered", "pending", "materialBytes", "uploadBytes", "instances", "warming", "cards", "cardPending",
            "globalReady", "globalPending", "globalUpdated", "patchQuota", "captureQuota", "brickQuota",
            "patchesScheduled", "groupPublished", "groupTransitioning", "pagePending", "pageFailed",
            "pageActiveOperations", "pageIoBytesInFlight", "pageRetiringLeases")


def analyze(folder, native_exit_path):
    result = dict(status="incomplete", completeMeasurement=False, productionAcceptance=False,
                  runDirectory=str(folder), failures=[], intervalStatistics=None,
                  scope="512 distinct consecutive source frames; native ReceiverCapture, Transport, Composite queue intervals and per-source sum.",
                  excludes="CPU preparation, uploads/RenderGraph work outside these intervals, query resolve, full-application GPU time, FPS and total VRAM. Queue intervals may include barriers/waits.",
                  percentileMethod="Linear interpolation at (N-1)*q; sum the three intervals for each source frame before percentile.",
                  memoryInterpretation="Start/end ledgers are unmodified observations; no growth, leak, total-VRAM or steady-state inference.")
    try:
        meta = load(folder / "run.json")
        frames = lines(folder / "frames.jsonl")
        samples = lines(folder / "completions.jsonl")
        native_exit = load(native_exit_path)
        result["nativeExit"] = native_exit
        result["environment"] = {k: meta[k] for k in ("unity", "gpu", "api", "driver", "scene", "scope", "scopeExclusions", "vSyncCount", "targetFrameRate") if k in meta}
        result["recordedCounts"] = dict(frames=len(frames), completions=len(samples))
        # Preserve both ledgers without interpreting deltas or ownership totals.
        result["ledgers"] = {name: load(folder / (name + "-ledger.json")) if (folder / (name + "-ledger.json")).is_file() else None
                             for name in ("start", "end")}
        if frames:
            result["frameCounters"] = {name: {k: row[k] for k in ("engineFrame",) + COUNTERS if k in row}
                                       for name, row in (("first", frames[0]), ("last", frames[-1]))}
        require(meta.get("status") == "collected" and not meta.get("error"), "Observer did not collect successfully")
        require(meta.get("api") == "Direct3D12", "NativeDX12 API not recorded")
        require(meta.get("scopes") == ["ReceiverCapture", "Transport", "Composite"], "Native scope order mismatch")
        require(integer(native_exit, "exitCode") == 0, "Native process exit was not zero")
        require(native_exit.get("watchdogTerminated", False) is False, "Native process was watchdog-terminated")
        require(meta.get("measureOnly") is True and meta.get("adaptive") is False and meta.get("targetMs") == 0,
                "Measurement-only / feedback-off controls not established")
        require(integer(meta, "window") == 512, "Source window must be 512")
        require(integer(meta, "drainLimit") == 32 and integer(meta, "warmupLimit") == 256 and integer(meta, "frameLimit") == 800,
                "Unexpected bounded collection contract")
        require(integer(meta, "frames") == len(frames) and 544 < len(frames) <= 800, "Frame receipt count mismatch")
        require(integer(meta, "completions") == len(samples), "Completion receipt count mismatch")
        start, end = integer(meta, "sourceStart", 0), integer(meta, "sourceEnd", 0)
        require(end - start + 1 == 512, "Source interval is not 512 frames")
        require([integer(row, "index", 0) for row in frames] == list(range(len(frames))), "Receipt index gap/duplicate")
        first = integer(frames[0], "engineFrame", 0)
        require(integer(meta, "firstEngineFrame", 0) == first, "First engine frame mismatch")
        require([integer(row, "engineFrame", 0) for row in frames] == list(range(first, first + len(frames))), "Engine/source receipt gap or duplicate")
        require(frames[-1]["engineFrame"] == end + 32, "Incomplete fixed drain receipts")
        rows = {row["engineFrame"]: row for row in frames}
        require(start - 1 in rows and 1 <= start - first <= 256, "Missing pre-window anchor or excessive warmup")
        for row in frames:
            expected_stage = 0 if row["engineFrame"] < start else 1 if row["engineFrame"] <= end else 2
            require(integer(row, "stage", 0) == expected_stage, "Stage/source-frame disagreement")
        anchor = rows[start - 1]
        result["window"] = dict(sourceStart=start, sourceEnd=end, count=512, fullWidth=anchor["fullWidth"], fullHeight=anchor["fullHeight"],
                                giWidth=anchor["width"], giHeight=anchor["height"])
        identity = ("owner", "generation", "deviceEpoch", "epoch")
        dimensions = ("width", "height", "fullWidth", "fullHeight")
        require((anchor["fullWidth"], anchor["fullHeight"]) == (960, 540), "Expected 960x540 full target")
        for key in identity + dimensions:
            integer(anchor, key, 0)
        require(anchor["owner"] > 0 and anchor["width"] > 0 and anchor["height"] > 0, "Invalid anchor identity/dimensions")
        for row in frames:
            if row["stage"] == 0:
                continue
            for key in identity + dimensions:
                integer(row, key, 0)
            require(all(row[key] == anchor[key] for key in identity + dimensions), "Window/drain identity or dimensions changed")
            require(row.get("native") is True and row.get("ready") is True and row.get("exactSoftware") is False and row.get("hardware") is True,
                    "Window/drain is not ready NativeDX12 DXR")
            require(row.get("feedback") is False and row.get("scale") == 1, "Feedback or adaptive quota scaling active")
            integer(row, "token", 1)
        tokens = [integer(sample, "token", 1) for sample in samples]
        require(len(set(tokens)) == len(tokens), "Repeated completion token")
        pairs = [(integer(sample, "owner", 1), integer(sample, "sourceFrame", 0)) for sample in samples]
        require(len(set(pairs)) == len(pairs), "Repeated completion owner/source frame")
        selected = [sample for sample in samples if start <= sample["sourceFrame"] <= end]
        present = {sample["sourceFrame"] for sample in selected}
        expected = set(range(start, end + 1))
        result["selectedCompletions"] = len(selected)
        result["missingSourceFrames"] = sorted(expected - present)
        require(present == expected and len(selected) == 512, "Incomplete source-frame set; no survivor percentiles")
        require(integer(meta, "windowCompletions") == 512, "Observer window completion count mismatch")
        columns = [[], [], [], []]
        for sample in sorted(selected, key=lambda row: row["sourceFrame"]):
            row = rows[sample["sourceFrame"]]
            for key in identity:
                integer(sample, key, 0)
            require(all(sample[key] == row[key] for key in ("token",) + identity), "Completion token/owner/generation/deviceEpoch/epoch mismatch")
            read_frame = integer(sample, "readFrame", 0)
            require(0 < read_frame - sample["sourceFrame"] <= 32 and read_frame in rows, "Completion read-frame boundary mismatch")
            frequency = integer(sample, "frequency", 1)
            ticks = [integer(sample, key, 0) for key in ("begin0", "end0", "begin1", "end1", "begin2", "end2")]
            require(all(a <= b for a, b in zip(ticks, ticks[1:])), "Nonmonotone scope timestamps")
            values = [(ticks[i + 1] - ticks[i]) * 1000 / frequency for i in (0, 2, 4)]
            values.append(sum(values))
            require(all(math.isfinite(value) and value >= 0 for value in values) and values[3] > 0, "Invalid native interval duration")
            for column, value in zip(columns, values):
                column.append(value)
        # Publish no percentile until the whole 512-frame set has passed every gate.
        result["intervalStatistics"] = {name: stats(values) for name, values in zip(("ReceiverCapture", "Transport", "Composite", "perSourceSum"), columns)}
        result.update(status="complete", completeMeasurement=True)
    except (OSError, ValueError, TypeError, KeyError, IndexError, OverflowError) as error:
        result["failures"].append(type(error).__name__ + ": " + str(error))
    return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run-dir", required=True, type=Path)
    parser.add_argument("--native-exit", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path, help="New result file; existing evidence is never overwritten")
    args = parser.parse_args()
    if args.output.exists():
        parser.error("Output already exists")
    report = analyze(args.run_dir.resolve(), args.native_exit.resolve())
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("x", encoding="utf-8", newline="\n") as output:
        json.dump(report, output, indent=2, ensure_ascii=False, allow_nan=False)
        output.write("\n")
    print(json.dumps(dict(status=report["status"], completeMeasurement=report["completeMeasurement"], failures=report["failures"], output=str(args.output))))
    raise SystemExit(0 if report["completeMeasurement"] else 1)
