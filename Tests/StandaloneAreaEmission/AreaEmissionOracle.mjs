import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
const mode=process.argv[2],dir=process.argv[3],F=Math.fround,PI=Math.PI;
const sub=(a,b)=>a.map((x,i)=>x-b[i]),dot=(a,b)=>a.reduce((s,x,i)=>s+x*b[i],0),norm=a=>Math.hypot(...a),cross=(a,b)=>[a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]];
let seed=103729;const random=()=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return(seed>>>8)/16777216;};
const make=(a,b,c,lo,hi,instance,primitive)=>({p0:[...a,norm(cross(sub(b,a),sub(c,a)))/2].map(F),p1:[...b,lo].map(F),p2:[...c,hi].map(F),ng:[0,0,-1,0],identity:[8+instance,2+instance,3,4],geometry:[instance,0,primitive,9]});
const table=[make([-1,-1,2],[0,-1,2],[-1,0,2],0,1/6,0,0),make([0,-1,2],[2,-1,2],[0,1,2],1/6,5/6,0,1),make([-1,0,2],[0,0,2],[-1,1,2],5/6,1,1,0)];
const base=()=>({e:structuredClone(table[0]),origin:[0,0,0,0],point:[0,0,2,0],parameters:[.3,.4,.6,0],control:[0,9,17,0],identity:[8,2,3,4],geometry:[0,0,0,9]});
function solid(e,origin,point){const delta=sub(point,origin),distance=norm(delta);if(distance===0)return{status:0};const direction=delta.map(x=>x/distance),cos=Math.abs(dot(e.ng.slice(0,3),direction))/norm(e.ng.slice(0,3));if(cos===0)return{status:0};return{status:1,distance,direction,pdf:(e.p2[3]-e.p1[3])*distance*distance/(e.p0[3]*cos)};}
function bary(e,p){const a=e.p0.slice(0,3),u=sub(e.p1.slice(0,3),a),v=sub(e.p2.slice(0,3),a),d=sub(p,a),uv=dot(u,v),det=dot(u,u)*dot(v,v)-uv*uv;return[(dot(d,u)*dot(v,v)-dot(d,v)*uv)/det,(dot(d,v)*dot(u,u)-dot(d,u)*uv)/det];}
function le(e,p){const [u,v]=bary(e,p);return 2+.8*u+.5*v;}
function sample(e,xi){const root=Math.sqrt(xi[1]),b=[1-root,root*(1-xi[2]),root*xi[2]];return[0,1,2].map(j=>e.p0[j]*b[0]+e.p1[j]*b[1]+e.p2[j]*b[2]);}
function addRecord(buffer,offset,e){for(const a of [e.p0,e.p1,e.p2,e.ng])for(const v of a){buffer.writeFloatLE(v,offset);offset+=4;}for(const a of [e.identity,e.geometry])for(const v of a){buffer.writeUInt32LE(v>>>0,offset);offset+=4;}return offset;}
if(mode==='prepare'){
    const cases=[];const add=(input,expected)=>cases.push({input,expected});
    for(let k=0;k<1200;k++){
        const input=base(),scale=10**(-4+8*random()),z=(.2+random()*4)*scale;
        input.e=make([0,0,z],[scale,0,z],[0,scale,z],0,1,0,0);
        input.origin=[(random()-.5)*scale,(random()-.5)*scale,0,0].map(F);
        input.point=[random()*scale,random()*scale,z,0].map(F);
        add(input,{...solid(input.e,input.origin.slice(0,3),input.point.slice(0,3)),kind:'pdf'});
    }
    for(const invalid of ['area','cdf','normal','generation','origin','point']){const i=base();if(invalid==='area')i.e.p0[3]=0;if(invalid==='cdf')i.e.p2[3]=0;if(invalid==='normal')i.e.ng=[0,0,0,0];if(invalid==='generation')i.e.geometry[3]=0;if(invalid==='origin')i.origin[0]=Infinity;if(invalid==='point')i.point[1]=NaN;add(i,{kind:'status',status:2});}
    for(const selector of [0,F(1/6)-2**-26,F(1/6),F(5/6),1-2**-24]){const i=base();i.control[0]=1;i.parameters=[selector,.36,.25,0];const index=table.findIndex(e=>selector>=e.p1[3]&&selector<e.p2[3]);add(i,{kind:'sample',index,point:sample(table[index],i.parameters)});}
    for(const bad of [-.1,1,Infinity,NaN]){const i=base();i.control[0]=1;i.parameters[0]=bad;add(i,{kind:'status',status:2});}
    for(let k=0;k<400;k++){const i=base();i.control[0]=4;const a=F(10**(-15+30*random())),b=F(10**(-15+30*random()));i.parameters=[a,b,0,0];add(i,{kind:'balance',weight:a/(a+b),inverse:1/(a+b),valid:true});}
    for(const [a,b,valid]of [[0,1,true],[1,0,true],[0,0,false],[-1,1,false],[Infinity,1,false],[NaN,1,false],[3e38,3e38,true]]){const i=base();i.control[0]=4;i.parameters=[a,b,0,0].map(F);add(i,{kind:'balance',weight:a/(a+b),inverse:1/(a+b),valid});}
    for(let change=0;change<11;change++){const i=base();i.control[0]=2;i.point=[-.5,-.3,2,0];if(change===1)i.geometry[2]=99;if(change===2)i.geometry[0]=7;if(change===3)i.identity[0]++;if(change===4)i.identity[1]++;if(change===5)i.identity[2]++;if(change===6)i.identity[3]++;if(change===7)i.control[1]++;if(change===8)i.geometry[1]++;if(change===9)i.control[2]=1;if(change===10)i.control[2]=16;add(i,{kind:'status',status:change===0?1:[1,2,9].includes(change)?0:2});}
    for(let change=0;change<8;change++){const i=base();i.control[0]=3;i.parameters=[.01,.25,.5,0];i.point=[0,0,0,0];if(change===1)i.identity[1]++;if(change===2)i.geometry[2]++;if(change===3)i.control[1]++;if(change===4)i.point[2]=-.01;if(change===5)i.point[3]=-.01;if(change===6)i.control[2]=1;if(change===7)i.point[0]=NaN;add(i,{kind:'match',match:change===0});}
    const samples=22000,areaStart=cases.length;
    for(let k=0;k<samples;k++){const i=base();i.control[0]=1;i.parameters=[random(),random(),random(),0];add(i,{kind:'integration-area'});}
    const directionStart=cases.length;
    for(let k=0;k<samples;k++){
        const u=random(),v=random(),d=[Math.sqrt(u)*Math.cos(2*PI*v),Math.sqrt(u)*Math.sin(2*PI*v),Math.sqrt(1-u)];const point=d.map(x=>x*2/d[2]);let index=-1;
        for(let j=0;j<table.length;j++){const b=bary(table[j],point);if(b[0]>=0&&b[1]>=0&&b[0]+b[1]<=1){index=j;break;}}
        const i=base();i.control[0]=2;i.point=[...point.map(F),0];i.geometry=index>=0?table[index].geometry:[99,0,99,9];i.identity=index>=0?table[index].identity:[0,0,0,0];add(i,{kind:'integration-direction',index,direction:d});
    }
    // Independent area integral using midpoint quadrature in uniform square coordinates.
    let exact=0;const grid=500;
    for(const e of table){let sum=0;for(let y=0;y<grid;y++)for(let x=0;x<grid;x++){
        const p=sample(e,[0,(y+.5)/grid,(x+.5)/grid]),r=norm(p),cos=p[2]/r;sum+=le(e,p)*cos*cos/(PI*r*r);
    }exact+=e.p0[3]*sum/(grid*grid);}
    const data=Buffer.alloc(4+cases.length*192);data.writeUInt32LE(cases.length);let offset=4;
    for(const {input:i}of cases){offset=addRecord(data,offset,i.e);for(const a of[i.origin,i.point,i.parameters])for(const v of a){data.writeFloatLE(v,offset);offset+=4;}for(const a of[i.control,i.identity,i.geometry])for(const v of a){data.writeUInt32LE(v>>>0,offset);offset+=4;}}
    const emitters=Buffer.alloc(4+table.length*96);emitters.writeUInt32LE(table.length);offset=4;for(const e of table)offset=addRecord(emitters,offset,e);
    // Keep binary input as evidence for nonfinite fixtures; JSON only contains expected values.
    fs.writeFileSync(path.join(dir,'inputs.bin'),data);fs.writeFileSync(path.join(dir,'emitters.bin'),emitters);
    fs.writeFileSync(path.join(dir,'oracle.json'),JSON.stringify({cases:cases.map(x=>x.expected),samples,areaStart,directionStart,exact,table}));console.log(`Prepared ${cases.length} cases`);
}else if(mode==='verify'){
    const oracle=JSON.parse(fs.readFileSync(path.join(dir,'oracle.json'))),out=fs.readFileSync(path.join(dir,'outputs.bin'));assert.equal(out.length,oracle.cases.length*64);let checks=0,maxRelative=0;
    const check=(x,s)=>{checks++;assert(x,s);},near=(a,b,t=8e-5)=>{const error=Math.abs(a-b)/Math.max(1e-30,Math.abs(b));maxRelative=Math.max(maxRelative,error);check(Number.isFinite(a)&&error<=t,`${a} != ${b}; relative ${error}`);};
    const result=i=>({direction:[0,1,2].map(j=>out.readFloatLE(i*64+j*4)),distance:out.readFloatLE(i*64+12),point:[0,1,2].map(j=>out.readFloatLE(i*64+16+j*4)),pdf:out.readFloatLE(i*64+28),weight:out.readFloatLE(i*64+32),inverse:out.readFloatLE(i*64+36),status:out.readUInt32LE(i*64+48),index:out.readUInt32LE(i*64+52),match:out.readUInt32LE(i*64+56)!==0});
    let areaSum=0,areaSq=0,directionSum=0,directionSq=0,plainSum=0,plainSq=0;
    for(let k=0;k<oracle.cases.length;k++){const e=oracle.cases[k],o=result(k);
        if(e.kind==='status')check(o.status===e.status,`status case${k}: ${o.status} != ${e.status}`);
        else if(e.kind==='pdf'){check(o.status===e.status,`pdf status ${k}`);near(o.pdf,e.pdf);near(o.distance,e.distance);for(let j=0;j<3;j++)check(Math.abs(o.direction[j]-e.direction[j])<4e-6,'direction');}
        else if(e.kind==='sample'){check(o.status===1&&o.index===e.index,'CDF boundary');for(let j=0;j<3;j++)check(Math.abs(o.point[j]-e.point[j])<2e-6,'uniform area point');near(o.pdf,solid(table[o.index],[0,0,0],o.point).pdf);}
        else if(e.kind==='balance'){check(o.match===e.valid,'balance validity');if(e.valid){near(o.weight,e.weight,3e-6);if(e.inverse<1.17549435e-38)check(Math.abs(o.inverse-e.inverse)<1.17549435e-38,'float32 subnormal inverse may flush to zero');else near(o.inverse,e.inverse,3e-6);}}
        else if(e.kind==='match')check(o.match===e.match,'exact endpoint identity/nearest match');
        else if(e.kind==='integration-area'){check(o.status===1,'area sample');const pb=Math.max(0,o.direction[2])/PI,Le=le(table[o.index],o.point),value=Le*pb/(pb+o.pdf);areaSum+=value;areaSq+=value*value;}
        else if(e.kind==='integration-direction'){check(o.status===(e.index<0?0:1),'direction hit lookup');const pb=e.direction[2]/PI,Le=e.index<0?0:le(table[e.index],e.direction.map(x=>2*x/e.direction[2]));const value=Le*pb/(pb+o.pdf);directionSum+=value;directionSq+=value*value;plainSum+=Le;plainSq+=Le*Le;}
    }
    const n=oracle.samples,meanA=areaSum/n,meanB=directionSum/n,mean=meanA+meanB,varianceA=areaSq/n-meanA*meanA,varianceB=directionSq/n-meanB*meanB,standardError=Math.sqrt((varianceA+varianceB)/n),plain=plainSum/n;
    check(Math.abs(mean-oracle.exact)<=6*standardError+2e-5,'paired light + direction estimates must integrate one Le');
    const report={status:'passed',count:oracle.cases.length,checks,maxRelativeError:maxRelative,mis:{estimate:mean,reference:oracle.exact,standardError,area:meanA,direction:meanB,plainDirection:plain,pairedVariance:varianceA+varianceB,plainVariance:plainSq/n-plain*plain,samplesPerTechnique:n},scope:'Actual AreaEmission HLSL WARP sampling/PDF/identity/MIS arithmetic; independent double area quadrature. Textured Le is an analytic UV signal for estimator validation, not execution of Unity materials, RTAS, SDF or product visibility.'};
    fs.writeFileSync(path.join(dir,'oracle-results.json'),JSON.stringify(report,null,2));console.log(JSON.stringify(report));
}else throw new Error('prepare|verify expected');
