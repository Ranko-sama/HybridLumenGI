"""Reuse reversible build installation; instrument only deterministic screen probes."""
import argparse,hashlib,importlib.util,json,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];H=ROOT/'LocalComparison/Harness';PROJECT=Path('I:/Unity test/Project')
PACKAGE=ROOT/'LocalComparison/Review/surface-detail-albedo-01';OUT=PACKAGE/'instrumentation'
spec=importlib.util.spec_from_file_location('fixture',H/'prepare-world-light-relevance.py');fixture=importlib.util.module_from_spec(spec);spec.loader.exec_module(fixture)
fixture.PACKAGE=PACKAGE;fixture.OUT=OUT;fixture.base.PACKAGE=PACKAGE;fixture.base.OUT=OUT
sha=fixture.sha;replace=fixture.replace
def prepare():
    assert not OUT.exists(),'Unique native fixture already prepared'
    product={p.relative_to(ROOT).as_posix():sha(p) for top in ['Runtime','Editor'] for p in (ROOT/top).rglob('*') if p.is_file() and p.suffix!='.meta'}
    assert all(sha(PROJECT/'Assets/HybridLumenGI'/p)==v for p,v in product.items())
    changed={};entry=PROJECT/'Assets/ComparisonHarness/RuntimeAuditEntry.cs';text=entry.read_text(encoding='utf-8')
    text=replace(text,'        capture.totalFrames=720;','''        if(SurfaceDetailAlbedoMode.Enabled)
        {
            try{SurfaceDetailAlbedoMode.Configure(capture);}
            catch(Exception e){capture.enabled=false;Directory.CreateDirectory(capture.outputRoot);File.WriteAllText(Path.Combine(capture.outputRoot,"preparation-failure.txt"),e.ToString());Debug.LogException(e);Application.Quit(1);}
            return;
        }
        capture.totalFrames=720;''');changed[entry]=text.encode()
    capture=PROJECT/'Assets/ComparisonHarness/ComparisonCapture.cs';text=capture.read_text(encoding='utf-8')
    text=replace(text,'        appliedEngine = Time.frameCount;','''        appliedEngine = Time.frameCount;
        if(SurfaceDetailAlbedoMode.Enabled){SurfaceDetailAlbedoMode.Apply(this,logicalFrame,directory);featureJson=JsonUtility.ToJson(feature,true);return;}''')
    text=replace(text,'if (FrameTimingManager.GetLatestTimings(1, timings) != 0)','if (!SurfaceDetailAlbedoMode.Enabled && FrameTimingManager.GetLatestTimings(1, timings) != 0)')
    text=replace(text,'if (CaptureAt(logicalFrame) || logicalFrame == totalFrames - 1) Capture(f);','if (!SurfaceDetailAlbedoMode.Enabled && (CaptureAt(logicalFrame) || logicalFrame == totalFrames - 1)) Capture(f);')
    text=replace(text,'receipt = true; run.renderedFrames++; SaveRun();','receipt = true; run.renderedFrames++; SaveRun();\n            if(SurfaceDetailAlbedoMode.Enabled)SurfaceDetailAlbedoMode.Rendered(logicalFrame);')
    text=replace(text,'        catch (Exception e) { Fail(e.ToString()); Finish(false); }\n    }\n    static bool CaptureAt','        catch (Exception e) { Fail(e.ToString()); if(SurfaceDetailAlbedoMode.Enabled){SurfaceDetailAlbedoMode.Abort(e);return;} Finish(false); }\n    }\n    static bool CaptureAt')
    text=replace(text,'        if (closing) return; closing = true; running = false; RenderPipelineManager.endCameraRendering -= Rendered;',
        '        if (closing) return; closing = true; running = false; RenderPipelineManager.endCameraRendering -= Rendered;\n        if(SurfaceDetailAlbedoMode.Enabled){camera.enabled=false;try{SurfaceDetailAlbedoMode.Close();}catch(Exception e){Fail("Shadow fixture close: "+e);}}')
    text=replace(text,'camera.enabled = oldEnabled;','camera.enabled = SurfaceDetailAlbedoMode.Enabled ? false : oldEnabled;');changed[capture]=text.encode()
    feature=PROJECT/'Assets/HybridLumenGI/Runtime/HybridLumenGIRendererFeature.cs';text=feature.read_text(encoding='utf-8')
    text=replace(text,'                using(d.frameTiming.Profile(cmd,"HLGI Gather")) Dispatch(cmd,c,trace,state);','''                SurfaceDetailAlbedoMode.Bind(cmd,state.camera,c,trace,d.hardware,state.width,state.height);
                using(d.frameTiming.Profile(cmd,"HLGI Gather")) Dispatch(cmd,c,trace,state);
                SurfaceDetailAlbedoMode.Read(cmd,state.camera);''');changed[feature]=text.encode()
    kernel=PROJECT/'Assets/HybridLumenGI/Runtime/Resources/HybridLumenGI/HybridLumenGIKernels.hlsl';text=kernel.read_text(encoding='utf-8')
    text=replace(text,'bool TraceScreen(float3 origin,','''// Read-only material capture probe; no additional transport queries.
RWStructuredBuffer<float4> _SDA_Records;
float4 _SDA_Centers[2];int _SDA_Enabled;
bool TraceScreen(float3 origin,''')
    line='    if(!ValidDepth(depth) || !sameSurface || !HLGIHasScreenMaterial(_HLGI_Emission.Load(int3(fullPixel,0)).a))'
    text=replace(text,line,'''    if(_SDA_Enabled!=0)
    {
        [unroll] for(uint lane=0;lane<2;lane++)
        {
            float clipW;float2 probeUV=ProjectUV(_SDA_Centers[lane].xyz,_HLGI_VP,clipW);
            if(all(id.xy==HLGIClosestGiPixel(probeUV,(uint2)_HLGI_Size.xy,(uint2)_HLGI_FullSize.xy)))
            {
                float4 capturedDiffuse=_HLGI_Diffuse.Load(int3(fullPixel,0));
                float4 capturedEmission=_HLGI_Emission.Load(int3(fullPixel,0));
                _SDA_Records[lane*4]=float4(12345,sameSurface?1:0,_HLGI_NativeComposition,lane);
                _SDA_Records[lane*4+1]=capturedDiffuse;
                _SDA_Records[lane*4+2]=capturedEmission;
                _SDA_Records[lane*4+3]=float4(fullPixel,HLGIScreenMaterialAO(capturedEmission.a,_HLGI_NativeComposition!=0,capturedDiffuse.a),HLGIHasScreenMaterial(capturedEmission.a)?1:0);
            }
        }
    }
'''+line);changed[kernel]=text.encode()
    for src,dst in [('SurfaceDetailAlbedoMode.cs','SurfaceDetailAlbedoMode.cs'),('CurrentPlayerBuild.cs','Editor/CurrentPlayerBuild.cs')]:changed[PROJECT/'Assets/ComparisonHarness'/dst]=(H/src).read_bytes()
    OUT.mkdir(parents=True)
    manifest={'baseline':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'productSourceSha256':product,
        'scene':'Assets/RuntimeAudit/Functional.unity','scope':'one build, one DXR64frame process; two detail variants, both original capture entries; read-only diffuse/emission metadata, no extra ray queries','files':[],'newMetadata':[]}
    for i,(path,data) in enumerate(changed.items()):
        rel=path.relative_to(PROJECT).as_posix();old=path.read_bytes() if path.exists() else None
        if old is not None:(OUT/f'{i}.original').write_bytes(old)
        target=OUT/'prepared'/rel;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(data)
        manifest['files'].append({'path':rel,'original':f'{i}.original' if old is not None else None,'originalSha256':hashlib.sha256(old).hexdigest() if old is not None else None,'prepared':'prepared/'+rel,'sha256':hashlib.sha256(data).hexdigest()})
        if not Path(str(path)+'.meta').exists():manifest['newMetadata'].append(rel+'.meta')
    (OUT/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8');(OUT/'installer.executed.py.txt').write_bytes(Path(__file__).read_bytes())
    print(json.dumps({'preparedFiles':len(changed),'productSourceCount':len(product)}))
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('action',choices=['deploy','prepare','install','restore']);a=p.parse_args()
    (prepare if a.action=='prepare' else getattr(fixture,a.action,None) or getattr(fixture.base,a.action))()
