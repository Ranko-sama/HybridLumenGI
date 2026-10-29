"""Release73: identity transform fix with byte-identical Release72 runtime wiring."""
import copy
import importlib.util
import json
import subprocess
import sys
from pathlib import Path

P = Path(__file__).resolve().parent
ROOT = P.parents[2]
PROJECT = Path('I:/Unity test/Project')
BUILD = Path('I:/Unity test/Comparison/Builds/LocalRelease73')
OUT = P / 'instrumentation'
PRIOR = P.parent / 'current-local-release-72'
PRODUCT_COMMIT = '95a3213aedef41ac6a021c0723e73343abffd748'


def module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    value = importlib.util.module_from_spec(spec); spec.loader.exec_module(value)
    return value


base = module('release73_assets', P.parent / 'current-local-release-67/prepare67.py')
base.P, base.OUT, base.BUILD = P, OUT, BUILD
for installer in (base.base, base.base.base):
    installer.PACKAGE, installer.OUT = P, OUT
sha, load, save = base.sha, base.load, base.save


def prepare():
    assert not OUT.exists() and not BUILD.exists(), 'Fresh preparation and output required'
    old = load(PRIOR / 'instrumentation/manifest.json')
    m = copy.deepcopy(old)
    product = {path.relative_to(ROOT).as_posix(): sha(path) for top in ('Runtime', 'Editor')
               for path in (ROOT / top).rglob('*') if path.is_file() and path.suffix != '.meta'}
    regression = P.parent / 'camera-motion-taa-response-03'
    assert load(regression / 'analysis-first.json')['passed']
    assert load(regression / 'execution-receipt.json')['passed']
    assert load(regression / 'product-deployment.json')['sourceCommit'] == PRODUCT_COMMIT
    assert product == load(regression / 'instrumentation/manifest.json')['productSourceSha256'] and len(product) == 112
    assert {key for key in product if product[key] != old['productSourceSha256'][key]} == {
        'Runtime/HybridLumenGIReceiverIdentityPass.cs',
        'Runtime/Resources/HybridLumenGI/HybridLumenGIReceiverIdentity.shader'}
    assert all(sha(PROJECT / 'Assets/HybridLumenGI' / path) == value for path, value in product.items())
    for row in m['files']:
        target = PROJECT / row['path']
        assert (sha(target) if target.is_file() else None) == row['originalSha256']
        assert sha(PRIOR / 'instrumentation' / row['prepared']) == row['sha256']
    assert all(not (PROJECT / rel).exists() for rel in m['newMetadata'])
    assert all(sha(PROJECT / row['path']) == row['sha256'] for row in m['excluded'])
    state = load(PRIOR / 'asset-state.json')
    for row in state['files']:
        target = PROJECT / row['path']
        assert target.exists() == row['existsBefore']
        if target.exists():
            assert sha(target) == row['sha256Before']
    OUT.mkdir()
    for row in m['files']:
        data = (PRIOR / 'instrumentation' / row['prepared']).read_bytes()
        if row['path'].endswith('/Editor/CurrentPlayerBuild.cs'):
            old_receipt = (PRIOR / 'cube-setup-receipt.json').as_posix().encode()
            assert data.count(old_receipt) == 1
            data = data.replace(old_receipt, (P / 'cube-setup-receipt.json').as_posix().encode())
        staged = OUT / row['prepared']; staged.parent.mkdir(parents=True, exist_ok=True); staged.write_bytes(data)
        row['sha256'] = sha(staged)
        if row['original']:
            backup = OUT / row['original']; backup.parent.mkdir(parents=True, exist_ok=True)
            backup.write_bytes((PROJECT / row['path']).read_bytes())
    for row in m['excluded']:
        (OUT / row['original']).write_bytes((PROJECT / row['path']).read_bytes())
    for row in state['files']:
        if row['existsBefore']:
            (P / row['backup']).write_bytes((PROJECT / row['path']).read_bytes())
    m.update(baseline=PRODUCT_COMMIT, productSourceSha256=product,
        scope='Identity vertex follows URP draw matrices; unchanged Release72 ordinary/explicit runtime wiring; no observers',
        sourcePreparationCommit=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip())
    m.pop('release71Source', None)
    host = next(row for row in m['files'] if row['path'].endswith('/LocalReleaseBootstrap.cs'))
    previous_host = next(row for row in old['files'] if row['path'].endswith('/LocalReleaseBootstrap.cs'))
    previous_host_path = PRIOR / 'instrumentation' / previous_host['prepared']
    m['unchangedRelease71Host'] = dict(priorPath=str(previous_host_path), sha256=sha(previous_host_path))
    assert m['unchangedRelease71Host']['sha256'] == host['sha256']
    save(OUT / 'manifest.json', m); save(P / 'asset-state.json', state)
    print(json.dumps(dict(stagedFiles=len(m['files']), productFiles=len(product), baseline=PRODUCT_COMMIT)))


def preflight():
    check = module('release73_preflight', P.parent / 'current-local-release-67/preflight67.py')
    check.PACKAGE, check.STAGE, check.DEST = P, OUT, P / 'preflight'
    check.main()


def analyze(action):
    check = module('release73_analysis', P.parent / 'current-local-release-67/analyze67.py')
    check.PACKAGE, check.BUILD = P, BUILD
    raise SystemExit(check.main(action))


def launcher():
    assert load(P / 'build-report.json')['result'] == 'Succeeded'
    assert not (BUILD / 'Start-LocalRelease.cmd').exists()
    for name in ('Start-LocalRelease.cmd', 'LocalRelease-README.txt'):
        data = (BUILD.parent / 'LocalRelease72' / name).read_text(encoding='utf-8')
        if name.endswith('.txt'):
            data = data.replace('LocalRelease72', 'LocalRelease73').replace('13f31ec', '95a3213')
            data = data.replace('current-local-release-72', 'current-local-release-73')
            data += '\n本次加入接收面身份顶点与URP矩阵同源修复；普通导航与形变入口保持。\n'
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
