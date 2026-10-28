"""Finite actual Composite/URP function contract on the existing WARP host."""
import argparse, importlib.util, json, os, struct, subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
S = ROOT / 'Runtime/Resources/HybridLumenGI'
OUT = ROOT / 'LocalComparison/Review/additive-fog-composition-01'
INC = Path(os.environ['TEMP']) / 'HybridLumenGI-shader-validation'
PACKAGES = Path('I:/Unity test/Project/Library/PackageCache')
URP = PACKAGES / 'com.unity.render-pipelines.universal@947f725e83ac'
CORE = PACKAGES / 'com.unity.render-pipelines.core@8d821d79e4bc'
T = ROOT / 'Tests/StandaloneRadianceValidity'
DXC = Path('C:/Program Files (x86)/Windows Kits/10/bin/10.0.26100.0/x64/dxc.exe')
spec = importlib.util.spec_from_file_location('prior', ROOT / 'LocalComparison/Harness/run-screen-receive-shadows-source.py')
prior = importlib.util.module_from_spec(spec)
spec.loader.exec_module(prior)
extract, sha = prior.extract, prior.sha

ADAPTER = r'''
#define real float
#define UNITY_REVERSED_Z 1
#define UNITY_UV_STARTS_AT_TOP 1
#define _FOG_FRAGMENT 1
static float4x4 _TestView=float4x4(1,0,0,0, 0,1,0,0, 0,0,1,-8, 0,0,0,1);
#define UNITY_MATRIX_V _TestView
static float4 _ProjectionParams=float4(1,2,18,1.0/18.0);
static float4 unity_FogParams=float4(0,0,-.125,1.25);
static float4 unity_FogColor=float4(3,5,7,1);
static float4x4 _HLGI_InvVP=float4x4(1,0,0,0, 0,1,0,0, 0,0,16,-10, 0,0,0,1);
static float4 _HLGI_Size=1;
static float _HLGI_Intensity;
static int _HLGI_Debug,_HLGI_Composition;
static RadianceInput active;
struct ScalarTexture {
    float value;
    float Load(int3 pixel) { return value; }
    void GetDimensions(out uint w,out uint h) { w=h=1; }
};
struct ColorTexture { float4 value;float4 Load(int3 pixel) { return value; } };
static ScalarTexture _HLGI_Depth,_HLGI_CaptureDepth;
static ColorTexture _HLGI_Diffuse,_HLGI_Emission,_HLGI_NativeDiffuseFog,_HLGI_Moments;
struct Varyings { float4 positionCS;float2 uv; };
// Explicit upstream resolve adapter: this contract begins at an already
// resolved measurement; spatial filtering/rasterization are not executed.
float4 Resolve(float2 uv,out bool resolved) { resolved=active.guide.z!=0;return active.incoming; }
#include "HybridLumenGIScreenSampling.hlsl"
#include "HybridLumenGIScreenMaterial.hlsl"
#include "HybridLumenGIRadianceValidity.hlsl"
'''
ENTRY = r'''
[numthreads(64,1,1)] void CSCompositeFog(uint3 id:SV_DispatchThreadID)
{
    if(id.x>=_Count)return;
    active=_Inputs[id.x];
    _HLGI_Depth.value=active.control.x;_HLGI_CaptureDepth.value=active.control.y;
    _HLGI_Emission.value=float4(0,0,0,active.control.z);_HLGI_Intensity=active.control.w;
    _HLGI_Diffuse.value=active.initialSum;_HLGI_NativeDiffuseFog.value=active.irradiance;
    _HLGI_Moments.value=float4(0,0,1,.25);
    _HLGI_Debug=(int)active.guide.x;_HLGI_Composition=(int)active.guide.y;
    Varyings v;v.positionCS=float4(.5,.5,0,1);v.uv=.5;
    RadianceOutput result=(RadianceOutput)0;
    result.sum=Frag(v);
    float3 world=Reconstruct(v.uv,active.control.x);
    real fogCoord=InitializeInputDataFog(float4(world,1),0);
    result.irradiance=float4(world,fogCoord);
    result.guide=float4(MixFogColor(half3(1,1,1),half3(0,0,0),fogCoord).r,0,0,0);
    _Outputs[id.x]=result;
}
'''

def invoke(folder, name, args, commands):
    result = subprocess.run(list(map(str,args)), capture_output=True, text=True)
    (folder/(name+'.log')).write_text(result.stdout+result.stderr, encoding='utf-8')
    commands.append(dict(name=name,arguments=list(map(str,args)),exitCode=result.returncode))
    (folder/'commands.json').write_text(json.dumps(commands,indent=2),encoding='utf-8')
    assert result.returncode==0, (name,result.returncode)

