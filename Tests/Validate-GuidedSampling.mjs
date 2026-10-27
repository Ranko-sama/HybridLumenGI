import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';

// A deterministic numerical reference for the shader's sampling distribution, not GPU execution.
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const source=fs.readFileSync(path.join(root,'Runtime/Resources/HybridLumenGI/HybridLumenGITransport.hlsl'),'utf8');
const emissive=fs.readFileSync(path.join(root,'Runtime/Resources/HybridLumenGI/HybridLumenGIEmissiveSampling.hlsl'),'utf8');
const kernels=fs.readFileSync(path.join(root,'Runtime/Resources/HybridLumenGI/HybridLumenGIKernels.hlsl'),'utf8');
assert(emissive.replace(/\s+/g,'').includes('if(emissive<=0)returnHLGISampleDirection(normal,guide,rng,weight);'),
  'Disabled/empty emissive proposals must preserve the original two-lobe sampler.');
assert(source.includes('HLGISampleTransportDirection(origin,n,e.guide,rng,weight)') &&
  kernels.includes('HLGISampleTransportDirection(origin,n,receiverCache.guide,rng,sampleWeight)'),
  'Cache and camera rays must use the same transport sampler with their biased trace origin.');
const cacheSeed=source.match(/uint rng=HLGIHash\(\(id\.x\+HLGIHash\(\(uint\)_HLGI_FrameIndex\+1\)\)\^(0x[0-9A-F]+)u\);/);
const cameraSeed=kernels.match(/uint rng=HLGIHash\(\(id\.x\+id\.y\*\(uint\)_HLGI_Size\.x\+HLGIHash\(\(uint\)_HLGI_FrameIndex\+1\)\)\^(0x[0-9A-F]+)u\);/);
assert(cacheSeed&&cameraSeed,'Both live seed expressions must preserve explicit cache/camera domain salts.');
const cacheSalt=Number(cacheSeed[1])>>>0,cameraSalt=Number(cameraSeed[1])>>>0;
assert.notEqual(cacheSalt,cameraSalt,'The two consumers must not repeat an identical same-index/frame stream.');
function hash32(x){x=(x^(x>>>16))>>>0;x=Math.imul(x,0x7feb352d)>>>0;x=(x^(x>>>15))>>>0;x=Math.imul(x,0x846ca68b)>>>0;return(x^(x>>>16))>>>0;}
let domainChecks=0;
for(const frame of [0,1,17,255,65535,0x7fffffff,0xfffffffe,0xffffffff])for(let index=0;index<4096;index++){
  const combined=(index+hash32((frame+1)>>>0))>>>0;
  let cache=hash32(combined^cacheSalt),camera=hash32(combined^cameraSalt);
  assert.notEqual(cache,camera,'Equal cache/pixel indices cannot have identical initial RNG states.');
  const a=[],b=[];for(let draw=0;draw<4;draw++){cache=hash32(cache);camera=hash32(camera);a.push(cache>>>8);b.push(camera>>>8);}
  assert.notDeepEqual(a,b,'The first four represented random draws cannot exactly reuse the other domain.');domainChecks++;
}
// Domain hashing removes this known exact stream reuse; it is not a proof of
// statistical independence between the evolving guide and all future samples.
console.log(`PASS ${domainChecks} equal-index/frame cache/camera RNG domain checks; no identical initial state or four-draw stream.`);
const start=source.indexOf('float3 HLGISampleDirection(');
assert(start>=0,'Shader guided sampler is missing.');
const begin=source.indexOf('{',start);let depth=1,end=begin+1;
for(;end<source.length&&depth;end++){if(source[end]==='{')depth++;else if(source[end]==='}')depth--;}
const body=source.slice(begin+1,end-1).replace(/\/\/[^\n]*/g,'');
const compact=body.replace(/\s+/g,'');
assert(compact.includes('weight=cosine/max((1-mixture)*cosine+mixture*guidedCosine,1e-8);'),
  'Shader must divide by the complete two-lobe mixture PDF, including the unselected branch.');
assert(compact.includes('floatcosine=saturate(dot(n,direction)),guidedCosine=saturate(dot(axis,direction));'),
  'The receiver cosine and guide cosine must be clamped independently.');
assert.equal((body.match(/Random\(rng\)/g)||[]).length,3,'One branch draw and exactly two lobe draws are expected.');
assert(!/\b(?:while|for|do)\b/.test(body),'Do not reject/resample directions below the receiver hemisphere.');
assert(compact.includes('CosineHemisphere(branch<mixture?axis:n,xi)'),'Branch probability and lobe selection must agree.');

