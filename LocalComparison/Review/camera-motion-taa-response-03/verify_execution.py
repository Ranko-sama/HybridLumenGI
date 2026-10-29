"""Source, execution and restoration verification; no temporal acceptance here."""
import hashlib
import importlib.util
import json
from pathlib import Path
import traceback

P = Path(__file__).resolve().parent
ROOT = P.parents[2]
PROJECT = Path('I:/Unity test/Project')
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
load = lambda p: json.loads(p.read_text(encoding='utf-8-sig'))


def module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


def verify():
    inputs = {}
    def pin(path, expected=None):
        digest = sha(path)
        assert expected is None or digest == expected, str(path)
        inputs[str(path)] = digest
    freeze = load(P / 'source-freeze.json')
    for group in ('sources', 'evidence'):
        for relative, digest in freeze[group].items():
            pin(ROOT / relative, digest)
    manifest = load(P / 'instrumentation/manifest.json')
    product = manifest['productSourceSha256']
    assert len(product) == 112 and len(manifest['files']) == 9
    for relative, digest in product.items():
        pin(ROOT / relative, digest)
        pin(PROJECT / 'Assets/HybridLumenGI' / relative, digest)
    for row in manifest['files']:
        pin(P / 'instrumentation' / row['prepared'], row['sha256'])
        pin(P / 'instrumentation/post-run' / row['path'], row['sha256'])
        if row['original']:
            pin(PROJECT / row['path'], row['originalSha256'])
        else:
            assert not (PROJECT / row['path']).exists()
    for row in load(P / 'instrumentation/protected.json'):
        pin(PROJECT / row['path'], row['sha256'])
    restored = load(P / 'instrumentation/restoration.json')
    assert restored['currentProductRestored'] and restored['ownedRootRemoved']
    assert all(row['restored'] for row in restored['protected'])
    owned = PROJECT / 'Assets/CameraMotionTaa01'
    assert not owned.exists() and not Path(str(owned) + '.meta').exists()
    assert load(P / 'preflight/exit.json')['exitCode'] == 0
    assert load(P / 'identity-shaders.json')['status'] == 'passed'
    assert load(P / 'compute-reuse.json')['passed']
    assert load(P / 'native-exit.json')['exitCode'] == 0
    scene = load(P / 'native/scene-result.json')
    assert scene['status'] == 'collected' and scene['error'] == '' and scene['readbacksDrained']
    assert all(scene[field] == 48 for field in ('requests', 'cameraBegins', 'cameraEnds', 'contextBegins', 'contextEnds'))
    assert scene['previewCaptures'] == 3 and scene['api'] == 'Direct3D12'
    scanner = module('camera_log_scanner', ROOT / 'LocalComparison/Harness/native_log_check.py')
    structured = module('structured_camera_result', P.parent / 'camera-identity-depth-diagnostic-01/structured_log.py')
    log = P / 'unity.log'
    errors, qualifications = structured.qualify_structured_summary(
        log.read_text(encoding='utf-8-sig').splitlines(), scanner.scan(log), scene, scanner.PATTERNS)
    assert not errors, repr(errors)
    frames = [load(P / 'native' / f'frame-{i:03d}.json') for i in range(48)]
    assert all(row['complete'] and not row.get('error') and row['logicalFrame'] == i for i, row in enumerate(frames))
    assert [row['engineFrame'] for row in frames] == list(range(frames[0]['engineFrame'], frames[0]['engineFrame'] + 48))
    assert all(row['useIdentity'] and row['instanceCount'] == 3 and row['triangleCount'] == 6 for row in frames)
    assert all(row['sources'] == frames[30]['sources'] for row in frames[30:])
    assert all(row['changeCount'] == 0 for row in frames[31:])
    for i in range(48):
        assert (P / 'native' / f'frame-{i:03d}.bin').stat().st_size == (12 + 264 * 45) * 16
        pin(P / 'native' / f'frame-{i:03d}.bin')
        pin(P / 'native' / f'frame-{i:03d}.json')
    for i in (31, 39, 47):
        pin(P / 'native' / f'final-{i:03d}-preview.png')
    for path in (P / 'source-freeze.json', log, P / 'native/scene-result.json', P / 'native-exit.json'):
        pin(path)
    return dict(passed=True, productFiles=112, stagedFiles=9, actualConsecutiveFrames=48,
                sourceAndRestorationVerified=True, structuredLogQualifications=qualifications,
                temporalAcceptanceDelegatedTo='analyze.py', performanceCompared=False,
                fullProductionAccepted=False, inputSha256=inputs)


if __name__ == '__main__':
    output = P / 'execution-receipt.json'
    assert not output.exists(), 'Preserve first execution verification'
    try:
        receipt = verify()
    except Exception:
        receipt = dict(passed=False, error=traceback.format_exc())
    output.write_text(json.dumps(receipt, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({k: v for k, v in receipt.items() if k != 'inputSha256'}))
    raise SystemExit(0 if receipt['passed'] else 1)
