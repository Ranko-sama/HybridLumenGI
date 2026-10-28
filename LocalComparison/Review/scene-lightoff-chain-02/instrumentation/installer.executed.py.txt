"""One combined bounded install/restore. Never runs old experiment installers."""
import argparse,ast,hashlib,json,shutil,subprocess
from pathlib import Path
root=Path(__file__).resolve().parents[2];project=Path('I:/Unity test/Project');assets=project/'Assets'
out=root/'LocalComparison/Review/scene-lightoff-chain-02/instrumentation'
parser=argparse.ArgumentParser();parser.add_argument('action',choices=['prepare','install','restore']);args=parser.parse_args()
sha=lambda b:hashlib.sha256(b).hexdigest()
paths={'feature':assets/'HybridLumenGI/Runtime/HybridLumenGIRendererFeature.cs',
    'transport':assets/'HybridLumenGI/Runtime/Resources/HybridLumenGI/HybridLumenGITransport.hlsl',
    'kernels':assets/'HybridLumenGI/Runtime/Resources/HybridLumenGI/HybridLumenGIKernels.hlsl',
    'wrapper':assets/'HybridLumenGI/Runtime/Resources/HybridLumenGI/HybridLumenGIExactSoftware.compute',
    'capture':assets/'ComparisonHarness/ComparisonCapture.cs'}
asset_paths=['Assets/Comparison/Renderer.asset','Assets/Comparison/Pipeline.asset','Assets/ComparisonScene/Run/Validation.unity','Assets/ThinWallProbe/Static.unity',
    'ProjectSettings/EditorBuildSettings.asset','ProjectSettings/GraphicsSettings.asset','ProjectSettings/QualitySettings.asset','ProjectSettings/ProjectSettings.asset']
helpers={'LightOffCacheWriter.hlsl':'Assets/HybridLumenGI/Runtime/Resources/HybridLumenGI/LightOffCacheWriter.hlsl',
    'GatherTraceWriter.hlsl':'Assets/HybridLumenGI/Runtime/Resources/HybridLumenGI/GatherTraceWriter.hlsl',
    'SceneLightoffTap.cs':'Assets/ComparisonHarness/SceneLightoffTap.cs',
    'LightoffPatchMap.cs':'Assets/ComparisonHarness/LightoffPatchMap.cs',
    'SceneLightoffEditor.cs':'Assets/ComparisonHarness/Editor/SceneLightoffEditor.cs',
    'ThinWallEditor.cs':'Assets/ComparisonHarness/Editor/ThinWallEditor.cs','GatherCacheTap.cs':'Assets/ComparisonHarness/GatherCacheTap.cs'}
