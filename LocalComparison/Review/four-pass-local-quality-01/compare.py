"""Four existing ordinary HDR time points: current two-ray DXR, three versus four spatial passes."""
import json
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
BASE = Path('I:/Unity test/Comparison/Release88DxrMotion01')
CURRENT = Path('I:/Unity test/Comparison/FourPassLocalQuality01')
FRAMES = (149, 179, 189, 209)


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def run(folder):
    host = read(folder / 'host-result.json')
    directory = Path(host['captureDirectory'])
    record = read(directory / 'run.json')
    assert record['renderedFrames'] == 210 and record['failures'] == 0 and record['backendMismatches'] == 0
    return directory, dict(status=record['status'], renderedFrames=record['renderedFrames'],
                          failures=record['failures'], backendMismatches=record['backendMismatches'])


def frame(directory, number):
    item = read(directory / f'frame-{number:04d}.json')
    assert item['logicalFrame'] == number and item['status'] == 'captured' and not item['error']
    assert (item['width'], item['height']) == (640, 360)
    rgba = np.fromfile(directory / item['rawFile'], dtype='<f4').reshape(360, 640, 4)
    assert np.isfinite(rgba).all()
    return item, rgba


def display(rgba):
    rgb = np.maximum(rgba[:, :, :3], 0)
    linear = rgb / (1 + rgb)
    srgb = np.where(linear <= .0031308, 12.92 * linear, 1.055 * linear ** (1 / 2.4) - .055)
    return Image.fromarray(np.uint8(np.clip(srgb * 255 + .5, 0, 255))).transpose(Image.Transpose.FLIP_TOP_BOTTOM)


assert not (HERE / 'comparison.json').exists(), 'Preserve the first comparison'
old, old_run = run(BASE)
new, new_run = run(CURRENT)
native = read(HERE / 'native-exit.json')
assert native['exitCode'] == 1  # Original 720-frame completion rule is unchanged.
result = dict(product='Release91 ffb42b1 / GI Runtime e352921 / two-ray DXR / filterIterations=4 candidate', fullSequencePassed=False, baselineRun=old_run, currentRun=new_run,
              quantity='Ordinary outgoing indirect contribution, not independent D or a physical reference',
              scope='Four matched reported-DXR time points, filterIterations 3 versus 4; visual ghosting/softness comparison, not all-frame or exact convergence proof',
              frames=[], visualReview='pending')
sheet = Image.new('RGB', (1280, 1625), (22, 22, 27))
draw = ImageDraw.Draw(sheet)
for row, number in enumerate(FRAMES):
    before, a = frame(old, number)
    after, b = frame(new, number)
    for key in ('cameraPosition', 'cameraRotation', 'cameraProjection', 'doorLocalPosition', 'lightsEnabled'):
        assert before[key] == after[key], f'Mismatched {key} at {number}'
    assert before['reportedBackend'] == 'reported-hardware' and before['diagnostics']['hardwareBackend']
    assert after['reportedBackend'] == 'reported-hardware' and after['diagnostics']['hardwareBackend']
    assert before['diagnosticFresh'] and after['diagnosticFresh'] and before['gpuReadbackCompleted'] and after['gpuReadbackCompleted']
    result['frames'].append(dict(frame=number, baselineBackend=before['reportedBackend'], backend=after['reportedBackend'],
        hardwareMeshes=after['diagnostics']['hardwareMeshes'], hardwareFallbacks=after['diagnostics']['hardwareFallbacks'],
        doorLocalPosition=after['doorLocalPosition'],
        baselineMeanRGB=a[:, :, :3].mean(axis=(0, 1), dtype=np.float64).tolist(),
        currentMeanRGB=b[:, :, :3].mean(axis=(0, 1), dtype=np.float64).tolist()))
    phase = {149: 'moving', 179: 'last movement', 189: 'stopped +10', 209: 'stopped +30'}[number]
    for x, title, pixels in ((0, '3 pass DXR (Release88 baseline)', a), (640, '4 pass DXR candidate', b)):
        draw.text((x + 8, row * 400 + 6), f'{title} | frame{number} | {phase}', fill='white')
        sheet.paste(display(pixels), (x, row * 400 + 28))
draw.text((8, 1605), 'Exposure1, Reinhard+sRGB. Four instants only; not a whole-trajectory or correct-color claim.', fill='white')
sheet.save(HERE / 'comparison.png')
(HERE / 'comparison.json').write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding='utf-8')
print(json.dumps(result, ensure_ascii=False, indent=2))
