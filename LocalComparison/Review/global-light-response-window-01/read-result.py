"""Read the one completed candidate; no rendering, hashes or reference integration."""
import json
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFont

here = Path(__file__).resolve().parent
baseline = json.loads((here.parent / 'current-lightoff-prefix-01/observations.json').read_text(encoding='utf-8-sig'))
base_dir = Path(baseline['captureDirectory'])
root = Path('I:/Unity test/Comparison/GlobalLightResponseWindow01')
runs = list((root / 'capture').glob('*/run.json'))
assert len(runs) == 1, 'Use only the one intended candidate run.'
candidate_dir = runs[0].parent
run = json.loads(runs[0].read_text())
assert (run['renderedFrames'], run['capturesWritten'], run['failures'], run['backendMismatches']) == (300, 4, 0, 0)
receipts = [json.loads(line) for line in (candidate_dir / 'frames.jsonl').read_text().splitlines()]
assert len(receipts) == 300
assert all(r['logicalFrame'] == i and r['giFrame'] == i + 1 and r['diagnosticFresh'] for i, r in enumerate(receipts))

frames = [239, 240, 270, 299]
weights = np.array([.2126, .7152, .0722], dtype=np.float64)
images, values, metadata = {}, {}, {}
for label, directory in [('baseline', base_dir), ('candidate', candidate_dir)]:
    for frame in frames:
        m = json.loads((directory / f'frame-{frame:04}.json').read_text())
        assert m['status'] == 'captured' and m['gpuReadbackCompleted'] and m['nonfiniteComponents'] == 0
        a = np.fromfile(directory / m['rawFile'], dtype='<f4').reshape(m['height'], m['width'], 4)
        images[label, frame] = a[..., :3]
        values[label, frame] = a[..., :3].astype(np.float64) @ weights
        metadata[label, frame] = m
for frame in frames:
    for key in ['cameraPosition', 'cameraRotation', 'cameraProjection', 'doorLocalPosition', 'lightsEnabled', 'width', 'height', 'giFrame', 'reportedBackend']:
        assert metadata['baseline', frame][key] == metadata['candidate', frame][key], (frame, key)

change = {label: float(np.abs(values[label, 270] - values[label, 299]).mean()) for label in ['baseline', 'candidate']}
means = {label: {str(f): float(values[label, f].mean()) for f in frames} for label in ['baseline', 'candidate']}
reduction = 1 - change['candidate'] / change['baseline']
late_difference = means['candidate']['299'] / means['baseline']['299'] - 1
result = dict(candidateDirectory=str(candidate_dir), completeSequence=False, sequenceStatus=run['status'],
    quantity=baseline['quantity'], meanOutputY=means, absolute270To299YChange=change,
    relativeReductionInTwoSnapshotChange=reduction, relative299MeanYDifference=late_difference,
    numericScreenPassed=reduction >= .2 and abs(late_difference) <= .1,
    visualReview='pending', adoption='pending',
    limitation='No convergence speed, physical-error or flicker inference; baseline 299 is not truth.')
(here / 'comparison.json').write_text(json.dumps(result, indent=2), encoding='utf-8')

font = ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf', 20)
small = ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf', 16)
canvas = Image.new('RGB', (1310, 1712), '#131820')
draw = ImageDraw.Draw(canvas)
draw.text((15, 12), 'Global light response | same exposure 1, Reinhard + sRGB | indirect outgoing, not D', font=font, fill='white')
draw.text((15, 44), 'Left: existing response     Right: 32-preparation cache response candidate     Emissive sources remain on.', font=small, fill='#bdc8d7')
for row, frame in enumerate(frames):
    y = 84 + row * 403
    for col, label in enumerate(['baseline', 'candidate']):
        x = 10 + col * 650
        rgb = np.maximum(images[label, frame], 0)
        rgb = rgb / (1 + rgb)
        rgb = np.where(rgb <= .0031308, 12.92 * rgb, 1.055 * np.power(rgb, 1 / 2.4) - .055)
        panel = Image.fromarray(np.uint8(np.clip(rgb, 0, 1)[::-1] * 255 + .5))
        draw.text((x, y), f'{label}  frame {frame}  mean Y {means[label][str(frame)]:.8f}', font=small, fill='white')
        canvas.paste(panel, (x, y + 27))
canvas.save(here / 'comparison.png')
print(json.dumps(result, indent=2))
