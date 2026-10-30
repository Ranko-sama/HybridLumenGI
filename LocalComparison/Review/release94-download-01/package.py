"""Package the existing ordinary Release94; no rebuild, hashes or source mutation."""
from pathlib import Path
import datetime
import json
import zipfile

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
BUILD = Path('I:/Unity test/Comparison/Builds/LocalRelease94')
OUTPUT = Path('I:/Unity test/Comparison/Packages/HybridLumenGI-Release94-Windows-x64.zip')
ROOT = 'HybridLumenGI-Release94-Windows-x64/'
report = json.loads((BUILD / 'build-result.json').read_text(encoding='utf-8-sig'))
if report['status'] != 'Succeeded' or report['actualOptions'] != 'None' or report['errors'] != 0:
    raise RuntimeError('Expected the existing successful ordinary Release94 build')
if OUTPUT.exists():
    raise RuntimeError('Preserve existing package')
inputs = [(path, path.relative_to(BUILD).as_posix()) for path in BUILD.rglob('*')
          if path.is_file() and not any(part.endswith('_DoNotShip') for part in path.relative_to(BUILD).parts)]
inputs += [(HERE / 'READ-ME-FIRST.md', 'READ-ME-FIRST.md')]
for relative in ['Documentation/NativeGpuTimingThirdPartyNotices.md', 'Documentation/Licenses/Unity-Companion-License.txt']:
    inputs.append((REPO / relative, relative))
OUTPUT.parent.mkdir(parents=True, exist_ok=True)
with zipfile.ZipFile(OUTPUT, 'x', compression=zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
    for path, relative in inputs:
        archive.write(path, ROOT + relative)
# Only inspect the directory for missing runtime deliverables; do not reread/hash all bytes.
with zipfile.ZipFile(OUTPUT) as archive:
    names = set(archive.namelist())
    for relative in ['Start-LocalRelease.cmd', 'HybridLumenGIPlayer.exe', 'UnityPlayer.dll',
                     'D3D12/D3D12Core.dll', 'HybridLumenGIPlayer_Data/Plugins/x86_64/HybridLumenGIGpuTiming.dll',
                     'READ-ME-FIRST.md', 'Documentation/NativeGpuTimingThirdPartyNotices.md',
                     'Documentation/Licenses/Unity-Companion-License.txt']:
        if ROOT + relative not in names:
            raise RuntimeError('Missing packaged runtime input: ' + relative)
    for folder in ['MonoBleedingEdge/', 'HybridLumenGIPlayer_Data/Managed/',
                   'HybridLumenGIPlayer_Data/StreamingAssets/UnifiedRelease74/']:
        if not any(name.startswith(ROOT + folder) for name in names):
            raise RuntimeError('Missing packaged runtime directory: ' + folder)
result = dict(createdUtc=datetime.datetime.now(datetime.timezone.utc).isoformat(), path=str(OUTPUT),
              bytes=OUTPUT.stat().st_size, source='e296750444a835c1346e073c7b6f73100dc64688',
              scope='Existing ordinary Release94 and required notices; no new runtime validation or production acceptance.')
(HERE / 'package-result.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
print(json.dumps(result, indent=2))
