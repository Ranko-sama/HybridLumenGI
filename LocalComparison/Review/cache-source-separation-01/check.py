"""One bounded check of the actual source-cache commit and invalidation fragment.
Integrated radiance values replace traversal; the existing WARP host is reused.
"""
import json, math, struct, subprocess
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
GPU = ROOT / 'Runtime/Resources/HybridLumenGI'
OUT = HERE / 'fixed-inputs'
assert not OUT.exists(), 'Preserve the first result; no automatic rerun.'
OUT.mkdir()
report = dict(status='running', scope='Actual HLSL joint commit and CSUpdateCache invalidation/empty-table fragment, fixed integrated inputs on existing WARP host; not traversal, CPU scheduling, HLOD readback or a physical reference.', cases=[])

# x global event, y uploaded light count, z hard invalidation, w skip/known/unknown.
# Source-origin RGB basis differs from total RGB, so preserving intensity alone cannot pass.
cases = [
    ('off-budget-then-on-budget', [(1,0,0,0),(0,1,0,0)], [2,2], [1,1],
        [.5,1.5,1,.5], [.5,1.5,1,0], [.5,.5], [.5,.5]),
    ('off-unknown-retains-emissive-color', [(1,0,0,2),(0,0,0,2)], [3,3], [3,3],
        [.5,1.5,1,.5], [.5,1.5,1,0], [.5,.5], [.5,.5]),
    ('off-known-then-on-known', [(1,0,0,1),(1,1,0,1)], [3,6], [3,2],
        [6,3,1.5,2], [.5,1.5,1,0], [2,2], [.75,6]),
    ('static-shared-weight', [(0,1,0,1),(0,1,0,1)], [4,4], [1,1],
        [20/3,10/3,5/3,6], [5/12,1.25,5/6,0], [5,6], [7.2,20/3]),
    ('invalid-unknown-then-cold-known', [(1,0,1,2),(0,0,0,1)], [1,1], [1,1],
        [.25,.75,.5,1], [.25,.75,.5,0], [0,1], [0,.25]),
    ('nonfinite-source-no-partial-commit', [(0,1,0,1)], [4], [float('nan')],
        [8,4,2,4], [.5,1.5,1,0], [4], [8]),
]

