"""Offline, evidence-based lifecycle qualification; never rewrites frozen results."""
import argparse,copy,hashlib,json,struct
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
PACKAGE=ROOT/'LocalComparison/Review/scene-lightoff-chain-02'
RUN=PACKAGE/'run/20261028-041010-d14728cf2da7410cbc7a56be035c20f6'
READY=119;OFF=120;SAMPLES=[119,120,121,123,127,135,151,239,359]
sha=lambda data:hashlib.sha256(data).hexdigest()
read=lambda p:json.loads(p.read_text(encoding='utf-8-sig'))
lines=lambda p:[json.loads(line) for line in p.read_text(encoding='utf-8').splitlines()]
def packed(light):
 return struct.pack('<16f4I',*[light[key][component] for key in ['positionType','directionRange','color','spot'] for component in 'xyzw'],*[light[key] for key in ['cullingMask','renderingLayers','shadowRenderingLayers','flags']])
def identity(p):return tuple(p[k] for k in ['entry','card','slot','stableId','revision','generation','layout','chart','cellX','cellY'])

def load():
 expected=read(PACKAGE/'execution.json')['outputSha256'];provenance={}
 def raw(path):
  data=path.read_bytes();key=str(path.relative_to(PACKAGE/'run'));actual=sha(data)
  if expected.get(key)!=actual:raise ValueError('Frozen source hash mismatch: '+key)
  provenance[key]=actual;return data
 def obj(path):return json.loads(raw(path))
 def rows(path):return [json.loads(line) for line in raw(path).decode('utf-8').splitlines()]
 commands=rows(RUN/'lightoff-commands.jsonl');bindings=rows(RUN/'lightoff-bindings.jsonl')
 lights=rows(RUN/'lightoff-lights.jsonl');receipts=rows(RUN/'lightoff-receipts.jsonl')
 frames=[]
 for n in range(360):
  s=obj(RUN/f'lightoff-schedule-{n:04d}.json');cache=raw(RUN/f'lightoff-{n:04d}-cache-observed.bin')
  r=[x for x in receipts if x['logicalFrame']==n];receipt_stages=[x['stage'] for x in r]
  for receipt in r:
   payload=raw(RUN/f"lightoff-{n:04d}-{receipt['stage']}.bin")
   if len(payload)!=receipt['bytes']:raise ValueError('Receipt size mismatch')
  frames.append({'n':n,'commands':[v for v in commands if v['logicalFrame']==n],
   'bindings':[v for v in bindings if v['logicalFrame']==n],'phases':[v for v in lights if v['logicalFrame']==n],
   's':{k:s[k] for k in ['giFrame','tick','readBuffer','writeBuffer','epoch','aliases','patches']},
   'receiptStages':receipt_stages,'receiptGI':[v['giFrame'] for v in r],
   'gpuLights':raw(RUN/f'lightoff-{n:04d}-gpu-lights.bin'),
   'old':[cache[lane*320:lane*320+80] for lane in range(2)],
   'new':[cache[lane*320+80:lane*320+160] for lane in range(2)],
   'headers':[struct.unpack_from('<4I',cache,lane*320+288) for lane in range(2)],
   'actual':[raw(RUN/f'lightoff-{n:04d}-cache-actual-{lane}.bin') for lane in range(2)]})
 return {'frames':frames,'warmup':obj(RUN/'lightoff-warmup119.json'),'lightSummary':obj(RUN/'lightoff-summary.json'),
  'gatherSummary':obj(RUN/'gather-summary.json'),'run':obj(RUN/'run.json'),'original':read(PACKAGE/'analysis.json'),'inputHashes':provenance}

