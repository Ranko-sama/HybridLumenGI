"""Freeze only current production input-generation functions for a diagnostic compute.

No ray trace, PDF output, material color, cache or measured radiance enters this
shader. The independent reference receives its origin/direction outputs as inputs.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[3]
SHADERS = ROOT / 'Runtime/Resources/HybridLumenGI'
DXC = Path('C:/Program Files (x86)/Windows Kits/10/bin/10.0.26100.0/x64/dxc.exe')


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def extract(text, names):
    result, counts = [], {name: 0 for name in names}
    for match in re.finditer(r'^(?:bool|float|float3|uint) (' + '|'.join(names) + r')\(', text, re.M):
        depth = 0
        for end in range(text.index('{', match.start()), len(text)):
            if text[end] == '{':
                depth += 1
            elif text[end] == '}':
                depth -= 1
                if depth == 0:
                    result.append(text[match.start():end + 1])
                    counts[match.group(1)] += 1
                    break
        else:
            raise RuntimeError('Unterminated production function')
    assert all(count == 1 for count in counts.values()), counts
    return '\n\n'.join(result) + '\n'


HEADER = '''// Diagnostic input replay only. No product radiance or hit answer.
#pragma kernel CSReferenceInputs
#pragma target 5.0
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "ReferenceScreenSampling.hlsl"
#include "ReferenceHit.hlsl"
Texture2D<float> _HLGI_Depth;
Texture2D<float4> _HLGI_Normals;
float4 _HLGI_Size,_HLGI_FullSize;
float4x4 _HLGI_InvVP,_HLGI_View;
int _HLGI_NormalsOct,_HLGI_FrameIndex,_HLGI_Rays;
float _HLGI_RayBias,_HLGI_GuideWeight;
StructuredBuffer<uint2> _ReferencePixels;
int _ReferencePixelCount;
RWStructuredBuffer<float4> _ReferenceRows;
#include "ReferenceInputFunctions.hlsl"
'''

ENTRY = '''
[numthreads(64,1,1)]
void CSReferenceInputs(uint3 dispatchId:SV_DispatchThreadID)
{
    if(dispatchId.x>=(uint)_ReferencePixelCount)return;
    uint group=dispatchId.x;
    // Fixed capacity of eight directions per receiver, independent of ray count.
    [unroll] for(uint clearIndex=0;clearIndex<48;clearIndex++)_ReferenceRows[group*48+clearIndex]=0;
    if(_HLGI_Rays<1 || _HLGI_Rays>8 || _HLGI_GuideWeight!=0)return;
    uint2 pixel=_ReferencePixels[group];
    if(any(pixel>=(uint2)_HLGI_Size.xy))return;
    uint2 fullPixel=HLGIFullPixelForGiPixel(pixel,(uint2)_HLGI_Size.xy,(uint2)_HLGI_FullSize.xy);
    float2 uv=HLGIFullPixelCenterUv(fullPixel,(uint2)_HLGI_FullSize.xy);
    float depth=_HLGI_Depth.Load(int3(fullPixel,0));
    if(!isfinite(depth) || !ValidDepth(depth))return;
    float3 position=WorldPosition(uv,depth,_HLGI_InvVP),normal=NormalAt(uv),geometricNormal;
    bool hasGeometry=HLGITryScreenGeometricNormal(uv,depth,position,geometricNormal);
    if(!all(isfinite(position)) || !all(isfinite(normal)))return;
    // Guide weight is zero, so CSTrace does not perform its world-match/guide query.
    float3 origin=position+(hasGeometry?HLGIOffsetNormal(geometricNormal,normal):normal)*_HLGI_RayBias;
    uint rng=HLGIHash((pixel.x+pixel.y*(uint)_HLGI_Size.x+HLGIHash((uint)_HLGI_FrameIndex+1))^0x63D83595u);
    [loop] for(int sample=0;sample<_HLGI_Rays;sample++)
    {
        float discardedWeight;
        // Actual transport's emissive<=0 branch calls this exact function.
        // There are no area draws in the frozen zero-emitter scene.
        float3 direction=HLGISampleDirection(normal,0,rng,discardedWeight);
        uint offset=(group*8+(uint)sample)*6;
        _ReferenceRows[offset]=float4(origin,1);
        _ReferenceRows[offset+1]=float4(direction,0);
        _ReferenceRows[offset+2]=float4(position,depth);
        _ReferenceRows[offset+3]=float4(normal,1);
        _ReferenceRows[offset+4]=float4(geometricNormal,hasGeometry?1:0);
        _ReferenceRows[offset+5]=asfloat(uint4(pixel,(uint)_HLGI_FrameIndex,(uint)sample));
    }
}
'''


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, default=Path(__file__).with_name('generated'))
    parser.add_argument('--compile', action='store_true')
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    paths = {name: SHADERS / ('HybridLumenGI' + name + '.hlsl') for name in
             ('Transport', 'Kernels', 'EmissiveSampling', 'ScreenSampling', 'Hit')}
    text = {name: path.read_text(encoding='utf-8-sig') for name, path in paths.items()}
    assert 'if(emissive<=0) return HLGISampleDirection(normal,guide,rng,weight);' in text['EmissiveSampling']
    assert 'if(hasGeometry && _HLGI_GuideWeight>0)' in text['Kernels']
    assert 'if(_HLGI_AreaEmitterCount>0)lightStatus=HLGISampleAreaEmitter' in text['Kernels']
    assert 'uint rng=HLGIHash((id.x+id.y*(uint)_HLGI_Size.x+HLGIHash((uint)_HLGI_FrameIndex+1))^0x63D83595u);' in text['Kernels']
    functions = extract(text['Transport'], ['HLGIHash', 'Random', 'CosineHemisphere', 'HLGISampleDirection'])
    functions += extract(text['Kernels'], ['ValidDepth', 'WorldPosition', 'NormalAt', 'HLGIScreenDepthDelta',
                                         'HLGIScreenDepthDerivative', 'HLGITryScreenGeometricNormal'])
    (output / 'ReferenceInputFunctions.hlsl').write_text(functions, encoding='utf-8')
    (output / 'ReferenceScreenSampling.hlsl').write_bytes(paths['ScreenSampling'].read_bytes())
    (output / 'ReferenceHit.hlsl').write_bytes(paths['Hit'].read_bytes())
    (output / 'FiniteWallReferenceInputs.compute').write_text(HEADER + ENTRY, encoding='utf-8')
    (output / 'generate_sampler.executed.py.txt').write_bytes(Path(__file__).read_bytes())
    manifest = dict(kernel='CSReferenceInputs', sourceSha256={str(path.relative_to(ROOT)): sha(path) for path in paths.values()},
                    generatedSha256={path.name: sha(path) for path in output.iterdir()},
                    layout='8 ray rows per pixel, each 6 float4=96 bytes; final float4 is raw uint4 identity bits',
                    compilePassed=None, nativeExecuted=False, productRadianceRead=False,
                    restrictions=['guideWeight=0', 'emissiveWeight=0', 'areaEmitterCount=0', 'same Work.frame/pixel/dimensions/depth/normals/InvVP/View as CSTrace'])
    if args.compile:
        includes = Path(os.environ['TEMP']) / 'HybridLumenGI-shader-validation'
        command = [str(DXC), '-HV', '2018', '-O3', '-T', 'cs_6_0', '-E', 'CSReferenceInputs',
                   '-I', str(includes / 'Adapters'), '-I', str(includes), '-I', str(output),
                   '-D', 'SHADER_API_D3D11=1', '-D', 'SHADER_STAGE_COMPUTE=1',
                   '-D', 'UNITY_COMPILER_DXC=1', '-D', 'UNITY_VERSION=600000',
                   '-Fo', str(output / 'sampler.dxil'), str(output / 'FiniteWallReferenceInputs.compute')]
        completed = subprocess.run(command, capture_output=True, text=True)
        (output / 'compile.log').write_text(completed.stdout + completed.stderr, encoding='utf-8')
        manifest.update(compileCommand=command, compileExitCode=completed.returncode, compilePassed=completed.returncode == 0,
                        compilerSha256=sha(DXC), dxilSha256=sha(output / 'sampler.dxil') if completed.returncode == 0 else None)
    (output / 'manifest.json').write_text(json.dumps(manifest, indent=2), encoding='utf-8')
    assert not args.compile or manifest['compilePassed'], 'Compile failed; original attempt preserved'
    print(json.dumps(dict(output=str(output), kernel=manifest['kernel'], compilePassed=manifest['compilePassed'])))


if __name__ == '__main__':
    main()
