import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';

const [mode, directory] = process.argv.slice(2);
assert(['prepare', 'verify'].includes(mode) && directory, 'prepare|verify and artifact directory required');
const f = Math.fround;
const finite = a => a.every(Number.isFinite);
const measured = a => finite(a) && a[3] > 0;
const zero = () => [0, 0, 0, 0];
const cases = [];
function make(name, edits = {}) {
  const v = { name, incoming: [2, 3, 4, 1], control: [1, 4, 1, 1], initialSum: [1, 2, 3, 0],
    irradiance: [4, 5, 6, 7], guide: [0, 1, 0, 2], history: [2, 3, 4, .8], moments: [3, 10, 8, 1],
    hitSpec: [1 | 256 | 2 | 4, 1, 1, 1], guideSumPower: [1, 2, 3, 4], normal: [0, 0, 1, 1], purpose: [0, 1, 7, 0],
    footprint: [.2, .3, -1, .2], connection: [.3, .4, 1, 0], ...edits };
  for (const [key, value] of Object.entries(v)) if (Array.isArray(value)) v[key] = value.map(f);
  cases.push(v);
}
make('baseline');
make('unknown-positive-keeps-cache-and-history', { incoming: [0, 0, 0, 0], hitSpec: [513, 1, 1, 1] });
make('known-black-counts', { incoming: [0, 0, 0, 1] });
make('zero-weight-unknown-is-known-zero', { incoming: [NaN, Infinity, 0, -1], control: [0, 4, 1, 1], hitSpec: [513, 1, 1, 1] });
make('hard-invalidated-does-not-resurrect', { incoming: [0, 0, 0, 0], irradiance: zero(), guide: zero(), history: [2, 3, 4, .8], control: [1, 4, 0, 0], hitSpec: [513, 1, 1, 1] });
make('unknown-invalid-old-cache', { incoming: [0, 0, 0, 0], irradiance: [NaN, 2, 3, 7] });
make('unknown-invalid-old-guide', { incoming: [0, 0, 0, 0], guide: [NaN, 1, 0, 2] });
make('unknown-no-history', { history: zero() });
make('unknown-no-moments', { moments: zero() });
make('unknown-nan-history', { history: [NaN, 0, 0, 1] });
make('unknown-inf-moments', { moments: [0, Infinity, 8, 1] });
make('negative-weight', { control: [-1, 4, 1, 1] });
make('nonfinite-weight', { control: [NaN, 4, 1, 1] });
make('nonfinite-guide-power', { guideSumPower: [1, 2, 3, Infinity] });
make('overflow-guide-length', { guideSumPower: [3e30, 3e30, 3e30, 2] });
make('overflow-sample', { incoming: [3e38, 3e38, 3e38, 1], control: [2, 4, 1, 1] });
make('shadow-off-ignores-invalid-strength', { hitSpec: [17,1,1,3], normal: [0,0,1,NaN] });
make('shadow-on-rejects-invalid-strength', { hitSpec: [17,1,1,1], normal: [0,0,1,NaN] });
for (const flags of [0, 1, 513, 17, 529]) for (const owner of [0, 1])
  for (const material of [0, 1]) for (const payload of [0, 1, 3, 5, 7]) for (const strength of [0, .5, 1])
    make(`query-${flags}-${owner}-${material}-${payload}-${strength}`, { hitSpec: [flags, owner, material, payload], normal: [0, 0, 1, strength] });
// Full-map failure must not poison a coverage-only request; coverage uncertainty
// must still retain the nearest blocker. Cross all query purposes independently.
for(const shadow of [0,1]) for(const resolve of [0,1]) for(let deps=0;deps<8;deps++)
  for(const footprint of [0,1,2,3,4])
    make(`purpose-${shadow}-${resolve}-${deps}-${footprint}`,{purpose:[shadow,resolve,deps,footprint]});
