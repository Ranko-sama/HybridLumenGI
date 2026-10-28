"""Finite actual-HLSL SDF completion check; one baseline and one same-input candidate.
Reuses the existing D3D12 WARP host, adapting only buffer bindings/strides.
No Unity, physical GPU, scene capture, or independently reimplemented marcher.
"""
import argparse, hashlib, json, math, re, shutil, struct, subprocess, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SHADERS = Path('Runtime/Resources/HybridLumenGI')
HARNESS = Path('Tests/StandaloneSdfQueryCompletion/SdfQueryCompletionHarness.hlsl')
HOST = Path('Tests/StandaloneRayQueryPropagation/RayQueryPropagationWarp.cpp.txt')
SOURCES = [SHADERS / ('HybridLumenGI' + name + '.hlsl') for name in
           ('SdfTrace', 'Hit', 'RayFootprint', 'RadianceValidity', 'SceneBvh', 'Transport', 'Kernels')]
SOURCES += [HARNESS, HOST, Path('Tests/Validate-SdfQueryCompletion.py')]


def sha(data): return hashlib.sha256(data).hexdigest()
def save_json(path, value): path.write_text(json.dumps(value, indent=2, ensure_ascii=False), encoding='utf-8')
def replace_once(text, old, new):
    if text.count(old) != 1: raise RuntimeError('Source adapter anchor changed: ' + old[:80])
    return text.replace(old, new, 1)


def functions(text, names):
    result = []
    pattern = r'^(?:bool|float3|HLGIRayFootprint) (' + '|'.join(names) + r')\('
    for match in re.finditer(pattern, text, re.M):
        start = text.index('{', match.start()); depth = 0
        for end in range(start, len(text)):
            if text[end] == '{': depth += 1
            elif text[end] == '}':
                depth -= 1
                if depth == 0:
                    result.append(text[match.start():end+1]); break
        else: raise RuntimeError('Unterminated source function')
    if not result: raise RuntimeError('Missing actual source functions')
    return '\n'.join(result) + '\n'


def fixtures():
    unit = 1 / math.sqrt(1 + .015**2)
    direction = (unit, 0, -.015 * unit)
    cases = []
    def add(name, origin=(0, 0, .28), ray=direction, limit=4, steps=8, mode=0, global_sdf=0, detail=4, screen=0):
        bits = 0xffffffff if screen == 'bound' else struct.unpack('<I', struct.pack('<f', screen))[0]
        values = (*origin, limit, *ray, detail, steps, mode, global_sdf, bits)
        cases.append(dict(name=name, values=values))
    add('exhausted')
    add('definite_hit', (2, 0, .9), (0, 0, -1), 2, 128)
    add('complete_interval_miss', (0, .8, .8), (1, 0, 0))
    add('nearer_known_after_sdf', mode=1)
    add('farther_known_after_sdf', mode=2)
    add('nearer_known_before_sdf', mode=3)
    add('farther_known_before_sdf', mode=4)
    add('near_segment_unresolved', global_sdf=1, detail=1.4)
    add('far_segment_unresolved', global_sdf=1, detail=.5)
    add('screen_before_interval', screen=.5)
    add('screen_after_interval', screen=2)
    add('screen_at_interval_bound', screen='bound')
    raw = struct.pack('<I', len(cases)) + b''.join(struct.pack('<8f4I', *c['values']) for c in cases)
    # Source geometry: closed axis-aligned box, center(2,0,0), half extents(.8,.5,.25).
    # The grazing ray enters the padded SDF domain near t=1 and the real box at t=2.
    # This independent slab intersection, not a high-step trace, establishes a
    # remaining interval containing real geometry after eight bounded advances.
    proxies = [((2, 0, 0), (1, 1, 1)), ((.5, 0, .28), (.05, .1, .1)), ((3.5, 0, .2275), (.05, .1, .1))]
    for slot, (center, extents) in enumerate(proxies):
        raw += struct.pack('<20f', *center, 0, *extents, 0, .5, .5, .5, 1, 1, 1, 1, 0, 17+slot, 3, 0, 1)
    matrix = [1,0,0,0, 0,1,0,0, 0,0,1,0, -2,0,0,1]
    raw += struct.pack('<28f4I', *matrix, -1,-1,-1,16, 2,2,2,1, .125,.125,.125,math.sqrt(3)*.125/2, 0,17,3,3)
    raw += bytes(2*128)
    distances = []
    for z in range(16):
        for y in range(16):
            for x in range(16):
                p = [(v+.5)/8-1 for v in (x,y,z)]
                q = [abs(v)-extent for v,extent in zip(p,(.8,.5,.25))]
                distances.append(math.sqrt(sum(max(v,0)**2 for v in q)) + min(max(q),0))
    raw += struct.pack('<4096f', *distances)
    interval = [1/unit, 3/unit]; intersection = (.28-.25)/(.015*unit)
    # Convex trilinear interpolation over the first half-unit corridor uses
    # these nodes. Their maximum absolute value bounds every possible step in
    # that corridor, independently of the actual march sequence. Eight steps
    # remain in the corridor, before the analytic box intersection.
    region_max = max(abs(distances[x+16*(y+16*z)]) for x in range(5) for y in (7,8) for z in (9,10))
    assert max(region_max-math.sqrt(3)*.125/2, .125*.2) < .0625
    assert interval[0] + .5 < intersection < interval[1]
    return raw, dict(cases=cases, geometry=dict(center=[2,0,0],halfExtents=[.8,.5,.25]),
        domainInterval=interval, geometricFirstIntersection=intersection, firstEightAdvanceUpperBound=.5, corridorMaximumAbsoluteSample=region_max,
        geometryTruth='Analytic closed-box SDF sampled at voxel centers; independent ray/slab intersection. Not a high-step oracle.',
        scope='Actual SDF sampler/loop, detail and near/far query, shadow/visibility, ProxyRadiance, cache interpolation and original screen/world gather decision. Controlled scene list/material/screen adapters; no Unity or physical GPU.')


