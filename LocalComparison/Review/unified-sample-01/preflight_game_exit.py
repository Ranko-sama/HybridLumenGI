"""Compile the already prepared game-exit Host snapshot in a fresh helper package."""
import hashlib
import importlib.util
import json
from pathlib import Path

P = Path(__file__).resolve().parent
ROOT = P.parents[2]
STAGE = P/'instrumentation-game-exit'
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
manifest = json.loads((STAGE/'manifest.json').read_text())
for row in manifest['files']:
    source = ROOT/row['path'].removeprefix('Assets/HybridLumenGI/') if row['path'].startswith('Assets/HybridLumenGI/') else ROOT/'LocalComparison/Harness'/Path(row['path']).name
    assert sha(source) == sha(STAGE/row['prepared']) == row['sha256']
package = P/'game-exit'; package.mkdir(exist_ok=True)
helper = P.parent/'current-local-release-67/preflight67.py'
spec = importlib.util.spec_from_file_location('sample_environment_preflight', helper)
module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
module.PACKAGE, module.STAGE, module.DEST = package, STAGE, package/'preflight'
module.main()
