"""Bounded build/backend/data/normal-exit acceptance. No image-quality oracle."""
import argparse,hashlib,json,re,traceback
from pathlib import Path
import numpy as np
from native_log_check import scan

ROOT=Path(__file__).resolve().parents[2]
PACKAGE=ROOT/'LocalComparison/Review/current-player-smoke-01'
PROJECT=Path('I:/Unity test/Project')
BUILD=Path('I:/Unity test/Comparison/Builds/CurrentSource9176b0f')
def load(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def lines(p):return [json.loads(s) for s in p.read_text(encoding='utf-8-sig').splitlines() if s.strip()]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def save(p,v):p.write_text(json.dumps(v,indent=2)+'\n',encoding='utf-8')
def hits(path):
    result=scan(path)
    extra={'scratch':r'D3D12ScratchBufferInternal','d3d-extra':r'\[d3d12\] Unreleased',
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
    report={'mode':mode,'playerSmokeVerified':False,'normalExitAccepted':False,'fullProductionAccepted':False,
            'scope':'Current Development/Mono/DX12 finite120frame scene and normal exit only; no dynamic/image/performance acceptance'}
    try:
        report['buildProductsManifestSha256']=verify_products();exit=load(package/'native-exit.json')
        report['nativeExitCode']=exit['exitCode'];report['watchdogTerminated']=exit['watchdogTerminated']
        report['nativeLogHits']=hits(package/'player.log')
        report['normalExitAccepted']=exit['exitCode']==0 and not exit['watchdogTerminated'] and not report['nativeLogHits']
        runs=list((package/'run').glob('*/run.json'));assert len(runs)==1,'Unique fresh run required';folder=runs[0].parent
        meta=load(runs[0]);frames=lines(folder/'frames.jsonl');report['runId']=folder.name
        report['collection']={k:meta[k] for k in ['status','renderedFrames','captures','errors','firstRenderWaitSeconds']}
        assert meta['requestedFrames']==meta['renderedFrames']==120 and meta['captures']==5 and meta['errors']==0
        assert meta['api']=='Direct3D12' and meta['width']==640 and meta['height']==360
        assert [f['logicalFrame'] for f in frames]==list(range(120))
        diagnostics=[json.loads(f['diagnosticsJson']) for f in frames];stable=diagnostics[104:120]
        report['lastDiagnostics']=diagnostics[-1]
        report['startupBackend']=[{'frame':i,'hardware':d['hardwareBackend'],'exactSoftware':d['exactSoftwareGeometry'],
                                  'fallbacks':d['hardwareFallbacks'],'materialStatus':d['hardwareMaterialStatus']} for i,d in enumerate(diagnostics[:104])]
        assert all(d['publishedInstances']>0 and d['readyCards']>0 and d['hardwareMaterialFrameBytes']>0 and
                   d['hardwareMaterialStatus']=='Uploads and both consumers bound; GPU completion unproven' for d in stable),'Prepared geometry/material consumer path missing'
        assert all((d['hardwareBackend'] and d['hardwareMeshes']>0 and d['hardwareAttributeBytes']>0) if mode=='hardware' else
                   (not d['hardwareBackend'] and d['exactSoftwareGeometry'] and d['softwareGeometryBytes']>0) for d in stable),'Requested stable backend not actually selected'
        coverage=[d['hardwareFallbacks'] for d in stable]
        report['stableUnrepresentedInstanceGauge']={'minimum':min(coverage),'maximum':max(coverage),
            'meaning':'Recomputed published instances outside backend, not cumulative fallback events'}
        assert min(coverage)==max(coverage),'Stable-window represented-instance coverage changed; requires explanation'
        functional=lines(folder/'functional.jsonl');first={}
        for row in functional:first.setdefault(row['frame'],row)
        report['functionalDuplicateRows']=len(functional)-len(first)
        report['inlineRayTracingSupported']=all(first[f]['inlineRT'] for f in range(104,120))
        for f in [30,119]:
            row=first[f];assert row['historyMaximum']>1 and row['historyFraction']>0 and row['validIdentityPixels']>0,'Existing history/identity completion coverage missing'
            assert row['momentsFormat0']==row['momentsFormat1']=='R32G32B32A32_SFloat','Actual moments allocation format changed'
        w,h=map(int,(folder/'denoise-size.txt').read_text(encoding='utf-8').split());report['giSize']=[w,h]
        assert [w,h]==[320,180]
        payload={}
        for field in ['history','moments','geometry','material']:
            p=folder/f'denoise-0119-{field}.rgba32f';assert p.stat().st_size==w*h*16
            a=np.fromfile(p,'<f4').reshape(h,w,4);assert np.isfinite(a).all(),field
            payload[field]=a
        history=payload['history'];report['measurementCounts']={'valid':int((history[:,:,3]>0).sum()),'unknown':int((history[:,:,3]<0).sum()),'absent':int((history[:,:,3]==0).sum())}
        assert report['measurementCounts']['valid']>0,'No completed GI measurements'
        report['measuredBlackCount']=int(((history[:,:,3]>0)&np.all(history[:,:,:3]==0,axis=2)).sum())
        report['maximumHistorySamples']=float(payload['moments'][:,:,2].max())
        assert report['maximumHistorySamples']>1
        for f in frames:
            if f['captured']:
                p=folder/f['raw'];assert p.stat().st_size==640*360*16 and np.isfinite(np.fromfile(p,'<f4')).all(),'Final HDR payload invalid'
        assert report['normalExitAccepted'],'Full native process exit/log not accepted'
        report['playerSmokeVerified']=True
    except Exception as e:report['failure']=str(e);report['traceback']=traceback.format_exc()
    save(package/'analysis.json',report);print(json.dumps({k:v for k,v in report.items() if k not in ['startupBackend','lastDiagnostics']}));return report['playerSmokeVerified']

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('action',choices=['build','products','software','hardware']);a=p.parse_args()
    if a.action=='products':print(verify_products());ok=True
    elif a.action=='build':ok=build()
    else:ok=run(a.action)
    raise SystemExit(0 if ok else 1)
