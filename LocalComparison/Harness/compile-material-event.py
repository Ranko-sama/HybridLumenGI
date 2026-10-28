"""Only the observer copy entries. Semantic mapper execution is recorded separately."""
import hashlib,json,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];PACKAGE=ROOT/'LocalComparison/Review/material-mpb-propagation-02'
OUT=PACKAGE/'preflight';SOURCE=ROOT/'LocalComparison/Harness/MaterialEventReadback.compute'
DXC='C:/Program Files (x86)/Windows Kits/10/bin/10.0.26100.0/x64/dxc.exe';results=[]
for entry in ['CopyIdentity','CopySamples']:
    args=[DXC,'-T','cs_6_0','-E',entry,'-O3','-I',str(SOURCE.parent),'-I',str(ROOT/'Runtime/Resources/HybridLumenGI'),'-Fo',str(OUT/(entry+'.dxil')),str(SOURCE)]
    result=subprocess.run(args,capture_output=True,timeout=300);(OUT/(entry+'.log')).write_bytes(result.stdout+result.stderr)
    results.append({'entry':entry,'arguments':args,'exitCode':result.returncode,'sha256':hashlib.sha256((OUT/(entry+'.dxil')).read_bytes()).hexdigest() if result.returncode==0 else None})
    (OUT/'copy-compile.json').write_text(json.dumps(results,indent=2),encoding='utf-8');print(entry,result.returncode,flush=True)
    if result.returncode:print((result.stdout+result.stderr).decode('utf-8',errors='replace'));raise SystemExit(result.returncode)
