"""Freeze one admission/upload Player; reuse existing reversible installation."""
import argparse,hashlib,importlib.util,json,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];H=ROOT/'LocalComparison/Harness'
PROJECT=Path('I:/Unity test/Project');PACKAGE=ROOT/'LocalComparison/Review/world-light-relevance-01';OUT=PACKAGE/'instrumentation'
spec=importlib.util.spec_from_file_location('base',H/'prepare-player-smoke.py');base=importlib.util.module_from_spec(spec);spec.loader.exec_module(base)
base.PACKAGE=PACKAGE;base.OUT=OUT
sha=base.sha;replace=base.replace

def deploy():
    out=PACKAGE/'deployment';assert not (out/'manifest.json').exists(),'Deployment already frozen'
    rows=[]
    for top in ['Runtime','Editor']:
        for p in sorted((ROOT/top).rglob('*')):
            if not p.is_file():continue
            rel=p.relative_to(ROOT);dst=PROJECT/'Assets/HybridLumenGI'/rel
            if dst.exists() and sha(p)==sha(dst):continue
            old=sha(dst) if dst.exists() else None
            if dst.exists():
                backup=out/'before'/rel;backup.parent.mkdir(parents=True,exist_ok=True);backup.write_bytes(dst.read_bytes())
            dst.parent.mkdir(parents=True,exist_ok=True);dst.write_bytes(p.read_bytes())
            rows.append({'path':rel.as_posix(),'before':old,'candidate':sha(p)})
    out.mkdir(parents=True,exist_ok=True);(out/'manifest.json').write_text(json.dumps(rows,indent=2),encoding='utf-8')
    print(json.dumps({'candidateDeploymentFiles':len(rows)}))

def prepare():
    assert not OUT.exists(),'Unique fixture preparation already exists'
    product={p.relative_to(ROOT).as_posix():sha(p) for top in ['Runtime','Editor'] for p in (ROOT/top).rglob('*') if p.is_file() and p.suffix!='.meta'}
    assert all(sha(PROJECT/'Assets/HybridLumenGI'/p)==v for p,v in product.items())
    changed={};entry=PROJECT/'Assets/ComparisonHarness/RuntimeAuditEntry.cs';text=entry.read_text(encoding='utf-8')
    text=replace(text,'        capture.totalFrames=720;','''        if(WorldLightRelevanceMode.Enabled)
        {
            try{WorldLightRelevanceMode.Configure(capture);}
            catch(Exception e){capture.enabled=false;Directory.CreateDirectory(capture.outputRoot);File.WriteAllText(Path.Combine(capture.outputRoot,"preparation-failure.txt"),e.ToString());Debug.LogException(e);Application.Quit(1);}
            return;
        }
        capture.totalFrames=720;''');changed[entry]=text.encode()
    capture=PROJECT/'Assets/ComparisonHarness/ComparisonCapture.cs';text=capture.read_text(encoding='utf-8')
    text=replace(text,'        appliedEngine = Time.frameCount;','''        appliedEngine = Time.frameCount;
        if(WorldLightRelevanceMode.Enabled){WorldLightRelevanceMode.Apply(this,logicalFrame,directory);return;}''')
    text=replace(text,'if (FrameTimingManager.GetLatestTimings(1, timings) != 0)','if (!WorldLightRelevanceMode.Enabled && FrameTimingManager.GetLatestTimings(1, timings) != 0)')
    text=replace(text,'if (CaptureAt(logicalFrame) || logicalFrame == totalFrames - 1) Capture(f);','if (!WorldLightRelevanceMode.Enabled && (CaptureAt(logicalFrame) || logicalFrame == totalFrames - 1)) Capture(f);')
    text=replace(text,'receipt = true; run.renderedFrames++; SaveRun();','receipt = true; run.renderedFrames++; SaveRun();\n            if(WorldLightRelevanceMode.Enabled)WorldLightRelevanceMode.Rendered(logicalFrame);')
    # Only Rendered's catch: final close/readback wait runs at the following Update, outside camera rendering.
    text=replace(text,'        catch (Exception e) { Fail(e.ToString()); Finish(false); }\n    }\n    static bool CaptureAt',
        '        catch (Exception e) { Fail(e.ToString()); if(WorldLightRelevanceMode.Enabled){WorldLightRelevanceMode.Abort(e);return;} Finish(false); }\n    }\n    static bool CaptureAt')
    text=replace(text,'        if (closing) return; closing = true; running = false; RenderPipelineManager.endCameraRendering -= Rendered;',
        '        if (closing) return; closing = true; running = false; RenderPipelineManager.endCameraRendering -= Rendered;\n        if(WorldLightRelevanceMode.Enabled){camera.enabled=false;try{WorldLightRelevanceMode.Close();}catch(Exception e){Fail("Light fixture close: "+e);}}')
    text=replace(text,'camera.enabled = oldEnabled;','camera.enabled = WorldLightRelevanceMode.Enabled ? false : oldEnabled;');changed[capture]=text.encode()
    feature=PROJECT/'Assets/HybridLumenGI/Runtime/HybridLumenGIRendererFeature.cs';text=feature.read_text(encoding='utf-8')
    text=replace(text,'                using(d.frameTiming.Profile(cmd,"HLGI World cache"))',
        '                WorldLightRelevanceMode.Observe(cmd,state,d.lightCount,d.frame,d.hardware,d.invVP);\n                using(d.frameTiming.Profile(cmd,"HLGI World cache"))')
    text=replace(text,'                state.previousLightCount=count;state.lastLightHash=hash;',
        '                WorldLightRelevanceMode.Selection(state,useRenderingLayers);\n                state.previousLightCount=count;state.lastLightHash=hash;');changed[feature]=text.encode()
    for src,dst in [('WorldLightRelevanceMode.cs','WorldLightRelevanceMode.cs'),('CurrentPlayerBuild.cs','Editor/CurrentPlayerBuild.cs')]:changed[PROJECT/'Assets/ComparisonHarness'/dst]=(H/src).read_bytes()
    OUT.mkdir(parents=True)
    manifest={'baseline':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'productSourceSha256':product,
        'scene':'Assets/RuntimeAudit/Functional.unity','scope':'one build; one visible DXR64frame final light upload; no images, mixed events or scene regeneration',
        'files':[],'newMetadata':[]}
    for i,(path,data) in enumerate(changed.items()):
        rel=path.relative_to(PROJECT).as_posix();old=path.read_bytes() if path.exists() else None
        if old is not None:(OUT/f'{i}.original').write_bytes(old)
        target=OUT/'prepared'/rel;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(data)
        manifest['files'].append({'path':rel,'original':f'{i}.original' if old is not None else None,'originalSha256':hashlib.sha256(old).hexdigest() if old is not None else None,
            'prepared':'prepared/'+rel,'sha256':hashlib.sha256(data).hexdigest()})
        if not Path(str(path)+'.meta').exists():manifest['newMetadata'].append(rel+'.meta')
    (OUT/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
    (OUT/'installer.executed.py.txt').write_bytes(Path(__file__).read_bytes())
    print(json.dumps({'preparedFiles':len(changed),'productSourceCount':len(product),'sceneRegenerated':False}))

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('action',choices=['deploy','prepare','install','restore']);a=p.parse_args()
    (globals().get(a.action) or getattr(base,a.action))()
