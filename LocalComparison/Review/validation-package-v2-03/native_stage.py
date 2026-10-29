"""Freeze, stage and restore the two-file driver for the existing 720-frame scene."""
import hashlib
import json
from pathlib import Path
import sys

P = Path(__file__).resolve().parent
ROOT = P.parents[2]
PROJECT = Path('I:/Unity test/Project')
OWNED = PROJECT / 'Assets/ValidationPackageV201'
OUT = Path('I:/Unity test/Comparison/ValidationPackageV203')
STAGE = P / 'instrumentation'
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
load = lambda p: json.loads(p.read_text(encoding='utf-8-sig'))


def save(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2) + '\n', encoding='utf-8')


def product_matches():
    products = load(P / 'deployment.json')['productSourceSha256']
    assert len(products) == 118
    for relative, digest in products.items():
        assert sha(ROOT / relative) == sha(PROJECT / 'Assets/HybridLumenGI' / relative) == digest, relative
    return products


def freeze():
    assert not (P / 'source-freeze.json').exists()
    assert (P / 'verify_package.py').is_file() and (P / 'verify_package.txt').is_file()
    assert not OWNED.exists() and not Path(str(OWNED) + '.meta').exists() and not OUT.exists()
    assert load(P / 'preflight/exit.json')['exitCode'] == 0
    products = product_matches()
    depth_report = ROOT / 'LocalComparison/Implementation/ValidationV2/capture-compile-02/result.json'
    depth = load(depth_report)
    depth_path = ROOT / 'LocalComparison/Implementation/ValidationV2/Runtime/Resources/HybridLumenGI/HybridLumenGIValidationCopy.compute'
    assert depth['passed'] and next(r for r in depth['checks'] if r['name'] == 'depth-copy')['exitCode'] == 0
    assert depth['sources'][str(depth_path)] == sha(depth_path) == products['Runtime/Resources/HybridLumenGI/HybridLumenGIValidationCopy.compute']
    protected = []
    for relative in ('ProjectSettings/QualitySettings.asset', 'ProjectSettings/GraphicsSettings.asset', 'Assets/RuntimeAudit/Functional.unity'):
        target = PROJECT / relative
        backup = STAGE / 'protected' / relative
        backup.parent.mkdir(parents=True, exist_ok=True)
        backup.write_bytes(target.read_bytes())
        protected.append(dict(path=relative, sha256=sha(target), backup=backup.relative_to(STAGE).as_posix()))
    save(STAGE / 'protected.json', protected)
    drivers = [r for r in load(STAGE / 'manifest.json')['files'] if r['path'].startswith('Assets/ValidationPackageV201/')]
    assert len(drivers) == 2
    for row in drivers:
        assert sha(STAGE / row['prepared']) == row['sha256']
    save(STAGE / 'native-drivers.json', drivers)
    paths = [p for p in P.iterdir() if p.is_file() and p.suffix in ('.py', '.ps1', '.json', '.md')]
    paths += [ROOT / 'LocalComparison/Harness' / name for name in ('ValidationPackageV2Host.cs', 'ValidationPackageV2Editor.cs')]
    paths += [ROOT / 'Tests' / name for name in ('compare-validation-reference.mjs', 'validation-reference-schema.md')]
    paths.append(ROOT / 'LocalComparison/Harness/native_log_check.py')
    sources = {p.relative_to(ROOT).as_posix(): sha(p) for p in paths}
    evidence = {p.relative_to(ROOT).as_posix(): sha(p) for p in
                [STAGE / 'manifest.json', STAGE / 'native-drivers.json', STAGE / 'protected.json',
                 P / 'preflight/exit.json', P / 'preflight/identity.json', P / 'preflight/commands.json', depth_report]}
    save(P / 'source-freeze.json', dict(schema='validation-package-v2-native-v1', sources=sources,
         evidence=evidence, productSourceSha256=products, nativeOutput=str(OUT),
         scope='Existing 720-frame sequence, automated SDF/charts, same-render HDR export; no physical reference or performance verdict'))
    print(json.dumps(dict(sourceFreezeSha256=sha(P / 'source-freeze.json'), productFiles=len(products), drivers=2)))


