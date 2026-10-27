// Independent octahedron oracle, explicit float32 arithmetic, and source contracts.
// This does not execute HLSL, Unity, texture filtering, or a GPU.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
const source=readFileSync(new URL('../Runtime/Resources/HybridLumenGI/HybridLumenGIScreenGeometry.hlsl',import.meta.url),'utf8');
let assertions=0;
function check(condition,message) { assertions++;assert.ok(condition,message); }
const f=Math.fround,add=(a,b)=>f(f(a)+f(b)),sub=(a,b)=>f(f(a)-f(b)),mul=(a,b)=>f(f(a)*f(b));
const dot32=(a,b)=>add(add(mul(a[0],b[0]),mul(a[1],b[1])),mul(a[2],b[2]));
const dot=(a,b)=>a.reduce((s,x,i)=>s+x*b[i],0);
const unit=a=>{const l=Math.hypot(...a);return a.map(x=>x/l);};
const finite=a=>a.every(Number.isFinite);
const sign=x=>x<0?-1:1;
const clamp=x=>Math.max(0,Math.min(1,x));

// Independent double-precision geometric definition: project onto the L1
// octahedron and fold its lower four faces onto the square. No Unity helper code.
function oracleEncode(normal) {
    const denominator=normal.reduce((s,x)=>s+Math.abs(x),0);
    const [x,y,z]=normal.map(v=>v/denominator);
    return z>=0?[x,y]:[(1-Math.abs(y))*sign(x),(1-Math.abs(x))*sign(y)];
}
function oracleDecode(oct) {
    let [x,y]=oct,z=1-Math.abs(x)-Math.abs(y);
    if(z<0) [x,y]=[(1-Math.abs(y))*sign(x),(1-Math.abs(x))*sign(y)];
    return unit([x,y,z]);
}
function normalize32(value) {
    value=value.map(f);const lengthSquared=dot32(value,value);
    if(!finite(value)||!Number.isFinite(lengthSquared)||lengthSquared<f(1e-12)) return null;
    const inverse=f(1/Math.sqrt(lengthSquared));
    return value.map(x=>mul(x,inverse));
}
// Float32 model of the public Unity oct helpers used by the source. The oracle
// above uses the unfolded geometry instead of these optimized arithmetic steps.
function encode32(n) {
    const inverse=f(1/Math.max(add(add(Math.abs(n[0]),Math.abs(n[1])),Math.abs(n[2])),f(1e-6)));
    n=n.map(x=>mul(x,inverse));const t=clamp(-n[2]);
    return [add(n[0],n[0]>=0?t:-t),add(n[1],n[1]>=0?t:-t)];
}
function decode32(oct) {
    const n=[...oct,sub(sub(1,Math.abs(oct[0])),Math.abs(oct[1]))],t=Math.max(-n[2],0);
    n[0]=add(n[0],n[0]>=0?-t:t);n[1]=add(n[1],n[1]>=0?-t:t);
    return normalize32(n);
}
function validDepth(d,reverse) {
    return Number.isFinite(d)&&d>=0&&d<=1&&(reverse?d>f(1e-6):d<sub(1,1e-6));
}
function pack(ns,ng,hasNg,depth,reverse=true) {
    depth=f(depth);ns=normalize32(ns);
    if(!validDepth(depth,reverse)||ns===null) return [0,0,0,0];
    let code=-1;
    if(hasNg&&(ng=normalize32(ng))!==null) {
        const q=encode32(ng).map(v=>Math.floor(add(mul(clamp(add(mul(v,.5),.5)),4095),.5)));
        code=f(q[0]+q[1]*4096+1);
    }
    return [...encode32(ns),code,depth];
}
function decode(packed,reverse=true) {
    packed=packed.map(f);const empty={valid:false,ns:[0,0,0],ng:[0,0,0],hasNg:false};
    if(!finite(packed)||packed.slice(0,2).some(v=>Math.abs(v)>1)||!validDepth(packed[3],reverse)) return empty;
    const code=packed[2],known=code>=1&&code<=16777216&&Math.floor(code)===code;
    if(code!==-1&&!known) return empty;
    const ns=decode32(packed.slice(0,2));
    if(!known) return {valid:true,ns,ng:[0,0,0],hasNg:false};
    const integer=code-1,q=[integer%4096,Math.floor(integer/4096)];
    const oct=q.map(v=>sub(mul(v,f(2/4095)),1));
    return {valid:true,ns,ng:decode32(oct),hasNg:true};
}

