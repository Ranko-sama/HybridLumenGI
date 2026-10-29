"""The one approved post-fix frame: history reuse and visual comparison only."""
import json
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
BASE = Path("I:/Unity test/Comparison/StationaryHistory01")
CANDIDATE = Path("I:/Unity test/Comparison/RigidPoseHistory01")
REFERENCE = Path("I:/Unity test/Comparison/ValidationPackageV209-reference-frame0119-01")


def read(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def inputs(folder):
    signals = folder / "signals"
    receipt = read(signals / "frame-0239-capture.json")
    assert receipt["logicalFrame"] == receipt["workFrame"] == 239
    assert receipt["status"] == "complete" and receipt["readbacksCompleted"] and not receipt["error"]
    assert receipt["retainedBytes"] == 0
    descriptor = next(x for x in receipt["support"] if x["role"] == "moments")
    assert (descriptor["width"], descriptor["height"], descriptor["format"], descriptor["rowOrder"]) == (320, 180, "rgba32f-le", "top-to-bottom")
    moments = np.fromfile(signals / descriptor["file"], dtype="<f4").reshape(180, 320, 4)
    sample = next(x for x in receipt["samples"] if x["signalId"] == "filteredD")
    assert sample["status"] == "available"
    known = np.fromfile(signals / sample["validity"]["file"], dtype=np.uint8).reshape(180, 320) > 0
    host = read(folder / "host-result.json")
    ordinary = Path(host["captureDirectory"]) / "frame-0239.json"
    frame = read(ordinary)
    assert frame["logicalFrame"] == 239 and frame["status"] == "captured" and not frame["error"]
    assert (frame["width"], frame["height"]) == (640, 360)
    outgoing = np.fromfile(ordinary.parent / frame["rawFile"], dtype="<f4").reshape(360, 640, 4)
    return receipt, moments, known, frame, outgoing, host


def display(rgba):
    rgb = np.maximum(rgba[:, :, :3], 0)
    linear = rgb / (1 + rgb)
    srgb = np.where(linear <= .0031308, 12.92 * linear, 1.055 * linear ** (1 / 2.4) - .055)
    return Image.fromarray(np.uint8(np.clip(srgb * 255 + .5, 0, 255))).transpose(Image.Transpose.FLIP_TOP_BOTTOM)


if any((HERE / name).exists() for name in ("comparison.json", "comparison.png")):
    raise RuntimeError("Preserve existing comparison")
old, new = inputs(BASE), inputs(CANDIDATE)
assert old[0]["composite"] == new[0]["composite"]
for field in ("cameraPosition", "cameraRotation", "doorLocalPosition", "reportedBackend"):
    assert old[3][field] == new[3][field]
names = [x["name"] for x in read(REFERENCE / "geometry-index.json")["objects"]]
with np.load(REFERENCE / "primary.npz", allow_pickle=False) as primary:
    region = primary["owner"] == names.index("Moving occluder")
result = dict(source="0181ef2", frame=239, pixels=int(region.sum()),
              scope="Normal product run, one moving-door time point. Reuse is not a proof of correct lighting, absence of ghosting, or convergence. No independent reference at239.",
              referenceGrid="Existing frame119 primary owner grid; camera unchanged and door returned to initial position at239.",
              visualReview="pending", adoption="pending", host=new[5])
for label, data in (("baseline", old), ("candidate", new)):
    lengths = data[1][:, :, 2][region]
    assert np.isfinite(lengths).all()
    result[label] = dict(known=int(data[2][region].sum()), reused=int((lengths > 1).sum()),
                         historyLengths={str(float(n)): int(c) for n, c in zip(*np.unique(lengths, return_counts=True))})
sheet = Image.new("RGB", (1280, 425), (22, 22, 27))
draw = ImageDraw.Draw(sheet)
for x, title, data in ((0, "Release82 / original frame239", old), (640, "0181ef2 / rigid pose fix / frame239", new)):
    draw.text((x + 8, 6), title, fill="white")
    sheet.paste(display(data[4]), (x, 27))
draw.text((8, 395), "Outgoing indirect contribution; exposure1, Reinhard+sRGB. One frame only; no reference error or no-ghosting claim.", fill="white")
sheet.save(HERE / "comparison.png")
(HERE / "comparison.json").write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
print(json.dumps(result, ensure_ascii=False, indent=2))
