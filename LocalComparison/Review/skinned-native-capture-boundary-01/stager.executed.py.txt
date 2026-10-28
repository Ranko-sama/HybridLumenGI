"""Reuse existing checked Editor staging/restoration; one dependency-only native batch."""
import argparse,hashlib,importlib.util,json,subprocess,traceback
from pathlib import Path
PACKAGE=Path(__file__).resolve().parent;ROOT=PACKAGE.parents[2];H=ROOT/'LocalComparison/Harness';OUT=PACKAGE/'instrumentation'
PROJECT=Path('I:/Unity test/Project');EDITOR=Path('I:/Unity test/Editor/6000.0.85f1/Editor/Data')
spec=importlib.util.spec_from_file_location('base',H/'prepare-player-smoke.py');base=importlib.util.module_from_spec(spec);spec.loader.exec_module(base)
base.PACKAGE=PACKAGE;base.OUT=OUT;sha=base.sha

def prepare():
    assert not OUT.exists(),'Unique preparation already exists'
    prior=json.loads((ROOT/'LocalComparison/Review/local-release-steady-use-01/instrumentation/manifest.json').read_text())
    product=prior['productSourceSha256'];assert all(sha(PROJECT/'Assets/HybridLumenGI'/p)==v for p,v in product.items())
    fingerprint='Runtime/HybridLumenGISurfaceCharts.cs';assert sha(ROOT/fingerprint)==product[fingerprint]
    rel='Assets/ComparisonHarness/Editor/SkinnedNativeCaptureBoundary.cs';path=PROJECT/rel;assert not path.exists(),'Do not replace an existing Editor script'
    data=(H/'SkinnedNativeCaptureBoundary.cs').read_bytes();target=OUT/'prepared'/rel;target.parent.mkdir(parents=True);target.write_bytes(data)
    m={'baseline':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'deployedProductCommit':'5120a8c7022b90d2ad954498e8b5dcd08d8bdb35',
       'productSourceSha256':product,'fingerprintSourceSha256':product[fingerprint],'scope':'one Editor batch, three native BakeMesh dependency captures; candidate component not deployed/executed',
       'files':[{'path':rel,'original':None,'originalSha256':None,'prepared':'prepared/'+rel,'sha256':hashlib.sha256(data).hexdigest()}],
       'newMetadata':[] if Path(str(path)+'.meta').exists() else [rel+'.meta']}
    d=json.loads((ROOT/'LocalComparison/Review/local-release-steady-use-01/deployment.json').read_text());m['sceneSettingsBefore']={p:sha(PROJECT/p) for p in d['unchangedSceneSettings']}
    (OUT/'manifest.json').write_text(json.dumps(m,indent=2));(PACKAGE/'contract.before-execution.md').write_bytes((ROOT/'Documentation/Checkpoint-Iteration46.md').read_bytes())
    (PACKAGE/'fingerprint-source.cs.txt').write_bytes((ROOT/fingerprint).read_bytes());(PACKAGE/'stager.executed.py.txt').write_bytes(Path(__file__).read_bytes())
    (PACKAGE/'base-stager.executed.py.txt').write_bytes((H/'prepare-player-smoke.py').read_bytes());print('Staged one new Editor script;112 old deployed product files retained; actual fingerprint dependency matches candidate.')

