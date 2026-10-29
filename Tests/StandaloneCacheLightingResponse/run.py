"""One fixed actual-HLSL WARP dispatch and three affected entry compiles. No hashes."""
import json, os, struct, subprocess
from pathlib import Path

P=Path(__file__).resolve().parent
ROOT=P.parents[1]
GPU=ROOT/'Runtime/Resources/HybridLumenGI'
DXC=Path('C:/Program Files (x86)/Windows Kits/10/bin/10.0.26100.0/x64/dxc.exe')
INCLUDES=Path(os.environ['TEMP'])/'HybridLumenGI-shader-validation'

def main():
    out=P/'output'
    assert not out.exists(), 'Do not overwrite or rerun the first result'
    out.mkdir()
    report=dict(status='running',scope='Actual CSUpdateCache invalidation/pending-mark fragment and real radiance commit helper on existing D3D12 software WARP host. Fixed integrated-light samples replace ray traversal; CPU scheduling, actual multi-dispatch double-buffer synchronization, Unity and physical GPU are not exercised.',commands=[],cases=[])
    def save(): (out/'result.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
    def command(label,args):
        args=[str(x) for x in args]
        r=subprocess.run(args,capture_output=True,timeout=300)
        (out/(label+'.log')).write_bytes(r.stdout+r.stderr)
        report['commands'].append(dict(name=label,arguments=args,exitCode=r.returncode))
        save()
        assert r.returncode==0, label+' failed; see log'
    # Each control is global reactive, local reactive, invalidation kind
    # (0 none / 1 hard / 2 identity), update (0 budget skip / 1 known / 2 unknown).
    # Expected values are declared explicitly, independently of the helper.
    cases=[
      ('global-known-black',[(1,1,0,1),(0,0,0,1)],[0,0],[1,2],[0,0],[0,0,0,2],[0,1,0,0]),
      ('global-known-nonzero',[(1,1,0,1),(0,0,0,1)],[2,2],[1,2],[2,2],[2,1,.5,2],[0,1,0,0]),
      ('budget-pending-across-frames',[(1,1,0,0),(0,0,0,0),(0,1,0,0),(0,0,0,1)],[2,2,2,2],[.5,.5,.5,1],[8,8,8,2],[2,1,.5,1],[0,1,0,0]),
      ('unknown-then-known',[(1,1,0,2),(0,0,0,2),(0,0,0,1)],[2,2,2],[.5,.5,1],[8,8,2],[2,1,.5,1],[0,1,0,0]),
      ('unknown-retains-guide',[(1,1,0,2)],[2],[.5],[8],[8,4,2,.5],[1,0,0,3]),
      ('static-preserves-average',[(0,0,0,1),(0,0,0,1)],[4,4],[5,6],[7.2,20/3],[20/3,10/3,5/3,6],[0,1,0,0]),
      ('local-preserves-average',[(0,1,0,1),(0,0,0,2)],[4,4],[2,2],[6,6],[6,3,1.5,2],[0,1,0,0]),
      ('identity-invalid-unknown',[(1,1,2,2),(0,0,0,2)],[2,2],[0,0],[0,0],[0,0,0,0],[0,0,0,0]),
      ('hard-invalid-global-unknown',[(1,1,1,2),(0,0,0,1)],[2,2],[0,1],[0,2],[2,1,.5,1],[0,1,0,0])]
    report['expected']=[dict(name=x[0],controls=x[1],estimates=x[2],ages=x[3],red=x[4],final=x[5],guide=x[6]) for x in cases]
    report['tolerance']='Exact for all dyadic replacement/retention cases and ages; absolute 1e-6 only for static 1/5 and 1/6 averaging.'
    save()
    try:
        transport=(GPU/'HybridLumenGITransport.hlsl').read_text()
        start=transport.index('    float3 tag=float3(p.identity.xy,_HLGI_Epoch);',transport.index('void CSUpdateCache('))
        end=transport.index('    float2 geometricOct=',start)
        fragment=transport[start:end]
        assert 'if(_HLGI_GlobalReactive>0.5) e.irradiance.a=min(e.irradiance.a,0.5);' in fragment
        commit='        HLGICommitCacheEstimate(estimateKnown,sum,guide,guidePower,_HLGI_CacheRays,n,e.irradiance,e.guide);'
        assert transport.count(commit)==1
        validity=(GPU/'HybridLumenGIRadianceValidity.hlsl').read_text()
        assert 'irradiance.a<1?1:min(irradiance.a+1,32)' in validity
        assert 'irradiance.a>=1?lerp(irradiance.rgb,estimate,alpha):estimate' in validity
        (out/'ActualCacheFragment.hlsl').write_text(fragment+'\n'+commit,encoding='utf-8')
        (out/'HybridLumenGIRadianceValidity.hlsl').write_text(validity,encoding='utf-8')
        shader='''#include "HybridLumenGIRadianceValidity.hlsl"
struct HLGICacheEntry { float4 irradiance,tag,anchor,normal,guide; };
struct Proxy { float4 identity; };
struct Surface { float3 position; uint generation; };
struct Input { float4 initial,guide,tag,steps[4],estimates,config,reserved0,reserved1; };
struct Output { float4 finalValue,guide,ages,red; };
StructuredBuffer<Input> Inputs : register(t0);
RWStructuredBuffer<Output> Outputs : register(u0);
cbuffer Counts : register(b0) { uint Count; }
static float2 activeChange;
static float _HLGI_GlobalReactive;
static float _HLGI_Epoch=3;
static int _HLGI_CacheRays=1;
float2 HLGIChangeAt(float3 position) { return activeChange; }
void Step(inout HLGICacheEntry e,Proxy p,Surface surface,float4 control,float measurement)
{
    _HLGI_GlobalReactive=control.x;
    activeChange=float2(control.z==1?1:0,control.y);
FRAGMENT
    if(control.w!=0)
    {
        bool estimateKnown=control.w==1;
        float3 sum=measurement*float3(1,.5,.25),guide=0,n=float3(0,1,0);
        float guidePower=0;
COMMIT
    }
}
[numthreads(64,1,1)]
void CSCacheLightingResponse(uint3 id:SV_DispatchThreadID)
{
    if(id.x>=Count)return;
    Input input=Inputs[id.x];
    HLGICacheEntry buffers[2]; buffers[0]=(HLGICacheEntry)0; buffers[1]=(HLGICacheEntry)0;
    buffers[0].irradiance=input.initial;buffers[0].guide=input.guide;buffers[0].tag=input.tag;
    Proxy p;p.identity=float4(1,2,0,1);
    Surface surface;surface.position=0;surface.generation=4;
    Output result=(Output)0;uint read=0;
    [loop] for(uint step=0;step<(uint)input.config.x;step++)
    {
        if(input.steps[step].z==2)p.identity.x+=1;
        HLGICacheEntry e=buffers[read];
        Step(e,p,surface,input.steps[step],input.estimates[step]);
        buffers[1-read]=e;read=1-read;
        result.ages[step]=e.irradiance.a;result.red[step]=e.irradiance.r;
    }
    result.finalValue=buffers[read].irradiance;result.guide=buffers[read].guide;
    Outputs[id.x]=result;
}
'''.replace('FRAGMENT',fragment).replace('COMMIT',commit)
        (out/'Fixture.hlsl').write_text(shader,encoding='utf-8')
        payload=bytearray(struct.pack('<I',len(cases)))
        for _,steps,estimates,*_ in cases:
            values=[8,4,2,4,1,0,0,3,1,2,3,4]
            values.extend(v for control in steps for v in control)
            values.extend([0]*(4*(4-len(steps))))
            values.extend(estimates+[0]*(4-len(estimates)))
            values.extend([len(steps),0,0,0]+[0]*8)
            assert len(values)==44
            payload.extend(struct.pack('<44f',*values))
        (out/'inputs.bin').write_bytes(payload)
        host=json.loads((ROOT/'LocalComparison/Review/temporal-reactive-history-limit-01/host-reuse.json').read_text())
        exe=Path(host['files']['exe']['path']);assert exe.is_file()
        report['host']=str(exe)
        command('compile-fixture',[DXC,'-T','cs_6_0','-E','CSCacheLightingResponse','-I',out,'-Fo',out/'fixture.dxil',out/'Fixture.hlsl'])
        command('warp',[exe,out/'fixture.dxil',out/'inputs.bin',out/'outputs.bin'])
        raw=(out/'outputs.bin').read_bytes();assert len(raw)==64*len(cases)
        for i,(name,steps,estimates,ages,red,final,guide) in enumerate(cases):
            observed=struct.unpack_from('<16f',raw,64*i)
            expected=final+guide+ages+[0]*(4-len(ages))+red+[0]*(4-len(red))
            tolerance=1e-6 if name=='static-preserves-average' else 0
            error=max(abs(a-b) for a,b in zip(observed,expected))
            report['cases'].append(dict(name=name,observed=list(observed),expected=expected,maxAbsError=error,passed=error<=tolerance))
            assert error<=tolerance, name
        # Same compiler flags/include paths used by ValidateShaders.ps1, narrowed
        # to CSUpdateCache. Existing Unity include cache and native RayQuery adapter.
        assert (INCLUDES/'Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl').is_file()
        assert (INCLUDES/'Adapters/UnityRayQuery.cginc').is_file()
        report['compileScope']='Only CSUpdateCache software, exact-software and hardware, with ValidateShaders flags and existing include/UnityRayQuery adapter paths. Offline compilation is not Unity or hardware execution.'
        for label,file,profile in [('software','HybridLumenGI.compute','cs_6_0'),('exact-software','HybridLumenGIExactSoftware.compute','cs_6_0'),('hardware','HybridLumenGIHardware.compute','cs_6_5')]:
            command('compile-'+label,[DXC,'-T',profile,'-E','CSUpdateCache','-D','SHADER_API_D3D11=1','-D','SHADER_STAGE_COMPUTE=1','-D','UNITY_COMPILER_DXC=1','-D','UNITY_VERSION=600000','-I',INCLUDES/'Adapters','-I',INCLUDES,'-I',GPU,'-Fo',out/(label+'.dxil'),GPU/file])
        report['status']='passed'
    except Exception as error:
        report['status']='failed';report['error']=repr(error)
        raise
    finally:
        save();print(json.dumps(dict(status=report['status'],result=str(out/'result.json'))))

if __name__=='__main__':main()
