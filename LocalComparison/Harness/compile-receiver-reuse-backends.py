"""Compile only the other two affected CSTrace entry points; DXR already archived."""
import hashlib,json,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'LocalComparison/Review/transport-hotspot-and-reuse-01/compiler/shared-entries';OUT.mkdir(exist_ok=True)
DXC='C:/Program Files (x86)/Windows Kits/10/bin/10.0.26100.0/x64/dxc.exe'
INCLUDE=Path('C:/Users/Administrator/AppData/Local/Temp/HybridLumenGI-shader-validation')
SOURCE=ROOT/'Runtime/Resources/HybridLumenGI';results=[]
for name in ['HybridLumenGI','HybridLumenGIExactSoftware']:
    args=[DXC,'-T','cs_6_0','-E','CSTrace','-O3','-D','SHADER_API_D3D11=1','-D','SHADER_STAGE_COMPUTE=1','-D','UNITY_COMPILER_DXC=1','-D','UNITY_VERSION=600000','-I',str(INCLUDE/'Adapters'),'-I',str(INCLUDE),'-I',str(SOURCE),'-Fo',str(OUT/(name+'.dxil')),str(SOURCE/(name+'.compute'))]
    run=subprocess.run(args,capture_output=True,timeout=300);(OUT/(name+'.log')).write_bytes(run.stdout+run.stderr)
    results.append({'source':name,'entry':'CSTrace','arguments':args,'exitCode':run.returncode,'dxilSha256':hashlib.sha256((OUT/(name+'.dxil')).read_bytes()).hexdigest() if run.returncode==0 else None})
    (OUT/'results.json').write_bytes((json.dumps(results,indent=2)+'\n').encode())
    print(name,'exit',run.returncode,flush=True)
    if run.returncode:raise SystemExit(run.returncode)