def prepare_source(snapshot, stage):
    out = stage / 'shader'; out.mkdir()
    for name in ('Hit','RayFootprint','RadianceValidity'):
        shutil.copyfile(snapshot / SHADERS / ('HybridLumenGI'+name+'.hlsl'), out / ('HybridLumenGI'+name+'.hlsl'))
    sdf = (snapshot / SHADERS / 'HybridLumenGISdfTrace.hlsl').read_text(encoding='utf-8-sig')
    sdf = replace_once(sdf, 'StructuredBuffer<HLGISdfMetadata> _HLGI_SdfMetadata;', 'StructuredBuffer<HLGISdfMetadata> _HLGI_SdfMetadata:register(t2);')
    sdf = replace_once(sdf, 'StructuredBuffer<float> _HLGI_SdfDistances;', 'StructuredBuffer<float> _HLGI_SdfDistances:register(t3);')
    sdf = replace_once(sdf, 'int _HLGI_SdfSlotCount, _HLGI_SdfVoxelCount, _HLGI_SdfTraceSteps;', 'static int _HLGI_SdfSlotCount, _HLGI_SdfVoxelCount, _HLGI_SdfTraceSteps;')
    (out / 'ActualSdfTrace.hlsl').write_text(sdf, encoding='utf-8')
    transport = (snapshot / SHADERS / 'HybridLumenGITransport.hlsl').read_text(encoding='utf-8-sig')
    bvh = (snapshot / SHADERS / 'HybridLumenGISceneBvh.hlsl').read_text(encoding='utf-8-sig')
    (out / 'ActualBvhBounds.hlsl').write_text(functions(bvh, ['HLGIBvhBounds']), encoding='utf-8')
    (out / 'ActualSceneQueries.hlsl').write_text(functions(transport, ['IntersectProxy','HLGIPointQueryFootprint','TraceSceneDetailQuery','TraceSceneQuery','TraceSceneHit','TraceSceneVisibilityHit','TraceShadow']), encoding='utf-8')
    (out / 'ActualCacheQueries.hlsl').write_text(functions(transport, ['HLGIHitOwnerCurrent','HLGICachedSurface','HLGICachedSample','CachedIrradiance']), encoding='utf-8')
    (out / 'ActualProxyRadiance.hlsl').write_text(functions(transport, ['ProxyRadiance']), encoding='utf-8')
    kernels = (snapshot / SHADERS / 'HybridLumenGIKernels.hlsl').read_text(encoding='utf-8-sig')
    start = kernels.index('        HLGIHit hit;', kernels.index('float3 dir=HLGISampleTransportDirection', kernels.index('void CSTrace(')))
    end = kernels.index('        // One independent area draw', start)
    gather = kernels[start:end]
    harness = (snapshot / HARNESS).read_text(encoding='utf-8-sig')
    proxy = re.search(r'^struct HLGIProxy\s*\{[^}]*\};', transport, re.M).group(0)
    harness = replace_once(harness, '// ACTUAL_PROXY_DECLARATION', proxy)
    harness = replace_once(harness, '        // ACTUAL_GATHER_DECISION', gather)
    (out / 'Harness.hlsl').write_text(harness, encoding='utf-8')
    save_json(stage / 'extracted-source.json', dict(gatherSha256=sha(gather.encode()), shaders={p.name:sha(p.read_bytes()) for p in out.iterdir()}))


