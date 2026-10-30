"""One original door-stop interval; no reference integration or quality gate."""
import importlib.util
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
ROOT = Path('I:/Unity test/Comparison/DoorStopResponse01')
REFERENCE = Path('I:/Unity test/Comparison/ValidationPackageV209-reference-frame0119-01')
spec = importlib.util.spec_from_file_location('existing_response_helpers', HERE.parent / 'stationary-history-01/analyze.py')
base = importlib.util.module_from_spec(spec)
spec.loader.exec_module(base)
load, require, Y = base.load, base.require, base.Y
FRAMES = (179, 189, 209)
OUTGOING = (119, 149, 179, 189, 209)


def main():
    require(not (HERE / 'result.json').exists(), 'Preserve original analysis')
    result = dict(status='unavailable', product='0181ef2 GI, retained in Release84', fullSequencePassed=False,
                  scope='Original door reaches its endpoint at179, then remains still through209. Sparse observations, not exact convergence, physical error or performance.',
                  signalFrames=list(FRAMES), outgoingFrames=list(OUTGOING), quantity=base.QUANTITY)
    try:
        native = load(HERE / 'native-exit.json')
        require(native['exitCode'] == 1, 'Unexpected exit; inspect original run')
        runs = list((ROOT / 'capture').glob('*/run.json'))
        require(len(runs) == 1, 'Expected one original run')
        directory = runs[0].parent
        run = load(runs[0])
        require(run['renderedFrames'] == 210 and run['failures'] == 0 and run['backendMismatches'] == 0,
                'Finite interval incomplete or failed')
        result['run'] = dict(directory=str(directory), status=run['status'], renderedFrames=run['renderedFrames'],
                             failures=run['failures'], backendMismatches=run['backendMismatches'], nativeExitCode=native['exitCode'])
        receipts = [json.loads(line) for line in (directory / 'frames.jsonl').read_text(encoding='utf-8-sig').splitlines()]
        require([r['logicalFrame'] for r in receipts] == list(range(210)), 'Missing frame receipts')
        for key in ('engineFrame', 'giFrame'):
            require(all(b[key] == a[key] + 1 for a, b in zip(receipts, receipts[1:])), 'Discontinuous ' + key)
        ordinary = {f: load(directory / f'frame-{f:04}.json') for f in OUTGOING}
        for row in ordinary.values():
            require(row['status'] == 'captured' and not row['error'] and row['lightsEnabled'], 'Missing image or unexpected light state')
        require(all(ordinary[f][key] == ordinary[179][key] for f in FRAMES
                    for key in ('cameraPosition', 'cameraRotation', 'cameraProjection', 'doorLocalPosition', 'reportedBackend')),
                'Door-stop state differs')
        old119 = load(base.OLD / 'frame-0119.json')
        require(all(ordinary[f][key] == old119[key] for f in OUTGOING
                    for key in ('cameraPosition', 'cameraRotation', 'cameraProjection')), 'Old screen footprint camera differs')
        result['doorPositions'] = {str(f): ordinary[f]['doorLocalPosition'] for f in OUTGOING}
        data, geometry, depth, lengths = {}, {}, {}, {}
        for f in FRAMES:
            capture = load(ROOT / 'signals' / f'frame-{f:04}-capture.json')
            require(capture['status'] == 'complete' and not capture['error'] and capture['readbacksCompleted']
                    and capture['logicalFrame'] == capture['workFrame'] == f and capture['retainedBytes'] == 0, 'Incomplete D capture')
            sample = base.unique(capture['samples'], 'signalId', 'filteredD')
            require(sample['status'] == 'available' and sample['quantity'] == base.QUANTITY
                    and (sample['width'], sample['height'], sample['format'], sample['rowOrder']) == (320, 180, 'rgba32f-le', 'top-to-bottom'), 'D descriptor differs')
            data[f] = base.read_measurements((ROOT / 'signals', capture, sample))
            for role, dest in (('geometry', geometry), ('depth', depth), ('moments', lengths)):
                descriptor = base.unique(capture['support'], 'role', role)
                values = base.rgba(base.linked(ROOT / 'signals', descriptor['file']), descriptor['width'], descriptor['height'])
                if role == 'depth':
                    values = values[1::2, 1::2, :]
                dest[f] = values
        same_surface = np.ones((180, 320), bool)
        for f in FRAMES:
            same_surface &= np.isfinite(geometry[f]).all(-1) & np.isfinite(depth[f]).all(-1)
            same_surface &= (geometry[f] == geometry[179]).all(-1) & (depth[f] == depth[179]).all(-1)
        names = [r['name'] for r in load(REFERENCE / 'geometry-index.json')['objects']]
        with np.load(REFERENCE / 'primary.npz', allow_pickle=False) as primary:
            old_footprint = primary['owner'] == names.index('Moving occluder')
        require(old_footprint.shape == (180, 320) and old_footprint.any(), 'Old footprint unavailable')
        result['regionDefinition'] = 'Frame119 independent primary owner grid selects only the OLD SCREEN FOOTPRINT. It does not label current surface identity. No reference radiance is read.'
        region = old_footprint & same_surface
        paired = region.copy()
        for f in FRAMES:
            paired &= data[f]['valid']
        require(paired.any(), 'No common known samples in the old footprint')
        result['oldFootprint'] = dict(screenPixels=int(old_footprint.sum()), sameDepthGeometryPixels=int(region.sum()), commonKnownPixels=int(paired.sum()),
                                     unknownPixels={str(f): int((region & ~data[f]['valid']).sum()) for f in FRAMES},
                                     lostEndpointKnownPixels={str(f): int((region & data[179]['valid'] & ~data[f]['valid']).sum()) for f in FRAMES}, frames={}, changes={})
        for f in FRAMES:
            rgb = data[f]['rgb'][paired]
            age = lengths[f][:, :, 2][paired]
            result['oldFootprint']['frames'][str(f)] = dict(meanRGB=rgb.mean(0).tolist(), meanY=float((rgb @ Y).mean()),
                                                          historyMedian=float(np.median(age)), historyMin=float(age.min()), historyMax=float(age.max()))
        for a, b in ((179, 189), (189, 209), (179, 209)):
            dy = (data[b]['rgb'][paired] - data[a]['rgb'][paired]) @ Y
            result['oldFootprint']['changes'][f'{a}-{b}'] = dict(meanYChange=float(dy.mean()), meanAbsoluteYChange=float(np.abs(dy).mean()))
        panel = Image.new('RGB', (1280, 1210), (22, 22, 27))
        draw = ImageDraw.Draw(panel)
        for i, f in enumerate(OUTGOING):
            row = ordinary[f]
            rgb = base.rgba(base.linked(directory, row['rawFile']), 640, 360)[:, :, :3]
            require(np.isfinite(rgb).all(), 'Nonfinite outgoing')
            x, y = (i % 2) * 640, (i // 2) * 390
            label = 'before motion' if f == 119 else 'moving' if f == 149 else 'endpoint / last move' if f == 179 else f'same endpoint, +{f - 179} frames'
            draw.text((x + 6, y + 7), f'Frame {f}: {label}', fill='white')
            panel.paste(Image.fromarray(base.preview(rgb)).transpose(Image.Transpose.FLIP_TOP_BOTTOM), (x, y + 25))
        draw.text((650, 850), 'Exposure1; Reinhard+sRGB.\nOutgoing indirect contribution, not D error.\nFrame209 is a later observation, not truth.\nSparse samples cannot give exact convergence.', fill='white')
        panel.save(HERE / 'outgoing.png')
        panel = Image.new('RGB', (960, 255), (22, 22, 27))
        draw = ImageDraw.Draw(panel)
        for i, f in enumerate(FRAMES):
            draw.text((320 * i + 5, 6), f'D at frame{f}; old screen footprint', fill='white')
            panel.paste(base.tile(data[f]['rgb'], region, data[f]['valid']), (320 * i, 26))
        draw.text((5, 214), 'Same depth/geometry at all 3 sampled endpoints. Gray: outside; magenta: unknown.', fill='white')
        draw.text((5, 234), 'No reference radiance; differences include normal lighting evolution and noise.', fill='white')
        panel.save(HERE / 'footprint.png')
        result['status'] = 'observed-limited-door-stop'
    except (ValueError, KeyError, OSError) as error:
        result['reason'] = str(error)
    with (HERE / 'result.json').open('x', encoding='utf-8') as stream:
        json.dump(result, stream, ensure_ascii=False, indent=2, allow_nan=False)
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
