import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const read=f=>fs.readFileSync(path.join(root,f),'utf8');
let checks=0;
const check=(ok,why)=>{checks++;if(!ok)throw new Error(why);};
// Independent bit-set oracle (BigInt avoids JS signed bitwise truncation).
const overlap=(a,b)=>(BigInt(a>>>0)&BigInt(b>>>0))!==0n;
const receiver=(objectBit,renderMask,lightMask,lightLayers,enabled)=>
  (objectBit&lightMask)!==0&&(!enabled||(renderMask&lightLayers)!==0);
for(let bit=0;bit<32;bit++) for(let other=0;other<32;other++)
for(const enabled of [false,true]) for(const renderMask of [0,1<<bit,0xffffffff]) {
  const b=(1<<bit)>>>0,c=(1<<other)>>>0;
  check(receiver(b,renderMask,c,c,enabled)===(overlap(b,c)&&(!enabled||overlap(renderMask,c))),
    'receiver culling/rendering layers including bit31 and zero');
}
// Blocker selection must continue beyond an ineligible nearest surface.
// Ordered distances here are the independent ray/plane intersection solution.
const candidates=[
  {t:1,mode:0,objectBit:1,layers:1},
  {t:2,mode:1,objectBit:2,layers:1},
  {t:3,mode:1,objectBit:1,layers:2},
  {t:4,mode:3,objectBit:1,layers:1},
];
const shadow=(items,mask,layers,enabled)=>items.filter(x=>x.mode!==0&&receiver(x.objectBit,x.layers,mask,layers,enabled))
  .reduce((best,x)=>x.t<best.t?x:best,{t:Infinity});
