"""Describe the already-collected frame158 coverage. No new selection or rendering."""
import json,hashlib
from pathlib import Path
import numpy as np
ROOT=Path(__file__).resolve().parents[2];PACKAGE=ROOT/'LocalComparison/Review/material-mpb-propagation-01'
folder=next((PACKAGE/'native-window/run').glob('*/run.json')).parent
rows=[json.loads(s) for s in (folder/'material-frames.jsonl').read_text(encoding='utf-8').splitlines()]
receipts=[json.loads(s) for s in (folder/'payloads.jsonl').read_text(encoding='utf-8').splitlines()];r=next(r for r in receipts if r['stage']=='identity-current')
w,h=r['width'],r['height'];ids=np.fromfile(folder/r['file'],dtype='<u4').reshape(h,w,4)
geometry=np.fromfile(folder/'material-0158-geometry.bin',dtype='<f4').reshape(h,w,4)
raw=np.fromfile(folder/'material-0158-raw.bin',dtype='<f4').reshape(h,w,4)
known=np.isfinite(geometry).all(axis=2)&(geometry[:,:,3]>1e-6)&(geometry[:,:,2]>=1)
report={'logical':158,'scope':'Offline corrected interpretation only; original failed gate remains unchanged. Resolved identity.z is primitive+1, candidate.x is object-row+1. No rendering or reselection.','width':w,'height':h,
    'validIdentityPixels':int((ids[:,:,3]!=0).sum()),'knownGeometryPixels':int(known.sum()),'roles':[]}
for s in rows[-1]['sources']:
    key=(ids[:,:,0]==s['keyLow'])&(ids[:,:,1]==s['keyHigh']);row=ids[:,:,2]==s['row']+1;valid=key&(ids[:,:,2]>0)&(ids[:,:,3]==1)
    interior=valid&known
    for dy in [-1,0,1]:
        for dx in [-1,0,1]:interior=interior & np.roll(np.roll(valid&known,dy,axis=0),dx,axis=1)&(ids[:,:,2]==np.roll(np.roll(ids[:,:,2],dy,axis=0),dx,axis=1))
    interior[[0,-1],:]=False;interior[:,[0,-1]]=False
    y,x=np.where(valid);z,counts=np.unique(geometry[:,:,2][valid],return_counts=True)
    report['roles'].append({'source':s,'keyPixels':int(key.sum()),'incorrectRowPredicatePixels':int(row.sum()),'validIdentityPixels':int(valid.sum()),
        'primitiveIndicesPlusOne':np.unique(ids[:,:,2][valid]).tolist(),
        'knownGeometryPixels':int((valid&known).sum()),'threeByThreeInteriorPixels':int(interior.sum()),
        'bounds':None if not len(x) else [int(x.min()),int(y.min()),int(x.max()),int(y.max())],
        'unknownGeometryPixels':int((valid&(geometry[:,:,2]==-1)).sum()),'invalidGeometryPixels':int((valid&(geometry[:,:,2]==0)).sum()),
        'knownRawPixels':int((valid&(raw[:,:,3]>0)).sum()),'unknownRawPixels':int((valid&(raw[:,:,3]<0)).sum())})
report['inputs']=[{'file':p.name,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in [folder/r['file'],folder/'material-0158-geometry.bin',folder/'material-0158-raw.bin',folder/'material-frames.jsonl']]
(PACKAGE/'coverage-identity-contract.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps({**{k:v for k,v in report.items() if k not in ['roles','inputs']},'roles':[{k:v for k,v in item.items() if k!='source'}|{'role':item['source']['role']} for item in report['roles']]}))
