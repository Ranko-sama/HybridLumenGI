import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
const [mode,dir,encoding='rgag']=process.argv.slice(2);
if(!dir||!['rgag','rgb','ag'].includes(encoding))throw Error('prepare|verify directory rgag|rgb|ag');
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
      if(!flag(3)&&(r.identity[3]&1)!==0)alpha*=texture(0,uv())[3];
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
if(mode==='prepare'){
  fs.mkdirSync(dir,{recursive:true});const textures=[],texels=[],metadata=[],cases=[],inputs=[];
  for(let map=0;map<10;map++){
    const t={generation:37,ready:true,bias:f((map%3-1)*.125),levels:[],offset:texels.length};
    for(let mip=0;mip<3;mip++){
      const size=4>>mip,pixels=[];
      for(let y=0;y<size;y++)for(let x=0;x<size;x++){
        const p=[.12+((map*5+x*3+y*7+mip*11)%23)/32,.18+((map*7+x+y*3+mip*5)%19)/30,.55+((map+x*2+y+mip*7)%11)/30,.22+((map*3+x*7+y*2+mip*11)%17)/24].map(f);
        pixels.push(p);texels.push(p);
      }
      t.levels.push({size,pixels});
    }
    t.count=texels.length-t.offset;textures.push(t);
    metadata.push([t.offset,4,4,0,3,t.generation,1,2,t.count,0,0,0,t.bias,1,0,0]);
  }
  // One descriptor deliberately not ready; source values themselves are retained.
  textures.push({...textures[0],ready:false});const unready=metadata[0].slice();unready[6]=0;metadata.push(unready);
  function record(flags=0,present=1023){return {identity:[19,flags,2,present],baseColor:[.8,.6,.4,.7].map(f),specColor:[.12,.3,.2,1].map(f),emissionColor:[2,.4,3,1].map(f),surface:[.37,.63,.71,1.4].map(f),detail:[.3,1.7,.8,.04].map(f),baseST:[1.7,.8,.12,-.17].map(f),detailST:[2.1,1.3,-.2,.1].map(f),proxyTint:[.6,1.2,.8,1].map(f),proxyEmission:[.12,.3,.01,1.8].map(f),handles:Array.from({length:10},(_,i)=>[i,37])};}
  function addCase(name,r=record(),overrides={}){
    const input={record:r,uv:[.23,.79].map(f),view:[.4,-.2,1].map(f),lods:Array.from({length:10},(_,i)=>f((i%5)*.4)),...overrides};
    inputs.push(input);cases.push({name,...reference(input,textures)});
  }
  for(let flags=0;flags<1024;flags++){addCase('keyword-'+flags,record(flags|((flags%3)<<10)));addCase('defaults-'+flags,record(flags,0));}
  for(let map=0;map<10;map++)for(const mode of ['stale','unready','not-assigned','unused']){
    const r=record(mode==='unused'?0:1023);if(mode==='stale')r.handles[map][1]++;
    if(mode==='unready')r.handles[map]=[10,37];if(mode==='not-assigned')r.identity[3]&=~(1<<map);
    // In metal workflow the specular map is irrelevant; the converse is tested too.
    addCase(`map-${map}-${mode}`,r);
  }
  for(const flags of [1,9,513,521])for(const map of [0,3,9]){
    const r=record(flags);r.handles[map]=[0xffffffff,1];addCase(`alpha-dependencies-${flags}-${map}`,r);
  }
  for(const flags of [5,7]){const r=record(flags);r.surface[0]=NaN;r.specColor[0]=NaN;addCase('map-replaces-scalar-'+flags,r);}
  for(const [name,edit] of [
    ['generation-zero',r=>r.identity[0]=0],['unknown-keyword',r=>r.identity[1]=8192],['unknown-present',r=>r.identity[3]=1024],['invalid-cull',r=>r.identity[2]=3],
    ['nonfinite-base',r=>r.baseColor[0]=NaN],['nonfinite-emission',r=>r.emissionColor[1]=Infinity],['nonfinite-bump',r=>r.surface[3]=NaN],
    ['nonfinite-detail',r=>r.detail[2]=NaN],['nonfinite-base-st',r=>r.baseST[0]=NaN],['nonfinite-detail-st',r=>r.detailST[0]=NaN],
    ['no-tint-energy-cap',r=>r.proxyTint=[10,20,30,1]],['extra-emission',r=>{r.identity[1]=0;r.proxyEmission=[4,5,6,3];}],
    ['alpha-at-threshold',r=>{r.identity[1]=9;r.baseColor[3]=r.detail[0];}],['alpha-below-threshold',r=>{r.identity[1]=9;r.baseColor[3]=f(r.detail[0]-.001);}],
    ['empty-assigned-handle',r=>r.handles[0]=[0,0]],['unused-invalid-scalar',r=>{r.identity[1]=0;r.emissionColor[1]=NaN;r.detail[2]=NaN;}],
    ['emission-negative-overflow',r=>{r.identity[1]=0;r.proxyEmission=[f(-3e38),0,0,2];}],
    ['emission-positive-overflow',r=>{r.identity[1]=0;r.proxyEmission=[f(3e38),0,0,2];}],
    ['nonfinite-alpha-cutoff',r=>{r.identity[1]=9;r.detail[0]=NaN;}],
  ]){const r=record(1023);edit(r);addCase(name,r);}
  addCase('no-parallax-bad-view-ignored',record(0),{view:[NaN,0,0]});
  addCase('parallax-bad-view',record(512),{view:[NaN,0,0]});addCase('parallax-zero-view',record(512),{view:[0,0,0]});
  addCase('nonfinite-used-lod',record(0),{lods:Array(10).fill(NaN)});
  addCase('nonfinite-unassigned-lod',record(1023,0),{lods:Array(10).fill(NaN)});
  for(let i=0;i<1024;i++){
    const flags=Math.floor(random()*8192),r=record(flags,Math.floor(random()*1024));
    r.surface=[random(),random(),random(),random()*2].map(f);r.detail=[random(),random()*2,random()*2,random()*.08].map(f);
    r.baseColor=Array.from({length:4},()=>f(random()));r.baseST=[random()*3,random()*3,random()-.5,random()-.5].map(f);
    r.detailST=[random()*3,random()*3,random()-.5,random()-.5].map(f);
    addCase('random-'+i,r,{uv:[f(random()*4-2),f(random()*4-2)],view:[f(random()-.5),f(random()-.5),f(.1+random())],lods:Array.from({length:10},()=>f(random()*4-1))});
  }
  const buf=Buffer.alloc(12+metadata.length*64+texels.length*16+inputs.length*320);buf.writeUInt32LE(inputs.length,0);buf.writeUInt32LE(metadata.length,4);buf.writeUInt32LE(texels.length,8);let at=12;
  for(const row of metadata)for(let i=0;i<16;i++,at+=4){if(i<12)buf.writeUInt32LE(row[i]>>>0,at);else buf.writeFloatLE(row[i],at);}
  for(const row of texels)for(const value of row){buf.writeFloatLE(value,at);at+=4;}
  for(const input of inputs){const r=input.record;
    for(const value of r.identity){buf.writeUInt32LE(value>>>0,at);at+=4;}
    for(const key of ['baseColor','specColor','emissionColor','surface','detail','baseST','detailST','proxyTint','proxyEmission'])for(const value of r[key]){buf.writeFloatLE(value,at);at+=4;}
    for(const h of r.handles)for(const value of h){buf.writeUInt32LE(value>>>0,at);at+=4;}
    for(const value of [...input.uv,...input.view.slice(0,2),input.view[2],0,0,0,...input.lods,0,0]){buf.writeFloatLE(value,at);at+=4;}
  }
  assert.equal(at,buf.length);fs.writeFileSync(path.join(dir,'inputs.bin'),buf);fs.writeFileSync(path.join(dir,'oracle.json'),JSON.stringify({encoding,count:cases.length,cases}));
  console.log(JSON.stringify({prepared:cases.length,encoding}));
}else if(mode==='verify'){
  const oracle=JSON.parse(fs.readFileSync(path.join(dir,'oracle.json'))),data=fs.readFileSync(path.join(dir,'outputs.bin'));
  assert.equal(data.length,oracle.count*96);assert.equal(oracle.encoding,encoding);let checks=0,maxError=0;
  oracle.cases.forEach((c,i)=>{
    const expected=[...c.values,0],start=i*96;
    for(let n=0;n<20;n++){
      const actual=data.readFloatLE(start+n*4),want=expected[n],error=Math.abs(actual-want);checks++;maxError=Math.max(maxError,error);
      assert.ok(finite(actual)&&error<=4e-4*Math.max(1,Math.abs(want)),`${c.name} ${encoding} component${n}: ${actual} vs ${want}`);
    }
    for(const [j,value] of [c.known,c.coverageKnown,c.receives,false].entries()){checks++;assert.equal(data.readUInt32LE(start+80+j*4),value?1:0,`${c.name} predicate${j} ${encoding}`);}
  });
  const result={status:'passed',encoding,count:oracle.count,checks,maxError,scope:'Actual HitMaterials and RayTextures HLSL on WARP. Independent double Lit-material oracle; not Unity texture import, DXR candidate traversal, TBN construction, or physical GPU.'};
  fs.writeFileSync(path.join(dir,'oracle-results.json'),JSON.stringify(result,null,2));console.log(JSON.stringify(result));
}else throw Error('mode');
