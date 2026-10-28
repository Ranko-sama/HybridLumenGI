import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';

// Independent directional-radiance integrals plus float32 edge cases and live source
// contracts. No Unity/HLSL execution, rasterization or GPU timing is performed here.
const root=path.resolve(path.dirname("C:\\Users\\Administrator\\Desktop\\test\\HybridLumenGI\\Tests\\Validate-EmissiveSampling.mjs"),'..');
const read=file=>fs.readFileSync(path.join(root,'Runtime/Resources/HybridLumenGI',file),'utf8');
const source=read('HybridLumenGIEmissiveSampling.hlsl'),transport=read('HybridLumenGITransport.hlsl'),kernels=read('HybridLumenGIKernels.hlsl');
const compact=source.replace(/\/\/[^\n]*/g,'').replace(/\s+/g,'');
assert(compact.includes('floatpmf=record.data.y-record.data.x;'),'Selection and PDF must use represented CDF intervals.');
assert(compact.includes('pdf+=pmf*HLGIEmissiveVmfPdf(origin,record.sphere,direction);'),'PDF must sum every candidate, including overlaps.');
assert(compact.includes('selector>=interval.x&&selector<interval.y'),'Zero-width CDF intervals must never be selected.');
assert(compact.includes('axis=float3(0,0,1);sharpness=0;')&&compact.includes('if(sharpness<=0)return1/(4*PI);'),'Inside/degenerate lobes must retain normalized sphere density.');
assert.equal((compact.match(/HLGIEmissiveLobe\(origin,sphere,axis,sharpness\)/g)||[]).length,2,'Sample and PDF share the same lobe construction.');
assert(compact.includes('delta=sinSquared/(1+sqrt(max(0,1-sinSquared)))')&&compact.includes('sharpness=1/max(delta,1e-4);'),'Stable angular scale and bounded vMF concentration contract.');
assert(compact.includes('float3chord=direction-axis;')&&compact.includes('exp(-0.5*sharpness*dot(chord,chord))'),'Smooth vMF PDF must avoid a hard support edge and dot-minus-one cancellation.');
assert(compact.includes('log((1-xi.x)+xi.x*tail)')&&compact.includes('sqrt(max(0,-r*(r+2)))'),'Inverse CDF preserves endpoint complements and angular spread.');
assert(!compact.includes('dot(axis,direction)>='),'The removed hard-cone support test must not return.');
assert(compact.includes('!isfinite(distanceSquared)')&&compact.includes('!isfinite(radiusSquared)')&&compact.includes('!all(isfinite(offset))'),'Float32 overflow must use the same normalized fallback.');
assert(compact.includes('floatguided=(1-emissive)*guideFraction;')&&compact.includes('floatcosineFraction=(1-emissive)*(1-guideFraction);'),'Mixture branch probabilities must leave cosine support.');
assert(compact.includes('(cosineFraction*receiverCosine+guided*guideCosine)/PI+emissive*HLGIEmissiveDirectionalPdf(origin,direction,count);'),'Complete direction PDF includes all three strategies.');
assert(compact.includes('receiverCosine/(PI*pdf)'),'D=E/pi estimator must use full solid-angle PDF.');
assert(compact.includes('if(emissive<=0)returnHLGISampleDirection(normal,guide,rng,weight);'),'Empty/disabled table must retain exact old random sequence.');
const sampler=compact.slice(compact.indexOf('float3HLGISampleTransportDirection('));
assert(!/\bwhile\b/.test(sampler)&&!sampler.includes('for('),'No conditional hemisphere/hit rejection in the transport sampler.');
assert(transport.includes('HLGISampleTransportDirection(origin,n,e.guide,rng,weight)')&&kernels.includes('HLGISampleTransportDirection(origin,n,receiverCache.guide,rng,sampleWeight)'),'Both paths must pass the actual biased origin.');
// The weighting/commit operations now live in the shared validity helpers.
// These are bounded source-wiring checks; the independent integrals below stay
// unchanged, and actual helper execution belongs to RadianceValidity's WARP test.
function body(text,declaration) {
  text=text.replace(/\/\*[\s\S]*?\*\//g,'').replace(/\/\/[^\n]*/g,'').replace(/\s+/g,'');
  const start=text.indexOf(declaration);assert(start>=0,`Missing declaration ${declaration}`);
  const open=text.indexOf('{',start);assert(open>=0,`Missing body ${declaration}`);
  let depth=1,end=open+1;
  for(;end<text.length&&depth;end++)depth+=(text[end]==='{')-(text[end]==='}');
  assert.equal(depth,0,`Unterminated body ${declaration}`);return text.slice(open+1,end-1);
}
const validity=read('HybridLumenGIRadianceValidity.hlsl');
const accumulate=body(validity,'boolHLGIAccumulateRadianceSample('),commit=body(validity,'boolHLGICommitCacheEstimate(');
const cacheBody=body(transport,'voidCSUpdateCache('),traceBody=body(kernels,'voidCSTrace(');
assert(accumulate.includes('float3next=sum+incoming*weight;')&&accumulate.includes('sum=next;returntrue;')&&
  (accumulate.match(/incoming\*weight/g)||[]).length===1&&
  cacheBody.includes('HLGIAccumulateRadianceSample(incoming,materialConfidence,weight,sum)')&&
  traceBody.includes('HLGIAccumulateRadianceSample(_HLGI_AreaEmitterCount>0?incoming:LimitRadiance(incoming),sampleConfidence,sampleWeight,sum)')&&
  cacheBody.includes('HLGIAccumulateRadianceSample(lightValue,1,1,sum)')&&
  traceBody.includes('HLGIAccumulateRadianceSample(lightValue,1,1,sum)')&&
  (cacheBody.match(/HLGIAccumulateRadianceSample\(/g)||[]).length===2&&
  (traceBody.match(/HLGIAccumulateRadianceSample\(/g)||[]).length===2&&
  !/sum(?:\+=|-=|\*=|\/=)/.test(cacheBody+traceBody),
  'Direction Li is weighted once; its paired area term already contains cos/(pi*(pB+pL)) and is accumulated once at unit weight, without a separate nonlinear clamp.');
assert(cacheBody.includes('HLGIAreaMatchedDirectionWeight(origin,n,e.guide,direction,weight)')&&
  traceBody.includes('HLGIAreaMatchedDirectionWeight(origin,n,receiverCache.guide,dir,sampleWeight)'),
  'Area MIS must use the complete actual direction PDF rather than the legacy grazing denominator floor.');
assert(cacheBody.includes('HLGIAreaDirectionEmissionWeight(origin,n,e.guide,direction,hit,emissionWeight)')&&
  traceBody.includes('HLGIAreaDirectionEmissionWeight(origin,n,receiverCache.guide,dir,hit,emissionWeight)')&&
  traceBody.includes('lightValue=0;lightKnown=true;'),
  'World-hit emission needs a paired weight; a winning screen endpoint excludes the area term as known zero.');
assert(commit.includes('float3estimate=sum/rayCount;')&&
  cacheBody.includes('HLGICommitCacheEstimate(estimateKnown,sum,guide,guidePower,_HLGI_CacheRays,n,e.irradiance,e.guide)')&&
  cacheBody.includes('for(intr=0;r<_HLGI_CacheRays;r++)')&&traceBody.includes('for(intr=0;r<_HLGI_Rays;r++)')&&
  traceBody.includes('sum/max(_HLGI_Rays,1)'),'Normalize by all requested draws, not accepted hits.');
assert(!/ProxyRadiance|TraceScene|DirectIrradiance|\.emission|\.rgb/.test(source.replace(/\/\/[^\n]*/g,'')),'Proposal header cannot add emitted radiance or replace tracing.');