check(shadow(candidates,1,1,true).t===4,'off/wrong layers cannot hide farther ShadowsOnly blocker');
check(shadow(candidates,1,1,false).t===3,'disabled rendering layers retains GameObject filter');
check(Math.min(...candidates.map(x=>x.t))===1,'surface query retains non-shadow-casting geometry');
check(shadow([{t:1,mode:1,objectBit:1,layers:0}],1,0xffffffff,false).t===1,'disabled layer zero remains caster');
check(shadow([{t:1,mode:1,objectBit:1,layers:0}],1,0xffffffff,true).t===Infinity,'enabled allmask is not bypass');
// A hard binary visibility sample blended by shadow strength must retain the
// unshadowed fraction, independently of radiance/attenuation/receiver reflectance.
for(const strength of [0,.25,.5,1]) for(const blocked of [false,true])
for(const rho of [0,.04,.5,.98]) for(const incident of [0,.1,1,100,10000]) {
  let traced=0;
  function trace(){traced++;return blocked;}
  let visibility=1;
  if(strength>0&&trace())visibility=1-strength;
  const actual=rho*incident*visibility;
  const expected=blocked?rho*incident*(1-strength):rho*incident;
  check(Math.abs(actual-expected)<=1e-12*Math.max(1,expected),'shadow energy fraction');
  check(traced===(strength>0?1:0),'zero shadow strength incurs no query');
}
const transport=read('Runtime/Resources/HybridLumenGI/HybridLumenGITransport.hlsl');
const policy=read('Runtime/Resources/HybridLumenGI/HybridLumenGILightingPolicy.hlsl');
const kernels=read('Runtime/Resources/HybridLumenGI/HybridLumenGIKernels.hlsl');
const feature=read('Runtime/HybridLumenGIRendererFeature.cs');
const screenBudget=read('Runtime/HybridLumenGIScreenBudget.cs');
const lights=read('Runtime/HybridLumenGILights.cs');
const compact=s=>s.replace(/\/\*[\s\S]*?\*\//g,'').replace(/\/\/[^\n]*/g,'').replace(/\s+/g,'');
// Bound each known-state contract to the actual overload/caller. Numeric query
// behavior is also exercised by Validate-RadianceValidity.ps1 with these original
// HLSL function bodies on WARP; these assertions only guard the production wiring.
const functionBody=(source,declaration)=>{
  const start=source.indexOf(compact(declaration));
  check(start>=0,`required function: ${declaration}`);
  const open=source.indexOf('{',start);let depth=1,end=open+1;
  for(;end<source.length&&depth;end++) depth+=(source[end]==='{')-(source[end]==='}');
  check(open>=0&&depth===0,`complete function body: ${declaration}`);
  return source.slice(open+1,end-1);
};
const f=compact(feature),budget=compact(screenBudget);
check(transport.includes('uint4 masks;'),'80B light ABI has typed integer masks');
check(transport.includes('if(strength>0)')&&transport.includes('if(blocked) visibility=1-strength;'),'conditional hard-shadow strength');
check(transport.includes('ndl*attenuation*visibility'),'visibility applied once to direct irradiance');
check(transport.includes('HLGILightAffectsReceiver(receiverLayers,light.masks.x,light.masks.y,useRenderingLayers)'),'per-receiver light eligibility');
check(transport.includes('light.masks.x,light.masks.z,useRenderingLayers'),'independent shadow mask');
check(policy.includes('!useRenderingLayers || (receiver.y&renderingLayers)!=0')&&
  policy.includes('!useRenderingLayers || (policy.y&shadowRenderingLayers)!=0'),'explicit gate handles zero masks');
check(transport.indexOf('if(shadowQuery && !HLGIShadowOwnerAllowed')<transport.indexOf('if(HLGIHasMeshSdf(i))'),'software filter before leaf trace');
check(transport.includes('TraceSceneQuery(o,d,maxT,false,true,0xffffffffu,0xffffffffu,false,result)'),'surface query keeps geometry visibility');
check(transport.includes('TraceSceneQuery(o,d,maxT,true,false,cullingMask,shadowRenderingLayers,useRenderingLayers,footprint,materialView,result)'),'shadow parameters and spatial/material observer survive near/far routing');
check(transport.includes('_HLGI_LightingPolicies[hit.ownerSlot].xy'),'world direct light uses hit owner receiver');
check(kernels.includes('Texture2D<uint2> _HLGI_ReceiverPolicy;')&&kernels.includes('_HLGI_ReceiverPolicy.Load('),'screen policy is an exact integer load');
const t=compact(transport),k=compact(kernels);
const shadowBody=functionBody(t,'bool TraceShadow(float3 o,float3 d,float maxT,uint cullingMask,uint shadowRenderingLayers,bool useRenderingLayers,HLGIRayFootprint footprint,float4 materialView,out bool known)');
check(shadowBody.includes('boolblocked=TraceSceneQuery(o,d,maxT,true,false,cullingMask,shadowRenderingLayers,useRenderingLayers,footprint,materialView,result);')&&
    shadowBody.includes('known=!blocked||HLGIHitMaterialKnown(result);returnblocked;'),
    'Unknown shadow coverage must preserve the geometric blocker and independently report unknown radiance.');
const shadowWrapper=functionBody(t,'bool TraceShadow(float3 o,float3 d,float maxT,uint cullingMask,uint shadowRenderingLayers,bool useRenderingLayers,out bool known)');
check(shadowWrapper.includes('TraceShadow(o,d,maxT,cullingMask,shadowRenderingLayers,useRenderingLayers,HLGIPointQueryFootprint(),float4(o,1),known)'),
  'Legacy shadow wrapper deliberately uses a point footprint and original observer.');
const visibilityBody=functionBody(t,'bool TraceSceneVisibilityHit(float3 o,float3 d,float maxT,HLGIRayFootprint footprint,float4 materialView,out HLGIHit result)');
check(visibilityBody.includes('TraceSceneQuery(o,d,maxT,false,false,0xffffffffu,0xffffffffu,false,footprint,materialView,result)'),
  'Ordinary visibility skips full shading independently of shadow policy; Cull/alpha still run.');
const nearFarBody=functionBody(t,'bool TraceSceneQuery(float3 o,float3 d,float maxT,bool shadowQuery,bool resolveMaterial,uint cullingMask,uint shadowRenderingLayers,bool useRenderingLayers,HLGIRayFootprint footprint,float4 materialView,out HLGIHit result)');
check((nearFarBody.match(/TraceSceneDetailQuery\(/g)||[]).length===3&&
  (nearFarBody.match(/shadowQuery,resolveMaterial,cullingMask,shadowRenderingLayers,useRenderingLayers,footprint,materialView,result/g)||[]).length===2&&
  nearFarBody.includes('HLGIAdvanceRayFootprint(footprint,advance,farFootprint)')&&
  nearFarBody.includes('shadowQuery,resolveMaterial,cullingMask,shadowRenderingLayers,useRenderingLayers,farFootprint,materialView,result'),
  'Material purpose/masks and original observer survive near/far detail calls; shifted origin advances the footprint once.');
const directBody=functionBody(t,'float3 DirectIrradiance(float3 p,float3 n,float3 biasNormal,uint2 receiverLayers,bool receivesShadows,float3 footprintDirection,HLGIRayFootprint footprint,out bool known)');
check(directBody.includes('light.masks.x,light.masks.z,useRenderingLayers,shadowFootprint,float4(p,1),shadowKnown)')&&
    directBody.includes('if(!shadowKnown){known=false;return0;}')&&
    directBody.indexOf('if(!shadowKnown)')<directBody.indexOf('if(blocked)visibility=1-strength;'),
    'A positive shadow query must reject unknown coverage before treating the blocker as measured black.');
check(directBody.indexOf('HLGILightAffectsReceiver(')<directBody.indexOf('if(receivesShadows)')&&
    directBody.indexOf('if(receivesShadows)')<directBody.indexOf('TraceShadow('),
    'ReceiveShadows off bypasses only shadow visibility, preserving the receiver light-layer decision.');
check(directBody.includes('float3connection=light.positionType.xyz-shadowOrigin;')&&
    directBody.includes('HLGITryRetargetFootprint(footprint,footprintDirection,biasNormal,shadowDirection,projected)')&&
    directBody.includes('HLGITryPointShadowFootprint(projected,shadowDistance,shadowFootprint)')&&
    directBody.includes('HLGITryDirectionalShadowFootprint(projected,shadowFootprint)'),
    'Point shadow focus uses the biased origin, while both light kinds retarget the incoming spatial support using Ng.');
const directWrapper=functionBody(t,'float3 DirectIrradiance(float3 p,float3 n,float3 biasNormal,uint2 receiverLayers,bool receivesShadows,out bool known)');
check(directWrapper.includes('DirectIrradiance(p,n,biasNormal,receiverLayers,receivesShadows,biasNormal,HLGIPointQueryFootprint(),known)'),
  'Legacy direct wrapper delegates to the spatial primary without changing receiver shadow policy.');
const screenBody=functionBody(k,'bool TraceScreen(float3 origin,float3 dir,float maxT,out float3 radiance,out float distanceHit,out bool known,bool resolveRadiance=true)');
check(screenBody.includes('DirectIrradiance(p,n,biasNormal,receiverLayers,true,cameraRay,screenFootprint,directKnown)')&&
    screenBody.includes('float3cameraRay=p*_HLGI_MaterialView.w-_HLGI_MaterialView.xyz;')&&
    screenBody.includes('HLGITryScreenRayFootprint(uv,raw,p,cameraRay,screenFootprint)')&&
    screenBody.includes('distanceHit=surfaceT;if(!directKnown){known=false;returntrue;}'),
    'A captured surface uses its receiver policy and keeps its hit distance when direct light is unknown; it cannot become a miss.');
const proxyBody=functionBody(t,'float3 ProxyRadiance(HLGIHit hit,float3 incomingDirection,HLGIRayFootprint hitFootprint,float emissionWeight,out float confidence)');
check(proxyBody.includes('DirectIrradiance(hit.position,shadingNormal,biasNormal,_HLGI_LightingPolicies[hit.ownerSlot].xy,receivesShadows,incomingDirection,hitFootprint,directKnown)')&&
    /if\(!directKnown[^{}]*\)\{confidence=0;return0;\}/.test(proxyBody),
    'World radiance must consume directKnown and mark unknown direct light with zero confidence.');
const proxySpatialWrapper=functionBody(t,'float3 ProxyRadiance(HLGIHit hit,float3 incomingDirection,HLGIRayFootprint hitFootprint,out float confidence)');
check(proxySpatialWrapper.includes('ProxyRadiance(hit,incomingDirection,hitFootprint,1,confidence)'),
  'Unpaired spatial callers delegate with full endpoint emission and preserve the same direct-light validity.');
const proxyWrapper=functionBody(t,'float3 ProxyRadiance(HLGIHit hit,out float confidence)');
check(proxyWrapper.includes('ProxyRadiance(hit,hit.rawNg,HLGIPointQueryFootprint(),confidence)'),
  'Legacy proxy wrapper delegates with an explicit point-query footprint.');
const traceBody=functionBody(k,'void CSTrace(uint3 id:SV_DispatchThreadID)');
check(traceBody.includes('incoming,screenT,screenKnown)')&&
    traceBody.includes('sampleConfidence=screenKnown?1:0;elseif(worldHit)')&&
    traceBody.includes('!HLGIHasRadianceMeasurement(float4(incoming,sampleConfidence))')&&
    traceBody.includes('{estimateKnown=false;break;}')&&
    traceBody.includes(':float4(0,0,0,-1);'),
    'Screen unknown must reach whole-estimate invalidation instead of a world/environment fallback or a known black sample.');
// Full allocation arithmetic is executed by the actual C# ScreenBudget/BigInteger
// suite. These checks retain the policy-byte contract and its Feature wiring after
// the old inline floating-point sizing was replaced by the shared integer planner.
check(f.includes('CreateTexture(graph,fullW,fullH,GraphicsFormat.R32G32_UInt,"HLGIreceiverlightingpolicy",false)')&&
    budget.includes('intfullBytes=(replaceNative?36:24)+(identity?4:0);'),
    'The full-resolution uint2 policy remains allocated and included in baseline 24/36 bytes per pixel.');
check(budget.includes('intlowBytes=identity?128:96;')&&
    budget.includes('longidentityBuffers=identity?fullPixels*12+rows*80L:0;')&&
    budget.includes('longfixedBytes=fullPixels*fullBytes+identityBuffers;'),
    'Optional identity costs must be additional to the existing policy and history allocation.');
check(f.includes('varscreenBudget=HybridLumenGIScreenBudget.Plan(fullW,fullH,s.resolutionScale,(long)Math.Max(32,s.textureBudgetMiB)*1024*1024,replace,identityEnabled,s.receiverSourceCapacity);')&&
    f.includes('state.fullPixelBytes=screenBudget.FullPixelBytes;')&&f.includes('state.lowPixelBytes=screenBudget.LowPixelBytes;'),
    'Feature must pass the actual capture mode and budget to the planner and use its byte strides.');
const fitGuard=f.indexOf('if(!screenBudget.Fits)'),dimensions=f.indexOf('intw=screenBudget.Width,h=screenBudget.Height;');
check(fitGuard>=0&&f.indexOf('return;',fitGuard)<dimensions&&dimensions<f.indexOf('state.Ensure(w,h,identityEnabled);')&&
    f.includes('state.receiverIdentityBufferBytes=screenBudget.IdentityBufferBytes;'),
    'Only a fitting plan may allocate its returned dimensions and identity buffers.');
check(budget.includes('longbytes=fixedBytes+(long)width*height*lowBytes;')&&
    budget.includes('if(bytes<=budgetBytes)low=middle;elsehigh=middle-1;')&&
    budget.includes('width=Math.Max(minWidth,(int)((long)fullWidth*extent/longest));'),
    'Budget comparisons and dimension scaling must use integer-wide arithmetic, preserving the former rounding safety gate.');
check(budget.includes('returnFit(fullWidth,fullHeight,scale,budgetBytes,replaceNative,false,identityRequested,0);')&&
    f.includes('identityEnabled=screenBudget.IdentityEnabled&&screenBudget.Fits;'),
    'Identity budget failure must retain the affordable baseline policy capture.');
check(feature.includes('SetComputeBufferParam(c,k,"_HLGI_LightingPolicies",state.scene.LightingPolicyBuffer)'),'owner buffer binding');
check(feature.includes('SetTexture(cmd,c,trace,"_HLGI_ReceiverPolicy",d.receiverPolicy)'),'screen binding');
check(feature.includes('UpdateLights(state,lightData.supportsLightLayers)'),'current camera pipeline layers gate');
check(!feature.includes('lastLightScan')&&lights.includes('engineFrame != snapshotFrame'),'membership refreshed per rendered engine frame');
check(feature.includes('foreach(var changed in state.lightChanges) AddLightChange(state,changed);'),'both old and new light regions invalidated');
check(lights.includes('LightShadows.None')&&lights.includes('flags == other.flags'),'shadow mode and layer gate enter equality');
console.log(JSON.stringify({status:'passed',checks,scope:'CPU mask/energy oracle and integration source contracts; no GPU execution or Unity rendering'},null,2));
