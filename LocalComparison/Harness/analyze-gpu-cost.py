"""Finite source-identified native GPU intervals. Never fill missing samples."""
import argparse,importlib.util,json,math,re,traceback
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];PACKAGE=ROOT/'LocalComparison/Review/gpu-cost-baseline-01'
BUILD=Path('I:/Unity test/Comparison/Builds/GpuCost22')
spec=importlib.util.spec_from_file_location('smoke',Path(__file__).with_name('analyze-player-smoke.py'));base=importlib.util.module_from_spec(spec);spec.loader.exec_module(base)
base.PACKAGE=PACKAGE;base.BUILD=BUILD
load=base.load;sha=base.sha;lines=base.lines
def save(p,v):p.write_bytes((json.dumps(v,indent=2)+'\n').encode('utf-8'))
def build():
    ok=base.build();report=load(PACKAGE/'build-analysis.json')
    try:
        assert ok,'Base build provenance failed'
        expected=load(PACKAGE/'native/provenance.json')['dllSha256']
        matches=[p for p in BUILD.rglob('HybridLumenGIGpuTiming.dll') if p.is_file()]
        assert len(matches)==1 and sha(matches[0])==expected,'Player native DLL mismatch'
        inputs={r['path']:r for r in load(PACKAGE/'build-report.json')['inputs']}
        native='Assets/Plugins/x86_64/HybridLumenGIGpuTiming.dll'
        assert inputs[native]['sha256']==expected
        meta=base.PROJECT/(native+'.meta');assert inputs[native+'.meta']['sha256']==sha(meta)
        (PACKAGE/'native/PluginImporter.meta').write_bytes(meta.read_bytes())
        report.update(nativePluginVerified=True,playerNativePath=str(matches[0]),nativeDllSha256=expected)
    except Exception as e:report.update(nativePluginVerified=False,nativeFailure=str(e));ok=False
    save(PACKAGE/'build-analysis.json',report);print(json.dumps(report));return ok
def percentile(a,q):
    a=sorted(a);pos=(len(a)-1)*q;lo=math.floor(pos);hi=math.ceil(pos)
    return a[lo]+(a[hi]-a[lo])*(pos-lo)
