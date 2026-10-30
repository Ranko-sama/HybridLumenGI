"""Read the four predeclared captures; no further capture or quality inference."""
import json
from pathlib import Path
import numpy as np

HERE = Path(__file__).resolve().parent
ROOT = Path("I:/Unity test/Comparison/MultiCameraHistory01")


def read(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def load(camera, frame):
    folder = ROOT / ("signals" if camera == "A" else "signals-B")
    r = read(folder / f"frame-{frame:04}-capture.json")
    assert r["logicalFrame"] == r["workFrame"] == frame
    assert r["status"] == "complete" and not r["error"] and r["readbacksCompleted"] and r["retainedBytes"] == 0
    data = {}
    for role in ("geometry", "moments", "material"):
        s = next(x for x in r["support"] if x["role"] == role)
        assert s["format"] == "rgba32f-le" and s["rowOrder"] == "top-to-bottom"
        data[role] = np.fromfile(folder / s["file"], dtype="<f4").reshape(s["height"], s["width"], 4)
    sample = next(x for x in r["samples"] if x["signalId"] == "filteredD")
    assert sample["status"] == "available"
    data["known"] = np.fromfile(folder / sample["validity"]["file"], dtype=np.uint8).reshape(sample["height"], sample["width"]) > 0
    data["ng"] = np.isfinite(data["geometry"]).all(axis=-1) & (data["geometry"][:, :, 2] > 0)
    return r, data


out = HERE / "result.json"
if out.exists():
    raise RuntimeError("Preserve existing result")
pair, host = read(ROOT / "camera-pair.json"), read(ROOT / "host-result.json")
result = dict(status="checking", pair=pair, host=host,
              scope="One same-Feature pair of Base cameras; B camera cut only. No whole G3, arbitrary pixel-isolation, image accuracy, convergence, performance or retirement claim.")
try:
    assert pair["primaryType"] == pair["secondaryType"] == "Base" and pair["sameRenderer"]
    assert pair["primaryCamera"] != pair["secondaryCamera"] and pair["primaryTarget"] != pair["secondaryTarget"]
    assert host["renderedFrames"] == host["secondaryRenderedFrames"] == 105 and host["referenceDrained"]
    sequence = Path(host["captureDirectory"])
    run, feature = read(sequence / "run.json"), read(sequence / "feature.json")
    maximum = feature["settings"]["maxHistory"]
    assert run["failures"] == run["backendMismatches"] == 0
    result["maxHistory"] = maximum
    frames = {(camera, frame): load(camera, frame) for camera, frame in (("A", 95), ("B", 95), ("B", 103), ("A", 104))}
    result["captures"] = {}
    for (camera, frame), (r, d) in frames.items():
        expected = pair["primaryCamera" if camera == "A" else "secondaryCamera"]
        assert r["cameraInstanceId"] == expected and r["featureInstanceId"] == pair["feature"]
        qualified = d["known"] & d["ng"]
        lengths = d["moments"][:, :, 2][qualified]
        result["captures"][f"{camera}{frame}"] = dict(engineFrame=r["engineFrame"], workFrame=r["workFrame"],
            qualified=int(qualified.sum()), historyLengths={str(float(n)): int(c) for n, c in zip(*np.unique(lengths, return_counts=True))})
    assert frames["A", 95][0]["engineFrame"] == frames["B", 95][0]["engineFrame"]
    assert frames["A", 104][0]["engineFrame"] == frames["B", 103][0]["engineFrame"] + 1
    a0, a1 = frames["A", 95], frames["A", 104]
    b0, b1 = frames["B", 95], frames["B", 103]
    assert a0[0]["composite"] == a1[0]["composite"]
    assert b0[0]["composite"]["invVP"] != b1[0]["composite"]["invVP"]
    cohort = a0[1]["known"] & a0[1]["ng"] & (a0[1]["moments"][:, :, 2] == maximum)
    b_old = b0[1]["known"] & b0[1]["ng"] & (b0[1]["moments"][:, :, 2] == maximum)
    b_new = b1[1]["known"] & b1[1]["ng"]
    assert cohort.any() and b_old.any() and b_new.any()
    # The fixed scene uses the existing half-GI odd-center sampling contract.
    assert a0[1]["material"].shape[:2] == (360, 640) and cohort.shape == (180, 320)
    material0, material1 = a0[1]["material"][1::2, 1::2], a1[1]["material"][1::2, 1::2]
    result["A_fixedMatureCohort"] = dict(pixels=int(cohort.sum()),
        lostKnown=int((cohort & ~a1[1]["known"]).sum()),
        geometryChanged=int((cohort & np.any(a0[1]["geometry"] != a1[1]["geometry"], axis=-1)).sum()),
        materialChanged=int((cohort & np.any(material0 != material1, axis=-1)).sum()),
        historyShortened=int((cohort & (a1[1]["moments"][:, :, 2] != maximum)).sum()))
    result["B_cut"] = dict(matureBefore=int(b_old.sum()), knownNgAfter=int(b_new.sum()),
        notLengthOne=int((b_new & (b1[1]["moments"][:, :, 2] != 1)).sum()))
    a_rows = [json.loads(line) for line in (sequence / "frames.jsonl").read_text().splitlines()]
    b_rows = [json.loads(line) for line in (ROOT / "secondary-frames.jsonl").read_text().splitlines()]
    assert len(a_rows) == len(b_rows) == 105
    for i, (a, b) in enumerate(zip(a_rows, b_rows)):
        assert a["logicalFrame"] == b["logicalFrame"] == i and a["engineFrame"] == b["engineFrame"]
        if i:
            assert a["engineFrame"] == a_rows[i-1]["engineFrame"] + 1
            assert a["giFrame"] == a_rows[i-1]["giFrame"] + 1 and b["giFrame"] == b_rows[i-1]["giFrame"] + 1
    result["continuousCameraFrames"] = 105
    result["B_cutPositions"] = dict(before=b_rows[102]["position"], after=b_rows[103]["position"])
    changed = any(v for k, v in result["A_fixedMatureCohort"].items() if k != "pixels")
    result["status"] = "finite-camera-cut-isolation-observed" if not changed and result["B_cut"]["notLengthOne"] == 0 else "needs-classification"
except Exception as error:
    result["status"] = "stopped-incomplete"
    result["error"] = repr(error)
out.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
print(json.dumps(result, ensure_ascii=False, indent=2))
