"""Read the three predeclared resize observations; no new capture or raw claims."""
import argparse, json
from pathlib import Path
import numpy as np

def read(p): return json.loads(p.read_text(encoding='utf-8-sig'))
def need(value, message):
    if not value: raise ValueError(message)
def histogram(a):
    v, n = np.unique(a, return_counts=True)
    return {str(float(x)): int(y) for x,y in zip(v,n)}
def plane(folder, item):
    need(item['format']=='rgba32f-le' and item['rowOrder']=='top-to-bottom', 'Unsupported recorded plane')
    return np.fromfile(folder/item['file'], dtype='<f4').reshape(item['height'],item['width'],4)

def analyze(area):
    root=area/'run'; host=read(root/'host-result.json')
    run=read(root/'legacy/run.json' if (root/'legacy/run.json').exists() else Path(host['runFile']))
    exit=read(area/'setup/native-exit.json'); series=read(root/'series.json')
    need(exit['exitCode']==0 and host['status']=='collected' and not host['error'], 'Incomplete normal observation')
    outer=read(root/'result.json'); need(outer['status']=='collected' and outer['restored'], 'Editor did not restore')
    need(run['status']=='failed' and run['renderedFrames']==105 and run['failures']==run['backendMismatches']==0, 'Not the intentional105-frame original720 prefix')
    rows=series['frames']; need(len(rows)==105, 'Different source count')
    need([r['logicalFrame'] for r in rows]==list(range(105)), 'Logical source gap')
    for i,r in enumerate(rows):
        need(r['returned'] and r['workFrame']==i and r['diagnostics']['hardwareBackend'] and r['diagnostics']['transportRecordedEngineFrame']==r['engineFrame'], 'Source/actual backend mismatch')
        if i: need(r['engineFrame']==rows[i-1]['engineFrame']+1 and r['giFrame']==rows[i-1]['giFrame']+1, 'Engine/GI source gap')
        need(all(r[k] for k in ['sameCamera','sameTarget','sameOutput','sameRenderRequest','sameRequestDestination','targetCreated','settingsUnchanged']), 'Live camera/target/request/settings reference differs')
        expected=(1918,1078) if i<=95 else (1919,1079)
        need((r['width'],r['height'])==(r['sequenceWidth'],r['sequenceHeight'])==expected, 'Live dimensions differ')
        need(r['cameraPosition']==rows[0]['cameraPosition'] and r['cameraRotation']==rows[0]['cameraRotation'] and r['doorLocalPosition']==rows[0]['doorLocalPosition'] and r['lightsEnabled'], 'Static source pose/light stage differs')
    need(host['eventSeen'] and host['sameTargetAfterEvent'] and host['sameRequestAfterEvent'] and host['createSucceeded'] and host['eventEngineFrame']==rows[95]['engineFrame'] and host['eventTargetIdBefore']==host['eventTargetIdAfter'], 'In-place event association differs')
    need(host['referenceDrained'] and host['legacyReadbacksDrained'] and host['ticketCount']==3 and host['allCapturesSucceeded'], 'Capture ownership did not drain normally')
    # The Host records live references and actual target sizes. The completed
    # Capture metadata independently provides full/GI texture dimensions below.
    captures={}; arrays={}; folder=root/'signals'
    for f in (95,96,97):
        meta=read(folder/f'frame-{f:04}-capture.json')
        need(meta['status']=='complete' and not meta['error'] and meta['readbacksCompleted'] and meta['retainedBytes']==0, 'Incomplete capture '+str(f))
        need(meta['logicalFrame']==meta['workFrame']==f and meta['engineFrame']==rows[f]['engineFrame'], 'Capture/source association '+str(f))
        support={p['role']:p for p in meta['support']}; samples={p['signalId']:p for p in meta['samples']}
        m=plane(folder,support['moments']); g=plane(folder,support['geometry']); dmeta=samples['filteredD']
        size=(dmeta['width'],dmeta['height'])
        need(dmeta['status']=='available' and m.shape==g.shape==(size[1],size[0],4) and (meta['composite']['giSize']['x'],meta['composite']['giSize']['y'])==size, 'GI plane/receipt dimensions disagree')
        expected=(1918,1078) if f==95 else (1919,1079)
        need((support['material']['width'],support['material']['height'])==expected, 'Actual full material dimensions differ')
        valid=np.fromfile(folder/dmeta['validity']['file'],dtype=np.uint8).reshape(size[1],size[0])>0
        ng=np.isfinite(g).all(axis=-1)&(g[:,:,2]>0)
        age=m[:,:,2]; finite=np.isfinite(m).all(axis=-1)
        arrays[f]=(age,valid,ng,finite)
        captures[str(f)]={'engineFrame':meta['engineFrame'],'camera':meta['cameraInstanceId'],'feature':meta['featureInstanceId'],'full':list(expected),'gi':list(size),
            'totalPixels':int(age.size),'nonfiniteMoments':int((~finite).sum()),'allPixelAgeDistribution':histogram(age),
            'filteredKnownPixels':int(valid.sum()),'knownNgPixels':int(ng.sum()),'filteredKnownNgPixels':int((valid&ng).sum()),
            'filteredKnownNgAgeDistribution':histogram(age[valid&ng]),'zeroAgePixels':int((age==0).sum())}
    need(len({(v['camera'],v['feature']) for v in captures.values()})==1, 'Capture Camera/Feature changed')
    a0,v0,n0,f0=arrays[95]; a1,v1,n1,f1=arrays[96]; a2,v2,n2,f2=arrays[97]
    maximum=json.loads(host['actualSettingsJson'])['maxHistory']
    mature=int((v0&n0&f0&(a0==maximum)).sum()); initial=int((f1&(a1==1)).sum()); resumed=int((f2&(a2==2)).sum())
    first_bad=int((~f1|(a1<0)|(a1>1)).sum()); next_bad=int((~f2|(a2<0)|(a2>2)).sum())
    qualified=bool(mature and initial and resumed)
    intended=all(v['gi']==[959,539] for v in captures.values())
    status=('finite-full-resize-history-reset-observed' if qualified and first_bad==next_bad==0 else ('age-bound-not-met' if first_bad or next_bad else 'insufficient-history-observation')) if intended else 'insufficient-unchanged-GI-contract'
    return {'status':status,'intendedUnchangedGiCaseQualified':intended,'product':'Release122 same-source7c08327; no Runtime change',
        'scope':'Same-Camera/same-RT-reference full1918x1078 ->1919x1079 was observed; actual GI changed820x460 ->819x460, so the intended unchanged-GI case is NOT qualified. No raw-fresh/fullG3/edge coverage/Player/performance claim',
        'preparationMismatch':'The initial parser expected959x539 and stopped. Actual budget-constrained GI sizes are retained without changing input, thresholds or promoting this to the unchanged-GI contract.',
        'captures':captures,'maturePreEventKnownNgPixels':mature,'firstPostAgeOnePixels':initial,'nextPostAgeTwoPixels':resumed,
        'firstPostAgeBoundViolations':first_bad,'nextPostAgeBoundViolations':next_bad,
        'actualJointResizeAgeBoundsSatisfied':bool(qualified and first_bad==next_bad==0),
        'validityMeaning':'FilteredD/Ng validity is not a current raw measurement certificate. Zero ages remain unknown; newly accumulating domain is reported, not all pixels required to accumulate.',
        'nativeExit':exit,'host':host}

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('area',type=Path);p.add_argument('output',type=Path);a=p.parse_args();a.output.mkdir(parents=True,exist_ok=False)
    try: result=analyze(a.area)
    except (OSError,ValueError,KeyError,TypeError,IndexError) as e: result={'status':'insufficient-input-or-record','error':str(e)}
    (a.output/'result.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({k:v for k,v in result.items() if k!='host'},ensure_ascii=False))
