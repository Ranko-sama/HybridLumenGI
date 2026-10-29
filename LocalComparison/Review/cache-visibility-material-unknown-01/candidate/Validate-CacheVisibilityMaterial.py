"""Paired current-source cache connectivity check on the existing source-matched WARP host.
Run baseline before changing Transport, then candidate. No Unity or physical GPU.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import struct
import subprocess

ROOT = Path(__file__).resolve().parents[1]
SHADERS = ROOT / 'Runtime/Resources/HybridLumenGI'
TEMPLATE = ROOT / 'Tests/StandaloneRadianceValidity'
OUT = ROOT / 'LocalComparison/Review/cache-visibility-material-unknown-01'
DXC = Path('C:/Program Files (x86)/Windows Kits/10/bin/10.0.26100.0/x64/dxc.exe')
CASES = [
    ('clear', 0, 1, 0),
    ('known-right-occluder', 1, 1, 0),
    ('unknown-first-tap', 2, 0, 0),
    ('unknown-after-red-tap', 2, 1, 0),
    ('unresolved-after-red-tap', 3, 1, 0),
    ('zero-weight-unknown-tap', 2, 1, 1),
    ('all-unknown', 2, 2, 0),
    ('all-known-occluded', 1, 2, 0),
]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def save(path, data):
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False), encoding='utf-8')


def extract(text, names):
    result = []
    counts = {name: 0 for name in names}
    for match in re.finditer(r'^(?:bool|float3|void|HLGIRayFootprint) (' + '|'.join(names) + r')\(', text, re.M):
        depth = 0
        for end in range(text.index('{', match.start()), len(text)):
            if text[end] == '{':
                depth += 1
            elif text[end] == '}':
                depth -= 1
                if depth == 0:
                    result.append(text[match.start():end + 1])
                    counts[match.group(1)] += 1
                    break
        else:
            raise RuntimeError('Unterminated production function')
    assert all(counts.values()), counts
    return '\n\n'.join(result) + '\n'


def main(stage):
    folder = OUT / stage
    folder.mkdir(parents=True, exist_ok=False)
    sources = [SHADERS / ('HybridLumenGI' + name + '.hlsl') for name in
               ('Transport', 'ExactMesh', 'Hit', 'RayFootprint', 'RadianceValidity')]
    sources += [TEMPLATE / 'CacheVisibilityMaterialHarness.hlsl',
                TEMPLATE / 'RadianceValidityWarp.cpp.txt', TEMPLATE / 'CMakeLists.txt', Path(__file__)]
    for source in sources:
        (folder / source.name).write_bytes(source.read_bytes())
    save(folder / 'sources.json', {str(p.relative_to(ROOT)): sha(p) for p in sources})
    transport = (folder / 'HybridLumenGITransport.hlsl').read_text(encoding='utf-8-sig')
    exact = (folder / 'HybridLumenGIExactMesh.hlsl').read_text(encoding='utf-8-sig')
    (folder / 'ActualCacheConsumers.hlsl').write_text(extract(transport, [
        'HLGIPointQueryFootprint', 'HLGIHitOwnerCurrent', 'HLGICachedSurface',
        'HLGICachedSample', 'CachedIrradiance', 'ProxyRadiance']), encoding='utf-8')
    (folder / 'ActualCommittedMaterial.hlsl').write_text(
        extract(exact, ['HLGIHardwareResolveCommittedMaterial']), encoding='utf-8')
    raw_inputs = struct.pack('<I', len(CASES)) + b''.join(
        struct.pack('<4I', kind, side, zero_weight, 0) + bytes(192)
        for _, kind, side, zero_weight in CASES)
    (folder / 'inputs.bin').write_bytes(raw_inputs)
    save(folder / 'cases.json', CASES)
    save(folder / 'contract.json', {
        'scope': 'Actual cache interpolation, known-state wrappers, ProxyRadiance and committed coverage classification. Explicit card/normal/scene/bridge/direct-light adapters; not Unity, traversal, physical GPU, images or performance.',
        'independentExpectation': 'Unknown connectivity with positive weight cannot yield a known interpolation. Clear red/blue taps of equal weight average to (2,0,1); proven right occlusion retains red (4,0,0). Zero-weight taps are irrelevant. Unknown invalidates the entire output, including an earlier accumulated red tap.',
        'tolerance': 0,
        'arithmetic': 'Representable binary fractions; controls and full zero structures require exact bytes.',
    })
    if stage == 'candidate':
        baseline = OUT / 'baseline'
        assert json.loads((baseline / 'analysis.json').read_text())['counterexampleEstablished']
        assert raw_inputs == (baseline / 'inputs.bin').read_bytes()
        for source in sources:
            if source.name != 'HybridLumenGITransport.hlsl':
                assert (folder / source.name).read_bytes() == (baseline / source.name).read_bytes(), source.name

    hosts = []
    for path in Path(os.environ['TEMP']).glob('hlgi-radiance-validity-warp-*'):
        exe = path / 'build/Release/RadianceValidityWarp.exe'
        cpp = path / 'source/RadianceValidityWarp.cpp'
        cmake = path / 'source/CMakeLists.txt'
        if exe.is_file() and cpp.is_file() and cmake.is_file() and \
                sha(cpp) == sha(TEMPLATE / 'RadianceValidityWarp.cpp.txt') and sha(cmake) == sha(TEMPLATE / 'CMakeLists.txt'):
            hosts.append(exe)
    assert hosts, 'Existing source-matched WARP host required'
    exe = sorted(hosts, key=lambda path: path.stat().st_mtime)[-1]
    commands = []

    def invoke(name, args):
        args = list(map(str, args))
        result = subprocess.run(args, capture_output=True, text=True)
        (folder / (name + '.log')).write_text(result.stdout + result.stderr, encoding='utf-8')
        commands.append(dict(name=name, arguments=args, exitCode=result.returncode))
        save(folder / 'commands.json', commands)
        assert result.returncode == 0, (name, result.returncode, result.stderr)

    invoke('compile', [DXC, '-HV', '2018', '-T', 'cs_6_0', '-E', 'CSCacheVisibilityMaterial',
                       '-I', folder, '-Fo', folder / 'test.dxil', folder / 'CacheVisibilityMaterialHarness.hlsl'])
    invoke('warp', [exe, folder / 'test.dxil', folder / 'inputs.bin', folder / 'outputs.bin'])
    raw = (folder / 'outputs.bin').read_bytes()
    assert len(raw) == 368 * len(CASES)
    prior = (OUT / 'baseline/outputs.bin').read_bytes() if stage == 'candidate' else raw
    rows, failures = [], []
    for index, (name, kind, side, zero_weight) in enumerate(CASES):
        values = struct.unpack_from('<92f', raw, index * 368)
        unknown = kind == 3 or (stage == 'candidate' and kind == 2 and not zero_weight)
        color = (0, 0, 0) if unknown or side == 2 else (4, 0, 0) if zero_weight or kind != 0 and side == 1 else (0, 0, 2) if kind != 0 else (2, 0, 1)
        accepted = not unknown and (color != (0, 0, 0))
        query_count = 1 if zero_weight or unknown and side in (0, 2) else 2 if unknown else 4
        flags = 2048 if kind == 3 else 512 if kind == 2 and not zero_weight else 0
        proxy = (0, 0, 0, 0) if unknown else tuple(e + .5 * (d + c) for e, d, c in zip((.125,.25,.5),(.25,.5,.75),color)) + (1,)
        expected_cache = color + (1 if accepted else 0,)
        checks = dict(
            status=values[:4] == (int(accepted), int(not unknown), query_count, flags),
            cache=values[4:8] == expected_cache,
            fullZeroOnUnknown=not unknown or all(value == 0 for value in values[4:24]),
            cachedConsumer=values[24:28] == color + (int(not unknown),),
            proxyConsumer=values[28:32] == proxy,
            unchangedControl=stage == 'baseline' or kind == 2 and not zero_weight or raw[index*368:(index+1)*368] == prior[index*368:(index+1)*368],
        )
        rows.append(dict(case=name, checks=checks, status=values[:4], cache=values[4:8], cached=values[24:28], proxy=values[28:32], expectedProxy=proxy))
        if not all(checks.values()):
            failures.append(name)
    analysis = dict(stage=stage, passed=not failures, counterexampleEstablished=stage == 'baseline' and not failures,
                    rows=rows, failures=failures, host=str(exe), hostSha256=sha(exe), dxcSha256=sha(DXC),
                    inputSha256=sha(folder/'inputs.bin'), outputSha256=sha(folder/'outputs.bin'),
                    sourceSha256=sha(folder/'HybridLumenGITransport.hlsl'), unityExecuted=False, physicalGpuExecuted=False)
    save(folder / 'analysis.json', analysis)
    assert not failures, failures
    print(json.dumps({key: value for key, value in analysis.items() if key != 'rows'}))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('stage', choices=['baseline', 'candidate'])
    main(parser.parse_args().stage)
