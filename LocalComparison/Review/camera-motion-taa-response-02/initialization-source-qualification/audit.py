"""Read-only source-window qualification; never decodes sample/output rows.

This is a post-run admission audit, not a replacement radiance/motion analyzer.
The original full-record/all-48-frames source failure remains authoritative for
that original gate. Only the contract's already declared 31..47 window is assessed.
"""
import argparse
import hashlib
import json
from pathlib import Path
import struct

HERE = Path(__file__).resolve().parent
PACKAGE = HERE.parent
ROOT = PACKAGE.parents[2]
SOURCE_KEYS = {'name', 'stableId', 'revision', 'geometryRevision', 'matrix', 'shaderLinearColor'}
GENERATION_KEYS = {'revision', 'geometryRevision'}


def load(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def require(ok, message):
    if not ok:
        raise AssertionError(message)


def physical(sources):
    require(len(sources) == 3, 'Exactly three source records required')
    for row in sources:
        require(set(row) == SOURCE_KEYS, 'Source schema changed; exclusions must not silently expand')
    return [{key: value for key, value in row.items() if key not in GENERATION_KEYS} for row in sources]


def qualify(records, controls):
    require(len(records) == len(controls) == 48, 'Fixed 48-frame budget required')
    original_physical = physical(records[0]['sources'])
    stable_records = records[30]['sources']
    transitions = []
    for i, (r, c) in enumerate(zip(records, controls)):
        require(r['logicalFrame'] == i and r['complete'] and not r['error'], 'Incomplete frame')
        require(physical(r['sources']) == original_physical, 'Physical source changed')
        require(bool(c[0]) == r['historyValid'] and c[3] == r['changeCount'], 'CPU/GPU control disagreement')
        if i:
            require(r['engineFrame'] == records[i-1]['engineFrame'] + 1, 'Engine sequence changed')
            if r['sources'] != records[i-1]['sources']:
                transitions.append(dict(frame=i, old=[{k:s[k] for k in GENERATION_KEYS} for s in records[i-1]['sources']],
                                        new=[{k:s[k] for k in GENERATION_KEYS} for s in r['sources']],
                                        historyValid=r['historyValid'], gpuControls0=list(c)))
        if i >= 30:
            require(r['sources'] == stable_records, 'Full source generations changed in observation/predecessor window')
        if i >= 31:
            require(c == (1.0, 0.0, 0.0, 0.0), 'Observation window history/change controls differ')
            require(r['previousVP'] == records[i-1]['vp'] and r['previousInvVP'] == records[i-1]['invVP'],
                    'Observation window previous-matrix ownership differs')
            require(r['workFrame'] == records[i-1]['workFrame'] + 1, 'Observation work-frame sequence changed')
    # Narrower than merely discarding warmup metadata: each observed generation
    # transition must occur before the protected predecessor and reject history.
    require(all(t['frame'] < 30 and not t['historyValid'] and t['gpuControls0'][0] == 0 for t in transitions),
            'Warmup generation transition did not independently reject temporal history')
    return dict(sourceWindowQualified=True, physicalSourceFieldsStableFrames=[0,47],
                fullSourceRecordsStableRequiredFrames=[30,47], observationFrames=[31,47],
                generationTransitions=transitions)


def audit():
    freeze = load(PACKAGE/'source-freeze.json')
    for rel, digest in freeze['sources'].items():
        require(sha(ROOT/rel) == digest, 'Frozen source changed: '+rel)
    manifest = load(PACKAGE/'instrumentation/manifest.json')
    for rel, digest in manifest['productSourceSha256'].items():
        require(sha(ROOT/rel) == digest, 'Frozen product source changed: '+rel)
    original_failure = load(PACKAGE/'analysis-first.json')
    require(original_failure == {'passed':False, 'executionOrSourceFailure':'Static geometry/material source changed',
                                 'context':{'logicalFrame':1}}, 'Original first failure differs')
    records = []; controls = []; pins = {}; timeline = []
    for i in range(48):
        receipt = PACKAGE/'native'/f'frame-{i:03}.json'
        binary = receipt.with_suffix('.bin')
        require(binary.stat().st_size == (12 + 264*45)*16, 'Frozen GPU ABI size differs')
        # Read only the twelve input-control vectors, before any per-pixel rows.
        with binary.open('rb') as stream:
            header = stream.read(192)
        c = struct.unpack('<48f', header)[:4]
        r = load(receipt); records.append(r); controls.append(c)
        pins[str(receipt.relative_to(ROOT)).replace('\\','/')] = sha(receipt)
        timeline.append(dict(frame=i, workFrame=r['workFrame'], engineFrame=r['engineFrame'],
                             generationPairs=[[s['revision'],s['geometryRevision']] for s in r['sources']],
                             gpuControls0=list(c), headerSha256=hashlib.sha256(header).hexdigest(),
                             geometryVersion=r['geometryVersion'], transformUpdates=r['transformUpdates'], sceneRebuilds=r['sceneRebuilds']))
    result = qualify(records, controls)
    full_stable_from = next(i for i in range(48) if all(r['sources'] == records[i]['sources'] for r in records[i:]))
    result.update(schema='camera-motion-taa-initialization-source-audit-v1', postRunQualification=True,
                  radianceOrPerPixelRowsRead=False, newNativeExecution=False, productChanged=False,
                  originalAnalysisAccepted=False, overallExecutionOrImageQualityAccepted=False,
                  fullSourceRecordsActuallyStableFrom=full_stable_from, timeline=timeline, receiptSha256=pins,
                  frozenSourcesChecked=len(freeze['sources']), productSourcesChecked=len(manifest['productSourceSha256']),
                  originalFailure=original_failure,
                  unobservedCaller='Not identified: lifecycle notifications are source-consistent candidates, not a measured cause.',
                  minimumGate='All 48 physical source fields exact; full generation-bearing source records exact on 30..47; original 31..47 history/change/matrix gates unchanged. Early observed generation transitions must reject history.',
                  downstream='Independent per-pixel geometry, identity, material, previous support, motion/jitter, history confidence, and original output/coverage gates remain required. This audit does not execute them.',
                  timing='Concurrent GPU gaming load was user-reported; no duration regression/improvement attribution.',
                  sourceSha256={})
    paths = [Path(__file__), HERE/'basis.txt', PACKAGE/'contract.txt', PACKAGE/'analysis-first.json',
             PACKAGE/'source-freeze.json', PACKAGE/'qualification-ties/analyze.py', PACKAGE/'qualification-ties/model.py',
             PACKAGE/'qualification-ties/source-manifest.json', PACKAGE/'instrumentation/manifest.json',
             PACKAGE/'instrumentation/restoration.json', PACKAGE/'run-environment.json',
             ROOT/'Runtime/HybridLumenGIProxy.cs', ROOT/'Runtime/HybridLumenGIScene.cs',
             ROOT/'Runtime/Resources/HybridLumenGI/HybridLumenGIKernels.hlsl',
             ROOT/'LocalComparison/Harness/CameraMotionTaaScene.cs', ROOT/'LocalComparison/Harness/CameraMotionTaaTap.cs']
    for path in paths:
        result['sourceSha256'][path.relative_to(ROOT).as_posix()] = sha(path)
    return result


if __name__ == '__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--output', type=Path, required=True);args=parser.parse_args()
    require(not args.output.exists(), 'Preserve every prior qualification result')
    result=audit()
    with args.output.open('x', encoding='utf-8') as stream:
        json.dump(result, stream, indent=2, sort_keys=True);stream.write('\n')
    print(json.dumps({k:result[k] for k in ('sourceWindowQualified','fullSourceRecordsActuallyStableFrom','radianceOrPerPixelRowsRead','originalAnalysisAccepted')}))
