"""Freeze each of the two authorized component invocations; never overwrite a run."""
import hashlib,json,subprocess,sys
from pathlib import Path
OUT=Path(__file__).resolve().parent;ROOT=OUT.parents[2]
case=sys.argv[1];assert case in ['baseline','candidate']
assert not (OUT/(case+'.log')).exists(),'Retain first invocation, do not rerun'
archive=OUT/(case+'-compiled-source')
cmd=['powershell.exe','-NoProfile','-ExecutionPolicy','Bypass','-File',str(ROOT/'Tests/Validate-DeformedMesh.ps1'),'-SourceArchive',str(archive)]
if case=='baseline':cmd+=['-LegacyUnchangedControl','-DeformationSource',str(OUT/'baseline-deformed.cs.txt')]
p=subprocess.run(cmd,cwd=ROOT,capture_output=True)
(OUT/(case+'.log')).write_bytes(p.stdout+p.stderr)
manifest={x.name:hashlib.sha256(x.read_bytes()).hexdigest() for x in sorted(archive.glob('*')) if x.is_file()}
(OUT/(case+'-result.json')).write_text(json.dumps({'command':cmd,'exitCode':p.returncode,'compiledSourceSha256':manifest},indent=2),encoding='utf-8')
print((p.stdout+p.stderr).decode('utf-8',errors='replace'));print('NATIVE_EXIT='+str(p.returncode));raise SystemExit(p.returncode)