def qualify(model):
 issues=[];initial=[];continuous=False;previous=None;ready_identity=None;ready_alias=None;startup_records=None;startup_light=None
 def check(ok,code,n=None):
  if not ok:issues.append({'code':code,'frame':n})
 check(len(model['frames'])==360,'complete-frames')
 check(model['run']['renderedFrames']==360 and model['run']['errors']==0,'native-observation-complete')
 check(model['warmup']['passed'] and model['lightSummary']['passed'] and model['gatherSummary']['passed'],'observer-summary')
 check(not model['lightSummary']['missing'] and not model['gatherSummary']['missing'],'missing-observer-summary')
 for index,f in enumerate(model['frames']):
  n=f['n'];check(n==index,'ordered-frame',n);s=f['s'];check(len(f['commands'])==len(f['bindings'])==1,'unique-control-binding',n)
  phases={p['phase']:p for p in f['phases']};check(len(f['phases'])==len(phases)==3 and set(phases)=={'before-update','after-update','uploaded-domains'},'unique-light-phases',n)
  if len(f['commands'])!=1 or len(f['bindings'])!=1 or set(phases)!={'before-update','after-update','uploaded-domains'}:continue
  cmd=f['commands'][0];binding=f['bindings'][0];before=phases['before-update'];after=phases['after-update'];upload=phases['uploaded-domains']
  expected_stages={'gpu-mask','gpu-lights','gpu-changes','gpu-proposals','cache-observed','cache-actual-0','cache-actual-1'}
  if n in SAMPLES:expected_stages|={'raw','history','filtered'}
  check(set(f['receiptStages'])==expected_stages and len(f['receiptStages'])==len(expected_stages),'required-receipts',n)
  check(all(v==s['giFrame'] for v in f['receiptGI']),'receipt-work-frame',n)
  check(len(s['patches'])==2 and s['aliases']==[0,0,1,1] and len({p['entry'] for p in s['patches']})==2,'unique-patch-aliases',n)
  check(all(f['headers'][lane]==(p['entry'],n,s['giFrame'],0x4c4f3031) for lane,p in enumerate(s['patches'])),'cache-header',n)
  check(f['new']==f['actual'],'cache-actual-correspondence',n)
  check([binding[k] for k in ['giFrame','cacheRead','cacheWrite','gatherRead']]==[s['giFrame'],s['readBuffer'],s['writeBuffer'],s['writeBuffer']] and binding['distinct'] and binding['exact'] and s['writeBuffer']==1-s['readBuffer'],'actual-buffer-provenance',n)
  check(cmd['enabled']==(n<OFF) and all(p['lampEnabled']==cmd['enabled'] and p['lampInstance']==cmd['lampInstance'] for p in phases.values()),'controlled-light-identity-enabled',n)
  if startup_light is None:startup_light=cmd
  check(all(cmd[k]==startup_light[k] for k in ['lampInstance','lampPosition','cameraPosition','doorPosition']),'fixed-controller-source',n)
  count=int(n<OFF);check(after['count']==len(after['records'])==upload['count']==binding['lightCount']==count,'effective-light-count',n)
  check(f['gpuLights'][:80*count]==b''.join(packed(r) for r in after['records']),'effective-gpu-light-bytes',n)
  check(upload['records']==after['records'],'uploaded-light-records',n)
  ids=[identity(p) for p in s['patches']]
  evidence={'emptyPrevious':before['count']==before['previousCount']==0 and not before['records'],
   'discoveryEqualsCurrent':after['changes']==after['records'] and bool(after['records']),
   'initialCounters':s['giFrame']==0 and s['tick']==1 and s['readBuffer']==0,
   'zeroFullOldCache':all(not any(value) for value in f['old'])}
  looks_initial=all(evidence.values())
  if not continuous and n<READY and looks_initial:
   current=tuple(packed(r) for r in after['records'])
   if startup_records is None:startup_records=current
   check(current==startup_records,'unchanged-initial-source',n)
   check(all(r['positionType'][k]==cmd['lampPosition'][k] for r in after['records'] for k in 'xyz'),'initial-source-position',n)
   initial.append({'frame':n,'evidence':evidence,'sameStartupSource':current==startup_records,'exactLifecycleCauseProven':False})
  else:
   continuous=True
   check(previous is not None,'continuous-predecessor',n)
   if previous is not None:
    ps=previous['s'];pa=next(v for v in previous['phases'] if v['phase']=='after-update')
    check(s['giFrame']==ps['giFrame']+1 and s['tick']==ps['tick']+1 and s['readBuffer']==ps['writeBuffer'],'continuous-state-not-reset',n)
    check(before['count']==before['previousCount']==pa['count'] and before['records']==pa['records'],'continuous-old-light-snapshot',n)
    for lane,p in enumerate(s['patches']):
     if identity(p)==identity(ps['patches'][lane]):check(f['old'][lane]==previous['new'][lane],'continuous-cache-read',n)
   if n==OFF:
    check(before['count']==1 and after['count']==0 and after['changes']==before['records'],'physical-light-removal',n)
   else:check(not after['changes'],'no-extra-continuous-source-event',n)
  if n==READY:ready_identity=ids;ready_alias=s['aliases']
  if n>=READY:
   check(continuous and ids==ready_identity and s['aliases']==ready_alias,'ready-identity-continuity',n)
   check(all(p['ready'] and p['published'] for p in s['patches']),'ready-patches',n)
   domains=upload['domains'];check(domains['globalGeometry']==0 and domains['globalLighting']==0,'ready-global-domain',n)
   if n==OFF:
    check(domains['count']==1,'single-local-removal-domain',n)
    if domains['count']==1:
     region=domains['regions'][0];check([region['minimum'][k] for k in 'xyzw']==[3,-3,-3,0] and [region['maximum'][k] for k in 'xyzw']==[13,7,7,18],'local-removal-bounds',n)
   elif n>OFF:check(domains['count']==0,'no-repeated-domain',n)
  previous=f
 startup={row['frame'] for row in initial if row['sameStartupSource']}
 unexplained=[v for v in model['original']['failures'] if not(v['check']=='no other source event' and v.get('frame') in startup)]
 check(not unexplained,'original-nonstartup-assertions')
 return {'originalFrozenPass':model['original']['passed'],'initializationCandidates':initial,'exactLifecycleCauseProven':False,
  'stableTestedInterval':[READY,359],'stableTestedIntervalQualified':not issues,'issues':issues,'unexplainedFrozenFailures':unexplained,
  'overallAccepted':False,'uncovered':['Exact Feature/CameraState recreation identity/caller','Complete startup lifecycle acceptance','Independent scene energy and production acceptance'],
  'scope':'New offline qualification of existing evidence only; original frozen failure is unchanged. Initialization phase never reopens after continuous propagation.'}

