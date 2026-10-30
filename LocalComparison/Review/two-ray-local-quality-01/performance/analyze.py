"""Describe the single ledger-confirmed DXR ordinary Player Present window."""
import csv
import json
import math
from pathlib import Path

here = Path(__file__).resolve().parent
source = Path('I:/Unity test/Comparison/TwoRayLocalQualityPerformance01/present.csv')
rows = list(csv.DictReader(source.open(encoding='utf-8-sig', newline='')))
result = dict(status='unavailable', source=str(source), rows=len(rows),
              interpretation='Application DXGI Present calls only. Display tracking disabled; no displayed FPS or dropped-display inference.',
              screenshotConfirmedNormalScene=False, endpointLedgerReportedBackend="DXR", targetWidth=960, targetHeight=540, targetFps=30)
try:
    run = json.loads((here / 'capture-exit.json').read_text(encoding='utf-8-sig'))
    assert run['exitCode'] == 0 and not run['watchdogTerminated']
    before = json.loads((here / 'before-ledger.json').read_text(encoding='utf-8'))
    after = json.loads((here / 'after-ledger.json').read_text(encoding='utf-8'))
    for endpoint in (before, after):
        assert endpoint['targetProcessId'] == run['targetProcessId']
        assert endpoint['ledger']['actualBackend'] == 'DXR'
        assert endpoint['ledger']['cameraGi']['hardwareBackend'] is True
    assert after['ledger']['engineFrame'] > before['ledger']['engineFrame']
    before_motion = before['ledger']['cameraGi']['hardwareTransformUpdates']
    after_motion = after['ledger']['cameraGi']['hardwareTransformUpdates']
    result['motionEvidence'] = dict(ordinaryMRequested=before.get('ordinaryMRequested', False),
        beforeHardwareTransformUpdates=before_motion, afterHardwareTransformUpdates=after_motion,
        confirmed=before.get('ordinaryMRequested', False) and after_motion > before_motion,
        scope='Input request and endpoint CPU transform-update counters, not per-frame door or short-history branch proof')
    result['screenshotConfirmedNormalScene'] = before.get('screenshotNormalScene', False)
    result['endpointLedgers'] = {'before': before, 'after': after}
    result['backendScope'] = 'Same process current CPU diagnostics before/after capture; not per-frame or per-ray proof.'
    assert len(rows) >= 2
    identities = {(r['Application'], r['ProcessID'], r['SwapChainAddress'], r['Runtime']) for r in rows}
    assert len(identities) == 1, 'Multiple identities; do not select a favourable swapchain'
    identity = next(iter(identities))
    assert identity[1] == str(run['targetProcessId']) and identity[3] == 'DXGI'
    times = [float(r['TimeInSeconds']) for r in rows]
    intervals = [float(r['msBetweenPresents']) for r in rows[1:]]
    assert all(math.isfinite(t) for t in times)
    assert all(math.isfinite(t) and t > 0 for t in intervals)
    assert all(b > a for a, b in zip(times, times[1:]))
    ordered = sorted(intervals)
    def percentile(q):
        p = (len(ordered) - 1) * q
        lo, hi = math.floor(p), math.ceil(p)
        return ordered[lo] + (ordered[hi] - ordered[lo]) * (p - lo)
    elapsed = times[-1] - times[0]
    assert abs(sum(intervals) / 1000 - elapsed) < 0.00001, 'Intervals do not match observed timestamps'
    slow = sum(t > 1000 / 30 for t in intervals)
    result.update(status='measured-application-present-only', identity=identity,
                  firstPresentSeconds=times[0], lastPresentSeconds=times[-1], elapsedSeconds=elapsed,
                  intervals=len(intervals), excludedInitialIntervals=1,
                  meanMs=sum(intervals)/len(intervals), frequencyHz=len(intervals)/elapsed,
                  medianMs=percentile(.5), p95Ms=percentile(.95), p99Ms=percentile(.99), maxMs=max(intervals),
                  above33_333Ms=slow, above33_333Fraction=slow/len(intervals),
                  syncIntervals=sorted({r['SyncInterval'] for r in rows}), presentFlags=sorted({r['PresentFlags'] for r in rows}),
                  percentileMethod='Linear interpolation at (N-1)*q', productionAcceptance=False)
except (AssertionError, ValueError, KeyError) as error:
    result['error'] = str(error)
with (here / 'result.json').open('x', encoding='utf-8') as output:
    json.dump(result, output, ensure_ascii=False, indent=2, allow_nan=False)
print(json.dumps(result, ensure_ascii=False, indent=2))
