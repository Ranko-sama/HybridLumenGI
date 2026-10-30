"""One bounded paired actual-HLSL comparison. Root executes; no hashes/new host/Unity."""
import json
import math
import re
import struct
import subprocess
from pathlib import Path

P = Path(__file__).resolve().parent
ROOT = P.parents[3]
GPU_REL = 'Runtime/Resources/HybridLumenGI/'
GPU = ROOT / GPU_REL
BASELINE = 'ff3805d'
DXC = Path('C:/Program Files (x86)/Windows Kits/10/bin/10.0.26100.0/x64/dxc.exe')
HOST_RECEIPT = ROOT / 'LocalComparison/Review/parallel-color-dynamics-01/temporal/host-reuse.json'
FILES = ('HybridLumenGITransport.hlsl', 'HybridLumenGIKernels.hlsl',
         'HybridLumenGIEmissiveSampling.hlsl', 'HybridLumenGIEmissiveRecords.hlsl')


def function(source, name):
    match = re.search(r'^(?:uint|float[234]?|bool|void) ' + name + r'\(', source, re.M)
    assert match, 'Actual function missing: ' + name
    start = match.start()
    opening = source.index('{', start)
    end, depth = opening + 1, 1
    while depth:
        depth += (source[end] == '{') - (source[end] == '}')
        end += 1
    return source[start:end]


def caller(source, screen):
    begin = 'float3 dir=HLGISampleTransportDirection(' if screen else 'float weight;float3 direction=HLGISampleTransportDirection('
    name = 'dir' if screen else 'direction'
    finish = 'if(!all(isfinite(' + name + '))) { estimateKnown=false;break; }'
    assert source.count(begin) == 1 and source.count(finish) == 1
    start = source.index(begin)
    return source[start:source.index(finish, start) + len(finish)]


def instrument_caller(body, screen):
    """Keep actual calls/gates; hoist locals and observe their values, no arithmetic edits."""
    name, weight = ('dir', 'sampleWeight') if screen else ('direction', 'weight')
    body = body.replace('float3 dir=', 'dir=', 1) if screen else body.replace('float weight;float3 direction=', 'direction=', 1)
    end = body.index(';', body.index('HLGISampleTransportDirection(')) + 1
    body = body[:end] + '\n        adapterInitial=' + weight + ';' + body[end:]
    pattern = r'if\(!HLGIAreaMatchedDirectionWeight\(([^\n]+)\)\)'
    body, count = re.subn(pattern, r'if(!(adapterMatched=HLGIAreaMatchedDirectionWeight(\1)))', body)
    assert count == 1
    function_name = 'AdapterScreen' if screen else 'AdapterCacheUpdate'
    local = 'receiverCache' if screen else 'e'
    return f'''void {function_name}(float3 origin,float3 n,float4 guide,uint seed,out float4 result,out uint4 state)
{{
    uint rng=seed; AdapterCache {local}; {local}.guide=guide;
    float3 {name}=0; float {weight}=0,adapterInitial=0;
    bool estimateKnown=true,adapterMatched=false;
    do {{
        {body}
    }} while(false);
    result=float4({name},{weight});
    state=uint4(rng,estimateKnown?1u:0u,adapterMatched?1u:0u,asuint(adapterInitial));
}}
'''


def row(name, area, emissive, *, bad_normal=False, infinite_cdf=False):
    normal = [float('nan'), 0, 1] if bad_normal else [0, 0, 1]
    guide = [0, 0, 0, 0] if bad_normal or infinite_cdf else [.6, 0, .8, 1]
    values = ([0, 0, 0, area] + normal + [.35] + guide +
              [emissive, 1 if infinite_cdf else 2, 0 if infinite_cdf else 17, 0] +
              ([0, 0, 2, .5] if infinite_cdf else [1, 0, 3, .5]) +
              [0, float('inf') if infinite_cdf else .4, 0, 0] +
              [-1, 0, 2, .5] + [.4, 1, 0, 0] + [0] * 12)
    assert len(values) == 44
    return dict(name=name, values=values, expectedAccepted=not (bad_normal or infinite_cdf),
                expectedMatched=False if infinite_cdf else None)


def json_safe(value):
    if isinstance(value, float) and not math.isfinite(value):
        return 'NaN' if math.isnan(value) else '+Infinity' if value > 0 else '-Infinity'
    if isinstance(value, dict):
        return {k: json_safe(v) for k, v in value.items()}
    if isinstance(value, (list, tuple)):
        return [json_safe(v) for v in value]
    return value