def negative_controls(model):
 original=qualify(model);restart=original['initializationCandidates'][-1]['frame'];cases=[]
 def test(name,mutate,expected):
  changed=copy.deepcopy(model);mutate(changed);result=qualify(changed)
  codes={item['code'] for item in result['issues']};cases.append({'name':name,'rejected':not result['stableTestedIntervalQualified'],'expectedCode':expected,'semanticCodes':sorted(codes),'passed':expected in codes})
 def source(m):
  f=m['frames'][restart];phases={p['phase']:p for p in f['phases']}
  for phase in ['after-update','uploaded-domains']:
   phases[phase]['records'][0]['color']['x']+=1
  phases['after-update']['changes']=copy.deepcopy(phases['after-update']['records'])
  f['gpuLights']=packed(phases['after-update']['records'][0])+f['gpuLights'][80:]
 test('changed-light-despite-empty-old-count',source,'unchanged-initial-source')
 def reset(m,n):
  f=m['frames'][n];f['s'].update(giFrame=0,tick=1,readBuffer=0,writeBuffer=1);f['old']=[bytes(80),bytes(80)]
  before=next(p for p in f['phases'] if p['phase']=='before-update');before.update(count=0,previousCount=0,records=[])
  after=next(p for p in f['phases'] if p['phase']=='after-update');after['changes']=copy.deepcopy(after['records'])
 test('reset-after-continuity',lambda m:reset(m,READY-1),'continuous-state-not-reset')
 test('reset-after-readiness',lambda m:reset(m,OFF+1),'continuous-state-not-reset')
 def extra(m):
  row=next(p for p in m['frames'][OFF+1]['phases'] if p['phase']=='after-update');row['changes']=copy.deepcopy(next(p for p in model['frames'][0]['phases'] if p['phase']=='after-update')['records'])
 test('extra-continuous-source-event',extra,'no-extra-continuous-source-event')
 test('missing-required-receipt',lambda m:m['frames'][READY]['receiptStages'].remove('cache-actual-0'),'required-receipts')
 def remove(m):next(p for p in m['frames'][OFF]['phases'] if p['phase']=='after-update')['changes'].clear()
 test('missing-real-removal',remove,'physical-light-removal')
 return cases

if __name__=='__main__':
 parser=argparse.ArgumentParser();parser.add_argument('--output',type=Path,required=True);args=parser.parse_args()
 protected=[PACKAGE/'analysis.json',PACKAGE/'summary.json',PACKAGE/'instrumentation/contract.executed.md']
 before={str(p.relative_to(ROOT)):sha(p.read_bytes()) for p in protected}
 model=load();result=qualify(model);result['negativeControls']=negative_controls(model)
 result['originalArtifactHashes']=before;result['originalArtifactsUnchanged']=all(sha(p.read_bytes())==before[str(p.relative_to(ROOT))] for p in protected)
 result['inputHashes']=model['inputHashes'];result['negativeControlsPassed']=all(c['passed'] and c['rejected'] for c in result['negativeControls'])
 args.output.parent.mkdir(parents=True,exist_ok=True);args.output.write_text(json.dumps(result,indent=2),encoding='utf-8')
 print(json.dumps({k:result[k] for k in ['originalFrozenPass','initializationCandidates','stableTestedIntervalQualified','exactLifecycleCauseProven','issues','negativeControls','originalArtifactsUnchanged']}))
 raise SystemExit(0 if result['stableTestedIntervalQualified'] and result['negativeControlsPassed'] and result['originalArtifactsUnchanged'] else 1)
