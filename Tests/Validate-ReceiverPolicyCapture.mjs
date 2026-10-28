// CPU integer-policy oracle plus actual capture-source contracts. This does not
// validate Unity's per-draw builtins, batching, RendererList order, or GPU MRTs.
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const shaderRoot=new URL('../Runtime/Resources/HybridLumenGI/',import.meta.url);
const read=name=>readFileSync(new URL(name,shaderRoot),'utf8');
const helper=read('HybridLumenGIReceiverPolicyCapture.hlsl');
const surface=read('HybridLumenGISurface.shader');
const native=read('HybridLumenGINativeDiffuseCapture.shader');
let checks=0,floatNumericLossCases=0;
const check=(ok,message)=>{checks++;assert.ok(ok,message);};
const uint=v=>Number(BigInt.asUintN(32,BigInt(v)));
const capture=(index,renderingMask)=>Number.isFinite(index)&&Number.isInteger(index)&&index>=0&&index<=31
  ? [Number(1n<<BigInt(index)),uint(renderingMask)] : [0,0];
const mrt=new DataView(new ArrayBuffer(8));
const roundTrip=policy=>{mrt.setUint32(0,policy[0],true);mrt.setUint32(4,policy[1],true);return [mrt.getUint32(0,true),mrt.getUint32(4,true)];};
const matches=(policy,gameObjectMask,renderingMask)=>
  ((policy[0]&gameObjectMask)>>>0)!==0&&((policy[1]&renderingMask)>>>0)!==0;
