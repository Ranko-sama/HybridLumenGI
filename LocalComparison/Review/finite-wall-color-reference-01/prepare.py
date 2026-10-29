"""Temporary full-feature observer and isolated finite reference scene ownership."""
import hashlib
import importlib.util
import json
import sys
from pathlib import Path

P = Path(__file__).resolve().parent
ROOT = P.parents[2]
PROJECT = Path('I:/Unity test/Project')
OWNED = PROJECT / 'Assets/FiniteWallReference01'
OUT = P / 'instrumentation'
FEATURE = 'Runtime/HybridLumenGIRendererFeature.cs'
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
load = lambda p: json.loads(p.read_text(encoding='utf-8-sig'))
def save(p, value):
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(value, indent=2)+'\n', encoding='utf-8')

def prepare():
    assert not OUT.exists() and not OWNED.exists() and not Path(str(OWNED)+'.meta').exists()
    current = {p.relative_to(ROOT).as_posix(): sha(p) for top in ('Runtime','Editor')
               for p in (ROOT/top).rglob('*') if p.is_file() and p.suffix != '.meta'}
    assert all(sha(PROJECT/'Assets/HybridLumenGI'/rel)==value for rel,value in current.items())
    old = (ROOT/FEATURE).read_bytes()
    anchor = b'                using(d.frameTiming.Profile(cmd,"HLGI Gather")) Dispatch(cmd,c,trace,state);'
    assert old.count(anchor)==1
    newline = b'\r\n' if b'\r\n' in old else b'\n'
    call = b'                global::FiniteWallReferenceTap.Record(cmd,((RTHandle)d.raw).rt,((RTHandle)d.geometryWrite).rt,((RTHandle)d.depth).rt,((RTHandle)d.materialWrite).rt,((RTHandle)d.normals).rt,state.camera,d.frame,d.invVP,d.vp,d.view,new Vector2Int((int)d.viewport.width,(int)d.viewport.height),Mathf.Max(0.001f,s.rayBias),Mathf.Clamp(s.raysPerPixel,1,8),s.normalsOctEncoded);'
    data = old.replace(anchor, anchor+newline+call)
    sources = {
        'Assets/FiniteWallReference01/FiniteWallReferenceTap.cs': ROOT/'LocalComparison/Harness/FiniteWallReferenceTap.cs',
        'Assets/FiniteWallReference01/FiniteWallReferenceScene.cs': ROOT/'LocalComparison/Harness/FiniteWallReferenceScene.cs',
        'Assets/FiniteWallReference01/Editor/FiniteWallReferenceEditor.cs': ROOT/'LocalComparison/Harness/FiniteWallReferenceEditor.cs',
    }
    reference = ROOT/'LocalComparison/Reference/ColorBounceRectangle'
    for name in ('FiniteWallReferenceInputs.compute','ReferenceInputFunctions.hlsl','ReferenceScreenSampling.hlsl','ReferenceHit.hlsl'):
        sources['Assets/FiniteWallReference01/Resources/'+name] = reference/'generated'/name
    assert all(p.is_file() for p in sources.values())
    rows=[]
    feature_rel='Assets/HybridLumenGI/'+FEATURE
    for rel,contents in [(feature_rel,data)]+[(r,s.read_bytes()) for r,s in sources.items()]:
        target=PROJECT/rel
        original='original/'+rel if target.exists() else None
        if original:
            backup=OUT/original;backup.parent.mkdir(parents=True,exist_ok=True);backup.write_bytes(target.read_bytes())
        staged=OUT/'prepared'/rel;staged.parent.mkdir(parents=True,exist_ok=True);staged.write_bytes(contents)
        rows.append(dict(path=rel,original=original,originalSha256=sha(target) if target.exists() else None,
                         prepared='prepared/'+rel,sha256=sha(staged)))
    save(OUT/'manifest.json',dict(productSourceSha256=current,files=rows,newMetadata=[],excluded=[],
         scope='One observational gather hook; current full product shaders, finite authored scene, independent input-only sampler'))
    protected=[]
    for rel in ('ProjectSettings/QualitySettings.asset','ProjectSettings/GraphicsSettings.asset','Assets/RuntimeAudit/Functional.unity'):
        target=PROJECT/rel;backup=OUT/'protected'/rel;backup.parent.mkdir(parents=True,exist_ok=True);backup.write_bytes(target.read_bytes())
        protected.append(dict(path=rel,sha256=sha(target),backup='protected/'+rel))
    save(OUT/'protected.json',protected)
    for name in ('source-contract.json','analytic-reference-storage-qualified.json'):
        (P/name).write_bytes((reference/name).read_bytes())
    print(json.dumps(dict(stagedFiles=len(rows),productFiles=len(current))))

