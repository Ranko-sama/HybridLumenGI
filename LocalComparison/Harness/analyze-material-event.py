"""Finite material-event artifact checks. No image brightness oracle."""
import argparse,hashlib,importlib.util,json,traceback,struct
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];H=ROOT/'LocalComparison/Harness';PACKAGE=ROOT/'LocalComparison/Review/material-mpb-propagation-01'
PROJECT=Path('I:/Unity test/Project');BUILD=Path('I:/Unity test/Comparison/Builds/MaterialEvent24')
spec=importlib.util.spec_from_file_location('smoke',H/'analyze-player-smoke.py');smoke=importlib.util.module_from_spec(spec);spec.loader.exec_module(smoke)
smoke.PACKAGE=PACKAGE;smoke.BUILD=BUILD
load=smoke.load;save=smoke.save;sha=smoke.sha;lines=smoke.lines

def vector(value):return [value[k] for k in ['x','y','z','w']]
def floats(blob,offset,count=4):return list(struct.unpack_from('<'+'f'*count,blob,offset))
def uints(blob,offset,count=4):return list(struct.unpack_from('<'+'I'*count,blob,offset))
def equal_json_float32(a,b):return all(abs(x-y)<=1e-6*max(1,abs(x),abs(y)) for x,y in zip(a,b))

def run():
    native=PACKAGE/'native-window';report={'fullProductionAccepted':False,'eventVerified':False,'productCounterexample':False}
    try:
        report['buildProductsManifestSha256']=smoke.verify_products()
        report['nativeExit']=load(native/'native-exit.json');report['nativeLogHits']=smoke.hits(native/'player.log')
        candidates=list((native/'run').glob('*/run.json'));assert len(candidates)==1,'Expected one actual run directory'
        folder=candidates[0].parent;meta=load(candidates[0]);report['runId']=folder.name;report['collection']=meta
        rows=lines(folder/'material-frames.jsonl') if (folder/'material-frames.jsonl').exists() else []
        payloads=lines(folder/'payloads.jsonl') if (folder/'payloads.jsonl').exists() else []
        report['observerResult']=load(folder/'material-event-result.json') if (folder/'material-event-result.json').exists() else None
        report['actualSourceFrames']=len(rows);report['payloadCount']=len(payloads)
        unique=set()
        for payload in payloads:
            key=(payload['logical'],payload['stage']);assert key not in unique,'Duplicate payload';unique.add(key)
            p=folder/payload['file'];assert p.stat().st_size==payload['bytes']==payload['stride']*payload['count'] and sha(p)==payload['sha256'],'Payload integrity'
            assert payload['engine']==rows[payload['logical']]['engine'] and payload['gi']==rows[payload['logical']]['gi'],'Payload provenance'
        report['payloadIntegrityVerified']=True
        if meta['errors'] or not (folder/'event.json').exists() or len(rows)!=256:
            report['status']='uncovered' if 'UNCOVERED:' in meta.get('error','') else 'stopped-first-failure'
            report['failure']=meta.get('error','Incomplete event experiment');return report
        assert report['nativeExit']['exitCode']==0 and not report['nativeExit']['watchdogTerminated'] and not report['nativeLogHits'],'Native exit/resource error'
        assert meta['requestedFrames']==meta['renderedFrames']==256 and meta['captures']==4
        captured=[f['logicalFrame'] for f in lines(folder/'frames.jsonl') if f['captured']]
        assert captured==[159,160,175,255]
        assert [r['logical'] for r in rows]==list(range(256))
        event=load(folder/'event.json');selection=load(folder/'selection.json');report['event']=event;report['selection']=selection
        assert event['logical']==160 and vector(event['baseColor'])==[0,0,1,1]
        report['sourceTimeline']=[];report['sourceViolations']=[];baseline={s['role']:s for s in rows[159]['sources']}
        baseline_upload={u['role']:floats(bytes(u['record240']),16) for u in rows[159]['uploads']}
        for f in rows[144:]:
            actual={s['role']:s for s in f['sources']};uploads={u['role']:u for u in f['uploads']}
            detail={'logical':f['logical'],'gi':f['gi'],'epoch':f['epoch'],'historyAllowed':f['historyAllowed'],'sources':[]}
            for role in ['target-slot0','target-slot1','control']:
                s=actual[role];b=baseline[role];u=uploads[role];record=bytes(u['record240']);binding=bytes(u['binding32'])
                target_event=role=='target-slot0' and f['logical']>=160
                expected=[0,0,1,1] if target_event else vector(b['baseColor'])
                expected_upload=[0,0,1,1] if target_event else baseline_upload[role]
                checks={'baseColor':vector(s['baseColor'])==expected,'geometryStable':(s['token'],s['geometryGeneration'],s['matrix'])==(b['token'],b['geometryGeneration'],b['matrix']),
                    'materialGeneration':s['materialGeneration']!=b['materialGeneration'] if target_event else s['materialGeneration']==b['materialGeneration'],
                    'origin':s['origin']==(3 if target_event else b['origin']),
                    'uploadColor':equal_json_float32(floats(record,16),expected_upload),'boundUpload':uints(record,0)[0]==u['batchGeneration']==uints(binding,0)[1] and uints(binding,0)[0]==u['index']}
                if f['logical']==160 and role=='target-slot0':checks['oldHistoryRejected']=(s['reusable']&1)==0
                if not all(checks.values()):report['sourceViolations'].append({'logical':f['logical'],'role':role,'checks':checks})
                detail['sources'].append({'role':role,'materialGeneration':s['materialGeneration'],'baseColor':vector(s['baseColor']),'origin':s['origin'],
                    'key':[s['keyLow'],s['keyHigh']],'reusable':s['reusable'],'uploadColor':floats(record,16),'bindingSource':uints(binding,16),'batch':u['batchGeneration']})
            report['sourceTimeline'].append(detail)
        report['samples']=[]
        for f in [*range(159,176),191,223,255]:
            blob=(folder/f'material-{f:04d}-samples.bin').read_bytes()
            for lane,point in enumerate(selection['points']):
                offset=lane*272
                report['samples'].append({'logical':f,'role':point['role'],'pixel':uints(blob,offset),'identity':uints(blob,offset+16),'previousIdentity':uints(blob,offset+32),
                    'candidate':uints(blob,offset+48),'raw':floats(blob,offset+64),'material':floats(blob,offset+80),'geometry':floats(blob,offset+96),
                    'history':floats(blob,offset+112),'moments':floats(blob,offset+128),'previousHistory':floats(blob,offset+144),'previousMoments':floats(blob,offset+160),
                    'receiverDiffuse':floats(blob,offset+176),'objectKey':uints(blob,offset+256,2),'objectFlags':uints(blob,offset+264,2)})
        report['historyViolations']=[]
        s=next(s for s in report['samples'] if s['logical']==160 and s['role']=='target-slot0')
        known=s['raw'][3]>0 and s['geometry'][2]>=1 and s['geometry'][3]>1e-6
        report['eventCurrentMeasurementKnown']=known
        if (s['objectFlags'][0]&1)!=0 or s['identity'][:2]==s['previousIdentity'][:2]:report['historyViolations'].append('Old target material identity remained reusable')
        if known and (s['moments'][2]!=1 or s['history'][3]<=0):report['historyViolations'].append('Known new target measurement did not start at count1')
        report['eventVerified']=not report['sourceViolations'] and not report['historyViolations']
        report['candidateProductCounterexample']=not report['eventVerified'];report['status']='event-collected-needs-path-review'
        return report
    except Exception as ex:report.update(status='analysis-failed',failure=str(ex),traceback=traceback.format_exc());return report
    finally:
        save(native/'analysis.json',report)