// Exhaustively verify the ENTIRE code domain, including the 2^24 endpoint.
// Integer division is an independent oracle for the shader's mask/shift pair.
for(let integer=0;integer<16777216;integer++) {
    const stored=f(integer+1),recovered=stored-1;
    check(stored===integer+1&&recovered===integer,'A legal numeric code lost float32 precision.');
    check((recovered&4095)===integer%4096&&(recovered>>>12)===Math.floor(integer/4096),'Oct components failed exact recovery.');
}
check(f(16777217)===16777216,'Float32 domain endpoint assumption changed.');
check(pack([0,0,1],[0,0,-1],true,.5)[2]===16777216,'South pole +/+ corner must exercise maximum code.');
check(decode([-1,-1,1,.5]).hasNg,'Minimum legal code was rejected.');
check(decode([1,1,16777216,.5]).hasNg,'Maximum legal code was rejected.');

let normalCases=0,maxNgAngleDegrees=0,maxNsAngleDegrees=0,maxOracleDecodeDistance=0;
function normalCase(n) {
    n=unit(n);const ns=unit([n[2]+.13,n[0]-.17,n[1]+.09]);
    const packed=pack(ns,n,true,.412345678),result=decode(packed);
    check(result.valid&&result.hasNg&&finite(result.ns)&&finite(result.ng),'Valid normals did not round trip.');
    check(packed[3]===f(.412345678),'Raw depth changed during packing.');
    const angle=(a,b)=>Math.acos(Math.max(-1,Math.min(1,dot(unit(a),unit(b)))))*180/Math.PI;
    maxNgAngleDegrees=Math.max(maxNgAngleDegrees,angle(n,result.ng));
    maxNsAngleDegrees=Math.max(maxNsAngleDegrees,angle(ns,result.ns));
    check(angle(n,result.ng)<.065,'12+12 oct quantization exceeded the tested 0.065 degree envelope.');
    const integer=packed[2]-1,oct=[integer%4096,Math.floor(integer/4096)].map(x=>x*2/4095-1);
    const oracle=oracleDecode(oct),distance=Math.hypot(...oracle.map((x,i)=>x-result.ng[i]));
    maxOracleDecodeDistance=Math.max(maxOracleDecodeDistance,distance);
    check(distance<8e-7,'Float32 decoding disagrees with the independent octahedron oracle.');
    const ownOct=encode32(normalize32(n)),referenceOct=oracleEncode(n);
    check(Math.hypot(...ownOct.map((x,i)=>x-referenceOct[i]))<4e-7,'Encoding disagrees with the independent octahedron oracle.');
    normalCases++;
}
// Axes, signed zeros, poles, every oct quadrant/fold boundary and nearby sides.
for(const x of [-1,-.5,-1e-7,-0,0,1e-7,.5,1])
    for(const y of [-1,-.5,-1e-7,-0,0,1e-7,.5,1]) normalCase(oracleDecode([x,y]));
for(const n of [[1,0,0],[-1,0,0],[0,1,0],[0,-1,0],[0,0,1],[0,0,-1]]) normalCase(n);
for(let i=0;i<=4095;i++) {
    const a=i*2/4095-1;
    for(const oct of [[a,1],[a,-1],[1,a],[-1,a],[a,1-Math.abs(a)],[a,Math.abs(a)-1]]) normalCase(oracleDecode(oct));
}
// Uniform-area sphere coverage does not overrepresent oct corners.
for(let i=0;i<50000;i++) {
    const z=1-2*(i+.5)/50000,r=Math.sqrt(1-z*z),phi=i*Math.PI*(3-Math.sqrt(5));
    normalCase([r*Math.cos(phi),r*Math.sin(phi),z]);
}

