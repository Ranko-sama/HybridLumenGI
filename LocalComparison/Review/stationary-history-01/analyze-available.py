"""Available-data supplement only; the original five-capture failure remains.

Uses unchanged analysis helpers and frame119 numerical conditions. Missing D240
is neither synthesized nor replaced by ordinary outgoing radiance.
"""
import importlib.util
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("stationary_existing_analysis", HERE / "analyze.py")
base = importlib.util.module_from_spec(spec)
spec.loader.exec_module(base)
NAMES, Y, W, H = base.NAMES, base.Y, base.W, base.H
FRAMES = (119, 239, 270, 299)
OUTGOING = Path("I:/Unity test/Comparison/StationaryHistory01/capture/20261029-230708-f1ff24abeb424690bf3dad7132d2c9b5")


def available_panel(path, baseline, frames, refs):
    on = refs[119]["rois"][NAMES[0]] | refs[119]["rois"][NAMES[1]]
    off = refs[299]["rois"][NAMES[0]] | refs[299]["rois"][NAMES[1]]
    valid_reference = np.ones((H, W), dtype=bool)
    rows = [
        [(baseline["rgb"], on, baseline["valid"], "Baseline D 119"),
         (frames[119]["rgb"], on, frames[119]["valid"], "Candidate D 119"),
         (refs[119]["rgb"], on, valid_reference, "Independent MC D 119")],
        [(frames[239]["rgb"], on, frames[239]["valid"], "Candidate D 239, before lights off"),
         (frames[299]["rgb"], off, frames[299]["valid"], "Candidate D 299"),
         (refs[299]["rgb"], off, valid_reference, "Independent MC D 299")],
        [None,
         (frames[270]["rgb"], off, frames[270]["valid"], "Candidate D 270"),
         (frames[299]["rgb"], off, frames[299]["valid"], "Candidate D 299")],
    ]
    sheet = Image.new("RGB", (W * 3, 695), (22, 22, 27))
    draw = ImageDraw.Draw(sheet)
    for row_index, columns in enumerate(rows):
        y = row_index * 205
        for col, item in enumerate(columns):
            if item is None:
                draw.text((col * W + 5, y + 5), "D 240 MISSING / CAPACITY", fill="#ffbb55")
                draw.text((col * W + 15, y + 75), "Capture byte budget exhausted.\nNo D value or interval inferred.\nOutgoing image is a different quantity.", fill="white")
                continue
            rgb, region, valid, title = item
            draw.text((col * W + 5, y + 5), title, fill="white")
            sheet.paste(base.tile(rgb, region, valid), (col * W, y + 25))
    draw.text((5, 623), "D panels: exposure 1, Reinhard+sRGB, display vertical flip only. Gray=outside Floor/White; magenta=unknown.", fill="white")
    draw.text((5, 642), "Only 119/299 have independent references. D240 is missing; the original five-capture contract did not pass.", fill="white")
    draw.text((5, 661), "Numerical conditions do not decide adoption. Visual artifacts, response and reference-model limits remain.", fill="white")
    sheet.save(path)


