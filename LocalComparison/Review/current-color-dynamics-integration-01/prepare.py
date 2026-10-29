"""Reuse the accepted ordinary Release wiring with current product sources.
The native temporal contract runs before the same-process Release build.
"""
import importlib.util
import json
import subprocess
import sys
from pathlib import Path

P = Path(__file__).resolve().parent
ROOT = P.parents[2]
PROJECT = Path('I:/Unity test/Project')
BUILD = Path('I:/Unity test/Comparison/Builds/LocalRelease70')
OUT = P / 'instrumentation'
PRIOR = P.parent / 'continuous-deformation-usage-01/build-correction'


def module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


base = module('release70_assets', P.parent / 'current-local-release-67/prepare67.py')
base.P = P
base.OUT = OUT
base.BUILD = BUILD
for installer in (base.base, base.base.base):
    installer.PACKAGE = P
    installer.OUT = OUT
sha, load, save = base.sha, base.load, base.save


def deploy():
    destination = P / 'deployment'
    assert not destination.exists(), 'Preserve prior deployment evidence'
    previous = load(PRIOR / 'instrumentation/manifest.json')['productSourceSha256']
    current = {p.relative_to(ROOT).as_posix(): sha(p)
               for top in ('Runtime', 'Editor') for p in (ROOT / top).rglob('*')
               if p.is_file() and p.suffix != '.meta'}
    assert set(previous) == set(current)
    assert all(sha(PROJECT / 'Assets/HybridLumenGI' / rel) == value for rel, value in previous.items())
    changed = [rel for rel in current if current[rel] != previous[rel]]
    assert set(changed) == {'Runtime/Resources/HybridLumenGI/HybridLumenGITransport.hlsl',
                            'Runtime/Resources/HybridLumenGI/HybridLumenGIKernels.hlsl'}
    destination.mkdir()
    for rel in changed:
        backup = destination / 'original' / rel
        backup.parent.mkdir(parents=True, exist_ok=True)
        backup.write_bytes((PROJECT / 'Assets/HybridLumenGI' / rel).read_bytes())
    save(destination / 'manifest.json', dict(previous=load(PRIOR / 'instrumentation/manifest.json')['baseline'],
         current=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
         before=previous, after=current, changed=changed))
    for rel in changed:
        (PROJECT / 'Assets/HybridLumenGI' / rel).write_bytes((ROOT / rel).read_bytes())
    assert all(sha(PROJECT / 'Assets/HybridLumenGI' / rel) == value for rel, value in current.items())
    print(json.dumps(dict(productFiles=len(current), deployed=changed)))


