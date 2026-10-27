import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';

// Float32 CPU reference and source contract, NOT GPU execution. The top-K oracle
// sorts the complete eligible set independently of the bounded insertion build.
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const source=fs.readFileSync(path.join(root,'Runtime/Resources/HybridLumenGI/HybridLumenGIEmissiveProposals.compute'),'utf8');
assert(source.includes('HLGISurfaceCardValid(card)'));
assert(source.includes('_HLGI_Proxies[owner].identity.w!=1'));
assert(source.indexOf('HLGISurfaceCardValid(card)')<source.indexOf('_HLGI_Proxies[owner]'));
assert(source.includes('clear<33')&&source.includes('clamp(_HLGI_EmitterBudget,0,32)'));
assert(source.includes('scores[sumIndex]/scores[0]'));
assert(source.includes('float4(lower,upper,0,0)'));
assert(source.includes('i==count-1?1:saturate(prefix/total)'));
assert(source.includes('if(upper>lower)'));
assert(source.indexOf('header.data.x=(float)written')>source.indexOf('_HLGI_EmissiveProposals[++written]=proposal'));
const f=Math.fround;
let state=0x24fe1783;
const random=()=>{state=(Math.imul(1664525,state)+1013904223)>>>0;return state/4294967296;};
const eligible=c=>c.valid&&c.phase===1&&c.sphere.every(Number.isFinite)&&c.sphere[3]>0&&Number.isFinite(c.score)&&c.score>0;
function bounded(cards,budget){
  budget=Math.min(32,Math.max(0,budget|0));const chosen=[];
  if(budget===0)return chosen;
  for(const card of cards){
    if(!eligible(card))continue;
    if(chosen.length===budget&&card.score<=chosen[budget-1].score)continue;
    let i=0;while(i<chosen.length){if(card.score>chosen[i].score)break;i++;}
    if(i>=budget)continue;
    chosen.splice(i,0,card);chosen.length=Math.min(chosen.length,budget);
  }return chosen;
}
function intervals(chosen){
  if(!chosen.length)return [];
  const scaled=chosen.map(c=>f(c.score/chosen[0].score));
  let total=0;for(const value of scaled)total=f(total+value);
  assert(total>=1&&total<=32&&Number.isFinite(total));
  let prefix=0,lower=0;const table=[];
  for(let i=0;i<chosen.length;i++){
    prefix=f(prefix+scaled[i]);
    const upper=Math.max(lower,i===chosen.length-1?1:Math.max(0,Math.min(1,f(prefix/total))));
    if(upper>lower)table.push({...chosen[i],lower,upper,pmf:upper-lower});
    lower=upper;
  }return table;
}
function validateTable(table){
  assert(table.length<=32);
  if(!table.length)return;
  let previous=0,total=0;
  for(const item of table){
    assert.equal(item.lower,previous);assert(item.upper>item.lower&&item.upper<=1);
    assert.equal(item.pmf,item.upper-item.lower);total+=item.pmf;previous=item.upper;
  }
  assert.equal(previous,1);assert.equal(total,1);
  for(const u of [0,...table.map(c=>c.lower),1-2**-24]){
    const matches=table.filter(c=>u>=c.lower&&u<c.upper);
    assert.equal(matches.length,1,'Every representable CDF boundary belongs to exactly one interval.');
  }
}
function card(id,score,phase=1){return{id,score:f(score),phase,valid:true,sphere:[id*.125,1,-2,.5]};}
let cases=0,checkedCards=0,zeroIntervals=0;
const fixtures=[
  [],[card(0,1)],[card(0,1,2)],
  Array.from({length:100},(_,i)=>card(i,1)),
  [card(0,3.4028234e38),card(1,1.7014117e38),card(2,1e-30)],
  [card(0,1e-40),card(1,2e-40),card(2,3e-40)],
  [card(0,NaN),card(1,Infinity),card(2,-1),card(3,0),card(4,1)],
  [{...card(0,10),sphere:[NaN,0,0,1]},{...card(1,10),sphere:[0,0,0,Infinity]},
   {...card(2,10),sphere:[0,0,0,0]},{...card(3,10),valid:false},card(4,1)]
];
for(let run=0;run<1000;run++){
  const n=Math.floor(random()*385),cards=[];
  for(let i=0;i<n;i++){
    const c=card(i,10**(random()*75-37));
    const mode=Math.floor(random()*20);
    if(mode===0)c.valid=false;else if(mode===1)c.phase=2;else if(mode===2)c.phase=0;
    else if(mode===3)c.score=0;else if(mode===4)c.sphere[3]=-1;
    cards.push(c);
  }fixtures.push(cards);
}
for(const cards of fixtures){
  for(const budget of [-1,0,1,4,16,32,40]){
    const expected=cards.filter(eligible).sort((a,b)=>b.score-a.score||a.id-b.id).slice(0,Math.min(32,Math.max(0,budget)));
    const chosen=bounded(cards,budget);
    assert.deepEqual(chosen.map(c=>c.id),expected.map(c=>c.id));
    const table=intervals(chosen);validateTable(table);
    zeroIntervals+=chosen.length-table.length;checkedCards+=cards.length;cases++;
  }
}
// Distribution selection frequencies use stored interval widths, including
// intentionally unequal powers, rather than a separately normalized weight.
const table=intervals(bounded([card(0,1),card(1,2),card(2,9),card(3,25),card(4,.01)],32));
const observed=new Array(table.length).fill(0),draws=300000;
for(let i=0;i<draws;i++){
  const u=random(),index=table.findIndex(c=>u>=c.lower&&u<c.upper);
  assert(index>=0);observed[index]++;
}
for(let i=0;i<table.length;i++){
  const mean=draws*table[i].pmf,sigma=Math.sqrt(draws*table[i].pmf*(1-table[i].pmf));
  assert(Math.abs(observed[i]-mean)<6*sigma+10);
}
// Cold/retired/zero-budget tables contain no surviving prior proposals. A
// warming HLOD is excluded even when brighter than the published counterpart.
const old=[card(0,1),card(1,100,2)];
assert.deepEqual(bounded(old,32).map(c=>c.id),[0]);
old[0].phase=0;old[1].phase=1;
assert.deepEqual(bounded(old,32).map(c=>c.id),[1]);
assert.equal(intervals(bounded(old,0)).length,0);
for(const c of old)c.valid=false;
assert.equal(intervals(bounded(old,32)).length,0);
console.log(`Emissive proposal reference: ${cases} top-K/CDF cases over ${checkedCards} cards; ${zeroIntervals} rounded-zero intervals rejected; ${draws} categorical draws and HLOD/empty transitions passed. CPU/source checks only, no GPU execution.`);
