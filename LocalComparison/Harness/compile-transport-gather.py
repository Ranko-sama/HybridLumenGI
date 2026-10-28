"""One optimized Gather DXIL inspection per side, using the existing pinned adapter."""
import argparse,hashlib,json,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];PACKAGE=ROOT/'LocalComparison/Review/transport-hotspot-and-reuse-01'
COMPILER=Path('C:/Program Files (x86)/Windows Kits/10/bin/10.0.26100.0/x64/dxc.exe')
INCLUDES=Path('C:/Users/Administrator/AppData/Local/Temp/HybridLumenGI-shader-validation')
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
p=argparse.ArgumentParser();p.add_argument('side',choices=['baseline','candidate']);a=p.parse_args();out=PACKAGE/'compiler'/a.side
assert not out.exists(),'Preserve first compilation';out.mkdir(parents=True)
source=out/'source';source.mkdir();rows=[]
for original in sorted((ROOT/'Runtime/Resources/HybridLumenGI').iterdir()):
    if original.is_file() and original.suffix in ['.hlsl','.compute','.shader']:
        target=source/original.name;target.write_bytes(original.read_bytes());rows.append({'file':original.name,'sha256':sha(target)})
adapter=INCLUDES/'Adapters/UnityRayQuery.cginc';assert sha(adapter)==sha(ROOT/'Tests/ShaderAdapters/UnityRayQuery.cginc.txt')
args=[str(COMPILER),'-T','cs_6_5','-E','CSTrace','-O3','-Zi','-Qembed_debug',
      '-D','SHADER_API_D3D11=1','-D','SHADER_STAGE_COMPUTE=1','-D','UNITY_COMPILER_DXC=1','-D','UNITY_VERSION=600000',
      '-I',str(INCLUDES/'Adapters'),'-I',str(INCLUDES),'-I',str(source),'-Fo',str(out/'gather.dxil'),'-Fc',str(out/'gather.asm'),str(source/'HybridLumenGIHardware.compute')]
report={'side':a.side,'sources':rows,'compiler':str(COMPILER),'compilerSha256':sha(COMPILER),'arguments':args,
        'adapterSha256':sha(adapter),'includeRoot':str(INCLUDES),'scope':'Optimized DXC/known RayQuery adapter inspection, not extracted Unity driver machine code or physical register counts.'}
(out/'compile.json').write_bytes((json.dumps(report,indent=2)+'\n').encode('utf-8'));started=time.monotonic()
result=subprocess.run(args,capture_output=True,timeout=300)
(out/'compiler.log').write_bytes(result.stdout+result.stderr)
report.update(exitCode=result.returncode,elapsedSeconds=time.monotonic()-started)
if result.returncode==0:report.update(dxilSha256=sha(out/'gather.dxil'),assemblySha256=sha(out/'gather.asm'),dxilBytes=(out/'gather.dxil').stat().st_size)
(out/'compile.json').write_bytes((json.dumps(report,indent=2)+'\n').encode('utf-8'));print(json.dumps({k:v for k,v in report.items() if k not in ['sources','arguments']}));raise SystemExit(result.returncode)
