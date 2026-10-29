"""Picture-level dynamic measurements from existing captures. No Unity; no independent RGB oracle is invented."""
import hashlib,json,sys
from pathlib import Path
import numpy as np
from PIL import Image,ImageDraw

P=Path(__file__).resolve().parent;ROOT=P.parents[2]
CAP=Path(r'I:/Unity test/Comparison/ValidationPackageV209/capture/20261029-153518-90ad50e68d454b52b48135246a18dfa5')
Y=np.array([.2126,.7152,.0722]);load=lambda p:json.loads(p.read_text(encoding='utf-8-sig'))
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
sys.path.insert(0,str(ROOT/'LocalComparison/Reference/ValidationSource'))
from geometry import Scene,Camera,render_primary,RECEIVER

def image(frame,signal):
    width,height=(320,180) if signal in ['filteredD','geometry','moments'] else (640,360)
    return np.fromfile(CAP/f'frame-{frame:04}-{signal}.rgba32f',dtype='<f4').reshape(height,width,4)
def known(frame):return np.fromfile(CAP/f'frame-{frame:04}-filteredD.validity.u8',dtype='u1').reshape(180,320)>0
def display(rgb):
    value=np.maximum(rgb,0);value=value/(1+value)
    value=np.where(value<=.0031308,value*12.92,1.055*np.power(value,1/2.4)-.055)
    return Image.fromarray(np.uint8(np.clip(value,0,1)*255))
def stat(rgb,mask):
    if not mask.any():return dict(count=0,meanRGB=None,meanY=None,p95Y=None,maxY=None)
    value=rgb[mask];lum=value@Y
    return dict(count=int(mask.sum()),meanRGB=value.mean(0).tolist(),meanY=float(lum.mean()),p95Y=float(np.percentile(lum,95)),maxY=float(lum.max()))
def first_stays_below(values,limit):
    return next((i for i in range(len(values)) if max(values[i:])<=limit),None)
