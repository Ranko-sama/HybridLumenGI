"""67-only routing and asset ownership around the existing Release installer."""
import hashlib, importlib.util, json, subprocess, sys
from pathlib import Path
P=Path(__file__).resolve().parent
ROOT=P.parents[2]; H=ROOT/'LocalComparison/Harness'
PROJECT=Path('I:/Unity test/Project'); OUT=P/'instrumentation'
BUILD=Path('I:/Unity test/Comparison/Builds/LocalRelease67')
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
load=lambda p:json.loads(p.read_text(encoding='utf-8-sig'))
def save(p,v):p.write_text(json.dumps(v,indent=2)+'\n',encoding='utf-8')
spec=importlib.util.spec_from_file_location('release67base',H/'prepare-local-release.py')
base=importlib.util.module_from_spec(spec);spec.loader.exec_module(base)
base.PACKAGE=P;base.OUT=OUT;base.base.PACKAGE=P;base.base.OUT=OUT
replace=base.replace

def deploy():
    dest=P/'deployment';assert not dest.exists(),'Preserve unique deployment backup'
    prior=load(ROOT/'LocalComparison/Review/local-light-move-response-01/instrumentation/manifest.json')['productSourceSha256']
    product={p.relative_to(ROOT).as_posix():sha(p) for top in ['Runtime','Editor'] for p in (ROOT/top).rglob('*') if p.is_file() and p.suffix!='.meta'}
    assert set(product)==set(prior)
    assert all(sha(PROJECT/'Assets/HybridLumenGI'/p)==v for p,v in prior.items()),'Deployment differs from known7190c28'
    changes=[p for p in product if product[p]!=prior[p]]
    assert set(changes)=={'Runtime/HybridLumenGIRendererFeature.cs','Runtime/Resources/HybridLumenGI/HybridLumenGIKernels.hlsl','Runtime/Resources/HybridLumenGI/HybridLumenGISurface.shader','Runtime/Resources/HybridLumenGI/HybridLumenGITransport.hlsl'}
    dest.mkdir()
    for rel in changes:
        old=dest/'original'/rel;old.parent.mkdir(parents=True,exist_ok=True)
        target=PROJECT/'Assets/HybridLumenGI'/rel;old.write_bytes(target.read_bytes())
    save(dest/'manifest.json',dict(previous='7190c28a38c7ab33713d4027537da8ef13f8763e',current=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),before=prior,after=product,changed=changes))
    for rel in changes:(PROJECT/'Assets/HybridLumenGI'/rel).write_bytes((ROOT/rel).read_bytes())
    assert all(sha(PROJECT/'Assets/HybridLumenGI'/p)==v for p,v in product.items())
    print(json.dumps(dict(currentFiles=len(product),updated=changes)))

