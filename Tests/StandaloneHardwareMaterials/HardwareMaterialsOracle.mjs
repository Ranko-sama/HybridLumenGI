import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
const [mode,dir,encoding='rgag',kind='full']=process.argv.slice(2);
if(!dir||!['rgag','rgb','ag'].includes(encoding)||!['full','coverage','shadow'].includes(kind))throw Error('prepare|verify directory rgag|rgb|ag full|coverage|shadow');
const f=Math.fround,finite=Number.isFinite;
const add=(a,b)=>a.map((v,i)=>v+b[i]),mul=(a,b)=>a.map((v,i)=>v*b[i]),scale=(a,s)=>a.map(v=>v*s);
const dot=(a,b)=>a.reduce((s,v,i)=>s+v*b[i],0),norm=a=>scale(a,1/Math.sqrt(dot(a,a)));
const clamp=(x,a,b)=>Math.max(a,Math.min(b,x)),rgb=a=>a.slice(0,3),valid=a=>a.every(finite);
let seed=0x91e433f1;const random=()=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed/4294967296;};
// Independent double reference. Textures are periodic images at integer mip
// levels; a bilinear/trilinear sample is a weighted sum over image texel centers.
function sample(t,uv,lod){
  const level=clamp(lod+t.bias,0,t.levels.length-1),lo=Math.floor(level),hi=Math.min(lo+1,t.levels.length-1);
  const result=[0,0,0,0];
  for(const [m,mw] of [[lo,1-(level-lo)],[hi,level-lo]]){
    const image=t.levels[m],w=image.size;
    const px=(uv[0]-Math.floor(uv[0]))*w-.5,py=(uv[1]-Math.floor(uv[1]))*w-.5;
    for(let y=Math.floor(py);y<=Math.floor(py)+1;y++)for(let x=Math.floor(px);x<=Math.floor(px)+1;x++){
      const weight=(1-Math.abs(px-x))*(1-Math.abs(py-y))*mw;
      const pixel=image.pixels[((y%w+w)%w)*w+(x%w+w)%w];
      for(let c=0;c<4;c++)result[c]+=weight*pixel[c];
    }
  }
  return result;
}
function unpack(p,scaleValue){
  if(encoding==='rgb')return [(p[0]*2-1)*scaleValue,(p[1]*2-1)*scaleValue,p[2]*2-1];
  const x=2*(encoding==='ag'?p[3]:p[0]*p[3])-1,y=2*p[1]-1;
  return [x*scaleValue,y*scaleValue,Math.max(1e-16,Math.sqrt(Math.max(0,1-x*x-y*y)))];
}
function reference(input,textures){
  const r=input.record,flag=b=>(r.identity[1]&(1<<b))!==0;
  const header=r.identity[0]!==0&&(r.identity[1]&~8191)===0&&r.identity[2]<=2&&(r.identity[3]&~1023)===0;
  const neutral=encoding==='ag'?[1,.5,0,.5]:[.5,.5,1,1];
  const defaults=[[1,1,1,1],[1,1,1,1],[1,1,1,1],neutral,[1,1,1,1],[1,1,1,1],[1,1,1,1],[.5,.5,.5,1],neutral,[0,0,0,1]];
  function texture(map,uv){
    if(!(r.identity[3]&(1<<map)))return defaults[map];
    const [index,generation]=r.handles[map],t=textures[index];
    if(!t||!generation||generation!==t.generation||!t.ready||!valid(uv)||!finite(input.lods[map]))throw Error('unknown texture');
    const result=sample(t,uv,input.lods[map]);if(!valid(result))throw Error('bad texel');return result;
  }
  function uv(){
    const uv=add(mul(input.uv,r.baseST.slice(0,2)),r.baseST.slice(2,4));
    if(!valid(input.uv)||!valid(r.baseST)||!valid(uv))throw Error('invalid uv');
    if(!flag(9))return uv;
    if(!valid(input.view)||!finite(r.detail[3])||dot(input.view,input.view)<=0)throw Error('invalid view');
    const height=texture(9,uv)[1],view=norm(input.view),denominator=view[2]+.42;
    if(!denominator)throw Error('parallax pole');
    const offset=(height-.5)*r.detail[3]/denominator;
    const displaced=[uv[0]+view[0]*offset,uv[1]+view[1]*offset];
    if(!valid(displaced))throw Error('nonfinite parallax');return displaced;
  }
  let coverageKnown=false,covered=true;
  try{
    if(!header)throw Error('header');
    if(!flag(0)){coverageKnown=true;}
    else{
      let alpha=r.baseColor[3];if(!finite(alpha)||!finite(r.detail[0]))throw Error('alpha constants');
      if(!flag(3))alpha*=texture(0,uv())[3];
      if(!finite(alpha))throw Error('invalid alpha');coverageKnown=true;covered=alpha>=r.detail[0];
    }
  }catch{}
  let known=false,values=Array(19).fill(0),receives=false;
  try{
    if(!header||!valid(r.baseColor)||!valid(r.proxyTint)||!valid(r.proxyEmission)||!finite(r.surface[1]))throw Error('material constants');
    const baseUv=uv(),base=texture(0,baseUv);
    let albedo=mul(rgb(base),rgb(r.baseColor));
    const alpha=(flag(3)?1:base[3])*r.baseColor[3];
    let specGloss;
    if(flag(2))specGloss=texture(flag(1)?2:1,baseUv);
    else{
      const reflectance=flag(1)?rgb(r.specColor):Array(3).fill(r.surface[0]);
      if(!valid(reflectance))throw Error('reflectance');specGloss=[...reflectance,1];
    }
    const smoothness=(flag(3)?base[3]:specGloss[3])*r.surface[1];
    let normal=[0,0,1];
    if(flag(4)){if(!finite(r.surface[3]))throw Error('bump');normal=unpack(texture(3,baseUv),r.surface[3]);}
    let occ=1,emission=[0,0,0];
    if(flag(6)){if(!finite(r.surface[2]))throw Error('occlusion');occ=1+r.surface[2]*(texture(4,baseUv)[1]-1);}
    if(flag(5)){if(!valid(rgb(r.emissionColor)))throw Error('emission');emission=mul(rgb(texture(5,baseUv)),rgb(r.emissionColor));}
    if(flag(7)){
      const detailUv=add(mul(baseUv,r.detailST.slice(0,2)),r.detailST.slice(2,4));
      if(!valid(r.detailST)||!valid(detailUv)||!finite(r.detail[2]))throw Error('detail constants');
      const mask=texture(6,baseUv)[3],detailColor=rgb(texture(7,detailUv)),packed=texture(8,detailUv);
      if(flag(8)&&!finite(r.detail[1]))throw Error('detail scale');
      const factor=detailColor.map(c=>flag(8)?1+(2*c-1)*r.detail[1]:2*c);
      albedo=albedo.map((c,i)=>c*(1+(factor[i]-1)*mask));
      const dn0=unpack(packed,r.detail[2]);if(!valid(dn0)||dot(dn0,dn0)<=0||normal[2]===-1)throw Error('detail normal');
      const dn=norm(dn0),t=add(normal,[0,0,1]),u=mul(dn,[-1,-1,1]);
      const rnm=add(scale(t,dot(t,u)/t[2]),scale(u,-1));normal=add(scale(normal,1-mask),scale(rnm,mask));
    }
    const share=flag(1)?1-Math.max(...rgb(specGloss)):.96*(1-specGloss[0]);
    const diffuse=mul(scale(albedo,share),rgb(r.proxyTint));
    const spec=flag(1)?rgb(specGloss):albedo.map(c=>.04+(c-.04)*specGloss[0]);
    const emitted=add(emission,rgb(r.proxyEmission)).map(c=>c*r.proxyEmission[3]);
    if(!valid(emission.map(f))||!valid(emitted.map(f)))throw Error('float32 emission overflow before nonnegative clamp');
    emission=emitted.map(c=>Math.max(0,c));
    values=[...diffuse,alpha,...emission,occ,...normal,smoothness,...spec,covered?1:0,...albedo];
    if(!valid(values)||dot(normal,normal)<=0||!finite(dot(normal,normal)))throw Error('nonfinite result');
    receives=!flag(10);known=true;
  }catch{values=Array(19).fill(0);values[15]=covered?1:0;}
  return {known,coverageKnown,covered,receives,values};
}

