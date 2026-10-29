import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';

// Independent-reference adapter. It neither renders a reference nor promotes a
// candidate-derived difference image to a physical reference. See the schema.
const SCHEMA = 'hlgi-validation-reference-v2';
const SHA = /^[0-9a-f]{64}$/;
const METHODS = new Set(['analytic', 'independent-numerical-integration', 'independent-path-tracing']);
const QUANTITIES = new Set(['camera-radiance', 'indirect-irradiance-over-pi', 'outgoing-indirect-diffuse-radiance', 'native-diffuse-radiance', 'composition-delta']);
const ROWS = new Set(['top-to-bottom', 'bottom-to-top']);
const canonical = value => JSON.stringify(value, (_, v) => v && !Array.isArray(v) && typeof v === 'object'
  ? Object.fromEntries(Object.entries(v).sort(([a], [b]) => a.localeCompare(b))) : v);
const hash = bytes => crypto.createHash('sha256').update(bytes).digest('hex');

export class ValidationError extends Error {
  constructor(code, message) { super(message); this.name = 'ValidationError'; this.code = code; }
}
function need(value, message, code = 'invalid-manifest') { if (!value) throw new ValidationError(code, message); }
function object(value) { return value !== null && typeof value === 'object' && !Array.isArray(value); }
function text(value) { return typeof value === 'string' && value.trim().length > 0; }
function finiteTree(value) {
  if (typeof value === 'number') need(Number.isFinite(value), 'Nonfinite JSON number');
  else if (value && typeof value === 'object') for (const child of Object.values(value)) finiteTree(child);
}
function parse(bytes, label) {
  let value;
  try { value = JSON.parse(bytes.toString('utf8').replace(/^\uFEFF/, '')); }
  catch { throw new ValidationError('invalid-json', `Invalid JSON: ${label}`); }
  finiteTree(value); return value;
}
function arrayNumbers(value, count, label) {
  need(Array.isArray(value) && value.length === count && value.every(Number.isFinite), `${label}: expected ${count} finite numbers`);
}
function unique(values, label) { need(new Set(values).size === values.length, `Duplicate ${label}`); }
function reasons(row) { need(Array.isArray(row.reasons) && row.reasons.length > 0 && row.reasons.every(text), 'Missing incomplete/unsupported/uncovered reasons'); }
function artifact(root, descriptor) {
  need(object(descriptor) && text(descriptor.file) && SHA.test(descriptor.sha256), 'Invalid artifact descriptor');
  const name = descriptor.file;
  need(!name.includes('\\') && !name.includes(':') && !name.startsWith('/') &&
    name.split('/').every(p => p && p !== '.' && p !== '..'), `Unsafe artifact path: ${name}`, 'unsafe-path');
  const filename = path.resolve(root, name);
  let real;
  try { real = fs.realpathSync(filename); } catch { throw new ValidationError('missing-artifact', `Missing artifact: ${name}`); }
  const relative = path.relative(root, real);
  need(relative !== '..' && !relative.startsWith(`..${path.sep}`) && !path.isAbsolute(relative), `Artifact escapes manifest directory: ${name}`, 'unsafe-path');
  need(fs.statSync(real).isFile(), `Artifact is not a file: ${name}`, 'unsafe-path');
  const bytes = fs.readFileSync(real);
  need(hash(bytes) === descriptor.sha256, `SHA256 mismatch: ${name}`, 'artifact-integrity');
  return bytes;
}
function evidence(root, entries) {
  need(Array.isArray(entries) && entries.length > 0, 'Evidence artifact list is required');
  unique(entries.map(e => e.file), 'evidence path');
  for (const entry of entries) artifact(root, entry);
}
function camera(value) {
  need(object(value) && value.matrixOrder === 'row-major', 'Camera matrices must be row-major');
  arrayNumbers(value.view, 16, 'camera.view'); arrayNumbers(value.projection, 16, 'camera.projection');
  arrayNumbers(value.jitter, 2, 'camera.jitter'); arrayNumbers(value.viewport, 4, 'camera.viewport');
  need(value.viewport.every(Number.isInteger) && value.viewport[0] >= 0 && value.viewport[1] >= 0 && value.viewport[2] > 0 && value.viewport[3] > 0, 'Invalid camera viewport');
  need(ROWS.has(value.rowOrder) && ['top-left', 'bottom-left'].includes(value.uvOrigin) &&
    ['zero-to-one', 'minus-one-to-one'].includes(value.clipDepth) && typeof value.reversedZ === 'boolean' &&
    value.pixelCenter === 'half-integer', 'Missing/unsupported camera pixel or clip convention');
}
function signal(value) {
  need(object(value) && text(value.id) && text(value.quantity) && text(value.units) && text(value.stage), 'Invalid signal definition/stage');
  need(['camera-pixel', 'gi-grid'].includes(value.domain), 'Unsupported signal domain');
  need(['physical-reference', 'diagnostic-only'].includes(value.comparison), 'Signal comparison role is required');
  need(value.colorSpace === 'linear-srgb' && value.exposure === 1 && value.alpha === 'not-compared', 'Only unexposed linear-sRGB RGB comparison is supported');
  need(['applied', 'not-applied'].includes(value.fog), 'Signal fog convention is required');
  need(Array.isArray(value.contributions) && value.contributions.length > 0 && value.contributions.every(text), 'Signal contributions are required');
  unique(value.contributions, 'signal contribution');
  need(canonical(value.contributions) === canonical([...value.contributions].sort()), 'Signal contributions must be sorted');
}
function thresholds(value) {
  if (value === undefined) return {};
  need(object(value) && Object.keys(value).length > 0 && Object.keys(value).every(k => ['rmse', 'maxError'].includes(k)), 'Invalid thresholds');
  for (const [key, limit] of Object.entries(value)) need(Number.isFinite(limit) && limit >= 0, `Invalid ${key} threshold`);
  return value;
}
function loadManifest(filename, kind) {
  const absolute = fs.realpathSync(filename), root = fs.realpathSync(path.dirname(absolute));
  const bytes = fs.readFileSync(absolute), m = parse(bytes, filename);
  need(m.schema === SCHEMA && m.kind === kind, 'Unsupported manifest schema/kind', 'unsupported-schema');
  need(['complete', 'incomplete'].includes(m.status), 'Invalid manifest status');
  if (m.status === 'incomplete') reasons(m);
  need(m.provenance === undefined || Array.isArray(m.provenance), 'Invalid provenance artifact list');
  for (const entry of m.provenance ?? []) { need(text(entry.role), 'Provenance role is required'); artifact(root, entry); }
  need(object(m.sequence) && text(m.sequence.id) && Number.isInteger(m.sequence.version) && m.sequence.version > 0 &&
    Number.isInteger(m.sequence.totalLogicalFrames) && m.sequence.totalLogicalFrames > 0, 'Invalid sequence');
  const selection = m.selection;
  need(object(selection) && Array.isArray(selection.logicalFrames) && selection.logicalFrames.length > 0 &&
    selection.logicalFrames.every(n => Number.isInteger(n) && n >= 0 && n < m.sequence.totalLogicalFrames), 'Invalid selected logical frames');
  unique(selection.logicalFrames, 'selected frame');
  need(canonical(selection.logicalFrames) === canonical([...selection.logicalFrames].sort((a, b) => a - b)), 'Selected frames must be sorted');
  need(Array.isArray(selection.signalIds) && selection.signalIds.length > 0 && selection.signalIds.every(text), 'Invalid selected signals');
  unique(selection.signalIds, 'selected signal');
  need(Array.isArray(m.signals), 'Signal definitions are required'); m.signals.forEach(signal);
  unique(m.signals.map(s => s.id), 'signal definition');
  const signals = new Map(m.signals.map(s => [s.id, s]));
  need(selection.signalIds.every(id => signals.has(id)), 'Selected signal has no definition');

  const sourceBytes = artifact(root, m.source), source = parse(sourceBytes, m.source.file);
  need(source.schema === 'hlgi-validation-source-v2' && text(source.sceneId) &&
    source.coordinateSystem === 'Unity-left-handed-y-up' && source.lengthUnit === 'metre', 'Invalid source scene identity/coordinates');
  for (const key of ['geometry', 'materials', 'lights']) need(Array.isArray(source[key]), `Source ${key} array is required`);
  need(object(source.environment) && object(source.rendering) && Array.isArray(source.assets), 'Source environment/rendering/assets are required');
  need(source.unsupported === undefined || (Array.isArray(source.unsupported) && source.unsupported.every(text)), 'Invalid source unsupported list');
  unique(source.assets.map(a => String(a.path).toLowerCase()), 'source asset path');
  for (const entry of source.assets) {
    need(text(entry.role), 'Source asset role is required');
    artifact(root, { file: entry.path, sha256: entry.sha256 });
  }
  const frames = new Map();
  need(Array.isArray(m.frames), 'Frames array is required');
  for (const frame of m.frames) {
    need(object(frame) && selection.logicalFrames.includes(frame.logicalFrame) && !frames.has(frame.logicalFrame), 'Unexpected/duplicate frame');
    camera(frame.camera);
    const state = parse(artifact(root, frame.state), frame.state.file);
    need(state.schema === 'hlgi-validation-frame-state-v2' && state.logicalFrame === frame.logicalFrame &&
      state.sourceSha256 === m.source.sha256 && object(state.dynamicState), 'Frame state identity/source mismatch', 'frame-state-mismatch');
    need(state.unsupported === undefined || (Array.isArray(state.unsupported) && state.unsupported.every(text)), 'Invalid frame-state unsupported list');
    need(canonical(state.camera) === canonical(frame.camera), 'Frame camera differs from state artifact', 'camera-mismatch');
    need(frame.support === undefined || Array.isArray(frame.support), 'Invalid frame support list');
    for (const support of frame.support ?? []) { need(text(support.role), 'Support artifact role is required'); artifact(root, support); }
    need(Array.isArray(frame.samples), 'Frame samples are required');
    unique(frame.samples.map(s => s.signalId), 'frame signal');
    const samples = new Map();
    for (const sample of frame.samples) {
      need(object(sample) && signals.has(sample.signalId) && ['available', 'unsupported', 'uncovered'].includes(sample.status), 'Invalid frame sample');
      if (sample.status !== 'available') reasons(sample);
      else {
        need(Number.isInteger(sample.width) && sample.width > 0 && sample.width <= 16384 &&
          Number.isInteger(sample.height) && sample.height > 0 && sample.height <= 16384 &&
          sample.format === 'rgba32f-le' && ROWS.has(sample.rowOrder), 'Invalid raw image layout');
        need(sample.rowOrder === frame.camera.rowOrder, 'Sample/camera row order differs; normalize explicitly before export', 'sample-shape-mismatch');
        if (signals.get(sample.signalId).domain === 'camera-pixel') need(sample.width === frame.camera.viewport[2] && sample.height === frame.camera.viewport[3], 'Camera-pixel image must cover the complete viewport', 'sample-shape-mismatch');
        // Descriptor bytes are validated now; numeric RGB is decoded only after
        // all frame/source/signal matching and reference qualification below.
        const data = artifact(root, sample.data), mask = artifact(root, sample.validity);
        need(data.length === sample.width * sample.height * 16, 'RGBA32F length mismatch', 'artifact-layout');
        need(sample.validity.format === 'uint8' && ['all-pixels', 'measurement-state', 'declared-reference-domain'].includes(sample.validity.basis), 'Explicit validity basis is required');
        need(mask.length === sample.width * sample.height && mask.every(v => v === 0 || v === 1), 'Validity mask must contain exactly one 0/1 byte per pixel', 'invalid-validity');
        if (sample.validity.basis === 'all-pixels') need(mask.every(v => v === 1), 'all-pixels mask contains uncovered pixels', 'invalid-validity');
        if (kind === 'reference') {
          const q = sample.qualification;
          need(object(q) && ['qualified', 'unqualified'].includes(q.status), 'Reference qualification is required');
          if (q.status === 'unqualified') reasons(q);
          else {
            need(object(q.errorBound) && q.errorBound.type === 'absolute-per-component' && Number.isFinite(q.errorBound.maxRgb) && q.errorBound.maxRgb >= 0, 'Qualified reference requires an absolute RGB component error bound');
            evidence(root, q.evidence);
          }
        }
      }
      samples.set(sample.signalId, sample);
    }
    frames.set(frame.logicalFrame, { ...frame, samples, unsupportedSource: state.unsupported ?? [] });
  }
  if (kind === 'candidate') thresholds(m.thresholds);
  else {
    need(object(m.reference) && text(m.reference.method) && object(m.reference.independence), 'Reference method/independence declaration is required');
    evidence(root, m.reference.evidence);
  }
  return { root, m, source, frames, signals, sha256: hash(bytes), path: absolute };
}

