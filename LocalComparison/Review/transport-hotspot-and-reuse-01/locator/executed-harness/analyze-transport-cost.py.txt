"""Single-purpose integer-tick nesting and four-block cost attribution."""
import argparse,importlib.util,json,math,re,traceback
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];PACKAGE=ROOT/'LocalComparison/Review/transport-hotspot-and-reuse-01';PROJECT=Path('I:/Unity test/Project')
spec=importlib.util.spec_from_file_location('base',Path(__file__).with_name('analyze-player-smoke.py'));base=importlib.util.module_from_spec(spec);spec.loader.exec_module(base)
load=base.load;sha=base.sha;lines=base.lines
def save(p,v):p.write_bytes((json.dumps(v,indent=2)+'\n').encode('utf-8'))
def build():
    r={'buildVerified':False,'fullProductionAccepted':False}
    try:
        report=load(SIDE/'build-report.json');m=load(SIDE/'instrumentation/manifest.json');restored=load(SIDE/'instrumentation/restoration.json')
        assert load(SIDE/'build-exit.json')['exitCode']==0 and report['result']=='Succeeded' and report['errors']==0
        assert not base.hits(SIDE/'build-unity.log'),'Build log errors'
        assert restored['currentProductRestored'] and all(x['restored'] for x in restored['files'])
        inputs={x['path']:x for x in report['inputs']}
        assert all(sha(PROJECT/'Assets/HybridLumenGI'/p)==v for p,v in m['productSourceSha256'].items())
        assert all(inputs['Assets/HybridLumenGI/'+p]['sha256']==v for p,v in m['builtProductSourceSha256'].items())
        assert all(inputs[x['path']]['sha256']==x['sha256'] for x in m['files'])
        native='Assets/Plugins/x86_64/HybridLumenGIGpuTiming.dll';expected='4d94afc2769208cd1da72ec7cda0f29b31fc42dd71febd86a3b9238b391d6431'
        dlls=list(BUILD.rglob('HybridLumenGIGpuTiming.dll'));assert len(dlls)==1 and sha(dlls[0])==expected==inputs[native]['sha256']
        meta=PROJECT/(native+'.meta');assert sha(meta)==inputs[native+'.meta']['sha256'];text=meta.read_text(encoding='utf-8')
        for platform,value in [('Any',0),('Editor',1),('Win64',1),('Win',0),('Linux64',0),('OSXUniversal',0)]:
            assert re.search(r'^    '+platform+r':\n      enabled: '+str(value)+r'\n',text,re.M),platform
        assert 'OS: Windows' in text and 'CPU: x86_64' in text
        (SIDE/'native-importer.meta').write_bytes(meta.read_bytes())
        assert not (SIDE/'build-products.json').exists(),'Products already frozen'
        files=[{'path':p.relative_to(BUILD).as_posix(),'bytes':p.stat().st_size,'sha256':sha(p)} for p in sorted(BUILD.rglob('*')) if p.is_file()]
        save(SIDE/'build-products.json',{'root':str(BUILD),'files':files})
        r.update(buildVerified=True,sourceCommit=m['baseline'],baseProductSourceCount=len(m['productSourceSha256']),
                 instrumentedProductSourceCount=len(m['builtProductSourceSha256']),temporaryFileCount=len(m['files']),productCount=len(files),
                 nativeDllSha256=expected,exclusivePlatformsVerified=True,restorationVerified=True)
    except Exception as e:r.update(error=str(e),traceback=traceback.format_exc())
    save(SIDE/'build-analysis.json',r);print(json.dumps(r));return r['buildVerified']
def verify():
    m=load(SIDE/'build-products.json');root=Path(m['root'])
    assert all((root/f['path']).stat().st_size==f['bytes'] and sha(root/f['path'])==f['sha256'] for f in m['files'])
    assert {f['path'] for f in m['files']}=={p.relative_to(root).as_posix() for p in root.rglob('*') if p.is_file()}
    return sha(SIDE/'build-products.json')
