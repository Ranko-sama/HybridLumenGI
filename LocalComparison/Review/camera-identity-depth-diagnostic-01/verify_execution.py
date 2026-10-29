"""Native/source/restoration checks only; diagnosis belongs to analyze.py."""
import hashlib
import importlib.util
import json
from pathlib import Path
import traceback
from structured_log import qualify_structured_summary

P = Path(__file__).resolve().parent
ROOT = P.parents[2]
PROJECT = Path('I:/Unity test/Project')
BASE = P.parent / 'camera-motion-taa-response-02'
load = lambda path: json.loads(path.read_text(encoding='utf-8-sig'))
sha = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()


def verify():
    inputs = {}

    def pin(path, expected=None):
        digest = sha(path)
        assert expected is None or digest == expected, 'Changed input: ' + str(path)
        inputs[str(path)] = digest
        return digest

    freeze = load(P / 'source-freeze.json')
    for name in ('sources', 'evidence'):
        for relative, digest in freeze[name].items():
            pin(ROOT / relative, digest)
    for name in ('verify_execution.py', 'structured_log.py', 'run.ps1', 'run-environment.json'):
        assert (P / name).relative_to(ROOT).as_posix() in freeze['sources']
    manifest = load(P / 'instrumentation/manifest.json')
    product = manifest['productSourceSha256']
    assert product == load(BASE / 'instrumentation/manifest.json')['productSourceSha256']
    assert len(product) == 112 and len(manifest['files']) == 13
    for relative, digest in product.items():
        pin(ROOT / relative, digest)
        pin(PROJECT / 'Assets/HybridLumenGI' / relative, digest)
    for row in manifest['files']:
        pin(P / 'instrumentation' / row['prepared'], row['sha256'])
        pin(P / 'instrumentation/post-run' / row['path'], row['sha256'])
        target = PROJECT / row['path']
        if row['original']:
            pin(P / 'instrumentation' / row['original'], row['originalSha256'])
            pin(target, row['originalSha256'])
        else:
            assert not target.exists(), 'New diagnostic source remains installed'
    for relative, digest in load(P / 'instrumentation/harness-source.json').items():
        pin(ROOT / relative, digest)
    for path, digest in load(P / 'instrumentation/urp-source.json').items():
        pin(Path(path), digest)
    for row in load(P / 'instrumentation/protected.json'):
        pin(PROJECT / row['path'], row['sha256'])
        pin(P / 'instrumentation' / row['backup'], row['sha256'])
    restored = load(P / 'instrumentation/restoration.json')
    assert restored['currentProductRestored'] and restored['ownedRootRemoved']
    assert all(row['restored'] for row in restored['protected'])
    owned = PROJECT / 'Assets/CameraMotionTaa01'
    assert not owned.exists() and not Path(str(owned) + '.meta').exists()
    assert load(P / 'preflight/exit.json')['exitCode'] == 0
    assert load(P / 'compile-probe/report.json')['passed'] is False, 'Keep the original FXC entry failure'
    assert load(P / 'compile-probe-02/report.json')['passed'] is False, 'Keep the dependency-output entry failure'
    assert load(P / 'compile-probe-03/report.json')['passed']
    assert load(P / 'native-exit.json')['exitCode'] == 0

    native = P / 'native'
    scene = load(native / 'scene-result.json')
    assert scene['status'] == 'collected' and scene['error'] == '' and scene['readbacksDrained']
    assert all(scene[field] == 48 for field in ('requests', 'cameraBegins', 'cameraEnds', 'contextBegins', 'contextEnds'))
    assert scene['previewCaptures'] == 3 and scene['api'] == 'Direct3D12'
    scanner_path = ROOT / 'LocalComparison/Harness/native_log_check.py'
    pin(scanner_path)
    spec = importlib.util.spec_from_file_location('unchanged_native_scanner', scanner_path)
    scanner = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(scanner)
    log = P / 'unity.log'
    remaining, structured = qualify_structured_summary(
        log.read_text(encoding='utf-8-sig').splitlines(), scanner.scan(log), scene, scanner.PATTERNS)
    assert not remaining, 'Native log errors: ' + repr(remaining)

    frames = [load(native / f'frame-{i:03d}.json') for i in range(48)]
    assert all(row['complete'] and not row.get('error') and row['logicalFrame'] == i
               for i, row in enumerate(frames))
    assert [row['engineFrame'] for row in frames] == list(range(frames[0]['engineFrame'], frames[0]['engineFrame'] + 48))
    assert all(row['useIdentity'] and row['instanceCount'] == 3 and row['triangleCount'] == 6 for row in frames)
    assert all(row['sources'] == frames[30]['sources'] for row in frames[30:])
    assert all(row['changeCount'] == 0 for row in frames[31:])
    for i in range(48):
        assert (native / f'frame-{i:03d}.bin').stat().st_size == (12 + 264 * 45) * 16
        pin(native / f'frame-{i:03d}.bin')
        pin(native / f'frame-{i:03d}.json')
    for i in (31, 39, 47):
        assert (native / f'final-{i:03d}-preview.png').is_file()

    probe = load(native / 'probe-result.json')
    assert probe['complete'] is True and probe['failure'] in (None, '')
    assert probe['framesExpected'] == probe['framesCreated'] == probe['framesCompleted'] == 8
    assert probe['pendingReadbacks'] == 0
    links = probe['frameLinks']
    assert [row['logicalFrame'] for row in links] == list(range(36, 44))
    for row in links:
        frame = frames[row['logicalFrame']]
        assert row['engineFrame'] == frame['engineFrame'] and row['workFrame'] == frame['workFrame']
        assert row['bytes'] == 38928
    # File/ABI payload qualification and causal interpretation remain the separate
    # analyzer's responsibility. This metadata audit does not assert a dropout.
    pin(native / 'probe-result.json')
    pin(native / 'scene-result.json')
    pin(log)
    return dict(passed=True, productFiles=112, stagedFiles=13, actualConsecutiveFrames=48,
                diagnosticFrames=list(range(36, 44)), sourceAndRestorationVerified=True,
                structuredSummaryCrossFieldMatches=structured, nativeLogErrors=remaining,
                diagnosticInterpretationDelegatedTo='analyze.py', temporalQualityAccepted=False,
                productFixed=False, performanceCompared=False, inputSha256=inputs)


if __name__ == '__main__':
    output = P / 'execution-receipt.json'
    assert not output.exists(), 'Preserve the first execution audit'
    try:
        result = verify()
    except Exception:
        result = dict(passed=False, error=traceback.format_exc())
    with output.open('x', encoding='utf-8') as stream:
        json.dump(result, stream, indent=2)
        stream.write('\n')
    print(json.dumps({k: v for k, v in result.items() if k != 'inputSha256'}))
    raise SystemExit(0 if result['passed'] else 1)
