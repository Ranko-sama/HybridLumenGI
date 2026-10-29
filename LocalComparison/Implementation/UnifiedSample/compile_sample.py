"""Compile an isolated source snapshot plus the three API patches. Does not run Unity or build bundles."""
import hashlib
import json
import shutil
import subprocess
import sys
from pathlib import Path

P = Path(__file__).resolve().parent
ROOT = P.parents[2]
PROJECT = Path('I:/Unity test/Project')
EDITOR = Path('I:/Unity test/Editor/6000.0.85f1/Editor/Data')
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()

def main():
    destination = P / (sys.argv[1] if len(sys.argv) == 2 else 'sample-compile-01')
    if destination.exists():
        raise RuntimeError('Preserve previous compiler evidence')
    stage = destination / 'stage'
    inputs = {}
    for scope in ('Runtime', 'Editor'):
        for source in (ROOT / scope).rglob('*.cs'):
            relative = source.relative_to(ROOT)
            target = stage / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, target)
            inputs[relative.as_posix()] = sha(source)
    patch_modes = {}
    for name in ('publication-api.patch', 'backend-preference.patch', 'asset-page-builder-api.patch'):
        patch = P / name
        command = ['git', 'apply', '--whitespace=error-all', '--directory=' + stage.relative_to(ROOT).as_posix()]
        forward = subprocess.run(command + ['--check', str(patch)], cwd=ROOT, capture_output=True)
        if forward.returncode == 0:
            subprocess.run(command + [str(patch)], cwd=ROOT, check=True)
            patch_modes[name] = 'applied to isolated snapshot'
        else:
            subprocess.run(command + ['--reverse', '--check', str(patch)], cwd=ROOT, check=True)
            patch_modes[name] = 'already present; reverse applicability checked only'
        inputs[patch.relative_to(ROOT).as_posix()] = sha(patch)
    for relative in ('Runtime/HybridLumenGIUnifiedSample.cs', 'Editor/HybridLumenGIUnifiedSampleBuilder.cs'):
        source = P / relative
        shutil.copyfile(source, stage / relative)
        inputs[source.relative_to(ROOT).as_posix()] = sha(source)
    rows = []
    for scope in ('Runtime', 'Editor'):
        original = PROJECT / ('Library/Bee/artifacts/1900b0aE.dag/Assembly-CSharp' + ('-Editor' if scope == 'Editor' else '') + '.rsp')
        lines = []
        for line in original.read_text(encoding='utf-8-sig').splitlines():
            if line.strip('"').endswith('.cs') or line.startswith(('-out:', '-refout:', '/analyzer:', '-analyzer:', '/additionalfile:')):
                continue
            if scope == 'Editor' and line.startswith('-r:') and 'Assembly-CSharp' in line:
                continue
            lines.append(line)
        if scope == 'Editor':
            lines.append('-r:"' + (destination / 'SampleRuntime.dll').as_posix() + '"')
        lines.append('-out:"' + (destination / ('Sample' + scope + '.dll')).as_posix() + '"')
        sources = sorted((stage / scope).rglob('*.cs'))
        lines.extend('"' + p.as_posix() + '"' for p in sources)
        response = destination / (scope + '.rsp')
        response.write_text('\n'.join(lines), encoding='utf-8')
        command = [str(EDITOR / 'NetCoreRuntime/dotnet.exe'), str(EDITOR / 'DotNetSdkRoslyn/csc.dll'), '@' + str(response)]
        execution = subprocess.run(command, cwd=PROJECT, capture_output=True)
        (destination / (scope + '.log')).write_bytes(execution.stdout + execution.stderr)
        rows.append(dict(scope=scope, exitCode=execution.returncode, command=command,
                         responseSha256=sha(response), originalResponseSha256=sha(original),
                         sources={str(p.relative_to(destination)): sha(p) for p in sources}))
        if execution.returncode:
            break
    report = dict(passed=len(rows) == 2 and all(r['exitCode'] == 0 for r in rows),
                  scope='Isolated managed Runtime/Editor compilation; no Unity, bundle generation, deployment or native behavior',
                  inputs=inputs, patchModes=patch_modes,
                  inputsUnchanged=all(sha(ROOT / name) == value for name, value in inputs.items()), checks=rows)
    (destination / 'report.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
    print(json.dumps(dict(passed=report['passed'], report=str(destination / 'report.json'))))
    raise SystemExit(0 if report['passed'] else 1)

if __name__ == '__main__':
    main()
