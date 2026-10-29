"""One fixed Surface clamp-order baseline/candidate; reuse existing WARP host."""
import argparse
import ast
import hashlib
import importlib.util
import json
import os
import re
import struct
from pathlib import Path

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[3]
FROZEN = OUT / 'frozen'
H = ROOT / 'LocalComparison/Harness'
S = ROOT / 'Runtime/Resources/HybridLumenGI'
T = ROOT / 'Tests/StandaloneRadianceValidity'
OLD = b'saturate(albedo) * diffuseFraction'
NEW = b'saturate(albedo * diffuseFraction)'
VARIANTS = [('metal', []), ('spec', ['_SPECULAR_SETUP'])]
BOUND = 2e-6
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()

ENTRY = r'''
[numthreads(64,1,1)] void CSSurfaceClampOrder(uint3 id:SV_DispatchThreadID)
{
    if(id.x>=_Count)return;
    active=_Inputs[id.x];
    discarded=false;clipCalls=0;minimumClip=3.402823466e+38;
    _BaseColor=active.incoming;_Metallic=active.control.x;
    _WorkflowMode=active.control.y;_SpecColor=active.history;
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
    folder = OUT / stage
    folder.mkdir(exist_ok=False)
    # Preserve every attempt, including a source/dependency failure before dispatch.
    (folder / 'runner.executed.py.txt').write_bytes(Path(__file__).read_bytes())
    commands = []
    try:
        manifest = json.loads((OUT / 'prepared-manifest.json').read_text(encoding='utf-8-sig'))
        for row in manifest['files']:
            path = OUT / row['path']
            assert sha(path) == row['sha256'], 'Frozen preparation changed: ' + str(path)
        include_manifest = json.loads((OUT / 'include-manifest.json').read_text(encoding='utf-8-sig'))
        for row in include_manifest['files'] + manifest['tools']:
            assert sha(Path(row['path'])) == row['sha256'], 'Pinned include/tool changed: ' + row['path']
        for name in ['run-surface-alpha-source.py', 'run-surface-detail-source.py', 'run-screen-receive-shadows-source.py']:
            assert (H / name).read_bytes() == (FROZEN / (name + '.txt')).read_bytes(), name
        for name in ['RadianceValidityHarness.hlsl', 'RadianceValidityWarp.cpp.txt', 'CMakeLists.txt']:
            assert (T / name).read_bytes() == (FROZEN / name).read_bytes(), name
        spec = importlib.util.spec_from_file_location('surface_alpha_reuse', H / 'run-surface-alpha-source.py')
        alpha = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(alpha)
        DXC, INC, URP = alpha.DXC, alpha.INC, alpha.URP
        dependencies = []
        for rel in ['ShaderLibrary/BRDF.hlsl', 'Shaders/LitInput.hlsl', 'Shaders/Lit.shader']:
            path = URP / rel
            assert path.read_bytes() == (FROZEN / path.name).read_bytes(), rel
            if path.suffix == '.hlsl':
                assert sha(path) == sha(INC / 'Packages/com.unity.render-pipelines.universal' / rel), rel
            dependencies.append(dict(path=str(path), sha256=sha(path)))
        for name in ['HybridLumenGIScreenMaterial.hlsl', 'HybridLumenGIReceiverPolicyCapture.hlsl']:
            assert (S / name).read_bytes() == (FROZEN / name).read_bytes(), name
            (folder / name).write_bytes((FROZEN / name).read_bytes())
            dependencies.append(dict(path=str(S / name), sha256=sha(S / name)))
        baseline = (FROZEN / 'HybridLumenGISurface.shader').read_bytes()
        assert baseline.count(OLD) == 1
        expected_product = baseline if stage == 'baseline' else baseline.replace(OLD, NEW)
        assert (S / 'HybridLumenGISurface.shader').read_bytes() == expected_product, 'Unexpected product edit'
        (folder / 'HybridLumenGISurface.shader').write_bytes(expected_product)
        shader = expected_product.decode('utf-8')
        for name in ['contract.md', 'cases.json', 'prepared-manifest.json', 'include-manifest.json']:
            (folder / name).write_bytes((OUT / name).read_bytes())
        cases = json.loads((OUT / 'cases.json').read_text(encoding='utf-8'))
        assert len(cases) == 3
        tree = ast.parse((FROZEN / 'run-surface-detail-source.py.txt').read_text(encoding='utf-8'))
        adapter = next(ast.literal_eval(x.value) for x in tree.body if isinstance(x, ast.Assign)
                       and any(isinstance(t, ast.Name) and t.id == 'adapter' for t in x.targets))
        replacements = {
            '// Only opaque/non-clipped inputs; raster coverage is outside this source contract.\n#define clip(x)': alpha.CLIP,
            'float4 Sample_BaseMap(float2 uv){return uv.x<.5&&uv.y<.5?float4(.5,.75,.25,1):float4(.25,.5,.75,1);}': 'float4 Sample_BaseMap(float2 uv){return 1;}',
            'float4 Sample_DetailMask(float2 uv){return float4(.125,.25,.5,uv.x<.5&&uv.y<.5?.75:.25);}': 'float4 Sample_DetailMask(float2 uv){return 1;}',
            'float4 Sample_DetailAlbedoMap(float2 uv){return uv.x>=.5&&uv.y>=.5?float4(.75,.25,.625,1):float4(.25,.75,.5,1);}': 'float4 Sample_DetailAlbedoMap(float2 uv){return active.guide;}',
            'float4 Sample_OcclusionMap(float2 uv){return 1;}': 'float4 Sample_OcclusionMap(float2 uv){return float4(.125,.5,.75,1);}',
        }
        for before, after in replacements.items():
            assert adapter.count(before) == 1, before
            adapter = adapter.replace(before, after)
        abi = (FROZEN / 'RadianceValidityHarness.hlsl').read_text(encoding='utf-8')
        abi = abi[abi.index('struct RadianceInput'):abi.index('// Explicit dependency adapter:')]
        bodies = alpha.prior.extract(shader, r'^\s*Varyings Vert\(') + '\n' + alpha.prior.extract(shader, r'^\s*SurfaceOutput Frag\(')
        source = folder / 'actual-surface.hlsl'
        source.write_text(abi + '\nstatic RadianceInput active;\n' + adapter + bodies + ENTRY, encoding='utf-8')
        matches = []
        for path in Path(os.environ['TEMP']).glob('hlgi-radiance-validity-warp-*'):
            exe = path / 'build/Release/RadianceValidityWarp.exe'
            cpp, cmake = path / 'source/RadianceValidityWarp.cpp', path / 'source/CMakeLists.txt'
            if exe.is_file() and cpp.is_file() and cmake.is_file() and sha(cpp) == sha(FROZEN / 'RadianceValidityWarp.cpp.txt') and sha(cmake) == sha(FROZEN / 'CMakeLists.txt'):
                matches.append(exe)
        assert matches, 'Existing source-matched WARP host required'
        exe = sorted(matches, key=lambda p: p.stat().st_mtime)[-1]
        if stage == 'candidate':
            previous = json.loads((OUT / 'baseline/analysis.json').read_text())
            assert previous['passed'] and previous['oldCounterexampleEstablished']
            assert previous['runnerSha256'] == sha(exe) and previous['dxcSha256'] == sha(DXC)
            assert (folder / 'runner.executed.py.txt').read_bytes() == (OUT / 'baseline/runner.executed.py.txt').read_bytes()
        rows, failures = [], []
        for variant, defines in VARIANTS:
            selected = [case for case in cases if case['variant'] == variant]
            data = bytearray(struct.pack('<I', len(selected)))
            for case in selected:
                row = bytearray(208)
                struct.pack_into('<4f', row, 0, *case['baseColor'])
                struct.pack_into('<4f', row, 16, case['metallic'], 0 if variant == 'spec' else 1, 0, 0)
                struct.pack_into('<4f', row, 64, *case['detail'])
                struct.pack_into('<4f', row, 80, *case['specular'])
                data += row
            inputs = folder / (variant + '-inputs.bin')
            inputs.write_bytes(data)
            if stage == 'candidate':
                assert data == (OUT / 'baseline' / inputs.name).read_bytes()
            args = [DXC, '-HV', '2018', '-T', 'cs_6_0', '-E', 'CSSurfaceClampOrder', '-D', '_EMISSION=1', '-D', '_OCCLUSIONMAP=1', '-D', '_DETAIL_MULX2=1', '-I', folder, '-Fo', folder / (variant + '.dxil')]
            for define in defines:
                args += ['-D', define + '=1']
            alpha.invoke(folder, variant + '-compile', args + [source], commands)
            binary = folder / (variant + '.bin')
            alpha.invoke(folder, variant + '-warp', [exe, folder / (variant + '.dxil'), inputs, binary], commands)
            raw = binary.read_bytes()
            assert len(raw) == 368 * len(selected)
            before = (OUT / 'baseline' / binary.name).read_bytes() if stage == 'candidate' else raw
            for index, case in enumerate(selected):
                offset = 368 * index
                diffuse = struct.unpack_from('<4f', raw, offset)
                emission = struct.unpack_from('<4f', raw, offset + 16)
                predicates = struct.unpack_from('<4I', raw, offset + 128)
                expected = case['baselineExpected' if stage == 'baseline' else 'candidateExpected']
                reference_match = max(abs(x-y) for x, y in zip(diffuse[:3], case['candidateExpected'])) <= BOUND
                checks = dict(expected=max(abs(x-y) for x, y in zip(diffuse[:3], expected)) <= BOUND,
                              referenceRole=reference_match == (stage == 'candidate' or not case['counterexample']),
                              payload=diffuse[3] == .5 and emission == (.125,.25,.5,1) and predicates == (1,1,1,1),
                              unrelatedUnchanged=raw[offset+12:offset+368] == before[offset+12:offset+368],
                              controlsUnchanged=case['counterexample'] or raw[offset:offset+368] == before[offset:offset+368],
                              unaffectedChannels=not case['counterexample'] or raw[offset+4:offset+12] == before[offset+4:offset+12])
                if not all(checks.values()):
                    failures.append(case['name'])
                rows.append(dict(case=case['name'], diffuse=diffuse, expected=expected, emission=emission, predicates=predicates, checks=checks))
        if stage == 'candidate':
            full = folder / 'surface-full-pass.hlsl'
            full.write_text(re.search(r'HLSLPROGRAM(.*?)ENDHLSL', shader, re.S)[1], encoding='utf-8')
            for variant, defines in VARIANTS:
                for detail in ['_DETAIL_MULX2', '_DETAIL_SCALED']:
                    name = 'full-' + variant + '-' + detail.lower()
                    args = [DXC, '-HV', '2018', '-E', 'Frag', '-T', 'ps_6_0', '-I', INC / 'Adapters', '-I', INC, '-I', folder, '-Fo', folder / (name + '.dxil')]
                    for define in ['SHADER_API_D3D11', 'SHADER_STAGE_FRAGMENT', 'UNITY_COMPILER_DXC', '_EMISSION', '_OCCLUSIONMAP', detail] + defines:
                        args += ['-D', define + '=1']
                    alpha.invoke(folder, name + '-compile', args + ['-D', 'UNITY_VERSION=600000', full], commands)
        for row in include_manifest['files'] + manifest['tools']:
            assert sha(Path(row['path'])) == row['sha256'], 'Pinned include/tool changed during execution: ' + row['path']
        assert (S / 'HybridLumenGISurface.shader').read_bytes() == expected_product
        for name in ['HybridLumenGIScreenMaterial.hlsl', 'HybridLumenGIReceiverPolicyCapture.hlsl']:
            assert (S / name).read_bytes() == (FROZEN / name).read_bytes(), name
        result = dict(passed=not failures, stage=stage, oldCounterexampleEstablished=stage == 'baseline' and not failures,
                      rows=rows, failures=failures, commands=commands, dependencies=dependencies,
                      runner=str(exe), runnerSha256=sha(exe), dxcSha256=sha(DXC),
                      productSha256=sha(folder / 'HybridLumenGISurface.shader'), sourceSha256=sha(source), colorAbsoluteBound=BOUND,
                      scope='Actual Vert/Frag with fixed shader-space texture/raster adapters on existing WARP host; candidate full fragment compilation. No Unity/native raster/image or performance qualification.')
        (folder / 'analysis.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
        print(json.dumps({key:value for key,value in result.items() if key not in ['rows','commands','dependencies']}))
        assert result['passed']
    except Exception as error:
        (folder / 'failure.json').write_text(json.dumps(dict(stage=stage, error=repr(error), commands=commands), indent=2), encoding='utf-8')
        raise


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('stage', choices=['baseline', 'candidate'])
    main(parser.parse_args().stage)
