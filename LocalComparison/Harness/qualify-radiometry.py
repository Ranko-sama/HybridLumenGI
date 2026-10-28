"""One finite pre-integration gate over THIS native run, using the shared log scanner."""
import argparse, hashlib, json, re, traceback
from pathlib import Path
import numpy as np
from native_log_check import scan


def load(path):return json.loads(path.read_text(encoding='utf-8-sig'))
def lines(path):return [json.loads(l) for l in path.read_text(encoding='utf-8-sig').splitlines() if l.strip()]
def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def vector(value):return np.array([value[k] for k in 'xyz'],dtype=float)


def native_hits(path):
    hits=scan(path)
    supplements={'radiometry-observer':r'SCENE_LIGHTOFF_OBSERVER_FAILED|Radiometry (?:gate|observer)[^\r\n]*(?:incomplete|missing|failed)|Receiver (?:completion|geometry coverage) missing',
                 'scratch':r'D3D12ScratchBufferInternal',
                 'd3d-extra':r'\[d3d12\] Unreleased',
                 'source-freeze':r'Prospective source changed after freeze'}
    for number,line in enumerate(path.read_text(encoding='utf-8-sig',errors='replace').splitlines(),1):
        for category,pattern in supplements.items():
            if re.search(pattern,line,re.I):hits.append({'category':category,'line':number,'text':line})
    return hits


