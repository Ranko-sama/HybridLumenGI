"""Ordinary Release startup/build overlay; product implementation bytes stay unchanged."""
import argparse,hashlib,importlib.util,json,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];H=ROOT/'LocalComparison/Harness';PROJECT=Path('I:/Unity test/Project')
PACKAGE=ROOT/'LocalComparison/Review/local-release-baseline-01';OUT=PACKAGE/'instrumentation'
spec=importlib.util.spec_from_file_location('base',H/'prepare-player-smoke.py');base=importlib.util.module_from_spec(spec);spec.loader.exec_module(base)
base.PACKAGE=PACKAGE;base.OUT=OUT;sha=base.sha;replace=base.replace

def configure_steady():
    global PACKAGE,OUT
    PACKAGE=ROOT/'LocalComparison/Review/local-release-steady-use-01';OUT=PACKAGE/'instrumentation'
    base.PACKAGE=PACKAGE;base.OUT=OUT

def configure_integration():
    global PACKAGE,OUT
    PACKAGE=ROOT/'LocalComparison/Review/current-release-integration-01';OUT=PACKAGE/'instrumentation'
    base.PACKAGE=PACKAGE;base.OUT=OUT
def configure_final_image():
    global PACKAGE,OUT
    PACKAGE=ROOT/'LocalComparison/Review/current-representative-final-image-01';OUT=PACKAGE/'instrumentation'
    base.PACKAGE=PACKAGE;base.OUT=OUT
def prepare():
    assert not OUT.exists(),'Unique Release preparation already exists'
    product={p.relative_to(ROOT).as_posix():sha(p) for top in ['Runtime','Editor'] for p in (ROOT/top).rglob('*') if p.is_file() and p.suffix!='.meta'}
    assert all(sha(PROJECT/'Assets/HybridLumenGI'/p)==v for p,v in product.items())
    changed={}
    entry=PROJECT/'Assets/ComparisonHarness/RuntimeAuditEntry.cs'
    changed[entry]=replace(entry.read_text(),'        if(Application.isEditor)return;','        if(Application.isEditor)return;\n        if(LocalReleaseBootstrap.TryStart())return;').encode()
    trace=PROJECT/'Assets/ComparisonHarness/ResourceShutdownTrace.cs'
    changed[trace]=replace(trace.read_text(),'    static void RuntimeStart(){Install();Mark("runtime-before-scene");}',
        '    static void RuntimeStart(){if(!Application.isEditor&&!Debug.isDebugBuild)return;Install();Mark("runtime-before-scene");}').encode()
    changed[PROJECT/'Assets/ComparisonHarness/LocalReleaseBootstrap.cs']=(H/'LocalReleaseBootstrap.cs').read_bytes()
    capture=PROJECT/'Assets/ComparisonHarness/ComparisonCapture.cs'
    changed[capture]=replace(capture.read_text(),'    void Start()\n', (H/'SingleFinalCaptureMethods.cs.txt').read_text()+'\n    void Start()\n').encode()
    changed[PROJECT/'Assets/ComparisonHarness/Editor/CurrentPlayerBuild.cs']=(H/'CurrentPlayerBuild.cs').read_bytes()
    OUT.mkdir(parents=True)
    m={'baseline':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'productSourceSha256':product,'files':[],'newMetadata':[],'excluded':[],
       'scope':'ordinary nonDevelopment Functional Player; no product source edits or GPU probe wiring'}
    for i,(path,data) in enumerate(changed.items()):
        rel=path.relative_to(PROJECT).as_posix();old=path.read_bytes() if path.exists() else None
        if old is not None:(OUT/f'{i}.original').write_bytes(old)
        target=OUT/'prepared'/rel;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(data)
        m['files'].append({'path':rel,'original':f'{i}.original' if old is not None else None,'originalSha256':hashlib.sha256(old).hexdigest() if old is not None else None,'prepared':'prepared/'+rel,'sha256':hashlib.sha256(data).hexdigest()})
        if not Path(str(path)+'.meta').exists():m['newMetadata'].append(rel+'.meta')
    # Three old unreferenced test includes are outside the approved product inventory.
    # Omit them and their metadata from this build only, retaining exact recoverable bytes.
    for name in ['GatherTraceWriter.hlsl','LightOffCacheWriter.hlsl','ThinWallQuery.hlsl']:
        for suffix in ['', '.meta']:
            path=PROJECT/'Assets/HybridLumenGI/Runtime/Resources/HybridLumenGI'/(name+suffix)
            if not path.exists():continue
            rel=path.relative_to(PROJECT).as_posix();backup='excluded-'+str(len(m['excluded']))+'.original';(OUT/backup).write_bytes(path.read_bytes())
            m['excluded'].append({'path':rel,'original':backup,'sha256':sha(path)})
    (OUT/'manifest.json').write_text(json.dumps(m,indent=2));(OUT/'installer.executed.py.txt').write_bytes(Path(__file__).read_bytes())
    print(json.dumps({'stagedFiles':len(changed),'unchangedProductFiles':len(product),'excludedHistoricalIncludeFiles':len(m['excluded'])}))
def exclusion_path(row):
    path=(PROJECT/row['path']).resolve();assert path.is_relative_to((PROJECT/'Assets/HybridLumenGI/Runtime').resolve());return path
def install():
    base.install();m=json.loads((OUT/'manifest.json').read_text())
    for row in m['excluded']:
        path=exclusion_path(row);assert sha(path)==row['sha256'];assert sha(OUT/row['original'])==row['sha256'];path.unlink()
def restore():
    base.restore();m=json.loads((OUT/'manifest.json').read_text())
    for row in m['excluded']:
        path=exclusion_path(row);assert not path.exists(),'Do not overwrite a changed historical include';data=(OUT/row['original']).read_bytes();assert hashlib.sha256(data).hexdigest()==row['sha256'];path.write_bytes(data)
    (OUT/'excluded-restoration.json').write_text(json.dumps({'allRestored':all(sha(exclusion_path(row))==row['sha256'] for row in m['excluded']),'files':m['excluded']},indent=2))
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('action',choices=['prepare','install','restore']);mode=p.add_mutually_exclusive_group();mode.add_argument('--steady',action='store_true');mode.add_argument('--integration',action='store_true');mode.add_argument('--final-image',action='store_true');a=p.parse_args()
    if a.steady:configure_steady()
    if a.integration:configure_integration()
    if a.final_image:configure_final_image()
    globals()[a.action]()
