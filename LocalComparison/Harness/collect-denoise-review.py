"""Copy selected immutable run evidence into the connector-visible workspace."""
import hashlib
import json
from pathlib import Path
import shutil
import numpy as np

root = Path(__file__).resolve().parents[2]
output = root / 'LocalComparison/Review/denoise-02/prior-runs'
base = Path('I:/Unity test/Comparison/Results')
runs = {'before01': '20261027-152612-574958fa6ca74fe58416590f2e4c56ed',
        'denoise01': '20261027-153457-43786b6cdf404df0bb43c9a24eafbb03'}
manifest = {}
for label, identifier in runs.items():
    source = base / identifier
    destination = output / label
    destination.mkdir(parents=True, exist_ok=True)
    files = ['feature.json', 'run.json', 'frames.jsonl', 'unity-log.jsonl', 'denoise-size.txt']
    for frame in [119, 179]:
        files += [f'frame-{frame:04d}.{ext}' for ext in ['json', 'rgba32f']]
        files += [f'denoise-{frame:04d}-{channel}.rgba32f' for channel in ['history', 'moments']]
    copied = []
    for name in files:
        before, after = source / name, destination / name
        digest = hashlib.sha256(before.read_bytes()).hexdigest()
        if after.exists():
            assert hashlib.sha256(after.read_bytes()).hexdigest() == digest, after
        else:
            shutil.copy2(before, after)
        copied.append({'file': name, 'bytes': before.stat().st_size, 'sha256': digest})
    receipts = [json.loads(line) for line in (source/'frames.jsonl').read_text(encoding='utf-8-sig').splitlines()]
    diagnostics = [json.loads(row['diagnosticsJson']) for row in receipts]
    summary = {'source': str(source), 'copied': copied, 'receipts': len(receipts),
               'exactFrames': sum(d['exactSoftwareGeometry'] for d in diagnostics), 'samples': {}}
    for frame in [119, 179]:
        h = np.fromfile(source/f'denoise-{frame:04d}-history.rgba32f', dtype='<f4').reshape(180,320,4)
        m = np.fromfile(source/f'denoise-{frame:04d}-moments.rgba32f', dtype='<f4').reshape(180,320,4)
        summary['samples'][str(frame)] = {'diagnostics': diagnostics[frame], 'historyFinite': bool(np.isfinite(h).all()),
            'momentsFinite': bool(np.isfinite(m).all()), 'GIWidth': 320, 'GIHeight': 180,
            'pixels': [{'xy':[x,y], 'history':h[y,x].tolist(), 'moments':m[y,x].tolist()} for x,y in [(175,80),(190,110),(160,90)]]}
    manifest[label] = summary
(output/'provenance.json').write_text(json.dumps(manifest, indent=2), encoding='utf-8')
print(json.dumps({'runs':len(manifest),'files':sum(len(v['copied']) for v in manifest.values()),'destination':str(output)}))
