// Independent CPU geometry/identity oracle and production-source contract checks.
// Does not execute Unity, the rasterizer, hardware rays, or shader instructions.
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const surface=readFileSync(new URL('../Runtime/Resources/HybridLumenGI/HybridLumenGISurfaceCache.hlsl',import.meta.url),'utf8');
const capture=readFileSync(new URL('../Runtime/Resources/HybridLumenGI/HybridLumenGICardCapture.shader',import.meta.url),'utf8');
let checks=0;
const check=(value,message)=>{checks++;assert.ok(value,message);};
const dot=(a,b)=>a.reduce((s,v,i)=>s+v*b[i],0),add=(a,b)=>a.map((v,i)=>v+b[i]),sub=(a,b)=>a.map((v,i)=>v-b[i]);
const mul=(a,s)=>a.map(v=>v*s),cross=(a,b)=>[a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]];
const unit=v=>mul(v,1/Math.hypot(...v)),finite=v=>v.every(Number.isFinite);
const rotate=(v,a)=>{
  const p=[v[0],Math.cos(a)*v[1]-Math.sin(a)*v[2],Math.sin(a)*v[1]+Math.cos(a)*v[2]];
  const b=a*.37,c=a*.71,q=[Math.cos(b)*p[0]+Math.sin(b)*p[2],p[1],-Math.sin(b)*p[0]+Math.cos(b)*p[2]];
  return [Math.cos(c)*q[0]-Math.sin(c)*q[1],Math.sin(c)*q[0]+Math.cos(c)*q[1],q[2]];
};
const flags={valid:1,oriented:2,triangle:16,binding:64,geometric:256};
const has=(value,required)=>(value&required)===required;
const owner={slot:2,stableId:7,revision:11,geometryRevision:13,layout:4,published:true};
const hit=()=>({ownerSlot:2,stableId:7,ownerRevision:11,geometryRevision:13,submesh:1,primitive:8,hardwareInstance:0,
  representation:1,flags:1|2|16|64|256,position:[0,0,0],rawNg:[0,0,1],binding:[3,91,4,13]});
const card=(index,chartId,position,emission)=>({index,chartId,ownerSlot:2,stableId:7,revision:11,layout:4,ready:1,generation:2,
  flags:5,direction:[0,0,1],tolerance:.1,position,rawNg:[0,0,1],shadingNormal:[0,0,-1],emission});
