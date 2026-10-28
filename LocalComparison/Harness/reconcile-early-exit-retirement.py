"""Offline owner reconciliation; preserves the frozen conservative acceptance result."""
import json
from pathlib import Path
root=Path(__file__).resolve().parents[2]
package=root/'LocalComparison/Review/early-exit-retirement-01/fixed'
read=lambda p:json.loads(p.read_text(encoding='utf-8-sig'))
analysis=read(package/'analysis.json')
rows=[json.loads(line) for line in (package/'run/early-exit-timeline.jsonl').read_text(encoding='utf-8').splitlines()]
runtime=[d for d in analysis['domains'] if d['tickets']]
assert len(runtime)==1
domain=runtime[0];tickets=domain['tickets'];events=[r for r in rows if r['domain']==domain['domain']]
select=lambda ticket,stage:[r for r in events if r['ticket']==ticket and r['stage']==stage]
parents=[t for t in tickets if t['owner']=='Feature.WithdrawForShutdown/pass-and-composite']
targets=[t for t in parents if t['enqueuePhase']=='after-own-end-context-callback']
assert len(targets)==1
parent=targets[0];children=[t for t in tickets if t['parent']==parent['id']]
expected={'CameraState.RetireSoftwareBuffers/nodes+leaves':24544}
expected.update({'HardwareBackend/software/'+name:size for name,size in [('Flags',128),('Instances',2048),('Normals',15360),('Surface',18432),('Bindings',3072),('Matrices',1024)]})
assert len(children)==7 and {t['owner']:t['logicalBytes'] for t in children}==expected
enqueue=select(parent['id'],'enqueue')[0];eligible=select(parent['id'],'detached-pass-idle-eligible');submitted=select(parent['id'],'submitted')[0]
begin=select(parent['id'],'destroy-begin')[0];returned=select(parent['id'],'destroy-returned')[0]
assert enqueue['awaitDetachedPassIdle'] and len(eligible)==1 and eligible[0]['outside']
assert enqueue['sequence']<eligible[0]['sequence']<submitted['sequence']<begin['sequence']<returned['sequence']
assert submitted['detail']=='idle' and all(t['destroyedExactlyOnceWithProof'] for t in tickets)
assert all(begin['sequence']<t['enqueueSequence']<returned['sequence']<select(t['id'],'submitted')[0]['sequence'] for t in children)
assert all(domain['lastState'][field]==0 for field in ['owned','pending','failed','unknown','failedWithdrawals','materialBytes','arenaBytes','deformationBytes'])
assert all(read(package/'execution.json')['sourceChecks'].values()) and read(package/'instrumentation/restoration.json')['passed']
hits=analysis['nativeResourceSignatures']
scratch=[h for h in hits if h['category']=='d3d-unreleased' and 'D3D12ScratchBufferInternal::' in h['text']]
other=[h for h in hits if h not in scratch]
assert len(scratch)==1 and not other
result={'expectedObserverFailure':analysis['expectedObserverFailure'],'lightoffCompleted':False,
 'retirementProofPassed':analysis['retirementProofPassed'],'scopedGIOwnerProofPassed':True,
 'nativeAttributedLeaks':0,'nativeAttributionScope':'No remaining stack/named-buffer signature for the eight baseline-attributed GI allocations; not an assertion of all-process zero leaks.',
 'engineScratchUnresolved':scratch,'domain':domain['domain'],'completeTicketCount':len(tickets),
 'parent':{'id':parent['id'],'enqueue':enqueue['sequence'],'idleEligible':eligible[0]['sequence'],'submitted':submitted['sequence'],'destroyBegin':begin['sequence'],'destroyReturned':returned['sequence']},
 'children':[{'id':t['id'],'owner':t['owner'],'logicalBytes':t['logicalBytes'],'parent':t['parent'],'events':t['events']} for t in children],
 'releasedLogicalChildBytes':sum(t['logicalBytes'] for t in children),'sourceAndRestorationVerified':True,
 'note':'Frozen analysis.json remains conservative false because engine scratch is unresolved. This supplemental scoped reconciliation does not overwrite that contract or claim light-off acceptance.'}
(package/'attribution.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
print(json.dumps({k:v for k,v in result.items() if k not in ['children','engineScratchUnresolved']}))
