"""Independent finite geometry/admission/upload checks; no image oracle."""
import argparse,base64,importlib.util,itertools,json,math,re,struct,traceback
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];H=ROOT/'LocalComparison/Harness'
PACKAGE=ROOT/'LocalComparison/Review/world-light-relevance-01';BUILD=Path('I:/Unity test/Comparison/Builds/WorldLightRelevance30')
spec=importlib.util.spec_from_file_location('existing',H/'analyze-material-event.py');existing=importlib.util.module_from_spec(spec);spec.loader.exec_module(existing)
existing.PACKAGE=PACKAGE;existing.BUILD=BUILD;existing.smoke.PACKAGE=PACKAGE;existing.smoke.BUILD=BUILD
smoke=existing.smoke;load=smoke.load;save=smoke.save;sha=smoke.sha
def vec(x):return [x[k] for k in ['x','y','z']]
def inside(lo,hi,p):return all(a<=c<=b for a,b,c in zip(lo,hi,p))
def run():
    native=PACKAGE/'native-window';report={'admissionUploadVerified':False,'fullProductionAccepted':False,
        'scope':'single fixed64frame DXR admission/upload, no image, radiometry, performance or additional platform acceptance'}
    try:
        report['buildProductsManifestSha256']=smoke.verify_products()
        exit=load(native/'native-exit.json');report['nativeExit']=exit;report['nativeLogHits']=smoke.hits(native/'player.log')
        assert exit['exitCode']==0 and not exit['watchdogTerminated'] and not report['nativeLogHits'],'Native exit/resource failure'
        events=[s for s in (native/'player.log').read_text(encoding='utf-8-sig',errors='replace').splitlines() if s.startswith('HybridLumenGI shutdown ')]
        names=['begin','owners withdrawn','idle fence submitted','completed owner destroyed','generic drain complete']
        indices=[next(i for i,e in enumerate(events) if e.startswith('HybridLumenGI shutdown '+name+':')) for name in names]
        assert indices==sorted(indices) and 'outside=True' in events[indices[0]] and 'generic drain complete:' in events[-1]
        for field in ['owned','pending','unknown','failed','failedWithdrawals','materialBytes','arenaBytes','deformationBytes','deformationJobs','deformationCleanupFailed']:
            assert re.search(r'(?:, |: )'+field+r'=0(?:,|$)',events[-1]),field
        report['shutdownEvents']=events
        runs=list((native/'run').glob('*/run.json'));assert len(runs)==1,'Unique run required'
        folder=runs[0].parent;meta=load(runs[0]);frames=smoke.lines(folder/'frames.jsonl')
        assert meta['requestedFrames']==meta['renderedFrames']==64 and meta['errors']==meta['captures']==0
        assert meta['api']=='Direct3D12' and meta['width']==640 and meta['height']==360 and meta['status']=='incomplete-probe'
        assert [f['logicalFrame'] for f in frames]==list(range(64))
        assert all(frames[i]['engineFrame']==frames[0]['engineFrame']+i for i in range(64))
        result=load(folder/'light-result.json');assert result['receipts']==64 and result['bindings']==1 and result['pending']==0 and result['completed'] and not result.get('failure')
        inputs=load(folder/'light-inputs.json');bound=load(folder/'binding.json');upload=load(folder/'upload.json')
        assert inputs['maximumFrames']==64 and inputs['capacity']==2 and inputs['spatialSelection']
        assert all(f['cameraPosition']==inputs['cameraPosition'] and f['cameraRotation']==inputs['cameraRotation'] and f['doorLocalPosition']==inputs['doorPosition'] for f in frames)
        assert all(f['lights']==frames[0]['lights'] and f['projection']==frames[0]['projection'] for f in frames)
        assert bound['logical']==63 and bound['engine']==frames[-1]['engineFrame'] and bound['hardware'] and bound['domainValid']
        assert [bound[k] for k in ['candidates','outside','selected','omitted','boundCount']]==[3,2,1,0,1]
        diagnostics=json.loads(frames[-1]['diagnosticsJson'])
        assert diagnostics['lightDomainValid'] and [diagnostics[k] for k in ['lightCandidates','lightOutsideDomain','lightSelected','lightCapacityOmitted']]==[3,2,1,0]
        assert all(upload[k]==v for k,v in bound.items() if k not in ['gpuCompleted','gpuSha256'])
        assert upload['gpuCompleted'] and sha(folder/upload['gpuFile'])==upload['gpuSha256']
        blob=(folder/upload['gpuFile']).read_bytes();assert bound['bufferCount']==32 and bound['bufferStride']==80 and len(blob)==2560
        source=bound['sources'];assert len(source)==3 and [s['id'] for s in source]==[s['id'] for s in inputs['lights']]
        assert [s['role'] for s in source]==['outside-0','outside-1','relevant']
        packed=[base64.b64decode(s['packedBase64'],validate=True) for s in source];assert all(len(p)==80 for p in packed)
        # The active GPU prefix must exactly match the original native TryPack bytes.
        # The unused tail has no validity claim; product uploads only the active prefix.
        assert blob[:80]==packed[2]
        for frozen,current in zip(inputs['lights'],source):
            assert frozen['position']==current['position'] and frozen['range']==current['range']
            # Lighting-layer policy may change the four uint fields only.
            assert base64.b64decode(frozen['packedBase64'])[:64]==base64.b64decode(current['packedBase64'])[:64]
        lo,hi=vec(bound['domainMin']),vec(bound['domainMax']);assert all(math.isfinite(v) for v in lo+hi) and all(a<=b for a,b in zip(lo,hi))
        matrix=bound['inverseGpuVP'];oracle=[]
        # Independent double unprojection samples cover boundary/interior evidence;
        # source interval proof, not these samples alone, establishes all-pixel coverage.
        for p in itertools.product([-1,0,1],[-1,0,1],[0,.5,1]):
            h=[sum(matrix[f'e{r}{c}']*v for c,v in enumerate((*p,1))) for r in range(4)]
            assert h[3]>0;world=[v/h[3] for v in h[:3]];assert inside(lo,hi,world),'Screen position outside recorded domain'
        assert bound['extents'],'No prepared world extent evidence'
        for e in bound['extents']:
            assert e['published'] or e['warming']
            assert inside(lo,hi,vec(e['traversalMin'])) and inside(lo,hi,vec(e['traversalMax']))
            if e['cards']>0:assert inside(lo,hi,vec(e['captureMin'])) and inside(lo,hi,vec(e['captureMax']))
        for i,p in enumerate(packed):
            values=struct.unpack('<16f4I',p);position=values[:3];radius=values[7]
            assert values[3]==1 and radius==10
            nearest=sum(max(a-x,x-b,0)**2 for a,b,x in zip(lo,hi,position));scale=max(1,radius,*map(abs,position),*map(abs,lo),*map(abs,hi))
            # Input radius10 has exact binary32 square100; conservative roundoff band.
            safe_radius=radius+64*(2**-24)*scale
            oracle.append({'role':source[i]['role'],'nearestDistance':math.sqrt(nearest),'range':radius,'safeRadius':safe_radius})
            if i<2:assert nearest>safe_radius**2,'Remote light exclusion not independently proven'
            else:
                assert inside(lo,hi,vec(inputs['targetPoint']))
                assert sum((a-b)**2 for a,b in zip(position,vec(inputs['targetPoint'])))<radius**2
                assert nearest<=radius**2,'Target-covering light unexpectedly outside'
        report.update(admissionUploadVerified=True,runId=folder.name,renderedFrames=64,captures=0,actualHardware=True,
            domain={'minimum':lo,'maximum':hi,'preparedExtents':len(bound['extents'])},independentRangeOracle=oracle,
            actualLightCountBindingArgument=bound['boundCount'],gpuActivePrefixBytes=80,gpuUploadSha256=upload['gpuSha256'],
            countEvidence=bound['countEvidence'],normalExitAccepted=True)
    except Exception as e:report.update(failure=str(e),traceback=traceback.format_exc())
    save(native/'analysis.json',report);print(json.dumps(report));return report['admissionUploadVerified']

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('action',choices=['build','products','run']);a=p.parse_args()
    if a.action=='build':ok=existing.build()
    elif a.action=='products':print(smoke.verify_products());ok=True
    else:ok=run()
    raise SystemExit(0 if ok else 1)
