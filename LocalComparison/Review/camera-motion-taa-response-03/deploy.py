"""Deploy exactly the reviewed two-file identity fix after baseline verification."""
import datetime
import json
from pathlib import Path
import subprocess
from prepare import P, ROOT, PROJECT, BASE, CHANGED, sha, load, save


def main():
    output = P / 'product-deployment.json'
    assert not output.exists()
    previous = load(BASE / 'instrumentation/manifest.json')['productSourceSha256']
    current = {p.relative_to(ROOT).as_posix(): sha(p) for top in ('Runtime', 'Editor')
               for p in (ROOT / top).rglob('*') if p.is_file() and p.suffix != '.meta'}
    assert current.keys() == previous.keys()
    assert {r for r in current if current[r] != previous[r]} == CHANGED
    assert all(sha(PROJECT / 'Assets/HybridLumenGI' / r) == v for r, v in previous.items())
    assert load(P / 'identity-shaders.json')['status'] == 'passed'
    # The root checks process ownership before invoking this deployer.
    rows = []
    for relative in sorted(CHANGED):
        source = ROOT / relative
        target = PROJECT / 'Assets/HybridLumenGI' / relative
        backup = P / 'deployment-original' / relative
        backup.parent.mkdir(parents=True, exist_ok=True)
        backup.write_bytes(target.read_bytes())
        target.write_bytes(source.read_bytes())
        rows.append(dict(path=relative, beforeSha256=previous[relative], afterSha256=current[relative]))
    assert all(sha(PROJECT / 'Assets/HybridLumenGI' / r) == v for r, v in current.items())
    save(output, dict(passed=True, productFiles=len(current), changedFiles=rows,
         sourceCommit=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
         recordedUtc=datetime.datetime.now(datetime.timezone.utc).isoformat()))
    print(json.dumps(dict(passed=True, productFiles=len(current), changedFiles=len(rows))))


if __name__ == '__main__':
    main()
