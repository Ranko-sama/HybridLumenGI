// Independent numerical reference for global distance lower bounds. Does not execute HLSL.
import assert from 'node:assert/strict';
let seed=0x165a07e1, cases=0;
const random=()=>{seed^=seed<<13;seed^=seed>>>17;seed^=seed<<5;return(seed>>>0)/4294967296;};
const range=(a,b)=>a+(b-a)*random();
const add=(a,b)=>a.map((v,i)=>v+b[i]),sub=(a,b)=>a.map((v,i)=>v-b[i]);
const length=a=>Math.hypot(...a),maxAbs=a=>Math.max(...a.map(Math.abs));
const f=Math.fround;
const fsub=(a,b)=>a.map((v,i)=>f(f(v)-f(b[i])));
const flength=a=>f(Math.sqrt(f(f(f(a[0]*a[0])+f(a[1]*a[1]))+f(a[2]*a[2]))));
const sphereDistance=(p,c,r)=>Math.abs(length(sub(p,c))-r);
const boxSigned=(p,c,e)=>{const q=sub(p,c).map((v,i)=>Math.abs(v)-e[i]);return length(q.map(v=>Math.max(v,0)))+Math.min(Math.max(...q),0);};
const boxDistance=(p,c,e)=>Math.abs(boxSigned(p,c,e));
const boxLower=(p,lo,hi)=>length(p.map((v,i)=>Math.max(lo[i]-v,v-hi[i],0)));
function floatPrimitive(p,c,e,sphere){
  const relative=fsub(p,c);
  if(sphere)return f(Math.abs(f(flength(relative)-f(e[0]))));
  const q=relative.map((v,i)=>f(Math.abs(v)-f(e[i])));
  return f(Math.abs(f(flength(q.map(v=>Math.max(v,0)))+Math.min(Math.max(...q),0))));
}
function centerStored(p,c,e,sphere,cap,voxel){
  const lo=c.map((v,i)=>v-e[i]),hi=c.map((v,i)=>v+e[i]);
  const geometryMargin=Math.max(1e-5,Math.max(maxAbs(lo),maxAbs(hi))*2e-6);
  const positionMargin=Math.max(1e-5,voxel*1e-4,maxAbs(p)*2e-6);
  return Math.max(0,Math.min(cap,Math.max(0,floatPrimitive(p,c,e,sphere)-geometryMargin))-positionMargin);
}
function requireLower(bound,truth,label){cases++;assert.ok(Number.isFinite(bound)&&bound>=0&&bound<=truth+1e-8*Math.max(1,truth),`${label}: ${bound} > ${truth}`);}

// Single-precision center values, capped storage and nearest-center Lipschitz extrapolation.
for(let i=0;i<100000;i++){
  const scale=10**range(-2,6),c=[range(-2,2)*scale,range(-2,2)*scale,range(-2,2)*scale].map(f);
  const sphere=(i&1)===0,e=(sphere?Array(3).fill(range(.1,2)*scale):Array.from({length:3},()=>range(.1,2)*scale)).map(f);
  const n=Array.from({length:3},()=>range(-1,1));const norm=length(n);const dir=n.map(v=>v/norm);
  const p=(sphere?add(c,dir.map(v=>v*e[0])):add(c,e.map((v,j)=>j===i%3?v:(2*random()-1)*v))).map(f);
  const voxel=10**range(-2,1),center=add(p,Array.from({length:3},()=>range(-voxel,voxel))).map(f);
  const query=add(center,Array.from({length:3},()=>range(-voxel/2,voxel/2))).map(f);
  const stored=centerStored(center,c,e,sphere,voxel*8,voxel);
  const queryMargin=Math.max(1e-5,voxel*1e-4,maxAbs(query)*2e-6);
  const lower=Math.max(0,stored-length(sub(query,center))-queryMargin);
  requireLower(lower,sphere?sphereDistance(query,c,e[0]):boxDistance(query,c,e),'float center extrapolation');
}

// Large center/radius cancellation near origin needs geometry-scale roundoff, not just query-scale.
const largeCenter=[f(1e6),f(1e6),0],largeRadius=f(Math.SQRT2*1e6),origin=[0,0,0];
requireLower(centerStored(origin,largeCenter,[largeRadius,largeRadius,largeRadius],true,4,.5),sphereDistance(origin,largeCenter,largeRadius),'large primitive near origin');