try:
    transport = (GPU / 'HybridLumenGITransport.hlsl').read_text()
    entry = next(l for l in transport.splitlines() if l.startswith('struct HLGICacheEntry {'))
    start = transport.index('    float3 tag=float3(p.identity.xy,_HLGI_Epoch);', transport.index('void CSUpdateCache('))
    fragment = transport[start:transport.index('    float2 geometricOct=', start)]
    commit = next(l for l in transport.splitlines() if l.strip().startswith('HLGICommitSourceCacheEstimate('))
    (OUT / 'HybridLumenGIRadianceValidity.hlsl').write_bytes((GPU / 'HybridLumenGIRadianceValidity.hlsl').read_bytes())
    shader = '''#include "HybridLumenGIRadianceValidity.hlsl"
ENTRY
struct Proxy { float4 identity; };
struct Surface { float3 position; uint generation; };
struct Input { float4 initial,guide,tag,steps[4],estimates,config,initialSource,sourceEstimates; };
struct Output { float4 finalValue,sourceValue,ages,red; };
StructuredBuffer<Input> Inputs : register(t0);
RWStructuredBuffer<Output> Outputs : register(u0);
cbuffer Counts : register(b0) { uint Count; }
static float2 activeChange;
static float _HLGI_GlobalReactive;
static int _HLGI_LightCount;
static float _HLGI_Epoch=3;
static int _HLGI_CacheRays=1;
float2 HLGIChangeAt(float3 position) { return activeChange; }
void Step(inout HLGICacheEntry e,Proxy p,Surface surface,float4 control,float totalInput,float sourceInput)
{
    _HLGI_GlobalReactive=control.x;_HLGI_LightCount=(int)control.y;
    activeChange=float2(control.z==1?1:0,control.x);
FRAGMENT
    if(control.w!=0)
    {
        bool estimateKnown=control.w==1;
        float3 sum=totalInput*(_HLGI_LightCount==0?float3(.25,.75,.5):float3(1,.5,.25));
        float3 nonAnalyticSum=sourceInput*float3(.25,.75,.5),guide=0,n=float3(0,1,0);
        float guidePower=0;
COMMIT
    }
}
[numthreads(64,1,1)]
void CSCacheSource(uint3 id:SV_DispatchThreadID)
{
    if(id.x>=Count)return;
    Input input=Inputs[id.x];HLGICacheEntry e=(HLGICacheEntry)0;
    e.irradiance=input.initial;e.guide=input.guide;e.tag=input.tag;e.nonAnalyticIrradiance=input.initialSource;
    Proxy p;p.identity=float4(1,2,0,1);Surface surface;surface.position=0;surface.generation=4;
    Output result=(Output)0;
    [loop] for(uint step=0;step<(uint)input.config.x;step++)
    {
        Step(e,p,surface,input.steps[step],input.estimates[step],input.sourceEstimates[step]);
        result.ages[step]=e.irradiance.a;result.red[step]=e.irradiance.r;
    }
    result.finalValue=e.irradiance;result.sourceValue=e.nonAnalyticIrradiance;Outputs[id.x]=result;
}
'''.replace('ENTRY', entry).replace('FRAGMENT', fragment).replace('COMMIT', commit)
    (OUT / 'Fixture.hlsl').write_text(shader, encoding='utf-8')
    payload = bytearray(struct.pack('<I', len(cases)))
    for _,steps,totals,sources,*_ in cases:
        values = [8,4,2,4, 1,0,0,3, 1,2,3,4]
        values += [v for step in steps for v in step] + [0] * (4 * (4-len(steps)))
        values += totals + [0] * (4-len(totals))
        values += [len(steps),0,0,0, .5,1.5,1,0]
        values += sources + [0] * (4-len(sources))
        payload.extend(struct.pack('<44f', *values))
    (OUT / 'inputs.bin').write_bytes(payload)
    host = json.loads((ROOT / 'LocalComparison/Review/temporal-reactive-history-limit-01/host-reuse.json').read_text())
    exe = Path(host['files']['exe']['path'])
    dxc = Path('C:/Program Files (x86)/Windows Kits/10/bin/10.0.26100.0/x64/dxc.exe')
    for label,command in [
        ('compile',[dxc,'-T','cs_6_0','-E','CSCacheSource','-I',OUT,'-Fo',OUT/'fixture.dxil',OUT/'Fixture.hlsl']),
        ('warp',[exe,OUT/'fixture.dxil',OUT/'inputs.bin',OUT/'outputs.bin'])]:
        process = subprocess.run([str(v) for v in command], capture_output=True, timeout=300)
        (OUT / (label+'.log')).write_bytes(process.stdout+process.stderr)
        if process.returncode: raise RuntimeError(label+' failed; retain the original log')
    raw = (OUT / 'outputs.bin').read_bytes()
    assert len(raw)==64*len(cases)
    for i,(name,_,__,___,total,source,ages,red) in enumerate(cases):
        observed = list(struct.unpack_from('<16f', raw, 64*i))
        assert all(math.isfinite(v) for v in observed), name+' nonfinite output'
        expected = total+source+ages+[0]*(4-len(ages))+red+[0]*(4-len(red))
        tolerance = 1e-6 if name=='static-shared-weight' else 0
        error = max(abs(a-b) for a,b in zip(observed,expected))
        report['cases'].append(dict(name=name,observed=observed,expected=expected,maxAbsError=error,passed=error<=tolerance))
        assert error<=tolerance, name
    report['status']='passed'
except Exception as error:
    report['status']='failed';report['error']=repr(error)
    raise
finally:
    (OUT / 'result.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
    print(json.dumps(dict(status=report['status'],result=str(OUT/'result.json'))))
