"""Compile only the new source-export draft against the installed Unity assemblies; no Unity process or deployment."""
import hashlib, json, subprocess
from pathlib import Path

P = Path(__file__).resolve().parent
PROJECT = Path('I:/Unity test/Project')
EDITOR = Path('I:/Unity test/Editor/6000.0.85f1/Editor/Data')
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()

def main():
    import sys
    dest = P / (sys.argv[1] if len(sys.argv) == 2 else 'source-compile-01')
    assert not dest.exists(), 'Preserve existing compile evidence'
    dest.mkdir()
    rows = []
    for scope, sources in [('Runtime', sorted((P/'Runtime').glob('HybridLumenGIValidationSource*.cs'))),
                           ('Editor', [P/'Editor/HybridLumenGIValidationSourceExport.cs'])]:
        original = PROJECT / ('Library/Bee/artifacts/1900b0aE.dag/Assembly-CSharp' + ('-Editor' if scope == 'Editor' else '') + '.rsp')
        lines = []
        for line in original.read_text(encoding='utf-8-sig').splitlines():
            if line.strip('"').endswith('.cs') or line.startswith(('-out:', '-refout:', '/analyzer:', '-analyzer:', '/additionalfile:')): continue
            lines.append(line)
        lines += ['-r:"' + (PROJECT/'Library/Bee/artifacts/1900b0aE.dag/Assembly-CSharp.ref.dll').as_posix() + '"'] if scope == 'Runtime' else ['-r:"' + (dest/'SourceRuntime.dll').as_posix() + '"']
        output = dest/('Source'+scope+'.dll')
        lines += ['-out:"'+output.as_posix()+'"'] + ['"'+p.as_posix()+'"' for p in sources]
        rsp = dest/(scope+'.rsp'); rsp.write_text('\n'.join(lines), encoding='utf-8')
        command = [str(EDITOR/'NetCoreRuntime/dotnet.exe'), str(EDITOR/'DotNetSdkRoslyn/csc.dll'), '@'+str(rsp)]
        result = subprocess.run(command, cwd=PROJECT, capture_output=True)
        (dest/(scope+'.log')).write_bytes(result.stdout+result.stderr)
        rows.append(dict(scope=scope, exitCode=result.returncode, command=command,
                         response=dict(file=str(rsp), sha256=sha(rsp)), originalResponse=dict(file=str(original), sha256=sha(original)),
                         sources=[dict(file=str(p), sha256=sha(p)) for p in sources]))
        if result.returncode: break
    report = dict(passed=len(rows)==2 and all(r['exitCode']==0 for r in rows), scope='New draft source files only; not a Unity/native or full-product build', checks=rows)
    (dest/'report.json').write_text(json.dumps(report, indent=2))
    print(json.dumps(dict(passed=report['passed'], report=str(dest/'report.json'))))
    raise SystemExit(0 if report['passed'] else 1)

if __name__ == '__main__': main()
