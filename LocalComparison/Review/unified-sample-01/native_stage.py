"""Stage the finite sample driver and restore only its two verified owned roots."""
import hashlib
import json
import os
from pathlib import Path
import stat
import sys

P = Path(__file__).resolve().parent
ROOT = P.parents[2]
PROJECT = Path('I:/Unity test/Project')
OWNED = [PROJECT/'Assets/UnifiedSampleV201', PROJECT/'Assets/StreamingAssets/UnifiedSampleV201']
OUT = Path('I:/Unity test/Comparison/UnifiedSample01')
STAGE = P/'instrumentation-game-exit'
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
load = lambda p: json.loads(p.read_text(encoding='utf-8-sig'))

def no_reparse(path):
    # Check the literal path and every ancestor without following the entry.
    for part in (path, *path.parents):
        try: attributes = part.lstat().st_file_attributes
        except FileNotFoundError: continue
        assert not attributes & stat.FILE_ATTRIBUTE_REPARSE_POINT, str(part)

def validate_owned():
    expected = [Path('I:/Unity test/Project/Assets/UnifiedSampleV201'), Path('I:/Unity test/Project/Assets/StreamingAssets/UnifiedSampleV201')]
    for owned, exact in zip(OWNED, expected):
        assert Path(os.path.abspath(owned)) == exact
        assert exact.is_relative_to(PROJECT/'Assets')
        no_reparse(owned); no_reparse(Path(str(owned)+'.meta'))

def save(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2)+'\n', encoding='utf-8')

def product_matches():
    products = load(P/'deployment.json')['productSourceSha256']
    assert len(products) == 120
    for name, digest in products.items():
        assert sha(ROOT/name) == sha(PROJECT/'Assets/HybridLumenGI'/name) == digest, name
    for row in load(P/'deployment.json')['files']:
        if row['path'].endswith('.meta'):
            assert sha(ROOT/row['path']) == sha(PROJECT/'Assets/HybridLumenGI'/row['path']) == row['afterSha256']
    return products

def fresh():
    validate_owned()
    assert not OUT.exists()
    for owned in OWNED:
        assert not owned.exists() and not Path(str(owned)+'.meta').exists(), owned
    assert (PROJECT/'Assets/StreamingAssets').is_dir()

def freeze():
    assert not (P/'source-freeze.json').exists()
    fresh(); products = product_matches()
    assert load(P/'game-exit/preflight/exit.json')['exitCode'] == 0
    assert (P/'verify_run.py').is_file()
    protected = []
    for name in ('ProjectSettings/QualitySettings.asset', 'ProjectSettings/GraphicsSettings.asset',
                 'Assets/RuntimeAudit/Functional.unity', 'Assets/StreamingAssets.meta'):
        source = PROJECT/name; backup = STAGE/'protected'/name
        backup.parent.mkdir(parents=True, exist_ok=True); backup.write_bytes(source.read_bytes())
        protected.append(dict(path=name, sha256=sha(source), backup=backup.relative_to(STAGE).as_posix()))
    save(STAGE/'protected.json', protected)
    drivers = [r for r in load(STAGE/'manifest.json')['files'] if r['path'].startswith('Assets/UnifiedSampleV201/')]
    assert len(drivers) == 2
    save(STAGE/'native-drivers.json', drivers)
    paths = [p for p in P.iterdir() if p.is_file() and p.suffix in ('.py','.ps1','.json','.md')]
    paths += [ROOT/'LocalComparison/Harness'/n for n in ('UnifiedSampleHost.cs','UnifiedSampleEditor.cs','native_log_check.py')]
    evidence = [STAGE/n for n in ('manifest.json','protected.json','native-drivers.json')]
    evidence += [P/'game-exit/preflight'/n for n in ('exit.json','identity.json','commands.json')]
    save(P/'source-freeze.json', dict(schema='unified-sample-native-v1',
        sources={p.relative_to(ROOT).as_posix():sha(p) for p in paths},
        evidence={p.relative_to(ROOT).as_posix():sha(p) for p in evidence},
        productSourceSha256=products, nativeOutput=str(OUT),
        scope='Same-scene finite streaming/HLOD/backend preference/release integration; no physical quality or performance verdict'))
    print(json.dumps(dict(sourceFreezeSha256=sha(P/'source-freeze.json'), products=120, drivers=2)))

