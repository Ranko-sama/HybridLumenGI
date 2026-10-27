// Independent integer/nearest-center and camera projection oracles, plus source
// contracts. This executes CPU math; it is not Unity, HLSL execution, or GPU evidence.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
const root = new URL('../', import.meta.url);
const helper = readFileSync(new URL('Runtime/Resources/HybridLumenGI/HybridLumenGIScreenSampling.hlsl', root), 'utf8');
const kernels = readFileSync(new URL('Runtime/Resources/HybridLumenGI/HybridLumenGIKernels.hlsl', root), 'utf8');
const composite = readFileSync(new URL('Runtime/Resources/HybridLumenGI/HybridLumenGIComposite.shader', root), 'utf8');
const compact = text => text.replace(/\/\*[\s\S]*?\*\//g, '').replace(/\/\/[^\n]*/g, '').replace(/\s+/g, '');
// Resolve only HLGI_RECEIVER_IDENTITY so source contracts cannot accidentally
// match the other branch. Other platform conditions remain source text.
function identityVariant(source,enabled) {
    let active=true;const stack=[],output=[];
    for(const line of source.split(/\r?\n/)) {
        const directive=line.match(/^\s*#\s*(if|ifdef|ifndef|else|elif|endif)\b(.*)$/);
        if(!directive) {if(active)output.push(line);continue;}
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
let checks = 0;
function check(condition, message) { assert.ok(condition, message); checks++; }
const f = Math.fround;
const clamp = (x, lo, hi) => Math.min(Math.max(x, lo), hi);
const samplePixel = (i, low, full) => Math.floor(((2 * i + 1) * full) / (2 * low));
const exactPixel = (i, low, full) => Number((BigInt(2 * i + 1) * BigInt(full)) / BigInt(2 * low));
const sampleUv = (i, low, full) => f(f(samplePixel(i, low, full) + .5) / full);

// Float32 translation of the bounded GPU candidate selection. The oracle below
// instead binary-searches the entire discrete center set generated with BigInt.
function closest(uv, low, full) {
    const base = clamp(Math.floor(f(uv * low)), 0, low - 1), target = f(uv * full);
    let best = Math.max(base - 1, 0), distance = f(Math.abs(f(samplePixel(best, low, full) + .5) - target));
    for (const offset of [0, 1]) {
        const candidate = Math.min(base + offset, low - 1);
        const d = f(Math.abs(f(samplePixel(candidate, low, full) + .5) - target));
        if (d < distance) { best = candidate; distance = d; }
    }
    return best;
}
function oracle(uv, centers, full) {
    const target = f(uv * full);
    let lo = 0, hi = centers.length;
    while (lo < hi) { const mid = (lo + hi) >>> 1; if (centers[mid] < target) lo = mid + 1; else hi = mid; }
    if (lo === 0) return 0;
    if (lo === centers.length) return lo - 1;
    return target - centers[lo - 1] <= centers[lo] - target ? lo - 1 : lo;
}
function footprint(uv,low,full) {
    const nearest=closest(uv,low,full),target=f(uv*full),center=samplePixel(nearest,low,full)+.5;
    const lower=target<center?Math.max(nearest-1,0):nearest,upper=target<center?nearest:Math.min(nearest+1,low-1);
    const lo=samplePixel(lower,low,full)+.5,hi=samplePixel(upper,low,full)+.5;
    return {lower,upper,fraction:hi>lo?clamp((target-lo)/(hi-lo),0,1):0};
}
let seed = 0x8c31d209;
function random() { seed ^= seed << 13; seed ^= seed >>> 17; seed ^= seed << 5; return (seed >>> 0) / 4294967296; }
const dimensions = [[1,1],[2,1],[3,1],[3,2],[5,2],[5,3],[7,3],[7,4],[9,4],[11,7],
    [13,8],[17,5],[19,11],[31,15],[63,31],[64,17],[127,63],[255,127],[257,128],
    [1919,959],[1920,960],[1921,960],[1921,961],[2161,721],[3841,1920],[4095,1023],
    [8191,2047],[16384,8192],[16383,8191],[16384,16384]];
let nearestCases = 0, footprintCases = 0, legacyNearestFailures = 0, legacyFloatMappingFailures = 0;
for (const [full, low] of dimensions) {
    const centers = Array.from({length: low}, (_, i) => exactPixel(i, low, full) + .5);
    const targets = [f(1e-8), f(1 - 1e-7)];
    for (let i = 0; i < low; i++) {
        const pixel = samplePixel(i, low, full), uv = sampleUv(i, low, full);
        check(pixel === exactPixel(i, low, full), 'Integer GI-to-full mapping differs from exact rational arithmetic.');
        check(pixel >= 0 && pixel < full, 'A mapped full pixel is outside the image.');
        check(i === 0 || pixel > samplePixel(i - 1, low, full), 'GI samples must have distinct ordered full centers.');
        check(Math.floor(f(uv * full)) === pixel, 'Encoded center no longer addresses its original full pixel.');
        check(closest(uv, low, full) === i, 'Zero motion must choose the same stored GI texel.');
        const legacyPixel = Math.floor(f(f(f(i + .5) * f(1 / low)) * full));
        if (legacyPixel !== pixel) legacyFloatMappingFailures++;
        targets.push(uv);
        if (i + 1 < low) {
            const midpoint = (centers[i] + centers[i + 1]) / 2;
            for (const delta of [-.001, 0, .001]) targets.push(f((midpoint + delta) / full));
        }
    }
    for (let i = 0; i < 600; i++) targets.push(f(random()));
    for (const uv of targets) {
        const expected = oracle(uv, centers, full), actual = closest(uv, low, full);
        check(actual === expected, `Nearest actual sample mismatch for ${full}/${low} at ${uv}.`);
        const fp=footprint(uv,low,full),target=clamp(f(uv*full),centers[0],centers.at(-1));
        check(fp.lower>=0&&fp.upper<low&&fp.lower<=fp.upper,'Bilinear footprint outside image.');
        check(fp.upper-fp.lower<=1,'Bilinear footprint must use adjacent actual samples.');
        check(fp.fraction>=0&&fp.fraction<=1,'Bilinear fraction outside [0,1].');
        const linear=x=>.713*x-2.87;
        const reconstructed=linear(centers[fp.lower])*(1-fp.fraction)+linear(centers[fp.upper])*fp.fraction;
        check(Math.abs(reconstructed-linear(target))<1e-9,'Actual-center interpolation must reconstruct linear data (clamped at edges).');
        if(centers[actual]===f(uv*full)) {
            check((fp.lower===actual&&fp.fraction===0)||(fp.upper===actual&&fp.fraction===1),'Sample center must have 100% self weight.');
        }
        if (Math.min(Math.floor(f(uv * low)), low - 1) !== expected) legacyNearestFailures++;
        nearestCases++;footprintCases++;
    }
}
check(dimensions.filter(([full, low]) => full % low !== 0).length >= 20, 'Need at least 20 non-integer size ratios.');
check(legacyNearestFailures > 100, 'The nearest-history tests must reproduce the old uniform-cell error.');
check(legacyFloatMappingFailures > 0, 'The mapping tests must reproduce float reciprocal boundary errors.');

// A 2x downsample stores GI[10] at full center 21.5, not at 21. Motion 1.25
// full pixels predicts 20.25. The nearest stored centers are 19.5 and 21.5.
// Starting at 21 instead predicts 19.75: this is a real positional error
// even where the corrected nearest-neighbor lookup happens to choose the same cell.
const oldOrigin = (10 + .5) / 960, trueOrigin = sampleUv(10, 960, 1920), motion = 1.25 / 1920;
check(Math.abs((trueOrigin - oldOrigin) * 1920 - .5) < 2e-6, 'Half-resolution start-center counterexample disappeared.');
check(Math.abs((trueOrigin - motion) * 1920 - 20.25) < 2e-6, 'Motion origin must be the full depth center.');
// Target 20.25 lies in virtual GI cell 10 but is closer to stored GI[9] at
// 19.5 than GI[10] at 21.5. The actual boundary is 20.5, not 20.
check(closest(f(20.25 / 1920), 960, 1920) === 9, 'Actual-center nearest selection counterexample disappeared.');
check(Math.floor(f(f(20.25 / 1920) * 960)) === 10, 'Old uniform-cell selection counterexample disappeared.');
const centered=footprint(f(1.5/4),2,4);
check(centered.lower===0&&centered.fraction===0,'At F4/L2 sample 1.5, interpolation must be 100% GI[0].');
check((1.5/4*2-.5)%1===.25,'Legacy uniform-grid 25% neighbor leak counterexample disappeared.');

const add = (a,b) => a.map((x,i) => x+b[i]);
const sub = (a,b) => a.map((x,i) => x-b[i]);
const scale = (v,s) => v.map(x=>x*s);
const dot = (a,b) => a.reduce((sum,x,i)=>sum+x*b[i],0);
const identity = () => [[1,0,0,0],[0,1,0,0],[0,0,1,0],[0,0,0,1]];
const mm = (a,b) => a.map(row => b[0].map((_,j)=>row.reduce((sum,x,k)=>sum+x*b[k][j],0)));
const mv = (a,v) => a.map(row=>dot(row,v));
function inverse(matrix) {
    const rows = matrix.map((row,i)=>[...row,...identity()[i]]);
    for(let c=0;c<4;c++) {
        let pivot=c;for(let r=c+1;r<4;r++) if(Math.abs(rows[r][c])>Math.abs(rows[pivot][c])) pivot=r;
        [rows[c],rows[pivot]]=[rows[pivot],rows[c]];
        const d=rows[c][c];check(Math.abs(d)>1e-12,'Camera matrix must be invertible.');
        rows[c]=rows[c].map(x=>x/d);
        for(let r=0;r<4;r++) if(r!==c) {const s=rows[r][c];rows[r]=rows[r].map((x,i)=>x-s*rows[c][i]);}
    }
    return rows.map(row=>row.slice(4));
}
function camera({ortho,reverse,top,clipMinusOne,jitter,translation}) {
    const near=.1,far=100,aspect=1.7;
    let p;
    if(ortho) p=[[1/aspect,0,0,0],[0,1,0,0],[0,0,reverse?1/(far-near):-1/(far-near),reverse?far/(far-near):-near/(far-near)],[0,0,0,1]];
    else p=[[1/aspect,0,0,0],[0,1,0,0],[0,0,reverse?near/(far-near):-far/(far-near),reverse?near*far/(far-near):-near*far/(far-near)],[0,0,-1,0]];
    if(clipMinusOne && !reverse) p[2]=p[2].map((x,i)=>2*x-p[3][i]);
    const view=identity();for(let i=0;i<3;i++) view[i][3]=-translation[i];
    const noJitter=mm(p,view),j=identity();j[0][3]=2*jitter[0];j[1][3]=2*jitter[1]*(top?-1:1);
    const vp=mm(j,noJitter),inv=inverse(vp);
    function project(position,matrix=vp) {
        const c=mv(matrix,[...position,1]),ndc=c.slice(0,3).map(x=>x/c[3]);
        return {uv:[ndc[0]*.5+.5,top?.5-ndc[1]*.5:ndc[1]*.5+.5],raw:clipMinusOne&&!reverse?ndc[2]*.5+.5:ndc[2],w:c[3]};
    }
    function world(uv,raw) {
        const p=mv(inv,[uv[0]*2-1,(uv[1]*2-1)*(top?-1:1),clipMinusOne&&!reverse?raw*2-1:raw,1]);
        return p.slice(0,3).map(x=>x/p[3]);
    }
    return {project,world,noJitter,jitter,nearDepth:reverse?1:0,farDepth:reverse?0:1};
}
const planeN=[.21,-.13,1],planeP=[0,0,-6];
function pointOnPlane(cam,uv) {
    const a=cam.world(uv,cam.nearDepth),b=cam.world(uv,cam.farDepth),d=sub(b,a);
    return add(a,scale(d,dot(planeN,sub(planeP,a))/dot(planeN,d)));
}
let projectionCases=0, oldFractionalPositionErrors=0, oldMotionOriginErrors=0;
for(const ortho of [false,true]) for(const reverse of [false,true]) for(const top of [false,true]) for(const clipMinusOne of [false,true]) {
    for(const [full,low] of dimensions.slice(3)) for(const movingCamera of [false,true]) {
        const height=Math.min(16384,full+2),lowHeight=Math.min(height,low+1),pixel=[Math.floor(low*.53),Math.floor(lowHeight*.47)];
        const uv=[sampleUv(pixel[0],low,full),sampleUv(pixel[1],lowHeight,height)];
        const jCurrent=[.31/full,-.23/height],jPrevious=[-.17/full,.41/height];
        const settings={ortho,reverse,top,clipMinusOne};
        const current=camera({...settings,jitter:jCurrent,translation:movingCamera?[.04,-.03,.02]:[0,0,0]});
        const previous=camera({...settings,jitter:jPrevious,translation:[0,0,0]});
        const p=pointOnPlane(current,uv),depth=current.project(p).raw;
        check(Math.hypot(...sub(current.world(uv,depth),p))<2e-10,'Full-center depth inverse projection failed.');
        const currentNoJitter=current.project(p,current.noJitter).uv,previousNoJitter=previous.project(p,previous.noJitter).uv;
        const velocity=sub(currentNoJitter,previousNoJitter);
        const byMotion=add(sub(uv,velocity),sub(jPrevious,jCurrent));
        const byProjection=previous.project(p).uv;
        check(Math.hypot(...sub(byMotion,byProjection))<1e-11,'Motion+jitter differs from previous jittered projection.');
        const noMotion=previous.project(current.world(uv,depth)).uv;
        check(Math.hypot(...sub(noMotion,byProjection))<1e-11,'No-motion static-world fallback projection differs.');
        const oldOriginUv=[(pixel[0]+.5)/low,(pixel[1]+.5)/lowHeight];
        if(Math.hypot(...sub(add(sub(oldOriginUv,velocity),sub(jPrevious,jCurrent)),byProjection))>1e-7) oldMotionOriginErrors++;
        const oldPixel=[closest(f(byMotion[0]),low,full),closest(f(byMotion[1]),lowHeight,height)];
        const oldUv=[sampleUv(oldPixel[0],low,full),sampleUv(oldPixel[1],lowHeight,height)];
        const oldP=pointOnPlane(previous,oldUv),oldDepth=previous.project(oldP).raw;
        const reconstructed=previous.world(oldUv,oldDepth);
        check(Math.hypot(...sub(reconstructed,oldP))<2e-10,'Previous depth must use its stored full-pixel center.');
        check(Math.abs(dot(planeN,sub(reconstructed,planeP)))<2e-10,'Stored-center reconstruction must stay on the original plane.');
        const wrong=previous.world(byMotion,oldDepth);
        if(Math.abs(dot(planeN,sub(wrong,planeP)))>1e-7) oldFractionalPositionErrors++;
        projectionCases++;
    }
}
check(oldFractionalPositionErrors>100,'Fractional-UV/point-depth mismatch must have explicit counterexamples.');
check(oldMotionOriginErrors>100,'Motion tests must exercise a different full and GI center.');
for(const uv of [[NaN,.5],[Infinity,.5],[-Infinity,.5],[-.1,.5],[1,.5],[0,.5]]) {
    check(!(uv.every(Number.isFinite)&&uv.every(x=>x>0&&x<1)),'Nonfinite/offscreen reprojection must reject before integer conversion.');
}
// Separable 2D nearest choice agrees with a brute-force Euclidean search.
for(let i=0;i<1000;i++) {
    const full=[17,19],low=[5,7],uv=[f(random()),f(random())],target=uv.map((v,k)=>f(v*full[k]));
    const selected=uv.map((v,k)=>closest(v,low[k],full[k]));
    let best=[0,0],bestD=Infinity;
    for(let y=0;y<low[1];y++) for(let x=0;x<low[0];x++) {
        const d=(exactPixel(x,low[0],full[0])+.5-target[0])**2+(exactPixel(y,low[1],full[1])+.5-target[1])**2;
        if(d<bestD) {best=[x,y];bestD=d;}
    }
    check(selected[0]===best[0]&&selected[1]===best[1],'Separable nearest center differs from 2D brute force.');
}

const h=compact(helper),k=compact(kernels);
const legacyKernel=compact(identityVariant(kernels,false)),identityKernel=compact(identityVariant(kernels,true));
for(const enabled of [false,true]) check(
    identityVariant(kernels.replace(/\r?\n/g,'\n'),enabled)===identityVariant(kernels.replace(/\r?\n/g,'\r\n'),enabled),
    'The identity selector must preserve the same branch for LF and CRLF sources.');
check(h.includes('return((giPixel*2u+1u)*fullSize)/(giSize*2u);'),'Exact integer full-pixel mapping contract changed.');
check(h.includes('candidateDistance.x<bestDistance.x')&&h.includes('candidateDistance.y<bestDistance.y'),'Nearest selection must compare actual centers with stable tie handling.');
check(h.includes('voidHLGIGiBilinearFootprint(')&&h.includes('hi.x>lo.x?saturate((target.x-lo.x)/(hi.x-lo.x)):0'),'Bilinear interpolation must use actual stored-center distances and handle zero edge spans.');
check(k.includes('#include"HybridLumenGIScreenSampling.hlsl"'),'Kernel must include the shared sampling helper.');
check(!k.includes('uv=(floor(uv*_HLGI_FullSize.xy)+0.5)'),'WorldPosition must not snap a second time.');
check(k.includes('floatdepth=_HLGI_Depth.Load(int3(fullPixel,0));'),'Trace depth must load the exact integer full pixel.');
for(const [name,variant] of [['legacy',legacyKernel],['identity',identityKernel]]) {
    check(variant.includes('uint2fullPixel=HLGIFullPixelForGiPixel(id.xy,(uint2)_HLGI_Size.xy,(uint2)_HLGI_FullSize.xy);')&&
        variant.includes('float2uv=HLGIFullPixelCenterUv(fullPixel,(uint2)_HLGI_FullSize.xy);')&&
        variant.includes('float2motionUV=uv-_HLGI_Motion.Load(int3(fullPixel,0))+_HLGI_JitterDelta.xy;'),
        name+': Motion must start and load at the same selected full pixel as depth, with exactly one jitter delta.');
}
check(legacyKernel.includes('prevUV=motionUV;')&&!legacyKernel.includes('abs(motionUV-prevUV)')&&!legacyKernel.includes('HLGITryReceiverMotion('),
    'Legacy motion retains the original full-center assignment without requiring object identity.');
check(identityKernel.includes('if(all(isfinite(motionUV))&&all(abs(motionUV-prevUV)*_HLGI_FullSize.xy<=1))prevUV=motionUV;')&&
    identityKernel.includes('float2prevUV=ProjectUV(expectedP,_HLGI_PreviousVP,w);'),
    'Identity motion may override verified pose projection only when finite and within one full texel.');
check(k.includes('all(isfinite(prevUV))')&&k.includes('if(valid)previousPixel=(int2)HLGIClosestGiPixel('),'Validate finite/in-bounds UV before integer history lookup.');
check(k.includes('float3oldP=WorldPosition(HLGIGiSampleUv('),'Old depth must reconstruct at its selected full center.');
check((k.match(/WorldPosition\(HLGIGiSampleUv\(/g)||[]).length===4,'Temporal neighborhood and filter must use the same GI sample mapping.');
check(!k.includes('WorldPosition((q+0.5)')&&!k.includes('WorldPosition((pixel+0.5)'),'Low-resolution centers cannot directly reconstruct full-resolution point depths.');
check(legacyKernel.includes('float3expectedP=p,expectedNs=shadingNormal,expectedNg=geometricNormal;')&&
    legacyKernel.includes('distance(expectedP,oldP)<tolerance')&&legacyKernel.includes('dot(expectedNs,oldShadingNormal)>_HLGI_NormalThreshold')&&
    !legacyKernel.includes('HLGISameReceiverPrimitive('),
    'Legacy reconstruction must preserve the original world-position/normal rejection rather than silently accepting object motion.');
check(identityKernel.includes('identityValid=HLGITryReceiverMotion(identity,candidate,row,p,shadingNormal,geometricNormal,expectedP,expectedNs,expectedNg);')&&
    identityKernel.includes('valid=_HLGI_HistoryValid!=0&&identityValid')&&
    identityKernel.includes('valid=valid&&HLGISameReceiverPrimitive(identity,_HLGI_IdentityPrevious.Load(int3(previousPixel,0)));')&&
    identityKernel.includes('distance(expectedP,oldP)<tolerance')&&identityKernel.includes('dot(expectedNs,oldShadingNormal)>_HLGI_NormalThreshold'),
    'Object-history reconstruction requires qualified pose and same receiver/primitive, while retaining depth/normal rejection.');
for(const [name,variant] of [['legacy',legacyKernel],['identity',identityKernel]]) check(
    variant.includes('boolcurrentKnown=HLGIHasRadianceMeasurement(current);')&&
    variant.includes('currentKnown=currentKnown&&isfinite(lum)&&isfinite(lum*lum)&&all(isfinite(current.rgb*current.rgb));')&&
    variant.includes('if(!hasGeometry){_HLGI_Output[pixel]=currentKnown?current:0;_HLGI_MomentsOut[pixel]=currentKnown?float4(lum,lum*lum,1,0):0;return;}'),
    name+': Unknown Ng must preserve measured current GI while rejecting unknown/nonfinite GI and moments.');
const c=compact(composite);
check(c.includes('HLGIGiBilinearFootprint(uv,(uint2)_HLGI_Size.xy,fullSize,lower,upper,f);'),'Composite weights must use actual GI sample positions.');
check(c.includes('uint2q=uint2(x==0?lower.x:upper.x,y==0?lower.y:upper.y);'),'Composite must load the selected actual-center neighbors.');
check(c.includes('boolsameFullPixel=all(sampleFullPixel==fullPixel);')&&c.includes('HLGIFullPixelForGiPixel(q,(uint2)_HLGI_Size.xy,fullSize)'),'Unknown geometry can resolve only its exact captured full pixel.');
check(c.includes('floatdepth=_HLGI_Depth.Load(int3(fullPixel,0));')&&c.includes('float2uv=HLGIFullPixelCenterUv(fullPixel,fullSize);'),'Composite reconstruction must use the center of its loaded depth.');
check(!c.includes('float2texel=uv*_HLGI_Size.xy-0.5;')&&!c.includes('sampleUV=(q+0.5)'),'Uniform low-resolution centers must not replace actual stored sample centers.');
console.log(JSON.stringify({status:'passed',checks,dimensionPairs:dimensions.length,nonIntegerRatios:dimensions.filter(([a,b])=>a%b!==0).length,
    nearestCases,footprintCases,projectionCases,legacyNearestFailures,legacyFloatMappingFailures,oldMotionOriginErrors,oldFractionalPositionErrors,
    scope:'CPU independent integer/nearest-center and projection oracles plus source contracts; no Unity/GPU execution'},null,2));
