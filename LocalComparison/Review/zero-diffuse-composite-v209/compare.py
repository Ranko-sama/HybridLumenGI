"""Compare the two zero-diffuse receivers in the existing V209 composition capture."""
import json
from pathlib import Path
import sys

import numpy as np
from PIL import Image, ImageDraw

here = Path(__file__).resolve().parent
sys.path.insert(0, str(here.parent / "dynamic-picture-comparison-01"))
from analyze import CAP, RECEIVER, display, image, load

reference = Path(load(here.parent / "dynamic-picture-comparison-01/reference-comparison-0119.json")["referenceDirectory"])
primary = np.load(reference / "primary.npz")
state = load(CAP / "states/frame-0119.json")["dynamicState"]
receipt = load(CAP / "frame-0119-capture.json")
assert receipt["status"] == "complete" and receipt["logicalFrame"] == 119
assert receipt["composite"]["debug"] == 0 and receipt["composite"]["composition"] == 0
before, after, material, emission, depth, capture_depth = (
    image(119, name) for name in ("cameraBeforeHLGI", "cameraAfterHLGI", "material", "emissionValidity", "depth", "captureDepth")
)
valid = np.ones(before.shape[:2], dtype=bool)
for name in ("cameraBeforeHLGI", "cameraAfterHLGI", "material", "emissionValidity", "depth", "captureDepth"):
    valid &= np.fromfile(CAP / f"frame-0119-{name}.validity.u8", dtype="u1").reshape(valid.shape) != 0
rows = {}
fig = Image.new("RGB", (680, 332), "#ededec")
draw = ImageDraw.Draw(fig)
for j, name in enumerate(("Metal zero diffuse receiver", "Black zero diffuse receiver")):
    owner = next(i for i, g in enumerate(state["geometry"]) if g["name"] == name)
    key, = state["geometry"][owner]["materialKeys"]
    source = next(m for m in state["materials"] if m["key"] == key)
    values = {p["name"]: p["value"] for p in source["properties"] if p["name"] in ("_Metallic", "_BaseColor", "_WorkflowMode")}
    selected = (primary["owner"] == owner) & (primary["classification"] == RECEIVER)
    x, y = primary["sampledFullPixel"][selected].T
    eligible = valid[y, x] & (np.abs(emission[y, x, 3]) > .5)
    u, v = x[eligible], y[eligible]
    a, b = before[v, u, :3], after[v, u, :3]
    rows[name] = dict(sourceMaterial=values, interiorPoints=len(x), pairedPoints=len(a),
        nonzeroBeforePixels=int(np.any(a != 0, axis=1).sum()), changedRgbPixels=int(np.any(a != b, axis=1).sum()),
        minChannelBefore=float(a.min()), maxChannelBefore=float(a.max()), maxAbsRgbDifference=float(np.abs(b-a).max()),
        maxCapturedDiffuse=float(material[v,u,:3].max()), maxSceneCaptureDepthDifference=float(np.abs(depth[v,u,0]-capture_depth[v,u,0]).max()),
        maxSourceDeviceDepthDifference=float(np.abs(depth[v,u,0]-primary["deviceDepth"][selected][eligible]).max()))
    # Full camera crops for context; the third tile marks exactly the paired samples.
    x0, x1, y0, y1 = x.min()-4, x.max()+5, y.min()-4, y.max()+5
    mask = np.zeros((y1-y0,x1-x0,3), dtype=np.uint8)
    mask[v-y0,u-x0] = (40,174,147)
    crops = (display(before[y0:y1,x0:x1,:3]), display(after[y0:y1,x0:x1,:3]), Image.fromarray(mask))
    draw.text((10, j*160+5), name, fill="#182922")
    for i, (tile, title) in enumerate(zip(crops, ("Before HLGI", "After HLGI", "Paired samples"))):
        tile = tile.transpose(Image.Transpose.FLIP_TOP_BOTTOM).resize((tile.width*3,tile.height*3), Image.Resampling.NEAREST)
        tile.thumbnail((212,105), Image.Resampling.NEAREST)
        fig.paste(tile, (10+i*225, j*160+28))
        draw.text((10+i*225,j*160+137), title, fill="#182922")
fig.save(here / "comparison.png")
result = dict(capture=str(CAP), referenceGeometry=str(reference), frame=119, engineFrame=receipt["engineFrame"],
    workFrame=receipt["workFrame"], mode="Final / Additive", rows=rows,
    otherImageChangeObserved=bool(np.any(after[valid,:3] != before[valid,:3])))
(here / "result.json").write_text(json.dumps(result, indent=2)+"\n", encoding="utf-8")
print(json.dumps(result, ensure_ascii=False))
