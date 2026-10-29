"""Independent metadata audit for one pinned cross-field JSON regex false positive.

Never reads radiance/preview contents, runs Unity, or changes the original scanner.
The original execution-receipt.json remains a failure. Other scanner hits fail.
"""
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import traceback

HERE = Path(__file__).resolve().parent
PACKAGE = HERE.parent
ROOT = PACKAGE.parents[2]
PROJECT = Path('I:/Unity test/Project')
PREFIX = 'CAMERA_MOTION_TAA_RESULT '
LINE = 530
LINE_SHA = '5711299472356f458bed32264b438675fd7ca927db8aa77edb1c1d05a74c49f5'
PINS = {
    'LocalComparison/Harness/native_log_check.py': 'fa30d084e3c0e4af821c6679ad6b4e299b56e766580f60e54b14fe15fd621a7a',
    'LocalComparison/Review/camera-motion-taa-response-02/verify_execution.py': 'b29258ff95423311ce8b49b3859680003f7cdc5933e76577e62a7e933c3d20d1',
    'LocalComparison/Review/camera-motion-taa-response-02/execution-receipt.json': '1597310b30d397e39381b46398d3ca74c62c2b1a0e3e32b160b777d84f0493de',
    'LocalComparison/Review/camera-motion-taa-response-02/unity.log': 'a986161da784c223cbc23cd85a49710ef606b01548c44b4137b8af8b72ad7bcc',
    'LocalComparison/Review/camera-motion-taa-response-02/native/scene-result.json': '8d556ed2ca61766fc153b3d6a9adf74471f9f90d675515ec73b12f5a920783da',
    'LocalComparison/Review/camera-motion-taa-response-02/source-freeze.json': 'bede8fa6a018a203e6d8e2459c869508229a0b856edce95cc3f5eed27b2956a9',
}


def require(value, reason):
    if not value:
        raise AssertionError(reason)


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def strict_object(pairs):
    result = {}
    for key, value in pairs:
        require(key not in result, 'Duplicate result key')
        result[key] = value
    return result


def reject_constant(value):
    raise AssertionError('Nonfinite JSON constant: ' + value)


def strings(value):
    if isinstance(value, str):
        yield value
    elif isinstance(value, dict):
        for key, child in value.items():
            yield key
            yield from strings(child)
    elif isinstance(value, list):
        for child in value:
            yield from strings(child)


def validate_result(text, scene_result, patterns):
    require(text.startswith(PREFIX), 'Not the exact result prefix')
    result = json.loads(text[len(PREFIX):], object_pairs_hook=strict_object,
                        parse_constant=reject_constant)
    require(result == scene_result, 'Log result differs from separate scene receipt')
    require(result['status'] == 'collected' and result['error'] == '', 'Result reports a failure')
    require(result['readbacksDrained'] is True, 'Readbacks not drained')
    d = result['selectedDiagnostics']
    require(d['failedHlodReadbacks'] == 0, 'Nonzero failed HLOD readbacks')
    require(d['hardwareMaterialStatus'] == 'Uploads and both consumers bound; GPU completion unproven',
            'Different material status')
    # No atomic JSON key/value may itself contain an original failure signature.
    # Only the accidental concatenation across distinct fields is qualified.
    require(not any(re.search(pattern, atom, re.I)
                    for atom in strings(result) for pattern in patterns.values()),
            'Failure signature within a JSON key/value')
    for key in ('requests', 'cameraBegins', 'cameraEnds', 'contextBegins', 'contextEnds'):
        require(result[key] == 48, 'Incomplete callback/request count: ' + key)
    require(result['previewCaptures'] == 3 and result['firstEngine'] == 1
            and result['lastEngine'] == 48, 'Incomplete finite run metadata')
    return result


