import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
const [mode,dir]=process.argv.slice(2);if(!dir)throw Error('prepare|verify artifactDirectory');
const f=Math.fround;
const I=()=>[1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1];
const mul=(a,b)=>Array.from({length:16},(_,k)=>{const r=Math.floor(k/4),c=k%4;return [0,1,2,3].reduce((s,i)=>s+a[4*r+i]*b[4*i+c],0);});
const point=(a,p)=>[0,1,2].map(r=>a[4*r]*p[0]+a[4*r+1]*p[1]+a[4*r+2]*p[2]+a[4*r+3]);
const norm=v=>{const s=Math.hypot(...v);return v.map(x=>x/s);};
// Independent double-precision 3x3 inverse-transpose source-normal oracle.
function normal(m,n){
    const a=m[0],b=m[1],c=m[2],d=m[4],e=m[5],g=m[6],h=m[8],i=m[9],j=m[10];
    const cof=[e*j-g*i,g*h-d*j,d*i-e*h,c*i-b*j,a*j-c*h,b*h-a*i,b*g-c*e,c*d-a*g,a*e-b*d];
    const determinant=a*cof[0]+b*cof[1]+c*cof[2];
    return norm([0,1,2].map(r=>(cof[r*3]*n[0]+cof[r*3+1]*n[1]+cof[r*3+2]*n[2])/determinant));
}
function transform(angle,axis,scale,t){
    const [x,y,z]=norm(axis),c=Math.cos(angle),s=Math.sin(angle),v=1-c;
    return [(x*x*v+c)*scale,(x*y*v-z*s)*scale,(x*z*v+y*s)*scale,t[0],
        (y*x*v+z*s)*scale,(y*y*v+c)*scale,(y*z*v-x*s)*scale,t[1],
        (z*x*v-y*s)*scale,(z*y*v+x*s)*scale,(z*z*v+c)*scale,t[2],0,0,0,1];
}
let seed=0x315bfa97;const random=()=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed/4294967296;};
const vector=(scale=1)=>[0,1,2].map(()=>scale*(2*random()-1));
if(mode==='prepare'){
    const cases=[];
    function add(name,data={},eligible=true,match=true,expected=null){
        const entry={name,matrix:I(),key:[0xffffffff,0x80000000],flags:1,identity:[0xffffffff,0x80000000,7,1],candidate:[1,0,7,0],position:[2,-3,4],ns:norm([1,2,3]),ng:norm([-3,1,2]),previous:[0xffffffff,0x80000000,7,1],...data};
        cases.push({entry,eligible,match,expected:expected??(eligible?[...entry.position,...norm(entry.ns),...norm(entry.ng)]:null)});
    }
    add('identity-row-and-high-key');
    for(let n=0;n<2048;n++){
        // Current source may contain nonuniform scale and a constant reflection.
        // Relative motion A is positive similarity, exactly the CPU eligibility contract.
        let current=transform(random()*6.2,vector(),1,vector(30));
        const diagonal=I();diagonal[0]=(n%2?-1:1)*(.4+random()*3);diagonal[5]=.4+random()*3;diagonal[10]=.4+random()*3;
        current=mul(current,diagonal);
        const A=transform(random()*6.2,vector(),.2+random()*4,vector(15)).map(f);
        const previous=mul(A,current),local=vector(4),localNs=norm(vector()),localNg=norm(vector());
        // Expected results are independently reconstructed from previous source geometry,
        // not from reproducing the shader's A*current-normal computation.
        const expected=[...point(previous,local),...normal(previous,localNs),...normal(previous,localNg)];
        add('source-transform-'+n,{matrix:A,position:point(current,local).map(f),ns:normal(current,localNs).map(f),ng:normal(current,localNg).map(f)},true,true,expected);
    }
    for(let bit=0;bit<32;bit++){
        const key=[((2**bit)>>>0),((2**((bit+13)%32))>>>0)],id=[...key,bit+1,1];
        add('key-bit-'+bit,{key,identity:id,candidate:[1,0,bit+1,0],previous:id});
        add('high-key-mismatch-'+bit,{key:[key[0],(key[1]^1)>>>0],identity:id,candidate:[1,0,bit+1,0],previous:id},false,true);
        add('previous-high-mismatch-'+bit,{key,identity:id,candidate:[1,0,bit+1,0],previous:[key[0],(key[1]^1)>>>0,bit+1,1]},true,false);
    }
    const invalid=[
        ['identity-invalid',{identity:[0xffffffff,0x80000000,7,0]},false],
        ['identity-valid-marker-two',{identity:[0xffffffff,0x80000000,7,2]},false],
        ['identity-zero-key',{identity:[0,0,7,1],key:[0,0]},false],
        ['identity-zero-primitive',{identity:[0xffffffff,0x80000000,0,1],candidate:[1,0,0,0]},false],
        ['candidate-zero-owner',{candidate:[0,0,7,0]},true],
        ['candidate-conflict',{candidate:[1,1,7,0]},true],
        ['candidate-conflict-highbit',{candidate:[1,0x80000000,7,0]},true],
        ['candidate-other-primitive',{candidate:[1,0,8,0]},true],
        ['previous-not-eligible',{flags:0},true],
        ['wrong-flag-only',{flags:2},true],
        ['zero-shading-normal',{ns:[0,0,0]},true],
        ['zero-geometric-normal',{ng:[0,0,0]},true],
        ['tiny-shading-normal',{ns:[1e-10,0,0]},true],
        ['tiny-geometric-normal',{ng:[0,1e-10,0]},true]
    ];for(const [name,data,match] of invalid)add(name,data,false,match);
    for(const value of [NaN,Infinity,-Infinity])for(const field of ['position','ns','ng']){
        add('nonfinite-'+String(value)+'-'+field,{[field]:[value,0,1]},false,true);
    }
    for(const [name,index,value] of [['translation-infinity',3,Infinity],['matrix-nan',5,NaN],['non-affine-w',15,1.001],['overflow-normal',0,1e30]]){
        const matrix=I();matrix[index]=value;add(name,{matrix},false,true);
    }
    for(const [name,matrix] of [['relative-nonuniform',[2,0,0,0,0,1,0,0,0,0,.5,0,0,0,0,1]],['relative-mirror',[-1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1]]]){
        add(name+'-cpu-flag-rejected',{matrix,flags:0},false,true);
    }
    add('unrelated-flags-preserved',{flags:0x80000001});
    add('previous-primitive-mismatch',{previous:[0xffffffff,0x80000000,8,1]},true,false);
    add('previous-invalid',{previous:[0xffffffff,0x80000000,7,0]},true,false);
    add('previous-valid-marker-two',{previous:[0xffffffff,0x80000000,7,2]},true,false);
    add('small-usable-normals',{ns:[1e-7,0,0],ng:[0,1e-7,0]});
    const bytes=Buffer.alloc(4+176*cases.length);bytes.writeUInt32LE(cases.length,0);
    for(let index=0;index<cases.length;index++){
        const c=cases[index].entry,base=4+176*index;
        // Unity Matrix4x4 native memory and HLSL column_major layout: columns contiguous.
        for(let col=0;col<4;col++)for(let row=0;row<4;row++)bytes.writeFloatLE(c.matrix[row*4+col],base+4*(col*4+row));
        c.key.forEach((x,i)=>bytes.writeUInt32LE(x>>>0,base+64+4*i));bytes.writeUInt32LE(c.flags>>>0,base+72);
        c.identity.forEach((x,i)=>bytes.writeUInt32LE(x>>>0,base+80+4*i));c.candidate.forEach((x,i)=>bytes.writeUInt32LE(x>>>0,base+96+4*i));
        for(const [field,offset] of [['position',112],['ns',128],['ng',144]])c[field].forEach((x,i)=>bytes.writeFloatLE(x,base+offset+4*i));
        c.previous.forEach((x,i)=>bytes.writeUInt32LE(x>>>0,base+160+4*i));
    }
    const reference={count:cases.length,inputStride:176,outputStride:64,scope:'Double source-geometry oracle; relative positive similarities only. Flags0 cases cover CPU-rejected nonuniform/relative mirror; no claim of arbitrary affine shader normal transport.',cases:cases.map(({entry,eligible,match,expected},index)=>({index,name:entry.name,eligible,match,expected}))};
    fs.writeFileSync(path.join(dir,'inputs.bin'),bytes);fs.writeFileSync(path.join(dir,'oracle.json'),JSON.stringify(reference,null,2));
    console.log(`Prepared ${cases.length} cases from independent double source-transform oracle; 80-byte column-major row inside 176-byte input.`);
}else if(mode==='verify'){
    const reference=JSON.parse(fs.readFileSync(path.join(dir,'oracle.json'),'utf8')),bytes=fs.readFileSync(path.join(dir,'outputs.bin'));
    assert.equal(bytes.length,reference.count*64,'all WARP output rows written');let checks=1,maxPositionError=0,maxNormalError=0;
    for(const c of reference.cases){
        const base=c.index*64;assert.equal(bytes.readUInt32LE(base+48),c.eligible?1:0,c.name+' actual eligibility');checks++;
        assert.equal(bytes.readUInt32LE(base+52),c.match?1:0,c.name+' actual history identity');checks++;
        assert.equal(bytes.readUInt32LE(base+56),0,c.name+' reserved0');assert.equal(bytes.readUInt32LE(base+60),0,c.name+' reserved1');checks+=2;
        if(c.eligible)for(let i=0;i<9;i++){
            const offset=16*Math.floor(i/3)+4*(i%3),actual=bytes.readFloatLE(base+offset),expected=c.expected[i],error=Math.abs(actual-expected);
            assert.ok(Number.isFinite(actual),c.name+' finite output');checks++;
            const tolerance=i<3?2e-4+3e-6*Math.abs(expected):3e-5;
            assert.ok(error<=tolerance,`${c.name} component ${i}: actual=${actual} expected=${expected} error=${error} tolerance=${tolerance}`);checks++;
            if(i<3)maxPositionError=Math.max(maxPositionError,error);else maxNormalError=Math.max(maxNormalError,error);
        }
    }
    const result={status:'passed',count:reference.count,checks,maxPositionError,maxNormalError,scope:'Actual DXIL helper results read back from D3D12 WARP and compared with independent double source-geometry oracle. Not Unity, raster identity ownership, RenderGraph barriers or physical GPU validation.'};
    fs.writeFileSync(path.join(dir,'oracle-results.json'),JSON.stringify(result,null,2));console.log(JSON.stringify(result));
}else throw Error('Expected prepare or verify');
