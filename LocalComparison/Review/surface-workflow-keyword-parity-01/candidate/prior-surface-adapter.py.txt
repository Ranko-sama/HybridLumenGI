"""Actual Surface vertex/fragment bodies with explicit texture/raster adapters; existing WARP ABI."""
import hashlib,importlib.util,json,os,re,struct,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];H=ROOT/'LocalComparison/Harness';S=ROOT/'Runtime/Resources/HybridLumenGI'
OUT=ROOT/'LocalComparison/Review/surface-detail-albedo-01/source';OUT.mkdir(exist_ok=False)
spec=importlib.util.spec_from_file_location('prior',H/'run-screen-receive-shadows-source.py');prior=importlib.util.module_from_spec(spec);spec.loader.exec_module(prior)
T=prior.TEMPLATE;sha=prior.sha;DXC=prior.DXC
matches=[]
for folder in Path(os.environ['TEMP']).glob('hlgi-radiance-validity-warp-*'):
    exe=folder/'build/Release/RadianceValidityWarp.exe';cpp=folder/'source/RadianceValidityWarp.cpp';cmake=folder/'source/CMakeLists.txt'
    if exe.is_file() and cpp.is_file() and cmake.is_file() and sha(cpp)==sha(T/'RadianceValidityWarp.cpp.txt') and sha(cmake)==sha(T/'CMakeLists.txt'):matches.append(exe)
