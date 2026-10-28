"""Finite old/candidate actual-HLSL comparison using the existing 192/48-byte WARP runner.

Only the depth fetch is adapted to eight supplied neighboring texels. Unity's
actual inverse projection and the product validation/projection functions run
in HLSL. This is not a new renderer or a whole-image equivalence claim.
"""
import hashlib,json,math,struct,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
PACKAGE=ROOT/'LocalComparison/Review/transport-hotspot-and-reuse-01'
OUT=PACKAGE/'receiver-contract';OUT.mkdir(exist_ok=True)
SHADERS=ROOT/'Runtime/Resources/HybridLumenGI'
BASE=PACKAGE/'compiler/baseline/source'
INCLUDES=Path('C:/Users/Administrator/AppData/Local/Temp/HybridLumenGI-shader-validation')
DXC=Path('C:/Program Files (x86)/Windows Kits/10/bin/10.0.26100.0/x64/dxc.exe')
RUNNER_ROOT=Path('C:/Users/Administrator/AppData/Local/Temp/hlgi-ray-footprint-warp-a5f05be8a41742cc9f59305cf543c29a')
RUNNER=RUNNER_ROOT/'build/Release/RayFootprintWarp.exe'
SCENE=ROOT/'LocalComparison/Review/thin-wall-transport-01/retry-v4/C/20261027-202314-2ac063eef20c4d9391e863bf1ead5fe2'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def save(p,value):p.write_bytes((json.dumps(value,indent=2)+'\n').encode())
def function(text,name):
    start=text.index(name+'(');start=text.rfind('\n',0,start)+1
    brace=text.index('{',start);depth=1;i=brace+1
    while depth:
        depth+=(text[i]=='{')-(text[i]=='}');i+=1
    return text[start:i]+'\n'
def matrix(d):return [d[f'e{r}{c}'] for c in range(4) for r in range(4)]
identity=[float(r==c) for c in range(4) for r in range(4)]
def record(m,uvd=(0,0,0,0),nx=(0,0,0,0),ny=(0,0,0,0),direction=(0,0,1,0),position=(0,0,0,0),size=(8,8,0,0),control=(0,0,0,0)):
    return struct.pack('<44f4I',*(m+list(uvd)+list(nx)+list(ny)+list(direction)+list(position)+list(size)+[0]*4),*control)
def run(name,args):
    result=subprocess.run([str(a) for a in args],capture_output=True,timeout=120)
    (OUT/(name+'.log')).write_bytes(result.stdout+result.stderr)
    commands.append({'name':name,'arguments':[str(a) for a in args],'exitCode':result.returncode})
    save(OUT/'commands.json',commands)
    assert result.returncode==0,(name,result.returncode)

commands=[]
assert not (OUT/'results.json').exists(),'Preserve completed first comparison'
original=(BASE/'HybridLumenGIKernels.hlsl').read_text();candidate=(SHADERS/'HybridLumenGIKernels.hlsl').read_text()
shared=['ValidDepth','WorldPosition','HLGIScreenDepthDelta','HLGITryScreenRayFootprint']
for name in shared:assert function(original,name)==function(candidate,name),name
assert (BASE/'HybridLumenGIRayFootprint.hlsl').read_bytes()==(SHADERS/'HybridLumenGIRayFootprint.hlsl').read_bytes()
runner_report=json.loads((RUNNER_ROOT/'ray-footprint-results.json').read_text(encoding='utf-8-sig'))
assert runner_report['status']=='passed'
for name in ['Tests/StandaloneRayFootprint/RayFootprintWarp.cpp.txt','Tests/StandaloneRayFootprint/CMakeLists.txt']:
    assert sha(ROOT/name).lower()==next(s['sha256'].lower() for s in runner_report['sources'] if s['file']==name)
