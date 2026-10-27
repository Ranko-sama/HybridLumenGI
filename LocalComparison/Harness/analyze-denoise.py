"""Compare saved Unity captures; never launches tests or modifies source captures."""
import argparse
import json
from pathlib import Path
import numpy as np

parser = argparse.ArgumentParser()
parser.add_argument("before", type=Path)
parser.add_argument("after", type=Path)
parser.add_argument("--output", required=True, type=Path)
args = parser.parse_args()
weights = np.array([.2126, .7152, .0722])

def read(path, width=640, height=360):
    return np.fromfile(path, dtype="<f4").reshape(height, width, 4)

def metrics(image, bounds):
    x0, y0, x1, y1 = bounds
    rgb = image[y0:y1, x0:x1, :3].astype(np.float64)
    luminance = rgb @ weights
    yy, xx = np.indices(luminance.shape)
    design = np.stack([np.ones(luminance.size), xx.ravel(), yy.ravel()], axis=1)
    plane = (design @ np.linalg.lstsq(design, luminance.ravel(), rcond=None)[0]).reshape(luminance.shape)
    high_frequency = luminance[1:-1, 1:-1] - .25 * (
        luminance[:-2, 1:-1] + luminance[2:, 1:-1] + luminance[1:-1, :-2] + luminance[1:-1, 2:])
    return dict(meanY=float(luminance.mean()), planeResidualRms=float(np.sqrt(np.mean((luminance-plane)**2))),
                neighborResidualRms=float(np.sqrt(np.mean(high_frequency**2))),
                finite=bool(np.isfinite(rgb).all()))

report = dict(before=str(args.before), after=str(args.after),
    scope="Saved linear HDR image statistics, not ground truth, temporal stability, or performance acceptance.", frames={})
read_json = lambda path: json.loads(path.read_text(encoding="utf-8-sig"))
report["featureSettingsMatch"] = read_json(args.before/"feature.json")["settings"] == read_json(args.after/"feature.json")["settings"]
assert report["featureSettingsMatch"], "Comparison settings differ"
for frame in [119, 179, 239, 299, 419, 719]:
    name = f"frame-{frame:04d}.rgba32f"
    if not (args.before/name).exists() or not (args.after/name).exists():
        continue
    before, after = read(args.before/name), read(args.after/name)
    info = dict(before=metrics(before, (0, 0, 640, 360)), after=metrics(after, (0, 0, 640, 360)),
                meanAbsRgbDifference=float(np.mean(np.abs(after[:,:,:3]-before[:,:,:3]))))
    state_before = read_json(args.before/f"frame-{frame:04d}.json")
    state_after = read_json(args.after/f"frame-{frame:04d}.json")
    info["sceneStateMatches"] = all(state_before[k] == state_after[k] for k in
        ("cameraPosition", "cameraRotation", "doorLocalPosition", "projection", "lights"))
    assert info["sceneStateMatches"], f"Scene state differs at frame {frame}"
    assert np.isfinite(before).all() and np.isfinite(after).all(), f"Nonfinite capture at frame {frame}"
    if frame == 179:
        # Fixed interior of the plain moving door; excludes silhouette, stripe
        # occluder, floor and contact boundary. Identical world pose in both runs.
        roi = (340, 144, 400, 250)
        info["doorRoi"] = dict(bounds=roi, before=metrics(before, roi), after=metrics(after, roi))
    prefix = f"denoise-{frame:04d}"
    if (args.before/f"{prefix}-history.rgba32f").exists() and (args.after/f"{prefix}-history.rgba32f").exists():
        history_before = read(args.before/f"{prefix}-history.rgba32f", 320, 180)
        history_after = read(args.after/f"{prefix}-history.rgba32f", 320, 180)
        info["unfilteredHistoryMaxAbsDifference"] = float(np.max(np.abs(history_after-history_before)))
        if frame == 179:
            for label, root in [("before", args.before), ("after", args.after)]:
                moments = read(root/f"{prefix}-moments.rgba32f", 320, 180)[72:125,170:200]
                variance = np.maximum(moments[:,:,1]-moments[:,:,0]**2, 0)
                info["doorRoi"][label].update(
                    historyOneFraction=float((moments[:,:,2]==1).mean()),
                    temporalVarianceMedian=float(np.median(variance)))
                if label == "after":
                    info["doorRoi"][label]["spatialVarianceMedian"] = float(np.median(moments[:,:,3]))
    report["frames"][frame] = info
args.output.parent.mkdir(parents=True, exist_ok=True)
args.output.write_text(json.dumps(report, indent=2), encoding="utf-8")
print(json.dumps(report, indent=2))