def preflight():
    dest=PACKAGE/'preflight';assert not dest.exists(),'One managed preflight only';dest.mkdir()
    m=json.loads((OUT/'manifest.json').read_text());f=m['files'][0]
    original=(PROJECT/'Library/Bee/artifacts/1900b0aE.dag/Assembly-CSharp-Editor.rsp').read_text(encoding='utf-8-sig');lines=[];removed=[]
    for line in original.splitlines():
        if line.strip('"').endswith('.cs') and not (PROJECT/line.strip('"')).exists():removed.append(line.strip('"'));continue
        if line.startswith('-out:'):line='-out:"'+(dest/'Assembly-CSharp-Editor.dll').as_posix()+'"'
        elif line.startswith('-refout:'):line='-refout:"'+(dest/'Assembly-CSharp-Editor.ref.dll').as_posix()+'"'
        lines.append(line)
    lines.append('"'+(OUT/f['prepared']).as_posix()+'"');assert not any('/generatedfilesout:' in x or '-pdb:' in x or '/errorlog:' in x for x in lines)
    rsp=dest/'prospective.rsp';rsp.write_text('\n'.join(lines)+'\n',encoding='utf-8');(dest/'removed-previous-overlays.json').write_text(json.dumps(removed,indent=2))
    p=subprocess.run([str(EDITOR/'NetCoreRuntime/dotnet.exe'),str(EDITOR/'DotNetSdkRoslyn/csc.dll'),'@'+str(rsp)],cwd=PROJECT,capture_output=True)
    (dest/'managed.log').write_bytes(p.stdout+p.stderr);(dest/'exit.json').write_text(json.dumps({'exitCode':p.returncode}));print((p.stdout+p.stderr).decode('utf-8',errors='replace'));raise SystemExit(p.returncode)

def analyze():
    out=PACKAGE/'native-editor';report={'status':'failed','nativeCapturePremiseAccepted':False,'candidateComponentNativeExecution':False,'fullProductionAccepted':False}
    try:
        m=json.loads((OUT/'manifest.json').read_text());restored=json.loads((OUT/'restoration.json').read_text());end=json.loads((out/'exit.json').read_text(encoding='utf-8-sig'))
        report['nativeExit']=end;assert end['exitCode']==0,'Editor process failed'
        spec=importlib.util.spec_from_file_location('check',H/'native_log_check.py');check=importlib.util.module_from_spec(spec);spec.loader.exec_module(check)
        report['nativeLogHits']=check.scan(out/'unity.log');assert not report['nativeLogHits'],'Native log failure'
        r=json.loads((out/'run/native-result.json').read_text());report['runtime']=r
        assert r['status']=='finite-native-capture-premise-established' and r['batchMode'] and r['captures']==3 and r['cleanupCompleted']
        assert r['fingerprintSourceSha256']==m['fingerprintSourceSha256']==sha(ROOT/'Runtime/HybridLumenGISurfaceCharts.cs')
        assert r['sourceFingerprintBefore']==r['sourceFingerprintAfter'] and r['samePoseFingerprintEqual'] and r['changedPoseFingerprintDifferent']
        assert [s['name'] for s in r['samples']]==['A1','A2','B'] and all(s['qualified'] for s in r['samples'])
        for sample in r['samples']:
            for blob in sample['streams']+[sample['index']]:
                p=out/'run'/blob['file'];assert p.stat().st_size==blob['bytes'] and sha(p)==blob['sha256'],'Raw native payload changed'
        assert restored['currentProductRestored'] and all(x['restored'] for x in restored['files'])
        assert all(sha(PROJECT/'Assets/HybridLumenGI'/p)==v for p,v in m['productSourceSha256'].items())
        assert all(sha(PROJECT/p)==v for p,v in m['sceneSettingsBefore'].items())
        report.update(status='finite-native-capture-premise-established',nativeCapturePremiseAccepted=True,restored=True,sceneSettingsUnchanged=True)
    except Exception as e:report.update(failure=str(e),traceback=traceback.format_exc())
    assert not (out/'analysis.json').exists(),'Preserve first analysis';(out/'analysis.json').write_text(json.dumps(report,indent=2))
    print(json.dumps({k:v for k,v in report.items() if k!='runtime'},indent=2));return report['nativeCapturePremiseAccepted']

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('action',choices=['prepare','preflight','install','restore','analyze']);a=p.parse_args()
    if a.action in ['install','restore']:getattr(base,a.action)()
    elif a.action=='analyze':raise SystemExit(0 if analyze() else 1)
    else:globals()[a.action]()