def prepare_host(snapshot, stage):
    text = (snapshot / HOST).read_text(encoding='utf-8-sig')
    text = replace_once(text, 'InputStride=160,OutputStride=368', 'InputStride=48,OutputStride=96')
    text = replace_once(text, 'input.size()!=4+InputStride*count', 'input.size()!=4+InputStride*count+3*80+3*128+4096*4')
    start = text.index('        D3D12_ROOT_PARAMETER parameters[3]{};')
    end = text.index('        ComPtr<ID3DBlob> signatureBytes', start)
    text = text[:start] + '''        D3D12_ROOT_PARAMETER parameters[6]{};
        for(UINT i=0;i<4;i++){parameters[i].ParameterType=D3D12_ROOT_PARAMETER_TYPE_SRV;parameters[i].Descriptor.ShaderRegister=i;}
        parameters[4].ParameterType=D3D12_ROOT_PARAMETER_TYPE_UAV;parameters[4].Descriptor.ShaderRegister=0;
        parameters[5].ParameterType=D3D12_ROOT_PARAMETER_TYPE_32BIT_CONSTANTS;parameters[5].Constants.ShaderRegister=0;parameters[5].Constants.Num32BitValues=1;
        D3D12_ROOT_SIGNATURE_DESC signatureDesc{};signatureDesc.NumParameters=6;signatureDesc.pParameters=parameters;
''' + text[end:]
    marker = '        ComPtr<ID3D12CommandAllocator> allocator;'
    extra = '''        auto Upload=[&](std::size_t offset,UINT64 bytes){
            auto resource=Buffer(device.Get(),bytes,D3D12_HEAP_TYPE_UPLOAD,D3D12_RESOURCE_STATE_GENERIC_READ);
            void* target=nullptr;D3D12_RANGE none{};Hr(resource->Map(0,&none,&target),"Map SDF data");
            std::memcpy(target,input.data()+offset,static_cast<std::size_t>(bytes));resource->Unmap(0,nullptr);return resource;};
        std::size_t offset=4+static_cast<std::size_t>(InputStride*count);
        auto proxies=Upload(offset,3*80),metadata=Upload(offset+3*80,3*128),distances=Upload(offset+3*80+3*128,4096*4);
'''
    text = replace_once(text, marker, extra+marker)
    text = replace_once(text, 'list->SetComputeRootUnorderedAccessView(1,outputs->GetGPUVirtualAddress());list->SetComputeRoot32BitConstant(2,count,0);',
        'list->SetComputeRootShaderResourceView(1,proxies->GetGPUVirtualAddress());list->SetComputeRootShaderResourceView(2,metadata->GetGPUVirtualAddress());list->SetComputeRootShaderResourceView(3,distances->GetGPUVirtualAddress());list->SetComputeRootUnorderedAccessView(4,outputs->GetGPUVirtualAddress());list->SetComputeRoot32BitConstant(5,count,0);')
    text = text.replace('RayQueryPropagation/scene query', 'SDF completion/query/consumer')
    host = stage / 'host'; host.mkdir(); (host / 'SdfQuery.cpp').write_text(text, encoding='utf-8')
    (host / 'CMakeLists.txt').write_text('cmake_minimum_required(VERSION 3.20)\nproject(SdfQuery LANGUAGES CXX)\nset(CMAKE_CXX_STANDARD 17)\nadd_executable(SdfQuery SdfQuery.cpp)\ntarget_link_libraries(SdfQuery PRIVATE d3d12 dxgi)\ntarget_compile_options(SdfQuery PRIVATE /W4 /WX /permissive- /utf-8)\n', encoding='utf-8')


