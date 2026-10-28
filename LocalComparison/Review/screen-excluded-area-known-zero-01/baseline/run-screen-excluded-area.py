"""Actual TraceScreen and estimator validity on the existing WARP host; four fixed cases."""
import argparse, importlib.util, json, os, struct, subprocess
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
S=ROOT/'Runtime/Resources/HybridLumenGI'
T=ROOT/'Tests/StandaloneRadianceValidity'
OUT=ROOT/'LocalComparison/Review/screen-excluded-area-known-zero-01'
DXC=Path('C:/Program Files (x86)/Windows Kits/10/bin/10.0.26100.0/x64/dxc.exe')
INC=Path(os.environ['TEMP'])/'HybridLumenGI-shader-validation'
spec=importlib.util.spec_from_file_location('prior',ROOT/'LocalComparison/Harness/run-screen-receive-shadows-source.py')
prior=importlib.util.module_from_spec(spec);spec.loader.exec_module(prior)
extract,sha=prior.extract,prior.sha
ENTRY=r'''
[numthreads(64,1,1)] void CSScreenExcludedArea(uint3 id:SV_DispatchThreadID)
{
    if(id.x>=_Count)return;
    active=_Inputs[id.x];RadianceOutput result=(RadianceOutput)0;
    float3 value;float distanceHit;bool known;
    bool hit=TraceScreen(float3(0,0,.03125),float3(1,0,0),active.initialSum.y,value,distanceHit,known);
    result.screen=float4(value,known?1:-1);result.validity=uint4(hit?1:0,known?1:0,0,0);
    result.proxy=float4(distanceHit,0,0,0);
    directionDraws=areaDraws=directCalls=unknownDirectCalls=0;
    result.sum=ActualEstimator();
    result.predicates=uint4(directionDraws,areaDraws,directCalls,unknownDirectCalls);
    _Outputs[id.x]=result;
}
'''