def qualify(package):
    output=package/'run';runs=list(output.glob('*/run.json'));assert len(runs)==1,'Require one fresh target run'
    run=runs[0].parent
    attempt=load(package/'native-attempt.json');assert attempt['nativeAttempt']==1 and attempt['maximumLogicalFrames']==120
    assert load(package/'native-exit.json')['exitCode']==0,'Native process failed'
    hits=native_hits(package/'unity.log')
    (package/'native-log-check.json').write_text(json.dumps({'passed':not hits,'hits':hits},indent=2),encoding='utf-8')
    assert not hits,'Shared native log scanner or supplemental signature rejected this run'
    restoration=load(package/'instrumentation/restoration.json');assert restoration and all(r['restored'] for r in restoration)
    manifest=load(package/'instrumentation/manifest.json');project=Path('I:/Unity test/Project')
    for f in manifest['files']:
        p=project/f['path'];assert (digest(p) if p.exists() else None)==f['originalSha256'],('Restored deployment changed',f['path'])
    assert all(digest(project/'Assets/HybridLumenGI'/p)==v for p,v in manifest['productSourceSha256'].items())
    freeze=load(output/'source-freeze.json');assert not freeze['historicalSourceClosure']
    assert freeze['archiveVerified'] and freeze['pathCorrespondenceVerified']
    selection_path=output/'dependency-selection.json';assert digest(selection_path)==freeze['dependencySelectionSha256']
    selection=load(selection_path);selected=set(selection['selected']);excluded={e['path'] for e in selection['exclusions']}
    assert not selected&excluded and set(selection['requested'])==selected|excluded
    assert selection['exclusions']==freeze['exclusions'] and all(e['reason'] for e in selection['exclusions'])
    assert all(m['source'] in selected and m['path']==m['source']+'.meta' for m in selection['additionalMetadata'])
    source_path=output/'reference-scene.json';source_hash=digest(source_path);assert source_hash==freeze['sourceSha256']
    for f in freeze['files']:assert (output/f['archive']).stat().st_size==f['bytes'] and digest(output/f['archive'])==f['sha256'],('Archived source differs',f['path'])
    names={f['path'] for f in freeze['files']}
    assert len(names)==len(freeze['files']) and names==selected|{m['path'] for m in selection['additionalMetadata']}
    assert {'Packages/manifest.json','Packages/packages-lock.json','Assets/RadiometryBaseline/Static.unity'}<=names
    for frame in [103,119]:
        check=load(output/f'source-check-{frame:04}.json')
        assert check['logicalFrame']==frame and check['sameSource'] and check['sameDependencyBytes'] and check['sourceSha256']==source_hash
        assert load(run/f'radiometry-gate-{frame:04}.json')['passed']
    meta=load(run/'run.json');assert meta['requestedFrames']==meta['renderedFrames']==120 and meta['captures']==2 and meta['errors']==0
    assert meta['scene']=='Assets/RadiometryBaseline/Static.unity'
    frames=lines(run/'frames.jsonl');bindings=lines(run/'lightoff-bindings.jsonl')
    assert [f['logicalFrame'] for f in frames]==list(range(120))
    assert [b['logicalFrame'] for b in bindings]==list(range(120)) and all(b['exact'] and b['distinct'] and b['lightCount']==1 for b in bindings)
    assert [f['logicalFrame'] for f in frames if f['captured']]==[104,119]
    assert load(run/'lightoff-summary.json')['passed'] and load(run/'gather-summary.json')['passed']
    updates=lines(run/'cache-update-receipts.jsonl');assert len(updates)==240
    assert {(r['logicalFrame'],r['lane']) for r in updates}=={(n,l) for n in range(120) for l in range(2)}
    cache_receipts=lines(run/'lightoff-receipts.jsonl');gather_receipts=lines(run/'gather-receipts.jsonl')
    for receipts,kind in [(cache_receipts,'lightoff'),(gather_receipts,'gather')]:
        keys=[(r['logicalFrame'],r['stage']) for r in receipts];assert len(keys)==len(set(keys))
        expected=({(n,s) for n in range(120) for s in ['gpu-mask','gpu-lights','gpu-changes','gpu-proposals','cache-observed','cache-actual-0','cache-actual-1']}|
                  {(n,s) for n in range(104,120) for s in ['raw','history','filtered']}) if kind=='lightoff' else (
                  {(103,'events')}|{(n,s) for n in range(104,120) for s in ['events','raw-selected','cards','ranges']})
        assert set(keys)==expected,('Receipt coverage differs',kind,sorted(expected-set(keys)),sorted(set(keys)-expected))
        assert all(r['giFrame']==bindings[r['logicalFrame']]['giFrame'] for r in receipts),('Receipt GI frame differs',kind)
        for r in receipts:
            frame,stage=r['logicalFrame'],r['stage']
            # Exactly the warmup binary payloads intentionally omitted by the contract.
            if (kind=='lightoff' and frame<104 and stage=='cache-observed') or (kind=='gather' and frame==103):continue
            p=run/f'{kind}-{frame:04}-{stage}.bin';assert p.stat().st_size==r['bytes'],('Missing/incorrect receipt bytes',p)
    targets_path=run/'reference-targets.json';targets=load(targets_path)['targets']
    assert [t['id'] for t in targets]==['cache-0','cache-1','gi-0','gi-1','gi-2','gi-3']
    assert all(t['logicalFrame']==119 and t['giFrame']==bindings[-1]['giFrame'] for t in targets)
    selected=load(run/'lightoff-schedule-0119.json');assert selected['aliases']==[0,0,1,1] and len(selected['patches'])==2
    for lane,t in enumerate(targets[:2]):
        p=selected['patches'][lane];assert all(t[k]==p[k] for k in ['entry','stableId','revision','generation'])
        actual=np.fromfile(run/f'lightoff-0119-cache-actual-{lane}.bin',dtype='<f4').reshape(5,4)
        assert np.array_equal(actual[2,:3].astype(float),vector(t['position']))
        assert np.array_equal(actual[3,:3].astype(float),vector(t['normal']))
    receivers=load(run/'receivers-0119.json')['targets'];assert targets[2:]==receivers
    for n in range(104,120):
        for key in ['cache-observed','cache-actual-0','cache-actual-1','raw','history','filtered']:
            values=np.fromfile(run/f'lightoff-{n:04}-{key}.bin',dtype='<f4')
            # Last two vec4 of observed records are uint headers, never interpret them as float radiance.
            if key=='cache-observed':values=values.reshape(4,20,4)[:2,:18].ravel()
            assert np.isfinite(values).all(),('Nonfinite product evidence',n,key)
        for key in ['events','raw-selected','cards','ranges']:assert (run/f'gather-{n:04}-{key}.bin').exists()
        assert len(load(run/f'receivers-{n:04}.json')['targets'])==4
    for n in [104,119]:
        assert (run/f'frame-{n:04}.png').stat().st_size>0 and (run/f'frame-{n:04}.exr').stat().st_size>0
        hdr=np.fromfile(run/f'frame-{n:04}.rgba32f',dtype='<f4');assert hdr.size==640*360*4 and np.isfinite(hdr).all()
    return {'passed':True,'historicalSourceClosure':False,'prospectiveSourceClosure':True,'productObservationValid':True,'nativeExitAccepted':True,
            'deploymentRestored':True,'source':str(source_path.resolve()),'targets':str(targets_path.resolve()),
            'runId':run.name,'sceneSha256':source_hash,'targetsSha256':digest(targets_path),'targetSurfaceCorrespondenceVerified':False,
            'note':'Source/native/receipt gate only; independent source-triangle correspondence is the solver first step before integration.'}


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--package',type=Path,required=True);a=p.parse_args()
    try:result=qualify(a.package)
    except Exception as error:
        result={'passed':False,'integrationAdmitted':False,'error':str(error),'traceback':traceback.format_exc()}
    (a.package/'pre-integration-gate.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
    print(json.dumps(result,ensure_ascii=True));raise SystemExit(0 if result['passed'] else 1)
