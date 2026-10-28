"""Summarize archived chain02 evidence without changing frozen analysis or acceptance."""
import hashlib,json
from pathlib import Path
import numpy as np
root=Path(__file__).resolve().parents[2];package=root/'LocalComparison/Review/scene-lightoff-chain-02'
read=lambda p:json.loads(p.read_text(encoding='utf-8-sig'))
run_path=next((package/'run').glob('*/run.json'));directory=run_path.parent
run=read(run_path);analysis=read(package/'analysis.json');execution=read(package/'execution.json')
light=read(directory/'lightoff-summary.json');gather=read(directory/'gather-summary.json')
records=[json.loads(x) for x in (directory/'lightoff-lights.jsonl').read_text(encoding='utf-8').splitlines()]
events={}
for frame in [0,1,2,119,120,121,359]:
 phases=[r for r in records if r['logicalFrame']==frame];s=read(directory/f'lightoff-schedule-{frame:04d}.json')
 events[frame]={'phases':[{k:r[k] for k in ['phase','giFrame','previousCount','count','lampInstance','lampEnabled','records','changes']} for r in phases],
  'schedule':{k:s[k] for k in ['giFrame','tick','readBuffer','writeBuffer','epoch','valid','selected','effectiveBudget','maxAge','aliases','patches']}}
samples=[]
for frame in [119,120,121,123,127,135,151,239,359]:
 image=np.fromfile(directory/f'frame-{frame:04d}.rgba32f',dtype='<f4').reshape(360,640,4)
 pixels=[p for p in analysis['pixels'] if p['frame']==frame];cache=[p for p in analysis['cache'] if p['frame']==frame]
 samples.append({'frame':frame,'cache':[{'entry':p['entry'],'scheduled':p['scheduled'],'committed':p['committed'],'irradiance':p['new']} for p in cache],
  'fullImageMeanRGB':image[:,:,:3].mean(axis=(0,1),dtype=float).tolist(),'fullImageMaxRGB':image[:,:,:3].max(axis=(0,1)).tolist(),
  'pixels':pixels})
observation=run['renderedFrames']==360 and run['errors']==0 and light['passed'] and gather['passed'] and not light['missing'] and not gather['missing']
chain=bool(analysis['passed'] and analysis['coverage'].get('off-known-direct-calls',0)>0 and analysis['coverage'].get('final-radiance-cache-consumed',0)>0)
native=execution['exitCode']==0 and not execution['nativeFailureSignatures']
result={'observationComplete':observation,'lightChangeChainPassed':chain,'scopedGIOwnerProof':{'passed':True,'source':'early-exit-retirement-01/fixed/attribution.json','currentRunPerTicketProof':False},
 'nativeResourceAccepted':native,'overallAccepted':observation and chain and native,'frozenAnalysisPassed':analysis['passed'],'frozenFailures':analysis['failures'],
 'scope':'Limited fixed C scene only; absent scratch signature here does not resolve prior exceptional-exit scratch ownership.',
 'genericRunStatus':run['status'],'genericRunStatusExplanation':'ComparisonCapture marks fullSequenceCompleted only for totalFrames720;360/9/0 is this completed bounded observation, not the old full720 suite.',
 'startupEvidence':events,'startupInference':'Logical0 and1 both begin GI frame0/scheduler tick1/cacheRead0/previousCount0, while the same Light is enabled and packed identically. Patch revision changes12→13. Consistent with renewed pass/state startup, but this run did not trace object lifetimes; exact caller/identity is unproven. Frozen no-other-source-event frame1 failure remains false.',
 'proposalCounts':sorted(set(s['proposalCount'] for s in analysis['sources'])),'areaCounts':sorted(set(s['areaCount'] for s in analysis['sources'])),
 'coverage':analysis['coverage'],'queueFrames':analysis['queueFrames'],'samples':samples,'runtimeDiffExpectedEmpty':True}
(package/'summary.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
print(json.dumps({k:result[k] for k in ['observationComplete','lightChangeChainPassed','nativeResourceAccepted','overallAccepted','frozenFailures','proposalCounts','areaCounts','coverage']}))
print(json.dumps({'sampleResiduals':[{'frame':s['frame'],'cache':[c['irradiance'][:3] for c in s['cache']],'meanRGB':s['fullImageMeanRGB'],'maxRGB':s['fullImageMaxRGB']} for s in samples]}))
