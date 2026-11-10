// Independent CPU geometry oracle plus source-contract checks. This does not
// execute the HLSL, Unity, a GPU, or rasterized normal/depth textures.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
const transport=readFileSync(new URL('../Runtime/Resources/HybridLumenGI/HybridLumenGITransport.hlsl',import.meta.url),'utf8');
const kernels=readFileSync(new URL('../Runtime/Resources/HybridLumenGI/HybridLumenGIKernels.hlsl',import.meta.url),'utf8');
const composite=readFileSync(new URL('../Runtime/Resources/HybridLumenGI/HybridLumenGIComposite.shader',import.meta.url),'utf8');
const receiverTemporal=readFileSync(new URL('../Runtime/Resources/HybridLumenGI/HybridLumenGIReceiverTemporal.hlsl',import.meta.url),'utf8');
let assertions=0;
const check=(condition,message)=>{assert.ok(condition,message);assertions++;};
const dot=(a,b)=>a.reduce((sum,x,i)=>sum+x*b[i],0);
const sub=(a,b)=>a.map((x,i)=>x-b[i]);
const add=(a,b)=>a.map((x,i)=>x+b[i]);
const mul=(a,s)=>a.map(x=>x*s);
const cross=(a,b)=>[a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]];
const norm=a=>mul(a,1/Math.hypot(...a));
const finite=a=>a.every(Number.isFinite);
const rotation=(a,b,c)=>v=>{
    const x=[v[0],Math.cos(a)*v[1]-Math.sin(a)*v[2],Math.sin(a)*v[1]+Math.cos(a)*v[2]];
    const y=[Math.cos(b)*x[0]+Math.sin(b)*x[2],x[1],-Math.sin(b)*x[0]+Math.cos(b)*x[2]];
    return [Math.cos(c)*y[0]-Math.sin(c)*y[1],Math.sin(c)*y[0]+Math.cos(c)*y[1],y[2]];
};

// Analytic camera/ray-plane intersections generate depth independently of the
// finite-difference reconstruction. Test both UV origins, Z conventions and
// perspective/orthographic cameras rather than assuming a cross-product sign.
function fixture({reverse=true,top=true,ortho=false,angle=0,width=64,height=48}={}) {
    const near=.1,far=300,rotate=rotation(angle*.37,angle*.23,angle*.71);
    const translation=[12,-7,21],normalLocal=norm([.55*Math.sin(angle),.65*Math.cos(angle),1]);
    const plane=[0,0,-5];
    const localRay=(x,y)=>{
        const sx=((x+.5)/width*2-1)*width/height,sy=((y+.5)/height*2-1)*(top?-1:1);
        return ortho?{origin:[sx,sy,0],direction:[0,0,-1]}:{origin:[0,0,0],direction:[sx,sy,-1]};
    };
    const encode=z=>{
        const reversed=ortho?(far-z)/(far-near):near*(far/z-1)/(far-near);
        return reverse?reversed:1-reversed;
    };
    const decode=d=>{const reversed=reverse?d:1-d;return ortho?far-(far-near)*reversed:near*far/(near+(far-near)*reversed);};
    const world=(x,y,d)=>{
        const ray=localRay(x,y),z=decode(d);
        return add(rotate(add(ray.origin,mul(ray.direction,z))),translation);
    };
    const depth=(x,y)=>{
        const ray=localRay(x,y),t=dot(normalLocal,sub(plane,ray.origin))/dot(normalLocal,ray.direction);
        return encode(t);
    };
    return {width,height,reverse,world,depth,normal:rotate(normalLocal),decode};
}
function reconstruct(f,x,y) {
    const valid=d=>Number.isFinite(d)&&d>=0&&d<=1&&(f.reverse?d>1e-6:d<1-1e-6);
    if(x<0||y<0||x>=f.width||y>=f.height) return null;
    const c=f.depth(x,y);
    if(!valid(c)) return null;
    const p=f.world(x,y,c);
    if(!finite(p)) return null;
    const derivative=axis=>{
        const candidates=[];
        for(const side of [-1,1]) {
            const p1=[x+axis[0]*side,y+axis[1]*side],p2=[x+axis[0]*side*2,y+axis[1]*side*2];
            if([...p1,...p2].some((v,i)=>v<0||v>=(i%2===0?f.width:f.height))) continue;
            const d1=f.depth(...p1),d2=f.depth(...p2),prediction=2*d1-d2;
            if(!valid(d1)||!valid(d2)||prediction<0||prediction>1) continue;
            candidates.push({error:Math.abs(prediction-c),prediction,d1,p1,side});
        }
        candidates.sort((a,b)=>a.error-b.error);
        if(!candidates.length) return null;
        const best=candidates[0],predicted=f.world(x,y,best.prediction);
        if(!finite(predicted)||Math.hypot(...sub(predicted,p))>Math.max(.002,Math.abs(f.decode(c))*1e-4)) return null;
        const d=mul(sub(f.world(...best.p1,best.d1),p),best.side),lengthSquared=dot(d,d);
        return finite(d)&&Number.isFinite(lengthSquared)&&lengthSquared>=1e-16?norm(d):null;
    };
    const h=derivative([1,0]),v=derivative([0,1]);
    if(!h||!v) return null;
    const product=cross(h,v),len=dot(product,product);
    if(!finite(product)||!Number.isFinite(len)||len<1e-6) return null;
    let normal=norm(product);
    const toward=sub(f.world(x,y,f.reverse?1:0),p),facing=dot(normal,toward);
    if(!finite(toward)||!Number.isFinite(facing)||Math.abs(facing)<1e-8) return null;
    if(facing<0) normal=mul(normal,-1);
    return normal;
}

