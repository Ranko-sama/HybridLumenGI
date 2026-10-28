"""One current scene triage: definite static-background history rejection only.
No physical truth, noise quality threshold, or recovery-time acceptance.
"""
import hashlib,json,traceback
from pathlib import Path
import numpy as np
from native_log_check import scan
ROOT=Path(__file__).resolve().parents[2];PACKAGE=ROOT/'LocalComparison/Review/moving-occluder-stage-review-01';NATIVE=PACKAGE/'native-window'
load=lambda p:json.loads(p.read_text(encoding='utf-8-sig'))
lines=lambda p:[json.loads(s) for s in p.read_text(encoding='utf-8-sig').splitlines() if s.strip()]
matrix=lambda v:np.array([[v[f'e{r}{c}'] for c in range(4)] for r in range(4)],dtype=np.float32)
def nearest(uv,w,h,fw,fh):
    result=[];margins=[]
    for axis,low,full in [(0,w,fw),(1,h,fh)]:
        base=np.clip(np.floor(uv[...,axis]*low).astype(int),0,low-1)
        choices=np.stack([np.maximum(base-1,0),base,np.minimum(base+1,low-1)],axis=-1)
        distances=np.abs(((choices*2+1)*full//(low*2)+.5)-uv[...,axis,None]*full)
        best=np.argmin(distances,axis=-1);selected=np.take_along_axis(choices,best[...,None],axis=-1)[...,0]
        # Ignore duplicate edge choices when bounding nearest-center ambiguity.
        other=np.where(choices!=selected[...,None],distances,np.inf)
        margins.append(np.min(other,axis=-1)-np.min(distances,axis=-1));result.append(selected)
    return result[0],result[1],np.minimum(*margins)
def run():
    report={'status':'unresolved','fullProductionAccepted':False,'productCounterexample':False,'frames':[],
        'scope':'One actual current DXR door fragment; static-background first exposure contract, not physical lag/overall image quality'}
    try:
        paths=list((NATIVE/'run').glob('*/run.json'));assert len(paths)==1;folder=paths[0].parent
        report['runId']=folder.name;meta=load(paths[0]);exit=load(NATIVE/'native-exit.json');frames=lines(folder/'frames.jsonl')
        report['collection']=meta;report['exit']=exit;report['nativeLogHits']=scan(NATIVE/'player.log')
        assert meta['errors']==0 and meta['renderedFrames']==meta['requestedFrames']==198 and meta['api']=='Direct3D12'
        assert exit['exitCode']==0 and not exit['watchdogTerminated'] and not report['nativeLogHits']
        assert [f['logicalFrame'] for f in frames]==list(range(198))
        assert all(frames[f]['captured'] and (folder/f'frame-{f:04d}.png').exists() and (folder/f'frame-{f:04d}.rgba32f').stat().st_size==640*360*16 for f in [119,*range(176,198)])
        assert load(folder/'door-stage-result.json')['passed'] and load(folder/'denoise-raw-summary.json')['passed']
        cameraFields=['cameraPosition','cameraRotation','projection','lights']
        assert all(all(f[k]==frames[119][k] for k in cameraFields) for f in frames[119:])
        assert all(f['doorLocalPosition']==frames[179]['doorLocalPosition'] for f in frames[179:])
        report['finiteProcessVerified']=True
        sources={f:load(folder/f'door-sources-{f:04d}.json') for f in range(175,197)}
        rawReceipts={r['logicalFrame']:r for r in lines(folder/'denoise-raw-receipts.jsonl')}
        sourceSet=lambda f:{(s['keyLow'],s['keyHigh']):s for s in sources[f]['sources']}
        knownTotal=unknownTotal=0;firstViolation=None;selectedUnion=None;hashes={}
        for f in range(176,197):
            d=load(folder/f'door-frame-{f:04d}.json');w,h,fw,fh=[d[k] for k in ['width','height','fullWidth','fullHeight']]
            assert (w,h,fw,fh)==(320,180,640,360)
            assert d['hardware'] and d['identityRecorded'] and json.loads(frames[f]['diagnosticsJson'])['hardwareBackend']
            assert d['engine']==frames[f]['engineFrame']==sources[f]['engine']==rawReceipts[f]['engineFrame']
            assert d['gi']==sources[f]['gi']==rawReceipts[f]['giFrame'] and d['gi']+1==json.loads(frames[f]['diagnosticsJson'])['frame']
            def read(stage,dtype='<f4',shape=None):
                p=folder/f'door-{f:04d}-{stage}.bin';r=load(Path(str(p)+'.json'));b=p.read_bytes()
                assert r['logical']==f and r['gi']==d['gi'] and r['engine']==d['engine'] and r['read']==d['read']
                digest=hashlib.sha256(b).hexdigest();assert len(b)==r['bytes'] and digest==r['sha256'];hashes[p.name]=digest
                return np.frombuffer(b,dtype=dtype).reshape(shape or (r['height'],r['width'],4))
            now=read('identity-current','<u4');old=read('identity-previous','<u4');geo=read('geometry');mat=read('material')
            history=read('history');moments=read('moments');filtered=read('filtered')
            objects=read('objects','<u4',(d['objects'],20));objectsF=objects.view('<f4')
            for i,s in enumerate(sources[f]['sources']):
                assert objects[i,16:19].tolist()==[s['keyLow'],s['keyHigh'],s['flags']]
                assert np.array_equal(objectsF[i,:16].reshape(4,4,order='F'),matrix(s['currentToPrevious']))
            rawPath=folder/f'denoise-{f:04d}-raw.rgba32f';rawBytes=rawPath.read_bytes();hashes[rawPath.name]=hashlib.sha256(rawBytes).hexdigest()
            raw=np.frombuffer(rawBytes,dtype='<f4').reshape(h,w,4)
            finalPath=folder/f'frame-{f:04d}.rgba32f';finalBytes=finalPath.read_bytes();hashes[finalPath.name]=hashlib.sha256(finalBytes).hexdigest()
            assert np.isfinite(np.frombuffer(finalBytes,dtype='<f4')).all()
            assert all(np.isfinite(a).all() for a in [raw,geo,mat,history,moments,filtered])
            yy,xx=np.indices((h,w));fx=((2*xx+1)*fw//(2*w));fy=((2*yy+1)*fh//(2*h))
            uv=np.stack([(fx+.5)/fw,(fy+.5)/fh],axis=-1).astype(np.float32)
            ndc=np.stack([uv[...,0]*2-1,1-uv[...,1]*2,geo[...,3],np.ones((h,w))],axis=-1).astype(np.float32)
            pos=ndc@matrix(d['invVP']).T;pos=pos/pos[...,3,None]
            oldSources=sourceSet(f-1);static=np.zeros((h,w),bool);expectedPos=pos.copy()
            for i,s in enumerate(sources[f]['sources']):
                key=(s['keyLow'],s['keyHigh']);prior=oldSources.get(key)
                if s['door'] or not prior or not(s['flags']&1) or s['localToWorld']!=prior['localToWorld']:continue
                selected=(now[...,0]==key[0])&(now[...,1]==key[1])&(now[...,2]>0)&(now[...,3]==1)
                static|=selected
                # Use the actual uploaded rigid mapping, including its float
                # roundoff even when the source pose itself stayed constant.
                expectedPos[selected]=pos[selected]@objectsF[i,:16].reshape(4,4,order='F').T
            projected=expectedPos@matrix(d['previousVP']).T
            previousUV=projected[...,:2]/np.maximum(projected[...,3,None],np.float32(1e-7))*.5+.5;previousUV[...,1]=1-previousUV[...,1]
            branchSafe=np.ones((h,w),bool)
            if d['hasMotion']:
                motion=read('motion')[fy,fx,:2];jitter=np.array([d['jitterDelta']['x'],d['jitterDelta']['y']],np.float32)
                motionUV=uv-motion+jitter;distance=np.abs(motionUV-previousUV)*[fw,fh]
                # A 0.001-full-pixel computational guard only excludes ambiguous
                # float projection/branch boundaries; never relaxes product gates.
                accept=np.all(distance<.999,axis=-1);reject=np.any(distance>1.001,axis=-1);branchSafe=accept|reject
                previousUV=np.where(accept[...,None],motionUV,previousUV)
            px,py,margin=nearest(previousUV,w,h,fw,fh)
            mappingSafe=branchSafe&(margin>.001)&np.all(np.isfinite(previousUV),axis=-1)&np.all((previousUV>0)&(previousUV<1),axis=-1)&(projected[...,3]>0)
            previous=old[py,px];oldDoor=np.zeros((h,w),bool)
            for key,s in oldSources.items():
                if s['door']:oldDoor|=(previous[...,0]==key[0])&(previous[...,1]==key[1])&(previous[...,3]==1)
            validGeo=(geo[...,3]>1e-6)&(geo[...,3]<=1)&np.all(np.abs(geo[...,:2])<=1,axis=-1)&(geo[...,2]>=1)&(geo[...,2]<=16777216)&(geo[...,2]==np.floor(geo[...,2]))
            different=np.any(now[...,:3]!=previous[...,:3],axis=-1)|(previous[...,3]!=1)
            exposure=static&oldDoor&different&validGeo&mappingSafe
            known=exposure&(raw[...,3]>0);unknown=exposure&~(raw[...,3]>0)
            violation=known&((moments[...,2]!=1)|np.any(history!=raw,axis=-1))
            knownTotal+=int(known.sum());unknownTotal+=int(unknown.sum())
            if selectedUnion is None:selectedUnion=exposure.copy()
            else:selectedUnion|=exposure
            row=dict(frame=f,knownExposure=int(known.sum()),unknownExposure=int(unknown.sum()),violations=int(violation.sum()),selectedOnlyByIdentityPoseGeometryAndMapping=True)
            if violation.any() and firstViolation is None:
                y,x=np.argwhere(violation)[0];firstViolation=dict(frame=f,x=int(x),y=int(y),previousPixel=[int(px[y,x]),int(py[y,x])],previousUV=previousUV[y,x].tolist(),identity=now[y,x].tolist(),oldIdentity=previous[y,x].tolist(),raw=raw[y,x].tolist(),history=history[y,x].tolist(),moments=moments[y,x].tolist())
            report['frames'].append(row)
        report.update(knownExposureSamples=knownTotal,unknownExposureSamples=unknownTotal,firstViolation=firstViolation,productCounterexample=firstViolation is not None,
            status='counterexample-needs-attribution' if firstViolation else 'finite-coverage-no-counterexample' if knownTotal else 'coverage-insufficient',payloadHashes=hashes,
            physicalLagQualified=False,laterStageDifferencesAreNotAReference=True)
        np.save(PACKAGE/'exposure-union-mask.npy',selectedUnion)
    except Exception as e:report.update(status='stopped-first-failure',failure=str(e),traceback=traceback.format_exc())
    destination=PACKAGE/'scene-analysis.json';assert not destination.exists(),'Preserve first analysis'
    destination.write_text(json.dumps(report,indent=2));print(json.dumps({k:v for k,v in report.items() if k not in ['payloadHashes','collection','frames']},indent=2))
    return report['status'] not in ['stopped-first-failure','counterexample-needs-attribution']
if __name__=='__main__':raise SystemExit(0 if run() else 1)
