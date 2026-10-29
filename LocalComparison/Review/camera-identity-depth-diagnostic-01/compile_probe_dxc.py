"""Bounded DXC development preflight of the unchanged identity probe shader.

Use the existing receiver-identity validation command model, not a claim that
standalone FXC reproduces Unity's shader preprocessing. Preserve the FXC failure.
"""
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess

P=Path(__file__).resolve().parent
ROOT=P.parents[2]
STAGE=P/'instrumentation'
FIRST=P/'compile-probe'
OUT=P/'compile-probe-02'
CACHE=Path('I:/Unity test/Project/Library/PackageCache')
OLD_INCLUDE=Path(os.environ['TEMP'])/'HybridLumenGI-shader-validation/Packages'
DXC=Path('C:/Program Files (x86)/Windows Kits/10/bin/10.0.26100.0/x64/dxc.exe')
BASIS=ROOT/'Tests/Validate-ReceiverIdentityShaders.ps1'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()


def main():
    assert not OUT.exists(),'Preserve the first corrected preflight'
    manifest_path=STAGE/'manifest.json';manifest=json.loads(manifest_path.read_text())
    rows={row['path']:row for row in manifest['files']}
    shader=STAGE/rows['Assets/HybridLumenGI/Runtime/Resources/HybridLumenGI/HybridLumenGIReceiverIdentity.shader']['prepared']
    observer=STAGE/rows['Assets/CameraMotionTaa01/CameraIdentityDepthDiagnostic.hlsl']['prepared']
    first=json.loads((FIRST/'report.json').read_text())
    assert first['passed'] is False and first['sourcesUnchanged'] is True and len(first['checks'])==3
    pins={str(path):sha(path) for path in (manifest_path,Path(__file__),DXC,BASIS,FIRST/'report.json',P/'compile_probe.py')}
    for path in FIRST.iterdir():
        if path.is_file():pins[str(path)]=sha(path)
    for row in manifest['files']:
        path=STAGE/row['prepared'];assert sha(path)==row['sha256'];pins[str(path)]=sha(path)
    OUT.mkdir();include_root=OUT/'includes';include_rows=[];skipped=[]
    for cached in sorted(OLD_INCLUDE.rglob('*')):
        if not cached.is_file():continue
        relative=cached.relative_to(OLD_INCLUDE);packages=list(CACHE.glob(relative.parts[0]+'@*'))
        actual=packages[0].joinpath(*relative.parts[1:]) if len(packages)==1 else None
        if actual is None or not actual.is_file():
            skipped.append(dict(relative=relative.as_posix(),previousCacheSha256=sha(cached),reason='No installed package source'))
            continue
        metadata=packages[0]/'package.json';version=json.loads(metadata.read_text())['version']
        pins[str(actual)]=sha(actual);pins[str(metadata)]=sha(metadata)
        copied=include_root/'Packages'/relative;copied.parent.mkdir(parents=True,exist_ok=True);copied.write_bytes(actual.read_bytes())
        assert sha(copied)==sha(actual);pins[str(copied)]=sha(copied)
        include_rows.append(dict(relative=relative.as_posix(),actualSource=str(actual),copied=str(copied),version=version,
                                 actualSha256=sha(actual),previousCacheSha256=sha(cached),previousCacheIdentical=sha(cached)==sha(actual)))
    assert len(include_rows)==67 and len(skipped)==1
    assert skipped[0]['relative']=='com.unity.visualeffectgraph/Shaders/VFXMatricesOverride.hlsl'
    assert all(row['version']==('17.0.3' if row['relative'].startswith('com.unity.render-pipelines.universal-config/') else '17.0.4') for row in include_rows)
    assert [row['relative'] for row in include_rows if not row['previousCacheIdentical']]==['com.unity.render-pipelines.universal/ShaderLibrary/GlobalIllumination.hlsl']
    (OUT/'include-sources.json').write_text(json.dumps(dict(copied=include_rows,skipped=skipped),indent=2)+'\n')
    source=shader.read_text().split('HLSLINCLUDE',1)[1].split('ENDHLSL',1)[0]
    old='"../../../../CameraMotionTaa01/CameraIdentityDepthDiagnostic.hlsl"'
    assert source.count(old)==1
    source=source.replace(old,'"'+observer.resolve().as_posix()+'"')
    extracted=OUT/'identity-probe.validation.hlsl';extracted.write_text(source,encoding='utf-8')
    # No new program or probe edit: only compiler and include-source qualification.
    assert extracted.read_bytes()==(FIRST/'identity-probe.validation.hlsl').read_bytes()
    pins[str(extracted)]=sha(extracted)
    previous=P.parent/'camera-motion-taa-response-02/compile/report.json'
    reuse=json.loads((STAGE/'reuse-source.json').read_text())
    assert sha(previous)==reuse['originalCompileReportSha256'] and json.loads(previous.read_text())['passed']
    report=dict(passed=False,unityExecuted=False,gpuExecuted=False,
                scope='Three distinct identity HLSL entries using the established DXC adapter; not native Unity preprocessing or runtime proof',
                compiler='DXC -HV 2018 -flegacy-macro-expansion, Shader Model 6.0',compilerSha256=sha(DXC),
                basisScriptSha256=sha(BASIS),firstFxcFailureSha256=sha(FIRST/'report.json'),
                stagedShadersChanged=False,extractedSourceUnchanged=True,actualInstalledHeaders=67,
                sources=pins,checks=[],unchangedComputeEntryCount=18,unchangedComputeCompileReportSha256=sha(previous))
    try:
        for name,entry,profile,stage,debug in [('vertex','HLGIIdentityVertex','vs_6_0','VERTEX',False),
                                             ('fragment','HLGIIdentityFragment','ps_6_0','FRAGMENT',False),
                                             ('fragment-debug','HLGIIdentityFragment','ps_6_0','FRAGMENT',True)]:
            command=[str(DXC),'-HV','2018','-flegacy-macro-expansion','-T',profile,'-E',entry,
                     '-D','SHADER_API_D3D11=1','-D','SHADER_STAGE_'+stage+'=1','-D','UNITY_COMPILER_DXC=1',
                     '-D','UNITY_VERSION=600000','-D','SHADER_TARGET=50','-I',str(include_root),
                     '-Fo',str(OUT/(name+'.dxil')),'-Fc',str(OUT/(name+'.asm')),
                     '-H','-MD','-MF',str(OUT/(name+'.d')),str(extracted)]
            if debug:command+=['-D','DEBUG_DISPLAY=1']
            completed=subprocess.run(command,capture_output=True)
            log=OUT/(name+'.log');log.write_bytes(completed.stdout+completed.stderr)
            valid=completed.returncode==0;signature_error=None
            if valid:
                assembly=(OUT/(name+'.asm')).read_text()
                if stage=='VERTEX':
                    valid=bool(re.search(r'SV_Position\s+0\s+xyzw\s+\d+\s+POS\s+float',assembly))
                else:
                    # DEBUG legitimately records probe u2 entry/header atomics; it
                    # must still contain no original candidate u1 claim/resource.
                    valid=bool(re.search(r'_HLGI_IdentityProbeRows\s+UAV\s+struct\s+r/w\s+U\d+\s+u2\s+1',assembly))
                    if debug:valid=valid and '_HLGI_IdentityCandidates' not in assembly and 'dx.op.discard' in assembly
                    else:valid=valid and bool(re.search(r'_HLGI_IdentityCandidates\s+UAV\s+struct\s+r/w\s+U\d+\s+u1\s+1',assembly)) and 'atomicCompareExchange' in assembly
                if not valid:signature_error='Compiled signature/resource binding differs from prospective probe ABI'
            report['checks'].append(dict(name=name,entry=entry,profile=profile,debug=debug,command=command,
                exitCode=completed.returncode,signatureVerified=valid,signatureError=signature_error,
                includeTrace=str(log),dependencyFile=str(OUT/(name+'.d'))))
            print(name+' compiler='+str(completed.returncode)+' signature='+str(valid),flush=True)
        report['passed']=len(report['checks'])==3 and all(row['exitCode']==0 and row['signatureVerified'] for row in report['checks'])
    except Exception as error:report['error']=repr(error)
    finally:
        report['sourcesUnchanged']=all(Path(path).is_file() and sha(Path(path))==digest for path,digest in pins.items())
        report['passed'] &= report['sourcesUnchanged']
        (OUT/'report.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({key:report.get(key) for key in ('passed','sourcesUnchanged','error')}))
    raise SystemExit(0 if report['passed'] else 1)


if __name__=='__main__':main()