def main(stage):
    folder=OUT/stage
    folder.mkdir(exist_ok=False)
    (folder/'runner.executed.py.txt').write_bytes(Path(__file__).read_bytes())
    (folder/'contract.before-execution.md').write_bytes((ROOT/'Documentation/Checkpoint-Iteration47.md').read_bytes())
    deps=[(URP/'ShaderLibrary/ShaderVariablesFunctions.hlsl','com.unity.render-pipelines.universal/ShaderLibrary/ShaderVariablesFunctions.hlsl'),
          (URP/'ShaderLibrary/Debug/DebuggingCommon.hlsl','com.unity.render-pipelines.universal/ShaderLibrary/Debug/DebuggingCommon.hlsl'),
          (CORE/'ShaderLibrary/Common.hlsl','com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl')]
    sources=[]
    for actual,cache in deps:
        cached=INC/'Packages'/cache
        assert sha(actual)==sha(cached), 'Current/fixed dependency mismatch: '+cache
        (folder/actual.name).write_bytes(actual.read_bytes())
        sources.append(dict(actual=str(actual),cache=str(cached),sha256=sha(actual)))
    for name in ['HybridLumenGIComposite.shader','HybridLumenGIScreenGeometry.hlsl','HybridLumenGIScreenSampling.hlsl','HybridLumenGIScreenMaterial.hlsl','HybridLumenGIRadianceValidity.hlsl']:
        (folder/name).write_bytes((S/name).read_bytes())
        sources.append(dict(actual=str(S/name),sha256=sha(S/name)))
    (folder/'source-manifest.json').write_text(json.dumps(sources,indent=2),encoding='utf-8')
    for path in [Path(prior.__file__),T/'RadianceValidityHarness.hlsl',T/'RadianceValidityWarp.cpp.txt',T/'CMakeLists.txt']:
        (folder/(path.name+'.dependency.txt')).write_bytes(path.read_bytes())
    shader=(folder/'HybridLumenGIComposite.shader').read_text(encoding='utf-8')
    fog=(folder/'ShaderVariablesFunctions.hlsl').read_text(encoding='utf-8')
    common=(folder/'Common.hlsl').read_text(encoding='utf-8')
    debug=(folder/'DebuggingCommon.hlsl').read_text(encoding='utf-8')
    assert '#define _FOG_FRAGMENT 1' in fog
    abi=(T/'RadianceValidityHarness.hlsl').read_text(encoding='utf-8')
    abi=abi[abi.index('struct RadianceInput'):abi.index('// Explicit dependency adapter:')]
    functions=[extract(debug,r'^bool IsFogEnabled\('),
               extract(common,r'^float4 ComputeClipSpacePosition\(float2 '),
               extract(common,r'^float3 ComputeWorldSpacePosition\(float2 '),
               extract(fog,r'^real ComputeFogFactorZ0ToFar\('),
               extract(fog,r'^half ComputeFogIntensity\('),
               extract(fog,r'^real InitializeInputDataFog\('),
               extract(fog,r'^half3 MixFogColor\('),
               extract(fog,r'^half3 MixFog\('),
               extract(shader,r'^\s*float3 Reconstruct\('),
               extract(shader,r'^\s*half4 Frag\(')]
    source=folder/'actual-composite.hlsl'
    source.write_text(abi+ADAPTER+'\n'.join(functions)+ENTRY,encoding='utf-8')
    matches=[]
    for p in Path(os.environ['TEMP']).glob('hlgi-radiance-validity-warp-*'):
        exe=p/'build/Release/RadianceValidityWarp.exe'
        cpp=p/'source/RadianceValidityWarp.cpp';cmake=p/'source/CMakeLists.txt'
        if exe.is_file() and cpp.is_file() and cmake.is_file() and sha(cpp)==sha(T/'RadianceValidityWarp.cpp.txt') and sha(cmake)==sha(T/'CMakeLists.txt'):matches.append(exe)
    assert matches,'Existing source-matched WARP host required'
    exe=sorted(matches,key=lambda p:p.stat().st_mtime)[-1]
    cases=[]
    def case(name,depth=.625,gi=(8,4,2,1),native=(.5,.5,.125,.5),debug=0,composition=0,valid=1,mismatch=0):
        cases.append(dict(name=name,depth=depth,gi=gi,native=native,debug=debug,composition=composition,valid=valid,mismatch=mismatch))
    case('additive-clear',.875);case('additive-half',.625);case('additive-opaque',.375)
    case('replace-signed',composition=1);case('replace-measured-black',gi=(0,0,0,1),composition=1)
    case('debug-indirect',debug=1);case('unknown-gi',gi=(8,4,2,-1));case('invalid-material',valid=0);case('capture-depth-mismatch',mismatch=.125)
    data=bytearray(struct.pack('<I',len(cases)))
    for c in cases:
        row=bytearray(208)
        for offset,values in [(0,c['gi']),(16,(c['depth'],c['depth']+c['mismatch'],c['valid'],.5)),(32,(.5,.25,.125,.5)),(48,c['native']),(64,(c['debug'],c['composition'],1,0))]:struct.pack_into('<4f',row,offset,*values)
        data+=row
    (folder/'inputs.bin').write_bytes(data)
    (folder/'cases.json').write_text(json.dumps(cases,indent=2),encoding='utf-8')
    if stage=='candidate':
        assert data==(OUT/'baseline/inputs.bin').read_bytes()
        assert (folder/'runner.executed.py.txt').read_bytes()==(OUT/'baseline/runner.executed.py.txt').read_bytes()
        assert json.loads((OUT/'baseline/analysis.json').read_text())['oldCounterexampleEstablished']
    commands=[];rows=[];failures=[];counterexamples=[]
    for variant,defines in [('linear',['FOG_LINEAR']),('off',[])]:
        args=[DXC,'-HV','2018','-T','cs_6_0','-E','CSCompositeFog','-I',folder,'-Fo',folder/(variant+'.dxil')]
        for d in defines:args+=['-D',d+'=1']
        invoke(folder,variant+'-compile',args+[source],commands)
        invoke(folder,variant+'-warp',[exe,folder/(variant+'.dxil'),folder/'inputs.bin',folder/(variant+'.bin')],commands)
        raw=(folder/(variant+'.bin')).read_bytes();assert len(raw)==368*len(cases)
        before=(OUT/'baseline'/(variant+'.bin')).read_bytes() if stage=='candidate' else raw
        for i,c in enumerate(cases):
            color=struct.unpack_from('<4f',raw,368*i)
            worldFog=struct.unpack_from('<4f',raw,368*i+16);transmission=struct.unpack_from('<f',raw,368*i+32)[0]
            # Independent affine-camera/fog reference, never derived from observed shader output.
            worldZ=16*c['depth']-10;eyeDistance=8-worldZ
            t=max(0,min(1,(10-(eyeDistance-2))/8)) if variant=='linear' else 1
            g=[max(x,0)*rho*.5*.5 for x,rho in zip(c['gi'][:3],[.5,.25,.125])]
            rejected=c['gi'][3]<=0 or c['valid']==0 or c['mismatch']!=0
            expected=([0,0,0] if rejected else [(x-n)*c['native'][3] for x,n in zip(g,c['native'])] if c['composition'] else g if c['debug'] or stage=='baseline' else [x*t for x in g])
            alpha=1 if c['debug'] and not rejected else 0
            target=expected+[alpha]
            reference=[x*t for x in g]
            change=variant=='linear' and c['name'] in ['additive-half','additive-opaque']
            checks=dict(color=max(abs(a-b) for a,b in zip(color,target))<=2e-6,
                        worldAndFog=max(abs(worldFog[0]),abs(worldFog[1]),abs(worldFog[2]-worldZ),abs(worldFog[3]-(t if variant=='linear' else 0)))<=2e-6,
                        transmission=abs(transmission-t)<=2e-6,
                        unchanged=stage=='baseline' or change or raw[368*i:368*i+16]==before[368*i:368*i+16])
            if stage=='baseline' and change:counterexamples.append(max(abs(a-b) for a,b in zip(color,reference))>2e-6)
            rows.append(dict(variant=variant,case=c['name'],color=color,worldAndFog=worldFog,transmission=transmission,expected=target,checks=checks))
            if not all(checks.values()):failures.append(variant+'/'+c['name'])
    if stage=='candidate':
        assert '#pragma multi_compile_fog' in shader.split('Name "Add indirect diffuse"')[1].split('ENDHLSL')[0]
        full=folder/'composite-pass.hlsl';full.write_text(shader.split('HLSLINCLUDE')[1].split('ENDHLSL')[0],encoding='utf-8')
        for name,entry,profile,kind,defines in [('vertex','Vert','vs_6_0','VERTEX',[]),('fragment-off','Frag','ps_6_0','FRAGMENT',[]),('fragment-linear','Frag','ps_6_0','FRAGMENT',['FOG_LINEAR'])]:
            args=[DXC,'-HV','2018','-E',entry,'-T',profile,'-I',INC,'-I',folder,'-Fo',folder/(name+'.dxil')]
            for d in ['SHADER_API_D3D11','SHADER_STAGE_'+kind,'UNITY_COMPILER_DXC']+defines:args+=['-D',d+'=1']
            args+=['-D','UNITY_VERSION=600000',str(full)]
            invoke(folder,name+'-compile',args,commands)
    result=dict(passed=not failures,oldCounterexampleEstablished=stage=='baseline' and len(counterexamples)==2 and all(counterexamples),
                stage=stage,failures=failures,rows=rows,absoluteErrorBound=2e-6,runner=str(exe),runnerSha256=sha(exe),
                inputSha256=sha(folder/'inputs.bin'),compiledSourceSha256=sha(source),commands=commands,
                scope='Actual Frag/Reconstruct plus current URP helpers on WARP; explicit texture loads/resolved GI and camera inputs. No Unity/raster/RenderGraph/runtime variant qualification.')
    (folder/'analysis.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
    print(json.dumps({k:v for k,v in result.items() if k not in ['rows','commands']}))
    assert result['passed'] and (stage!='baseline' or result['oldCounterexampleEstablished'])

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('stage',choices=['baseline','candidate']);main(parser.parse_args().stage)
