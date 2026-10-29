"""One Pro-reviewed continuation. Preserve the first attempt and all runtime bytes."""
import copy,importlib.util,json,sys
from pathlib import Path
P=Path(__file__).resolve().parent;ROOT=P.parents[2];C=P/'build-correction';OUT=C/'instrumentation'
PROJECT=Path('I:/Unity test/Project');BUILD=Path('I:/Unity test/Comparison/Builds/LocalRelease69')
def module(name,path):
    spec=importlib.util.spec_from_file_location(name,path);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m
base=module('correction67base',P.parent/'current-local-release-67/prepare67.py')
base.P=C;base.OUT=OUT;base.BUILD=BUILD
for item in [base.base,base.base.base]:item.PACKAGE=C;item.OUT=OUT
sha=base.sha;load=base.load;save=base.save
old='AssetDatabase.AssetPathToGUID(Release67CubePath)))'
new='AssetDatabase.AssetPathToGUID(Release67CubePath,AssetPathToGUIDOptions.OnlyExistingAssets)))'

def prepare():
    assert not C.exists() and not BUILD.exists(),'Unique correction/output required'
    assert load(P/'build-exit.json')['exitCode']==1 and not (P/'build-report.json').exists()
    assert load(P/'preflight/exit.json')['exitCode']==0
    m=load(P/'instrumentation/manifest.json');state=load(P/'asset-state.json');checks=[]
    def verify(path,expected):
        actual=sha(path) if path.is_file() else None
        assert actual==expected and not path.is_dir(),'Input not restored: '+str(path)
        checks.append(dict(path=str(path),sha256=actual))
    for rel,value in m['productSourceSha256'].items():verify(ROOT/rel,value);verify(PROJECT/'Assets/HybridLumenGI'/rel,value)
    for row in m['files']:
        verify(PROJECT/row['path'],row['originalSha256']);verify(P/'instrumentation'/row['prepared'],row['sha256'])
    for rel in m['newMetadata']:verify(PROJECT/rel,None)
    for row in m['excluded']:verify(PROJECT/row['path'],row['sha256'])
    for row in state['files']:verify(PROJECT/row['path'],row['sha256Before'])
    frozen=P/'instrumentation/prepared/Assets/ComparisonHarness/Editor/CurrentPlayerBuild.cs'
    text=frozen.read_text(encoding='utf-8');assert text.count(old)==1
    fragment=(P/'CurrentReleaseCubeSetup.cs.txt').read_text(encoding='utf-8')
    assert fragment.count(new)==1 and fragment.replace(new,old)==(P.parent/'current-local-release-67/CurrentReleaseCubeSetup.cs.txt').read_text(encoding='utf-8')
    C.mkdir();OUT.mkdir();save(C/'current-inputs.json',dict(allCurrent=True,checks=checks))
    changed=[]
    for row in m['files']:
        source=P/'instrumentation'/row['prepared'];dest=OUT/row['prepared'];dest.parent.mkdir(parents=True,exist_ok=True);data=source.read_bytes()
        if row['path'].endswith('/Editor/CurrentPlayerBuild.cs'):
            text=data.decode('utf-8').replace(old,new)
            receipt=(P/'cube-setup-receipt.json').as_posix();assert text.count(receipt)==1
            text=text.replace(receipt,(C/'cube-setup-receipt.json').as_posix());data=text.encode('utf-8');changed.append(row['path'])
        dest.write_bytes(data);row['sha256']=sha(dest)
        if row['original']:(OUT/row['original']).write_bytes((P/'instrumentation'/row['original']).read_bytes())
    assert changed==['Assets/ComparisonHarness/Editor/CurrentPlayerBuild.cs']
    for row in m['excluded']:(OUT/row['original']).write_bytes((P/'instrumentation'/row['original']).read_bytes())
    for row in state['files']:
        if row['backup']:(C/row['backup']).write_bytes((P/row['backup']).read_bytes())
    save(C/'asset-state.json',state)
    m['correction']=dict(originalManifestSha256=sha(P/'instrumentation/manifest.json'),functionalChange='OnlyExistingAssets in collision guard',routingChange='new Cube receipt directory',runtimeBytesUnchanged=True)
    save(OUT/'manifest.json',m);(OUT/'correct69.executed.py.txt').write_bytes(Path(__file__).read_bytes())
    (C/'CurrentReleaseCubeSetup.cs.txt').write_bytes((P/'CurrentReleaseCubeSetup.cs.txt').read_bytes())
    print('Original inputs freshly verified; unique correction staged; runtime/check bytes unchanged')

def launcher():
    assert load(C/'build-report.json')['result']=='Succeeded' and not (BUILD/'Start-LocalRelease.cmd').exists()
    for name in ['Start-LocalRelease.cmd','LocalRelease-README.txt']:(BUILD/name).write_bytes((ROOT/'LocalComparison/Harness'/name).read_bytes())

def analyze(action):
    m=module('correction69analysis',P/'analyze69.py');m.P=C;m.base.PACKAGE=C;m.base.BUILD=BUILD;m.m=m.base.reuse();m.load=m.m.load
    raise SystemExit(m.main(action))

if __name__=='__main__':
    action=sys.argv[1];assert action in ['prepare','install','restore','launcher','build','products','run']
    if action in ['install','restore']:getattr(base,action)()
    elif action in ['build','products','run']:analyze(action)
    else:globals()[action]()
