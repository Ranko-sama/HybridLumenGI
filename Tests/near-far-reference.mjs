import assert from 'node:assert/strict';
import fs from 'node:fs';
const source=fs.readFileSync(new URL('../Runtime/Resources/HybridLumenGI/HybridLumenGITransport.hlsl',import.meta.url),'utf8');
assert(source.includes('detailLimit-0.001') && source.includes('emptyDistance-guard'), 'Detailed ray TMin needs overlap at both transitions');
const tmin=1e-4;
function detail(planes,origin,limit){return planes.find(t=>t-origin>tmin && t-origin<limit)??null;}
function split(planes,limit,near,query){
  if(near>=limit)return detail(planes,0,limit);
  const hit=detail(planes,0,near);if(hit!==null)return hit;
  let advance=Math.max(0,near-.001);
  for(let i=0;i<8 && advance<limit;i++){
    const d=query(advance,planes);
    if(d===null||d<=0)break;
    if(d>=limit-advance)return null;
    const next=advance+Math.max(0,d-Math.max(.001,Math.abs(advance)*2e-6));
    if(next<=advance)break;advance=next;
  }
  return detail(planes,advance,limit-advance);
}
let seed=91342;
function random(){seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed/4294967296;}
const exact=(p,planes)=>Math.min(1000,...planes.map(t=>Math.abs(t-p)));
let cases=0;
for(let i=0;i<100000;i++){
  const near=1+random()*50,limit=near+1+random()*100;
  const planes=Array.from({length:i%7},()=>random()*limit*1.5).sort((a,b)=>a-b);
  if(i%8===0)planes.push(near);
  if(i%8===1)planes.push(near+tmin/10);
  planes.sort((a,b)=>a-b);
  const expected=detail(planes,0,limit);
  for(const query of [()=>null,()=>0,exact,(p,s)=>exact(p,s)*.3]) {
    assert.equal(split(planes,limit,near,query),expected);cases++;
  }
}
// Without a guard a valid distance bound can land precisely on the wall; TMin then rejects it.
assert.equal(detail([10],10,90),null);
assert.equal(split([10],100,5,exact),10);
console.log(`PASS: ${cases} near/far interval cases, exact-bound and unknown/zero-page fallbacks, boundary and TMin regressions. CPU reference plus live source guard contract; not GPU execution.`);
