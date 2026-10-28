"""Compile staged C# through the real Unity Roslyn toolchain without starting Unity."""
import json, subprocess
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
PROJECT=Path('I:/Unity test/Project')
OUT=ROOT/'LocalComparison/Review/scene-radiometry-matched-baseline-03/instrumentation'
BUILD=OUT.parent/'preflight'
EDITOR=Path('I:/Unity test/Editor/6000.0.85f1/Editor/Data')
manifest=json.loads((OUT/'manifest.json').read_text(encoding='utf-8'))
sources={f['path']:str(OUT/f['prepared']).replace('\\','/') for f in manifest['files'] if f['path'].endswith('.cs')}
BUILD.mkdir(parents=True,exist_ok=True)
original=(PROJECT/'Library/Bee/artifacts/1900b0aE.dag/Assembly-CSharp.rsp').read_text(encoding='utf-8-sig')
lines=[];seen=set()
for line in original.splitlines():
    if line.startswith('-out:'):line='-out:"'+str(BUILD/'Assembly-CSharp.dll').replace('\\','/')+'"'
    elif line.startswith('-refout:'):line='-refout:"'+str(BUILD/'Assembly-CSharp.ref.dll').replace('\\','/')+'"'
    elif line.strip('"') in sources:
        path=line.strip('"');seen.add(path);line='"'+sources[path]+'"'
    lines.append(line)
for path in sources.keys()-seen:lines.append('"'+sources[path]+'"')
assert not any('/generatedfilesout:' in l or '-pdb:' in l or '/errorlog:' in l for l in lines), 'Review any added compiler output destination'
rsp=BUILD/'prospective.rsp';rsp.write_text('\n'.join(lines)+'\n',encoding='utf-8')
cmd=[str(EDITOR/'NetCoreRuntime/dotnet.exe'),str(EDITOR/'DotNetSdkRoslyn/csc.dll'),'@'+str(rsp)]
result=subprocess.run(cmd,cwd=PROJECT,capture_output=True,text=True,encoding='utf-8',errors='replace')
log=result.stdout+result.stderr;(BUILD/'compile.log').write_text(log,encoding='utf-8')
print(log);print('COMPILER_EXIT='+str(result.returncode));raise SystemExit(result.returncode)
