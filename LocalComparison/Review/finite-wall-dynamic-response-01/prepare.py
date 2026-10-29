"""Stage a finite temporal observation; reuse the isolated scene/restore owner."""
import importlib.util
import json
import sys
from pathlib import Path

P=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('finite_dynamic_base',P.parent/'finite-wall-color-reference-01/prepare.py')
base=importlib.util.module_from_spec(spec);spec.loader.exec_module(base)
base.P=P;base.OUT=P/'instrumentation'
ROOT=base.ROOT;OUT=base.OUT

def once(data,old,new):
    assert data.count(old)==1,(old[:100],data.count(old))
    return data.replace(old,new)

def prepare():
    base.prepare()
    manifest=base.load(OUT/'manifest.json')
    # Replace the unused single-frame host/tap/sampler by the compact sequence.
    kept=[]
    for row in manifest['files']:
        if row['path'].startswith('Assets/FiniteWallReference01/'):
            staged=OUT/row['prepared'];assert staged.resolve().is_relative_to(OUT.resolve());staged.unlink()
        else:kept.append(row)
    manifest['files']=kept
    def stage(rel,data):
        target=base.PROJECT/rel
        row=next((r for r in manifest['files'] if r['path']==rel),None)
        if row is None:
            original='original/'+rel if target.exists() else None
            if original:
                backup=OUT/original;backup.parent.mkdir(parents=True,exist_ok=True);backup.write_bytes(target.read_bytes())
            row=dict(path=rel,original=original,originalSha256=base.sha(target) if target.exists() else None,prepared='prepared/'+rel)
            manifest['files'].append(row)
        path=OUT/row['prepared'];path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(data);row['sha256']=base.sha(path)
    feature=(ROOT/base.FEATURE).read_bytes();nl=b'\r\n' if b'\r\n' in feature else b'\n'
    anchor=b'                using(d.frameTiming.Profile(cmd,"HLGI Temporal")) Dispatch(cmd,c,temporal,state);'
    call=b'                global::FiniteWallDynamicTap.Record(cmd,c,((RTHandle)d.raw).rt,((RTHandle)d.historyWrite).rt,((RTHandle)d.momentsWrite).rt,((RTHandle)d.historyRead).rt,((RTHandle)d.momentsRead).rt,((RTHandle)d.geometryWrite).rt,((RTHandle)d.geometryRead).rt,((RTHandle)d.materialWrite).rt,((RTHandle)d.materialRead).rt,((RTHandle)d.motion).rt,state.changes,state.camera,d.frame,d.lightCount,d.invVP,d.vp,d.previousVP,d.previousInvVP,d.view,d.jitterDelta,d.valid,d.hasMotion);'
    stage('Assets/HybridLumenGI/'+base.FEATURE,once(feature,anchor,anchor+nl+call))
    for name in ('HybridLumenGI.compute','HybridLumenGIHardware.compute','HybridLumenGIExactSoftware.compute'):
        rel='Runtime/Resources/HybridLumenGI/'+name;source=(ROOT/rel).read_bytes();newline=b'\r\n' if b'\r\n' in source else b'\n'
        data=b'#pragma kernel CSFiniteWallDynamicCopy'+newline+source+newline+b'#include "../../../../FiniteWallReference01/FiniteWallDynamicCopy.hlsl"'+newline
        stage('Assets/HybridLumenGI/'+rel,data)
    harness=ROOT/'LocalComparison/Harness'
    for name in ('FiniteWallDynamicScene.cs','FiniteWallDynamicTap.cs','FiniteWallDynamicCopy.hlsl'):
        stage('Assets/FiniteWallReference01/'+name,(harness/name).read_bytes())
    editor=(harness/'FiniteWallReferenceEditor.cs').read_text(encoding='utf-8')
    editor=editor.replace('FiniteWallReferenceEditor','FiniteWallDynamicEditor').replace('FiniteWallReferenceScene','FiniteWallDynamicScene')
    editor=once(editor,'temporalAccumulation=false,maxHistory=1','temporalAccumulation=true,maxHistory=32')
    stage('Assets/FiniteWallReference01/Editor/FiniteWallDynamicEditor.cs',editor.encode('utf-8'))
    manifest['scope']='96 actual temporal dispatches; compact data-only copy after Temporal; ordinary MPB event32 and directional off64; no product arithmetic replacement'
    base.save(OUT/'manifest.json',manifest)
    base.save(OUT/'harness-source.json',{name:base.sha(harness/name) for name in ('FiniteWallReferenceEditor.cs','FiniteWallDynamicScene.cs','FiniteWallDynamicTap.cs','FiniteWallDynamicCopy.hlsl')})
    dependencies=[P/'analyze.py',P/'contract.txt',ROOT/'LocalComparison/Reference/ColorBounceRectangle/qualify_native_inputs.py',ROOT/'LocalComparison/Reference/ColorBounceRectangle/decode_sampler.py']
    base.save(OUT/'analysis-source.json',{path.relative_to(ROOT).as_posix():base.sha(path) for path in dependencies})
    print(json.dumps(dict(stagedFiles=len(manifest['files']),executeMethod='FiniteWallDynamicEditor.Run',frames=96)))

if __name__=='__main__':
    assert sys.argv[1] in ('prepare','preflight','install','restore')
    (prepare if sys.argv[1]=='prepare' else getattr(base,sys.argv[1]))()
