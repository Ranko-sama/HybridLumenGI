"""One finite local recolor observation. Late color is not independent truth."""
import importlib.util
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
ROOT = Path('I:/Unity test/Comparison/LocalRecolorResponse01')
spec = importlib.util.spec_from_file_location('existing_response_helpers', HERE.parent / 'stationary-history-01/analyze.py')
base = importlib.util.module_from_spec(spec)
spec.loader.exec_module(base)
load, require, Y = base.load, base.require, base.Y
FRAMES = (119, 150, 179, 239)
OUTGOING = (119, 120, 150, 179, 239)


def main():
    require(not (HERE / 'result.json').exists(), 'Preserve original analysis')
    result = dict(status='unavailable', product='0181ef2 / Release83', fullSequencePassed=False,
                  scope='One local Red wall MPB event with fixed door, camera, lights and receivers. No independent blue reference, absolute old-color residue, exact convergence time or performance claim.',
                  quantity=base.QUANTITY, frameSet=list(FRAMES), outgoingFrames=list(OUTGOING), independentRadianceReferenceUsed=False)
    try:
        native = load(HERE / 'native-exit.json')
        require(native['exitCode'] == 1, 'Unexpected native exit; inspect original run')
        captures = list((ROOT / 'capture').glob('*/run.json'))
        require(len(captures) == 1, 'Expected one original run')
        directory = captures[0].parent
        run = load(captures[0])
        require(run['renderedFrames'] == 240 and run['failures'] == 0 and run['backendMismatches'] == 0, 'Finite window incomplete or failed')
        result['run'] = dict(directory=str(directory), status=run['status'], renderedFrames=run['renderedFrames'],
                             failures=run['failures'], backendMismatches=run['backendMismatches'], nativeExitCode=native['exitCode'])
        receipts = [json.loads(line) for line in (directory / 'frames.jsonl').read_text(encoding='utf-8-sig').splitlines()]
        require([r['logicalFrame'] for r in receipts] == list(range(240)), 'Missing frame receipts')
        for key in ('engineFrame', 'giFrame'):
            require(all(b[key] == a[key] + 1 for a, b in zip(receipts, receipts[1:])), 'Discontinuous ' + key)
        event = load(ROOT / 'local-recolor-event.json')
        require(event['afterRenderedLogicalFrame'] == 119 and event['firstAffectedLogicalFrame'] == 120 and
                event['engineFrame'] == receipts[119]['engineFrame'] and receipts[120]['engineFrame'] == event['engineFrame'] + 1,
                'Event does not precede the declared120 render')
        requested = np.array([event['requestedColor'][k] for k in ('r', 'g', 'b', 'a')])
        observed = np.array([event['readBackMpbColor'][k] for k in ('r', 'g', 'b', 'a')])
        # Read-back R/G differ by <3e-8 in the recorded float values. This is
        # source-operation matching only, not a radiometric error threshold.
        require(event['renderer'] == 'Red wall' and np.allclose(requested, observed, rtol=0, atol=1e-6) and
                event['previousEffectiveColor'] != event['readBackMpbColor'], 'Local material change not observed')
        result['event'] = event
        invariant_keys = ('cameraPosition', 'cameraRotation', 'cameraProjection', 'doorLocalPosition', 'lightsEnabled')
        require(all(row[key] == receipts[0][key] for row in receipts for key in invariant_keys), 'Camera, door or light stage changed')
        require(receipts[0]['lightsEnabled'], 'Expected lights on throughout')
        result['cameraDoorAndLightStageUnchanged'] = True
        # Only existing source geometry/ROI and material-support metadata are reused.
        # Do not load any independent reference radiance or call its error metrics.
        geometry = base.reference_inputs(119)
        data, checks = {}, {}
        for f in FRAMES:
            checks[str(f)] = {}
            data[f] = base.read_measurements(base.input_gate(ROOT / 'signals', f, geometry, checks[str(f)]))
        result['inputChecks'] = checks
        result['rois'] = {}
        for name, region in geometry['rois'].items():
            fixed = region & data[119]['valid']
            paired = fixed.copy()
            for f in FRAMES[1:]:
                paired &= data[f]['valid']
            require(bool(paired.any()), 'No paired samples in ' + name)
            values = dict(sourcePixels=int(region.sum()), baselineKnownPixels=int(fixed.sum()), pairedPixels=int(paired.sum()),
                          unknownPixels={str(f): int((region & ~data[f]['valid']).sum()) for f in FRAMES},
                          lostBaselinePixels={str(f): int((fixed & ~data[f]['valid']).sum()) for f in FRAMES}, frames={}, intervals=[])
            means = {f: data[f]['rgb'][paired].mean(0) for f in FRAMES}
            require(all(float(v.sum()) > 0 for v in means.values()), 'Undefined mean chromaticity')
            chroma = {f: rgb / rgb.sum() for f, rgb in means.items()}
            for f in FRAMES:
                values['frames'][str(f)] = dict(meanRGB=means[f].tolist(), meanY=float(means[f] @ Y),
                    meanRgbChromaticity=chroma[f].tolist(), chromaticityL1ToLate239=float(np.abs(chroma[f] - chroma[239]).sum()),
                    meanAbsolutePixelRgbChangeFrom119=float(np.abs(data[f]['rgb'][paired] - data[119]['rgb'][paired]).mean()))
            for a, b in zip(FRAMES, FRAMES[1:]):
                delta = data[b]['rgb'][paired] - data[a]['rgb'][paired]
                values['intervals'].append(dict(first=a, last=b, meanAbsolutePixelRgbChange=float(np.abs(delta).mean()),
                    meanAbsolutePixelYChange=float(np.abs(delta @ Y).mean()), meanChromaticityL1Change=float(np.abs(chroma[b] - chroma[a]).sum())))
            result['rois'][name] = values
        region = geometry['rois'][base.NAMES[0]] | geometry['rois'][base.NAMES[1]]
        panel = Image.new('RGB', (1280, 260), (22, 22, 27))
        draw = ImageDraw.Draw(panel)
        for i, f in enumerate(FRAMES):
            draw.text((320 * i + 5, 7), f'D {f}: ' + ('before recolor' if f == 119 else f'{f - 120} frames after'), fill='white')
            panel.paste(base.tile(data[f]['rgb'], region, data[f]['valid']), (320 * i, 28))
        draw.text((5, 218), 'Unchanged Floor/White materials; exposure1, Reinhard+sRGB. Gray: outside ROI; magenta: unknown.', fill='white')
        draw.text((5, 238), '239 is a late observation, not truth. No independent blue reference or exact old-color residue.', fill='white')
        panel.save(HERE / 'comparison.png')
        panel = Image.new('RGB', (1280, 1210), (22, 22, 27))
        draw = ImageDraw.Draw(panel)
        result['outgoing'] = {}
        for i, f in enumerate(OUTGOING):
            row = load(directory / f'frame-{f:04}.json')
            require(row['status'] == 'captured' and not row['error'], 'Missing outgoing image')
            rgb = base.rgba(base.linked(directory, row['rawFile']), 640, 360)[:, :, :3]
            require(bool(np.isfinite(rgb).all()), 'Nonfinite outgoing RGB')
            x, y = (i % 2) * 640, (i // 2) * 390
            draw.text((x + 6, y + 7), f'Frame {f}: ' + ('red wall' if f == 119 else f'blue wall, +{f - 120} frames'), fill='white')
            panel.paste(Image.fromarray(base.preview(rgb)).transpose(Image.Transpose.FLIP_TOP_BOTTOM), (x, y + 25))
            result['outgoing'][str(f)] = dict(meanY=float((rgb @ Y).mean()), rawFile=str(directory / row['rawFile']))
        draw.text((650, 850), 'Same exposure1; Reinhard+sRGB.\nOutgoing = upsampled D * rho * AO * intensity.\nThe changed wall itself is not the receiver metric.\nNo independent blue-state reference.\nSparse samples do not give exact convergence.', fill='white')
        panel.save(HERE / 'outgoing.png')
        result['status'] = 'observed-limited-local-recolor-response'
    except (ValueError, KeyError, OSError) as error:
        result['reason'] = str(error)
    with (HERE / 'result.json').open('x', encoding='utf-8') as stream:
        json.dump(result, stream, indent=2, ensure_ascii=False, allow_nan=False)
    print(json.dumps({k: v for k, v in result.items() if k in ('status', 'reason', 'run', 'event', 'rois')}, indent=2))


if __name__ == '__main__':
    main()
