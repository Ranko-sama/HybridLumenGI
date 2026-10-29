"""Prepared continuation; run only after the separate Pro qualification decision.
Original runner/failure and both on readbacks remain immutable. No on dispatch.
"""
import importlib.util, json, math, re, struct
from pathlib import Path
import run_parallax as frozen


def numeric_checks(block, shifted):
    assert len(block)==368
    values=struct.unpack_from('<24f',block);predicates=struct.unpack_from('<4I',block,128)
    expected=frozen.EXPECTED_NEW if shifted else frozen.EXPECTED_OLD
    uv=frozen.DISPLACED_UV if shifted else frozen.UNSHIFTED_UV
    material=list(values[8:10])+list(values[12:16])+list(values[16:20])+list(values[20:24])
    expected_uv=uv*6+[uv[0]*.5+.25,uv[1]*.75+.1]
    assert max(abs(a-b) for a,b in zip(values[:8],expected))<=frozen.BOUND
    assert max(abs(a-b) for a,b in zip(material,expected_uv))<=frozen.BOUND
    assert predicates==(1,1,1,1) and values[10]==.5 and values[11]==1 and values[7]==1
    assert all(math.isfinite(v) for v in struct.unpack('<92f',block))


def main():
    out=frozen.OUT;candidate=out/'candidate';baseline=out/'baseline'
    folder=out/'continuation';folder.mkdir(exist_ok=False);commands=[]
    (folder/'runner.executed.py.txt').write_bytes(Path(__file__).read_bytes())
    try:
        pins=json.loads((out/'continuation-inputs.json').read_text())
        prepared=json.loads((out/'prepared-manifest.json').read_text())
        includes=json.loads((frozen.PRIOR/'include-manifest.json').read_text())
        def unchanged():
            for item in pins['files']+prepared['files']+includes['files']:
                assert frozen.sha(Path(item['path']))==item['sha256'],'Source/input changed: '+item['path']
        unchanged()
        assert frozen.BOUND==2e-6
        assert frozen.sha(candidate/'HybridLumenGISurface.shader')=='289acdf7ef8a05e48c9cff491f7e5d823820ab77a0047bf655bf92bc3a97cb6a'
        assert (candidate/'HybridLumenGISurface.shader').read_bytes()==(frozen.S/'HybridLumenGISurface.shader').read_bytes()
        assert json.loads((baseline/'analysis.json').read_text())['passed']
        original_failure=json.loads((candidate/'failure.json').read_text())
        assert [c['name'] for c in original_failure['commands']]==['on-compile','on-warp']
        rows=json.loads((candidate/'partial-rows.json').read_text())
        assert all(rows[0]['checks'].values())
        assert [k for k,v in rows[1]['checks'].items() if not v]==['controlBytes']
        old=(baseline/'on.bin').read_bytes();new=(candidate/'on.bin').read_bytes()
        assert len(old)==len(new)==736
        numeric_checks(old[:368],False);numeric_checks(new[:368],True)
        assert max(abs(a-b) for a,b in zip(struct.unpack_from('<8f',old),frozen.EXPECTED_NEW))>frozen.BOUND
        assert old[40:48]==new[40:48] and old[96:368]==new[96:368]
        old,new=old[368:],new[368:]
        numeric_checks(old,False);numeric_checks(new,False)
        allowed={0:('diffuse.r',frozen.EXPECTED_OLD[0]),4:('diffuse.g',frozen.EXPECTED_OLD[1]),
                 8:('diffuse.b',frozen.EXPECTED_OLD[2]),88:('detailUv.x',.49)}
        changed=[i for i in range(0,368,4) if old[i:i+4]!=new[i:i+4]]
        assert set(changed)==set(allowed),'Unexpected differing field'
        numeric=[]
        for offset,(name,reference) in allowed.items():
            a=struct.unpack_from('<f',old,offset)[0];b=struct.unpack_from('<f',new,offset)[0]
            assert math.isfinite(a) and math.isfinite(b)
            assert max(abs(a-reference),abs(b-reference),abs(a-b))<=frozen.BOUND
            numeric.append(dict(field=name,byteOffset=offset,baseline=a,candidate=b,reference=reference))
        assert all(old[i:i+4]==new[i:i+4] for i in range(0,368,4) if i not in allowed)
        (folder/'existing-zero-readback.json').write_text(json.dumps(dict(fields=numeric,
            absoluteBound=frozen.BOUND,allOtherBytesExact=True,originalFailureRetained=True),indent=2))

        spec=importlib.util.spec_from_file_location('surface_alpha_reuse',frozen.H/'run-surface-alpha-source.py')
        alpha=importlib.util.module_from_spec(spec);spec.loader.exec_module(alpha)
        prior=json.loads((frozen.PRIOR/'candidate/analysis.json').read_text());exe=Path(prior['runner'])
        assert frozen.sha(exe)==prior['runnerSha256'] and frozen.sha(alpha.DXC)==prior['dxcSha256']
        host=exe.parents[2]/'source'
        assert frozen.sha(host/'RadianceValidityWarp.cpp')==frozen.sha(frozen.T/'RadianceValidityWarp.cpp.txt')
        assert frozen.sha(host/'CMakeLists.txt')==frozen.sha(frozen.T/'CMakeLists.txt')
        # Only the original unexecuted off record, using the original candidate extraction.
        inputs=baseline/'off-inputs.bin';raw_inputs=inputs.read_bytes()
        assert len(raw_inputs)==212 and struct.unpack_from('<I',raw_inputs)[0]==1
        assert struct.unpack_from('<f',raw_inputs,20)[0]==1
        args=[alpha.DXC,'-HV','2018','-T','cs_6_0','-E','CSSurfaceParallax','-I',candidate,
              '-Fo',folder/'off.dxil','-Fc',folder/'off.ll']
        for define in frozen.FIXED_DEFINES+['HLGI_SURFACE_HAS_PARALLAX']:args+=['-D',define+'=1']
        alpha.invoke(folder,'off-compile',args+[candidate/'actual-parallax.hlsl'],commands)
        alpha.invoke(folder,'off-warp',[exe,folder/'off.dxil',inputs,folder/'off.bin'],commands)
        assert (folder/'off.bin').read_bytes()==(baseline/'off.bin').read_bytes(),'Keyword-off record differs'
        numeric_checks((folder/'off.bin').read_bytes(),False)
        # The four original unexecuted complete product entries; unchanged flags/includes.
        shader=(candidate/'HybridLumenGISurface.shader').read_text()
        full=folder/'surface-full-pass.hlsl';full.write_text(re.search(r'HLSLPROGRAM(.*?)ENDHLSL',shader,re.S)[1])
        for variant in ['off','on']:
            for entry,profile,stage in [('Vert','vs_6_0','SHADER_STAGE_VERTEX'),('Frag','ps_6_0','SHADER_STAGE_FRAGMENT')]:
                name='full-'+variant+'-'+entry.lower()
                args=[alpha.DXC,'-HV','2018','-E',entry,'-T',profile,'-I',alpha.INC/'Adapters',
                      '-I',alpha.INC,'-I',candidate,'-Fo',folder/(name+'.dxil')]
                defines=['SHADER_API_D3D11',stage,'UNITY_COMPILER_DXC']+frozen.FIXED_DEFINES+(['_PARALLAXMAP'] if variant=='on' else [])
                for define in defines:args+=['-D',define+'=1']
                alpha.invoke(folder,name+'-compile',args+['-D','UNITY_VERSION=600000',full],commands)
        unchanged()
        assert (candidate/'HybridLumenGISurface.shader').read_bytes()==(frozen.S/'HybridLumenGISurface.shader').read_bytes()
        result=dict(passed=True,originalCandidateStatus='failed; retained unchanged',
            qualification='Only four frozen zero-offset float fields use the existing 2e-6 bound; all other bytes exact',
            existingPrimaryCaseReused=True,zeroOffset=numeric,keywordOffAll368BytesExact=True,
            fullEntriesCompiled=4,onRecompiledOrRedispatched=False,hostRebuilt=False,commands=commands)
        (folder/'analysis.json').write_text(json.dumps(result,indent=2));print(json.dumps(result))
    except Exception as error:
        (folder/'failure.json').write_text(json.dumps(dict(error=repr(error),commands=commands),indent=2));raise


if __name__=='__main__':main()
