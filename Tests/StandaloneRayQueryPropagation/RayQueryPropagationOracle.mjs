import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
const [mode,dir]=process.argv.slice(2);
assert(['prepare','verify'].includes(mode)&&dir);
const f=Math.fround,zero=()=>[0,0,0,0],uintRows=new Set([0,2,3,12,13,14]);
const keys=['originMax','directionLimit','footprint','view','policy','control','hitT','global0','global1','metadata'];
const uintInputs=new Set(['policy','control','metadata']);
const cases=[];
function make(name,edits={}) {
 const v={name,originMax:[1,2,3,20],directionLimit:[0,0,1,4],footprint:[1,.125,0,0],view:[13,17,19,1],policy:[0,1,0x80000000,0xfedcba98],control:[1,1,0,513],hitT:[1,2,0,0],global0:[1,1,1,1],global1:[1,1,1,1],metadata:[0,1,0x8123abcd,0],...edits};
 for(const key of keys)v[key]=v[key].map(x=>uintInputs.has(key)?x>>>0:f(x));cases.push(v);
}
make('far-unknown-stays-blocking');
make('global-disabled',{control:[0,1,513,17]});
make('whole-ray-detail',{directionLimit:[0,0,1,30],control:[1,1,17,513]});
make('near-unknown-no-far',{control:[1,1,513,17]});
make('far-miss',{control:[1,1,0,0]});
make('global-one-advance',{metadata:[1,1,0x8123abcd,0]});
make('global-eight-advances',{metadata:[255,1,0x8123abcd,0]});
make('global-proves-miss',{global0:[100,1,1,1],metadata:[255,1,0x8123abcd,0]});
make('small-distance-guard-stops',{global0:[.0005,1,1,1],metadata:[255,1,0x8123abcd,0]});
make('large-distance-relative-guard',{originMax:[1,2,3,4096],directionLimit:[0,0,1,1024],global0:[.0019,1,1,1],metadata:[255,1,0x8123abcd,0]});
make('zero-detail-overlap-clamped',{directionLimit:[0,0,1,.0005]});
make('point-visibility-intentionally-valid-zero',{footprint:[0,0,0,0],policy:[0,0,0xffffffff,0]});
const footprintCases=[{footprint:[1,.125,0,0],valid:1},{footprint:[4,-.25,0,0],valid:1},{footprint:[1,-1,0,0],valid:1},{footprint:[0,0,0,0],valid:0},{footprint:[-1,0,0,0],valid:1},{footprint:[NaN,0,0,0],valid:1},{footprint:[1,Infinity,0,0],valid:1},{footprint:[1,0,0,0],valid:2}];
for(const shadow of [0,1])for(const resolve of [0,1])for(const layers of [0,1])for(const viewKind of [0,1])for(let p=0;p<footprintCases.length;p++)for(let route=0;route<5;route++) {
 const fp=footprintCases[p];const controls=[[0,layers,17,513],[1,layers,513,17],[1,layers,0,17],[1,layers,0,513],[1,layers,0,0]][route];
 make(`cross-${shadow}-${resolve}-${layers}-${viewKind}-${p}-${route}`,{footprint:fp.footprint,metadata:[route===2?255:1,fp.valid,0xffffff01,0],policy:[shadow,resolve,0x80000000,0xffffffff],control:controls,view:viewKind?[113,-217,359,1]:[.6,0,.8,0]});
}
let seed=0x29f03ac1;function random(){seed^=seed<<13;seed^=seed>>>17;seed^=seed<<5;return(seed>>>0)/4294967296;}
for(let i=0;i<1024;i++) {
 const max=16+Math.floor(random()*64),limit=.25+Math.floor(random()*24)/4;
 const dist=()=>Array.from({length:4},()=>Math.floor(random()*16)/4);
 make(`fuzz-${i}`,{originMax:[random()*8,random()*8,random()*8,max],directionLimit:[.6,0,.8,limit],footprint:[random()*4,(random()-.5)*.5,0,0],view:[random()*30,random()*30,random()*30,i&1],policy:[i&1,(i>>>1)&1,1<<(i%32),0xfedcba98],control:[i%9?1:0,(i>>>2)&1,i%7===0?513:0,i%5===0?0:17],hitT:[.125,.125+random()*2,0,0],global0:dist(),global1:dist(),metadata:[i%256,i%13?1:0,0xfedcba98,0]});
}
function advance(fp,d){
 if(fp[2]!==1||!Number.isFinite(d)||d<0||!Number.isFinite(fp[0])||fp[0]<0||!Number.isFinite(fp[1]))return[0,0,0];
 const r=f(fp[0]+f(fp[1]*d));return Number.isFinite(r)&&r>=0?[r,fp[1],1]:[0,0,0];
}
function expected(v){
 const rows=Array.from({length:23},zero),o=v.originMax.slice(0,3),d=v.directionLimit.slice(0,3),max=v.originMax[3],limit=Math.min(max,v.directionLimit[3]);
 const fp=[v.footprint[0],v.footprint[1],v.metadata[1]],globalDistances=[...v.global0,...v.global1];
 let calls=0,globals=0;
 const point=(s)=>o.map((x,i)=>f(x+f(d[i]*s)));
 let result={found:false,flags:0,p:[0,0,0],t:max,identity:[0xffffffff,0,0,0],binding:[0xffffffff,0,0,0]};
 function detail(start,length,foot){
  const index=calls++,position=point(start),base=index?5:4;
  rows[base]=[...position,length];rows[index?7:6]=[...d,0];rows[index?9:8]=[foot[0],foot[1],0,0];rows[index?11:10]=v.view;rows[index?13:12]=v.policy;
  rows[14][index]=v.control[1]?1:0;rows[14][index+2]=foot[2];
  const t=v.hitT[index],flags=v.control[index+2];
  if(!(flags&1)||t<=0||t>=length)return false;
  result={found:true,flags:(flags|(!advance(foot,t)[2]?512:0))>>>0,p:position.map((x,i)=>f(x+f(d[i]*t))),t,identity:[3,v.metadata[2],41,43],binding:[7,11,13,43]};return true;
 }
 if(!v.control[0]||limit>=max)detail(0,max,fp);
 else if(!detail(0,limit,fp)){
  let start=Math.max(0,f(limit-.001)),emptyToEnd=false;
  // Independent segment schedule: retain the original observer/policy; each
  // empty interval ends before its reported boundary by the production TMin guard.
  for(let segment=0;segment<8&&start<max;segment++){
   const distance=globalDistances[segment];rows[15+segment]=[...point(start),distance];globals++;
   if(!((v.metadata[0]>>>segment)&1)||distance<=0)break;
   if(distance>=f(max-start)){emptyToEnd=true;break;}
   const guard=Math.max(f(.001),f(Math.abs(start)*f(2e-6))),next=f(start+Math.max(0,f(distance-guard)));
   if(next<=start)break;start=next;
  }
  if(!emptyToEnd&&start<max&&detail(start,f(max-start),advance(fp,start))){result.t=f(result.t+start);result.p=point(result.t);}
 }
 rows[0]=[result.found?1:0,calls,globals,result.flags];rows[1]=[...result.p,result.t];rows[2]=result.identity;rows[3]=result.binding;return rows;
}
if(mode==='prepare'){
 const data=Buffer.alloc(4+cases.length*160);data.writeUInt32LE(cases.length);
 cases.forEach((v,i)=>keys.forEach((key,row)=>v[key].forEach((x,lane)=>{const at=4+i*160+row*16+lane*4;if(uintInputs.has(key))data.writeUInt32LE(x>>>0,at);else data.writeFloatLE(x,at);})));fs.writeFileSync(path.join(dir,'inputs.bin'),data);
 fs.writeFileSync(path.join(dir,'oracle.json'),JSON.stringify({count:cases.length,inputStride:160,outputStride:368,seed:'0x29f03ac1',names:cases.map(x=>x.name)},null,2));console.log(`Prepared ${cases.length} query propagation cases`);
}else{
 const bytes=fs.readFileSync(path.join(dir,'outputs.bin'));assert.equal(bytes.length,cases.length*368);let checks=0,maxError=0;
 cases.forEach((v,index)=>expected(v).forEach((row,r)=>row.forEach((target,lane)=>{
  const at=index*368+r*16+lane*4,actual=uintRows.has(r)?bytes.readUInt32LE(at):bytes.readFloatLE(at);checks++;
  if(Number.isNaN(target))assert(Number.isNaN(actual),`${v.name} row${r}.${lane} NaN`);
  else if(!Number.isFinite(target)||uintRows.has(r)||r===10||r===11){assert.equal(actual,target,`${v.name} exact row${r}.${lane}`);}
  else{const error=Math.abs(actual-target);maxError=Math.max(maxError,error);assert(error<=3e-5*Math.max(1,Math.abs(target)),`${v.name} row${r}.${lane}: ${actual} != ${target}`);}
 })));
 const result={status:'passed',count:cases.length,checks,maxError,scope:'Original TraceSceneQuery and RayFootprint/Hit HLSL executed on D3D12 WARP; recording detail/global-SDF adapters supply geometry. Not actual DXR, BVH, SDF, Unity or physical GPU.'};fs.writeFileSync(path.join(dir,'oracle-results.json'),JSON.stringify(result,null,2));console.log(JSON.stringify(result));
}
