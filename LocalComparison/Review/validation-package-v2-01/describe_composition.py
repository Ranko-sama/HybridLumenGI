"""Describe hash-bound same-render signals. Delta is diagnostic, never a reference."""
import argparse
import hashlib
import html
import json
import math
from pathlib import Path
import platform
import sys

import numpy as np


SIGNALS = {
    "cameraBeforeHLGI": ("before-hlgi-composite-after-skybox", "camera-radiance", "camera-pixel"),
    "cameraAfterHLGI": ("after-hlgi-composite-before-transparents", "camera-radiance", "camera-pixel"),
    "filteredD": ("before-hlgi-composite-after-filter", "indirect-irradiance-over-pi", "gi-grid"),
}
LUMA = np.array([.2126, .7152, .0722], dtype=np.float64)
LIMITATION = ("Same-render linear RGB observations only. After-minus-before is a composition diagnostic, "
              "not an independent physical reference. Before includes native camera lighting, not direct light alone. "
              "After is before later URP transparent/post passes. No quality, convergence or performance verdict.")


def require(condition, reason):
    if not condition:
        raise ValueError(reason)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def decode_json(data):
    return json.loads(data.decode("utf-8-sig"), parse_constant=lambda value: (_ for _ in ()).throw(ValueError("Nonfinite JSON constant: " + value)))


class Artifacts:
    def __init__(self, root):
        self.root = root.resolve(strict=True)
        self.checked = {}

    def get(self, descriptor, read=False):
        name, expected = descriptor["file"], descriptor["sha256"]
        require(isinstance(name, str) and name and "\\" not in name and ":" not in name and
                not name.startswith("/") and all(p and p not in (".", "..") for p in name.split("/")), "Unsafe artifact path: " + str(name))
        require(isinstance(expected, str) and len(expected) == 64 and all(c in "0123456789abcdef" for c in expected), "Invalid SHA256: " + name)
        path = (self.root / name).resolve(strict=True)
        require(path.is_relative_to(self.root) and path.is_file(), "Artifact escapes manifest directory or is not a file: " + name)
        if read:
            data = path.read_bytes()
            actual, size = digest(data), len(data)
        else:
            hasher, size = hashlib.sha256(), 0
            with path.open("rb") as handle:
                while chunk := handle.read(1024 * 1024):
                    hasher.update(chunk)
                    size += len(chunk)
            actual, data = hasher.hexdigest(), None
        require(actual == expected, "Artifact hash mismatch: " + name)
        self.checked[name] = {"file": name, "sha256": actual, "bytes": size}
        return data


def stats(rgba, mask):
    finite = np.isfinite(rgba)
    finite_pixels = finite.all(axis=1)
    valid = mask.astype(bool) & finite_pixels
    selected = rgba[valid, :3].astype(np.float64)
    result = {
        "totalPixels": int(len(mask)), "maskValidPixels": int(mask.sum()),
        "maskInvalidPixels": int((mask == 0).sum()), "validFinitePixels": int(valid.sum()),
        "finitePixels": int(finite_pixels.sum()), "nonfinitePixels": int((~finite_pixels).sum()),
        "nonfiniteComponentsRGBA": (~finite).sum(axis=0).astype(int).tolist(),
        "maskValidButNonfinitePixels": int((mask.astype(bool) & ~finite_pixels).sum()),
        "statisticsDomain": "mask=1 and all four stored components finite; excluded counts remain explicit",
        "meanRGB": None, "minimumRGB": None, "maximumRGB": None, "maximumComponent": None,
        "meanLuminance": None, "maximumLuminance": None, "negativeRGBComponents": 0, "zeroRGBPixels": 0,
    }
    if len(selected):
        luminance = selected @ LUMA
        result.update(meanRGB=selected.mean(axis=0).tolist(), minimumRGB=selected.min(axis=0).tolist(),
                      maximumRGB=selected.max(axis=0).tolist(), maximumComponent=float(selected.max()),
                      meanLuminance=float(luminance.mean()), maximumLuminance=float(luminance.max()),
                      negativeRGBComponents=int((selected < 0).sum()), zeroRGBPixels=int((selected == 0).all(axis=1).sum()))
    return result, valid


