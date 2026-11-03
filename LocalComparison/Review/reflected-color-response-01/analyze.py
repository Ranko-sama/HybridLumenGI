"""One existing reflected-color event. Fixed source ROIs, no integration/hash/GPU."""
import argparse, json
from pathlib import Path
import numpy as np
from PIL import Image,ImageDraw

Y=np.array([.2126,.7152,.0722]); W,H=320,180
REFERENCE=Path('I:/Unity test/Comparison/ValidationPackageV209-reference-frame0119-01')
OLD=Path('I:/Unity test/Comparison/ValidationPackageV209/capture/20261029-153518-90ad50e68d454b52b48135246a18dfa5')
NAMES=['Floor','White receiver']
def load(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def need(ok,why):
    if not ok:raise ValueError(why)
def rgb(c):return np.array([c[k] for k in 'rgba'],dtype=np.float32)
def read(base,n):
    r=load(base/'signals'/f'frame-{n:04d}-capture.json')
    need(r['status']=='complete' and r['readbacksCompleted'] and not r['error'] and r['logicalFrame']==r['workFrame']==n and len(r['samples'])==1 and not r['support'],'Incomplete D-only source')
    s=r['samples'][0]
    need(s['signalId']=='filteredD' and s['quantity']=='indirect-irradiance-over-pi' and s['status']=='available' and s['width']==W and s['height']==H and s['rowOrder']=='top-to-bottom' and s['sourceFormat']=='R16G16B16A16_SFloat','Different D descriptor')
    a=np.fromfile(base/'signals'/s['data']['file'],'<f4').reshape(H,W,4)
    valid=np.fromfile(base/'signals'/s['validity']['file'],'u1').reshape(H,W)>0
    need(np.all(np.isfinite(a[valid])),'Nonfinite known source')
    return r,a[:,:,:3].astype(float),valid
def window(rows,times,key):
    for i in range(len(rows)):
        if not rows[i][key]:continue
        for j in range(i,len(rows)):
            if not rows[j][key]:break
            if times[j]-times[i]>=.5:
                return {'firstLogical':rows[i]['logicalFrame'],'lastLogical':rows[j]['logicalFrame'],'startSeconds':float(times[i]),'endSeconds':float(times[j]),'durationSeconds':float(times[j]-times[i]),'enteredByTwoSeconds':bool(times[i]<=2),'laterObservedBreach':any(not r[key] for r in rows[j+1:])}
    return None
def preview(a):
    a=np.maximum(a,0);a=a/(1+a);a=np.where(a<=.0031308,a*12.92,1.055*a**(1/2.4)-.055)
    return np.uint8(np.clip(a,0,1)*255)
def figure(out,selected,all_roi):
    yy,xx=np.indices((H,W));checker=np.repeat((80+((xx//6+yy//6)%2)*35)[:,:,None],3,2).astype(np.uint8)
    canvas=Image.new('RGB',(W*3,(H+40)*len(selected)),(28,28,31));d=ImageDraw.Draw(canvas)
    for k,(frame,t,a,b,va,vb) in enumerate(selected):
        delta=(a-b)@Y;level=np.clip(abs(delta)/.05,0,1);heat=np.zeros((H,W,3),np.uint8);heat[:,:,0]=np.where(delta>=0,255*level,0);heat[:,:,2]=np.where(delta<0,255*level,0)
        tiles=[preview(a),preview(b),heat]
        for i,p in enumerate(tiles):
            p[~all_roi]=checker[~all_roi];p[all_roi&~(va if i==0 else vb if i==1 else va&vb)]=[255,0,255]
            canvas.paste(Image.fromarray(p).transpose(Image.Transpose.FLIP_TOP_BOTTOM),(i*W,k*(H+40)+24))
        d.text((4,k*(H+40)+5),f'work {frame}, event source {t:.6f}s: red->blue D | blue-from-start D | delta Y (+red/-blue, .05)',fill=(240,240,240))
    canvas.save(out/'comparison.png')
def analyze(parent,out):
    dirs=[parent/'RedToBlue',parent/'BlueFromStart'];hosts=[];series=[];settings=[]
    for i,base in enumerate(dirs):
        e=load(base/'result.json');h=load(base/'host-result.json');s=load(base/'series.json');cfg=json.loads(h['actualSettingsJson'])
        need(e['status']=='collected' and e['restored'] and e['importIdentityMatched'] and h['status']==s['status']=='collected' and not h['error'] and h['referenceDrained'] and h['legacyReadbacksDrained'] and h['allCapturesSucceeded'] and h['wallRestored'],'Incomplete restored observation')
        need(h['legacy']['status']=='failed' and h['legacy']['failures']==h['legacy']['backendMismatches']==0,'Unexpected original sequence failure')
        # Ordinary MPB SetColor/GetColor can round-trip a few float ULPs. Check
        # the requested color within float precision, then require the actual
        # observed blue to stay exact across every source and both histories.
        need(np.allclose(rgb(h['finalColor']),np.array([.05,.15,.8,1],np.float32),rtol=0,atol=1e-7),'Different requested blue input')
        need(cfg['raysPerPixel']==2 and cfg['filterIterations']==4 and cfg['preferHardwareTracing'] and cfg['debugView']==1 and cfg['resolutionScale']==.5 and cfg['cacheRaysPerFace']==8 and cfg['bounceFeedback']==1,'Different configured profile')
        need(h['finalLogical']==s['finalLogical'] and 120<=h['finalLogical']<=239 and len(s['frames'])==h['finalLogical']+1 and h['ticketCount']==h['finalLogical']-118,'Different bounded prefix')
        need(h['eventSeconds']==s['eventSeconds'] and h['eventEngineFrame']==s['frames'][119]['engineFrame'] and s['frames'][119]['renderReturnedSeconds']<=h['eventSeconds']<s['frames'][120]['sourceSeconds'],'Event/source boundary differs')
        for n,f in enumerate(s['frames']):
            need(f['logicalFrame']==f['workFrame']==n and f['returned'] and f['diagnostics']['hardwareBackend'] and f['diagnostics']['transportRecordedEngineFrame']==f['engineFrame'],'Source/work/backend association differs')
            need(n==0 or f['engineFrame']==s['frames'][n-1]['engineFrame']+1,'Source engine gap')
            expected=rgb(h['originalColor']) if i==0 and n<=119 else rgb(h['finalColor'])
            need(np.array_equal(rgb(f['wallColor']),expected),'Actual wall input differs')
            if n>=120:need(abs(f['sourceSeconds']-h['eventSeconds']-f['eventElapsed'])<1e-7,'Source time differs')
        hosts.append(h);series.append(s);settings.append(cfg)
    need(settings[0]==settings[1] and hosts[0]['finalLogical']==hosts[1]['finalLogical'] and np.array_equal(rgb(hosts[0]['originalColor']),rgb(hosts[1]['originalColor'])) and np.array_equal(rgb(hosts[0]['finalColor']),rgb(hosts[1]['finalColor'])),'Different paired input profile')
    end=hosts[0]['finalLogical'];times=np.array([f['eventElapsed'] for f in series[0]['frames'][120:]])
    need(times[-1]>=2.6 and np.all(np.diff(times)>0),'Missing terminal source')
    names=[x['name'] for x in load(REFERENCE/'geometry-index.json')['objects']]
    with np.load(REFERENCE/'primary.npz',allow_pickle=False) as p:
        owner=p['owner'];yy,xx=np.indices((H,W));need(np.array_equal(p['sampledFullPixel'],np.stack([2*xx+1,2*yy+1],-1)),'Original fixed source grid differs')
    geom=np.fromfile(REFERENCE/'validity.u8','u1').reshape(H,W)>0
    rois={name:geom&(owner==names.index(name)) for name in NAMES}
    old=load(OLD/'frame-0119-capture.json')['composite'];bases=[read(b,119) for b in dirs]
    fixed={name:mask&bases[0][2]&bases[1][2] for name,mask in rois.items()}
    need(all(m.any() for m in fixed.values()),'Empty pre-event known domain')
    roi_stats={name:{'sourcePixels':int(rois[name].sum()),'fixedKnownBeforeEvent':int(m.sum()),'unknownBeforeEvent':int(np.sum(rois[name]&~m))} for name,m in fixed.items()}
    data=[];rows=[];controls={name:[] for name in NAMES}
    for n in range(120,end+1):
        pairs=[read(b,n) for b in dirs];r,a,va=pairs[0];q,b,vb=pairs[1]
        for receipt in [r,q,bases[0][0],bases[1][0]]:
            need(receipt['composite']['invVP']==old['invVP'] and receipt['composite']['giSize']=={'x':W,'y':H} and receipt['composite']['intensity']==1 and receipt['composite']['debug']==1,'Original projection/grid/quantity profile differs')
        need(r['engineFrame']==series[0]['frames'][n]['engineFrame'] and q['engineFrame']==series[1]['frames'][n]['engineFrame'],'Capture/source clock differs')
        need(series[0]['frames'][n]['cameraPosition']==series[1]['frames'][n]['cameraPosition']==series[0]['frames'][0]['cameraPosition'] and series[0]['frames'][n]['cameraRotation']==series[1]['frames'][n]['cameraRotation']==series[0]['frames'][0]['cameraRotation'],'Fixed camera differs')
        row={'logicalFrame':n,'sourceSeconds':float(times[n-120]),'regions':{},'bothQualified':True}
        for name,m in fixed.items():
            invalid_a=int(np.sum(m&~va));invalid_b=int(np.sum(m&~vb));valid=not invalid_a and not invalid_b
            region={'eventUnknownInFixedDomain':invalid_a,'controlUnknownInFixedDomain':invalid_b,'known':valid,'qualified':False}
            if valid:
                ar,br=a[m].mean(0),b[m].mean(0);ay,by=ar@Y,br@Y
                if by>0 and ar.sum()>0 and br.sum()>0:
                    bias=(ay-by)/by;chroma=float(abs(ar/ar.sum()-br/br.sum()).sum())
                    region.update(eventMeanRGB=ar.tolist(),controlMeanRGB=br.tolist(),eventMeanY=float(ay),controlMeanY=float(by),relativeMeanY=float(bias),meanChromaL1=chroma,pixelYMAE=float(abs((a[m]-b[m])@Y).mean()),pixelYMaxAbs=float(abs((a[m]-b[m])@Y).max()),qualified=bool(abs(bias)<=.1 and chroma<=.05))
                    controls[name].append(br)
            row['regions'][name]=region;row['bothQualified']&=region['qualified'];row[name]=region['qualified']
        data.append((a,b,va,vb));rows.append(row)
    cadence=[]
    for s in series:
        gaps=np.array([f['previousSourceGap'] for f in s['frames'][120:]])
        cadence.append({'sourceMeanHz':float((len(gaps)-1)/(s['frames'][-1]['sourceSeconds']-s['frames'][120]['sourceSeconds'])),'medianGap':float(np.median(gaps)),'p95Gap':float(np.quantile(gaps,.95)),'maxGap':float(gaps.max()),'qualified':bool(np.all((gaps>0)&(gaps<=2/30)))})
    stable={}
    for name in NAMES:
        c=np.array(controls[name]);ok=len(c)==len(rows)
        if ok:
            ys=c@Y;ch=c/c.sum(1,keepdims=True);spread=float(np.ptp(ys)/ys.mean());drift=float(abs(ch-ch[0]).sum(1).max());ok=spread<=.05 and drift<=.025
            stable[name]={'meanYRangeOverMean':spread,'maxMeanColorDriftL1':drift,'qualified':bool(ok)}
        else:stable[name]={'qualified':False,'reason':'Unknown or nonpositive control on the fixed pre-event domain'}
    joint=window(rows,times,'bothQualified');windows={name:window(rows,times,name) for name in NAMES}
    control_ok=all(s['qualified'] for s in stable.values());cadence_ok=all(c['qualified'] for c in cadence)
    for name,w in windows.items():
        if w is not None:w.update(controlQualified=stable[name]['qualified'],sourceCadenceQualified=cadence_ok,adoptable=bool(stable[name]['qualified'] and cadence_ok and w['enteredByTwoSeconds']))
    if joint is not None:joint.update(controlQualified=control_ok,sourceCadenceQualified=cadence_ok,adoptable=bool(control_ok and cadence_ok and joint['enteredByTwoSeconds']))
    decisions={name:('insufficient-control-stability' if not stable[name]['qualified'] else 'insufficient-source-cadence' if not cadence_ok else 'finite-response-target-observed' if windows[name] and windows[name]['enteredByTwoSeconds'] else 'finite-response-target-not-observed') for name in NAMES}
    status='insufficient-control-stability' if not control_ok else 'insufficient-source-cadence' if not cadence_ok else 'finite-response-target-observed' if joint and joint['enteredByTwoSeconds'] else 'finite-response-target-not-observed'
    selected_indices=[int(np.argmin(abs(times-2))),len(rows)-1]
    selected=[(rows[i]['logicalFrame'],times[i],*data[i]) for i in selected_indices]
    figure(out,selected,rois[NAMES[0]]|rois[NAMES[1]])
    result={'status':status,'quantity':'filteredD=E_indirect/pi','scope':'Original reflected-color event/current122 Runtime, two original source ROIs, fixed door and five lights; same-work-frame product control, not physical truth/fullG3/Player/performance','roi':roi_stats,'cadence':cadence,'controlStability':stable,'regionDecision':decisions,'jointWindow':joint,'perRegionWindow':windows,'windowMeaning':'Frame qualified/paired windows express relative difference criteria only; recovery adoption also requires the separately frozen control and cadence qualification. White is not adopted when its control is unstable.','selectedTimes':[rows[i] for i in selected_indices],'allLaterObservedDifferencesWithinTargets':bool(joint and not joint['laterObservedBreach']),'frames':rows,'limits':['Filtered validity is not fresh raw qualification','Unknown fixed-domain pixels make the frame unqualified; they are not dropped','No old-red photon fraction or MC reference was inferred','Original720 protocol remains incomplete; observer source was restored']}
    return result
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('capture',type=Path);p.add_argument('output',type=Path);a=p.parse_args();a.output.mkdir(exist_ok=False,parents=True)
    try:r=analyze(a.capture,a.output)
    except (OSError,ValueError,KeyError,IndexError,TypeError) as e:r={'status':'insufficient-input-or-record','error':str(e)}
    (a.output/'result.json').write_text(json.dumps(r,indent=2)+'\n',encoding='utf-8');print(json.dumps({k:v for k,v in r.items() if k!='frames'}))