for(const reverse of [false,true]) {
    const unknown=decode(pack([0,1,0],[NaN,0,0],false,.5,reverse),reverse);
    check(unknown.valid&&!unknown.hasNg&&unknown.ng.every(v=>v===0),'Unknown Ng must retain a valid receiver without inventing geometry.');
    for(const ng of [[NaN,0,0],[Infinity,1,0],[0,0,0],[1e30,1e30,1e30]]) {
        const p=pack([0,0,1],ng,true,.5,reverse),r=decode(p,reverse);
        check(p[2]===-1&&r.valid&&!r.hasNg,'Invalid claimed Ng must degrade to unknown.');
    }
    for(const ns of [[NaN,0,0],[Infinity,1,0],[0,0,0],[1e30,1e30,1e30]])
        check(!decode(pack(ns,[0,0,1],true,.5,reverse),reverse).valid,'Invalid Ns must invalidate the receiver.');
    for(const code of [0,-2,-.5,.5,1.5,4096.5,16777218,Infinity,-Infinity,NaN]) {
        const r=decode([0,0,code,.5],reverse);
        check(!r.valid&&!r.hasNg&&r.ns.every(v=>v===0)&&r.ng.every(v=>v===0),'Malformed numeric code did not fail closed.');
    }
    for(const xy of [[NaN,0],[Infinity,0],[1.0001,0],[0,-1.0001]])
        check(!decode([...xy,1,.5],reverse).valid,'Malformed shading oct coordinates were accepted.');
    for(const d of [-1,2,NaN,Infinity,reverse?0:1])
        check(!decode(pack([0,0,1],[0,0,1],true,d,reverse),reverse).valid,'Invalid/background raw depth was accepted.');
    check(decode(pack([0,0,1],[0,0,1],true,reverse?1:0,reverse),reverse).valid,'Near-plane raw depth must remain valid.');
}

const compact=source.replace(/\/\/[^\n]*/g,'').replace(/\s+/g,'');
check(compact.includes('float4HLGIPackScreenGeometry(float3shadingNormal,float3geometricNormal,boolhasGeometricNormal,floatrawDepth)'), 'Pack API drifted.');
check(compact.includes('boolHLGIDecodeScreenGeometry(float4packed,outfloat3shadingNormal,outfloat3geometricNormal,outboolhasGeometricNormal)'), 'Decode API drifted.');
check(compact.includes('uintintegerCode=quantized.x+(quantized.y<<12)+1u;code=(float)integerCode;'),'Packing must store a numeric exact integer with reserved zero.');
check(compact.includes('packed.z<=16777216.0&&floor(packed.z)==packed.z'),'Decode must reject out-of-domain/nonintegral codes.');
check(compact.includes('uintbits=(uint)packed.z-1u;')&&compact.includes('uint2(bits&4095u,bits>>12)'),'Decode component layout drifted.');
check(compact.includes('floatcode=-1;')&&compact.includes('if(packed.z!=-1&&!known)returnfalse;'),'Unknown Ng sentinel contract drifted.');
check(compact.includes('returnfloat4(PackNormalOctQuadEncode(ns),code,rawDepth);'),'Depth must stay in w unchanged.');
check(!/\b(?:asfloat|asuint|asint|half[1-4]?)\s*\(/.test(source),'Reinterpretation or half precision is forbidden for this numeric encoding.');
check(compact.includes('shadingNormal=0;geometricNormal=0;hasGeometricNormal=false;'),'Decode failure must initialize all outputs.');
console.log(JSON.stringify({status:'passed',scope:'Independent CPU octahedron oracle, explicit float32 arithmetic and source contracts; no HLSL/Unity/GPU execution',assertions,exactFloat32Codes:16777216,normalCases,maxNgAngleDegrees,maxNsAngleDegrees,maxOracleDecodeDistance},null,2));
