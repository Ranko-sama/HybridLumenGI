"""Finite current door capture. Reuse prior copy and reversible build machinery."""
import argparse,hashlib,importlib.util,json,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];H=ROOT/'LocalComparison/Harness';PROJECT=Path('I:/Unity test/Project')
PACKAGE=ROOT/'LocalComparison/Review/moving-occluder-stage-review-01';OUT=PACKAGE/'instrumentation'
spec=importlib.util.spec_from_file_location('base',H/'prepare-player-smoke.py');base=importlib.util.module_from_spec(spec);spec.loader.exec_module(base)
base.PACKAGE=PACKAGE;base.OUT=OUT;sha=base.sha;replace=base.replace
def prepare():
    assert not OUT.exists(),'Unique stage preparation already exists'
    product={p.relative_to(ROOT).as_posix():sha(p) for top in ['Runtime','Editor'] for p in (ROOT/top).rglob('*') if p.is_file() and p.suffix!='.meta'}
    assert all(sha(PROJECT/'Assets/HybridLumenGI'/p)==v for p,v in product.items())
    changed={}
    def source(rel):return (PROJECT/'Assets'/rel).read_text(encoding='utf-8')
    def put(rel,text):changed[PROJECT/'Assets'/rel]=text.encode()
    entry=source('ComparisonHarness/RuntimeAuditEntry.cs')
    entry=replace(entry,'        capture.totalFrames=720;','        capture.totalFrames=198; capture.quitWhenComplete=true;')
    put('ComparisonHarness/RuntimeAuditEntry.cs',entry)
    capture=source('ComparisonHarness/ComparisonCapture.cs')
    capture=replace(capture,'static bool CaptureAt(int n) => n % 30 == 0','static bool CaptureAt(int n) => DenoiseSceneTap.Wants(n) || n % 30 == 0')
    capture=replace(capture,'    void Finish(bool collected)','    public bool AuditOpen=>running && !closing;\n    public event Action AuditClosing;\n    void Finish(bool collected)')
    capture=replace(capture,'running = false; RenderPipelineManager.endCameraRendering -= Rendered;',
        'running = false; try{AuditClosing?.Invoke();}catch(Exception e){Fail("Probe close: "+e);} RenderPipelineManager.endCameraRendering -= Rendered;\n        camera.enabled=false;\n        try{DenoiseSceneTap.Finish(collected);}catch(Exception e){Fail(e.ToString());}\n        try{HybridLumenGI.MovingOccluderStageTap.Finish(collected);}catch(Exception e){Fail(e.ToString());}')
    capture=replace(capture,'camera.enabled = oldEnabled;','camera.enabled = false;')
    put('ComparisonHarness/ComparisonCapture.cs',capture)
    probe=source('ComparisonHarness/RuntimeAuditProbe.cs')
    start=probe.index('    void Update()');end=probe.index('    void Rendered(',start)
    probe=probe[:start]+'    // Only the original door timeline moves; initial snapshot setup is retained.\n    void Update() {}\n'+probe[end:]
    probe=replace(probe,'    void Start()', '    bool probeClosed;\n    void CloseProbe(){if(probeClosed)return;probeClosed=true;RenderPipelineManager.endCameraRendering-=Rendered;writer?.Dispose();writer=null;}\n    void Start()')
    probe=replace(probe,'        RenderPipelineManager.endCameraRendering+=Rendered;','        capture.AuditClosing+=CloseProbe;\n        RenderPipelineManager.endCameraRendering+=Rendered;')
    probe=replace(probe,'        if(camera!=capture.camera)return;','        if(camera!=capture.camera||!capture.AuditOpen||probeClosed)return;')
    probe=replace(probe,'    void OnDestroy(){RenderPipelineManager.endCameraRendering-=Rendered;writer?.Dispose();}','    void OnDestroy(){capture.AuditClosing-=CloseProbe;CloseProbe();}')
    put('ComparisonHarness/RuntimeAuditProbe.cs',probe)
    feature=source('HybridLumenGI/Runtime/HybridLumenGIRendererFeature.cs')
    feature=replace(feature,'                state.changes.Upload();','                MovingOccluderStageTap.Sources(camera,state.frame,state.width,state.height,receiverSources,identityFrame);\n                state.changes.Upload();')
    feature=replace(feature,'                    Copy(work,data);','                    Copy(work,data);\n                    foreach(var observed in MovingOccluderStageTap.OwnedBuffers)builder.UseBuffer(graph.ImportBuffer(observed),AccessFlags.ReadWrite);')
    feature=replace(feature,'                using(d.frameTiming.Profile(cmd,"HLGI Gather")) Dispatch(cmd,c,trace,state);','                using(d.frameTiming.Profile(cmd,"HLGI Gather")) Dispatch(cmd,c,trace,state);\n                global::DenoiseSceneTap.Record(cmd,((RTHandle)d.raw).rt,state.camera,d.frame);')
    feature=replace(feature,'                state.readiness.Record(cmd,state.scene,state.sdf,state.surfaceCache,state.cache[1-d.cacheRead],state.patchGrid,d.epoch,d.frame);',
        '''                if(d.useIdentity)MovingOccluderStageTap.Record(cmd,state.camera,d.frame,d.read,d.hardware,d.receiverReceipt.identityRecorded,d.valid,d.hasMotion,
                    d.vp,d.invVP,d.previousVP,d.previousInvVP,d.jitterDelta,(RTHandle)d.identityWrite,(RTHandle)d.identityRead,
                    (RTHandle)d.geometryWrite,(RTHandle)d.materialWrite,(RTHandle)d.historyWrite,(RTHandle)d.momentsWrite,
                    (RTHandle)(s.filterIterations<=0?d.historyWrite:(Mathf.Clamp(s.filterIterations,0,4)%2==1?d.tempA:d.tempB)),(RTHandle)d.motion,
                    (GraphicsBuffer)d.identity.Objects,d.identity.ObjectCount,((RTHandle)d.diffuse).rt.width,((RTHandle)d.diffuse).rt.height);
                state.readiness.Record(cmd,state.scene,state.sdf,state.surfaceCache,state.cache[1-d.cacheRead],state.patchGrid,d.epoch,d.frame);''')
    put('HybridLumenGI/Runtime/HybridLumenGIRendererFeature.cs',feature)
    for name,destination in [('DenoiseSceneTap.cs','DenoiseSceneTap.cs'),('MovingOccluderStageTap.cs','MovingOccluderStageTap.cs'),('CurrentPlayerBuild.cs','Editor/CurrentPlayerBuild.cs')]:
        changed[PROJECT/'Assets/ComparisonHarness'/destination]=(H/name).read_bytes()
    original=(H/'MaterialEventReadback.compute').read_text();start=original.index('[numthreads(8,8,1)]');end=original.index('[numthreads(3,1,1)]',start)
    # Same exact uint copy body, without the unrelated material trace/selection kernel.
    put('ComparisonHarness/Resources/MovingOccluderIdentityCopy.compute','#pragma kernel CopyIdentity\n#pragma target 5.0\n#pragma use_dxc\nTexture2D<uint4> _Identity;\nRWStructuredBuffer<uint4> _IdentityCopy;\nint2 _Size;\n'+original[start:end])
    OUT.mkdir(parents=True)
    manifest={'baseline':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'productSourceSha256':product,
        'scene':'Assets/RuntimeAudit/Functional.unity','scope':'one current DXR198frame door segment; original raw tap and integer copy; no product algorithm edits','files':[],'newMetadata':[]}
    for i,(path,data) in enumerate(changed.items()):
        rel=path.relative_to(PROJECT).as_posix();old=path.read_bytes() if path.exists() else None
        if old is not None:(OUT/f'{i}.original').write_bytes(old)
        target=OUT/'prepared'/rel;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(data)
        manifest['files'].append({'path':rel,'original':f'{i}.original' if old is not None else None,'originalSha256':hashlib.sha256(old).hexdigest() if old is not None else None,'prepared':'prepared/'+rel,'sha256':hashlib.sha256(data).hexdigest()})
        if not Path(str(path)+'.meta').exists():manifest['newMetadata'].append(rel+'.meta')
    (OUT/'manifest.json').write_text(json.dumps(manifest,indent=2));(OUT/'installer.executed.py.txt').write_bytes(Path(__file__).read_bytes())
    print(json.dumps({'preparedFiles':len(changed),'productSources':len(product),'copiedKernelBodyUnchanged':True}))
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('action',choices=['prepare','install','restore']);a=p.parse_args()
    (prepare if a.action=='prepare' else getattr(base,a.action))()
