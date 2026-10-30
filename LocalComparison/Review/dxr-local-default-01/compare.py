"""One predeclared current software/DXR119 comparison, reusing existing helpers."""
import importlib.util
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
ROOTS = {'software': Path('I:/Unity test/Comparison/LightRestoreResponse01'),
         'dxr': Path('I:/Unity test/Comparison/DxrLocalDefault01')}
spec = importlib.util.spec_from_file_location('existing_response_helpers', HERE.parent / 'stationary-history-01/analyze.py')
base = importlib.util.module_from_spec(spec)
spec.loader.exec_module(base)
load, require = base.load, base.require


def main():
    require(not (HERE / 'result.json').exists(), 'Preserve original comparison')
    result = dict(status='unavailable', product='0181ef2 GI retained in Release84', fullSequencePassed=False,
                  scope='Only a local startup preference decision; static119 in saved V209 scene, 640x360 outgoing/320x180 D. No dynamic parity, new cost measurement or fullG4 verdict.')
    try:
        require(load(HERE / 'native-exit.json')['exitCode'] == 1, 'Unexpected exit; inspect original run')
        dirs, runs, frames, settings, data, checks = {}, {}, {}, {}, {}, {}
        reference = base.reference_inputs(119)
        base.read_reference(reference)
        for label, root in ROOTS.items():
            dirs[label] = Path(load(root / 'host-result.json')['captureDirectory'])
            runs[label] = load(dirs[label] / 'run.json')
            frames[label] = load(dirs[label] / 'frame-0119.json')
            settings[label] = load(dirs[label] / runs[label]['featureSnapshot'])['settings']
            require(runs[label]['failures'] == 0 and frames[label]['status'] == 'captured' and not frames[label]['error'], 'Missing original frame')
            checks[label] = {}
            data[label] = base.read_measurements(base.input_gate(root / 'signals', 119, reference, checks[label]))
        result['run'] = {k: dict(directory=str(dirs[k]), status=v['status'], renderedFrames=v['renderedFrames'],
                                failures=v['failures'], backendMismatches=v['backendMismatches']) for k, v in runs.items()}
        require(runs['dxr']['renderedFrames'] == 120, 'Incomplete finite prefix')
        receipts = [json.loads(line) for line in (dirs['dxr'] / 'frames.jsonl').read_text(encoding='utf-8-sig').splitlines()]
        require([r['logicalFrame'] for r in receipts] == list(range(120)), 'Missing frame receipts')
        for key in ('engineFrame', 'giFrame'):
            require(all(b[key] == a[key] + 1 for a, b in zip(receipts, receipts[1:])), 'Discontinuous ' + key)
        changes = {k: [settings['software'].get(k), settings['dxr'].get(k)]
                   for k in set(settings['software']) | set(settings['dxr']) if settings['software'].get(k) != settings['dxr'].get(k)}
        result['settingsDifferences'] = changes
        require(changes == {'preferHardwareTracing': [False, True]}, 'Unexpected settings differences')
        for key in ('cameraPosition', 'cameraRotation', 'cameraProjection', 'doorLocalPosition', 'lightsEnabled', 'width', 'height'):
            require(frames['software'][key] == frames['dxr'][key], 'Frame input differs: ' + key)
        require(runs['software']['lights'] == runs['dxr']['lights'], 'Light inputs differ')
        result['inputChecks'] = checks
        diag = frames['dxr']['diagnostics']
        result['backendAt119'] = {k: diag[k] for k in ('hardwareBackend', 'hardwareMeshes', 'hardwareFallbacks', 'hardwareMaterialUnknownRecords', 'exactSoftwareGeometry')}
        require(diag['hardwareBackend'] and diag['hardwareMeshes'] > 0 and diag['hardwareFallbacks'] == 0
                and diag['hardwareMaterialUnknownRecords'] == 0, 'Actual DXR unavailable or partial at119')
        require(not frames['software']['diagnostics']['hardwareBackend'], 'Baseline is not software')
        result['rois'] = {}
        numeric_ok = True
        for name, region in reference['rois'].items():
            fixed = region & data['software']['valid']
            paired = fixed & data['dxr']['valid']
            loss = int((fixed & ~data['dxr']['valid']).sum())
            require(paired.any(), 'No common known samples: ' + name)
            row = dict(sourcePixels=int(region.sum()), softwareKnown=int(fixed.sum()), commonKnown=int(paired.sum()), lostSoftwareKnown=loss,
                       unknown={k: int((region & ~v['valid']).sum()) for k, v in data.items()},
                       metrics={k: base.measures(v, reference, paired) for k, v in data.items()})
            row['notWorse'] = {k: row['metrics']['dxr'][k] <= row['metrics']['software'][k]
                               for k in ('absoluteMeanBiasY', 'pixelYMAE', 'meanChromaL1')}
            row['meanAbsoluteBackendYDifference'] = float(np.abs((data['dxr']['rgb'][paired] - data['software']['rgb'][paired]) @ base.Y).mean())
            numeric_ok &= loss == 0 and all(row['notWorse'].values())
            result['rois'][name] = row
        result['numericAdoptionConditionsMet'] = bool(numeric_ok)
        result['visualReview'] = 'See result.md; no automatic adoption from numbers alone'
        panel = Image.new('RGB', (1280, 420), (22, 22, 27))
        draw = ImageDraw.Draw(panel)
        for i, label in enumerate(ROOTS):
            rgb = base.rgba(base.linked(dirs[label], frames[label]['rawFile']), 640, 360)[:, :, :3]
            require(np.isfinite(rgb).all(), 'Nonfinite outgoing')
            draw.text((i * 640 + 6, 6), label + ' / current frame119 / outgoing indirect', fill='white')
            panel.paste(Image.fromarray(base.preview(rgb)).transpose(Image.Transpose.FLIP_TOP_BOTTOM), (i * 640, 26))
        draw.text((6, 395), 'Exposure1, Reinhard+sRGB. One static scene/time; not dynamic equality or 960x540 performance.', fill='white')
        panel.save(HERE / 'outgoing.png')
        panel = Image.new('RGB', (960, 255), (22, 22, 27))
        draw = ImageDraw.Draw(panel)
        region = reference['rois'][base.NAMES[0]] | reference['rois'][base.NAMES[1]]
        for i, label in enumerate(ROOTS):
            draw.text((i * 320 + 6, 6), label + ' / current D119', fill='white')
            panel.paste(base.tile(data[label]['rgb'], region, data[label]['valid']), (i * 320, 26))
        draw.text((646, 6), 'Existing independent reference D119', fill='white')
        panel.paste(base.tile(reference['rgb'], region, np.ones(region.shape, bool)), (640, 26))
        draw.text((6, 214), 'Same display mapping; gray outside fixed Floor/White ROIs, magenta unknown.', fill='white')
        draw.text((6, 234), 'Reused 256spp/8-bounce reference and model limitations; no new integration.', fill='white')
        panel.save(HERE / 'comparison.png')
        result['status'] = 'observed-limited-current-backend-comparison'
    except (ValueError, KeyError, OSError) as error:
        result['reason'] = str(error)
    with (HERE / 'result.json').open('x', encoding='utf-8') as stream:
        json.dump(result, stream, ensure_ascii=False, indent=2, allow_nan=False)
    print(json.dumps({k: v for k, v in result.items() if k != 'inputChecks'}, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
