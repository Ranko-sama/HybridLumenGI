"""One old-source control and one candidate; no Unity/Player/GPU process."""
import hashlib,json,shutil,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'LocalComparison/Review/additive-chunk-multiview-demand-01'
FROZEN=OUT/'frozen'
EDITOR=Path('I:/Unity test/Editor/6000.0.85f1/Editor/Data')
PROJECT=Path('I:/Unity test/Project')
NAMES=['HybridLumenGIChunkStreaming','HybridLumenGIChunkStreamer','HybridLumenGIStreamingManifest']
FILES=['Tests/Validate-ChunkStreaming.ps1','Tests/StandaloneBvh/StreamingProgram.cs.txt',
       'Tests/StandaloneBvh/UnityStubs.cs.txt','Tests/StandaloneBvh/SceneDependencies.cs.txt',
       'Tests/StandaloneBvh/AssetPageStreamingChecks.cs.txt','Runtime/HybridLumenGIAssetPageStreaming.cs',
       'Documentation/Checkpoint-Iteration59.md','LocalComparison/Harness/run-additive-chunk-multiview.py']
def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def save(path,value):path.write_text(json.dumps(value,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
phase=sys.argv[1]
if phase=='freeze':
    FROZEN.mkdir(parents=True,exist_ok=False)
    for name in FILES+[f'Runtime/{n}.cs' for n in NAMES]:
        target=FROZEN/name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(ROOT/name,target)
    old=FROZEN/'old-ChunkStreaming.cs'
    old.write_bytes(subprocess.check_output(['git','show','3314a7f:Runtime/HybridLumenGIChunkStreaming.cs'],cwd=ROOT))
    original=(PROJECT/'Library/Bee/artifacts/1900b0aE.dag/Assembly-CSharp.rsp').read_text(encoding='utf-8-sig')
    refs=[line for line in original.splitlines() if line.startswith(('-r:','-define:','-langversion:','-nostdlib','-unsafe'))]
    rsp=OUT/'driver.rsp'
    rsp.write_text('\n'.join(['-target:library','-out:"'+(OUT/'ChunkDriver.dll').as_posix()+'"']+refs+['"'+(FROZEN/f'Runtime/{n}.cs').as_posix()+'"' for n in NAMES])+'\n',encoding='utf-8')
    save(OUT/'manifest.json',{'baselineCommit':'3314a7ffe48d11c20b3101fd7ee0acb8e999cf89','files':{p.relative_to(FROZEN).as_posix():digest(p) for p in FROZEN.rglob('*') if p.is_file()},'driverRspSha256':digest(rsp)})
    print('Frozen source, shared harness and fixed contract. No behavior executed.');sys.exit(0)
assert phase in ('baseline','candidate')
manifest=json.loads((OUT/'manifest.json').read_text(encoding='utf-8'))
for name,sha in manifest['files'].items():assert digest(FROZEN/name)==sha,name
for name in FILES+[f'Runtime/{n}.cs' for n in NAMES]:assert digest(ROOT/name)==manifest['files'][name],name
assert digest(OUT/'driver.rsp')==manifest['driverRspSha256']
run=OUT/phase;run.mkdir(exist_ok=False)
source=FROZEN/('old-ChunkStreaming.cs' if phase=='baseline' else 'Runtime/HybridLumenGIChunkStreaming.cs')
command=['powershell.exe','-NoProfile','-ExecutionPolicy','Bypass','-File',str(FROZEN/'Tests/Validate-ChunkStreaming.ps1'),'-SourceRoot',str(FROZEN),'-ChunkSource',str(source),'-ChunkMultiviewOnly']
if phase=='baseline':command+=['-ExpectSingleObserver']
result=subprocess.run(command,cwd=ROOT,capture_output=True,text=True,encoding='utf-8',errors='replace')
(run/'behavior.log').write_text(result.stdout+result.stderr,encoding='utf-8')
save(run/'behavior-execution.json',{'command':command,'exitCode':result.returncode,'sourceSha256':digest(source)})
print(phase+' behavior exit='+str(result.returncode))
if result.returncode:print(result.stdout+result.stderr);sys.exit(result.returncode)
data=json.loads(next(line for line in result.stdout.splitlines() if line.startswith('{"mode":')))
save(run/'result.json',data)
if phase=='candidate':
    baseline=json.loads((OUT/'baseline/result.json').read_text(encoding='utf-8'))
    assert baseline['legacyControls']==data['legacyControls'],'Legacy single-position control changed'
    assert baseline['external']==data['external'],'External ownership control changed'
    command=[str(EDITOR/'NetCoreRuntime/dotnet.exe'),str(EDITOR/'DotNetSdkRoslyn/csc.dll'),'@'+str(OUT/'driver.rsp')]
    compile_result=subprocess.run(command,cwd=PROJECT,capture_output=True,text=True,encoding='utf-8',errors='replace')
    (run/'driver-compile.log').write_text(compile_result.stdout+compile_result.stderr,encoding='utf-8')
    save(run/'driver-compile-execution.json',{'command':command,'exitCode':compile_result.returncode})
    print('Actual full driver/state/manifest Unity-reference compilation exit='+str(compile_result.returncode))
    if compile_result.returncode:print(compile_result.stdout+compile_result.stderr);sys.exit(compile_result.returncode)
    save(run/'qualification.json',{'auxiliaryColdLoad':True,'legacyControlsByteIdentical':True,'externalControlByteIdentical':True,'fullDriverCompiled':True,'driverTransformExecution':False,'nativeSceneIO':False,'unityPlayerGpuRuns':0})
print('PASS finite '+phase+'; original logs retained.')
