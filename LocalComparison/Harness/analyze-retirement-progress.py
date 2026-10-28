"""Validate one natural 12-frame shutdown trace, preserving raw log failures."""
import argparse,json,re,sys
from pathlib import Path
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
p=argparse.ArgumentParser();p.add_argument('root',type=Path);p.add_argument('log',type=Path);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
result={'scope':'One natural Editor exit integration probe; deterministic adapter separately covers completion race','errors':[]}
errors=result['errors']
def check(ok,message):
    if not ok:errors.append(message)
try:
    runs=list(a.root.glob('*/run.json'));check(len(runs)==1,'Expected exactly one run');run=read(runs[0]);directory=runs[0].parent
    check(run['renderedFrames']==12 and run['errors']==0 and run['status']=='incomplete-probe','Capture completion')
    frames=[json.loads(l) for l in (directory/'frames.jsonl').read_text(encoding='utf-8').splitlines()]
    diag=json.loads(frames[-1]['diagnosticsJson']);check(diag['exactSoftwareGeometry'] and not diag['hardwareBackend'] and diag['publishedInstances']>0 and diag['worldCacheBytes']>0,'Target resource/backend coverage')
    rows=[json.loads(l) for l in (a.root/'progress-timeline.jsonl').read_text(encoding='utf-8').splitlines()]
    capture=next(r for r in rows if r['stage']=='capture-finish-before-exit');domain=capture['domain'];rows=[r for r in rows if r['domain']==domain]
    check(all(r['sequence']==i+1 for i,r in enumerate(rows)),'Domain sequence order')
    closed=next(r for r in rows if r['stage']=='shutdown-closed' and r['sequence']>capture['sequence']);deadline=closed['deadline']
    late=[r for r in rows if r['sequence']>=closed['sequence']]
    check(all(r['deadline']==deadline for r in late),'Shutdown deadline changed')
    check(not any(r['stage'].startswith('drain-stop-') or r['stage'].endswith('-error') or r['stage']=='destroy-failed' for r in late),'Unexpected stop/query/destruction error')
    tickets={r['ticket'] for r in rows if r['stage']=='enqueue'};result['ticketCount']=len(tickets);result['tickets']=[]
    parent=[]
    for ticket in sorted(tickets):
        events=[r for r in rows if r['ticket']==ticket];stages=[r['stage'] for r in events]
        for stage in ['enqueue','submitted','destroy-begin','destroy-returned']:check(stages.count(stage)==1,f'Ticket {ticket}: {stage} not exactly once')
        enq=next(r for r in events if r['stage']=='enqueue');submit=next(r for r in events if r['stage']=='submitted');begin=next(r for r in events if r['stage']=='destroy-begin');end=next(r for r in events if r['stage']=='destroy-returned')
        check(enq['sequence']<submit['sequence']<begin['sequence']<end['sequence'],f'Ticket {ticket} lifetime order')
        prior=[r for r in events if r['sequence']<begin['sequence'] and r['stage']=='fence-read'];prereq=[r for r in events if r['sequence']<begin['sequence'] and r['stage']=='destroy-prerequisite']
        check(bool(prior) and prior[-1]['observed']=='passed' and bool(prereq) and prereq[-1]['observed']=='ready',f'Ticket {ticket} missing actual completion proof')
        check(begin['submitted'] and not begin['submissionUnknown'],f'Ticket {ticket} unknown submission destroyed')
        result['tickets'].append({'id':ticket,'callback':enq['callback'],'queryResults':[r['observed'] for r in events if r['stage']=='fence-read'],'submission':submit['detail'],'begin':begin['sequence'],'end':end['sequence']})
        if 'WithdrawForShutdown' in enq['callback']:parent.append((begin['sequence'],end['sequence'],ticket))
    check(len(parent)==1,'Expected one old Feature parent owner')
    if parent:
        start,end,_=parent[0];children=[r['ticket'] for r in rows if r['stage']=='enqueue' and start<r['sequence']<end]
        result['parent']=parent[0][2];result['children']=children;check(len(children)>0,'No child retirement coverage')
    empty=[r for r in late if r['stage']=='drain-empty'];check(bool(empty),'No same-domain empty drain')
    if empty:
        last=empty[-1];check(all(last[k]==0 for k in ['owned','pending','failed','unknown','failedWithdrawals','materialBytes','arenaBytes','deformationBytes']),'Remaining related ownership/accounting');result['finalAccounting']=last
    log=a.log.read_text(encoding='utf-8',errors='replace')
    patterns=['retained unresolved retirement','separate owners remain','Leak Detected','Found \\d+ leak\\(s\\)','Unreleased non-evictable','RETIREMENT_PROGRESS_OBSERVER_FAILED','Comparison failed:','Shader error','error CS\\d','NullReferenceException','MissingReferenceException','DXGI_ERROR_DEVICE']
    matched=[pat for pat in patterns if re.search(pat,log,re.I)];check(not matched,'Native log failure signatures: '+str(matched))
    result['nativeFailureSignatures']=matched;result['genericMemoryLeaksAggregatePresent']='"type":"MemoryLeaks"' in log
    result['renderedFrames']=run['renderedFrames'];result['lastDiagnostics']=diag
except Exception as e:errors.append(repr(e))
result['shutdownAccepted']=not errors;a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(json.dumps(result,indent=2),encoding='utf-8')
print(json.dumps({k:v for k,v in result.items() if k not in ['tickets','lastDiagnostics','finalAccounting']},indent=2));sys.exit(0 if result['shutdownAccepted'] else 1)
