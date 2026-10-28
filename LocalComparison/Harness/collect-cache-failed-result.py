"""Archive the completed fixed-input run and its full native exit log."""
import argparse,hashlib,json,shutil
from pathlib import Path
from native_log_check import scan
p=argparse.ArgumentParser();p.add_argument('phase',choices=['baseline','fixed']);p.add_argument('--pid',type=int,required=True);p.add_argument('--exit-code',type=int,required=True);p.add_argument('--exec-chunk',required=True);a=p.parse_args()
root=Path(__file__).resolve().parents[2];out=root/'LocalComparison/Review/cache-failed-result-01'
name='CacheFailed01-'+a.phase.capitalize();source=Path('I:/Unity test/Comparison/Evidence')/name
assert not (out/a.phase).exists(),'Never overwrite prior execution'
shutil.copytree(source,out/a.phase)
log=out/(a.phase+'-Unity.log');shutil.copy2(Path('I:/Unity test/Logs')/(name+'.log'),log)
upm=Path('I:/Unity test/Logs')/(name+'-upm.log')
if upm.exists():shutil.copy2(upm,out/(a.phase+'-Unity-upm.log'))
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
manifest=json.loads((out/('source-'+a.phase)/'manifest.json').read_text(encoding='utf-8'));assets=Path('I:/Unity test/Project/Assets')
checks={relative:sha(root/relative)==expected==sha(assets/'HybridLumenGI'/relative) for relative,expected in manifest['productSourceSha256'].items()}
for filename,relative in [('CacheFailedResult.compute','ComparisonHarness/Resources/CacheFailedResult.compute'),('CacheFailedResultEditor.cs','ComparisonHarness/Editor/CacheFailedResultEditor.cs')]:
 checks[filename]=sha(assets/relative)==manifest['helperSha256'][filename]
for filename,expected in manifest['generatedSha256'].items():checks[filename]=sha(assets/'ComparisonHarness/Resources'/filename)==expected
receipt={'phase':a.phase,'pid':a.pid,'exitCode':a.exit_code,'execChunk':a.exec_chunk,'nativeLogSha256':sha(log),'nativeFailureSignatures':scan(log),'sourceChecks':checks,
 'command':'Start-Unity.ps1 -Batch -KeepRunning -LogName '+name+' -ExecuteMethod CacheFailedResultEditor.Run -ExtraArguments -cacheFailedOutput I:/Unity test/Comparison/Evidence/'+name,
 'outputSha256':{p.name:sha(p) for p in sorted((out/a.phase).glob('*')) if p.is_file()}}
(out/(a.phase+'-execution.json')).write_text(json.dumps(receipt,indent=2),encoding='utf-8')
print(json.dumps({'exitCode':a.exit_code,'sourceChecks':all(checks.values()),'nativeFailureSignatures':receipt['nativeFailureSignatures']}))
assert a.exit_code==0 and all(checks.values()) and not receipt['nativeFailureSignatures'],'Execution/source/native exit failed; stop before candidate changes'
