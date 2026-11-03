"""Interpret the one prospective Final HDR pair. Never launches Unity."""
import argparse
import json
from pathlib import Path
import numpy as np

Y = np.array([.2126, .7152, .0722])


def load(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def rgba(values):
    return np.array([[v[k] for k in "rgba"] for v in values], dtype=np.float64)


def need(value, message):
    if not value:
        raise ValueError(message)


def plane(folder, descriptor):
    name = descriptor["data"]["file"] if "data" in descriptor else descriptor["file"]
    return np.fromfile(folder / name, dtype="<f4").reshape(descriptor["height"], descriptor["width"], 4)


def read_lane(folder, expected_lane):
    r = load(folder / "scene-result.json")
    editor = load(folder / "editor-result.json")
    need(r["status"] == editor["status"] == "collected" and editor["restored"], "Collection/restore incomplete")
    need(r["lane"] == expected_lane and r["width"] == 960 and r["height"] == 540 and r["uvStartsAtTop"], "Lane/camera convention differs")
    need(r["baselineDrained"] and r["preEventReadbackCompleted"] and r["readbacksDrained"] and r["pendingReadbacks"] == 0, "Readback owner not drained")
    need(r["eventAfterLogical"] == 119 and r["peakPendingReadbacks"] <= 8, "Event/observation limits differ")
    selection = r["selection"]["points"]
    points = np.array([p["full"] for p in selection], dtype=int)
    old = np.array([p["oldSampledFull"] for p in selection], dtype=int)
    need(points.shape == (27, 2) and len(set(map(tuple, points))) == 27 and np.array_equal(points, np.floor((old + .5) * 1.5)), "Fixed source-pixel mapping differs")
    settings = json.loads(r["settings"])
    expected = dict(resolutionScale=.5, raysPerPixel=2, filterIterations=4,
                    temporalAccumulation=True, temporalCurrentWeight=.08, maxHistory=32,
                    bounceFeedback=1, cachePatchesPerFrame=256, cachePatchGrid=4,
                    cacheRaysPerFace=8, guidedSamplingWeight=.35, emissiveSamplingWeight=.5,
                    maxEmissiveProposals=16, preferHardwareTracing=True, adaptiveGpuBudget=False,
                    receiverObjectHistory=True, debugView=0)
    need(all(np.float32(settings[k]) == np.float32(v) for k, v in expected.items()), "Released quality settings differ")
    need(all(settings["environmentRadiance"][k] == 0 for k in "rgb"), "Nonblack GI environment")
    rows = r["frames"]
    need([f["logicalFrame"] for f in rows] == list(range(r["requests"])) and rows[-1]["logicalFrame"] == r["finalLogical"], "Incomplete source sequence")
    need(all(rows[i]["engineFrame"] == rows[i-1]["engineFrame"] + 1 for i in range(2, len(rows))), "Observer interrupted f-1 engine history")
    need(r["eventEngine"] == rows[119]["engineFrame"], "Event left pre-event engine frame")
    observed = rows[119:]
    need(all(f["readbackRequested"] and f["readbackCompleted"] and not f.get("readbackError") for f in observed), "An issued source has no valid Final readback")
    need(all(f["workFrame"] == f["logicalFrame"] and f["diagnostics"]["transportRecordedEngineFrame"] == f["engineFrame"] for f in observed), "Actual transport receipt differs")
    need(all(f["diagnostics"]["hardwareBackend"] and f["diagnostics"]["hardwareMeshes"] == 2 and f["diagnostics"]["hardwareFallbacks"] == 1 and f["diagnostics"]["publishedInstances"] == 3 and f["diagnostics"]["lightSelected"] == 0 for f in observed), "Actual backend/source composition differs")
    values = np.array([rgba(f["points"]) for f in observed])
    need(values.shape == (len(observed), 27, 4) and np.isfinite(values).all(), "Missing/nonfinite fixed point")
    baseline = values[0, :, :3]
    dominant = 1 if expected_lane == "GreenToBlue" else 2
    need(np.max(np.abs(baseline[:, [i for i in range(3) if i != dominant]])) <= 1e-6 and np.all(baseline[:, dominant] > 0), "Pre-event Final is not isolated expected color")
    capture_folder = folder / r["baselineDirectory"]
    receipt = load(capture_folder / "frame-0000-capture.json")
    need(receipt["status"] == "complete" and receipt["logicalFrame"] == 0, "Logical0 support capture incomplete")
    samples = {s["signalId"]: s for s in receipt["samples"]}
    support = {s["role"]: s for s in receipt["support"]}
    need((samples["filteredD"]["width"], samples["filteredD"]["height"]) == (480, 270), "Actual GI dimensions differ")
    px, py = points.T
    before = plane(capture_folder, samples["cameraBeforeHLGI"])[py, px]
    material = plane(capture_folder, support["material"])[py, px]
    depth = plane(capture_folder, support["depth"])[py, px, 0]
    need(np.isfinite(before).all() and np.max(np.abs(before[:, :3])) <= 1e-6, "Native camera contribution is not black")
    need(np.max(np.abs(material[:, :3] - .96)) <= 2/255, "Fixed point is not the declared white diffuse receiver")
    camera = r["baselineCamera"]
    need(camera["matrixOrder"] == "row-major" and camera["rowOrder"] == "top-to-bottom" and camera["uvOrigin"] == "top-left" and camera["clipDepth"] == "zero-to-one", "Camera projection contract differs")
    view = np.array(camera["view"]).reshape(4, 4)
    projection = np.array(camera["projection"]).reshape(4, 4)
    clip = np.c_[(points + .5) / [960, 540] * 2 - 1, depth, np.ones(27)]
    clip[:, 1] *= -1  # Fixed Core ComputeClipSpacePosition / UNITY_UV_STARTS_AT_TOP.
    homogeneous = clip @ np.linalg.inv(projection @ view).T
    position = homogeneous[:, :3] / homogeneous[:, 3:]
    need(np.isfinite(position).all() and np.max(np.abs(position[:, 1])) <= 1e-3 and np.all((position[:, 0] > 0) & (position[:, 0] < 5) & (position[:, 2] > -3) & (position[:, 2] < 3)), "Fixed source pixel is not inside the floor plane")
    response = observed[1:]
    need(all(f["response"] for f in response) and all(f["inputEmission"]["x"] == f["inputEmission"]["y"] == 0 and f["inputEmission"]["z"] == 1 for f in response), "Response input is not fixed blue")
    times = np.array([f["elapsedSeconds"] for f in response])
    need(np.all(np.diff(times) > 0), "Nonmonotone source clock")
    info = dict(sourceFrames=len(response), sourceHz=float((len(times)-1)/(times[-1]-times[0])),
                intervalMedian=float(np.median(np.diff(times))), intervalP95=float(np.quantile(np.diff(times), .95)),
                intervalMax=float(np.max(np.diff(times))), lastElapsed=float(times[-1]),
                peakPending=r["peakPendingReadbacks"], prewarmEngineGap=r["earlyEngineGap"],
                prewarmSourceGap=r["earlySourceGap"], floorMaxAbsY=float(np.max(np.abs(position[:, 1]))),
                nativeMaxAbs=float(np.max(np.abs(before[:, :3]))),
                readbackLatencyMedian=float(np.median([f["completionSeconds"] - f["sourceSeconds"] for f in response])))
    return r, values[:, :, :3], times, info


def analyze(event_folder, control_folder, output):
    event, evalues, times, einfo = read_lane(event_folder, "GreenToBlue")
    control, cvalues, ctimes, cinfo = read_lane(control_folder, "BlueFromStart")
    need(event["finalLogical"] == control["finalLogical"] and event["selection"] == control["selection"], "Work-frame/pixel pairing differs")
    need(event["baselineCamera"] == control["baselineCamera"], "Matched camera differs")
    need(json.loads(event["settings"]) == json.loads(control["settings"]), "Full recorded settings differ")
    source_fields = ("panelPosition", "panelCenter", "panelSize", "cameraPosition", "cameraRotation",
                     "baseColor", "sharedEmission", "materialLayerMask", "panelLayer", "submeshes",
                     "readable", "forceRenderingOff", "hasSdf", "hasCharts", "readMaterialProperties",
                     "emissionKeyword", "materialGiFlags")
    need(all(event[k] == control[k] for k in source_fields), "Recorded fixed source inputs differ")
    ev, cv = evalues[1:], cvalues[1:]
    need(ev.shape == cv.shape, "Missing paired source")
    emean, cmean = ev.mean(1), cv.mean(1)
    ey, cy = emean @ Y, cmean @ Y
    need(np.all(cy > 1e-5) and np.all(emean.sum(1) > 0), "Nearzero mean invalidates normalized comparison")
    echroma = emean / emean.sum(1)[:, None]
    cchroma = cmean / cmean.sum(1)[:, None]
    control_y_range = float(np.ptp(cy) / cy.mean())
    control_chroma_range = float(np.max(np.abs(cchroma - cchroma[0]).sum(1)))
    control_ok = control_y_range <= .05 and control_chroma_range <= .025
    y_error = ey / cy - 1
    chroma_error = np.abs(echroma - cchroma).sum(1)
    good = (np.abs(y_error) <= .10) & (chroma_error <= .05)
    stable_windows = []
    for first in np.flatnonzero(times <= 2):
        end = np.searchsorted(times, times[first] + .5)
        if end >= len(times):
            continue
        selected = slice(first, end + 1)
        if np.all(good[selected]) and np.max(np.diff(times[selected])) <= 2/30 and np.max(np.diff(ctimes[selected])) <= 2/30:
            stable_windows.append(dict(firstLogical=int(first+120), lastLogical=int(end+120),
                                       start=float(times[first]), end=float(times[end]),
                                       span=float(times[end]-times[first]),
                                       maxAbsRelativeY=float(np.max(np.abs(y_error[selected]))),
                                       maxChromaL1=float(np.max(chroma_error[selected]))))
            break
    old_g = ev[:, :, 1].mean(1) / evalues[0, :, 1].mean()
    old_point_g = ev[:, :, 1] / evalues[0, :, 1][None, :]
    def signal(index):
        return dict(logical=int(index+120), elapsed=float(times[index]), oldGreenMean=float(old_g[index]),
                    oldGreenWorstPoint=float(np.max(old_point_g[index])), relativeY=float(y_error[index]), chromaL1=float(chroma_error[index]))
    deadlines = {}
    for deadline in (1, 2):
        before = np.flatnonzero(times <= deadline)
        after = np.flatnonzero(times >= deadline)
        deadlines[str(deadline)] = dict(before=signal(before[-1]) if len(before) else None,
                                        after=signal(after[0]) if len(after) else None)
    state = "insufficient-control" if not control_ok else "satisfied-observed-recovery-window" if stable_windows else "not-observed-within-target"
    result = dict(status=state, fullFrozenInputVerified=False,
                  inputDescriptorDeviation="Frozen text called the wall white; retained executed source sets its MPB BaseColor to (.5,.25,.125,1). Adopt actual brown-wall/white-floor fixture metrics only; all-white-wall condition is unverified.",
                  quantity="linear Final HDR radiance at the same27 white-floor pixels; product-history comparison",
                  physicalReference=False, controlSufficient=bool(control_ok), controlRelativeYRange=control_y_range,
                  controlMaxChromaL1FromFirst=control_chroma_range, firstObservedRecoveryWindow=stable_windows[0] if stable_windows else None,
                  residualDeadlineSamples=deadlines, cadence=dict(GreenToBlue=einfo, BlueFromStart=cinfo),
                  final=signal(len(times)-1), pairedLogicalFrames=[120, event["finalLogical"]],
                  maximumPointAbsoluteRgbDifference=float(np.max(np.abs(ev-cv))),
                  actualTimeAlignmentMaxDifference=float(np.max(np.abs(times-ctimes))))
    result["frames"] = [signal(i) for i in range(len(times))]
    np.savez_compressed(output / "signals.npz", event=evalues, control=cvalues, event_elapsed=times,
                        control_elapsed=ctimes, points=np.array([p["full"] for p in event["selection"]["points"]]))
    return result


def main():
    p = argparse.ArgumentParser()
    p.add_argument("event", type=Path)
    p.add_argument("control", type=Path)
    p.add_argument("output", type=Path)
    args = p.parse_args()
    args.output.mkdir(parents=True, exist_ok=False)
    try:
        result = analyze(args.event, args.control, args.output)
    except (ValueError, KeyError, IndexError, OSError) as error:
        result = dict(status="insufficient-input-or-record", error=str(error))
    (args.output / "result.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({k: v for k, v in result.items() if k != "frames"}, ensure_ascii=False))


if __name__ == "__main__":
    main()
