"""One finite actual observer-mapper check through the existing192/48-byte WARP runner."""
import hashlib,json,struct,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];H=ROOT/'LocalComparison/Harness';OUT=ROOT/'LocalComparison/Review/material-mpb-propagation-02/preflight'
OUT.mkdir(parents=True,exist_ok=True)
BASE=ROOT/'LocalComparison/Review/transport-hotspot-and-reuse-01/receiver-contract'
RUNNER=BASE/'RayFootprintWarp.exe';sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
assert sha(RUNNER)==json.loads((BASE/'results.json').read_text(encoding='utf-8'))['artifacts']['RayFootprintWarp.exe']
shader='''#include "MaterialEventIdentity.hlsl"
struct Input { float4x4 matrix;float4 p,pX,pY,direction,normal,auxiliary,parameters;uint4 control; };
struct Output { uint4 mapping,objectRow,identity; };
StructuredBuffer<Input> _Inputs:register(t0);RWStructuredBuffer<Output> _Outputs:register(u0);
cbuffer Counts:register(b0){uint _Count;}
[numthreads(64,1,1)]void CSObserverContract(uint3 id:SV_DispatchThreadID)
{
 if(id.x>=_Count)return;Input input=_Inputs[id.x];Output output=(Output)0;
 if(input.control.z==0u){_Outputs[id.x]=output;return;}
 uint4 identity=asuint(input.p);uint3 candidate=asuint(input.pX).xyz;
 uint4 rows[3];rows[0]=uint4(11,0,1,0);rows[1]=uint4(22,0,1,0);rows[2]=uint4(33,0,input.control.y,0);
 uint index,status;bool loaded=MEObjectIndex(identity,candidate,input.control.x,index,status);
 if(loaded){output.objectRow=rows[index];status=MEObjectLoadedStatus(status,identity.xy,output.objectRow.xy);}
 output.mapping=uint4(loaded?index:0xffffffffu,status,candidate.x,candidate.z);output.identity=identity;_Outputs[id.x]=output;
}
'''
(OUT/'ObserverIdentityContract.hlsl').write_text(shader,encoding='utf-8')
cases=[
 ('different-row-and-primitive',(33,0,9,1),(3,0,9),1,1,127,2,33),
 ('valid-nonreusable-row',(33,0,9,1),(3,0,9),0,1,127,2,33),
 ('zero-candidate',(33,0,9,1),(0,0,9),0,1,27,0xffffffff,0),
 ('out-of-range',(33,0,9,1),(4,0,9),0,1,27,0xffffffff,0),
 ('ambiguous',(33,0,9,1),(3,1,9),0,1,119,2,33),
 ('key-mismatch',(77,0,9,1),(3,0,9),0,1,63,2,33),
 ('primitive-mismatch',(33,0,9,1),(3,0,8),0,1,111,2,33),
 ('unknown-identity-row-present',(0,0,0,0),(3,0,9),0,1,45,2,33),
 ('unknown-no-row',(0,0,0,0),(0,0,0),0,1,9,0xffffffff,0),
 ('inactive',(33,0,9,1),(3,0,9),0,0,0,0,0)]
inputs=[]
for name,identity,candidate,reusable,active,status,index,key in cases:
    record=bytearray(192);struct.pack_into('<4I',record,64,*identity);struct.pack_into('<4I',record,80,*candidate,0);struct.pack_into('<4I',record,176,3,reusable,active,0);inputs.append(bytes(record))
(OUT/'mapper-inputs.bin').write_bytes(struct.pack('<I',len(inputs))+b''.join(inputs))
commands=[]
def run(name,args):
    result=subprocess.run([str(a) for a in args],capture_output=True,timeout=60);(OUT/(name+'.log')).write_bytes(result.stdout+result.stderr)
    commands.append({'name':name,'arguments':[str(a) for a in args],'exitCode':result.returncode})
    (OUT/'mapper-commands.json').write_text(json.dumps(commands,indent=2),encoding='utf-8');assert result.returncode==0,(name,result.returncode)
DXC='C:/Program Files (x86)/Windows Kits/10/bin/10.0.26100.0/x64/dxc.exe'
run('mapper-compile',[DXC,'-T','cs_6_0','-E','CSObserverContract','-O3','-I',H,'-Fo',OUT/'mapper.dxil',OUT/'ObserverIdentityContract.hlsl'])
run('mapper-warp',[RUNNER,OUT/'mapper.dxil',OUT/'mapper-inputs.bin',OUT/'mapper-outputs.bin'])
outputs=(OUT/'mapper-outputs.bin').read_bytes();assert len(outputs)==48*len(cases)
results=[]
for i,(name,identity,candidate,reusable,active,status,index,key) in enumerate(cases):
    data=struct.unpack_from('<12I',outputs,i*48)
    passed=data[0]==index and data[1]==status and data[4]==key and data[6]==(reusable if key else 0)
    results.append({'case':name,'actual':list(data),'expectedIndex':index,'expectedStatus':status,'passed':passed})
report={'passed':all(r['passed'] for r in results),'cases':results,'sourceSha256':sha(H/'MaterialEventIdentity.hlsl'),'runnerSha256':sha(RUNNER),
    'scope':'Actual observer index/status helper on existing WARP runner; distinct object index and primitive, bounds/unknown/key/ambiguity and reusable0. No Unity event or new IO runner.'}
(OUT/'mapper-check.json').write_text(json.dumps(report,indent=2),encoding='utf-8');print(json.dumps(report));raise SystemExit(0 if report['passed'] else 1)
