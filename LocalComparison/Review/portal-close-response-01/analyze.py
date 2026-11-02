"""Compare the six outgoing-indirect observations with the separately started closed-room endpoint."""
import json
import math
import argparse
from pathlib import Path

import numpy as np


HERE = Path(__file__).resolve().parent
RUN = Path("I:/Unity test/Comparison/PortalCloseResponse01/run")
FRAMES = (119, 120, 127, 150, 179, 239)
Y_WEIGHTS = (0.2126, 0.7152, 0.0722)


def finite_json(text):
    def invalid(value):
        raise ValueError("Nonfinite JSON value: " + value)
    return json.loads(text, parse_constant=invalid)


def read(path):
    return finite_json(path.read_text(encoding="utf-8-sig"))


def require(condition, reason):
    if not condition:
        raise ValueError(reason)


def measure(folder, frame, roi):
    name = "frame-%04d.rgba32f" % frame["logicalFrame"]
    require(frame["captured"] is True and frame["raw"] == name, "No matching raw capture")
    image = np.fromfile(folder / name, dtype="<f4").reshape(360, 640, 4)
    left, top, right, bottom = roi
    rgb = image[top:bottom, left:right, :3]
    require(np.isfinite(rgb).all(), "Nonfinite RGB in fixed ROI")
    mean = rgb.mean(axis=(0, 1), dtype=np.float64)
    return mean.tolist(), float(mean @ Y_WEIGHTS)


