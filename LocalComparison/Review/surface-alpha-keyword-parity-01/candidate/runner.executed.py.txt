"""Bounded ordinary Surface coverage contract; actual Frag and existing WARP host."""
import argparse, ast, hashlib, importlib.util, json, os, re, struct, subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
H = ROOT / 'LocalComparison/Harness'
S = ROOT / 'Runtime/Resources/HybridLumenGI'
OUT = ROOT / 'LocalComparison/Review/surface-alpha-keyword-parity-01'
INC = Path(os.environ['TEMP']) / 'HybridLumenGI-shader-validation'
URP = Path('I:/Unity test/Project/Library/PackageCache/com.unity.render-pipelines.universal@947f725e83ac')
T = ROOT / 'Tests/StandaloneRadianceValidity'
DXC = Path('C:/Program Files (x86)/Windows Kits/10/bin/10.0.26100.0/x64/dxc.exe')
spec = importlib.util.spec_from_file_location('prior', H / 'run-screen-receive-shadows-source.py')
prior = importlib.util.module_from_spec(spec)
spec.loader.exec_module(prior)
sha = prior.sha

CASES = [
    dict(name='clip-off-property-on', variant='off', clip=1, smooth=0, keep=True, mismatch=True),
    dict(name='opaque-control', variant='off', clip=0, smooth=0, keep=True, mismatch=False),
    dict(name='clip-on-property-off', variant='test', clip=0, smooth=0, keep=False, mismatch=True),
    dict(name='smooth-off-property-on', variant='test', clip=1, smooth=1, keep=False, mismatch=True),
    dict(name='cutout-control', variant='test', clip=1, smooth=0, keep=False, mismatch=False),
    dict(name='smooth-on-property-off', variant='smooth', clip=1, smooth=0, keep=True, mismatch=True),
    dict(name='smooth-control', variant='smooth', clip=1, smooth=1, keep=True, mismatch=False),
]
VARIANTS = [('off', []), ('test', ['_ALPHATEST_ON']),
            ('smooth', ['_ALPHATEST_ON', '_SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A'])]
CLIP = '''// Source-decision adapter only: later color is invalid after any negative clip.
static bool discarded;
static uint clipCalls;
static float minimumClip;
void RecordClip(float value) { discarded=discarded || value<0; minimumClip=min(minimumClip,value); clipCalls++; }
#define clip(value) RecordClip(value)
'''
ENTRY = r'''
[numthreads(64,1,1)] void CSSurfaceAlpha(uint3 id:SV_DispatchThreadID)
{
    if(id.x>=_Count)return;
    discarded=false;clipCalls=0;minimumClip=3.402823466e+38;
    _AlphaClip=_Inputs[id.x].control.x;
    _SmoothnessTextureChannel=_Inputs[id.x].control.y;
    Attributes input;input.positionOS=float4(0,0,0,1);input.uv=float2(.125,.125);
    Varyings mapped=Vert(input);SurfaceOutput captured=Frag(mapped);
    RadianceOutput result=(RadianceOutput)0;
    if(!discarded) { result.sum=captured.diffuseOcclusion;result.irradiance=captured.emissionValidity; }
    result.guide=float4(minimumClip,mapped.uv,0);
    result.predicates=uint4(discarded?0u:1u,clipCalls,discarded?uint2(0,0):captured.receiverPolicy);
    _Outputs[id.x]=result;
}
'''

def invoke(folder, name, args, commands):
    result = subprocess.run(list(map(str, args)), capture_output=True, text=True)
    (folder / (name + '.log')).write_text(result.stdout + result.stderr, encoding='utf-8')
    commands.append(dict(name=name, arguments=list(map(str, args)), exitCode=result.returncode))
    (folder / 'commands.json').write_text(json.dumps(commands, indent=2), encoding='utf-8')
    assert result.returncode == 0, (name, result.returncode)