def outgoing_panel(path):
    sheet = Image.new("RGB", (1280, 820), (22, 22, 27))
    draw = ImageDraw.Draw(sheet)
    records = []
    for i, frame in enumerate((239, 240, 270, 299)):
        info = base.load(OUTGOING / f"frame-{frame:04}.json")
        base.require(info.get("logicalFrame") == frame and info.get("status") == "captured" and
                     not info.get("error") and (info.get("width"), info.get("height")) == (640, 360),
                     f"Ordinary outgoing capture {frame} is incomplete")
        raw_path = base.linked(OUTGOING, info["rawFile"])
        values = base.rgba(raw_path, 640, 360)
        base.require(bool(np.isfinite(values).all()), f"Nonfinite ordinary outgoing frame {frame}")
        tile = Image.fromarray(base.preview(values[:, :, :3])).transpose(Image.Transpose.FLIP_TOP_BOTTOM)
        x, y = (i % 2) * 640, (i // 2) * 385
        draw.text((x + 5, y + 5), f"Outgoing indirect contribution, frame {frame}", fill="white")
        sheet.paste(tile, (x, y + 25))
        records.append(dict(frame=frame, engineFrame=info.get("engineFrame"), giFrame=info.get("giFrame"),
                            rawFile=str(raw_path), allRGBAFinite=True))
    draw.text((5, 778), "Quantity: upsampled D * diffuse rho * material AO * intensity. Not D; not independent reference error.", fill="white")
    draw.text((5, 797), "Exposure 1, Reinhard+sRGB; PNG vertical flip only. Ordinary alpha is not a qualified validity mask. No historical exact A/B.", fill="white")
    sheet.save(path)
    return records


def main():
    output, image, outgoing = HERE / "available-comparison.json", HERE / "available-comparison.png", HERE / "outgoing.png"
    base.require(not any(p.exists() for p in (output, image, outgoing)), "Supplement output exists; refusing overwrite")
    result = dict(status="checking-available-inputs", originalResult=str(HERE / "comparison.json"),
                  originalCaptureContractSatisfied=False, adoption="pending", visualReview="pending", qualityVerdict=None,
                  candidateDirectory=str(base.CANDIDATE), baselineDirectory=str(base.BASELINE),
                  decisionFile=str(HERE / "decision.md"), reusedAnalysis=str(HERE / "analyze.py"),
                  availableFrames=list(FRAMES), inputChecks={}, references={},
                  scope="Available-data supplement; original stopped-incomparable result is unchanged. No new capture, hashes, integration or source reconstruction.",
                  uncertainty="Reference SE is a mean of per-pixel Monte Carlo SE, not an ROI confidence interval; original model differences remain.",
                  momentsMeaning="Stored moments.x is raw-luminance temporal statistics, not truth or temporal RGB.")
    try:
        original = base.load(HERE / "comparison.json")
        result["originalFailure"] = dict(status=original.get("status"), reason=original.get("reason"))
        missing = base.load(base.CANDIDATE / "frame-0240-capture.json")
        missing_d = base.unique(missing.get("samples", []), "signalId", "filteredD")
        base.require(missing.get("logicalFrame") == 240 and missing.get("status") == "incomplete" and
                     missing_d.get("status") != "available" and "byte budget exhausted" in missing.get("error", "").lower(),
                     "D240 does not match the declared incomplete/capacity case; stop for owner review")
        result["missingD240"] = dict(status=missing.get("status"), error=missing.get("error"),
                                     sampleStatus=missing_d.get("status"), reasons=missing_d.get("reasons"),
                                     readbacksCompleted=missing.get("readbacksCompleted"), substituted=False)
        refs = {frame: base.reference_inputs(frame) for frame in (119, 299)}
        for frame, ref in refs.items():
            result["references"][str(frame)] = dict(directory=str(ref["directory"]), spp=ref["report"]["spp"],
                maxDepth=ref["report"]["maxDepth"], modelDifferences=ref["report"]["modelDifferences"],
                computation="Source float64 geometry/MC; stored RGBA32F")
        audit = result["inputChecks"]["baseline119"] = {}
        baseline_input = base.input_gate(base.BASELINE, 119, refs[119], audit)
        inputs = {}
        for frame in FRAMES:
            audit = result["inputChecks"][str(frame)] = {}
            inputs[frame] = base.input_gate(base.CANDIDATE, frame, refs[119 if frame in (119, 239) else 299], audit)
        baseline = base.read_measurements(baseline_input)
        frames = {frame: base.read_measurements(inputs[frame]) for frame in FRAMES}
        for reference in refs.values():
            base.read_reference(reference)
        comparison119, conditions = {}, {}
        for name, region in refs[119]["rois"].items():
            baseline_domain = region & baseline["valid"]
            paired = baseline_domain & frames[119]["valid"]
            lost = int((baseline_domain & ~frames[119]["valid"]).sum())
            a, b = base.measures(baseline, refs[119], paired), base.measures(frames[119], refs[119], paired)
            comparison119[name] = dict(sourcePixels=int(region.sum()), fixedBaselineDomainPixels=int(baseline_domain.sum()),
                pairedPixels=int(paired.sum()), baselineUnknownPixels=int((region & ~baseline["valid"]).sum()),
                candidateUnknownPixels=int((region & ~frames[119]["valid"]).sum()), newlyUnknownOnBaselineDomain=lost,
                baseline=a, candidate=b,
                cohort="Unchanged original rule: baseline-known source ROI paired with candidate; any lost baseline point fails the coverage condition.")
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
                unknownPixels=int((region & ~frames[299]["valid"]).sum()), candidate=base.measures(frames[299], refs[299], paired))
        result["frameObservations"] = {}
        for frame in FRAMES:
            reference = refs[119 if frame in (119, 239) else 299]
            result["frameObservations"][str(frame)] = {}
            for name, region in reference["rois"].items():
                selected = region & frames[frame]["valid"]
                values = frames[frame]["rgb"][selected]
                result["frameObservations"][str(frame)][name] = dict(sourcePixels=int(region.sum()),
                    validPixels=int(selected.sum()), unknownPixels=int((region & ~frames[frame]["valid"]).sum()),
                    meanRGB=values.mean(0).tolist() if selected.any() else None,
                    meanY=float((values @ Y).mean()) if selected.any() else None,
                    meanMomentsX=float(frames[frame]["moments"][selected].mean()) if selected.any() else None)
        result["intervalChanges"] = []
        for name, region in refs[299]["rois"].items():
            selected = region & frames[270]["valid"] & frames[299]["valid"]
            delta = (frames[299]["rgb"][selected] - frames[270]["rgb"][selected]) @ Y
            result["intervalChanges"].append(dict(first=270, last=299, roi=name,
                sourcePixels=int(region.sum()), pairedPixels=int(selected.sum()),
                firstUnknownPixels=int((region & ~frames[270]["valid"]).sum()),
                lastUnknownPixels=int((region & ~frames[299]["valid"]).sum()),
                meanSignedDeltaY=float(delta.mean()) if selected.any() else None,
                meanAbsoluteDeltaY=float(np.abs(delta).mean()) if selected.any() else None,
                rmsDeltaY=float(np.sqrt(np.mean(delta * delta))) if selected.any() else None))
        available_panel(image, baseline, frames, refs)
        result["outgoing"] = dict(directory=str(OUTGOING), image=str(outgoing),
            quantity="D * diffuse rho * material AO * intensity after upsampling; not D or reference error",
            records=outgoing_panel(outgoing))
        result.update(status="available-data-comparison-produced", image=str(image),
            display="Exposure 1/Reinhard+sRGB; only PNG is vertically flipped, numeric rows unchanged.",
            decisionBoundary="Only original item-3 numerical conditions are evaluated. D240 and its D intervals remain missing. Original five-capture failure remains; available images do not automatically establish adoption, dynamic parity or convergence.")
    except (ValueError, KeyError, TypeError, OSError) as error:
        result.update(status="stopped-incomparable", reason=str(error), numericalScreen119="incomplete")
        for key in ("comparison119", "comparison299", "predeclaredNumericalConditions119", "frameObservations", "intervalChanges"):
            result.pop(key, None)
    output.write_text(json.dumps(result, indent=2, allow_nan=False) + "\n", encoding="utf-8")
    print(json.dumps(dict(status=result["status"], numericalScreen119=result.get("numericalScreen119"),
                          output=str(output), image=str(image), outgoing=str(outgoing))))
    if result["status"] != "available-data-comparison-produced":
        raise SystemExit(2)


if __name__ == "__main__":
    main()
