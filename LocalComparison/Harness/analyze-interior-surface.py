"""Frozen single-run layer/identity/consumption oracle, not an energy reference."""
import hashlib,json,math,struct,traceback
from pathlib import Path
import numpy as np
ROOT=Path(__file__).resolve().parents[2];P=ROOT/'LocalComparison/Review/interior-surface-cache-chain-01';N=P/'native-window'
load=lambda p:json.loads(p.read_text(encoding='utf-8-sig'))
vec=lambda v:np.array([v[k] for k in 'xyzw' if k in v],dtype=float)
def need(v,msg):
    if not v:raise AssertionError(msg)
def close(a,b,tol=1e-4):return np.all(np.abs(np.asarray(a)-b)<=tol)
def nearest(v,ix,origin,direction,limit):
    hits=[]
    for primitive,tri in enumerate(ix.reshape(-1,3)):
        a,b,c=v[tri];e1=b-a;e2=c-a;p=np.cross(direction,e2);det=np.dot(e1,p)
        if det<=1e-9:continue
        q0=origin-a;u=np.dot(q0,p)/det;q=np.cross(q0,e1);w=np.dot(direction,q)/det;t=np.dot(e2,q)/det
        if u>=0 and w>=0 and u+w<=1 and 0<t<=limit:hits.append((t,primitive,u,w))
    need(bool(hits),'Independent source ray misses');return min(hits)
def atlas_valid(position,normal,emission):
    return np.isfinite(np.concatenate([position,normal,emission])).all() and 0<=position[3]<=1 and np.dot(normal[:3],normal[:3])>=.25 and 1<=emission[3]<=1024 and emission[3]==round(emission[3])
