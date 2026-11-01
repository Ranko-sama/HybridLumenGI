"""Use the ordinary Release94 delivery recipe, with the existing five-picture guide inside the Player ZIP."""
import json
from pathlib import Path
import re
import sys

HERE = Path(__file__).resolve().parent
REVIEW = HERE.parent
SOURCE = "e20759384555c918e1a91b48665082cbe9a0942c"
if len(sys.argv) != 2 or sys.argv[1] not in ("package", "draft", "upload", "publish"):
    raise SystemExit("Expected package, draft, upload or publish")
action = sys.argv[1]
attempt = json.loads((HERE / "release-build-attempt.json").read_text(encoding="utf-8-sig"))
if attempt["source"] != SOURCE:
    raise RuntimeError("Expected the reviewed Release99 surface cache ordering source")

recipe = REVIEW / "release94-download-01" / ("package.py" if action == "package" else "publish.py")
code = recipe.read_text(encoding="utf-8")
code = code.replace("Release94", "Release99").replace("release94-demo", "release99-demo")
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
    )
    sources = re.findall(r'<img\b[^>]*\bsrc="([^"]+)"', page.read_text(encoding="utf-8"))
    if sorted(sources) != sorted(images):
        raise RuntimeError("The offline page must reference exactly the five original comparison images")
    pictures = [(page, "PictureComparison/index.html")]
    pictures.extend((REVIEW / image, "PictureComparison/" + image) for image in images)
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
