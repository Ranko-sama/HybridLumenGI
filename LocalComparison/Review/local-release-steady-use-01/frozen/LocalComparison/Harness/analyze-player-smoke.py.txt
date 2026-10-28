"""Bounded build/backend/data/normal-exit acceptance. No image-quality oracle."""
import argparse,hashlib,json,re,traceback
from pathlib import Path
import numpy as np
from native_log_check import scan

ROOT=Path(__file__).resolve().parents[2]
PACKAGE=ROOT/'LocalComparison/Review/current-player-shutdown-01'
PROJECT=Path('I:/Unity test/Project')
BUILD=Path('I:/Unity test/Comparison/Builds/CurrentShutdown20')
def load(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def lines(p):return [json.loads(s) for s in p.read_text(encoding='utf-8-sig').splitlines() if s.strip()]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def save(p,v):p.write_text(json.dumps(v,indent=2)+'\n',encoding='utf-8')
def hits(path):
    result=scan(path)
    extra={'scratch':r'D3D12ScratchBufferInternal','gc-buffer-disposal':r'GarbageCollector disposing of (?:ComputeBuffer|GraphicsBuffer)',
           'exception':r'(?:^|\s)(?:Unhandled\s+)?[A-Za-z0-9_.]*Exception(?::|\s*$)|The referenced script .* is missing|Failed to load .*shader|Invalid bounded Player smoke'}
    for n,line in enumerate(path.read_text(encoding='utf-8-sig',errors='replace').splitlines(),1):
        for category,pattern in extra.items():
            if re.search(pattern,line,re.I):result.append({'category':category,'line':n,'text':line})
    return result

def build():
    report={'currentSourceBuildVerified':False,'fullProductionAccepted':False}
    try:
        b=load(PACKAGE/'build-report.json');exit=load(PACKAGE/'build-exit.json')
        report['nativeLogHits']=hits(PACKAGE/'build-unity.log');report['buildResult']=b['result'];report['buildErrors']=b['errors']
        assert exit['exitCode']==0 and b['result']=='Succeeded' and b['errors']==0 and not report['nativeLogHits'],'Build/native log failed'
        m=load(PACKAGE/'instrumentation/manifest.json');restore=load(PACKAGE/'instrumentation/restoration.json')
        assert restore['currentProductRestored'] and all(x['restored'] for x in restore['files'])
        assert all(sha(PROJECT/'Assets/HybridLumenGI'/p)==v for p,v in m['productSourceSha256'].items())
        selected={x['path']:x for x in b['inputs']}
        assert all(selected['Assets/HybridLumenGI/'+p]['sha256']==v for p,v in m['productSourceSha256'].items())
        assert b['scene']=='Assets/RuntimeAudit/Functional.unity' and b['unity']=='6000.0.85f1'
        assert not (PACKAGE/'build-products.json').exists(),'Build product manifest already frozen'
        files=[{'path':p.relative_to(BUILD).as_posix(),'bytes':p.stat().st_size,'sha256':sha(p)} for p in sorted(BUILD.rglob('*')) if p.is_file()]
        assert any(x['path'].endswith('/Managed/Assembly-CSharp.dll') for x in files),'Actual loaded managed assembly missing'
        assert any(x['path'].endswith('resources.assets') for x in files),'Built Resources data missing'
        save(PACKAGE/'build-products.json',{'root':str(BUILD),'files':files})
        report.update(currentSourceBuildVerified=True,productFileCount=len(files),productBytes=sum(x['bytes'] for x in files),sourceCommit=m['baseline'],
                      productSourceCount=len(m['productSourceSha256']),restored=True)
    except Exception as e:report['failure']=str(e);report['traceback']=traceback.format_exc()
    save(PACKAGE/'build-analysis.json',report);print(json.dumps(report));return report['currentSourceBuildVerified']

def verify_products():
    m=load(PACKAGE/'build-products.json');root=Path(m['root'])
    assert all((root/f['path']).stat().st_size==f['bytes'] and sha(root/f['path'])==f['sha256'] for f in m['files']),'Built product bytes changed'
    assert set(f['path'] for f in m['files'])=={p.relative_to(root).as_posix() for p in root.rglob('*') if p.is_file()},'Built product file set changed'
    return sha(PACKAGE/'build-products.json')

def run(mode):
    package=PACKAGE/(mode+'-windowed')
    report={'mode':mode,'playerSmokeVerified':False,'fullProductionAccepted':False,'failures':{},
            'scope':f'Current Development/Mono/DX12 {mode}120frame capture and natural exit; no image/performance acceptance'}
    data={}
    def check(name,fn):
        report[name]=False
        try:fn();report[name]=True
        except Exception as error:report['failures'][name]={'error':str(error),'traceback':traceback.format_exc()}
    def products():report['buildProductsManifestSha256']=verify_products()
    def collect():
        runs=list((package/'run').glob('*/run.json'));assert len(runs)==1,'Unique fresh run required'
        folder=runs[0].parent;meta=load(runs[0]);frames=lines(folder/'frames.jsonl')
        data.update(folder=folder,meta=meta,frames=frames);report['runId']=folder.name
        report['collection']={k:meta[k] for k in ['status','renderedFrames','captures','errors','firstRenderWaitSeconds']}
        assert meta['requestedFrames']==meta['renderedFrames']==120 and meta['captures']==5 and meta['errors']==0,'Capture count/errors'
        assert meta['api']=='Direct3D12' and meta['width']==640 and meta['height']==360,'Capture configuration'
        assert [f['logicalFrame'] for f in frames]==list(range(120)),'Missing/duplicate capture receipt'
    def backend():
        diagnostics=[json.loads(f['diagnosticsJson']) for f in data['frames']];stable=diagnostics[104:120]
        assert len(stable)==16;report['lastDiagnostics']=diagnostics[-1]
        report['startupBackend']=[{'frame':i,'hardware':d['hardwareBackend'],'exactSoftware':d['exactSoftwareGeometry'],
            'fallbacks':d['hardwareFallbacks'],'materialStatus':d['hardwareMaterialStatus']} for i,d in enumerate(diagnostics[:104])]
        assert all(d['publishedInstances']>0 and d['readyCards']>0 and d['hardwareMaterialFrameBytes']>0 and
            d['hardwareMaterialStatus']=='Uploads and both consumers bound; GPU completion unproven' for d in stable),'Prepared consumers missing'
        assert all((d['hardwareBackend'] and d['hardwareMeshes']>0 and d['hardwareAttributeBytes']>0) if mode=='hardware' else
            (not d['hardwareBackend'] and d['exactSoftwareGeometry'] and d['softwareGeometryBytes']>0) for d in stable),'Actual backend mismatch'
        coverage=[d['hardwareFallbacks'] for d in stable]
        report['stableUnrepresentedInstanceGauge']={'minimum':min(coverage),'maximum':max(coverage),'meaning':'Instance coverage gauge, not event counter'}
        assert min(coverage)==max(coverage),'Unexplained stable coverage change'
        if mode=='hardware':assert max(coverage)==0,'Hardware stable-window instances remain unrepresented'
    def gi():
        folder=data['folder'];rows=lines(folder/'functional.jsonl');frames=data['frames']
        assert [r['frame'] for r in rows]==list(range(120)),'Missing/duplicate functional receipt'
        assert all(r['engineFrame']==f['engineFrame'] and r['giFrame']==json.loads(f['diagnosticsJson'])['frame'] for r,f in zip(rows,frames)),'Receipt engine/GI identity mismatch'
        report['functionalDuplicateRows']=0;report['inlineRayTracingSupported']=all(r['inlineRT'] for r in rows[104:120])
        for f in [30,119]:
            row=rows[f];assert row['historyMaximum']>1 and row['historyFraction']>0 and row['validIdentityPixels']>0,'History/identity coverage'
            assert row['momentsFormat0']==row['momentsFormat1']=='R32G32B32A32_SFloat','Moments format'
        w,h=map(int,(folder/'denoise-size.txt').read_text(encoding='utf-8').split());assert [w,h]==[320,180]
        report['giSize']=[w,h];payload={};receipts=[];row=rows[119]
        for field in ['history','moments','geometry','material']:
            path=folder/f'denoise-0119-{field}.rgba32f';receipt=load(Path(str(path)+'.json'))
            assert receipt['file']==path.name and receipt['field']==field and receipt['sha256']==sha(path),'Payload hash/name mismatch'
            assert all(receipt[k]==row[k] for k in ['frame','engineFrame','giFrame','readIndex']),'Payload receipt identity mismatch'
            assert receipt['width']==w and receipt['height']==h and path.stat().st_size==w*h*16,'Payload size'
            if field=='moments':assert receipt['format']=='R32G32B32A32_SFloat'
            a=np.fromfile(path,'<f4').reshape(h,w,4);assert np.isfinite(a).all(),field
            payload[field]=a;receipts.append(receipt)
        history=payload['history'];samples=payload['moments'][:,:,2]
        report['payloadReceipts']=receipts
        report['measurementCounts']={'valid':int((history[:,:,3]>0).sum()),'unknown':int((history[:,:,3]<0).sum()),'absent':int((history[:,:,3]==0).sum())}
        assert report['measurementCounts']['valid']>0,'No valid measurements'
        report['measuredBlackCount']=int(((history[:,:,3]>0)&np.all(history[:,:,:3]==0,axis=2)).sum())
        report['maximumHistorySamples']=float(samples.max());report['historyFraction']=float((samples>1).mean())
        assert report['maximumHistorySamples']==row['historyMaximum'] and abs(report['historyFraction']-row['historyFraction'])<1e-6,'Statistics/payload disagreement'
        assert report['maximumHistorySamples']>1,'No mature history'
    def hdr():
        captures=[f for f in data['frames'] if f['captured']]
        assert [f['logicalFrame'] for f in captures]==[0,30,60,90,119]
        for f in captures:
            path=data['folder']/f['raw'];assert path.stat().st_size==640*360*16 and np.isfinite(np.fromfile(path,'<f4')).all(),'Invalid HDR payload'
        report['validatedHdrCaptures']=len(captures)
    def native():
        exit=load(package/'native-exit.json');report['nativeExitCode']=exit['exitCode'];report['watchdogTerminated']=exit['watchdogTerminated']
        report['nativeLogHits']=hits(package/'player.log')
        raw=(package/'player.log').read_text(encoding='utf-8-sig',errors='replace')
        events=[line for line in raw.splitlines() if line.startswith('HybridLumenGI shutdown ')]
        report['shutdownEvents']=events
        assert exit['exitCode']==0 and not exit['watchdogTerminated'] and not report['nativeLogHits'],'Native exit/resource failure'
        names=['begin','owners withdrawn','idle fence submitted','completed owner destroyed','generic drain complete']
        indices=[next(i for i,e in enumerate(events) if e.startswith('HybridLumenGI shutdown '+name+':')) for name in names]
        assert indices==sorted(indices),'Shutdown order missing/invalid'
        assert 'outside=True' in events[indices[0]],'No real boundary before native shutdown'
        final=events[-1];assert 'generic drain complete:' in final,'No final completed drain'
        for field in ['owned','pending','unknown','failed','failedWithdrawals','materialBytes','arenaBytes','deformationBytes','deformationJobs','deformationCleanupFailed']:
            assert re.search(r'(?:, |: )'+field+r'=0(?:,|$)',final),'Final owner accounting not zero: '+field
    for name,fn in [('buildProductsVerified',products),('collectionVerified',collect),('backendVerified',backend),('giDataVerified',gi),('hdrVerified',hdr),('normalExitAccepted',native)]:check(name,fn)
    report['playerSmokeVerified']=not report['failures']
    save(package/'analysis.json',report)
    print(json.dumps({k:v for k,v in report.items() if k not in ['startupBackend','lastDiagnostics']}))
    return report['playerSmokeVerified']

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('action',choices=['build','products','software','hardware']);a=p.parse_args()
    if a.action=='products':print(verify_products());ok=True
    elif a.action=='build':ok=build()
    else:ok=run(a.action)
    raise SystemExit(0 if ok else 1)
