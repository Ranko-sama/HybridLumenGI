"""Isolated real-geometry finite cache feedback observation; no product edits."""
import importlib.util
import json
import sys
from pathlib import Path

P=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('cache_feedback_base',P.parent/'finite-wall-color-reference-01/prepare.py')
base=importlib.util.module_from_spec(spec);spec.loader.exec_module(base)
base.P=P;base.OUT=P/'instrumentation'
ROOT=base.ROOT;OUT=base.OUT

def once(data,old,new):
    assert data.count(old)==1,(old[:100],data.count(old))
    return data.replace(old,new)

def prepare():
    reference=ROOT/'LocalComparison/Reference/CacheFeedbackFinite'
    generated=reference/'generated'
    assert generated.is_dir() and list(generated.glob('*.compute')),'Complete the input-only generator before staging'
    base.prepare()
    manifest=base.load(OUT/'manifest.json')
    kept=[]
    for row in manifest['files']:
        if row['path'].startswith('Assets/FiniteWallReference01/'):
            staged=OUT/row['prepared'];assert staged.resolve().is_relative_to(OUT.resolve());staged.unlink()
        else:kept.append(row)
    manifest['files']=kept
    def stage(rel,data):
        target=base.PROJECT/rel
        row=next((r for r in manifest['files'] if r['path']==rel),None)
        if row is None:
            original='original/'+rel if target.exists() else None
            if original:
                backup=OUT/original;backup.parent.mkdir(parents=True,exist_ok=True);backup.write_bytes(target.read_bytes())
            row=dict(path=rel,original=original,originalSha256=base.sha(target) if target.exists() else None,prepared='prepared/'+rel)
            manifest['files'].append(row)
        path=OUT/row['prepared'];path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(data);row['sha256']=base.sha(path)
    feature=(ROOT/base.FEATURE).read_bytes();nl=b'\r\n' if b'\r\n' in feature else b'\n'
    dispatch=b'                    cmd.DispatchCompute(c,update,(state.cacheEntryCount+63)/64,1,1);'
    before=b'                    global::CacheFeedbackFiniteTap.RecordBeforeUpdate(cmd,state.surfaceCache,state.scene,state.changes,state.scheduler.UpdateMask,state.cache[d.cacheRead],state.cache[1-d.cacheRead],state.camera,d.frame,d.epoch,d.cacheRead,state.patchGrid,Mathf.Clamp(s.cacheRaysPerFace,1,32),Mathf.Max(0.001f,s.rayBias),Mathf.Clamp01(s.bounceFeedback),d.lightCount);'
    after=b'                    global::CacheFeedbackFiniteTap.RecordAfterUpdate(cmd,state.cache[d.cacheRead],state.cache[1-d.cacheRead],state.camera,d.frame);'
    feature=once(feature,dispatch,before+nl+dispatch+nl+after)
    gather=b'                using(d.frameTiming.Profile(cmd,"HLGI Gather")) Dispatch(cmd,c,trace,state);'
    tap=b'                global::CacheFeedbackFiniteTap.RecordGather(cmd,((RTHandle)d.raw).rt,((RTHandle)d.geometryWrite).rt,((RTHandle)d.depth).rt,((RTHandle)d.materialWrite).rt,((RTHandle)d.normals).rt,state.camera,d.frame,d.invVP,d.vp,d.view,new Vector2Int((int)d.viewport.width,(int)d.viewport.height),Mathf.Max(0.001f,s.rayBias),Mathf.Clamp(s.raysPerPixel,1,8),s.normalsOctEncoded);'
    feature=once(feature,gather,gather+nl+tap)
    stage('Assets/HybridLumenGI/'+base.FEATURE,feature)
    harness=ROOT/'LocalComparison/Harness'
    names=('CacheFeedbackFiniteScene.cs','CacheFeedbackFiniteTap.cs','CacheFeedbackFiniteEditor.cs')
    for name in names:
        stage('Assets/FiniteWallReference01/'+('Editor/' if name.endswith('Editor.cs') else '')+name,(harness/name).read_bytes())
    for path in sorted(generated.rglob('*')):
        if path.is_file() and path.suffix in ('.compute','.hlsl'):
            stage('Assets/FiniteWallReference01/Resources/'+path.relative_to(generated).as_posix(),path.read_bytes())
    # The reused owner helper copied the earlier single-bounce reference; replace
    # its source contract and remove that unrelated mathematical result before freezing.
    (P/'source-contract.json').write_bytes((reference/'source-contract.json').read_bytes())
    (P/'analytic-reference-storage-qualified.json').unlink()
    manifest['scope']='Fixed32 measured-black frames then exactly2 source-on cache updates; full Feature, geometry-only inputs and separate raw/cache observations'
    base.save(OUT/'manifest.json',manifest)
    base.save(OUT/'harness-source.json',{name:base.sha(harness/name) for name in names})
    base.save(OUT/'reference-source-preparation.json',{path.relative_to(ROOT).as_posix():base.sha(path) for path in sorted(reference.rglob('*')) if path.is_file() and path.suffix in ('.py','.json','.compute','.hlsl','.md')})
    print(json.dumps(dict(stagedFiles=len(manifest['files']),executeMethod='CacheFeedbackFiniteEditor.Run',frames=34)))

