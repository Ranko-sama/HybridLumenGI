"""One offline assessment of existing captures. No Unity or acceptance thresholds."""
import hashlib, json, shutil
from pathlib import Path
import numpy as np

out = Path(__file__).resolve().parent
repo = out.parents[2]
prior = repo / 'LocalComparison/Review/denoise-03'
pair = json.loads((prior / 'paired-scene.json').read_text())
folder = Path(pair['runs']['candidate']['path'])
manifest = {r['file']: r['sha256'] for r in json.loads((prior / 'scene-candidate/raw-manifest.json').read_text())}
used = {}
def read(f, stage):
    name = f'frame-{f:04d}.rgba32f' if stage == 'final' else f'denoise-{f:04d}-{stage}.rgba32f'
    data = (folder / name).read_bytes()
    digest = hashlib.sha256(data).hexdigest()
    assert digest == manifest[name], name
    used[name] = digest
    return np.frombuffer(data, dtype='<f4').reshape((360,640,4) if stage == 'final' else (180,320,4)).astype(np.float64)

geometry = {f:read(f,'geometry') for f in range(176,197)}
material = {f:read(f,'material') for f in range(176,197)}
cohorts = []
for first in [177,178,179]:
    before, current = geometry[first-1], geometry[first]
    # DX12 reversed-Z, fixed camera; farther visible depth is an exposure proxy.
    # No identity capture exists here, so this is not a proven per-object mask.
    mask = (before[:,:,3] > current[:,:,3]) & (current[:,:,3] > 1e-6)
    for f in range(first,197):
        mask &= np.all(geometry[f] == current,axis=2) & np.all(material[f] == material[first],axis=2)
    ys,xs = np.where(mask)
    row = dict(first=first,pixels=len(xs),selection='Farther depth followed by exactly stable geometry/material through196; no history or radiance selection')
    if len(xs):
        row['giBoundsInclusive'] = [int(xs.min()),int(ys.min()),int(xs.max()),int(ys.max())]
        row['frames'] = []
        for f in range(first,197):
            raw,history,moments = (read(f,s)[mask] for s in ['raw','history','moments'])
            final = read(f,'final')[2*ys+1,2*xs+1,:3]
            row['frames'].append(dict(frame=f,rawValid=int((raw[:,3]>0).sum()),historyCountMin=float(moments[:,2].min()),historyCountMax=float(moments[:,2].max()),historyEqualsRawRgbPixels=int(np.all(raw[:,:3]==history[:,:3],axis=1).sum()),rawMeanRgb=raw[:,:3].mean(axis=0).tolist(),historyMeanRgb=history[:,:3].mean(axis=0).tolist(),finalMeanRgb=final.mean(axis=0).tolist()))
    cohorts.append(row)

older = Path('I:/Unity test/Comparison/Results/20261027-153457-43786b6cdf404df0bb43c9a24eafbb03')
copies=[]
(out/'older-scene').mkdir(exist_ok=True)
for name in ['run.json','frame-0119.png','frame-0360.png','frame-0419.png']:
    source=older/name; target=out/'older-scene'/name
    assert not target.exists(),target
    shutil.copy2(source,target)
    copies.append(dict(source=str(source),copy=str(target.relative_to(repo)),sha256=hashlib.sha256(source.read_bytes()).hexdigest()))
result=dict(scope='Historical-source evidence triage only; neither current-source acceptance nor physical reference',source=str(folder),priorManifestVerifiedForAllReadArrays=True,used=used,cohorts=cohorts,existingPreviewCopies=copies,newUnityRuns=0,newGpuRuns=0)
(out/'existing-evidence.json').write_text(json.dumps(result,indent=2))
print(json.dumps({'cohorts':cohorts,'readArrayCount':len(used),'newUnityRuns':0,'newGpuRuns':0},indent=2))
