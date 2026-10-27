// Numerical reference values for the diffuse-transport contract. This does NOT
// run or certify Unity's shaders. It provides an independent integration oracle.
import assert from 'node:assert/strict';

const pi = Math.PI;
const count = 100000;
function random(seed) {
  let state = seed >>> 0;
  return () => {
    state = (Math.imul(1664525, state) + 1013904223) >>> 0;
    return (state + 0.5) / 4294967296;
  };
}
function diffuse(rho, incident, cosine, pdf) {
  return rho / pi * incident * cosine / pdf;
}

// Constant incident radiance under a cosine PDF must reproduce rho * Li exactly.
for (const rho of [0, 0.1, 0.5, 0.96]) {
  for (const cosine of [0.01, 0.25, 0.9, 1]) {
    assert.ok(Math.abs(diffuse(rho, 3, cosine, cosine / pi) - rho * 3) < 1e-12);
  }
}

// Independent uniform-hemisphere integration of Li=1+2*cos(theta).
// Its exact cosine-weighted mean is 1+4/3 = 7/3.
let rng = random(0x12345678);
let uniform = 0;
for (let i = 0; i < count; i++) {
  const cosine = rng();
  uniform += diffuse(0.6, 1 + 2 * cosine, cosine, 1 / (2 * pi));
}
uniform /= count;
assert.ok(Math.abs(uniform - 0.6 * 7 / 3) < 0.015);

// A mixed proposal requires its full mixture density. Using only the chosen
// component's PDF biases the estimate. Both branches cover the hemisphere.
rng = random(0x9e3779b9);
let mixture = 0;
for (let i = 0; i < count; i++) {
  const chooseCosine = rng() < 0.7;
  const u = rng();
  const cosine = chooseCosine ? Math.sqrt(u) : u;
  const density = 0.7 * cosine / pi + 0.3 / (2 * pi);
  mixture += diffuse(0.6, 1 + 2 * cosine, cosine, density);
}
mixture /= count;
assert.ok(Math.abs(mixture - 0.6 * 7 / 3) < 0.015);

// Jacobi cache updates must read the previous bounce for BOTH surfaces. The
// closed two-patch solution has a finite geometric series when rhoA*rhoB < 1.
const rhoA = 0.7, rhoB = 0.8, source = 2;
let a = source, b = 0;
for (let iteration = 0; iteration < 200; iteration++) {
  [a, b] = [source + rhoA * b, rhoB * a];
}
assert.ok(Math.abs(a - source / (1 - rhoA * rhoB)) < 1e-10);
assert.ok(Math.abs(b - rhoB * source / (1 - rhoA * rhoB)) < 1e-10);

// A dark cache must decay when its source is removed, even after convergence.
for (let iteration = 0; iteration < 200; iteration++) [a, b] = [rhoA * b, rhoB * a];
assert.ok(Math.max(a, b) < 1e-20);

console.log(JSON.stringify({
  status: 'mathematical reference passed; Unity shader/GPU validation not performed',
  expectedDirectionalIncidentResult: 1.4,
  uniformEstimate: uniform,
  mixtureEstimate: mixture,
  darkCacheResidual: Math.max(a, b)
}, null, 2));
