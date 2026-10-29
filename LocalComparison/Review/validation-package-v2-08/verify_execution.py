"""Check the frozen execution source, restored project, and archived bake bindings."""
import hashlib
import json
import re
from pathlib import Path

P = Path(__file__).resolve().parent
ROOT = P.parents[2]
PROJECT = Path('I:/Unity test/Project')
OUT = Path('I:/Unity test/Comparison/ValidationPackageV208')
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
load = lambda p: json.loads(p.read_text(encoding='utf-8-sig'))

frozen = load(P / 'source-freeze.json')
for mapping in ('sources', 'evidence'):
    for name, value in frozen[mapping].items():
        assert sha(ROOT / name) == value, name
for name, value in frozen['productSourceSha256'].items():
    assert sha(ROOT / name) == sha(PROJECT / 'Assets/HybridLumenGI' / name) == value, name
protected = load(P / 'instrumentation/protected.json')
for row in protected:
    assert sha(PROJECT / row['path']) == row['sha256'], row['path']
assert not (PROJECT / 'Assets/ValidationPackageV201').exists()
assert not (PROJECT / 'Assets/ValidationPackageV201.meta').exists()
restoration = load(P / 'restoration.json')
for row in restoration['archivedFiles']:
    assert sha(OUT / 'project-archive' / row['path']) == row['sha256'], row['path']
run = OUT / 'project-archive/Assets/ValidationPackageV201/Generated/Scenes/Run'
guid = lambda p: re.search(r'^guid: (\w+)$', p.read_text(), re.M).group(1)
proxy = guid(ROOT / 'Runtime/HybridLumenGIProxy.cs.meta')
sdf = guid(run / 'Mesh-000-SDF.asset.meta')
charts = guid(run / 'Mesh-000-SurfaceCharts.asset.meta')
blocks = [b for b in (run / 'Validation.unity').read_text().split('--- !u!') if f'guid: {proxy},' in b]
assert len(blocks) == 20
for block in blocks:
    assert f'meshSdf: {{fileID: 11400000, guid: {sdf},' in block
    assert f'surfaceCharts: {{fileID: 11400000, guid: {charts},' in block
    assert re.search(r'sourceRenderer: \{fileID: [1-9]\d*\}', block)
native = load(P / 'native-exit.json')
assert native['exitCode'] == 0 and load(P / 'native-log-analysis.json')['passed']
verification = load(P / 'package-verification-first.json')
assert verification['dataIntegrityPassed'] and verification['nativeSequenceComplete']
lifecycle = [json.loads(s) for s in (OUT / 'lifecycle.jsonl').read_text().splitlines()]
begins = [r for r in lifecycle if r['stage'] == 'begin-camera']
ends = [r for r in lifecycle if r['stage'] == 'end-camera-before-sequence-receipt']
assert len(begins) == len(ends) == 720
assert len({r['pipelineIdentity'] for r in begins + ends}) == 1
assert len({r['passIdentity'] for r in begins + ends}) == 1
assert all(r['cameras'][0]['frame'] == i + 1 for i, r in enumerate(ends))
result = dict(passed=True, scope='Source/execution/restoration and archived asset binding integrity only',
    sourceFreezeSha256=sha(P/'source-freeze.json'), products=len(frozen['productSourceSha256']),
    protectedFiles=len(protected), ownedRootRemoved=True, archivedFiles=len(restoration['archivedFiles']),
    boundProxies=len(blocks), uniqueMeshBakes=1, nativeExitCode=0, samePipelineAndPassFor720=True,
    verificationSha256=sha(P/'package-verification-first.json'), lifecycleSha256=sha(OUT/'lifecycle.jsonl'),
    physicalQualityPassed=None, performanceCompared=False)
with (P / 'execution-verification.json').open('x', encoding='utf-8') as f:
    json.dump(result, f, indent=2); f.write('\n')
print(json.dumps(result))
