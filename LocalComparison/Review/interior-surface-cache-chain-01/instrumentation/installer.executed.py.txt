"""One same-owner internal-layer query. Reuse reversible Player deployment."""
import argparse,hashlib,importlib.util,json,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];H=ROOT/'LocalComparison/Harness';PROJECT=Path('I:/Unity test/Project')
PACKAGE=ROOT/'LocalComparison/Review/interior-surface-cache-chain-01';OUT=PACKAGE/'instrumentation'
spec=importlib.util.spec_from_file_location('base',H/'prepare-player-smoke.py');base=importlib.util.module_from_spec(spec);spec.loader.exec_module(base)
base.PACKAGE=PACKAGE;base.OUT=OUT;sha=base.sha;replace=base.replace

def prepare():
    assert not OUT.exists(),'Unique stage already prepared'
    product={p.relative_to(ROOT).as_posix():sha(p) for top in ['Runtime','Editor'] for p in (ROOT/top).rglob('*') if p.is_file() and p.suffix!='.meta'}
    assert all(sha(PROJECT/'Assets/HybridLumenGI'/p)==v for p,v in product.items())
    changed={}
    def source(rel):return (PROJECT/'Assets'/rel).read_text(encoding='utf-8')
    def put(rel,text):changed[PROJECT/'Assets'/rel]=text.encode()
    entry=source('ComparisonHarness/RuntimeAuditEntry.cs')
    entry=replace(entry,'        capture.label="player-"+Arg("-auditScene","functional")+"-"+mode;',
        '        capture.label="player-"+Arg("-auditScene","functional")+"-"+mode;\n        if(InteriorSurfaceMode.Enabled)InteriorSurfaceMode.Configure(capture);')
    put('ComparisonHarness/RuntimeAuditEntry.cs',entry)
    capture=source('ComparisonHarness/ComparisonCapture.cs')
    capture=replace(capture,'        appliedEngine = Time.frameCount;',
        '        appliedEngine = Time.frameCount;\n        if(InteriorSurfaceMode.Enabled){InteriorSurfaceMode.Apply(this,logicalFrame,directory);return;}')
    capture=replace(capture,'            if (FrameTimingManager.GetLatestTimings(1, timings) != 0)',
        '            if (!InteriorSurfaceMode.Enabled && FrameTimingManager.GetLatestTimings(1, timings) != 0)')
    capture=replace(capture,'            if (CaptureAt(logicalFrame) || logicalFrame == totalFrames - 1) Capture(f);',
        '            if(InteriorSurfaceMode.Enabled)InteriorSurfaceMode.Rendered(logicalFrame);\n            else if (CaptureAt(logicalFrame) || logicalFrame == totalFrames - 1) Capture(f);')
    capture=replace(capture,'running = false; RenderPipelineManager.endCameraRendering -= Rendered;',
        'running = false; RenderPipelineManager.endCameraRendering -= Rendered;\n        camera.enabled=false;\n        try{if(InteriorSurfaceMode.Enabled)InteriorSurfaceMode.Close();}catch(Exception e){Fail(e.ToString());}')
    capture=replace(capture,'camera.enabled = oldEnabled;','camera.enabled = false;')
    put('ComparisonHarness/ComparisonCapture.cs',capture)
    feature=source('HybridLumenGI/Runtime/HybridLumenGIRendererFeature.cs')
    feature=replace(feature,'                    Copy(work,data);',
        '                    Copy(work,data);\n                    if(global::InteriorSurfaceMode.Enabled)builder.UseBuffer(graph.ImportBuffer(global::InteriorSurfaceMode.Buffer),AccessFlags.ReadWrite);')
    feature=replace(feature,'                state.exactSoftwareGeometry=d.geometry!=null && !d.hardware;',
        '                int interiorProbe=global::InteriorSurfaceMode.Enabled&&c.HasKernel("CSInteriorSurfaceProbe")?c.FindKernel("CSInteriorSurfaceProbe"):-1;\n                state.exactSoftwareGeometry=d.geometry!=null && !d.hardware;')
    feature=replace(feature,'                foreach(int k in new[]{update,trace})\n                {',
        '                foreach(int k in new[]{update,trace,interiorProbe})\n                {\n                    if(k<0)continue;')
    feature=replace(feature,'                using(d.frameTiming.Profile(cmd,"HLGI Gather")) Dispatch(cmd,c,trace,state);',
        '                using(d.frameTiming.Profile(cmd,"HLGI Gather")) Dispatch(cmd,c,trace,state);\n                global::InteriorSurfaceMode.Record(cmd,c,interiorProbe,state.camera,state.scene,state.surfaceCache,state.cache[1-d.cacheRead],state.patchGrid,d.epoch,d.frame,d.hardware);')
    put('HybridLumenGI/Runtime/HybridLumenGIRendererFeature.cs',feature)
    materials=source('HybridLumenGI/Runtime/HybridLumenGIHitMaterialPass.cs')
    materials=replace(materials,'            return batch.Record(cmd,out reason) && batch.Bind(cmd,shader,cacheKernel,out reason) &&\n                batch.Bind(cmd,shader,traceKernel,out reason);',
        '''            bool productBound=batch.Record(cmd,out reason) && batch.Bind(cmd,shader,cacheKernel,out reason) &&
                batch.Bind(cmd,shader,traceKernel,out reason);
            if(productBound && global::InteriorSurfaceMode.Enabled && shader.HasKernel("CSInteriorSurfaceProbe") &&
                !batch.Bind(cmd,shader,shader.FindKernel("CSInteriorSurfaceProbe"),out string probeReason))
                throw new System.InvalidOperationException("Interior query material binding failed: "+probeReason);
            return productBound;''')
    put('HybridLumenGI/Runtime/HybridLumenGIHitMaterialPass.cs',materials)
    shader=source('HybridLumenGI/Runtime/Resources/HybridLumenGI/HybridLumenGIHardware.compute')
    shader=replace(shader,'#pragma kernel CSFilter','#pragma kernel CSFilter\n#pragma kernel CSInteriorSurfaceProbe HLGI_INTERIOR_QUERY')
    shader=replace(shader,'#include "HybridLumenGIKernels.hlsl"','#include "HybridLumenGIKernels.hlsl"\n#if defined(HLGI_INTERIOR_QUERY)\n#include "InteriorSurfaceQuery.hlsl"\n#endif')
    put('HybridLumenGI/Runtime/Resources/HybridLumenGI/HybridLumenGIHardware.compute',shader)
    transport=source('HybridLumenGI/Runtime/Resources/HybridLumenGI/HybridLumenGITransport.hlsl')
    transport=replace(transport,'#define HLGI_TRANSPORT_INCLUDED','#define HLGI_TRANSPORT_INCLUDED\n#if defined(HLGI_INTERIOR_QUERY)\n#include "InteriorSurfaceWriter.hlsl"\n#endif')
    start=transport.index('bool HLGICachedSurface(');end=transport.index('bool HLGICachedSample(',start);body=transport[start:end]
    body=replace(body,'        HLGICacheEntry e=_HLGI_CacheRead[entry];','''        HLGICacheEntry e=_HLGI_CacheRead[entry];
#if defined(HLGI_INTERIOR_QUERY)
        uint row=24u+(uint)tap*9u;
        ISW(row,e.irradiance);ISW(row+1,e.tag);ISW(row+2,e.anchor);ISW(row+3,e.normal);ISW(row+4,e.guide);
        ISW(row+5,float4(0,entry,tap,0));int2 anchorPixel=_HLGI_SurfaceAnchors[entry];ISW(row+6,asfloat(int4(anchorPixel,cell)));
        if(all(anchorPixel>=0)){ISW(row+7,_HLGI_SurfacePosition.Load(int3(anchorPixel,0)));ISW(row+8,_HLGI_SurfaceNormal.Load(int3(anchorPixel,0)));ISW(72u+(uint)tap,_HLGI_SurfaceEmission.Load(int3(anchorPixel,0)));}
#endif''')
    body=replace(body,'        totalWeight+=weight;result.irradiance+=e.irradiance*weight;result.guide+=e.guide*weight;',
        '''        totalWeight+=weight;result.irradiance+=e.irradiance*weight;result.guide+=e.guide*weight;
#if defined(HLGI_INTERIOR_QUERY)
        ISW(24u+(uint)tap*9u+5u,float4(weight,entry,tap,1));ISW(22,float4(totalWeight,0,0,0));
#endif''')
    transport=transport[:start]+body+transport[end:]
    put('HybridLumenGI/Runtime/Resources/HybridLumenGI/HybridLumenGITransport.hlsl',transport)
    for name,destination in [('InteriorSurfaceMode.cs','ComparisonHarness/InteriorSurfaceMode.cs'),('CurrentPlayerBuild.cs','ComparisonHarness/Editor/CurrentPlayerBuild.cs'),
        ('InteriorSurfaceWriter.hlsl','HybridLumenGI/Runtime/Resources/HybridLumenGI/InteriorSurfaceWriter.hlsl'),('InteriorSurfaceQuery.hlsl','HybridLumenGI/Runtime/Resources/HybridLumenGI/InteriorSurfaceQuery.hlsl')]:
        changed[PROJECT/'Assets'/destination]=(H/name).read_bytes()
    OUT.mkdir(parents=True)
    manifest={'baseline':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'productSourceSha256':product,
        'scene':'Assets/RuntimeAudit/Functional.unity','scope':'one existing same-owner internal layer fixture,120frames/four actual queries; no product algorithm edits','files':[],'newMetadata':[]}
    for i,(path,data) in enumerate(changed.items()):
        rel=path.relative_to(PROJECT).as_posix();old=path.read_bytes() if path.exists() else None
        if old is not None:(OUT/f'{i}.original').write_bytes(old)
        target=OUT/'prepared'/rel;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(data)
        manifest['files'].append({'path':rel,'original':f'{i}.original' if old is not None else None,'originalSha256':hashlib.sha256(old).hexdigest() if old is not None else None,'prepared':'prepared/'+rel,'sha256':hashlib.sha256(data).hexdigest()})
        if not Path(str(path)+'.meta').exists():manifest['newMetadata'].append(rel+'.meta')
    (OUT/'manifest.json').write_text(json.dumps(manifest,indent=2));(OUT/'installer.executed.py.txt').write_bytes(Path(__file__).read_bytes())
    print(json.dumps({'preparedFiles':len(changed),'productSources':len(product),'fixedQueries':4,'maximumFrames':120}))
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('action',choices=['prepare','install','restore']);a=p.parse_args()
    (prepare if a.action=='prepare' else getattr(base,a.action))()