def judge(data, fixture, stage_name, baseline, flags):
    names = [c['name'] for c in fixture['cases']]
    assert len(data) == len(names)*96, 'Output ABI differs'
    rows = []
    for i, name in enumerate(names):
        values = struct.unpack_from('<4I4f4I4f4I4f', data, i*96)
        rows.append(dict(name=name,query=values[:4],distancePosition=values[4:8],consumers=values[8:12],radiance=values[12:16],extra=values[16:20],cache=values[20:24]))
    r = {v['name']:v for v in rows}
    assert r['definite_hit']['query'][0] == 1 and r['definite_hit']['consumers'][1] == 1, 'Definite hit control'
    assert r['complete_interval_miss']['query'][0] == 0 and r['complete_interval_miss']['consumers'][1] == 1, 'Complete interval miss control'
    if stage_name == 'baseline':
        e = r['exhausted']; assert e['query'][0] == 0 and e['consumers'] == (0,1,0,1) and e['radiance'][:3] == (2,3,4), 'Legal counterexample not established; stop'
        assert e['extra'][3] == 1 and e['cache'][0:3] == (1,1,1), 'Original numeric acceptance not observed'
    else:
        assert flags != 0, 'Candidate unresolved state missing'
        unknown = ['exhausted','farther_known_after_sdf','farther_known_before_sdf','near_segment_unresolved','far_segment_unresolved','screen_after_interval','screen_at_interval_bound']
        for name in unknown:
            v = r[name]
            assert v['query'][0] == 1 and v['query'][1]&flags and v['query'][3] == 0, name+' lost unresolved query'
            assert v['consumers'] == (1,0,1,0) and v['extra'][3] == 0, name+' converted unknown into a measurement'
            assert not v['query'][1] & (2|4|8|16|32|64|128|256|1024), name+' fabricated surface identity'
            assert abs(v['distancePosition'][0]-fixture['domainInterval'][0]) < 2e-5, name+' did not use conservative interval bound'
            assert v['distancePosition'][1:] == (0,0,0), name+' fabricated a position'
        for name in ['nearer_known_after_sdf','nearer_known_before_sdf']:
            assert r[name]['query'][2] == 1 and r[name]['query'][3] == 1 and r[name]['consumers'][3] == 1, name+' lost nearer proven hit'
        s = r['screen_before_interval']; assert s['query'][1]&flags and s['consumers'][3] == 1 and s['radiance'][:3] == (7,8,9), 'Proven closer screen sample rejected'
        assert r['exhausted']['cache'] == (0,0,0,0), 'Unknown cache connection was reweighted or became valid zero bounce'
        prior = {v['name']:v for v in baseline['rows']}
        for name in ['definite_hit','complete_interval_miss','nearer_known_after_sdf','nearer_known_before_sdf']:
            for key in ['query','distancePosition','consumers','radiance','extra']:
                assert list(r[name][key]) == prior[name][key], name+' changed proven control '+key
    return rows