// The same linear RGB RMSE/max-absolute-error arithmetic as the legacy capture
// comparator. Alpha is only checked for finite measured pixels, never scored.
function comparePixels(candidate, reference, c, r) {
  const a = artifact(candidate.root, c.data), b = artifact(reference.root, r.data);
  const ma = artifact(candidate.root, c.validity), mb = artifact(reference.root, r.validity);
  const luma = [.2126, .7152, .0722];
  let compared = 0, candidateUnknown = 0, referenceUnknown = 0, squared = 0, maxError = 0, luminance = 0, maximumRgb = -Infinity;
  for (let i = 0; i < ma.length; i++) {
    if (!ma[i]) candidateUnknown++; if (!mb[i]) referenceUnknown++;
    // Check each known measurement, even when the other side is uncovered.
    for (let j = 0; j < 4; j++) {
      if (ma[i]) need(Number.isFinite(a.readFloatLE(i * 16 + j * 4)), `Nonfinite candidate measurement at pixel ${i}`, 'nonfinite-measurement');
      if (mb[i]) need(Number.isFinite(b.readFloatLE(i * 16 + j * 4)), `Nonfinite reference measurement at pixel ${i}`, 'nonfinite-measurement');
    }
    if (!ma[i] || !mb[i]) continue;
    compared++;
    for (let j = 0; j < 3; j++) {
      const value = a.readFloatLE(i * 16 + j * 4), error = value - b.readFloatLE(i * 16 + j * 4);
      squared += error * error; maxError = Math.max(maxError, Math.abs(error)); maximumRgb = Math.max(maximumRgb, value);
      luminance += value * luma[j];
    }
  }
  return { totalPixels: ma.length, comparedPixels: compared, candidateUnknownPixels: candidateUnknown, referenceUnknownPixels: referenceUnknown,
    metrics: compared ? { rmse: Math.sqrt(squared / (compared * 3)), maxError, meanLuminance: luminance / compared, maximumRgb } : null };
}
function physicalReferenceSupported(reference) {
  const r = reference.m.reference, i = r.independence;
  return METHODS.has(r.method) && i.inputs === 'source-only' && i.usesCandidateRadiance === false && i.usesProductTransport === false;
}