let planarCases=0;
for(let i=0;i<120;i++) for(const reverse of [false,true]) for(const top of [false,true]) for(const ortho of [false,true]) {
    const f=fixture({reverse,top,ortho,angle:i*.137}),n=reconstruct(f,31,23);
    check(n!==null,'A valid planar neighborhood must reconstruct.');
    check(dot(n,f.normal)>1-1e-9,'World plane normal changed with camera rotation/UV origin/Z convention.');
    check(Math.abs(dot(n,n)-1)<1e-12,'Reconstructed geometry normal must be normalized.');
    planarCases++;
}
const f=fixture(),cx=31,cy=23,originalDepth=f.depth;
// One side crosses a silhouette; the opposite two samples still establish the
// center plane. An isolated one-pixel layer has no consistent supported axis.
const oneSide={...f,depth:(x,y)=>x>cx?originalDepth(x,y)*.5:originalDepth(x,y)};
check(dot(reconstruct(oneSide,cx,cy),f.normal)>1-1e-9,'Silhouette selected the discontinuous side.');
const isolated={...f,depth:(x,y)=>x===cx&&y===cy?originalDepth(x,y):originalDepth(x,y)*.5};
check(reconstruct(isolated,cx,cy)===null,'An isolated layer must not invent a world-cache normal.');
const missingAxis={...f,depth:(x,y)=>x!==cx?(f.reverse?0:1):originalDepth(x,y)};
check(reconstruct(missingAxis,cx,cy)===null,'Missing horizontal neighbors must reject.');
check(reconstruct(f,-1,cy)===null,'Offscreen center must reject.');
check(reconstruct(fixture({width:2,height:2}),0,0)===null,'A 2x2 image cannot provide two-tap slopes.');
for(const bad of [NaN,Infinity,-Infinity,-1,2,0]) {
    check(reconstruct({...f,depth:()=>bad},cx,cy)===null,'Invalid depth was accepted.');
}
check(reconstruct({...f,world:()=>[NaN,0,0]},cx,cy)===null,'Nonfinite reconstructed position was accepted.');
check(reconstruct({...f,world:()=>[1,1,1]},cx,cy)===null,'Coincident derivatives were accepted.');
check(reconstruct({...f,world:(x,y,d)=>[x+y,0,d]},cx,cy)===null,'Collinear derivatives were accepted.');

