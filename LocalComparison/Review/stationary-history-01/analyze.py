"""One read-only comparison of the five predeclared captures; run after capture.

No hashes, integration, source reconstruction, statistical tests or adoption
verdict. The unchanged current-color utility supplies only file/preview helpers.
"""
import argparse
import importlib.util
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
HELPER = HERE.parent / "current-color-frame119-01/compare.py"
spec = importlib.util.spec_from_file_location("existing_color_helpers", HELPER)
common = importlib.util.module_from_spec(spec)
spec.loader.exec_module(common)
load, require, unique = common.read_json, common.require, common.unique
rgba, mask, linked, preview = common.rgba, common.mask, common.linked, common.preview
Y, NAMES, W, H, QUANTITY = common.Y, common.NAMES, common.WIDTH, common.HEIGHT, common.QUANTITY
CANDIDATE = Path("I:/Unity test/Comparison/StationaryHistory01/signals")
BASELINE = Path("I:/Unity test/Comparison/Release81ColorFrame119/signals")
OLD = common.OLD
REFS = {119: common.REFERENCE,
        299: Path("I:/Unity test/Comparison/ValidationPackageV209-reference-frame0299-02")}
FRAMES = (119, 239, 240, 270, 299)


def reference_inputs(frame):
    directory = REFS[frame]
    report = load(directory / "report.json")
    require(report.get("logicalFrame") == frame and report.get("quantity") == QUANTITY and
            (report.get("width"), report.get("height")) == (W, H) and
            report.get("rowOrder") == "top-to-bottom", "Reference descriptor differs")
    names = [row["name"] for row in load(directory / "geometry-index.json")["objects"]]
    with np.load(directory / "primary.npz", allow_pickle=False) as primary:
        owners, pixels = primary["owner"].copy(), primary["sampledFullPixel"].copy()
    yy, xx = np.indices((H, W))
    require(owners.shape == (H, W) and np.array_equal(pixels, np.stack([2 * xx + 1, 2 * yy + 1], -1)),
            "Independent primary sample grid differs")
    domain = mask(directory / "validity.u8", W, H)
    rois = {}
    for name in NAMES:
        require(names.count(name) == 1, "Ambiguous source owner: " + name)
        rois[name] = domain & (owners == names.index(name))
        require(bool(rois[name].any()), "Empty source ROI: " + name)
    return dict(directory=directory, report=report, rois=rois)


def input_gate(directory, frame, reference, audit):
    receipt = load(directory / f"frame-{frame:04}-capture.json")
    old_frame = 119 if frame in (119, 239) else 299
    old = load(OLD / f"frame-{old_frame:04}-capture.json")
    for item, expected in ((receipt, frame), (old, old_frame)):
        require(item.get("logicalFrame") == expected and item.get("status") == "complete" and
                not item.get("error") and item.get("readbacksCompleted") is True,
                f"Incomplete capture receipt: frame {expected}")
    sample = unique(receipt["samples"], "signalId", "filteredD")
    require(sample.get("status") == "available" and sample.get("quantity") == QUANTITY and
            (sample.get("width"), sample.get("height")) == (W, H) and
            sample.get("format") == "rgba32f-le" and sample.get("rowOrder") == "top-to-bottom" and
            sample.get("sourceFormat") == "R16G16B16A16_SFloat", "filteredD descriptor differs")
    audit.update(directory=str(directory), frame=frame, oldCaptureFrame=old_frame,
                 sourceFormat=sample["sourceFormat"], storedFormat=sample["format"],
                 encoding=sample.get("encoding"), metadata={}, materials={})
    for key in ("invVP", "giSize", "intensity"):
        current, previous = receipt["composite"][key], old["composite"][key]
        values = list(current.values()) if isinstance(current, dict) else [current]
        same = current == previous and bool(np.isfinite(np.asarray(values, dtype=float)).all())
        audit["metadata"][key] = dict(same=same, current=current, old=previous)
        require(same, f"Frame {frame} {key} differs from old physical capture")
    require(receipt["composite"]["giSize"] == {"x": W, "y": H}, "GI grid differs")
    audit["debugIgnoredForD"] = dict(current=receipt["composite"].get("debug"), old=old["composite"].get("debug"))
    cur_info, cur_material, cur_valid = common.material_input(directory, receipt)
    old_info, old_material, old_valid = common.material_input(OLD, old)
    audit["materialSourceFormats"] = dict(current=cur_info.get("sourceFormat"), old=old_info.get("sourceFormat"))
    for name, region in reference["rois"].items():
        finite = np.isfinite(cur_material).all(-1) & np.isfinite(old_material).all(-1)
        require(bool((cur_valid & old_valid & finite)[region].all()), f"Frame {frame}: invalid {name} material support")
        same = bool(np.array_equal(cur_material[region], old_material[region]))
        audit["materials"][name] = dict(same=same, sourcePixels=int(region.sum()),
            maxAbsoluteDifferenceRGBA=np.abs(cur_material[region] - old_material[region]).max(0).tolist())
    require(all(row["same"] for row in audit["materials"].values()), f"Frame {frame}: material RGB/AO differs")
    return directory, receipt, sample