assert sha(RUNNER)==next(s['sha256'].lower() for s in runner_report['artifacts'] if s['path']==str(RUNNER))
(OUT/'RayFootprintWarp.exe').write_bytes(RUNNER.read_bytes())
header='''#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
#include "HybridLumenGIRayFootprint.hlsl"
#include "HybridLumenGIScreenSampling.hlsl"
struct RayFootprintInput { column_major float4x4 worldToCard;float4 p,pX,pY,direction,normal,auxiliary,parameters;uint4 control; };
struct RayFootprintOutput { float4 values,comparison;uint4 predicates; };
StructuredBuffer<RayFootprintInput> _Inputs : register(t0);
RWStructuredBuffer<RayFootprintOutput> _Outputs : register(u0);
cbuffer TestCounts : register(b0) { uint _Count; }
// Substitutes only immutable texture loads; input order is x-1,x-2,x+1,x+2, then y.
struct DepthInput {
    float4 x,y;int2 center;
    float Load(int3 pixel) {
        int2 delta=pixel.xy-center;int distance=delta.x!=0?delta.x:delta.y;
        int index=distance<0?-distance-1:distance+1;
        return delta.x!=0?x[index]:y[index];
    }
};
static DepthInput _HLGI_Depth;
static float4 _HLGI_FullSize;
static float4x4 _HLGI_InvVP,_HLGI_View;
'''
source=header+'\n'.join(function(original,n) for n in shared)
source+='struct HLGIReceiverFootprintInput { float3 dx,dy;bool valid; };\n'
source+=function(candidate,'HLGIPrepareReceiverFootprint')+function(candidate,'HLGITryReceiverFootprint')
source+='''
[numthreads(64,1,1)]
void CSRayFootprintTest(uint3 id:SV_DispatchThreadID)
{
    if(id.x>=_Count || (id.x&1u)!=0u)return;
    RayFootprintInput i=_Inputs[id.x],j=_Inputs[id.x+1];
    _HLGI_InvVP=i.worldToCard;_HLGI_View=j.worldToCard;_HLGI_FullSize=i.auxiliary;
    _HLGI_Depth.x=i.pX;_HLGI_Depth.y=i.pY;_HLGI_Depth.center=(int2)i.control.zw;
    float2 uv=i.p.xy;float depth=i.p.z;
    float3 p=i.control.x!=0?i.normal.xyz:WorldPosition(uv,depth,_HLGI_InvVP);
#if CANDIDATE
    HLGIReceiverFootprintInput prepared=HLGIPrepareReceiverFootprint(uv,depth,p);
#endif
    [unroll]for(uint k=0;k<2;k++)
    {
        float3 direction=k==0?i.direction.xyz:j.direction.xyz;
        HLGIRayFootprint f;bool valid;
#if CANDIDATE
        valid=HLGITryReceiverFootprint(prepared,p,direction,f);
#else
        valid=HLGITryScreenRayFootprint(uv,depth,p,direction,f);
#endif
        RayFootprintOutput o=(RayFootprintOutput)0;
        o.values=float4(f.radius,f.slope,0,0);o.predicates=uint4(valid?1u:0u,f.valid,0,0);
        _Outputs[id.x+k]=o;
    }
}
'''
(OUT/'ReceiverFootprint.hlsl').write_bytes(source.encode())
cases=[];binary=[]
def add(name,uv,depth,nx,ny,dirs=((0,0,1),(1,2,3)),m=identity,view=identity,size=(8,8),position=None,pixel=None,expected=None):
    center=pixel or tuple(math.floor(u*s) if math.isfinite(u) else 0 for u,s in zip(uv,size))
    a=record(m,(*uv,depth,0),nx,ny,(*dirs[0],0),(*(position or (0,0,0)),0),(*size,0,0),(int(position is not None),0,*center))
    b=record(view,direction=(*dirs[1],0));binary.extend([a,b]);cases.append({'name':name,'pixel':center,'expected':expected})
flat=(.5,)*4
for pixel in [(0,0),(1,1),(3,3),(6,6),(7,7)]:
    add('flat-edge-'+str(pixel),tuple((p+.5)/8 for p in pixel),.5,flat,flat,expected=[True,True])
add('both-directions-degenerate',(.4375,.4375),.5,flat,flat,dirs=((0,0,0),(float('nan'),1,0)),expected=[False,False])
add('grazing-direction',(.4375,.4375),.5,flat,flat,dirs=((1,0,0),(1e-30,0,0)),expected=[True,True])
for name,nx,ny in [('all-invalid',(0,)*4,flat),('nan-neighbors',(float('nan'),)*4,flat),('infinite-neighbors',flat,(float('inf'),)*4),('discontinuous',(.8,.8,.8,.8),flat),('one-valid-side',(0,0,.5,.5),flat),('sloped',(.49,.48,.51,.52),(.48,.46,.52,.54))]:
    add(name,(.4375,.4375),.5,nx,ny,expected=[name in ['one-valid-side','sloped']]*2)
for name,uv,depth,position in [('uv-outside',(-.1,.5),.5,None),('depth-zero',(.4375,.4375),0,None),('depth-nan',(.4375,.4375),float('nan'),None),('depth-outside',(.4375,.4375),1.1,None),('position-invalid',(.4375,.4375),.5,(float('inf'),0,0))]:
    add(name,uv,depth,flat,flat,position=position,pixel=(3,3),expected=[False,False])