// Same geometric plane, identical strong normal map. Old cache code projected
// distance onto Ns, rejecting valid tangential motion and admitting another layer.
let legacyRejected=0;
for(let i=0;i<360;i++) {
    const rotate=rotation(i*.03,i*.17,i*.09),ng=rotate([0,0,1]);
    const ns=rotate(norm([.995,0,.1])),along=rotate([.1,0,0]),between=rotate([0,0,.1]);
    const threshold=.06;
    check(Math.abs(dot(along,ns))>threshold,'Counterexample no longer reproduces the legacy false rejection.');
    check(Math.abs(dot(between,ns))<threshold,'Counterexample no longer reproduces the legacy false acceptance.');
    check(Math.abs(dot(along,ng))<threshold,'Geometric plane rejected a tangential neighbor.');
    check(Math.abs(dot(between,ng))>threshold,'Geometric plane accepted a distinct layer.');
    check(dot(ns,ns)>.85&&dot(ng,ng)>.85,'Like normals must remain compatible.');
    check(dot(ns,ng)<.2,'Strong normal-map example must differ from mesh geometry.');
    legacyRejected++;
}
// A short probe may substitute actual Ng only when position and Ng agree. Ns is
// deliberately absent from these geometric qualification conditions.
const match=(t,probe,hitNg,estimatedNg,bias)=>Math.abs(t-probe)<=Math.max(.002,Math.min(bias,.03))&&Math.abs(dot(hitNg,estimatedNg))>=.85;
check(match(.06,.06,[0,0,1],[0,0,1],.03),'Matching geometry rejected.');
check(match(.06,.06,[0,0,-1],[0,0,1],.03),'A backend-accepted backside lost its original source winding identity.');
check(!match(.1,.06,[0,0,1],[0,0,1],.03),'Nearby different layer accepted.');
check(!match(.06,.06,[1,0,0],[0,0,1],.03),'Geometrically unrelated probe accepted.');

// An authored +Z shading hemisphere remains +Z on a visible CullFront/CullOff
// backside. Its history normal faces a camera below the plane (-Z), so using
// history Ng as the ray-origin side makes every +Z sample hit the same plane.
// Solve the independent analytic ray/plane equation, not a tracing surrogate.
let oldBacksideSelfHits=0,newBacksideSelfHits=0;
for(let i=0;i<1000;i++) {
    const dz=Math.sqrt(1-(i+.5)/1000),bias=.02;
    const oldT=-(-bias)/dz,newT=-(bias)/dz;
    if(oldT>1e-4) oldBacksideSelfHits++;
    if(newT>1e-4) newBacksideSelfHits++;
}
check(oldBacksideSelfHits===1000,'Backside origin fixture no longer reproduces self intersection.');
check(newBacksideSelfHits===0,'The shading-hemisphere origin still intersects its own flat surface.');

// Screen filtering must preserve shading-normal similarity while using geometry
// for the layer/plane distance. The old Ns plane gives the opposite decision for
// these tangential/disconnected-layer fixtures under arbitrary world rotations.
let screenPlaneCases=0;
for(let i=0;i<240;i++) {
    const rotate=rotation(i*.19,i*.07,i*.11),ng=rotate([0,0,1]),ns=rotate(norm([.995,0,.1]));
    const along=rotate([.1,0,0]),between=rotate([0,0,.1]),tolerance=.06;
    const planeDistance=delta=>Math.abs(dot(delta,ng));
    check(planeDistance(along)<tolerance,'Temporal neighborhood rejected the actual plane.');
    check(planeDistance(between)>tolerance,'Temporal neighborhood admitted a separate layer.');
    const legacyAlong=Math.exp(-Math.abs(dot(along,ns))/.03),legacyBetween=Math.exp(-Math.abs(dot(between,ns))/.03);
    const correctedAlong=Math.exp(-planeDistance(along)/.03),correctedBetween=Math.exp(-planeDistance(between)/.03);
    check(correctedAlong>legacyAlong*20,'Spatial plane weighting still suppresses tangential motion.');
    check(correctedBetween<legacyBetween*.06,'Spatial plane weighting still favors the wrong layer.');
    check(dot(ns,ns)>.99,'Ns remains the independent lighting compatibility normal.');
    screenPlaneCases++;
}

