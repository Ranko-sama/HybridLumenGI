"""Bounded interpretation of one saved deformation run; never executes a GPU query."""
import argparse, importlib.util, json, math, struct, traceback
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];H=ROOT/'LocalComparison/Harness'
PACKAGE=ROOT/'LocalComparison/Review/deformation-snapshot-propagation-01'
BUILD=Path('I:/Unity test/Comparison/Builds/DeformationEvent26')
spec=importlib.util.spec_from_file_location('base',H/'analyze-material-event.py');base=importlib.util.module_from_spec(spec);spec.loader.exec_module(base)
base.PACKAGE=PACKAGE;base.BUILD=BUILD;base.smoke.PACKAGE=PACKAGE;base.smoke.BUILD=BUILD
load=base.load;save=base.save;sha=base.sha;lines=base.lines;u=base.uints;f=base.floats
FROZEN=[159,160,161,162,175,191,223,255]
def mesh(folder,name):
    receipt=load(folder/name);blob=(folder/receipt['file']).read_bytes();assert len(blob)==receipt['bytes'] and sha(folder/receipt['file'])==receipt['sha256']
    offset=0;out={'receipt':receipt}
    for key,components in [('positions',3),('normals',3),('tangents',4),('uv',2)]:
        count=u(blob,offset,1)[0];offset+=4
        out[key]=[f(blob,offset+i*components*4,components) for i in range(count)];offset+=count*components*4
        assert all(math.isfinite(v) for values in out[key] for v in values),'Nonfinite saved mesh'
    count=u(blob,offset,1)[0];offset+=4;out['indices']=[];out['topologies']=[]
    for _ in range(count):
        topology,n=u(blob,offset,2);offset+=8;out['topologies'].append(topology);out['indices'].append(u(blob,offset,n));offset+=n*4
    assert offset==len(blob);return out
def equal_mesh(a,b):return all(a[k]==b[k] for k in ['positions','normals','tangents','uv','indices','topologies'])
def sources(row):return {s['role']:s for s in row['sources']}
def key(s):return [s['keyLow'],s['keyHigh']]
def parse_sample(blob,p):
    result={k:u(blob,p+off) for k,off in [('pixel',0),('identity',16),('previousIdentity',32),('candidate',48)]}
    result.update({k:f(blob,p+off) for k,off in [('raw',64),('material',80),('geometry',96),('history',112),('moments',128),('previousHistory',144),('previousMoments',160)]})
    result['objectKey']=u(blob,p+256,2);result['objectFlags']=u(blob,p+264,2);return result
