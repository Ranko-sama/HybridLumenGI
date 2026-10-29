"""Deploy and compile the complete unified-sample implementation without running Unity."""
import hashlib
import importlib.util
import json
from pathlib import Path
import sys

P = Path(__file__).resolve().parent
ROOT = P.parents[2]
PROJECT = Path('I:/Unity test/Project')
OUT = P / 'instrumentation-game-exit'
BASE = P.parent / 'unified-sample-01/deployment.json'
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
load = lambda p: json.loads(p.read_text(encoding='utf-8-sig'))


def save(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2) + '\n', encoding='utf-8')


def deploy():
    assert not (P / 'deployment.json').exists(), 'Preserve the original deployment receipt'
    baseline = load(BASE)['productSourceSha256']
    assert len(baseline) == 120
    assert all(sha(PROJECT / 'Assets/HybridLumenGI' / r) == h for r, h in baseline.items())
    current = {p.relative_to(ROOT).as_posix(): sha(p) for top in ('Runtime', 'Editor')
               for p in (ROOT / top).rglob('*') if p.is_file() and p.suffix != '.meta'}
    added = sorted(current.keys() - baseline.keys())
    modified = sorted(r for r in baseline if baseline[r] != current[r])
    assert len(current) == 120 and added == []
    assert modified == ['Runtime/HybridLumenGIValidationSourceData.cs']
    rows = []
    planned = modified + added + [r + '.meta' for r in added]
    for relative in planned:
        source = ROOT / relative
        target = PROJECT / 'Assets/HybridLumenGI' / relative
        assert source.is_file(), relative
        if relative in added or relative.endswith('.meta'):
            assert not target.exists(), relative
        else:
            assert sha(source) == current[relative] and sha(target) == baseline[relative]
    # Save every original before the first installed product mutation.
    for relative in planned:
        target = PROJECT / 'Assets/HybridLumenGI' / relative
        source = ROOT / relative
        before = sha(target) if target.exists() else None
        if before:
            backup = P / 'deployment-original' / relative
            backup.parent.mkdir(parents=True, exist_ok=True)
            backup.write_bytes(target.read_bytes())
            assert sha(backup) == before
        rows.append(dict(path=relative, beforeSha256=before, afterSha256=sha(source)))
    save(P / 'deployment-intent.json', dict(files=rows))
    try:
        for row in rows:
            source = ROOT / row['path']; target = PROJECT / 'Assets/HybridLumenGI' / row['path']
            assert sha(source) == row['afterSha256']
            target.parent.mkdir(parents=True, exist_ok=True); target.write_bytes(source.read_bytes())
        assert all(sha(PROJECT / 'Assets/HybridLumenGI' / r) == h for r, h in current.items())
    except Exception as error:
        # Restore only bytes from this attempted deployment, never a concurrent edit.
        for row in rows:
            target = PROJECT / 'Assets/HybridLumenGI' / row['path']
            if target.exists(): assert sha(target) in (row['beforeSha256'], row['afterSha256'])
        for row in rows:
            target = PROJECT / 'Assets/HybridLumenGI' / row['path']
            if row['beforeSha256']:
                target.write_bytes((P / 'deployment-original' / row['path']).read_bytes())
            elif target.exists():
                assert target.resolve().is_relative_to((PROJECT / 'Assets/HybridLumenGI').resolve())
                target.unlink()
        save(P / 'deployment-failure.json', dict(error=str(error), baselineRestored=all(sha(PROJECT / 'Assets/HybridLumenGI' / r)==h for r,h in baseline.items())))
        raise
    save(P / 'deployment.json', dict(passed=True, baselineSource='unified-sample-01', baselineManifestSha256=sha(BASE), productFiles=len(current),
         modified=modified, added=added, files=rows, productSourceSha256=current))
    print(json.dumps(dict(productFiles=len(current), modified=modified, added=added)))


def preflight():
    assert not OUT.exists(), 'Keep the first complete assembly preparation'
    current = load(P / 'deployment.json')['productSourceSha256']
    rows = []
    for relative, digest in current.items():
        source = ROOT / relative
        assert sha(source) == sha(PROJECT / 'Assets/HybridLumenGI' / relative) == digest
        if not relative.endswith('.cs'):
            continue
        staged = OUT / 'prepared/Assets/HybridLumenGI' / relative
        staged.parent.mkdir(parents=True, exist_ok=True)
        staged.write_bytes(source.read_bytes())
        rows.append(dict(path='Assets/HybridLumenGI/' + relative,
                         prepared=staged.relative_to(OUT).as_posix(), sha256=digest))
    for name in ('UnifiedSampleHost.cs', 'UnifiedSampleEditor.cs'):
        relative = 'Assets/UnifiedSampleV201/' + ('Editor/' if name.endswith('Editor.cs') else '') + name
        source = ROOT / 'LocalComparison/Harness' / name
        staged = OUT / 'prepared' / relative
        staged.parent.mkdir(parents=True, exist_ok=True)
        staged.write_bytes(source.read_bytes())
        rows.append(dict(path=relative, prepared=staged.relative_to(OUT).as_posix(), sha256=sha(staged)))
    save(OUT / 'manifest.json', dict(productSourceSha256=current, files=rows,
         scope='Complete unified-sample product sources; all Runtime/Editor C# included, no GPU/native execution'))
    helper = P.parent / 'current-local-release-67/preflight67.py'
    spec = importlib.util.spec_from_file_location('complete_validation_preflight', helper)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    compiler_package = P / 'game-exit'
    compiler_package.mkdir(exist_ok=True)
    module.PACKAGE, module.STAGE, module.DEST = compiler_package, OUT, compiler_package / 'preflight'
    module.main()


if __name__ == '__main__':
    assert sys.argv[1] in ('deploy', 'preflight')
    globals()[sys.argv[1]]()
