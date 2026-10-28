"""One semantic counterexample and signed-alpha contract, using existing actual-HLSL WARP facilities."""
import argparse,hashlib,json,os,re,struct,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];SHADER=ROOT/'Runtime/Resources/HybridLumenGI'
PACKAGE=ROOT/'LocalComparison/Review/screen-receive-shadows-01'
TEMPLATE=ROOT/'Tests/StandaloneRadianceValidity'
DXC=Path('C:/Program Files (x86)/Windows Kits/10/bin/10.0.26100.0/x64/dxc.exe')
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def extract(text,pattern):
    match=re.search(pattern,text,re.M);assert match,pattern
    start=text.index('{',match.start());depth=0
    for at in range(start,len(text)):
        if text[at]=='{':depth+=1
        elif text[at]=='}':
            depth-=1
            if depth==0:return text[match.start():at+1]
    raise AssertionError('Unterminated actual function')
def run_command(out,name,args):
    result=subprocess.run(list(map(str,args)),capture_output=True,text=True)
    (out/(name+'.log')).write_text(result.stdout+result.stderr,encoding='utf-8')
    assert result.returncode==0,(name,result.returncode,result.stdout,result.stderr)
def run(stage):
    out=PACKAGE/('source-'+stage);assert not out.exists(),'Preserve this source attempt';out.mkdir(parents=True)
    source_names=['HybridLumenGITransport.hlsl','HybridLumenGIKernels.hlsl','HybridLumenGIExactMesh.hlsl','HybridLumenGIHit.hlsl','HybridLumenGIRayFootprint.hlsl','HybridLumenGIRadianceValidity.hlsl']
    helper=SHADER/'HybridLumenGIScreenMaterial.hlsl'
    assert helper.exists()==(stage=='candidate'),'Unexpected product stage'
    if helper.exists():source_names.append(helper.name)
    for name in source_names:(out/name).write_bytes((SHADER/name).read_bytes())
    for name in ['RadianceValidityHarness.hlsl','ScreenReceiveShadowsHarness.hlsl']:(out/name).write_bytes((TEMPLATE/name).read_bytes())
    transport=(SHADER/'HybridLumenGITransport.hlsl').read_text();kernels=(SHADER/'HybridLumenGIKernels.hlsl').read_text();exact=(SHADER/'HybridLumenGIExactMesh.hlsl').read_text()
    patterns=[r'^HLGIRayFootprint HLGIPointQueryFootprint\(',r'^bool TraceShadow\([^\r\n]*useRenderingLayers,\n',
        r'^bool TraceShadow\([^\r\n]*out bool known\)',r'^bool TraceShadow\([^\r\n]*bool useRenderingLayers\)',r'^bool HLGIHitOwnerCurrent\(',
        r'^float3 DirectIrradiance\([^\r\n]*bool receivesShadows,\n',r'^float3 DirectIrradiance\([^\r\n]*bool receivesShadows,out bool known\)',
        r'^float3 DirectIrradiance\(float3 p,float3 n,float3 biasNormal,uint2 receiverLayers,out bool known\)',
        r'^float3 DirectIrradiance\(float3 p,float3 n,float3 biasNormal,uint2 receiverLayers\)',
        r'^float3 ProxyRadiance\(HLGIHit hit,float3 incomingDirection,[^\r\n]*float emissionWeight,',
        r'^float3 ProxyRadiance\(HLGIHit hit,float3 incomingDirection,HLGIRayFootprint hitFootprint,out float confidence\)',r'^float3 ProxyRadiance\(HLGIHit hit,out float confidence\)']
    functions=[extract(exact,r'^void HLGIHardwareResolveCommittedMaterial\(')]+[extract(transport,p) for p in patterns]+[extract(kernels,r'^bool TraceScreen\(')]
    (out/'ActualTransportFunctions.hlsl').write_text('\n\n'.join(functions),encoding='utf-8')
    # Reuse only a previously built runner whose frozen C++ and CMake sources
    # exactly match this unchanged 208/368-byte ABI. No new C++ framework/build.
    matches=[]
    for folder in Path(os.environ['TEMP']).glob('hlgi-radiance-validity-warp-*'):
        exe=folder/'build/Release/RadianceValidityWarp.exe';cpp=folder/'source/RadianceValidityWarp.cpp';cmake=folder/'source/CMakeLists.txt'
        if exe.is_file() and cpp.is_file() and cmake.is_file() and sha(cpp)==sha(TEMPLATE/'RadianceValidityWarp.cpp.txt') and sha(cmake)==sha(TEMPLATE/'CMakeLists.txt'):matches.append(exe)
    assert matches,'Existing matching WARP runner not found';exe=sorted(matches,key=lambda p:p.stat().st_mtime)[-1]
    cases=[]
    def add(name,on,blocked,native,valid=True,ao=.375,black=False):
        cases.append(dict(name=name,on=on,blocked=blocked,native=native,valid=valid,ao=ao,black=black))
    for native in [False,True]:
        for blocked in [False,True]:
            for on in [False,True]:add(f'{"native" if native else "ordinary"}-blocked{blocked}-on{on}',on,blocked,native)
    for ao in [0,1]:
        for on in [False,True]:add(f'ao{ao}-on{on}',on,True,True,ao=ao)
    for on in [False,True]:
        add(f'valid-black-on{on}',on,True,True,black=True)
        add(f'invalid-on{on}',on,True,True,valid=False,black=True)
    blob=bytearray(struct.pack('<I',len(cases)))
    for case in cases:
        row=bytearray(208);emission=[0,0,0] if case['black'] else [.125,.25,.5]
        struct.pack_into('<4f',row,0,*emission,case['ao'])
        struct.pack_into('<4f',row,16,case['on'],case['blocked'],case['native'],case['valid'])
        struct.pack_into('<4f',row,144,*([0,0,0] if case['black'] else [.5,.5,.5]),1)
        blob.extend(row)
    (out/'inputs.bin').write_bytes(blob);(out/'cases.json').write_text(json.dumps(cases,indent=2),encoding='utf-8')
    args=[DXC,'-HV','2018','-T','cs_6_0','-E','CSScreenReceiveShadowsTest','-I',out,'-Fo',out/'test.dxil','-Fc',out/'test.ll']
    if stage=='candidate':args+=['-D','HLGI_TEST_SCREEN_MATERIAL=1']
    args+=[out/'ScreenReceiveShadowsHarness.hlsl'];run_command(out,'compile',args)
    run_command(out,'warp',[exe,out/'test.dxil',out/'inputs.bin',out/'outputs.bin'])
    output=(out/'outputs.bin').read_bytes();assert len(output)==368*len(cases)
    rows=[];failures=[]
    for i,case in enumerate(cases):
        offset=i*368;screen=struct.unpack_from('<4f',output,offset+80);world=struct.unpack_from('<4f',output,offset+96)
        predicates=struct.unpack_from('<4I',output,offset+128);metadata=struct.unpack_from('<4I',output,offset+144);alpha=struct.unpack_from('<4f',output,offset+64)
        emission=[0,0,0] if case['black'] else [.125,.25,.5];direct=0 if case['blocked'] and case['on'] else 1
        expected=[e+(0 if case['black'] else .5)*direct for e in emission]
        checks={'worldExpected':list(world[:3])==expected and world[3]==1,
            'screenHit':predicates[0]==int(case['valid']),'screenExpected':not case['valid'] or list(screen[:3])==expected,
            'screenKnown':screen[3]==1,'samePathRadiance':not case['valid'] or screen[:3]==world[:3]}
        if stage=='candidate':
            expected_ao=(alpha[1]-1 if case['native'] else .75)
            checks.update(validity=metadata[0]==int(case['valid']),sign=not case['valid'] or metadata[1]==int(case['on']),
                halfMagnitude=metadata[2]==1,ao=not case['valid'] or alpha[2]==expected_ao)
        row=dict(case=case,screen=screen,world=world,queries=predicates[1:3],alpha=alpha,checks=checks);rows.append(row)
        if not all(checks.values()):failures.append(case['name'])
    result={'stage':stage,'passed':not failures,'failures':failures,'rows':rows,'runner':str(exe),'runnerSha256':sha(exe),
        'runnerCppSha256':sha(TEMPLATE/'RadianceValidityWarp.cpp.txt'),'dxcSha256':sha(DXC),'inputSha256':sha(out/'inputs.bin'),
        'fixtureSha256':sha(out/'ScreenReceiveShadowsHarness.hlsl'),'sources':{n:sha(out/n) for n in source_names},
        'scope':'Actual extracted TraceScreen/ProxyRadiance/DirectIrradiance and half conversion on WARP; same p/n/layers/footprint, explicit dependency adapters. Not Unity capture or real occlusion traversal.'}
    (out/'analysis.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
    print(json.dumps({k:v for k,v in result.items() if k not in ['rows','sources']}))
    return not failures
if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('stage',choices=['baseline','candidate']);args=parser.parse_args();raise SystemExit(0 if run(args.stage) else 1)
