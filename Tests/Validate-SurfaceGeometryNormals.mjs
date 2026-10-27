import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

// Independent geometry fixtures plus source contract checks. This does not run
// HLSL, Unity, a rasterizer, or a GPU, and does not prove exact chart/triangle identity.
const root = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const source = readFileSync(path.join(root,
  'Runtime/Resources/HybridLumenGI/HybridLumenGISurfaceCache.hlsl'), 'utf8');
let checks = 0;
function check(value, message) { ++checks; assert.ok(value, message); }
const dot = (a, b) => a.reduce((sum, value, i) => sum + value * b[i], 0);
const sub = (a, b) => a.map((value, i) => value - b[i]);
const mul = (a, scale) => a.map(value => value * scale);
const add = (a, b) => a.map((value, i) => value + b[i]);
const cross = (a, b) => [a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0]];
const unit = vector => mul(vector, 1 / Math.hypot(...vector));
const finite = vector => vector.every(Number.isFinite);

function surface(overrides = {}) {
  return {
    position: [0, 0, 0], geometricNormal: [0, 0, 1], normal: [0, 0, 1],
    cardDirection: [0, 0, 1], tolerance: .1, projected: [.5, .5, .5],
    capturedDepth: .5, depthScale: 1, emission: [4, 1, .25], ...overrides,
  };
}

// Reference in world-space geometry: material shading normals deliberately do
// not participate. The thresholds are the existing cache's approximation policy.
function geometryAccept(position, geometricNormal, candidate) {
  const length = Math.hypot(...geometricNormal);
  if (!finite(position) || !finite(geometricNormal) || !Number.isFinite(length) || length < 1e-5)
    return false;
  const ng = unit(geometricNormal);
  if (dot(candidate.cardDirection, ng) <= .05) return false;
  if (!finite(candidate.projected) || candidate.projected.some(value => value < 0 || value > 1)) return false;
  const delta = sub(candidate.position, position);
  const tolerance = Math.max(candidate.tolerance, .002);
  const withinRadius = Math.hypot(...delta) <= tolerance;
  const sameOrientedSurface = dot(candidate.geometricNormal, ng) >= .2;
  const withinPlane = Math.abs(dot(delta, ng)) <= Math.max(.002, .3 * tolerance);
  const withinCaptureDepth = Math.abs(candidate.capturedDepth - candidate.projected[2]) /
    Math.max(candidate.depthScale, 1e-8) <= tolerance;
  return withinRadius && sameOrientedSurface && withinPlane && withinCaptureDepth;
}

function oldShadingAgreement(geometricNormal, candidate) {
  return dot(candidate.normal, geometricNormal) >= .2;
}

// Actual regression: the hit and captured texel have identical Ng/position, but
// a valid strong normal map yields Ns dot Ng = 0.1. The previous test rejected it.
const ng = [0, 0, 1];
const strong = surface({ normal: [Math.sqrt(.99), 0, .1] });
check(dot(strong.normal, ng) < .2, 'fixture crosses the previous rejection threshold');
check(!oldShadingAgreement(ng, strong), 'previous shading-normal agreement rejects correct geometry');
check(geometryAccept([0, 0, 0], ng, strong), 'strong normal map preserves the captured material');
check(strong.emission[0] === 4 && strong.normal[2] === .1,
  'geometry classification does not replace material values or the shading normal');

// Identity must be invariant to changing only the shading normal, in arbitrary
// rotated frames. This tests tilted smooth normals as well as tangent-space maps.
const axes = [[0, 0, 1], [1, 0, 0], [0, -1, 0], [1, 2, 3], [-.3, .8, -.2]].map(unit);
let formerlyRejected = 0;
for (const axis of axes) {
  const tangent = unit(cross(Math.abs(axis[2]) < .9 ? [0, 0, 1] : [0, 1, 0], axis));
  const bitangent = cross(axis, tangent);
  for (const degrees of [0, 15, 30, 45, 60, 75, 78, 79, 80, 84, 88, 89.9]) {
    const theta = degrees * Math.PI / 180;
    for (let azimuth = 0; azimuth < 16; ++azimuth) {
      const phi = azimuth * 2 * Math.PI / 16;
      const ns = add(mul(axis, Math.cos(theta)),
        mul(add(mul(tangent, Math.cos(phi)), mul(bitangent, Math.sin(phi))), Math.sin(theta)));
      const candidate = surface({ geometricNormal: axis, normal: ns, cardDirection: axis });
      check(Math.abs(Math.hypot(...ns) - 1) < 1e-12, 'rotated shading normal is unit length');
      check(geometryAccept([0, 0, 0], axis, candidate), 'changing Ns never changes the geometry match');
      check(geometryAccept([0, 0, 0], mul(axis, 3), candidate), 'finite scaled query Ng is normalized');
      if (!oldShadingAgreement(axis, candidate)) ++formerlyRejected;
    }
  }
}
check(formerlyRejected > 0, 'rotated fixtures exercise actual prior false rejections');