def analyze(result, run_root):
    previous = read(HERE.parent / "connected-rooms-01" / "readings.json")
    roi = previous["roiXYHalfOpen"]
    require(roi == [240, 135, 400, 225], "Unexpected previous ROI")
    opened, closed = (previous["cases"][key] for key in ("Open", "Closed"))
    closed_folder = Path(closed["folder"])
    ref = read(closed_folder / "frame-0119.json")
    result.update(roiXYHalfOpen=roi, pixels=(roi[2] - roi[0]) * (roi[3] - roi[1]),
                  staticClosed=dict(source=closed["folder"], logicalFrame=119, meanRGB=closed["meanRGB"], meanY=closed["meanY"]))
    folders = [p for p in run_root.iterdir() if p.is_dir() and (p / "run.json").is_file()]
    require(len(folders) == 1, "Expected one capture directory")
    folder = folders[0]
    run = read(folder / "run.json")
    result.update(captureDirectory=str(folder), nativeCaptureStatus=run["status"], captureErrors=run["errors"])
    require(run["status"] == "incomplete-probe" and run["errors"] == 0 and not run["error"]
            and run["requestedFrames"] == run["renderedFrames"] == 240, "Incomplete requested 240-frame capture")
    require((run["width"], run["height"]) == (640, 360) and run["api"] == "Direct3D12"
            and run["indirectOnly"] and run["actualMode"] == "IndirectOnly" and not run["featureOff"],
            "Capture dimensions, API or signal differ")
    settings = read(folder / "feature.json")["settings"]
    closed_settings = read(closed_folder / "feature.json")["settings"]
    require(settings["raysPerPixel"] == closed["raysPerPixel"] and settings["filterIterations"] == closed["filterIterations"]
            and settings["resolutionScale"] == closed["giScale"] and settings["bounceFeedback"] == closed["bounceFeedback"]
            and settings["indirectIntensity"] == closed_settings["indirectIntensity"]
            and settings["environmentRadiance"] == closed_settings["environmentRadiance"],
            "GI settings differ from the static endpoint")
    events = {}
    for line in (run_root / "events.jsonl").read_text(encoding="utf-8-sig").splitlines():
        if line.strip():
            event = finite_json(line)
            n = event["logicalFrame"]
            if n in FRAMES:
                require(n not in events, f"Duplicate event for frame {n}")
                events[n] = event

    for n in FRAMES:
        row = {"logicalFrame": n}
        result["frames"].append(row)
        try:
            frame = read(folder / f"frame-{n:04d}.json")
            event = events[n]
            row.update(engineFrame=frame["engineFrame"], secondsSinceClose=event["secondsSinceClose"],
                       doorOpen=event["doorOpen"], doorPosition=event["doorPosition"], roomsEnabled=event["roomsEnabled"],
                       cameraPosition=frame["cameraPosition"], enabledLights=event["enabledLights"], published=event["published"])
            names = event["published"]
            require(isinstance(names, list), "Missing publication list")
            row.update(receiverPublished="Entry floor" in names, portalPublished="Sliding partition door" in names,
                       emitterPublished="Source room warm panel" in names)
            diag = finite_json(frame["diagnosticsJson"])
            row["diagnostics"] = {key: diag[key] for key in ("frame", "hardwareBackend", "hardwareMeshes", "hardwareFallbacks",
                                  "publishedInstances", "lightSelected", "readyCards", "pendingCards")}
            row["meanRGB"], row["meanY"] = measure(folder, frame, roi)
            require(frame["logicalFrame"] == n and event["engineFrame"] == frame["engineFrame"], "Event/capture frame mismatch")
            require(frame["cameraPosition"] == event["cameraPosition"] == ref["cameraPosition"]
                    and frame["cameraRotation"] == ref["cameraRotation"] and frame["projection"] == ref["projection"],
                    "Different view of fixed receiver")
            require(event["roomsEnabled"] is True and event["doorOpen"] is (n == 119)
                    and event["doorPosition"] == (opened if n == 119 else closed)["sceneState"]["doorPosition"],
                    "Room or physical door state differs")
            require(math.isfinite(row["secondsSinceClose"]) and (n == 119 or row["secondsSinceClose"] >= 0),
                    "Invalid event clock")
            require(event["enabledLights"] == 0 and diag["lightSelected"] == 0, "Analytic lights active")
            require(diag["hardwareBackend"] is True and diag["hardwareMeshes"] > 0, "No reported DXR backend")
            require(row["receiverPublished"], "Fixed entry-floor receiver is not published")
        except (OSError, KeyError, TypeError, ValueError, OverflowError) as error:
            result["failures"].append(f"{n}: {error}")

    if result["failures"]:
        return
    rows = result["frames"]
    engine_offset = rows[0]["engineFrame"] - FRAMES[0]
    require(all(row["engineFrame"] == row["logicalFrame"] + engine_offset for row in rows), "Engine frame discontinuity")
    require(all(a["secondsSinceClose"] <= b["secondsSinceClose"] for a, b in zip(rows[1:], rows[2:])),
            "Post-close timestamps run backwards")
    span = rows[0]["meanY"] - closed["meanY"]
    require(math.isfinite(span) and span > 0, "Open-minus-closed luminance does not define a positive normalization")
    for row in rows:
        row["relativeRemainingY"] = (row["meanY"] - closed["meanY"]) / span
    result.update(status="observed", openMinusStaticClosedY=span)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--run", type=Path, default=RUN)
    parser.add_argument("--output", type=Path, default=HERE / "result.json")
    args = parser.parse_args()
    output = args.output
    if output.exists():
        raise SystemExit("Preserve existing result.json")
    result = dict(status="incomplete", frames=[], failures=[],
                  quantity="Mean linear outgoing indirect diffuse RGB/Y of the same entry-floor ROI, using native raw rows.",
                  normalization="(Y - separately started static-closed frame119 Y) / (this run's open frame119 Y - static-closed Y). Signed and unclipped.",
                  scope="Sampled response only. Door pose and published GI owners are separate observations. Published names do not establish a refreshed cache or per-pixel validity. The closed endpoint is an observed baseline, with no physical truth or settling threshold.")
    try:
        analyze(result, args.run)
    except (OSError, KeyError, TypeError, ValueError, OverflowError) as error:
        result["failures"].append(str(error))
    with output.open("x", encoding="utf-8") as stream:
        json.dump(result, stream, ensure_ascii=False, indent=2, allow_nan=False)
        stream.write("\n")
    print(json.dumps({"status": result["status"], "failures": result["failures"], "output": str(output)}))
    raise SystemExit(0 if result["status"] == "observed" else 1)
