"""Independent finite-round and closed-form checks of the single actual GPU batch."""
import hashlib,json,sys
from pathlib import Path
import numpy as np
root=Path(__file__).resolve().parents[2];out=root/'LocalComparison/Review/cache-energy-decay-reference-01'
ref=json.loads((out/'reference.json').read_text(encoding='utf-8'))
receipt=json.loads((out/'execution.json').read_text(encoding='utf-8'))
collection=json.loads((out/'run/collection.json').read_text(encoding='utf-8'))
manifest=json.loads((out/'source/manifest.json').read_text(encoding='utf-8'))
failures=[]
def check(condition,label,round=None,node=None,detail=None):
    if not condition:failures.append({'check':label,'round':round,'node':node,'detail':detail})
def equal(actual,expected,label,k,i):check(np.array_equal(actual,expected),label,k,i,{'actual':np.asarray(actual).tolist(),'expected':np.asarray(expected).tolist()})
def bounded(actual,expected,bound,label,k,i):
    delta=np.abs(np.asarray(actual,dtype=np.float64)-np.asarray(expected));b=np.asarray(bound)
    check(np.all(delta<=b),label,k,i,{'actual':np.asarray(actual).tolist(),'expected':np.asarray(expected).tolist(),'error':delta.tolist(),'bound':b.tolist()})
check(hashlib.sha256((out/'reference.json').read_bytes()).hexdigest()==manifest['referenceSha256'],'frozen reference hash')
check(receipt['exitCode']==0 and not receipt['nativeFailureSignatures'] and all(receipt['sourceChecks'].values()),'native exit and frozen source')
check(collection['collectionComplete'] and collection['rounds']==512 and collection['pending']==0 and not collection['error'],'complete readback')
obs=np.fromfile(out/'run/observations.bin',dtype='<f4');written=np.fromfile(out/'run/cache.bin',dtype='<f4')
check(obs.size==512*2*26*4 and written.size==512*2*5*4,'binary sizes')
check(np.all(np.isfinite(obs)) and np.all(np.isfinite(written)),'finite records')
if failures:
    result={'passed':False,'failureCount':len(failures),'failures':failures}
    (out/'analysis.json').write_text(json.dumps(result,indent=2),encoding='utf-8');print(json.dumps(result));sys.exit(1)