def install():
    fresh(); product_matches()
    assert not (STAGE/'installed.json').exists()
    frozen = load(P/'source-freeze.json')
    for mapping in ('sources','evidence'):
        for name, digest in frozen[mapping].items(): assert sha(ROOT/name) == digest, name
    for row in load(STAGE/'protected.json'):
        assert sha(PROJECT/row['path']) == sha(STAGE/row['backup']) == row['sha256']
    drivers = load(STAGE/'native-drivers.json')
    for row in drivers:
        assert sha(STAGE/row['prepared']) == row['sha256'] and not (PROJECT/row['path']).exists()
    save(STAGE/'installed.json', dict(sourceFreezeSha256=sha(P/'source-freeze.json'), ownedRoots=[str(p) for p in OWNED]))
    for row in drivers:
        target = PROJECT/row['path']; target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes((STAGE/row['prepared']).read_bytes())

def restore():
    product_matches()
    validate_owned()
    # Reject redirected descendants before either archiving or deleting any root.
    for owned in OWNED:
        if owned.exists():
            for child in owned.rglob('*'): no_reparse(child)
    for row in load(STAGE/'native-drivers.json'):
        target = PROJECT/row['path']
        if target.exists(): assert sha(target) == row['sha256']
    protected = load(STAGE/'protected.json')
    for row in protected:
        assert sha(STAGE/row['backup']) == row['sha256']
        assert sha(PROJECT/row['path']) == row['sha256'] or row['path'] == 'ProjectSettings/QualitySettings.asset'
    archive = OUT/'project-archive'; assert not archive.exists()
    rows = []
    inventories = []
    for owned in OWNED:
        paths = [p for p in owned.rglob('*') if p.is_file()] if owned.exists() else []
        metadata = Path(str(owned)+'.meta')
        if metadata.exists(): paths.append(metadata)
        inventories.append((owned, metadata, paths))
    # Complete both archives before deleting anything from either owned root.
    for owned, metadata, paths in inventories:
        for path in paths:
            no_reparse(path)
            assert path.resolve().is_relative_to(owned.resolve()) or path.resolve() == metadata.resolve()
            target = archive/path.relative_to(PROJECT); target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(path.read_bytes()); assert sha(path) == sha(target)
            rows.append(dict(path=path.relative_to(PROJECT).as_posix(), sha256=sha(path), bytes=path.stat().st_size))
    for row in protected:
        target = PROJECT/row['path']
        if sha(target) != row['sha256']:
            assert row['path'] == 'ProjectSettings/QualitySettings.asset'
            prior = archive/row['path']; prior.parent.mkdir(parents=True, exist_ok=True); prior.write_bytes(target.read_bytes())
            assert sha(prior) == sha(target)
            rows.append(dict(path=row['path'],sha256=sha(target),bytes=target.stat().st_size))
    for owned, metadata, paths in inventories:
        if owned.exists():
            for path in sorted(owned.rglob('*'), key=lambda p:len(p.parts), reverse=True):
                no_reparse(path)
                assert path.resolve().is_relative_to(owned.resolve())
                if path.is_file(): path.unlink()
                elif path.is_dir(): path.rmdir()
            no_reparse(owned); owned.rmdir()
        if metadata.exists():
            no_reparse(metadata); metadata.unlink()
    protected_rows = []
    for row in protected:
        target = PROJECT/row['path']; unchanged = sha(target) == row['sha256']
        if not unchanged:
            assert row['path'] == 'ProjectSettings/QualitySettings.asset'
            target.write_bytes((STAGE/row['backup']).read_bytes())
        protected_rows.append(dict(path=row['path'],unchanged=unchanged,restored=sha(target)==row['sha256']))
    product_matches()
    assert all(not p.exists() and not Path(str(p)+'.meta').exists() for p in OWNED)
    save(P/'restoration.json', dict(productFiles=120, productMatches=True, ownedRootsRemoved=True,
        protected=protected_rows, archivedFiles=rows, archiveDirectory=str(archive)))

if __name__ == '__main__':
    assert sys.argv[1] in ('freeze','install','restore')
    globals()[sys.argv[1]]()
