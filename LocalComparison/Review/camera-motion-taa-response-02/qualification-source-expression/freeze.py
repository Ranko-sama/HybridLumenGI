"""Freeze the exact author-input adapter; hash native bytes without RGB decode."""
import json
from pathlib import Path
import analyze as q

def freeze():
    here=Path(__file__).resolve().parent;package=here.parent;root=q.ROOT
    destination=here/'source-manifest.json';q.require(not destination.exists(),'Preserve first author-expression freeze')
    sources=[here/name for name in ('analyze.py','test_expression.py','freeze.py','qualification.txt','cpu-validation.json')]
    target=package/'target-input-qualification'
    evidence=[target/name for name in ('audit.py','basis.txt','result.json','audit-source-manifest.json')]
    evidence += sorted(p for p in (package/'qualification-initialization').iterdir() if p.is_file() and p.suffix in ('.py','.txt','.json'))
    evidence += [package/name for name in ('analysis-first.json','analysis-initialization-qualified.json','contract.txt','source-freeze.json',
                    'qualification-ties/analyze.py','qualification-ties/model.py','qualification-ties/source-manifest.json',
                    'native/scene-inputs.json','native/scene-result.json')]
    evidence += [package/'native'/f'frame-{i:03d}.{suffix}' for i in range(48) for suffix in ('json','bin')]
    manifest=dict(schema='camera-taa-source-expression-qualification-v1',
        sources={p.relative_to(root).as_posix():q.sha(p) for p in sources},
        evidence={p.relative_to(root).as_posix():q.sha(p) for p in evidence},
        independentTargetReport=(target/'result.json').relative_to(root).as_posix(),
        originalFailuresPreserved=True,rawBinaryFilesHashed=48,rawOrHistoryRgbDecoded=False,nativeExecutionAdded=False)
    with destination.open('x',encoding='utf-8') as stream:json.dump(manifest,stream,indent=2);stream.write('\n')
    closure=q.source_closure()
    initialization,_,_,init_patch,target_patch,_=q.prepare_adapter();init_closure=initialization.source_closure()
    result=dict(sourceExpressionQualificationReady=True,**closure,initializationQualification=init_closure,
                initializationPatch=init_patch,targetPatch=target_patch,rawOrHistoryRgbDecoded=False,nativeExecutionAdded=False,
                downstreamAnalysisExecuted=False,originalNativeFilesPinned=96)
    with (here/'source-validation.json').open('x',encoding='utf-8') as stream:json.dump(result,stream,indent=2);stream.write('\n')
    print(json.dumps(result))

if __name__=='__main__':freeze()
