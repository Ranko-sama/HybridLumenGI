"""One fixed environment batch; reuse checked installation/restoration, no retries."""
import argparse, hashlib, importlib.util, json, re, subprocess, traceback
from pathlib import Path
PACKAGE=Path(__file__).resolve().parent; ROOT=PACKAGE.parents[2]; H=ROOT/'LocalComparison/Harness'; OUT=PACKAGE/'instrumentation'
PROJECT=Path('I:/Unity test/Project'); EDITOR=Path('I:/Unity test/Editor/6000.0.85f1/Editor/Data')
spec=importlib.util.spec_from_file_location('base',H/'prepare-player-smoke.py');base=importlib.util.module_from_spec(spec);spec.loader.exec_module(base)
base.PACKAGE=PACKAGE;base.OUT=OUT;sha=base.sha

def extract(text,pattern,structure=False):
    matches=list(re.finditer(pattern,text,re.M));assert len(matches)==1,(pattern,len(matches))
    start=matches[0].start();opening=text.index('{',start);depth=0
    for end in range(opening,len(text)):
        if text[end]=='{':depth+=1
        elif text[end]=='}':
            depth-=1
            if depth==0:return text[start:end+1]+(';' if structure else '')
    raise AssertionError(pattern)

def prepare():
    assert not OUT.exists(),'Preparation already frozen'
    prior=json.loads((ROOT/'LocalComparison/Review/local-light-move-response-01/instrumentation/manifest.json').read_text())
    product=prior['productSourceSha256'];assert len(product)==112
    assert all(sha(PROJECT/'Assets/HybridLumenGI'/p)==v for p,v in product.items()),'Deployed source changed'
    frozen=json.loads((PACKAGE/'baseline.json').read_text())
    assert subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()==frozen['head']
    assert all(sha(PACKAGE/'baseline'/p)==v for p,v in frozen['files'].items())
    shader=ROOT/'Runtime/Resources/HybridLumenGI';old=PACKAGE/'baseline/Runtime/Resources/HybridLumenGI'
    t=(shader/'HybridLumenGITransport.hlsl').read_text();k=(shader/'HybridLumenGIKernels.hlsl').read_text();s=(shader/'HybridLumenGISurfaceCache.hlsl').read_text()
    fn=lambda source,name:extract(source,r'^(?:bool|void|uint|float|float3) '+name+r'\(')
    structs=[extract(t,r'^struct '+n+r'\b',True) for n in ['HLGIProxy','HLGICacheEntry']]+[extract(s,r'^struct HLGISurfaceSample\b',True)]
    env=t[t.index('float4 _HLGI_Environment;'):t.index('#include "HybridLumenGILightingPolicy.hlsl"')]
    sampling=[fn(t,n) for n in ['HLGIHash','Random','CosineHemisphere','HLGISampleDirection']]
    functions=[fn(t,'HLGIHitOwnerCurrent'),extract(t,r'^float3 ProxyRadiance\(HLGIHit hit,float3 incomingDirection,HLGIRayFootprint hitFootprint,float emissionWeight,'),fn(t,'HLGIAreaMatchedDirectionWeight'),fn(k,'LuminanceGI'),fn(k,'LimitRadiance')]
    provenance=[]
    for name,filename,source,threads in [('CSUpdateCache','HybridLumenGITransport.hlsl',t,'64,1,1'),('CSTrace','HybridLumenGIKernels.hlsl',k,'8,8,1')]:
        legacy=fn((old/filename).read_text(),name);candidate=fn(source,name)
        functions+=['[numthreads('+threads+')]\n'+legacy.replace('void '+name+'(','void '+name+'Legacy(',1),'[numthreads('+threads+')]\n'+candidate]
        provenance.append({'function':name,'legacy':hashlib.sha256(legacy.encode()).hexdigest(),'candidate':hashlib.sha256(candidate.encode()).hexdigest(),'onlyAdapter':'Legacy entry name; original bodies unchanged'})
    generated={'EnvironmentStructures.hlsl':'\n\n'.join(structs),'EnvironmentSource.hlsl':env,'EnvironmentSampling.hlsl':'\n\n'.join(sampling),'EnvironmentActualConsumers.hlsl':'\n\n'.join(functions)}
    feature=(ROOT/'Runtime/HybridLumenGIRendererFeature.cs').read_text()
    block=feature[feature.index('                string serializedSettings=JsonUtility.ToJson(s);'):feature.index('                state.PrepareGpuBudget(s,serializedSettings,Time.frameCount);')]
    settings='''using System;
using System.IO;
using HybridLumenGI;
using UnityEngine;
public static class EnvironmentSettingsActual
{
    sealed class Scene { public int calls;public void InvalidateReadiness(){calls++;} }
    sealed class Readiness { public int calls;public void Invalidate(){calls++;} }
    sealed class State { public int lastSettingsHash,epoch=1,history;public Scene scene=new Scene();public Readiness readiness=new Readiness();public void InvalidateScreenHistory(){history++;} }
    [Serializable] sealed class Row {public string label,serialized;public int hash,epoch,history,scene,readiness;}
    [Serializable] sealed class Receipt {public Row[] rows;public bool passed;}
    static void Actual(HybridLumenGIRendererFeature.Settings s,State state)
    {
ACTUAL_BLOCK
    }
    public static bool Check(Cubemap a,Cubemap b,string folder)
    {
        var s=new HybridLumenGIRendererFeature.Settings();var state=new State();var rows=new Row[5];
        var sources=new Cubemap[]{null,a,a,b,null};var labels=new[]{"null","A","same-A","B","clear"};var counts=new[]{1,2,2,3,4};bool passed=true;
        for(int i=0;i<sources.Length;i++)
        {
            s.environmentCubemap=sources[i];string serialized=JsonUtility.ToJson(s);
            if(i==0)state.lastSettingsHash=serialized.GetHashCode()^1;
            Actual(s,state);rows[i]=new Row{label=labels[i],serialized=serialized,hash=serialized.GetHashCode(),epoch=state.epoch,history=state.history,scene=state.scene.calls,readiness=state.readiness.calls};
            passed &= state.epoch==counts[i]+1 && state.history==counts[i] && state.scene.calls==counts[i] && state.readiness.calls==counts[i];
        }
        passed &= rows[0].serialized==rows[4].serialized && rows[1].serialized==rows[2].serialized && rows[0].serialized!=rows[1].serialized && rows[1].serialized!=rows[3].serialized && rows[3].serialized!=rows[4].serialized;
        File.WriteAllText(Path.Combine(folder,"settings.json"),JsonUtility.ToJson(new Receipt{rows=rows,passed=passed},true));return passed;
    }
}
'''.replace('ACTUAL_BLOCK',block)
    files=[];metadata=[]
    def stage(rel,data):
        path=PROJECT/rel;original=None
        if path.exists():
            original='original/'+rel;backup=OUT/original;backup.parent.mkdir(parents=True,exist_ok=True);backup.write_bytes(path.read_bytes())
        target=OUT/'prepared'/rel;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(data)
        files.append({'path':rel,'original':original,'originalSha256':sha(path) if path.exists() else None,'prepared':'prepared/'+rel,'sha256':sha(target)})
        if not Path(str(path)+'.meta').exists():metadata.append(rel+'.meta')
    for rel in frozen['files']:
        if rel.startswith('Runtime/'):stage('Assets/HybridLumenGI/'+rel,(ROOT/rel).read_bytes())
    for name,source in generated.items():stage('Assets/ComparisonHarness/Resources/'+name,(source+'\n').encode())
    stage('Assets/ComparisonHarness/Resources/StaticEnvironmentCube.compute',(H/'StaticEnvironmentCube.compute').read_bytes())
    stage('Assets/ComparisonHarness/Editor/StaticEnvironmentCubeEditor.cs',(H/'StaticEnvironmentCubeEditor.cs').read_bytes())
    stage('Assets/ComparisonHarness/Editor/EnvironmentSettingsActual.cs',settings.encode())
    candidate={p:sha(ROOT/p) for p in product}
    assert {p for p in product if product[p]!=candidate[p]}=={p for p in frozen['files'] if p.startswith('Runtime/')}
    settings_paths=[p for basepath in [PROJECT/'Assets/Comparison',PROJECT/'ProjectSettings',PROJECT/'Packages'] if basepath.exists() for p in basepath.rglob('*') if p.is_file()]
    m={'baseline':frozen['head'],'deployedProductCommit':'7190c28a38c7ab33713d4027537da8ef13f8763e','productSourceSha256':product,'candidateProductSourceSha256':candidate,'files':files,'newMetadata':metadata,'functionProvenance':provenance,'sceneSettingsBefore':{p.relative_to(PROJECT).as_posix():sha(p) for p in settings_paths}}
    (OUT/'manifest.json').write_text(json.dumps(m,indent=2))
    (PACKAGE/'contract.before-execution.md').write_bytes((ROOT/'Documentation/Checkpoint-Iteration63.md').read_bytes())
    (PACKAGE/'stager.executed.py.txt').write_bytes(Path(__file__).read_bytes());(PACKAGE/'base-stager.executed.py.txt').write_bytes((H/'prepare-player-smoke.py').read_bytes())
    (PACKAGE/'runner.executed.ps1.txt').write_bytes((PACKAGE/'run.ps1').read_bytes())
    print(json.dumps({'stagedFiles':len(files),'productFiles':len(product),'settingsFiles':len(settings_paths),'scope':'one native batch, actual functions and real Cube; explicit geometry adapters'}))

