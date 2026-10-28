"""Post-run provenance checks, without rerunning rendering or changing the first analysis."""
import hashlib,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];OUT=Path(__file__).resolve().parent;PROJECT=Path('I:/Unity test/Project')
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
load=lambda p:json.loads(p.read_text(encoding='utf-8-sig'))
d=load(OUT/'deployment.json');m=load(OUT/'execution-source-manifest.json');products=load(OUT/'build-products.json');restored=load(OUT/'instrumentation/restoration.json')
assert not (OUT/'source-verification.json').exists()
assert all(sha(ROOT/p)==v and sha(PROJECT/'Assets/HybridLumenGI'/p)==v for p,v in d['after'].items()),'Current112 product sources changed'
assert all(sha(PROJECT/p)==v for p,v in d['unchangedSceneSettings'].items()),'Scene/settings changed'
assert all(sha(ROOT/r['path'])==r['sha256']==sha(OUT/r['frozen']) for r in m['files']),'Execution helper changed'
build=Path(products['root']);assert all(sha(build/r['path'])==r['sha256'] and (build/r['path']).stat().st_size==r['bytes'] for r in products['files']),'Build artifacts changed'
assert restored['currentProductRestored'] and all(r['restored'] for r in restored['files']) and load(OUT/'instrumentation/excluded-restoration.json')['allRestored']
report={'sourceCommit':d['sourceCommit'],'productFilesVerified':len(d['after']),'sceneSettingsUnchanged':True,'frozenExecutionHelpersUnchanged':True,'productArtifactsVerified':len(products['files']),
        'temporaryOverlaysAndIncludesRestored':True,'fullProductionAccepted':False,'firstNativeAnalysisPreserved':True}
(OUT/'source-verification.json').write_text(json.dumps(report,indent=2),encoding='utf-8');print(json.dumps(report))
