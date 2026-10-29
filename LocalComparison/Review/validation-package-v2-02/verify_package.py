"""Read-only 720-frame capture integrity audit; never a physical quality verdict.

The existing Node adapter owns the v2 schema/source/camera/artifact protocol.
This script adds the native sequence and same-render receipt links, plus numeric
mask validation even when no reference exists. It never creates expected RGB.
"""
import argparse
from collections import Counter
import hashlib
import json
import math
from pathlib import Path
import re
import struct
import subprocess
import sys

P = Path(__file__).resolve().parent
ROOT = P.parents[2]
ADAPTER = ROOT / 'Tests/compare-validation-reference.mjs'
TOTAL, INTERVAL = 720, 30
BOUNDARIES = (119, 120, 179, 180, 209, 210, 239, 240, 299, 300, 359, 360, 419, 420)
SELECTED = [n for n in range(TOTAL) if n % INTERVAL == 0 or n == TOTAL - 1 or n in BOUNDARIES]
SIGNALS = {'cameraBeforeHLGI': 'before-hlgi-composite-after-skybox',
           'cameraAfterHLGI': 'after-hlgi-composite-before-transparents',
           'filteredD': 'before-hlgi-composite-after-filter'}
SUPPORT = {'geometry', 'material', 'depth', 'captureDepth', 'emissionValidity', 'normals', 'moments'}


def require(value, message):
    if not value:
        raise ValueError(message)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def parse(data):
    def invalid(value):
        raise ValueError('Nonstandard JSON number: ' + value)
    result = json.loads(data.decode('utf-8-sig'), parse_constant=invalid)
    def finite(value):
        if isinstance(value, float):
            require(math.isfinite(value), 'Nonfinite JSON numeric input')
        elif isinstance(value, dict):
            for child in value.values(): finite(child)
        elif isinstance(value, list):
            for child in value: finite(child)
    finite(result)
    return result


def stage(n):
    return ('color-static' if n < 120 else 'moving-door' if n < 240 else 'lights-off' if n < 300 else
            'lights-restored' if n < 360 else 'thin-wall-cut' if n < 420 else 'sealed-room-cut')


