"""One guarded deployment of approved product bytes; retain old source and build40."""
import hashlib,json,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];OUT=Path(__file__).resolve().parent;PROJECT=Path('I:/Unity test/Project')
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
old=json.loads((ROOT/'LocalComparison/Review/local-release-baseline-01/instrumentation/manifest.json').read_text())['productSourceSha256']
current={p.relative_to(ROOT).as_posix():sha(p) for top in ['Runtime','Editor'] for p in (ROOT/top).rglob('*') if p.is_file() and p.suffix!='.meta'}
assert not (OUT/'deployment.json').exists(),'Unique current-source deployment already recorded'
assert old.keys()==current.keys()
assert all(sha(PROJECT/'Assets/HybridLumenGI'/p)==v for p,v in old.items()),'Deployment diverged from known prior source; do not overwrite'
changed=[p for p in current if current[p]!=old[p]]
for p in changed:
    dst=OUT/'prior-deployed-source'/p;dst.parent.mkdir(parents=True,exist_ok=True);dst.write_bytes((PROJECT/'Assets/HybridLumenGI'/p).read_bytes())
for p in changed:(PROJECT/'Assets/HybridLumenGI'/p).write_bytes((ROOT/p).read_bytes())
assert all(sha(PROJECT/'Assets/HybridLumenGI'/p)==v for p,v in current.items())
config=['Assets/RuntimeAudit/Functional.unity','Assets/Comparison/Renderer.asset','ProjectSettings/GraphicsSettings.asset','ProjectSettings/QualitySettings.asset','ProjectSettings/ProjectSettings.asset']
report={'sourceCommit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'productFiles':len(current),'changed':changed,
        'before':old,'after':current,'unchangedSceneSettings':{p:sha(PROJECT/p) for p in config},'release40Untouched':True}
(OUT/'deployment.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps({'approvedSource':report['sourceCommit'],'productFiles':len(current),'changedFiles':changed}))
