"""Compile the staged observers in complete backend shader contexts."""
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess

P=Path(__file__).resolve().parent;ROOT=P.parents[2]
OUT=P/'compile';OUT.mkdir(exist_ok=False)
INCLUDES=Path(os.environ['TEMP'])/'HybridLumenGI-shader-validation'
SHADERS=ROOT/'Runtime/Resources/HybridLumenGI'
STAGED=P/'instrumentation/prepared/Assets/HybridLumenGI/Runtime/Resources/HybridLumenGI'
DXC=Path('C:/Program Files (x86)/Windows Kits/10/bin/10.0.26100.0/x64/dxc.exe')
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
assert sha(INCLUDES/'Adapters/UnityRayQuery.cginc')==sha(ROOT/'Tests/ShaderAdapters/UnityRayQuery.cginc.txt')
report=dict(compilerSha256=sha(DXC),sources={str(p):sha(p) for p in SHADERS.glob('*.hlsl')},
            stagedManifestSha256=sha(P/'instrumentation/manifest.json'),checks=[],passed=False)
for name,profile in [('HybridLumenGI.compute','cs_6_0'),('HybridLumenGIExactSoftware.compute','cs_6_0'),('HybridLumenGIHardware.compute','cs_6_5')]:
    for kernel in ('CSFiniteWallOcclusionCopy','CSFiniteWallOcclusionInputs'):
        label=Path(name).stem+'-'+kernel;assembly=OUT/(label+'.asm')
        command=[str(DXC),'-O3','-T',profile,'-E',kernel,'-D','SHADER_API_D3D11=1','-D','SHADER_STAGE_COMPUTE=1',
                 '-D','UNITY_COMPILER_DXC=1','-D','UNITY_VERSION=600000','-I',str(INCLUDES/'Adapters'),'-I',str(INCLUDES),
                 '-I',str(SHADERS),'-Fo',str(OUT/(label+'.dxil')),'-Fc',str(assembly),str(STAGED/name)]
        result=subprocess.run(command,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
        (OUT/(label+'.log')).write_bytes(result.stdout)
        uavs=re.findall(r'^;\s+(\S+)\s+UAV\s+',assembly.read_text()) if assembly.exists() else []
        # Resource lines are matched line by line to avoid compiler prose.
        if assembly.exists():uavs=[m.group(1) for line in assembly.read_text().splitlines() if (m:=re.match(r'^;\s+(\S+)\s+UAV\s+',line))]
        report['checks'].append(dict(name=label,command=command,exitCode=result.returncode,uavs=uavs,withinUnityLimit=len(uavs)<=8))
        (OUT/'report.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
        print(label,'exit',result.returncode,'UAV',len(uavs))
        assert result.returncode==0 and len(uavs)<=8,result.stdout.decode(errors='replace')
report['passed']=True
(OUT/'report.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