class Audit:
    def __init__(self, native):
        self.native = native.resolve()
        self.pins, self.images, self.coverage = {}, {}, []
        self.context = 'initialization'

    def read(self, path):
        path = path.resolve()
        require(path.is_relative_to(self.native), 'Input escapes native root: ' + str(path))
        data = path.read_bytes()
        h = digest(data)
        key = str(path)
        require(key not in self.pins or self.pins[key] == h, 'Input changed during audit: ' + key)
        self.pins[key] = h
        return data

    def load(self, path):
        return parse(self.read(path))

    def artifact(self, base, item, path_key='file'):
        name = item[path_key]
        require(isinstance(name, str) and name and '\\' not in name and ':' not in name and
                not name.startswith('/') and all(part not in ('', '.', '..') for part in name.split('/')),
                'Unsafe artifact path: ' + repr(name))
        path = (base / name).resolve()
        require(path.is_relative_to(base.resolve()), 'Artifact symlink escapes package: ' + name)
        data = self.read(path)
        require(re.fullmatch('[0-9a-f]{64}', item['sha256']) and digest(data) == item['sha256'], 'Artifact hash differs: ' + name)
        return path, data

    def image(self, base, item, role, mask_required=True):
        require(item['format'] == 'rgba32f-le' and item['rowOrder'] == 'top-to-bottom', 'Unexpected image encoding: ' + role)
        w, h = item['width'], item['height']
        require(type(w) is int and type(h) is int and 0 < w <= 16384 and 0 < h <= 16384, 'Invalid image dimensions')
        raw = item.get('data', item)
        _, data = self.artifact(base, raw)
        require(len(data) == w * h * 16, 'Image byte count differs: ' + role)
        if mask_required:
            validity = item['validity']
            require(validity['format'] == 'uint8' and validity['basis'] == 'measurement-state', 'Capture mask declaration differs')
            _, mask = self.artifact(base, validity)
            require(len(mask) == w * h and all(v in (0, 1) for v in mask), 'Invalid mask bytes: ' + role)
        else:
            mask = None
        unknown = nonfinite = 0
        for index, pixel in enumerate(struct.iter_unpack('<4f', data)):
            is_finite = all(math.isfinite(v) for v in pixel)
            nonfinite += not is_finite
            expected = is_finite and (role != 'filteredD' or pixel[3] > 0)
            if mask is None:
                require(is_finite, 'Nonfinite legacy image: ' + role)
            else:
                require(mask[index] == int(expected), 'Finite/measurement mask differs at ' + role + ' pixel ' + str(index))
                unknown += not bool(mask[index])
        if mask_required:
            require(item['invalidPixels'] == unknown, 'Capture invalid-pixel count differs: ' + role)
        counters = self.images.setdefault(role, Counter())
        counters.update(images=1, pixels=w*h, unknownPixels=unknown, nonfinitePixels=nonfinite)
        if unknown:
            self.coverage.append(dict(context=self.context, signal=role, unknownPixels=unknown, totalPixels=w*h))

    def verify(self, node):
        self.context = 'host/editor receipts'
        host = self.load(self.native/'host-result.json')
        editor = self.load(self.native/'editor-result.json')
        require(host['status'] == editor['status'] == 'collected' and not host.get('error') and not editor.get('error'), 'Host/editor did not collect normally')
        require(host['legacyStatus'] == 'completed' and host['renderedFrames'] == TOTAL and host['referenceDrained'] is True and editor['restored'] is True,
                'Host frame/drain or Editor restoration receipt differs')
        capture = Path(host['captureDirectory']).resolve()
        require(capture.is_relative_to(self.native) and capture != self.native, 'Capture directory is outside the supplied native root')
        run = self.load(capture/'run.json')
        require(run['status'] == 'completed' and run['renderedFrames'] == run['totalLogicalFrames'] == TOTAL and
                run['captureEvery'] == INTERVAL and run['failures'] == run['backendMismatches'] == 0 and not run.get('lastError'), 'Legacy run did not complete the frozen sequence')
        require(run['sequenceVersion'] == 1 and run['capturesWritten'] == len(SELECTED) and run['referencePackage'] == 'candidate.json' and
                run['referenceStatus'] == 'reference-required' and run['explicitRequest'] is True, 'Run/capture contract differs')
        require(run['graphicsApi'] == 'Direct3D12' and run['colorSpace'] == 'Linear' and not run['targetSRGB'] and run['width'] == 640 and run['height'] == 360,
                'Native capture device/target scope differs')

        self.context = '720 native frame receipts'
        frames = [parse(line) for line in self.read(capture/'frames.jsonl').splitlines() if line.strip()]
        require(len(frames) == TOTAL and [r['logicalFrame'] for r in frames] == list(range(TOTAL)), 'Missing/repeated/out-of-order logical frame')
        expected_backend = {'Software': 'reported-software', 'Hardware': 'reported-hardware'}[run['expectedBackend']]
        for n, frame in enumerate(frames):
            require(frame['status'] == 'render-receipt' and frame['sequenceVersion'] == 1 and frame['width'] == 640 and frame['height'] == 360 and
                    frame['stage'] == stage(n) and frame['lightsEnabled'] == (n < 240 or n >= 300), 'Frame action/stage/shape differs: ' + str(n))
            require(frame['engineFrame'] == frames[0]['engineFrame'] + n and frame['giFrame'] == frames[0]['giFrame'] + n,
                    'Engine/GI receipt is not consecutive: ' + str(n))
            require(frame['diagnosticFresh'] and frame['reportedBackend'] == expected_backend and frame['diagnostics']['frame'] == frame['giFrame'] and
                    frame['camera'] == frames[0]['camera'], 'Frame camera/backend/diagnostic differs')
        require(run['firstEngineFrame'] == frames[0]['engineFrame'] and run['firstRenderedGiFrame'] == frames[0]['giFrame'], 'Run first-frame identity differs')
        logs = [parse(line) for line in self.read(capture/'unity-log.jsonl').splitlines() if line.strip()]
        require(not any(row['type'] in ('Error', 'Exception', 'Assert') for row in logs), 'Captured Unity log contains an error/assert/exception')
        legacy_names = sorted(path.name for path in capture.glob('frame-[0-9][0-9][0-9][0-9].json'))
        require(legacy_names == [f'frame-{n:04}.json' for n in SELECTED], 'Legacy capture selection differs')
        for n in SELECTED:
            self.context = 'legacy frame ' + str(n)
            legacy = self.load(capture/f'frame-{n:04}.json')
            require(legacy['status'] == 'captured' and legacy['gpuReadbackCompleted'] and legacy['nonfiniteComponents'] == 0 and not legacy.get('error'), 'Legacy selected capture did not finish')
            for key in ('logicalFrame', 'engineFrame', 'giFrame', 'camera', 'cameraPosition', 'cameraRotation', 'cameraProjection', 'doorLocalPosition', 'lightsEnabled', 'stage', 'width', 'height'):
                require(legacy[key] == frames[n][key], 'Legacy capture belongs to a different render: ' + key)
            require(legacy['rawFile'] == f'frame-{n:04}.rgba32f' and legacy['exrFile'] == f'frame-{n:04}.exr', 'Legacy file association differs')
            raw = self.read(capture/legacy['rawFile'])
            self.image(capture, dict(width=640, height=360, format='rgba32f-le', rowOrder='top-to-bottom',
                                    data=dict(file=legacy['rawFile'], sha256=digest(raw))), 'legacyEndCamera', False)
            require(self.read(capture/legacy['exrFile'])[:4] == b'\x76\x2f\x31\x01', 'Legacy EXR magic differs')

        self.context = 'v2 schema/source/camera/artifact adapter'
        command = [node, str(ADAPTER), '--candidate', str(capture/'candidate.json')]
        result = subprocess.run(command, capture_output=True, text=True, encoding='utf-8', timeout=600)
        adapter = json.loads(result.stdout)
        require(result.returncode == 2 and adapter['exitCode'] == 2 and adapter['passed'] is None and adapter['reference'] is None,
                'No-reference adapter did not report an incomplete/reference-required result: ' + repr(adapter))
        candidate = self.load(capture/'candidate.json')
        require(candidate['referenceStatus'] == 'reference-required' and candidate['sequence'] == dict(id='HybridLumenGIValidationSequence', version=1, totalLogicalFrames=TOTAL), 'V2 sequence declaration differs')
        require(candidate['selection'] == dict(logicalFrames=SELECTED, signalIds=['cameraAfterHLGI']), 'V2 declared selection differs from Sequence.IsCaptureFrame(30)')
        require(sorted(r['logicalFrame'] for r in candidate['frames']) == SELECTED, 'V2 frame coverage is incomplete')
        require({s['id']: s['stage'] for s in candidate['signals']} == SIGNALS, 'V2 signal stage declarations differ')
        _, source_bytes = self.artifact(capture, candidate['source']); source = parse(source_bytes)
        unsupported = set(source.get('unsupported', []))
        for asset in source['assets']: self.artifact(capture, asset, 'path')
        for artifact in candidate.get('provenance', []): self.artifact(capture, artifact)
        captured_ids, product_ids = set(), set()
        for frame in candidate['frames']:
            n = frame['logicalFrame']; self.context = 'same-render v2 frame ' + str(n)
            _, state_bytes = self.artifact(capture, frame['state']); state = parse(state_bytes)
            unsupported.update(state.get('unsupported', []))
            require(state['camera'] == frame['camera'] and state['logicalFrame'] == n and state['sourceSha256'] == candidate['source']['sha256'], 'Source state/camera association differs')
            for asset in state.get('dynamicState', {}).get('assets', []): self.artifact(capture, asset, 'path')
            for artifact in frame.get('support', []): self.artifact(capture, artifact)
            receipts = [a for a in frame['support'] if a['role'] == 'same-render-capture-and-composite-inputs']
            require(len(receipts) == 1, 'Exactly one same-render receipt is required')
            _, receipt_bytes = self.artifact(capture, receipts[0]); receipt = parse(receipt_bytes)
            require(receipt['logicalFrame'] == n and receipt['engineFrame'] == frames[n]['engineFrame'] and receipt['workFrame'] + 1 == frames[n]['giFrame'], 'Capture ticket is from another camera/render counter')
            require(receipt['status'] == 'complete' and not receipt['error'] and receipt['retainedBytes'] == 0 and
                    all(receipt[k] is True for k in ('beforeRecorded', 'afterRecorded', 'cameraEnded', 'readbacksCompleted')), 'Same-render capture did not drain successfully')
            require(receipt['cameraName'] == frames[n]['camera'], 'Capture camera name differs')
            captured_ids.add(receipt['cameraInstanceId']); product_ids.add(receipt['featureInstanceId'])
            require(receipt['samples'] == frame['samples'] and {s['signalId'] for s in frame['samples']} == set(SIGNALS), 'Frame samples differ from capture receipt')
            for sample in frame['samples']:
                require(sample['status'] == 'available' and sample['stage'] == SIGNALS[sample['signalId']], 'Missing capture signal/boundary')
                if sample['signalId'] != 'filteredD': require((sample['width'], sample['height']) == (640, 360), 'Camera signal is not full resolution')
                else: require((sample['width'], sample['height']) == (receipt['composite']['giSize']['x'], receipt['composite']['giSize']['y']), 'filteredD is not the recorded GI grid')
                self.image(capture, sample, sample['signalId'])
            support = {s['role']: s for s in receipt['support']}
            expected_support = SUPPORT | ({'nativeDiffuseFog'} if receipt['composite']['composition'] != 0 else set())
            require(set(support) == expected_support, 'Missing/extra composite support')
            require(receipt['nativeDiffuseFogStatus'] == ('available' if 'nativeDiffuseFog' in expected_support else 'not-applicable'), 'Native diffuse applicability differs')
            outer_links = {(a['file'], a['sha256']) for a in frame['support']}
            for role, sample in support.items():
                require((sample['file'], sample['sha256']) in outer_links and (sample['validity']['file'], sample['validity']['sha256']) in outer_links, 'Support raw/mask missing from manifest artifact bindings')
                size = receipt['composite']['giSize'] if role in ('geometry', 'moments') else dict(x=640, y=360)
                require((sample['width'], sample['height']) == (size['x'], size['y']), 'Composite support dimensions differ: ' + role)
                self.image(capture, sample, role)
        require(len(captured_ids) == len(product_ids) == 1 and 0 not in captured_ids and 0 not in product_ids, 'Camera/Feature instance changed during capture')

        self.context = 'separate source provenance'
        provenance = capture/'source-provenance.json'; origin_paths = []
        if provenance.exists():
            origins = self.load(provenance)
            for artifact in origins['artifacts']:
                self.artifact(capture, artifact); origin_paths.append(artifact['role'])
        bake = dict(explicitBindingReports={key: source[key] for key in ('bakeBindings', 'generatedBakeBindings') if key in source},
                    archivedSdfOrigins=[p for p in origin_paths if '-SDF.asset' in p],
                    archivedChartsOrigins=[p for p in origin_paths if '-SurfaceCharts.asset' in p],
                    bindingVerified=False, note='Archived product bake assets are provenance, not physical mesh input or proof of live bindings; explicit reports are reported without an invented binding claim.')
        return dict(dataIntegrityPassed=True, nativeSequenceComplete=True, selectedCaptureCount=len(SELECTED), logicalFrames=TOTAL,
                    engineFrameRange=[frames[0]['engineFrame'], frames[-1]['engineFrame']], giFrameRange=[frames[0]['giFrame'], frames[-1]['giFrame']],
                    captureDirectory=str(capture), candidateStatus=candidate['status'], sourceUnsupported=sorted(unsupported),
                    originArchivePresent=provenance.exists(), originArtifactCount=len(origin_paths), automaticBakeEvidence=bake,
                    imageStatistics=self.images, unknownMeasurements=self.coverage, measurementCoverageComplete=not self.coverage,
                    referenceAdapter=adapter, adapterStderr=result.stderr, inputSha256=self.pins,
                    limits='EXR magic only; RGBA32F is the numeric evidence. Host/editor restoration is a receipt check, not an independent workspace restoration audit. No image/reference/threshold/performance verdict.')


