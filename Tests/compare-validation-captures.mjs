import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';

// Raw linear RGBA32F comparison only. This is not an EXR decoder or renderer test.
const totalFrames = 720;
const boundaries = new Set([119,120,179,180,209,210,239,240,299,300,359,360,419,420,719]);
const captureAt = (frame, interval) => frame % interval === 0 || boundaries.has(frame);
const stageAt = frame => frame < 120 ? 'color-static' : frame < 240 ? 'moving-door' : frame < 300 ? 'lights-off' : frame < 360 ? 'lights-restored' : frame < 420 ? 'thin-wall-cut' : 'sealed-room-cut';
const json = file => JSON.parse(fs.readFileSync(file, 'utf8').replace(/^\uFEFF/, ''));
const canonical = value => JSON.stringify(value, (_, v) => v && !Array.isArray(v) && typeof v === 'object' ? Object.fromEntries(Object.entries(v).sort(([a],[b]) => a.localeCompare(b))) : v);
function need(condition, message) { if (!condition) throw new Error(message); }
function safeFile(root, name) {
  need(typeof name === 'string' && name.length > 0 && path.basename(name) === name && !name.includes('\\') && !name.includes('/'), 'Unsafe capture filename');
  return path.join(root, name);
}
function rawValues(bytes, width, height) {
  need(bytes.length === width * height * 16, 'RGBA32F byte length mismatch');
  const values = new Float64Array(width * height * 4);
  for (let i = 0; i < values.length; ++i) { values[i] = bytes.readFloatLE(i * 4); need(Number.isFinite(values[i]), 'Nonfinite HDR component'); }
  return values;
}
function metrics(a, b = null) {
  need(!b || a.length === b.length, 'Pixel length mismatch');
  let sum = 0, maximum = -Infinity, squared = 0, maxError = 0;
  for (let i = 0; i < a.length; i += 4) {
    sum += a[i] * .2126 + a[i+1] * .7152 + a[i+2] * .0722;
    for (let c = 0; c < 3; ++c) {
      maximum = Math.max(maximum, a[i+c]);
      if (b) { const error = a[i+c] - b[i+c]; squared += error * error; maxError = Math.max(maxError, Math.abs(error)); }
    }
  }
  return { meanLuminance: sum / (a.length / 4), maximumRgb: maximum, ...(b ? { rmse: Math.sqrt(squared / (a.length / 4 * 3)), maxError } : {}) };
}
function loadRun(root) {
  root = path.resolve(root);
  const run = json(path.join(root, 'run.json'));
  need(run.status === 'completed' && run.failures === 0 && run.backendMismatches === 0, 'Run failed, incomplete, or backend differs from its requested test');
  need(run.sequenceVersion === 1 && run.totalLogicalFrames === totalFrames && run.renderedFrames === totalFrames, 'Unsupported or incomplete sequence');
  need(Number.isInteger(run.width) && run.width >= 16 && run.width <= 4096 && Number.isInteger(run.height) && run.height >= 16 && run.height <= 4096, 'Invalid dimensions');
  need(Number.isInteger(run.captureEvery) && run.captureEvery > 0, 'Invalid capture interval');
  need(run.colorSpace === 'Linear' && run.targetSRGB === false && run.targetFormat === 'R32G32B32A32_SFloat' && run.postProcessing === false, 'Not the required linear HDR output');
  need(['Software', 'Hardware', 'FeatureDisabled'].includes(run.expectedBackend), 'Unknown backend request');
  const disabled = run.expectedBackend === 'FeatureDisabled';
  const backend = disabled ? 'feature-disabled' : run.expectedBackend === 'Hardware' ? 'reported-hardware' : 'reported-software';
  need(run.featureActive === !disabled, 'Feature state mismatch');
  const feature = json(safeFile(root, run.featureSnapshot));
  need(feature.settings && typeof feature.settings === 'object', 'Missing serialized feature settings');
  const receipts = fs.readFileSync(path.join(root, 'frames.jsonl'), 'utf8').trim().split(/\r?\n/).map(x => JSON.parse(x));
  need(receipts.length === totalFrames, 'Missing or repeated camera receipts');
  need(Number.isInteger(run.firstEngineFrame) && run.firstEngineFrame >= 0 && Number.isInteger(run.firstRenderedGiFrame), 'Missing first-frame counters');
  for (let i = 0; i < receipts.length; ++i) {
    const f = receipts[i];
    need(f.logicalFrame === i && f.engineFrame === run.firstEngineFrame + i && f.stage === stageAt(i), 'Receipt order/gap/phase mismatch');
    need(f.status === 'render-receipt' && f.reportedBackend === backend, 'Receipt backend/status mismatch');
    need(f.width === run.width && f.height === run.height, 'Receipt dimensions mismatch');
    need(disabled ? f.giFrame === -1 : f.diagnosticFresh === true && f.giFrame === run.firstRenderedGiFrame + i, 'Stale or skipped GI diagnostic counter');
    if (!disabled) need(f.diagnostics && f.diagnostics.camera === f.camera && f.diagnostics.frame === f.giFrame && f.diagnostics.hardwareBackend === (run.expectedBackend === 'Hardware'), 'Diagnostic identity mismatch');
  }
  const indices = Array.from({length: totalFrames}, (_, i) => i).filter(i => captureAt(i, run.captureEvery));
  need(run.capturesWritten === indices.length, 'Capture count mismatch');
  const metadataFiles = fs.readdirSync(root).filter(name => /^frame-\d+\.json$/.test(name));
  need(metadataFiles.length === indices.length, 'Missing or extra captured frame metadata');
  const frames = indices.map(i => {
    const frame = json(path.join(root, `frame-${String(i).padStart(4, '0')}.json`));
    need(frame.status === 'captured' && frame.gpuReadbackCompleted === true && frame.nonfiniteComponents === 0, 'Capture did not complete successfully');
    for (const field of ['sequenceVersion','logicalFrame','engineFrame','giFrame','width','height','stage','camera','reportedBackend','diagnosticFresh','cameraPosition','cameraRotation','cameraProjection','doorLocalPosition','lightsEnabled'])
      need(canonical(frame[field]) === canonical(receipts[i][field]), `Capture/receipt mismatch: ${field}`);
    const exr = fs.readFileSync(safeFile(root, frame.exrFile));
    need(exr.length >= 4 && exr.readUInt32LE(0) === 20000630, 'Missing/invalid EXR header (full EXR decoding is not performed)');
    // Keep only metadata here: large real captures are read one pair at a time.
    return frame;
  });
  return { root, run, feature, frames };
}
function analyze(candidate, reference, options = {}) {
  if (reference) {
    for (const field of ['sequenceVersion','width','height','captureEvery','colorSpace','targetFormat','targetSRGB','graphicsApi','graphicsUVStartsAtTop','rowOrder','unityVersion','urpAssemblyVersion','ambientMode','ambientLight','ambientIntensity','reflectionIntensity','hasSkybox','lightmapCount','fog','lights'])
      need(canonical(candidate.run[field]) === canonical(reference.run[field]), `Run contract differs: ${field}`);
    need(options.allowBackendDifference || candidate.run.expectedBackend === reference.run.expectedBackend, 'Backend differs; use explicit --allow-backend-difference for a backend comparison');
    need(options.allowFeatureStateDifference || candidate.run.featureActive === reference.run.featureActive, 'Feature state differs; use explicit --allow-feature-state-difference for an enabled/disabled comparison');
    const settings = value => { const copy = structuredClone(value.feature.settings); if (options.allowBackendDifference) delete copy.preferHardwareTracing; return copy; };
    need(canonical(settings(candidate)) === canonical(settings(reference)), 'Serialized GI settings differ (only explicit backend preference differences are permitted)');
    need(candidate.frames.length === reference.frames.length, 'Capture lists differ');
  }
  const frames = candidate.frames.map((f, index) => {
    const values = rawValues(fs.readFileSync(safeFile(candidate.root, f.rawFile)), f.width, f.height);
    let other = null;
    if (reference) {
      const r = reference.frames[index];
      for (const field of ['logicalFrame','stage','cameraPosition','cameraRotation','cameraProjection','doorLocalPosition','lightsEnabled']) need(canonical(f[field]) === canonical(r[field]), `Scene pose/phase differs: ${field}`);
      other = rawValues(fs.readFileSync(safeFile(reference.root, r.rawFile)), r.width, r.height);
    }
    return { logicalFrame: f.logicalFrame, stage: f.stage, engineFrame: f.engineFrame, giFrame: f.giFrame, reportedBackend: f.reportedBackend, ...metrics(values, other) };
  });
  const thresholdGiven = options.rmse !== undefined || options.maxError !== undefined;
  const passed = !reference || !thresholdGiven ? null : frames.every(f => (options.rmse === undefined || f.rmse <= options.rmse) && (options.maxError === undefined || f.maxError <= options.maxError));
  return { schema: 1, status: !reference ? 'reference-required' : !thresholdGiven ? 'comparison-only-threshold-required' : passed ? 'within-user-thresholds' : 'outside-user-thresholds', passed,
    candidate: candidate.root, reference: reference?.root ?? null, thresholds: { rmse: options.rmse ?? null, maxError: options.maxError ?? null },
    firstGiFrameOffset: reference ? candidate.run.firstRenderedGiFrame - reference.run.firstRenderedGiFrame : null,
    firstEngineFrameOffset: reference ? candidate.run.firstEngineFrame - reference.run.firstEngineFrame : null,
    limitation: 'RGB image comparison only. No established reference, per-sample deterministic replay, Feature success, actual DXR, physical GPU or production certification is inferred. GI counter offsets remain explicit.', frames };
}
function selfTest() {
  let checks = 0;
  const check = fn => { fn(); checks++; };
  check(() => assert.deepEqual(metrics([1,2,3,1], [2,2,3,1]), {meanLuminance:1.8596, maximumRgb:3, rmse:Math.sqrt(1/3), maxError:1}));
  check(() => assert.equal(metrics([0,0,0,1], [0,0,0,0]).rmse, 0));
  check(() => assert.throws(() => rawValues(Buffer.alloc(15), 1, 1), /length/));
  const bad = Buffer.alloc(16); bad.writeFloatLE(NaN, 0);
  check(() => assert.throws(() => rawValues(bad, 1, 1), /Nonfinite/));
  check(() => assert.throws(() => safeFile('.', '../outside'), /Unsafe/));
  check(() => assert.ok([119,120,179,180,209,210,239,240,299,300,359,360,419,420,719].every(i => captureAt(i, 71))));
  // Execute only the arithmetic of these two actual C# methods as JavaScript.
  // No Unity lifecycle, API binding, GPU callback or EXR codec is simulated here.
  const sourceRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
  const sequenceSource = fs.readFileSync(path.join(sourceRoot, 'Runtime/HybridLumenGIValidationSequence.cs'), 'utf8');
  const captureExpression = sequenceSource.match(/public static bool IsCaptureFrame\(int frame, int interval\)\s*\{\s*return ([\s\S]*?);\s*\}/);
  need(captureExpression, 'Cannot locate actual IsCaptureFrame arithmetic');
  const sourceCaptureAt = new Function('frame', 'interval', 'return ' + captureExpression[1].replaceAll('Math.Max', 'Math.max').replaceAll('TotalFrames', String(totalFrames)));
  check(() => { for (const interval of [1,30,31,71,1000]) for (let frame = -1; frame <= 720; frame++) assert.equal(sourceCaptureAt(frame, interval), frame >= 0 && frame < 720 && captureAt(frame, interval)); });
  const motionSource = fs.readFileSync(path.join(sourceRoot, 'Runtime/HybridLumenGIValidationMotion.cs'), 'utf8');
  const motionBody = motionSource.match(/public static float TravelAtFrame\(int frame\)\s*\{([\s\S]*?)\n\s*\}/);
  need(motionBody, 'Cannot locate actual TravelAtFrame arithmetic');
  const travel = new Function('frame', motionBody[1].replace(/\b(\d+(?:\.\d+)?)f\b/g, '$1'));
  check(() => { for (const [frame, value] of [[0,0],[119,0],[120,0],[179,1],[180,1],[209,1],[210,1],[239,0],[240,0],[719,0]]) assert.equal(travel(frame), value); });
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'hlgi-capture-comparison-'));
  const pose = {x:0,y:1,z:2}, rotation = {x:0,y:0,z:0,w:1};
  function fixture(name, value, startGi) {
    const dir = path.join(root, name); fs.mkdirSync(dir);
    const receipts = Array.from({length:totalFrames}, (_, i) => ({sequenceVersion:1,logicalFrame:i,engineFrame:100+i,giFrame:startGi+i,width:16,height:16,stage:stageAt(i),camera:'Validation Camera',reportedBackend:'reported-software',status:'render-receipt',diagnosticFresh:true,cameraPosition:pose,cameraRotation:rotation,doorLocalPosition:pose,lightsEnabled:i<240||i>=300,diagnostics:{camera:'Validation Camera',frame:startGi+i,hardwareBackend:false}}));
    const indices = receipts.filter(f => captureAt(f.logicalFrame, 71));
    const run = {status:'completed',failures:0,backendMismatches:0,sequenceVersion:1,totalLogicalFrames:720,renderedFrames:720,width:16,height:16,captureEvery:71,colorSpace:'Linear',targetSRGB:false,targetFormat:'R32G32B32A32_SFloat',postProcessing:false,expectedBackend:'Software',featureActive:true,featureSnapshot:'feature.json',firstEngineFrame:100,firstRenderedGiFrame:startGi,capturesWritten:indices.length};
    fs.writeFileSync(path.join(dir,'run.json'), JSON.stringify(run)); fs.writeFileSync(path.join(dir,'feature.json'), JSON.stringify({settings:{debugView:1,preferHardwareTracing:false}}));
    fs.writeFileSync(path.join(dir,'frames.jsonl'), receipts.map(x => JSON.stringify(x)).join('\n'));
    const pixels=Buffer.alloc(16*16*16);for(let i=0;i<pixels.length;i+=4)pixels.writeFloatLE(value,i);
    const exr=Buffer.alloc(4);exr.writeUInt32LE(20000630); // Header-only fixture, not a rendered EXR.
    for(const f of indices){const stem=`frame-${String(f.logicalFrame).padStart(4,'0')}`;const capture={...f,status:'captured',gpuReadbackCompleted:true,nonfiniteComponents:0,rawFile:stem+'.rgba32f',exrFile:stem+'.exr'};
      fs.writeFileSync(path.join(dir,stem+'.json'),JSON.stringify(capture));fs.writeFileSync(path.join(dir,capture.rawFile),pixels);fs.writeFileSync(path.join(dir,capture.exrFile),exr);}
    return dir;
  }
  const candidateDir=fixture('candidate',2,10), referenceDir=fixture('reference',1,8);
  const candidate=loadRun(candidateDir), reference=loadRun(referenceDir);
  check(()=>assert.equal(analyze(candidate,null).status,'reference-required'));
  check(()=>assert.equal(analyze(candidate,reference).passed,null));
  check(()=>assert.equal(analyze(candidate,reference,{rmse:1,maxError:1}).passed,true));
  check(()=>assert.equal(analyze(candidate,reference,{maxError:.99}).passed,false));
  check(()=>assert.equal(analyze(candidate,reference,{rmse:1}).firstGiFrameOffset,2));
  reference.feature.settings.debugView=0;
  check(()=>assert.throws(()=>analyze(candidate,reference,{rmse:1}),/settings differ/));reference.feature.settings.debugView=1;
  reference.run.graphicsApi='Different';
  check(()=>assert.throws(()=>analyze(candidate,reference),/graphicsApi/));delete reference.run.graphicsApi;
  const framePath=path.join(candidateDir,'frame-0000.json'), frame=json(framePath);frame.gpuReadbackCompleted=false;fs.writeFileSync(framePath,JSON.stringify(frame));
  check(()=>assert.throws(()=>loadRun(candidateDir),/did not complete/));frame.gpuReadbackCompleted=true;frame.giFrame++;fs.writeFileSync(framePath,JSON.stringify(frame));
  check(()=>assert.throws(()=>loadRun(candidateDir),/Capture\/receipt mismatch/));
  fs.writeFileSync(framePath,JSON.stringify({...frame,giFrame:frame.giFrame-1}));
  const receiptPath=path.join(candidateDir,'frames.jsonl'), lines=fs.readFileSync(receiptPath,'utf8').split('\n');const repeated=JSON.parse(lines[1]);repeated.engineFrame=100;lines[1]=JSON.stringify(repeated);fs.writeFileSync(receiptPath,lines.join('\n'));
  check(()=>assert.throws(()=>loadRun(candidateDir),/Receipt order/));
  const runPath=path.join(referenceDir,'run.json'), run=json(runPath);run.status='completed-with-backend-mismatch';fs.writeFileSync(runPath,JSON.stringify(run));
  check(()=>assert.throws(()=>loadRun(referenceDir),/backend differs/));
  process.stdout.write(JSON.stringify({status:'passed',checks,fixtures:root,scope:'Comparator inputs, float arithmetic and extracted two C# schedule arithmetic methods only; synthetic files, no Unity API/lifecycle, GPU execution or reference images.'},null,2)+'\n');
}
try {
  const args = process.argv.slice(2);
  if (args.length === 1 && args[0] === '--self-test') selfTest();
  else {
    const options={};let candidate,reference;
    for(let i=0;i<args.length;i++) {
      const arg=args[i];
      if(arg==='--candidate'||arg==='--reference'){need(args[i+1]&&!args[i+1].startsWith('--'),`Missing value for ${arg}`);if(arg==='--candidate')candidate=args[++i];else reference=args[++i];}
      else if(arg==='--rmse'||arg==='--max-error'){const text=args[++i];need(text!==undefined&&text.trim()!==''&&!text.startsWith('--'),'Missing threshold');const value=Number(text);need(Number.isFinite(value)&&value>=0,'Threshold must be finite and nonnegative');options[arg==='--rmse'?'rmse':'maxError']=value;}
      else if(arg==='--allow-backend-difference')options.allowBackendDifference=true;
      else if(arg==='--allow-feature-state-difference')options.allowFeatureStateDifference=true;
      else throw new Error(`Unknown argument: ${arg}`);
    }
    need(candidate,'Use --candidate <run-directory> [--reference <run-directory>] [--rmse number] [--max-error number]');
    const result=analyze(loadRun(candidate),reference?loadRun(reference):null,options);process.stdout.write(JSON.stringify(result,null,2)+'\n');process.exitCode=result.passed===null?2:result.passed?0:1;
  }
} catch(error) { process.stderr.write(JSON.stringify({status:'input-or-comparison-error',error:error.message})+'\n');process.exitCode=1; }

