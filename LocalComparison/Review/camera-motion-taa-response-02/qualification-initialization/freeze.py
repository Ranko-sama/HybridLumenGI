"""Freeze adapter, first failure and captured bytes; never decode pixel RGB."""
import json
from pathlib import Path
import analyze as q

HERE=Path(__file__).resolve().parent
PACKAGE=HERE.parent
ROOT=q.ROOT

def freeze():
    destination=HERE/'source-manifest.json'
    q.require(not destination.exists(),'Preserve original initialization qualification freeze')
    independent=PACKAGE/'initialization-source-qualification'
    sources=[HERE/name for name in ('analyze.py','test_gate.py','freeze.py','qualification.txt','cpu-validation.json')]
    evidence=[independent/name for name in ('audit.py','basis.txt','test_audit.py','cpu-validation.json','result.json','audit-source-manifest.json')]
    evidence += [PACKAGE/name for name in ('analysis-first.json','contract.txt','source-freeze.json','verify_execution.py',
                    'qualification-ties/analyze.py','qualification-ties/model.py','qualification-ties/source-manifest.json',
                    'native/scene-inputs.json','native/scene-result.json')]
    evidence += [PACKAGE/'native'/f'frame-{frame:03d}.{suffix}' for frame in range(48) for suffix in ('json','bin')]
    manifest=dict(schema='camera-taa-initialization-qualification-v1',
        sources={p.relative_to(ROOT).as_posix():q.sha(p) for p in sources},
        evidence={p.relative_to(ROOT).as_posix():q.sha(p) for p in evidence},
        independentSourceReport=(independent/'result.json').relative_to(ROOT).as_posix(),
        originalFirstFailurePreserved=True,rawBinaryFilesHashed=48,rawOrHistoryRgbDecoded=False,nativeExecutionAdded=False,
        scope='Only generation-bearing source equality gate; every original pixel/output/coverage function remains frozen')
    with destination.open('x',encoding='utf-8') as stream:json.dump(manifest,stream,indent=2);stream.write('\n')
    closure=q.source_closure()
    original=q.original_module();_,patch=q.adapted_analyze(original)
    result=dict(sourceQualificationReady=True,**closure,**patch,originalNativeFilesPinned=96,independentAuditFilesPinned=6,
                rawOrHistoryRgbDecoded=False,nativeExecutionAdded=False,downstreamAnalysisExecuted=False)
    with (HERE/'source-validation.json').open('x',encoding='utf-8') as stream:json.dump(result,stream,indent=2);stream.write('\n')
    print(json.dumps(result))

if __name__=='__main__':freeze()