def main():
    parser = argparse.ArgumentParser(); parser.add_argument('--stage', choices=['baseline','candidate'], required=True); parser.add_argument('--evidence', type=Path, required=True)
    args = parser.parse_args(); evidence=args.evidence.resolve(); evidence.mkdir(parents=True, exist_ok=True)
    stage = evidence / args.stage; stage.mkdir(exist_ok=False)
    report = dict(stage=args.stage,status='preparing',unityExecuted=False,physicalGpuExecuted=False,warpExecuted=False,commands=[])
    def run(name, argv):
        completed = subprocess.run([str(v) for v in argv], stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        (stage/(name+'.log')).write_bytes(completed.stdout); report['commands'].append(dict(name=name,arguments=[str(v) for v in argv],exitCode=completed.returncode))
        print(name, 'exit='+str(completed.returncode), flush=True)
        if completed.returncode: raise RuntimeError(name+' failed; original output retained')
        return completed.stdout
    try:
        snapshot = stage / 'source'; hashes = {}
        for path in SOURCES:
            target=snapshot/path;target.parent.mkdir(parents=True,exist_ok=True);data=(ROOT/path).read_bytes();target.write_bytes(data);hashes[str(path).replace('\\','/')]=sha(data)
        report['sources']=hashes
        if args.stage == 'baseline':
            raw, fixture=fixtures();(evidence/'inputs.bin').write_bytes(raw);save_json(evidence/'fixture.json',fixture)
        else:
            fixture=json.loads((evidence/'fixture.json').read_text(encoding='utf-8'));raw=(evidence/'inputs.bin').read_bytes()
            old=json.loads((evidence/'baseline/report.json').read_text(encoding='utf-8'))
            assert old['status']=='counterexample_confirmed' and old['inputSha256']==sha(raw), 'Baseline/inputs not frozen'
            for path in [str(HARNESS).replace('\\','/'),str(HOST).replace('\\','/'),'Tests/Validate-SdfQueryCompletion.py']:
                assert hashes[path]==old['sources'][path], 'Harness changed between frozen executions'
        report['inputSha256']=sha(raw);prepare_source(snapshot,stage);prepare_host(snapshot,stage)
        dxc=Path('C:/Program Files (x86)/Windows Kits/10/bin/10.0.26100.0/x64/dxc.exe')
        shader=stage/'shader';dxil=stage/'query.dxil';listing=stage/'query.ll'
        run('dxc',[dxc,'-HV','2018','-T','cs_6_0','-E','CSSdfQueryCompletion','-I',shader,'-Fo',dxil,'-Fc',listing,shader/'Harness.hlsl'])
        assembly=listing.read_text(encoding='utf-8-sig')
        assert re.search(r'(?s)QueryInput.*?Size:\s+48',assembly) and re.search(r'(?s)QueryOutput.*?Size:\s+96',assembly), 'DXIL ABI mismatch'
        vswhere=Path('C:/Program Files (x86)/Microsoft Visual Studio/Installer/vswhere.exe')
        vs=json.loads(run('vswhere',[vswhere,'-latest','-products','*','-version','[17.0,18.0)','-requires','Microsoft.VisualStudio.Component.VC.Tools.x86.x64','-format','json','-utf8']).decode('utf-8-sig'))[0]
        cmake=Path(vs['installationPath'])/'Common7/IDE/CommonExtensions/Microsoft/CMake/CMake/bin/cmake.exe'
        run('configure',[cmake,'-S',stage/'host','-B',stage/'build','-G','Visual Studio 17 2022','-A','x64'])
        run('build',[cmake,'--build',stage/'build','--config','Release'])
        (stage/'execution-started.txt').write_text('Unique frozen '+args.stage+' execution\n',encoding='utf-8')
        run('warp',[stage/'build/Release/SdfQuery.exe',dxil,evidence/'inputs.bin',stage/'outputs.bin']);report['warpExecuted']=True
        hit=(snapshot/SHADERS/'HybridLumenGIHit.hlsl').read_text(encoding='utf-8-sig');match=re.search(r'#define HLGI_HIT_QUERY_UNRESOLVED\s+(\d+)u',hit)
        baseline=None if args.stage=='baseline' else json.loads((evidence/'baseline/report.json').read_text(encoding='utf-8'))
        report['rows']=judge((stage/'outputs.bin').read_bytes(),fixture,args.stage,baseline,int(match[1]) if match else 0)
        for path,digest in hashes.items(): assert sha((ROOT/path).read_bytes())==digest, 'Source changed during execution: '+path
        report['status']='counterexample_confirmed' if args.stage=='baseline' else 'passed'
        print(report['status']+': actual HLSL execution; no Unity or physical GPU.',flush=True)
    except Exception as error:
        report['status']='failed';report['error']=str(error);raise
    finally: save_json(stage/'report.json',report)


if __name__ == '__main__': main()
