"""Stage narrow original-operation observers; restore every modified project file."""
import argparse,hashlib,importlib.util,json,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];H=ROOT/'LocalComparison/Harness';PROJECT=Path('I:/Unity test/Project')
PACKAGE=ROOT/'LocalComparison/Review/asset-page-inflight-withdrawal-01';OUT=PACKAGE/'instrumentation'
spec=importlib.util.spec_from_file_location('base',H/'prepare-player-smoke.py');base=importlib.util.module_from_spec(spec);spec.loader.exec_module(base)
base.PACKAGE=PACKAGE;base.OUT=OUT;replace=base.replace;sha=base.sha
def prepare():
    assert not (OUT/'installed.json').exists()
    frozen=json.loads((PACKAGE/'input.json').read_text(encoding='utf-8'))
    for f in frozen['files']:assert sha(PROJECT/f['path'])==f['sha256'],'Frozen input changed'
    product={p.relative_to(ROOT).as_posix():sha(p) for top in ['Runtime','Editor'] for p in (ROOT/top).rglob('*') if p.is_file() and p.suffix!='.meta'}
    assert all(sha(PROJECT/'Assets/HybridLumenGI'/p)==v for p,v in product.items())
    changed={}
    def put(path,text):changed[PROJECT/'Assets'/path]=text.encode('utf-8')
    entry=(PROJECT/'Assets/ComparisonHarness/RuntimeAuditEntry.cs').read_text(encoding='utf-8')
    entry=replace(entry,'if(Arg("-auditScene","functional")=="streaming"','if(!PageWithdrawalMode.Requested && Arg("-auditScene","functional")=="streaming"')
    entry=replace(entry,'        capture.totalFrames=720;', '''        if(PageWithdrawalMode.Requested)
        {
            try{PageWithdrawalMode.Configure(capture);}
            catch(Exception e){Directory.CreateDirectory(capture.outputRoot);File.WriteAllText(Path.Combine(capture.outputRoot,"preparation-failure.txt"),e.ToString());Debug.LogException(e);Application.Quit(1);}
            return;
        }
        capture.totalFrames=720;''')
    put('ComparisonHarness/RuntimeAuditEntry.cs',entry)
    streamer=(ROOT/'Runtime/HybridLumenGIAssetPageStreamer.cs').read_text(encoding='utf-8')
    streamer=replace(streamer,'            State.Step(budgets);','''            if(PageWithdrawalTap.Active){PageWithdrawalTap.Tick++;PageWithdrawalTap.Snapshot("step-before",State);}
            State.Step(budgets);
            PageWithdrawalTap.Snapshot("step-after",State);''')
    streamer=replace(streamer,'        public bool SetRequests(','''        internal PageWithdrawalTap.Row PageWithdrawalCheck()
        {
            foreach(var state in State.States)
                if(state.Status==HybridLumenGIAssetPageStreaming.Phase.LoadingAsset && state.operation is AssetLoad load)
                {
                    var receipt=new PageWithdrawalTap.Row{stage="native-asset-check-link",page=state.Id,state=PageWithdrawalTap.Describe(state),operation=PageWithdrawalTap.Id(load),native=PageWithdrawalTap.Id(load.request)};
                    receipt.done=load.request.isDone; // Last operation: no serialization/IO before the caller's immediate removal.
                    return receipt;
                }
            return null;
        }
        public bool SetRequests(''')
    # Only AssetLoad's field visibility changes for the narrow native check.
    streamer=replace(streamer,'            private readonly AssetBundleRequest request;','            internal readonly AssetBundleRequest request;')
    streamer=replace(streamer,'new BundleLoad(request):throw','PageWithdrawalTap.Start(new BundleLoad(request),request,definition,"bundle-start"):throw')
    streamer=replace(streamer,'new AssetLoad(request,type):throw','PageWithdrawalTap.Start(new AssetLoad(request,type),request,definition,"asset-start"):throw')
    streamer=replace(streamer,'=> new Release((BundleHandle)bundle,asset as UnityEngine.Object);',
        '=> PageWithdrawalTap.Start(new Release((BundleHandle)bundle,asset as UnityEngine.Object),null,definition,"release-start");')
    streamer=replace(streamer,'handle.unload=handle.bundle.UnloadAsync(false);handle.unloadStarted=true;',
        'handle.unload=handle.bundle.UnloadAsync(false);handle.unloadStarted=true;PageWithdrawalTap.ReleaseCall("unload-async-start",this,handle.unload,asset);')
    streamer=replace(streamer,'if(handle.unload!=null && !handle.unload.isDone)return false;',
        'if(handle.unload!=null){bool completed=handle.unload.isDone;PageWithdrawalTap.Write(new PageWithdrawalTap.Row{stage="unload-async-poll",operation=PageWithdrawalTap.Id(this),native=PageWithdrawalTap.Id(handle.unload),done=completed});if(!completed)return false;}')
    streamer=replace(streamer,'if(asset!=null)Resources.UnloadAsset(asset);',
        'if(asset!=null){PageWithdrawalTap.ReleaseCall("unload-asset-before",this,null,asset);Resources.UnloadAsset(asset);PageWithdrawalTap.ReleaseCall("unload-asset-returned",this,null,null);}')
    put('HybridLumenGI/Runtime/HybridLumenGIAssetPageStreamer.cs',streamer)
    scheduler=(ROOT/'Runtime/HybridLumenGIAssetPageStreaming.cs').read_text(encoding='utf-8')
    scheduler=replace(scheduler,'            foreach(var state in states)Poll(state);',
        '            foreach(var state in states){PageWithdrawalTap.PageEvent("poll-before",state);Poll(state);PageWithdrawalTap.PageEvent("poll-after",state);}')
    scheduler=replace(scheduler,'done=state.operation.IsDone;if(!done)return;error=state.operation.Error;result=state.operation.Result;',
        'done=state.operation.IsDone;PageWithdrawalTap.PageEvent("poll-done",state,done);if(!done)return;error=state.operation.Error;result=state.operation.Result;PageWithdrawalTap.PageEvent("poll-result",state,done,error,result);')
    put('HybridLumenGI/Runtime/HybridLumenGIAssetPageStreaming.cs',scheduler)
    for name,dest in [('PageWithdrawalTap.cs','HybridLumenGI/Runtime'),('PageWithdrawalMode.cs','ComparisonHarness')]:put(dest+'/'+name,(H/name).read_text(encoding='utf-8'))
    build=(H/'CurrentPlayerBuild.cs').read_text(encoding='utf-8').replace('Assets/RuntimeAudit/Functional.unity','Assets/RuntimeAudit/Streaming.unity')
    build=replace(build,'!UnityEngine.Object.FindFirstObjectByType<RuntimeAuditProbe>()','!UnityEngine.Object.FindFirstObjectByType<StreamingAuditProbe>()')
    build=replace(build,'        var projectSettings=', '''        var frozen=JsonUtility.FromJson<PageWithdrawalMode.Input>(File.ReadAllText("Assets/StreamingAssets/PageWithdrawalInput.json"));
        foreach(var page in frozen.pages)
        {
            string path=Path.Combine("Assets/StreamingAssets",frozen.relativeRoot,page.bundlePath);
            if(!BuildPipeline.GetCRCForAssetBundle(path,out uint actualCrc) || actualCrc!=page.crc || Hash(File.ReadAllBytes(path))!=page.sha256)
                throw new Exception("Frozen bundle CRC/hash mismatch: "+page.id);
        }
        File.WriteAllText(Path.Combine(Path.GetDirectoryName(receipt),"build-crc.json"),"{\\"sixFrozenBundleCrcsVerified\\":true}");
        var projectSettings=''')
    build=replace(build,'        var paths=readable.Concat(', '        var paths=Directory.GetFiles("Assets/StreamingAssets","*",SearchOption.AllDirectories).Concat(readable).Concat(')
    put('ComparisonHarness/Editor/CurrentPlayerBuild.cs',build)
    put('StreamingAssets/PageWithdrawalInput.json',(PACKAGE/'input.json').read_text(encoding='utf-8'))
    OUT.mkdir(parents=True,exist_ok=True)
    m={'baseline':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'productSourceSha256':product,
       'scene':frozen['scene'],'scope':'one pending native asset withdrawal, no leases/render binding','files':[],'newMetadata':[]}
    for i,(path,data) in enumerate(changed.items()):
        rel=path.relative_to(PROJECT).as_posix();old=path.read_bytes() if path.exists() else None
        if old is not None:(OUT/f'{i}.original').write_bytes(old)
        target=OUT/'prepared'/rel;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(data)
        m['files'].append({'path':rel,'original':f'{i}.original' if old is not None else None,'originalSha256':hashlib.sha256(old).hexdigest() if old is not None else None,'prepared':'prepared/'+rel,'sha256':hashlib.sha256(data).hexdigest()})
        meta=Path(str(path)+'.meta')
        if not meta.exists():m['newMetadata'].append(meta.relative_to(PROJECT).as_posix())
    (OUT/'manifest.json').write_text(json.dumps(m,indent=2),encoding='utf-8')
    (OUT/'installer.executed.py.txt').write_bytes(Path(__file__).read_bytes());print(json.dumps({'staged':len(changed),'productSources':len(product)}))
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('action',choices=['prepare','install','restore']);a=p.parse_args()
    if a.action=='prepare':prepare()
    else:getattr(base,a.action)()
