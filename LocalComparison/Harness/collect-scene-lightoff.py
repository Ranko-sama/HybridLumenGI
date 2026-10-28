"""Archive once before restoration, including failure and serialized execution inputs."""
import argparse,hashlib,json,shutil
from pathlib import Path
from native_log_check import scan
p=argparse.ArgumentParser();p.add_argument('--pid',required=True,type=int);p.add_argument('--exit-code',required=True,type=int);p.add_argument('--exec-chunk',required=True);a=p.parse_args()
root=Path(__file__).resolve().parents[2];out=root/'LocalComparison/Review/scene-lightoff-chain-02';project=Path('I:/Unity test/Project');name='SceneLightoff02'
assert not (out/'run').exists(),'Never overwrite a physical execution'
source=Path('I:/Unity test/Comparison/Evidence')/name
if source.exists():shutil.copytree(source,out/'run')
else:(out/'run').mkdir()
log=out/'Unity.log';shutil.copy2(Path('I:/Unity test/Logs')/(name+'.log'),log)
upm=Path('I:/Unity test/Logs')/(name+'-upm.log')
if upm.exists():shutil.copy2(upm,out/'Unity-upm.log')
sha=lambda path:hashlib.sha256(path.read_bytes()).hexdigest()
manifest=json.loads((out/'instrumentation/manifest.json').read_text(encoding='utf-8'));checks={}
for key,item in manifest['files'].items():checks[key]=sha(Path(item['path']))==item['instrumentedSha256']
for key,item in manifest['helpers'].items():checks[key]=sha(Path(item['path']))==item['sha256']
for relative,expected in manifest['productSourceSha256'].items():checks['workspace/'+relative]=sha(root/relative)==expected
archive=out/'run/executed-assets';executed={p.name:sha(p) for p in archive.glob('*') if p.is_file()}
hits=scan(log)
for number,line in enumerate(log.read_text(encoding='utf-8').splitlines(),1):
 if 'SCENE_LIGHTOFF_OBSERVER_FAILED' in line:hits.append({'category':'lightoff-observer','line':number,'text':line})
receipt={'pid':a.pid,'exitCode':a.exit_code,'execChunk':a.exec_chunk,'singleProcess':True,'nativeLogSha256':sha(log),
 'sourceChecksBeforeRestore':checks,'executedAssetSha256':executed,'nativeFailureSignatures':hits,
 'command':"Start-Unity.ps1 -Batch -KeepRunning -LogName SceneLightoff02 -ExecuteMethod SceneLightoffEditor.Play -ExtraArguments -thinWallConfig C -comparisonMode final -comparisonFrames 360 -comparisonOutput I:/Unity test/Comparison/Evidence/SceneLightoff02 -sceneLightoffProbe -gatherCacheProbe",
 'outputSha256':{str(p.relative_to(out/'run')):sha(p) for p in sorted((out/'run').rglob('*')) if p.is_file()}}
(out/'execution.json').write_text(json.dumps(receipt,indent=2),encoding='utf-8')
print(json.dumps({'exitCode':a.exit_code,'sourceChecks':all(checks.values()),'executedAssets':len(executed),'nativeFailureSignatures':hits}))
assert a.exit_code==0 and all(checks.values()) and len(executed)==8 and not hits,'Native/source/exit failure: preserve and return to review, no rerun'