def load_sample(files, sample, camera, signal_id):
    require(sample["format"] == "rgba32f-le" and sample["validity"]["format"] == "uint8", "Unsupported sample format")
    width, height = sample["width"], sample["height"]
    require(type(width) is int and type(height) is int and 0 < width <= 16384 and 0 < height <= 16384, "Invalid sample dimensions")
    require(sample["rowOrder"] in ("top-to-bottom", "bottom-to-top") and sample["rowOrder"] == camera["rowOrder"], "Sample/camera row orientation mismatch")
    if signal_id.startswith("camera"):
        require([width, height] == camera["viewport"][2:], "Camera sample does not cover the full viewport")
    data = files.get(sample["data"], read=True)
    validity = files.get(sample["validity"], read=True)
    require(len(data) == width * height * 16 and len(validity) == width * height, "Raw/mask byte count mismatch")
    rgba = np.frombuffer(data, dtype="<f4").reshape(-1, 4)
    mask = np.frombuffer(validity, dtype=np.uint8)
    require(np.isin(mask, [0, 1]).all(), "Validity mask has values other than 0/1")
    require(sample["validity"].get("basis") in ("all-pixels", "measurement-state", "declared-reference-domain"), "Missing validity basis")
    if sample["validity"]["basis"] == "all-pixels":
        require((mask == 1).all(), "all-pixels mask contains zero")
    result, valid = stats(rgba, mask)
    return rgba, valid, {"status": "described", "width": width, "height": height, "rowOrder": sample["rowOrder"],
                         "data": sample["data"], "validity": sample["validity"], **result}


def preview(image_module, output, name, rgb, valid, width, height, row_order, exposure_stops):
    # One explicit exposure and one fixed display mapping for every frame/signal.
    scaled = np.maximum(np.where(np.isfinite(rgb), rgb, 0).astype(np.float64), 0) * math.exp2(exposure_stops)
    mapped = scaled / (1 + scaled)
    srgb = np.where(mapped <= .0031308, 12.92 * mapped, 1.055 * np.power(mapped, 1 / 2.4) - .055)
    pixels = np.floor(np.clip(srgb, 0, 1) * 255 + .5).astype(np.uint8)
    pixels[~valid] = [255, 0, 255]
    pixels = pixels.reshape(height, width, 3)
    if row_order == "bottom-to-top":
        pixels = pixels[::-1]
    filename = name + ".png"
    image_module.fromarray(pixels, mode="RGB").save(output / filename)
    return filename