def read_measurements(inputs):
    directory, receipt, sample = inputs
    values = rgba(linked(directory, sample["data"]["file"]), W, H)
    valid = mask(linked(directory, sample["validity"]["file"]), W, H)
    require(bool(np.isfinite(values[valid]).all()), "Nonfinite valid filteredD")
    support = unique(receipt["support"], "role", "moments")
    require((support.get("width"), support.get("height")) == (W, H) and
            support.get("format") == "rgba32f-le" and support.get("rowOrder") == "top-to-bottom",
            "Moments descriptor differs")
    moments = rgba(linked(directory, support["file"]), W, H)
    moment_valid = mask(linked(directory, support["validity"]["file"]), W, H)
    require(bool((moment_valid & np.isfinite(moments).all(-1))[valid].all()), "Invalid moments for a valid filteredD measurement")
    return dict(rgb=values[:, :, :3], valid=valid, moments= moments[:, :, 0])


def read_reference(reference):
    rgb = rgba(reference["directory"] / "filteredD.rgba32f", W, H)[:, :, :3]
    with np.load(reference["directory"] / "statistics.npz", allow_pickle=False) as statistics:
        se = statistics["standardErrorRgb"].reshape(H, W, 3).astype(np.float64)
    region = reference["rois"][NAMES[0]] | reference["rois"][NAMES[1]]
    require(bool(np.isfinite(rgb[region]).all()) and bool(np.isfinite(se[region]).all()) and
            bool((se[region] >= 0).all()), "Invalid reference RGB/SE")
    reference.update(rgb=rgb, se=se)


def measures(data, reference, selected):
    if not selected.any():
        return None
    a, b = data["rgb"][selected], reference["rgb"][selected]
    actual, expected = a.mean(0), b.mean(0)
    delta_y = (a - b) @ Y
    bias = float(delta_y.mean())
    chroma = float(np.abs(actual / actual.sum() - expected / expected.sum()).sum()) \
        if actual.sum() > 0 and expected.sum() > 0 else None
    return dict(meanRGB=actual.tolist(), meanY=float(actual @ Y), referenceMeanRGB=expected.tolist(),
                meanBiasRGB=(actual - expected).tolist(), absoluteMeanBiasRGB=np.abs(actual - expected).tolist(),
                referenceMeanY=float(expected @ Y), meanBiasY=bias, absoluteMeanBiasY=abs(bias),
                relativeMeanBiasY=bias / float(expected @ Y) if expected @ Y > 0 else None,
                pixelYMAE=float(np.abs(delta_y).mean()), pixelYRMSE=float(np.sqrt(np.mean(delta_y * delta_y))),
                meanChromaL1=chroma, meanMomentsX=float(data["moments"][selected].mean()),
                referenceMeanPixelStandardErrorRGB=reference["se"][selected].mean(0).tolist(),
                referenceMeanPixelConservativeLumaSE=float((reference["se"][selected] @ Y).mean()))


