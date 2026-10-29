"""Build-only owned scene staging, source identity and restoration for the unified local release."""
import hashlib
import importlib.util
import json
from pathlib import Path
import stat
import subprocess
import sys

P = Path(__file__).resolve().parent
ROOT = P.parents[2]
PROJECT = Path('I:/Unity test/Project')
BUILD = Path('I:/Unity test/Comparison/Builds/LocalRelease74')
ARCHIVE = Path('I:/Unity test/Comparison/Release74BuildArchive')
STAGE = P/'instrumentation'
OWNED = ['Assets/UnifiedRelease74', 'Assets/StreamingAssets/UnifiedRelease74']
ENTRY = 'Assets/ComparisonHarness/RuntimeAuditEntry.cs'
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
load = lambda p: json.loads(p.read_text(encoding='utf-8-sig'))
def save(p, value):
    p.parent.mkdir(parents=True, exist_ok=True)
    with p.open('x', encoding='utf-8') as stream: json.dump(value, stream, indent=2); stream.write('\n')
def safe(p):
    for item in (p, *p.parents):
        if item.exists(): assert not item.lstat().st_file_attributes & stat.FILE_ATTRIBUTE_REPARSE_POINT, str(item)
def products():
    return {p.relative_to(ROOT).as_posix():sha(p) for top in ('Runtime','Editor') for p in (ROOT/top).rglob('*') if p.is_file() and p.suffix != '.meta'}
def match():
    frozen = load(STAGE/'manifest.json')['productSourceSha256']
    assert products() == frozen
    assert all(sha(PROJECT/'Assets/HybridLumenGI'/r) == h for r,h in frozen.items())
    return frozen

def prepare():
    assert not STAGE.exists() and not BUILD.exists() and not ARCHIVE.exists()
    for name in OWNED:
        safe(PROJECT/name); assert not (PROJECT/name).exists() and not (PROJECT/(name+'.meta')).exists()
    old = load(P.parent/'unified-sample-02/deployment.json')['productSourceSha256']; current = products()
    assert all(sha(PROJECT/'Assets/HybridLumenGI'/r) == h for r,h in old.items())
    assert not (old.keys()-current.keys())
    changed = [r for r,h in current.items() if old.get(r) != h]
    added = [r for r in changed if r not in old]
    for r in added: assert not (PROJECT/'Assets/HybridLumenGI'/r).exists() and not (PROJECT/'Assets/HybridLumenGI'/(r+'.meta')).exists()
    deployment = []
    for r in changed + [r+'.meta' for r in added]:
        target = PROJECT/'Assets/HybridLumenGI'/r; backup = P/'product-original'/r
        if target.exists(): backup.parent.mkdir(parents=True, exist_ok=True); backup.write_bytes(target.read_bytes())
        deployment.append(dict(path=r,beforeSha256=sha(target) if target.exists() else None,sha256=sha(ROOT/r)))
    save(P/'deployment-intent.json',dict(files=deployment))
    for row in deployment:
        target = PROJECT/'Assets/HybridLumenGI'/row['path']; target.write_bytes((ROOT/row['path']).read_bytes())
    rows = []
    def staged(name, data):
        path = STAGE/'prepared'/name; path.parent.mkdir(parents=True, exist_ok=True); path.write_bytes(data)
        rows.append(dict(path=name,prepared=path.relative_to(STAGE).as_posix(),sha256=sha(path)))
    for r in current:
        if r.endswith('.cs'): staged('Assets/HybridLumenGI/'+r, (ROOT/r).read_bytes())
    for name in ('UnifiedSampleHost.cs','UnifiedSampleReleaseBootstrap.cs','UnifiedSampleReleaseBuild.cs'):
        staged(OWNED[0] + ('/Editor/' if name.endswith('Build.cs') else '/') + name, (ROOT/'LocalComparison/Harness'/name).read_bytes())
    entry = (PROJECT/ENTRY).read_bytes()
    marker = b'if(Application.isEditor)return;'
    assert entry.count(marker) == 1
    staged(ENTRY, entry.replace(marker, marker+b'\n        if(UnityEngine.Object.FindFirstObjectByType<HybridLumenGIUnifiedSample>())return;'))
    protected = []
    for name in (ENTRY,'ProjectSettings/QualitySettings.asset','ProjectSettings/GraphicsSettings.asset','Assets/RuntimeAudit/Functional.unity','Assets/StreamingAssets.meta'):
        path = PROJECT/name; backup = STAGE/'original'/name; backup.parent.mkdir(parents=True, exist_ok=True); backup.write_bytes(path.read_bytes())
        protected.append(dict(path=name,backup=backup.relative_to(STAGE).as_posix(),sha256=sha(path)))
    save(STAGE/'protected.json',protected)
    save(STAGE/'manifest.json',dict(sourceCommit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
         productSourceSha256=current,files=rows,scope='Unified ordinary interactive Player; opt-in finite verification'))
    match(); print(json.dumps(dict(prepared=True,changedProducts=changed)))