def prepare():
    base.prepare();m=load(OUT/'manifest.json')
    for row in m['files']:
        path=OUT/row['prepared'];text=path.read_text(encoding='utf-8')
        if row['path'].endswith('/Editor/CurrentPlayerBuild.cs'):
            fragment=(P/'CurrentReleaseCubeSetup.cs.txt').read_text(encoding='utf-8')
            text=replace(text,'    const string ScenePath=',fragment+'\n    const string ScenePath=')
            call='        SetupCurrentRelease67Cube(capture,@"'+(P/'cube-setup-receipt.json').as_posix()+'");\n'
            text=replace(text,'        var projectSettings=',call+'        var projectSettings=')
        elif row['path'].endswith('/LocalReleaseBootstrap.cs'):
            text=replace(text,'        public bool finalImageMode,', '''        public bool environmentCubePresent,environmentCubeSupported,environmentCubeLinear;
        public string environmentCubeName,environmentCubeFormat,environmentCubeGraphicsFormat,environmentCubeFilterMode,environmentCubeWrapMode;
        public int environmentCubeInstanceId,environmentCubeWidth,environmentCubeHeight,environmentCubeMipCount;
        public bool finalImageMode,''')
            text=replace(text,'            Require(result.actualViewMode=="Final",', '''            var cube=((HybridLumenGIRendererFeature.Settings)settings).environmentCubemap;
            result.environmentCubePresent=cube!=null;
            result.environmentCubeSupported=HybridLumenGIRendererFeature.IsSupportedEnvironmentCubemap(cube);
            if(cube!=null)
            {
                result.environmentCubeName=cube.name;result.environmentCubeInstanceId=cube.GetInstanceID();
                result.environmentCubeFormat=cube.format.ToString();result.environmentCubeGraphicsFormat=cube.graphicsFormat.ToString();
                result.environmentCubeLinear=!UnityEngine.Experimental.Rendering.GraphicsFormatUtility.IsSRGBFormat(cube.graphicsFormat);
                result.environmentCubeWidth=cube.width;result.environmentCubeHeight=cube.height;result.environmentCubeMipCount=cube.mipmapCount;
                result.environmentCubeFilterMode=cube.filterMode.ToString();result.environmentCubeWrapMode=cube.wrapMode.ToString();
            }
            Save();
            Require(result.environmentCubePresent&&result.environmentCubeSupported&&result.environmentCubeLinear&&
                result.environmentCubeName=="CurrentRelease67Environment"&&result.environmentCubeFormat=="RGBAFloat"&&
                result.environmentCubeWidth==2&&result.environmentCubeHeight==2&&result.environmentCubeMipCount==1&&
                result.environmentCubeFilterMode=="Bilinear"&&result.environmentCubeWrapMode=="Clamp","Frozen Release67 environment asset missing or invalid");
            Require(result.actualViewMode=="Final",''')
        else:continue
        path.write_text(text,encoding='utf-8');row['sha256']=sha(path)
    m['scope']='Current2fefc09 ordinary Release and one FinalHDR; existing63 staticCube asset; no product edits or GPU probes'
    save(OUT/'manifest.json',m)
    assets=['Assets/Comparison/Renderer.asset','Assets/Comparison/Renderer.asset.meta','Assets/Comparison/CurrentRelease67Environment.asset','Assets/Comparison/CurrentRelease67Environment.asset.meta']
    rows=[]
    for i,rel in enumerate(assets):
        path=PROJECT/rel;exists=path.exists();assert exists==(i<2)
        backup='asset-original-'+str(i)
        if exists:(P/backup).write_bytes(path.read_bytes())
        rows.append(dict(path=rel,existsBefore=exists,sha256Before=sha(path) if exists else None,backup=backup if exists else None))
    save(P/'asset-state.json',dict(files=rows))
    print('67 staged existing Release wiring plus build-time Cube setup and one CPU configuration receipt')

def install():
    state=load(P/'asset-state.json')
    for row in state['files']:
        path=PROJECT/row['path'];assert path.exists()==row['existsBefore']
        if path.exists():assert sha(path)==row['sha256Before']
    base.install()

def restore():
    # Copy evidence, then restore only the four explicitly owned inputs.
    state=load(P/'asset-state.json');rows=[]
    for row in state['files']:
        path=(PROJECT/row['path']).resolve();assert path.is_relative_to((PROJECT/'Assets/Comparison').resolve()) and not path.is_dir()
        if path.exists():
            archive=P/'built-assets'/Path(row['path']).name;archive.parent.mkdir(exist_ok=True);archive.write_bytes(path.read_bytes())
        if row['existsBefore']:
            backup=P/row['backup'];assert sha(backup)==row['sha256Before'];path.write_bytes(backup.read_bytes())
        elif path.exists():path.unlink()
        rows.append(dict(path=row['path'],restored=path.exists()==row['existsBefore'] and (not path.exists() or sha(path)==row['sha256Before'])))
    save(P/'asset-restoration.json',dict(allRestored=all(r['restored'] for r in rows),files=rows))
    base.restore();assert all(r['restored'] for r in rows)

def launcher():
    assert load(P/'build-report.json')['result']=='Succeeded'
    assert not (BUILD/'Start-LocalRelease.cmd').exists()
    (BUILD/'Start-LocalRelease.cmd').write_bytes((H/'Start-LocalRelease.cmd').read_bytes())
    text=(H/'LocalRelease-README.txt').read_text(encoding='utf-8')
    text=text.replace('源码与构建收据、产物清单及本次有限交互结果位于仓库 LocalComparison/Review/local-release-navigation-01。',
        '当前产品源码：2fefc09。构建、实际Feature静态HDR Cube配置和单张Final HDR收据位于仓库 LocalComparison/Review/current-local-release-67。\n本轮实测同EXE的有限HDR分支；导航代码沿用58，本轮未重复键盘交互验收。\n环境为63固定六面RGBAFloat工程演示输入，非目标天空或物理参考；不按画面调整亮度。')
    (BUILD/'LocalRelease-README.txt').write_text(text,encoding='utf-8')
    print('67 launcher installed; default persistent navigation, no finite flags')

if __name__=='__main__':
    assert sys.argv[1] in ['deploy','prepare','install','restore','launcher']
    globals()[sys.argv[1]]()