def main(stage):
    folder = OUT / stage
    folder.mkdir(parents=True, exist_ok=False)
    (folder/'runner.executed.py.txt').write_bytes(Path(__file__).read_bytes())
    (folder/'contract.before-execution.md').write_bytes((ROOT/'Documentation/Checkpoint-Iteration51.md').read_bytes())
    sources = []
    for rel in ['ShaderLibrary/SurfaceInput.hlsl', 'ShaderLibrary/ShaderVariablesFunctions.hlsl', 'Shaders/Lit.shader']:
        actual = URP / rel
        cached = INC/'Packages/com.unity.render-pipelines.universal'/rel
        if rel.startswith('ShaderLibrary/'):
            assert sha(actual) == sha(cached), 'Installed/include-cache dependency mismatch: '+rel
        (folder/actual.name).write_bytes(actual.read_bytes())
        sources.append(dict(path=str(actual), sha256=sha(actual)))
    for name in ['HybridLumenGISurface.shader', 'HybridLumenGIScreenMaterial.hlsl', 'HybridLumenGIReceiverPolicyCapture.hlsl']:
        (folder/name).write_bytes((S/name).read_bytes())
        sources.append(dict(path=str(S/name), sha256=sha(S/name)))
    old_adapter_source = H/'run-surface-detail-source.py'
    (folder/'prior-surface-adapter.py.txt').write_bytes(old_adapter_source.read_bytes())
    tree = ast.parse(old_adapter_source.read_text(encoding='utf-8'))
    adapter = next(ast.literal_eval(x.value) for x in tree.body if isinstance(x, ast.Assign) and any(isinstance(t, ast.Name) and t.id=='adapter' for t in x.targets))
    old = '// Only opaque/non-clipped inputs; raster coverage is outside this source contract.\n#define clip(x)'
    assert old in adapter
    adapter = adapter.replace(old, CLIP)
    old = 'float4 Sample_BaseMap(float2 uv){return uv.x<.5&&uv.y<.5?float4(.5,.75,.25,1):float4(.25,.5,.75,1);}'
    assert old in adapter
    adapter = adapter.replace(old, old.replace(',.25,1)', ',.25,.25)').replace(',.75,1)', ',.75,.25)'))
    abi = (T/'RadianceValidityHarness.hlsl').read_text(encoding='utf-8')
    abi = abi[abi.index('struct RadianceInput'):abi.index('// Explicit dependency adapter:')]
    shader = (S/'HybridLumenGISurface.shader').read_text(encoding='utf-8')
    bodies = prior.extract(shader, r'^\s*Varyings Vert\(')+'\n'+prior.extract(shader, r'^\s*SurfaceOutput Frag\(')
    source = folder/'actual-surface.hlsl'
    source.write_text(abi+adapter+bodies+ENTRY, encoding='utf-8')
    matches=[]
    for p in Path(os.environ['TEMP']).glob('hlgi-radiance-validity-warp-*'):
        exe=p/'build/Release/RadianceValidityWarp.exe'
        cpp=p/'source/RadianceValidityWarp.cpp'; cmake=p/'source/CMakeLists.txt'
        if exe.is_file() and cpp.is_file() and cmake.is_file() and sha(cpp)==sha(T/'RadianceValidityWarp.cpp.txt') and sha(cmake)==sha(T/'CMakeLists.txt'): matches.append(exe)
    assert matches, 'Existing source-matched WARP host required'
    exe=sorted(matches, key=lambda p:p.stat().st_mtime)[-1]
    (folder/'cases.json').write_text(json.dumps(CASES, indent=2), encoding='utf-8')
    if stage=='candidate':
        assert (folder/'runner.executed.py.txt').read_bytes()==(OUT/'baseline/runner.executed.py.txt').read_bytes()
        assert json.loads((OUT/'baseline/analysis.json').read_text())['oldCounterexamplesEstablished']
    commands=[];rows=[];failures=[];counterexamples=[]
    for variant, defines in VARIANTS:
        cases=[c for c in CASES if c['variant']==variant]
        data=bytearray(struct.pack('<I',len(cases)))
        for c in cases:
            row=bytearray(208);struct.pack_into('<4f',row,16,c['clip'],c['smooth'],0,0);data+=row
        inputs=folder/(variant+'-inputs.bin');inputs.write_bytes(data)
        if stage=='candidate': assert data==(OUT/'baseline'/inputs.name).read_bytes()
        args=[DXC,'-HV','2018','-T','cs_6_0','-E','CSSurfaceAlpha','-D','_EMISSION=1','-D','_OCCLUSIONMAP=1','-I',folder,'-Fo',folder/(variant+'.dxil')]
        for d in defines:args+=['-D',d+'=1']
        invoke(folder, variant+'-compile', args+[source], commands)
        binary=folder/(variant+'.bin')
        invoke(folder, variant+'-warp', [exe,folder/(variant+'.dxil'),inputs,binary], commands)
        raw=binary.read_bytes();assert len(raw)==368*len(cases)
        before=(OUT/'baseline'/binary.name).read_bytes() if stage=='candidate' else raw
        for i,c in enumerate(cases):
            offset=368*i
            diffuse=struct.unpack_from('<4f',raw,offset);emission=struct.unpack_from('<4f',raw,offset+16)
            minimum=struct.unpack_from('<f',raw,offset+32)[0];predicate=struct.unpack_from('<4I',raw,offset+128)
            keep=predicate[0]==1
            coverage_match=keep==c['keep']
            expected_match=not c['mismatch'] if stage=='baseline' else True
            expected_color=[.25*.96,.28125*.96,.0625*.96,1]
            valid_payload=(max(abs(x-y) for x,y in zip(diffuse,expected_color))<=2e-6 and emission==(.125,.25,.5,1) and predicate[2:]==(1,1)) if keep else (diffuse==(0,0,0,0) and emission==(0,0,0,0) and predicate[2:]==(0,0))
            unchanged=stage=='baseline' or c['mismatch'] or raw[offset:offset+368]==before[offset:offset+368]
            checks=dict(coverage=coverage_match==expected_match,payload=valid_payload,consistentControlUnchanged=unchanged)
            if stage=='baseline' and c['mismatch']:counterexamples.append(not coverage_match)
            if not all(checks.values()):failures.append(c['name'])
            rows.append(dict(case=c['name'],variant=variant,keep=keep,expectedKeep=c['keep'],minimumClip=minimum,clipCalls=predicate[1],diffuse=diffuse,emission=emission,policy=predicate[2:],checks=checks))
    if stage=='candidate':
        for keyword in ['_ALPHATEST_ON','_SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A']:
            assert '#pragma multi_compile_local_fragment _ '+keyword in shader
        full=folder/'surface-full-pass.hlsl'
        full.write_text(re.search(r'HLSLPROGRAM(.*?)ENDHLSL',shader,re.S)[1],encoding='utf-8')
        for variant,defines in VARIANTS+[('smooth-without-test',['_SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A'])]:
            args=[DXC,'-HV','2018','-E','Frag','-T','ps_6_0','-I',INC/'Adapters','-I',INC,'-I',folder,'-Fo',folder/('full-'+variant+'.dxil')]
            for d in ['SHADER_API_D3D11','SHADER_STAGE_FRAGMENT','UNITY_COMPILER_DXC']+defines:args+=['-D',d+'=1']
            invoke(folder,'full-'+variant+'-compile',args+['-D','UNITY_VERSION=600000',full],commands)
    result=dict(passed=not failures,stage=stage,oldCounterexamplesEstablished=stage=='baseline' and len(counterexamples)==4 and all(counterexamples),failures=failures,rows=rows,commands=commands,runner=str(exe),runnerSha256=sha(exe),sources=sources,compiledSourceSha256=sha(source),inputs={v:sha(folder/(v+'-inputs.bin')) for v,_ in VARIANTS},colorAbsoluteBound=2e-6,scope='Actual Vert/Frag source decisions on WARP; clip predicate adapter masks discarded payload. Fixed textures/transforms and layer adapter. Full fragment compilation has real clip. No Unity keyword transfer, raster coverage, AlphaToCoverage or native image qualification.')
    (folder/'analysis.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
    print(json.dumps({k:v for k,v in result.items() if k not in ['rows','commands','sources']}))
    assert result['passed'] and (stage!='baseline' or result['oldCounterexamplesEstablished'])

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('stage',choices=['baseline','candidate']);main(parser.parse_args().stage)
