"""Read the single completed timed run; no rendering, hashes, interpolation or new reference."""
import json
from pathlib import Path
import sys
import numpy as np

RUN = Path(sys.argv[1]) if len(sys.argv) > 1 else Path('I:/Unity test/Comparison/TimedResponse123')
OUT = Path(__file__).resolve().parent / 'result.json'

def load(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))

def plane(root, record):
    shape = (record['height'], record['width'])
    file = record['data']['file'] if 'data' in record else record['file']
    return (np.fromfile(root / file, '<f4').reshape(*shape, 4),
            np.fromfile(root / record['validity']['file'], 'u1').reshape(shape) != 0)

scene = load(RUN / 'scene-result.json')
editor = load(RUN / 'editor-result.json')
setup = RUN.parent / (RUN.name + 'Setup')
native = load(setup / 'native-exit.json')
selection = load(setup / 'selection.json')
assert native['exitCode'] == 0 and editor['status'] == 'collected' and editor['restored']
assert scene['status'] == 'collected' and not scene['error'] and scene['eventAfterLogical'] == 119
assert scene['eventScope'] == 'local' and scene['captureDrained'] and scene['capturedNominalCount'] == 5
assert len(selection) == 27
x, y = np.array([p['gi'] for p in selection]).T
rows, values = [], []
original_inv_vp = original_depth = None
for src in scene['observations']:
    path = RUN / 'signals' / f"frame-{src['logicalFrame']:04d}-capture.json"
    r = load(path)
    assert r['status'] == 'complete' and r['readbacksCompleted'] and r['retainedBytes'] == 0
    assert r['logicalFrame'] == r['workFrame'] == src['logicalFrame'] == src['workFrame']
    assert r['engineFrame'] == src['engineFrame']
    signal = next(v for v in r['samples'] if v['signalId'] == 'filteredD')
    assert signal['quantity'] == 'indirect-irradiance-over-pi'
    assert (signal['width'], signal['height']) == (320, 180)
    data, valid = plane(RUN / 'signals', signal)
    points = data[y, x, :3].astype(float)
    assert valid[y, x].all() and np.isfinite(points).all(), 'Do not discard an unknown original point'
    assert len(points) == 27
    inv = r['composite']['invVP']
    if original_inv_vp is None:
        original_inv_vp = inv
    assert inv == original_inv_vp
    for role in ('geometry', 'material', 'depth', 'normals'):
        q = next(v for v in r['support'] if v['role'] == role)
        d, mask = plane(RUN / 'signals', q)
        px, py = (x, y) if role == 'geometry' else (2*x+1, 2*y+1)
        assert mask[py, px].all()
        if role == 'material':
            assert (np.rint(d[py, px, :3]*255) == 245).all() and (d[py, px, 3] == 1).all()
        elif role == 'normals':
            assert (d[py, px, :3] == [0, 1, 0]).all()
        elif role == 'depth':
            if original_depth is None:
                original_depth = d[py, px, 0].copy()
            assert np.array_equal(original_depth, d[py, px, 0])
    expected_emission = [0, 1, 0] if src['logicalFrame'] == 119 else [0, 0, 1]
    assert [src['gpuProxyEmission'][c] for c in 'xyz'] == expected_emission
    diag = src['diagnostics']
    assert diag['hardwareBackend'] and (diag['hardwareMeshes'], diag['hardwareFallbacks'], diag['lightSelected']) == (2, 1, 0)
    rows.append({k: src[k] for k in ('logicalFrame', 'workFrame', 'engineFrame', 'nominalSeconds',
                 'sourceSeconds', 'elapsedSeconds', 'renderCallEndSeconds', 'observationReadEndSeconds',
                 'previousSourceGap', 'nextSourceGap')})
    rows[-1].update(known=27, unknown=0, sourceFormat=signal['sourceFormat'], pointRGB=points.tolist())
    values.append(points)

baseline = values[0][:, 1]
assert (baseline > 0).all()
for row, points in zip(rows, values):
    row['meanRGB'] = points.mean(0).tolist()
    row['meanOldGreenPercent'] = 100*float(points[:, 1].mean()/baseline.mean())
    row['maxPointOldGreenPercent'] = 100*float((points[:, 1]/baseline).max())
observed = rows[1:]
first = lambda pct: next((r['elapsedSeconds'] for r in observed if r['meanOldGreenPercent'] <= pct), None)
times = scene['requestTimes']
intervals = [r['previousSourceGap'] for r in times if r['elapsedSeconds'] >= 0 and r['previousSourceGap'] > 0]
result = dict(status='observed-limited-timed-green-decay', criteriaCommit='42ea190e',
    quantity='filteredD = indirect irradiance / pi; linear RGB before receiver diffuse, AO and intensity',
    eventScope='local', cameraPixels=[640, 360], giPixels=[320, 180], settings=json.loads(scene['settings']),
    knownCohort=27, selection=selection, eventSeconds=scene['eventSeconds'], requests=scene['requests'],
    rows=rows, firstObservedAtMost5PercentSeconds=first(5), firstObservedAtMost1PercentSeconds=first(1),
    sourceIntervalMedianSeconds=float(np.median(intervals)), sourceIntervalP95Seconds=float(np.percentile(intervals, 95)),
    maxGapAfterEventSeconds=scene['maxGapAfterEvent'], drainDurationSeconds=scene['drainDurationSeconds'],
    native=native, editor=editor, requestTimes=times,
    scope='Five discrete captures on an uneven explicit-render-request route. Source-frame clock, not readback completion. No ordinary-window, 960x540/30FPS, physical-zero, new-blue steady-state or continuous-half-second claim.',
    sources=dict(run=str(RUN), setup=str(setup)))
with OUT.open('x', encoding='utf-8') as stream:
    json.dump(result, stream, ensure_ascii=False, indent=2)
print(json.dumps({k: result[k] for k in ('status', 'requests', 'firstObservedAtMost5PercentSeconds',
      'firstObservedAtMost1PercentSeconds', 'sourceIntervalMedianSeconds', 'sourceIntervalP95Seconds',
      'maxGapAfterEventSeconds', 'drainDurationSeconds')}))
for row in rows:
    print(json.dumps({k: row[k] for k in ('workFrame', 'elapsedSeconds', 'meanOldGreenPercent', 'maxPointOldGreenPercent', 'sourceFormat')}))
