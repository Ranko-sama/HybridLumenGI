"""Release71 staging: accepted ordinary wiring plus an opt-in explicit render path.

No product deployment or native temporal rerun. Only build/run.ps1 launch Unity.
"""
import importlib.util
import json
import subprocess
import sys
from pathlib import Path

P = Path(__file__).resolve().parent
ROOT = P.parents[2]
PROJECT = Path('I:/Unity test/Project')
BUILD = Path('I:/Unity test/Comparison/Builds/LocalRelease71')
OUT = P / 'instrumentation'
PRIOR = P.parent / 'continuous-deformation-usage-01/build-correction'
CURRENT = P.parent / 'current-color-dynamics-integration-01'


def module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    value = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(value)
    return value


base = module('release71_assets', P.parent / 'current-local-release-67/prepare67.py')
base.P, base.OUT, base.BUILD = P, OUT, BUILD
for installer in (base.base, base.base.base):
    installer.PACKAGE, installer.OUT = P, OUT
sha, load, save = base.sha, base.load, base.save


def prepare():
    assert not OUT.exists() and not BUILD.exists(), 'Fresh staging and Release output required'
    m = load(PRIOR / 'instrumentation/manifest.json')
    current = load(CURRENT / 'instrumentation/manifest.json')
    assert load(CURRENT / 'build-analysis.json')['currentSourceBuildVerified']
    assert load(CURRENT / 'instrumentation/restoration.json')['currentProductRestored']
    m['baseline'], m['productSourceSha256'] = current['baseline'], current['productSourceSha256']
    m.pop('correction', None)
    product = {path.relative_to(ROOT).as_posix(): sha(path)
               for top in ('Runtime', 'Editor') for path in (ROOT / top).rglob('*')
               if path.is_file() and path.suffix != '.meta'}
    assert product == m['productSourceSha256'] and len(product) == 112
    assert all(sha(PROJECT / 'Assets/HybridLumenGI' / rel) == value for rel, value in product.items())
    for row in m['files']:
        target = PROJECT / row['path']
        assert (sha(target) if target.is_file() else None) == row['originalSha256']
        assert sha(PRIOR / 'instrumentation' / row['prepared']) == row['sha256']
    for rel in m['newMetadata']:
        assert not (PROJECT / rel).exists()
    for row in m['excluded']:
        assert sha(PROJECT / row['path']) == row['sha256']
    state = load(CURRENT / 'asset-state.json')
    for row in state['files']:
        target = PROJECT / row['path']
        assert target.exists() == row['existsBefore']
        if target.exists():
            assert sha(target) == row['sha256Before']
    # All original/owned boundaries are checked before creating this staging.
    OUT.mkdir()
    for row in m['files']:
        staged = OUT / row['prepared']
        staged.parent.mkdir(parents=True, exist_ok=True)
        data = (PRIOR / 'instrumentation' / row['prepared']).read_bytes()
        if row['path'].endswith('/LocalReleaseBootstrap.cs'):
            data = (P / 'source/LocalReleaseBootstrap.cs').read_bytes()
        elif row['path'].endswith('/Editor/CurrentPlayerBuild.cs'):
            old = (PRIOR / 'cube-setup-receipt.json').as_posix().encode()
            assert data.count(old) == 1
            data = data.replace(old, (P / 'cube-setup-receipt.json').as_posix().encode())
        staged.write_bytes(data)
        row['sha256'] = sha(staged)
        if row['original']:
            backup = OUT / row['original']
            backup.parent.mkdir(parents=True, exist_ok=True)
            backup.write_bytes((PROJECT / row['path']).read_bytes())
    for row in m['excluded']:
        (OUT / row['original']).write_bytes((PROJECT / row['path']).read_bytes())
    for row in state['files']:
        if row['existsBefore']:
            (P / row['backup']).write_bytes((PROJECT / row['path']).read_bytes())
    m['scope'] = 'Current112 product sources; unchanged69 ordinary default; opt-in batch Final120 StandardRequest; no native temporal rerun'
    m['release71Source'] = dict(path='source/LocalReleaseBootstrap.cs', sha256=sha(P / 'source/LocalReleaseBootstrap.cs'))
    m['sourcePreparationCommit'] = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    save(OUT / 'manifest.json', m)
    save(P / 'asset-state.json', state)
    print(json.dumps(dict(stagedFiles=len(m['files']), productFiles=len(product), baseline=m['baseline'])))


def preflight():
    check = module('release71_preflight', P.parent / 'current-local-release-67/preflight67.py')
    check.PACKAGE, check.STAGE, check.DEST = P, OUT, P / 'preflight'
    check.main()


def analyze(action):
    check = module('release71_analysis', P.parent / 'current-local-release-67/analyze67.py')
    check.PACKAGE, check.BUILD = P, BUILD
    raise SystemExit(check.main(action))


def launcher():
    assert load(P / 'build-report.json')['result'] == 'Succeeded'
    assert not (BUILD / 'Start-LocalRelease.cmd').exists()
    for name in ('Start-LocalRelease.cmd', 'LocalRelease-README.txt'):
        data = (ROOT / 'LocalComparison/Harness' / name).read_text(encoding='utf-8')
        if name.endswith('.txt'):
            data = data.replace('LocalRelease69', 'LocalRelease71').replace('产品源码50b63c3', '产品源码269241b')
            data += '\n本次整合：LocalComparison/Review/current-local-release-71。\n'
            data += '有限后台验证仅用 -batchmode -localReleaseFinalImage120 -localReleaseExplicitRequest；默认启动仍为普通交互，不据此宣称 OS 按键或普通自动渲染已复验。\n'
        (BUILD / name).write_text(data, encoding='utf-8')


if __name__ == '__main__':
    action = sys.argv[1]
    if action in ('install', 'restore'):
        getattr(base, action)()
    elif action in ('build', 'products'):
        analyze(action)
    else:
        assert action in ('prepare', 'preflight', 'launcher')
        globals()[action]()
