"""Compare existing candidate D with an independent source-only approximate MC picture."""
import argparse,json
from pathlib import Path
import numpy as np
from PIL import Image,ImageDraw
from analyze import CAP,P,Y,load,sha,image,known,display,stat

def main():
    parser=argparse.ArgumentParser();parser.add_argument('reference');args=parser.parse_args();q=Path(args.reference)
    refreport=load(q/'report.json');frame=refreport['logicalFrame'];candidate=load(CAP/'candidate.json')
    assert refreport['sourceSha256']==candidate['source']['sha256'] and refreport['stateSha256']==sha(CAP/f'states/frame-{frame:04}.json')
    assert refreport['quantity']=='indirect-irradiance-over-pi' and refreport['width']==320 and refreport['height']==180
    for row in refreport['artifacts']:assert sha(q/row['file'])==row['sha256']
    reference=np.fromfile(q/'filteredD.rgba32f',dtype='<f4').reshape(180,320,4)[:,:,:3]
    domain=np.fromfile(q/'validity.u8',dtype='u1').reshape(180,320)>0;primary=np.load(q/'primary.npz');statistics=np.load(q/'statistics.npz')
    stderr=statistics['standardErrorRgb'].reshape(180,320,3);source=load(CAP/f'states/frame-{frame:04}.json');names=[g['name'] for g in source['dynamicState']['geometry']]
    frames=[240,270,299] if frame==299 else [0,30,60,90,119,120,239,300,330,359] if frame==119 else [frame];rows=[]
    for f in frames:
        state=load(CAP/f'states/frame-{f:04}.json');assert state['dynamicState']==source['dynamicState'] and state['camera']==source['camera'],'Reference reuse requires exact same physical inputs'
        actual=image(f,'filteredD')[:,:,:3];valid=known(f);row=dict(frame=f,referenceFrame=frame,sourcePixels=int(domain.sum()),unknownCandidatePixels=int((domain&~valid).sum()),roi={})
        for name in ['all-source-receivers','Floor','White receiver','Red wall','Green wall','Moving occluder']:
            region=domain if name=='all-source-receivers' else domain&(primary['owner']==names.index(name))
            mask=region&valid
            if not mask.any():continue
            delta=actual-reference;y0=reference@Y;dy=delta@Y;rgb0=reference[mask].mean(0);rgb1=actual[mask].mean(0)
            row['roi'][name]=dict(sourcePixels=int(region.sum()),comparedPixels=int(mask.sum()),unknownPixels=int((region&~valid).sum()),
                candidateMeanRGB=rgb1.tolist(),referenceMeanRGB=rgb0.tolist(),meanBiasRGB=delta[mask].mean(0).tolist(),
                referenceMeanY=float(y0[mask].mean()),candidateMeanY=float((actual[mask]@Y).mean()),meanBiasY=float(dy[mask].mean()),
                meanAbsoluteY=float(abs(dy[mask]).mean()),relativeMeanBiasY=float(dy[mask].mean()/y0[mask].mean()),
                meanPixelStandardErrorRGB=stderr[mask].mean(0).tolist(),meanPixelConservativeLumaSE=float((stderr[mask]@Y).mean()),
                meanChromaL1=float(abs(rgb1/rgb1.sum()-rgb0/rgb0.sum()).sum()),
                meanMetalHitFraction=float(statistics['metalHitFraction'].reshape(180,320)[mask].mean()),
                meanMaxDepthFraction=float(statistics['maxDepthReachedFraction'].reshape(180,320)[mask].mean()))
        rows.append(row)
        if f!=frame:continue
        sheet=Image.new('RGB',(1280,225),(22,22,27));draw=ImageDraw.Draw(sheet)
        rgb_actual=np.asarray(display(actual)).copy();rgb_ref=np.asarray(display(reference)).copy()
        yy,xx=np.indices(domain.shape);checker=np.uint8(80+((xx//6+yy//6)%2)*35);checker=np.repeat(checker[:,:,None],3,axis=2)
        rgb_actual[~domain]=checker[~domain];rgb_ref[~domain]=checker[~domain];rgb_actual[domain&~valid]=[255,0,255]
        difference=(actual-reference)@Y;scale=.05
        heat=np.zeros((180,320,3),dtype=np.uint8);level=np.clip(abs(difference)/scale,0,1)
        heat[:,:,0]=np.where(difference>=0,255*level,0);heat[:,:,2]=np.where(difference<0,255*level,0);heat[~domain]=checker[~domain];heat[domain&~valid]=[255,0,255]
        error=np.clip((stderr@Y)/scale,0,1);uncertainty=np.uint8(np.stack([error,error*.6,np.zeros_like(error)],-1)*255);uncertainty[~domain]=checker[~domain]
        for i,(rgb,title) in enumerate([(rgb_actual,f'Candidate D frame {f}'),(rgb_ref,f'Independent MC D ({refreport["spp"]} spp)'),(heat,'Delta Y: red positive / blue negative'),(uncertainty,'MC pixel SE (not model bias)')]):
            tile=Image.fromarray(rgb).transpose(Image.Transpose.FLIP_TOP_BOTTOM);sheet.paste(tile,(i*320,25));draw.text((i*320+5,5),title,fill='white')
        draw.text((5,208),'Both D images: exposure 1, same Reinhard+sRGB. Heat/SE scale: 0.05. Gray checker=not compared; magenta=unknown.',fill='white')
        sheet.save(P/f'color-reference-{frame:04}.png')
    result=dict(scope='Independent approximate diffuse path tracing versus candidate filteredD. The reported discrepancy includes candidate error, Monte Carlo uncertainty and reference model bias; no certified quality PASS.',referenceDirectory=str(q),referenceReportSha256=sha(q/'report.json'),
        modelDifferences=refreport['modelDifferences'],sameSourceReuseFrames=frames,rows=rows,sourceOnlyRois=True,
        unknownIsNotBlack=True,exposure=1,displayTransform='vertical flip only; all numerical comparisons use original aligned rows')
    (P/f'reference-comparison-{frame:04}.json').write_text(json.dumps(result,indent=2));print(json.dumps(dict(referenceFrame=frame,comparedFrames=frames,output=str(P/f'reference-comparison-{frame:04}.json'))))
if __name__=='__main__':main()