def install():
    m=load(OUT/'manifest.json')
    assert not OWNED.exists() and not (OUT/'installed.json').exists()
    for rel,value in m['productSourceSha256'].items():
        assert sha(PROJECT/'Assets/HybridLumenGI'/rel)==value
    for row in m['files']:
        p=PROJECT/row['path'];assert (sha(p) if p.exists() else None)==row['originalSha256']
        assert sha(OUT/row['prepared'])==row['sha256']
    save(OUT/'installed.json',dict(installed=True))
    for row in m['files']:
        p=PROJECT/row['path'];p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes((OUT/row['prepared']).read_bytes())

def restore():
    m=load(OUT/'manifest.json')
    # Archive all newly owned project files before removing this exact isolated root.
    owned=OWNED.resolve();assert owned==Path('I:/Unity test/Project/Assets/FiniteWallReference01').resolve()
    archive=OUT/'post-run'
    if owned.exists():
        for p in owned.rglob('*'):
            if p.is_file():
                dest=archive/p.relative_to(PROJECT);dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(p.read_bytes())
        for p in sorted(owned.rglob('*'),key=lambda v:len(v.parts),reverse=True):
            if p.is_file():p.unlink()
            elif p.is_dir():p.rmdir()
        owned.rmdir()
    meta=Path(str(owned)+'.meta')
    if meta.exists():
        dest=archive/meta.relative_to(PROJECT);dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(meta.read_bytes());meta.unlink()
    for row in m['files']:
        if row['original']:
            backup=OUT/row['original'];assert sha(backup)==row['originalSha256']
            target=PROJECT/row['path']
            assert target.is_file() and sha(target)==row['sha256'],'Temporary feature changed outside the observer manifest'
            dest=archive/row['path'];dest.parent.mkdir(parents=True,exist_ok=True)
            if target.exists():dest.write_bytes(target.read_bytes())
            target.write_bytes(backup.read_bytes())
    matched=all(sha(PROJECT/'Assets/HybridLumenGI'/rel)==value for rel,value in m['productSourceSha256'].items())
    protected=[]
    for row in load(OUT/'protected.json'):
        unchanged=sha(PROJECT/row['path'])==row['sha256']
        if not unchanged:
            assert row['path']=='ProjectSettings/QualitySettings.asset','Unexpected change to protected source'
            dest=archive/row['path'];dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes((PROJECT/row['path']).read_bytes())
            backup=OUT/row['backup'];assert sha(backup)==row['sha256'];(PROJECT/row['path']).write_bytes(backup.read_bytes())
        protected.append(dict(path=row['path'],unchanged=unchanged,restored=sha(PROJECT/row['path'])==row['sha256']))
    save(OUT/'restoration.json',dict(currentProductRestored=matched,ownedRootRemoved=not owned.exists(),protected=protected))
    assert matched and not owned.exists() and all(r['restored'] for r in protected)

def preflight():
    path=P.parent/'current-local-release-67/preflight67.py'
    spec=importlib.util.spec_from_file_location('finite_wall_managed',path);check=importlib.util.module_from_spec(spec);spec.loader.exec_module(check)
    check.PACKAGE=P;check.STAGE=OUT;check.DEST=P/'preflight';check.main()

if __name__=='__main__':
    assert sys.argv[1] in ('prepare','preflight','install','restore')
    globals()[sys.argv[1]]()
