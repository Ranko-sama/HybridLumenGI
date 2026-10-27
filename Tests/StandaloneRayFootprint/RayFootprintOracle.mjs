import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
const [mode,dir]=process.argv.slice(2);if(!dir)throw Error('prepare|verify artifactDirectory');
const f=Math.fround,add=(a,b)=>a.map((x,i)=>x+b[i]),sub=(a,b)=>a.map((x,i)=>x-b[i]);
const mul=(a,s)=>a.map(x=>x*s),dot=(a,b)=>a.reduce((s,x,i)=>s+x*b[i],0),norm=a=>Math.hypot(...a);
const cross=(a,b)=>[a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]];
const unit=a=>mul(a,1/norm(a)),project=(v,d)=>sub(v,mul(d,dot(v,d)));
const I=[1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1];
function solve(rows,rhs){
    // Independent double Gaussian elimination, not the shader's projected Gram inverse.
    const m=rows.map((r,i)=>[...r,rhs[i]]);
    for(let c=0;c<3;c++){
        let pivot=c;for(let i=c+1;i<3;i++)if(Math.abs(m[i][c])>Math.abs(m[pivot][c]))pivot=i;
        assert(Math.abs(m[pivot][c])>0);[m[c],m[pivot]]=[m[pivot],m[c]];
        const divisor=m[c][c];for(let k=c;k<4;k++)m[c][k]/=divisor;
        for(let r=0;r<3;r++)if(r!==c){const a=m[r][c];for(let k=c;k<4;k++)m[r][k]-=a*m[c][k];}
    }return m.map(row=>row[3]);
}
const row=(m,r)=>m.slice(r*4,r*4+3),transform=(m,p)=>[0,1,2].map(r=>dot(row(m,r),p)+m[r*4+3]);
function expected(i){
    const op=i.control[0],p=i.p,par=i.parameters;
    if(op===0){const radius=p[0]+p[1]*f(par[0]+par[1]);return [radius,p[1]];}
    if(op===1)return [0,Math.tan(par[0]*.5)];
    if(op===2){
        const u=mul(sub(i.pX,p),.5*par[2]/par[0]),v=mul(sub(i.pY,p),.5*par[3]/par[1]),d=unit(i.direction);
        return [Math.max(...[-1,1].flatMap(s=>[-1,1].map(t=>norm(project(add(mul(u,s),mul(v,t)),d))))),0];
    }
    if(op===3){
        const grid=i.control[1],cell=i.control.slice(2),size=i.auxiliary.slice(0,2),uv=transform(i.matrix,p),n=unit(i.normal),d=unit(i.direction);
        const low=cell.map((c,j)=>Math.floor(c*size[j]/grid)/size[j]),high=cell.map((c,j)=>Math.floor((c+1)*size[j]/grid)/size[j]);
        const corners=[low[0],high[0]].flatMap(u=>[low[1],high[1]].map(v=>solve([row(i.matrix,0),row(i.matrix,1),n],[u-uv[0],v-uv[1],0])));
        return [Math.max(...corners.map(v=>norm(project(v,d)))),0];
    }
    if(op===4){
        const source=unit(i.direction),target=unit(i.auxiliary),n=unit(i.normal);
        const helper=Math.abs(source[0])<.7?[1,0,0]:[0,1,0],u=unit(cross(source,helper)),v=cross(source,u);
        let greatest=0;
        // Trace 8,192 perimeter rays onto the plane. No covariance/eigenvalue formula.
        for(let k=0;k<8192;k++){
            const angle=k*2*Math.PI/8192,q=add(mul(u,Math.cos(angle)),mul(v,Math.sin(angle)));
            const t=-dot(q,n)/dot(source,n),hit=add(q,mul(source,t));greatest=Math.max(greatest,norm(project(hit,target)));
        }
        return [p[0]*greatest,0];
    }
    if(op===5)return [p[0],-p[0]/par[0]];
    if(op===6)return [p[0],0];throw Error('op');
}
let seed=0x790acd12;const random=()=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed/4294967296;};
const vec=()=>[0,1,2].map(()=>2*random()-1);
function rotation(){const [x,y,z]=unit(vec()),a=random()*6.2,c=Math.cos(a),s=Math.sin(a),v=1-c;return [[c+x*x*v,x*y*v-z*s,x*z*v+y*s],[y*x*v+z*s,c+y*y*v,y*z*v-x*s],[z*x*v-y*s,z*y*v+x*s,c+z*z*v]];}
if(mode==='prepare'){
    const inputs=[],cases=[];
    function addCase(name,op,change={},valid=true,otherValid=false,other=null){
        const i={matrix:I,p:[1,.2,0],pX:[1,0,0],pY:[0,1,0],direction:[0,0,1],normal:[0,0,1],auxiliary:[16,16,0],parameters:[1,0,1,1],control:[op,1,0,0],...change};
        for(const key of ['matrix','p','pX','pY','direction','normal','auxiliary','parameters'])i[key]=i[key].map(f);
        const value=valid?expected(i):[0,0];
        inputs.push(i);cases.push({name,op,valid,otherValid,expected:value,other:otherValid?(other??value):[0,0]});return i;
    }
    for(let k=0;k<256;k++){
        const scale=10**(-18+36*random()),r=f(scale*(.2+random())),s=f(random()*4),a=f(scale*random()),b=f(scale*random());
        addCase('advance-split-'+k,0,{p:[r,s,0],parameters:[a,b,0,0]},true,true,[r+s*(a+b),s]);
    }
    addCase('zero-radius-valid',0,{p:[0,1,0],parameters:[2,3,0,0]},true,true,[5,1]);
    addCase('far-shift-continuity',0,{p:[.25,.125,0],parameters:[1000,3,0,0]},true,true,[125.625,.125]);
    addCase('converging-focus',0,{p:[2,-.5,0],parameters:[2,2,0,0]},true,true,[0,-.5]);
    addCase('beyond-focus-invalid',0,{p:[2,-.5,0],parameters:[2,3,0,0]},false,false);
    for(const p of [[-1,0,0],[NaN,0,0],[1,Infinity,0],[3e38,3e38,0]])addCase('invalid-cone-'+p,0,{p,parameters:[3,1,0,0]},false);
    for(const d of [-1,NaN,Infinity])addCase('invalid-distance-'+d,0,{parameters:[d,0,0,0]},false);
    for(const flag of [0,2,0xffffffff])addCase('invalid-validity-'+flag,0,{control:[0,flag,0,0]},false);
    for(let k=0;k<80;k++)addCase('angle-'+k,1,{parameters:[k/80*3.1,0,0,0]});
    for(const angle of [-1,NaN,Infinity,f(Math.PI),4])addCase('invalid-full-angle-'+angle,1,{parameters:[angle,0,0,0]},false);
    for(let k=0;k<512;k++){
        const scale=10**(-12+24*random()),r=rotation(),p=vec().map(x=>x*scale),u=mul(r[0],scale),v=mul(add(r[1],mul(r[0],random()*.8)),scale*(.3+random()*2));
        const dx=k%2?-1:1,dy=k%3?-2:3;
        addCase('screen-'+k,2,{p,pX:add(p,mul(u,dx)),pY:add(p,mul(v,dy)),direction:vec(),parameters:[dx,dy,k%4?1:2,k%4?1:3]});
    }
    for(const change of [{pX:[0,0,0],p:[0,0,0]},{p:[0,0,0],pX:[1,0,0],pY:[2,0,0]},
        {parameters:[0,1,1,1]},{parameters:[1,1,0,1]},{direction:[0,0,0]},{p:[NaN,0,0]}])addCase('invalid-screen-'+cases.length,2,change,false);
    for(let k=0;k<256;k++){
        const scale=10**(-10+20*random()),r=rotation(),a=mul(r[0],scale),b=mul(add(r[1],mul(r[0],random())),scale*(.3+random()*2)),c=mul(r[2],scale);
        const forward=[0,1,2].map(j=>[a[j],b[j],c[j]]),inverse=[0,1,2].map(j=>solve(forward,[j===0?1:0,j===1?1:0,j===2?1:0]));
        const m=Array.from({length:16},(_,i)=>i===15?1:i%4===3||i>=12?0:inverse[i%4][Math.floor(i/4)]);
        const grid=1+k%4,size=[13+k%7,17+k%9],cell=[k%grid,(k*7)%grid],low=cell.map((x,j)=>Math.floor(x*size[j]/grid)/size[j]),high=cell.map((x,j)=>Math.floor((x+1)*size[j]/grid)/size[j]);
        const uv=low.map((x,j)=>x+(high[j]-x)*(.05+.9*random())),anchor=forward.map(row=>dot(row,[...uv,.5]));
        addCase('card-odd-offcenter-'+k,3,{matrix:m,p:anchor,normal:cross(a,b),auxiliary:[...size,0],direction:vec(),control:[3,grid,...cell]});
    }
    addCase('anchor-cell-center',3,{p:[.125,.125,.5],auxiliary:[128,128,0],control:[3,4,0,0]});
    addCase('anchor-cell-edge',3,{p:[0,0,.5],auxiliary:[128,128,0],control:[3,4,0,0]});
    for(const change of [{control:[3,0,0,0]},{control:[3,4,4,0]},{control:[3,4,0,0],auxiliary:[1,1,0]},
        {auxiliary:[0,16,0]},{p:[1.1,0,.5]},{normal:[1,0,0]},{matrix:I.map((x,j)=>j===12?.1:x)},
        {matrix:I.map((x,j)=>j===0?Infinity:x)}])addCase('invalid-card-'+cases.length,3,change,false);
    for(let k=0;k<128;k++){
        const n=unit(vec());let incoming=unit(vec());if(Math.abs(dot(n,incoming))<.1)incoming=n;
        addCase('retarget-ellipse-'+k,4,{p:[10**(-10+random()*20),.2,0],direction:incoming,normal:n,auxiliary:vec()});
    }
    addCase('retarget-grazing-reject',4,{direction:[1,0,0],normal:[0,0,1],auxiliary:[0,0,1]},false);
    addCase('retarget-zero-radius-known',4,{p:[0,0,0],direction:[0,0,1],normal:[0,0,1],auxiliary:[0,0,1]});
    for(let k=0;k<128;k++){
        // Dyadic point-light parameters give an exact endpoint and pre-end domain.
        const radius=2**(k%20-10),L=2**(k%18-9),fraction=(k%17)/16;
        addCase('point-shadow-'+k,5,{p:[radius,.7,0],parameters:[L,L*fraction,0,0]},true,true,[radius*(1-fraction),-radius/L]);
        addCase('directional-shadow-'+k,6,{p:[radius,.7,0],parameters:[L,L*100,0,0]},true,true,[radius,0]);
    }
    addCase('point-shadow-past-light',5,{p:[1,0,0],parameters:[1,2,0,0]},true,false);
    for(const L of [0,-1,NaN,Infinity])addCase('invalid-point-distance-'+L,5,{parameters:[L,0,0,0]},false,false);
    const bytes=Buffer.alloc(4+inputs.length*192);bytes.writeUInt32LE(inputs.length);let offset=4;
    for(const i of inputs){
        for(let c=0;c<4;c++)for(let r=0;r<4;r++){bytes.writeFloatLE(i.matrix[r*4+c],offset);offset+=4;}
        for(const key of ['p','pX','pY','direction','normal','auxiliary','parameters'])for(let j=0;j<4;j++){bytes.writeFloatLE(i[key][j]??0,offset);offset+=4;}
        for(let j=0;j<4;j++){bytes.writeUInt32LE(i.control[j]>>>0,offset);offset+=4;}
    }
    fs.writeFileSync(path.join(dir,'inputs.bin'),bytes);fs.writeFileSync(path.join(dir,'oracle.json'),JSON.stringify({count:cases.length,cases}));
    console.log(JSON.stringify({prepared:cases.length,bytes:bytes.length}));
}else if(mode==='verify'){
    const data=JSON.parse(fs.readFileSync(path.join(dir,'oracle.json'),'utf8')),bytes=fs.readFileSync(path.join(dir,'outputs.bin'));
    assert.equal(bytes.length,data.count*48);let checks=0,maxRelativeError=0,worstCase='';
    function check(ok,why){checks++;assert(ok,why);}
    for(let k=0;k<data.count;k++){
        const item=data.cases[k],off=k*48,values=Array.from({length:8},(_,j)=>bytes.readFloatLE(off+j*4)),flags=Array.from({length:4},(_,j)=>bytes.readUInt32LE(off+32+j*4));
        check(flags[0]===(item.valid?1:0),item.name+' known');check(flags[1]===(item.otherValid?1:0),item.name+' secondary known');
        check(flags[2]===flags[0]&&flags[3]===flags[1],item.name+' validity payload');
        for(const [base,expected,valid] of [[0,item.expected,item.valid],[4,item.other,item.otherValid]]){
            for(let j=0;j<2;j++){
                const actual=values[base+j],reference=expected[j];check(Number.isFinite(actual),item.name+' finite');
                const error=Math.abs(actual-reference)/Math.max(1e-30,Math.abs(reference));
                if(valid&&reference!==0&&error>maxRelativeError){maxRelativeError=error;worstCase=item.name;}
                const tolerance=valid?Math.max(2e-30,Math.abs(reference)*1.5e-4):0;
                check(Math.abs(actual-reference)<=tolerance,item.name+' value '+j+': '+actual+' vs '+reference);
            }
            check(values[base+2]===0&&values[base+3]===0,item.name+' reserved zero');
        }
    }
    const edge=data.cases.findIndex(x=>x.name==='anchor-cell-edge'),center=data.cases.findIndex(x=>x.name==='anchor-cell-center');
    check(bytes.readFloatLE(edge*48)>bytes.readFloatLE(center*48)*1.99,'off-center patch footprint is not assumed centered');
    const result={status:'passed',count:data.count,checks,maxRelativeError,worstCase,scope:'Actual runtime HLSL on D3D12 WARP; geometry-only radius/slope, projection and shadow convergence. Diffuse angular model pending. No Unity/transport integration/physical GPU.'};
    fs.writeFileSync(path.join(dir,'oracle-results.json'),JSON.stringify(result,null,2));console.log(JSON.stringify(result));
}else throw Error('unknown mode');