def main():
    out = P / 'output'
    assert not out.exists(), 'Preserve the first output; no overwrite or automatic retry.'
    out.mkdir()
    report = dict(status='preparing', baseline=BASELINE, commands=[], warpExecuted=False,
        scope='Seven fixed inputs, two real caller prefixes, actual baseline/current sampler and Matched helper. D3D12 WARP; no Unity, transport hits, area-light contribution, physical integration or distribution claim.',
        adaptation=['Emissive StructuredBuffer becomes a fixed 3-record thread-local array; two proposal records come from the 176-byte input.',
                    'Actual record header and sampler/helper bodies are extracted unchanged except resource storage declarations.',
                    'Actual screen/cache sample-Matched-finite prefixes have locals hoisted and observation assignments inserted; break and arithmetic remain.',
                    'PI/TWO_PI use the normal Unity decimal definitions; existing host binds only input/output/count.',
                    'Positive-infinite CDF interval is deliberately outside builder-produced data, testing actual nonfinite-PDF rejection, not supported scene content.'],
        equality='RNG and caller/Matched decisions exact. Direction and accepted final weight bit-exact except NaN payloads may differ when both are NaN. Rejected/unconsumed final weight and preweight are recorded only; no numeric tolerance.',
        rows=[])

    def save():
        (out / 'result.json').write_text(json.dumps(json_safe(report), indent=2, allow_nan=False), encoding='utf-8')

    def command(name, args):
        args = list(map(str, args))
        result = subprocess.run(args, cwd=ROOT, capture_output=True, timeout=300)
        (out / (name + '.log')).write_bytes(result.stdout + result.stderr)
        report['commands'].append(dict(name=name, arguments=args, exitCode=result.returncode))
        save()
        assert result.returncode == 0, name + ' failed; original log retained, no automatic retry'
        return result.stdout

    rows = [row('area-off-emissive-off', 0, 0), row('area-on-emissive-off', 1, 0),
            row('area-off-emissive-on', 0, .5), row('area-on-emissive-on', 1, .5),
            row('area-off-nonfinite-normal', 0, 0, bad_normal=True),
            row('area-on-nonfinite-normal', 1, 0, bad_normal=True),
            row('area-on-positive-infinite-cdf', 1, .5, infinite_cdf=True)]
    report['inputRows'] = rows
    save()
    try:
        host = Path(json.loads(HOST_RECEIPT.read_text())['files']['exe']['path'])
        assert host.is_file() and DXC.is_file(), 'Existing host/compiler required; no installation/build'
        report['existingHost'] = str(host)
        (out / 'inputs.bin').write_bytes(struct.pack('<I', len(rows)) + b''.join(struct.pack('<44f', *r['values']) for r in rows))
        for variant in ('baseline', 'candidate'):
            folder = out / variant
            folder.mkdir()
            sources = {}
            for filename in FILES:
                data = command('read-baseline-' + filename, ['git', 'show', BASELINE + ':' + GPU_REL + filename]) if variant == 'baseline' else (GPU / filename).read_bytes()
                sources[filename] = data.decode('utf-8-sig').replace('\r\n', '\n')
            transport, kernels, sampler, records = (sources[n] for n in FILES)
            sample_function = function(sampler, 'HLGISampleTransportDirection')
            signature = sample_function[:sample_function.index('{')]
            assert ('evaluateWeight' in signature) == (variant == 'candidate'), 'Unexpected sampler API'
            if variant == 'candidate':
                assert 'boolevaluateWeight=true' in re.sub(r'\s+', '', signature), 'Expected optional evaluateWeight=true'
                assert 'if(emissive<=0) return HLGISampleDirection(normal,guide,rng,weight);' in sampler
            helpers = '\n\n'.join(function(transport, name) for name in ('HLGIHash', 'Random', 'CosineHemisphere', 'HLGISampleDirection'))
            (folder / 'ActualTransportHelpers.hlsl').write_text(helpers, encoding='utf-8')
            (folder / 'HybridLumenGIEmissiveRecords.hlsl').write_text(records, encoding='utf-8')
            declaration = 'StructuredBuffer<HLGIEmissiveRecord> _HLGI_EmissiveProposals;'
            assert sampler.count(declaration) == 1 and sampler.count('float _HLGI_EmissiveWeight;') == 1
            adapted = sampler.replace(declaration, 'static HLGIEmissiveRecord _HLGI_EmissiveProposals[3];').replace('float _HLGI_EmissiveWeight;', 'static float _HLGI_EmissiveWeight;')
            (folder / 'ActualEmissiveSampling.hlsl').write_text(adapted, encoding='utf-8')
            (folder / 'ActualMatchedWeight.hlsl').write_text(function(transport, 'HLGIAreaMatchedDirectionWeight'), encoding='utf-8')
            wrappers = []
            for screen, source in ((True, kernels), (False, transport)):
                prefix = caller(source, screen)
                assert ('_HLGI_AreaEmitterCount<=0' in re.sub(r'\s+', '', prefix)) == (variant == 'candidate'), 'Actual production caller flag absent/different'
                (folder / ('ActualScreenPrefix.txt' if screen else 'ActualCachePrefix.txt')).write_text(prefix, encoding='utf-8')
                wrappers.append(instrument_caller(prefix, screen))
            (folder / 'ActualCallers.hlsl').write_text('\n'.join(wrappers), encoding='utf-8')
            command('compile-' + variant, [DXC, '-HV', '2018', '-T', 'cs_6_0', '-E', 'CSUnusedDirectionWeight', '-O3',
                    '-I', folder, '-Fo', out / (variant + '.dxil'), '-Fc', out / (variant + '.ll'), P / 'Adapters.hlsl'])
            ir = (out / (variant + '.ll')).read_text()
            assert re.search(r'Input.*?Size:\s+176', ir, re.S), variant + ' input ABI'
            assert re.search(r'Output.*?Size:\s+64', ir, re.S), variant + ' output ABI'
        buffers = {}
        for variant in ('baseline', 'candidate'):
            command('warp-' + variant, [host, out / (variant + '.dxil'), out / 'inputs.bin', out / (variant + '.bin')])
            buffers[variant] = (out / (variant + '.bin')).read_bytes()
            assert len(buffers[variant]) == len(rows) * 64, variant + ' output length'
        report['warpExecuted'] = True
        for i, definition in enumerate(rows):
            result = dict(name=definition['name'], callers={})
            for slot, name in enumerate(('screen', 'cache')):
                results = {}
                for variant in ('baseline', 'candidate'):
                    words = struct.unpack_from('<8I', buffers[variant], i * 64 + slot * 32)
                    floats = struct.unpack('<4f', struct.pack('<4I', *words[:4]))
                    results[variant] = dict(words=list(words), direction=list(floats[:3]), finalWeight=floats[3],
                        rng=words[4], accepted=bool(words[5]), matched=bool(words[6]),
                        preweight=struct.unpack('<f', struct.pack('<I', words[7]))[0])
                result['callers'][name] = results
            report['rows'].append(result)
        save()  # Preserve every original output before checking numeric/semantic expectations.
        for definition, result in zip(rows, report['rows']):
            for name, pair in result['callers'].items():
                a, b = pair['baseline'], pair['candidate']
                label = definition['name'] + '/' + name
                assert a['words'][4:7] == b['words'][4:7], label + ' RNG/rejection differs'
                for value in pair.values():
                    assert value['accepted'] == definition['expectedAccepted'], label + ' expected caller acceptance/rejection did not occur'
                    if definition['expectedMatched'] is not None:
                        assert value['matched'] == definition['expectedMatched'], label + ' expected nonfinite PDF rejection did not occur'
                for lane in range(3 + int(a['accepted'])):
                    af = struct.unpack('<f', struct.pack('<I', a['words'][lane]))[0]
                    bf = struct.unpack('<f', struct.pack('<I', b['words'][lane]))[0]
                    assert a['words'][lane] == b['words'][lane] or math.isnan(af) and math.isnan(bf), label + f' output lane {lane} differs'
        report['status'] = 'passed'
        report['summary'] = 'Direction, RNG, actual caller rejection and all consumed final weights preserved for the fixed inputs. Unconsumed weight words retained without asserting equality. No performance/distribution claim.'
    except Exception as error:
        report['status'] = 'failed'
        report['error'] = str(error)
        raise
    finally:
        save()
        print(json.dumps(dict(status=report['status'], result=str(out / 'result.json'), error=report.get('error'))))


if __name__ == '__main__':
    main()
