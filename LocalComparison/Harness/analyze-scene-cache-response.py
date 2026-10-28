"""Conditional double-precision response from archived actual GPU inputs only."""
import argparse,collections,hashlib,json,math
from pathlib import Path
import numpy as np

ROOT=Path(__file__).resolve().parents[2]
SOURCE=ROOT/'LocalComparison/Review/scene-lightoff-chain-02'
RUN=SOURCE/'run/20261028-041010-d14728cf2da7410cbc7a56be035c20f6'
READY=119;OFF=120;SAMPLES=[119,120,121,123,127,135,151,239,359]
GAMMA=32*2**-24/(1-32*2**-24)
read=lambda p:json.loads(p.read_text(encoding='utf-8-sig'))
sha=lambda b:hashlib.sha256(b).hexdigest()
def identity(p):return tuple(p[k] for k in ['entry','card','slot','stableId','revision','generation','layout','chart','cellX','cellY'])

def analyze():
 manifest=read(SOURCE/'execution.json')['outputSha256'];hashes={};issues=[]
 def raw(path):
  data=path.read_bytes();key=str(path.relative_to(SOURCE/'run'));digest=sha(data)
  if manifest.get(key)!=digest:raise ValueError('Frozen input hash mismatch: '+key)
  hashes[key]=digest;return data
 def obj(path):return json.loads(raw(path))
 def binary(n,stage,dtype='<f4'):return np.frombuffer(raw(RUN/f'lightoff-{n:04d}-{stage}.bin'),dtype=dtype)
 def check(ok,code,n=None,lane=None):
  if not ok:issues.append({'code':code,'frame':n,'lane':lane})
 frozen=read(SOURCE/'analysis.json');decoded={(r['frame'],r['lane']):r for r in frozen['cache']}
 states={};rows=[];fairness=[];counts=collections.Counter();signature=None;segment_start=None;off_tick=None
 for n in range(360):
  s=obj(RUN/f'lightoff-schedule-{n:04d}.json');mask=binary(n,'gpu-mask','<u4')
  values=binary(n,'cache-observed').reshape(4,20,4).astype(float)
  bits=binary(n,'cache-observed','<u4').reshape(4,20,4)
  check(np.array_equal(mask,s['cpuMask']),'actual-mask',n)
  candidates=s['candidates'];N=s['valid'];budget=s['effectiveBudget'];quota=min(budget,(budget+3)//4)
  check(len(candidates)==N and len({c['entry'] for c in candidates})==N and sum(s['cpuMask'])==s['selected']==budget and s['fairness']==quota,'budget-quota',n)
  oldest=sorted(candidates,key=lambda c:(c['previousService'],c['entry']))[:quota]
  check(all(c['selected']==1 for c in oldest),'oldest-selected',n)
  check(all(c['newService']==(s['tick'] if c['selected'] else c['previousService']) and c['selected']==int(mask[c['entry']]!=0) for c in candidates),'service-clocks-and-mask',n)
  owners={o['slot']:o for o in s['owners']};ids=[]
  for c in candidates:
   card=c['entry']//(s['patchGrid']**2);slot=s['cardOwners'][card];owner=owners[slot]
   ids.append((c['entry'],slot,owner['stableId'],owner['revision'],owner['layout'],s['cardGenerations'][card]))
  current=(tuple(sorted(ids)),budget)
  if current!=signature:signature=current;segment_start=s['tick']
  bound=math.ceil(N/quota) if quota else None
  age=max((s['tick']-c['newService'] for c in candidates),default=0)
  check(age==s['maxAge'],'actual-max-service-age',n)
  mature=bound is not None and s['tick']-segment_start>=bound
  if mature:check(age<=bound,'stable-service-bound',n)
  fairness.append({'frame':n,'tick':s['tick'],'candidates':N,'budget':budget,'oldestQuota':quota,'maxServiceAge':age,'bound':bound,'stableSegmentMature':mature})
  if n==OFF:off_tick=s['tick']
  for lane,p in enumerate(s['patches']):
   v=values[lane];u=bits[lane];old=v[:5];new=v[5:10];prepared=v[10];change=v[12];estimate=v[13];status=v[16];params=v[17]
   actual=binary(n,'cache-actual-'+str(lane)).reshape(5,4)
   check(np.array_equal(u[18],[p['entry'],n,s['giFrame'],0x4c4f3031]) and np.array_equal(new,actual),'cache-provenance',n,lane)
   check(np.all(np.isfinite(v)),'finite-record',n,lane)
   d=decoded.get((n,lane));check(d is not None,'decoded-record-present',n,lane)
   if d is not None:
    for key,record in [('old',old[0]),('prepared',prepared),('estimateSum',estimate[:3]),('new',new[0]),('change',change[:2])]:check(np.array_equal(record,d[key]),'frozen-decoded-'+key,n,lane)
   attempted=bool(change[3]);committed=bool(status[1]);known=bool(estimate[3]);covered=bool(status[0])
   kind='uncovered' if not covered else 'committed' if committed else 'unscheduled' if not attempted else 'attempted-unknown' if not known else 'attempted-uncommitted'
   counts[kind]+=1
   check(bool(mask[p['entry']])==attempted and change[2]==mask[p['entry']],'attempt-actual-mask',n,lane)
   check(not committed or (attempted and known),'commit-valid-attempt',n,lane)
   row={'frame':n,'tick':s['tick'],'lane':lane,'entry':p['entry'],'kind':kind,'reactive':bool(change[1]>.5),'oldSamples':old[0,3],'preparedSamples':prepared[3],'newSamples':new[0,3],'actual':new[0,:3].tolist(),'rayCount':params[3],'estimateSum':estimate[:3].tolist(),'knownDirectMaxAbs':v[15,:3].tolist(),'knownDirectCalls':v[15,3]}
   if n==READY:
    check(covered and new[0,3]>0,'ready-measurement',n,lane)
    states[lane]={'identity':identity(p),'epoch':s['epoch'],'base':new[0,:3].copy(),'A':1.,'B':np.zeros(3),'error':np.zeros(3),'previous':new[0].copy(),'active':True,'commits':[],'attempts':[]}
   elif n>READY:
    st=states[lane]
    hard=identity(p)!=st['identity'] or s['epoch']!=st['epoch'] or change[0]>.5 or not covered or not np.array_equal(old[1],new[1]) or old[0,3]<=0
    if hard:
     st['active']=False;row['segmentEnded']='identity/epoch/geometry/coverage/measurement';check(False,'response-segment-ended',n,lane)
    if st['active']:
     check(np.array_equal(old[0],st['previous']),'actual-previous-write',n,lane)
     expected_pre=old[0].copy()
     if change[1]>.5:expected_pre[3]=min(expected_pre[3],1)
     check(np.array_equal(prepared,expected_pre),'prepared-reactive-history',n,lane)
     if attempted:st['attempts'].append({'frame':n,'tick':s['tick'],'committed':committed,'known':known})
     if committed:
      check(params[3]>0,'positive-ray-count',n,lane)
      e=estimate[:3]/params[3];samples=min(prepared[3]+1,32);alpha=max(1/samples,.1) if prepared[3]>0 else 1.
      previous=st['A']*st['base']+st['B']
      local=GAMMA*(np.abs(previous)+st['error']+np.abs(e))+2**-120
      st['error']=abs(1-alpha)*st['error']+local
      st['A']=(1-alpha)*st['A'];st['B']=(1-alpha)*st['B']+alpha*e
      st['commits'].append({'frame':n,'tick':s['tick'],'alpha':alpha,'estimate':e.tolist()})
      row.update(alpha=alpha,estimate=e.tolist(),localErrorBound=local.tolist())
      check(new[0,3]==samples,'committed-sample-count',n,lane)
     else:check(np.array_equal(new[0],prepared),'noncommit-holds-prepared',n,lane)
     st['previous']=new[0].copy()
   if n>=READY and states[lane]['active']:
    st=states[lane];own=st['A']*st['base'];prediction=own+st['B'];error=np.abs(prediction-new[0,:3])
    check(np.all(error<=st['error']),'propagated-response-bound',n,lane)
    row.update(A=st['A'],ownInitialHistory=own.tolist(),incomingEstimateHistory=st['B'].tolist(),prediction=prediction.tolist(),absoluteError=error.tolist(),propagatedErrorBound=st['error'].tolist())
    if n>READY:
     row['increasedChannels']=[i for i in range(3) if new[0,i]>old[0,i]]
   rows.append(row)
 check(len(rows)==720,'all-patch-records');samples=[]
 for n in SAMPLES:
  stages={k:binary(n,k).reshape(4,4).astype(float) for k in ['raw','history','filtered']}
  # Provenance covers the original stream on which the retained decoder operated.
  raw(RUN/f'gather-{n:04d}-events.bin');raw(RUN/f'gather-{n:04d}-raw-selected.bin')
  image=np.frombuffer(raw(RUN/f'frame-{n:04d}.rgba32f'),dtype='<f4').reshape(360,640,4)
  pixels=[p for p in frozen['pixels'] if p['frame']==n];check(len(pixels)==4,'four-gather-pixels',n)
  for p in pixels:
   for k in stages:check(np.array_equal(stages[k][p['lane']],p[k]),'saved-stage-'+k,n,p['lane'])
   x,y=p['giPixel'];check(np.array_equal(image[2*y:2*y+2,2*x:2*x+2],p['finalFootprint2x2']),'final-footprint',n,p['lane'])
  samples.append({'frame':n,'cache':[r for r in rows if r['frame']==n],'pixels':pixels,'meanRGB':image[:,:,:3].mean(axis=(0,1),dtype=float).tolist(),'maxRGB':image[:,:,:3].max(axis=(0,1)).tolist()})
 patch_summary=[]
 for lane,st in states.items():
  commits=[c for c in st['commits'] if c['frame']>=OFF];intervals=[b['tick']-a['tick'] for a,b in zip(commits,commits[1:])]
  seq=[r for r in rows if r['lane']==lane and r['frame']>=OFF];last=seq[-1]
  patch_summary.append({'lane':lane,'entry':last['entry'],'base119':st['base'].tolist(),'firstActualCommit':commits[0] if commits else None,'serviceDelayTicks':commits[0]['tick']-off_tick if commits else None,'commits':commits,'attempts':st['attempts'],'updateIntervalsTicks':intervals,'maxUpdateIntervalTicks':max(intervals,default=None),'waitOrUncommittedFrames':sum(r['kind']!='committed' for r in seq),'allIncreaseEvents':[{'frame':r['frame'],'channels':r['increasedChannels']} for r in seq if r.get('increasedChannels')],'final':last})
 return {'passed':not issues,'issues':issues,'originalFrozenPass':frozen['passed'],'overallAccepted':False,'inputHashes':hashes,'derivedInputHashes':{str(p.relative_to(ROOT)):sha(p.read_bytes()) for p in [SOURCE/'analysis.json',SOURCE/'summary.json']},'arithmetic':{'precision':'Python double/NumPy float64','gamma32':GAMMA,'contract':'contract.md','errorPropagation':'abs(1-alpha)*priorBound + gamma32*(abs(predictedPrior)+priorBound+abs(actualEstimate)) + 2^-120'},'coverage':dict(counts),'patchRecords':rows,'fairness':fairness,'patchSummary':patch_summary,'samples':samples,'observedSources':frozen['sources'],'limits':['B is incoming-estimate history, not exclusively new external energy; other old cache feedback remains possible.','Only two unique patches and nine gather times; no interpolated gather trajectory or whole-image causal fraction.','Scheduling service is not a guarantee of a valid estimate. No wall-clock performance claim.','No independent whole-scene physical reference, convergence threshold or parameter counterfactual.']}

if __name__=='__main__':
 parser=argparse.ArgumentParser();parser.add_argument('--output',type=Path,required=True);args=parser.parse_args()
 result=analyze();args.output.parent.mkdir(parents=True,exist_ok=True);args.output.write_text(json.dumps(result,indent=2),encoding='utf-8')
 print(json.dumps({'passed':result['passed'],'issues':result['issues'],'coverage':result['coverage'],'patches':[{k:p[k] for k in ['entry','serviceDelayTicks','maxUpdateIntervalTicks','waitOrUncommittedFrames','final']} for p in result['patchSummary']]}))
 raise SystemExit(0 if result['passed'] else 1)
