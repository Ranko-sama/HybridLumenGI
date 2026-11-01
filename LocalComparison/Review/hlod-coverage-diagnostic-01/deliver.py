"""Use the ordinary Release94 delivery recipe, with seven PNGs and the linear white-furnace EXR inside the Player ZIP."""
import json
from pathlib import Path
import re
import sys

HERE = Path(__file__).resolve().parent
REVIEW = HERE.parent
SOURCE = "192afe9f83412097fb9efb2e7adbeb6e6fd62474"
if len(sys.argv) != 2 or sys.argv[1] not in ("package", "draft", "upload", "publish"):
    raise SystemExit("Expected package, draft, upload or publish")
action = sys.argv[1]
attempt = json.loads((HERE / "release-build-attempt.json").read_text(encoding="utf-8-sig"))
if attempt["source"] != SOURCE:
    raise RuntimeError("Expected the reviewed Release100 HLOD coverage diagnostic source")

recipe = REVIEW / "release94-download-01" / ("package.py" if action == "package" else "publish.py")
code = recipe.read_text(encoding="utf-8")
code = code.replace("Release94", "Release100").replace("release94-demo", "release100-demo")
code = code.replace("e296750444a835c1346e073c7b6f73100dc64688", SOURCE)
context = {"__file__": str(HERE / "deliver.py"), "__name__": "__main__"}

if action == "package":
    page = REVIEW / "picture-comparison.html"
    images = (
        "release93-color-frame119-01/comparison.png",
        "local-recolor-response-01/comparison.png",
        "cache-source-separation-01/comparison.png",
        "four-pass-local-quality-01/comparison.png",
        "light-restore-response-01/comparison.png",
        "white-furnace-ordinary-01/frame-0000.png",
        "zero-diffuse-composite-v209/comparison.png",
    )
    hdr = "white-furnace-ordinary-01/frame-0000.exr"
    html = page.read_text(encoding="utf-8")
    sources = re.findall(r'<img\b[^>]*\bsrc="([^"]+)"', html)
    if sorted(sources) != sorted(images):
        raise RuntimeError("Expected the seven original comparison images in the offline page")
    if hdr not in re.findall(r'<a\b[^>]*\bhref="([^"]+)"', html):
        raise RuntimeError("Expected the original linear EXR link in the offline page")
    pictures = [(page, "PictureComparison/index.html")]
    pictures.extend((REVIEW / name, "PictureComparison/" + name) for name in (*images, hdr))
    for path, _ in pictures:
        if not path.is_file():
            raise FileNotFoundError(path)

    anchor = "inputs += [(HERE / 'READ-ME-FIRST.md', 'READ-ME-FIRST.md')]"
    if code.count(anchor) != 1:
        raise RuntimeError("Expected the established ordinary package input list")
    code = code.replace(anchor, anchor + "\ninputs.extend(picture_inputs)")
    context["picture_inputs"] = pictures

sys.argv = [str(HERE / "deliver.py"), action]
exec(compile(code, str(recipe), "exec"), context)
