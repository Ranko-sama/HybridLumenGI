import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { compareValidationReference as compare, ValidationError } from './compare-validation-reference.mjs';

// Synthetic protocol/arithmetic inputs only. No Unity, physical reference,
// established scene, GPU or image-quality result is produced by this test.
const root = fs.mkdtempSync(path.join(os.tmpdir(), 'hlgi-reference-adapter-cpu-'));
const sha = b => crypto.createHash('sha256').update(b).digest('hex');
const copy = v => structuredClone(v);
const identity = [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1];
const camera = { matrixOrder: 'row-major', view: identity, projection: identity, viewport: [0, 0, 2, 1], jitter: [0, 0],
  rowOrder: 'top-to-bottom', uvOrigin: 'top-left', clipDepth: 'zero-to-one', reversedZ: true, pixelCenter: 'half-integer' };
const signal = { id: 'cameraAfterHLGI', stage: 'after-hlgi-composite-before-transparents', quantity: 'camera-radiance', units: 'scene-linear-radiance',
  domain: 'camera-pixel', comparison: 'physical-reference', colorSpace: 'linear-srgb', exposure: 1, alpha: 'not-compared', fog: 'not-applied', contributions: ['indirect-diffuse'] };
const floats = values => { const bytes = Buffer.alloc(values.length * 4); values.forEach((v, i) => bytes.writeFloatLE(v, i * 4)); return bytes; };
let checks = 0, serial = 0;
const skipped = [];
function blob(dir, name, bytes) {
  const file = path.join(dir, name); fs.mkdirSync(path.dirname(file), { recursive: true }); fs.writeFileSync(file, bytes);
  return { file: name, sha256: sha(bytes) };
}
const jsonBlob = (dir, name, value) => blob(dir, name, Buffer.from(JSON.stringify(value) + '\n'));
function pair() {
  const base = path.join(root, String(++serial)), result = {};
  for (const kind of ['candidate', 'reference']) {
    const dir = path.join(base, kind); fs.mkdirSync(dir, { recursive: true });
    const asset = blob(dir, 'source/assets/synthetic.bin', Buffer.from('synthetic source bytes'));
    const source = { schema: 'hlgi-validation-source-v2', sceneId: 'cpu-synthetic-no-scene', coordinateSystem: 'Unity-left-handed-y-up', lengthUnit: 'metre',
      geometry: [], materials: [], lights: [], environment: {}, rendering: {}, unsupported: [],
      assets: [{ path: asset.file, sha256: asset.sha256, role: 'synthetic-test-data' }] };
    const sourceDescriptor = jsonBlob(dir, 'source/scene-source.json', source);
    const evidence = blob(dir, 'evidence/synthetic.txt', Buffer.from('SYNTHETIC ADAPTER TEST ONLY. Not renderer or physical-reference evidence.'));
    const manifest = { schema: 'hlgi-validation-reference-v2', kind, status: 'complete', source: sourceDescriptor,
      sequence: { id: 'cpu-synthetic', version: 2, totalLogicalFrames: 2 }, selection: { logicalFrames: [0, 1], signalIds: [signal.id] },
      signals: [copy(signal)], frames: [0, 1].map(logicalFrame => {
        const state = { schema: 'hlgi-validation-frame-state-v2', logicalFrame, sourceSha256: sourceDescriptor.sha256, camera: copy(camera), dynamicState: {} };
        const sample = { signalId: signal.id, status: 'available', width: 2, height: 1, format: 'rgba32f-le', rowOrder: 'top-to-bottom',
          data: blob(dir, `frames/${logicalFrame}.rgba32f`, floats([1, 2, 3, 1, 2, 4, 6, 1])),
          validity: { ...blob(dir, `frames/${logicalFrame}.validity`, Buffer.from([1, 1])), format: 'uint8', basis: 'all-pixels' } };
        if (kind === 'reference') sample.qualification = { status: 'qualified', errorBound: { type: 'absolute-per-component', maxRgb: 0 }, evidence: [evidence] };
        return { logicalFrame, camera: copy(camera), state: jsonBlob(dir, `states/${logicalFrame}.json`, state), support: [], samples: [sample] };
      }) };
    if (kind === 'reference') manifest.reference = { method: 'analytic', independence: { inputs: 'source-only', usesCandidateRadiance: false, usesProductTransport: false }, evidence: [evidence] };
    const file = path.join(dir, 'manifest.json');
    result[kind] = { dir, file, manifest, source };
  }
  save(result); return result;
}
function save(p) { for (const kind of ['candidate', 'reference']) fs.writeFileSync(p[kind].file, JSON.stringify(p[kind].manifest) + '\n'); }
function run(p, thresholds = { rmse: 0, maxError: 0 }) { save(p); return compare(p.candidate.file, p.reference.file, thresholds ? { thresholds } : {}); }
function error(p, code) { assert.throws(() => run(p), e => e instanceof ValidationError && e.code === code); }
function test(name, action) { action(); checks++; process.stdout.write(`ok ${checks} - ${name}\n`); }
function changeState(side, index, mutate) {
  const f = side.manifest.frames[index], state = JSON.parse(fs.readFileSync(path.join(side.dir, f.state.file)));
  mutate(state); f.state = jsonBlob(side.dir, f.state.file, state);
}
try {
  test('two independent selected frames need no HLGI/720 receipts; exact comparison passes', () => {
    const r = run(pair()); assert.equal(r.passed, true); assert.equal(r.rows.length, 2); assert.equal(r.rows[0].comparedPixels, 2);
  });
  test('no reference or explicit threshold cannot pass', () => {
    const p = pair(); assert.equal(compare(p.candidate.file).exitCode, 2); assert.equal(run(p, null).rows[0].status, 'threshold-required');
  });
  test('known RGB arithmetic uses RGB denominator and ignores finite alpha difference', () => {
    const p = pair(), c = p.candidate, s = c.manifest.frames[0].samples[0];
    s.data = blob(c.dir, s.data.file, floats([4, 2, 3, -5, 2, 4, 6, 100]));
    const r = run(p, { rmse: 1, maxError: 2 });
    assert.equal(r.rows[0].metrics.rmse, Math.sqrt(9 / 6)); assert.equal(r.rows[0].metrics.maxError, 3); assert.equal(r.passed, false);
  });
  test('signed zero and measured black remain exact valid measurements', () => {
    const p = pair();
    for (const kind of ['candidate', 'reference']) {
      const side = p[kind], s = side.manifest.frames[0].samples[0];
      s.data = blob(side.dir, s.data.file, floats([kind === 'candidate' ? -0 : 0, 0, 0, 1, 0, -0, 0, 1]));
    }
    assert.equal(run(p).passed, true);
  });
  test('reference error bound is propagated; it cannot be added as permissive tolerance', () => {
    const p = pair(); p.reference.manifest.frames[0].samples[0].qualification.errorBound.maxRgb = .25;
    assert.equal(run(p, { maxError: .1 }).rows[0].status, 'uncertain-with-reference-bound');
    assert.equal(run(p, { maxError: .25 }).passed, true);
  });
  test('unqualified and candidate-derived references cannot pass', () => {
    const p = pair(); p.reference.manifest.frames[0].samples[0].qualification = { status: 'unqualified', reasons: ['No convergence certificate.'] };
    assert.equal(run(p).rows[0].status, 'reference-unqualified');
    p.reference.manifest.reference.independence.usesCandidateRadiance = true;
    assert.equal(run(p).rows[0].status, 'unsupported-reference');
  });
  test('composition difference stays diagnostic even if mislabeled physical', () => {
    const p = pair(); for (const side of [p.candidate, p.reference]) side.manifest.signals[0].quantity = 'composition-delta';
    assert.equal(run(p).rows[0].status, 'unsupported-signal');
  });
  test('missing required frame/signal and duplicate frames cannot shrink coverage', () => {
    const p = pair(); p.reference.manifest.frames.pop(); assert.equal(run(p).rows[1].status, 'uncovered');
    p.reference.manifest.frames[0].samples = []; assert.equal(run(p).rows[0].status, 'uncovered');
    p.candidate.manifest.frames.push(copy(p.candidate.manifest.frames[0])); error(p, 'invalid-manifest');
  });
  test('unknown pixels do not pass after valid-pixel filtering; unknown payload is not decoded', () => {
    const p = pair(), side = p.candidate, s = side.manifest.frames[0].samples[0];
    s.validity = { ...blob(side.dir, s.validity.file, Buffer.from([0, 1])), format: 'uint8', basis: 'measurement-state' };
    s.data = blob(side.dir, s.data.file, floats([NaN, Infinity, -Infinity, NaN, 2, 4, 6, 1]));
    const r = run(p); assert.equal(r.passed, null); assert.equal(r.rows[0].status, 'uncovered'); assert.equal(r.rows[0].comparedPixels, 1);
  });
  test('known NaN and non-binary validity are invalid input', () => {
    const p = pair(), side = p.candidate, s = side.manifest.frames[0].samples[0];
    s.data = blob(side.dir, s.data.file, floats([NaN, 2, 3, 1, 2, 4, 6, 1])); error(p, 'nonfinite-measurement');
    s.validity = { ...blob(side.dir, s.validity.file, Buffer.from([2, 1])), format: 'uint8', basis: 'measurement-state' }; error(p, 'invalid-validity');
  });
  test('asset bytes and image lengths are checked against actual descriptors', () => {
    const p = pair(); fs.appendFileSync(path.join(p.candidate.dir, p.candidate.source.assets[0].path), '!'); error(p, 'artifact-integrity');
    const q = pair(), side = q.reference, s = side.manifest.frames[0].samples[0]; s.data = blob(side.dir, s.data.file, Buffer.alloc(4)); error(q, 'artifact-layout');
  });
  test('scene source content and frame input state must match', () => {
    const p = pair(), side = p.reference; side.source.sceneId = 'different-scene'; side.manifest.source = jsonBlob(side.dir, side.manifest.source.file, side.source);
    for (let i = 0; i < 2; i++) changeState(side, i, s => { s.sourceSha256 = side.manifest.source.sha256; }); error(p, 'source-mismatch');
    const q = pair(); changeState(q.reference, 0, s => { s.dynamicState.doorPosition = [1, 0, 0]; }); error(q, 'frame-state-mismatch');
  });
  test('camera, stage, unit and sample orientation mismatches are refused', () => {
    const p = pair(); p.reference.manifest.frames[0].camera.jitter[0] = .5; error(p, 'camera-mismatch');
    const q = pair(); q.reference.manifest.signals[0].stage = 'end-camera'; error(q, 'signal-mismatch');
    const r = pair(); r.reference.manifest.signals[0].units = 'pi-scaled-radiance'; error(r, 'signal-mismatch');
    const s = pair(); s.reference.manifest.frames[0].samples[0].rowOrder = 'bottom-to-top'; error(s, 'sample-shape-mismatch');
  });
  test('unsupported source and incomplete collection cannot become a pass', () => {
    const p = pair();
    for (const side of [p.candidate, p.reference]) {
      side.source.unsupported = ['Missing source texture semantics.']; side.manifest.source = jsonBlob(side.dir, side.manifest.source.file, side.source);
      for (let i = 0; i < 2; i++) changeState(side, i, s => { s.sourceSha256 = side.manifest.source.sha256; });
    }
    assert.equal(run(p).rows[0].status, 'unsupported-source');
    const q = pair(); q.candidate.manifest.status = 'incomplete'; q.candidate.manifest.reasons = ['Collection was interrupted.']; assert.equal(run(q).passed, null);
  });
  test('support artifacts are hash-bound without requiring a physical reference signal', () => {
    const p = pair(); p.candidate.manifest.frames[0].support = [{ ...blob(p.candidate.dir, 'support/depth.bin', Buffer.alloc(8)), role: 'camera-depth-observation' }];
    assert.equal(run(p).passed, true); fs.appendFileSync(path.join(p.candidate.dir, 'support/depth.bin'), '!'); error(p, 'artifact-integrity');
  });
  test('dynamic unsupported inputs block reference comparison and provenance bytes are verified', () => {
    const p = pair();
    for (const side of [p.candidate, p.reference]) changeState(side, 0, s => { s.unsupported = ['Dynamic material input unavailable.']; });
    assert.equal(run(p).rows[0].status, 'unsupported-source');
    const q = pair(), entry = blob(q.candidate.dir, 'provenance/source.txt', Buffer.from('synthetic tool source'));
    q.candidate.manifest.provenance = [{ ...entry, role: 'tool-source' }]; assert.equal(run(q).passed, true);
    fs.appendFileSync(path.join(q.candidate.dir, entry.file), '!'); error(q, 'artifact-integrity');
  });
  test('traversal, absolute and Windows-style artifact paths are refused', () => {
    for (const name of ['../source.json', '/source.json', 'C:/source.json', 'source\\scene.json']) {
      const p = pair(); p.candidate.manifest.source.file = name; error(p, 'unsafe-path');
    }
  });
  test('real path escape through a symlink is refused when supported by the OS', () => {
    const p = pair(), outside = path.join(root, 'outside-synthetic.bin'); fs.writeFileSync(outside, 'outside');
    const link = path.join(p.candidate.dir, 'escape.bin');
    try { fs.symlinkSync(outside, link, 'file'); }
    catch (e) { if (e.code === 'EPERM' || e.code === 'EACCES') { skipped.push('Symlink creation denied by OS; traversal tests still executed.'); return; } throw e; }
    p.candidate.manifest.source.file = 'escape.bin'; error(p, 'unsafe-path');
  });
  test('manifest thresholds work, conflicting CLI thresholds do not silently replace them', () => {
    const p = pair(); p.candidate.manifest.thresholds = { maxError: 0 }; assert.equal(run(p, null).passed, true);
    assert.throws(() => run(p, { maxError: 1 }), e => e.code === 'threshold-conflict');
  });
  test('CLI emits incomplete for missing reference and refuses to overwrite an output', () => {
    const p = pair(), tool = fileURLToPath(new URL('./compare-validation-reference.mjs', import.meta.url));
    let r = spawnSync(process.execPath, [tool, '--candidate', p.candidate.file], { encoding: 'utf8' });
    assert.equal(r.status, 2); assert.equal(JSON.parse(r.stdout).status, 'incomplete');
    const output = path.join(root, 'preserve.json'); fs.writeFileSync(output, 'preserved');
    r = spawnSync(process.execPath, [tool, '--candidate', p.candidate.file, '--output', output], { encoding: 'utf8' });
    assert.equal(r.status, 1); assert.equal(fs.readFileSync(output, 'utf8'), 'preserved');
  });
  process.stdout.write(JSON.stringify({ status: 'passed', checks, skipped, scope: 'Synthetic schema, input matching, path protection and numeric comparison only; no physical reference, Unity, GPU or product quality claim.' }) + '\n');
} finally {
  // Delete only this invocation's explicitly created temporary directory.
  const resolved = path.resolve(root);
  assert.equal(path.dirname(resolved), path.resolve(os.tmpdir()));
  assert(path.basename(resolved).startsWith('hlgi-reference-adapter-cpu-'));
  fs.rmSync(resolved, { recursive: true, force: true });
}
