"""Predeclared finite comparison; never requests extra frames or another candidate."""
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];PACKAGE=ROOT/'LocalComparison/Review/transport-hotspot-and-reuse-01'
load=lambda p:json.loads(p.read_text(encoding='utf-8-sig'))
old=load(PACKAGE/'locator/native-window/analysis.json');new=load(PACKAGE/'candidate/native-window/analysis.json')
assert old['completeAttribution'] and new['completeAttribution']
manifests=[load(PACKAGE/s/'instrumentation/manifest.json') for s in ['locator','candidate']]
instrumentation=[{x['path']:x['sha256'] for x in m['files']} for m in manifests]
assert instrumentation[0]==instrumentation[1],'Diagnostic source wiring changed'
product=[m['productSourceSha256'] for m in manifests];assert product[0].keys()==product[1].keys()
diff=[p for p in product[0] if product[0][p]!=product[1][p]]
assert diff==['Runtime/Resources/HybridLumenGI/HybridLumenGIKernels.hlsl'],diff
reports=[load(PACKAGE/s/'build-report.json') for s in ['locator','candidate']]
buildinputs=[{i['path']:i['sha256'] for i in r['inputs']} for r in reports]
changedInputs=[p for p in buildinputs[0] if buildinputs[0][p]!=buildinputs[1].get(p)]
assert buildinputs[0].keys()==buildinputs[1].keys()
assert changedInputs==['Assets/HybridLumenGI/'+diff[0]],changedInputs
assert load(PACKAGE/'receiver-contract/results.json')['passed']
for key in ['window','warmupLimit','drainLimit','frameLimit','sourceStart','sourceEnd','frames','scene','gpu','api','measureOnly','adaptive','targetMs']:
    assert old['collection'][key]==new['collection'][key],key
comparisons={}
for scope in old['statistics']:
    a=old['statistics'][scope]['medianMs'];b=new['statistics'][scope]['medianMs']
    blocks=[[block['statistics'][scope]['medianMs'] for block in side['consecutiveBlocks']] for side in [old,new]]
    variation=max(max(v)-min(v) for v in blocks)
    comparisons[scope]={'locatorMedianMs':a,'candidateMedianMs':b,'savedMs':a-b,'savedPercent':100*(a-b)/a,
        'locatorBlockMedians':blocks[0],'candidateBlockMedians':blocks[1],'largestWithinSideBlockRangeMs':variation,
        'improvementExceedsBlockVariation':a-b>variation,'candidateBlocksEntirelyBelowLocator':max(blocks[1])<min(blocks[0]),
        'outerAdverseIncreaseExceedsVariation':b-a>variation}
retain=comparisons['Gather']['improvementExceedsBlockVariation'] and all(not comparisons[k]['outerAdverseIncreaseExceedsVariation'] for k in ['Transport','FormalSum'])
result={'candidateRetainGate':retain,'decision':'retain-for-Pro-review' if retain else 'revert-no-clear-benefit-or-regression',
        'predeclaredRule':'Gather median saving must exceed the larger within-side range of 4 consecutive block medians; Transport/FormalSum must not increase beyond own block variation. Contract and native validity gates required. No added samples.',
        'scope':'Two instrumented 64-source windows; descriptive finite comparison, not randomized repeatability, full-app speed or production tails.',
        'instrumentationIdentical':True,'onlyChangedBuildInput':changedInputs,'comparisons':comparisons}
(PACKAGE/'comparison.json').write_bytes((json.dumps(result,indent=2)+'\n').encode());print(json.dumps(result))