def preflight():
    dest=PACKAGE/'preflight';assert not dest.exists(),'One managed preflight only';dest.mkdir()
    m=json.loads((OUT/'manifest.json').read_text());results=[]
    for assembly in ['Assembly-CSharp','Assembly-CSharp-Editor']:
        is_editor=assembly.endswith('Editor');replacements={f['path']:OUT/f['prepared'] for f in m['files'] if f['path'].endswith('.cs') and ('/Editor/' in f['path'])==is_editor}
        original=(PROJECT/('Library/Bee/artifacts/1900b0aE.dag/'+assembly+'.rsp')).read_text(encoding='utf-8-sig');lines=[];removed=[];used=set()
        for line in original.splitlines():
            path=line.strip('"')
            if path.endswith('.cs'):
                if path in replacements:line='"'+replacements[path].as_posix()+'"';used.add(path)
                elif not (PROJECT/path).exists():removed.append(path);continue
            if line.startswith('-out:'):line='-out:"'+(dest/(assembly+'.dll')).as_posix()+'"'
            elif line.startswith('-refout:'):line='-refout:"'+(dest/(assembly+'.ref.dll')).as_posix()+'"'
            elif is_editor and line.startswith('-r:') and line.rstrip('"').endswith(('/Assembly-CSharp.dll','/Assembly-CSharp.ref.dll')):line='-r:"'+(dest/'Assembly-CSharp.dll').as_posix()+'"'
            lines.append(line)
        lines+=['"'+p.as_posix()+'"' for rel,p in replacements.items() if rel not in used]
        assert not any('/generatedfilesout:' in x or '-pdb:' in x or '/errorlog:' in x for x in lines)
        rsp=dest/(assembly+'.rsp');rsp.write_text('\n'.join(lines)+'\n',encoding='utf-8')
        p=subprocess.run([str(EDITOR/'NetCoreRuntime/dotnet.exe'),str(EDITOR/'DotNetSdkRoslyn/csc.dll'),'@'+str(rsp)],cwd=PROJECT,capture_output=True)
        log=p.stdout+p.stderr;(dest/(assembly+'.log')).write_bytes(log);results.append({'assembly':assembly,'exitCode':p.returncode,'removedPreviousOverlays':removed});print(log.decode('utf-8',errors='replace'))
        if p.returncode:break
    (dest/'exit.json').write_text(json.dumps({'exitCode':results[-1]['exitCode'],'assemblies':results},indent=2));raise SystemExit(results[-1]['exitCode'])