def freeze_reference():
    # The mathematical/input tools may finish while managed preflight runs.
    # Preserve that preparation snapshot; freeze their final bytes before native.
    assert not (OUT/'reference-source.json').exists() and not (P/'attempt.json').exists()
    assert base.load(P/'preflight/exit.json')['exitCode']==0
    reference=ROOT/'LocalComparison/Reference/CacheFeedbackFinite'
    (P/'source-contract.json').write_bytes((reference/'source-contract.json').read_bytes())
    sources={path.relative_to(ROOT).as_posix():base.sha(path) for path in sorted(reference.rglob('*')) if path.is_file() and path.suffix in ('.py','.json','.compute','.hlsl','.md')}
    for name in ('qualify_native_inputs.py','decode_sampler.py','generate_sampler.py'):
        path=reference.parent/'ColorBounceRectangle'/name;sources[path.relative_to(ROOT).as_posix()]=base.sha(path)
    base.save(OUT/'reference-source.json',sources)
    print('Final reference sources frozen before native execution')

def restage_dxc():
    assert not (P/'attempt.json').exists() and not (OUT/'reference-source.json').exists()
    prior=OUT/'manifest-before-dxc.json';assert not prior.exists()
    manifest=base.load(OUT/'manifest.json');reference=ROOT/'LocalComparison/Reference/CacheFeedbackFinite/generated'
    compiled=base.load(reference/'manifest.json')
    assert len(compiled['compile'])==4 and all(r['exitCode']==0 for r in compiled['compile'])
    prefix='Assets/FiniteWallReference01/Resources/'
    changes=[]
    for row in manifest['files']:
        if not row['path'].startswith(prefix):continue
        staged=OUT/row['prepared'];fresh=reference/row['path'][len(prefix):]
        assert base.sha(staged)==row['sha256']
        if staged.read_bytes()==fresh.read_bytes():continue
        assert fresh.suffix=='.compute'
        old=staged.read_bytes();new=fresh.read_bytes()
        assert new.replace(b'#pragma use_dxc\r\n',b'').replace(b'#pragma use_dxc\n',b'')==old
        changes.append((row,staged,new))
    assert len(changes)==1,'Only the explicit observer compiler pragma may change here'
    prior.write_bytes((OUT/'manifest.json').read_bytes())
    records=[]
    for row,staged,new in changes:
        archived=OUT/'shader-before-dxc'/Path(row['path']).name;archived.parent.mkdir(parents=True,exist_ok=True);archived.write_bytes(staged.read_bytes())
        old_sha=row['sha256'];staged.write_bytes(new);row['sha256']=base.sha(staged)
        records.append(dict(path=row['path'],before=old_sha,after=row['sha256']))
    base.save(OUT/'manifest.json',manifest)
    base.save(OUT/'shader-restaging.json',dict(changes=records,reason='Metadata uses nine UAVs; explicitly select DXC for the DX12-only observer',managedSourcesUnchanged=True,compiledManifestSha256=base.sha(reference/'manifest.json')))
    print('Restaged only explicit observer DXC pragma; prior staging and managed preflight preserved')

def install():
    for name,digest in base.load(OUT/'reference-source.json').items():
        assert base.sha(ROOT/name)==digest,'Reference source changed after final freeze: '+name
    for name,digest in base.load(OUT/'harness-source.json').items():
        assert base.sha(ROOT/'LocalComparison/Harness'/name)==digest,'Harness changed after preflight: '+name
    assert (P/'source-contract.json').read_bytes()==(ROOT/'LocalComparison/Reference/CacheFeedbackFinite/source-contract.json').read_bytes()
    base.install()

if __name__=='__main__':
    assert sys.argv[1] in ('prepare','preflight','restage_dxc','freeze_reference','install','restore')
    (globals()[sys.argv[1]] if sys.argv[1] in ('prepare','restage_dxc','freeze_reference','install') else getattr(base,sys.argv[1]))()
