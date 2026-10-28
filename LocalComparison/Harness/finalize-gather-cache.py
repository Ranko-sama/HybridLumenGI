"""Provenance, source restoration and readable decoding for the one saved run."""
from pathlib import Path
import hashlib,json,collections,re
import numpy as np
root=Path(__file__).resolve().parents[2];out=root/'LocalComparison/Review/gather-cache-visibility-01';assets=Path('I:/Unity test/Project/Assets')
manifest=json.loads((out/'instrumentation/manifest.json').read_text(encoding='utf-8'));run=next((out/'A').glob('20*'))
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
checks=[]
for relative,expected in manifest['productSourceSha256'].items():
 local=root/relative;deployed=assets/'HybridLumenGI'/relative
 checks.append({'path':str(relative),'expected':expected,'workspace':sha(local),'deployed':sha(deployed),'pass':sha(local)==expected==sha(deployed)})
for key in ['feature','transport','kernels','wrapper','capture']:
 item=manifest['files'][key];checks.append({'path':item['path'],'expected':item['originalSha256'],'actual':sha(Path(item['path'])),'pass':sha(Path(item['path']))==item['originalSha256']})
for i,name in enumerate(['Comparison/Renderer.asset','Comparison/Pipeline.asset','ComparisonScene/Run/Validation.unity','ThinWallProbe/Static.unity']):
 expected=sha(out/f'instrumentation/asset-{i}.original.txt');actual=sha(assets/name);checks.append({'path':name,'expected':expected,'actual':actual,'pass':expected==actual})
for name,source in [('ThinWallEditor.cs',assets/'ComparisonHarness/Editor/ThinWallEditor.cs'),('ComparisonRunnerEditor.cs',assets/'ComparisonHarness/Editor/ComparisonRunnerEditor.cs')]:
 (out/'instrumentation'/(name+'.observed-after-run.txt')).write_bytes(source.read_bytes())
checks.append({'path':'ThinWallEditor.cs helper dependency','pass':sha(assets/'ComparisonHarness/Editor/ThinWallEditor.cs')==sha(root/'LocalComparison/Harness/ThinWallEditor.cs')})
current=json.loads((out/'A/scene-contract.json').read_text(encoding='utf-8'))
baseline=json.loads((root/'LocalComparison/Review/thin-wall-transport-01/retry-v3/A/scene-contract.json').read_text(encoding='utf-8'))
settings_equal=json.loads(current['featureJson'])['settings']==json.loads(baseline['featureJson'])['settings']
scene_checks={k:current[k]==baseline[k] for k in ['config','cameraPosition','cameraRotation','fov','aspect','ambientLight','ambientIntensity','ambientMode','skybox']}
scene_checks['settings']=settings_equal
scene_checks['lights']={v['name']:v for v in current['lights']}=={v['name']:v for v in baseline['lights']}
scene_checks['objects']={v['name']:v for v in current['objects']}=={v['name']:v for v in baseline['objects']}
frames=[json.loads(line) for line in (run/'frames.jsonl').read_text(encoding='utf-8').splitlines()]
frame_checks={'exactly120':len(frames)==120,'logicalSequence':[f['logicalFrame'] for f in frames]==list(range(120)),
 'allReportedExact':all(json.loads(f['diagnosticsJson'])['exactSoftwareGeometry'] and not json.loads(f['diagnosticsJson'])['hardwareBackend'] for f in frames)}
log=(out/'Unity-A.log').read_text(encoding='utf-8')
patterns=[r'error CS\d+',r'Shader error',r'Compute shader .* (?:invalid|failed)',r'Leak Detected',r'leaked \d+ .*Persistent',r'retirement.*(?:unresolved|timed out|owned=)',r'Gather (?:observer|stream|event|source|raw).*?(?:failed|mismatch|missing|overflow)',r'Device (?:removed|lost)',r'Comparison failed']
fail_signatures=[line for line in log.splitlines() if any(re.search(p,line,re.I) for p in patterns)]
receipt={'baseline':manifest['baseline'],'pid':1356,'exitCode':0,'execSession':58520,'finalExecChunk':'061f9d','singleRun':True,
 'command':"Start-Unity.ps1 -Batch -KeepRunning -LogName GatherCache01-A -ExecuteMethod GatherCacheEditor.Play -ExtraArguments '-comparisonFrames','120','-comparisonOutput','I:/Unity test/Comparison/Evidence/GatherCache01-A','-thinWallConfig','A','-gatherCacheProbe'",
 'nativeLogSha256':sha(out/'Unity-A.log'),'frameChecks':frame_checks,'sceneChecksAgainstPriorA':scene_checks,
 'nativeFailureSignatures':fail_signatures,'nativeScanScope':'No matching product allocation/shader/readback/backend/shutdown signatures. General Unity MemoryLeaks aggregate and licensing/info-queue startup warnings remain in full log; not whole-process leak acceptance.'}
(out/'source-restored.json').write_text(json.dumps({'passed':all(c['pass'] for c in checks),'checks':checks},indent=2),encoding='utf-8')
(out/'execution-receipt.json').write_text(json.dumps(receipt,indent=2),encoding='utf-8')
uint_rows={1:{1},21:{0,1,2},23:{0},31:{0,1,2},33:{0},40:{0},42:{0},45:{0,1,2},100:{4},110:{5},112:{2},113:{0,1,2},114:{0},120:{0}}
decoded=out/'decoded';decoded.mkdir(exist_ok=True);max_count=0
for path in sorted(run.glob('gather-*-events.bin')):
 data=np.frombuffer(path.read_bytes(),dtype='<u4').reshape(4,256,32)
 for lane in range(4):
  count=int(data[lane,0,1]);max_count=max(max_count,count);records=[]
  for row in data[lane,1:count]:
   code=int(row[0]);payload={}
   for j,key in enumerate('abcdefg'):
    values=row[4+j*4:8+j*4]
    if j in uint_rows.get(code,set()):payload[key]={'uint':values.tolist()}
    else:payload[key]={'float':[float(v) if np.isfinite(v) else str(v) for v in values.view('<f4')]}
   records.append({'code':code,'sequence':int(row[1]),'context':int(row[2]),'cacheCall':int(row[3]),**payload})
  (decoded/(path.stem+f'-lane{lane}.json')).write_text(json.dumps(records,indent=2,allow_nan=False),encoding='utf-8')
print(json.dumps({'sourceRestored':all(c['pass'] for c in checks),'sceneChecks':scene_checks,'frameChecks':frame_checks,'nativeFailureSignatures':fail_signatures,'maximumRecordsIncludingHeader':max_count}))
assert all(c['pass'] for c in checks) and all(scene_checks.values()) and all(frame_checks.values()) and not fail_signatures
