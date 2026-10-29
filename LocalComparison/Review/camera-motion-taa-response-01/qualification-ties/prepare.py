"""Install the unchanged, already compiled nine files with revised input proof.

The original package, staged bytes, first C#/DXC results and source freeze stay
untouched. Only the separate pre-native nearest-candidate qualification changes.
"""
import hashlib
import importlib.util
import json
from pathlib import Path
import sys

P=Path(__file__).resolve().parent
BASE=P.parent
ROOT=BASE.parents[2]
sha=lambda path:hashlib.sha256(path.read_bytes()).hexdigest()
load=lambda path:json.loads(path.read_text(encoding='utf-8-sig'))

def verify():
    revised=load(P/'source-manifest.json')
    assert revised['schema']=='camera-taa-nearest-qualification-v2'
    for collection in ('sources','originalEvidence'):
        for rel,digest in revised[collection].items():assert sha(ROOT/rel)==digest,rel
    original=load(BASE/'instrumentation/manifest.json')
    recorded={row['path']:row['sha256'] for row in revised['stagedFiles']}
    assert len(recorded)==9 and recorded=={row['path']:row['sha256'] for row in original['files']}
    for row in revised['stagedFiles']:assert sha(ROOT/row['prepared'])==row['sha256']
    frozen=load(BASE/'source-freeze.json')
    for rel,digest in frozen['sources'].items():assert sha(ROOT/rel)==digest,rel
    assert load(BASE/'preflight/exit.json')['exitCode']==0
    compiler=load(BASE/'compile/report.json')
    assert compiler['passed'] and compiler['sourcesUnchanged'] and len(compiler['checks'])==3
    assert all(row['exitCode']==0 for row in compiler['checks'])
    for path,digest in compiler['sources'].items():assert sha(Path(path))==digest,path
    return dict(verified=True,originalStagedFiles=9,sourceManifestSha256=sha(P/'source-manifest.json'),
                shaderAndHostBytesUnchanged=True,managedOrShaderCompilationRepeated=False)

def original_module():
    spec=importlib.util.spec_from_file_location('camera_taa_original_prepare',BASE/'prepare.py')
    value=importlib.util.module_from_spec(spec);spec.loader.exec_module(value);return value

if __name__=='__main__':
    assert len(sys.argv)==2 and sys.argv[1] in ('verify','install','restore')
    operation=sys.argv[1]
    if operation!='restore':
        result=verify();print(json.dumps(result))
    if operation=='install':original_module().install()
    elif operation=='restore':original_module().restore()