# Actual captured full-resolution D3D depth and exact GPU invVP, not low-res history depth.
source_data=json.loads((SCENE/'thin-0119-sources.json').read_text());frame=json.loads((SCENE/'frame-0119.json').read_text())
inv=matrix(source_data['invVP']);q=frame['cameraRotation'];x,y,z,w=(q[k] for k in ['x','y','z','w'])
rotation=[[1-2*(y*y+z*z),2*(x*y-z*w),2*(x*z+y*w)],[2*(x*y+z*w),1-2*(x*x+z*z),2*(y*z-x*w)],[2*(x*z-y*w),2*(y*z+x*w),1-2*(x*x+y*y)]]
pos=[frame['cameraPosition'][k] for k in ['x','y','z']]
viewrows=[[rotation[c][r] for c in range(3)] for r in range(3)]
viewrows=[[v*(-1 if r==2 else 1) for v in row] for r,row in enumerate(viewrows)]
for row in viewrows:row.append(-sum(a*b for a,b in zip(row,pos)))
viewrows.append([0,0,0,1]);view=[viewrows[r][c] for c in range(4) for r in range(4)]
depths=struct.unpack('<230400f',(SCENE/'thin-0119-depth.bin').read_bytes())
for px,py in [(1,1),(639,359),(321,181),(101,101),(201,181),(401,181),(501,281),(301,301),(21,181),(621,181),(321,21),(321,341)]:
    neighbor=lambda x,y:depths[y*640+x] if 0<=x<640 and 0<=y<360 else 0
    add('scene-'+str((px,py)),((px+.5)/640,(py+.5)/360),neighbor(px,py),tuple(neighbor(px+d,py) for d in [-1,-2,1,2]),tuple(neighbor(px,py+d) for d in [-1,-2,1,2]),m=inv,view=view,size=(640,360))
(OUT/'inputs.bin').write_bytes(struct.pack('<I',len(binary))+b''.join(binary));save(OUT/'cases.json',cases)
for side,define in [('old',0),('candidate',1)]:
    run(side+'-compile',[DXC,'-HV','2018','-T','cs_6_0','-E','CSRayFootprintTest','-O3','-D',f'CANDIDATE={define}','-D','SHADER_API_D3D11=1','-I',INCLUDES,'-I',SHADERS,'-Fo',OUT/(side+'.dxil'),'-Fc',OUT/(side+'.asm'),OUT/'ReceiverFootprint.hlsl'])
    asm=(OUT/(side+'.asm')).read_text();assert 'Size:   192' in asm and 'Size:    48' in asm,'Frozen runner ABI'
    run(side+'-warp',[OUT/'RayFootprintWarp.exe',OUT/(side+'.dxil'),OUT/'inputs.bin',OUT/(side+'.bin')])
old=(OUT/'old.bin').read_bytes();new=(OUT/'candidate.bin').read_bytes();assert len(old)==len(binary)*48
differences=[i for i in range(len(binary)) if old[i*48:(i+1)*48]!=new[i*48:(i+1)*48]]
failures=[];valid=0
for index,case in enumerate(cases):
    predicates=[]
    for k in range(2):
        row=old[(index*2+k)*48:(index*2+k+1)*48];known,flag=struct.unpack_from('<2I',row,32);predicates.append(bool(known));valid+=known
        if known!=flag or (not known and row[:8]!=b'\0'*8):failures.append(case['name']+' invalid semantics')
    case['oldValid']=predicates
    if case['expected'] is not None and predicates!=case['expected']:failures.append(case['name']+' expected '+str(case['expected'])+' actual '+str(predicates))
save(OUT/'cases.json',cases)
report={'passed':not differences and not failures,'cases':len(cases),'directionOutputs':len(binary),'validOutputs':valid,'bitwiseDifferentRows':differences,'failures':failures,
        'scope':'Old and candidate actual extracted HLSL, same finite inputs on D3D12 WARP; depth texture fetch adapter only. Not full-frame or physical-GPU equality.',
        'sceneView':'Reconstructed from recorded camera transform; invVP and depth copied from actual Unity frame. No claim of byte-identical recorded View constant.',
        'files':{str(p.relative_to(ROOT)):sha(p) for p in [BASE/'HybridLumenGIKernels.hlsl',SHADERS/'HybridLumenGIKernels.hlsl',SHADERS/'HybridLumenGIRayFootprint.hlsl',SCENE/'thin-0119-depth.bin',SCENE/'thin-0119-sources.json',SCENE/'frame-0119.json']},
        'artifacts':{p.name:sha(p) for p in OUT.iterdir() if p.is_file()},'commands':commands}
save(OUT/'results.json',report);print(json.dumps({k:v for k,v in report.items() if k not in ['files','artifacts','commands']}));raise SystemExit(0 if report['passed'] else 1)
