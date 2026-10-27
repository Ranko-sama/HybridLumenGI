"""Install/restore only the explicitly archived test-project readback instrumentation."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil

parser=argparse.ArgumentParser();parser.add_argument('action',choices=['install','restore']);args=parser.parse_args()
repo=Path(__file__).resolve().parents[2];project=Path('I:/Unity test/Project/Assets')
evidence=repo/'LocalComparison/Review/denoise-03/scene-instrumentation';evidence.mkdir(parents=True,exist_ok=True)
files={'feature':project/'HybridLumenGI/Runtime/HybridLumenGIRendererFeature.cs',
       'capture':project/'ComparisonHarness/ComparisonCapture.cs','probe':project/'ComparisonHarness/RuntimeAuditProbe.cs'}
sha=lambda b:hashlib.sha256(b).hexdigest()
if args.action=='install':
    replacements={
      'feature':('                using(d.frameTiming.Profile(cmd,"HLGI Gather")) Dispatch(cmd,c,trace,state);',
                 '                using(d.frameTiming.Profile(cmd,"HLGI Gather")) Dispatch(cmd,c,trace,state);\n                global::DenoiseSceneTap.Record(cmd,((RTHandle)d.raw).rt,state.camera,d.frame);'),
      'capture':('static bool CaptureAt(int n) => n % 30 == 0','static bool CaptureAt(int n) => DenoiseSceneTap.Wants(n) || n % 30 == 0'),
      'probe':('(f==119||f==149||f==179||f==209||f==239||f==419)', '(DenoiseSceneTap.Wants(f)||f==119||f==149||f==179||f==209||f==239||f==419)')}
    manifest={}
    for label,path in files.items():
        original=path.read_bytes();backup=evidence/(label+'.original.cs.txt')
        if backup.exists():assert backup.read_bytes()==original, f'Already instrumented or changed: {path}'
        else:backup.write_bytes(original)
        newline='\r\n' if b'\r\n' in original else '\n'
        text=original.decode('utf-8');before,after=replacements[label];assert text.count(before)==1,(label,before)
        text=text.replace(before,after.replace('\n',newline))
        if label=='capture':
            before='            if (pending) { readback.WaitForCompletion();';assert text.count(before)==1
            text=text.replace(before,'            DenoiseSceneTap.Finish(collected);'+newline+before)
        data=text.encode('utf-8');path.write_bytes(data);(evidence/(label+'.instrumented.cs.txt')).write_bytes(data)
        manifest[label]={'path':str(path),'originalSha256':sha(original),'instrumentedSha256':sha(data)}
    tap=repo/'LocalComparison/Harness/DenoiseSceneTap.cs';shutil.copy2(tap,project/'ComparisonHarness/DenoiseSceneTap.cs')
    manifest['tap']={'source':str(tap),'sha256':sha(tap.read_bytes())}
    (evidence/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
else:
    manifest=json.loads((evidence/'manifest.json').read_text())
    for label,path in files.items():
        assert sha(path.read_bytes())==manifest[label]['instrumentedSha256'],f'Test source changed; do not overwrite: {path}'
        original=(evidence/(label+'.original.cs.txt')).read_bytes();assert sha(original)==manifest[label]['originalSha256']
        path.write_bytes(original)
    # The inert helper remains as test source outside the product package. No
    # deletion or cache cleanup is required; absent command-line flag disables it.
print(json.dumps({'action':args.action,'files':list(files),'evidence':str(evidence)}))