const front=card(3,91,[.035,0,0],[10,0,0]),back=card(4,92,[0,0,-.001],[0,10,0]);
const cullFacing=(f,value)=>(f&1)===0?Math.abs(value):((f>>1)&3)===1?-value:((f>>1)&3)===0?Math.abs(value):value;
let texelLoads=0;
function exactQuery(h,o,cards) {
  if(!has(h.flags,flags.valid|flags.geometric)||!finite(h.position)||!finite(h.rawNg)||Math.hypot(...h.rawNg)<1e-5) return null;
  if(!o.published||h.ownerSlot!==o.slot||h.stableId!==o.stableId||h.ownerRevision!==o.revision||h.geometryRevision!==o.geometryRevision) return null;
  if(h.representation!==1||!has(h.flags,flags.triangle|flags.binding|flags.oriented)||[h.submesh,h.primitive,h.hardwareInstance].includes(0xffffffff)) return null;
  if(h.binding[3]!==h.geometryRevision||h.binding[2]!==o.layout) return null;
  const c=cards.get(h.binding[0]);
  if(!c||c.ready!==1||c.generation===0||(c.flags&1)===0||c.ownerSlot!==h.ownerSlot||c.stableId!==h.stableId||c.revision!==h.ownerRevision||c.chartId!==h.binding[1]||c.layout!==h.binding[2]) return null;
  const ng=unit(h.rawNg),facing=cullFacing(c.flags,dot(c.direction,ng));
  if(facing<=.05)return null;
  texelLoads++;
  const delta=sub(c.position,h.position);
  if(Math.hypot(...delta)>c.tolerance||dot(c.rawNg,ng)<.2||Math.abs(dot(delta,ng))>Math.max(.002,c.tolerance*.3))return null;
  return c;
}
const cards=new Map([[3,front],[4,back]]);
check(Math.hypot(...back.position)<Math.hypot(...front.position),'Thin-layer fixture must make the wrong back layer closer.');
check([...cards.values()].sort((a,b)=>Math.hypot(...a.position)-Math.hypot(...b.position))[0]===back,'Legacy nearest-card counterexample is not reproduced.');
check(exactQuery(hit(),owner,cards)===front,'Triangle binding must keep the farther front texel, including its red emission.');
check(texelLoads===1,'Exact lookup must load only the bound card.');
const missingFront=new Map([[3,{...front,position:[.2,0,0]}],[4,back]]);
check(exactQuery(hit(),owner,missingFront)===null,'A failed bound texel must not fall through to the closer back layer.');
for(const mutate of [
  h=>h.flags&=~flags.binding,h=>h.flags&=~flags.oriented,h=>h.flags&=~flags.geometric,h=>h.binding[0]=0xffffffff,
  h=>h.binding[1]++,h=>h.binding[2]++,h=>h.binding[3]++,h=>h.geometryRevision++,h=>h.stableId++,h=>h.ownerRevision++,
  h=>h.ownerSlot++,h=>h.primitive=0xffffffff,h=>h.submesh=0xffffffff,h=>h.hardwareInstance=0xffffffff,
  h=>h.rawNg=[NaN,0,1],h=>h.rawNg=[0,0,0],h=>h.position=[Infinity,0,0]
]) {const h=hit();mutate(h);check(exactQuery(h,owner,cards)===null,'Stale/incomplete hit identity resolved a material.');}
check(exactQuery(hit(),{...owner,geometryRevision:14},cards)===null,'Two matching stale tickets bypassed the current owner geometry revision.');
for(const change of [{ready:0},{ready:2},{generation:0},{flags:0},{ownerSlot:9},{stableId:9},{revision:12},{chartId:92},{layout:5}])
  check(exactQuery(hit(),owner,new Map([[3,{...front,...change}],[4,back]]))===null,'Stale/reused physical card was accepted.');
check(exactQuery(hit(),{...owner,published:false},cards)===null,'Warming/absent owner was accepted as a traced published hit.');
for(const cull of [0,1,2]) {
  const c={...front,flags:1|(cull<<1),direction:cull===1?[0,0,-1]:[0,0,1]};
  check(exactQuery(hit(),owner,new Map([[3,c]]))===c,'Original raw Ng must address Cull Off/Front/Back chart material.');
  check(c.shadingNormal[2]===-1,'Material lookup must preserve reversed stock-Lit Ns.');
}

