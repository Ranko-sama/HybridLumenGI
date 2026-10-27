import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
let checks=0;function check(condition,message){checks++;assert.ok(condition,message);}
const f=Math.fround;
// Independent supported DX12/non-MSAA ordinary-Lit alpha oracle. No image/raster simulation.
function alphaPass(sample,color,cutoff,alphaTest,smoothnessAlpha){
    const alpha=smoothnessAlpha?f(color):f(f(sample)*f(color));
    return Number.isFinite(alpha)&&Number.isFinite(cutoff)&&(!alphaTest||f(alpha-f(cutoff))>=0);
}
function eligible(fragment){return fragment.owner>0&&fragment.owner<=0xffffffff&&fragment.primitive<0xffffffff&&
    [fragment.z,fragment.camera,fragment.capture].every(x=>Number.isFinite(x)&&x>=0&&x<=1)&&
    fragment.z===fragment.camera&&fragment.camera===fragment.capture&&
    alphaPass(fragment.sample,fragment.color,fragment.cutoff,fragment.clip,fragment.smooth);}
function resolve(candidate,objects){
    if(candidate.owner<=0||candidate.owner>objects.length||candidate.conflict!==0||candidate.primitive===0)return [0,0,0,0];
    const row=objects[candidate.owner-1];
    return (row.key[0]||row.key[1])?[...row.key,candidate.primitive,1]:[0,0,0,0];
}
// Enumerate every ordering of each fragment's CAS followed by its dependent write.
// Unknown masks may run before or after fragments, but clear precedes all work,
// and resolve occurs only after every event/UAV dependency completes.
function interleavings(fragments,mask=false){
    const states=new Array(fragments.length).fill(0),winners=new Array(fragments.length).fill(false),results=[];
    function visit(candidate,maskDone){
        if(states.every(x=>x===2)&&(!mask||maskDone)){results.push({...candidate});return;}
        for(let i=0;i<states.length;i++)if(states[i]<2){
            const before=states[i],won=winners[i],copy={...candidate};states[i]++;
            if(before===0){winners[i]=copy.owner===0;if(winners[i])copy.owner=fragments[i].owner;}
            else if(winners[i])copy.primitive=fragments[i].primitive+1;
            else copy.conflict|=1;
            visit(copy,maskDone);states[i]=before;winners[i]=won;
        }
        if(mask&&!maskDone)visit({...candidate,conflict:candidate.conflict|1},true);
    }
    visit({owner:0,conflict:0,primitive:0},false);return results;
}
const objectRows=[{key:[0xffffffff,0x80000000],flags:0},{key:[1,0],flags:1}];
const base={owner:1,primitive:17,z:f(.4),camera:f(.4),capture:f(.4),sample:f(.8),color:f(.7),cutoff:f(.5),clip:true,smooth:false};
check(eligible(base),'supported depth and alpha accepted');
for(let count=1;count<=3;count++)for(const sameOwner of [false,true])for(const mask of [false,true]){
    const fragments=Array.from({length:count},(_,i)=>({...base,owner:sameOwner?1:(i%2)+1,primitive:i+2}));
    for(const result of interleavings(fragments,mask)){
        const output=resolve(result,objectRows);
        check((output[3]===1)===(count===1&&!mask),'all atomic interleavings reject any second fragment, including same owner');
        if(output[3])check(output[2]===3&&output[0]===0xffffffff&&output[1]===0x80000000,'winner primitive and uint key remain exact; flags0 still current-valid');
        if(mask)check(result.conflict===1,'unknown mask remains sticky even if winner writes primitive later');
    }
}
for(const bad of [NaN,Infinity,-Infinity,-.01,1.01])for(const field of ['z','camera','capture'])check(!eligible({...base,[field]:bad}),'bad depth rejected '+field);
const bits=new Uint32Array(new Float32Array([base.z]).buffer);bits[0]++;const adjacent=new Float32Array(bits.buffer)[0];
for(const field of ['z','camera','capture'])check(!eligible({...base,[field]:adjacent}),'one-ULP depth mismatch is unknown');
for(const sample of [0,.1,.5,1,2])for(const color of [0,.1,.5,1,2])for(const cutoff of [-.1,0,.1,.5,1])for(const clip of [false,true])for(const smooth of [false,true]){
    const value=smooth?f(color):f(f(sample)*f(color));
    check(alphaPass(sample,color,cutoff,clip,smooth)===(!clip||value>=f(cutoff)),'alpha branch oracle');
}
check(!alphaPass(0,1,.5,true,false)&&alphaPass(0,1,.5,true,true),'smoothness-from-albedo-alpha must not punch holes');
check(alphaPass(.5,1,.5,true,false),'exact clip boundary survives');
for(const bad of [NaN,Infinity,-Infinity])check(!alphaPass(bad,1,.5,true,false),'invalid sampled alpha fails closed');
for(const candidate of [{owner:0,conflict:0,primitive:1},{owner:3,conflict:0,primitive:1},{owner:1,conflict:1,primitive:1},{owner:1,conflict:0,primitive:0}])
    check(resolve(candidate,objectRows).every(v=>v===0),'invalid candidate no row load/identity');
