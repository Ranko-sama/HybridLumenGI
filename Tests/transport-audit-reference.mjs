// Independent numerical fixtures for the community-source/transport audit.
// These exercise mathematical contracts, NOT compiled Unity shader execution.
// "legacy" branches reproduce the audited counterexamples deliberately.
import assert from 'node:assert/strict';

const checks = [];
function check(name, test) { test(); checks.push(name); }
const dot = (a, b) => a.reduce((s, v, i) => s + v * b[i], 0);
const subtract = (a, b) => a.map((v, i) => v - b[i]);
const normalize = v => v.map(x => x / Math.hypot(...v));
const nearly = (a, b, epsilon = 1e-10) => assert.ok(Math.abs(a - b) <= epsilon, `${a} != ${b}`);
const srgbToLinear = x => x <= 0.04045 ? x / 12.92 : ((x + 0.055) / 1.055) ** 2.4;

check('Nearest world occluder wins over a farther screen hit', () => {
  const worldT = 1, screenT = 1.05, thickness = 0.1, numericalEpsilon = 0.0001;
  const legacySelectsScreen = screenT < worldT + thickness;
  const conservativeSelectsScreen = screenT <= worldT + numericalEpsilon;
  assert.equal(legacySelectsScreen, true);
  assert.equal(conservativeSelectsScreen, false);
  assert.equal(0.7 <= worldT + numericalEpsilon, true);
  // Thickness is an intersection tolerance, not permission to see through a wall.
});

check('A surface anchor remains addressable when its normal differs from its capture axis', () => {
  const normal = normalize([0.35, 0.94, 0]);
  const faceIndex = n => {
    const a = n.map(Math.abs);
    const axis = a[0] >= a[1] && a[0] >= a[2] ? 0 : a[1] >= a[2] ? 1 : 2;
    return axis * 2 + (n[axis] < 0 ? 1 : 0);
  };
  const entries = Array(6).fill(null);
  // An X-axis capture ray can hit a sloping surface whose dominant normal is Y.
  entries[0] = { position: [0, 0, 0], normal, irradiance: [1, 0.2, 0.1] };
  assert.equal(faceIndex(normal), 2);
  assert.equal(entries[faceIndex(normal)], null);
  const find = (p, n) => entries.find(e => e && dot(e.normal, n) > 0.85 &&
    Math.abs(dot(subtract(p, e.position), e.normal)) <= 0.03);
  assert.equal(find([0, 0, 0], normal), entries[0]);
  assert.equal(find(normal.map(v => v * 0.05), normal), undefined);
  assert.equal(find([0, 0, 0], normal.map(v => -v)), undefined);
});

check('An unrelated moving object must not erase a static transport recurrence', () => {
  const rhoA = 0.7, rhoB = 0.8, source = 2;
  let a = 0, b = 0;
  let legacyA = 0, legacyB = 0;
  for (let frame = 0; frame < 250; frame++) {
    // Static pair survives an unrelated third object's geometry revision.
    [a, b] = [source + rhoA * b, rhoB * a];
    // A scene-wide epoch increment makes every old entry unreadable every frame.
    [legacyA, legacyB] = [source + rhoA * 0, rhoB * 0];
  }
  nearly(a, source / (1 - rhoA * rhoB));
  nearly(b, rhoB * source / (1 - rhoA * rhoB));
  assert.ok(Math.abs(a - legacyA) > 2);
  assert.equal(legacyB, 0);
  // Keeping history is not retaining it forever: an unlit contractive pair decays.
  for (let frame = 0; frame < 250; frame++) [a, b] = [rhoA * b, rhoB * a];
  assert.ok(Math.max(a, b) < 1e-25);
});

