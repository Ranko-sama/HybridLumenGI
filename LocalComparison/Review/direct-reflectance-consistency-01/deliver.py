"""Reuse the established Release94 packaging/upload recipe for this Release95.

Only artifact names and the source commit change; credentials remain inside the
existing repository-scoped uploader. No build, runtime check or hashing here.
"""
import json
from pathlib import Path
import sys

HERE = Path(__file__).resolve().parent
action = sys.argv[1]
if action not in ("package", "draft", "upload", "publish"):
    raise ValueError("Expected package, draft, upload or publish")
source = json.loads((HERE / "release-build-attempt.json").read_text(encoding="utf-8-sig"))["source"]
if not source.startswith("1503738"):
    raise RuntimeError("Expected the reviewed direct-reflectance source")
recipe = HERE.parent / "release94-download-01" / ("package.py" if action == "package" else "publish.py")
code = recipe.read_text(encoding="utf-8")
code = code.replace("Release94", "Release95").replace("release94-demo", "release95-demo")
code = code.replace("e296750444a835c1346e073c7b6f73100dc64688", source)
sys.argv = [str(HERE / "deliver.py"), action]
exec(compile(code, str(recipe), "exec"), {"__file__": str(HERE / "deliver.py"), "__name__": "__main__"})
