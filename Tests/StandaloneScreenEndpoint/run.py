"""One paired TraceScreen WARP dispatch; only three complete CSTrace entry compiles."""
import json,os,re,struct,subprocess
from pathlib import Path
P=Path(__file__).resolve().parent;ROOT=P.parents[1];GPU=ROOT/'Runtime/Resources/HybridLumenGI'
DXC=Path('C:/Program Files (x86)/Windows Kits/10/bin/10.0.26100.0/x64/dxc.exe')
INC=Path(os.environ['TEMP'])/'HybridLumenGI-shader-validation'

def function(text):
    start=re.search(r'^bool TraceScreen\(',text,re.M).start()
    body=text.index('{',start);end=body+1;depth=1
    while depth:depth+=(text[end]=='{')-(text[end]=='}');end+=1
    return text[start:end]

def main():
    out=P/'output';assert not out.exists(),'Preserve the first execution';out.mkdir()
    report=dict(status='running',scope='Actual git-HEAD and current TraceScreen bodies, renamed only, in one D3D12 software WARP dispatch. ScreenPoint, texture values, depth/world reconstruction, normals and footprint are fixed dependency adapters; world-match/direct/cache calls are counted stubs. This proves conditional control/output equivalence, not real screen projection, lighting integration, Unity bindings or performance.',commands=[],observations=[])
    def save(): (out/'result.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
    def command(label,args):
        args=[str(v) for v in args];r=subprocess.run(args,cwd=ROOT,capture_output=True,timeout=300)
        (out/(label+'.log')).write_bytes(r.stdout+r.stderr);report['commands'].append(dict(name=label,arguments=args,exitCode=r.returncode));save()
        assert r.returncode==0,label+' failed';return r.stdout
    cases=[('known-hit',(1,1,1,1),(1.625,1.75,2,1),1,7,65793),
           ('direct-unknown',(1,1,0,1),(0,0,0,0),1,7,257),
           ('cache-unknown',(1,1,1,0),(1.125,1.25,1.5,0),1,7,65793),
           ('no-screen-hit',(0,1,1,1),(0,0,0,1),4,0,0),
           ('orientation-rejected',(1,0,1,1),(0,0,0,1),4,0,0)]
    report['expected']=[dict(name=n,control=c,fullResult=v,distance=t,hitBits=h,fullDependencyCountsPacked=k,endpointDependencyCountsPacked=0) for n,c,v,t,h,k in cases]
    report['expectation']='Old and candidate default/full float4 outputs and dependency counts are bit-identical; all three hit/distance pairs equal the explicit fixture expectation; endpoint world/direct/cache counters are zero. RGB/known in endpoint mode are unused by the product caller.'
    save()
    try:
        # d3b8ade was HEAD for the original paired execution; keep that baseline after adoption.
        old=command('read-head',['git','show','d3b8ade:Runtime/Resources/HybridLumenGI/HybridLumenGIKernels.hlsl']).decode('utf-8-sig')
        current=(GPU/'HybridLumenGIKernels.hlsl').read_text();a=function(old);b=function(current)
        assert 'resolveRadiance' not in a and 'bool resolveRadiance=true' in b
        assert 'if(!resolveRadiance) { distanceHit=surfaceT;return true; }' in b
        (out/'TraceScreen-baseline.hlsl').write_text(a,encoding='utf-8');(out/'TraceScreen-candidate.hlsl').write_text(b,encoding='utf-8')
        shader='''#include "HybridLumenGIScreenMaterial.hlsl"
struct Input { float4 control,emission,diffuse,direct,cached,reserved0,reserved1,reserved2,reserved3,reserved4,reserved5; };
struct Output { float4 oldValue,fullValue,distances,counts; };
StructuredBuffer<Input> Inputs : register(t0);
RWStructuredBuffer<Output> Outputs : register(u0);
cbuffer Counts : register(b0) { uint Count; }
static Input active;
static uint worldCalls,directCalls,cacheCalls;
static float3 screenP;
static int _HLGI_ScreenSteps=1,_HLGI_NativeComposition=0;
static float _HLGI_RayBias=.03125,_HLGI_Thickness=.15,_HLGI_BounceFeedback=1;
static float4 _HLGI_MaterialView=float4(0,0,0,1);
static float4x4 _HLGI_InvVP;
struct HLGIHit { float3 rawNg; };
struct HLGIRayFootprint { float unused; };
SamplerState sampler_PointClamp;
struct ScalarTexture { float SampleLevel(SamplerState s,float2 uv,float mip) { return .5; } };
struct EmissionTexture { float4 SampleLevel(SamplerState s,float2 uv,float mip) { return active.emission; } };
struct DiffuseTexture { float4 SampleLevel(SamplerState s,float2 uv,float mip) { return active.diffuse; } };
struct PolicyTexture {
    void GetDimensions(out uint width,out uint height) { width=height=1; }
    uint2 Load(int3 pixel) { return uint2(1,1); }
};
static ScalarTexture _HLGI_Depth,_HLGI_CaptureDepth;
static EmissionTexture _HLGI_Emission;static DiffuseTexture _HLGI_Diffuse;
static PolicyTexture _HLGI_ReceiverPolicy;
bool ScreenPoint(float3 origin,float3 dir,float t,out float2 uv,out float delta,out float3 p)
{ screenP=origin+dir;uv=.5;delta=t-1;p=screenP;return active.control.x!=0; }
float3 NormalAt(float2 uv) { return float3(0,0,active.control.y!=0?-1:1); }
bool ValidDepth(float d) { return d>0&&d<1; }
float3 WorldPosition(float2 uv,float depth,float4x4 matrix) { return screenP; }
bool HLGITryScreenGeometricNormal(float2 uv,float d,float3 p,out float3 n) { n=NormalAt(uv);return true; }
bool HLGITryScreenWorldMatch(float2 uv,float d,float3 p,float3 n,out HLGIHit hit)
{ worldCalls++;hit.rawNg=n;return true; }
bool HLGITryScreenWorldMatch(float2 uv,float d,float3 p,float3 n,uint2 screenPolicy,out HLGIHit hit)
{ return HLGITryScreenWorldMatch(uv,d,p,n,hit); }
bool HLGITryScreenRayFootprint(float2 uv,float d,float3 p,float3 ray,out HLGIRayFootprint footprint)
{ footprint.unused=0;return true; }
float3 DirectIrradiance(float3 p,float3 n,float3 ng,uint2 layers,bool shadows,float3 ray,HLGIRayFootprint footprint,out bool known)
{ directCalls++;known=active.control.z!=0;return active.direct.xyz; }
float3 CachedIrradiance(HLGIHit hit,float3 n,out bool known)
{ cacheCalls++;known=active.control.w!=0;return active.cached.xyz; }
float CountCalls() { return (float)(worldCalls|(directCalls<<8)|(cacheCalls<<16)); }
OLD
NEW
[numthreads(64,1,1)]
void CSScreenEndpointTest(uint3 id:SV_DispatchThreadID)
{
    if(id.x>=Count)return;active=Inputs[id.x];Output result=(Output)0;
    float3 oldRgb,newRgb,endRgb;float oldT,newT,endT;bool oldKnown,newKnown,endKnown;
    worldCalls=directCalls=cacheCalls=0;
    bool oldHit=TraceScreenOld(0,float3(0,0,1),4,oldRgb,oldT,oldKnown);result.counts.x=CountCalls();
    worldCalls=directCalls=cacheCalls=0;
    bool newHit=TraceScreenNew(0,float3(0,0,1),4,newRgb,newT,newKnown);result.counts.y=CountCalls();
    worldCalls=directCalls=cacheCalls=0;
    bool endHit=TraceScreenNew(0,float3(0,0,1),4,endRgb,endT,endKnown,false);result.counts.z=CountCalls();
    result.oldValue=float4(oldRgb,oldKnown?1:0);result.fullValue=float4(newRgb,newKnown?1:0);
    result.distances=float4(oldT,newT,endT,(oldHit?1:0)+(newHit?2:0)+(endHit?4:0));
    result.counts.w=all(endRgb==0)&&endKnown?1:0;Outputs[id.x]=result;
}
'''.replace('OLD',a.replace('TraceScreen(','TraceScreenOld(',1)).replace('NEW',b.replace('TraceScreen(','TraceScreenNew(',1))
        (out/'Fixture.hlsl').write_text(shader,encoding='utf-8')
        payload=bytearray(struct.pack('<I',len(cases)))
        for _,control,*_ in cases:
            values=list(control)+[.125,.25,.5,1]+[.5,.25,.125,1]+[2,4,8,1]+[1,2,4,1]+[0]*24
            assert len(values)==44;payload.extend(struct.pack('<44f',*values))
        (out/'inputs.bin').write_bytes(payload)
        host=json.loads((ROOT/'LocalComparison/Review/temporal-reactive-history-limit-01/host-reuse.json').read_text());exe=Path(host['files']['exe']['path'])
        report['host']=str(exe)
        command('compile-fixture',[DXC,'-HV','2018','-T','cs_6_0','-E','CSScreenEndpointTest','-I',GPU,'-Fo',out/'fixture.dxil',out/'Fixture.hlsl'])
        command('warp',[exe,out/'fixture.dxil',out/'inputs.bin',out/'outputs.bin'])
        raw=(out/'outputs.bin').read_bytes();assert len(raw)==len(cases)*64
        for i,(name,control,value,distance,bits,counter) in enumerate(cases):
            record=raw[i*64:(i+1)*64];actual=struct.unpack('<16f',record)
            expected=tuple(value)+tuple(value)+(distance,distance,distance,bits,counter,counter,0,1)
            same=record[:16]==record[16:32]
            report['observations'].append(dict(name=name,actual=actual,expected=expected,fullByteIdentical=same,passed=actual==expected and same))
            assert actual==expected and same,name
        for label,file,profile in [('software','HybridLumenGI.compute','cs_6_0'),('exact-software','HybridLumenGIExactSoftware.compute','cs_6_0'),('hardware','HybridLumenGIHardware.compute','cs_6_5')]:
            command('compile-'+label,[DXC,'-T',profile,'-E','CSTrace','-D','SHADER_API_D3D11=1','-D','SHADER_STAGE_COMPUTE=1','-D','UNITY_COMPILER_DXC=1','-D','UNITY_VERSION=600000','-I',INC/'Adapters','-I',INC,'-I',GPU,'-Fo',out/(label+'.dxil'),GPU/file])
        report['compileScope']='Only actual current CSTrace on software/exact-software/hardware using ValidateShaders include paths and native RayQuery adapter; no Unity import or physical GPU execution.'
        report['status']='passed'
    except Exception as error:
        report['status']='failed';report['error']=repr(error);raise
    finally:
        save();print(json.dumps(dict(status=report['status'],result=str(out/'result.json'))))

if __name__=='__main__':main()