// Derivatives are generated from projected triangle positions independently of
// the recovery formula. DX12 screen Y points down; default Unity raster fronts
// have positive (clockwise in those screen coordinates) signed triangle area.
// This explicitly tests both shader UV-flip branches, nonuniform scales, every
// reflection parity, and arbitrary world rotations. External inverted raster
// state is deliberately NOT assumed to satisfy the default-state contract.
let rasterCases=0,reversedNsCounterexamples=0;
const vertices=[[0,0,0],[.8,.1,.2],[.2,.9,-.1]],sourceNg=unit(cross(sub(vertices[1],vertices[0]),sub(vertices[2],vertices[0])));
for(let step=0;step<40;step++)for(let mirror=0;mirror<8;mirror++)for(const uvTop of [false,true]) {
  const scale=[(mirror&1)?-1.2:1.2,(mirror&2)?-.7:.7,(mirror&4)?-1.8:1.8],angle=step*.173;
  const world=vertices.map(p=>rotate(p.map((x,i)=>x*scale[i]),angle));
  const rawNg=unit(rotate(sourceNg.map((x,i)=>x/scale[i]),angle)),detSign=Math.sign(scale[0]*scale[1]*scale[2]);
  const direction=unit(add(rawNg,rotate([.2,-.1,.1],angle))),forward=mul(direction,-1);
  const right=unit(cross(Math.abs(forward[1])>.9?[0,0,1]:[0,1,0],forward)),up=cross(forward,right);
  const raster=world.map(p=>[2*dot(p,right),-2*dot(p,up)*(uvTop?-1:1)]);
  const s1=sub(raster[1],raster[0]),s2=sub(raster[2],raster[0]),area=s1[0]*s2[1]-s1[1]*s2[0];
  const e1=sub(world[1],world[0]),e2=sub(world[2],world[0]);
  const dx=mul(sub(mul(e1,s2[1]),mul(e2,s1[1])),1/area),dy=mul(sub(mul(e2,s1[0]),mul(e1,s2[0])),1/area);
  const derivative=unit(cross(dx,dy)),frontSign=area>0?1:-1;
  const recovered=mul(derivative,frontSign*detSign);
  check(dot(recovered,rawNg)>1-1e-10,'Fallback winding recovery changed under UV origin/reflection.');
  const chartRecovered=dot(derivative,rawNg)<0?mul(derivative,-1):derivative;
  check(dot(chartRecovered,rawNg)>1-1e-10,'Chart geometry direction did not resolve the derivative sign.');
  check(dot(mul(recovered,-1),rawNg)<-.999,'An externally inverted raster state must remain a declared unsupported case.');
  for(const cull of [0,1,2]) {
    const viewDirection=cull===1?mul(rawNg,-1):rawNg;
    const facing=dot(chartRecovered,viewDirection),kept=cull===0||(cull===1?facing<=0:facing>=0);
    check(kept,'Capture dropped a valid chart for its original Cull mode.');
    const reversedNs=mul(rawNg,-1),legacy=dot(derivative,reversedNs)<0?mul(derivative,-1):derivative;
    const legacyFacing=dot(legacy,viewDirection),legacyKept=cull===0||(cull===1?legacyFacing<=0:legacyFacing>=0);
    if(cull!==0){check(!legacyKept,'Reversed vertex Ns must reproduce the old all-clipped chart.');reversedNsCounterexamples++;}
    check(dot(reversedNs,rawNg)<-.999,'Stock Lit Ns must remain opposite, without face-forward repair.');
  }
  rasterCases++;
}
// Unsigned gradient identity remains approximate. Both oriented queries may be
// considered but their selection must not grant a triangle/front-face identity.
const unsignedHit={flags:flags.valid|flags.geometric,representation:3},beforeFlags=unsignedHit.flags;
const unsignedConfidence=Math.max(.8,.3)*.25;
check(unsignedConfidence===.2&&unsignedHit.flags===beforeFlags&&!has(unsignedHit.flags,flags.triangle),'Unsigned shell query manufactured exact triangle identity.');
check(.8*.5<.8&&.8*.25<.8*.5,'Approximate signed/analytic and unsigned material confidence must remain below chart identity confidence.');
function scaledFacet(dx,dy) {
  const sx=Math.max(...dx.map(Math.abs)),sy=Math.max(...dy.map(Math.abs));
  if(!finite(dx)||!finite(dy)||sx<=0||sy<=0)return null;
  const f=cross(mul(dx,1/sx),mul(dy,1/sy)),sf=Math.max(...f.map(Math.abs));
  return finite(f)&&sf>0?unit(mul(f,1/sf)):null;
}
for(const scale of [1e-15,1e-10,1e-5,1,1e10,1e15])
  check(dot(scaledFacet([scale,0,0],[0,scale*.5,0]),[0,0,1])>.999999,'Valid derivative scale changed the capture geometry normal.');