// Baked trilinear mesh field, including non-uniform and reflected object transforms.
const resolution=32,extent=[.6,.7,.8],lo=[-2,-2,-2],voxel=4/resolution,error=Math.sqrt(3)*voxel;
const samples=new Float32Array(resolution**3);
for(let z=0;z<resolution;z++)for(let y=0;y<resolution;y++)for(let x=0;x<resolution;x++)samples[x+resolution*(y+resolution*z)]=boxSigned([lo[0]+(x+.5)*voxel,lo[1]+(y+.5)*voxel,lo[2]+(z+.5)*voxel],[0,0,0],extent);
function sampledField(p){
  const grid=p.map(v=>Math.max(0,Math.min(resolution-1,(v+2)/voxel-.5))),a=grid.map(Math.floor),b=a.map(v=>Math.min(v+1,resolution-1)),t=grid.map((v,i)=>v-a[i]);
  let result=0;
  for(let z=0;z<2;z++)for(let y=0;y<2;y++)for(let x=0;x<2;x++)result+=samples[(x?b[0]:a[0])+resolution*((y?b[1]:a[1])+resolution*(z?b[2]:a[2]))]*(x?t[0]:1-t[0])*(y?t[1]:1-t[1])*(z?t[2]:1-t[2]);
  return result;
}
for(let i=0;i<50000;i++){
  const p=Array.from({length:3},()=>range(-3,3)),scale=Array.from({length:3},()=>range(.05,10)*(random()<.5?-1:1));
  const minScale=1/Math.hypot(...scale.map(v=>1/v));
  const outside=boxLower(p,lo,[2,2,2]);
  const lower=(outside>0?outside:Math.max(0,Math.abs(sampledField(p))-2*error))*minScale;
  requireLower(lower,boxDistance(p.map((v,j)=>v*scale[j]),[0,0,0],extent.map((v,j)=>v*Math.abs(scale[j]))),'transformed mesh SDF bound');
}

// A triangle vertex can be outside its max-extent sphere proxy. Renderer AABB clamp prevents skipping it.
const vertex=[1,1,0],center=[.5,.5,.5],radius=.5;
assert.ok(sphereDistance(vertex,center,radius)>.3);
requireLower(Math.min(sphereDistance(vertex,center,radius),boxLower(vertex,[0,0,0],[1,1,1])),0,'triangle safety clamp');
for(let i=0;i<20000;i++){
  // Triangle in the XY plane with vertices (0,0), (1,0), (0,1).
  const p=[range(-2,2),range(-2,2),range(-2,2)],q=[p[0],p[1],0];
  const segmentDistance=(a,b)=>{const ab=sub(b,a),ap=sub(p,a),t=Math.max(0,Math.min(1,ap.reduce((sum,v,j)=>sum+v*ab[j],0)/ab.reduce((sum,v)=>sum+v*v,0)));return length(sub(p,add(a,ab.map(v=>v*t))));};
  const truth=q[0]>=0&&q[1]>=0&&q[0]+q[1]<=1?Math.abs(p[2]):Math.min(segmentDistance([0,0,0],[1,0,0]),segmentDistance([1,0,0],[0,1,0]),segmentDistance([0,1,0],[0,0,0]));
  requireLower(boxLower(p,[0,0,0],[1,1,0]),truth,'renderer AABB to real triangle');
}

// A capped center value can only become unsafe when the new object is within cap of that center.
let affected=0;
for(let i=0;i<100000;i++){
  const brickSize=range(.1,16),cap=brickSize*range(.5,4),key=Array.from({length:3},()=>Math.floor(range(-20,20)));
  const minimum=key.map(v=>v*brickSize),maximum=minimum.map(v=>v+brickSize),sample=minimum.map(v=>v+random()*brickSize);
  const objectCenter=sample.map(v=>v+range(-2,2)*cap),half=Array.from({length:3},()=>range(0,.5)*cap);
  if(boxDistance(sample,objectCenter,half)>=cap)continue;
  affected++;
  const dirtyLo=objectCenter.map((v,j)=>v-half[j]-cap),dirtyHi=objectCenter.map((v,j)=>v+half[j]+cap);
  assert.ok(maximum.every((v,j)=>v>=dirtyLo[j])&&minimum.every((v,j)=>v<=dirtyHi[j]),'Potentially unsafe cached sample escaped expanded dirty domain');
}
assert.ok(affected>1000);

// Query validity reference: a page's world key, ready flag and published-generation payload all matter.
const valid=(page,key,payload)=>page.ready&&page.generation!==0&&page.key.every((v,i)=>v===key[i])&&payload===page.generation;
const page={key:[-1,2,0],generation:5,ready:true};
assert.equal(valid(page,[-1,2,0],5),true);
assert.equal(valid(page,[3,2,0],5),false); // same torus slot for axis=4, different world key
assert.equal(valid(page,[-1,2,0],4),false); // discarded update / old voxel payload
assert.equal(valid({...page,ready:false},page.key,5),false);
assert.equal(valid({...page,generation:0},page.key,0),false);
console.log(`Global SDF bounds: ${cases} numerical lower-bound cases + ${affected} affected dirty-domain checks + 5 validity checks passed. Independent CPU reference; not GPU execution.`);
