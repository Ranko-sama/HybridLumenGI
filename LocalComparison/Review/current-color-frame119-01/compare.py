"""Read existing frame119 captures and reference; no hashing or integration.

Only Floor/White source ROIs are quantified. This produces a comparison, not a
quality verdict. Run only after the owner confirms capture completion.
"""
import argparse
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw


HERE = Path(__file__).resolve().parent
SIGNALS = Path("I:/Unity test/Comparison/Release81ColorFrame119/signals")
OLD = Path("I:/Unity test/Comparison/ValidationPackageV209/capture/20261029-153518-90ad50e68d454b52b48135246a18dfa5")
REFERENCE = Path("I:/Unity test/Comparison/ValidationPackageV209-reference-frame0119-01")
Y = np.array([.2126, .7152, .0722], dtype=np.float64)
NAMES = ("Floor", "White receiver")
QUANTITY = "indirect-irradiance-over-pi"
WIDTH, HEIGHT = 320, 180


def read_json(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def require(condition, reason):
    if not condition:
        raise ValueError(reason)


def linked(root, filename):
    path = (root / filename).resolve()
    require(path.is_relative_to(root.resolve()), "Input file escapes its capture directory")
    return path


def unique(rows, key, value):
    found = [row for row in rows if row.get(key) == value]
    require(len(found) == 1, "Expected one " + value + " entry")
    return found[0]


def rgba(path, width, height):
    values = np.fromfile(path, dtype="<f4")
    require(values.size == width * height * 4, "Unexpected RGBA32F length: " + str(path))
    return values.reshape(height, width, 4).astype(np.float64)


def mask(path, width, height):
    values = np.fromfile(path, dtype="u1")
    require(values.size == width * height, "Unexpected validity length: " + str(path))
    return values.reshape(height, width) > 0


def capture_sample(receipt):
    require(receipt.get("status") == "complete" and not receipt.get("error"), "Capture did not complete")
    require(receipt.get("logicalFrame") == 119 and receipt.get("readbacksCompleted") is True,
            "Frame119 readback is incomplete")
    sample = unique(receipt.get("samples", []), "signalId", "filteredD")
    require(sample.get("status") == "available", "filteredD is unavailable")
    require((sample.get("width"), sample.get("height")) == (WIDTH, HEIGHT), "filteredD must be 320x180")
    require(sample.get("quantity") == QUANTITY, "filteredD quantity differs")
    require(sample.get("format") == "rgba32f-le" and sample.get("rowOrder") == "top-to-bottom",
            "filteredD format/row convention differs")
    return sample


def material_input(root, receipt):
    support = unique(receipt.get("support", []), "role", "material")
    require((support.get("width"), support.get("height")) == (640, 360), "Material support must be 640x360")
    require(support.get("format") == "rgba32f-le" and support.get("rowOrder") == "top-to-bottom",
            "Material support format/row convention differs")
    values = rgba(linked(root, support["file"]), 640, 360)
    valid = mask(linked(root, support["validity"]["file"]), 640, 360)
    return support, values[1::2, 1::2], valid[1::2, 1::2]


def preview(rgb):
    value = np.maximum(rgb, 0)
    value = value / (1 + value)
    value = np.where(value <= .0031308, value * 12.92, 1.055 * value ** (1 / 2.4) - .055)
    return np.uint8(np.clip(value, 0, 1) * 255)


def save_panel(path, current, reference, se, region, valid):
    yy, xx = np.indices((HEIGHT, WIDTH))
    checker = np.repeat(np.uint8(80 + ((xx // 6 + yy // 6) % 2) * 35)[:, :, None], 3, axis=2)
    # Values outside the display domain have no role in the image or statistics.
    a = np.where((region & valid)[:, :, None], current, 0)
    b = np.where(region[:, :, None], reference, 0)
    uncertainty_rgb = np.where(region[:, :, None], se, 0)
    actual_preview, reference_preview = preview(a), preview(b)
    difference = (a - b) @ Y
    level = np.clip(np.abs(difference) / .05, 0, 1)
    heat = np.zeros((HEIGHT, WIDTH, 3), dtype=np.uint8)
    heat[:, :, 0] = np.where(difference >= 0, 255 * level, 0)
    heat[:, :, 2] = np.where(difference < 0, 255 * level, 0)
    error = np.clip((uncertainty_rgb @ Y) / .05, 0, 1)
    uncertainty = np.uint8(np.stack([error, error * .6, np.zeros_like(error)], axis=-1) * 255)
    for tile in (actual_preview, reference_preview, heat, uncertainty):
        tile[~region] = checker[~region]
    for tile in (actual_preview, heat):
        tile[region & ~valid] = [255, 0, 255]
    sheet = Image.new("RGB", (1280, 230), (22, 22, 27))
    draw = ImageDraw.Draw(sheet)
    panels = [(actual_preview, "Current filteredD, frame 119"),
              (reference_preview, "Existing independent MC D, 256 spp"),
              (heat, "Delta Y: red + / blue -, scale 0.05"),
              (uncertainty, "Reference pixel SE, scale 0.05")]
    for i, (tile, title) in enumerate(panels):
        sheet.paste(Image.fromarray(tile).transpose(Image.Transpose.FLIP_TOP_BOTTOM), (i * WIDTH, 25))
        draw.text((i * WIDTH + 5, 5), title, fill="white")
    draw.text((5, 208), "Floor/White only. Exposure 1, Reinhard+sRGB. Gray=outside source ROI; magenta=current unknown. SE is not model bias or ROI CI.", fill="white")
    sheet.save(path)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--signals", type=Path, default=SIGNALS)
    parser.add_argument("--output", type=Path, default=HERE)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    json_path, png_path = args.output / "comparison.json", args.output / "comparison.png"
    require(not json_path.exists() and not png_path.exists(), "Comparison output already exists; first result is retained")
    result = dict(status="checking-inputs", qualityVerdict=None,
                  currentDirectory=str(args.signals), oldCaptureDirectory=str(OLD), referenceDirectory=str(REFERENCE),
                  logicalFrame=119, quantity=QUANTITY, roiNames=list(NAMES),
                  scope="Existing approximate CPU reference versus current filteredD. Saved-scene reuse is supplied by the run; this script only checks the listed capture inputs, not a new physical-source archive.",
                  metadataChecks={}, materialChecks={},
                  uncertainty="Mean per-pixel RGB SE and conservative luma SE over paired pixels; not an ROI confidence interval. Model differences remain.",
                  display=dict(exposure=1, tonemap="Reinhard then sRGB", deltaYScale=.05, standardErrorScale=.05,
                               transform="PNG vertical flip only; original numeric rows unchanged",
                               gray="outside independent Floor/White receiver ROI", magenta="current unknown in that ROI"))
    try:
        current_receipt = read_json(args.signals / "frame-0119-capture.json")
        old_receipt = read_json(OLD / "frame-0119-capture.json")
        current_sample, old_sample = capture_sample(current_receipt), capture_sample(old_receipt)
        ref_report = read_json(REFERENCE / "report.json")
        require(ref_report.get("quantity") == QUANTITY and ref_report.get("logicalFrame") == 119 and
                (ref_report.get("width"), ref_report.get("height")) == (WIDTH, HEIGHT), "Reference quantity/frame/dimensions differ")
        require(ref_report.get("rowOrder") == "top-to-bottom", "Reference row convention differs")
        result["modelDifferences"] = ref_report["modelDifferences"]
        result["captureFormat"] = dict(currentSourceFormat=current_sample.get("sourceFormat"),
                                       oldSourceFormat=old_sample.get("sourceFormat"),
                                       storedFormat=current_sample["format"], encoding=current_sample.get("encoding"),
                                       reference="Source float64 geometry/MC computation, stored RGBA32F")
        require(current_sample.get("sourceFormat") == old_sample.get("sourceFormat") == "R16G16B16A16_SFloat",
                "Expected the existing RGBA16F filteredD capture converted to RGBA32F")
        for key in ("invVP", "giSize", "intensity"):
            old_value = old_receipt["composite"][key]
            current_value = current_receipt["composite"][key]
            values = list(current_value.values()) if isinstance(current_value, dict) else [current_value]
            same = current_value == old_value and bool(np.isfinite(np.asarray(values, dtype=float)).all())
            result["metadataChecks"][key] = dict(same=same, old=old_value, current=current_value)
            require(same, "Current/old composite " + key + " differs or is nonfinite")
        require(current_receipt["composite"]["giSize"] == {"x": WIDTH, "y": HEIGHT}, "Unexpected GI size")
        result["debugDifferenceIgnoredForD"] = dict(old=old_receipt["composite"].get("debug"),
                                                   current=current_receipt["composite"].get("debug"))

        index = read_json(REFERENCE / "geometry-index.json")
        names = [row["name"] for row in index["objects"]]
        with np.load(REFERENCE / "primary.npz", allow_pickle=False) as primary:
            owners = primary["owner"].copy()
            pixels = primary["sampledFullPixel"].copy()
        domain = mask(REFERENCE / "validity.u8", WIDTH, HEIGHT)
        yy, xx = np.indices((HEIGHT, WIDTH))
        expected_pixels = np.stack([2 * xx + 1, 2 * yy + 1], axis=-1)
        require(owners.shape == (HEIGHT, WIDTH) and np.array_equal(pixels, expected_pixels),
                "Independent owner grid/full-pixel mapping differs")
        rois = {}
        for name in NAMES:
            require(names.count(name) == 1, "Independent owner is ambiguous: " + name)
            rois[name] = domain & (owners == names.index(name))
            require(bool(rois[name].any()), "Independent ROI is empty: " + name)
        comparison_region = rois[NAMES[0]] | rois[NAMES[1]]

        cur_support, cur_material, cur_material_valid = material_input(args.signals, current_receipt)
        old_support, old_material, old_material_valid = material_input(OLD, old_receipt)
        result["materialSampling"] = "Source ROI full pixels (2*x+1,2*y+1); captured material RGB/AO, no resampling"
        result["materialSourceFormats"] = dict(current=cur_support.get("sourceFormat"), old=old_support.get("sourceFormat"))
        for name, region in rois.items():
            qualified = (cur_material_valid & old_material_valid &
                         np.isfinite(cur_material).all(axis=2) & np.isfinite(old_material).all(axis=2))
            require(bool(qualified[region].all()), "Invalid material support in source ROI: " + name)
            max_difference = np.abs(cur_material[region] - old_material[region]).max(axis=0)
            same = bool(np.array_equal(cur_material[region], old_material[region]))
            result["materialChecks"][name] = dict(sourcePixels=int(region.sum()), same=same,
                                                  maxAbsoluteDifferenceRGBA=max_difference.tolist())
        require(all(row["same"] for row in result["materialChecks"].values()), "Current/old ROI diffuse RGB or AO differs")

        current = rgba(linked(args.signals, current_sample["data"]["file"]), WIDTH, HEIGHT)
        valid = mask(linked(args.signals, current_sample["validity"]["file"]), WIDTH, HEIGHT)
        require(bool(np.isfinite(current[valid]).all()), "A current valid measurement is nonfinite")
        reference = rgba(REFERENCE / "filteredD.rgba32f", WIDTH, HEIGHT)[:, :, :3]
        with np.load(REFERENCE / "statistics.npz", allow_pickle=False) as statistics:
            stderr = statistics["standardErrorRgb"].reshape(HEIGHT, WIDTH, 3).astype(np.float64)
        require(bool(np.isfinite(reference[comparison_region]).all()) and
                bool(np.isfinite(stderr[comparison_region]).all()) and bool((stderr[comparison_region] >= 0).all()),
                "Reference RGB/SE is invalid in the source ROI")
        current = current[:, :, :3]
        rows = {}
        for name, region in rois.items():
            paired = region & valid
            row = dict(sourcePixels=int(region.sum()), pairedPixels=int(paired.sum()),
                       unknownPixels=int((region & ~valid).sum()), metrics=None)
            if paired.any():
                actual_rgb = current[paired].mean(axis=0)
                ref_rgb = reference[paired].mean(axis=0)
                delta_rgb = actual_rgb - ref_rgb
                ref_y, actual_y = float(ref_rgb @ Y), float(actual_rgb @ Y)
                chroma = float(np.abs(actual_rgb / actual_rgb.sum() - ref_rgb / ref_rgb.sum()).sum()) \
                    if actual_rgb.sum() > 0 and ref_rgb.sum() > 0 else None
                row["metrics"] = dict(candidateMeanRGB=actual_rgb.tolist(), referenceMeanRGB=ref_rgb.tolist(),
                                      meanBiasRGB=delta_rgb.tolist(), candidateMeanY=actual_y, referenceMeanY=ref_y,
                                      meanBiasY=actual_y - ref_y, relativeMeanBiasY=(actual_y - ref_y) / ref_y if ref_y > 0 else None,
                                      meanChromaL1=chroma, meanPixelStandardErrorRGB=stderr[paired].mean(axis=0).tolist(),
                                      meanPixelConservativeLumaSE=float((stderr[paired] @ Y).mean()))
            rows[name] = row
        save_panel(png_path, current, reference, stderr, comparison_region, valid)
        result.update(status="comparison-produced", roi=rows, image=str(png_path),
                      metricBasis="Only current-valid pixels inside each independent source ROI. Chroma L1 compares normalized ROI mean RGB. Unknown is not black; no threshold or statistical test.")
    except (ValueError, KeyError, OSError, TypeError) as error:
        result.update(status="stopped-incomparable", reason=str(error))
        result.pop("roi", None)
    json_path.write_text(json.dumps(result, indent=2, allow_nan=False) + "\n", encoding="utf-8")
    print(str(json_path))
    if result["status"] != "comparison-produced":
        raise SystemExit(2)


if __name__ == "__main__":
    main()
