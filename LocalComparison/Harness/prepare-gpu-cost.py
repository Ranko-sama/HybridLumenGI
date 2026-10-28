"""One fixed-work Player wiring, reusing the existing reversible build installer."""
import argparse,hashlib,json,subprocess,importlib.util
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];PROJECT=Path('I:/Unity test/Project')
PACKAGE=ROOT/'LocalComparison/Review/gpu-cost-baseline-01';OUT=PACKAGE/'instrumentation';H=ROOT/'LocalComparison/Harness'
spec=importlib.util.spec_from_file_location('installer',H/'prepare-player-smoke.py');installer=importlib.util.module_from_spec(spec);spec.loader.exec_module(installer)
installer.PACKAGE=PACKAGE;installer.OUT=OUT
sha=installer.sha
def save(p,v):p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes((json.dumps(v,indent=2)+'\n').encode('utf-8'))
def prepare():
    assert not (OUT/'manifest.json').exists(),'Preparation already frozen'
    old=json.loads((ROOT/'LocalComparison/Review/current-player-shutdown-01/instrumentation/manifest.json').read_text(encoding='utf-8-sig'))
    for rel,digest in old['productSourceSha256'].items():assert sha(PROJECT/'Assets/HybridLumenGI'/rel)==digest,'Unexpected deployed change: '+rel
    # Deploy only the two reviewed source changes; keep the old bytes as evidence.
    for rel in ['Runtime/HybridLumenGINativeGpuTiming.cs','Runtime/HybridLumenGIRendererFeature.cs']:
        p=PROJECT/'Assets/HybridLumenGI'/rel;backup=PACKAGE/'deployment-before'/rel;backup.parent.mkdir(parents=True,exist_ok=True);backup.write_bytes(p.read_bytes());p.write_bytes((ROOT/rel).read_bytes())
    product={p.relative_to(ROOT).as_posix():sha(p) for top in ['Runtime','Editor'] for p in (ROOT/top).rglob('*') if p.is_file() and p.suffix!='.meta'}
    assert all(sha(PROJECT/'Assets/HybridLumenGI'/p)==v for p,v in product.items())
    native=json.loads((ROOT/'Tests/native-gpu-timing-validation-results.json').read_text(encoding='utf-8-sig'))
    source=native['build']['sourceHashes']
    for row in source:
        p=ROOT/row['file'];assert sha(p).lower()==row['sha256'].lower(),str(p)
    dll=Path(native['buildDirectory'])/'Release/HybridLumenGIGpuTiming.dll'
    assert sha(dll)=='4d94afc2769208cd1da72ec7cda0f29b31fc42dd71febd86a3b9238b391d6431'
    installed=PROJECT/'Assets/Plugins/x86_64/HybridLumenGIGpuTiming.dll'
    assert not installed.exists(),'Do not replace an installed native plugin'
    installed.parent.mkdir(parents=True,exist_ok=True);installed.write_bytes(dll.read_bytes())
    archive=PACKAGE/'native/HybridLumenGIGpuTiming.dll';archive.parent.mkdir(parents=True,exist_ok=True);archive.write_bytes(dll.read_bytes())
    save(PACKAGE/'native/provenance.json',{'sourceHashes':source,'dllSource':str(dll),'dllSha256':sha(dll),'installed':str(installed),'priorReport':'Tests/native-gpu-timing-validation-results.json','reuseNoNativeRebuild':True})
    changed={}
    entry=PROJECT/'Assets/ComparisonHarness/RuntimeAuditEntry.cs';text=entry.read_text(encoding='utf-8')
    text=installer.replace(text,'        var capture=UnityEngine.Object.FindFirstObjectByType<ComparisonCapture>();',
        '        var capture=UnityEngine.Object.FindFirstObjectByType<ComparisonCapture>();\n        if(Array.IndexOf(Environment.GetCommandLineArgs(),"-gpuCost")>=0){GpuCostBaseline.Configure(capture);return;}')
    changed[entry]=text.encode('utf-8')
    changed[PROJECT/'Assets/ComparisonHarness/GpuCostBaseline.cs']=(H/'GpuCostBaseline.cs').read_bytes()
    builder=(H/'CurrentPlayerBuild.cs').read_text(encoding='utf-8').replace('public static class CurrentPlayerBuild','public static class GpuCostPlayerBuild')
    builder=installer.replace(builder,'        EditorSceneManager.OpenScene(ScenePath,OpenSceneMode.Single);','''        const string pluginPath="Assets/Plugins/x86_64/HybridLumenGIGpuTiming.dll";
        var importer=AssetImporter.GetAtPath(pluginPath) as PluginImporter;
        if(importer==null)throw new Exception("Native plugin importer missing");
        importer.SetCompatibleWithAnyPlatform(false);importer.SetCompatibleWithEditor(true);
        importer.SetEditorData("CPU","x86_64");importer.SetEditorData("OS","Windows");
        importer.SetCompatibleWithPlatform(BuildTarget.StandaloneWindows,false);
        importer.SetCompatibleWithPlatform(BuildTarget.StandaloneWindows64,true);
        importer.SetPlatformData(BuildTarget.StandaloneWindows64,"CPU","x86_64");importer.SaveAndReimport();
        if(importer.GetCompatibleWithAnyPlatform()||!importer.GetCompatibleWithEditor()||!importer.GetCompatibleWithPlatform(BuildTarget.StandaloneWindows64)||
            importer.GetCompatibleWithPlatform(BuildTarget.StandaloneWindows)||importer.GetEditorData("OS")!="Windows"||importer.GetEditorData("CPU")!="x86_64")
            throw new Exception("Native plugin platform settings mismatch");
        EditorSceneManager.OpenScene(ScenePath,OpenSceneMode.Single);''')
    builder=installer.replace(builder,'            .Concat(Directory.GetFiles("Assets/ComparisonHarness","*",SearchOption.AllDirectories))',
        '            .Concat(Directory.GetFiles("Assets/ComparisonHarness","*",SearchOption.AllDirectories))\n            .Concat(Directory.GetFiles("Assets/Plugins","*",SearchOption.AllDirectories))')
    changed[PROJECT/'Assets/ComparisonHarness/Editor/GpuCostPlayerBuild.cs']=builder.encode('utf-8')
    m={'baseline':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'productSourceSha256':product,
       'scene':'Assets/RuntimeAudit/Functional.unity','scope':'one fixed-work NativeDX12 cost build and run','files':[],'newMetadata':[]}
    OUT.mkdir(parents=True,exist_ok=True)
    for i,(p,data) in enumerate(changed.items()):
        rel=p.relative_to(PROJECT).as_posix();previous=p.read_bytes() if p.exists() else None
        if previous is not None:(OUT/f'{i}.original').write_bytes(previous)
        dest=OUT/'prepared'/rel;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(data)
        m['files'].append({'path':rel,'original':f'{i}.original' if previous is not None else None,'originalSha256':hashlib.sha256(previous).hexdigest() if previous is not None else None,'prepared':'prepared/'+rel,'sha256':hashlib.sha256(data).hexdigest()})
        if not Path(str(p)+'.meta').exists():m['newMetadata'].append(rel+'.meta')
    save(OUT/'manifest.json',m)
    for name in ['prepare-gpu-cost.py','prepare-player-smoke.py','CurrentPlayerBuild.cs','GpuCostBaseline.cs']:
        dest=PACKAGE/'executed-harness'/(name+'.txt');dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes((H/name).read_bytes())
    print(json.dumps({'productSources':len(product),'wiringFiles':len(changed),'nativeDllSha256':sha(dll)}))
if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('action',choices=['prepare','install','restore']);a=parser.parse_args()
    if a.action=='prepare':prepare()
    else:getattr(installer,a.action)()