def tile(rgb, region, valid):
    safe = np.where((region & valid)[:, :, None], rgb, 0)
    image = preview(safe)
    yy, xx = np.indices((H, W))
    checker = np.repeat(np.uint8(80 + ((xx // 6 + yy // 6) % 2) * 35)[:, :, None], 3, -1)
    image[~region] = checker[~region]
    image[region & ~valid] = [255, 0, 255]
    return Image.fromarray(image).transpose(Image.Transpose.FLIP_TOP_BOTTOM)


def panel(path, baseline, frames, refs):
    on = refs[119]["rois"][NAMES[0]] | refs[119]["rois"][NAMES[1]]
    off = refs[299]["rois"][NAMES[0]] | refs[299]["rois"][NAMES[1]]
    full_valid = np.ones((H, W), dtype=bool)
    rows = [
        [(baseline["rgb"], on, baseline["valid"], "Baseline D 119"),
         (frames[119]["rgb"], on, frames[119]["valid"], "Candidate D 119"),
         (refs[119]["rgb"], on, full_valid, "Independent MC D 119")],
        [(frames[239]["rgb"], on, frames[239]["valid"], "Candidate D 239, before lights off"),
         (frames[299]["rgb"], off, frames[299]["valid"], "Candidate D 299"),
         (refs[299]["rgb"], off, full_valid, "Independent MC D 299")],
        [(frames[f]["rgb"], off, frames[f]["valid"], f"Candidate D {f}") for f in (240, 270, 299)],
    ]
    sheet = Image.new("RGB", (W * 3, 675), (22, 22, 27))
    draw = ImageDraw.Draw(sheet)
    for row_index, columns in enumerate(rows):
        y = row_index * 205
        for col, (rgb, region, valid, title) in enumerate(columns):
            draw.text((col * W + 5, y + 5), title, fill="white")
            sheet.paste(tile(rgb, region, valid), (col * W, y + 25))
    draw.text((5, 623), "All D: exposure 1, Reinhard+sRGB; PNG vertical flip only. Gray=outside Floor/White; magenta=unknown.", fill="white")
    draw.text((5, 642), "Only 119/299 have independent references. Late-frame change is not convergence or measured residual error.", fill="white")
    sheet.save(path)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--signals", type=Path, default=CANDIDATE)
    parser.add_argument("--output", type=Path, default=HERE)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    output, image = args.output / "comparison.json", args.output / "comparison.png"
    require(not output.exists() and not image.exists(), "First comparison output already exists; refusing overwrite")
    result = dict(status="checking-inputs", adoption="pending", visualReview="pending", qualityVerdict=None,
                  decisionFile=str(HERE / "decision.md"), helperFile=str(HELPER),
                  candidateDirectory=str(args.signals), baselineDirectory=str(BASELINE), oldPhysicalCapture=str(OLD),
                  quantity=QUANTITY, frameSet=list(FRAMES), inputChecks={}, references={},
                  scope="Fixed source-only Floor/White ROIs. Capture invVP/GI size/intensity/material matching only; no new physical-source qualification. No historical Release78 exact A/B or performance claim.",
                  uncertainty="Monte Carlo per-pixel SE means are not ROI confidence intervals. Existing reference model differences and finite depth remain.",
                  momentsMeaning="moments.x is the stored raw-luminance temporal statistic, not independent truth or unfiltered-history RGB.")
    try:
        refs = {f: reference_inputs(f) for f in (119, 299)}
        for f, ref in refs.items():
            result["references"][str(f)] = dict(directory=str(ref["directory"]), spp=ref["report"]["spp"],
                maxDepth=ref["report"]["maxDepth"], modelDifferences=ref["report"]["modelDifferences"],
                computation="Source float64 geometry/MC; stored RGBA32F", strictAbsoluteErrorCertificate=False)
        baseline_audit = result["inputChecks"]["baseline119"] = {}
        baseline_input = input_gate(BASELINE, 119, refs[119], baseline_audit)
        inputs = {}
        for frame in FRAMES:
            audit = result["inputChecks"][str(frame)] = {}
            inputs[frame] = input_gate(args.signals, frame, refs[119 if frame in (119, 239) else 299], audit)
        # All metadata/material checks finish before reading radiance for metrics.
        baseline = read_measurements(baseline_input)
        frames = {f: read_measurements(inputs[f]) for f in FRAMES}
        for reference in refs.values():
            read_reference(reference)
        comparison119, conditions = {}, {}
        for name, region in refs[119]["rois"].items():
            baseline_domain = region & baseline["valid"]
            paired = baseline_domain & frames[119]["valid"]
            lost = int((baseline_domain & ~frames[119]["valid"]).sum())
            a, b = measures(baseline, refs[119], paired), measures(frames[119], refs[119], paired)
            comparison119[name] = dict(sourcePixels=int(region.sum()), fixedBaselineDomainPixels=int(baseline_domain.sum()),
                pairedPixels=int(paired.sum()), baselineUnknownPixels=int((region & ~baseline["valid"]).sum()),
                candidateUnknownPixels=int((region & ~frames[119]["valid"]).sum()), newlyUnknownOnBaselineDomain=lost,
                baseline=a, candidate=b,
                cohort="Baseline-known source ROI, paired with candidate. Any lost baseline point makes numerical conditions unmet; newly known points do not change this comparison cohort.")
            available = a is not None and b is not None
            conditions[name] = dict(noNewUnknownPoints=lost == 0 and int(baseline_domain.sum()) > 0,
                lowerAbsoluteMeanYBias=available and b["absoluteMeanBiasY"] < a["absoluteMeanBiasY"],
                lowerPixelYMAE=available and b["pixelYMAE"] < a["pixelYMAE"],
                chromaL1NotWorse=available and a["meanChromaL1"] is not None and b["meanChromaL1"] is not None and
                    b["meanChromaL1"] <= a["meanChromaL1"])
        result["comparison119"] = comparison119
        result["predeclaredNumericalConditions119"] = conditions
        result["numericalScreen119"] = "met" if all(all(row.values()) for row in conditions.values()) else "not-met"
        result["comparison299"] = {}
        for name, region in refs[299]["rois"].items():
            paired = region & frames[299]["valid"]
            result["comparison299"][name] = dict(sourcePixels=int(region.sum()), pairedPixels=int(paired.sum()),
                unknownPixels=int((region & ~frames[299]["valid"]).sum()), candidate=measures(frames[299], refs[299], paired))
        result["frameObservations"] = {}
        for frame in FRAMES:
            ref = refs[119 if frame in (119, 239) else 299]
            result["frameObservations"][str(frame)] = {}
            for name, region in ref["rois"].items():
                selected = region & frames[frame]["valid"]
                values = frames[frame]["rgb"][selected]
                result["frameObservations"][str(frame)][name] = dict(sourcePixels=int(region.sum()),
                    validPixels=int(selected.sum()), unknownPixels=int((region & ~frames[frame]["valid"]).sum()),
                    meanRGB=values.mean(0).tolist() if selected.any() else None,
                    meanY=float((values @ Y).mean()) if selected.any() else None,
                    meanMomentsX=float(frames[frame]["moments"][selected].mean()) if selected.any() else None)
        result["intervalChanges"] = []
        for first, last in ((239, 240), (240, 270), (270, 299), (240, 299)):
            for name, region in refs[299]["rois"].items():
                selected = region & frames[first]["valid"] & frames[last]["valid"]
                delta = (frames[last]["rgb"][selected] - frames[first]["rgb"][selected]) @ Y
                result["intervalChanges"].append(dict(first=first, last=last, roi=name,
                    sourcePixels=int(region.sum()), pairedPixels=int(selected.sum()),
                    firstUnknownPixels=int((region & ~frames[first]["valid"]).sum()),
                    lastUnknownPixels=int((region & ~frames[last]["valid"]).sum()),
                    meanSignedDeltaY=float(delta.mean()) if selected.any() else None,
                    meanAbsoluteDeltaY=float(np.abs(delta).mean()) if selected.any() else None,
                    rmsDeltaY=float(np.sqrt(np.mean(delta * delta))) if selected.any() else None))
        panel(image, baseline, frames, refs)
        result.update(status="comparison-produced", image=str(image),
            decisionBoundary="Numerical conditions are only decision.md item 3. Actual-body control result, unmarked-darkening behavior, visual artifacts and notified-event response remain main-thread decisions. No automatic adoption or convergence verdict.",
            display="Exposure 1 / Reinhard+sRGB for every radiance panel. Only PNG is vertically flipped; numeric rows are unchanged.")
    except (ValueError, KeyError, TypeError, OSError) as error:
        result.update(status="stopped-incomparable", reason=str(error), numericalScreen119="incomplete")
        for key in ("comparison119", "comparison299", "predeclaredNumericalConditions119", "frameObservations", "intervalChanges"):
            result.pop(key, None)
    output.write_text(json.dumps(result, indent=2, allow_nan=False) + "\n", encoding="utf-8")
    print(str(output))
    if result["status"] != "comparison-produced":
        raise SystemExit(2)


if __name__ == "__main__":
    main()
