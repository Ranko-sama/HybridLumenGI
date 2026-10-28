"""Only the two instrumented hardware transport entries; structural compile, not a driver-performance claim."""
import hashlib,json,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];PACKAGE=ROOT/'LocalComparison/Review/material-mpb-propagation-01'
OUT=PACKAGE/'preflight';STAGE=PACKAGE/'instrumentation/prepared/Assets/HybridLumenGI/Runtime/Resources/HybridLumenGI'
INCLUDE=Path('C:/Users/Administrator/AppData/Local/Temp/HybridLumenGI-shader-validation')
DXC='C:/Program Files (x86)/Windows Kits/10/bin/10.0.26100.0/x64/dxc.exe';results=[]
for entry in ['CSTrace','CSUpdateCache']:
    args=[DXC,'-T','cs_6_5','-E',entry,'-Od','-D','HLGI_MATERIAL_EVENT=1','-D','SHADER_API_D3D11=1','-D','SHADER_STAGE_COMPUTE=1','-D','UNITY_COMPILER_DXC=1','-D','UNITY_VERSION=600000',
        '-I',str(INCLUDE/'Adapters'),'-I',str(INCLUDE),'-I',str(STAGE),'-I',str(ROOT/'Runtime/Resources/HybridLumenGI'),'-Fo',str(OUT/(entry+'.dxil')),str(STAGE/'HybridLumenGIHardware.compute')]
    result=subprocess.run(args,capture_output=True,timeout=300);(OUT/(entry+'.log')).write_bytes(result.stdout+result.stderr)
    results.append({'entry':entry,'arguments':args,'exitCode':result.returncode,'sha256':hashlib.sha256((OUT/(entry+'.dxil')).read_bytes()).hexdigest() if result.returncode==0 else None})
    (OUT/'instrumented-shaders.json').write_text(json.dumps(results,indent=2),encoding='utf-8');print(entry,result.returncode,flush=True)
    if result.returncode:print((result.stdout+result.stderr).decode('utf-8',errors='replace'));raise SystemExit(result.returncode)
