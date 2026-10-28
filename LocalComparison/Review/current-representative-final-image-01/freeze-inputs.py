"""Freeze only execution helpers and their existing imports before the unique native build."""
import ast,hashlib,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];OUT=Path(__file__).resolve().parent
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
assert not (OUT/'execution-source-manifest.json').exists()
old=json.loads((ROOT/'LocalComparison/Review/current-release-integration-01/execution-source-manifest.json').read_text())
paths=[r['path'] for r in old['files'] if r['path'].startswith('LocalComparison/Harness/')]
paths+=['LocalComparison/Harness/SingleFinalCaptureMethods.cs.txt','LocalComparison/Harness/material_event_paths.py','Documentation/Checkpoint-Iteration54.md',
        'LocalComparison/Review/current-representative-final-image-01/prepare-deployment.py','LocalComparison/Review/current-representative-final-image-01/freeze-inputs.py']
rows=[]
for path in paths:
    target=OUT/'frozen'/(path+'.txt');target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes((ROOT/path).read_bytes())
    rows.append({'path':path,'frozen':target.relative_to(OUT).as_posix(),'sha256':sha(target)})
m=json.loads((OUT/'instrumentation/manifest.json').read_text());row=next(r for r in m['files'] if r['path'].endswith('/ComparisonCapture.cs'))
before=(OUT/'instrumentation'/row['original']).read_text();after=(OUT/'instrumentation'/row['prepared']).read_text()
assert after==before.replace('    void Start()\n',(ROOT/'LocalComparison/Harness/SingleFinalCaptureMethods.cs.txt').read_text()+'\n    void Start()\n'), 'Original capture/Finish changed'
report={'originalCaptureAndFinishUnchanged':True,'productSourceCommit':json.loads((OUT/'deployment.json').read_text())['sourceCommit'],'files':rows}
(OUT/'execution-source-manifest.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps({'frozen':len(rows),'originalCaptureAndFinishUnchanged':True}))
