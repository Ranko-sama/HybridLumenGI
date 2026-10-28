import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';

// Independent directional-radiance integrals plus float32 edge cases and live source
// contracts. No Unity/HLSL execution, rasterization or GPU timing is performed here.
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const read=file=>fs.readFileSync(path.join(root,'Runtime/Resources/HybridLumenGI',file),'utf8');
const source=read('HybridLumenGIEmissiveSampling.hlsl'),transport=read('HybridLumenGITransport.hlsl'),kernels=read('HybridLumenGIKernels.hlsl');
const compact=source.replace(/\/\/[^\n]*/g,'').replace(/\s+/g,'');
assert(compact.includes('floatpmf=record.data.y-record.data.x;'),'Selection and PDF must use represented CDF intervals.');
assert(compact.includes('pdf+=pmf*HLGIEmissiveVmfPdf(origin,record.sphere,direction);'),'PDF must sum every candidate, including overlaps.');
assert(compact.includes('selector>=interval.x&&selector<interval.y'),'Zero-width CDF intervals must never be selected.');
assert(compact.includes('axis=float3(0,0,1);sharpness=0;')&&compact.includes('if(sharpness<=0)return1/(4*PI);'),'Inside/degenerate lobes must retain normalized sphere density.');
assert.equal((compact.match(/HLGIEmissiveLobe\(origin,sphere,axis,sharpness\)/g)||[]).length,2,'Sample and PDF share the same lobe construction.');
assert(compact.includes('delta=sinSquared/(1+sqrt(max(0,1-sinSquared)))')&&compact.includes('sharpness=1/max(delta,1e-4);'),'Stable angular scale and bounded vMF concentration contract.');
assert(compact.includes('float3chord=direction-axis;')&&compact.includes('exp(-0.5*sharpness*dot(chord,chord))'),'Smooth vMF PDF must avoid a hard support edge and dot-minus-one cancellation.');
assert(compact.includes('log((1-xi.x)+xi.x*tail)')&&compact.includes('sqrt(max(0,-r*(r+2)))'),'Inverse CDF preserves endpoint complements and angular spread.');
assert(!compact.includes('dot(axis,direction)>='),'The removed hard-cone support test must not return.');
assert(compact.includes('!isfinite(distanceSquared)')&&compact.includes('!isfinite(radiusSquared)')&&compact.includes('!all(isfinite(offset))'),'Float32 overflow must use the same normalized fallback.');
assert(compact.includes('floatguided=(1-emissive)*guideFraction;')&&compact.includes('floatcosineFraction=(1-emissive)*(1-guideFraction);'),'Mixture branch probabilities must leave cosine support.');
assert(compact.includes('(cosineFraction*receiverCosine+guided*guideCosine)/PI+emissive*HLGIEmissiveDirectionalPdf(origin,direction,count);'),'Complete direction PDF includes all three strategies.');
assert(compact.includes('receiverCosine/(PI*pdf)'),'D=E/pi estimator must use full solid-angle PDF.');
assert(compact.includes('if(emissive<=0)returnHLGISampleDirection(normal,guide,rng,weight);'),'Empty/disabled table must retain exact old random sequence.');
const sampler=compact.slice(compact.indexOf('float3HLGISampleTransportDirection('));
assert(!/\bwhile\b/.test(sampler)&&!sampler.includes('for('),'No conditional hemisphere/hit rejection in the transport sampler.');
assert(transport.includes('HLGISampleTransportDirection(origin,n,e.guide,rng,weight)')&&kernels.includes('HLGISampleTransportDirection(origin,n,receiverCache.guide,rng,sampleWeight)'),'Both paths must pass the actual biased origin.');
// The weighting/commit operations now live in the shared validity helpers.
// These are bounded source-wiring checks; the independent integrals below stay
// unchanged, and actual helper execution belongs to RadianceValidity's WARP test.
function body(text,declaration) {
  text=text.replace(/\/\*[\s\S]*?\*\//g,'').replace(/\/\/[^\n]*/g,'').replace(/\s+/g,'');
  const start=text.indexOf(declaration);assert(start>=0,`Missing declaration ${declaration}`);
  const open=text.indexOf('{',start);assert(open>=0,`Missing body ${declaration}`);
  let depth=1,end=open+1;
  for(;end<text.length&&depth;end++)depth+=(text[end]==='{')-(text[end]==='}');
  assert.equal(depth,0,`Unterminated body ${declaration}`);return text.slice(open+1,end-1);
}
const validity=read('HybridLumenGIRadianceValidity.hlsl');
const accumulate=body(validity,'boolHLGIAccumulateRadianceSample('),commit=body(validity,'boolHLGICommitCacheEstimate(');
const cacheBody=body(transport,'voidCSUpdateCache('),traceBody=body(kernels,'voidCSTrace(');
assert(accumulate.includes('float3next=sum+incoming*weight;')&&accumulate.includes('sum=next;returntrue;')&&
  (accumulate.match(/incoming\*weight/g)||[]).length===1&&
  cacheBody.includes('HLGIAccumulateRadianceSample(incoming,materialConfidence,weight,sum)')&&
  traceBody.includes('HLGIAccumulateRadianceSample(_HLGI_AreaEmitterCount>0?incoming:LimitRadiance(incoming),sampleConfidence,sampleWeight,sum)')&&
  cacheBody.includes('HLGIAccumulateRadianceSample(lightValue,1,1,sum)')&&
  traceBody.includes('HLGIAccumulateRadianceSample(lightValue,1,1,sum)')&&
  (cacheBody.match(/HLGIAccumulateRadianceSample\(/g)||[]).length===2&&
  (traceBody.match(/HLGIAccumulateRadianceSample\(/g)||[]).length===2&&
  !/sum(?:\+=|-=|\*=|\/=)/.test(cacheBody+traceBody),
  'Direction Li is weighted once; its paired area term already contains cos/(pi*(pB+pL)) and is accumulated once at unit weight, without a separate nonlinear clamp.');
assert(cacheBody.includes('HLGIAreaMatchedDirectionWeight(origin,n,e.guide,direction,weight)')&&
  traceBody.includes('HLGIAreaMatchedDirectionWeight(origin,n,receiverCache.guide,dir,sampleWeight)'),
  'Area MIS must use the complete actual direction PDF rather than the legacy grazing denominator floor.');
assert(cacheBody.includes('HLGIAreaDirectionEmissionWeight(origin,n,e.guide,direction,hit,emissionWeight)')&&
  traceBody.includes('HLGIAreaDirectionEmissionWeight(origin,n,receiverCache.guide,dir,hit,emissionWeight)')&&
  traceBody.includes('lightValue=0;lightKnown=true;'),
  'World-hit emission needs a paired weight; a winning screen endpoint excludes the area term as known zero.');
assert(commit.includes('float3estimate=sum/rayCount;')&&
  cacheBody.includes('HLGICommitCacheEstimate(estimateKnown,sum,guide,guidePower,_HLGI_CacheRays,n,e.irradiance,e.guide)')&&
  cacheBody.includes('for(intr=0;r<_HLGI_CacheRays;r++)')&&traceBody.includes('for(intr=0;r<_HLGI_Rays;r++)')&&
  traceBody.includes('sum/max(_HLGI_Rays,1)'),'Normalize by all requested draws, not accepted hits.');
assert(!/ProxyRadiance|TraceScene|DirectIrradiance|\.emission|\.rgb/.test(source.replace(/\/\/[^\n]*/g,'')),'Proposal header cannot add emitted radiance or replace tracing.');

const PI=Math.PI,TAU=2*PI,F=Math.fround;
const dot=(a,b)=>a[0]*b[0]+a[1]*b[1]+a[2]*b[2];
const normalize=a=>{const length=Math.hypot(...a);return a.map(v=>v/length);};
const cross=(a,b)=>[a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]];
const maxCos=(n,w)=>Math.max(0,Math.min(1,dot(n,w)));
function frame(axis){const t=normalize(cross(Math.abs(axis[2])<.999?[0,0,1]:[0,1,0],axis));return[t,cross(axis,t),axis];}
function orient(b,x,y,z){return[0,1,2].map(i=>b[0][i]*x+b[1][i]*y+b[2][i]*z);}
function random(seed){let state=seed>>>0;const r=()=>{state=(Math.imul(state,1664525)+1013904223)>>>0;return(state>>>8)/16777216;};r.state=()=>state;return r;}
function cosine(axis,u,v){const r=Math.sqrt(u),phi=TAU*v;return orient(frame(axis),r*Math.cos(phi),r*Math.sin(phi),Math.sqrt(1-u));}
function record(sphere,lo,hi){return{sphere,lo,hi};}
function sphereAt(axis,distance,theta){return[...axis.map(v=>v*distance),distance*Math.sin(theta)];}

// Double-precision geometry oracle: derive sphere angular scale with asin,
// independently of the shader's rational expression. It controls a smooth vMF lobe.
function lobe(origin,sphere){
  const delta=sphere.slice(0,3).map((v,i)=>v-origin[i]),distance=Math.hypot(...delta),radius=sphere[3];
  if(!sphere.every(Number.isFinite)||!origin.every(Number.isFinite)||radius<=0||distance<=radius)return{axis:[0,0,1],k:0};
  const theta=Math.asin(radius/distance),width=Math.max(1-Math.cos(theta),1e-4);
  return{axis:delta.map(v=>v/distance),k:1/width};
}
function lobePdf(c,w){return c.k===0?1/(4*PI):c.k*Math.exp(c.k*(dot(c.axis,w)-1))/(TAU*(-Math.expm1(-2*c.k)));}
function lobeSample(c,u,v){const d=c.k>0?Math.log1p(u*Math.expm1(-2*c.k))/c.k:-2*u,z=1+d,r=Math.sqrt(Math.max(0,-d*(d+2))),phi=TAU*v;return orient(frame(c.axis),r*Math.cos(phi),r*Math.sin(phi),z);}
function build(records,origin){return records.map(r=>({...r,pmf:r.hi-r.lo,lobe:lobe(origin,r.sphere)}));}
function density(list,w){let p=0;for(const r of list)if(r.pmf>0)p+=r.pmf*lobePdf(r.lobe,w);return p;}
function choose(list,u){const index=list.findIndex(r=>u>=r.lo&&u<r.hi);assert(index>=0,'CDF has an uncovered selection interval');return index;}
function coefficients(list,e,g){e=list.length?Math.max(0,Math.min(.8,e)):0;g=Math.max(0,Math.min(.8,g));return{e,g:(1-e)*g,c:(1-e)*(1-g)};}
function oldSample(n,axis,g,rng){const branch=rng(),u=rng(),v=rng(),w=cosine(branch<g?axis:n,u,v),c=maxCos(n,w),gc=maxCos(axis,w);return{w,weight:c/Math.max((1-g)*c+g*gc,1e-8),selected:-1};}
function sample(n,axis,list,e,g,rng){
  if(!list.length||e<=0)return oldSample(n,axis,g,rng);
  const a=coefficients(list,e,g),branch=rng(),select=rng(),u=rng(),v=rng();let w,selected=-1;
  if(branch<a.e){selected=choose(list,select);w=lobeSample(list[selected].lobe,u,v);}
  else w=cosine(branch<a.e+a.g?axis:n,u,v);
  const c=maxCos(n,w),gc=maxCos(axis,w),p=(a.c*c+a.g*gc)/PI+a.e*density(list,w);
  return{w,weight:c>0?c/(PI*p):0,selected,p};
}
function capRadiance(n,axis,theta,brightness=50,background=.05){
  // Integral over an entire cap above the receiver horizon: integral(w dOmega)
  // equals pi*sin(theta)^2*axis. This target is independent of all proposal geometry.
  assert(dot(n,axis)>Math.sin(theta),'Analytic cap must lie above the receiver horizon.');
  const cutoff=Math.cos(theta);return{evaluate:w=>background+(dot(axis,w)>=cutoff?brightness:0),exact:background+brightness*Math.sin(theta)**2*dot(n,axis)};
}
let draws=0,zeroSamples=0,maxZ=0;
function integrate(name,n,guide,list,e,g,signal,seed,count=350000){
  const rng=random(seed);let sum=0,squares=0,zero=0;const floor=coefficients(list,e,g).c;
  for(let i=0;i<count;i++){
    const s=sample(n,guide,list,e,g,rng),value=signal.evaluate(s.w)*s.weight;
    assert(Number.isFinite(value)&&s.weight>=0&&s.weight<=1/floor+1e-8,'Finite bounded estimator requires cosine support.');
    if(maxCos(n,s.w)===0){zero++;assert.equal(s.weight,0);}
    sum+=value;squares+=value*value;
  }
  const mean=sum/count,variance=Math.max(0,squares/count-mean*mean),se=Math.sqrt(variance/count),error=Math.abs(mean-signal.exact);
  assert(error<=7*se+3e-4,`${name}: ${mean} versus ${signal.exact}, stderr ${se}`);
  draws+=count;zeroSamples+=zero;if(se>0)maxZ=Math.max(maxZ,error/se);
  console.log(`PASS ${name}: estimate=${mean.toFixed(6)} reference=${signal.exact.toFixed(6)} sampleVariance=${variance.toFixed(6)} zeroDraws=${zero}`);
  return{mean,variance,zero,count,sum};
}

const n=[0,0,1],origin=[0,0,0],axis=normalize([.25,.1,1]);
const empty=build([],origin),single=build([record(sphereAt(n,5,.05),0,1)],origin);
const duplicates=build([record(sphereAt(n,5,.05),0,.25),record(sphereAt(n,9,.05),.25,1)],origin);
assert.equal(density(single,n),density(duplicates,n),'Duplicate proposals are one normalized density, not extra light.');
const small=capRadiance(n,n,.025,80,.05);
const baseline=integrate('small bright emitter / cosine baseline',n,n,empty,0,0,small,17,500000);
const guided=integrate('small bright emitter / emissive proposal',n,n,single,.65,.3,small,19,500000);
assert(guided.variance<baseline.variance*.1,'The representative well-aligned emitter should improve sample variance at the same draw budget.');
integrate('duplicate lobes do not duplicate emission',n,n,duplicates,.65,.3,small,23);
const overlap=build([record(sphereAt(n,5,.4),0,.3),record(sphereAt(axis,6,.45),.3,.8),record(sphereAt(n,3,.25),.8,1)],origin);
integrate('partly overlapping lobes and tilted guide',n,normalize([1,0,.1]),overlap,.8,.8,capRadiance(n,axis,.17,8,.4),29);
integrate('constant environment / overlaps',n,axis,overlap,.8,.8,{evaluate:()=>1,exact:1},31);
const inside=build([record([.1,0,0,2],0,1)],origin);
assert.equal(inside[0].lobe.k,0);assert.equal(density(inside,[0,0,-1]),1/(4*PI));
integrate('inside proposal sphere',n,axis,inside,.8,.8,{evaluate:()=>1,exact:1},37);
const behind=build([record(sphereAt([0,0,-1],4,.3),0,1)],origin);
const back=integrate('back hemisphere retains zero contributions',n,n,behind,.8,0,{evaluate:()=>1,exact:1},41);
assert(back.zero/back.count>.79&&back.zero/back.count<.81);
assert(back.sum/(back.count-back.zero)>4.5,'Wrong accepted-only normalization must fail the constant-radiance oracle.');
const rn=normalize([.37,.72,-.4]),rb=frame(rn),ra=normalize(orient(rb,.2,.1,1));
const rotated=build([record(sphereAt(ra,4,.2),0,1)],origin);
integrate('rotated receiver and proposal',rn,normalize(orient(rb,1,0,-.2)),rotated,.7,.65,capRadiance(rn,ra,.1,10,.2),43);
integrate('proposal misses actual emitter geometry',n,n,single,.65,.3,capRadiance(n,axis,.08,8,.1),47);
integrate('occluded emissive proposal evaluates actual Li once',n,n,single,.65,.3,{evaluate:()=>.2,exact:.2},53);
integrate('fully black traced scene adds no proposal emission',n,n,single,.8,.8,{evaluate:()=>0,exact:0},57,10000);
const tiny=build([record([0,0,1e8,1e-4],0,1)],origin);
assert.equal(tiny[0].lobe.k,10000,'Very small angular bounds use a finite smooth distribution.');
integrate('maximum concentration / constant environment',n,n,tiny,.8,.8,{evaluate:()=>1,exact:1},59);

// Independent uniform-solid-angle quadrature checks broad proposal PDFs without
// using the sampler. Sharp axis-aligned lobes have a separate analytic CDF oracle.
for(const [name,normal,guide,list] of [['overlap',n,axis,overlap],['inside',n,axis,inside],['behind',n,n,behind],['rotated',rn,ra,rotated]]){
  let integral=0;const nz=4096,np=384,a=coefficients(list,.7,.5);
  for(let zIndex=0;zIndex<nz;zIndex++){
    const z=2*(zIndex+.5)/nz-1,r=Math.sqrt(1-z*z);
    for(let pIndex=0;pIndex<np;pIndex++){
      const phi=TAU*(pIndex+.5)/np,w=[r*Math.cos(phi),r*Math.sin(phi),z];
      integral+=((a.c*maxCos(normal,w)+a.g*maxCos(guide,w))/PI+a.e*density(list,w))*4*PI/(nz*np);
    }
  }
  assert(Math.abs(integral-1)<.008,`${name}: independent full-sphere density quadrature ${integral}`);
}
const shiftedOrigin=[3,-2,5],shiftedSphere=sphereAt(n,5,.05).map((v,i)=>i<3?v+shiftedOrigin[i]:v);
const shifted=build([record(shiftedSphere,0,1)],shiftedOrigin);
assert.deepEqual(shifted[0].lobe,single[0].lobe,'Proposal geometry must use the same origin as tracing.');

// An explicit selected-only density counterexample catches the common overlap bug.
{
  const rng=random(67),a=coefficients(duplicates,.8,0);let correct=0,wrong=0;const count=180000;
  for(let i=0;i<count;i++){
    const s=sample(n,n,duplicates,.8,0,rng),c=maxCos(n,s.w),li=small.evaluate(s.w);correct+=li*s.weight;
    const selected=s.selected>=0?s.selected:0;
    const badPdf=a.c*c/PI+a.e*duplicates[selected].pmf*lobePdf(duplicates[selected].lobe,s.w);
    wrong+=li*c/(PI*badPdf);
  }
  assert(Math.abs(correct/count-small.exact)<.002);assert(wrong/count>small.exact*1.2,'Selected-only lobe PDF must expose measurable bias.');
  draws+=count;
}

// Float32 prefix-CDF construction: PDF uses representable interval widths, so
// disappearing tiny weights cannot be selected or retain phantom probability mass.
function floatCdf(weights){
  const max=Math.max(...weights),scaled=weights.map(w=>F(w/max));let total=F(0);for(const w of scaled)total=F(total+w);
  let prefix=F(0),lo=F(0);const intervals=[];
  for(let i=0;i<scaled.length;i++){prefix=F(prefix+scaled[i]);const hi=i===scaled.length-1?1:F(prefix/total);if(hi>lo)intervals.push([lo,hi]);lo=hi;}
  return intervals;
}
const intervals=floatCdf([1e30,1e-30,1,1e25,1e-20,1e29]);
assert(intervals.length<6);assert.equal(intervals[0][0],0);assert.equal(intervals.at(-1)[1],1);
assert.equal(intervals.reduce((sum,[lo,hi])=>sum+(hi-lo),0),1);
const cdfList=build(intervals.map(([lo,hi])=>record(sphereAt(n,5,.2),lo,hi)),origin),counts=new Array(intervals.length).fill(0),cdfRandom=random(71);
for(let i=0;i<200000;i++)counts[choose(cdfList,cdfRandom())]++;
for(let i=0;i<counts.length;i++){const p=intervals[i][1]-intervals[i][0],se=Math.sqrt(p*(1-p)/200000);assert(Math.abs(counts[i]/200000-p)<7*se+1e-5);}
assert(Math.abs(density(cdfList,n)-lobePdf(cdfList[0].lobe,n))<1e-12,'CDF quantization must not alter the normalized duplicate-lobe density.');
const boundaryList=build([record(sphereAt(n,5,.2),0,0),record(sphereAt(n,5,.2),0,.5),record(sphereAt(n,5,.2),.5,.5),record(sphereAt(n,5,.2),.5,1)],origin);
assert.equal(choose(boundaryList,0),1);assert.equal(choose(boundaryList,.5),3);assert.equal(choose(boundaryList,1-2**-24),3);
assert.equal(density(boundaryList,n),lobePdf(boundaryList[1].lobe,n),'Zero CDF intervals have neither selected samples nor density.');

// Disabled and empty tables use the old sampler with exactly three random draws.
for(const list of [empty,single]){
  const a=random(83),b=random(83);
  for(let i=0;i<300;i++){const actual=sample(n,axis,list,0,.6,a),expected=oldSample(n,axis,.6,b);assert.deepEqual(actual,expected);assert.equal(a.state(),b.state());}
}

// Explicit fround after each scalar arithmetic operation models a non-FMA float32
// implementation, including frame construction, normalization, log/exp and trig.
// This is a CPU numerical model, not GPU instruction, compiler or driver evidence.
const add32=(a,b)=>a.map((v,i)=>F(v+b[i]));
const sub32=(a,b)=>a.map((v,i)=>F(v-b[i]));
const scale32=(a,s)=>a.map(v=>F(v*s));
const dot32=(a,b)=>F(F(F(a[0]*b[0])+F(a[1]*b[1]))+F(a[2]*b[2]));
const cross32=(a,b)=>[F(F(a[1]*b[2])-F(a[2]*b[1])),F(F(a[2]*b[0])-F(a[0]*b[2])),F(F(a[0]*b[1])-F(a[1]*b[0]))];
const normalize32=a=>scale32(a,F(1/Math.sqrt(dot32(a,a))));
function orient32(axis,r,z,v,normalizeResult=true){
  const t=normalize32(cross32(Math.abs(axis[2])<F(.999)?[0,0,1]:[0,1,0],axis)),b=cross32(axis,t),phi=F(F(TAU)*v);
  const w=add32(add32(scale32(t,F(r*F(Math.cos(phi)))),scale32(b,F(r*F(Math.sin(phi))))),scale32(axis,z));
  return normalizeResult?normalize32(w):w;
}
function logOnePlus32(x){
  if(x<=F(-.125))return F(Math.log(F(1+x)));
  let p=F(F(1/7)-F(x*F(.125)));
  for(const coefficient of [-1/6,.2,-.25,1/3,-.5,1])p=F(F(coefficient)+F(x*p));
  return F(x*p);
}
function sample32(c,u,v){
  u=F(u);v=F(v);let d;
  if(c.k>0){const tail=F(Math.exp(F(-2*c.k))),l=u<=F(.125)?logOnePlus32(F(u*F(tail-1))):F(Math.log(F(F(1-u)+F(u*tail))));d=F(l/c.k);}
  else d=F(-2*u);
  const z=F(1+d),r=F(Math.sqrt(Math.max(0,F(F(-d)*F(d+2)))));
  return orient32(c.axis,r,z,v);
}
function pdf32(c,w){
  if(c.k<=0)return F(1/F(4*F(PI)));
  const chord=sub32(w,c.axis),exponent=F(F(F(-.5)*c.k)*dot32(chord,chord));
  return F(F(c.k*F(Math.exp(exponent)))/F(F(TAU)*F(1-F(Math.exp(F(-2*c.k))))));
}
function lobe32(origin,sphere){
  origin=origin.map(F);sphere=sphere.map(F);const offset=sphere.slice(0,3).map((v,i)=>F(v-origin[i]));
  const d2=dot32(offset,offset),r2=F(sphere[3]*sphere[3]);
  if(!origin.every(Number.isFinite)||!sphere.every(Number.isFinite)||sphere[3]<=0||!offset.every(Number.isFinite)||!Number.isFinite(d2)||!Number.isFinite(r2)||d2<=r2||d2<=0)return{axis:[0,0,1],k:0};
  const a=offset.map(v=>F(v*F(1/Math.sqrt(d2))));if(!a.every(Number.isFinite))return{axis:[0,0,1],k:0};
  const s=Math.max(0,Math.min(1,F(r2/d2))),delta=F(s/F(1+F(Math.sqrt(Math.max(0,F(1-s))))));
  return{axis:a,k:F(1/Math.max(delta,F(1e-4)))};
}
const extremes=[
  {o:[3e38,0,0],s:[-3e38,0,0,1],sphere:true},
  {o:origin,s:[1e30,0,0,1],sphere:true},
  {o:origin,s:[1,2,3,1e20],sphere:true},
  {o:origin,s:[1e-30,0,0,1e-35],sphere:true},
  {o:origin,s:[0,0,0,1],sphere:true},
  {o:origin,s:[0,0,1e15,1e-10],sphere:false},
  {o:origin,s:[0,0,2,1],sphere:false},
  {o:origin,s:[0,0,1,1],sphere:true},
  {o:origin,s:[Infinity,0,0,1],sphere:true},
  {o:origin,s:[0,0,1,-1],sphere:true}
];
for(const c of extremes){
  const con=lobe32(c.o,c.s);assert(Number.isFinite(con.k)&&con.k>=0&&con.k<=10000);assert.equal(con.k===0,c.sphere);
  const rng=random(97);for(let i=0;i<500;i++){const w=sample32(con,rng(),rng());assert(w.every(Number.isFinite));assert(pdf32(con,w)>0,'Degenerate fallback cannot drop selected proposal mass.');}
}

// Reproduce the actual removed hard-cone defect; double-precision-only tests do
// not expose this. The replacement has no hard support gate at that direction.
const regressionAxis=normalize32([1,1,1]),regressionWidth=F(1-F(1-F(1e-4)));
function removedConeSample(u,v){const z=F(1-F(F(u)*regressionWidth)),r=F(Math.sqrt(F(F(1-z)*F(1+z))));return orient32(regressionAxis,r,z,F(v),false);}
const regressionDirection=removedConeSample(.9997050166,.3700000048);
assert(dot32(regressionAxis,regressionDirection)<F(1-regressionWidth));
assert(pdf32({axis:regressionAxis,k:10000},normalize32(regressionDirection))>0);
let removedFalseZero=0;
for(let i=0;i<100000;i++)if(dot32(regressionAxis,removedConeSample(F((i+.5)/100000),F(.37)))<F(1-regressionWidth))removedFalseZero++;
assert(removedFalseZero>0,'The regression fixture must reproduce the removed float32 support error.');

// Independently evaluate the exact vMF CDF/density at the float32-generated
// direction, using double-normalized axis/direction rather than copied shader math.
const axes=[[1,1,1],[.2,.5,.8],[.7,-.3,.1],[.001,0,1],[0,0,1],[1,0,0],[.4,.8,-.2]];
const concentrations=[0,1,1.01,2,8,10,100,1000,10000];
let float32Samples=0,maxCdfError=0,maxPdfRelativeError=0,maxDirectionLengthError=0,maxEndpointPdfRelativeError=0,maxInversePdfRelativeError=0;
const endpoints=[0,2**-24,2**-23,.00001,.12499999,.125,.12500001,.5,1-2**-20,1-2**-23,1-2**-24];
for(const rawAxis of axes)for(const concentration of concentrations){
  const c={axis:normalize32(rawAxis.map(F)),k:F(concentration)},exactAxis=normalize(c.axis),rng=random(173);
  for(let i=0;i<4096;i++){
    const u=F(i<endpoints.length?endpoints[i]:rng()),v=F(i<endpoints.length?.37:rng()),w=sample32(c,u,v),q=pdf32(c,w);
    assert(w.every(Number.isFinite)&&q>0&&Number.isFinite(q),'No selected float32 vMF sample may lose its own density.');
    const wn=normalize(w),cos=Math.max(-1,Math.min(1,dot(exactAxis,wn))),d=cos-1;
    const expectedU=c.k>0?-Math.expm1(c.k*d)/(-Math.expm1(-2*c.k)):(1-cos)/2;
    const exactPdf=c.k>0?c.k*Math.exp(c.k*d)/(TAU*(-Math.expm1(-2*c.k))):1/(4*PI);
    const inversePdf=c.k>0?c.k*((1-u)+u*Math.exp(-2*c.k))/(TAU*(-Math.expm1(-2*c.k))):1/(4*PI);
    const cdfError=Math.abs(u-expectedU),pdfError=Math.abs(q/exactPdf-1);
    const inversePdfError=Math.abs(q/inversePdf-1);maxInversePdfRelativeError=Math.max(maxInversePdfRelativeError,inversePdfError);
    maxCdfError=Math.max(maxCdfError,cdfError);maxPdfRelativeError=Math.max(maxPdfRelativeError,pdfError);
    if(i<endpoints.length)maxEndpointPdfRelativeError=Math.max(maxEndpointPdfRelativeError,pdfError);
    maxDirectionLengthError=Math.max(maxDirectionLengthError,Math.abs(Math.hypot(...w)-1));
    assert(cdfError<5e-5,`float32 vMF CDF error ${cdfError} at k=${c.k}, u=${u}`);
    assert(pdfError<5e-4,`float32 vMF relative PDF error ${pdfError} at k=${c.k}, u=${u}`);
    assert(inversePdfError<5e-4,`float32 vMF inverse-CDF relative PDF error ${inversePdfError} at k=${c.k}, u=${u}`);
    float32Samples++;
  }
}
// Sharp-lobe normalization by an exact independent change of variables: integrate
// in exponential-CDF bins, not a uniform angular grid that can miss the narrow peak.
for(const k of concentrations.filter(k=>k>0)){
  let mass=0;const count=20000,tail=-Math.expm1(-2*k);
  for(let i=0;i<count;i++){const u=(i+.5)/count,z=1+Math.log1p(-u*tail)/k,q=lobePdf({axis:n,k},[Math.sqrt(Math.max(0,1-z*z)),0,z]),jacobian=TAU*tail/(k*(1-u*tail));mass+=q*jacobian/count;}
  assert(Math.abs(mass-1)<1e-10,`vMF normalized density at k=${k}: ${mass}`);
}
console.log(`PASS: ${draws} deterministic transport draws; ${zeroSamples} below-hemisphere zero draws retained; ${intervals.length} representable CDF intervals; ${extremes.length} float32 edge cases. Maximum integration error ${maxZ.toFixed(2)} standard errors.`);
console.log(`PASS: ${float32Samples} full float32 vMF sample/PDF checks, k=0 or [1,10000], 7 axes and endpoint draws; own-PDF zero failures=0; maximum absolute CDF error=${maxCdfError.toExponential(6)}, relative PDF error at generated direction=${maxPdfRelativeError.toExponential(6)}, inverse-CDF relative PDF error=${maxInversePdfRelativeError.toExponential(6)}, endpoint relative PDF error=${maxEndpointPdfRelativeError.toExponential(6)}, unit-length error=${maxDirectionLengthError.toExponential(6)}. Removed hard-cone regression reproduced ${removedFalseZero}/100000 false zero PDFs.`);
console.log(`Same-budget aligned-emitter sample-variance ratio: ${(baseline.variance/guided.variance).toFixed(1)}x lower in this CPU fixture. This is not a general scene-speedup or GPU timing claim. Independent integral/float32 references plus HLSL source contracts only.`);
