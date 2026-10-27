"""Archive the finite GPU package and derive diagnostics from actual readbacks."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import numpy as np

root = Path(__file__).resolve().parents[2]

def transition_report():
    source=Path('I:/Unity test/Comparison/Evidence/local-denoise-03')
    output=root/'LocalComparison/Review/denoise-03'
    reports={label:json.loads((source/label/'gpu-transition.json').read_text()) for label in ['baseline','candidate']}
    for label,r in reports.items():
        assert r['passed'] and all(x['passed'] for x in r['cases']),r.get('error')
        shutil.copytree(source/label,output/label,dirs_exist_ok=True)
        shutil.copy2(Path('I:/Unity test/Logs')/f'Denoise03-{label}.log',output/f'Denoise03-{label}.log')
    def read(label,kernel,name,frame,stage,channel='output'):
        return np.fromfile(source/label/'raw'/f'{kernel}-{name}-{frame}-{stage}-{channel}.rgba32f',dtype='<f4').reshape(17,17,4)
    def error(a,reference):
        d=a[:,:,:3].astype(np.float64)-reference[:,:,None]
        return {'rmse':float(np.sqrt(np.mean(d*d))),'meanBias':float(d.mean()),'maxAbs':float(np.abs(d).max()),
                'edgeBandRmse':float(np.sqrt(np.mean(d[:,7:11,:]**2))),'interiorRmse':float(np.sqrt(np.mean(d[7:10,7:10,:]**2)))}
    result={'baselineCommit':'5eb1058','onlyCandidate':'sigma blend over existing1..4 history window',
        'formatDeltaCriterion':0.001,'productionAccepted':False,'results':{},'stageCounts':{k:len(v['cases']) for k,v in reports.items()}}
    yy,xx=np.indices((17,17));references={'fixed-checker':np.where((xx+yy)%2==0,.25,.75),
        'changing-noise':np.full((17,17),.5),'signal-edge':np.where(xx<9,.5,3.5)}
    for kernel in ['CSTemporal','CSTemporalIdentity']:
        evidence={};result['results'][kernel]=evidence
        matching=True;max_initial_mature_difference=0
        for row in reports['baseline']['cases']:
            if row['kernel']!=kernel:continue
            n,f,s=row['name'],row['frame'],row['stage']
            a,b=read('baseline',kernel,n,f,s),read('candidate',kernel,n,f,s)
            ma,mb=read('baseline',kernel,n,f,s,'moments'),read('candidate',kernel,n,f,s,'moments')
            assert np.isfinite(a).all() and np.isfinite(b).all() and np.isfinite(ma).all() and np.isfinite(mb).all()
            matching &= bool(np.array_equal(ma,mb) and (s!='temporal' or np.array_equal(a,b)) and np.array_equal(a[:,:,3],b[:,:,3]))
            if f==1 or (n in references or n.startswith('parallel')) and f>=4:
                max_initial_mature_difference=max(max_initial_mature_difference,float(np.abs(a-b).max()))
        evidence['recordedTemporalMomentsConfidenceExactlyMatch']=matching
        evidence['firstAndMatureFilterMaxAbsDifference']=max_initial_mature_difference
        for signal,reference in references.items():
            by_label={}
            for label in reports:
                frames=[read(label,kernel,signal,f,'filter-4') for f in range(1,9)]
                differences=np.stack([np.abs(frames[i][:,:,:3]-frames[i-1][:,:,:3]) for i in range(1,8)])
                index=np.unravel_index(np.argmax(differences),differences.shape)
                by_label[label]={'maxChange3to4':float(differences[2].max()),'maxRecoveryAdjacentChange':float(differences.max()),
                    'maxAt':{'fromFrame':int(index[0]+1),'toFrame':int(index[0]+2),'x':int(index[2]),'y':int(index[1]),'channel':int(index[3])},
                    'referenceErrors':[error(a,reference) for a in frames],
                    'windowRmse':float(np.sqrt(np.mean([(a[:,:,:3].astype(np.float64)-reference[:,:,None])**2 for a in frames]))),
                    'centerSeries':[float(a[8,8,0]) for a in frames]}
            evidence[signal]=by_label
        checker=evidence['fixed-checker'];base,candidate=checker['baseline'],checker['candidate']
        evidence['necessaryContinuityPassed']=matching and max_initial_mature_difference<=.001 and \
            base['maxChange3to4']-candidate['maxChange3to4']>.001 and \
            base['maxRecoveryAdjacentChange']-candidate['maxRecoveryAdjacentChange']>.001
        evidence['R1matchedControl']={}
        for label in reports:
            evidence['R1matchedControl'][label]=[]
            for f in range(1,9):
                d=read(label,kernel,'parallel-bright',f,'filter-4')[:,:9,:3]-read(label,kernel,'parallel-control',f,'filter-4')[:,:9,:3]
                evidence['R1matchedControl'][label].append({'frame':f,'darkSideMeanResponse':float(d.mean()),'darkSideMaxResponse':float(d.max()),'centerResponse':float(d[8,8,0])})
    result['necessaryContinuityPassed']=all(v['necessaryContinuityPassed'] for v in result['results'].values())
    result['interpretation']='Continuity is necessary, not sufficient. Fixed checker reference is itself for detail; only changing noise has uniform0.5 truth. R1 is matched signal sensitivity, not automatic physical leakage.'
    for kind in ['baseline','candidate']:
        result[kind+'ShaderSha256']=hashlib.sha256((output/f'HybridLumenGIKernels.{kind}.hlsl').read_bytes()).hexdigest()
    (output/'paired-synthetic.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
    print(json.dumps({'necessaryContinuityPassed':result['necessaryContinuityPassed'],
        'kernel':'CSTemporal','stageCounts':result['stageCounts'],
        'fixedChecker':{k:{kk:vv for kk,vv in v.items() if kk not in ['referenceErrors']} for k,v in result['results']['CSTemporal']['fixed-checker'].items()},
        'changingNoiseWindowRmse':{k:v['windowRmse'] for k,v in result['results']['CSTemporal']['changing-noise'].items()},
        'signalEdgeWindowRmse':{k:v['windowRmse'] for k,v in result['results']['CSTemporal']['signal-edge'].items()}},indent=2))

def scene_report():
    evidence=Path('I:/Unity test/Comparison/Evidence/local-denoise-03')
    output=root/'LocalComparison/Review/denoise-03';load=lambda p:json.loads(p.read_text(encoding='utf-8-sig'))
    paths={k:next((evidence/('scene-'+k)).glob('*/run.json')).parent for k in ['baseline','candidate']}
    def texture(label,frame,channel):
        filename=f'frame-{frame:04d}.rgba32f' if channel=='final' else f'denoise-{frame:04d}-{channel}.rgba32f'
        shape=(360,640,4) if channel=='final' else (180,320,4)
        a=np.fromfile(paths[label]/filename,dtype='<f4').reshape(shape);assert np.isfinite(a).all(),filename
        return a
    result={'scope':'One static door-stop recovery event; no physical ground truth, production quality or performance acceptance.',
        'runs':{},'sourcePaired':True,'frameChecks':[],'coverage':[],'cohorts':[]}
    settings={k:load(p/'feature.json')['settings'] for k,p in paths.items()};assert settings['baseline']==settings['candidate']
    for k,p in paths.items():
        run=load(p/'run.json');tap=load(p/'denoise-raw-summary.json')
        assert run['status']=='incomplete-probe' and run['renderedFrames']==198 and run['errors']==0 and tap['passed']
        dest=output/('scene-'+k);dest.mkdir(exist_ok=True)
        receipts=[json.loads(x) for x in (p/'denoise-raw-receipts.jsonl').read_text().splitlines()]
        assert len(receipts)==21 and sorted(r['logicalFrame'] for r in receipts)==list(range(176,197))
        assert len(set(r['cameraId'] for r in receipts))==1
        result['runs'][k]={'path':str(p),'run':run,'tap':tap,'rawReceipts':receipts}
        for name in ['feature.json','run.json','frames.jsonl','denoise-raw-summary.json','denoise-raw-receipts.jsonl','unity-log.jsonl']:
            shutil.copy2(p/name,dest/name)
        raw_manifest=[]
        for f in range(176,197):
            for c in ['raw','history','moments','geometry','material','final']:
                name=f'frame-{f:04d}.rgba32f' if c=='final' else f'denoise-{f:04d}-{c}.rgba32f'
                src=p/name;raw_manifest.append({'file':name,'sha256':hashlib.sha256(src.read_bytes()).hexdigest(),'bytes':src.stat().st_size})
                if f in [179,180,181,182,196] and c in ['raw','history','moments','final']:shutil.copy2(src,dest/name)
            shutil.copy2(p/f'frame-{f:04d}.json',dest/f'frame-{f:04d}.json')
            if f in [179,180,181,182,196]:shutil.copy2(p/f'frame-{f:04d}.png',dest/f'frame-{f:04d}.png')
        (dest/'raw-manifest.json').write_text(json.dumps(raw_manifest,indent=2),encoding='utf-8')
        shutil.copy2(Path('I:/Unity test/Logs')/f'Denoise03-scene-{k}.log',output/f'Denoise03-scene-{k}.log')
    for f in range(176,197):
        states={k:load(p/f'frame-{f:04d}.json') for k,p in paths.items()}
        for field in ['logicalFrame','engineFrame','cameraPosition','cameraRotation','doorLocalPosition','projection','lights']:assert states['baseline'][field]==states['candidate'][field],(f,field)
        row={'frame':f,'maxAbsStageDifference':{}}
        for c in ['raw','history','moments','geometry','material']:
            a,b=texture('baseline',f,c),texture('candidate',f,c);difference=float(np.abs(a-b).max());row['maxAbsStageDifference'][c]=difference
            result['sourcePaired'] &= difference==0
        for k in paths:
            d=json.loads(states[k]['diagnosticsJson']);assert d['exactSoftwareGeometry'] and d['receiverIdentityEnabled'],(f,k)
            receipt=next(r for r in result['runs'][k]['rawReceipts'] if r['logicalFrame']==f)
            # Work.frame is captured before RendererFeature increments state.frame
            # at line907; post-graph diagnostics expose the incremented counter.
            assert receipt['giFrame']+1==d['frame'] and receipt['engineFrame']==states[k]['engineFrame'] and (receipt['width'],receipt['height'])==(320,180)
        before_receipt=next(r for r in result['runs']['baseline']['rawReceipts'] if r['logicalFrame']==f)
        after_receipt=next(r for r in result['runs']['candidate']['rawReceipts'] if r['logicalFrame']==f)
        assert before_receipt['giFrame']==after_receipt['giFrame']
        result['frameChecks'].append(row)
    assert result['sourcePaired'],'Do not attribute mismatched upstream data to filter change'
    weights=np.array([.2126,.7152,.0722])
    for start in range(179,194):
        g0=texture('baseline',start,'geometry');m0=texture('baseline',start,'material');mask=np.ones((180,320),bool)
        for offset in range(4):
            f=start+offset;mom=texture('baseline',f,'moments');history=texture('baseline',f,'history')
            mask &= (mom[:,:,2]==offset+1)&(history[:,:,3]>0)&np.all(texture('baseline',f,'geometry')==g0,axis=2)&np.all(texture('baseline',f,'material')==m0,axis=2)
        count=int(mask.sum());door=np.zeros_like(mask);door[72:125,170:200]=mask[72:125,170:200]
        result['coverage'].append({'start':start,'wholeImagePixels':count,'doorPixels':int(door.sum())})
        if not door.any():continue
        ys,xs=np.where(door);fy,fx=2*ys+1,2*xs+1
        np.save(output/f'door-cohort-{start}-mask.npy',door)
        cohort={'start':start,'giPixelCount':int(door.sum()),'fullPixelSampling':'(2*x+1,2*y+1), the actual GI source full-pixel centers','metrics':{},'finalPairDifference':[]}
        for label in paths:
            values=[];rows=[]
            for f in range(start,197):
                final=texture(label,f,'final');y=final[:,:,:3].astype(np.float64)@weights;rgb=final[fy,fx,:3].astype(np.float64);values.append(rgb)
                residual=y[fy,fx]-.25*(y[fy-1,fx]+y[fy+1,fx]+y[fy,fx-1]+y[fy,fx+1])
                z=texture(label,f,'moments')[ys,xs,2]
                rows.append({'frame':f,'meanY':float((rgb@weights).mean()),'spatialResidualRms':float(np.sqrt(np.mean(residual**2))),
                    'historyMin':float(z.min()),'historyMax':float(z.max())})
            deltas=[]
            for i in range(1,len(values)):
                diff=values[i]-values[i-1];deltas.append({'fromFrame':start+i-1,'toFrame':start+i,'rgbRms':float(np.sqrt(np.mean(diff**2))), 'maxAbsRgb':float(np.abs(diff).max())})
            cohort['metrics'][label]={'frames':rows,'adjacentChanges':deltas,'recoveryMaxAbsRgb':max(r['maxAbsRgb'] for r in deltas[:7]),'jump3to4':deltas[2]}
        for f in range(start,197):
            d=texture('candidate',f,'final')[fy,fx,:3]-texture('baseline',f,'final')[fy,fx,:3]
            cohort['finalPairDifference'].append({'frame':f,'maxAbsRgb':float(np.abs(d).max()),'meanAbsRgb':float(np.abs(d).mean())})
        result['cohorts'].append(cohort)
    result['targetCovered']=bool(result['cohorts'])
    result['limitations']=['Spatial high-frequency residual is not reference noise error; the real event has no path-traced ground truth.',
        'Raw receipt GI frame is pre-increment Work.frame; diagnostics frame is post-increment state.frame (offset1 verified from RendererFeature).',
        'Static pose and identical geometry establish alignment for selected recovery pixels, not arbitrary moving-frame correspondence.',
        'Subsequent equality rules out persistent candidate-vs-baseline differences in this cohort; it does not prove either baseline lacks absolute ghosting.',
        'Shutdown native allocation warnings persist and remain a separate open work item.']
    (output/'paired-scene.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
    print(json.dumps({'sourcePaired':result['sourcePaired'],'targetCovered':result['targetCovered'],'cohorts':[
        {'start':c['start'],'pixels':c['giPixelCount'],'metrics':{k:{'jump3to4':v['jump3to4'],'recoveryMaxAbsRgb':v['recoveryMaxAbsRgb']} for k,v in c['metrics'].items()},'finalPairDifference':c['finalPairDifference'][:6]} for c in result['cohorts']]},indent=2))

if '--scene' in sys.argv:
    scene_report()
    sys.exit(0)

if '--transition' in sys.argv:
    transition_report()
    sys.exit(0)

source = Path('I:/Unity test/Comparison/Evidence/local-denoise-02')
output = root/'LocalComparison/Review/denoise-02'
load = lambda p: json.loads(p.read_text(encoding='utf-8-sig'))
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
report = load(source/'gpu-contracts.json')
assert report['passed'], report['error']
assert all(r['passed'] for r in report['cases'])
for name in ['gpu-contracts.json', 'legacy-regression.json']:
    shutil.copy2(source/name, output/name)
shutil.copy2(source/'actual-formats.csv', output/'actual-formats.csv')
for kernel in ['CSTemporal', 'CSTemporalIdentity']:
    for channel in ['output', 'moments']:
        a=np.fromfile(source/'raw-contracts'/f'{kernel}-unknown-center-1-temporal-{channel}.rgba32f',dtype='<f4').reshape(17,17,4)
        assert np.all(a[8,8]==0), (kernel,channel)
for name in ['baseline', 'raw-contracts']:
    shutil.copytree(source/name, output/name, dirs_exist_ok=True)
for stem in ['Denoise02-baseline-retry', 'Denoise02-contracts-final', 'Denoise02-formats']:
    shutil.copy2(Path('I:/Unity test/Logs')/(stem+'.log'), output/(stem+'.log'))
product = []
for item in load(root/'Tests/runtime-validation-results.json')['productSources']:
    path = item['file']
    digest = sha(root/path)
    assert digest == sha(Path('I:/Unity test/Project/Assets/HybridLumenGI')/path), path
    product.append({'file':path,'sha256':digest})
patch = subprocess.run(['git','diff','--','Runtime','Tests/StandaloneScreenBudget/Program.cs.txt','Documentation/ValidationSequence.md'], cwd=root,check=True,capture_output=True).stdout
(output/'product.patch').write_bytes(patch)
diagnostics = {}
baseline_values=[]
for frame in range(1,6):
    h=np.fromfile(source/'baseline'/f'frame-{frame}-history.rgba32f',dtype='<f4').reshape(17,17,4)
    m=np.fromfile(source/'baseline'/f'frame-{frame}-moments.rgba32f',dtype='<f4').reshape(17,17,4)
    baseline_values.append({'frame':frame,'allFinite':bool(np.isfinite(h).all() and np.isfinite(m).all()),
        'radianceMin':float(h[:,:,:3].min()),'radianceMax':float(h[:,:,:3].max()),
        'secondMomentMin':float(m[:,:,1].min()),'secondMomentMax':float(m[:,:,1].max()),
        'historyMin':float(m[:,:,2].min()),'historyMax':float(m[:,:,2].max()),'expectedSecondMoment':1000000})
for kernel in ['CSTemporal','CSTemporalIdentity']:
    diagnostics[kernel] = {}
    for boundary in ['noise','coplanar-edge','parallel-plane','material-edge','normal-edge']:
        values = []
        for frame in range(1,6):
            rows = [r for r in report['cases'] if r['kernel']==kernel and r['name']==boundary and r['frame']==frame]
            data = {}
            for row in rows:
                a=np.fromfile(source/'raw-contracts'/(row['rawOutput']+'-output.rgba32f'),dtype='<f4').reshape(17,17,4)
                m=np.fromfile(source/'raw-contracts'/(row['rawOutput']+'-moments.rgba32f'),dtype='<f4').reshape(17,17,4)
                assert np.isfinite(a).all() and np.isfinite(m).all()
                # This center window is inside the full 1+2+4 support. x=8 is
                # the last dark-side sample; x=9 starts the synthetic boundary.
                roi=a[7:10,7:9,0].astype('float64')
                data[row['stage']]={'center':row['center'][0], 'darkWindowMean':float(roi.mean()),
                    'darkWindowResidualRms':float(np.sqrt(np.mean((roi-roi.mean())**2))),
                    'history':row['centerMoments'][2], 'temporalVariance':row['temporalVariance'],
                    'spatialVariance':row['spatialVariance'], 'sigma':row['effectiveSigma']}
            data['darkWindowFilterIncrement']=data['filter-4']['darkWindowMean']-data['temporal']['darkWindowMean']
            values.append(data)
        diagnostics[kernel][boundary]={'frames1to5':values,
            'centerFilterChange3to4':values[3]['filter-4']['center']-values[2]['filter-4']['center']}
summary={'revision':'local-development-denoise-02-contracts','baselineCommit':'7d33d02',
    'contractRows':len(report['cases']), 'legacyCases':len(load(source/'legacy-regression.json')['cases']),
    'baselineActualReadbacks':baseline_values,
    'harnessSource':{'file':'LocalComparison/Harness/DenoiseRegressionEditor.cs','sha256':sha(root/'LocalComparison/Harness/DenoiseRegressionEditor.cs'),
        'note':'Final source compiled by VerifyFormats. After277-stage run only explicit zero assertion (also checked against saved data) and allocation-only format probe were added.'},
    'sigmaMeaning':'CPU-derived from actual stored center moments, not separately read from GPU',
    'allPassed':report['passed'],'actualRuntime':{k:report[k] for k in ['unity','gpu','api']},
    'baselineObservation':'DX12 half UAV stores L=1000 but saturates E[L^2]=1000000 to65504. No nonfinite output or history rejection observed in this five-frame baseline.',
    'budget':'ScreenBudget PASS: 11381 plans,95211 assertions. +16 bytes/GI pixel;640x360 full/320x180 GI at128MiB unchanged; +921600 bytes.',
    'runtimeProductSources':product,'productPatchSha256':sha(output/'product.patch'),
    'diagnostics':diagnostics,'sceneRerun':False,
    'limits':['Synthetic filter discontinuities are not real-scene flicker or physical-reference acceptance.',
              'No full Player/DXR/long-run/GPU-time/VRAM certification. The previous runs remain historical.',
              'The first baseline fixture failed because ordinary Texture2D UInt Sample usage is unsupported; fixed with UInt RenderTexture and input-only compute upload. Failure log retained.',
              'A second bounded run added missing legacy full-texture finite checks, both-kernel black/unknown filter checks, Final composite readback and raw readback retention.']}
(output/'validation.json').write_text(json.dumps(summary,indent=2),encoding='utf-8')
print(json.dumps({'rows':summary['contractRows'],'legacyCases':summary['legacyCases'],'allPassed':True,
    'R2':{k:v['noise']['centerFilterChange3to4'] for k,v in diagnostics.items()},
    'parallelPlaneDarkWindowChangeNotCausalLeakMeasure':{k:v['parallel-plane']['frames1to5'][0]['darkWindowFilterIncrement'] for k,v in diagnostics.items()},
    'syncedProductSources':len(product)},indent=2))
