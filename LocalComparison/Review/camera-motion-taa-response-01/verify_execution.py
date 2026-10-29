"""One metadata/source/restoration audit; temporal claims belong to analyze.py."""
import hashlib
import importlib.util
import json
import traceback
from pathlib import Path

P = Path(__file__).resolve().parent
ROOT = P.parents[2]
PROJECT = Path('I:/Unity test/Project')
sha = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
load = lambda path: json.loads(path.read_text(encoding='utf-8-sig'))


def verify():
    manifest = load(P / 'instrumentation/manifest.json')
    product = manifest['productSourceSha256']
    assert len(product) == 112
    assert product['Runtime/Resources/HybridLumenGI/HybridLumenGIKernels.hlsl'] == '68bdfe49b2c8b09a52722bc5ba7dcb7045be016359d6682e380269116df67455'
    assert all(sha(ROOT / rel) == sha(PROJECT / 'Assets/HybridLumenGI' / rel) == digest
               for rel, digest in product.items())
    for row in manifest['files']:
        assert sha(P / 'instrumentation' / row['prepared']) == row['sha256']
        archive = P / 'instrumentation/post-run' / row['path']
        assert archive.is_file() and sha(archive) == row['sha256']
    for relative, digest in load(P / 'instrumentation/analysis-source.json').items():
        assert sha(ROOT / relative) == digest, relative
    harness = load(P / 'instrumentation/harness-source.json')
    for name, digest in harness.items():
        assert sha(ROOT / 'LocalComparison/Harness' / name) == digest, name
    restored = load(P / 'instrumentation/restoration.json')
    assert restored['currentProductRestored'] and restored['ownedRootRemoved']
    assert all(row['restored'] for row in restored['protected'])
    assert not (PROJECT / 'Assets/CameraMotionTaa01').exists()
    assert load(P / 'preflight/exit.json')['exitCode'] == 0
    assert load(P / 'native-exit.json')['exitCode'] == 0
    spec = importlib.util.spec_from_file_location('camera_native_log_check', ROOT / 'LocalComparison/Harness/native_log_check.py')
    scanner = importlib.util.module_from_spec(spec); spec.loader.exec_module(scanner)
    assert not scanner.scan(P / 'unity.log')
    result = load(P / 'native/scene-result.json')
    assert result['status'] == 'collected'
    frames = [load(P / 'native' / ('frame-%03d.json' % i)) for i in range(48)]
    assert all(row['complete'] and row['logicalFrame'] == i for i, row in enumerate(frames))
    assert [row['engineFrame'] for row in frames] == list(range(frames[0]['engineFrame'], frames[0]['engineFrame'] + 48))
    assert all(row['useIdentity'] and row['instanceCount'] == 3 and row['triangleCount'] == 6 for row in frames)
    assert all(row['sources'] == frames[31]['sources'] for row in frames[31:])
    assert all(row['changeCount'] == 0 for row in frames[31:])
    assert all((P / 'native' / ('frame-%03d.bin' % i)).stat().st_size == (12 + 264 * 45) * 16 for i in range(48))
    return dict(passed=True, productFiles=112, stagedFiles=len(manifest['files']),
                actualConsecutiveFrames=48, sourceShader=product['Runtime/Resources/HybridLumenGI/HybridLumenGIKernels.hlsl'],
                sourceAndRestorationVerified=True, temporalAcceptanceDelegatedTo='analyze.py',
                fullProductionAccepted=False)


if __name__ == '__main__':
    output = P / 'execution-receipt.json'
    assert not output.exists(), 'Preserve first execution audit'
    try:
        receipt = verify()
    except Exception:
        receipt = dict(passed=False, error=traceback.format_exc())
    with output.open('x', encoding='utf-8') as stream:
        json.dump(receipt, stream, indent=2)
    print(json.dumps(receipt))
    raise SystemExit(0 if receipt['passed'] else 1)
