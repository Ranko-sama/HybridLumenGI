"""Iteration67: reuse63's two-assembly preflight once, with a fresh runtime ref.
Preparation only until explicitly invoked; no deployment or Unity launch here.
"""
import hashlib, importlib.util, json, subprocess, traceback
from pathlib import Path
from types import SimpleNamespace

PACKAGE=Path(__file__).resolve().parent
ROOT=PACKAGE.parents[2]
PROJECT=Path('I:/Unity test/Project')
EDITOR=Path('I:/Unity test/Editor/6000.0.85f1/Editor/Data')
STAGE=PACKAGE/'instrumentation'
DEST=PACKAGE/'preflight'
PRIOR=ROOT/'LocalComparison/Review/static-hdr-environment-cubemap-01/prepare.py'
sha=lambda path:hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    assert not DEST.exists(),'One managed preflight only; existing evidence must not be overwritten'
    manifest_path=STAGE/'manifest.json'
    manifest=json.loads(manifest_path.read_text(encoding='utf-8-sig'))
    pins={};calls=[];status=1;error=None
    def pin(path,expected=None):
        path=path.resolve();value=sha(path)
        if expected is not None:assert value==expected,'Staged/deployed identity differs: '+str(path)
        assert str(path) not in pins or pins[str(path)]==value,'Input changed: '+str(path)
        pins[str(path)]=value
    def unchanged():
        for path,value in pins.items():assert sha(Path(path))==value,'Input changed: '+path
    pin(manifest_path);pin(PRIOR);pin(Path(__file__))
    for row in manifest['files']:pin(STAGE/row['prepared'],row['sha256'])
    for relative,value in manifest['productSourceSha256'].items():
        pin(ROOT/relative,value);pin(PROJECT/'Assets/HybridLumenGI'/relative,value)
    for name in ['Assembly-CSharp','Assembly-CSharp-Editor']:
        pin(PROJECT/('Library/Bee/artifacts/1900b0aE.dag/'+name+'.rsp'))
    pin(EDITOR/'NetCoreRuntime/dotnet.exe');pin(EDITOR/'DotNetSdkRoslyn/csc.dll')
    spec=importlib.util.spec_from_file_location('iteration63_preflight_reuse',PRIOR)
    prior=importlib.util.module_from_spec(spec);spec.loader.exec_module(prior)
    prior.PACKAGE=PACKAGE;prior.OUT=STAGE;prior.PROJECT=PROJECT;prior.EDITOR=EDITOR

    def compile_once(arguments,**kwargs):
        rsp=Path(arguments[-1][1:]);assembly=rsp.stem
        assert assembly==['Assembly-CSharp','Assembly-CSharp-Editor'][len(calls)],'Unexpected compiler invocation'
        text=rsp.read_text(encoding='utf-8')
        if assembly.endswith('-Editor'):
            #63 already redirects the runtime reference;67 uses its new reference assembly.
            old='-r:"'+(DEST/'Assembly-CSharp.dll').as_posix()+'"'
            new='-r:"'+(DEST/'Assembly-CSharp.ref.dll').as_posix()+'"'
            assert text.count(old)==1 and (DEST/'Assembly-CSharp.ref.dll').is_file()
            text=text.replace(old,new);rsp.write_text(text,encoding='utf-8')
            pin(DEST/'Assembly-CSharp.ref.dll')
        for line in text.splitlines():
            source=line.strip('"')
            if source.endswith('.cs'):pin(PROJECT/source)
        pin(rsp);unchanged()
        entry=dict(assembly=assembly,arguments=list(map(str,arguments)),responseSha256=sha(rsp))
        calls.append(entry)
        result=subprocess.run(arguments,**kwargs)
        (DEST/(assembly+'.log')).write_bytes(result.stdout+result.stderr)
        entry['exitCode']=result.returncode
        for suffix in ['.dll','.ref.dll']:
            artifact=DEST/(assembly+suffix)
            if artifact.exists():entry[artifact.name+'Sha256']=sha(artifact)
        (DEST/'commands.json').write_text(json.dumps(calls,indent=2))
        unchanged();return result

    # Reuse the actual63 response rewriting, stale-source removal, logs and first-failure exit.
    prior.subprocess=SimpleNamespace(run=compile_once)
    try:
        prior.preflight()
    except SystemExit as completion:
        status=int(completion.code or 0)
        if status==0:assert len(calls)==2 and all(row['exitCode']==0 for row in calls)
    except Exception:
        error=traceback.format_exc()
    finally:
        try:unchanged()
        except Exception:status=1;error=(error or '')+traceback.format_exc()
        if DEST.exists():
            (DEST/'identity.json').write_text(json.dumps(dict(exitCode=status,error=error,
                reusedPreflight=str(PRIOR),stagedManifestSha256=pins[str(manifest_path.resolve())],
                inputs=[dict(path=p,sha256=v) for p,v in sorted(pins.items())],commands=calls,
                editorRuntimeReference=str(DEST/'Assembly-CSharp.ref.dll')),indent=2))
    if error:print(error)
    print(json.dumps(dict(exitCode=status,assemblies=[row['assembly'] for row in calls])))
    raise SystemExit(status)


if __name__=='__main__':main()