// Independent low/full-resolution support mapping. A receiver with unknown Ng
// owns a valid sample; it can resolve at that sample's full-resolution texel, but
// cannot authorize filling surrounding pixels or removal of their native GI.
let unknownResolveCases=0;
const resolveUnknown=(fullSize,giSize,fullPixel,samples)=>{
    const uv=(fullPixel+.5)/fullSize,texel=uv*giSize-.5,base=Math.floor(texel),fraction=texel-base;
    let weighted=0,total=0;
    for(let x=0;x<2;x++) {
        const q=Math.max(0,Math.min(giSize-1,base+x));
        if(Math.floor((q+.5)/giSize*fullSize)!==fullPixel) continue;
        const weight=x===0?1-fraction:fraction;
        weighted+=samples[q]*weight;total+=weight;
    }
    return total>1e-5?{resolved:true,value:weighted/total}:{resolved:false,value:0};
};
for(const [fullSize,giSize] of [[8,8],[8,4],[7,3],[17,5],[1920,960]]) {
    const samples=Array.from({length:giSize},(_,q)=>2+q*.25);
    for(let pixel=0;pixel<fullSize;pixel++) {
        const owner=samples.findIndex((_,q)=>Math.floor((q+.5)/giSize*fullSize)===pixel);
        const result=resolveUnknown(fullSize,giSize,pixel,samples);
        check(result.resolved===(owner>=0),'Unknown geometry leaked into another full-resolution sample.');
        if(owner>=0) check(Math.abs(result.value-samples[owner])<1e-10,'Valid unknown-Ng fallback was erased.');
        else {
            const native=.7,delta=result.resolved?result.value-native:0;
            check(native+delta===native,'Unsupported upsample removed native diffuse GI.');
        }
        unknownResolveCases++;
    }
}
const current=[3,.5,1,.65],unknownFilter=(value,hasNg)=>hasNg?null:[...value];
check(unknownFilter(current,false).every((x,i)=>x===current[i]),'Unknown-Ng filtering must preserve the complete current sample.');
const mayReuseHistory=(currentHasNg,oldHasNg)=>currentHasNg&&oldHasNg;
check(!mayReuseHistory(false,true)&&!mayReuseHistory(true,false)&&!mayReuseHistory(false,false),'Unknown-Ng history must be rejected on either side.');
const resolveMixed=candidates=>{
    let sum=0,weight=0;
    for(const candidate of candidates) {
        const confidence=candidate.confidence??1;
        if(!Number.isFinite(confidence)||confidence<=0||!Number.isFinite(candidate.value)) continue;
        if(!candidate.hasNg) { if(candidate.isOwnSample) return candidate.value;continue; }
        if(!Number.isFinite(candidate.weight)||candidate.weight<=0) continue;
        sum+=candidate.value*candidate.weight;weight+=candidate.weight;
    }
    return weight>1e-5?sum/weight:null;
};
const ownUnknown={hasNg:false,isOwnSample:true,value:3.5},otherUnknown={hasNg:false,isOwnSample:false,value:900};
const knownNeighbor={hasNg:true,value:27,weight:.8};
check(resolveMixed([knownNeighbor,ownUnknown])===3.5,'A visited known neighbor diluted the authoritative unknown-Ng sample.');
check(resolveMixed([ownUnknown,knownNeighbor])===3.5,'Candidate order changed unknown-Ng preservation.');
check(resolveMixed([otherUnknown,knownNeighbor])===27,'An unrelated unknown-Ng candidate contaminated a known sample.');
check(resolveMixed([otherUnknown])===null,'No valid support must remain unresolved, not measured black.');
// A measured black surface and an unavailable material have different meanings
// for native-diffuse replacement, even when their RGB payloads are identical.
let unknownRadianceResolveCases=0;
for(const hasNg of [false,true]) for(const confidence of [0,-1,NaN,Infinity]) {
    const unavailable={hasNg,isOwnSample:true,value:0,weight:1,confidence};
    check(resolveMixed([unavailable])===null,'Missing radiance authorized native diffuse subtraction.');
    check(resolveMixed([unavailable,knownNeighbor])===27,'Invalid center diluted independently valid neighboring support.');
    check(resolveMixed([knownNeighbor,unavailable])===27,'Invalid own unknown-Ng sample overrode valid support.');
    unknownRadianceResolveCases++;
}
for(const value of [NaN,Infinity,-Infinity]) {
    const corrupt={hasNg:false,isOwnSample:true,value,confidence:1};
    check(resolveMixed([corrupt])===null,'Nonfinite own radiance was trusted.');
    check(resolveMixed([knownNeighbor,corrupt])===27,'Nonfinite own radiance contaminated finite support.');
    unknownRadianceResolveCases++;
}
for(const hasNg of [false,true]) {
    const measuredBlack={hasNg,isOwnSample:true,value:0,weight:1,confidence:1};
    check(resolveMixed([measuredBlack])===0,'A known black estimate was incorrectly classified as missing.');
    const native=.7,replacement=resolveMixed([measuredBlack]);
    check(native+(replacement-native)===0,'Known black must legitimately replace native diffuse.');
    unknownRadianceResolveCases++;
}