def main(stage):
    folder=OUT/stage;folder.mkdir(exist_ok=False)
    files=[S/n for n in ['HybridLumenGIKernels.hlsl','HybridLumenGIHit.hlsl','HybridLumenGIRayFootprint.hlsl','HybridLumenGIScreenMaterial.hlsl','HybridLumenGIRadianceValidity.hlsl']]
    files += [T/'ScreenExcludedAreaAdapters.hlsl',T/'RadianceValidityHarness.hlsl',T/'RadianceValidityWarp.cpp.txt',T/'CMakeLists.txt',
              ROOT/'Documentation/Checkpoint-Iteration57.md',Path(__file__),Path(prior.__file__)]
    for f in files:(folder/f.name).write_bytes(f.read_bytes())
    (folder/'sources.json').write_text(json.dumps({str(f.relative_to(ROOT)):sha(f) for f in files},indent=2),encoding='utf-8')
    abi=(folder/'RadianceValidityHarness.hlsl').read_text(encoding='utf-8')
    abi=abi[abi.index('struct RadianceInput'):abi.index('// Explicit dependency adapter:')]
    kernels=(folder/'HybridLumenGIKernels.hlsl').read_text(encoding='utf-8')
    trace=extract(kernels,r'^bool TraceScreen\(')
    estimator=extract(kernels,r'^void CSTrace\(')
    estimator=estimator[estimator.index('float3 sum=0;'):estimator.rfind('}')]
    assert estimator.count('_HLGI_Output[id.xy]=')==1
    estimator=estimator.replace('_HLGI_Output[id.xy]=','return ')
    setup='float4 ActualEstimator() { float3 p=0,n=normalize(float3(1,0,1)),geometricNormal=float3(0,0,1); bool hasGeometry=true; float2 uv=.5; float depth=.5; uint rng=0; HLGICacheEntry receiverCache=(HLGICacheEntry)0;\n'
    source=folder/'actual-estimator.hlsl'
    source.write_text(abi+'\n#include "ScreenExcludedAreaAdapters.hlsl"\n'+trace+'\n'+setup+estimator+'}\n'+ENTRY,encoding='utf-8')
    # These are dependency inputs, not a replacement implementation of either tested function.
    cases=[dict(name='excluded-area-unknown',control=[0,1,1,0],world=[0,2,0,0]),
           dict(name='participating-direction-unknown',control=[1,0,0,0],world=[0,2,0,0]),
           dict(name='area-unknown-unresolved-equal-bound',control=[0,1,1,0],world=[0,1,1,0]),
           dict(name='participating-area-known',control=[0,0,1,1],world=[1,2,0,0])]
    blob=bytearray(struct.pack('<I',len(cases)))
    for c in cases:
        row=bytearray(208)
        for offset,values in [(16,c['control']),(32,c['world']),(48,[1,2,3,0])]:struct.pack_into('<4f',row,offset,*values)
        blob+=row
    (folder/'inputs.bin').write_bytes(blob)
    (folder/'cases.json').write_text(json.dumps(cases,indent=2),encoding='utf-8')
    if stage=='candidate':
        for f in files:
            if f.name!='HybridLumenGIKernels.hlsl':assert (folder/f.name).read_bytes()==(OUT/'baseline'/f.name).read_bytes(),f.name
        assert blob==(OUT/'baseline/inputs.bin').read_bytes()
        assert json.loads((OUT/'baseline/analysis.json').read_text())['counterexampleEstablished']
    matches=[]
    for p in Path(os.environ['TEMP']).glob('hlgi-radiance-validity-warp-*'):
        exe=p/'build/Release/RadianceValidityWarp.exe';cpp=p/'source/RadianceValidityWarp.cpp';cmake=p/'source/CMakeLists.txt'
        if exe.is_file() and cpp.is_file() and cmake.is_file() and sha(cpp)==sha(T/'RadianceValidityWarp.cpp.txt') and sha(cmake)==sha(T/'CMakeLists.txt'):matches.append(exe)
    assert matches,'Existing source-matched host required'
    exe=sorted(matches,key=lambda p:p.stat().st_mtime)[-1]
    commands=[]
    def invoke(name,args):
        args=list(map(str,args));r=subprocess.run(args,capture_output=True,text=True)
        (folder/(name+'.log')).write_text(r.stdout+r.stderr,encoding='utf-8')
        commands.append(dict(name=name,arguments=args,exitCode=r.returncode))
        (folder/'commands.json').write_text(json.dumps(commands,indent=2),encoding='utf-8')
        assert r.returncode==0,(name,r.returncode,r.stdout,r.stderr)
    invoke('compile',[DXC,'-HV','2018','-T','cs_6_0','-E','CSScreenExcludedArea','-I',folder,'-Fo',folder/'test.dxil',source])
    invoke('warp',[exe,folder/'test.dxil',folder/'inputs.bin',folder/'outputs.bin'])
    raw=(folder/'outputs.bin').read_bytes();assert len(raw)==368*4
    before=(OUT/'baseline/outputs.bin').read_bytes() if stage=='candidate' else raw
    rows=[];failures=[]
    for i,c in enumerate(cases):
        result=struct.unpack_from('<4f',raw,i*368)
        probe=struct.unpack_from('<4I',raw,i*368+144)[:2]
        probeDistance=struct.unpack_from('<f',raw,i*368+96)[0]
        counts=struct.unpack_from('<4I',raw,i*368+128)
        expected=(.125,.25,.5,.25) if i==0 and stage=='candidate' else (1.125,2.25,3.5,.25) if i==3 else (0,0,0,-1)
        expectedCounts=(2,2,2,2) if i==0 and stage=='candidate' else (1,0,1,1) if i==1 else (2,2,0,0) if i==3 else (1,1,1,1)
        checks=dict(expected=result==expected,counts=counts==expectedCounts,
                    actualScreenHitUnknown=probe==((1,0) if i in [0,2] else (0,1)),
                    screenDistance=probeDistance==(1 if i in [0,2] else c['world'][1]),
                    unchangedControl=stage=='baseline' or i==0 or raw[i*368:(i+1)*368]==before[i*368:(i+1)*368])
        rows.append(dict(case=c['name'],result=result,expected=expected,counts=counts,probe=probe,probeDistance=probeDistance,checks=checks))
        if not all(checks.values()):failures.append(c['name'])
    result=dict(stage=stage,passed=not failures,counterexampleEstablished=stage=='baseline' and not failures,
                rows=rows,failures=failures,host=str(exe),hostSha256=sha(exe),inputSha256=sha(folder/'inputs.bin'),
                sourceSha256=sha(source),absoluteErrorBound=1e-6,comparison='All four representable outputs matched exactly; zero area increment and unchanged controls exact.',
                scope='Actual TraceScreen unknown exit and complete estimator loop/final expression; fixed dependency inputs; no Unity, real scene/PDF or physical GPU.')
    (folder/'analysis.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
    assert result['passed'],failures
    if stage=='candidate':
        (folder/'full-entry-source-hashes.json').write_text(json.dumps({p.name:sha(p) for p in sorted(S.glob('*')) if p.suffix in ['.hlsl','.compute']},indent=2),encoding='utf-8')
        for backend,file,profile in [('software','HybridLumenGI.compute','cs_6_0'),('hardware','HybridLumenGIHardware.compute','cs_6_5')]:
            args=[DXC,'-HV','2018','-T',profile,'-E','CSTrace','-I',INC/'Adapters','-I',INC,'-I',S,'-Fo',folder/(backend+'.dxil')]
            for d in ['SHADER_API_D3D11=1','SHADER_STAGE_COMPUTE=1','UNITY_COMPILER_DXC=1','UNITY_VERSION=600000']:args+=['-D',d]
            invoke(backend+'-compile',args+[S/file])
        # Execute only the existing source-wiring assertions, not its numeric CDF suite.
        contract=ROOT/'Tests/Validate-EmissiveSampling.mjs'
        original=contract.read_text(encoding='utf-8');(folder/contract.name).write_bytes(contract.read_bytes())
        prefix=original[:original.index('const PI=Math.PI')]
        prefix=prefix.replace('fileURLToPath(import.meta.url)',json.dumps(str(contract)))
        (folder/'source-assertions.executed.mjs').write_text(prefix,encoding='utf-8')
        invoke('existing-source-wiring',['node','--input-type=module','-e',prefix])
    print(json.dumps({k:v for k,v in result.items() if k!='rows'}))

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('stage',choices=['baseline','candidate']);main(parser.parse_args().stage)
