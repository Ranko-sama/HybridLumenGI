// Independent CPU coverage/partition reference plus live shader contract checks.
// This does not dispatch GPU code or establish rasterized scene coverage.
import assert from 'node:assert/strict';
import fs from 'node:fs';
const source=fs.readFileSync(new URL('../Runtime/Resources/HybridLumenGI/HybridLumenGISurfaceCache.hlsl',import.meta.url),'utf8');
const anchorSource=fs.readFileSync(new URL('../Runtime/Resources/HybridLumenGI/HybridLumenGISurfaceAnchors.compute',import.meta.url),'utf8');
const emitterSource=fs.readFileSync(new URL('../Runtime/Resources/HybridLumenGI/HybridLumenGIEmissiveRecords.hlsl',import.meta.url),'utf8');
const transportSource=fs.readFileSync(new URL('../Runtime/Resources/HybridLumenGI/HybridLumenGITransport.hlsl',import.meta.url),'utf8');
assert.match(source,/uint ownerSlot, chartId, layoutGeneration, flags/);
assert.match(source,/StructuredBuffer<uint4> _HLGI_SurfaceOwnerRanges/);
assert.match(source,/StructuredBuffer<uint> _HLGI_SurfaceCardIndices/);
assert.match(source,/StructuredBuffer<int2> _HLGI_SurfaceAnchors/);
assert.match(anchorSource,/numthreads\(4,4,1\)/);
assert.match(anchorSource,/#define HLGI_SURFACE_ANCHOR_SCAN 1/);
assert.match(anchorSource,/HLGILoadSurfaceTexel\(pixel,sample\)/);
assert.match(emitterSource,/#ifndef HLGI_EMISSIVE_RECORDS_INCLUDED/);
assert.match(emitterSource,/struct HLGIEmissiveRecord\s*\{\s*float4 sphere;\s*float4 data;/);
assert.match(anchorSource,/RWStructuredBuffer<HLGIEmissiveRecord> _HLGI_SurfaceEmitters/);
const scanBody=anchorSource.slice(anchorSource.indexOf('void CSBuildAnchors')).replace(/\/\/[^\n]*/g,'');
assert.doesNotMatch(scanBody,/\breturn\b/,'All sixteen threads must reach each shared-memory reduction barrier.');
assert.match(scanBody,/GroupMemoryBarrierWithGroupSync\(\)/);
assert.match(scanBody,/_HLGI_SurfaceEmitters\[\(uint\)_HLGI_AnchorCard\]=record/);
assert.match(source,/HLGILoadSurfaceTexel\(pixel,sample\)/);
assert.match(transportSource,/uint count=\(uint\)_HLGI_SurfaceCardCount\*patches/);
assert.doesNotMatch(transportSource,/slot\s*=\s*card\s*\/\s*6/);
const cardValidSource=source.slice(source.indexOf('bool HLGISurfaceCardValid'),source.indexOf('bool HLGISurfaceCardUv'));
assert.ok(cardValidSource.indexOf('card.ownerSlot>=')<cardValidSource.indexOf('_HLGI_Proxies[card.ownerSlot]'));
assert.ok(cardValidSource.indexOf('range.z!=card.layoutGeneration')<cardValidSource.indexOf('_HLGI_Proxies[card.ownerSlot]'));

const valid={emission:[0.1,0.2,0.3,1],position:[2,3,4,.5],normal:[0,0,1,.6],diffuse:[.2,.3,.4,1]};
const clone=()=>Object.fromEntries(Object.entries(valid).map(([key,value])=>[key,[...value]]));
function texelValid(value){
  if(!Object.values(value).every(array=>array.every(Number.isFinite)))return false;
  const e=value.emission[3];if(e<1||e>1024||e!==Math.round(e))return false;
  const n=value.normal,n2=Math.fround(Math.fround(Math.fround(n[0]*n[0])+Math.fround(n[1]*n[1]))+Math.fround(n[2]*n[2]));
  return Number.isFinite(n2)&&n2>=.25&&value.position[3]>=0&&value.position[3]<=1;
}
let invalidCases=0;
for(const channel of ['emission','position','normal','diffuse'])for(let component=0;component<4;component++)for(const bad of [NaN,Infinity,-Infinity]){
  const item=clone();item[channel][component]=bad;assert.equal(texelValid(item),false);invalidCases++;
}
for(const alpha of [0,.5,1.5,1025,-1]){const item=clone();item.emission[3]=alpha;assert.equal(texelValid(item),false);invalidCases++;}
for(const z of [-.001,1.001]){const item=clone();item.position[3]=z;assert.equal(texelValid(item),false);invalidCases++;}
for(const vector of [[0,0,0],[.49,0,0],[1e30,1e30,1e30]]){const item=clone();item.normal.splice(0,3,...vector);assert.equal(texelValid(item),false);invalidCases++;}
for(let alpha=1;alpha<=1024;alpha++){const item=clone();item.emission[3]=alpha;assert.equal(texelValid(item),true);}

function choose(width,height,grid,mask,offset=[5,7]){
  const anchors=Array.from({length:grid*grid},()=>[-1,-1]);
  const visits=new Uint8Array(width*height);
  for(let cy=0;cy<grid;cy++)for(let cx=0;cx<grid;cx++){
    const begin=[Math.floor(cx*width/grid),Math.floor(cy*height/grid)],end=[Math.floor((cx+1)*width/grid),Math.floor((cy+1)*height/grid)];
    let best=Infinity;
    for(let y=begin[1];y<end[1];y++)for(let x=begin[0];x<end[0];x++){
      visits[x+y*width]++;if(!mask[x+y*width])continue;
      const dx=(2*x+1)*grid-(2*cx+1)*width,dy=(2*y+1)*grid-(2*cy+1)*height,distance=dx*dx+dy*dy;
      if(distance<best){best=distance;anchors[cx+cy*grid]=[offset[0]+x,offset[1]+y];}
    }
  }
  assert.ok(visits.every(n=>n===1),'Half-open integer cells must partition every texel exactly once.');
  return anchors;
}
// Oracle assigns each pixel to its unique cell, then minimizes real pixel-center distance.
function oracle(width,height,grid,mask,offset=[5,7]){
  const results=Array.from({length:grid*grid},()=>[-1,-1]),best=new Float64Array(grid*grid).fill(Infinity);
  for(let y=0;y<height;y++)for(let x=0;x<width;x++){
    if(!mask[x+y*width])continue;
    const cx=Math.ceil((x+1)*grid/width)-1,cy=Math.ceil((y+1)*grid/height)-1;
    const center=[(cx+.5)*width/grid,(cy+.5)*height/grid];
    const distance=(x+.5-center[0])**2+(y+.5-center[1])**2,index=cx+cy*grid;
    if(distance<best[index]-1e-9){best[index]=distance;results[index]=[offset[0]+x,offset[1]+y];}
  }
  return results;
}
let seed=0x4912a5bd;
const random=()=>{seed^=seed<<13;seed^=seed>>>17;seed^=seed<<5;return(seed>>>0)/4294967296;};
let partitions=0,texels=0;
for(let width=1;width<=32;width++)for(let height=1;height<=32;height++)for(let grid=1;grid<=4;grid++){
  const mask=Uint8Array.from({length:width*height},()=>random()<.2?1:0);
  assert.deepEqual(choose(width,height,grid,mask),oracle(width,height,grid,mask));partitions++;texels+=width*height;
}
for(let i=0;i<1000;i++){
  const width=1+Math.floor(random()*128),height=1+Math.floor(random()*128),grid=1+Math.floor(random()*4);
  const mask=Uint8Array.from({length:width*height},()=>random()<.03?1:0),offset=[Math.floor(random()*1000),Math.floor(random()*1000)];
  assert.deepEqual(choose(width,height,grid,mask,offset),oracle(width,height,grid,mask,offset));partitions++;texels+=width*height;
}
const width=32,height=32,grid=4;
const thin=new Uint8Array(width*height);for(let y=0;y<height;y++)thin[y*width]=1;
const thinAnchors=choose(width,height,grid,thin,[0,0]);
assert.equal(thinAnchors.filter(a=>a[0]>=0).length,4,'One-pixel-wide strip must get one real anchor in each covered row cell.');
let fixedCenters=0;for(let y=0;y<grid;y++)for(let x=0;x<grid;x++)fixedCenters+=thin[Math.floor((x+.5)*width/grid)+width*Math.floor((y+.5)*height/grid)];
assert.equal(fixedCenters,0,'Regression fixture should be missed by the old fixed-center approach.');
const corner=new Uint8Array(17*19);corner[corner.length-1]=1;
const cornerAnchors=choose(17,19,4,corner,[0,0]);
assert.equal(cornerAnchors.filter(a=>a[0]>=0).length,1,'Sparse coverage must not be copied into adjacent cells.');
assert.deepEqual(cornerAnchors[15],[16,18]);
assert.ok(choose(31,29,3,new Uint8Array(31*29)).every(a=>a[0]===-1&&a[1]===-1),'Empty recapture must clear stale anchors.');

function patchPixelAccepted(pixel,cell,size,grid,offset){
  const lo=cell.map((v,i)=>offset[i]+Math.floor(v*size[i]/grid));
  const hi=cell.map((v,i)=>offset[i]+Math.floor((v+1)*size[i]/grid));
  return pixel.every((v,i)=>v>=lo[i]&&v<hi[i]);
}
assert.equal(patchPixelAccepted([-1,-1],[0,0],[32,32],4,[5,7]),false);
assert.equal(patchPixelAccepted([14,8],[0,0],[32,32],4,[5,7]),false,'A valid neighboring-cell texel must not act as this cell anchor.');
assert.equal(patchPixelAccepted([5,7],[0,0],[32,32],4,[5,7]),true);
assert.equal(patchPixelAccepted([37,8],[0,0],[32,32],4,[5,7]),false,'Another card rectangle must not be sampled.');

// Explicit owner/layout guards, including adversarial indirect indices, are independent of physical adjacency.
let proxyReads=0;
const proxies=[{id:11,revision:2,phase:1},{id:12,revision:3,phase:2}];
const ranges=[{first:0,count:2,generation:8},{first:2,count:1,generation:9}];
const cards=[{owner:1,layout:9,id:12,revision:3,ready:1,generation:31},{owner:0,layout:8,id:11,revision:2,ready:1,generation:32},{owner:0,layout:8,id:11,revision:2,ready:1,generation:33}];
const indices=[2,1,0];
function cardValid(card){
  if(card.owner<0||card.owner>=proxies.length||!card.ready||!card.generation||!card.layout)return false;
  const range=ranges[card.owner];
  if(!range.count||range.first<0||range.first>=cards.length||range.count>cards.length-range.first||range.generation!==card.layout)return false;
  proxyReads++;const proxy=proxies[card.owner];return proxy.phase>.5&&card.id===proxy.id&&card.revision===proxy.revision;
}
function forOwner(owner){const range=ranges[owner];return indices.slice(range.first,range.first+range.count).filter(i=>i>=0&&i<cards.length&&cards[i].owner===owner&&cardValid(cards[i]));}
assert.deepEqual(forOwner(0),[2,1]);assert.deepEqual(forOwner(1),[0]);
const before=proxyReads;assert.equal(cardValid({...cards[0],owner:0xffffffff}),false);assert.equal(proxyReads,before,'Invalid owner accessed the proxy buffer.');
assert.equal(cardValid({...cards[1],layout:7}),false);assert.equal(proxyReads,before,'Stale layout accessed proxy data.');
indices[0]=0;assert.deepEqual(forOwner(0),[1],'Indirect entry from another owner leaked into material lookup.');
indices[0]=0xffffffff;assert.deepEqual(forOwner(0),[1],'Out-of-range physical card leaked into lookup.');

// CPU model of the 16-lane reduction; the independent oracle below scans the
// input linearly and does not partition cells or use the group reduction tree.
const f=Math.fround,add=(a,b)=>f(f(a)+f(b)),mul=(a,b)=>f(f(a)*f(b));
const zeroRecord=()=>({sphere:[0,0,0,0],data:[0,0,0,0]});
function descriptorModel(width,height,grid,values,padding=.001,options={}){
  const lanes=Array.from({length:16},()=>({min:[Infinity,Infinity,Infinity],max:[-Infinity,-Infinity,-Infinity],sum:0,count:0}));
  const barriers=Array(16).fill(0),visits=new Uint8Array(width*height);
  const validCard=options.validCard??true,rectValid=options.rectValid??true,validGrid=grid>=1&&grid<=4;
  for(let lane=0;lane<16;lane++){
    const cx=lane%4,cy=Math.floor(lane/4),value=lanes[lane];
    if(validCard&&validGrid&&rectValid&&cx<grid&&cy<grid){
      for(let y=Math.floor(cy*height/grid);y<Math.floor((cy+1)*height/grid);y++)
      for(let x=Math.floor(cx*width/grid);x<Math.floor((cx+1)*width/grid);x++){
        const index=x+y*width;visits[index]++;
        const texel=values[index];if(!texelValid(texel))continue;
        const rgb=texel.emission.slice(0,3).map(v=>Math.max(v,0));
        const power=add(add(mul(rgb[0],.2126),mul(rgb[1],.7152)),mul(rgb[2],.0722));
        if(!Number.isFinite(power)||power<=0)continue;
        for(let i=0;i<3;i++){value.min[i]=Math.min(value.min[i],texel.position[i]);value.max[i]=Math.max(value.max[i],texel.position[i]);}
        value.sum=add(value.sum,power);value.count++;
      }
    }
    barriers[lane]++;
  }
  for(let stride=8;stride>0;stride>>=1){
    for(let lane=0;lane<stride;lane++){
      const a=lanes[lane],b=lanes[lane+stride];
      for(let i=0;i<3;i++){a.min[i]=Math.min(a.min[i],b.min[i]);a.max[i]=Math.max(a.max[i],b.max[i]);}
      a.sum=add(a.sum,b.sum);a.count+=b.count;
    }
    for(let lane=0;lane<16;lane++)barriers[lane]++;
  }
  let record=validCard?zeroRecord():null;
  const lane=lanes[0];
  if(validCard&&validGrid&&lane.count>0&&Number.isFinite(padding)&&padding>=0){
    const center=lane.min.map((v,i)=>add(mul(v,.5),mul(lane.max[i],.5)));
    const extent=lane.max.map((v,i)=>add(mul(v,.5),-mul(lane.min[i],.5)));
    const radius=Math.max(add(f(Math.sqrt(add(add(mul(extent[0],extent[0]),mul(extent[1],extent[1])),mul(extent[2],extent[2])))),padding),f(.001));
    const mean=f(lane.sum/lane.count),score=mul(mul(mean,radius),radius);
    if(center.every(Number.isFinite)&&Number.isFinite(radius)&&radius>0&&Number.isFinite(score)&&score>0)
      record={sphere:[...center,radius],data:[score,0,0,0]};
  }
  return {record,barriers,visits,count:lane.count};
}
function descriptorOracle(values,padding){
  const emitting=values.filter(value=>texelValid(value)&&value.emission.slice(0,3).some(v=>v>0));
  if(emitting.length===0)return zeroRecord();
  const lo=[0,1,2].map(i=>Math.min(...emitting.map(value=>value.position[i])));
  const hi=[0,1,2].map(i=>Math.max(...emitting.map(value=>value.position[i])));
  const center=lo.map((v,i)=>(v+hi[i])/2),radius=Math.max(Math.hypot(...hi.map((v,i)=>(v-lo[i])/2))+padding,.001);
  const mean=emitting.reduce((sum,value)=>sum+value.emission.slice(0,3).reduce((l,v,i)=>l+Math.max(v,0)*[.2126,.7152,.0722][i],0),0)/emitting.length;
  return {sphere:[...center,radius],data:[mean*radius*radius,0,0,0]};
}
function closeRecord(actual,expected,label){
  for(const key of ['sphere','data'])for(let i=0;i<4;i++)
    assert.ok(Math.abs(actual[key][i]-expected[key][i])<=3e-6*Math.max(1e-12,Math.abs(expected[key][i])),`${label}: ${key}[${i}] ${actual[key][i]} != ${expected[key][i]}`);
}
function emittingTexel(position,rgb){const value=clone();value.position.splice(0,3,...position);value.emission.splice(0,3,...rgb);return value;}
let emissionCases=0;
for(let fixture=0;fixture<240;fixture++){
  const w=1+Math.floor(random()*24),h=1+Math.floor(random()*24),g=1+fixture%4,padding=.001+random()*.3;
  // Nonuniform captured emission stands in for GPU-sampled emission textures;
  // the proposal consumes these values, not an assumed CPU material average.
  const values=Array.from({length:w*h},()=>emittingTexel([f(random()*20-10),f(random()*8-6),f(random()*4-2)],random()<.85?[0,0,0]:[f(random()*64),f(random()*8),f(random()*2)]));
  const actual=descriptorModel(w,h,g,values,padding);
  assert.ok(actual.visits.every(value=>value===1),'Emitter scan reuses the exact texel partition with no missing/doubled samples.');
  assert.ok(actual.barriers.every(value=>value===5),'Inactive threads must participate in all five barriers.');
  closeRecord(actual.record,descriptorOracle(values,padding),'independent emissive bounds/mean oracle');emissionCases++;
}
const textured=Array.from({length:32*32},()=>emittingTexel([100,100,100],[0,0,0]));
textured[0]=emittingTexel([-2,-3,-4],[4,0,0]);textured[31+31*32]=emittingTexel([2,3,4],[0,8,0]);
for(let g=1;g<=4;g++){
  const actual=descriptorModel(32,32,g,textured,.05);
  closeRecord(actual.record,descriptorOracle(textured,.05),'sparse texture emission');
  assert.equal(actual.count,2);assert.ok(actual.barriers.every(value=>value===5));
  assert.deepEqual(actual.record.sphere.slice(0,3),[0,0,0],'Dark distant texels must not enlarge the emitting bounds.');emissionCases++;
}
const tiny=descriptorModel(1,1,4,[emittingTexel([1e-20,2e-20,-1e-20],[1e-6,0,0])],0);
assert.equal(tiny.count,1);assert.ok(tiny.record.sphere[3]>=.001-1e-10&&tiny.record.data[0]>0,'Single tiny emitting texel retains a finite positive proposal.');
assert.ok(tiny.barriers.every(value=>value===5));emissionCases++;
const oldRecord=descriptorModel(1,1,1,[clone()]).record;
assert.ok(oldRecord.data[0]>0);
let storage=oldRecord;storage=descriptorModel(1,1,1,[emittingTexel([0,0,0],[0,0,0])]).record;
assert.deepEqual(storage,zeroRecord(),'Empty recapture must overwrite a previously emitting descriptor.');emissionCases++;
for(const padding of [NaN,Infinity,-Infinity,-.1]){
  assert.deepEqual(descriptorModel(1,1,1,[clone()],padding).record,zeroRecord(),'Invalid padding fails closed.');emissionCases++;
}
for(const grid of [0,5,-1]){
  const actual=descriptorModel(1,1,grid,[clone()]);assert.deepEqual(actual.record,zeroRecord());assert.ok(actual.barriers.every(value=>value===5));emissionCases++;
}
for(const options of [{rectValid:false},{validCard:false}]){
  const actual=descriptorModel(1,1,1,[clone()],.001,options);assert.deepEqual(actual.record,options.validCard===false?null:zeroRecord());assert.ok(actual.barriers.every(value=>value===5));emissionCases++;
}
for(const channel of ['emission','position','normal','diffuse'])for(let component=0;component<4;component++)for(const bad of [NaN,Infinity,-Infinity]){
  const texel=clone();texel[channel][component]=bad;
  assert.deepEqual(descriptorModel(1,1,4,[texel]).record,zeroRecord(),'Invalid texel must not poison or revive an emitter.');emissionCases++;
}
const huge=descriptorModel(2,1,1,[emittingTexel([-1e30,0,0],[1,1,1]),emittingTexel([1e30,0,0],[1,1,1])]);
assert.deepEqual(huge.record,zeroRecord(),'Overflowing float radius/importance must explicitly produce a zero descriptor.');emissionCases++;
const partial=clone();partial.position[0]=NaN;
closeRecord(descriptorModel(2,1,3,[partial,clone()]).record,descriptorOracle([clone()],.001),'Invalid texel exclusion retains the other finite emission');emissionCases++;

console.log(`Surface anchors: ${partitions} partition/nearest-covered comparisons, ${texels} texels, ${invalidCases} invalid-data cases, ${emissionCases} emission reduction cases and sparse/owner/layout regressions passed. CPU reference and source contracts only; no GPU/raster execution.`);