def qualify_hits(hits, lines, scene_result, patterns):
    require(sum(line.startswith(PREFIX) for line in lines) == 1, 'Result line is not unique')
    qualified, remaining = [], []
    for hit in hits:
        exact = (hit['category'] == 'readback' and hit['line'] == LINE
                 and hashlib.sha256(hit['text'].encode('utf-8')).hexdigest() == LINE_SHA)
        if not exact:
            remaining.append(hit)
            continue
        require(lines[LINE - 1] == hit['text'], 'Scanner line differs from actual log')
        validate_result(hit['text'], scene_result, patterns)
        match = re.search(patterns['readback'], hit['text'], re.I)
        require(match is not None and match.span() == (582, 2167), 'Unexpected regex match span')
        require(match.group().startswith('readbacksDrained\":true,')
                and match.group().endswith('GPU completion unproven'), 'Unexpected match endpoints')
        qualified.append(dict(category=hit['category'], line=LINE, lineSha256=LINE_SHA,
                              matchSpan=list(match.span()), pattern=patterns['readback'],
                              reason='Regex crosses from readbacksDrained:true to independent hardwareMaterialStatus GPU completion unproven.'))
    require(len(qualified) == 1, 'Expected exactly one pinned summary false positive')
    return qualified, remaining


def verify():
    inputs = {}

    def pin(path, expected=None):
        digest = sha(path)
        require(expected is None or digest == expected, 'Source changed: ' + str(path))
        inputs[str(path)] = digest
        return digest

    for relative, digest in PINS.items():
        pin(ROOT / relative, digest)
    for source in HERE.glob('*.py'):
        pin(source)
    original = load(PACKAGE / 'execution-receipt.json')
    require(original['passed'] is False and 'assert not scanner.scan' in original['error'],
            'Original failure is not the preserved scanner assertion')
    scanner_path = ROOT / 'LocalComparison/Harness/native_log_check.py'
    spec = importlib.util.spec_from_file_location('unchanged_native_scanner', scanner_path)
    scanner = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(scanner)
    log = PACKAGE / 'unity.log'
    lines = log.read_text(encoding='utf-8').splitlines()
    hits = scanner.scan(log)
    scene_result = load(PACKAGE / 'native/scene-result.json')
    qualified, remaining = qualify_hits(hits, lines, scene_result, scanner.PATTERNS)
    require(not remaining, 'Other original scanner failures remain: ' + repr(remaining))

    # Independently repeat every non-log assertion in the original execution audit.
    manifest_path = PACKAGE / 'instrumentation/manifest.json'
    pin(manifest_path)
    manifest = load(manifest_path)
    product = manifest['productSourceSha256']
    require(len(product) == 112 and len(manifest['files']) == 9, 'Product/staged scope differs')
    require(product['Runtime/Resources/HybridLumenGI/HybridLumenGIKernels.hlsl']
            == '68bdfe49b2c8b09a52722bc5ba7dcb7045be016359d6682e380269116df67455',
            'Product kernel version differs')
    for relative, digest in product.items():
        pin(ROOT / relative, digest)
        pin(PROJECT / 'Assets/HybridLumenGI' / relative, digest)
    for row in manifest['files']:
        pin(PACKAGE / 'instrumentation' / row['prepared'], row['sha256'])
        pin(PACKAGE / 'instrumentation/post-run' / row['path'], row['sha256'])
        if row['original']:
            pin(PACKAGE / 'instrumentation' / row['original'], row['originalSha256'])
            pin(PROJECT / row['path'], row['originalSha256'])
        else:
            require(not (PROJECT / row['path']).exists(), 'New staged source still deployed')
    for name, base in (('analysis-source.json', ROOT),
                       ('harness-source.json', ROOT / 'LocalComparison/Harness')):
        path = PACKAGE / 'instrumentation' / name
        pin(path)
        for relative, digest in load(path).items():
            pin(base / relative, digest)
    urp = PACKAGE / 'instrumentation/urp-source.json'
    pin(urp)
    for path, digest in load(urp).items():
        pin(Path(path), digest)
    restored_path = PACKAGE / 'instrumentation/restoration.json'
    pin(restored_path)
    restored = load(restored_path)
    require(restored['currentProductRestored'] and restored['ownedRootRemoved']
            and all(row['restored'] for row in restored['protected']), 'Restoration receipt failed')
    protected_path = PACKAGE / 'instrumentation/protected.json'
    pin(protected_path)
    for row in load(protected_path):
        pin(PROJECT / row['path'], row['sha256'])
    owned = PROJECT / 'Assets/CameraMotionTaa01'
    require(not owned.exists() and not Path(str(owned) + '.meta').exists(), 'Owned root/meta remains')
    for name in ('preflight/exit.json', 'native-exit.json'):
        pin(PACKAGE / name)
        require(load(PACKAGE / name)['exitCode'] == 0, 'Nonzero exit: ' + name)
    compile_path = PACKAGE / 'compile/report.json'
    pin(compile_path)
    compiled = load(compile_path)
    require(compiled['passed'] and compiled['sourcesUnchanged'] and len(compiled['checks']) == 18
            and all(row['exitCode'] == 0 for row in compiled['checks']), '18-entry compile preflight failed')
    frozen = load(PACKAGE / 'source-freeze.json')
    for relative, digest in frozen['sources'].items():
        pin(ROOT / relative, digest)
    reuse_path = PACKAGE / 'reuse-source.json'
    pin(reuse_path)
    for relative, digest in load(reuse_path)['originalSources'].items():
        pin(ROOT / relative, digest)

    frames = []
    sizes = []
    for i in range(48):
        path = PACKAGE / 'native' / ('frame-%03d.json' % i)
        pin(path)
        frame = load(path)
        require(frame['complete'] is True and frame['logicalFrame'] == i
                and frame['engineFrame'] == i + 1 and frame['error'] == '', 'Incomplete frame receipt')
        require(frame['useIdentity'] and frame['instanceCount'] == 3 and frame['triangleCount'] == 6,
                'Identity/source geometry scope differs')
        require(frame['pixels'] == 264 and frame['rowVectors'] == 45 and frame['controlVectors'] == 12,
                'Compact ABI metadata differs')
        size = (PACKAGE / 'native' / ('frame-%03d.bin' % i)).stat().st_size
        require(size == (12 + 264 * 45) * 16, 'Compact buffer file size differs')
        sizes.append(size)
        frames.append(frame)
    require(all(row['sources'] == frames[31]['sources'] for row in frames[31:]), 'Observed sources changed')
    require(all(row['changeCount'] == 0 for row in frames[31:]), 'Unexpected observed source changes')
    previews = []
    for frame in (31, 39, 47):
        path = PACKAGE / 'native' / ('final-%03d-preview.png' % frame)
        require(path.is_file() and path.stat().st_size > 0, 'Preview absent')
        previews.append(dict(path=str(path), bytes=path.stat().st_size, contentsRead=False))
    require(all(sha(Path(path)) == digest for path, digest in inputs.items()), 'An audited input changed')
    return dict(passed=True, schema='camera-taa-log-execution-qualification-v1',
                originalExecutionReceiptRemainsFailed=True, originalScannerHits=len(hits),
                qualifiedSummaryHits=qualified, remainingOriginalScannerHits=remaining,
                productFiles=112, stagedFiles=9, actualConsecutiveFrames=48, engineFrames=[1, 48],
                requestAndCallbackCounts=48, previewFiles=previews, compactFileBytes=sizes,
                sourceAndRestorationVerified=True, ownedRootAndMetadataAbsent=True,
                radianceOrPreviewContentsRead=False, unityOrGpuExecuted=False,
                temporalQualityAccepted=False, temporalAcceptanceDelegatedTo='qualification-ties/analyze.py',
                performanceCompared=False,
                performanceScope='User reported concurrent gameplay on GPU; this report makes no performance comparison.',
                scope='Only pinned structured-summary regex false positive and source/execution/restoration metadata.',
                inputsSha256=inputs)


if __name__ == '__main__':
    output = HERE / 'result.json'
    require(not output.exists(), 'Preserve the first qualification result')
    try:
        result = verify()
    except Exception:
        result = dict(passed=False, error=traceback.format_exc())
    with output.open('x', encoding='utf-8') as stream:
        json.dump(result, stream, indent=2)
        stream.write('\n')
    print(json.dumps({key: result.get(key) for key in ('passed', 'productFiles', 'stagedFiles',
                     'actualConsecutiveFrames', 'originalExecutionReceiptRemainsFailed', 'error')}))
    raise SystemExit(0 if result['passed'] else 1)