def run():
    native=PACKAGE/'native-window';report={'fullProductionAccepted':False,'productCounterexample':False,'candidateProductCounterexample':False,
        'nativeExitAccepted':False,'eventSourceVerified':False,'coherentPublicationVerified':False,'newGeometryBufferCoverage':False,
        'actualNewGeometryHitCoverage':False,'actualDisplacedTriangleHitCoverage':False,'targetHistoryResponseVerified':False,'violations':[],'coverageGaps':[]}
    try:
        report['buildProductsManifestSha256']=base.smoke.verify_products()
        report['nativeExit']=load(native/'native-exit.json');report['nativeLogHits']=base.smoke.hits(native/'player.log')
        runs=list((native/'run').glob('*/run.json'));assert len(runs)==1,'Expected unique run';folder=runs[0].parent
        report['runId']=folder.name;meta=load(runs[0]);report['collection']=meta
        rows=lines(folder/'deformation-frames.jsonl') if (folder/'deformation-frames.jsonl').exists() else []
        life=lines(folder/'geometry-lifecycle.jsonl') if (folder/'geometry-lifecycle.jsonl').exists() else []
        payloads=lines(folder/'payloads.jsonl') if (folder/'payloads.jsonl').exists() else []
        report['observerResult']=load(folder/'deformation-event-result.json') if (folder/'deformation-event-result.json').exists() else None
        report['frames']=len(rows);report['payloads']=len(payloads);report['lifecycle']=life;unique=set()
        for r in payloads:
            label=(r['logical'],r['stage']);assert label not in unique;unique.add(label);path=folder/r['file']
            assert path.stat().st_size==r['bytes']==r['stride']*r['count'] and sha(path)==r['sha256'],'Payload integrity'
            assert r['engine']==rows[r['logical']]['engine'] and r['gi']==rows[r['logical']]['gi'] and r['screenMask']==r['traceMask']==3
        report['payloadIntegrityVerified']=True
        if meta['errors'] or len(rows)!=256 or not (folder/'event.json').exists():
            report.update(status='stopped-first-failure',failure=meta.get('error','Incomplete bounded event'));return report
        assert not (folder/'geometry-observer-errors.txt').exists(),'Lifecycle observer failed'
        assert report['nativeExit']['exitCode']==0 and not report['nativeExit']['watchdogTerminated'] and not report['nativeLogHits'],'Native failure'
        report['nativeExitAccepted']=True
        assert meta['captures']==4 and [r['logicalFrame'] for r in lines(folder/'frames.jsonl') if r['captured']]==[159,160,175,255]
        assert [r['logical'] for r in rows]==list(range(256))
        assert load(folder/'event.json')['logical']==160
        original=mesh(folder,'mesh-initial.json');before=mesh(folder,'mesh-before-event.json');after=mesh(folder,'mesh-after-event.json')
        assert equal_mesh(original,before),'Source changed before event'
        expected=[[struct.unpack('<f',struct.pack('<f',p[0]+(0.8 if p[1]>0 else 0)))[0],p[1],p[2]] for p in before['positions']]
        assert expected==after['positions'],'Actual event positions differ from frozen edit'
        assert all(before[k]==after[k] for k in ['tangents','uv','indices','topologies'])
        assert before['receipt']['mesh']==after['receipt']['mesh'],'Event replaced visible mesh'
        requests=[r for r in life if r['phase']=='request'];assert len(requests)==2 and requests[-1]['logical']==160
        captures=[r for r in life if r['phase']=='capture'];publications=[r for r in life if r['phase']=='publish']
        report['eventSourceVerified']=True
        report['publicationTimes']=[{'logical':r['logical'],'engine':r['engine'],'captureFrame':r['captureFrame'],'publishedCaptureFrame':r['publishedCaptureFrame'],'mesh':r['mesh']} for r in publications]
        new_pub=next((r for r in publications if r['logical']>=160),None)
        coherent=True
        for r in publications:
            match=next(c for c in captures if c['mesh']==r['mesh'] and c['jobGeneration']==r['jobGeneration'])
            actual=mesh(folder,r['meshReceipt']);captured=mesh(folder,match['meshReceipt']);expected=after if r['logical']>=160 else before
            assert equal_mesh(actual,captured) and equal_mesh(actual,expected),'Published/captured/input arrays disagree'
            assert r['linksCoherent'] and r['captureFrame']==r['publishedCaptureFrame'] and r['engine']>=r['captureFrame']
            assets=load(folder/r['assetsReceipt']);path=folder/assets['sdfFile'];blob=path.read_bytes()
            assert len(blob)==assets['sdfBytes']==assets['resolution']**3*4 and sha(path)==assets['sdfSha256']
            assert all(math.isfinite(v) for (v,) in struct.iter_unpack('<f',blob))
            mesh(folder,assets['captureMeshReceipt'])
            assert assets['charts'],'Published charts absent'
        report['coherentPublicationVerified']=new_pub is not None and coherent
        destroyed=[r for r in life if r['phase']=='destroyed']
        report['snapshotRetirementVerified']=bool(publications) and all(
            len([d for d in destroyed if d['mesh']==p['mesh'] and d['sequence']>p['sequence'] and d['snapshotReservation']==0])==1
            for p in publications)
        if not report['snapshotRetirementVerified']:report['coverageGaps'].append('Published snapshot retirement receipts are not complete')
        if new_pub is None:report['coverageGaps'].append('No new CPU publication by255')
        detail=set(FROZEN)
        dispatch=next((r['logical'] for r in rows if r['firstNewDispatch']>=160),None)
        for start in [new_pub['logical'] if new_pub else None,dispatch]:
            if start is not None:detail.update(range(start,min(256,start+4)))
        assert set(r['logical'] for r in payloads)<=detail,'Unplanned detail frame'
        backend_stages={'backend-'+s for s in ['instancesBuffer','surfaceBuffer','bindingsBuffer','objectToWorldBuffer']}
        initial_stages={'identity-current','identity-previous','geometry','material','raw','history','moments','previous-history','previous-moments','receiver-diffuse','receiver-candidates','receiver-objects'}
        for logical in detail:
            stages={r['stage'] for r in payloads if r['logical']==logical};status=rows[logical]['gpuDetailStatus']
            if status=='recorded':assert stages==backend_stages|(initial_stages if logical==159 else {'samples','actual-paths'}),'Missing or unexpected detail stage'
            else:assert status=='uncovered-current-backend-or-identity' and not stages,'Detail frame was silently omitted'
        report['detailFrames']=sorted(detail);report['firstNewDispatchRecorded']=dispatch
        baseline=sources(rows[159]);report['sourceTimeline']=[]
        for row in rows[144:]:
            ss=sources(row);report['sourceTimeline'].append({'logical':row['logical'],'visibleMesh':row['visibleMesh'],'snapshotMesh':row['snapshotMesh'],
                'surfaceMesh':row['surfaceMesh'],'backendMesh':row['backendMesh'],'proxyGeometry':row['geometryRevision'],
                'surfaceGeometry':row['surfaceGeometryRevision'],'backendGeometry':row['backendGeometryRevision'],'backendVersion':row['backendVersion'],
                'gpuDetailStatus':row['gpuDetailStatus'],'sources':row['sources']})
            for role,s in ss.items():
                b=baseline[role]
                if s['matrix']!=b['matrix'] or s['baseColor']!=b['baseColor'] or s['materialGeneration']!=b['materialGeneration']:
                    report['violations'].append({'logical':row['logical'],'kind':'Unexpected transform/material change','role':role})
                if role=='control' and (s['token'],s['geometryGeneration'],key(s))!=(b['token'],b['geometryGeneration'],key(b)):
                    report['violations'].append({'logical':row['logical'],'kind':'Static source identity changed'})
                if role=='target' and row['logical']>=160 and s['geometryFingerprint']!=b['geometryFingerprint'] and s['geometryGeneration']==b['geometryGeneration']:
                    report['violations'].append({'logical':row['logical'],'kind':'Changed visible fingerprint retained geometry generation'})
            if new_pub and row['logical']>=new_pub['logical'] and row['snapshotMesh']!=new_pub['mesh']:
                report['violations'].append({'logical':row['logical'],'kind':'Current snapshot did not follow actual publication'})
        report['bufferChecks']=[];report['targetHits']=[]
        for logical in sorted(detail):
            row=rows[logical]
            if row['gpuDetailStatus']!='recorded':continue
            blobs={stage:(folder/next(r['file'] for r in payloads if r['logical']==logical and r['stage']==stage)).read_bytes()
                for stage in ['backend-instancesBuffer','backend-surfaceBuffer','backend-bindingsBuffer','backend-objectToWorldBuffer']}
            ib=blobs['backend-instancesBuffer'];sb=blobs['backend-surfaceBuffer'];mb=blobs['backend-objectToWorldBuffer']
            new=bool(new_pub and row['backendMesh']==new_pub['mesh']);source_mesh=after if new else before
            for instance in range(row['backendFirstInstance'],row['backendFirstInstance']+row['backendInstanceCount']):
                q=instance*128;slot,offset,count,submesh=u(ib,q+64);stable,owner,revision,_=u(ib,q+80)
                assert slot==row['sceneSlot'] and [stable,owner]==[int(row['sceneIdentity']['x']),int(row['sceneIdentity']['y'])]
                assert revision==row['backendGeometryRevision']==row['surfaceGeometryRevision']==row['geometryRevision'],'Consumer generation coherence'
                indices=source_mesh['indices'][submesh];assert count*3==len(indices)
                for primitive in range(count):
                    for vertex in range(3):
                        assert f(sb,(offset+primitive)*96+vertex*16,3)==source_mesh['positions'][indices[primitive*3+vertex]],'Bound GPU triangle differs from snapshot'
                report['bufferChecks'].append({'logical':logical,'instance':instance,'mesh':row['backendMesh'],'revision':revision,'newSnapshot':new,'triangles':count})
                if new:report['newGeometryBufferCoverage']=True
            if logical==159:continue # No selected trace existed before159 full-state selection.
            trace=(folder/f'deformation-{logical:04d}-actual-paths.bin').read_bytes()
            for lane in [0,1]:
                begin=lane*256*128;header=u(trace,begin);label=u(trace,begin+16);count=header[1]
                assert header[2:]==[1,0] and label==[logical,row['gi'],lane,0x47434131] and 2<=count<=256
                for n in range(1,count):
                    p=begin+n*128;meta=u(trace,p);assert meta[1]==n
                    if meta[0] not in [31,200] or u(trace,p+16,1)[0]!=1:continue
                    a=u(trace,p+16);b=u(trace,p+32);kind=u(trace,p+48)
                    if a[2]!=int(row['sceneIdentity']['x']) or kind[0]!=1 or not (kind[1]&16):continue
                    revision,submesh,primitive,instance=b;q=instance*128
                    assert u(ib,q+80,3)==[a[2],a[3],revision] and u(ib,q+76,1)[0]==submesh,'Hit/bound instance identity'
                    offset=u(ib,q+68,1)[0];triangle=[f(sb,(offset+primitive)*96+j*16,3) for j in range(3)]
                    bary=f(trace,p+112+8,2);weights=[1-bary[0]-bary[1],bary[0],bary[1]]
                    local=[sum(weights[j]*triangle[j][k] for j in range(3)) for k in range(3)]+[1]
                    matrix=f(mb,instance*64,16);world=[sum(matrix[c*4+r]*local[c] for c in range(4)) for r in range(3)]
                    position=f(trace,p+64,3);error=max(abs(a-b) for a,b in zip(world,position));tolerance=1e-4*max(1,*map(abs,position))
                    assert error<=tolerance,'Actual triangle hit position disagrees with bound geometry'
                    changed=any(before['positions'][i]!=after['positions'][i] for i in after['indices'][submesh][primitive*3:primitive*3+3])
                    report['targetHits'].append({'logical':logical,'lane':lane,'context':meta[2],'call':meta[3],'code':meta[0],
                        'revision':revision,'primitive':primitive,'instance':instance,'positionError':error,'tolerance':tolerance,'newSnapshot':new,'triangleChanged':changed})
                    if new:report['actualNewGeometryHitCoverage']=True
                    if new and changed:report['actualDisplacedTriangleHitCoverage']=True
        selection=load(folder/'selection.json');report['samples']=[];reset=[];recovery=[]
        for logical in sorted(detail-{159}):
            row=rows[logical]
            if row['gpuDetailStatus']!='recorded':continue
            blob=(folder/f'deformation-{logical:04d}-samples.bin').read_bytes();assert len(blob)==816 and not any(blob[544:])
            ss=sources(row)
            for lane,point in enumerate(selection['points']):
                s=parse_sample(blob,lane*272);s.update(logical=logical,role=point['role']);ids=s['identity'];candidate=s['candidate']
                known=ids[3]==1 and ids[2]>0 and any(ids[:2]);inrange=0<candidate[0]<=row['objectCount']
                status=1|(2 if known else 0)|(4 if inrange else 0)|(8 if candidate[1]==0 else 0)|(16 if ids[2]>0 and candidate[2]==ids[2] else 0)|(32 if inrange else 0)|(64 if inrange and s['objectKey']==ids[:2] else 0)
                assert candidate[3]==status and s['pixel']==[point['x'],point['y'],logical,row['gi']],'GPU mapper/receipt'
                source=ss.get(point['role']);belongs=source is not None and known and ids[:2]==key(source)
                s['coverage']='target-current' if belongs and lane==0 else 'control-current' if belongs else 'unknown' if not known else 'left-selected-source'
                if belongs and status==127:
                    assert candidate[0]==source['row']+1 and s['objectFlags']==[source['reusable'],source['rendererGroup']]
                    if lane==0:
                        new_geometry=source['geometryGeneration']!=baseline['target']['geometryGeneration']
                        radiance_known=s['raw'][3]>0 and all(math.isfinite(v) for v in s['raw'])
                        geom=s['geometry'];has_ng=1<=geom[2]<=16777216 and math.floor(geom[2])==geom[2]
                        receiver_valid=all(math.isfinite(v) for v in geom) and abs(geom[0])<=1 and abs(geom[1])<=1 and 1e-6<geom[3]<=1 and (geom[2]==-1 or has_ng)
                        s.update(radianceKnown=radiance_known,receiverValid=receiver_valid,hasNg=has_ng)
                        rejected=(s['objectFlags'][0]&1)==0
                        previous=s['previousIdentity']
                        if new_geometry and previous[3]==1 and previous[:2]==key(baseline['target']) and (not rejected or ids[:2]==previous[:2]):
                            report['violations'].append({'logical':logical,'kind':'Known new visible geometry reused old-source identity'})
                        if new_geometry and rejected:
                            if receiver_valid and radiance_known:
                                if s['moments'][2]!=1 or s['history'][3]<=0:report['violations'].append({'logical':logical,'kind':'Known new geometry history did not restart'})
                                else:reset.append(logical)
                            elif (not receiver_valid or not radiance_known) and (s['moments'][2]>0 or s['history'][3]>0):
                                report['violations'].append({'logical':logical,'kind':'Invalid receiver or unknown raw promoted to valid history'})
                        if new_geometry and receiver_valid and has_ng and radiance_known and s['history'][3]>0 and s['moments'][2]>1:recovery.append(logical)
                report['samples'].append(s)
        report['historyResetFrames']=reset;report['historyRecoveryFrames']=recovery
        report['targetHistoryResponseVerified']=bool(reset and any(r>min(reset) for r in recovery))
        if not report['actualNewGeometryHitCoverage']:report['coverageGaps'].append('No selected original ray hit proves new geometry')
        if not report['targetHistoryResponseVerified']:report['coverageGaps'].append('Fixed target pixel did not cover both reset and recovery')
        report['candidateProductCounterexample']=bool(report['violations']);report['status']='event-collected-layered-evidence'
        return report
    except Exception as ex:
        report.update(status='analysis-failed',failure=str(ex),traceback=traceback.format_exc());return report
    finally:save(native/'analysis.json',report)

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('action',choices=['build','products','run']);args=parser.parse_args()
    if args.action=='build':ok=base.build()
    elif args.action=='products':print(base.smoke.verify_products());ok=True
    else:
        report=run();print(json.dumps({k:v for k,v in report.items() if k not in ['samples','sourceTimeline','lifecycle','collection']}));ok=report['status']!='analysis-failed'
    raise SystemExit(0 if ok else 1)