export function compareValidationReference(candidatePath, referencePath = null, options = {}) {
  need(object(options) && Object.keys(options).every(k => k === 'thresholds'), 'Unsupported comparison options');
  const candidate = loadManifest(candidatePath, 'candidate');
  const limits = { ...thresholds(candidate.m.thresholds) }, cliLimits = thresholds(options.thresholds);
  for (const [key, value] of Object.entries(cliLimits)) {
    need(limits[key] === undefined || limits[key] === value, `CLI/manifest ${key} threshold conflict`, 'threshold-conflict'); limits[key] = value;
  }
  const reference = referencePath ? loadManifest(referencePath, 'reference') : null;
  if (reference) {
    need(candidate.m.source.sha256 === reference.m.source.sha256, 'Scene-source content differs', 'source-mismatch');
    need(canonical(candidate.m.sequence) === canonical(reference.m.sequence), 'Sequence contract differs', 'sequence-mismatch');
    need(canonical(candidate.m.selection) === canonical(reference.m.selection), 'Predeclared frame/signal selection differs', 'selection-mismatch');
    for (const id of candidate.m.selection.signalIds) need(canonical(candidate.signals.get(id)) === canonical(reference.signals.get(id)), `Signal contract differs: ${id}`, 'signal-mismatch');
    for (const n of candidate.m.selection.logicalFrames) {
      const c = candidate.frames.get(n), r = reference.frames.get(n);
      if (c && r) {
        need(c.state.sha256 === r.state.sha256, `Frame input state differs: ${n}`, 'frame-state-mismatch');
        need(canonical(c.camera) === canonical(r.camera), `Camera differs: ${n}`, 'camera-mismatch');
        for (const id of candidate.m.selection.signalIds) {
          const cs = c.samples.get(id), rs = r.samples.get(id);
          if (cs?.status === 'available' && rs?.status === 'available')
            need(['width', 'height', 'format', 'rowOrder'].every(k => cs[k] === rs[k]), `Sample layout differs: ${n}/${id}`, 'sample-shape-mismatch');
        }
      }
    }
  }
  const rows = [];
  for (const n of candidate.m.selection.logicalFrames) for (const id of candidate.m.selection.signalIds) {
    const row = { logicalFrame: n, signalId: id }, s = candidate.signals.get(id);
    const c = candidate.frames.get(n)?.samples.get(id), r = reference?.frames.get(n)?.samples.get(id);
    if (!QUANTITIES.has(s.quantity) || s.units !== 'scene-linear-radiance' || s.comparison === 'diagnostic-only' || s.quantity === 'composition-delta')
      rows.push({ ...row, status: 'unsupported-signal', reasons: ['Signal has no supported physical-reference comparison; composition differences remain diagnostics.'] });
    else if (candidate.source.unsupported?.length) rows.push({ ...row, status: 'unsupported-source', reasons: candidate.source.unsupported });
    else if (candidate.frames.get(n)?.unsupportedSource.length) rows.push({ ...row, status: 'unsupported-source', reasons: candidate.frames.get(n).unsupportedSource });
    else if (!c || c.status !== 'available') rows.push({ ...row, status: c?.status ?? 'uncovered', side: 'candidate', reasons: c?.reasons ?? ['Missing selected candidate frame/signal.'] });
    else if (!reference) rows.push({ ...row, status: 'reference-required' });
    else if (!physicalReferenceSupported(reference)) rows.push({ ...row, status: 'unsupported-reference', reasons: ['Independent source-only reference declaration is not satisfied.'] });
    else if (!r || r.status !== 'available') rows.push({ ...row, status: r?.status ?? 'uncovered', side: 'reference', reasons: r?.reasons ?? ['Missing selected reference frame/signal.'] });
    else if (r.qualification.status !== 'qualified') rows.push({ ...row, status: 'reference-unqualified', reasons: r.qualification.reasons });
    else {
      const observed = comparePixels(candidate, reference, c, r), bound = r.qualification.errorBound.maxRgb;
      const intervals = observed.metrics ? Object.fromEntries(['rmse', 'maxError'].map(k => [k, { lower: Math.max(0, observed.metrics[k] - bound), upper: observed.metrics[k] + bound }])) : null;
      let status;
      if (observed.candidateUnknownPixels || observed.referenceUnknownPixels) status = 'uncovered';
      else if (!Object.keys(limits).length) status = 'threshold-required';
      else if (Object.entries(limits).some(([k, t]) => intervals[k].lower > t)) status = 'outside-thresholds';
      else if (Object.entries(limits).every(([k, t]) => intervals[k].upper <= t)) status = 'within-thresholds';
      else status = 'uncertain-with-reference-bound';
      rows.push({ ...row, status, ...observed, metricsScope: 'mutually-valid-pixels-only', referenceErrorBound: bound, errorIntervals: intervals });
    }
  }
  const failures = rows.filter(r => r.status === 'outside-thresholds').length;
  const fullyCovered = rows.every(r => r.status === 'within-thresholds') && candidate.m.status === 'complete' && reference?.m.status === 'complete';
  const passed = failures ? false : fullyCovered ? true : null;
  return { schema: 'hlgi-validation-reference-result-v2', status: failures ? 'outside-thresholds' : fullyCovered ? 'within-declared-thresholds' : 'incomplete', passed,
    exitCode: failures ? 1 : fullyCovered ? 0 : 2,
    adapter: { file: fileURLToPath(import.meta.url), sha256: hash(fs.readFileSync(fileURLToPath(import.meta.url))), node: process.version },
    candidate: { manifest: candidate.path, sha256: candidate.sha256, status: candidate.m.status },
    reference: reference ? { manifest: reference.path, sha256: reference.sha256, status: reference.m.status, method: reference.m.reference.method } : null,
    sourceSha256: candidate.m.source.sha256, sequence: candidate.m.sequence, selection: candidate.m.selection, thresholds: limits,
    expectedComparisons: candidate.m.selection.logicalFrames.length * candidate.m.selection.signalIds.length,
    comparedPairs: rows.filter(r => r.metrics !== undefined).length,
    incompleteReasons: [ ...(candidate.m.status !== 'complete' ? ['Candidate manifest is incomplete.', ...candidate.m.reasons] : []),
      ...(reference && reference.m.status !== 'complete' ? ['Reference manifest is incomplete.', ...reference.m.reasons] : []) ],
    limitation: 'Conditional on the declared source, signal and qualified independent reference evidence. Hashes establish byte correspondence, not physical validity or source-export completeness. Missing pixels never pass. No Unity/DXR execution, dynamic stability, performance or production acceptance is inferred.', rows };
}