def selection_source():
    source = ROOT/'Runtime/HybridLumenGIValidationSequence.cs'
    text = source.read_text(encoding='utf-8-sig')
    body = text.split('public static bool IsCaptureFrame(int frame, int interval)', 1)[1].split('public static string StageAtFrame', 1)[0]
    require(re.findall(r'frame == (\d+)', body) == [str(n) for n in BOUNDARIES] and
            all(s in body for s in ('frame >= 0 && frame < TotalFrames', 'frame % Math.Max(1, interval) == 0', 'frame == TotalFrames - 1')) and
            re.search(r'TotalFrames\s*=\s*720\s*;', text), 'IsCaptureFrame/TotalFrames source changed; audit contract needs review')
    return dict(file=str(source), sha256=digest(source.read_bytes()), interval=INTERVAL, expectedLogicalFrames=SELECTED)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('native_root', type=Path, help='Fresh -validationPackageOutput root containing host/editor receipts')
    parser.add_argument('--output', type=Path, required=True, help='New report path outside native input; never overwritten')
    parser.add_argument('--node', default='node', help='Installed Node.js executable')
    args = parser.parse_args()
    require(not args.output.exists() and not args.output.resolve().is_relative_to(args.native_root.resolve()), 'Preserve input and previous reports; output must be a new file outside native root')
    audit = Audit(args.native_root)
    report = dict(schema='hlgi-validation-native-integrity-v2', status='incomplete', passed=None, physicalQualityPassed=None,
                  referenceStatus='reference-required', referenceSupplied=False, performanceCompared=False)
    try:
        report['selectionSource'] = selection_source()
        report.update(audit.verify(args.node))
        code = 2  # No reference can never become quality PASS/exit0.
    except Exception as error:
        report.update(dataIntegrityPassed=False, nativeSequenceComplete=False, error=str(error), context=audit.context, inputSha256=audit.pins)
        code = 1
    report['verifierSha256'] = digest(Path(__file__).read_bytes())
    report['adapterSha256'] = digest(ADAPTER.read_bytes())
    report['exitCode'] = code
    with args.output.open('x', encoding='utf-8') as stream:
        json.dump(report, stream, indent=2, allow_nan=False); stream.write('\n')
    print(json.dumps({k: report.get(k) for k in ('status', 'dataIntegrityPassed', 'nativeSequenceComplete', 'measurementCoverageComplete', 'referenceStatus', 'error', 'context', 'exitCode')}))
    return code


if __name__ == '__main__':
    sys.exit(main())
