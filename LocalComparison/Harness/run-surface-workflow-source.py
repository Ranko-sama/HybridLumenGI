"""Finite ordinary Surface workflow selection; reuse existing clip adapter and WARP ABI."""
import argparse, ast, importlib.util, json, os, re, struct
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
H=ROOT/'LocalComparison/Harness';S=ROOT/'Runtime/Resources/HybridLumenGI'
OUT=ROOT/'LocalComparison/Review/surface-workflow-keyword-parity-01'
spec=importlib.util.spec_from_file_location('alpha',H/'run-surface-alpha-source.py')
alpha=importlib.util.module_from_spec(spec);spec.loader.exec_module(alpha)
sha,invoke,DXC,INC,URP,T=alpha.sha,alpha.invoke,alpha.DXC,alpha.INC,alpha.URP,alpha.T
VARIANTS=[('metal',[]),('spec',['_SPECULAR_SETUP']),('metal-map',['_METALLICSPECGLOSSMAP']),('spec-map',['_SPECULAR_SETUP','_METALLICSPECGLOSSMAP'])]
CASES=[
    dict(name='metal-opposite-property',variant='metal',workflow=0,mismatch=True),
    dict(name='metal-control',variant='metal',workflow=1,mismatch=False),
    dict(name='spec-opposite-property',variant='spec',workflow=1,mismatch=True),
    dict(name='spec-control',variant='spec',workflow=0,mismatch=False),
    dict(name='metal-map-opposite-property',variant='metal-map',workflow=0,mismatch=True),
    dict(name='spec-map-opposite-property',variant='spec-map',workflow=1,mismatch=True),
]
ENTRY=r'''
[numthreads(64,1,1)] void CSSurfaceWorkflow(uint3 id:SV_DispatchThreadID)
{
    if(id.x>=_Count)return;
    discarded=false;clipCalls=0;minimumClip=3.402823466e+38;
    _WorkflowMode=_Inputs[id.x].control.x;_Metallic=1;
    Attributes input;input.positionOS=float4(0,0,0,1);input.uv=float2(.125,.125);
    Varyings mapped=Vert(input);SurfaceOutput captured=Frag(mapped);
    RadianceOutput result=(RadianceOutput)0;
    if(!discarded) {result.sum=captured.diffuseOcclusion;result.irradiance=captured.emissionValidity;}
    result.guide=float4(minimumClip,mapped.uv,0);
    result.predicates=uint4(discarded?0u:1u,clipCalls,discarded?uint2(0,0):captured.receiverPolicy);
    _Outputs[id.x]=result;
}
'''

