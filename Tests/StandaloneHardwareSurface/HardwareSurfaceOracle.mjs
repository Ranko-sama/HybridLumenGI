import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
const [mode,root]=process.argv.slice(2),inputStride=400,outputStride=96;
const add=(a,b)=>a.map((v,i)=>v+b[i]),sub=(a,b)=>a.map((v,i)=>v-b[i]),mul=(a,s)=>a.map(v=>v*s),dot=(a,b)=>a.reduce((s,v,i)=>s+v*b[i],0);
const cross=(a,b)=>[a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]];
const norm=a=>Math.sqrt(dot(a,a)),unit=a=>mul(a,1/norm(a)),transform=(m,a)=>m.map(row=>dot(row,a));
const det=m=>dot(m[0],cross(m[1],m[2]));
const transpose=m=>m[0].map((_,i)=>m.map(row=>row[i]));
const inverseTranspose=m=>[cross(m[1],m[2]),cross(m[2],m[0]),cross(m[0],m[1])].map(v=>mul(v,1/det(m)));
const finite=a=>a.every(Number.isFinite),mix=(a,w)=>a[0].map((_,j)=>a.reduce((s,v,i)=>s+v[j]*w[i],0));
let state=0x51c26b8d;const random=()=>{state=(Math.imul(state,1664525)+1013904223)>>>0;return state/2**32;};
function base(){return {o:[[2,.3,0],[0,.7,.1],[.2,0,1.4]],n:[[1,0,1],[0,1,1],[.2,.3,1]],t:[[1,0,0,1],[1,0,.1,1],[1,.2,0,1]],w:[.2,.3,.5],dir:[.3,.2,1],normalTS:[.3,-.2,.9],p:[[0,0,0],[2,0,0],[0,1,0]],uv:[[0,0],[1,0],[0,1]],uvScale:[1,1],size:[512,256],radius:.01};}
function writeCase(c){
    const b=Buffer.alloc(inputStride);let cursor=0;
    const vec=a=>{for(let j=0;j<4;j++){b.writeFloatLE(Math.fround(a[j]??0),cursor);cursor+=4;}};
    for(const row of c.o)vec(row);for(const row of c.nMatrix??inverseTranspose(c.o))vec(row);
    for(const row of c.n)vec(row);for(const row of c.t)vec(row);
    vec(c.w);vec(c.dir);vec(c.normalTS);for(const row of c.p)vec(row);
    vec([...c.uv[0],...c.uv[1]]);vec([...c.uv[2],...c.uvScale]);
    for(const x of [...c.size,0,0]){b.writeUInt32LE(x>>>0,cursor);cursor+=4;}vec([c.radius]);
    for(const view of c.views??[c.dir,c.dir,c.dir])vec(view);
    assert.equal(cursor,inputStride);return b;
}
function decode(b){let cursor=0;const vec=()=>{const v=Array.from({length:4},(_,j)=>b.readFloatLE(cursor+j*4));cursor+=16;return v;};
    const o=Array.from({length:3},()=>vec().slice(0,3)),nm=Array.from({length:3},()=>vec().slice(0,3));
    const n=Array.from({length:3},()=>vec().slice(0,3)),t=Array.from({length:3},()=>vec());
    const w=vec().slice(0,3),dir=vec().slice(0,3),normalTS=vec().slice(0,3),p=Array.from({length:3},()=>vec().slice(0,3)),uv01=vec(),uv2Scale=vec();
    const size=[b.readUInt32LE(cursor),b.readUInt32LE(cursor+4)];cursor+=16;const radius=vec()[0],views=Array.from({length:3},()=>vec().slice(0,3));
    return {o,nm,n,t,w,dir,normalTS,p,uv:[uv01.slice(0,2),uv01.slice(2),uv2Scale.slice(0,2)],uvScale:uv2Scale.slice(2),size,radius,views};
}
function expectedFrame(c){
    const fail=()=>({valid:false});
    if(!finite(c.o.flat())||!finite(c.nm.flat())||det(c.o)===0||!finite(c.w)||c.w.some(x=>x<0)||Math.abs(c.w.reduce((s,x)=>s+x,0)-1)>.0001||
        !c.views.every(v=>finite(v)&&norm(v))||!c.n.every(v=>finite(v)&&norm(v))||!c.t.every(v=>finite(v)&&Math.abs(v[3])===1&&norm(v.slice(0,3))))return fail();
    const ns=c.n.map(v=>unit(transform(c.nm,v))),ts=c.t.map(v=>unit(transform(c.o,v.slice(0,3))));
    if(!finite(ns.flat())||!finite(ts.flat()))return fail();
    const n=mix(ns,c.w),t=mix(ts,c.w),hand=c.t.reduce((s,v,i)=>s+v[3]*c.w[i],0)*Math.sign(det(c.o)),b=mul(cross(n,t),hand);
    if(dot(n,n)<=1e-16||dot(b,b)<=1e-16)return fail();
    const perVertex=c.views.map((direction,i)=>{
        const view=unit(direction),bitangent=mul(cross(ns[i],ts[i]),c.t[i][3]*Math.sign(det(c.o)));
        return [dot(ts[i],view)/norm(ns[i]),dot(bitangent,view)/norm(ns[i]),dot(ns[i],view)/norm(ns[i])];
    });const v=mix(perVertex,c.w);
    const raw=add(add(mul(t,c.normalTS[0]),mul(b,c.normalTS[1])),mul(n,c.normalTS[2]));
    return {valid:true,n,t,b,view:v,normal:finite(raw)&&norm(raw)>0?unit(raw):null};
}
// Independent geometric oracle: project a ray-perpendicular disk onto the
// triangle, solve the barycentric Gram system, and numerically maximize its
// texel diameter. It does not reproduce the shader's gradient/eigenvalue code.
function expectedLod(c){
    const bad={valid:false,lod:0};
    if(!finite(c.p.flat())||!finite(c.uv.flat())||!finite(c.uvScale)||!finite(c.dir)||!norm(c.dir)||!Number.isFinite(c.radius)||c.radius<0||c.size.some(v=>v===0||v>16384))return bad;
    const e1=sub(c.p[1],c.p[0]),e2=sub(c.p[2],c.p[0]),area=cross(e1,e2),areaLength=norm(area);
    if(!areaLength)return bad;
    const scale=Math.max(...e1.map(Math.abs),...e2.map(Math.abs));if(dot(cross(mul(e1,1/scale),mul(e2,1/scale)),cross(mul(e1,1/scale),mul(e2,1/scale)))<=1e-20)return bad;
    const ray=unit(c.dir),n=mul(area,1/areaLength),cos=dot(ray,n),maximum=Math.floor(Math.log2(Math.max(...c.size)));
    if(c.radius===0)return {valid:true,lod:0};
    const du=sub(c.uv[1],c.uv[0]),dv=sub(c.uv[2],c.uv[0]);
    if(du.every((v,j)=>v*c.uvScale[j]===0)&&dv.every((v,j)=>v*c.uvScale[j]===0))return {valid:true,lod:0};
    if(Math.abs(cos)<1e-6)return {valid:true,lod:maximum};
    const basis=unit(cross(ray,Math.abs(ray[0])<.8?[1,0,0]:[0,1,0])),other=cross(ray,basis);
    const g00=dot(e1,e1),g01=dot(e1,e2),g11=dot(e2,e2),gd=g00*g11-g01*g01;
    function projected(v){const delta=sub(v,mul(ray,dot(v,n)/cos)),r0=dot(delta,e1),r1=dot(delta,e2),b1=(r0*g11-r1*g01)/gd,b2=(r1*g00-r0*g01)/gd;
        return c.size.map((size,j)=>(du[j]*b1+dv[j]*b2)*c.uvScale[j]*size);}
    const a=projected(basis),b=projected(other);let length=0;
    for(let i=0;i<2048;i++){const angle=i*Math.PI/2048,delta=add(mul(a,Math.cos(angle)),mul(b,Math.sin(angle)));length=Math.max(length,norm(delta));}
    const raw=Math.log2(2*c.radius*length);return {valid:true,lod:Math.min(maximum,Math.max(0,raw))};
}
if(mode==='prepare'){
    const cases=[];for(let i=0;i<768;i++){
        const c=base();c.o=[[.3+random()*4,random()*.5,random()*.2],[random()*.1,.2+random()*3,random()*.4],[random()*.3,random()*.2,.5+random()*2]];
        if(i%2)c.o[0]=mul(c.o[0],-1);c.w=[random(),random(),random()];c.w=mul(c.w,1/c.w.reduce((s,x)=>s+x,0));
        c.n=Array.from({length:3},()=>[random()-.5,random()-.5,.5+random()]);c.t=Array.from({length:3},()=>[.5+random(),random()-.5,random()*.3,i%3===0?-1:1]);
        c.dir=[random()*2-1,random()*2-1,.04+random()];c.normalTS=[random()*1.6-.8,random()*1.6-.8,.2+random()];
        c.p=[[random(),random(),0],[2+random()*3,random(),0],[random(),2+random(),0]];c.uv=Array.from({length:3},()=>[random()*3-1,random()*3-1]);
        c.uvScale=[random()*8-4,random()*8-4];c.size=[1+Math.floor(random()*1024),1+Math.floor(random()*1024)];c.radius=2**(-12+random()*8);
        if(i%2===0)c.views=c.p.map(p=>sub([.4,.5,3],p));cases.push(c);
    }
    for(const change of [c=>{c.t[0][3]=0;},c=>{c.t[1][3]=.5;},c=>{c.t[2][0]=NaN;},c=>{c.t[0]=[0,0,0,1];},c=>{c.n[0]=[0,0,0];},c=>{c.o[0]=[0,0,0];c.nMatrix=[[1,0,0],[0,1,0],[0,0,1]];},c=>{c.w=[-.1,.6,.5];},c=>{c.w=[.5,.5,.5];},c=>{c.dir=[0,0,0];},c=>{c.normalTS=[NaN,0,1];},c=>{c.p[1]=c.p[0];},c=>{c.radius=-1;},c=>{c.radius=Infinity;},c=>{c.size=[0,512];},c=>{c.size=[16385,512];},c=>{c.uv[0][0]=NaN;},c=>{c.uvScale=[0,0];},c=>{c.radius=0;},c=>{c.dir=[1,0,0];},c=>{c.uv=[[0,0],[0,0],[0,0]];}]){const c=base();change(c);cases.push(c);}
    const regression=base();regression.o=[[1,0,0],[0,1,0],[0,0,1]];regression.n=[[0,0,1],[0,1,0],[0,0,1]];
    regression.t=[[1,0,0,1],[0,0,1,1],[1,0,0,1]];regression.w=[.5,.5,0];regression.dir=[1,1,1];cases.push(regression);
    const canceledGradient=base();canceledGradient.uv=[[0,0],[1,0],[2,0]];canceledGradient.uvScale=[0,1];canceledGradient.dir=[1,0,0];
    cases.splice(cases.length-1,0,canceledGradient); // Keep the explicit parallax regression last.
    const binaries=cases.map(writeCase),header=Buffer.alloc(4);header.writeUInt32LE(cases.length);fs.writeFileSync(path.join(root,'inputs.bin'),Buffer.concat([header,...binaries]));
    const expected=binaries.map(b=>{const c=decode(b);return {frame:expectedFrame(c),lod:expectedLod(c)};});fs.writeFileSync(path.join(root,'oracle.json'),JSON.stringify({count:cases.length,expected}));
    console.log(`Prepared ${cases.length} independent geometry cases; no GPU result assumed.`);
}else if(mode==='verify'){
    const oracle=JSON.parse(fs.readFileSync(path.join(root,'oracle.json'))),actual=fs.readFileSync(path.join(root,'outputs.bin'));assert.equal(actual.length,oracle.count*outputStride);
    let checks=0,maxFrameError=0,maxLodError=0,frameKnown=0,lodKnown=0;const check=(v,m)=>{checks++;assert.ok(v,m);};
    for(let i=0;i<oracle.count;i++){
        const values=Array.from({length:24},(_,j)=>actual.readFloatLE(i*outputStride+j*4)),e=oracle.expected[i];check((values[3]===1)===e.frame.valid,`frame validity ${i}`);
        if(e.frame.valid){frameKnown++;const expected=[...e.frame.n,1,...e.frame.t,1,...e.frame.b,1,...e.frame.view,1,...(e.frame.normal??[0,0,0]),e.frame.normal?1:0];for(let j=0;j<20;j++){const err=Math.abs(values[j]-expected[j]);maxFrameError=Math.max(maxFrameError,err);check(Number.isFinite(values[j])&&err<3e-5,`frame ${i}/${j}: ${values[j]} vs ${expected[j]}`);}}
        else for(let j=0;j<20;j++)check(values[j]===0,`invalid frame cleared ${i}/${j}`);
        check((values[23]===1)===e.lod.valid,`lod validity ${i}`);if(e.lod.valid){lodKnown++;const err=Math.abs(values[20]-e.lod.lod);maxLodError=Math.max(maxLodError,err);check(Number.isFinite(values[20])&&err<.0003,`lod ${i}: ${values[20]} vs ${e.lod.lod}`);}else check(values[20]===0,`invalid lod cleared ${i}`);
    }
    const regressionView=Array.from({length:3},(_,j)=>actual.readFloatLE((oracle.count-1)*outputStride+48+j*4));
    for(const component of regressionView)check(Math.abs(component-1/Math.sqrt(3))<1e-6,'URP vertex-space parallax regression');
    const result={status:'passed',count:oracle.count,checks,frameKnown,lodKnown,maxFrameError,maxLodError,regressionView,scope:'Actual runtime helper DXIL on WARP against double per-vertex transforms/parallax interpolation and independently projected disk/barycentric LOD oracle; no Unity, DXR traversal or propagated transport cone.'};
    fs.writeFileSync(path.join(root,'oracle-results.json'),JSON.stringify(result,null,2));console.log(JSON.stringify(result));
}else throw Error('prepare|verify required');