function main(args) {
  let candidate, reference, output; const limits = {};
  const seen = new Set();
  for (let i = 0; i < args.length; i++) {
    const flag = args[i];
    need(['--candidate', '--reference', '--output', '--rmse', '--max-error'].includes(flag) && !seen.has(flag), `Unknown/duplicate option: ${flag}`);
    seen.add(flag); need(i + 1 < args.length && !args[i + 1].startsWith('--'), `Missing value for ${flag}`);
    const value = args[++i];
    if (flag === '--candidate') candidate = value;
    else if (flag === '--reference') reference = value;
    else if (flag === '--output') output = value;
    else limits[flag === '--rmse' ? 'rmse' : 'maxError'] = Number(value);
  }
  need(candidate, 'Use --candidate <manifest.json> [--reference <manifest.json>] [--rmse n] [--max-error n] [--output new.json]');
  const result = compareValidationReference(candidate, reference, Object.keys(limits).length ? { thresholds: limits } : {});
  const serialized = JSON.stringify(result, null, 2) + '\n';
  if (output) fs.writeFileSync(output, serialized, { encoding: 'utf8', flag: 'wx' });
  process.stdout.write(serialized); process.exitCode = result.exitCode;
}
if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try { main(process.argv.slice(2)); }
  catch (error) {
    process.stdout.write(JSON.stringify({ schema: 'hlgi-validation-reference-result-v2', status: 'invalid-input', passed: null, exitCode: 1,
      error: { code: error.code ?? 'io-error', message: error.message }, limitation: 'Input rejection is not a product-rendering defect.' }, null, 2) + '\n');
    process.exitCode = 1;
  }
}