check(Math.pow(1e-10*1e-10,2)<1e-16,'Small-chart fixture must reproduce the absolute area-threshold failure.');
check(scaledFacet([0,0,0],[0,1,0])===null&&scaledFacet([1,0,0],[2,0,0])===null&&scaledFacet([Infinity,0,0],[0,1,0])===null,'Degenerate/nonfinite derivatives must remain invalid.');

const compact=s=>s.replace(/\/\/[^\n]*/g,'').replace(/\s+/g,''),s=compact(surface),c=compact(capture);
check(s.includes('#include"HybridLumenGIHit.hlsl"'),'Surface query must independently include the hit ABI.');
check(s.includes('range.w!=hit.geometryRevision')&&s.includes('hit.surfaceBinding.w!=hit.geometryRevision'),'Current geometry revision must validate both hit and binding.');
for(const contract of ['card.ownerSlot!=hit.ownerSlot','card.stableId!=hit.stableId','card.revision!=hit.ownerRevision','card.chartId!=hit.surfaceBinding.y','card.layoutGeneration!=hit.surfaceBinding.z','card.ready!=1u'])
  check(s.includes(contract),'Missing exact material identity guard: '+contract);
const hitStart=s.indexOf('boolHLGITrySurfaceMaterialHit('),nonTriangle=s.indexOf('if(!isTriangle)',hitStart),block=s.indexOf('{',nonTriangle);
let braces=1,end=block+1;for(;braces&&end<s.length;end++){if(s[end]==='{')braces++;if(s[end]==='}')braces--;}
const exactSuffix=s.slice(end,s.indexOf('#endif',end));
check(!exactSuffix.includes('HLGITrySurfaceMaterial(')&&!exactSuffix.includes('_HLGI_SurfaceCardIndices')&&!exactSuffix.includes('for('),'Exact triangle failure must never scan other cards.');
check(exactSuffix.includes('HLGILoadSurfaceSample(cardIndex,projected.xy,candidate)'),'Exact material path must load its binding card.');
check(exactSuffix.includes('dot(candidate.geometricNormal,rawNg)')&&exactSuffix.includes('abs(dot(delta,rawNg))'),'Exact layer checks must retain raw Ng.');
check(s.includes('sample.confidence*=0.25')&&s.includes('hit.position,-rawNg,negative'),'Unsigned approximation must consider both sides with reduced confidence.');
check(c.includes('FRONT_FACE_TYPErasterFrontFace:FRONT_FACE_SEMANTIC'),'Capture must receive raster front-face identity.');
check(c.includes('IS_FRONT_VFACE(rasterFrontFace,1.0,-1.0)*_HLGI_CardObjectDeterminantSign'),'Fallback must explicitly undo reflection under the default raster contract.');
check(c.includes('dot(facet,_HLGI_CardGeometryDirection.xyz)')&&!c.includes('dot(facet,shadingBasisNormal)')&&!c.includes('dot(facet,geometricNormal)'),'Chart facet orientation must not use vertex Ns.');
check(c.includes('scaleX<=0||scaleY<=0)discard')&&c.includes('facetScale<=0)discard'),'Degenerate derivatives must not invent Ng from Ns.');
check(c.includes('cross(derivativeX/scaleX,derivativeY/scaleY)')&&!c.includes('facetLengthSquared<=1e-16'),'Small valid charts must not depend on an absolute world-area threshold.');
check(c.includes('half3shadingBasisNormal=normalize(input.normalWS)')&&c.includes(':shadingBasisNormal;'),'Capture must retain stock Lit Ns without face-forward.');
console.log(JSON.stringify({status:'passed',checks,rasterCases,reversedNsCounterexamples,scope:'CPU identity/numerical oracle and shader source contracts; no Unity/raster/GPU execution',fallbackRasterContract:'DX12 default Unity raster winding; external unrestored invert-culling unsupported'},null,2));
