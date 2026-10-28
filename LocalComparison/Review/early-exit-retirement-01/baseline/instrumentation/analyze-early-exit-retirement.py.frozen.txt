"""Decode one original-trigger attribution by domain/ticket; never advances GPU work."""
import argparse,collections,json
from pathlib import Path
from native_log_check import scan
def read(p):return json.loads(p.read_text(encoding='utf-8'))
p=argparse.ArgumentParser();p.add_argument('package',type=Path);a=p.parse_args();errors=[];report={}
try:
 execution=read(a.package/'execution.json');runs=list((a.package/'run').glob('*/run.json'))
 if len(runs)!=1:raise ValueError('Expected one physical run')
 run=read(runs[0]);frames=[json.loads(x) for x in (runs[0].parent/'frames.jsonl').read_text(encoding='utf-8').splitlines()]
 expected=run['renderedFrames']==1 and run['captures']==0 and 'Actual cache observer entry/frame/epoch mismatch' in run['error'] and execution['exitCode']==1
 if not expected:errors.append('Original first-frame observer failure not reproduced exactly')
 rows=[json.loads(x) for x in (a.package/'run/early-exit-timeline.jsonl').read_text(encoding='utf-8').splitlines()]
 bydomain=collections.defaultdict(list)
 for row in rows:bydomain[row['domain']].append(row)
 domains=[];complete=True
 for domain,events in bydomain.items():
  if [r['sequence'] for r in events]!=list(range(1,len(events)+1)):errors.append('Trace sequence gap in '+domain)
  tickets=collections.defaultdict(list)
  for row in events:
   if row['ticket']:tickets[row['ticket']].append(row)
  records=[]
  for ticket,life in tickets.items():
   select=lambda stage:[r for r in life if r['stage']==stage]
   enq=select('enqueue');submitted=select('submitted');begin=select('destroy-begin');returned=select('destroy-returned')
   if not enq:
    records.append({'id':ticket,'kind':'external ticket without owned enqueue','events':life});complete=False;continue
   if len(enq)!=1:errors.append('Duplicate enqueue identity: '+str(ticket))
   ordered=len(submitted)==len(begin)==len(returned)==1
   if ordered:
    ordered=enq[0]['sequence']<submitted[0]['sequence']<begin[0]['sequence']<returned[0]['sequence']
    fences=[r for r in life if r['stage']=='fence-read' and r['sequence']<begin[0]['sequence']]
    prerequisites=[r for r in life if r['stage']=='destroy-prerequisite' and r['sequence']<begin[0]['sequence']]
    ordered=ordered and bool(fences) and fences[-1]['observed']=='passed' and bool(prerequisites) and prerequisites[-1]['observed']=='ready' and begin[0]['submitted'] and not begin[0]['submissionUnknown']
   complete=complete and ordered
   records.append({'id':ticket,'owner':enq[0]['owner'],'callback':enq[0]['callback'],'logicalBytes':enq[0]['logicalBytes'],'parent':enq[0]['parent'],
    'enqueuePhase':enq[0]['phase'],'enqueueSequence':enq[0]['sequence'],'enqueueContext':enq[0]['context'],'requiresContextAtEnqueue':enq[0]['requiresContext'],
    'submitted':bool(submitted),'destroyedExactlyOnceWithProof':bool(ordered),'exclusions':[{'sequence':r['sequence'],'reason':r['detail'],'phase':r['phase']} for r in life if r['stage'] in ['idle-excluded','context-excluded']],
    'events':[{'sequence':r['sequence'],'stage':r['stage'],'phase':r['phase'],'observed':r['observed'],'detail':r['detail'],'outside':r['outside'],'parent':r['parent']} for r in life],
    'enqueueStack':enq[0]['enqueueStack']})
  closes=[r for r in events if r['stage']=='shutdown-closed'];stops=[r for r in events if r['stage'].startswith('drain-stop-')]
  if closes:
   for row in events:
    if row['sequence']>=closes[0]['sequence'] and row['deadline']!=closes[0]['deadline']:errors.append('Deadline changed in '+domain);break
  domains.append({'domain':domain,'tickets':records,'boundaries':[r for r in events if r['stage'] in ['allocation-stacks-enabled','begin-context','end-context-enter','end-context-return','idle-enter','idle-certified-state','shutdown-closed','capture-finish-before-exit','first-receipt-cap']],
   'stops':stops,'capabilityReads':[r for r in events if r['stage']=='fence-support-read'],'lastState':events[-1]})
 raw=(a.package/'Unity.log').read_text(encoding='utf-8');hits=scan(a.package/'Unity.log')
 trace_failed='EARLY_EXIT_TRACE_FAILED' in raw
 if trace_failed:errors.append('Attribution observer failed')
 resource_hits=[h for h in hits if h['category'] in ['native-allocation','d3d-unreleased','unresolved-owner']]
 report={'expectedObserverFailure':expected,'retirementProofPassed':bool(complete and not errors and not resource_hits),'lightoffCompleted':False,
  'attributionCollected':bool(expected and not trace_failed and rows and not errors),'errors':errors,'domains':domains,'nativeResourceSignatures':resource_hits,
  'nativeAttributedLeaks':None,'attributionNote':'Owner labels/logical bytes and allocation stacks require explicit reconciliation; native counts do not prove one-to-one ownership, engine scratch remains separate.',
  'renderedFrames':run['renderedFrames'],'runtimeDiagnostics':json.loads(frames[-1]['diagnosticsJson']) if frames else None}
except Exception as e:errors.append(repr(e));report={'attributionCollected':False,'retirementProofPassed':False,'errors':errors,'lightoffCompleted':False}
(a.package/'analysis.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps({k:report.get(k) for k in ['expectedObserverFailure','attributionCollected','retirementProofPassed','lightoffCompleted','errors','nativeResourceSignatures']}))
raise SystemExit(0 if report.get('attributionCollected') else 1)
