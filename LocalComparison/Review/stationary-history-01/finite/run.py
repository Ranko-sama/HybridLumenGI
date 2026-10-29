"""One finite paired actual-temporal execution; existing host, no hashing or Unity."""
import json, math, re, struct, subprocess
from pathlib import Path

P = Path(__file__).resolve().parent
ROOT = P.parents[3]
GPU = ROOT / 'Runtime/Resources/HybridLumenGI'
DXC = Path('C:/Program Files (x86)/Windows Kits/10/bin/10.0.26100.0/x64/dxc.exe')
HOST_RECEIPT = ROOT / 'LocalComparison/Review/parallel-color-dynamics-01/temporal/host-reuse.json'

def function(source, name):
    start = re.search(r'^(?:float[234]?|bool|void) ' + name + r'\(', source, re.M).start()
    opening = source.index('{', start); end = opening + 1; depth = 1
    while depth:
        depth += (source[end] == '{') - (source[end] == '}'); end += 1
    return source[start:end]

def extract(source):
    source = source.replace('\r\n', '\n')
    start = source.index('bool HLGITemporalTapMatches(')
    end = source.index('[numthreads(8,8,1)]\nvoid CSFilter(', start)
    body = source[start:end]
    assert body.count('[numthreads(8,8,1)]\n') == 1
    body = body.replace('[numthreads(8,8,1)]\n', '')
    assert body.count('_HLGI_Output[pixel]') == body.count('_HLGI_MomentsOut[pixel]') == 6
    body = body.replace('_HLGI_Output[pixel]', 'adapterOutput').replace('_HLGI_MomentsOut[pixel]', 'adapterMoments')
    return '\n\n'.join(function(source, n) for n in ('WorldPosition', 'ProjectUV', 'LuminanceGI')) + '\n\n' + body

def half_rtz(value):
    """Independent positive binary16 storage model, not readback-derived."""
    value = max(0.0, value)
    bits = struct.unpack('<H', struct.pack('<e', value))[0]
    result = struct.unpack('<e', struct.pack('<H', bits))[0]
    if result > value: bits -= 1
    return struct.unpack('<e', struct.pack('<H', bits))[0]

def row(name, *, local=0, hard=0, global_change=0, has_motion=0,
        motion=0, camera=0, previous_depth=.5, current=0, unknown=False, age=32):
    values = [1, 1, 1, 1, 1, 1, age, 0,
              current, current, current, -1 if unknown else 1, 0, 0, 0, 0,
              local, hard, global_change, has_motion,
              motion, 0, camera, previous_depth, 1, 32, .08, 0] + [0] * 16
    assert len(values) == 44
    return dict(name=name, values=values)