obs=obs.reshape(512,2,26,4);written=written.reshape(512,2,5,4)
rho=np.asarray(ref['rho']);gamma=ref['roundoff']['gamma32'];tiny=ref['roundoff']['underflowAllowance']
u=ref['roundoff']['unitRoundoffFloat32'];gamma4=4*u/(1-4*u)
maximum_ratio=0.;maximum_error=0.;first=[]
for k,row in enumerate(ref['rounds']):
    step=collection['steps'][k]
    check(step['round']==k and step['distinctBuffers'] and step['readBuffer']==k%2 and step['writeBuffer']==1-k%2 and
        step['mask']==[1,1] and step['changeCount']==int(k==256) and step['sourceOn']==(k<256),'CPU dispatch schedule',k)
    equal([collection['rho'][i][c] for i in range(2) for c in 'xyz'],rho.reshape(-1),'input reflectance',k,None)
    previous_bound=np.asarray(ref['rounds'][k-1]['roundingBound']) if k else np.zeros((2,3))
    for i in range(2):
        j=1-i;o=obs[k,i];old=o[:5];new=o[5:10];bound=np.asarray(row['roundingBound'][i]);expected=np.asarray(row['new'][i])
        equal(new,written[k,i],'observed equals actual cache-write buffer',k,i)
        equal(old,written[k-1,i] if k else np.zeros((5,4)),'actual old buffer equals prior write bytes',k,i)
        equal(o[19],[k,i,k%2,1-k%2],'GPU buffer/schedule labels',k,i)
        equal(o[20],row['direct'][0]+[0],'actual source state',k,i)
        equal(o[21],[1,1,1,1],'known/update/mask/patch',k,i)
        equal(o[22],[1,0,0,j],'actual environment calls and pair',k,i)
        equal(o[25],[0,0,0,0],'disabled guide/emitter and adapter failure flags',k,i)
        equal(o[12],[0,int(k==256),0,int(k==256)],'actual lighting change response',k,i)
        equal(new[1],[i+1,2,3,i+4],'identity/revision/epoch/generation',k,i)
        equal(new[2],[.5,.5,.5+2*i,0],'actual cache anchor',k,i)
        equal(new[3],[0,0,1,0],'actual shading/geometric normal',k,i)
        equal(o[10,:3],old[0,:3],'history retained RGB',k,i)
        equal(o[10,3],row['preparedSamples'][i],'prepared samples including reactive trim',k,i)
        equal(new[0,3],row['samples'][i],'committed samples',k,i)
        equal(o[15],row['direct'][j]+[1],'actual directional direct injection and known flag',k,i)
        equal(o[18],[int(k>0),j,j+1,j+4],'actual endpoint lookup status and identity',k,i)
        equal(o[16,3],row['oldSamples'][j] if k else 0,'lookup reads untrimmed partner old samples',k,i)
        bounded(o[16,:3],row['old'][j],previous_bound[j]+tiny,'lookup partner old RGB',k,i)
        endpoint=np.asarray(row['endpointRadiance'][j])
        endpoint_bound=rho[j]*previous_bound[j]+gamma*(np.abs(endpoint)+rho[j]*previous_bound[j])+tiny
        bounded(o[14,:3],endpoint,endpoint_bound,'actual outgoing endpoint radiance',k,i)
        equal(o[14,3],1,'endpoint confidence',k,i)
        bounded(o[13,3],1,gamma4,'actual cosine weight within float division bound',k,i)
        check(o[13,2]>0 and abs(np.dot(o[13,:3].astype(float),o[13,:3])-1)<2**-18,'unit positive cosine direction',k,i)
        check(o[24,0]>0 and o[24,1]==0 and np.array_equal(o[24,2:],[1,1]),'actual valid card/hit footprint',k,i)
        bounded(new[0,:3],expected,bound,'finite-round cache energy',k,i)
        bounded(o[23,:3],o[14,:3].astype(float)*float(o[13,3]),2*u*np.abs(o[23,:3])+tiny,'one-ray accumulated weighted sum',k,i)
        equal(new[4,3],o[23,3],'actual guide power committed',k,i)
        check(new[4,3]>=0 and abs(np.dot(new[4,:3].astype(float),new[4,:3])-1)<2**-17,'finite unit guide with nonnegative power',k,i)
        error=np.abs(new[0,:3].astype(float)-expected)
        maximum_ratio=max(maximum_ratio,float(np.max(error/bound)));maximum_error=max(maximum_error,float(np.max(error)))
    if k in [0,1,2,255,256,257,511]:first.append({'round':k,'actualCache':written[k,:,0,:].tolist(),'reference':row['new'],'bound':row['roundingBound']})
for k in [255,511]:
    target=np.asarray(ref['steadyCache']) if k==255 else np.zeros((2,3))
    bounded(written[k,:,0,:3],target,ref['rounds'][k]['steadyErrorBound'],'independent equilibrium plus finite-round bound',k,None)
result={'passed':not failures,'rounds':512,'failureCount':len(failures),'firstDivergence':failures[0] if failures else None,'failures':failures,
    'maximumFiniteRoundAbsoluteError':maximum_error,'maximumFractionOfPredeclaredBound':maximum_ratio,'selectedRounds':first,
    'onFinalActualCache':written[255,:,0,:3].tolist(),'onFinalSteadyBound':ref['rounds'][255]['steadyErrorBound'],
    'offFinalActualCache':written[511,:,0,:3].tolist(),'offFinalZeroBound':ref['rounds'][511]['steadyErrorBound'],
    'nativeExitPassed':receipt['exitCode']==0 and not receipt['nativeFailureSignatures'],
    'scope':ref['scope']}
(out/'analysis.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
print(json.dumps({k:result[k] for k in ['passed','rounds','failureCount','firstDivergence','maximumFiniteRoundAbsoluteError','maximumFractionOfPredeclaredBound','offFinalActualCache']}))
sys.exit(0 if result['passed'] else 1)