// Existing spatial rejection remains intact. An adjacent layer within the radial
// radius but beyond the allowed geometry plane must not replace the front texel.
const otherLayer = surface({ position: [0, 0, .04], capturedDepth: .54 });
check(Math.hypot(...otherLayer.position) < otherLayer.tolerance, 'neighbor is inside radial tolerance');
check(!geometryAccept([0, 0, 0], ng, otherLayer), 'separate depth layer rejected by geometric plane');
check(!geometryAccept([0, 0, 0], ng, surface({ geometricNormal: [0, 0, -1] })),
  'oppositely oriented captured geometry rejected');
check(!geometryAccept([0, 0, 0], ng, surface({ cardDirection: [0, 0, -1] })),
  'opposite card direction rejected');
check(!geometryAccept([0, 0, 0], ng, surface({ position: [.11, 0, 0] })),
  'unrelated lateral surface outside radius rejected');
check(!geometryAccept([0, 0, 0], ng, surface({ capturedDepth: .61 })),
  'capture depth disagreement remains rejected');
check(!geometryAccept([0, 0, 0], ng, surface({ projected: [.5, 1.01, .5] })),
  'projection outside the card rejected');
for (const invalidNormal of [[0, 0, 0], [1e-8, 0, 0], [NaN, 0, 1], [Infinity, 0, 1]])
  check(!geometryAccept([0, 0, 0], invalidNormal, strong), 'invalid query Ng has no material match');
check(!geometryAccept([NaN, 0, 0], ng, strong), 'invalid world position has no match');
check(geometryAccept([0, 0, 0], ng, surface({ position: [0, 0, .001], capturedDepth: .501 })),
  'documented limitation: sub-tolerance layers still need explicit hit identity');

// Tie the fixtures to the edited production function without treating this as a
// shader execution test. This check would fail on the previous implementation.
const signature = 'bool HLGITrySurfaceMaterial(int slot,float3 position,float3 geometricNormal,out HLGISurfaceSample sample)';
const start = source.indexOf(signature);
check(start >= 0, 'production API names the third parameter geometricNormal');
const begin = source.indexOf('{', start);
let depth = 1, end = begin + 1;
while (depth && end < source.length) {
  if (source[end] === '{') ++depth;
  if (source[end] === '}') --depth;
  ++end;
}
check(depth === 0, 'production material query body located');
const body = source.slice(begin, end).replace(/\/\/[^\n]*/g, '');
check(/float facing\s*=\s*dot\(card\.directionTolerance\.xyz,\s*geometricNormal\)/.test(body),
  'production card facing uses Ng');
check(/float agreement\s*=\s*dot\(candidate\.geometricNormal,\s*geometricNormal\)/.test(body),
  'production agreement uses captured Ng and query Ng');
check(/abs\(dot\(delta,\s*geometricNormal\)\)/.test(body), 'production layer plane uses Ng');
check(!/candidate\.normal\b/.test(body), 'production geometry selection never reads shading normal');
check(/geometricNormal\s*\*=\s*rsqrt\(geometricLengthSquared\)/.test(body), 'production normalizes valid Ng');
check(/isfinite\(geometricLengthSquared\)/.test(body) && /isfinite\(geometricNormal\)/.test(body),
  'production rejects nonfinite Ng');
check(/card\.ownerSlot!=\(uint\)slot/.test(body) && /card\.layoutGeneration!=range\.z/.test(body),
  'owner/layout isolation retained');
check(/sample\.normal=normal\.xyz\*rsqrt\(normalLengthSquared\)/.test(source) &&
  /sample\.geometricNormal=HLGIDecodeSurfaceGeometricNormal\(emission\.a\)/.test(source),
  'sample returns independent shading and geometric normals');

console.log(`SurfaceGeometryNormals PASS: ${checks} checks; ${formerlyRejected} rotated prior false rejections covered.`);
console.log('Evidence: independent CPU geometry fixtures and production-source contract checks; no shader/GPU/Unity execution.');
