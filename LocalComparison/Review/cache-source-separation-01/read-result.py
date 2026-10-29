"""Read the one source-cache candidate; no rendering, hashes or physical reference."""
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont


def require(value, reason):
    if not value:
        raise ValueError(reason)


def read_json(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


here = Path(__file__).resolve().parent
require(not (here / 'comparison.json').exists() and not (here / 'comparison.png').exists(),
        'Preserve existing comparison outputs.')
criterion = read_json(here / 'criterion.json')
baseline = read_json(here.parent / 'current-lightoff-prefix-01/observations.json')
base_dir = Path(baseline['captureDirectory'])
root = Path('I:/Unity test/Comparison/CacheSourceSeparation01')
runs = list((root / 'capture').glob('*/run.json'))
require(len(runs) == 1, 'Use only the one intended candidate run.')
candidate_dir = runs[0].parent
run = read_json(runs[0])
base_run = read_json(base_dir / 'run.json')
require((run['totalLogicalFrames'], run['renderedFrames'], run['capturesWritten'],
         run['failures'], run['backendMismatches']) == (720, 300, 4, 0, 0),
        'The intended 300-frame prefix or its captures are incomplete/failed early.')
require(not run.get('lastError'), 'The sequence recorded an error before the intentional stop.')
receipts = [json.loads(line) for line in (candidate_dir / 'frames.jsonl').read_text(encoding='utf-8-sig').splitlines()]
require(len(receipts) == 300, 'Expected exactly 300 render receipts.')
require(all(r['logicalFrame'] == i and r['engineFrame'] == run['firstEngineFrame'] + i and
            r['giFrame'] == i + 1 and r['diagnostics']['frame'] == i + 1 and
            r['diagnosticFresh'] and not r.get('error') and
            r['reportedBackend'] == 'reported-software' and
            not r['diagnostics']['hardwareBackend'] and r['diagnostics']['exactSoftwareGeometry']
            for i, r in enumerate(receipts)), 'Missing/stale GI, nonconsecutive receipt or changed backend.')
for key in ['width', 'height', 'graphicsApi', 'colorSpace', 'rowOrder', 'targetFormat', 'targetSRGB',
            'postProcessing', 'fog']:
    require(base_run[key] == run[key], 'Capture configuration mismatch: ' + key)

frames = [239, 240, 270, 299]
weights = np.array([.2126, .7152, .0722], dtype=np.float64)
images, values, metadata = {}, {}, {}
for label, directory in [('baseline', base_dir), ('candidate', candidate_dir)]:
    for frame in frames:
        m = read_json(directory / f'frame-{frame:04}.json')
        require(m['logicalFrame'] == frame and m['giFrame'] == frame + 1 and
                m['status'] == 'captured' and not m.get('error') and m['diagnosticFresh'] and
                m['gpuReadbackCompleted'] and m['nonfiniteComponents'] == 0,
                f'{label} frame {frame}: capture receipt is not complete.')
        require(m['rawFile'] == f'frame-{frame:04}.rgba32f', 'Unexpected raw file identity.')
        a = np.fromfile(directory / m['rawFile'], dtype='<f4')
        require(a.size == m['height'] * m['width'] * 4 and bool(np.isfinite(a).all()),
                f'{label} frame {frame}: raw RGBA size/nonfinite failure.')
        a = a.reshape(m['height'], m['width'], 4)
        images[label, frame] = a[..., :3]
        values[label, frame] = a[..., :3].astype(np.float64) @ weights
        metadata[label, frame] = m
for frame in frames:
    for key in ['cameraPosition', 'cameraRotation', 'cameraProjection', 'doorLocalPosition', 'lightsEnabled',
                'width', 'height', 'giFrame', 'reportedBackend']:
        require(metadata['baseline', frame][key] == metadata['candidate', frame][key], f'{frame}: {key} mismatch.')

means = {label: {str(f): float(values[label, f].mean()) for f in frames} for label in ['baseline', 'candidate']}
early_change = {label: float(np.abs(values[label, 240] - values[label, 299]).mean()) for label in ['baseline', 'candidate']}
late_change = {label: float(np.abs(values[label, 270] - values[label, 299]).mean()) for label in ['baseline', 'candidate']}
require(means['baseline']['239'] > 0 and early_change['baseline'] > 0,
        'Relative pre-off/reduction criteria are undefined for this baseline.')
preoff_difference = means['candidate']['239'] / means['baseline']['239'] - 1
reduction = 1 - early_change['candidate'] / early_change['baseline']
checks = dict(
    preOff239MeanWithinLimit=abs(preoff_difference) <= criterion['maximumRelative239MeanYDifference'],
    change240To299Reduced=reduction >= criterion['minimum240To299AbsoluteYChangeReduction'],
    change270To299WithinBaseline=late_change['candidate'] <=
        late_change['baseline'] * criterion['maximum270To299AbsoluteYChangeRelativeToBaseline'])
result = dict(
    baselineDirectory=str(base_dir), candidateDirectory=str(candidate_dir), frames=frames,
    prefixReceiptsComplete=True, completeSequence=False, sequenceStatus=run['status'],
    quantity=baseline['quantity'], rawRgbaAllFinite=True, meanOutputY=means,
    relative239MeanYDifference=preoff_difference,
    absolute240To299YChange=early_change, relativeReduction240To299YChange=reduction,
    absolute270To299YChange=late_change,
    relative270To299YChange=(late_change['candidate'] / late_change['baseline'] if late_change['baseline'] > 0 else None),
    numericChecks=checks, numericScreenPassed=all(checks.values()), criterion=criterion,
    visualReview='pending', adoption='pending',
    display='Exposure 1, Reinhard + sRGB; vertical flip only for display. Metrics use unchanged raw rows.',
    scope=criterion['nativeScope'],
    limitation=criterion['limitations'] + ' All-pixel outgoing Y snapshot changes only; no independent validity mask or physical reference. '
        'The intentional incomplete sequence status is retained, and numeric acceptance does not satisfy visual requirements.')

font = ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf', 20)
small = ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf', 16)
width, height = run['width'], run['height']
canvas = Image.new('RGB', (width * 2 + 30, 100 + len(frames) * (height + 43)), '#131820')
draw = ImageDraw.Draw(canvas)
draw.text((15, 12), 'Source-separated cache | same exposure 1, Reinhard + sRGB | indirect outgoing, not D', font=font, fill='white')
draw.text((15, 44), 'Left: existing baseline     Right: source-cache candidate     Emissive sources remain on. Visual review pending.', font=small, fill='#bdc8d7')
for row, frame in enumerate(frames):
    y = 84 + row * (height + 43)
    for col, label in enumerate(['baseline', 'candidate']):
        x = 10 + col * (width + 10)
        rgb = np.maximum(images[label, frame], 0)
        rgb = rgb / (1 + rgb)
        rgb = np.where(rgb <= .0031308, 12.92 * rgb, 1.055 * np.power(rgb, 1 / 2.4) - .055)
        panel = Image.fromarray(np.uint8(np.clip(rgb, 0, 1)[::-1] * 255 + .5))
        draw.text((x, y), f'{label}  frame {frame}  mean Y {means[label][str(frame)]:.8f}', font=small, fill='white')
        canvas.paste(panel, (x, y + 27))
canvas.save(here / 'comparison.png')
(here / 'comparison.json').write_text(json.dumps(result, indent=2, allow_nan=False), encoding='utf-8')
print(json.dumps(result, indent=2, allow_nan=False))
