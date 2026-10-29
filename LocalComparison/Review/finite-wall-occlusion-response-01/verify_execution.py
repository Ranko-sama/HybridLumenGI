"""Verify execution identity and restoration separately from radiance analysis."""
import hashlib
import json
from pathlib import Path

P=Path(__file__).resolve().parent
ROOT=P.parents[2]
PROJECT=Path('I:/Unity test/Project')
def load(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()

def verify():
    manifest=load(P/'instrumentation/manifest.json')
    for rel,digest in manifest['productSourceSha256'].items():
        assert sha(ROOT/rel)==digest and sha(PROJECT/'Assets/HybridLumenGI'/rel)==digest,rel
    for row in manifest['files']:
        assert sha(P/'instrumentation'/row['prepared'])==row['sha256'],row['path']
        archived=P/'instrumentation/post-run'/row['path']
        assert sha(archived)==row['sha256'],row['path']
    restored=load(P/'instrumentation/restoration.json')
    assert restored['currentProductRestored'] and restored['ownedRootRemoved']
    for row in load(P/'instrumentation/protected.json'):
        assert sha(PROJECT/row['path'])==row['sha256'],row['path']
    assert not (PROJECT/'Assets/FiniteWallOcclusion01').exists()
    preflight=load(P/'preflight/exit.json')
    assert preflight['exitCode']==0 and all(a['exitCode']==0 for a in preflight['assemblies'])
    assert load(P/'native-exit.json')['exitCode']==0
    editor=load(P/'native/editor-result.json')
    assert editor['status']=='collected' and editor['restored']
    frames=[json.loads(line) for line in (P/'native/frames.jsonl').read_text().splitlines()]
    assert len(frames)==56
    for i,frame in enumerate(frames):
        d=frame['diagnostics']
        assert frame['engineFrame']==i+1 and frame['request']==i+1 and frame['cameraFrames']==i+1
        assert d['hardwareBackend'] and d['hardwareMeshes']==3 and d['hardwareFallbacks']==0
        assert d['chartedOwners']==3 and d['approximateOwners']==0
    return dict(passed=True,productFiles=len(manifest['productSourceSha256']),stagedFiles=len(manifest['files']),
                frames=len(frames),firstRenderSeconds=frames[0]['seconds'],allFramesSourceReady=all(f['ready'] for f in frames),
                restored=True,nativeSha256={p.relative_to(P/'native').as_posix():sha(p) for p in sorted((P/'native').rglob('*')) if p.is_file()},
                scope='Execution, exact geometry backend, archived observer bytes and source restoration; radiance/history checks are separate')

if __name__=='__main__':
    out=P/'execution-receipt.json'
    assert not out.exists(),'Preserve the first execution receipt'
    result=verify();out.write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({k:v for k,v in result.items() if k!='nativeSha256'}))
