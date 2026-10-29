"""Compile every staged compute entry affected by the guarded observer include.

No Unity, GPU execution, deployment, product edits, or repeated compilation of
unchanged transport entries. Preserve the first diagnostics and immutable inputs.
"""
import hashlib
import json
import os
from pathlib import Path
import subprocess

P=Path(__file__).resolve().parent
ROOT=P.parents[2]
STAGE=P/'instrumentation'
OUT=P/'compile'
INC=Path(os.environ['TEMP'])/'HybridLumenGI-shader-validation'
DXC=Path('C:/Program Files (x86)/Windows Kits/10/bin/10.0.26100.0/x64/dxc.exe')
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()

def main():
    assert not OUT.exists(),'Preserve the first observer compilation'
    manifest_path=STAGE/'manifest.json'
    manifest=json.loads(manifest_path.read_text(encoding='utf-8'))
    pins={str(manifest_path):sha(manifest_path),str(Path(__file__)):sha(Path(__file__)),str(DXC):sha(DXC)}
    for rel,digest in manifest['productSourceSha256'].items():
        source=ROOT/rel;assert sha(source)==digest;pins[str(source)]=digest
    for row in manifest['files']:
        source=STAGE/row['prepared'];assert sha(source)==row['sha256'];pins[str(source)]=row['sha256']
    adapter=INC/'Adapters/UnityRayQuery.cginc'
    assert sha(adapter)==sha(ROOT/'Tests/ShaderAdapters/UnityRayQuery.cginc.txt'),'RayQuery adapter differs'
    for folder in ('Packages','Adapters'):
        for source in (INC/folder).rglob('*'):
            if source.is_file():pins[str(source)]=sha(source)
    OUT.mkdir()
    report=dict(passed=False,unityExecuted=False,gpuExecuted=False,compilerSha256=sha(DXC),
                sources=pins,checks=[])
    try:
        for name,profile in [('HybridLumenGI','cs_6_0'),('HybridLumenGIHardware','cs_6_5'),('HybridLumenGIExactSoftware','cs_6_0')]:
            source=STAGE/'prepared/Assets/HybridLumenGI/Runtime/Resources/HybridLumenGI'/(name+'.compute')
            for entry,identity in [('CSUpdateCache',False),('CSTrace',False),('CSTemporal',False),('CSFilter',False),('CSTemporalIdentity',True),('CSCameraMotionTaaCopy',True)]:
                macros=['-D','HLGI_RECEIVER_IDENTITY=1'] if identity else []
                command=[str(DXC),'-O3','-T',profile,'-E',entry,*macros,
                    '-D','SHADER_API_D3D11=1','-D','SHADER_STAGE_COMPUTE=1','-D','UNITY_COMPILER_DXC=1','-D','UNITY_VERSION=600000',
                    '-I',str(INC/'Adapters'),'-I',str(INC),'-I',str(ROOT/'Runtime/Resources/HybridLumenGI'),
                    '-Fo',str(OUT/(name+'-'+entry+'.dxil')),str(source)]
                completed=subprocess.run(command,capture_output=True)
                (OUT/(name+'-'+entry+'.log')).write_bytes(completed.stdout+completed.stderr)
                report['checks'].append(dict(name=name,entry=entry,identityMacro=identity,profile=profile,command=command,exitCode=completed.returncode))
                print(name+' '+entry+' identity='+str(identity)+' exit='+str(completed.returncode),flush=True)
        report['passed']=len(report['checks'])==18 and all(row['exitCode']==0 for row in report['checks'])
    except Exception as error:
        report['error']=repr(error)
    finally:
        report['sourcesUnchanged']=all(Path(path).is_file() and sha(Path(path))==digest for path,digest in pins.items())
        report['passed']=report['passed'] and report['sourcesUnchanged']
        (OUT/'report.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({key:report.get(key) for key in ('passed','sourcesUnchanged','error')}))
    raise SystemExit(0 if report['passed'] else 1)

if __name__=='__main__':main()