if args.action=='restore':
    manifest=json.loads((out/'manifest.json').read_text(encoding='utf-8'))
    for key,path in paths.items():
        assert sha(path.read_bytes())==manifest['files'][key]['instrumentedSha256'],('Changed instrumented source',path)
        path.write_bytes((out/(key+'.original.txt')).read_bytes())
    for index,path in enumerate(asset_paths):
        (project/path).write_bytes((out/f'asset-{index}.original.txt').read_bytes())
    # Restore helper files that already existed. New helpers remain inert, as in prior packages.
    for name,path in helpers.items():
        backup=out/(name+'.original-helper.txt')
        if backup.exists():
            assert sha((project/path).read_bytes())==manifest['helpers'][name]['sha256']
            (project/path).write_bytes(backup.read_bytes())
    result={'restored':{key:sha(path.read_bytes())==manifest['files'][key]['originalSha256'] for key,path in paths.items()},
        'assets':{path:sha((project/path).read_bytes())==manifest['assets'][path] for path in asset_paths}}
    (out/'restoration.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
    assert all(result['restored'].values()) and all(result['assets'].values());print('Original source/assets/existing helpers restored');raise SystemExit

def replace(text,old,new):
    assert text.count(old)==1,(old[:100],text.count(old));return text.replace(old,new)

# Reuse ONLY pure instrumentation functions through AST. No old installer main,
# baseline assertion, backup, mutation or saved instrumented product is executed.
reuse_path=root/'LocalComparison/Harness/prepare-gather-cache.py';tree=ast.parse(reuse_path.read_text(encoding='utf-8'))
functions=[node for node in tree.body if isinstance(node,ast.FunctionDef) and node.name in ['replace','transport','kernels']]
assert len(functions)==3
changes={
    'if(totalWeight<=1e-5) return false;':'if(totalWeight<=1e-5) { result=(HLGICacheEntry)0;return false; }',
    'if(totalWeight<=1e-5) { GCV(121,result.irradiance,result.guide,float4(totalWeight,0,0,0),0,0,0,0);GCU(120,uint4(0,2,0,0));return false; }':
    'if(totalWeight<=1e-5) { result=(HLGICacheEntry)0;GCV(121,result.irradiance,result.guide,float4(totalWeight,0,0,0),0,0,0,0);GCU(120,uint4(0,2,0,0));return false; }'}
hits={k:0 for k in changes}
for function in functions:
    for node in ast.walk(function):
        if isinstance(node,ast.Constant) and isinstance(node.value,str) and node.value in changes:
            hits[node.value]+=1;node.value=changes[node.value]
assert all(count==1 for count in hits.values()),hits
module=ast.fix_missing_locations(ast.Module(body=functions,type_ignores=[]));reused={};exec(compile(module,str(reuse_path),'exec'),reused)

def transport(text):
    text=reused['transport'](text)
    text=replace(text,'float _HLGI_DetailTraceDistance;','float _HLGI_DetailTraceDistance;\n#include "LightOffCacheWriter.hlsl"')
    text=replace(text,'    if(!directKnown ||','    LO_DIRECT(direct,directKnown);\n    if(!directKnown ||')
    text=replace(text,'    uint card=id.x/patches,local=id.x%patches;','    LO_BEGIN(id.x);\n    uint card=id.x/patches,local=id.x%patches;')
    text=replace(text,'    if(!covered) { _HLGI_CacheWrite[id.x]=(HLGICacheEntry)0;return; }',
        '    if(!covered) { _HLGI_CacheWrite[id.x]=(HLGICacheEntry)0;LO_END((HLGICacheEntry)0);return; }')
    text=replace(text,'    if(_HLGI_CacheUpdateMask[id.x]!=0)',
        '    LO_PATCH(surface,e,change,_HLGI_CacheUpdateMask[id.x]);\n    if(_HLGI_CacheUpdateMask[id.x]!=0)')
    text=replace(text,'        HLGICommitCacheEstimate(estimateKnown,sum,guide,guidePower,_HLGI_CacheRays,n,e.irradiance,e.guide);',
        '        LO_ESTIMATE(sum,guide,guidePower,estimateKnown);\n        bool loCommitted=HLGICommitCacheEstimate(estimateKnown,sum,guide,guidePower,_HLGI_CacheRays,n,e.irradiance,e.guide);\n        LO_COMMIT(loCommitted);')
    return replace(text,'    _HLGI_CacheWrite[id.x]=e;','    _HLGI_CacheWrite[id.x]=e;LO_END(e);')

def feature(text):
    text=replace(text,'                    Copy(work,data);',
        '                    Copy(work,data);\n                    if(global::SceneLightoffTap.Enabled)builder.UseBuffer(graph.ImportBuffer(global::SceneLightoffTap.Records),AccessFlags.ReadWrite);\n                    if(global::GatherCacheTap.Enabled)builder.UseBuffer(graph.ImportBuffer(global::GatherCacheTap.Records),AccessFlags.ReadWrite);')
    text=replace(text,'                int count=worldLights.Update(Time.frameCount,useRenderingLayers,state.lightData,Mathf.Clamp(s.maxLights,1,32),',
        '                if(global::SceneLightoffTap.Enabled)global::SceneLightoffTap.Lights(state,"before-update",state.previousLightCount);\n                int count=worldLights.Update(Time.frameCount,useRenderingLayers,state.lightData,Mathf.Clamp(s.maxLights,1,32),')
    text=replace(text,'                foreach(var changed in state.lightChanges) AddLightChange(state,changed);',
        '                foreach(var changed in state.lightChanges) AddLightChange(state,changed);\n                if(global::SceneLightoffTap.Enabled)global::SceneLightoffTap.Lights(state,"after-update",count);')
    text=replace(text,'                state.changes.Upload();',
        '                state.changes.Upload();\n                if(global::SceneLightoffTap.Enabled)global::SceneLightoffTap.Lights(state,"uploaded-domains",lightCount);')
    text=replace(text,'                    state.lightingChanged,Mathf.Max(s.shadowDistance,s.traceDistance)+Mathf.Max(1,s.traceDistance));',
        '                    state.lightingChanged,Mathf.Max(s.shadowDistance,s.traceDistance)+Mathf.Max(1,s.traceDistance));\n                if(global::SceneLightoffTap.Enabled)global::SceneLightoffTap.Scheduled(state,d.frame,d.cacheRead,Mathf.Clamp(d.cachePatchBudget,1,state.cacheEntryCount),Mathf.Max(s.shadowDistance,s.traceDistance)+Mathf.Max(1,s.traceDistance));')
    text=replace(text,'                    cmd.DispatchCompute(c,update,(state.cacheEntryCount+63)/64,1,1);',
        '                    if(global::SceneLightoffTap.Enabled)global::SceneLightoffTap.Begin(cmd,c,update,state,d.frame,d.cacheRead,d.lightCount,areaReady?d.areaLayout.Count:0,state.exactSoftwareGeometry);\n                    cmd.DispatchCompute(c,update,(state.cacheEntryCount+63)/64,1,1);\n                    if(global::SceneLightoffTap.Enabled)global::SceneLightoffTap.AfterCache(cmd,state,d.frame,1-d.cacheRead);')
    text=replace(text,'                using(d.frameTiming.Profile(cmd,"HLGI Gather")) Dispatch(cmd,c,trace,state);',
        '                if(global::GatherCacheTap.Enabled)global::GatherCacheTap.Begin(cmd,c,trace,state.camera,d.frame,state.exactSoftwareGeometry);\n                using(d.frameTiming.Profile(cmd,"HLGI Gather")) Dispatch(cmd,c,trace,state);\n                if(global::GatherCacheTap.Enabled)global::GatherCacheTap.Read(cmd,((RTHandle)d.raw).rt,state,state.camera,d.frame,d.invVP);\n                if(global::SceneLightoffTap.Enabled)global::SceneLightoffTap.Texture(cmd,((RTHandle)d.raw).rt,state.camera,d.frame,"raw");')
    text=replace(text,'                using(d.frameTiming.Profile(cmd,"HLGI Temporal")) Dispatch(cmd,c,temporal,state);',
        '                using(d.frameTiming.Profile(cmd,"HLGI Temporal")) Dispatch(cmd,c,temporal,state);\n                if(global::SceneLightoffTap.Enabled)global::SceneLightoffTap.Texture(cmd,((RTHandle)d.historyWrite).rt,state.camera,d.frame,"history");')
    text=replace(text,'                state.readiness.Record(cmd,state.scene,state.sdf,state.surfaceCache,state.cache[1-d.cacheRead],state.patchGrid,d.epoch,d.frame);',
        '                if(global::SceneLightoffTap.Enabled)global::SceneLightoffTap.Texture(cmd,((RTHandle)(s.filterIterations<=0?d.historyWrite:(Mathf.Clamp(s.filterIterations,0,4)%2==1?d.tempA:d.tempB))).rt,state.camera,d.frame,"filtered");\n                state.readiness.Record(cmd,state.scene,state.sdf,state.surfaceCache,state.cache[1-d.cacheRead],state.patchGrid,d.epoch,d.frame);')
    return text

def capture(text):
    text=replace(text,'        appliedEngine = Time.frameCount;','        appliedEngine = Time.frameCount;\n        if(SceneLightoffTap.Enabled){SceneLightoffTap.Apply(this,logicalFrame,doorOrigin);return;}')
    text=replace(text,'        logicalFrame++; receipt = false; Apply();',
        '        if(logicalFrame==119&&SceneLightoffTap.Enabled){try{SceneLightoffTap.Gate119();}catch(Exception e){Fail(e.ToString());Finish(false);return;}}\n        logicalFrame++; receipt = false; Apply();')
    text=replace(text,'    static bool CaptureAt(int n) => n % 30 == 0',
        '    static bool CaptureAt(int n) => SceneLightoffTap.Enabled ? SceneLightoffTap.Wants(n) : n % 30 == 0')
    text=replace(text,'            for (int i = 0; i < lights.Length; i++) { var l = lights[i];',
        '            if(SceneLightoffTap.Enabled)f.stage=logicalFrame<120?"lightoff-source-on":"lightoff-source-off";\n            for (int i = 0; i < lights.Length; i++) { var l = lights[i];')
    text=replace(text,'            if (pending) { readback.WaitForCompletion();',
        '            try{SceneLightoffTap.Finish(collected);}catch(Exception e){Fail("Light-off observer close: "+e);}\n            try{GatherCacheTap.Finish(collected);}catch(Exception e){Fail("Gather observer close: "+e);}\n            if (pending) { readback.WaitForCompletion();')
    return text

out.mkdir(parents=True,exist_ok=True)
assert not (out/'installed.json').exists(),'Installed once; do not overwrite or repeat an experiment'
head=subprocess.run(['git','rev-parse','HEAD'],capture_output=True,text=True,check=True).stdout.strip();assert head.startswith('c50ec78')
manifest={'baseline':head,'files':{},'assets':{},'helpers':{},'productSourceSha256':{},'gatherFunctionSourceSha256':sha(reuse_path.read_bytes())}
for source in (root/'Runtime').rglob('*'):
    if source.suffix not in ['.cs','.hlsl','.compute','.shader']:continue
    relative=source.relative_to(root);assert source.read_bytes()==(assets/'HybridLumenGI'/relative).read_bytes(),str(relative)
    manifest['productSourceSha256'][str(relative)]=sha(source.read_bytes())
prepared={}
for key,path in paths.items():
    original=path.read_bytes();text=original.decode('utf-8').replace('\r\n','\n')
    if key=='transport':text=transport(text)
    elif key=='kernels':text=reused['kernels'](text)
    elif key=='feature':text=feature(text)
    elif key=='capture':text=capture(text)
    else:
        text=replace(text,'#pragma kernel CSUpdateCache','#pragma kernel CSUpdateCache HLGI_LIGHTOFF_AUDIT')
        text=replace(text,'#pragma kernel CSTrace','#pragma kernel CSTrace HLGI_GATHER_AUDIT')
    data=text.replace('\n','\r\n' if b'\r\n' in original else '\n').encode('utf-8')
    backup=out/(key+'.original.txt');assert not backup.exists() or backup.read_bytes()==original
    backup.write_bytes(original);(out/(key+'.instrumented.txt')).write_bytes(data);prepared[path]=data
    manifest['files'][key]={'path':str(path),'originalSha256':sha(original),'instrumentedSha256':sha(data)}
for index,path in enumerate(asset_paths):
    data=(project/path).read_bytes();backup=out/f'asset-{index}.original.txt';assert not backup.exists() or backup.read_bytes()==data
    backup.write_bytes(data);manifest['assets'][path]=sha(data)
for name,path in helpers.items():
    destination=project/path;data=(root/'LocalComparison/Harness'/name).read_bytes()
    if name=='GatherCacheTap.cs':
        text=data.decode('utf-8');text=replace(text,'{0,1,3,7,15,31,63,95,119}','{119,120,121,123,127,135,151,239,359}')
        # A selected event request owns completion before binding the private UAV.
        text=replace(text,'        cmd.SetComputeIntParam(shader,"_GC_Enabled",selected?1:0);','        if(selected)pending++;\n        cmd.SetComputeIntParam(shader,"_GC_Enabled",selected?1:0);')
        text=replace(text,'        pending++;cmd.RequestAsyncReadback(Records,request=>{try{','        cmd.RequestAsyncReadback(Records,request=>{try{')
        # In this combined package the earlier cache observation also owns each
        # frame's command recording; an exception must not release either UAV.
        text=replace(text,'if(pending==0){records?.Dispose();records=null;}','if(pending==0&&SceneLightoffTap.CompletionProven){records?.Dispose();records=null;}')
        data=text.encode('utf-8')
    backup=out/(name+'.original-helper.txt')
    if destination.exists():assert not backup.exists() or backup.read_bytes()==destination.read_bytes();backup.write_bytes(destination.read_bytes())
    (out/(name+'.executed.txt')).write_bytes(data);prepared[destination]=data
    manifest['helpers'][name]={'path':str(destination),'sha256':sha(data),'existed':destination.exists()}
(out/'gather-adapters.resolved.py.txt').write_text(ast.unparse(module),encoding='utf-8')
(out/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
(out/'installer.executed.py.txt').write_bytes(Path(__file__).read_bytes())
if args.action=='install':
    for path,data in prepared.items():path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(data)
    (out/'installed.json').write_text(json.dumps({'baseline':head,'installedFiles':len(prepared)}),encoding='utf-8')
print(json.dumps({'action':args.action,'baseline':head,'temporaryFiles':len(prepared),'RuntimeEdited':False}))