def describe(candidate, output, exposure_stops=None):
    raw_manifest = candidate.read_bytes()
    manifest = decode_json(raw_manifest)
    require(manifest.get("schema") == "hlgi-validation-reference-v2" and manifest.get("kind") == "candidate", "Expected validation v2 candidate manifest")
    files = Artifacts(candidate.parent)
    source = decode_json(files.get(manifest["source"], read=True))
    require(source.get("schema") == "hlgi-validation-source-v2", "Source schema mismatch")
    for item in source["assets"]:
        files.get({"file": item["path"], "sha256": item["sha256"]})
    for item in manifest.get("provenance", []):
        files.get(item)
    definitions = {item["id"]: item for item in manifest["signals"]}
    require(len(definitions) == len(manifest["signals"]), "Duplicate signal definitions")
    for name, (stage, quantity, domain) in SIGNALS.items():
        signal = definitions.get(name)
        require(signal is not None and signal.get("stage") == stage and signal.get("quantity") == quantity and signal.get("domain") == domain,
                "Missing or different signal boundary: " + name)
        require(signal.get("units") == "scene-linear-radiance" and signal.get("colorSpace") == "linear-srgb" and signal.get("exposure") == 1, "Unsupported signal units/color/exposure")
    selected = manifest["selection"]["logicalFrames"]
    require(isinstance(selected, list) and selected and all(type(n) is int and 0 <= n < manifest["sequence"]["totalLogicalFrames"] for n in selected)
            and selected == sorted(set(selected)), "Invalid selected frame list")
    frames = {item["logicalFrame"]: item for item in manifest["frames"]}
    require(len(frames) == len(manifest["frames"]) and set(frames).issubset(selected), "Duplicate/unselected frames")
    image_module, preview_status = None, {"requested": exposure_stops is not None, "generated": False}
    if exposure_stops is not None:
        try:
            from PIL import Image
            image_module = Image
            preview_status.update(generated=True, exposureStops=exposure_stops, transform="max(0,linear)*2^stops; Reinhard x/(1+x); sRGB; round to uint8",
                                  invalidColor="magenta", deltaDisplay="positive RGB and negative RGB magnitude separately, at the same fixed exposure",
                                  orientation="display top-to-bottom; flip only when declared raw rowOrder is bottom-to-top", pillow=Image.__version__)
        except ImportError:
            preview_status["reason"] = "Pillow unavailable; numeric report still produced."

    rows = []
    for logical in selected:
        row = {"logicalFrame": logical, "signals": {}, "delta": {"status": "uncovered"}, "previews": {}}
        if logical not in frames:
            row["status"] = "missing-frame"
            rows.append(row)
            continue
        frame = frames[logical]
        state = decode_json(files.get(frame["state"], read=True))
        require(state.get("schema") == "hlgi-validation-frame-state-v2" and state.get("logicalFrame") == logical and
                state.get("sourceSha256") == manifest["source"]["sha256"] and state.get("camera") == frame.get("camera"), "Frame input identity/camera mismatch")
        camera = frame["camera"]
        require(camera.get("matrixOrder") == "row-major" and len(camera.get("view", [])) == 16 and len(camera.get("projection", [])) == 16 and
                all(math.isfinite(v) for v in camera["view"] + camera["projection"] + camera["jitter"]), "Invalid camera matrices")
        row.update(status="described", state=frame["state"], sourceUnsupported=state.get("unsupported", []))
        for item in frame.get("support", []):
            files.get(item)
        samples = {item["signalId"]: item for item in frame["samples"]}
        require(len(samples) == len(frame["samples"]), "Duplicate frame samples")
        loaded = {}
        for name in SIGNALS:
            sample = samples.get(name)
            if sample is None or sample.get("status") != "available":
                row["signals"][name] = {"status": sample.get("status", "uncovered") if sample else "uncovered",
                                          "reasons": sample.get("reasons", []) if sample else ["Selected frame has no signal."]}
                continue
            require(sample.get("stage", definitions[name]["stage"]) == definitions[name]["stage"], "Sample/definition stage mismatch")
            rgba, valid, info = load_sample(files, sample, camera, name)
            loaded[name] = (rgba, valid)
            row["signals"][name] = info
            if image_module:
                row["previews"][name] = preview(image_module, output, f"frame-{logical:04d}-{name}", rgba[:, :3], valid,
                                               info["width"], info["height"], info["rowOrder"], exposure_stops)
        if all(name in loaded for name in ("cameraBeforeHLGI", "cameraAfterHLGI")):
            before, before_valid = loaded["cameraBeforeHLGI"]
            after, after_valid = loaded["cameraAfterHLGI"]
            before_info, after_info = row["signals"]["cameraBeforeHLGI"], row["signals"]["cameraAfterHLGI"]
            require(all(before_info[k] == after_info[k] for k in ("width", "height", "rowOrder")), "Same-frame camera signal layouts differ")
            common = before_valid & after_valid
            # Convert before subtraction: diagnostic differences must not overflow float32.
            delta_rgb = np.zeros((len(common), 3), dtype=np.float64)
            delta_rgb[common] = after[common, :3].astype(np.float64) - before[common, :3].astype(np.float64)
            delta_rgba = np.column_stack((delta_rgb, np.ones(len(common))))
            delta_stats, _ = stats(delta_rgba, common.astype(np.uint8))
            delta_stats["finitePixels"] = int(common.sum())
            delta_stats["uncomputedPixels"] = int((~common).sum())
            delta_stats["statisticsDomain"] = "after-minus-before computed only on common-valid pixels; excluded deltas are not evaluated"
            row["delta"] = {"status": "described", "definition": "cameraAfterHLGI.rgb - cameraBeforeHLGI.rgb", "diagnosticOnly": True,
                            "beforeDataSha256": before_info["data"]["sha256"], "afterDataSha256": after_info["data"]["sha256"],
                            "commonValidPixels": int(common.sum()), "excludedPixels": int((~common).sum()), **delta_stats}
            if image_module:
                for suffix, values in (("delta-positive", np.maximum(delta_rgb, 0)), ("delta-negative", np.maximum(-delta_rgb, 0))):
                    row["previews"][suffix] = preview(image_module, output, f"frame-{logical:04d}-{suffix}", values, common,
                                                     after_info["width"], after_info["height"], after_info["rowOrder"], exposure_stops)
        rows.append(row)
    require(candidate.read_bytes() == raw_manifest, "Candidate manifest changed during description")
    report = {"schema": "hlgi-composition-description-v1", "status": "described", "diagnosticOnly": True, "physicalReference": False,
              "qualityVerdict": None, "performanceVerdict": None, "limitation": LIMITATION,
              "candidate": {"path": str(candidate), "sha256": digest(raw_manifest), "status": manifest.get("status"), "reasons": manifest.get("reasons", [])},
              "source": manifest["source"], "sourceUnsupported": source.get("unsupported", []), "sequence": manifest["sequence"],
              "selectedFrames": selected, "signals": [definitions[n] for n in SIGNALS], "preview": preview_status,
              "tool": {"path": str(Path(__file__).resolve()), "sha256": digest(Path(__file__).read_bytes()), "python": platform.python_version(), "numpy": np.__version__},
              "checkedArtifacts": sorted(files.checked.values(), key=lambda item: item["file"]), "frames": rows}
    (output / "composition.json").write_text(json.dumps(report, indent=2, allow_nan=False) + "\n", encoding="utf-8")
    write_html(output, report)
    return report