const expected=(policy,g,r)=>(BigInt(policy[0])&BigInt(uint(g)))!==0n&&(BigInt(policy[1])&BigInt(uint(r)))!==0n;
const masks=[0,1,0x80000000,0x80000001,0xffffffff,0x7fffffff,0xaaaaaaaa,0x55555555,0x01000001,0x7fc12345,0xff812345];
for(let bit=0;bit<32;bit++)masks.push(Number(1n<<BigInt(bit)));
for(let layer=0;layer<32;layer++){
  const bit=Number(1n<<BigInt(layer));
  for(const mask of masks){
    const policy=capture(layer,mask),stored=roundTrip(policy);
    check(policy[0]===bit&&stored[0]===bit,'GameObject single-layer bit changed in integer MRT.');
    check(policy[1]===mask&&stored[1]===mask,'Renderer layer bits changed in integer MRT.');
    for(let lightLayer=0;lightLayer<32;lightLayer++){
      const gameMask=Number(1n<<BigInt(lightLayer));
      check(matches(stored,gameMask,mask)===expected(stored,gameMask,mask),'Bit 31 or renderer-mask intersection differs from integer oracle.');
    }
  }
}
check(capture(31,0xffffffff)[0]===0x80000000,'Layer 31 must stay an unsigned high bit.');
check(capture(0,0)[1]===0&&!matches(capture(0,0),0xffffffff,0xffffffff),'An empty rendering mask must not become all layers.');
for(const invalid of [-Infinity,-32,-1,-.01,.5,31.5,32,255,Infinity,NaN]){
  check(capture(invalid,0xffffffff).every(v=>v===0),'Malformed layer index must produce unknown/empty policy.');
}
// The two channels occupy all 64 bits. Numeric float storage loses low bits
// for ordinary high-bit masks, so it cannot be used as a transport for masks.
for(const mask of masks){if(Math.fround(mask)!==mask)floatNumericLossCases++;}
check(floatNumericLossCases>=5,'Fixtures must expose numeric float32 mask corruption.');
check(Math.fround(0x80000001)===Math.fround(0x80000000),'Expected float mask alias is absent.');
let seed=0x9341f2ad;
const next=()=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed;};
for(let i=0;i<10000;i++){
  const layer=next()&31,rendererMask=next(),lightGameMask=next(),lightRenderingMask=next();
  const stored=roundTrip(capture(layer,rendererMask));
  check(stored[1]===rendererMask,'Random 32-bit rendering mask did not roundtrip.');
  check(matches(stored,lightGameMask,lightRenderingMask)===expected(stored,lightGameMask,lightRenderingMask),'Mixed layer filtering differs from BigInt reference.');
}
const compact=s=>s.replace(/\/\/[^\n]*/g,'').replace(/\s+/g,'');
const h=compact(helper),s=compact(surface),n=compact(native);
check(h.includes('float_HLGI_ReceiverLayerIndex;'),'Draw-level layer index must remain a separate global.');
check(h.includes('!isfinite(_HLGI_ReceiverLayerIndex)')&&h.includes('_HLGI_ReceiverLayerIndex<0')&&h.includes('_HLGI_ReceiverLayerIndex>31')&&h.includes('_HLGI_ReceiverLayerIndex!=floor(_HLGI_ReceiverLayerIndex)'),'Missing invalid-index guard.');
check(h.includes('returnuint2(1u<<(uint)_HLGI_ReceiverLayerIndex,GetMeshRenderingLayer());'),'Masks must stay uint; GetMeshRenderingLayer performs URP bit reinterpretation.');
check(!h.includes('EncodeMeshRenderingLayer(')&&!h.includes('(float)GetMeshRenderingLayer')&&!h.includes('(half)GetMeshRenderingLayer'),'Policy must not use normalized or numeric-float rendering mask encoding.');
for(const [source,fragment,target] of [[s,'SurfaceOutputFrag(Varyingsinput)',2],[n,'HLGIDiffuseCaptureOutputHLGICaptureNativeDiffuse(Varyingsinput)',3]]){
  check(source.includes('#include"HybridLumenGIReceiverPolicyCapture.hlsl"'),'Both captures must use the same policy contract.');
  check(source.includes('#pragmamulti_compile_instancing')&&source.includes('#pragmainstancing_optionsrenderinglayer'),'Instanced receiver rendering layers must be requested.');
  check(source.includes(`uint2receiverPolicy:SV_Target${target};`),'Policy output must be an unsigned two-channel MRT in the specified slot.');
  const body=source.slice(source.indexOf(fragment));
  check(body.indexOf('UNITY_SETUP_INSTANCE_ID(input);')>=0&&body.indexOf('UNITY_SETUP_INSTANCE_ID(input);')<body.indexOf('output.receiverPolicy=HLGICaptureReceiverPolicy();'),'Per-instance rendering layer must be set up before capture.');
  check(body.indexOf('clip(0.5h-_Surface);')<body.indexOf('output.receiverPolicy=HLGICaptureReceiverPolicy();'),'Discarded transparent fragments must not produce receiver policy.');
}
check(s.includes('output.diffuseOcclusion=half4(saturate(baseSample.rgb*_BaseColor.rgb)*diffuseFraction,saturate(occlusion));')&&s.includes('output.emissionValidity=half4(emission,HLGIEncodeScreenMaterial(1.0h,HLGICaptureReceivesShadows()));'),'Ordinary capture material output contract changed.');
check(n.includes('HLGIDiffuseCaptureOutputoutput=(HLGIDiffuseCaptureOutput)0;')&&n.indexOf('returnoutput;')<n.indexOf('output.receiverPolicy=HLGICaptureReceiverPolicy();'),'Rejected native variants must preserve zero material validity and zero policy.');
check(n.includes('output.diffuseOcclusion=half4(brdfData.diffuse,ao.indirectAmbientOcclusion);')&&n.includes('output.emissionValidity=half4(surfaceData.emission,HLGIEncodeScreenMaterial(1+saturate(surfaceData.occlusion),HLGICaptureReceivesShadows()));')&&n.includes('output.nativeDiffuseFog=half4(nativeDiffuse,fogTransmission);'),'Native capture diffuse/emission/AO/fog output contract changed.');
console.log(JSON.stringify({status:'passed',checks,layers:32,randomMaskPairs:10000,floatNumericLossCases,policyBytesPerPixel:8,scope:'CPU integer-mask oracle and capture shader source contracts only; Unity per-object data, batching and integer MRT writes require runtime verification'},null,2));