let seed = 0x6139cafe;
function random() { seed ^= seed << 13; seed ^= seed >>> 17; seed ^= seed << 5; return (seed >>> 0) / 4294967296; }
for (let i = 0; i < 2048; i++) {
  const rgb = () => [random() * 8, random() * 8, random() * 8];
  make(`fuzz-${i}`, { incoming: [...rgb(), random() < .25 ? 0 : random()], control: [random() < .2 ? 0 : random() * 2, [1, 2, 4, 8][i % 4], i % 7 ? 1 : 0, i % 5 ? 1 : 0],
    initialSum: [...rgb(), 0], irradiance: [...rgb(), i % 9 ? 1 + i % 32 : 0], guide: [...rgb(), random() * 3],
    history: [...rgb(), i % 8 ? .7 : 0], moments: [2, 5, i % 10 ? 3 : 0, 1],
    guideSumPower: [...rgb(), random() * 8], hitSpec: [i % 3 ? 17 : 529, i % 4 ? 1 : 0, i % 2, (i >>> 1) % 2], normal: [0, 0, 1, i % 2] });
}
for (const [name, footprint, connection] of [
  ['directional-normal', [0,0,-1,.3], [0,0,1,0]],
  ['directional-tilted', [.8,-.2,-.4,.7], [.7,.4,1,0]],
  ['directional-grazing-unknown', [1,0,0,.3], [.2,.1,1,0]],
  ['directional-zero-radius', [.2,.3,-1,0], [.7,.4,1,0]],
  ['point-biased-focus', [.8,-.2,-.4,.7], [2,1,3,1]],
  ['point-near-biased-focus', [.2,.3,-1,.1], [.3,-.4,.8,1]],
  ['point-zero-radius', [.2,.3,-1,0], [.25,-.5,.8,1]],
  ['point-invalid-radius', [.2,.3,-1,-1], [2,1,3,1]],
]) make(name, {footprint, connection});

const dot=(a,b)=>a.reduce((sum,x,i)=>sum+x*b[i],0);
const sub=(a,b)=>a.map((x,i)=>x-b[i]);
const scale=(a,s)=>a.map(x=>x*s);
const unit=a=>scale(a,1/Math.hypot(...a));
const cross=(a,b)=>[a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]];
const footprintCache=new Map();
// Independent double oracle: intersect a circle's rays with z=0, project that
// ellipse onto the outgoing ray plane and search its boundary (8192 angles).
// This does not reproduce the production maximum-singular-value formula.
function shadowConnection(v) {
  const key=JSON.stringify([v.footprint,v.connection]);
  if(footprintCache.has(key)) return footprintCache.get(key);
  const p=[.25,-.5,.75], origin=[.25,-.5,.75+f(.03)], point=v.connection[3]>.5;
  const connection=point?sub(v.connection.slice(0,3),p):v.connection.slice(0,3);
  const toLight=unit(connection), biased=point?sub(v.connection.slice(0,3),origin):connection;
  const direction=unit(biased), distance=point?Math.hypot(...biased):2;
  const source=unit(v.footprint.slice(0,3)), radius=v.footprint[3];
  const valid=Number.isFinite(radius)&&radius>=0&&finite(source)&&Math.abs(source[2])>=1e-6;
  let projected=0;
  if(valid&&radius>0) {
    const u=unit(cross(source,Math.abs(source[2])<.9?[0,0,1]:[0,1,0])),w=cross(source,u);
    for(let i=0;i<8192;i++) {
      const angle=2*Math.PI*i/8192;
      const circle=u.map((x,j)=>radius*(x*Math.cos(angle)+w[j]*Math.sin(angle)));
      const plane=sub(circle,scale(source,circle[2]/source[2]));
      projected=Math.max(projected,Math.hypot(...sub(plane,scale(direction,dot(plane,direction)))));
    }
  }
  const d2=dot(connection,connection), attenuation=point?(1-(d2/100)**2)**2/d2:1;
  const light=Math.max(0,toLight[2])*attenuation;
  const result=[[...origin,Math.max(0,distance-f(.03))],[...direction,1],
    [projected,point?-projected/distance:0,valid?1:0,1],[...p,1],[light,light,light,1]];
  footprintCache.set(key,result);return result;
}