def write_html(output, report):
    def esc(value):
        return html.escape(str(value))
    def mean(value):
        return "—" if value is None else ", ".join(f"{v:.6g}" for v in value)
    pieces = ["<!doctype html><meta charset='utf-8'><title>HLGI composition observations</title>",
              "<style>body{font:15px system-ui;max-width:1500px;margin:24px auto;padding:0 16px;background:#151719;color:#e6e7e8}"
              "table{border-collapse:collapse}td,th{padding:7px 12px;border:1px solid #46494c;text-align:left}"
              ".images{display:flex;flex-wrap:wrap;gap:12px}figure{margin:8px 0}img{max-width:440px;image-rendering:pixelated}"
              "a{color:#8fc5ff}section{margin:34px 0}code{word-break:break-all}</style>",
              "<h1>Same-render composition observations</h1><p>" + esc(LIMITATION) + "</p>",
              f"<p>Capture status: {esc(report['candidate']['status'])}. Source unsupported: {esc(report['sourceUnsupported'])}.</p>",
              f"<p>Candidate SHA256: <code>{esc(report['candidate']['sha256'])}</code>. <a href='composition.json'>Complete JSON report</a></p>",
              "<p>Preview: " + esc(report["preview"]) + ". Magenta indicates excluded pixels. Negative values remain in numeric statistics.</p>"]
    for row in report["frames"]:
        pieces.append(f"<section><h2>Logical frame {row['logicalFrame']}</h2><table><tr><th>Signal</th><th>Valid / total pixels</th><th>Mean linear RGB</th><th>Maximum component</th><th>Nonfinite pixels</th></tr>")
        for name, info in list(row["signals"].items()) + [("after − before (diagnostic)", row["delta"])]:
            pieces.append("<tr>" + "".join("<td>" + esc(v) + "</td>" for v in [name,
                f"{info.get('validFinitePixels', '—')} / {info.get('totalPixels', '—')}", mean(info.get("meanRGB")),
                info.get("maximumComponent", "—"), info.get("nonfinitePixels", "—")]) + "</tr>")
        pieces.append("</table><div class='images'>")
        for name, filename in row["previews"].items():
            pieces.append(f"<figure><figcaption>{esc(name)}</figcaption><a href='{esc(filename)}'><img src='{esc(filename)}' alt='{esc(name)}'></a></figure>")
        pieces.append("</div></section>")
    (output / "index.html").write_text("\n".join(pieces), encoding="utf-8")


