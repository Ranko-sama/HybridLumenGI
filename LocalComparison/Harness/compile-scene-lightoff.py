"""Compile only the two instrumented complete exact-software entries, no GPU run."""
import hashlib,json,os,shutil,subprocess,sys
from pathlib import Path
root=Path(__file__).resolve().parents[2];package=root/'LocalComparison/Review/scene-lightoff-chain-02'
out=package/(sys.argv[1] if len(sys.argv)>1 else 'compile');instrumentation=package/'instrumentation'
assert not out.exists(),'Do not overwrite or repeat preflight'
compiler=Path('C:/Program Files (x86)/Windows Kits/10/bin/10.0.26100.0/x64/dxc.exe')
includes=Path(os.environ['TEMP'])/'HybridLumenGI-shader-validation'
assert compiler.exists() and (includes/'Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl').exists()
source=out/'source';shutil.copytree(root/'Runtime/Resources/HybridLumenGI',source)
for label,name in [('transport','HybridLumenGITransport.hlsl'),('kernels','HybridLumenGIKernels.hlsl'),('wrapper','HybridLumenGIExactSoftware.compute')]:
    (source/name).write_bytes((instrumentation/(label+'.instrumented.txt')).read_bytes())
for name in ['LightOffCacheWriter.hlsl','GatherTraceWriter.hlsl']:(source/name).write_bytes((root/'LocalComparison/Harness'/name).read_bytes())
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
report={'passed':False,'scope':'Two complete instrumented exact-software entries; DXC preflight only, no physical execution.',
    'compilerSha256':sha(compiler),'sourceSha256':{p.name:sha(p) for p in source.glob('*') if p.is_file()},
    'includeSource':'Existing Unity Graphics feb4de2d9a93a4ae10d287d3a6d7003d08ea3e53 cache',
    'includeSha256':{str(p.relative_to(includes)):sha(p) for p in (includes/'Packages').rglob('*') if p.is_file()},'entries':[]}
(out/'compiler-script.executed.py.txt').write_bytes(Path(__file__).read_bytes())
# CSTrace's changed helper body is disabled without HLGI_LIGHTOFF_AUDIT. Reuse
# its previous complete compilation only after checking every source dependency.
prior=root/'LocalComparison/Review/scene-lightoff-chain-01/compile-fixed'
prior_report=json.loads((prior/'report.json').read_text(encoding='utf-8'));assert prior_report['passed']
for p in source.glob('*'):
    if not p.is_file():continue
    old=prior/'source'/p.name;assert old.exists(),p.name
    if p.name=='LightOffCacheWriter.hlsl':
        disabled=lambda s:s[:s.index('#if defined(HLGI_LIGHTOFF_AUDIT)')]+s[s.index('#else',s.index('#if defined(HLGI_LIGHTOFF_AUDIT)')):]
        assert disabled(p.read_text(encoding='utf-8'))==disabled(old.read_text(encoding='utf-8'))
    else:assert p.read_bytes()==old.read_bytes(),p.name
assert report['includeSha256']==prior_report['includeSha256'] and report['compilerSha256']==prior_report['compilerSha256']
report['reusedCSTrace']={'reportSha256':sha(prior/'report.json'),'sameEffectiveSources':True,'reason':'Only changed LightOffCacheWriter active body is excluded by this entry define; every other source/compiler/include matches.'}
for entry,define in [('CSUpdateCache','HLGI_LIGHTOFF_AUDIT=1')]:
    arguments=[str(compiler),'-T','cs_6_0','-E',entry,'-D',define,'-D','SHADER_API_D3D11=1','-D','SHADER_STAGE_COMPUTE=1',
        '-D','UNITY_COMPILER_DXC=1','-D','UNITY_VERSION=600000','-I',str(includes),'-Fo',str(out/(entry+'.dxil')),str(source/'HybridLumenGIExactSoftware.compute')]
    print('Compiling '+entry,flush=True);result=subprocess.run(arguments,capture_output=True,text=True)
    (out/(entry+'.stdout.log')).write_text(result.stdout,encoding='utf-8');(out/(entry+'.stderr.log')).write_text(result.stderr,encoding='utf-8')
    report['entries'].append({'entry':entry,'arguments':arguments,'exitCode':result.returncode,
        'dxilSha256':sha(out/(entry+'.dxil')) if (out/(entry+'.dxil')).exists() else None})
    (out/'report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
    print(json.dumps({'entry':entry,'exitCode':result.returncode,'diagnostics':result.stderr}),flush=True)
    if result.returncode:sys.exit(result.returncode)
report['passed']=True;(out/'report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print('Changed CSUpdateCache passed; unchanged CSTrace full compilation reused with verified effective source/compiler/include identity',flush=True)
