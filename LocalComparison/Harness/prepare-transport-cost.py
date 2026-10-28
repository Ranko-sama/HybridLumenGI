"""Bounded temporary timing hooks; repository product code stays uninstrumented."""
import argparse,hashlib,json,subprocess,importlib.util
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];PROJECT=Path('I:/Unity test/Project');H=ROOT/'LocalComparison/Harness'
PACKAGE=ROOT/'LocalComparison/Review/transport-hotspot-and-reuse-01';SIDE=PACKAGE/'locator';OUT=SIDE/'instrumentation'
spec=importlib.util.spec_from_file_location('installer',H/'prepare-player-smoke.py');installer=importlib.util.module_from_spec(spec);spec.loader.exec_module(installer)
installer.PACKAGE=SIDE;installer.OUT=OUT;sha=installer.sha;replace=installer.replace
def save(p,v):p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes((json.dumps(v,indent=2)+'\n').encode('utf-8'))
def prepare():
    assert not (OUT/'manifest.json').exists(),'Locator preparation already frozen'
    product={p.relative_to(ROOT).as_posix():sha(p) for top in ['Runtime','Editor'] for p in (ROOT/top).rglob('*') if p.is_file() and p.suffix!='.meta'}
    assert all(sha(PROJECT/'Assets/HybridLumenGI'/p)==v for p,v in product.items()),'Unexpected deployment changes'
    changed={};entry=PROJECT/'Assets/ComparisonHarness/RuntimeAuditEntry.cs';text=entry.read_text(encoding='utf-8')
    text=replace(text,'        var capture=UnityEngine.Object.FindFirstObjectByType<ComparisonCapture>();',
        '        var capture=UnityEngine.Object.FindFirstObjectByType<ComparisonCapture>();\n        if(Array.IndexOf(Environment.GetCommandLineArgs(),"-gpuCost")>=0){GpuCostBaseline.Configure(capture);return;}')
    changed[entry]=text.encode('utf-8')
    feature=(ROOT/'Runtime/HybridLumenGIRendererFeature.cs').read_text(encoding='utf-8')
    feature=replace(feature,'{ internal HybridLumenGIGpuFrameTiming frameTiming; }',
        '{ internal HybridLumenGIGpuFrameTiming frameTiming; internal Camera diagnosticCamera; internal HybridLumenGINativeGpuTiming.FrameToken diagnosticParent; }')
    feature=replace(feature,'                        data.frameTiming=frameTiming;',
        '                        data.frameTiming=frameTiming;data.diagnosticCamera=state.camera;data.diagnosticParent=state.nativeGpuTiming.CurrentFrameToken;')
    feature=replace(feature,'                            d.frameTiming.Resolve(CommandBufferHelpers.GetNativeCommandBuffer(ctx.cmd));',
        '                            d.frameTiming.Resolve(CommandBufferHelpers.GetNativeCommandBuffer(ctx.cmd));\n                            TransportCostProbe.Resolve(CommandBufferHelpers.GetNativeCommandBuffer(ctx.cmd),d.diagnosticCamera,d.diagnosticParent);')
    feature=replace(feature,'                state.InvalidateGpuFeedback();d.frameTiming.Invalidate();',
        '                state.InvalidateGpuFeedback();d.frameTiming.Invalidate();TransportCostProbe.Invalidate(state.camera);')
    feature=replace(feature,'                var c=d.compute; var state=d.state;',
        '                var c=d.compute; var state=d.state;\n                TransportCostProbe.Begin(state.camera,state.nativeGpuTiming.CurrentFrameToken);')
    feature=replace(feature,'                using(d.frameTiming.Profile(cmd,"HLGI World cache"))',
        '                using(d.frameTiming.Profile(cmd,"HLGI World cache"))\n                using(TransportCostProbe.Profile(state.camera,cmd,0))')
    feature=replace(feature,'                using(d.frameTiming.Profile(cmd,"HLGI Gather")) Dispatch(cmd,c,trace,state);',
        '                using(d.frameTiming.Profile(cmd,"HLGI Gather")) using(TransportCostProbe.Profile(state.camera,cmd,1)) Dispatch(cmd,c,trace,state);')
    feature=replace(feature,'                using(d.frameTiming.Profile(cmd,"HLGI Temporal")) Dispatch(cmd,c,temporal,state);',
        '                using(TransportCostProbe.Profile(state.camera,cmd,2))\n                {\n                using(d.frameTiming.Profile(cmd,"HLGI Temporal")) Dispatch(cmd,c,temporal,state);')
    feature=replace(feature,'                state.readiness.Record(cmd,state.scene,state.sdf,state.surfaceCache,state.cache[1-d.cacheRead],state.patchGrid,d.epoch,d.frame);',
        '                }\n                state.readiness.Record(cmd,state.scene,state.sdf,state.surfaceCache,state.cache[1-d.cacheRead],state.patchGrid,d.epoch,d.frame);')
    changed[PROJECT/'Assets/HybridLumenGI/Runtime/HybridLumenGIRendererFeature.cs']=feature.encode('utf-8')
    changed[PROJECT/'Assets/HybridLumenGI/Runtime/TransportCostProbe.cs']=(H/'TransportCostProbe.cs').read_bytes()
    capture=(H/'GpuCostBaseline.cs').read_text(encoding='utf-8').replace('Window=512,Drain=32,Limit=800','Window=64,Drain=32,Limit=352')
    capture=replace(capture,'    int count,sampleCount,readyStreak',
        '    readonly HybridLumenGINativeGpuTiming.CompletedSample[] diagnosticCompletions=new HybridLumenGINativeGpuTiming.CompletedSample[Limit];\n    int diagnosticCount,diagnosticPendingBeforeStop;\n    int count,sampleCount,readyStreak')
    capture=replace(capture,'        public int buffered,pending;', '''        public int buffered,pending;
        public ulong diagnosticToken,diagnosticParentToken,diagnosticOwner,diagnosticDeviceEpoch,diagnosticCompleted,diagnosticExported,diagnosticInvalid,diagnosticUnexported,diagnosticCancelled,diagnosticTimedOut;
        public long diagnosticEpoch;public int diagnosticSource,diagnosticGeneration,diagnosticPending;''')
    capture=replace(capture,'        public bool measureOnly,adaptive;',
        '        public int diagnosticCompletions,diagnosticPendingBeforeStop,diagnosticPendingAfterStop;public ulong diagnosticCancelledAfterStop;\n        public bool measureOnly,adaptive;')
    capture=replace(capture,'            Application.runInBackground=true;startupFrame=',
        '            TransportCostProbe.Configure(camera);\n            Application.runInBackground=true;startupFrame=')
    capture=replace(capture,'            r.completed=timing.CompletedResults;', '''            var diagnostic=TransportCostProbe.Timing;var child=diagnostic.CurrentFrameToken;
            while(diagnostic.TryDequeueCompleted(out var childSample)){if(diagnosticCount==diagnosticCompletions.Length)throw new Exception("Diagnostic export overflow");diagnosticCompletions[diagnosticCount++]=childSample;}
            r.diagnosticToken=(ulong)TokenId.GetValue(child);r.diagnosticParentToken=(ulong)TokenId.GetValue(TransportCostProbe.Parent);
            r.diagnosticOwner=(ulong)TokenOwner.GetValue(child);r.diagnosticEpoch=(long)TokenEpoch.GetValue(child);r.diagnosticDeviceEpoch=diagnostic.DeviceEpoch;
            r.diagnosticSource=child.EngineFrame;r.diagnosticGeneration=child.Generation;r.diagnosticPending=diagnostic.PendingCount;
            r.diagnosticCompleted=diagnostic.CompletedResults;r.diagnosticExported=diagnostic.ExportedResults;r.diagnosticUnexported=diagnostic.UnexportedResults;
            r.diagnosticInvalid=diagnostic.InvalidCompletedResults;r.diagnosticCancelled=diagnostic.CancelledSubmissions;r.diagnosticTimedOut=diagnostic.TimedOutSubmissions;
            r.completed=timing.CompletedResults;''')
    capture=replace(capture,'            r.ready=token.IsValid&&',
        '            r.ready=child.IsValid&&child.EngineFrame==Time.frameCount&&r.diagnosticParentToken==r.token&&token.IsValid&&')
    capture=replace(capture,'            if(settings.adaptiveGpuBudget||', '''            if(TransportCostProbe.Failure!=null)throw new Exception(TransportCostProbe.Failure);
            if(token.IsValid&&(!child.IsValid||!diagnostic.Available||child.EngineFrame!=token.EngineFrame||child.Generation!=token.Generation||r.diagnosticParentToken!=r.token))
                throw new Exception("Diagnostic submission/parent missing or mismatched");
            if(settings.adaptiveGpuBudget||''')
    capture=replace(capture,'                if(r.invalid!=anchor.invalid||',
        '                if(r.diagnosticInvalid!=anchor.diagnosticInvalid||r.diagnosticUnexported!=anchor.diagnosticUnexported||r.diagnosticTimedOut!=anchor.diagnosticTimedOut||r.diagnosticCancelled!=anchor.diagnosticCancelled||r.invalid!=anchor.invalid||')
    capture=replace(capture,'        a.width==b.width&&',
        '        a.diagnosticOwner==b.diagnosticOwner&&a.diagnosticGeneration==b.diagnosticGeneration&&a.diagnosticDeviceEpoch==b.diagnosticDeviceEpoch&&a.diagnosticEpoch==b.diagnosticEpoch&&\n        a.width==b.width&&')
    capture=replace(capture,'        try{capture.camera.enabled=false;',
        '        try{diagnosticPendingBeforeStop=TransportCostProbe.Timing?.PendingCount??0;TransportCostProbe.Stop();capture.camera.enabled=false;')
    capture=replace(capture,'                frames=count,completions=sampleCount,',
        '                diagnosticCompletions=diagnosticCount,diagnosticPendingBeforeStop=diagnosticPendingBeforeStop,diagnosticPendingAfterStop=TransportCostProbe.Timing?.PendingCount??0,diagnosticCancelledAfterStop=TransportCostProbe.Timing?.CancelledSubmissions??0,\n                frames=count,completions=sampleCount,')
    capture=replace(capture,'                using(var w=new StreamWriter(Path.Combine(directory,"completions.jsonl")))',
        '                using(var w=new StreamWriter(Path.Combine(directory,"diagnostic-completions.jsonl")))for(int i=0;i<diagnosticCount;i++)w.WriteLine(JsonUtility.ToJson(new Sample(diagnosticCompletions[i])));\n                using(var w=new StreamWriter(Path.Combine(directory,"completions.jsonl")))')
    changed[PROJECT/'Assets/ComparisonHarness/GpuCostBaseline.cs']=capture.encode('utf-8')
    builder=(ROOT/'LocalComparison/Review/gpu-cost-baseline-01/instrumentation/prepared/Assets/ComparisonHarness/Editor/GpuCostPlayerBuild.cs').read_text(encoding='utf-8')
    builder=replace(builder,'        importer.SetCompatibleWithPlatform(BuildTarget.StandaloneWindows,false);',
        '        importer.SetCompatibleWithPlatform(BuildTarget.StandaloneWindows,false);\n        importer.SetCompatibleWithPlatform(BuildTarget.StandaloneLinux64,false);\n        importer.SetCompatibleWithPlatform(BuildTarget.StandaloneOSX,false);')
    builder=replace(builder,'            importer.GetCompatibleWithPlatform(BuildTarget.StandaloneWindows)||',
        '            importer.GetCompatibleWithPlatform(BuildTarget.StandaloneWindows)||importer.GetCompatibleWithPlatform(BuildTarget.StandaloneLinux64)||importer.GetCompatibleWithPlatform(BuildTarget.StandaloneOSX)||')
    changed[PROJECT/'Assets/ComparisonHarness/Editor/GpuCostPlayerBuild.cs']=builder.encode('utf-8')
    m={'baseline':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'productSourceSha256':product,
       'builtProductSourceSha256':dict(product),'scene':'Assets/RuntimeAudit/Functional.unity','scope':'temporary additional owner; '+SIDE.name+' side of the single receiver reuse candidate','files':[],'newMetadata':[]}
    OUT.mkdir(parents=True,exist_ok=True)
    for i,(p,data) in enumerate(changed.items()):
        rel=p.relative_to(PROJECT).as_posix();old=p.read_bytes() if p.exists() else None
        if old is not None:(OUT/f'{i}.original').write_bytes(old)
        dest=OUT/'prepared'/rel;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(data);digest=hashlib.sha256(data).hexdigest()
        m['files'].append({'path':rel,'original':f'{i}.original' if old is not None else None,'originalSha256':hashlib.sha256(old).hexdigest() if old is not None else None,'prepared':'prepared/'+rel,'sha256':digest})
        if rel.startswith('Assets/HybridLumenGI/'):
            m['builtProductSourceSha256'][rel.removeprefix('Assets/HybridLumenGI/')]=digest
        if not Path(str(p)+'.meta').exists():m['newMetadata'].append(rel+'.meta')
    save(OUT/'manifest.json',m)
    for name in ['prepare-transport-cost.py','prepare-player-smoke.py','GpuCostBaseline.cs','TransportCostProbe.cs']:
        dest=SIDE/'executed-harness'/(name+'.txt');dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes((H/name).read_bytes())
    print(json.dumps({'baseProductSources':len(product),'instrumentedProductSources':len(m['builtProductSourceSha256']),'temporaryFiles':len(changed)}))
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('action',choices=['prepare','install','restore']);p.add_argument('--side',choices=['locator','candidate'],default='locator');a=p.parse_args()
    SIDE=PACKAGE/a.side;OUT=SIDE/'instrumentation';installer.PACKAGE=SIDE;installer.OUT=OUT
    if a.action=='prepare':prepare()
    else:getattr(installer,a.action)()
