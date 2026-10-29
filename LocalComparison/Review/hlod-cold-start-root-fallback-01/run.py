"""One invocation of the existing HLOD runner per frozen source, preserving output."""
import hashlib,json,os,subprocess,sys,traceback
from pathlib import Path
P=Path(__file__).resolve().parent;ROOT=P.parents[2]
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def load(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def save(p,v):p.write_text(json.dumps(v,indent=2)+'\n',encoding='utf-8')

def main(mode):
    assert mode in ['baseline','candidate']
    dest=P/mode;assert not dest.exists(),'Preserve the first invocation'
    frozen=load(P/'frozen-inputs.json')
    def unchanged():
        for row in frozen['files']:assert sha(Path(row['path']))==row['sha256'],'Frozen input changed: '+row['path']
    unchanged()
    if mode=='candidate':assert load(P/'baseline/command.json')['exitCode']==0,'Old-source counterexample must pass first'
    dest.mkdir();env=os.environ.copy();env['HLGI_HLOD_COLD_START_EXPECTATION']=mode
    source=ROOT if mode=='candidate' else P/'baseline-source'
    command=['powershell.exe','-NoProfile','-ExecutionPolicy','Bypass','-File',str(ROOT/'Tests/Validate-HlodTransactions.ps1'),'-SourceRoot',str(source)]
    receipt=dict(mode=mode,command=command,expectation=mode,sourceRoot=str(source),exitCode=None,
        frozenManifestSha256=sha(P/'frozen-inputs.json'))
    save(dest/'command.json',receipt)
    try:
        result=subprocess.run(command,cwd=ROOT,env=env,capture_output=True)
        (dest/'stdout.log').write_bytes(result.stdout);(dest/'stderr.log').write_bytes(result.stderr)
        (dest/'output.log').write_bytes(result.stdout+result.stderr)
        receipt['nativeExitCode']=result.returncode;receipt['exitCode']=result.returncode
        print((result.stdout+result.stderr).decode('utf-8',errors='replace'))
        unchanged();receipt['frozenInputsUnchanged']=True
    except Exception:
        receipt['exitCode']=1;receipt['error']=traceback.format_exc();print(receipt['error'])
    finally:save(dest/'command.json',receipt)
    raise SystemExit(receipt['exitCode'])

if __name__=='__main__':main(sys.argv[1])