def layer(position,z):return abs(position[2]-z)<=1e-4 and 99-1e-4<=position[0]<=101+1e-4 and -1-1e-4<=position[1]<=1+1e-4
def analyze():
    report={'fullProductionAccepted':False,'productCounterexample':False,'finiteChainVerified':False,'randomGatherCoverage':False,'samples':[]}
    stage='collection'
    try:
        candidates=list((N/'run').glob('*/run.json'));need(len(candidates)==1,'One run required');folder=candidates[0].parent
        meta=load(candidates[0]);end=load(N/'native-exit.json');result=load(folder/'interior-result.json')
        report.update(runId=folder.name,collection=meta,result=result,nativeExit=end)
        need(end['exitCode']==0 and not end['watchdogTerminated'] and meta['errors']==0,'Native collection failed')
        need(meta['renderedFrames']==meta['requestedFrames']==120 and meta['captures']==0,'Bounded no-image collection')
        need(result['receipts']==120 and result['pending']==0 and not result.get('failure'),'Readback completion')
        source=load(folder/'interior-source.json');snapshot=load(folder/'interior-snapshot.json');report['snapshot']=snapshot
        vertices=np.array([vec(x) for x in source['vertices']]);indices=np.array(source['indices']);translation=vec(source['translation'])
        # Exact previously existing fixture, independently specified before run.
        quads=[((-2,-2,-2),(2,-2,-2),(2,2,-2),(-2,2,-2)),((-2,2,2),(2,2,2),(2,-2,2),(-2,-2,2)),
            ((-2,-2,2),(2,-2,2),(2,-2,-2),(-2,-2,-2)),((-2,2,-2),(2,2,-2),(2,2,2),(-2,2,2)),
            ((-2,-2,2),(-2,-2,-2),(-2,2,-2),(-2,2,2)),((2,-2,-2),(2,-2,2),(2,2,2),(2,2,-2)),
            ((-1,-1,-.4),(1,-1,-.4),(1,1,-.4),(-1,1,-.4)),((-1,-1,.4),(1,-1,.4),(1,1,.4),(-1,1,.4))]
        expected=np.array(quads).reshape(-1,3);expected_indices=np.array([n+j for n in range(0,32,4) for j in (0,1,2,0,2,3)])
        need(close(vertices,expected,1e-7) and np.array_equal(indices,expected_indices) and close(translation,[100,0,0],0),'Source fixture changed')
        need(source['targetPrimitives']==[12,13,14,15],'Targets changed')
        stage='CPU chart membership';owners={}
        for c in source['charts']:
            need(c['submesh']==0,'Unexpected source submesh')
            need(c['captureIndices']==[int(indices[t*3+k]) for t in c['triangles'] for k in range(3)],'Capture indices differ from declared source membership')
            for t in c['triangles']:need(t not in owners,'Duplicate source membership');owners[t]=c
        need(sorted(owners)==list(range(16)),'Missing source triangles');report['sourceMembershipVerified']=True
        need(all(snapshot[k] for k in ['hardware','published','captureReady','sourceCurrent','charted']),'UNCOVERED: owner/backend not ready at fixed119')
        need(snapshot['logical']==119 and snapshot['grid'] in [1,2,3,4],'Snapshot contract')
        need(result['completed']==1,'UNCOVERED: no unique query payload')
        blob=(folder/'interior-query.bin').read_bytes();need(len(blob)==4*80*16==result['bytes'],'Query ABI')
        need(hashlib.sha256(blob).hexdigest().upper()==result['sha256'],'Readback hash')
        f=np.frombuffer(blob,dtype='<f4').reshape(4,80,4);u=np.frombuffer(blob,dtype='<u4').reshape(4,80,4)
        dimensions=np.array([snapshot['atlasWidth'],snapshot['atlasHeight']]);grid=snapshot['grid'];cards=[]
        for lane,primitive in enumerate(range(12,16)):
            r=f[lane].astype(float);q=u[lane];sample={'primitive':primitive};report['samples'].append(sample)
            origin=vec(source['origins'][lane]).astype(np.float32).astype(float);tri=indices[primitive*3:primitive*3+3];point=(vertices[tri]+translation).mean(axis=0);z=point[2]
            need(close(origin[:3],point+[0,0,.5]) and origin[3]==.75 and close(r[0],origin,0) and close(r[1],[0,0,-1,0],0),'Fixed query changed')
            t,p,a,b=nearest(vertices+translation,indices,origin[:3],r[1,:3],.75);need(p==primitive and abs(t-.5)<=1e-4 and min(a,b,1-a-b)>.3,'Independent target ambiguity')
            stage='actual hit';need(q[2,0]==1,'UNCOVERED: actual ray misses')
            need(list(q[6])==[snapshot['slot'],snapshot['id'],snapshot['revision'],snapshot['geometryRevision']],'Actual hit owner/version differs')
            need(list(q[7,:3])==[0,primitive,1] and q[7,3]&16 and q[7,3]&64,'Actual hit not original triangle/binding')
            need(close(r[3,:3],origin[:3]+r[1,:3]*t) and abs(r[3,3]-t)<=1e-4 and r[4,2]>=.999,'Actual source intersection differs')
            stage='triangle-to-card binding';binding=snapshot['bindings'][lane]
            need(binding['valid'],'CPU binding missing');expected_binding=[binding[k] for k in ['cardIndex','chartId','layoutGeneration','geometryRevision']]
            need(list(q[8])==expected_binding and binding['chartId']==owners[primitive]['id'],'Hit binding differs from source chart')
            need(binding['geometryRevision']==snapshot['geometryRevision'],'Stale binding geometry')
            stage='actual surface capture';need(q[2,1]==1,'UNCOVERED: surface material lookup rejected')
            card,generation,slot,_=q[12];cards.append(int(card));sample.update(card=int(card),generation=int(generation),capturedPosition=r[14,:3].tolist())
            need(list(q[17])==[snapshot['id'],snapshot['revision'],generation,1] and generation>0,'Captured card identity/readiness')
            need(list(q[18,:3])==[snapshot['slot'],binding['chartId'],binding['layoutGeneration']] and q[18,3]&1,'Captured chart metadata')
            need(card==binding['cardIndex'] and slot==snapshot['slot'],'Material used different card/owner')
            minimum=np.rint(r[64,:2]*dimensions).astype(int);count=np.rint(r[64,2:]*dimensions).astype(int)
            pixel=q[13,:2].astype(int);need(np.all(pixel>=minimum)&np.all(pixel<minimum+count),'Surface pixel outside mapped card')
            need(atlas_valid(r[14],r[15],r[16]) and layer(r[14],z) and close(r[9,:3],r[14,:3],0) and r[10,2]>=.995 and r[11,2]>=.999,'Actual captured texel missing or on different layer')
            stage='actual cache consumption';need(q[2,2]==1,'UNCOVERED: no legal initialized cache support')
            accepted=[];weighted=np.zeros(4);total=0
            for tap in range(4):
                base=24+tap*9;weight,entry,tap_id,used=r[base+5]
                if not used:continue
                cell=q[base+6,2:].astype(int);anchor_pixel=q[base+6,:2].astype(np.int32)
                need(used==1 and tap_id==tap and weight>=0 and np.all(cell>=0) and np.all(cell<grid),'Actual accepted tap metadata')
                need(entry==card*grid*grid+cell[1]*grid+cell[0],'Cache entry belongs to different card/cell')
                need(close(r[base+1],[snapshot['id'],snapshot['revision'],snapshot['epoch'],generation],0),'Accepted stale identity/epoch/generation')
                begin=minimum+cell*count//grid;end_pixel=minimum+(cell+1)*count//grid
                need(np.all(anchor_pixel>=begin)&np.all(anchor_pixel<end_pixel),'Anchor outside its card cell')
                need(atlas_valid(r[base+7],r[base+8],r[72+tap]) and layer(r[base+7],z) and layer(r[base+2],z),'Anchor on different/invalid layer')
                need(close(r[base+2,:3],r[base+7,:3]) and r[base+3,2]>=.999,'Cache anchor differs from actual captured texel')
                need(np.isfinite(np.concatenate([r[base],r[base+4]])).all() and r[base,3]>0,'Accepted unknown cache measurement')
                weighted+=weight*r[base];total+=weight;accepted.append({'entry':int(entry),'weight':weight,'anchorPixel':anchor_pixel.tolist(),'anchor':r[base+2,:3].tolist(),'irradiance':r[base].tolist()})
            need(total>1e-5 and abs(total-r[22,0])<1e-5,'No actual accepted support')
            expected_irradiance=weighted/total;need(np.all(np.abs(expected_irradiance-r[20])<=1e-5*(1+np.abs(expected_irradiance))),'Returned cache is not the accepted weighted support')
            sample.update(acceptedTaps=accepted,returnedIrradiance=r[20].tolist(),finiteChainVerified=True)
        need(not(set(cards[:2])&set(cards[2:])),'Distinct internal layers share a physical card')
        report.update(status='finite-chain-verified',finiteChainVerified=True)
    except Exception as e:
        uncovered=str(e).startswith('UNCOVERED:');report.update(status='uncovered' if uncovered else 'stopped-first-error',stage=stage,failure=str(e),traceback=traceback.format_exc())
        # A failed assertion is evidence requiring attribution, not automatic product blame.
    finally:
        need(not (N/'analysis.json').exists(),'Preserve first analysis')
        (N/'analysis.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2))
    return report
if __name__=='__main__':
    result=analyze();raise SystemExit(0 if result['status'] in ['finite-chain-verified','uncovered'] else 1)