function accumulate(incoming, weight, initial) {
  const sum = initial.slice(0, 3);
  if (!Number.isFinite(weight) || weight < 0) return { accepted: false, sum };
  if (weight === 0) return { accepted: true, sum };
  if (!measured(incoming)) return { accepted: false, sum };
  const next = sum.map((value, i) => f(value + f(incoming[i] * weight)));
  return finite(next) ? { accepted: true, sum: next } : { accepted: false, sum };
}
function commit(v, known, sum, guideSum, power) {
  let irradiance = v.irradiance.slice(), guide = v.guide.slice();
  if (!measured(irradiance) || !finite(guide)) { irradiance = zero(); guide = zero(); }
  const rays = Math.trunc(v.control[1]);
  if (!known || rays <= 0 || !finite(sum) || !finite(guideSum) || !Number.isFinite(power) || power < 0 || !finite(v.normal.slice(0, 3)))
    return { committed: false, irradiance, guide };
  const estimate = sum.map(x => f(x / rays)), samples = Math.min(irradiance[3] + 1, 32), alpha = Math.max(1 / samples, .1);
  const next = [...estimate.map((x, i) => f(irradiance[3] > 0 ? irradiance[i] * (1 - alpha) + x * alpha : x)), samples];
  const lengthSquared = f(f(f(guideSum[0] * guideSum[0]) + f(guideSum[1] * guideSum[1])) + f(guideSum[2] * guideSum[2]));
  const nextGuide = [...(lengthSquared > 1e-12 ? guideSum.map(x => f(x / Math.sqrt(lengthSquared))) : v.normal.slice(0, 3)), f(power / rays)];
  if (!measured(next) || !finite(nextGuide) || !Number.isFinite(lengthSquared)) return { committed: false, irradiance, guide };
  return { committed: true, irradiance: next, guide: nextGuide };
}
function expected(v) {
  const sample = accumulate(v.incoming, v.control[0], v.initialSum);
  const cache = commit(v, sample.accepted && v.control[2] > 0, sample.sum, v.guideSumPower.slice(0, 3), v.guideSumPower[3]);
  const hasHistory = measured(v.history) && finite(v.moments) && v.moments[2] > 0;
  const retained = hasHistory && v.control[3] > 0;
  const [flags, owner, material, payload] = v.hitSpec, hit = !!(flags & 1), materialKnown = !(flags & 512), affects=!(payload&4);
  const shadowKnown = !hit || materialKnown, strength = v.normal[3];
  const directKnown = !affects || (Number.isFinite(strength) && (strength <= 0 || shadowKnown));
  const direct = affects && directKnown ? (hit ? 1 - strength : 1) : 0;
  const receives=!(flags&16) || !(payload&2), proxyDirectKnown=!receives || directKnown;
  const proxyDirect=receives?direct:(affects?1:0);
  let confidence = 0;
  if (hit && owner && materialKnown) confidence = (flags & 16) ? (payload&1 ? 1 : 0) : material ? .8 : .1;
  if (!proxyDirectKnown) confidence = 0;
  const cached=material?[.8,.4,.2]:[0,0,0];
  const proxy = confidence > 0 ? (flags&16 ? [.1+.2*(proxyDirect+.25*cached[0]),.2+.4*(proxyDirect+.25*cached[1]),.3+.6*(proxyDirect+.25*cached[2]),confidence] : [.5*direct,.5*direct,.5*direct,confidence]) : zero();
  const propagated = accumulate(proxy, v.control[0], [0, 0, 0]);
  const propagatedCache = commit(v, propagated.accepted, propagated.sum, [0, 0, 0], 0);
  const [shadowPurpose,resolveMaterial,deps,footprint]=v.purpose;
  // Material view is not a blanket prerequisite: the real bridge determines
  // parallax dependencies. Our call spy models a material which ignores view.
  const footprintKnown=footprint===0||footprint===2||footprint===4;
  const coverageKnown=footprintKnown&&!!(deps&1), covered=!!(deps&2);
  const fullCalled=coverageKnown&&covered&&!!resolveMaterial&&!shadowPurpose;
  const materialUnknown=!coverageKnown||!covered||(fullCalled&&!(deps&4));
  const published=fullCalled&&!!(deps&4);
  const resolvedFlags=17|(materialUnknown?512:0)|(published?1152:0);
  return [ [...sample.sum, sample.accepted ? 1 : 0], cache.irradiance, cache.guide,
    retained ? v.history : zero(), retained ? v.moments : zero(), [1, directKnown ? 1 : 0, 1, directKnown ? .5 * direct : 0],
    proxy, [direct, direct, direct, directKnown ? 1 : 0], [hit ? 1 : 0, materialKnown ? 1 : 0, hit ? 1 : 0, shadowKnown ? 1 : 0],
    [cache.committed ? 1 : 0, measured(v.incoming) ? 1 : 0, hasHistory ? 1 : 0, retained ? 1 : 0], propagatedCache.irradiance, propagatedCache.guide,
    [affects?1:0,affects?1:0,affects?1:0,1], [!materialKnown||material?1:0,1,0,1],
    [resolvedFlags,footprintKnown?1:0,fullCalled?1:0,footprintKnown&&shadowPurpose?1:0],
    [...(published?[.2,.4,.6]:[0,0,0]),materialUnknown?0:1],
    ...shadowConnection(v),[direct,direct,direct,hit?1:0],proxy ];
}
if (mode === 'prepare') {
  const buffer = Buffer.alloc(4 + cases.length * 208); buffer.writeUInt32LE(cases.length);
  const keys = ['incoming', 'control', 'initialSum', 'irradiance', 'guide', 'history', 'moments', 'hitSpec', 'guideSumPower', 'normal', 'purpose','footprint','connection'];
  cases.forEach((v, i) => keys.forEach((key, row) => v[key].forEach((x, lane) => {
    const address = 4 + i * 208 + row * 16 + lane * 4;
    if (key === 'hitSpec' || key === 'purpose') buffer.writeUInt32LE(x >>> 0, address); else buffer.writeFloatLE(x, address);
  })));
  fs.writeFileSync(path.join(directory, 'inputs.bin'), buffer);
  fs.writeFileSync(path.join(directory, 'oracle.json'), JSON.stringify({ count: cases.length, names: cases.map(v => v.name), seed: '0x6139cafe', inputStride: 208, outputStride: 368 }, null, 2));
  console.log(`Prepared ${cases.length} actual-HLSL radiance validity cases.`);
} else {
  const bytes = fs.readFileSync(path.join(directory, 'outputs.bin'));
  assert.equal(bytes.length, cases.length * 368);
  let checks = 0, maxError = 0;
  cases.forEach((v, index) => expected(v).forEach((row, r) => row.forEach((target, lane) => {
    const address = index * 368 + r * 16 + lane * 4;
    const actual = r === 8 || r === 9 || r===13 || r===14 ? bytes.readUInt32LE(address) : bytes.readFloatLE(address);
    checks++;
    if (Number.isNaN(target)) assert(Number.isNaN(actual), `${v.name} row${r}.${lane}: expected NaN`);
    else if (!Number.isFinite(target)) assert.equal(actual, target, `${v.name} nonfinite lane`);
    else { const error = Math.abs(actual - target); maxError = Math.max(maxError, error); assert(error <= 2e-4 * Math.max(1, Math.abs(target)), `${v.name} row${r}.${lane}: ${actual} != ${target}`); }
    // These are copies/zeros, not estimates. No tolerance may conceal a sample
    // count increment, retained-history mutation or resurrection after invalidation.
    if (r === 3 || r === 4 || r === 8 || r === 9 || r===13 || r===14) { checks++;assert.equal(actual, f(target), `${v.name} exact state`); }
  })));
  const report = { status: 'passed', count: cases.length, checks, maxError,
    scope: 'Actual production HLSL validity/commit helpers and extracted committed-material/query/radiance functions (explicit bridge call spy) on D3D12 WARP with explicit scene/texture adapters; not DXR traversal, Unity, full temporal reprojection, texture filtering or physical GPU validation.' };
  fs.writeFileSync(path.join(directory, 'oracle-results.json'), JSON.stringify(report, null, 2));
  console.log(JSON.stringify(report));
}