def stats(a):return {'count':len(a),'medianMs':percentile(a,.5),'p95Ms':percentile(a,.95),'p99Ms':percentile(a,.99),'maxMs':max(a)}
def run():
    out=PACKAGE/'native-window';r={'completeBaseline':False,'fullProductionAccepted':False,'failures':{},
        'scope':'512 source frames; three native queue intervals and per-source sum; descriptive finite-window percentiles, not production tail guarantee',
        'excludes':'CPU preparation, out-of-scope uploads/RenderGraph work, full-app GPU time; intervals may include barriers/waits'}
    data={}
    def check(name,fn):
        try:fn();r[name]=True
        except Exception as e:r[name]=False;r['failures'][name]={'error':str(e),'traceback':traceback.format_exc()}
    def provenance():
        assert load(PACKAGE/'build-analysis.json')['nativePluginVerified'];r['buildManifestSha256']=base.verify_products()
    def collection():
        runs=list((out/'run').glob('*/run.json'));assert len(runs)==1,'Unique output run required'
        folder=runs[0].parent;meta=load(runs[0]);f=lines(folder/'frames.jsonl');s=lines(folder/'completions.jsonl')
        data.update(meta=meta,frames=f,samples=s);r['runId']=folder.name;r['collection']=meta
        assert meta['status']=='collected' and not meta.get('error'),'Player collection failed'
        assert meta['frames']==len(f)<=800 and meta['completions']==len(s)
        assert meta['sourceEnd']-meta['sourceStart']+1==512
        assert [v['index'] for v in f]==list(range(len(f)))
        assert [v['engineFrame'] for v in f]==list(range(f[0]['engineFrame'],f[0]['engineFrame']+len(f)))
        assert sum(v['stage']==0 for v in f)<=256 and sum(v['stage']==1 for v in f)==512 and sum(v['stage']==2 for v in f)==32
        assert f[-1]['engineFrame']==meta['sourceEnd']+32 and meta['measureOnly'] and not meta['adaptive'] and meta['targetMs']==0
        before=load(folder/'feature-before.json');after=load(folder/'feature-measure.json')
        for key in ['preferHardwareTracing','measureGpuCost','adaptiveGpuBudget','targetGpuMilliseconds','preferNativeGpuTiming']:
            before['settings'].pop(key,None);after['settings'].pop(key,None)
        assert before==after,'GI settings outside timing/provider controls changed'
    def samples():
        meta=data['meta'];rows={f['engineFrame']:f for f in data['frames']};ss=data['samples']
        assert len({s['token'] for s in ss})==len(ss),'Repeated token'
        assert len({(s['owner'],s['sourceFrame']) for s in ss})==len(ss),'Repeated owner/source'
        selected=[s for s in ss if meta['sourceStart']<=s['sourceFrame']<=meta['sourceEnd']]
        present={s['sourceFrame'] for s in selected};expected=set(range(meta['sourceStart'],meta['sourceEnd']+1))
        r['missingSourceFrames']=sorted(expected-present);r['selectedCompletions']=len(selected)
        assert present==expected and len(selected)==512,'Incomplete source-frame set; no survivor percentiles'
        columns=[[],[],[],[]]
        anchor=rows[meta['sourceStart']-1]
        for s in selected:
            f=rows[s['sourceFrame']]
            assert all(s[k]==f[k] for k in ['token','owner','generation','deviceEpoch','epoch'])
            assert all(f[k]==anchor[k] for k in ['owner','generation','deviceEpoch','epoch','width','height','fullWidth','fullHeight'])
            assert 0<s['readFrame']-s['sourceFrame']<=32 and s['readFrame'] in rows and s['frequency']>0
            ticks=[s[k] for k in ['begin0','end0','begin1','end1','begin2','end2']]
            assert all(a<=b for a,b in zip(ticks,ticks[1:]))
            values=[(ticks[i+1]-ticks[i])*1000/s['frequency'] for i in [0,2,4]];values.append(sum(values))
            assert all(math.isfinite(v) and v>=0 for v in values) and values[3]>0
            for dest,v in zip(columns,values):dest.append(v)
        for f in data['frames']:
            if f['stage']==0:continue
            assert f['native'] and f['hardware'] and f['ready'] and f['dispatchable'] and f['identity'] and f['published'] and not f['feedback'] and f['scale']==1
            assert [f[k] for k in ['patchQuota','captureQuota','brickQuota']]==[256,24,16]
            assert all(f[k]==anchor[k] for k in ['cancelled','timedOut','invalid','unexported'])
            assert f['completed']==f['exported']+f['unexported']+f['buffered']
        r['intervalStatistics']={name:stats(values) for name,values in zip(['ReceiverCapture','Transport','Composite','perSourceSum'],columns)}
        r['percentileMethod']='Linear interpolation at (N-1)*q; sum scopes per source before percentile'
        r['lastPreExitCounters']={k:data['frames'][-1][k] for k in ['completed','exported','unexported','invalid','cancelled','timedOut','feedbackRejected','pending']}
        r['scopeNote']='ReceiverCapture includes enabled identity chain. Six ticks do not isolate Transport subkernels. Pending exit work is outside the fixed source window.'
    def native():
        exit=load(out/'native-exit.json');r['nativeExit']=exit;hits=base.hits(out/'player.log');r['nativeLogHits']=hits
        assert exit['exitCode']==0 and not exit['watchdogTerminated'] and not hits,'Native exit/log failure'
        events=[line for line in (out/'player.log').read_text(encoding='utf-8-sig').splitlines() if line.startswith('HybridLumenGI shutdown ')]
        r['shutdownEvents']=events
        names=['begin','owners withdrawn','idle fence submitted','completed owner destroyed','generic drain complete']
        indices=[next(i for i,e in enumerate(events) if e.startswith('HybridLumenGI shutdown '+name+':')) for name in names]
        assert indices==sorted(indices) and 'outside=True' in events[indices[0]],'Shutdown boundary/order'
        final=events[-1];assert 'generic drain complete:' in final
        for key in ['owned','pending','unknown','failed','failedWithdrawals','materialBytes','arenaBytes','deformationBytes','deformationJobs','deformationCleanupFailed']:
            assert re.search(r'(?:, |: )'+key+r'=0(?:,|$)',final),'Recorded shutdown owner not zero: '+key
    for name,fn in [('provenanceVerified',provenance),('collectionVerified',collection),('samplesVerified',samples),('nativeExitVerified',native)]:check(name,fn)
    r['completeBaseline']=not r['failures'];save(out/'analysis.json',r);print(json.dumps(r));return r['completeBaseline']
if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('action',choices=['build','run','verify']);a=parser.parse_args()
    if a.action=='verify':print(base.verify_products())
    else:raise SystemExit(0 if globals()[a.action]() else 1)
