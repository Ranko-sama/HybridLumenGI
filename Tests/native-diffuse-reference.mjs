// Independent algebra oracle, not Unity/GPU execution or shader pixel validation.
import assert from 'node:assert/strict';

let seed = 0x17bdf001;
const random = () => ((seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0) + 0.5) / 4294967296;
const near = (a, b) => assert.ok(Math.abs(a - b) < 1e-10 * Math.max(1, Math.abs(a), Math.abs(b)), `${a} != ${b}`);

function nativeDiffuse(bakedGI, rho, materialAO, screenAO) {
  return bakedGI * rho * Math.min(materialAO, screenAO);
}
function signedDelta(newIrradianceOverPi, rho, indirectAO, intensity, native, fogTransmission, valid) {
  if (!valid) return 0;
  return (newIrradianceOverPi * rho * indirectAO * intensity - native) * fogTransmission;
}
for (let i = 0; i < 10000; i++) {
  const rho = random(), materialAO = random(), screenAO = random(), ao = Math.min(materialAO, screenAO);
  const oldGI = random() * 16, newGI = random() * 16, fog = random(), fogColor = random() * 4;
  const directAndSpecularAndEmission = random() * 30, intensity = random() * 2;
  const native = nativeDiffuse(oldGI, rho, materialAO, screenAO);
  const original = (directAndSpecularAndEmission + native) * fog + fogColor * (1 - fog);
  const replacement = original + signedDelta(newGI, rho, ao, intensity, native, fog, true);
  const oracle = (directAndSpecularAndEmission + newGI * rho * ao * intensity) * fog + fogColor * (1 - fog);
  near(replacement, oracle);
  near(signedDelta(oldGI, rho, ao, 1, native, fog, true), 0);
  near(signedDelta(newGI, rho, ao, intensity, native, fog, false), 0);
  near(signedDelta(newGI, rho, ao, intensity, native, 0, true), 0);
}
// Clamping delta to nonnegative would fail this darkening case.
near(signedDelta(0, 0.8, 0.4, 1, 2, 0.5, true), -1);
// SSAO and material AO combine by min in URP, not multiplication.
near(nativeDiffuse(2, 0.5, 0.8, 0.6), 0.6);
// Replacement uses the established E/pi contract; no additional pi conversion.
near(signedDelta(2, 0.5, 1, 1, 0, 1, true), 1);
console.log('Native diffuse algebra: 10000 randomized replacements; negative delta, AO minimum, fog and invalid-capture cases passed. No Unity/GPU execution.');