def main(stage):
    folder=OUT/stage;folder.mkdir(parents=True,exist_ok=False)
    (folder/'runner.executed.py.txt').write_bytes(Path(__file__).read_bytes())
    (folder/'alpha-helper.py.txt').write_bytes((H/'run-surface-alpha-source.py').read_bytes())
    (folder/'contract.before-execution.md').write_bytes((ROOT/'Documentation/Checkpoint-Iteration52.md').read_bytes())
    sources=[]
    for rel in ['ShaderLibrary/BRDF.hlsl','Shaders/LitInput.hlsl','Shaders/Lit.shader']:
        actual=URP/rel
        if rel.endswith('.hlsl'):assert sha(actual)==sha(INC/'Packages/com.unity.render-pipelines.universal'/rel),rel
        (folder/actual.name).write_bytes(actual.read_bytes());sources.append(dict(path=str(actual),sha256=sha(actual)))
    for name in ['HybridLumenGISurface.shader','HybridLumenGIScreenMaterial.hlsl','HybridLumenGIReceiverPolicyCapture.hlsl']:
        (folder/name).write_bytes((S/name).read_bytes());sources.append(dict(path=str(S/name),sha256=sha(S/name)))
    old_adapter=H/'run-surface-detail-source.py'
    (folder/'prior-surface-adapter.py.txt').write_bytes(old_adapter.read_bytes())
    tree=ast.parse(old_adapter.read_text(encoding='utf-8'))
    adapter=next(ast.literal_eval(x.value) for x in tree.body if isinstance(x,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='adapter' for t in x.targets))
    replacements={
        '// Only opaque/non-clipped inputs; raster coverage is outside this source contract.\n#define clip(x)':alpha.CLIP,
        'static float4 _BaseColor=float4(.5,.375,.25,1),_SpecColor=.04,_EmissionColor=float4(.125,.25,.5,1);':'static float4 _BaseColor=1,_SpecColor=float4(.125,.25,.5,1),_EmissionColor=float4(.125,.25,.5,1);',
        'float4 Sample_BaseMap(float2 uv){return uv.x<.5&&uv.y<.5?float4(.5,.75,.25,1):float4(.25,.5,.75,1);}':'float4 Sample_BaseMap(float2 uv){return float4(.25,.5,.75,.25);}',
        'float4 Sample_OcclusionMap(float2 uv){return 1;}':'float4 Sample_OcclusionMap(float2 uv){return float4(.125,.5,.75,1);}',
    }
    for before,after in replacements.items():assert before in adapter;adapter=adapter.replace(before,after)
    adapter+='\nfloat4 Sample_MetallicGlossMap(float2 uv){return float4(.25,.875,.625,.5);}\nfloat4 Sample_SpecGlossMap(float2 uv){return float4(.75,.125,.5,.25);}\n'
    abi=(T/'RadianceValidityHarness.hlsl').read_text(encoding='utf-8');abi=abi[abi.index('struct RadianceInput'):abi.index('// Explicit dependency adapter:')]
    shader=(S/'HybridLumenGISurface.shader').read_text(encoding='utf-8')
    bodies=alpha.prior.extract(shader,r'^\s*Varyings Vert\(')+'\n'+alpha.prior.extract(shader,r'^\s*SurfaceOutput Frag\(')
    source=folder/'actual-surface.hlsl';source.write_text(abi+adapter+bodies+ENTRY,encoding='utf-8')
    matches=[]
    for p in Path(os.environ['TEMP']).glob('hlgi-radiance-validity-warp-*'):
        exe=p/'build/Release/RadianceValidityWarp.exe';cpp=p/'source/RadianceValidityWarp.cpp';cmake=p/'source/CMakeLists.txt'
        if exe.is_file() and cpp.is_file() and cmake.is_file() and sha(cpp)==sha(T/'RadianceValidityWarp.cpp.txt') and sha(cmake)==sha(T/'CMakeLists.txt'):matches.append(exe)
    assert matches,'Existing source-matched host required';exe=sorted(matches,key=lambda p:p.stat().st_mtime)[-1]
    (folder/'cases.json').write_text(json.dumps(CASES,indent=2),encoding='utf-8')
    if stage=='candidate':
        for name in ['runner.executed.py.txt','alpha-helper.py.txt','prior-surface-adapter.py.txt','contract.before-execution.md','BRDF.hlsl','LitInput.hlsl','Lit.shader','cases.json']:
            assert (folder/name).read_bytes()==(OUT/'baseline'/name).read_bytes(),name
        assert json.loads((OUT/'baseline/analysis.json').read_text())['oldCounterexamplesEstablished']
    commands=[];rows=[];failures=[];counterexamples=[]
    for variant,defines in VARIANTS:
        cases=[c for c in CASES if c['variant']==variant];data=bytearray(struct.pack('<I',len(cases)))
        for c in cases:
            row=bytearray(208);struct.pack_into('<4f',row,16,c['workflow'],0,0,0);data+=row
        inputs=folder/(variant+'-inputs.bin');inputs.write_bytes(data)
        if stage=='candidate':assert data==(OUT/'baseline'/inputs.name).read_bytes()
        args=[DXC,'-HV','2018','-T','cs_6_0','-E','CSSurfaceWorkflow','-D','_EMISSION=1','-D','_OCCLUSIONMAP=1','-I',folder,'-Fo',folder/(variant+'.dxil')]
        for d in defines:args+=['-D',d+'=1']
        invoke(folder,variant+'-compile',args+[source],commands)
        binary=folder/(variant+'.bin');invoke(folder,variant+'-warp',[exe,folder/(variant+'.dxil'),inputs,binary],commands)
        raw=binary.read_bytes();assert len(raw)==368*len(cases)
        before=(OUT/'baseline'/binary.name).read_bytes() if stage=='candidate' else raw
        is_spec='_SPECULAR_SETUP' in defines;has_map='_METALLICSPECGLOSSMAP' in defines
        m=.25 if has_map else 1;s=(.75,.125,.5) if has_map else (.125,.25,.5)
        factor=1-max(s) if is_spec else .96*(1-m)
        expected=[a*factor for a in [.25,.5,.75]]
        for i,c in enumerate(cases):
            offset=368*i;diffuse=struct.unpack_from('<4f',raw,offset);emission=struct.unpack_from('<4f',raw,offset+16);predicate=struct.unpack_from('<4I',raw,offset+128)
            matches_reference=max(abs(x-y) for x,y in zip(diffuse[:3],expected))<=2e-6
            old_factor=1-max(s) if c['workflow']==0 else .96*(1-m)
            old_expected=[a*old_factor for a in [.25,.5,.75]]
            checks=dict(reference=matches_reference==(not c['mismatch'] if stage=='baseline' else True),
                        oldSourceSanity=stage!='baseline' or max(abs(x-y) for x,y in zip(diffuse[:3],old_expected))<=2e-6,
                        payload=diffuse[3]==.5 and emission==(.125,.25,.5,1) and predicate==(1,1,1,1),
                        unrelatedUnchanged=stage=='baseline' or raw[offset+12:offset+368]==before[offset+12:offset+368],
                        consistentControlUnchanged=stage=='baseline' or c['mismatch'] or raw[offset:offset+368]==before[offset:offset+368])
            if stage=='baseline' and c['mismatch']:counterexamples.append(not matches_reference)
            if not all(checks.values()):failures.append(c['name'])
            rows.append(dict(case=c['name'],variant=variant,diffuse=diffuse,expected=expected,emission=emission,predicates=predicate,checks=checks))
    if stage=='candidate':
        assert '#pragma multi_compile_local_fragment _ _SPECULAR_SETUP' in shader
        full=folder/'surface-full-pass.hlsl';full.write_text(re.search(r'HLSLPROGRAM(.*?)ENDHLSL',shader,re.S)[1],encoding='utf-8')
        for variant,defines in VARIANTS:
            args=[DXC,'-HV','2018','-E','Frag','-T','ps_6_0','-I',INC/'Adapters','-I',INC,'-I',folder,'-Fo',folder/('full-'+variant+'.dxil')]
            for d in ['SHADER_API_D3D11','SHADER_STAGE_FRAGMENT','UNITY_COMPILER_DXC']+defines:args+=['-D',d+'=1']
            invoke(folder,'full-'+variant+'-compile',args+['-D','UNITY_VERSION=600000',full],commands)
    result=dict(passed=not failures,stage=stage,oldCounterexamplesEstablished=stage=='baseline' and len(counterexamples)==4 and all(counterexamples),failures=failures,rows=rows,commands=commands,sources=sources,runner=str(exe),runnerSha256=sha(exe),compiledSourceSha256=sha(source),inputs={v:sha(folder/(v+'-inputs.bin')) for v,_ in VARIANTS},colorAbsoluteBound=2e-6,scope='Actual Vert/Frag on existing WARP host, fixed shader-space textures and transform/policy adapters; clip recorder masks invalid payload. Real-clip full fragment compilation. No Unity keyword transfer, native raster/image, A2C or performance qualification.')
    (folder/'analysis.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
    print(json.dumps({k:v for k,v in result.items() if k not in ['rows','commands','sources']}))
    assert result['passed'] and (stage!='baseline' or result['oldCounterexamplesEstablished'])

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('stage',choices=['baseline','candidate']);main(parser.parse_args().stage)