assert matches;exe=sorted(matches,key=lambda p:p.stat().st_mtime)[-1]
abi=(T/'RadianceValidityHarness.hlsl').read_text();abi=abi[abi.index('struct RadianceInput'):abi.index('// Explicit dependency adapter:')]
adapter=r'''
#include "HybridLumenGIScreenMaterial.hlsl"
#define UNITY_SETUP_INSTANCE_ID(x)
#define UNITY_TRANSFER_INSTANCE_ID(x,y)
#define UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(x)
#define UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(x)
// Only opaque/non-clipped inputs; raster coverage is outside this source contract.
#define clip(x)
#define TRANSFORM_TEX(uv,name) ((uv)*name##_ST.xy+name##_ST.zw)
#define SAMPLE_TEXTURE2D(tex,smp,uv) Sample##tex(uv)
struct Attributes {float4 positionOS;float2 uv;};
struct Varyings {float4 positionCS;float2 uv;};
struct SurfaceOutput {float4 diffuseOcclusion,emissionValidity;uint2 receiverPolicy;};
float4 TransformObjectToHClip(float3 p){return float4(p,1);}
uint2 HLGICaptureReceiverPolicy(){return uint2(1,1);}
static float4 _BaseMap_ST=float4(2,3,.1,.05),_DetailAlbedoMap_ST=float4(1.5,.5,.2,.3);
static float4 _BaseColor=float4(.5,.375,.25,1),_SpecColor=.04,_EmissionColor=float4(.125,.25,.5,1);
static float _Metallic=0,_OcclusionStrength=1,_WorkflowMode=1,_AlphaClip=0,_Cutoff=.5,_Surface=0,_SmoothnessTextureChannel=0,_DetailAlbedoMapScale=.5;
// Point-sampled linear 2x2 inputs. Non-target cells differ to expose wrong UV/mask semantics.
float4 Sample_BaseMap(float2 uv){return uv.x<.5&&uv.y<.5?float4(.5,.75,.25,1):float4(.25,.5,.75,1);}
float4 Sample_DetailMask(float2 uv){return float4(.125,.25,.5,uv.x<.5&&uv.y<.5?.75:.25);}
float4 Sample_DetailAlbedoMap(float2 uv){return uv.x>=.5&&uv.y>=.5?float4(.75,.25,.625,1):float4(.25,.75,.5,1);}
float4 Sample_OcclusionMap(float2 uv){return 1;}
float4 Sample_EmissionMap(float2 uv){return 1;}
'''
entry=r'''
[numthreads(64,1,1)] void CSSurfaceDetail(uint3 id:SV_DispatchThreadID)
{
    if(id.x>=_Count)return;
    Attributes input;input.positionOS=float4(0,0,0,1);input.uv=_Inputs[id.x].control.xy;
    Varyings mapped=Vert(input);SurfaceOutput captured=Frag(mapped);
    RadianceOutput result=(RadianceOutput)0;
    result.sum=captured.diffuseOcclusion;result.irradiance=captured.emissionValidity;
    result.guide=float4(mapped.uv,0,0);result.predicates=uint4(captured.receiverPolicy,0,0);
    _Outputs[id.x]=result;
}
'''
(OUT/'HybridLumenGIScreenMaterial.hlsl').write_bytes((S/'HybridLumenGIScreenMaterial.hlsl').read_bytes())
row=bytearray(208);struct.pack_into('<4f',row,16,.125,.125,0,0);(OUT/'inputs.bin').write_bytes(struct.pack('<I',1)+row)
results=[];base=[.25,.28125,.0625];detail=[.75,.25,.625]
for stage,path in [('baseline',OUT.parent/'baseline/HybridLumenGISurface.shader'),('candidate',S/'HybridLumenGISurface.shader')]:
    actual=path.read_text();(OUT/(stage+'.shader')).write_bytes(path.read_bytes())
    bodies=prior.extract(actual,r'^\s*Varyings Vert\(')+'\n'+prior.extract(actual,r'^\s*SurfaceOutput Frag\(')
    source=OUT/(stage+'.hlsl');source.write_text(abi+adapter+bodies+entry,encoding='utf-8')
    for variant,keyword in [('off',None),('mulx2','_DETAIL_MULX2'),('scaled','_DETAIL_SCALED')]:
        name=stage+'-'+variant;args=[DXC,'-HV','2018','-T','cs_6_0','-E','CSSurfaceDetail','-D','_EMISSION=1','-D','_OCCLUSIONMAP=1','-I',OUT,'-Fo',OUT/(name+'.dxil')]
        if keyword:args+=['-D',keyword+'=1']
        args+=[source];prior.run_command(OUT,name+'-compile',args)
        prior.run_command(OUT,name+'-warp',[exe,OUT/(name+'.dxil'),OUT/'inputs.bin',OUT/(name+'.bin')])
        raw=(OUT/(name+'.bin')).read_bytes();assert len(raw)==368
        diffuse=struct.unpack_from('<4f',raw,0);emission=struct.unpack_from('<4f',raw,16);uv=struct.unpack_from('<2f',raw,32)
        factor=[1]*3 if variant=='off' else [2*d if variant=='mulx2' else 2*d*.5-.5+1 for d in detail]
        expected=[b*(1+.75*(f-1))*.96 for b,f in zip(base,factor)]
        matchesReference=all(abs(a-b)<=2e-6 for a,b in zip(diffuse[:3],expected))
        assert emission==(.125,.25,.5,1) and diffuse[3]==1 and max(abs(uv[0]-.35),abs(uv[1]-.425))<2e-6
        if stage=='candidate' or variant=='off':assert matchesReference,name
        else:assert not matchesReference and all(abs(a-b*.96)<=2e-6 for a,b in zip(diffuse[:3],base)),name
        results.append({'stage':stage,'variant':variant,'diffuse':diffuse,'emission':emission,'mappedUv':uv,'expected':expected,'matchesReference':matchesReference,'shaderSha256':sha(path),'compiledSourceSha256':sha(source),'command':list(map(str,args))})
for variant in ['off']:
    assert (OUT/('baseline-'+variant+'.bin')).read_bytes()==(OUT/('candidate-'+variant+'.bin')).read_bytes()
report={'passed':True,'oldCounterexampleEstablished':True,'detailOffBitwiseUnchanged':True,'floatSourceBound':2e-6,'runner':str(exe),'runnerSha256':sha(exe),'inputSha256':sha(OUT/'inputs.bin'),'scope':'Actual unchanged Vert/Frag function bodies on WARP; fixed point-texture and raster adapters, not Unity keyword transfer','rows':results}
(OUT/'analysis.json').write_text(json.dumps(report,indent=2),encoding='utf-8');print(json.dumps({k:v for k,v in report.items() if k!='rows'}))
