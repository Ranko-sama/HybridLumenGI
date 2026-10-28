"""Pre-execution double-precision reference; never reads GPU results."""
import hashlib,json,math
from pathlib import Path

root=Path(__file__).resolve().parents[2]
out=root/'LocalComparison/Review/cache-energy-decay-reference-01'
target=out/'reference.json'
assert not target.exists(),'Frozen reference must not be overwritten'
rho=[[.5,.25,.5],[.25,.5,.5]]
source=[1,.5,.25]
steady_l=[[rho[0][c]*source[c]/(1-rho[0][c]*rho[1][c]) for c in range(3)],[]]
steady_l[1]=[rho[1][c]*steady_l[0][c] for c in range(3)]
steady_c=[steady_l[1],steady_l[0]]
u=2**-24;gamma=32*u/(1-32*u)
ud=2**-53;gamma_double=8*ud/(1-8*ud)
cache=[[0.]*3 for _ in range(2)];error=[[0.]*3 for _ in range(2)];samples=[0,0]
rows=[]
for k in range(512):
    direct=[source if k<256 else [0.,0.,0.],[0.,0.,0.]]
    previous=cache;old_error=error;old_samples=samples
    prepared_samples=[min(s,1) if k==256 else s for s in old_samples]
    samples=[min(s+1,32) for s in prepared_samples]
    alpha=[max(1/s,.1) for s in samples]
    endpoint=[[rho[i][c]*(direct[i][c]+previous[i][c]) for c in range(3)] for i in range(2)]
    cache=[];error=[]
    for i in range(2):
        j=1-i;a=alpha[i]
        cache.append([(1-a)*previous[i][c]+a*endpoint[j][c] for c in range(3)])
        # At most 32 elementary rounded operations on the enabled energy path,
        # including alpha division/representation and lerp. Cosine/cosine is 1;
        # single cell interpolation, binary rho/light and division by rayCount=1
        # introduce no unbounded trig error into energy. No fitting to GPU output.
        error.append([(1-a)*old_error[i][c]+a*rho[j][c]*old_error[j][c]+
            (gamma+gamma_double)*(abs(previous[i][c])+old_error[i][c]+abs(endpoint[j][c])+rho[j][c]*old_error[j][c])+2**-120
            for c in range(3)])
    rows.append({'round':k,'sourceOn':k<256,'lightingChange':k==256,'readBuffer':k%2,'writeBuffer':1-k%2,
        'mask':[1,1],'old':previous,'oldSamples':old_samples,'preparedSamples':prepared_samples,'samples':samples,'alpha':alpha,
        'direct':direct,'endpointRadiance':endpoint,'new':cache,'roundingBound':error,
        'steadyErrorBound':[[abs(cache[i][c]-(steady_c[i][c] if k<256 else 0))+error[i][c] for c in range(3)] for i in range(2)]})
result={'baseline':'1b8e751','quantity':'C = indirect E/pi; L = rho*(direct E/pi+C), emission=0, AO=feedback=1',
    'rho':rho,'source':source,'steadyRadiance':steady_l,'steadyCache':steady_c,
    'roundoff':{'unitRoundoffFloat32':u,'operationAllowance':32,'gamma32':gamma,'unitRoundoffDouble':ud,'underflowAllowance':2**-120,
        'derivation':'e_next_i <= (1-alpha)*e_i+alpha*rho_j*e_j + (gamma32+gamma8_double)*(abs(C_i)+e_i+abs(L_j)+rho_j*e_j)+2^-120. Round-local scale decays with the source; no fixed error floor fitted from observations.'},
    'rounds':rows,'scope':'Ideal two-node operator; no real geometry, whole-image, frame-time, atlas capture or runtime light detection claim.'}
out.mkdir(parents=True,exist_ok=True)
target.write_text(json.dumps(result,indent=2),encoding='utf-8')
(out/'reference-generator.executed.py.txt').write_bytes(Path(__file__).read_bytes())
print(json.dumps({'referenceSha256':hashlib.sha256(target.read_bytes()).hexdigest(),'rounds':len(rows),
    'steadyCache':steady_c,'onFinalBound':rows[255]['steadyErrorBound'],'offFinalBound':rows[-1]['steadyErrorBound']}))