const dot=(a,b)=>a[0]*b[0]+a[1]*b[1]+a[2]*b[2];
const cross=(a,b)=>[a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]];
const normalize=a=>{const s=1/Math.hypot(...a);return a.map(x=>x*s);};
const saturate=x=>Math.min(1,Math.max(0,x));
function basis(n){const t=normalize(cross(Math.abs(n[2])<.999?[0,0,1]:[0,1,0],n));return[t,cross(n,t),n];}
function transform(b,x,y,z){return[b[0][0]*x+b[1][0]*y+b[2][0]*z,b[0][1]*x+b[1][1]*y+b[2][1]*z,b[0][2]*x+b[1][2]*y+b[2][2]*z];}
function cosineSample(b,u,v){const r=Math.sqrt(u),p=2*Math.PI*v;return transform(b,r*Math.cos(p),r*Math.sin(p),Math.sqrt(1-u));}
function rng(seed){let state=seed>>>0;return()=>{state=(Math.imul(state,1664525)+1013904223)>>>0;return state/4294967296;};}
function quadrature(n,light){
  const b=basis(n);let bright=0,polynomial=0;const nz=256,np=512;
  for(let iz=0;iz<nz;iz++){const z=(iz+.5)/nz,r=Math.sqrt(1-z*z);
    for(let ip=0;ip<np;ip++){const p=2*Math.PI*(ip+.5)/np,w=transform(b,r*Math.cos(p),r*Math.sin(p),z),d=dot(w,light);
      bright+=(.05+30*Math.pow(Math.max(d,0),16))*z*2/(nz*np);
      polynomial+=(.4+.6*d*d)*z*2/(nz*np);
    }
  }
  const exact=.55+.15*Math.pow(dot(n,light),2);
  assert(Math.abs(polynomial-exact)<2e-5,'Independent hemisphere quadrature failed its analytic cross-check.');
  return[1,exact,bright];
}
function pdfIntegral(n,axis,mix){
  let integral=0;const nz=128,np=256;
  for(let iz=0;iz<nz;iz++){const z=2*(iz+.5)/nz-1,r=Math.sqrt(1-z*z);
    for(let ip=0;ip<np;ip++){const p=2*Math.PI*(ip+.5)/np,w=[r*Math.cos(p),r*Math.sin(p),z];
      integral+=4*((1-mix)*Math.max(dot(n,w),0)+mix*Math.max(dot(axis,w),0))/(nz*np);
    }
  }
  assert(Math.abs(integral-1)<.0004,`Mixture PDF must integrate to one over the full sphere: ${integral}`);
}
const rotated=normalize([.27,.81,.52]),rotatedBasis=basis(rotated);
const cases=[
  {name:'cosine baseline',n:[0,0,1],axis:[0,0,1],mix:0},
  {name:'aligned guide',n:[0,0,1],axis:[0,0,1],mix:.8},
  {name:'tilted 45 degrees',n:[0,0,1],axis:normalize([1,0,1]),mix:.35},
  {name:'grazing guide',n:[0,0,1],axis:normalize([1,0,.02]),mix:.8},
  {name:'guide below horizon',n:[0,0,1],axis:normalize([1,0,-.45]),mix:.8},
  {name:'opposite guide',n:[0,0,1],axis:[0,0,-1],mix:.8},
  {name:'rotated receiver',n:rotated,axis:normalize(transform(rotatedBasis,.9,.2,-.35)),mix:.65}
];
const count=600000;let totalBelow=0,maxRelativeError=0;
for(let ci=0;ci<cases.length;ci++){
  const c=cases[ci],random=rng(0x93d12+ci*173),bn=basis(c.n),ba=basis(c.axis);
  const light=normalize(transform(bn,.82,.14,.55)),reference=quadrature(c.n,light);
  pdfIntegral(c.n,c.axis,c.mix);
  const sum=[0,0,0],squares=[0,0,0];let below=0;
  for(let i=0;i<count;i++){
    // Exactly one branch draw and one sample, even when the chosen guide points below n.
    const branch=random(),u=random(),v=random(),w=cosineSample(branch<c.mix?ba:bn,u,v);
    const cosine=saturate(dot(c.n,w)),guidedCosine=saturate(dot(c.axis,w));
    const weight=cosine/Math.max((1-c.mix)*cosine+c.mix*guidedCosine,1e-8);
    assert(Number.isFinite(weight)&&weight>=0&&weight<=1/(1-c.mix)+1e-9,'Estimator weight lost its bounded cosine proposal.');
    if(cosine===0){below++;assert.equal(weight,0);}
    const d=dot(w,light),values=[1,.4+.6*d*d,.05+30*Math.pow(Math.max(d,0),16)];
    for(let k=0;k<3;k++){const value=values[k]*weight;sum[k]+=value;squares[k]+=value*value;}
  }
  const estimates=sum.map(x=>x/count);
  for(let k=0;k<3;k++){
    const variance=Math.max(squares[k]/count-estimates[k]*estimates[k],0),stderr=Math.sqrt(variance/count);
    const tolerance=6*stderr+3e-4;
    assert(Math.abs(estimates[k]-reference[k])<tolerance,`${c.name}, integrand ${k}: ${estimates[k]} vs ${reference[k]} (tolerance ${tolerance}).`);
    maxRelativeError=Math.max(maxRelativeError,Math.abs(estimates[k]-reference[k])/Math.max(reference[k],1e-9));
  }
  if(c.name==='opposite guide'){
    assert(below/count>.79&&below/count<.81,'Opposite lobe must retain its below-hemisphere probability mass.');
    // Dividing by accepted samples (or resampling until above) is demonstrably biased.
    const wrongRejectionEstimate=sum[0]/(count-below);
    assert(Math.abs(wrongRejectionEstimate-1)>3,'Regression test did not expose below-hemisphere rejection bias.');
  }
  totalBelow+=below;
  console.log(`PASS ${c.name}: constant=${estimates[0].toFixed(5)}, polynomial=${estimates[1].toFixed(5)}, bright lobe=${estimates[2].toFixed(5)}, zero-weight below=${below}`);
}
console.log(`PASS: ${cases.length*count} deterministic mixture samples; full-PDF normalization, analytic/independent integration targets, bounded weights and no below-hemisphere resampling. Maximum relative integration error ${(100*maxRelativeError).toFixed(3)}%; ${totalBelow} below-hemisphere samples retained with zero weight. CPU numerical reference plus live HLSL contract checks, not GPU execution.`);
