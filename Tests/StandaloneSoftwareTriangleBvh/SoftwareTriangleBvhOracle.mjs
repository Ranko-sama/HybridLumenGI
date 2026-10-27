import fs from 'node:fs';import path from 'node:path';import assert from 'node:assert/strict';
const mode=process.argv[2],dir=process.argv[3],F=Math.fround;
const sub=(a,b)=>a.map((v,i)=>v-b[i]),cross=(a,b)=>[a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]],dot=(a,b)=>a.reduce((s,v,i)=>s+v*b[i],0),unit=a=>{const n=Math.hypot(...a);return a.map(v=>v/n);};
let seed=13719;const random=()=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return(seed>>>8)/16777216;};
const bytes=fs.readFileSync(path.join(dir,'leaves.bin')),count=bytes.readUInt32LE(),leaves=[];
for(let k=0;k<count;k++){const off=4+k*64;leaves.push({p:[0,1,2].map(v=>[0,1,2].map(a=>bytes.readFloatLE(off+v*16+a*4))),id:[0,1,2,3].map(a=>bytes.readUInt32LE(off+48+a*4))});}
function intersect(o,d,tri,maxT){const e1=sub(tri.p[1],tri.p[0]),e2=sub(tri.p[2],tri.p[0]),h=cross(d,e2),det=dot(e1,h);if(det===0)return null;const s=sub(o,tri.p[0]),u=dot(s,h)/det,q=cross(s,e1),v=dot(d,q)/det,t=dot(e2,q)/det;if(u<0||v<0||u+v>1||t<.0001||t>maxT)return null;return{t,b:[u,v],primitive:tri.id[1]};}
if(mode==='prepare'){
    const cases=[];
    function add(tri,o,d,maxT=100,global=false,edge=false){o=o.map(F);d=d.map(F);let expected=intersect(o,d,tri,maxT);if(global){expected=null;for(const t of leaves){const hit=intersect(o,d,t,maxT);if(hit&&(!expected||hit.t<expected.t||hit.t===expected.t&&hit.primitive<expected.primitive))expected=hit;}}cases.push({tri,o,d,maxT,global,edge,expected});}
    for(let k=0;k<5000;k++){const tri=leaves[k%count],p=tri.p[0].map((_,i)=>(tri.p[0][i]+tri.p[1][i]+tri.p[2][i])/3),d=unit([random()-.5,random()-.5,.2+random()]);const length=.1+random()*10;add(tri,p.map((v,i)=>v-length*d[i]),d,100,true);}
    for(let k=0;k<500;k++)add(leaves[0],[random()*20-10,random()*20-10,random()*3],[0,0,1],100,true);
    for(let k=0;k<257;k++){const x=F(-1+2*k/256);add(leaves[0],[x,-x,0],[0,0,1],100,true,true);}
    for(let k=0;k<1700;k++){
        const scale=10**(-2+8*random()),p0=[(random()-.5)*scale,(random()-.5)*scale,scale].map(F),p1=[p0[0]+scale*.8,p0[1]+scale*.1,p0[2]+scale*.3].map(F),p2=[p0[0]+scale*.2,p0[1]+scale*.9,p0[2]+scale*.05].map(F),tri={p:[p0,p1,p2],id:[0,0,0,0]};
        let u=random()*.7,v=random()*(1-u)*.9;const hit=p0.map((a,j)=>a+(p1[j]-a)*u+(p2[j]-a)*v),d=unit([random()-.5,random()-.5,.3+random()]);
        add(tri,hit.map((a,j)=>a-scale*d[j]),d,scale*3,false);
    }
    const inputs=Buffer.alloc(4+cases.length*128);inputs.writeUInt32LE(cases.length);let offset=4;
    for(const c of cases){for(const p of c.tri.p)for(const v of [...p,1]){inputs.writeFloatLE(v,offset);offset+=4;}for(const v of c.tri.id){inputs.writeUInt32LE(v,offset);offset+=4;}for(const a of[[...c.o,0],[...c.d,0],[c.maxT,0,0,0]])for(const v of a){inputs.writeFloatLE(v,offset);offset+=4;}for(const v of[c.global?1:0,0,0,0]){inputs.writeUInt32LE(v,offset);offset+=4;}}
    fs.writeFileSync(path.join(dir,'inputs.bin'),inputs);fs.writeFileSync(path.join(dir,'oracle.json'),JSON.stringify(cases));console.log(`Prepared ${cases.length} exact geometric query cases`);
}else if(mode==='verify'){
    const cases=JSON.parse(fs.readFileSync(path.join(dir,'oracle.json'))),b=fs.readFileSync(path.join(dir,'outputs.bin'));assert.equal(b.length,cases.length*32);let checks=0,maxRelative=0,totalLeaves=0;
    function check(p,s){checks++;assert(p,s);}
    for(let i=0;i<cases.length;i++){
        const c=cases[i],t=b.readFloatLE(i*32),u=b.readFloatLE(i*32+4),v=b.readFloatLE(i*32+8),status=b.readFloatLE(i*32+12),primitive=b.readUInt32LE(i*32+20),visits=b.readUInt32LE(i*32+24);totalLeaves+=visits;
        check(status!==2,`No unreported numeric unknown ${i}`);check((status===1)===!!c.expected,`query ${i} hit mismatch ${status} expected${!!c.expected}`);
        if(c.expected){const error=Math.abs(t-c.expected.t)/Math.max(1e-20,c.expected.t);maxRelative=Math.max(maxRelative,error);check(error<3e-5,`query ${i} nearest t ${t} vs ${c.expected.t}`);check(u>=0&&v>=0&&u+v<=1.0000001,'valid source barycentric support');if(c.global&&!c.edge)check(primitive===c.expected.primitive,'nearest primitive');if(!c.global){check(Math.abs(u-c.expected.b[0])<4e-5&&Math.abs(v-c.expected.b[1])<4e-5,'independent double barycentrics');}}
        if(c.global)check(visits<=count,'stackless termination and primitive bound');
    }
    const result={status:'passed',count:cases.length,checks,maxRelativeError:maxRelative,visitedLeaves:totalLeaves,sceneTriangles:count,scope:'Actual C# BVH output uploaded and actual HLSL stackless traversal/intersection on D3D12 WARP, against independent double Moller-Trumbore brute force. Coverage/material/lighting policy functions are not executed by this geometry-only harness; product shared evaluator is verified separately. No Unity or physical GPU.'};
    fs.writeFileSync(path.join(dir,'oracle-results.json'),JSON.stringify(result,null,2));console.log(JSON.stringify(result));
}else throw Error('prepare|verify expected');
