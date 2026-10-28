"""One compile preflight for the generated actual update reference entry."""
import hashlib,json,os,subprocess,sys
from pathlib import Path
root=Path(__file__).resolve().parents[2];out=root/'LocalComparison/Review/cache-energy-decay-reference-01/compile'
assert not out.exists(),'Do not repeat or overwrite compile evidence'
compiler=Path('C:/Program Files (x86)/Windows Kits/10/bin/10.0.26100.0/x64/dxc.exe')
includes=Path(os.environ['TEMP'])/'HybridLumenGI-shader-validation'
source=Path('I:/Unity test/Project/Assets/ComparisonHarness/Resources/CacheEnergyDecay.compute')
assert compiler.exists() and (includes/'Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl').exists()
out.mkdir(parents=True)
args=[str(compiler),'-T','cs_6_0','-E','CSUpdateCache','-D','SHADER_API_D3D11=1','-D','SHADER_STAGE_COMPUTE=1',
    '-D','UNITY_COMPILER_DXC=1','-D','UNITY_VERSION=600000','-I',str(includes),'-Fo',str(out/'CSUpdateCache.dxil'),str(source)]
result=subprocess.run(args,capture_output=True,text=True)
(out/'stdout.log').write_text(result.stdout,encoding='utf-8');(out/'stderr.log').write_text(result.stderr,encoding='utf-8')
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
report={'exitCode':result.returncode,'arguments':args,'sourceSha256':sha(source),'compilerSha256':sha(compiler),
    'includeSource':'existing Unity Graphics feb4de2d9a93a4ae10d287d3a6d7003d08ea3e53 cache',
    'includeSha256':{str(p.relative_to(includes)):sha(p) for p in (includes/'Packages').rglob('*') if p.is_file()},
    'dxilSha256':sha(out/'CSUpdateCache.dxil') if (out/'CSUpdateCache.dxil').exists() else None,
    'scope':'Actual generated CSUpdateCache fixture compile only; Unity dispatch follows only after preflight review.'}
(out/'report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
(out/'compiler-script.executed.py.txt').write_bytes(Path(__file__).read_bytes())
print(json.dumps({'exitCode':result.returncode,'dxilSha256':report['dxilSha256'],'diagnostics':result.stderr}));sys.exit(result.returncode)
