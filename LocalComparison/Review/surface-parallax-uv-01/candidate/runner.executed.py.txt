"""One frozen parallax counterexample and two controls; unchanged existing WARP host."""
import argparse, hashlib, importlib.util, json, os, re, struct
from pathlib import Path
OUT=Path(__file__).resolve().parent
ROOT=OUT.parents[2]
S=ROOT/'Runtime/Resources/HybridLumenGI'
H=ROOT/'LocalComparison/Harness'
FROZEN=OUT/'frozen'
PRIOR=ROOT/'LocalComparison/Review/parallel-color-dynamics-01/surface'
T=ROOT/'Tests/StandaloneRadianceValidity'
BOUND=2e-6
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
FIXED_DEFINES=['_METALLICSPECGLOSSMAP','_DETAIL_MULX2','_OCCLUSIONMAP','_EMISSION']
UNSHIFTED_UV=[.48,.4]
DISPLACED_UV=[.502188156899485,.41407039768868076]
EXPECTED_OLD=[.2055932928,.15168384,.2245088664,.5875,.12,.075,.04625,1]
EXPECTED_NEW=[.21338153357195896,.1559212979313438,.22571812243813022,.5927763991332553,
              .12554703922487126,.07763819956662764,.04694337990310891,1]

def main(stage):
    folder=OUT/stage;folder.mkdir(exist_ok=False)
    (folder/'runner.executed.py.txt').write_bytes(Path(__file__).read_bytes())
    commands=[]
    try:
        prepared=json.loads((OUT/'prepared-manifest.json').read_text())
        for item in prepared['files']:
            assert sha(Path(item['path']))==item['sha256'],'Prepared dependency changed: '+item['path']
        # Existing include closure is reused by reference, not copied into a new framework.
        include_manifest=json.loads((PRIOR/'include-manifest.json').read_text())
        for item in include_manifest['files']:
            assert sha(Path(item['path']))==item['sha256'],'Pinned include changed: '+item['path']
        spec=importlib.util.spec_from_file_location('surface_alpha_reuse',H/'run-surface-alpha-source.py')
        alpha=importlib.util.module_from_spec(spec);spec.loader.exec_module(alpha)
        DXC,INC=alpha.DXC,alpha.INC
        references=json.loads((OUT/'reference-manifest.json').read_text())
        for item in references:
            frozen=OUT/item['path'];assert sha(frozen)==item['sha256'].lower()
            if frozen.name!='HybridLumenGISurface.shader':
                assert Path(item['source']).read_bytes()==frozen.read_bytes(),'Installed reference changed'
                package='com.unity.render-pipelines.core' if frozen.name=='ParallaxMapping.hlsl' else 'com.unity.render-pipelines.universal'
                subdir='Shaders' if frozen.name in ['LitInput.hlsl','LitForwardPass.hlsl'] else 'ShaderLibrary'
                assert (INC/'Packages'/package/subdir/frozen.name).read_bytes()==frozen.read_bytes(),'Include/reference mismatch'
        source_path=FROZEN/'HybridLumenGISurface.shader' if stage=='baseline' else S/'HybridLumenGISurface.shader'
        product=source_path.read_bytes();(folder/'HybridLumenGISurface.shader').write_bytes(product)
        shader=product.decode('utf-8')
        has_parallax='half3 viewDirTS' in shader
        assert has_parallax==(stage=='candidate'),'Unexpected shader phase'
        for name in ['contract.md','proposal.txt','cases.json','reference-manifest.json','prepared-manifest.json','SurfaceParallaxAdapters.hlsl']:
            (folder/name).write_bytes((OUT/name).read_bytes())
        abi=(T/'RadianceValidityHarness.hlsl').read_text()
        abi=abi[abi.index('struct RadianceInput'):abi.index('// Explicit dependency adapter:')]
        structs=[]
        for name in ['Attributes','Varyings','SurfaceOutput']:
            match=re.search(r'\bstruct\s+'+name+r'\s*\{.*?\};',shader,re.S);assert match,name
            structs.append(match.group())
        actual='\n'.join(structs)+'\n'+alpha.prior.extract(shader,r'^\s*Varyings Vert\(')+'\n'+alpha.prior.extract(shader,r'^\s*SurfaceOutput Frag\(')
        (folder/'ActualSurface.hlsl').write_text(actual,encoding='utf-8')
        view_source=(FROZEN/'ShaderVariablesFunctions.hlsl').read_text()
        patterns=[r'^VertexPositionInputs GetVertexPositionInputs\(',r'^VertexNormalInputs GetVertexNormalInputs\(float3 normalOS, float4 tangentOS\)',r'^half3 GetWorldSpaceNormalizeViewDir\(']
        (folder/'ActualViewHelpers.hlsl').write_text('\n\n'.join(alpha.prior.extract(view_source,p) for p in patterns),encoding='utf-8')
        (folder/'ParallaxMapping.hlsl').write_bytes((FROZEN/'ParallaxMapping.hlsl').read_bytes())
        for name in ['HybridLumenGIScreenMaterial.hlsl','HybridLumenGIReceiverPolicyCapture.hlsl']:
            (folder/name).write_bytes((S/name).read_bytes())
        source=folder/'actual-parallax.hlsl'
        source.write_text(abi+'\nstatic RadianceInput active;\n'+(OUT/'SurfaceParallaxAdapters.hlsl').read_text(),encoding='utf-8')
        # Same existing source-matched executable already used by the accepted65 pair.
        old_report=json.loads((PRIOR/'candidate/analysis.json').read_text())
        exe=Path(old_report['runner'])
        assert sha(exe)==old_report['runnerSha256'] and sha(DXC)==old_report['dxcSha256']
        host_source=exe.parents[2]/'source'
        assert sha(host_source/'RadianceValidityWarp.cpp')==sha(T/'RadianceValidityWarp.cpp.txt')
        assert sha(host_source/'CMakeLists.txt')==sha(T/'CMakeLists.txt')
        if stage=='candidate':
            old=json.loads((OUT/'baseline/analysis.json').read_text())
            assert old['passed'] and old['oldCounterexampleEstablished']
            assert old['runnerSha256']==sha(exe) and old['dxcSha256']==sha(DXC)
            assert (folder/'runner.executed.py.txt').read_bytes()==(OUT/'baseline/runner.executed.py.txt').read_bytes()
        cases=json.loads((OUT/'cases.json').read_text());assert len(cases)==3
        rows=[]
        for variant in ['on','off']:
            selected=[case for case in cases if case['variant']==variant]
            data=bytearray(struct.pack('<I',len(selected)))
            for case in selected:
                row=bytearray(208);struct.pack_into('<f',row,16,case['height']);data+=row
            inputs=folder/(variant+'-inputs.bin');inputs.write_bytes(data)
            if stage=='candidate':assert data==(OUT/'baseline'/inputs.name).read_bytes()
            args=[DXC,'-HV','2018','-T','cs_6_0','-E','CSSurfaceParallax','-I',folder,'-Fo',folder/(variant+'.dxil'),'-Fc',folder/(variant+'.ll')]
            defines=FIXED_DEFINES+(['_PARALLAXMAP'] if variant=='on' else [])+(['HLGI_SURFACE_HAS_PARALLAX'] if has_parallax else [])
            for define in defines:args+=['-D',define+'=1']
            alpha.invoke(folder,variant+'-compile',args+[source],commands)
            binary=folder/(variant+'.bin')
            alpha.invoke(folder,variant+'-warp',[exe,folder/(variant+'.dxil'),inputs,binary],commands)
            raw=binary.read_bytes();assert len(raw)==368*len(selected)
            before=(OUT/'baseline'/binary.name).read_bytes() if stage=='candidate' else raw
            for index,case in enumerate(selected):
                block=raw[index*368:(index+1)*368];old_block=before[index*368:(index+1)*368]
                values=struct.unpack_from('<24f',block,0);predicates=struct.unpack_from('<4I',block,128)
                shifted=stage=='candidate' and case['counterexample']
                expected=EXPECTED_NEW if shifted else EXPECTED_OLD
                uv=DISPLACED_UV if shifted else UNSHIFTED_UV;detail=[uv[0]*.5+.25,uv[1]*.75+.1]
                uv_expected=uv+uv+uv+uv+uv+uv+detail
                uv_actual=list(values[8:10])+list(values[12:16])+list(values[16:20])+list(values[20:24])
                assert len(uv_actual)==len(uv_expected)==14
                ref_match=max(abs(a-b) for a,b in zip(values[:8],EXPECTED_NEW))<=BOUND
                checks=dict(payload=max(abs(a-b) for a,b in zip(values[:8],expected))<=BOUND,
                    allMaterialUvs=max(abs(a-b) for a,b in zip(uv_actual,uv_expected))<=BOUND,
                    opaquePolicy=predicates==(1,1,1,1) and values[10]==.5 and values[11]==1 and values[7]==1,
                    finite=all(abs(v)<float('inf') for v in struct.unpack('<92f',block)),
                    expectedReferenceRole=ref_match==(stage=='candidate') if case['counterexample'] else True,
                    controlBytes=case['counterexample'] or block==old_block,
                    unrelatedBytes=block[40:48]==old_block[40:48] and block[96:]==old_block[96:])
                row=dict(case=case['name'],payload=values[:8],textureUvs=uv_actual,expectedUv=uv,
                         expected=expected,referenceMatch=ref_match,checks=checks)
                rows.append(row)
                (folder/'partial-rows.json').write_text(json.dumps(rows,indent=2))
                assert all(checks.values()),row
        if stage=='candidate':
            full=folder/'surface-full-pass.hlsl';full.write_text(re.search(r'HLSLPROGRAM(.*?)ENDHLSL',shader,re.S)[1])
            for variant in ['off','on']:
                for entry,profile,stage_define in [('Vert','vs_6_0','SHADER_STAGE_VERTEX'),('Frag','ps_6_0','SHADER_STAGE_FRAGMENT')]:
                    name='full-'+variant+'-'+entry.lower()
                    args=[DXC,'-HV','2018','-E',entry,'-T',profile,'-I',INC/'Adapters','-I',INC,'-I',folder,'-Fo',folder/(name+'.dxil')]
                    defines=['SHADER_API_D3D11',stage_define,'UNITY_COMPILER_DXC']+FIXED_DEFINES+(['_PARALLAXMAP'] if variant=='on' else [])
                    for define in defines:args+=['-D',define+'=1']
                    alpha.invoke(folder,name+'-compile',args+['-D','UNITY_VERSION=600000',full],commands)
        for item in prepared['files']:
            assert sha(Path(item['path']))==item['sha256'],'Dependency changed during execution'
        for item in include_manifest['files']:
            assert sha(Path(item['path']))==item['sha256'],'Include changed during execution'
        assert source_path.read_bytes()==product,'This stage source changed during execution'
        result=dict(passed=True,stage=stage,oldCounterexampleEstablished=stage=='baseline',rows=rows,commands=commands,
            runner=str(exe),runnerSha256=sha(exe),dxcSha256=sha(DXC),productSha256=sha(folder/'HybridLumenGISurface.shader'),
            floatAbsoluteBound=BOUND,scope='Actual product Vert x3 and Frag plus actual URP view/parallax helpers; fixed transform/barycentric/texture/raster adapters on existing WARP. No Unity/native raster or material matrix.')
        (folder/'analysis.json').write_text(json.dumps(result,indent=2))
        print(json.dumps({k:v for k,v in result.items() if k not in ['rows','commands']}))
    except Exception as error:
        (folder/'failure.json').write_text(json.dumps(dict(stage=stage,error=repr(error),commands=commands),indent=2));raise

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('stage',choices=['baseline','candidate']);main(parser.parse_args().stage)