check('Jitter correction has the correct sign for non-jittered motion vectors', () => {
  const currentNoJitter = [0.6, 0.4], previousNoJitter = [0.57, 0.42];
  const currentJitter = [0.0003, -0.0002], previousJitter = [-0.0001, 0.0004];
  const currentUv = currentNoJitter.map((x, i) => x + currentJitter[i]);
  const motion = subtract(currentNoJitter, previousNoJitter);
  const previousUv = currentUv.map((x, i) => x - motion[i] + previousJitter[i] - currentJitter[i]);
  previousUv.forEach((x, i) => nearly(x, previousNoJitter[i] + previousJitter[i]));
});

check('Point-sampled depth is reconstructed at its texel center', () => {
  const width = 4, queryUv = 0.49, previousPixel = Math.floor(queryUv * width);
  const texelUv = (previousPixel + 0.5) / width;
  // A unit-depth orthographic plane maps x = 2*uv-1.
  nearly(2 * texelUv - 1, -0.25);
  assert.ok(Math.abs((2 * queryUv - 1) - (2 * texelUv - 1)) > 0.2);
});

check('Invalid history cannot contaminate a finite current estimate with NaN', () => {
  const current = 3;
  const legacyLerp = NaN * (1 - 1) + current * 1;
  assert.ok(Number.isNaN(legacyLerp));
  const historyValid = false;
  const history = historyValid ? NaN : current;
  nearly(history, current);
});

check('Linear transport is homogeneous and receiver reflectance is applied once', () => {
  const rho = srgbToLinear(0.5), incoming = 5;
  nearly(rho, 0.21404114048223255);
  const outgoing = rho * incoming;
  nearly(rho * incoming * 8, outgoing * 8);
  assert.ok(Math.abs(srgbToLinear(rho) * incoming - outgoing) > 0.8);
  assert.ok(Math.abs(rho * rho * incoming - outgoing) > 0.8);
  // A Lambertian BRDF upper bound 1/pi is not an upper bound on radiance.
  assert.ok(outgoing > 1 / Math.PI);
});

check('Tilted guiding uses the full mixture PDF and keeps zero-contribution samples', () => {
  let state = 0x51a7c0de;
  const random = () => {
    state = (Math.imul(state, 1664525) + 1013904223) >>> 0;
    return (state + 0.5) / 4294967296;
  };
  const cross = (a, b) => [a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0]];
  const sample = axis => {
    const u = random(), phi = 2 * Math.PI * random();
    const tangent = normalize(cross(Math.abs(axis[2]) < 0.99 ? [0, 0, 1] : [0, 1, 0], axis));
    const bitangent = cross(axis, tangent);
    return axis.map((n, i) => n*Math.sqrt(1-u) + Math.sqrt(u)*(tangent[i]*Math.cos(phi)+bitangent[i]*Math.sin(phi)));
  };
  const normal = [0, 0, 1], rays = 200000;
  for (const axis of [normalize([0.9, 0, 0.3]), [0, 0, -1]]) {
    for (const mixture of [0.25, 0.75]) {
      let total = 0, accepted = 0;
      for (let i = 0; i < rays; i++) {
        const direction = sample(random() < mixture ? axis : normal);
        const cosine = Math.max(direction[2], 0);
        const guideCosine = Math.max(dot(axis, direction), 0);
        if (cosine === 0) continue;
        const denominator = (1-mixture)*cosine + mixture*guideCosine;
        total += (1+2*cosine)*cosine/denominator;
        accepted++;
      }
      // Integral of (1+2*cos(theta))*cos(theta)/pi over the upper hemisphere.
      nearly(total/rays, 7/3, 0.025);
      assert.ok(accepted < rays, 'This fixture must exercise below-hemisphere samples.');
      assert.ok(total/accepted > total/rays, 'Renormalizing by accepted samples would bias this estimate.');
    }
  }
});

console.log(JSON.stringify({
  status: 'reference fixtures passed; not Unity, HLSL, GPU or image validation',
  checks: checks.length,
  reproducedLegacyCounterexamples: ['screen hit behind world occluder', 'capture axis/normal key mismatch', 'global-epoch cache starvation'],
  contracts: checks
}, null, 2));
