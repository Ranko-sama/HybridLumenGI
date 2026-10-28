"""Post-reference comparison only. Never feeds product values into reference inputs."""
import argparse, hashlib, json, math, importlib.util
from pathlib import Path
import numpy as np
spec=importlib.util.spec_from_file_location('radiometry_qualification',Path(__file__).with_name('qualify-radiometry.py'))
qualification=importlib.util.module_from_spec(spec);spec.loader.exec_module(qualification)


def load(path):return json.loads(path.read_text(encoding='utf-8-sig'))
def lines(path):return [json.loads(l) for l in path.read_text(encoding='utf-8-sig').splitlines() if l.strip()]
def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def vec(o):return np.array([o[k] for k in 'xyz'])


def main():
    p=argparse.ArgumentParser();p.add_argument('--package',type=Path,required=True);a=p.parse_args();package=a.package
    previous_gate=load(package/'pre-integration-gate.json');assert previous_gate['passed'],'Integration must first be admitted'
    current_gate=qualification.qualify(package)
    assert all(current_gate[k]==previous_gate[k] for k in ['runId','sceneSha256','targetsSha256'])
    output=package/'run';run_paths=list(output.glob('*/run.json'));assert len(run_paths)==1
    run=run_paths[0].parent;meta=load(run/'run.json');reference=load(package/'reference/reference.json')
    assert reference['integrationExecuted'], 'Reference must exist before product comparison'
    freeze=load(output/'source-freeze.json');source=load(output/'reference-scene.json')
    checks=[load(output/f'source-check-{n:04}.json') for n in [103,119]]
    source_closed=(digest(output/'reference-scene.json')==freeze['sourceSha256']==reference['sceneSha256'] and
        all(c['sameSource'] and c['sameDependencyBytes'] and c['sourceSha256']==freeze['sourceSha256'] for c in checks) and
        all(digest(output/f['archive'])==f['sha256'] for f in freeze['files']))
    assert source_closed
    assert digest(run/'reference-targets.json')==reference['targetsSha256']
    bindings=lines(run/'lightoff-bindings.jsonl');frames=lines(run/'frames.jsonl');receipts=lines(run/'cache-update-receipts.jsonl')
    assert meta['requestedFrames']==meta['renderedFrames']==120 and meta['captures']==2 and meta['errors']==0
    assert [f['logicalFrame'] for f in frames]==list(range(120))
    assert [b['logicalFrame'] for b in bindings]==list(range(120)) and all(b['exact'] and b['distinct'] and b['lightCount']==1 for b in bindings)
    assert len(receipts)==240 and {(r['logicalFrame'],r['lane']) for r in receipts}=={(n,l) for n in range(120) for l in range(2)}
    assert load(run/'lightoff-summary.json')['passed'] and load(run/'gather-summary.json')['passed']
    assert all(load(run/f'radiometry-gate-{n:04}.json')['passed'] for n in [103,119])
    rows={t['id']:[] for t in load(run/'reference-targets.json')['targets']}
    targets={t['id']:t for t in load(run/'reference-targets.json')['targets']}
    identity_stable=True;positions_stable=True;commit_counts={str(l):{'all120':0,'window16':0} for l in range(2)}
    for receipt in receipts:
        assert all(math.isfinite(v) for v in receipt['status'].values())
        if receipt['status']['y']==1:
            commit_counts[str(receipt['lane'])]['all120']+=1
            if receipt['logicalFrame']>=104:commit_counts[str(receipt['lane'])]['window16']+=1
    for n in range(104,120):
        schedule=load(run/f'lightoff-schedule-{n:04}.json');assert schedule['aliases']==[0,0,1,1]
        observed=np.fromfile(run/f'lightoff-{n:04}-cache-observed.bin',dtype='<f4').reshape(4,20,4)
        for lane,patch in enumerate(schedule['patches']):
            actual=np.fromfile(run/f'lightoff-{n:04}-cache-actual-{lane}.bin',dtype='<f4').reshape(5,4)
            assert np.array_equal(actual,observed[lane,5:10]) and np.isfinite(actual).all()
            target=targets[f'cache-{lane}'];identity_stable &= all(target[key]==patch[key] for key in ['entry','stableId','revision','generation'])
            positions_stable &= np.array_equal(actual[2,:3].astype(float),vec(target['position']))
            assert bool(schedule['cpuMask'][patch['entry']])==bool(observed[lane,12,3])
            rows[f'cache-{lane}'].append({'logicalFrame':n,'value':actual[0,:3].astype(float).tolist(),'historySamples':float(actual[0,3]),
                'measurementAvailable':bool(observed[lane,16,2] and actual[0,3]>0),
                'committed':bool(observed[lane,16,1]),'scheduled':bool(observed[lane,12,3])})
        receivers=load(run/f'receivers-{n:04}.json')['targets']
        stage={key:np.fromfile(run/f'lightoff-{n:04}-{key}.bin',dtype='<f4').reshape(4,4) for key in ['raw','history','filtered']}
        gather=np.fromfile(run/f'gather-{n:04}-raw-selected.bin',dtype='<f4').reshape(4,4)
        assert all(np.isfinite(v).all() for v in stage.values()) and np.array_equal(gather,stage['raw'])
        for lane,receiver in enumerate(receivers):
            key=f'gi-{lane}';positions_stable &= np.array_equal(vec(receiver['position']),vec(targets[key]['position']))
            positions_stable &= np.array_equal(vec(receiver['normal']),vec(targets[key]['normal']))
            rows[key].append({'logicalFrame':n,'value':stage['raw'][lane,:3].astype(float).tolist(),
                'measurementAvailable':bool(stage['raw'][lane,3]>0),'rawAlpha':float(stage['raw'][lane,3]),
                'rawState':'measurement' if stage['raw'][lane,3]>0 else 'unknown' if stage['raw'][lane,3]<0 else 'no measurement',
                'history':stage['history'][lane,:3].astype(float).tolist(),'historyAlpha':float(stage['history'][lane,3]),
                'filtered':stage['filtered'][lane,:3].astype(float).tolist(),'filteredAlpha':float(stage['filtered'][lane,3])})
    comparison=[]
    for r in reference['results']:
        observations=rows[r['id']];available=[v for v in observations if v['measurementAvailable']]
        values=np.array([v['value'] for v in available]);finite=np.array(r['meanFinite64'])
        last=np.array(observations[-1]['value']) if observations[-1]['measurementAvailable'] else None
        comparison.append({'id':r['id'],'cpuFinite64':r['meanFinite64'],'cpuApproximateT95HalfWidth':r['approximateT95HalfWidth'],
            'cpuStrictSimultaneous95HalfWidth':r['strictSimultaneous95HalfWidth'],'cpuStrictNonnegativeTailBound':r['strictNonnegativeTailBound'],
            'product119':last.tolist() if last is not None else None,'difference119MinusCPU64':(last-finite).tolist() if last is not None else None,
            'windowMeanDescriptiveOnly':values.mean(0).tolist() if identity_stable and positions_stable and len(available)==16 else None,
            'availableMeasurementCount':len(available),'windowMinimum':values.min(0).tolist() if len(available) else None,
            'windowMaximum':values.max(0).tolist() if len(available) else None,'observations':observations,
            'GPUConfidenceInterval':None,'steadyStateProven':False,'classification':'finite estimation/model difference; no deterministic counterexample established by numeric distance alone'})
    bad=load(package/'native-log-check.json')['hits']
    accepted=current_gate['nativeExitAccepted']
    report={'baseline':'C-prospective-01','historicalSourceClosure':False,'prospectiveSourceClosure':source_closed,
        'targetSurfaceCorrespondenceVerified':reference['targetSurfaceCorrespondenceVerified'],'productObservationValid':True,
        'referenceEstimateQualified':reference['referenceEstimateQualified'],'comparisonConclusive':False,'nativeExitAccepted':accepted,
        'scope':'Six finite-history points only; independent finite64 reference, not whole-image/steady-state/DXR/Player/performance acceptance',
        'exceptionalExitScratchResolved':False,'nativeResourceSignatures':bad,'windowIdentityStable':bool(identity_stable),'windowPositionsStable':bool(positions_stable),
        'actualCommits':commit_counts,'comparison':comparison,'sourceSettings':json.loads(source['featureSettings']),
        'referenceBounds':reference['sourceBounds'],'RuntimeChanged':False}
    (package/'comparison.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
    print(json.dumps({k:report[k] for k in ['prospectiveSourceClosure','targetSurfaceCorrespondenceVerified','productObservationValid','referenceEstimateQualified','comparisonConclusive','nativeExitAccepted']}))


if __name__=='__main__':main()
