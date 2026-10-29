"""Source/build qualification. Never starts Unity or a Player."""
import hashlib
import importlib.util
import json
import sys
import traceback
from pathlib import Path

P = Path(__file__).resolve().parent
ROOT = P.parents[2]
PROJECT = Path('I:/Unity test/Project')
BUILD = Path('I:/Unity test/Comparison/Builds/StartupStageProbe01')
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
load = lambda p: json.loads(p.read_text(encoding='utf-8-sig'))


def product_inventory():
    return {p.relative_to(BUILD).as_posix(): dict(sha256=sha(p), bytes=p.stat().st_size)
            for p in sorted(BUILD.rglob('*')) if p.is_file()}


def build():
    m = load(P / 'instrumentation/manifest.json')
    r = load(P / 'build-report.json')
    assert load(P / 'build-exit.json')['exitCode'] == 0
    assert r['result'] == 'Succeeded' and r['errors'] == 0
    assert r['configuration'] == 'Release' and r['actualOptions'] == r['requestedOptions'] == 'None'
    assert r['unity'] == '6000.0.85f1' and r['scene'] == 'Assets/RuntimeAudit/Functional.unity'
    assert Path(r['output']).resolve() == (BUILD / 'HybridLumenGITest.exe').resolve()
    assert sha(BUILD / 'HybridLumenGITest.exe') == r['executableSha256']
    expected = {'Assets/HybridLumenGI/' + k: v for k, v in m['productSourceSha256'].items()}
    assert len(expected) == 112
    for row in m['files']:
        assert sha(P / 'instrumentation' / row['prepared']) == row['sha256']
        expected[row['path']] = row['sha256']
    actual = {row['path']: row['sha256'] for row in r['inputs']}
    assert all(actual.get(k) == v for k, v in expected.items())
    prior = load(P.parent / 'current-local-release-71/build-report.json')
    # Compare serialized scene/geometry/material/settings and package inputs,
    # excluding temporary C# wiring, generated GUIDs and the rebuilt Cube binding.
    context = {row['path']: row['sha256'] for row in prior['inputs']
               if not row['path'].endswith(('.cs', '.meta')) and row['path'] not in
               ('Assets/Comparison/Renderer.asset', 'Assets/Comparison/CurrentRelease67Environment.asset')}
    assert all(actual.get(k) == v for k, v in context.items()), [k for k, v in context.items() if actual.get(k) != v]
    cube_spec = importlib.util.spec_from_file_location('startup_cube_check', P.parent / 'current-local-release-67/analyze67.py')
    cube_check = importlib.util.module_from_spec(cube_spec); cube_spec.loader.exec_module(cube_check)
    cube_check.PACKAGE = P
    cube_check.check_cube_build(load)
    changed = [k for k, v in m['productSourceSha256'].items()
               if expected['Assets/HybridLumenGI/' + k] != v]
    assert changed == ['Runtime/HybridLumenGIRendererFeature.cs']
    shaders = {k: v for k, v in m['productSourceSha256'].items()
               if Path(k).suffix in ('.hlsl', '.compute', '.shader')}
    assert sum(Path(k).suffix == '.compute' for k in shaders) == 8
    assert all(actual.get('Assets/HybridLumenGI/' + k) == v for k, v in shaders.items())
    restore = load(P / 'instrumentation/restoration.json')
    assert restore['currentProductRestored'] and all(row['restored'] for row in restore['files'])
    assert load(P / 'asset-restoration.json')['allRestored']
    assert load(P / 'instrumentation/excluded-restoration.json')['allRestored']
    assert all(sha(ROOT / k) == sha(PROJECT / 'Assets/HybridLumenGI' / k) == v
               for k, v in m['productSourceSha256'].items())
    spec = importlib.util.spec_from_file_location('startup_native_log_check', ROOT / 'LocalComparison/Harness/native_log_check.py')
    scanner = importlib.util.module_from_spec(spec); spec.loader.exec_module(scanner)
    hits = scanner.scan(P / 'build-unity.log')
    assert not hits, hits
    products = product_inventory()
    with (P / 'build-products.json').open('x') as f:
        json.dump(products, f, indent=2)
    return dict(passed=True, sourceFiles=112, stagedFiles=len(m['files']),
                unchangedShaderFiles=len(shaders), temporaryCpuObserverOnly=True,
                warnings=r['warnings'], productFiles=len(products), release71ContextInputs=len(context),
                productBaseline=m['baseline'], diagnosticBuild=True,
                ordinaryReleaseUpdated=False, fullProductionAccepted=False)


def products():
    assert load(P / 'build-analysis.json')['passed']
    assert load(P / 'build-products.json') == product_inventory(), 'Built Player products changed'
    return dict(passed=True, productsUnchanged=True)


if __name__ == '__main__':
    action = sys.argv[1]
    assert action in ('build', 'products')
    output = P / 'build-analysis.json'
    if action == 'build':
        assert not output.exists(), 'Preserve first build qualification'
    try:
        result = globals()[action]()
    except Exception:
        result = dict(passed=False, error=traceback.format_exc())
    if action == 'build':
        with output.open('x') as f:
            json.dump(result, f, indent=2)
    print(json.dumps(result))
    raise SystemExit(0 if result['passed'] else 1)
