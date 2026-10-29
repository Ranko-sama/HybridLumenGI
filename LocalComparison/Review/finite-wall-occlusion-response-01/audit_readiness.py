"""Post-run metadata/source audit only. Never rewrites frozen inputs or reads RGB."""
import hashlib,json,re,struct
from pathlib import Path
P=Path(__file__).resolve().parent;ROOT=P.parents[2]
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
load=lambda p:json.loads(p.read_text(encoding='utf-8-sig'))
def main():
    target=P/'readiness-audit.json';assert not target.exists(),'Preserve first readiness audit'
    freeze=load(P/'source-freeze.json');frozen={**freeze['newSources'],**freeze['unchangedDependencies']}
    assert all(sha(ROOT/path)==digest for path,digest in frozen.items()),'A frozen dependency changed'
    host=ROOT/'LocalComparison/Harness/FiniteWallOcclusionScene.cs';analyzer=P/'analyze.py'
    host_text=host.read_text();analysis_text=analyzer.read_text()
    assert host_text.count('Ready(diagnostic)')==1 and 'd.readyCards>=6' in host_text
    assert not re.search(r'''["']ready["']''',analysis_text),'Analyzer unexpectedly consumes Ready summary'
    generated=P/'instrumentation/post-run/Assets/FiniteWallOcclusion01/Generated'
    assets=[]
    for name in ('ReferenceWall','ReferenceFloor','MovingBlackPanel'):
        path=generated/(name+'Charts.asset');text=path.read_text();charts=text.split('  charts:\n',1)[1].split('  contentVersion:',1)[0]
        chart_count=len(re.findall(r'^  - stableId:',charts,re.M));ordinals=re.findall(r'^    triangleIndices: ([0-9a-fA-F]+)$',charts,re.M)
        assert chart_count==1 and len(ordinals)==1
        triangles=list(struct.unpack('<2I',bytes.fromhex(ordinals[0])));assert triangles==[0,1]
        capture=text.split('  m_SubMeshes:\n',1)[1].split('  m_Shapes:',1)[0]
        assert len(re.findall(r'^  - serializedVersion:',capture,re.M))==1 and '    indexCount: 6\n' in capture
        assets.append(dict(name=name,sha256=sha(path),charts=chart_count,triangleOrdinals=triangles,captureSubmeshes=1,captureIndices=6))
    frames=[json.loads(line) for line in (P/'native/frames.jsonl').read_text(encoding='utf-8-sig').splitlines()]
    assert len(frames)==56 and all(row['ready'] is False for row in frames)
    expected={'hardwareBackend':True,'hardwareMeshes':3,'hardwareFallbacks':0,'hardwareMaterialUnknownRecords':0,
        'hardwareMaterialStatus':'Uploads and both consumers bound; GPU completion unproven','publishedInstances':3,
        'warmingInstances':0,'pendingCapacity':0,'chartedOwners':3,'approximateOwners':0,'readyCards':3,
        'requiredSurfaceCards':3,'pendingCards':0,'lightSelected':1,'lightCapacityOmitted':-1}
    assert all(all(row['diagnostics'][key]==value for key,value in expected.items()) for row in frames)
    report=load(P/'analysis-first.json');assert report['passed'] and report['checks']==1512 and not report['unknown'] and not report['uncovered']
    execution=load(P/'execution-receipt.json');assert execution['passed'] and execution['allFramesSourceReady'] is False and execution['restored']
    for logical,x in ((32,.25),(44,20)):
        assert report['frames'][logical]['panel']['current'] and report['frames'][logical]['panel']['x']==x
    product_sources=['Runtime/HybridLumenGISurfaceCharts.cs','Runtime/HybridLumenGISurfaceCache.cs','Runtime/HybridLumenGIRendererFeature.cs']
    manifest=load(P/'instrumentation/manifest.json')
    assert all(sha(ROOT/path)==manifest['productSourceSha256'][path] for path in product_sources)
    record=dict(audit='post-run readiness-summary defect qualification; metadata/source only',passed=True,
        defect=dict(file='LocalComparison/Harness/FiniteWallOcclusionScene.cs',line=132,expression='d.readyCards>=6',
                    cause='Harness author conflated six mesh triangles with six cards. Each pair of adjacent coplanar triangles bakes into one chart/card.',
                    originalLoggedReady=False,originalLoggedFalseFrames=56,originalValuesPreserved=True),
        chartAssets=assets,totalActualCharts=3,totalSourceTriangles=6,
        productReason='BakeTriangles merges adjacent same-submesh triangles within the seed normal cone when projected interiors do not overlap; SurfaceCache requests asset.Charts.Length cards.',
        actualAllFrameCounters=expected,all56FramesSatisfyRecordedCardCoverage=True,
        correctedInterpretation='readyCards==requiredSurfaceCards==3 and pendingCards==0; CPU recorded readiness only, not a GPU fence or broad quality claim.',
        independence=dict(hostReadyOnlySerializedAtLines=[151,152],hostControlGate='FixedScope(diagnostic)',
                          analyzerReadsReadySummary=False,originalAcceptanceChanged=False,originalAnalysisPassed=True,
                          physicalChecks=1512,unknown=0,uncovered=0,sourcePoseCurrentAtEvents=[32,44]),
        conclusion='The summary boolean is wrong. The independent finite source/geometry/ray/history acceptance remains supported; do not reinterpret or overwrite original ready=false or allFramesSourceReady=false.',
        limits='No GPU rerun, no original analyzer rerun, no radiance payload decoded by this audit, no claim that readiness counters themselves prove per-ray hits or whole-scene dynamic quality.',
        sources={path:sha(ROOT/path) for path in product_sources},
        evidence={path:sha(P/path) for path in ('source-freeze.json','native/frames.jsonl','native/scene-result.json','analysis-first.json','execution-receipt.json')},
        frozenHostSha256=sha(host),frozenAnalyzerSha256=sha(analyzer))
    target.write_text(json.dumps(record,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(dict(passed=True,totalActualCharts=3,sourceTriangles=6,loggedFalseFrames=56,originalAcceptanceChanged=False,auditSha256=sha(target))))
if __name__=='__main__':main()
