"""Compile the one actual DXR query entry before spending the unique Player run."""
import hashlib,json,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];P=ROOT/'LocalComparison/Review/interior-surface-cache-chain-01';O=P/'preflight';O.mkdir(exist_ok=True)
STAGE=P/'instrumentation/prepared/Assets/HybridLumenGI/Runtime/Resources/HybridLumenGI';S=O/'shader-sources';S.mkdir(exist_ok=True)
# Quoted relative includes resolve beside the including file. Mirror the deployed overlay,
# otherwise an unstaged Kernels.hlsl silently resolves an unstaged Transport.hlsl first.
for original in (ROOT/'Runtime/Resources/HybridLumenGI').iterdir():
    if original.is_file():(S/original.name).write_bytes(original.read_bytes())
for original in STAGE.iterdir():
    if original.is_file():(S/original.name).write_bytes(original.read_bytes())
I=Path('C:/Users/Administrator/AppData/Local/Temp/HybridLumenGI-shader-validation')
assert (I/'Adapters/UnityRayQuery.cginc').read_bytes()==(ROOT/'Tests/ShaderAdapters/UnityRayQuery.cginc.txt').read_bytes()
args=['C:/Program Files (x86)/Windows Kits/10/bin/10.0.26100.0/x64/dxc.exe','-T','cs_6_5','-E','CSInteriorSurfaceProbe','-O3',
 '-D','HLGI_INTERIOR_QUERY=1','-D','SHADER_API_D3D11=1','-D','SHADER_STAGE_COMPUTE=1','-D','UNITY_COMPILER_DXC=1','-D','UNITY_VERSION=600000',
 '-I',str(S),'-I',str(ROOT/'Runtime/Resources/HybridLumenGI'),'-I',str(I/'Adapters'),'-I',str(I),'-Fo',str(O/'query.dxil'),str(S/'HybridLumenGIHardware.compute')]
attempt=len(list(O.glob('query-*.log')))+1;r=subprocess.run(args,capture_output=True,timeout=300);(O/f'query-{attempt}.log').write_bytes(r.stdout+r.stderr)
(O/f'query-{attempt}.json').write_text(json.dumps({'arguments':args,'exitCode':r.returncode,'scope':'Known Unity RayQuery adapter compile; actual Unity build/run still required'},indent=2))
print((r.stdout+r.stderr).decode(errors='replace'));print('QUERY_COMPILER_EXIT='+str(r.returncode));raise SystemExit(r.returncode)
