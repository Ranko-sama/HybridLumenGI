"""Compare the single qualified same-frame depth pair; no rendering or source hashes."""
import json
from pathlib import Path
import sys
import numpy as np

RUN = Path(sys.argv[1]) if len(sys.argv) > 1 else Path('I:/Unity test/Comparison/AlphaCoverage124RuntimeInput')
OUT = Path(__file__).resolve().parent
TOLERANCE = 1e-6
INSET = 2

def load(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))

scene = load(RUN / 'scene-result.json')
editor = load(RUN / 'editor-result.json')
setup = RUN.parent / (RUN.name + 'Setup')
native_exit = load(setup / 'native-exit.json')
capture = load(RUN / 'signals/frame-0002-capture.json')
assert native_exit['exitCode'] == 0 and editor['restored'] and editor['status'] == 'collected'
assert scene['status'] == 'collected' and scene['requests'] == 3 and scene['logicalFrame'] == scene['workFrame'] == 2
assert scene['composition'] == 'Additive' and scene['captureDrained']
assert capture['status'] == 'complete' and capture['readbacksCompleted'] and capture['retainedBytes'] == 0
assert capture['logicalFrame'] == capture['workFrame'] == 2 and capture['engineFrame'] == scene['engineFrame']
material = scene['foregroundMaterial']
assert material['alphaTest'] and material['alphaToMask'] == 0 and material['cutoff'] == .5
assert material['alphaZero'] == material['alphaOne'] == 512 and material['alphaOther'] == 0

def plane(role):
    q = next(s for s in capture['support'] if s['role'] == role)
    shape = (q['height'], q['width'])
    data = np.fromfile(RUN / 'signals' / q['file'], '<f4').reshape(*shape, 4)
    valid = np.fromfile(RUN / 'signals' / q['validity']['file'], 'u1').reshape(shape) != 0
    return data, valid

depth, depth_valid = plane('depth')
redraw, redraw_valid = plane('captureDepth')
surface, surface_valid = plane('material')
assert depth.shape == redraw.shape == surface.shape == (128, 128, 4)
x0, y0, x1, y1 = (scene['foregroundPixelBoundsBottomLeft'][c] for c in 'xyzw')
y, x = np.indices((128, 128))
# Geometry-defined interior; internal cutout edges are deliberately retained.
domain = ((x+.5 >= x0+INSET) & (x+.5 < x1-INSET) &
          (y+.5 >= 128-y1+INSET) & (y+.5 < 128-y0-INSET))
assert domain.any() and (depth_valid & redraw_valid & surface_valid)[domain].all()
assert np.isfinite(depth[domain]).all() and np.isfinite(redraw[domain]).all()
corners = scene['foregroundGpuClipCorners']
front_depth = float(np.mean([p['z']/p['w'] for p in corners]))
projection = np.array(scene['captureCamera']['projection']).reshape(4, 4)
view = np.array(scene['captureCamera']['view']).reshape(4, 4)
back_matrix = np.array([[scene['backgroundMatrix'][f'e{r}{c}'] for c in range(4)] for r in range(4)])
back_clip = projection @ view @ back_matrix @ [0, 0, 0, 1]
back_depth = float(back_clip[2]/back_clip[3])
assert abs(front_depth-back_depth) > 100*TOLERANCE
foreground = domain & (np.abs(depth[:, :, 0]-front_depth) <= TOLERANCE)
background = domain & (np.abs(depth[:, :, 0]-back_depth) <= TOLERANCE)
assert foreground.any() and background.any() and np.array_equal(foreground | background, domain)
difference = np.abs(depth[:, :, 0].astype(float)-redraw[:, :, 0].astype(float))
bad = domain & (difference > TOLERANCE)
near_rgb = surface[foreground, :3].mean(0, dtype=np.float64)
far_rgb = surface[background, :3].mean(0, dtype=np.float64)
result = dict(status='qualified-limited-input' if not bad.any() else 'coverage-mismatch',
    composition='Additive', cameraPixels=[128, 128], giPixels=[64, 64],
    tolerance=TOLERANCE, geometryInsetFullPixels=INSET, internalAlphaEdgesIncluded=True,
    domainPixels=int(domain.sum()), foregroundPixels=int(foreground.sum()), backgroundPixels=int(background.sum()),
    unknownPixels=0, mismatchedPixels=int(bad.sum()), maxAbsoluteDepthDifference=float(difference[domain].max()),
    expectedForegroundDepth=front_depth, expectedBackgroundDepth=back_depth,
    foregroundCapturedMeanRGB=near_rgb.tolist(), backgroundCapturedMeanRGB=far_rgb.tolist(),
    material=material, camera=scene['captureCamera'], projectedBounds=scene['foregroundPixelBoundsBottomLeft'],
    diagnostics=scene['diagnostics'], nativeExit=native_exit, editor=editor,
    firstAttempt=dict(path='I:/Unity test/Comparison/AlphaCoverage124', nativeExitCode=1, requests=0,
        reason='URP asset import restored AlphaToMask=1; input assertion stopped before rendering.'),
    launchPreparationFailure=dict(path='I:/Unity test/Comparison/AlphaCoverage124CorrectedSetup', unityLaunched=False,
        reason='A loop variable overwrote the requested log stem; launcher rejected the file name before Unity start.'),
    sources=dict(run=str(RUN), setup=str(setup)),
    scope='One runtime AlphaToMask=0 ordinary Additive binary-cutout input. Not author-default flag1, MSAA, Replace, DXR alpha traversal, Player, or full G1 acceptance.')
with (OUT / 'result.json').open('x', encoding='utf-8') as stream:
    json.dump(result, stream, ensure_ascii=False, indent=2)
if (OUT / 'signals.npz').exists():
    raise FileExistsError('Preserve existing measured planes')
np.savez_compressed(OUT / 'signals.npz', nativeDepth=depth[:, :, 0], captureDepth=redraw[:, :, 0],
                    nativeValid=depth_valid, captureValid=redraw_valid, material=surface,
                    materialValid=surface_valid, domain=domain, foreground=foreground, background=background)
print(json.dumps({k: result[k] for k in ('status', 'domainPixels', 'foregroundPixels', 'backgroundPixels',
      'mismatchedPixels', 'maxAbsoluteDepthDifference', 'foregroundCapturedMeanRGB', 'backgroundCapturedMeanRGB')}))
