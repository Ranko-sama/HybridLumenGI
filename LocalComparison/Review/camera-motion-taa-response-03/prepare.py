"""Reuse the original camera protocol with the identity vertex fix only."""
import hashlib
import importlib.util
import json
from pathlib import Path
import sys

P = Path(__file__).resolve().parent
ROOT = P.parents[2]
BASE = P.parent / 'camera-motion-taa-response-02'
DIAG = P.parent / 'camera-identity-depth-diagnostic-01'
PROJECT = Path('I:/Unity test/Project')
OWNED = PROJECT / 'Assets/CameraMotionTaa01'
OUT = P / 'instrumentation'
CHANGED = {'Runtime/HybridLumenGIReceiverIdentityPass.cs',
           'Runtime/Resources/HybridLumenGI/HybridLumenGIReceiverIdentity.shader'}
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
load = lambda p: json.loads(p.read_text(encoding='utf-8-sig'))


def save(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2) + '\n', encoding='utf-8')


def shared():
    spec = importlib.util.spec_from_file_location('safe_camera_staging', DIAG / 'prepare.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    module.P = P
    module.OUT = OUT
    return module


def prepare():
    assert not OUT.exists() and not OWNED.exists() and not Path(str(OWNED) + '.meta').exists()
    base = load(BASE / 'instrumentation/manifest.json')
    current = {p.relative_to(ROOT).as_posix(): sha(p) for top in ('Runtime', 'Editor')
               for p in (ROOT / top).rglob('*') if p.is_file() and p.suffix != '.meta'}
    assert current.keys() == base['productSourceSha256'].keys()
    assert {r for r in current if current[r] != base['productSourceSha256'][r]} == CHANGED
    assert all(sha(PROJECT / 'Assets/HybridLumenGI' / r) == v for r, v in current.items())
    rows = []
    for old in base['files']:
        source = BASE / 'instrumentation' / old['prepared']
        assert sha(source) == old['sha256']
        target = PROJECT / old['path']
        original = 'original/' + old['path'] if target.exists() else None
        if original:
            # All nine observation files remain byte-identical to the old run.
            assert sha(target) == old['originalSha256']
            backup = OUT / original
            backup.parent.mkdir(parents=True, exist_ok=True)
            backup.write_bytes(target.read_bytes())
        staged = OUT / 'prepared' / old['path']
        staged.parent.mkdir(parents=True, exist_ok=True)
        staged.write_bytes(source.read_bytes())
        rows.append(dict(path=old['path'], original=original,
                         originalSha256=sha(target) if target.exists() else None,
                         prepared='prepared/' + old['path'], sha256=sha(staged)))
    assert len(rows) == 9
    save(OUT / 'manifest.json', dict(productSourceSha256=current, files=rows,
         scope='Original 48-frame camera/TAA protocol; only two product identity vertex/matrix-binding files change'))
    save(OUT / 'reuse-source.json', dict(originalManifestSha256=sha(BASE / 'instrumentation/manifest.json'),
         changedProductFiles=sorted(CHANGED), unchangedProductFiles=len(current)-len(CHANGED),
         unchangedPreparedFiles=9, originalCompileReportSha256=sha(BASE / 'compile/report.json')))
    protected = []
    for relative in ('ProjectSettings/QualitySettings.asset', 'ProjectSettings/GraphicsSettings.asset', 'Assets/RuntimeAudit/Functional.unity'):
        target = PROJECT / relative
        backup = OUT / 'protected' / relative
        backup.parent.mkdir(parents=True, exist_ok=True)
        backup.write_bytes(target.read_bytes())
        protected.append(dict(path=relative, sha256=sha(target), backup='protected/' + relative))
    save(OUT / 'protected.json', protected)
    urp = load(BASE / 'instrumentation/urp-source.json')
    assert all(sha(Path(path)) == digest for path, digest in urp.items())
    save(OUT / 'urp-source.json', urp)
    save(OUT / 'harness-source.json', load(BASE / 'instrumentation/harness-source.json'))
    report = load(BASE / 'compile/report.json')
    assert report['passed'] and report['sourcesUnchanged']
    # Raster identity files are not included by any of the unchanged compute entries.
    for name, digest in report['sources'].items():
        path = Path(name)
        if path.is_relative_to(ROOT) and path.relative_to(ROOT).as_posix() in CHANGED:
            continue
        assert sha(path) == digest, name
    save(P / 'compute-reuse.json', dict(passed=True, compilerExecuted=False, entries=18,
         originalReportSha256=sha(BASE / 'compile/report.json'),
         scope='Same staged compute files, includes, adapter and all compute product sources; changed raster shader/pass compiled separately'))
    print(json.dumps(dict(productFiles=len(current), changedProductFiles=sorted(CHANGED), stagedFiles=len(rows))))


def freeze():
    assert not (P / 'source-freeze.json').exists()
    assert load(P / 'preflight/exit.json')['exitCode'] == 0
    shader_report = load(P / 'identity-shaders.json')
    assert shader_report['status'] == 'passed'
    required = ('analyze.py', 'test_analyze.py', 'input-model.txt', 'run.ps1', 'run-environment.json', 'verify_execution.py')
    assert all((P / name).is_file() for name in required)
    sources = {p.relative_to(ROOT).as_posix(): sha(p) for p in P.iterdir()
               if p.is_file() and p.suffix in ('.py', '.txt', '.json', '.ps1')}
    for relative in ('prepare.py', 'structured_log.py'):
        path = DIAG / relative
        sources[path.relative_to(ROOT).as_posix()] = sha(path)
    # The analysis dependency manifest is authored before this freeze.
    for relative, digest in load(P / 'analysis-dependencies.json').items():
        assert sha(ROOT / relative) == digest
        sources[relative] = digest
    for name, digest in load(OUT / 'harness-source.json').items():
        path = ROOT / 'LocalComparison/Harness' / name
        assert sha(path) == digest
        sources[path.relative_to(ROOT).as_posix()] = digest
    for path in (ROOT / 'LocalComparison/Harness/native_log_check.py',
                 P.parent / 'current-local-release-67/preflight67.py',
                 P.parent / 'static-hdr-environment-cubemap-01/prepare.py'):
        sources[path.relative_to(ROOT).as_posix()] = sha(path)
    evidence = {p.relative_to(ROOT).as_posix(): sha(p) for p in OUT.glob('*.json')}
    for path in (P / 'identity-contracts').iterdir():
        if path.is_file():
            evidence[path.relative_to(ROOT).as_posix()] = sha(path)
    for row in shader_report['sources']:
        assert sha(ROOT / row['file']).lower() == row['sha256'].lower()
    for row in shader_report['includes']:
        path = Path(shader_report['includeRoot']) / row['file']
        assert sha(path).lower() == row['sha256'].lower()
        evidence[path.relative_to(ROOT).as_posix()] = sha(path)
    validator = ROOT / shader_report['script']
    assert sha(validator).lower() == shader_report['scriptSha256'].lower()
    sources[validator.relative_to(ROOT).as_posix()] = sha(validator)
    for path in (P / 'preflight/exit.json', P / 'preflight/identity.json', P / 'preflight/commands.json', BASE / 'compile/report.json'):
        evidence[path.relative_to(ROOT).as_posix()] = sha(path)
    save(OUT / 'analysis-source.json', sources)
    save(P / 'source-freeze.json', dict(schema='camera-motion-taa-regression-v1', sources=sources, evidence=evidence))
    print(json.dumps(dict(sourceFiles=len(sources), sourceFreezeSha256=sha(P / 'source-freeze.json'))))


if __name__ == '__main__':
    action = sys.argv[1]
    assert action in ('prepare', 'preflight', 'freeze', 'install', 'restore')
    if action in ('prepare', 'freeze'):
        globals()[action]()
    else:
        getattr(shared(), action)()