def preflight():
    path = P.parent/'current-local-release-67/preflight67.py'
    spec=importlib.util.spec_from_file_location('release74_preflight',path); helper=importlib.util.module_from_spec(spec);spec.loader.exec_module(helper)
    helper.PACKAGE,helper.STAGE,helper.DEST=P,STAGE,P/'preflight'; helper.main()

def install():
    match(); assert not BUILD.exists() and not ARCHIVE.exists()
    for name in OWNED:
        safe(PROJECT/name); assert not (PROJECT/name).exists() and not (PROJECT/(name+'.meta')).exists()
    protected=load(STAGE/'protected.json')
    assert all(sha(PROJECT/r['path']) == sha(STAGE/r['backup']) == r['sha256'] for r in protected)
    rows=[r for r in load(STAGE/'manifest.json')['files'] if not r['path'].startswith('Assets/HybridLumenGI/')]
    assert all(sha(STAGE/r['prepared'])==r['sha256'] for r in rows)
    save(STAGE/'installed.json',dict(manifestSha256=sha(STAGE/'manifest.json'),files=rows))
    for r in rows:
        target=PROJECT/r['path']; target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes((STAGE/r['prepared']).read_bytes())

def restore():
    match(); assert not ARCHIVE.exists()
    installed=load(STAGE/'installed.json'); protected=load(STAGE/'protected.json')
    for r in installed['files']: assert not (PROJECT/r['path']).exists() or sha(PROJECT/r['path']) == r['sha256']
    paths=[]
    for name in OWNED:
        owned=PROJECT/name; safe(owned)
        assert owned.resolve().is_relative_to((PROJECT/'Assets').resolve())
        for path in owned.rglob('*') if owned.exists() else []: safe(path)
        paths += [p for p in owned.rglob('*') if p.is_file()] if owned.exists() else []
        meta=PROJECT/(name+'.meta')
        if meta.exists(): safe(meta);paths.append(meta)
    for r in protected:
        assert sha(STAGE/r['backup']) == r['sha256']
        if sha(PROJECT/r['path']) != r['sha256']:
            assert r['path'] in (ENTRY,'ProjectSettings/QualitySettings.asset')
            paths.append(PROJECT/r['path'])
    archive=[]
    for path in paths:
        target=ARCHIVE/path.relative_to(PROJECT);target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(path.read_bytes())
        assert sha(target)==sha(path);archive.append(dict(path=path.relative_to(PROJECT).as_posix(),sha256=sha(path)))
    # All copies are complete before deleting any of the two exact fresh roots.
    for name in OWNED:
        owned=PROJECT/name;safe(owned)
        if owned.exists():
            for path in sorted(owned.rglob('*'),key=lambda p:len(p.parts),reverse=True):
                safe(path);assert path.resolve().is_relative_to(owned.resolve())
                if path.is_file():path.unlink()
                else:path.rmdir()
            owned.rmdir()
        meta=PROJECT/(name+'.meta')
        if meta.exists():safe(meta);meta.unlink()
    for r in protected:
        target=PROJECT/r['path']
        if sha(target)!=r['sha256']:target.write_bytes((STAGE/r['backup']).read_bytes())
    match();assert all(sha(PROJECT/r['path'])==r['sha256'] for r in protected)
    save(P/'restoration.json',dict(passed=True,ownedRootsRemoved=True,protectedFilesRestored=True,archive=archive,archiveDirectory=str(ARCHIVE)))

def artifacts():
    report=load(P/'build-report.json');assert report['result']=='Succeeded' and report['restored'] and not report.get('error')
    assert load(P/'build-exit.json')['exitCode']==0 and load(P/'restoration.json')['passed']
    assert report['sourceUnchanged'] and report['requestedOptions']==report['actualOptions']=='None'
    manifest=load(STAGE/'manifest.json');match()
    inputs={r['path']:r['sha256'] for r in report['inputs']}
    assert all(inputs['Assets/HybridLumenGI/'+r]==h for r,h in manifest['productSourceSha256'].items())
    assert all(inputs[r['path']]==r['sha256'] for r in manifest['files'])
    save(P/'build-products.json',{p.relative_to(BUILD).as_posix():sha(p) for p in BUILD.rglob('*') if p.is_file()})
    save(P/'build-analysis.json',dict(passed=True,sourceManifestSha256=sha(STAGE/'manifest.json'),scene=report['scene'],
         ordinaryInteractive=True,sourceMatched=True,productionQualityPassed=None,performanceCompared=False))

if __name__=='__main__':
    assert sys.argv[1] in ('prepare','preflight','install','restore','artifacts')
    globals()[sys.argv[1]]()