def main():
    out = P / 'output'
    assert not out.exists(), 'Preserve the first output; do not rerun successful or numerical-failed GPU data.'
    out.mkdir()
    report = dict(status='running', commands=[], controls=[], sequence=[],
        scope='Actual HEAD/current temporal bodies and current Runtime validity/sampling/receiver-motion helpers, legacy and identity. One 1x1 reliable +Z-plane resource/normal-decoding adapter. The same GPU thread consumes explicitly half-stored output and float32 moments for 32 calls; not separate frame dispatches, real textures, Unity, physical GPU or visual convergence.',
        adapters=['Fixed texture Load values and declared decoded +Z geometry', 'ComputeWorldSpacePosition homogeneous matrix reconstruction adapter',
                  'Explicit f32tof16/f16tof32 storage; no physical RGBA16F UAV', 'Fixed change-region and identity-object inputs'],
        thresholds={'rawArithmeticAbsolute': 2e-7, 'momentAbsolute': 2e-6, 'controlPair': 'all 64 bytes identical'},
        expectations={'stationaryFirst': {'baseline': .0368, 'candidate': .92},
            'unmarkedBlack': '32 continuous known-black updates preserve the existing .08 EMA and half storage; candidate residual is a deliberate dynamic cost, not unchanged response.',
            'identityRejectedMotion': 'motion=(2,0) at fullSize1 disagrees with poseUV by >1 texel. Identity keeps pose correspondence but must still clip; legacy rejects offscreen motionUV.'})
    def save(): (out / 'result.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
    def command(name, args):
        args = list(map(str, args))
        run = subprocess.run(args, cwd=ROOT, capture_output=True, timeout=300)
        (out / (name + '.log')).write_bytes(run.stdout + run.stderr)
        report['commands'].append(dict(name=name, arguments=args, exitCode=run.returncode)); save()
        assert run.returncode == 0, name + ' failed; see original log'
        return run.stdout
    sequence = row('unmarked-known-black')
    controls = [
        row('marked-global-light-off', local=1, global_change=1),
        row('local-reactive', local=1),
        row('camera-motion-with-velocity', has_motion=1, motion=.001, camera=.002),
        row('nonzero-velocity-rejected-by-identity-pose', has_motion=1, motion=2),
        row('disocclusion-depth-reject', previous_depth=.75, current=.25),
        row('current-unknown-global-local', unknown=True, local=1, global_change=1),
        row('immature-age31', age=31),
    ]
    rows = [sequence] * 32 + controls
    report['inputRows'] = [dict(index=i, name=('unmarked-black-step-' + str(i + 1)) if i < 32 else r['name'], values=r['values']) for i, r in enumerate(rows)]
    report['sourceFiles'] = [str(GPU / name) for name in ('HybridLumenGIKernels.hlsl', 'HybridLumenGIRadianceValidity.hlsl', 'HybridLumenGIScreenSampling.hlsl', 'HybridLumenGIReceiverTemporal.hlsl', 'HybridLumenGIReceiverIdentity.hlsl')]
    save()
    try:
        host = Path(json.loads(HOST_RECEIPT.read_text())['files']['exe']['path'])
        assert host.is_file() and DXC.is_file(), 'Existing host/compiler is required; no installation/build.'
        report['existingHost'] = str(host)
        baseline = command('read-head', ['git', 'show', 'HEAD:Runtime/Resources/HybridLumenGI/HybridLumenGIKernels.hlsl']).decode('utf-8-sig')
        candidate = (GPU / 'HybridLumenGIKernels.hlsl').read_text(encoding='utf-8-sig')
        assert 'bool stationaryHistory=' not in baseline and 'bool stationaryHistory=' in candidate
        assert 'all(_HLGI_Motion.Load(int3(fullPixel,0))==0)' in candidate
        (out / 'inputs.bin').write_bytes(struct.pack('<I', len(rows)) + b''.join(struct.pack('<44f', *r['values']) for r in rows))
        for variant, source in (('baseline', baseline), ('candidate', candidate)):
            folder = out / variant; folder.mkdir()
            (folder / 'ActualTemporalBody.hlsl').write_text(extract(source), encoding='utf-8')
            for mode in ('legacy', 'identity'):
                label = variant + '-' + mode
                args = [DXC, '-HV', '2018', '-T', 'cs_6_0', '-E', 'CSStationaryHistory', '-O3', '-I', folder, '-I', GPU,
                        '-Fo', out / (label + '.dxil'), '-Fc', out / (label + '.ll')]
                if mode == 'identity': args += ['-D', 'HLGI_RECEIVER_IDENTITY=1']
                command('compile-' + label, args + [P / 'Adapters.hlsl'])
                assembly = (out / (label + '.ll')).read_text()
                assert re.search(r'Input.*?Size:\s+176', assembly, re.S), label + ' input ABI'
                assert re.search(r'Output.*?Size:\s+64', assembly, re.S), label + ' output ABI'
        buffers = {}
        for variant in ('baseline', 'candidate'):
            for mode in ('legacy', 'identity'):
                label = variant + '-' + mode
                command('warp-' + label, [host, out / (label + '.dxil'), out / 'inputs.bin', out / (label + '.bin')])
                data = (out / (label + '.bin')).read_bytes(); assert len(data) == len(rows) * 64
                buffers[variant, mode] = data
        report['warpExecuted'] = True
        def unpack(variant, mode, index):
            values = struct.unpack_from('<16f', buffers[variant, mode], index * 64)
            assert all(map(math.isfinite, values)), 'Nonfinite output'
            return list(values)
        # Freeze all original readbacks in the report before applying assertions.
        for i in range(32):
            report['sequence'].append(dict(step=i + 1, **{v + '-' + m: unpack(v, m, i) for v in ('baseline', 'candidate') for m in ('legacy', 'identity')}))
        for i, control in enumerate(controls, 32):
            report['controls'].append(dict(name=control['name'], **{v + '-' + m: unpack(v, m, i) for v in ('baseline', 'candidate') for m in ('legacy', 'identity')}))
        save()
        # Sufficient arithmetic/storage bounds are derived from black current,
        # fixed EMA .08 and the independent half truncation model, never RGB data.
        for variant in ('baseline', 'candidate'):
            low = high = 1.0
            for i in range(32):
                if variant == 'baseline': low, high = min(low, .04), min(high, .04)
                next_low, next_high = max(0, low * .92 - 2e-7), high * .92 + 2e-7
                stored_low, stored_high = half_rtz(next_low), half_rtz(next_high)
                for mode in ('legacy', 'identity'):
                    values = unpack(variant, mode, i)
                    assert all(next_low <= x <= next_high for x in values[:3]), f'{variant}/{mode}/step{i+1} raw EMA'
                    assert all(stored_low <= x <= stored_high for x in values[8:11]), f'{variant}/{mode}/step{i+1} stored EMA'
                    assert values[3] == values[11] == 1 and values[6] == values[14] == 32
                    assert values[7] == values[15] == 0
                    assert all(abs(values[lane] - .92 ** (i + 1)) <= 2e-6 for lane in (4, 5, 12, 13))
                low, high = stored_low, stored_high
        expected_raw = [0, .02, .0368, None, .25, 1, .0368]
        expected_age = [1, 2, 32, None, 1, 2, 32]
        for n, control in enumerate(controls):
            i = n + 32
            for mode in ('legacy', 'identity'):
                a = buffers['baseline', mode][i*64:(i+1)*64]
                b = buffers['candidate', mode][i*64:(i+1)*64]
                assert a == b, control['name'] + '/' + mode + ' changed actual consumer bytes'
                values = unpack('candidate', mode, i)
                value = expected_raw[n] if n != 3 else (.0368 if mode == 'identity' else 0)
                age = expected_age[n] if n != 3 else (32 if mode == 'identity' else 1)
                assert all(abs(x-value) <= 2e-7 for x in values[:3]), control['name'] + '/' + mode + ' output'
                assert values[3] == values[11] == 1 and values[6] == values[14] == age
        assert buffers['baseline', 'legacy'][:32*64] == buffers['baseline', 'identity'][:32*64]
        assert buffers['candidate', 'legacy'][:32*64] == buffers['candidate', 'identity'][:32*64]
        report['summary'] = {
            'firstRaw': {v: unpack(v, 'legacy', 0)[0] for v in ('baseline', 'candidate')},
            'firstStored': {v: unpack(v, 'legacy', 0)[8] for v in ('baseline', 'candidate')},
            'unmarkedBlackStep32Stored': {v: unpack(v, 'legacy', 31)[8] for v in ('baseline', 'candidate')},
            'preservedControls': [x['name'] for x in controls],
            'dynamicTradeoff': 'Unmarked real lighting removal is intentionally slower: candidate retains the existing EMA instead of clipping mature exact-static history. This finite result is not a general no-ghosting or convergence claim.'}
        report['status'] = 'passed'
    except Exception as error:
        report['status'] = 'failed'; report['error'] = str(error)
        raise
    finally:
        save()
        print(json.dumps({'status': report['status'], 'result': str(out / 'result.json'), 'summary': report.get('summary'), 'error': report.get('error')}))

if __name__ == '__main__': main()