def build():
    report={'currentSourceBuildVerified':False,'fullProductionAccepted':False}
    try:
        result=load(PACKAGE/'build-report.json');exit=load(PACKAGE/'build-exit.json');m=load(PACKAGE/'instrumentation/manifest.json')
        restore=load(PACKAGE/'instrumentation/restoration.json');report['nativeLogHits']=smoke.hits(PACKAGE/'build-unity.log')
        assert exit['exitCode']==0 and result['result']=='Succeeded' and result['errors']==0 and not report['nativeLogHits'],'Build/native failure'
        assert restore['currentProductRestored'] and all(x['restored'] for x in restore['files'])
        assert all(sha(ROOT/p)==v and sha(PROJECT/'Assets/HybridLumenGI'/p)==v for p,v in m['productSourceSha256'].items())
        expected={'Assets/HybridLumenGI/'+p:v for p,v in m['productSourceSha256'].items()}
        expected.update({f['path']:f['sha256'] for f in m['files']})
        actual={x['path']:x['sha256'] for x in result['inputs']}
        assert all(actual.get(p)==v for p,v in expected.items()),'Actual build did not use frozen staged inputs'
        assert result['scene']=='Assets/RuntimeAudit/Functional.unity' and result['unity']=='6000.0.85f1'
        assert not (PACKAGE/'build-products.json').exists(),'Build inventory already frozen'
        files=[{'path':p.relative_to(BUILD).as_posix(),'bytes':p.stat().st_size,'sha256':sha(p)} for p in sorted(BUILD.rglob('*')) if p.is_file()]
        assert any(x['path'].endswith('/Managed/Assembly-CSharp.dll') for x in files)
        save(PACKAGE/'build-products.json',{'root':str(BUILD),'files':files})
        report.update(currentSourceBuildVerified=True,productSourceCount=len(m['productSourceSha256']),stagedFiles=len(m['files']),sourceCommit=m['baseline'],productFileCount=len(files))
    except Exception as ex:report.update(failure=str(ex),traceback=traceback.format_exc())
    save(PACKAGE/'build-analysis.json',report);print(json.dumps(report));return report['currentSourceBuildVerified']

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('action',choices=['build','products','run']);args=parser.parse_args()
    if args.action=='build':ok=build()
    elif args.action=='run':
        report=run();print(json.dumps({k:v for k,v in report.items() if k not in ['sourceTimeline','samples','collection']}));ok=report.get('status')!='analysis-failed'
    else:print(smoke.verify_products());ok=True
    raise SystemExit(0 if ok else 1)
