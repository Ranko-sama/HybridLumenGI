"""Compile only the new identity shader observer using matching FXC/SM5.

Three ShaderLab passes differ only by Cull state and use these same entry points.
The eighteen unchanged compute entries retain their prior frozen compilation.
"""
import hashlib
import json
import os
from pathlib import Path
import subprocess

P=Path(__file__).resolve().parent
ROOT=P.parents[2]
STAGE=P/'instrumentation'
OUT=P/'compile-probe'
INC=Path(os.environ['TEMP'])/'HybridLumenGI-shader-validation'
FXC=Path('C:/Program Files (x86)/Windows Kits/10/bin/10.0.26100.0/x64/fxc.exe')
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()


def main():
    assert not OUT.exists(),'Preserve first diagnostic compilation'
    manifest_path=STAGE/'manifest.json'
    manifest=json.loads(manifest_path.read_text())
    rows={row['path']:row for row in manifest['files']}
    shader=STAGE/rows['Assets/HybridLumenGI/Runtime/Resources/HybridLumenGI/HybridLumenGIReceiverIdentity.shader']['prepared']
    observer=STAGE/rows['Assets/CameraMotionTaa01/CameraIdentityDepthDiagnostic.hlsl']['prepared']
    pins={str(manifest_path):sha(manifest_path),str(Path(__file__)):sha(Path(__file__)),str(FXC):sha(FXC)}
    for row in manifest['files']:
        path=STAGE/row['prepared'];assert sha(path)==row['sha256'];pins[str(path)]=sha(path)
    for path in (INC/'Packages').rglob('*'):
        if path.is_file():pins[str(path)]=sha(path)
    raw=shader.read_text()
    assert raw.count('HLSLINCLUDE')==1
    source=raw.split('HLSLINCLUDE',1)[1].split('ENDHLSL',1)[0]
    old='"../../../../CameraMotionTaa01/CameraIdentityDepthDiagnostic.hlsl"'
    assert source.count(old)==1
    source=source.replace(old,'"'+observer.resolve().as_posix()+'"')
    OUT.mkdir();extracted=OUT/'identity-probe.validation.hlsl';extracted.write_text(source,encoding='utf-8')
    pins[str(extracted)]=sha(extracted)
    reuse=json.loads((STAGE/'reuse-source.json').read_text())
    previous=P.parent/'camera-motion-taa-response-02/compile/report.json'
    assert sha(previous)==reuse['originalCompileReportSha256'] and json.loads(previous.read_text())['passed']
    report=dict(passed=False,unityExecuted=False,gpuExecuted=False,compiler='FXC Shader Model 5',
                compilerSha256=sha(FXC),sources=pins,checks=[],
                unchangedComputeEntryCount=18,unchangedComputeCompileReportSha256=sha(previous))
    try:
        for name,entry,profile,stage,debug in [('vertex','HLGIIdentityVertex','vs_5_0','VERTEX',False),
                                             ('fragment','HLGIIdentityFragment','ps_5_0','FRAGMENT',False),
                                             ('fragment-debug','HLGIIdentityFragment','ps_5_0','FRAGMENT',True)]:
            definitions=['SHADER_API_D3D11=1','UNITY_COMPILER_HLSL=1','UNITY_VERSION=600000','SHADER_TARGET=50','SHADER_STAGE_'+stage+'=1']
            if debug:definitions.append('DEBUG_DISPLAY=1')
            command=[str(FXC),'/nologo','/O3','/T',profile,'/E',entry]
            for value in definitions:command+=['/D',value]
            command+=['/I',str(INC),'/Fo',str(OUT/(name+'.dxbc')),'/Fc',str(OUT/(name+'.asm')),str(extracted)]
            result=subprocess.run(command,capture_output=True)
            (OUT/(name+'.log')).write_bytes(result.stdout+result.stderr)
            report['checks'].append(dict(name=name,entry=entry,profile=profile,debug=debug,command=command,exitCode=result.returncode))
            print(name+' exit='+str(result.returncode),flush=True)
        report['passed']=all(row['exitCode']==0 for row in report['checks']) and len(report['checks'])==3
    except Exception as error:report['error']=repr(error)
    finally:
        report['sourcesUnchanged']=all(Path(path).is_file() and sha(Path(path))==digest for path,digest in pins.items())
        report['passed'] &= report['sourcesUnchanged']
        (OUT/'report.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({key:report.get(key) for key in ('passed','sourcesUnchanged','error')}))
    raise SystemExit(0 if report['passed'] else 1)


if __name__=='__main__':main()