check(resolve({owner:1,conflict:0,primitive:1},[{key:[0,0],flags:1}]).every(v=>v===0),'hole key invalid');
check(!eligible({...base,owner:0})&&!eligible({...base,primitive:0xffffffff}),'reserved zero/overflow excluded');
for(let full=1;full<=151;full+=3)for(let low=1;low<=full;low+=7)for(let q=0;q<low;q++){
    const fullPixel=Math.floor((2*q+1)*full/(2*low));
    const storedCenter=Math.floor((q+.5)*full/low);
    check(fullPixel===storedCenter&&fullPixel<full,'resolve uses the actual full depth center including odd ratios');
}
function maskRect(size,rect){const hit=[];const start=rect.slice(0,2).map((v,i)=>Math.min(v,size[i]));const end=rect.slice(2).map((v,i)=>Math.min(v,size[i]));for(let y=start[1];y<end[1];y++)for(let x=start[0];x<end[0];x++)hit.push(y*size[0]+x);return hit;}
check(maskRect([7,5],[2,1,6,4]).length===12,'exclusive rectangle extent');
check(maskRect([7,5],[6,4,99,99]).join(',')==='34','rect clipped to full size');
check(maskRect([7,5],[6,4,2,1]).length===0,'empty/reversed rectangle is safe');
const shader=fs.readFileSync(path.join(root,'Runtime/Resources/HybridLumenGI/HybridLumenGIReceiverIdentity.shader'),'utf8');
const compute=fs.readFileSync(path.join(root,'Runtime/Resources/HybridLumenGI/HybridLumenGIReceiverIdentity.compute'),'utf8');
const source=fs.readFileSync(path.join(root,'Runtime/HybridLumenGIMaterialSource.cs'),'utf8');
for(const cull of ['Off','Front','Back'])check(shader.includes(`Name "Cull${cull}"`)&&shader.includes(`Cull ${cull} ZWrite Off ZTest Always Blend Off ColorMask 0`),'immutable fixed raster pass '+cull);
check(shader.includes('RWStructuredBuffer<uint3> _HLGI_IdentityCandidates : register(u1)'),'12-byte candidate u1');
const validSize=size=>size.every(x=>Number.isFinite(x)&&x>=1&&x<=16384&&Math.floor(x)===x);
for(const size of [[1,1],[16384,16384],[1919,1079]])check(validSize(size)&&size.every(x=>f(x)===x),'MPB float dimensions convert exactly');
for(const bad of [0,-1,.5,1.5,16385,NaN,Infinity])check(!validSize([bad,100]),'malformed raster size rejected');
check(shader.includes('float4 _HLGI_IdentityFullSize')&&shader.includes('uint2 fullSize=(uint2)_HLGI_IdentityFullSize.xy'),'raster sizes have a real MPB SetVector ABI');
check(shader.indexOf('clip(alpha-')<shader.indexOf('InterlockedCompareExchange')&&shader.indexOf('cameraDepth!=captureDepth')<shader.indexOf('InterlockedCompareExchange'),'alpha/depth validation precedes claim');
check(shader.includes('if(_AlphaToMaskAvailable!=0) discard;')&&shader.indexOf('if(_AlphaToMaskAvailable!=0)')<shader.indexOf('InterlockedCompareExchange'),'GPU alpha-to-coverage state gates claim');
check((shader.match(/#pragma multi_compile_fragment _ DEBUG_DISPLAY/g)||[]).length===3&&shader.includes('#if defined(DEBUG_DISPLAY)'),'every raster pass has a discard-only debug variant');
check(shader.includes('else\n                InterlockedOr')&&!shader.includes('previous==_HLGI_IdentityOwnerIndexPlusOne'),'any second fragment conflicts');
check(compute.includes('HLGIFullPixelForGiPixel(id.xy,_HLGI_IdentityGiSize,_HLGI_IdentityFullSize)'),'actual-center helper used');
check(compute.includes('candidate.x<=_HLGI_IdentityObjectCount')&&compute.includes('if(any(owner.key!=0u))')&&!compute.includes('owner.flags'),'current identity independent of previous eligibility');
const coverage=source.slice(source.indexOf('public readonly struct IdentityCoverageData'),source.indexOf('public sealed class Snapshot'));
check(!coverage.includes('source.Get')&&!coverage.includes('renderer.Get')&&!coverage.includes('GetPropertyBlock'),'coverage constructed from frozen data only');
check(source.includes('new IdentityCoverageData(this.values, this.textures, this.keywords, this.passes, passEnabled)'),'owned snapshot inputs used');
console.log(`Receiver identity CPU/contract reference: ${checks} checks passed. Atomic interleavings, alpha/depth, uint identity, unknown rectangles, and actual sample centers; not Unity raster/UAV execution.`);
