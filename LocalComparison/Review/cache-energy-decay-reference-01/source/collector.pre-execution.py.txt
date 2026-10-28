"""Archive the one completed native batch, preserving logs and frozen sources."""
import argparse,hashlib,json,shutil
from pathlib import Path
from native_log_check import scan
p=argparse.ArgumentParser();p.add_argument('--pid',required=True,type=int);p.add_argument('--exit-code',required=True,type=int);p.add_argument('--exec-chunk',required=True);a=p.parse_args()
root=Path(__file__).resolve().parents[2];out=root/'LocalComparison/Review/cache-energy-decay-reference-01';name='CacheEnergy01'
assert not (out/'run').exists(),'Never overwrite prior execution'
shutil.copytree(Path('I:/Unity test/Comparison/Evidence')/name,out/'run')
log=out/'Unity.log';shutil.copy2(Path('I:/Unity test/Logs')/(name+'.log'),log)
upm=Path('I:/Unity test/Logs')/(name+'-upm.log')
if upm.exists():shutil.copy2(upm,out/'Unity-upm.log')
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
manifest=json.loads((out/'source/manifest.json').read_text(encoding='utf-8'));assets=Path('I:/Unity test/Project/Assets')
checks={relative:sha(root/relative)==expected==sha(assets/'HybridLumenGI'/relative) for relative,expected in manifest['productSourceSha256'].items()}
for filename,relative in [('CacheEnergyDecay.compute','ComparisonHarness/Resources/CacheEnergyDecay.compute'),('CacheEnergyDecayEditor.cs','ComparisonHarness/Editor/CacheEnergyDecayEditor.cs')]:
    checks[filename]=sha(assets/relative)==manifest['helperSha256'][filename]
for filename,expected in manifest['generatedSha256'].items():checks[filename]=sha(assets/'ComparisonHarness/Resources'/filename)==expected
checks['reference']=sha(out/'reference.json')==manifest['referenceSha256']
hits=scan(log)
for number,line in enumerate(log.read_text(encoding='utf-8').splitlines(),1):
    if 'CACHE_ENERGY_OBSERVER_FAILED' in line:hits.append({'category':'energy-observer','line':number,'text':line})
receipt={'pid':a.pid,'exitCode':a.exit_code,'execChunk':a.exec_chunk,'nativeLogSha256':sha(log),'nativeFailureSignatures':hits,'sourceChecks':checks,
    'command':'Start-Unity.ps1 -Batch -KeepRunning -LogName CacheEnergy01 -ExecuteMethod CacheEnergyDecayEditor.Run -ExtraArguments -cacheEnergyOutput I:/Unity test/Comparison/Evidence/CacheEnergy01',
    'outputSha256':{p.name:sha(p) for p in sorted((out/'run').glob('*')) if p.is_file()}}
(out/'execution.json').write_text(json.dumps(receipt,indent=2),encoding='utf-8')
print(json.dumps({'exitCode':a.exit_code,'sourceChecks':all(checks.values()),'nativeFailureSignatures':hits}))
assert a.exit_code==0 and all(checks.values()) and not hits,'Stop on native execution/source/exit failure'
