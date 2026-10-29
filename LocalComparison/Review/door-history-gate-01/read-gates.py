"""Read only the approved door/frame239 observer; no image or quality verdict."""
import json
from pathlib import Path
import numpy as np

HERE = Path(__file__).resolve().parent
CAPTURE = Path("I:/Unity test/Comparison/DoorHistoryGate01/signals")
REFERENCE = Path("I:/Unity test/Comparison/ValidationPackageV209-reference-frame0119-01")
receipt = json.loads((CAPTURE / "frame-0239-capture.json").read_text(encoding="utf-8-sig"))
if not (receipt["logicalFrame"] == receipt["workFrame"] == 239 and receipt["status"] == "complete" and receipt["readbacksCompleted"]):
    raise RuntimeError("The single requested frame was not captured completely; stop without retry.")
support = next(s for s in receipt["support"] if s["role"] == "moments")
if (support["width"], support["height"], support["format"], support["rowOrder"]) != (320, 180, "rgba32f-le", "top-to-bottom"):
    raise RuntimeError("Unexpected existing moments descriptor.")
moments = np.fromfile(CAPTURE / support["file"], dtype="<f4").reshape(180, 320, 4)
names = [o["name"] for o in json.loads((REFERENCE / "geometry-index.json").read_text())["objects"]]
with np.load(REFERENCE / "primary.npz", allow_pickle=False) as p:
    region = p["owner"] == names.index("Moving occluder")
values = moments[:, :, 3][region]
if not np.isfinite(values).all() or not (values == np.floor(values)).all():
    raise RuntimeError("Door observer values are not exact finite integers.")
codes = values.astype(np.uint32)
if not ((codes >> 16) == 239).all():
    raise RuntimeError("Observer frame stamp is missing; stop without retry.")
labels = ["geometryDecoded", "hasNg", "currentKnown", "candidateRowEntered", "rowReusableFlag",
          "identityMotionPassed", "initialReprojectionValid", "validAfterPrimitive", "validAfterTap",
          "validAfterChange", "validAfterOldHistory", "globalReactiveBranchTaken", "historyValidInput", "identityKernel"]
counts = {name: int(((codes & (1 << bit)) != 0).sum()) for bit, name in enumerate(labels)}
patterns = []
for code, count in zip(*np.unique(codes, return_counts=True)):
    patterns.append(dict(code=int(code), count=int(count), identityState=int((code >> 14) & 3),
                         setStates=[name for bit, name in enumerate(labels) if code & (1 << bit)]))
result = dict(frame=239, workFrame=receipt["workFrame"], engineFrame=receipt["engineFrame"], pixels=int(region.sum()),
              doorSource="Saved frame119 primary owner grid; same camera and door returns to its initial pose at239.",
              counts=counts, patterns=patterns,
              historyLengths={str(float(n)): int(c) for n, c in zip(*np.unique(moments[:, :, 2][region], return_counts=True))},
              scope="One door at239 only. Bits6..10 record cumulative validity, not independent predicate failures. Later zero states after an earlier zero are inconclusive. Diagnostic moments/filter/output are not quality or convergence evidence.")
(HERE / "gates.json").write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
print(json.dumps(result, ensure_ascii=False, indent=2))
