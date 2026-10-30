"""Describe one completed finite light-restoration observation; no quality gate."""
import importlib.util
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
ROOT = Path('I:/Unity test/Comparison/LightRestoreResponse01')
spec = importlib.util.spec_from_file_location('existing_response_helpers', HERE.parent / 'stationary-history-01/analyze.py')
base = importlib.util.module_from_spec(spec)
spec.loader.exec_module(base)
load, require, Y = base.load, base.require, base.Y
FRAMES = (119, 330, 359)
OUTGOING = (119, 299, 300, 330, 359)


def main():
    require(not (HERE / 'result.json').exists(), 'Preserve original analysis')
    result = dict(status='unavailable', product='0181ef2 / Release83', fullSequencePassed=False,
                  scope='One 0-359 prefix; same-run light-restoration response, not local recolor, full motion quality, performance or exact convergence time.',
                  quantity=base.QUANTITY, frameSet=list(FRAMES), outgoingFrames=list(OUTGOING))
    try:
        native = load(HERE / 'native-exit.json')
        require(native['exitCode'] == 1, 'Unexpected native exit; inspect original run')
        captures = list((ROOT / 'capture').glob('*/run.json'))
        require(len(captures) == 1, 'Expected one original run')
        directory = captures[0].parent
        run = load(captures[0])
        require(run['renderedFrames'] == 360 and run['failures'] == 0 and run['backendMismatches'] == 0,
                'Original finite window incomplete or failed')
        result['run'] = dict(directory=str(directory), status=run['status'], renderedFrames=run['renderedFrames'],
                             failures=run['failures'], backendMismatches=run['backendMismatches'], nativeExitCode=native['exitCode'])
        receipts = [json.loads(line) for line in (directory / 'frames.jsonl').read_text(encoding='utf-8-sig').splitlines()]
        require([r['logicalFrame'] for r in receipts] == list(range(360)), 'Missing frame receipts')
        for key in ('engineFrame', 'giFrame'):
            require(all(b[key] == a[key] + 1 for a, b in zip(receipts, receipts[1:])), 'Discontinuous ' + key)
        ordinary = {f: load(directory / f'frame-{f:04}.json') for f in OUTGOING}
        for f, row in ordinary.items():
            require(row['status'] == 'captured' and not row['error'], 'Missing outgoing image')
            require(row['lightsEnabled'] == (f != 299), 'Unexpected light stage')
        equivalent = all(ordinary[f][key] == ordinary[119][key] for f in FRAMES
                         for key in ('cameraPosition', 'cameraRotation', 'cameraProjection', 'doorLocalPosition', 'lightsEnabled'))
        result['sameRunPhysicalStateMatches119'] = equivalent
        reference = base.reference_inputs(119)
        data, checks = {}, {}
        for f in FRAMES:
            checks[str(f)] = {}
            data[f] = base.read_measurements(base.input_gate(ROOT / 'signals', f, reference, checks[str(f)]))
        result['inputChecks'] = checks
        old_run = load(base.OLD / 'run.json')
        old_119 = load(base.OLD / 'frame-0119.json')
        reference_equivalent = equivalent and run['lights'] == old_run['lights'] and all(
            ordinary[119][key] == old_119[key] for key in ('cameraPosition', 'cameraRotation', 'cameraProjection', 'doorLocalPosition'))
        result['independentReferenceUsed'] = reference_equivalent
        if reference_equivalent:
            base.read_reference(reference)
            result['reference'] = dict(directory=str(reference['directory']), spp=reference['report']['spp'],
                                       maxDepth=reference['report']['maxDepth'], modelDifferences=reference['report']['modelDifferences'],
                                       uncertainty='Per-pixel Monte Carlo SE is not an ROI confidence interval; no new source certification.')
        result['rois'] = {}
        for name, region in reference['rois'].items():
            fixed = region & data[119]['valid']
            paired = fixed & data[330]['valid'] & data[359]['valid']
            values = dict(sourcePixels=int(region.sum()), baselineKnownPixels=int(fixed.sum()), pairedPixels=int(paired.sum()),
                          unknownPixels={str(f): int((region & ~data[f]['valid']).sum()) for f in FRAMES},
                          lostBaselinePixels={str(f): int((fixed & ~data[f]['valid']).sum()) for f in FRAMES}, frames={})
            require(bool(paired.any()), 'No paired samples in ' + name)
            original_y = float((data[119]['rgb'][paired] @ Y).mean())
            for f in FRAMES:
                rgb = data[f]['rgb'][paired]
                values['frames'][str(f)] = dict(meanRGB=rgb.mean(0).tolist(), meanY=float((rgb @ Y).mean()),
                    ratioTo119=float((rgb @ Y).mean() / original_y),
                    absolutePixelYChangeFrom119=float(np.abs((rgb - data[119]['rgb'][paired]) @ Y).mean()))
                if reference_equivalent:
                    values['frames'][str(f)]['independentReference'] = base.measures(data[f], reference, paired)
            values['meanAbsoluteYChange330To359'] = float(np.abs((data[359]['rgb'][paired] - data[330]['rgb'][paired]) @ Y).mean())
            result['rois'][name] = values
        panel = Image.new('RGB', (1280, 1210), (22, 22, 27))
        draw = ImageDraw.Draw(panel)
        result['outgoing'] = {}
        for i, f in enumerate(OUTGOING):
            row = ordinary[f]
            rgb = base.rgba(base.linked(directory, row['rawFile']), 640, 360)[:, :, :3]
            require(bool(np.isfinite(rgb).all()), 'Nonfinite outgoing RGB')
            x, y = (i % 2) * 640, (i // 2) * 390
            draw.text((x + 6, y + 7), f'Frame {f}: ' + ('lights off' if f == 299 else 'lights on'), fill='white')
            panel.paste(Image.fromarray(base.preview(rgb)).transpose(Image.Transpose.FLIP_TOP_BOTTOM), (x, y + 25))
            result['outgoing'][str(f)] = dict(meanY=float((rgb @ Y).mean()), rawFile=str(directory / row['rawFile']))
        draw.text((650, 850), 'Same exposure 1; Reinhard + sRGB.\nOutgoing = upsampled D * rho * AO * intensity.\nNot independent D error.\n119 is a pre-event observation, not truth.\nSparse samples do not give exact convergence.', fill='white')
        panel.save(HERE / 'outgoing.png')
        region = reference['rois'][base.NAMES[0]] | reference['rois'][base.NAMES[1]]
        panel = Image.new('RGB', (1280, 260), (22, 22, 27))
        draw = ImageDraw.Draw(panel)
        for i, f in enumerate(FRAMES):
            draw.text((320 * i + 5, 7), f'Current D, frame {f}', fill='white')
            panel.paste(base.tile(data[f]['rgb'], region, data[f]['valid']), (320 * i, 28))
        if reference_equivalent:
            draw.text((965, 7), 'Reused independent MC reference', fill='white')
            panel.paste(base.tile(reference['rgb'], region, np.ones(region.shape, bool)), (960, 28))
        else:
            draw.text((965, 55), 'Reference not used:\ninput equivalence not established.', fill='white')
        draw.text((5, 218), 'Same exposure 1, Reinhard+sRGB; vertical flip for display only. Gray: outside fixed ROIs. Magenta: unknown.', fill='white')
        draw.text((5, 238), 'No new physical integration, convergence threshold or production acceptance.', fill='white')
        panel.save(HERE / 'comparison.png')
        result['status'] = 'observed-limited-light-restoration'
    except (ValueError, KeyError, OSError) as error:
        result['reason'] = str(error)
    with (HERE / 'result.json').open('x', encoding='utf-8') as stream:
        json.dump(result, stream, indent=2, ensure_ascii=False, allow_nan=False)
    print(json.dumps({k: v for k, v in result.items() if k in ('status', 'reason', 'run', 'sameRunPhysicalStateMatches119', 'independentReferenceUsed', 'rois')}, indent=2))


if __name__ == '__main__':
    main()