def prepare():
    assert not OUT.exists() and not BUILD.exists(), 'Fresh staging and Release output required'
    m = load(PRIOR / 'instrumentation/manifest.json')
    deployment = load(P / 'deployment/manifest.json')
    m['baseline'] = deployment['current']
    m['productSourceSha256'] = deployment['after']
    m.pop('correction', None)
    assert all(sha(ROOT / rel) == value and sha(PROJECT / 'Assets/HybridLumenGI' / rel) == value
               for rel, value in m['productSourceSha256'].items())
    # Current project must still be the restored input of the previous build.
    for row in m['files']:
        target = PROJECT / row['path']
        assert (sha(target) if target.is_file() else None) == row['originalSha256']
        assert sha(PRIOR / 'instrumentation' / row['prepared']) == row['sha256']
    for rel in m['newMetadata']:
        assert not (PROJECT / rel).exists()
    OUT.mkdir()
    for row in m['files']:
        staged = OUT / row['prepared']
        staged.parent.mkdir(parents=True, exist_ok=True)
        data = (PRIOR / 'instrumentation' / row['prepared']).read_bytes()
        if row['path'].endswith('/Editor/CurrentPlayerBuild.cs'):
            old = (PRIOR / 'cube-setup-receipt.json').as_posix().encode()
            assert data.count(old) == 1
            data = data.replace(old, (P / 'cube-setup-receipt.json').as_posix().encode())
        staged.write_bytes(data)
        row['sha256'] = sha(staged)
        if row['original']:
            (OUT / row['original']).write_bytes((PROJECT / row['path']).read_bytes())
    for row in m['excluded']:
        assert sha(PROJECT / row['path']) == row['sha256']
        (OUT / row['original']).write_bytes((PROJECT / row['path']).read_bytes())
    native_sources = {
        'Assets/ComparisonHarness/Editor/DenoiseRegressionEditor.cs':
            ROOT / 'LocalComparison/Harness/DenoiseRegressionEditor.cs',
        'Assets/ComparisonHarness/Editor/DenoiseRegressionEditor.ReactiveHistoryLimit.cs':
            ROOT / 'LocalComparison/Harness/DenoiseRegressionEditor.ReactiveHistoryLimit.cs',
        'Assets/ComparisonHarness/Editor/ColorDynamicsBuild.cs': P / 'ColorDynamicsBuild.cs',
    }
    for rel, source in native_sources.items():
        target = PROJECT / rel
        assert source.is_file()
        original = original_hash = None
        if rel.endswith('/DenoiseRegressionEditor.cs'):
            original_hash = '7749e6b95d880da42e02336d0208979db876b08d1851464b3e97f4def67d039f'
            assert sha(target) == original_hash
            original = 'original/' + rel
            backup = OUT / original
            backup.parent.mkdir(parents=True, exist_ok=True)
            backup.write_bytes(target.read_bytes())
        else:
            assert not target.exists() and not Path(str(target) + '.meta').exists()
        staged = OUT / 'prepared' / rel
        staged.parent.mkdir(parents=True, exist_ok=True)
        staged.write_bytes(source.read_bytes())
        m['files'].append(dict(path=rel, original=original, originalSha256=original_hash,
                              prepared='prepared/' + rel, sha256=sha(staged)))
        if original is None:
            m['newMetadata'].append(rel + '.meta')
    m['scope'] = 'Current269241b product, unchanged69 ordinary example and Cube; real-texture temporal contract then Release70 build in one Unity invocation'
    save(OUT / 'manifest.json', m)
    state = load(PRIOR / 'asset-state.json')
    for row in state['files']:
        target = PROJECT / row['path']
        assert target.exists() == row['existsBefore']
        if target.exists():
            assert sha(target) == row['sha256Before']
            (P / row['backup']).write_bytes(target.read_bytes())
    save(P / 'asset-state.json', state)
    print(json.dumps(dict(stagedFiles=len(m['files']), baseline=m['baseline'])))


def preflight():
    check = module('release70_preflight', P.parent / 'current-local-release-67/preflight67.py')
    check.PACKAGE, check.STAGE, check.DEST = P, OUT, P / 'preflight'
    check.main()


def analyze(action):
    check = module('release70_analysis', P.parent / 'current-local-release-67/analyze67.py')
    check.PACKAGE, check.BUILD = P, BUILD
    raise SystemExit(check.main(action))


def launcher():
    assert load(P / 'build-report.json')['result'] == 'Succeeded'
    assert not (BUILD / 'Start-LocalRelease.cmd').exists()
    for name in ('Start-LocalRelease.cmd', 'LocalRelease-README.txt'):
        data = (ROOT / 'LocalComparison/Harness' / name).read_text(encoding='utf-8')
        if name.endswith('.txt'):
            data = data.replace('LocalRelease69', 'LocalRelease70').replace('产品源码50b63c3', '产品源码269241b')
            data += '\n本次整合记录：LocalComparison/Review/current-color-dynamics-integration-01。\n'
        (BUILD / name).write_text(data, encoding='utf-8')


if __name__ == '__main__':
    action = sys.argv[1]
    if action in ('install', 'restore'):
        getattr(base, action)()
    elif action in ('build', 'products', 'run'):
        analyze(action)
    else:
        assert action in ('deploy', 'prepare', 'preflight', 'launcher')
        globals()[action]()
