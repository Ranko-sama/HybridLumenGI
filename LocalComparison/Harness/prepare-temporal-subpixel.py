"""One Editor compute batch, using existing reversible fixture installation."""
import argparse, hashlib, importlib.util, json, subprocess
from pathlib import Path
HERE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('base',HERE/'prepare-player-smoke.py')
base=importlib.util.module_from_spec(spec);spec.loader.exec_module(base)
ROOT=base.ROOT;PROJECT=base.PROJECT
PACKAGE=ROOT/'LocalComparison/Review/temporal-subpixel-history-01'
OUT=PACKAGE/'instrumentation';base.OUT=OUT
KERNEL='Runtime/Resources/HybridLumenGI/HybridLumenGIKernels.hlsl'

def prepare():
    assert not (OUT/'manifest.json').exists(),'Single frozen preparation already exists'
    baseline=PACKAGE/'baseline/HybridLumenGIKernels.hlsl'
    deployed=PROJECT/'Assets/HybridLumenGI'/KERNEL
    assert base.sha(deployed)==base.sha(baseline),'Unexpected deployed kernel'
    deployed.write_bytes((ROOT/KERNEL).read_bytes())
    product={p.relative_to(ROOT).as_posix():base.sha(p) for top in ['Runtime','Editor'] for p in (ROOT/top).rglob('*') if p.is_file() and p.suffix!='.meta'}
    assert all(base.sha(PROJECT/'Assets/HybridLumenGI'/p)==v for p,v in product.items())
    changed={PROJECT/'Assets/ComparisonHarness/Editor'/n:(HERE/n).read_bytes() for n in ['DenoiseRegressionEditor.cs','TemporalSubpixelRegression.cs','DenoiseFixture.compute']}
    directories=[]
    for name,source in [('Baseline',baseline),('Candidate',ROOT/KERNEL)]:
        folder=PROJECT/'Assets/ComparisonHarness/Editor'/('TemporalSubpixel'+name)
        assert not folder.exists();directories.append(folder.relative_to(PROJECT).as_posix())
        changed[folder/'HybridLumenGIKernels.hlsl']=source.read_bytes()
        changed[folder/'Temporal.compute']=b'#pragma kernel CSTemporal\n#pragma kernel CSTemporalIdentity HLGI_RECEIVER_IDENTITY\n#pragma kernel CSFilter\n#pragma target 5.0\n#pragma use_dxc\n#include "HybridLumenGIKernels.hlsl"\n'
        for helper in ['Transport','ScreenGeometry','ScreenSampling','ScreenMaterial','ReceiverTemporal']:
            filename='HybridLumenGI'+helper+'.hlsl'
            changed[folder/filename]=('#include "../../../HybridLumenGI/Runtime/Resources/HybridLumenGI/'+filename+'"\n').encode()
    OUT.mkdir(parents=True)
    manifest={'baseline':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'productSourceSha256':product,'scope':'One actual Editor compute batch, zero Player builds/runs','files':[],'newMetadata':[],'newDirectories':directories}
    for i,(path,data) in enumerate(changed.items()):
        rel=path.relative_to(PROJECT).as_posix();old=path.read_bytes() if path.exists() else None
        if old is not None:(OUT/f'{i}.original').write_bytes(old)
        staged=OUT/'prepared'/rel;staged.parent.mkdir(parents=True,exist_ok=True);staged.write_bytes(data)
        manifest['files'].append({'path':rel,'original':f'{i}.original' if old is not None else None,'originalSha256':hashlib.sha256(old).hexdigest() if old is not None else None,'prepared':'prepared/'+rel,'sha256':hashlib.sha256(data).hexdigest()})
        if not Path(str(path)+'.meta').exists():manifest['newMetadata'].append(rel+'.meta')
    manifest['newMetadata'] += [d+'.meta' for d in directories]
    (OUT/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
    (OUT/'installer.executed.py.txt').write_bytes(Path(__file__).read_bytes())
    print(json.dumps({'preparedFiles':len(changed),'productSources':len(product),'rawKernelBytesPreserved':True}))

def preflight():
    build=PACKAGE/'preflight-current-sources';build.mkdir();m=json.loads((OUT/'manifest.json').read_text())
    sources={f['path']:str(OUT/f['prepared']).replace('\\','/') for f in m['files'] if f['path'].endswith('.cs')}
    choices=list((PROJECT/'Library/Bee/artifacts').glob('*/Assembly-CSharp-Editor.rsp'))
    assert len(choices)==1,choices
    lines=[];seen=set();removed=[]
    for line in choices[0].read_text(encoding='utf-8-sig').splitlines():
        if line.startswith('-out:'):line='-out:"'+str(build/'Assembly-CSharp-Editor.dll').replace('\\','/')+'"'
        elif line.startswith('-refout:'):line='-refout:"'+str(build/'Assembly-CSharp-Editor.ref.dll').replace('\\','/')+'"'
        elif line.strip('"') in sources:
            key=line.strip('"');seen.add(key);line='"'+sources[key]+'"'
        elif line.strip('"').endswith('.cs') and not (PROJECT/line.strip('"')).exists():
            removed.append(line.strip('"'));continue
        lines.append(line)
    for key in sources.keys()-seen:lines.append('"'+sources[key]+'"')
    assert not any('/generatedfilesout:' in l or '-pdb:' in l or '/errorlog:' in l for l in lines)
    rsp=build/'prospective.rsp';rsp.write_text('\n'.join(lines)+'\n',encoding='utf-8')
    editor=Path('I:/Unity test/Editor/6000.0.85f1/Editor/Data')
    command=[str(editor/'NetCoreRuntime/dotnet.exe'),str(editor/'DotNetSdkRoslyn/csc.dll'),'@'+str(rsp)]
    result=subprocess.run(command,cwd=PROJECT,capture_output=True,text=True,encoding='utf-8',errors='replace')
    (build/'compile.log').write_text(result.stdout+result.stderr,encoding='utf-8')
    (build/'result.json').write_text(json.dumps({'command':command,'exitCode':result.returncode,'staleRestoredSourcesExcluded':removed},indent=2),encoding='utf-8')
    print(result.stdout+result.stderr);raise SystemExit(result.returncode)

def restore():
    base.restore()
    m=json.loads((OUT/'manifest.json').read_text())
    for rel in m['newDirectories']:
        path=(PROJECT/rel).resolve();assert path.is_relative_to(PROJECT.resolve())
        if path.exists():path.rmdir()

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('action',choices=['prepare','preflight','install','restore']);args=parser.parse_args()
    (base.install if args.action=='install' else globals()[args.action])()
