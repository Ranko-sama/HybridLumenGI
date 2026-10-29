"""Execute only a temporary two-line candidate using the eight frozen inputs."""
import importlib.util
import json
import math
from pathlib import Path
import struct
import subprocess

HERE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('baseline_runner',HERE/'run.py')
base=importlib.util.module_from_spec(spec);spec.loader.exec_module(base)


def main():
    baseline=HERE/'baseline';out=HERE/'candidate';out.mkdir(exist_ok=False)
    original=(baseline/'HybridLumenGIKernels.hlsl').read_bytes()
    assert original==(base.S/'HybridLumenGIKernels.hlsl').read_bytes()
    assert json.loads((HERE/'qualified-analysis.json').read_text())['counterexampleEstablished']
    old_gate=b'    if(hasGeometry && _HLGI_GuideWeight>0)'
    old_cache=b'            HLGICachedSample(receiverHit,n,receiverCache);'
    assert original.count(old_gate)==original.count(old_cache)==1
    changed=original.replace(old_gate,b'    if(hasGeometry)').replace(old_cache,b'            if(_HLGI_GuideWeight>0) HLGICachedSample(receiverHit,n,receiverCache);')
    for path in baseline.iterdir():
        if path.suffix=='.hlsl' or path.name in ('inputs.bin','cases.json','RadianceValidityWarp.cpp.txt','CMakeLists.txt'):
            (out/path.name).write_bytes(path.read_bytes())
    (out/'run_candidate.py').write_bytes(Path(__file__).read_bytes())
    (out/'HybridLumenGIKernels.hlsl').write_bytes(changed)
    candidate_function=base.trace_function(changed.decode('utf-8-sig'))
    prelude=candidate_function[candidate_function.index('{')+1:candidate_function.index('    float3 sum=0;')]
    for name,destination in [('_HLGI_Output[id.xy]','capturedOutput'),('_HLGI_GeometryOut[id.xy]','capturedGeometry'),('_HLGI_MaterialOut[id.xy]','capturedMaterial')]:prelude=prelude.replace(name,destination)
    prior_prelude=(baseline/'ActualReceiverPrelude.hlsl').read_text(encoding='utf8')
    source=(baseline/'fixture.hlsl').read_text(encoding='utf8');assert source.count(prior_prelude)==1
    (out/'ActualReceiverPrelude.hlsl').write_text(prelude,encoding='utf8')
    (out/'fixture.hlsl').write_text(source.replace(prior_prelude,prelude),encoding='utf8')
    for name,digest in json.loads((baseline/'compiler-include-hashes.json').read_text()).items():assert base.sha(base.INC/name)==digest
    for path in baseline.glob('*.hlsl'):
        if path.name not in ('HybridLumenGIKernels.hlsl','ActualReceiverPrelude.hlsl','fixture.hlsl'):assert (out/path.name).read_bytes()==path.read_bytes()
    base.save(out/'contract.json',dict(scope='Temporary candidate only; repository Runtime unchanged. Same eight inputs, actual-source prefix/sampler and explicit dependency adapters as baseline.',
        changes=['CSTrace world-match gated by hasGeometry regardless of guide setting','Only HLGICachedSample remains gated by guideWeight>0'],
        retainedConditions=['All guide.35 rows exactly match complete baseline output records','All paired origin/direction/weight/RNG/Geometry are equal after the candidate','guide0 cache queries remain zero','world-miss geometric outputs preserved; the extra matching query is recorded','no-depth complete records preserved'],
        signedZero='Original baseline aligned -0/+0 exception remains preserved and separately qualified; no other tolerance changes.',
        cost='One short visibility query and its footprint per valid GI receiver with reliable depth geometry and guide0, not per ray. No measured GPU time claim.',
        absoluteGeometryTolerance=2e-6,inputSha256=base.sha(out/'inputs.bin'),baselineRawSha256=base.sha(baseline/'outputs.bin'),baselineProductSha256=base.sha(base.S/'HybridLumenGIKernels.hlsl'),candidateProductSha256=base.sha(out/'HybridLumenGIKernels.hlsl')))
    prior_commands=json.loads((baseline/'commands.json').read_text());exe=Path(next(row['args'][0] for row in prior_commands if row['label']=='warp'))
    assert exe.is_file()
    host_root=exe.parents[2]
    assert base.sha(host_root/'source/RadianceValidityWarp.cpp')==base.sha(base.T/'RadianceValidityWarp.cpp.txt')
    assert base.sha(host_root/'source/CMakeLists.txt')==base.sha(base.T/'CMakeLists.txt')
    commands=[]
    def invoke(label,args):
        args=list(map(str,args));result=subprocess.run(args,capture_output=True,text=True)
        (out/(label+'.log')).write_text(result.stdout+result.stderr,encoding='utf8');commands.append(dict(label=label,args=args,exitCode=result.returncode));base.save(out/'commands.json',commands)
        assert result.returncode==0,(label,result.stderr)
    invoke('compile',[base.DXC,'-HV','2018','-O3','-T','cs_6_0','-E','CSGuideOrigin','-I',out,'-I',base.INC/'Adapters','-I',base.INC,
        '-D','SHADER_API_D3D11=1','-D','SHADER_STAGE_COMPUTE=1','-D','UNITY_COMPILER_DXC=1','-D','UNITY_VERSION=600000','-Fo',out/'fixture.dxil',out/'fixture.hlsl'])
    invoke('warp',[exe,out/'fixture.dxil',out/'inputs.bin',out/'outputs.bin'])
    raw=(out/'outputs.bin').read_bytes();previous=(baseline/'outputs.bin').read_bytes();assert len(raw)==len(previous)==8*368
    cases=json.loads((out/'cases.json').read_text());rows=[];failures=[]
    for index,case in enumerate(cases):
        values=struct.unpack_from('<92f',raw,index*368);original_values=struct.unpack_from('<92f',previous,index*368)
        reliable=case['kind']!='no-depth-support';matched=reliable and case['kind']!='world-miss'
        expected_cache=int(bool(case['guideWeight']) and matched)
        checks=dict(finite=all(math.isfinite(v) for k,v in enumerate(values) if k!=7),
            queryCount=values[40:44]==(int(reliable),expected_cache,int(matched),0),
            absentGuide=values[44:48]==(0,0,0,0),
            defaultCompleteRecordUnchanged=case['guideWeight']==0 or raw[index*368:(index+1)*368]==previous[index*368:(index+1)*368],
            samplerBytesUnchanged=raw[index*368+12:index*368+32]==previous[index*368+12:index*368+32],
            unmatchedOriginGeometryUnchanged=case['kind'] not in ('world-miss','no-depth-support') or (values[:3]==original_values[:3] and raw[index*368+32:index*368+48]==previous[index*368+32:index*368+48]),
            noDepthCompleteRecordUnchanged=case['kind']!='no-depth-support' or raw[index*368:(index+1)*368]==previous[index*368:(index+1)*368])
        if index%2==0:checks['pairOriginSamplerGeometryBytesEqual']=raw[index*368:index*368+48]==raw[(index+1)*368:(index+1)*368+48]
        if not all(checks.values()):failures.append(index)
        rows.append(dict(case=case['kind'],guideWeight=case['guideWeight'],origin=values[:3],direction=values[4:7],geometry=values[8:12],counts=values[40:44],checks=checks))
    unchanged_runtime=(base.S/'HybridLumenGIKernels.hlsl').read_bytes()==original
    result=dict(passed=not failures and unchanged_runtime,failures=failures,rows=rows,repositoryRuntimeUnchanged=unchanged_runtime,
        inputSha256=base.sha(out/'inputs.bin'),outputSha256=base.sha(out/'outputs.bin'),baselineRawSha256=base.sha(baseline/'outputs.bin'),
        baselineProductSha256=base.sha(base.S/'HybridLumenGIKernels.hlsl'),candidateProductSha256=base.sha(out/'HybridLumenGIKernels.hlsl'),
        hostSha256=base.sha(exe),dxcSha256=base.sha(base.DXC),physicalGpuExecuted=False,unityExecuted=False,
        scope='Actual-source temporary receiver-gate candidate on source-matched WARP; input-coupling repair only, not physical GPU/DXR or image-quality acceptance.')
    base.save(out/'analysis.json',result);assert result['passed'],failures
    print(json.dumps({k:v for k,v in result.items() if k!='rows'}))


if __name__=='__main__':main()
