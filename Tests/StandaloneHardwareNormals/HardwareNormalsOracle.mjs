import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
const [mode,dir]=process.argv.slice(2);
if(!dir)throw Error('prepare|verify artifactDirectory');
const f=Math.fround,unit=v=>{const length=Math.hypot(...v);return v.map(x=>x/length);};
const I=()=>[1,0,0,0,1,0,0,0,1];
const product=(m,v)=>[0,1,2].map(r=>m[r*3]*v[0]+m[r*3+1]*v[1]+m[r*3+2]*v[2]);
const mm=(a,b)=>Array.from({length:9},(_,k)=>[0,1,2].reduce((s,i)=>s+a[Math.floor(k/3)*3+i]*b[i*3+k%3],0));
// The oracle starts with object-to-world source geometry and constructs its
// cofactor inverse-transpose in double. It never implements the shader's
// rescaling/float32 matrix multiply algorithm.
function covector(m){
    const [a,b,c,d,e,g,h,i,j]=m;
    const cof=[e*j-g*i,g*h-d*j,d*i-e*h,c*i-b*j,a*j-c*h,b*h-a*i,b*g-c*e,c*d-a*g,a*e-b*d];
    const determinant=a*cof[0]+b*cof[1]+c*cof[2];
    assert(Number.isFinite(determinant)&&determinant!==0);
    return cof.map(x=>x/determinant);
}
function oracle(world,normals,weights){
    const inverseTranspose=covector(world);
    const perVertex=normals.map(n=>unit(product(inverseTranspose,n)));
    return unit([0,1,2].map(c=>perVertex.reduce((s,n,v)=>s+n[c]*weights[v],0)));
}
let seed=0x6abc137d;
const random=()=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed/4294967296;};
const vector=()=>[0,1,2].map(()=>2*random()-1);
function rotation(){
    const [x,y,z]=unit(vector()),angle=random()*6.2,c=Math.cos(angle),s=Math.sin(angle),v=1-c;
    return [c+x*x*v,x*y*v-z*s,x*z*v+y*s,y*x*v+z*s,c+y*y*v,y*z*v-x*s,z*x*v-y*s,z*y*v+x*s,c+z*z*v];
}
if(mode==='prepare'){
    const inputs=[],cases=[];
    function add(name,world=I(),normals=[[1,0,1],[0,1,1],[0,0,1]],weights=[.25,.25,.5],changes={},valid=true){
        normals=normals.map(n=>n.map(f));weights=weights.map(f);
        const entry={matrix:covector(world).map(f),normals,weights,sourcePresent:1,...changes};
        inputs.push(entry);
        cases.push({name,valid,expected:valid?oracle(world,entry.normals,entry.weights):[0,0,0]});
    }
    add('old-order-regression-3.1766deg',[2,0,0,0,1,0,0,0,1],[[1,0,1],[0,1,1],[0,0,1]].map(unit),[.5,.5,0]);
    add('identity');
    add('mirror',[-2,0,0,0,1,0,0,0,.5]);
    add('shear',[2,.7,-.2,0,.5,.4,0,0,1.2]);
    for(const scale of [1e-30,1e-15,1e15,1e30]){
        add('uniform-scale-'+scale,[scale,0,0,0,scale,0,0,0,scale]);
        add('nonuniform-sheared-scale-'+scale,[scale,.3*scale,0,0,2*scale,.2*scale,0,0,-.5*scale]);
    }
    for(const scale of [1e-30,1e30])add('source-normal-magnitude-'+scale,I(),[[scale,0,scale],[0,scale,scale],[0,0,scale]]);
    for(let n=0;n<4096;n++){
        const magnitude=10**(-25+random()*50),diagonal=[(n%2?-1:1)*(.3+random()*3),0,0,0,.3+random()*3,0,0,0,.3+random()*3];
        const shear=[1,.5*random(),-.5*random(),0,1,.5*random(),0,0,1];
        const world=mm(rotation(),mm(shear,diagonal)).map(x=>x*magnitude);
        const normals=[unit(vector()),unit(vector()),unit(vector())];
        const u=random(),v=random(),weights=[1-Math.sqrt(u),Math.sqrt(u)*(1-v),Math.sqrt(u)*v];
        add('affine-source-'+n,world,normals,weights);
    }
    add('absent-source-normals',I(),undefined,undefined,{sourcePresent:0},false);
    for(let vertex=0;vertex<3;vertex++){
        const normals=[[1,0,1],[0,1,1],[0,0,1]];normals[vertex]=[0,0,0];
        add('zero-source-vertex-'+vertex,I(),normals,undefined,{},false);
    }
    add('zero-source-even-with-zero-weight',I(),[[0,0,0],[0,1,0],[0,0,1]],[0,.5,.5],{},false);
    add('degenerate-interpolation',I(),[[1,0,0],[-1,0,0],[0,1,0]],[.5,.5,0],{},false);
    add('small-nondegenerate-interpolation',I(),[[1,0,0],[-1,0,0],[0,1,0]],[.5,.5-2**-10,2**-10]);
    add('all-zero-weights',I(),undefined,[0,0,0],{},false);
    add('zero-matrix',I(),undefined,undefined,{matrix:Array(9).fill(0)},false);
    add('vertex-maps-to-zero',I(),[[0,1,0],[1,0,0],[0,0,1]],undefined,{matrix:[1,0,0,0,0,0,0,0,1]},false);
    for(const bad of [NaN,Infinity,-Infinity]){
        for(let component=0;component<9;component++){
            const matrix=I();matrix[component]=bad;
            add('bad-matrix-'+String(bad)+'-'+component,I(),undefined,undefined,{matrix},false);
            const normals=[[1,0,1],[0,1,1],[0,0,1]];normals[Math.floor(component/3)][component%3]=bad;
            add('bad-source-'+String(bad)+'-'+component,I(),normals,undefined,{},false);
        }
        for(let component=0;component<3;component++){
            const weights=[.25,.25,.5];weights[component]=bad;
            add('bad-weight-'+String(bad)+'-'+component,I(),undefined,weights,{},false);
        }
    }
    const binary=Buffer.alloc(4+inputs.length*144);binary.writeUInt32LE(inputs.length,0);
    for(let i=0;i<inputs.length;i++){
        const input=inputs[i];let offset=4+i*144;
        // StructuredBuffer column-major float4x4. Translation is irrelevant and zero.
        for(let column=0;column<4;column++)for(let row=0;row<4;row++){
            binary.writeFloatLE(row<3&&column<3?input.matrix[row*3+column]:row===3&&column===3?1:0,offset);offset+=4;
        }
        for(const vector of [...input.normals,input.weights])for(let component=0;component<4;component++){
            binary.writeFloatLE(component<3?vector[component]:0,offset);offset+=4;
        }
        binary.writeUInt32LE(input.sourcePresent,offset);
    }
    fs.writeFileSync(path.join(dir,'inputs.bin'),binary);
    fs.writeFileSync(path.join(dir,'oracle.json'),JSON.stringify({count:cases.length,inputStride:144,outputStride:48,cases},null,2));
    console.log(`Prepared ${cases.length} source-geometry / invalid-input cases.`);
}else if(mode==='verify'){
    const fixture=JSON.parse(fs.readFileSync(path.join(dir,'oracle.json'),'utf8'));
    const output=fs.readFileSync(path.join(dir,'outputs.bin'));
    assert.equal(output.length,fixture.count*48);
    let checks=0,maxComponentError=0,maxAngularErrorDegrees=0,maxUnitLengthError=0,regression=null;
    const require=(condition,message)=>{checks++;assert(condition,message);};
    for(let i=0;i<fixture.count;i++){
        const entry=fixture.cases[i],offset=i*48;
        const actual=[0,1,2].map(c=>output.readFloatLE(offset+c*4));
        const valid=output.readUInt32LE(offset+16)!==0;
        require(valid===entry.valid,`${entry.name}: validity differs (${valid}).`);
        require(actual.every(Number.isFinite),`${entry.name}: nonfinite output.`);
        if(!valid){require(actual.every(x=>x===0),`${entry.name}: invalid output must be zero.`);continue;}
        const error=Math.max(...actual.map((x,c)=>Math.abs(x-entry.expected[c])));
        const lengthError=Math.abs(Math.hypot(...actual)-1);
        const direction=unit(actual),cos=Math.max(-1,Math.min(1,direction.reduce((s,x,c)=>s+x*entry.expected[c],0)));
        const angle=Math.acos(cos)*180/Math.PI;
        maxComponentError=Math.max(maxComponentError,error);maxAngularErrorDegrees=Math.max(maxAngularErrorDegrees,angle);maxUnitLengthError=Math.max(maxUnitLengthError,lengthError);
        require(error<=2e-5,`${entry.name}: normal error ${error}.`);
        require(lengthError<=1e-6,`${entry.name}: normal length error ${lengthError}.`);
        if(i===0){
            const old=[0,1,2].map(c=>output.readFloatLE(offset+32+c*4));
            const oldUnit=unit(old),oldAngle=Math.acos(Math.max(-1,Math.min(1,oldUnit.reduce((s,x,c)=>s+x*entry.expected[c],0))))*180/Math.PI;
            require(oldAngle>3.17&&oldAngle<3.19,'Actual legacy HLSL must reproduce the nonuniform-scale regression.');
            require(angle<.001,'New actual helper did not remove the regression.');
            regression={oldAngularErrorDegrees:oldAngle,newAngularErrorDegrees:angle,old,new:actual,expected:entry.expected};
        }
    }
    const sourceRoot=path.resolve(import.meta.dirname,'../..');
    const trace=fs.readFileSync(path.join(sourceRoot,'Runtime/Resources/HybridLumenGI/HybridLumenGIHardwareTrace.hlsl'),'utf8').replace(/\/\/[^\n]*/g,'').replace(/\s+/g,'');
    const exact=fs.readFileSync(path.join(sourceRoot,'Runtime/Resources/HybridLumenGI/HybridLumenGIExactMesh.hlsl'),'utf8').replace(/\/\/[^\n]*/g,'').replace(/\s+/g,'');
    require(trace.includes('#include"HybridLumenGIExactMesh.hlsl"')&&exact.includes('#include"HybridLumenGIHardwareNormals.hlsl"'),'Trace does not include the executed helper through the shared exact geometry contract.');
    require(trace.includes('normals.face.w>0.5&&HLGITryHardwareShadingNormal((float3x3)instance.normalToWorld,normals.a.xyz,normals.b.xyz,normals.c.xyz,weights,shadingNormal)'),'Trace does not invoke the executed helper under source availability.');
    require(trace.includes('if(!normalValid)shadingNormal=rawNg;')&&trace.includes('if(normalValid)hit.flags|=HLGI_HIT_SHADING_NORMAL;'),'Invalid Ns fallback has lost its explicit flag contract.');
    require(trace.includes('hit.rawNg=rawNg;')&&!trace.includes('rawNg=-rawNg')&&!trace.includes('shadingNormal=-shadingNormal'),'Normal fix changed rawNg/front-back identity.');
    const result={status:'passed',count:fixture.count,checks,maxComponentError,maxAngularErrorDegrees,maxUnitLengthError,regression,
        scope:'Actual DXIL on D3D12 WARP; independent double source object-to-world covector oracle. Source contracts link helper to HardwareTrace. Not Unity, DXR traversal, texture normals or physical GPU.'};
    fs.writeFileSync(path.join(dir,'oracle-results.json'),JSON.stringify(result,null,2));console.log(JSON.stringify(result));
}else throw Error('Unknown mode');