def chart(title,curves,xlabel,ylabel,size=(700,360),log=False,markers=()):
    im=Image.new('RGB',size,'white');draw=ImageDraw.Draw(im);w,h=size;l,t,r,b=65,55,w-20,h-60
    vals=[(x,float(y)) for _,xs,ys in curves for x,y in zip(xs,ys) if y is not None and (not log or y>0)]
    xmin,xmax=min(x for x,y in vals),max(x for x,y in vals)
    ymin,ymax=min(y for x,y in vals),max(y for x,y in vals)
    if log:ymin,ymax=np.log10([ymin,ymax])
    else:ymin=min(0,ymin)
    ymax=max(ymin+1e-8,ymax)
    def point(x,y):return (l+(x-xmin)/(xmax-xmin)*(r-l),b-((np.log10(y) if log else y)-ymin)/(ymax-ymin)*(b-t))
    draw.text((10,8),title,fill='black');draw.text((l,h-20),xlabel,fill='black');draw.text((5,30),ylabel,fill='black')
    for i in range(6):
        x=xmin+(xmax-xmin)*i/5;y=ymin+(ymax-ymin)*i/5;px=l+(r-l)*i/5;py=b-(b-t)*i/5
        draw.line((l,py,r,py),fill='#dddddd');draw.text((2,py-5),f'{10**y if log else y:.3g}',fill='black');draw.text((px-8,b+8),f'{x:.0f}',fill='black')
    draw.line((l,t,l,b,r,b),fill='black',width=2)
    colors=['#c42828','#2459bb','#198335','#ad650d','#973fa6']
    for k,(label,xs,ys) in enumerate(curves):
        points=[point(x,y) for x,y in zip(xs,ys) if y is not None and (not log or y>0)]
        if len(points)>1:draw.line(points,fill=colors[k%len(colors)],width=2)
        for px,py in points:draw.ellipse((px-2,py-2,px+2,py+2),fill=colors[k%len(colors)])
        draw.text((l+8+(k%3)*185,t+8+(k//3)*14),label,fill=colors[k%len(colors)])
    for x,label in markers:
        px=point(x,10**ymin if log else ymin)[0];draw.line((px,t,px,b),fill='#aaaaaa');draw.text((px+2,t-14),label,fill='black')
    return im

def finite_wall():
    q=ROOT/'LocalComparison/Review/finite-wall-dynamic-response-01';selection=load(q/'native/selection.json')
    coords={(r['x'],r['y']):i for i,r in enumerate(selection['coordinates'])}
    ids=[coords[(r['x'],r['y'])] for r in selection['selection']]
    basis=np.array([[4,1],[2,2],[1,4]],dtype=float)/7;inverse=np.linalg.pinv(basis)
    rows=[];stored=[]
    for frame in range(96):
        data=np.fromfile(q/f'native/frame-{frame:03}.bin',dtype='<f4').reshape(-1,4)[3:].reshape(-1,10,4)[ids]
        raw,hist=data[:,0],data[:,1];valid=(hist[:,3]>0)&np.isfinite(hist).all(1);positive=valid&(hist[:,:3].sum(1)>0)
        coef=hist[positive,:3]@inverse.T;fraction=coef[:,0]/coef.sum(1)
        chroma=hist[positive,:3]/hist[positive,:3].sum(1,keepdims=True)
        rows.append(dict(frame=frame,currentKnown=int((raw[:,3]>0).sum()),currentBlack=int(((raw[:,3]>0)&(raw[:,:3].max(1)==0)).sum()),historyKnown=int(valid.sum()),
            historyMaxRGB=float(hist[valid,:3].max()),historyMeanY=float((hist[valid,:3]@Y).mean()),
            oldColorFractionMean=float(fraction.mean()),oldColorFractionMax=float(fraction.max()),
            newChromaL1Mean=float(abs(chroma-np.array([1,2,4])/7).sum(1).mean()),
            newChromaL1Max=float(abs(chroma-np.array([1,2,4])/7).sum(1).max()),
            normalizedColorDistanceMean=float(abs(chroma-np.array([1,2,4])/7).sum(1).mean()/(6/7)),
            normalizedColorDistanceMax=float(abs(chroma-np.array([1,2,4])/7).sum(1).max()/(6/7)),
            twoColorFitMaximumResidual=float(abs(hist[positive,:3]-coef@basis.T).max()),
            historyMinAge=float(data[:,2,2].min()),historyMaxAge=float(data[:,2,2].max())))
        stored.append(hist.copy())
    off=[r['historyMaxRGB'] for r in rows[64:]]
    color=[r['oldColorFractionMax'] for r in rows[32:64]]
    distance=[r['normalizedColorDistanceMax'] for r in rows[32:64]]
    result=dict(scope='Previously captured 27 fixed floor points; one bounce, eight rays, no feedback/environment/emission/filter. Color changes at32; only directional source turns off at64. Current and history are separate actual shader textures.',
        oldColorMetric='Least-squares old/new normalized RGB basis fraction; fit residual separately reported. A chroma-memory diagnostic, not an irradiance accuracy metric.',
        unknownIsNotBlack=True,frames=rows,
        colorOffsetsForAllPositiveHistoryBelow={str(v):first_stays_below(color,v) for v in [.5,.1,.05,.02,.01]},
        colorDistanceOffsetsForAllBelow={str(v):first_stays_below(distance,v) for v in [.5,.1,.05,.02,.01]},
        blackOffsetsForAllHistoryBelow={str(v):first_stays_below(off,v) for v in [.02,.01,.005,.002,.001,.0005]},
        evidence={str(p.relative_to(ROOT)):sha(p) for p in [q/'analysis-first.json',q/'qualification/input-result.json',q/'native/selection.json']})
    x=np.arange(32);fig=Image.new('RGB',(1400,360),'white')
    fig.paste(chart('Actual history: 4:2:1 to 1:2:4 source change',[('worst of 27',x,distance),('mean',x,[r['normalizedColorDistanceMean'] for r in rows[32:64]])],'Frames after color event','Chroma distance / full source color change'),(0,0))
    fig.paste(chart('Current is known black at all 27 points',[('max history channel',x,off),('0.001 scene-linear',x,[.001]*32)],'Frames after light-off','Residual radiance (log10 scale)',log=True),(700,0));fig.save(P/'finite-response-curves.png')
    chosen=[31,32,33,34,40,48,63,64,66,70,88,95];sheet=Image.new('RGB',(650,38*len(chosen)),(25,25,30));draw=ImageDraw.Draw(sheet)
    for n,frame in enumerate(chosen):
        draw.text((5,n*38+10),f'frame {frame}',fill='white')
        colors=np.asarray(display(stored[frame][:,:3][None]))[0]
        for i,color in enumerate(colors):draw.rectangle((96+i*20,n*38+4,114+i*20,n*38+33),fill=tuple(int(v) for v in color))
    sheet.save(P/'finite-history-swatches.png');return result

def taa_motion():
    q=ROOT/'LocalComparison/Review/camera-motion-taa-response-03';a=load(q/'analysis-first.json');events=[]
    for frame in a['frames']:
        data=None
        for sample in frame['samples']:
            if sample['classification']!='first-exposure':continue
            if data is None:data=np.fromfile(q/f"native/frame-{frame['logicalFrame']:03}.bin",dtype='<f4').reshape(-1,4)[12:].reshape(-1,45,4)
            v=data[sample['index']];difference=float(abs(v[6,:3]-v[5,:3]).max())
            events.append(dict(frame=frame['logicalFrame'],pixel=sample['pixel'],maxHistoryMinusCurrent=difference,historyAge=float(v[7,2]),currentKnown=bool(v[5,3]>0),historyKnown=bool(v[6,3]>0)))
    return dict(scope='Existing fixed planar, moving-camera/real TAA test; source-qualified first exposure points, no RGB-based sample selection. This tests stale-history rejection, not general whole-scene spatial-filter trails.',
        events=len(events),continuedControls=sum(f['qualifiedContinued'] for f in a['frames']),nonzeroJitterFrames=a['nonzeroJitterFrames'],
        maxFirstExposureHistoryMinusCurrent=max(e['maxHistoryMinusCurrent'] for e in events),maxFirstExposureHistoryAge=max(e['historyAge'] for e in events),
        unknown=sum(not e['currentKnown'] or not e['historyKnown'] for e in events),observations=events,evidenceSha256=sha(q/'analysis-first.json'))

def v2():
    manifest=load(CAP/'candidate.json');frames=[f['logicalFrame'] for f in manifest['frames']];primaries={};cache={};rows=[]
    names=['Floor','White receiver','Red wall','Green wall','Moving occluder','Thin-wall receiver','Sealed room gray receiver']
    for frame in frames:
        state=load(CAP/f'states/frame-{frame:04}.json');snapshot=state['dynamicState'];camera=Camera(state['camera'])
        key=json.dumps([state['camera'],[(g['key'],g['localToWorld']) for g in snapshot['geometry']]],sort_keys=True)
        if key not in cache:
            scene=Scene(snapshot);primary=render_primary(scene,camera,320,180)
            cache[key]=(primary,[g['name'] for g in scene.objects]);print('primary',frame,len(cache),flush=True)
        primary,objects=cache[key];primaries[frame]=primary
        domain=primary['classification']==RECEIVER;valid=known(frame);d=image(frame,'filteredD')[:,:,:3]
        positions=primary['sampledFullPixel'];before=image(frame,'cameraBeforeHLGI');after=image(frame,'cameraAfterHLGI');full=after[positions[:,:,1],positions[:,:,0],:3];delta=(after-before)[positions[:,:,1],positions[:,:,0],:3]
        depth=image(frame,'geometry')[:,:,3]
        row=dict(frame=frame,sourceReceiverPixels=int(domain.sum()),knownReceiverPixels=int((domain&valid).sum()),unknownReceiverPixels=int((domain&~valid).sum()),
                 sourceDepthAbsDifferenceP99=float(np.percentile(abs(depth-primary['deviceDepth'])[domain],99)),filteredD=stat(d,domain&valid),cameraAfter=stat(full,domain),compositeDelta=stat(delta,domain),roi={})
        for name in names:
            mask=domain&(primary['owner']==objects.index(name)) if name in objects else np.zeros_like(domain)
            row['roi'][name]=dict(sourcePixels=int(mask.sum()),knownPixels=int((mask&valid).sum()),unknownPixels=int((mask&~valid).sum()),filteredD=stat(d,mask&valid),cameraAfter=stat(full,mask),compositeDelta=stat(delta,mask))
        rows.append(row)
    # These are observable same-physical-source differences, never independent expected RGB.
    def difference(a,b,mask):
        v=mask&known(a)&known(b);da=image(a,'filteredD')[:,:,:3];db=image(b,'filteredD')[:,:,:3]
        delta=da-db;lum=delta@Y;den=np.mean((db[v]@Y)) if v.any() else 0
        return dict(frames=[a,b],sourcePixels=int(mask.sum()),pairedKnown=int(v.sum()),pairedUnknown=int((mask&~v).sum()),
                    meanSignedY=float(lum[v].mean()),meanAbsoluteY=float(abs(lum[v]).mean()),p95AbsoluteY=float(np.percentile(abs(lum[v]),95)),
                    normalizedMeanAbsoluteY=float(abs(lum[v]).mean()/den) if den>0 else None,
                    interpretation='Temporal difference to a later candidate snapshot; later candidate is not a physical oracle.')
    closed=primaries[119];opened=primaries[179];state=load(CAP/'states/frame-0179.json');scene=Scene(state['dynamicState']);objects=[g['name'] for g in scene.objects];door=objects.index('Moving occluder')
    revealed=(closed['owner']==door)&(opened['owner']!=door)&(opened['classification']==RECEIVER)&(closed['classification']==RECEIVER)
    hold=[difference(f,209,revealed) for f in [179,180]]
    color_domain=closed['classification']==RECEIVER
    off=[difference(f,299,color_domain) for f in [240,270]]
    static=[difference(f,119,color_domain) for f in [0,30,60,90]]
    chosen=[0,119,150,179,180,209,239,240,270,299,300,330,359,360,420,719]
    sheet=Image.new('RGB',(1280,4*202),(22,22,27));draw=ImageDraw.Draw(sheet)
    for k,frame in enumerate(chosen):
        # Display-only flip. All measurements above preserve the original stored matrix/row convention.
        tile=display(image(frame,'cameraAfterHLGI')[:,:,:3]).transpose(Image.Transpose.FLIP_TOP_BOTTOM).resize((320,180))
        x=(k%4)*320;y=(k//4)*202;sheet.paste(tile,(x,y+20));draw.text((x+5,y+3),f'Frame {frame}',fill='white')
    sheet.save(P/'sequence-contact-sheet-upright.png')
    # Same geometry at open-stop frames; magnify GI and identify the source-defined newly exposed cohort.
    sheet=Image.new('RGB',(960,220),(22,22,27));draw=ImageDraw.Draw(sheet)
    for col,frame in enumerate([179,180,209]):
        rgb=np.asarray(display(image(frame,'filteredD')[:,:,:3]*4)).copy();rgb[~known(frame)]=[255,0,255]
        edge=revealed.copy();edge[1:,:]&=~revealed[:-1,:];rgb[edge]=[0,255,255]
        tile=Image.fromarray(rgb).transpose(Image.Transpose.FLIP_TOP_BOTTOM);sheet.paste(tile,(col*320,25));draw.text((col*320+5,5),f'Frame {frame}: D x4; cyan exposed ROI',fill='white')
    sheet.save(P/'door-stop-gi-comparison.png')
    curves=[]
    for name in ['Floor','White receiver','Red wall','Green wall']:
        rr=[r for r in rows if r['frame']<=359];curves.append((name,[r['frame'] for r in rr],[r['roi'][name]['filteredD']['meanY'] for r in rr]))
    chart('720-frame sequence: sparse observed response',curves,'Logical frame (only stored samples)','Known source-ROI mean D luminance',size=(1000,400),markers=[(120,'move'),(180,'stop'),(240,'off'),(300,'on')]).save(P/'v209-response-curves.png')
    return dict(scope='32 real HDR samples from a 720-render sequence. ROIs come only from source triangle intersections; sky and raster-boundary pixels are not receivers. Unknown D is counted separately, never black. No physical-reference RGB used in these temporal-change summaries.',
        frames=rows,doorStopNewlyExposed=hold,lightOffToLateCandidate=off,staticToLateCandidate=static,
        displayTransform='vertical-flip for PNG contact sheets only; numeric measurements preserve original stored row/matrix alignment',
        warning='Light-off leaves the emissive mesh enabled, and default bounceFeedback=1. Remaining D is not assumed zero. Sparse samples cannot locate unobserved convergence time.',
        reference='Independent MC reference is a separate parallel artifact, to be compared after it is available.',
        inputs={'candidate.json':sha(CAP/'candidate.json'),'source.json':sha(CAP/'source.json'),'feature.json':sha(CAP/'feature.json')})

def main():
    report=dict(scope='Observed dynamic response, not a new formal certificate or physical quality PASS.',finiteWall=finite_wall(),cameraTaa=taa_motion())
    (P/'metrics-partial.json').write_text(json.dumps(report,indent=2))
    report['v209']=v2();(P/'metrics.json').write_text(json.dumps(report,indent=2));print('wrote',P/'metrics.json')
if __name__=='__main__':main()
