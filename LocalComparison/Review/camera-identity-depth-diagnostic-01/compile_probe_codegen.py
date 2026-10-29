"""Generate code with the existing Identity validator's exact compiler options.

The earlier dependency-output command and original FXC failure remain unchanged.
Reuse the verified actual-package mirror; no shader or header edits.
"""
import hashlib
import json
from pathlib import Path
import re
import subprocess

P = Path(__file__).resolve().parent
ROOT = P.parents[2]
SECOND = P / 'compile-probe-02'
OUT = P / 'compile-probe-03'
DXC = Path('C:/Program Files (x86)/Windows Kits/10/bin/10.0.26100.0/x64/dxc.exe')
sha = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
load = lambda path: json.loads(path.read_text(encoding='utf-8-sig'))


def main():
    assert not OUT.exists(), 'Preserve the first code-generation result'
    first = load(P / 'compile-probe/report.json')
    second = load(SECOND / 'report.json')
    assert first['passed'] is False and second['passed'] is False
    assert second['sourcesUnchanged'] and second['checks'] == []
    assert (SECOND / 'vertex.d').is_file() and not (SECOND / 'vertex.dxil').exists()
    pins = dict(second['sources'])
    for path in (Path(__file__), P / 'compile-probe/report.json', SECOND / 'report.json',
                 SECOND / 'vertex.d', SECOND / 'vertex.log', SECOND / 'include-sources.json',
                 ROOT / 'Tests/Validate-ReceiverIdentityShaders.ps1', DXC):
        pins[str(path)] = sha(path)
    assert all(sha(Path(path)) == digest for path, digest in pins.items())
    source = SECOND / 'identity-probe.validation.hlsl'
    include_root = SECOND / 'includes'
    OUT.mkdir()
    report = dict(passed=False, unityExecuted=False, gpuExecuted=False,
                  scope='Offline DXC code generation; native Unity shader compilation remains separate',
                  correction='Remove dependency-output flags -H/-MD/-MF; use the established Identity code-generation command',
                  shaderOrHeadersChanged=False, sources=pins, checks=[])
    try:
        entries = [('vertex', 'HLGIIdentityVertex', 'vs_6_0', 'VERTEX', False),
                   ('fragment', 'HLGIIdentityFragment', 'ps_6_0', 'FRAGMENT', False),
                   ('fragment-debug', 'HLGIIdentityFragment', 'ps_6_0', 'FRAGMENT', True)]
        for name, entry, profile, stage, debug in entries:
            command = [str(DXC), '-HV', '2018', '-flegacy-macro-expansion', '-T', profile, '-E', entry,
                       '-D', 'SHADER_API_D3D11=1', '-D', 'SHADER_STAGE_' + stage + '=1',
                       '-D', 'UNITY_COMPILER_DXC=1', '-D', 'UNITY_VERSION=600000', '-D', 'SHADER_TARGET=50',
                       '-I', str(include_root), '-Fo', str(OUT / (name + '.dxil')),
                       '-Fc', str(OUT / (name + '.asm'))]
            if debug:
                command += ['-D', 'DEBUG_DISPLAY=1']
            command.append(str(source))
            completed = subprocess.run(command, capture_output=True)
            (OUT / (name + '.log')).write_bytes(completed.stdout + completed.stderr)
            row = dict(name=name, entry=entry, profile=profile, debug=debug,
                       command=command, exitCode=completed.returncode, signatureVerified=False)
            report['checks'].append(row)
            if completed.returncode == 0:
                assembly = (OUT / (name + '.asm')).read_text()
                if stage == 'VERTEX':
                    valid = bool(re.search(r'SV_Position\s+0\s+xyzw\s+\d+\s+POS\s+float', assembly))
                else:
                    valid = bool(re.search(r'_HLGI_IdentityProbeRows\s+UAV\s+struct\s+r/w\s+U\d+\s+u2\s+1', assembly))
                    if debug:
                        valid &= '_HLGI_IdentityCandidates' not in assembly and 'dx.op.discard' in assembly
                    else:
                        valid &= bool(re.search(r'_HLGI_IdentityCandidates\s+UAV\s+struct\s+r/w\s+U\d+\s+u1\s+1', assembly))
                        valid &= 'atomicCompareExchange' in assembly
                row['signatureVerified'] = bool(valid)
                row['dxilSha256'] = sha(OUT / (name + '.dxil'))
            print(name + ' compiler=' + str(completed.returncode) + ' signature=' + str(row['signatureVerified']), flush=True)
        report['passed'] = len(report['checks']) == 3 and all(row['exitCode'] == 0 and row['signatureVerified'] for row in report['checks'])
    except Exception as error:
        report['error'] = repr(error)
    finally:
        report['sourcesUnchanged'] = all(sha(Path(path)) == digest for path, digest in pins.items())
        report['passed'] &= report['sourcesUnchanged']
        (OUT / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps({k: report.get(k) for k in ('passed', 'sourcesUnchanged', 'error')}))
    raise SystemExit(0 if report['passed'] else 1)


if __name__ == '__main__':
    main()