def summary(values):
    s=sorted(values);n=len(s);return {'count':n,'medianMs':(s[(n-1)//2]+s[n//2])/2,'maxMs':s[-1]}
def run():
    out=SIDE/'native-window';r={'completeAttribution':False,'failures':{},'scope':'64 selected sources, instrumented fixed DXR scene; formal scopes plus separate diagnostic owner',
        'diagnosticScopeMap':{'begin0/end0':'WorldCache','begin1/end1':'Gather','begin2/end2':'Reconstruction (Temporal through Atrous)'},
        'remainderMeaning':'Other commands, gaps and instrumentation inside formal Transport; not a named kernel or pure ALU cost'}
    data={}
    def check(name,fn):
        try:fn();r[name]=True
        except Exception as e:r[name]=False;r['failures'][name]={'error':str(e),'traceback':traceback.format_exc()}
    def collect():
        assert load(SIDE/'build-analysis.json')['buildVerified'];r['buildManifestSha256']=verify()
        runs=list((out/'run').glob('*/run.json'));assert len(runs)==1
        folder=runs[0].parent;meta=load(runs[0]);frames=lines(folder/'frames.jsonl');parent=lines(folder/'completions.jsonl');child=lines(folder/'diagnostic-completions.jsonl')
        data.update(meta=meta,frames=frames,parent=parent,child=child);r['runId']=folder.name;r['collection']=meta
        assert meta['status']=='collected' and not meta.get('error')
        assert meta['frames']==len(frames)<=352 and meta['completions']==len(parent) and meta['diagnosticCompletions']==len(child)
        assert meta['sourceEnd']-meta['sourceStart']+1==64 and meta['window']==64
        assert [f['engineFrame'] for f in frames]==list(range(frames[0]['engineFrame'],frames[0]['engineFrame']+len(frames)))
        assert [f['index'] for f in frames]==list(range(len(frames)))
        assert sum(f['stage']==0 for f in frames)<=256 and sum(f['stage']==1 for f in frames)==64 and sum(f['stage']==2 for f in frames)==32
        assert frames[-1]['engineFrame']==meta['sourceEnd']+32 and meta['measureOnly'] and not meta['adaptive'] and meta['targetMs']==0
        assert meta['diagnosticPendingAfterStop']==0
        assert meta['diagnosticCancelledAfterStop']==frames[-1]['diagnosticCancelled']+meta['diagnosticPendingBeforeStop']
        before=load(folder/'feature-before.json');after=load(folder/'feature-measure.json')
        for k in ['preferHardwareTracing','measureGpuCost','adaptiveGpuBudget','targetGpuMilliseconds','preferNativeGpuTiming']:before['settings'].pop(k,None);after['settings'].pop(k,None)
        assert before==after
    def samples():
        meta=data['meta'];expected=set(range(meta['sourceStart'],meta['sourceEnd']+1));rows={f['engineFrame']:f for f in data['frames']};anchor=rows[meta['sourceStart']-1]
        selected=[]
        for kind in ['parent','child']:
            all_samples=data[kind]
            assert len({s['token'] for s in all_samples})==len(all_samples) and len({(s['owner'],s['sourceFrame']) for s in all_samples})==len(all_samples)
            by_source={s['sourceFrame']:s for s in all_samples if s['sourceFrame'] in expected};r[kind+'MissingSources']=sorted(expected-by_source.keys())
            assert set(by_source)==expected and len(by_source)==64,'Incomplete '+kind+' source set'
            selected.append(by_source)
        parent,child=selected;values={name:[] for name in ['ReceiverCapture','Transport','Composite','FormalSum','WorldCache','Gather','Reconstruction','TransportRemainder']}
        for source in sorted(expected):
            f=rows[source];p=parent[source];c=child[source]
            for k in ['token','owner','generation','deviceEpoch','epoch']:assert p[k]==f[k],k
            for k,rowkey in [('token','diagnosticToken'),('owner','diagnosticOwner'),('generation','diagnosticGeneration'),('deviceEpoch','diagnosticDeviceEpoch'),('epoch','diagnosticEpoch')]:assert c[k]==f[rowkey],rowkey
            assert f['diagnosticParentToken']==p['token'] and f['diagnosticSource']==source and p['owner']!=c['owner']
            assert all(p[k]==c[k] for k in ['generation','deviceEpoch','frequency'])
            ticks=[]
            for sample in [p,c]:
                assert 0<sample['readFrame']-source<=32 and sample['readFrame'] in rows and sample['frequency']>0
                t=[sample[k] for k in ['begin0','end0','begin1','end1','begin2','end2']];assert all(a<=b for a,b in zip(t,t[1:]));ticks.append(t)
            pt,ct=ticks;assert pt[2]<=ct[0]<=ct[1]<=ct[2]<=ct[3]<=ct[4]<=ct[5]<=pt[3],'Child outside formal Transport'
            pdelta=[pt[i+1]-pt[i] for i in [0,2,4]];cdelta=[ct[i+1]-ct[i] for i in [0,2,4]]
            raw=pdelta+[sum(pdelta)]+cdelta+[pdelta[1]-sum(cdelta)]
            for name,t in zip(values,raw):v=t*1000/p['frequency'];assert math.isfinite(v) and v>=0;values[name].append(v)
        for f in data['frames']:
            if f['stage']==0:continue
            assert f['ready'] and f['native'] and f['hardware'] and not f['feedback'] and f['scale']==1
            assert [f[k] for k in ['patchQuota','captureQuota','brickQuota']]==[256,24,16]
            for key in ['owner','generation','epoch','deviceEpoch','width','height','fullWidth','fullHeight','diagnosticOwner','diagnosticGeneration','diagnosticEpoch','diagnosticDeviceEpoch',
                        'cancelled','invalid','unexported','timedOut','diagnosticCancelled','diagnosticInvalid','diagnosticUnexported','diagnosticTimedOut']:assert f[key]==anchor[key],key
        r['statistics']={name:summary(v) for name,v in values.items()}
        r['consecutiveBlocks']=[{'sourceStart':meta['sourceStart']+i*16,'sourceEnd':meta['sourceStart']+i*16+15,
                                'statistics':{name:summary(v[i*16:i*16+16]) for name,v in values.items()}} for i in range(4)]
        r['rankedTransportParts']=sorted(['WorldCache','Gather','Reconstruction','TransportRemainder'],key=lambda k:r['statistics'][k]['medianMs'],reverse=True)
        r['selectedSources']=64
    def native():
        exit=load(out/'native-exit.json');r['nativeExit']=exit;r['nativeLogHits']=base.hits(out/'player.log')
        assert exit['exitCode']==0 and not exit['watchdogTerminated'] and not r['nativeLogHits']
        events=[line for line in (out/'player.log').read_text(encoding='utf-8-sig').splitlines() if line.startswith('HybridLumenGI shutdown ')]
        r['shutdownEvents']=events;final=events[-1];assert 'generic drain complete:' in final
        for key in ['owned','pending','unknown','failed','failedWithdrawals','materialBytes','arenaBytes','deformationBytes','deformationJobs','deformationCleanupFailed']:
            assert re.search(r'(?:, |: )'+key+r'=0(?:,|$)',final),key
    for name,fn in [('collectionVerified',collect),('nestedSamplesVerified',samples),('nativeExitVerified',native)]:check(name,fn)
    r['completeAttribution']=not r['failures'];save(out/'analysis.json',r);print(json.dumps(r));return r['completeAttribution']
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('action',choices=['build','run','verify']);p.add_argument('--side',choices=['locator','candidate'],default='locator');a=p.parse_args()
    SIDE=PACKAGE/a.side;BUILD=Path('I:/Unity test/Comparison/Builds')/('TransportCost23-'+a.side)
    if a.action=='verify':print(verify())
    else:raise SystemExit(0 if globals()[a.action]() else 1)