def self_test():
    data = np.array([[0, -0., 0, 1], [2, 4, 6, 1], [np.nan, np.inf, 0, 1]], dtype=np.float32)
    value, valid = stats(data, np.array([1, 1, 0], dtype=np.uint8))
    assert value["validFinitePixels"] == 2 and value["nonfinitePixels"] == 1 and value["meanRGB"] == [1, 2, 3]
    assert value["zeroRGBPixels"] == 1 and valid.tolist() == [True, True, False]
    delta = np.array([[-1, 2, -3, 1], [0, 0, 0, 1]], dtype=np.float64)
    value, _ = stats(delta, np.array([1, 0], dtype=np.uint8))
    assert value["meanRGB"] == [-1, 2, -3] and value["negativeRGBComponents"] == 2 and value["maximumComponent"] == 2
    assert stats(data, np.zeros(3, dtype=np.uint8))[0]["meanRGB"] is None
    print(json.dumps({"status": "passed", "scope": "CPU arithmetic/validity only; no native inputs or physical reference"}))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--candidate", type=Path, help="candidate.json, its directory, or one native root containing exactly one candidate.json")
    parser.add_argument("--output", type=Path, help="New report directory; existing paths are rejected")
    parser.add_argument("--exposure-stops", type=float, help="Request previews using this one fixed exposure for all frames (Pillow optional)")
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        require(args.candidate is None and args.output is None, "Self-test does not consume captures")
        self_test()
        return
    require(args.candidate is not None and args.output is not None, "Pass --candidate and --output")
    require(args.exposure_stops is None or (math.isfinite(args.exposure_stops) and -32 <= args.exposure_stops <= 32), "Exposure must be finite, between -32 and 32 stops")
    candidate = args.candidate.resolve(strict=True)
    if candidate.is_dir():
        choices = list(candidate.rglob("candidate.json"))
        require(len(choices) == 1, "Directory must contain exactly one candidate.json; otherwise supply the exact file")
        candidate = choices[0].resolve(strict=True)
    output = args.output.absolute()
    require(not output.exists(), "Refusing to overwrite output: " + str(output))
    output.mkdir(parents=True, exist_ok=False)
    try:
        report = describe(candidate, output, args.exposure_stops)
        print(json.dumps({"status": "described", "frames": len(report["frames"]), "output": str(output), "diagnosticOnly": True}))
    except Exception as error:
        (output / "failure.json").write_text(json.dumps({"status": "description-failed", "error": str(error), "qualityVerdict": None}, indent=2) + "\n", encoding="utf-8")
        raise


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(json.dumps({"status": "description-failed", "error": str(error), "qualityVerdict": None}), file=sys.stderr)
        raise SystemExit(1)