// The bridge oracle is geometric, not a translation of its validation branches.
// Invalid test expectations are stated by each fixture. Valid LOD is measured by
// projecting a circular footprint and solving triangle barycentrics independently.
const sub=(a,b)=>a.map((v,i)=>v-b[i]),cross=(a,b)=>[a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]];
const transform=(m,p)=>m.map(row=>dot(row.slice(0,3),p)+(row[3]??0));
const det=m=>dot(m[0].slice(0,3),cross(m[1].slice(0,3),m[2].slice(0,3)));
const invT=m=>[cross(m[1].slice(0,3),m[2].slice(0,3)),cross(m[2].slice(0,3),m[0].slice(0,3)),cross(m[0].slice(0,3),m[1].slice(0,3))].map(v=>scale(v,1/det(m)));
const mix=(vectors,w)=>vectors[0].map((_,j)=>vectors.reduce((s,v,i)=>s+v[j]*w[i],0));
function geometricLod(c,size,uvScale){
  const ps=c.positions.map(p=>transform(c.o,p.slice(0,3))),e1=sub(ps[1],ps[0]),e2=sub(ps[2],ps[0]);
  const n=norm(cross(e1,e2)),d=norm(c.direction),du=c.uv.map(uv=>mul(uv,uvScale));
  if(c.radius===0 || du.every(v=>v[0]===du[0][0]&&v[1]===du[0][1]))return 0;
  if(Math.abs(dot(n,d))<1e-6)return Math.log2(size);
  const helper=Math.abs(d[0])<.8?[1,0,0]:[0,1,0],a=norm(cross(d,helper)),b=cross(d,a);
  const aa=dot(e1,e1),ab=dot(e1,e2),bb=dot(e2,e2),den=aa*bb-ab*ab;
  let maxDiameter=0;
  for(let j=0;j<2048;j++){
    const theta=j*Math.PI*2/2048,v=add(scale(a,Math.cos(theta)),scale(b,Math.sin(theta)));
    const projected=sub(v,scale(d,dot(n,v)/dot(n,d)));
    const pe1=dot(projected,e1),pe2=dot(projected,e2);
    const u=(pe1*bb-pe2*ab)/den,vv=(pe2*aa-pe1*ab)/den;
    const uv=add(scale(sub(du[1],du[0]),u),scale(sub(du[2],du[0]),vv));
    maxDiameter=Math.max(maxDiameter,2*c.radius*size*Math.sqrt(dot(uv,uv)));
  }
  return clamp(Math.log2(maxDiameter),0,Math.log2(size));
}
function expectation(c,textures){
  const zeros=Array(24).fill(0),unknown=()=>({known:false,covered:true,receives:false,values:zeros.map((x,i)=>i===15?1:x)});
  if(c.unknown)return unknown();
  const w=[1-c.bary[0]-c.bary[1],...c.bary],r=structuredClone(c.record);
  // ShadowCaster alpha samples transformed base UV, without ForwardLit height
  // displacement. Derive this purpose's independent material equation locally.
  if(c.shadow)r.identity[1]&=~512;
  const uv=mix(c.uv,w),nm=c.nm??invT(c.o);
  const normals=c.normals.map(n=>norm(transform(nm,n))),tangents=c.tangents.map(t=>norm(transform(c.o.map(row=>row.slice(0,3)),t.slice(0,3))));
  const n=mix(normals,w),t=mix(tangents,w),hand=c.tangents.reduce((sum,v,i)=>sum+v[3]*w[i],0)*Math.sign(det(c.o));
  const b=scale(cross(n,t),hand);
  let view=[0,0,1];
  if(r.identity[1]&512){
    const ps=c.positions.map(p=>transform(c.o,p.slice(0,3)));
    view=mix(ps.map((p,i)=>{const v=norm(sub(c.origin,scale(p,c.viewW))),bn=scale(cross(normals[i],tangents[i]),c.tangents[i][3]*Math.sign(det(c.o)));return [dot(tangents[i],v),dot(bn,v),dot(normals[i],v)];}),w);
  }
  const lods=Array.from({length:10},(_,map)=>{
    const tex=textures[r.handles[map][0]];
    if(!tex || !(r.identity[3]&(1<<map)))return 0;
    const uvScale=map===7||map===8?mul(r.baseST.slice(0,2),r.detailST.slice(0,2)):r.baseST.slice(0,2);
    return geometricLod(c,tex.levels[0].size,uvScale);
  });
  const ref=reference({record:r,uv,view,lods},textures);
  if(c.coverage){
    const values=zeros.slice();values[15]=ref.covered?1:0;
    return {known:ref.coverageKnown,covered:ref.covered,receives:false,values};
  }
  if(!ref.known)return unknown();
  const needsFrame=(r.identity[1]&(16|128|512))!==0;
  const normal=needsFrame?norm(add(add(scale(t,ref.values[8]),scale(b,ref.values[9])),scale(n,ref.values[10]))):norm(n);
  const values=[...ref.values,0,...normal,0];values[15]=1;
  return {known:true,covered:true,receives:ref.receives,values};
}
if(mode==='prepare'){
  fs.mkdirSync(dir,{recursive:true});const textures=[],metadata=[],texels=[];let inputs=[],cases=[];
  for(let map=0;map<12;map++){
    const top=map===10?8:map===11?2:4,t={generation:37,ready:true,bias:0,levels:[],offset:texels.length};
    for(let mip=0;mip<=Math.log2(top);mip++){
      const size=top>>mip,pixels=[];
      for(let y=0;y<size;y++)for(let x=0;x<size;x++){
        const p=[.12+((map*5+x*3+y*7+mip*11)%23)/32,.18+((map*7+x+y*3+mip*5)%19)/30,.55+((map+x*2+y+mip*7)%11)/30,.22+((map*3+x*7+y*2+mip*11)%17)/24].map(f);
        pixels.push(p);texels.push(p);
      }t.levels.push({size,pixels});
    }
    t.count=texels.length-t.offset;textures.push(t);metadata.push([t.offset,top,top,0,t.levels.length,37,1,2,t.count,0,0,0,0,1,0,0]);
  }
  textures.push({...textures[0],ready:false});metadata.push(metadata[0].map((x,i)=>i===6?0:x));
  function record(flags=0,present=1023){return {identity:[19,flags,2,present],baseColor:[.8,.6,.4,.7],specColor:[.12,.3,.2,1],emissionColor:[2,.4,3,1],surface:[.37,.63,.71,1.4],detail:[.3,1.7,.8,.04],baseST:[1.7,.8,.12,-.17],detailST:[2.1,1.3,-.2,.1],proxyTint:[.6,1.2,.8,1],proxyEmission:[.12,.3,.01,1.8],handles:Array.from({length:10},(_,i)=>[i,37])};}
  function base(flags=0,present=1023){return {record:record(flags,present),identity:[101,53,29,2],geometry:[3,0,2,7],
    bindingSource:[101,53,29,7],bindingTable:[0,19,0,0],o:[[1,0,0,0],[0,1,0,0],[0,0,1,0]],
    positions:[[0,0,0,1],[1,0,0,1],[0,1,0,1]],tangents:[[1,0,0,1],[1,0,0,1],[1,0,0,1]],normals:[[0,0,1],[0,0,1],[0,0,1]],
    uv:[[0,0],[1,0],[0,1]],uvValid:1,normalValid:1,bary:[.23,.39],origin:[.5,.5,2],viewW:1,direction:[0,0,-1],radius:.1,primitive:1,coverage:false,shadow:false};}
  function addCase(name,c){
    // Freeze exactly the float32 values written into the actual buffers.
    for(const key of ['baseColor','specColor','emissionColor','surface','detail','baseST','detailST','proxyTint','proxyEmission'])c.record[key]=c.record[key].map(f);
    for(const key of ['o','positions','tangents','normals','uv'])c[key]=c[key].map(row=>row.map(f));
    for(const key of ['bary','origin','direction'])c[key]=c[key].map(f);c.radius=f(c.radius);c.viewW=f(c.viewW);c.nm=(c.nm??invT(c.o)).map(row=>row.map(f));
    inputs.push(c);cases.push({name,...expectation(c,textures)});
  }
  for(const flags of [0,1,2,3,4,5,7,9,16,32,64,128,384,512,513,521,1023,2047,4095,8191])for(const present of [0,1023])for(const coverage of [false,true]){
    const c=base(flags,present);c.coverage=coverage;addCase(`flags-${flags}-present-${present}-coverage-${coverage}`,c);
  }
  const rejects=[
    ['binding-generation',c=>c.bindingTable[1]++],['binding-reserved',c=>c.bindingTable[3]=1],
    ['binding-owner',c=>c.bindingSource[0]++],['binding-owner-revision',c=>c.bindingSource[1]++],['binding-geometry-revision',c=>c.bindingSource[2]++],['binding-original-submesh',c=>c.bindingSource[3]++],
    ['record-cull',c=>c.record.identity[2]=1],['material-index',c=>c.bindingTable[0]=0xffffffff],['instance-index',c=>c.instanceIndex=0xffffffff],
    ['texture-generation',c=>c.record.handles[0][1]++],['texture-index',c=>c.record.handles[0][0]=0xffffffff],['texture-unready',c=>c.record.handles[0]=[12,37]],
    ['uv-missing',c=>c.uvValid=0],['uv-nonfinite',c=>c.uv[0][0]=NaN],['bary-negative',c=>c.bary=[-.1,.2]],['bary-outside',c=>c.bary=[.8,.8]],['bary-nonfinite',c=>c.bary[0]=NaN],
    ['primitive-oob',c=>c.primitive=2],['triangle-offset-oob',c=>c.geometry[1]=0xffffffff],['position-invalid',c=>c.positions[0][3]=0],['position-nonfinite',c=>c.positions[1][0]=NaN],
    ['matrix-nonfinite',c=>c.o[1][3]=Infinity],['zero-scale',c=>{c.o=[[0,0,0,0],[0,0,0,0],[0,0,0,0]];c.nm=[[1,0,0],[0,1,0],[0,0,1]];}],
    ['negative-radius',c=>c.radius=-.1],['nan-radius',c=>c.radius=NaN],['zero-ray',c=>c.direction=[0,0,0]]
  ];
  for(const [name,edit] of rejects)for(const coverage of [false,true]){const c=base(1);edit(c);c.coverage=coverage;c.unknown=true;addCase(name+'-'+coverage,c);}
  for(const [name,edit] of [
    ['tangent-missing',c=>c.tangents[1]=[0,0,0,0]],['tangent-nan',c=>c.tangents[2][0]=NaN],['tangent-sign',c=>c.tangents[0][3]=0],
    ['normal-missing',c=>c.normalValid=0],['normal-zero',c=>c.normals[2]=[0,0,0]],['normal-nan',c=>c.normals[1][0]=NaN]
  ]){const c=base(16);edit(c);c.unknown=true;addCase(name,c);}
  // Geometry irrelevant to opaque / constant-alpha coverage must not poison it.
  for(const flags of [0,9,521]){const c=base(flags);c.coverage=true;c.uvValid=0;c.normalValid=0;c.positions[0][3]=0;c.record.handles[0]=[0xffffffff,0];c.tangents[0]=[0,0,0,0];addCase('independent-coverage-'+flags,c);}
  for(const alpha of [.1,.3,.8]){const c=base(9);c.coverage=true;c.record.baseColor[3]=alpha;addCase('constant-alpha-'+alpha,c);}
  for(const scaleValue of [1e-10,1e-3,.25,1,4,1e5])for(const uvScale of [.125,1,4]){
    const c=base();c.o=[[scaleValue,0,0,0],[0,scaleValue,0,0],[0,0,scaleValue,0]];c.record.baseST=[uvScale,uvScale,.1,-.1];addCase(`scale-${scaleValue}-uv-${uvScale}`,c);
  }
  for(const tex of [0,10,11])for(const radius of [0,.01,.2,.7]){const c=base();c.record.handles[0]=[tex,37];c.radius=radius;addCase(`texture-size-${tex}-radius-${radius}`,c);}
  for(const map of [1,2,3,4,5,6,7,8,9]){
    const c=base();c.record.handles[map]=[0xffffffff,0];addCase('unused-bad-map-'+map,c);
    const full=base(1023);full.record.handles[map]=[0xffffffff,0];if(map!==1)full.unknown=true;addCase('required-bad-map-'+map,full);
  }
  // Multiple source submeshes have distinct records and non-zero original IDs.
  for(let submesh=0;submesh<8;submesh++){const c=base(32);c.geometry[3]=c.bindingSource[3]=submesh*2+1;c.record.baseColor=[.1*submesh,.7,.3,1];c.record.proxyEmission=[submesh,0,0,1];addCase('original-submesh-'+submesh,c);}
  for(let i=0;i<160;i++){
    const c=base(Math.floor(random()*8192),Math.floor(random()*1024));
    c.o=[[f(.3+random()*3)*(i%2?-1:1),f(random()*.4),0,0],[0,f(.3+random()*2),f(random()*.2),0],[0,0,f(.5+random()),0]];
    c.normals=[[.2,.1,1],[0,.3,1],[-.1,.2,1]];c.tangents=[[1,.1,0,1],[1,0,.2,1],[1,.2,.1,1]];
    c.bary=[random()*.45,random()*.45];c.direction=[random()-.5,random()-.5,-1];c.radius=random()*.3;
    c.record.baseST=[random()*3,random()*3,random()-.5,random()-.5];c.coverage=i%3===0;addCase('random-affine-'+i,c);
  }
  // On a shared geometric plane, varying vertex normals/tangents produce
  // distinct per-vertex tangent-space views even for a fixed orthographic view.
  for(const flags of [512,513,1023])for(const viewW of [0,1])for(const coverage of [false,true])for(const mirror of [false,true]){
    const c=base(flags);c.viewW=viewW;c.origin=[1,.2,1];c.coverage=coverage;c.radius=.02;
    c.normals=[[.4,.1,1],[0,.3,1],[-.2,.2,1]];c.tangents=[[1,.2,0,1],[1,0,.1,1],[1,.2,.3,1]];
    c.o=[[mirror?-1.7:1.7,.2,0,.1],[0,.8,.1,-.2],[0,0,1.3,0]];
    addCase(`view-${viewW}-flags-${flags}-coverage-${coverage}-mirror-${mirror}`,c);
  }
  for(const translation of [[0,0,0],[1000,-40,50]]){
    const c=base(1023);c.viewW=0;c.origin=[.7,-.2,1];c.normals=[[.4,.1,1],[0,.3,1],[-.2,.2,1]];
    c.o[0][3]=translation[0];c.o[1][3]=translation[1];c.o[2][3]=translation[2];addCase('orthographic-translation-'+translation.join(','),c);
  }
  const shadowIndependent=[
    ['height-missing',c=>c.record.handles[9]=[0xffffffff,0]],['height-unready',c=>c.record.handles[9]=[12,37]],
    ['tangent-missing',c=>c.tangents[1]=[0,0,0,0]],['normal-missing',c=>c.normalValid=0],
    ['view-nonfinite',c=>c.origin[0]=NaN],['view-zero',c=>{c.viewW=0;c.origin=[0,0,0];}],['view-invalid-w',c=>c.viewW=.5]
  ];
  for(const [name,edit] of shadowIndependent){
    const c=base(513);c.coverage=true;edit(c);c.unknown=true;addCase('surface-requires-'+name,c);
    const s=structuredClone(c);s.shadow=true;s.unknown=false;addCase('shadow-ignores-'+name,s);
  }
  // Construct four robust acceptance counterexamples with an independent alpha
  // midpoint. This proves actual shadow UV behavior, not merely missing-resource
  // independence. Keep a margin much larger than float32 rounding error.
  for(const [axis,view] of [[0,[1,0,1]],[1,[-1,0,1]],[2,[0,1,1]],[3,[0,-1,1]]]){
    let best=null;
    for(let u=.1;u<.81;u+=.1)for(let v=.1;u+v<.91;v+=.1){
      const c=base(513);c.coverage=true;c.viewW=0;c.origin=view;c.radius=0;c.bary=[u,v];
      c.record.baseST=[1,1,0,0];c.record.detail[3]=.08;
      const input={record:c.record,uv:[u,v],view,lods:Array(10).fill(0)};
      const surfaceAlpha=reference(input,textures).values[3],shadowRecord=structuredClone(c.record);shadowRecord.identity[1]&=~512;
      const shadowAlpha=reference({...input,record:shadowRecord},textures).values[3],gap=Math.abs(surfaceAlpha-shadowAlpha);
      if(!best||gap>best.gap)best={c,gap,cutoff:(surfaceAlpha+shadowAlpha)*.5};
    }
    assert.ok(best&&best.gap>.002,'nontrivial shadow/surface alpha separation');
    best.c.record.detail[0]=f(best.cutoff);addCase('parallax-shadow-decision-'+axis,best.c);
  }
  // Clone all ordinary coverage fixtures before purpose-specific additions.
  const ordinary=inputs.map((c,i)=>({c,name:cases[i].name})).filter(({c,name})=>c.coverage&&!c.shadow&&!name.startsWith('surface-requires-'));
  for(const {c,name} of ordinary){const s=structuredClone(c);s.shadow=true;addCase('shadow-'+name,s);}
  for(let i=0;i<4;i++){
    const a=cases.find(c=>c.name==='parallax-shadow-decision-'+i),b=cases.find(c=>c.name==='shadow-parallax-shadow-decision-'+i);
    assert.ok(a.known&&b.known);assert.notEqual(a.covered,b.covered,'surface and shadow alpha must disagree at midpoint');
  }
  // Base UV/texels remain real shadow dependencies; unknown is not transparent.
  for(const [name,edit] of [['base-missing',c=>c.record.handles[0]=[0xffffffff,0]],['uv-missing',c=>c.uvValid=0],['base-unready',c=>c.record.handles[0]=[12,37]]]){
    const c=base(513);c.coverage=true;c.shadow=true;c.unknown=true;edit(c);addCase('shadow-requires-'+name,c);
  }
  // Each fixture gets its own material/binding and two surface records. The
  // first surface is deliberately unusable; primitive 1 must select the second.
  const selected=inputs.map((c,i)=>({c,expected:cases[i]})).filter(({c})=>kind==='shadow'?c.shadow:!c.shadow&&c.coverage===(kind==='coverage'));
  inputs=selected.map(({c})=>c);cases=selected.map(({expected})=>expected);
  const count=inputs.length,buf=Buffer.alloc(24+metadata.length*64+texels.length*16+count*(240+32+192+320));let at=0;
  const u=x=>{buf.writeUInt32LE(x>>>0,at);at+=4;},flt=x=>{buf.writeFloatLE(x,at);at+=4;},vec=v=>v.forEach(flt);
  [count,metadata.length,texels.length,count,count,count*2].forEach(u);
  for(const row of metadata)row.forEach((v,i)=>i<12?u(v):flt(v));texels.forEach(vec);
  for(const c of inputs){const r=c.record;r.identity.forEach(u);for(const key of ['baseColor','specColor','emissionColor','surface','detail','baseST','detailST','proxyTint','proxyEmission'])vec(r[key]);r.handles.flat().forEach(u);}
  inputs.forEach((c,i)=>{const table=c.bindingTable.slice();if(table[0]!==0xffffffff)table[0]=i;table.forEach(u);c.bindingSource.forEach(u);});
  for(const c of inputs){vec(Array(24).fill(0));c.positions.forEach(vec);c.tangents.forEach(vec);}
  inputs.forEach((c,i)=>{
    for(let col=0;col<4;col++)for(let row=0;row<4;row++)flt(row<3&&col<3?c.nm[row][col]:row===col?1:0);
    const geometry=c.geometry.slice();if(geometry[1]!==0xffffffff)geometry[1]=i*2;geometry.forEach(u);c.identity.forEach(u);vec(Array(8).fill(0));
    for(let v=0;v<3;v++)vec([...c.normals[v],c.uv[v][0]]);vec([0,0,1,c.normalValid]);vec([c.uv[0][1],c.uv[1][1],c.uv[2][1],c.uvValid]);
    c.o.forEach(vec);vec([...c.bary,c.radius,0]);vec([...c.origin,c.viewW]);vec([...c.direction,0]);[c.instanceIndex??i,c.primitive,c.coverage?1:0,c.shadow?1:0].forEach(u);
  });
  assert.equal(at,buf.length);fs.writeFileSync(path.join(dir,'inputs.bin'),buf);fs.writeFileSync(path.join(dir,'oracle.json'),JSON.stringify({encoding,kind,count,cases}));console.log(JSON.stringify({prepared:count,encoding,kind}));
}else if(mode==='verify'){
  const oracle=JSON.parse(fs.readFileSync(path.join(dir,'oracle.json'))),data=fs.readFileSync(path.join(dir,'outputs.bin'));
  assert.equal(data.length,oracle.count*112);assert.equal(oracle.encoding,encoding);assert.equal(oracle.kind,kind);let checks=0,maxError=0;
  oracle.cases.forEach((c,i)=>{
    for(let j=0;j<24;j++){const actual=data.readFloatLE(i*112+j*4),expected=c.values[j],error=Math.abs(actual-expected);checks++;maxError=Math.max(maxError,error);assert.ok(finite(actual)&&error<=8e-4*Math.max(1,Math.abs(expected)),`${c.name} ${encoding} float${j}: ${actual} vs ${expected}`);}
    [c.known,c.covered,c.receives,false].forEach((value,j)=>{checks++;assert.equal(data.readUInt32LE(i*112+96+j*4),value?1:0,`${c.name} ${encoding} predicate${j}`);});
  });
  const result={status:'passed',encoding,kind,count:oracle.count,checks,maxError,scope:'Actual runtime hardware material bridge with compile-time constant full/surface-coverage/shadow-coverage calls, point/orthographic material views, plus sampler/evaluator/TBN/LOD on D3D12 WARP; independent double material and projected-footprint oracle. Not dynamic purpose selection, Unity, DXR traversal, native texture upload, or physical GPU.'};
  fs.writeFileSync(path.join(dir,'oracle-results.json'),JSON.stringify(result,null,2));console.log(JSON.stringify(result));
}else throw Error('mode');
