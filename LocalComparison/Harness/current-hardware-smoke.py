"""Reuse the reviewed software build/analyzer for one separate hardware run."""
import importlib.util,json,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
UPSTREAM=ROOT/'LocalComparison/Review/current-player-shutdown-01'
PACKAGE=ROOT/'LocalComparison/Review/current-player-dxr-smoke-01'
source=Path(__file__).with_name('analyze-player-smoke.py')
# Pro20 requires only mode-correct scope and zero unrepresented hardware instances.
spec=importlib.util.spec_from_file_location('player_smoke',source)
module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)

def prepare():
    software=module.load(UPSTREAM/'software-windowed/analysis.json')
    assert software['playerSmokeVerified'] and software['normalExitAccepted'] and software['inlineRayTracingSupported']
    digest=module.verify_products()
    assert digest==software['buildProductsManifestSha256']=='bbda6cbb087d6944cf1ef0210c978806455a12923539073f3d180a8ea5197ef4'
    product=module.load(UPSTREAM/'instrumentation/manifest.json')['productSourceSha256']
    assert all(module.sha(ROOT/p)==sha and module.sha(module.PROJECT/'Assets/HybridLumenGI'/p)==sha for p,sha in product.items()),'Current/deployed product differs from built software'
    PACKAGE.mkdir(parents=True,exist_ok=True)
    for name in ['build-products.json','build-analysis.json']:
        target=PACKAGE/name;content=(UPSTREAM/name).read_bytes()
        if target.exists():assert target.read_bytes()==content,'Existing upstream evidence differs'
        else:target.write_bytes(content)
    module.save(PACKAGE/'source-provenance.json',{'upstream':str(UPSTREAM),'buildProductsManifestSha256':digest,
        'candidateCommit':'3088d41b00d69293d3899cdcc5bc0e354bb4ece9','matchingProductSources':len(product),
        'productFileCount':283,'newBuild':False,'softwareRerun':False,'analyzerSha256':module.sha(source)})
    print('Same283build products verified;110current/deployed sources match; software/capability gates passed')

if __name__=='__main__':
    if sys.argv[1:] == ['prepare']:prepare()
    elif sys.argv[1:] == ['analyze']:
        module.PACKAGE=PACKAGE
        raise SystemExit(0 if module.run('hardware') else 1)
    else:raise SystemExit('Expected prepare or analyze')
