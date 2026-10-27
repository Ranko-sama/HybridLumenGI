"""Read-only bounded lifecycle evidence analysis; no product state mutation."""
import collections, hashlib, json, re
from pathlib import Path

root = Path(__file__).resolve().parents[2]
out = root / 'LocalComparison/Review/resource-shutdown-01b'
receipts = json.loads((out/'execution-receipts.json').read_text())
report = {'baseline': '4610cc2', 'scope': 'Unity 6000.0.85f1, URP 17.0.4, DX12 RTX2080Ti, default domain reload; 12-frame finite probes, not performance/long-duration acceptance', 'runs': {}}
state_keys = ['pendingCount', 'ownedCount', 'materialBytes', 'materialBatches', 'arenaBytes', 'arenas', 'deformationBytes', 'deformationJobs', 'publishedSnapshots', 'failedWithdrawals', 'failedCleanup']
for run in ['lifecycle', 'direct']:
    rows = [json.loads(s) for s in (out/run/'retirement-timeline.jsonl').read_text().splitlines()]
    domains = collections.defaultdict(list)
    for row in rows:
        domains[row['domain']].append(row)
    result = {'executionReceipt': receipts[run], 'domains': [], 'captureRuns': []}
    assert receipts[run]['exitCode'] == 0
    for domain, events in domains.items():
        tickets = collections.defaultdict(list)
        for row in events:
            if row['ticket']:
                tickets[row['ticket']].append(row)
        traces = []
        for tid, history in tickets.items():
            stages = collections.Counter(x['stage'] for x in history)
            assert stages['enqueue'] == stages['submitted'] == stages['destroy-begin'] == stages['destroy-returned'] == 1, (run, domain, tid, stages)
            en, sub, begin, end = [next(x for x in history if x['stage'] == stage) for stage in ['enqueue', 'submitted', 'destroy-begin', 'destroy-returned']]
            assert en['sequence'] < sub['sequence'] < begin['sequence'] < end['sequence']
            assert begin['submitted'] and begin['completion'] == 'passed' and not begin['submissionUnknown']
            assert begin['prerequisite'] == 'none'  # Other prerequisite states are adapter-only coverage.
            traces.append({'ticket': tid, 'owner': en['owner'], 'callback': en['callback'], 'logicalDirectBufferBytes': en['logicalBytes'],
                           'enqueue': en['sequence'], 'submitted': sub['sequence'], 'destroyBegin': begin['sequence'], 'destroyReturned': end['sequence'],
                           'completionAtDestroy': begin['completion'], 'requiresContextAtEnqueue': en['requiresContext']})
        assert all(events[-1][key] == 0 for key in state_keys), (run, domain, events[-1])
        close = next((x for x in events if x['stage'] == 'shutdown-admission-closed'), None)
        late = [x for x in events if x['stage'] == 'feature-dispose-enter' and close and x['sequence'] > close['sequence']]
        if late:
            assert not any(x['stage'] == 'enqueue' and x['sequence'] > late[0]['sequence'] for x in events), (run, 'late Dispose added another owner')
        result['domains'].append({'domain': domain, 'ticketCount': len(traces), 'tickets': traces,
             'close': ({key: close[key] for key in ['sequence', 'admissionClosed', 'outsideRenderLoop']+state_keys} if close else None),
             'lateDisposeSequences': [x['sequence'] for x in late], 'finalStage': events[-1]['stage'],
             'finalState': {key: events[-1][key] for key in state_keys}})
    for manifest in sorted((out/run).glob('*/run.json')):
        data = json.loads(manifest.read_text())
        assert data['renderedFrames'] == data['requestedFrames'] == 12 and data['errors'] == 0 and not data['featureOff']
        result['captureRuns'].append({'path': str(manifest.relative_to(root)), 'renderedFrames': data['renderedFrames'], 'status': data['status']})
    assert len(result['captureRuns']) == (2 if run == 'lifecycle' else 1)
    log = (out/(run+'.log')).read_text(errors='replace')
    patterns = {'observerFailure': r'RESOURCE_TRACE_WRITE_FAILED', 'nativeAllocationLeak': r'A Native Collection has not been disposed|leaked allocation|leak\(s\) from callstack:|Leak Detected\s*:\s*Persistent|\[d3d12\] Unreleased non-evictable resource',
                'unresolvedOwners': r'retained unresolved retirement|separate owners remain', 'missingReference': r'MissingReferenceException',
                'compileError': r'error CS\d+', 'deviceLost': r'DXGI_ERROR_DEVICE_(REMOVED|HUNG|RESET)'}
    result['failureMarkers'] = {key: len(re.findall(pattern, log, re.I)) for key, pattern in patterns.items()}
    assert all(n == 0 for n in result['failureMarkers'].values())
    result['remainingLogCaveats'] = ['Unity licensing access-token diagnostic; DX12 info-queue-interface query unavailable; normal engine shutdown MemoryLeaks aggregate is not interpreted as product ownership', 'Lifecycle compile includes existing obsolete-API/camera-hiding warnings']
    report['runs'][run] = result
executed = json.loads((out/'product-hashes.json').read_text())
report['currentSourceDeltaFromExecuted'] = {}
for name, sha in executed.items():
    current = hashlib.sha256((root/'Runtime'/name).read_bytes()).hexdigest()
    if sha != current:
        report['currentSourceDeltaFromExecuted'][name] = {'executed': sha, 'current': current, 'reason': 'Astra-directed failure-retention fix in normal cancelled-worker cleanup after GPU runs; actual-source controlled destruction-failure test passed, no new native run claimed'}
assert set(report['currentSourceDeltaFromExecuted']) == {'HybridLumenGIDeformedMesh.cs'}
(out/'analysis.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
print(json.dumps({'result': 'PASS bounded evidence checks', 'ticketsByRun': {k: sum(x['ticketCount'] for x in v['domains']) for k,v in report['runs'].items()}, 'postRunSourceDelta': list(report['currentSourceDeltaFromExecuted'])}, indent=2))
