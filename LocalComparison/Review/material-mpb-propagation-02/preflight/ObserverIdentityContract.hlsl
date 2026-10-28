#include "MaterialEventIdentity.hlsl"
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