def analyze():
    out=PACKAGE/'native-editor';report={'status':'failed','fullFeatureExecution':False,'fullProductionAccepted':False}
    try:
        m=json.loads((OUT/'manifest.json').read_text());restore=json.loads((OUT/'restoration.json').read_text());end=json.loads((out/'exit.json').read_text(encoding='utf-8-sig'))
        assert end['exitCode']==0,'Native Editor failed'
        spec=importlib.util.spec_from_file_location('check',H/'native_log_check.py');check=importlib.util.module_from_spec(spec);spec.loader.exec_module(check)
        report['nativeLogHits']=check.scan(out/'unity.log');assert not report['nativeLogHits'],'Native log failure'
        r=json.loads((out/'run/result.json').read_text());report['runtime']=r
        assert r['status']=='finite-directional-environment-established' and r['cases']==12 and r['dispatches']==48 and r['pending']==0 and r['cleanupCompleted'] and r['formatContract'] and r['settingsInvalidation']
        assert len(r['rows'])==48 and len(r['compiledEntries'])==6
        for row in r['rows']:
            p=out/'run'/row['file'];assert p.stat().st_size==row['bytes'] and sha(p)==row['sha256']
        assert restore['currentProductRestored'] and all(f['restored'] for f in restore['files'])
        assert all(sha(PROJECT/'Assets/HybridLumenGI'/p)==v for p,v in m['productSourceSha256'].items())
        assert all(sha(ROOT/p)==v for p,v in m['candidateProductSourceSha256'].items())
        assert all(sha(PROJECT/p)==v for p,v in m['sceneSettingsBefore'].items())
        assert all(sha(OUT/f['prepared'])==f['sha256'] for f in m['files'])
        report.update(status=r['status'],restored=True,sourceQualified=True,sceneSettingsUnchanged=True)
    except Exception as e:report.update(failure=str(e),traceback=traceback.format_exc())
    assert not (out/'analysis.json').exists(),'Preserve first analysis';(out/'analysis.json').write_text(json.dumps(report,indent=2));print(json.dumps({k:v for k,v in report.items() if k!='runtime'},indent=2));return report['status']!='failed'

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('action',choices=['prepare','preflight','install','restore','analyze']);a=p.parse_args()
    if a.action in ['install','restore']:getattr(base,a.action)()
    elif a.action=='analyze':raise SystemExit(0 if analyze() else 1)
    else:globals()[a.action]()
