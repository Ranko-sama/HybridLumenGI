"""Compile the same Runtime/Host against the actual failed Player response and Player API."""
import hashlib
import json
from pathlib import Path
import subprocess

P = Path(__file__).resolve().parent
ROOT = P.parents[2]
PROJECT = Path('I:/Unity test/Project')
EDITOR = Path('I:/Unity test/Editor/6000.0.85f1/Editor/Data')
STAGE = P/'instrumentation-game-exit'
DEST = P/'preflight-player'
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
assert not DEST.exists(), 'Preserve the first Player compilation'
manifest = json.loads((STAGE/'manifest.json').read_text())
original = PROJECT/'Library/Bee/artifacts/1900b0aP.dag/Assembly-CSharp.rsp'
source = original.read_text(encoding='utf-8-sig').splitlines()
assert not any(line in ('-define:UNITY_EDITOR','-define:UNITY_EDITOR_WIN') for line in source)
replacements = {r['path']:STAGE/r['prepared'] for r in manifest['files'] if r['path'].endswith('.cs') and '/Editor/' not in r['path']}
pins = {str(original):sha(original), str(STAGE/'manifest.json'):sha(STAGE/'manifest.json')}
for row in manifest['files']:
    assert sha(STAGE/row['prepared']) == row['sha256']
for name, digest in manifest['productSourceSha256'].items():
    for path in (ROOT/name, PROJECT/'Assets/HybridLumenGI'/name):
        assert sha(path) == digest; pins[str(path)] = digest
DEST.mkdir(); lines = []; used = set(); removed = []
for line in source:
    path = line.strip('"')
    if path.endswith('.cs'):
        if path in replacements: line = '"'+replacements[path].as_posix()+'"'; used.add(path)
        elif not (PROJECT/path).exists(): removed.append(path); continue
        else: pins[str(PROJECT/path)] = sha(PROJECT/path)
    if line.startswith('-out:'): line = '-out:"'+(DEST/'Assembly-CSharp.dll').as_posix()+'"'
    elif line.startswith('-refout:'): line = '-refout:"'+(DEST/'Assembly-CSharp.ref.dll').as_posix()+'"'
    assert not any(flag in line for flag in ('/generatedfilesout:', '-pdb:', '/errorlog:', '/doc:'))
    lines.append(line)
lines += ['"'+p.as_posix()+'"' for name,p in replacements.items() if name not in used]
for path in replacements.values(): pins[str(path)] = sha(path)
response = DEST/'Assembly-CSharp.rsp'; response.write_text('\n'.join(lines)+'\n', encoding='utf-8')
command = [str(EDITOR/'NetCoreRuntime/dotnet.exe'), str(EDITOR/'DotNetSdkRoslyn/csc.dll'), '@'+str(response)]
result = subprocess.run(command, cwd=PROJECT, capture_output=True)
(DEST/'compiler.log').write_bytes(result.stdout+result.stderr)
unchanged = all(sha(Path(path)) == value for path,value in pins.items())
report = dict(passed=result.returncode==0 and unchanged, exitCode=result.returncode, inputsUnchanged=unchanged,
    scope='Actual non-Editor Windows Player API compilation; no Player execution or bundle success claim',
    originalResponse=str(original), originalResponseSha256=sha(original), responseSha256=sha(response),
    command=command, removedStaleSources=removed, inputSha256=pins)
(DEST/'report.json').write_text(json.dumps(report,indent=2)+'\n', encoding='utf-8')
print((result.stdout+result.stderr).decode('utf-8',errors='replace'))
print(json.dumps(dict(passed=report['passed'],exitCode=result.returncode)))
raise SystemExit(0 if report['passed'] else 1)
