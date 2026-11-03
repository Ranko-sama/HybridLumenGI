"""Complete the predeclared MAE from the existing capture; no new sampling."""
import importlib.util
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
HELPER = HERE.parent / "stationary-history-01/analyze.py"
spec = importlib.util.spec_from_file_location("existing_history_helpers", HELPER)
common = importlib.util.module_from_spec(spec)
spec.loader.exec_module(common)

comparison = common.load(HERE / "comparison.json")
common.require(comparison["status"] == "comparison-produced", "Existing input checks did not pass")
output = HERE / "pixel-mae.json"
common.require(not output.exists(), "Preserve the first result")
directory = Path(comparison["currentDirectory"])
receipt = common.load(directory / "frame-0119-capture.json")
sample = common.unique(receipt["samples"], "signalId", "filteredD")
data = common.read_measurements((directory, receipt, sample))
reference = common.reference_inputs(119)
common.read_reference(reference)
rows = {}
for name, region in reference["rois"].items():
    selected = region & data["valid"]
    common.require(int(selected.sum()) == comparison["roi"][name]["pairedPixels"], "Comparison domain differs")
    rows[name] = dict(pairedPixels=int(selected.sum()),
                     pixelYMAE=common.measures(data, reference, selected)["pixelYMAE"])
result = dict(logicalFrame=119, quantity=comparison["quantity"],
              helper="../stationary-history-01/analyze.py:measures",
              formula="mean(abs((currentRGB - referenceRGB) dot [0.2126, 0.7152, 0.0722]))",
              domain="Current-valid pixels in the existing independent source ROI; same as comparison.json",
              roi=rows, qualityVerdict=None)
output.write_text(json.dumps(result, indent=2, allow_nan=False) + "\n", encoding="utf-8")
print(json.dumps(result, indent=2, allow_nan=False))
