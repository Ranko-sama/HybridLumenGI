"""Compile the staged observer once through Unity Roslyn; no Editor or Player launch."""
import json,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];PROJECT=Path('I:/Unity test/Project');EDITOR=Path('I:/Unity test/Editor/6000.0.85f1/Editor/Data')
PACKAGE=ROOT/'LocalComparison/Review/local-release-baseline-01';OUT=PACKAGE/'preflight';STAGE=PACKAGE/'instrumentation'
if '--steady' in sys.argv:PACKAGE=ROOT/'LocalComparison/Review/local-release-steady-use-01';OUT=PACKAGE/'preflight';STAGE=PACKAGE/'instrumentation'
if '--integration' in sys.argv:PACKAGE=ROOT/'LocalComparison/Review/current-release-integration-01';OUT=PACKAGE/'preflight';STAGE=PACKAGE/'instrumentation'
if '--final-image' in sys.argv:PACKAGE=ROOT/'LocalComparison/Review/current-representative-final-image-01';OUT=PACKAGE/'preflight';STAGE=PACKAGE/'instrumentation'
if '--navigation' in sys.argv:PACKAGE=ROOT/'LocalComparison/Review/local-release-navigation-01';OUT=PACKAGE/'preflight';STAGE=PACKAGE/'instrumentation'
if '--auxiliary' in sys.argv:PACKAGE=ROOT/'LocalComparison/Review/asset-page-auxiliary-cold-bind-01';OUT=PACKAGE/'preflight';STAGE=PACKAGE/'instrumentation'
if '--light-move' in sys.argv:PACKAGE=ROOT/'LocalComparison/Review/local-light-move-response-01';OUT=PACKAGE/'preflight';STAGE=PACKAGE/'instrumentation'
manifest=json.loads((STAGE/'manifest.json').read_text(encoding='utf-8'))
sources={f['path']:(STAGE/f['prepared']).as_posix() for f in manifest['files'] if f['path'].endswith('.cs') and '/Editor/' not in f['path']}
original=(PROJECT/'Library/Bee/artifacts/1900b0aE.dag/Assembly-CSharp.rsp').read_text(encoding='utf-8-sig');lines=[];seen=set();removed=[]
for line in original.splitlines():
    if line.strip('"').endswith('.cs') and line.strip('"') not in sources and not (PROJECT/line.strip('"')).exists():
        assert not (PROJECT/line.strip('"')).exists();removed.append(line.strip('"'));continue
    if line.startswith('-out:'):line='-out:"'+(OUT/'Assembly-CSharp.dll').as_posix()+'"'
    elif line.startswith('-refout:'):line='-refout:"'+(OUT/'Assembly-CSharp.ref.dll').as_posix()+'"'
    elif line.strip('"') in sources:
        path=line.strip('"');seen.add(path);line='"'+sources[path]+'"'
    lines.append(line)
for path in sorted(sources.keys()-seen):lines.append('"'+sources[path]+'"')
assert not any('/generatedfilesout:' in l or '-pdb:' in l or '/errorlog:' in l for l in lines)
OUT.mkdir(parents=True,exist_ok=True);rsp=OUT/'prospective.rsp';rsp.write_text('\n'.join(lines)+'\n',encoding='utf-8')
(OUT/'removed-restored-prior-observers.json').write_text(json.dumps(removed,indent=2),encoding='utf-8')
result=subprocess.run([str(EDITOR/'NetCoreRuntime/dotnet.exe'),str(EDITOR/'DotNetSdkRoslyn/csc.dll'),'@'+str(rsp)],cwd=PROJECT,capture_output=True,text=True,encoding='utf-8',errors='replace')
attempt=len(list(OUT.glob('managed-*.log')))+1;(OUT/f'managed-{attempt}.log').write_text(result.stdout+result.stderr,encoding='utf-8')
print(result.stdout+result.stderr);print('COMPILER_EXIT='+str(result.returncode));raise SystemExit(result.returncode)
