"""One actual-source receiver prelude experiment; no Runtime mutation/Unity."""
import hashlib
import importlib.util
import json
import math
import os
from pathlib import Path
import struct
import subprocess

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
S=ROOT/'Runtime/Resources/HybridLumenGI'
T=ROOT/'Tests/StandaloneRadianceValidity'
INC=Path(os.environ['TEMP'])/'HybridLumenGI-shader-validation'
DXC=Path('C:/Program Files (x86)/Windows Kits/10/bin/10.0.26100.0/x64/dxc.exe')
spec=importlib.util.spec_from_file_location('input_extractor',ROOT/'LocalComparison/Reference/ColorBounceRectangle/generate_sampler.py')
extractor=importlib.util.module_from_spec(spec);spec.loader.exec_module(extractor)


def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def save(path,value):path.write_text(json.dumps(value,indent=2,allow_nan=False),encoding='utf8')


def trace_function(text):
    start=text.index('void CSTrace(');opened=text.index('{',start);depth=0
    for end in range(opened,len(text)):
        depth+=(text[end]=='{')-(text[end]=='}')
        if depth==0:return text[start:end+1]
    raise AssertionError('Unterminated CSTrace')


def main():
    out=HERE/'baseline';out.mkdir(exist_ok=False)
    names=['Hit','RayFootprint','ScreenSampling','ScreenGeometry','ScreenMaterial','EmissiveRecords','EmissiveSampling','Transport','Kernels']
    sources=[S/('HybridLumenGI'+name+'.hlsl') for name in names]+[HERE/'fixture.template.hlsl',Path(__file__),T/'RadianceValidityWarp.cpp.txt',T/'CMakeLists.txt',Path(extractor.__file__)]
    for path in sources:(out/path.name).write_bytes(path.read_bytes())
    save(out/'source-hashes.json',{p.relative_to(ROOT).as_posix():sha(p) for p in sources})
    packages={p.relative_to(INC).as_posix():sha(p) for top in ('Packages','Adapters') for p in (INC/top).rglob('*.hlsl')}
    save(out/'compiler-include-hashes.json',packages)
    kernels=(out/'HybridLumenGIKernels.hlsl').read_text(encoding='utf-8-sig')
    transport=(out/'HybridLumenGITransport.hlsl').read_text(encoding='utf-8-sig')
    functions=extractor.extract(kernels,['ValidDepth','WorldPosition','NormalAt','HLGIScreenDepthDelta','HLGIScreenDepthDerivative','HLGITryScreenRayFootprint','HLGITryScreenGeometricNormal','HLGITryScreenWorldMatch'])
    (out/'ActualScreenInputs.hlsl').write_text(functions,encoding='utf8')
    (out/'ActualSamplerFunctions.hlsl').write_text(extractor.extract(transport,['HLGIHash','Random','CosineHemisphere','HLGISampleDirection']),encoding='utf8')
    emissive=(out/'HybridLumenGIEmissiveSampling.hlsl').read_text(encoding='utf-8-sig')
    declaration='StructuredBuffer<HLGIEmissiveRecord> _HLGI_EmissiveProposals;'
    assert emissive.count(declaration)==1
    assert emissive.count('float _HLGI_EmissiveWeight;')==1
    (out/'ActualEmissiveSampling.hlsl').write_text(emissive.replace(declaration,'static HLGIEmissiveRecord _HLGI_EmissiveProposals[33];').replace('float _HLGI_EmissiveWeight;','static float _HLGI_EmissiveWeight;'),encoding='utf8')
    function=trace_function(kernels);start=function.index('{')+1;end=function.index('    float3 sum=0;')
    prelude=function[start:end]
    for name,destination in [('_HLGI_Output[id.xy]','capturedOutput'),('_HLGI_GeometryOut[id.xy]','capturedGeometry'),('_HLGI_MaterialOut[id.xy]','capturedMaterial')]:
        assert name in prelude;prelude=prelude.replace(name,destination)
    ray_start=function.index('        float3 origin=p+');ray_end=function.index('\n',function.index('        float3 dir=HLGISampleTransportDirection',ray_start))
    ray=function[ray_start:ray_end]
    template=(out/'fixture.template.hlsl').read_text()
    source=template.replace('// ACTUAL_CSTRACE_PRELUDE',prelude).replace('// ACTUAL_ORIGIN_AND_DIRECTION',ray)
    (out/'ActualReceiverPrelude.hlsl').write_text(prelude,encoding='utf8')
    (out/'ActualRayInput.hlsl').write_text(ray,encoding='utf8')
    (out/'fixture.hlsl').write_text(source,encoding='utf8')
    cases=[];blob=bytearray()
    for kind in ('tilted','aligned','world-miss','no-depth-support'):
        for guide in (0,.35):
            slope=0 if kind=='aligned' else .2
            depths=[.5-slope*((x+.5)/5*2-1)*.05 for y in range(5) for x in range(5)]
            if kind=='no-depth-support':depths=[.5 if i==12 else 0 for i in range(25)]
            row=struct.pack('<52f',guide,0 if kind=='world-miss' else 1,0,0,*depths,*([0]*23))
            blob+=row;cases.append(dict(kind=kind,guideWeight=guide,depthSamples=depths))
    (out/'inputs.bin').write_bytes(struct.pack('<I',len(cases))+blob);save(out/'cases.json',cases)
    save(out/'contract.json',dict(scope='Actual CSTrace receiver prefix, world reconstruction, normal reconstruction, world-match gates, footprint, complete direction sampler and geometry encoding. Depth/material storage, finite opaque plane traversal, and absent cache are explicit dependencies; no real scene/DXR/atlas/native frame or RGB energy claim.',
        expected='With empty guide, all pairs have identical direction, sampler weight and RNG. Only tilted+world-match changes origin and encoded geometry on the current source. Aligned, world-miss and unreliable-depth pairs preserve origin and encoded geometry.',
        sourceGeometry='Center camera sample is on a y=0 patch |x|<=.01, |z|<=.05; neighboring sample depths follow y=-.2*x, except aligned/no-support controls. Full 5x5 data and orthographic invVP are fixed before execution.',
        absoluteGeometryTolerance=2e-6,directionWeightRngPairComparison='exact raw bytes',
        execution='One baseline D3D12 WARP dispatch on existing source-matched host; Runtime and frozen finite reference unchanged.'))
    matches=[]
    for path in Path(os.environ['TEMP']).glob('hlgi-radiance-validity-warp-*'):
        exe=path/'build/Release/RadianceValidityWarp.exe';cpp=path/'source/RadianceValidityWarp.cpp';cmake=path/'source/CMakeLists.txt'
        if exe.is_file() and cpp.is_file() and cmake.is_file() and sha(cpp)==sha(T/'RadianceValidityWarp.cpp.txt') and sha(cmake)==sha(T/'CMakeLists.txt'):matches.append(exe)
    assert matches,'Existing source-matched WARP host required'
    exe=max(matches,key=lambda p:p.stat().st_mtime);commands=[]
    def invoke(label,args):
        args=list(map(str,args));result=subprocess.run(args,capture_output=True,text=True)
        (out/(label+'.log')).write_text(result.stdout+result.stderr,encoding='utf8')
        commands.append(dict(label=label,args=args,exitCode=result.returncode));save(out/'commands.json',commands)
        assert result.returncode==0,(label,result.stderr)
    invoke('compile',[DXC,'-HV','2018','-O3','-T','cs_6_0','-E','CSGuideOrigin','-I',out,'-I',INC/'Adapters','-I',INC,
                      '-D','SHADER_API_D3D11=1','-D','SHADER_STAGE_COMPUTE=1','-D','UNITY_COMPILER_DXC=1','-D','UNITY_VERSION=600000',
                      '-Fo',out/'fixture.dxil',out/'fixture.hlsl'])
    invoke('warp',[exe,out/'fixture.dxil',out/'inputs.bin',out/'outputs.bin'])
    data=(out/'outputs.bin').read_bytes();assert len(data)==len(cases)*368
    rows=[];checks=[]
    for index,case in enumerate(cases):
        values=struct.unpack_from('<92f',data,index*368)
        row=dict(case=case['kind'],guideWeight=case['guideWeight'],origin=values[:3],weight=values[3],direction=values[4:7],rng=struct.unpack_from('<I',data,index*368+28)[0],geometry=values[8:12],positionDepth=values[12:16],shadingNormal=values[16:20],finalNg=values[20:24],screenNg=values[24:28],probeOriginLimit=values[28:32],probeDirection=values[32:36],probeHit=values[36:40],counts=values[40:44],guide=values[44:48])
        assert all(math.isfinite(v) for k,v in enumerate(values) if k!=7),'Nonfinite output outside raw uint RNG'
        assert row['guide']==(0,0,0,0) and row['positionDepth']==(0,0,0,.5)
        assert math.dist(row['shadingNormal'][:3],(0,1,0))<2e-6
        assert row['direction'][1]>0 and abs(row['weight']-1)<2e-6
        expected_probe=1 if case['guideWeight'] and case['kind']!='no-depth-support' else 0
        expected_match=expected_probe if case['kind']!='world-miss' else 0
        assert row['counts']==(expected_probe,expected_match,expected_match,0)
        rows.append(row)
    for index in range(0,len(rows),2):
        left,right=rows[index:index+2];changed=left['case']=='tilted'
        same_direction=data[index*368+12:index*368+32]==data[(index+1)*368+12:(index+1)*368+32]
        same_origin=data[index*368:index*368+12]==data[(index+1)*368:(index+1)*368+12]
        same_geometry=data[index*368+32:index*368+48]==data[(index+1)*368+32:(index+1)*368+48]
        assert same_direction and same_origin!=changed and same_geometry!=changed
        checks.append(dict(case=left['case'],sameDirectionWeightAndRng=same_direction,sameOrigin=same_origin,sameEncodedGeometry=same_geometry))
    tilted=rows[0];guided=rows[1]
    assert math.dist(tilted['screenNg'][:3],(.2/math.sqrt(1.04),1/math.sqrt(1.04),0))<2e-6
    assert math.dist(guided['finalNg'][:3],(0,1,0))<2e-6
    assert abs(guided['probeHit'][3]-.06)<2e-6
    result=dict(passed=True,counterexampleEstablished=True,rows=rows,pairs=checks,sourceSha256=sha(S/'HybridLumenGIKernels.hlsl'),inputSha256=sha(out/'inputs.bin'),outputSha256=sha(out/'outputs.bin'),host=str(exe),hostSha256=sha(exe),dxcSha256=sha(DXC),unityExecuted=False,physicalGpuExecuted=False,
                conclusion='Current guide setting changes receiver geometry and ray origin even when no guide participates. This is a concrete integration-input coupling, not a demonstrated PDF mismatch or scene image-quality defect.')
    save(out/'analysis.json',result)
    assert all(sha(ROOT/name)==digest for name,digest in json.loads((out/'source-hashes.json').read_text()).items()),'Source changed while observing'
    print(json.dumps({key:value for key,value in result.items() if key not in ('rows','pairs')}))


if __name__=='__main__':main()
