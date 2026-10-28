"""Temporary, finite material-event observation beside unchanged product operations."""
import argparse, ast, hashlib, importlib.util, json, subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]; H=ROOT/'LocalComparison/Harness';PROJECT=Path('I:/Unity test/Project')
PACKAGE=ROOT/'LocalComparison/Review/material-mpb-propagation-01';OUT=PACKAGE/'instrumentation'
spec=importlib.util.spec_from_file_location('base',H/'prepare-player-smoke.py');base=importlib.util.module_from_spec(spec);spec.loader.exec_module(base)
base.PACKAGE=PACKAGE;base.OUT=OUT;replace=base.replace;sha=base.sha

def prepare():
    assert not (OUT/'installed.json').exists(), 'Unique installation already used'
    product={p.relative_to(ROOT).as_posix():sha(p) for top in ['Runtime','Editor'] for p in (ROOT/top).rglob('*') if p.is_file() and p.suffix!='.meta'}
    assert all(sha(PROJECT/'Assets/HybridLumenGI'/p)==v for p,v in product.items()),'Deployment differs from current product'
    changed={}
    def put(path,text):changed[PROJECT/'Assets'/path]=text.encode('utf-8')
    entry=(PROJECT/'Assets/ComparisonHarness/RuntimeAuditEntry.cs').read_text(encoding='utf-8')
    entry=replace(entry,'        capture.totalFrames=720;', '''        if(Array.IndexOf(Environment.GetCommandLineArgs(),"-materialEvent")>=0)
        {
            try
            {
                if(Arg("-auditScene","functional")!="functional")throw new Exception("Material event requires existing Functional scene");
                MaterialEventMode.Configure(capture);
            }
            catch(Exception e)
            {
                capture.enabled=false;
                try{MaterialEventMode.Close(false);}catch(Exception closeError){Debug.LogError(closeError);}
                Directory.CreateDirectory(capture.outputRoot);
                File.WriteAllText(Path.Combine(capture.outputRoot,"material-preparation-failure.txt"),e.ToString());
                Debug.LogError(e);Application.Quit(1);
            }
            return;
        }
        capture.totalFrames=720;''')
    put('ComparisonHarness/RuntimeAuditEntry.cs',entry)
    capture=(PROJECT/'Assets/ComparisonHarness/ComparisonCapture.cs').read_text(encoding='utf-8')
    capture=replace(capture,'        appliedEngine = Time.frameCount;', '''        appliedEngine = Time.frameCount;
        if(MaterialEventMode.Requested)
        {
            try{MaterialEventMode.Apply(logicalFrame);}catch(Exception e){HybridLumenGI.MaterialEventTap.Abort(e);Fail(e.ToString());Finish(false);}
            return;
        }''')
    capture=replace(capture,'            if (CaptureAt(logicalFrame) || logicalFrame == totalFrames - 1) Capture(f);',
        '            if (MaterialEventMode.Requested ? (logicalFrame==159||logicalFrame==160||logicalFrame==175||logicalFrame==255) : (CaptureAt(logicalFrame)||logicalFrame==totalFrames-1)) Capture(f);')
    capture=replace(capture,'receipt = true; run.renderedFrames++; SaveRun();',
        'receipt = true; run.renderedFrames++; if(MaterialEventMode.Requested)MaterialEventMode.Rendered(logicalFrame,Time.frameCount); SaveRun();')
    # Preserve the first Rendered error, then close from the existing next Update error branch.
    # No extra render is admitted, and an endCamera callback is never treated as an idle queue boundary.
    capture=replace(capture,'        catch (Exception e) { Fail(e.ToString()); Finish(false); }\n    }\n    static bool CaptureAt',
        '        catch (Exception e) { Fail(e.ToString()); if(MaterialEventMode.Requested){HybridLumenGI.MaterialEventTap.Abort(e);return;} Finish(false); }\n    }\n    static bool CaptureAt')
    capture=replace(capture,'    void Finish(bool collected)', '''    public bool AuditOpen=>running && !closing;
    public bool AuditReceipt(int frame,int engine)=>AuditOpen && receipt && logicalFrame==frame && lastEngine==engine;
    void Finish(bool collected)''')
    capture=replace(capture,'            if (pending) { readback.WaitForCompletion();',
        '            try{if(MaterialEventMode.Requested)MaterialEventMode.Close(collected);}catch(Exception e){Fail("Material close: "+e);}\n            if (pending) { readback.WaitForCompletion();')
    capture=replace(capture,'camera.enabled = oldEnabled;','camera.enabled = MaterialEventMode.Requested?false:oldEnabled;')
    put('ComparisonHarness/ComparisonCapture.cs',capture)
    feature=(ROOT/'Runtime/HybridLumenGIRendererFeature.cs').read_text(encoding='utf-8')
    feature=replace(feature,'                state.changes.Upload();',
        '                MaterialEventTap.Sources(camera,state.frame,state,receiverSources,identityFrame,vp);\n                state.changes.Upload();')
    feature=replace(feature,'                    Copy(work,data);',
        '                    Copy(work,data);\n                    foreach(var observed in MaterialEventTap.OwnedBuffers)builder.UseBuffer(graph.ImportBuffer(observed),AccessFlags.ReadWrite);')
    feature=replace(feature,'                if(d.useIdentity && !d.receiverReceipt.identityRecorded) d.valid=false;',
        '''                if(d.useIdentity && !d.receiverReceipt.identityRecorded) d.valid=false;
                MaterialEventTap.BeginTransport(state.camera,d.frame,d.read,d.cacheRead,d.hardware,d.useIdentity,d.valid,
                    d.receiverReceipt.sourcesCurrent,d.receiverReceipt.identityRecorded,d.hitMaterials?.Generation??0,d.historyToken);''')
    feature=replace(feature,'                using(d.frameTiming.Profile(cmd,"HLGI World material capture")) state.surfaceCache.RecordCapture(cmd,d.viewport);',
        '                using(d.frameTiming.Profile(cmd,"HLGI World material capture")) state.surfaceCache.RecordCapture(cmd,d.viewport);\n                MaterialEventTap.CaptureRecorded(state.camera,state.surfaceCache);')
    feature=replace(feature,'                int update=c.FindKernel("CSUpdateCache"),trace=c.FindKernel("CSTrace"),',
        '                MaterialEventTap.MaterialBound(state.camera,d.hardware,state.hardwareMaterialStatus);\n                int update=c.FindKernel("CSUpdateCache"),trace=c.FindKernel("CSTrace"),')
    feature=replace(feature,'                using(d.frameTiming.Profile(cmd,"HLGI World cache"))',
        '                MaterialEventTap.BindTrace(state.camera,cmd,c,update,trace,state.width,state.height,state.scheduler,state.patchGrid);\n                using(d.frameTiming.Profile(cmd,"HLGI World cache"))')
    feature=replace(feature,'                using(d.frameTiming.Profile(cmd,"HLGI Temporal")) Dispatch(cmd,c,temporal,state);',
        '''                using(d.frameTiming.Profile(cmd,"HLGI Temporal")) Dispatch(cmd,c,temporal,state);
                if(d.useIdentity)MaterialEventTap.Gpu(state.camera,cmd,(RTHandle)d.identityWrite,(RTHandle)d.identityRead,(RTHandle)d.raw,
                    (RTHandle)d.materialWrite,(RTHandle)d.geometryWrite,(RTHandle)d.historyWrite,(RTHandle)d.momentsWrite,
                    (RTHandle)d.historyRead,(RTHandle)d.momentsRead,(RTHandle)d.diffuse,(GraphicsBuffer)d.identity.Candidates,
                    (GraphicsBuffer)d.identity.Objects,d.identity.ObjectCount,state.cache[d.cacheRead],state.cache[1-d.cacheRead]);''')
    put('HybridLumenGI/Runtime/HybridLumenGIRendererFeature.cs',feature)
    batch=(ROOT/'Runtime/HybridLumenGIHitMaterialBatch.cs').read_text(encoding='utf-8')
    batch=replace(batch,'                cmd.SetBufferData(records,materialRecords);',
        '                MaterialEventTap.MaterialUpload(Generation,sources,materialRecords,materialBindings);\n                cmd.SetBufferData(records,materialRecords);')
    put('HybridLumenGI/Runtime/HybridLumenGIHitMaterialBatch.cs',batch)
    shaders='Runtime/Resources/HybridLumenGI/'
    # Reuse the already-reviewed finite original-path recorder, without executing its installer.
    syntax=ast.parse((H/'prepare-gather-cache.py').read_text(encoding='utf-8'))
    node=next(n for n in syntax.body if isinstance(n,ast.FunctionDef) and n.name=='kernels')
    namespace={'replace':replace};exec(compile(ast.Module(body=[node],type_ignores=[]),'<reused-kernels-observer>','exec'),namespace)
    kernels=namespace['kernels']((ROOT/shaders/'HybridLumenGIKernels.hlsl').read_text(encoding='utf-8'))
    put('HybridLumenGI/'+shaders+'HybridLumenGIKernels.hlsl',kernels)
    transport=(ROOT/shaders/'HybridLumenGITransport.hlsl').read_text(encoding='utf-8')
    transport=replace(transport,'#define HLGI_TRANSPORT_INCLUDED','#define HLGI_TRANSPORT_INCLUDED\n#include "MaterialEventTraceWriter.hlsl"')
    start=transport.index('float3 ProxyRadiance(HLGIHit hit,float3 incomingDirection,HLGIRayFootprint hitFootprint,float emissionWeight');end=transport.index('float3 ProxyRadiance(',start+20)
    block=transport[start:end]
    block=replace(block,'    confidence=0;','    GCCALL();GCH(200,true,hit);\n    confidence=0;')
    block=replace(block,'    bool directKnown;',
        '    GCV(201,float4(diffuse,ao),float4(emission,emissionWeight),float4(shadingNormal,confidence),cached.irradiance,cached.tag,cached.anchor,cached.normal);\n    bool directKnown;')
    block=replace(block,'    return value;',
        '    GCV(202,float4(direct,directKnown),float4(value,confidence),float4(_HLGI_BounceFeedback,ao,emissionWeight,0),0,0,0,0);\n    return value;')
    transport=transport[:start]+block+transport[end:]
    transport=replace(transport,'    uint card=id.x/patches,local=id.x%patches;',
        '    GCSTARTCACHE(id.x);GCCTX(900u);\n    uint card=id.x/patches,local=id.x%patches;')
    transport=replace(transport,'    if(!covered) { _HLGI_CacheWrite[id.x]=(HLGICacheEntry)0;return; }',
        '''    GCU(300,uint4(card,local,covered,_HLGI_CacheUpdateMask[id.x]));
    if(!covered) { _HLGI_CacheWrite[id.x]=(HLGICacheEntry)0;GCFINISH(0,0);return; }
    GCV(301,asfloat(uint4(surface.ownerSlot,surface.generation,surface.cardIndex,0)),float4(surface.position,surface.confidence),
        float4(surface.diffuse,surface.occlusion),float4(surface.emission,0),float4(surface.normal,0),float4(surface.geometricNormal,0),0);''')
    transport=replace(transport,'            float3 origin=position+HLGIOffsetNormal(surface.geometricNormal,n)*_HLGI_RayBias;',
        '            GCCTX(1000u+r*10u);\n            float3 origin=position+HLGIOffsetNormal(surface.geometricNormal,n)*_HLGI_RayBias;')
    transport=replace(transport,'            if(!all(isfinite(direction)))',
        '            GCV(310,float4(origin,weight),float4(direction,0),0,0,0,0,0);\n            if(!all(isfinite(direction)))')
    transport=replace(transport,'            if(!HLGIAccumulateRadianceSample(incoming,materialConfidence,weight,sum))',
        '            GCV(311,float4(incoming,materialConfidence),float4(sum,weight),0,0,0,0,0);\n            if(!HLGIAccumulateRadianceSample(incoming,materialConfidence,weight,sum))')
    transport=replace(transport,'        HLGICommitCacheEstimate(estimateKnown,sum,guide,guidePower,_HLGI_CacheRays,n,e.irradiance,e.guide);',
        '        GCV(312,float4(sum,estimateKnown),float4(guide,guidePower),0,0,0,0,0);\n        HLGICommitCacheEstimate(estimateKnown,sum,guide,guidePower,_HLGI_CacheRays,n,e.irradiance,e.guide);')
    transport=replace(transport,'    _HLGI_CacheWrite[id.x]=e;','    _HLGI_CacheWrite[id.x]=e;GCV(313,e.irradiance,e.tag,e.anchor,e.normal,e.guide,0,0);GCFINISH(e.irradiance,1);')
    put('HybridLumenGI/'+shaders+'HybridLumenGITransport.hlsl',transport)
    wrapper=(ROOT/shaders/'HybridLumenGIHardware.compute').read_text(encoding='utf-8')
    wrapper=wrapper.replace('#pragma kernel CSUpdateCache','#pragma kernel CSUpdateCache HLGI_MATERIAL_EVENT').replace('#pragma kernel CSTrace','#pragma kernel CSTrace HLGI_MATERIAL_EVENT')
    put('HybridLumenGI/'+shaders+'HybridLumenGIHardware.compute',wrapper)
    for name,dest in [('MaterialEventTap.cs','HybridLumenGI/Runtime/MaterialEventTap.cs'),('MaterialEventGpu.cs','HybridLumenGI/Runtime/MaterialEventGpu.cs'),
        ('MaterialEventTraceWriter.hlsl','HybridLumenGI/'+shaders+'MaterialEventTraceWriter.hlsl'),('MaterialEventMode.cs','ComparisonHarness/MaterialEventMode.cs'),
        ('MaterialEventReadback.compute','ComparisonHarness/Resources/MaterialEventReadback.compute'),('CurrentPlayerBuild.cs','ComparisonHarness/Editor/CurrentPlayerBuild.cs')]:
        data=(H/name).read_text(encoding='utf-8')
        if name=='MaterialEventReadback.compute':data=data.replace('#include "HybridLumenGI','#include "Assets/HybridLumenGI/Runtime/Resources/HybridLumenGI/HybridLumenGI')
        put(dest,data)
    OUT.mkdir(parents=True,exist_ok=True)
    manifest={'baseline':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'productSourceSha256':product,
        'scene':'Assets/RuntimeAudit/Functional.unity','scope':'one visible DXR run 0..255, MPB slot0 before160, no scene regeneration or product fix','files':[],'newMetadata':[]}
    for i,(path,data) in enumerate(changed.items()):
        rel=path.relative_to(PROJECT).as_posix();old=path.read_bytes() if path.exists() else None
        if old is not None:(OUT/f'{i}.original').write_bytes(old)
        dest=OUT/'prepared'/rel;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(data)
        manifest['files'].append({'path':rel,'original':f'{i}.original' if old is not None else None,'originalSha256':hashlib.sha256(old).hexdigest() if old is not None else None,
            'prepared':'prepared/'+rel,'sha256':hashlib.sha256(data).hexdigest()})
        meta=Path(str(path)+'.meta')
        if not meta.exists():manifest['newMetadata'].append(meta.relative_to(PROJECT).as_posix())
    (OUT/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
    (OUT/'installer.executed.py.txt').write_bytes(Path(__file__).read_bytes())
    print(json.dumps({'preparedFiles':len(changed),'productSourceCount':len(product),'installed':False}))

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('action',choices=['prepare','install','restore']);args=parser.parse_args()
    if args.action=='prepare':prepare()
    else:getattr(base,args.action)()
