"""Reuse67's reversible build/asset wiring; add the ordinary example and one finite entry."""
import importlib.util,json,sys,subprocess
from pathlib import Path
P=Path(__file__).resolve().parent;ROOT=P.parents[2];H=ROOT/'LocalComparison/Harness'
PROJECT=Path('I:/Unity test/Project');OUT=P/'instrumentation';BUILD=Path('I:/Unity test/Comparison/Builds/LocalRelease69')
def module(name,path):
    spec=importlib.util.spec_from_file_location(name,path);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m
base=module('reuse67',P.parent/'current-local-release-67/prepare67.py')
base.P=P;base.OUT=OUT;base.BUILD=BUILD
for m in [base.base,base.base.base]:m.PACKAGE=P;m.OUT=OUT
sha=base.sha;load=base.load;save=base.save

def deploy():
    dest=P/'deployment';assert not dest.exists(),'Unique deployment'
    before=load(P.parent/'current-local-release-67/deployment/manifest.json')['after']
    after={p.relative_to(ROOT).as_posix():sha(p) for top in ['Runtime','Editor'] for p in (ROOT/top).rglob('*') if p.is_file() and p.suffix!='.meta'}
    assert set(before)==set(after) and all(sha(PROJECT/'Assets/HybridLumenGI'/p)==v for p,v in before.items())
    changed=[p for p in after if before[p]!=after[p]];assert changed==['Runtime/HybridLumenGIScene.cs']
    dest.mkdir()
    for rel in changed:
        old=dest/'original'/rel;old.parent.mkdir(parents=True,exist_ok=True);old.write_bytes((PROJECT/'Assets/HybridLumenGI'/rel).read_bytes())
    save(dest/'manifest.json',dict(previous='2fefc097b36084e05e88653d8dff8466caf9d513',current=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),before=before,after=after,changed=changed))
    for rel in changed:(PROJECT/'Assets/HybridLumenGI'/rel).write_bytes((ROOT/rel).read_bytes())
    assert all(sha(PROJECT/'Assets/HybridLumenGI'/p)==v for p,v in after.items())
    print(json.dumps(dict(updated=changed,files=len(after))))

def prepare():
    fragment=P/'CurrentReleaseCubeSetup.cs.txt';assert not fragment.exists()
    fragment.write_bytes((P.parent/'current-local-release-67/CurrentReleaseCubeSetup.cs.txt').read_bytes())
    base.prepare();manifest=load(OUT/'manifest.json')
    for name in ['ContinuousDeformationExample.cs','ContinuousDeformationCheck.cs','ContinuousDeformationRun.cs']:
        rel='Assets/ComparisonHarness/'+name;dest=PROJECT/rel;assert not dest.exists() and not Path(str(dest)+'.meta').exists()
        staged=OUT/'prepared'/rel;staged.write_bytes((H/name).read_bytes())
        manifest['files'].append(dict(path=rel,original=None,originalSha256=None,prepared='prepared/'+rel,sha256=sha(staged)));manifest['newMetadata'].append(rel+'.meta')
    row=next(row for row in manifest['files'] if row['path'].endswith('/ComparisonCapture.cs'))
    staged=OUT/row['prepared'];text=staged.read_text(encoding='utf-8')
    text=base.replace(text,'    void Start()\n',(H/'ContinuousDeformationCapture.cs.txt').read_text(encoding='utf-8')+'\n    void Start()\n')
    staged.write_text(text,encoding='utf-8');row['sha256']=sha(staged)
    manifest['scope']='Current50b63c3, ordinary Space start/stop example, one256frame finite mode; unchanged67 Cube definition and no new core algorithm'
    save(OUT/'manifest.json',manifest)
    (OUT/'prepare69.executed.py.txt').write_bytes(Path(__file__).read_bytes())
    print('69 example and bounded two-image entry staged')

def preflight():
    m=module('preflight67reuse',P.parent/'current-local-release-67/preflight67.py')
    m.PACKAGE=P;m.STAGE=OUT;m.DEST=P/'preflight';m.main()

def launcher():
    assert load(P/'build-report.json')['result']=='Succeeded'
    assert not (BUILD/'Start-LocalRelease.cmd').exists()
    (BUILD/'Start-LocalRelease.cmd').write_bytes((H/'Start-LocalRelease.cmd').read_bytes())
    (BUILD/'LocalRelease-README.txt').write_bytes((H/'LocalRelease-README.txt').read_bytes())
    print('LocalRelease69 launcher installed; default persistent Space start/stop')

if __name__=='__main__':
    action=sys.argv[1];assert action in ['deploy','prepare','preflight','install','restore','launcher']
    if action in ['install','restore']:getattr(base,action)()
    else:globals()[action]()