def install():
    assert not OWNED.exists() and not Path(str(OWNED) + '.meta').exists() and not OUT.exists()
    assert not (STAGE / 'installed.json').exists()
    frozen = load(P / 'source-freeze.json')
    for mapping in ('sources', 'evidence'):
        for relative, digest in frozen[mapping].items():
            assert sha(ROOT / relative) == digest, relative
    product_matches()
    for row in load(STAGE / 'protected.json'):
        assert sha(PROJECT / row['path']) == sha(STAGE / row['backup']) == row['sha256']
    for row in load(STAGE / 'native-drivers.json'):
        assert sha(STAGE / row['prepared']) == row['sha256']
        assert not (PROJECT / row['path']).exists()
    save(STAGE / 'installed.json', dict(sourceFreezeSha256=sha(P / 'source-freeze.json'), ownedRoot=str(OWNED)))
    for row in load(STAGE / 'native-drivers.json'):
        target = PROJECT / row['path']
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes((STAGE / row['prepared']).read_bytes())


def restore():
    # Validate every target before archiving/removing only this exact owned root.
    owned = OWNED.resolve()
    assert owned == Path('I:/Unity test/Project/Assets/ValidationPackageV201').resolve()
    assert owned.parent == (PROJECT / 'Assets').resolve()
    product_matches()
    for row in load(STAGE / 'native-drivers.json'):
        target = PROJECT / row['path']
        if target.exists():
            assert sha(target) == row['sha256'], row['path']
    protected = load(STAGE / 'protected.json')
    for row in protected:
        assert sha(STAGE / row['backup']) == row['sha256']
        assert sha(PROJECT / row['path']) == row['sha256'] or row['path'] == 'ProjectSettings/QualitySettings.asset'
    archive = OUT / 'project-archive'
    assert not archive.exists(), 'Preserve the first restoration archive'
    archive_rows = []
    metadata = Path(str(owned) + '.meta')
    paths = [p for p in owned.rglob('*') if p.is_file()] if owned.exists() else []
    if metadata.exists():
        paths.append(metadata)
    for path in paths:
        assert path.resolve().is_relative_to(owned) or path.resolve() == metadata.resolve()
        destination = archive / path.relative_to(PROJECT)
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(path.read_bytes())
        assert sha(destination) == sha(path)
        archive_rows.append(dict(path=path.relative_to(PROJECT).as_posix(), sha256=sha(path), bytes=path.stat().st_size))
    if owned.exists():
        for path in sorted(owned.rglob('*'), key=lambda p: len(p.parts), reverse=True):
            assert path.resolve().is_relative_to(owned)
            if path.is_file(): path.unlink()
            elif path.is_dir(): path.rmdir()
        owned.rmdir()
    if metadata.exists(): metadata.unlink()
    protected_rows = []
    for row in protected:
        target = PROJECT / row['path']
        unchanged = sha(target) == row['sha256']
        if not unchanged:
            assert row['path'] == 'ProjectSettings/QualitySettings.asset'
            destination = archive / row['path']
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes(target.read_bytes())
            archive_rows.append(dict(path=row['path'], sha256=sha(target), bytes=target.stat().st_size))
            target.write_bytes((STAGE / row['backup']).read_bytes())
        protected_rows.append(dict(path=row['path'], unchanged=unchanged, restored=sha(target) == row['sha256']))
    product_matches()
    save(P / 'restoration.json', dict(productFiles=118, productMatches=True, ownedRootRemoved=not owned.exists(),
         ownedMetadataRemoved=not metadata.exists(), protected=protected_rows, archiveDirectory=str(archive), archivedFiles=archive_rows))
    assert not owned.exists() and not metadata.exists() and all(r['restored'] for r in protected_rows)


if __name__ == '__main__':
    assert sys.argv[1] in ('freeze', 'install', 'restore')
    globals()[sys.argv[1]]()