// Couple the independent oracle to the actual call contracts. Numerical fixtures
// alone cannot catch passing Ns as a geometry argument in a different call site.
const compact=s=>s.replace(/\/\*[\s\S]*?\*\//g,'').replace(/\/\/[^\n]*/g,'').replace(/\s+/g,'');
// Select only the receiver-identity conditional. Leave unrelated API/depth
// directives untouched; this is a call-site contract check, not an HLSL compiler.
function identityVariant(source,enabled) {
    let active=true;const stack=[],output=[];
    for(const line of source.split(/\r?\n/)) {
        const directive=line.match(/^\s*#\s*(if|ifdef|ifndef|else|elif|endif)\b(.*)$/);
        if(!directive) { if(active)output.push(line);continue; }
        const [,kind,tail]=directive;
        if(['if','ifdef','ifndef'].includes(kind)) {
            const name=tail.trim();
            const selected=kind==='if'?/^defined\s*\(\s*HLGI_RECEIVER_IDENTITY\s*\)$/.test(name):name==='HLGI_RECEIVER_IDENTITY';
            stack.push({parent:active,selected});
            if(selected)active=active&&(kind==='ifndef'?!enabled:enabled);else if(active)output.push(line);
        } else {
            const frame=stack.at(-1);assert.ok(frame,'Balanced shader conditional');
            if(kind==='endif') {stack.pop();if(!frame.selected&&active)output.push(line);active=frame.parent;}
            else if(frame.selected) {assert.equal(kind,'else','Review new receiver #elif explicitly');active=frame.parent&&!active;}
            else if(active)output.push(line);
        }
    }
    assert.equal(stack.length,0,'Balanced shader conditional');return output.join('\n');
}
const t=compact(transport),k=compact(kernels),c=compact(composite);
const legacy=compact(identityVariant(kernels,false)),identity=compact(identityVariant(kernels,true)),rt=compact(receiverTemporal);
for(const enabled of [false,true]) check(
    identityVariant(kernels.replace(/\r?\n/g,'\n'),enabled)===identityVariant(kernels.replace(/\r?\n/g,'\r\n'),enabled),
    'The limited identity conditional selector must accept both LF and CRLF sources.');
check(t.includes('HLGITrySurfaceMaterialHit(hit,surface)'),'Cache material lookup lost its complete geometry identity.');
// Actual sealed-room overlap: a roof-card anchor at x=11.971396 lies
// inside the left wall [11.85,12.15]. An interior query at x=13.985698
// must not read it through the wall's back-face-culled exit.
const firstFrontFace=(origin,target,minimum,maximum)=>{
    const direction=Math.sign(target-origin),length=Math.abs(target-origin);
    const face=direction>0?minimum:maximum;
    const distance=(face-origin)/direction;
    return distance>=.0001&&distance<length-.0001?distance:null;
};
check(firstFrontFace(11.971396,13.985698,11.85,12.15)===null,
    'Fixture must reproduce the embedded-anchor/back-face escape.');
check(firstFrontFace(13.985698,11.971396,11.85,12.15)!==null,
    'Query-to-anchor visibility must block the intersecting wall.');
check(firstFrontFace(13.985698,15.999998,11.85,12.15)===null,
    'An unobstructed interior cache connection must remain usable.');
const thinNearAnchor=firstFrontFace(0,1,.97,1.0);
check(thinNearAnchor>.94 && thinNearAnchor<.9999,
    'A RayBias=0.06 endpoint gap loses a thin blocker that the full segment sees.');
check(t.includes('float3visibilityOrigin=position+HLGIOffsetNormal(geometricNormal,shadingNormal)*_HLGI_RayBias;')&&
    t.includes('TraceSceneVisibilityHit(visibilityOrigin,connection/separation,separation-0.0001,'),
    'Cache visibility must start at the query and retain the complete offset segment.');
check(t.includes('abs(dot(delta,anchorGeometricNormal))'),'Cache layer test must use stored Ng.');
check(t.includes('dot(shadingNormal,e.normal.xyz)<0.85'),'Cache lighting compatibility must compare Ns with Ns.');
check(t.includes('HLGICachedSurface((int)hit.ownerSlot,hit.position,queryNg,shadingNormal,surface,cached)'),'Proxy bounce lost its separate geometry identity and shading normal.');
check(k.includes('CachedIrradiance(match,n)'),'Screen bounce must preserve the matched hit record and separate Ns.');
check(k.includes('HLGICachedSample(receiverHit,n,receiverCache)'),'Screen guide query must preserve its complete matched hit record.');
check(k.includes('hasGeometry?HLGIOffsetNormal(geometricNormal,n):n'),'A camera-facing history normal must not choose the wrong sampling side.');
check(k.includes('if(hasGeometry)worldMatch=HLGITryScreenWorldMatch'),'Invalid depth geometry must not query the world cache.');
check(k.includes('DirectIrradiance(p,n,biasNormal,receiverLayers,true,cameraRay,screenFootprint,directKnown)')&&
    k.includes('HLGITryScreenRayFootprint(uv,raw,p,cameraRay,screenFootprint)')&&
    k.includes('if(!directKnown){known=false;returntrue;}'),
    'Direct shading must separate Ns from offset geometry, preserve the screen spatial footprint/observer, use the captured receiver identity and propagate unknown shadows.');
check(k.includes('HLGITryScreenWorldMatch(uv,raw,p,geometricNormal,policy.x,match)')&&
    k.includes('footprint,_HLGI_MaterialView,hit)'),
    'The screen-world probe must retain the real pixel/depth footprint and camera material observer.');
check(!/dot\((?:mn|receiverNormal),n\)>0\.85/.test(k),'A screen-to-world match still compares Ng to Ns.');
check(k.includes('abs(hit.t-probeDistance)>max(0.002,min(_HLGI_RayBias,0.03))'),'Probe must require spatial agreement.');
check(k.includes('abs(dot(hit.rawNg,estimatedGeometricNormal))<0.85'),'Camera-facing screen Ng must match source geometry on either allowed material side.');
check(k.includes('float3towardCamera=WorldPosition('),'Normal orientation must come from the inverse-projected camera ray.');
check(k.includes('_HLGI_GeometryOut[id.xy]=HLGIPackScreenGeometry(n,geometricNormal,hasGeometry,depth)'),'Trace output must preserve separate Ns/Ng and receiver validity.');
check(k.includes('if(!hasGeometry){_HLGI_Output[pixel]=currentKnown?current:0;')&&
    k.includes('_HLGI_MomentsOut[pixel]=currentKnown?float4(lum,lum*lum,1,0):0;'),
    'Unknown geometry must preserve a measured current estimate, and reject unknown radiance without fabricated moments.');
check(k.includes('if(!hasGeometry){_HLGI_Output[pixel]=center;return;}'),'Unknown geometry must preserve the spatial current estimate.');
for(const [name,variant] of [['legacy',legacy],['identity',identity]]) {
    check(variant.includes('HLGIDecodeScreenGeometry(geometry,shadingNormal,geometricNormal,hasGeometry)')&&
        variant.includes('HLGIDecodeScreenGeometry(oldGeometry,oldShadingNormal,oldGeometricNormal,oldHasGeometry)'),name+': Temporal must decode distinct current and prior Ns/Ng.');
    check(variant.includes('oldReceiver&&oldHasGeometry&&dot(expectedNs,oldShadingNormal)>_HLGI_NormalThreshold')&&
        variant.includes('floatgeometricAgreement=dot(expectedNg,oldGeometricNormal);')&&variant.includes('geometricAgreement>0.85'),name+': Temporal must qualify both normal identities.');
    check(variant.includes('abs(dot(expectedP-oldP,expectedNg))<tolerance&&abs(dot(expectedP-oldP,oldGeometricNormal))<tolerance'),name+': Both geometric normals constrain the temporal plane.');
}
check(legacy.includes('float3expectedP=p,expectedNs=shadingNormal,expectedNg=geometricNormal;')&&
    legacy.includes('voidCSTemporal(')&&!legacy.includes('HLGITryReceiverMotion(')&&!legacy.includes('geometricAgreement=abs('),
    'Legacy temporal preserves the original world position and signed Ns/Ng checks without object-history transforms.');
check(identity.includes('identityValid=HLGITryReceiverMotion(identity,candidate,row,p,shadingNormal,geometricNormal,expectedP,expectedNs,expectedNg);')&&
    identity.includes('valid=_HLGI_HistoryValid!=0&&identityValid')&&identity.includes('HLGISameReceiverPrimitive(identity,'),
    'Object-history qualification must retain independent normals and exact receiver/primitive validity.');
check(rt.includes('float3ns=mul((float3x3)row.currentToPrevious,shadingNormal);')&&
    rt.includes('float3ng=mul((float3x3)row.currentToPrevious,geometricNormal);')&&
    rt.includes('previousShadingNormal=ns*rsqrt(ns2);previousGeometricNormal=ng*rsqrt(ng2);'),
    'Qualified object motion must transform and normalize Ns and Ng separately.');
check(!/dot\(qp-p,(?:geometry|g)\.xyz\)/.test(k),'A denoiser plane test still consumes packed geometry/Ns.');
check(k.includes('floatplaneDistance=max(abs(dot(qp-p,geometricNormal)),abs(dot(qp-p,neighborGeometricNormal)))'),'Spatial plane constraints must use Ng on both sides.');
check(k.includes('float3sum=center.rgb*4;floatweight=4;'),'Spatial filter must always preserve a valid center sample.');
check(c.includes('HLGIDecodeScreenGeometry(g,shadingNormal,geometricNormal,hasGeometry)'),'Upsampling must decode packed geometry.');
check(c.includes('float4sampleGI=_HLGI_GITexture.Load(int3(q,0));')&&
    c.includes('if(!HLGIHasRadianceMeasurement(sampleGI))continue;')&&
    c.includes('if(!hasGeometry){if(!sameFullPixel)continue;resolved=true;returnsampleGI;}'),
    'Unknown-Ng upsample support must preserve only a measured, finite own sample.');
check(c.indexOf('if(!HLGIHasRadianceMeasurement(sampleGI))continue;')<c.indexOf('if(!hasGeometry){'),
    'Radiance qualification must precede the authoritative unknown-Ng branch.');
check(c.includes('resolved=HLGIHasRadianceMeasurement(result);')&&c.includes('if(!HLGIHasRadianceMeasurement(gi))return0;'),
    'Overflowed or missing final interpolation cannot authorize native replacement.');
check(c.includes('dot(qp-p,geometricNormal)')&&!c.includes('dot(qp-p,n)'),'Upsample plane constraint must use the candidate Ng.');
check(c.includes('if(!resolved)return0;'),'An unresolved estimate must not remove native GI.');
console.log(JSON.stringify({status:'passed',scope:'Independent CPU geometry oracle and shader source contracts; no Unity/HLSL/GPU execution',assertions,planarCases,reproducedLegacyNormalPlaneCases:legacyRejected,screenPlaneCases,unknownResolveCases,unknownRadianceResolveCases,officialReference:'Unity Graphics feb4de2d9a93a4ae10d287d3a6d7003d08ea3e53 NormalReconstruction.hlsl ReconstructNormalTap9'},null,2));
