"""One fixed active Skin window; reuse native interval math, retain every source."""
import argparse,csv,datetime,json,math,runpy
from collections import Counter
from pathlib import Path

here=Path(__file__).resolve().parent
helper=here/'native-analysis.py'
if not helper.exists():helper=here.parents[1]/'LocalComparison/Review/release83-dxr-cost-01/native-analysis.py'
base=runpy.run_path(str(helper));load,lines,need,stats,percentile=(base[k] for k in ['load','lines','require','stats','percentile'])
def date(s):return datetime.datetime.fromisoformat(s.replace('Z','+00:00'))
def analyze(area):
    root=area/'run';r=load(root/'run.json');exit=load(area/'setup/native-exit.json')
    need(r['status']=='collected' and not r['error'] and exit['exitCode']==0 and not exit['watchdogTerminated'],'Incomplete normal process/observation')
    settings=load(root/'settings-measure.json');before=load(root/'settings-before.json')
    expected=before.copy();expected.update(measureGpuCost=True,preferNativeGpuTiming=True,adaptiveGpuBudget=False,targetGpuMilliseconds=0)
    need(settings==expected and settings['raysPerPixel']==2 and settings['filterIterations']==4 and settings['resolutionScale']==.5 and settings['preferHardwareTracing'],'Released profile/measure-only differs')
    f=lines(root/'frames.jsonl');c=lines(root/'completions.jsonl');start,end=r['sourceStart'],r['sourceEnd']
    rows=[x for x in f if x['stage']==2]
    need(r['windowComplete'] and r['workloadQualified'] and r['windowDuration']>=35 and len(rows)==r['windowSources'] and [x['engineFrame'] for x in rows]==list(range(start,end+1)),'Incomplete35-second source window')
    need(len(f)==r['frames'] and len(c)==r['completions'] and f[-1]['engineFrame']==end+32,'Different source/drain records')
    need(all(x['actor']['skinnedDeformation'] and x['actor']['deformationRunning'] and x['actor']['sourceIsSkin'] and not x['actor']['doorMoving'] for x in rows),'Not the active K+Space case')
    need(all((x['fullWidth'],x['fullHeight'],x['width'],x['height'])==(960,540,480,270) and not x['feedback'] and x['transportEngineFrame']==x['engineFrame'] for x in rows),'Size/feedback/source recording differs')
    need(r['sourceBones']==2 and r['sourceVertices']>0 and r['sourceTriangles']>0 and r['distinctWindowCapturedFrames']>=2 and r['windowBendChanges']>0,'Actual two-bone workload did not advance')
    identity=['token','owner','generation','deviceEpoch','epoch','providerIndex'];indexed={x['engineFrame']:x for x in rows}
    samples=[x for x in c if start<=x['sourceFrame']<=end];matched={};bad=[]
    for s in samples:
        frame=indexed.get(s['sourceFrame']);ok=bool(frame and frame['stateAvailable'] and frame['native'] and frame['tokenValid'] and frame['tokenEngineFrame']==frame['engineFrame'])
        ok=ok and all(s[k]==frame[k] for k in identity) and s['frequency']>0 and s['readFrame']>=s['sourceFrame']
        ticks=[s[k] for k in ['begin0','end0','begin1','end1','begin2','end2']]
        ok=ok and all(a<=b for a,b in zip(ticks,ticks[1:]))
        if not ok or s['sourceFrame'] in matched:bad.append(s['sourceFrame'])
        else:matched[s['sourceFrame']]=s
    missing=sorted(set(indexed)-set(matched));timing_ok=not missing and not bad and len(samples)==len(rows)
    need(timing_ok==r['timingQualified'],'Observer/native qualification disagreement')
    intervals=None
    if timing_ok:
        values=[[1000*(s[f'end{i}']-s[f'begin{i}'])/s['frequency'] for i in range(3)] for s in matched.values()]
        intervals={'perSourceSum':stats([sum(x) for x in values]),'scopes':{name:stats([v[i] for v in values]) for i,name in enumerate(r['scopes'])}}
    m=r['memoryWindow'];memory_ok=bool(r['memoryQualified'] and m['valid'] and m['hasSamples'] and m['windowFirstFrame']==start and m['sampleFrame']==m['attemptFrame']==end and m['samples']==len(rows) and m['failedSamples']==0)
    for row in rows:
        mem=row['memory'];memory_ok=memory_ok and mem['valid'] and mem['sampleFrame']==mem['attemptFrame']==row['engineFrame'] and mem['windowFirstFrame']==start and mem['samples']==row['engineFrame']-start+1 and mem['failedSamples']==0 and mem['deviceEpoch']==m['deviceEpoch'] and mem['adapterLuid']==m['adapterLuid']
    need(memory_ok==r['memoryQualified'],'Memory source/window qualification disagreement')
    publications=[p for p in r['publications'] if p['stage']==2];ages=[]
    for p in publications:
        row=indexed[p['firstObservedEngineFrame']];a=row['actor']
        need(p['ageFrames']==p['firstObservedEngineFrame']-p['capturedFrame']>=0 and p['capturedFrame']>=r['skinActivatedEngineFrame'] and a['sourceReferencesAgree'] and a['publishedFrame']==p['capturedFrame'] and a['sourceMeshId']==p['meshId'],'CPU capture/first-observation association differs')
        ages.append(p['ageFrames'])
    need(len({p['capturedFrame'] for p in publications})==r['distinctWindowCapturedFrames'],'CPU publication count differs')
    present={'status':'unavailable'}
    try:
        attempt=load(area/'setup/present-attempt.json');wm0=load(root/'window-start.json');wm1=load(root/'window-end.json')
        need(attempt['status']=='completed' and attempt['exitCode']==0,'PresentMon did not complete')
        need(date(wm0['utc'])<=date(attempt['startedUtc'])<date(attempt['finishedUtc'])<=date(wm1['utc']) and wm0['activeSkin'] and wm1['activeSkin'],'Present invocation not wholly inside the active window')
        with (area/'present.csv').open(encoding='utf-8-sig',newline='') as h:pr=list(csv.DictReader(h))
        identities={(v['ProcessID'],v['SwapChainAddress'],v['Runtime'],v['Application']) for v in pr}
        need(len(identities)==1 and next(iter(identities))[0]==str(exit['processId']) and next(iter(identities))[2]=='DXGI','Different Present process/stream')
        t=[float(x['TimeInSeconds']) for x in pr];v=[float(x['msBetweenPresents']) for x in pr[1:]];span=t[-1]-t[0]
        need(v and all(math.isfinite(x) and x>0 for x in v) and abs(sum(v)/1000-span)<1e-5,'Incomplete Present intervals')
        present={'status':'same-run-active-window','actualInvocationUtc':[attempt['startedUtc'],attempt['finishedUtc']],'csvSpanSeconds':span,'meanHz':len(v)/span,'intervals':stats(v),'above33ms':sum(x>1000/30 for x in v),'scope':'Application Present, first row without preceding anchor excluded; not actual display FPS or per-source GI pairing'}
    except (OSError,ValueError,KeyError,IndexError) as e:present={'status':'unavailable-or-unqualified','error':str(e)}
    allpub=r['publications'];firstpub=allpub[0] if allpub else None
    gpu_limit=intervals['perSourceSum']['p95Ms']<=25 if timing_ok else None
    memory_limit=m['peakLocalUsageBytes']<=2**30 if memory_ok else None
    result={'status':'qualified-active-skin-cost-window' if timing_ok and memory_ok else 'incomplete-active-skin-cost-window','scope':'One instrumented35-second active K+Space Skin workload; actual default mesh/budgets/HUD, not observation-off performance, cold start, larger models, all motion quality or fullG3/G4/G5',
        'product':'7c08327 / Release122 same-source private ordinary Release-None measurement Player','sources':[start,end],'windowSources':len(rows),'windowSeconds':r['windowDuration'],
        'workload':{k:r[k] for k in ['sourceBones','sourceVertices','sourceTriangles','sdfResolution','updateIntervalFrames','vertexBudgetPerFrame','maximumWorkers','deformationMemoryBudgetBytes','deformationUploadBudgetBytesPerFrame','captureBudgetMillisecondsPerFrame','initialSampleHud','initialInteractionHud','distinctWindowCapturedFrames','windowBendChanges']},
        'nativeTiming':{'qualified':timing_ok,'missing':missing,'invalidOrDuplicate':bad,'statistics':intervals,'p95LimitMs':25,'withinP95Limit':gpu_limit,'basis':'Identity-matched complete3-scope sum for every source; linear(N-1)*q. Source epochs/generations may vary; none are filtered.'},
        'processMemory':{'qualified':memory_ok,'samples':m['samples'],'failedSamples':m['failedSamples'],'localSampledPeakBytes':m['peakLocalUsageBytes'],'localSampledPeakMiB':m['peakLocalUsageBytes']/2**20,'nonlocalSampledPeakMiB':m['peakNonlocalUsageBytes']/2**20,'localLimitBytes':2**30,'withinLocalLimit':memory_limit,'scope':'DXGI process finite CPU samples on the Unity adapter, not GI-only/total machine VRAM or guaranteed instantaneous peak'},
        'withinBothStartingBudgetLimits':bool(gpu_limit and memory_limit) if gpu_limit is not None and memory_limit is not None else None,'applicationPresent':present,
        'cpuSnapshotAge':{'count':len(ages),'medianFrames':percentile(ages,.5),'p95Frames':percentile(ages,.95),'p99Frames':percentile(ages,.99),'maxFrames':max(ages),'scope':'Actual capture engine frame to first recorded matching CPU snapshot observation; not exact publication time/BakeMesh milliseconds/GPU consumption latency'},
        'actualStates':{'backendCounts':dict(Counter(x['recordedBackend'] for x in rows)),'nativeProviderIndices':sorted({x['providerIndex'] for x in rows}),'gpuGenerations':sorted({x['gpuGeneration'] for x in rows}),'epochs':sorted({x['epoch'] for x in rows}),'materialUnknownRows':sum(x['materialUnknown']>0 for x in rows),'materialUnknownMax':max(x['materialUnknown'] for x in rows),'identityUnknownMax':max(x['identityUnknown'] for x in rows),'fallbackMeshMax':max(x['unrepresented'] for x in rows),'sourceReferencesDisagreeRows':sum(not x['actor']['sourceReferencesAgree'] for x in rows),'cpuPublicationPhases':dict(Counter(x['actor']['publicationPhase'] for x in rows))},
        'preparation':{'firstCameraSourceRealtime':f[0]['sourceSeconds'],'skinActivationRealtime':r['skinActivatedSeconds'],'activePreparationSecondsToWindow':r['windowStartSeconds']-r['skinActivatedSeconds'],'firstSkinCpuObservation':firstpub,'sourceSwitchMarkerToFirstCpuObservedSeconds':firstpub['sourceSeconds']-r['skinActivatedSeconds'] if firstpub else None,'scope':'Observed setup/source clocks are outside the warm35-second window, not isolated CPU costs or a cause attribution'},
        'remainingProviderPending':[p['pending'] for p in r['providers']],'screenshotStatus':r['screenshotStatus'],'cpuCaptureMilliseconds':'unknown','gpuGeometryConsumptionLatency':'unknown','nativeExit':exit}
    return result
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('area',type=Path);p.add_argument('output',type=Path);a=p.parse_args();a.output.mkdir(parents=True,exist_ok=False)
    try:r=analyze(a.area)
    except (OSError,ValueError,KeyError,IndexError,TypeError) as e:r={'status':'insufficient-input-or-record','error':str(e)}
    (a.output/'result.json').write_text(json.dumps(r,indent=2)+'\n',encoding='utf-8');print(json.dumps(r))
