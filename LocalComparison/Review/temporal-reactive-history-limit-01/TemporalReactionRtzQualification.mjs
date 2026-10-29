import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
const base=path.dirname(fileURLToPath(import.meta.url));
const [action,directory,candidatePath]=process.argv.slice(2);
const hash=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
// Microsoft Data Conversion Rules: narrowing a FLOAT format uses round-to-zero.
// https://learn.microsoft.com/en-us/windows/win32/direct3d10/d3d10-graphics-programming-guide-resources-data-conversion
// All declared oracle values lie in [1,2), so binary16 and binary32 share one
// exponent; retaining the high ten fraction bits gives the exact stored value.
// This independent integer encoding model never uses a GPU answer as an input.
function storedHalfRtz(value) {
  assert.ok(Number.isFinite(value)&&value>=1&&value<2,'Declared normal [1,2) oracle domain');
  const bytes=Buffer.alloc(4);bytes.writeFloatLE(Math.fround(value));
  bytes.writeUInt32LE((bytes.readUInt32LE()&0xffffe000)>>>0);
  return bytes.readFloatLE();
}
const fixed=[
  {name:'max1-reactive-known',maxHistory:1,reactive:1,length:1,known:true,eventAlphaOld:.5,eventAlphaNew:1,eventOld:2,eventNew:1,recoveryAlpha:1,recovery:1},
  {name:'max1-stable-known',maxHistory:1,reactive:0,length:1,known:true,eventAlphaOld:1,eventAlphaNew:1,eventOld:1,eventNew:1,recoveryAlpha:1,recovery:1},
  {name:'max2-reactive-known',maxHistory:2,reactive:1,length:2,known:true,eventAlphaOld:.5,eventAlphaNew:.5,eventOld:2,eventNew:2,recoveryAlpha:.5,recovery:2},
  {name:'max32-reactive-known',maxHistory:32,reactive:1,length:32,known:true,eventAlphaOld:.5,eventAlphaNew:.5,eventOld:2,eventNew:2,recoveryAlpha:1/3,recovery:3},
  {name:'max1-invalid-previous',maxHistory:1,reactive:1,length:1,known:true,invalid:true,eventAlphaOld:1,eventAlphaNew:1,eventOld:1,eventNew:1,recoveryAlpha:1,recovery:1},
  {name:'max1-reactive-unknown',maxHistory:1,reactive:1,length:1,eventAlphaOld:0,eventAlphaNew:0,eventOld:1,eventNew:1,recoveryAlpha:1,recovery:1},
  {name:'max32-reactive-unknown',maxHistory:32,reactive:1,length:32,eventAlphaOld:0,eventAlphaNew:0,eventOld:2,eventNew:2,recoveryAlpha:1/3,recovery:3}
];
function extractFunction(source,name) {
  const expression=new RegExp('^(?:float[234]?|bool|void) '+name+'\\(', 'm');
  const match=expression.exec(source);assert.ok(match,`Missing actual ${name}`);
  const opening=source.indexOf('{',match.index);let depth=1,end=opening+1;
  while(depth>0&&end<source.length){if(source[end]==='{')depth++;if(source[end]==='}')depth--;end++;}
  assert.equal(depth,0,`Unclosed actual ${name}`);return source.slice(match.index,end);
}
function actualBody(source) {
  const begin=source.indexOf('bool HLGITemporalTapMatches(');
  const end=source.indexOf('[numthreads(8,8,1)]\nvoid CSFilter(');
  assert.ok(begin>=0&&end>begin,'Actual temporal source boundaries changed');
  let body=source.slice(begin,end);
  assert.equal((body.match(/\[numthreads\(8,8,1\)\]/g)||[]).length,1);
  // The numthreads attribute belongs to the original entry point, not a callable
  // function. Its body and preprocessor identity variant remain actual source.
  body=body.replace('[numthreads(8,8,1)]\n','');
  assert.equal((body.match(/_HLGI_Output\[pixel\]/g)||[]).length,6);
  assert.equal((body.match(/_HLGI_MomentsOut\[pixel\]/g)||[]).length,6);
  body=body.replaceAll('_HLGI_Output[pixel]','adapterOutput').replaceAll('_HLGI_MomentsOut[pixel]','adapterMoments');
  return ['WorldPosition','ProjectUV','LuminanceGI'].map(n=>extractFunction(source,n)).join('\n\n')+'\n\n'+body;
}
if(action==='prepare') {
  throw new Error('Qualification reads existing paired outputs only; no preparation or GPU rerun');
  assert.ok(path.isAbsolute(directory)&&path.isAbsolute(candidatePath),'Absolute paths required');
  const oldBytes=fs.readFileSync(path.join(base,'frozen/HybridLumenGIKernels.hlsl'));
  const newBytes=fs.readFileSync(candidatePath);
  const oldText=oldBytes.toString('utf8').replaceAll('\r\n','\n');
  const newText=newBytes.toString('utf8').replaceAll('\r\n','\n');
  const line='    float samples=valid?min(moments.z+1,change.y>0.5?2:(float)_HLGI_MaxHistory):1;';
  assert.equal(oldText.split(line).length-1,1,'Expected exactly one old shared samples expression');
  const expected=oldText.replace(line,'    float samples=valid?min(moments.z+1,change.y>0.5?min(2,(float)_HLGI_MaxHistory):(float)_HLGI_MaxHistory):1;');
  assert.equal(newText,expected,'Candidate must contain only the declared intersection of reactive/configured limits');
  for(const [label,text] of [['baseline',oldText],['candidate',newText]]) {
    fs.mkdirSync(path.join(directory,label));
    fs.writeFileSync(path.join(directory,label,'ActualTemporalBody.hlsl'),actualBody(text));
  }
  const input=Buffer.alloc(4+176*fixed.length);input.writeUInt32LE(fixed.length);
  fixed.forEach((row,index)=>{
    const values=[1,1,1,1,1,1,row.length,0,
      ...(row.known?[1,1,1,1]:[0,0,0,-1]),1.03125,1.03125,1.03125,1,
      row.reactive,0,row.invalid?0:1,row.maxHistory,...Array(24).fill(0)];
    if(row.known)values.splice(8,4,1.03125,1.03125,1.03125,1);
    assert.equal(values.length,44);values.forEach((value,lane)=>input.writeFloatLE(value,4+index*176+lane*4));
  });
  fs.writeFileSync(path.join(directory,'inputs.bin'),input);
  fs.writeFileSync(path.join(directory,'oracle.json'),JSON.stringify({cases:fixed,inputStride:176,outputStride:64,
    sourceHashes:{baseline:hash(oldBytes),candidate:hash(newBytes)},
    scope:'Actual temporal body with explicit fixed dependency/half-rounding adapters; not real texture-format or scene evidence'},null,2));
  console.log('Prepared seven fixed rows, two dependent calls per actual temporal variant; no GPU executed by prepare.');
} else if(action==='verify') {
  const evidenceNames=['result.json','oracle-results.json','oracle.json','inputs.bin',
    'baseline-legacy.bin','candidate-legacy.bin','baseline-identity.bin','candidate-identity.bin'];
  const before=Object.fromEntries(evidenceNames.map(name=>[name,hash(fs.readFileSync(path.join(directory,name)))]));
  const qualificationDirectory=path.join(base,'qualification');
  assert.ok(!fs.existsSync(qualificationDirectory),'Preserve an existing qualification result');
  fs.mkdirSync(qualificationDirectory);
  const original=JSON.parse(fs.readFileSync(path.join(directory,'result.json'),'utf8').replace(/^\uFEFF/,''));
  assert.equal(original.status,'failed','Original failure remains unchanged');
  const report={status:'running',originalFrozenPass:false,gpuRerun:false,cases:[],
    source:'https://learn.microsoft.com/en-us/windows/win32/direct3d10/d3d10-graphics-programming-guide-resources-data-conversion',
    qualification:'Independent positive-normal binary32-to-binary16 round-to-zero bit model; frozen inputs and all original readbacks retained',
    scope:'Finite actual-body WARP consumer comparison; no Unity/physical GPU/real texture-format proof'};
  let checks=0;
  const require=(test,message)=>{checks++;assert.ok(test,message);};
  const read=(variant,identity)=>{
    const buffer=fs.readFileSync(path.join(directory,`${variant}-${identity}.bin`));
    assert.equal(buffer.length,fixed.length*64,'Readback size');return buffer;
  };
  const vectors=buffer=>Array.from({length:16},(_,i)=>buffer.readFloatLE(i*4));
  try {
    const buffers={};
    for(const mode of ['legacy','identity']) {
      const old=read('baseline',mode),next=read('candidate',mode);buffers[mode]=[old,next];
      for(let index=0;index<fixed.length;index++) {
        const row=fixed[index],a=old.subarray(index*64,(index+1)*64),b=next.subarray(index*64,(index+1)*64);
        const av=vectors(a),bv=vectors(b);report.cases.push({name:row.name,mode,baseline:av,candidate:bv});
        require([...av,...bv].every(Number.isFinite),`${row.name}/${mode}: nonfinite output`);
        for(const [variant,bytes,values] of [['Old',a,av],['New',b,bv]]) {
          const eventLength=row['event'+variant],eventAlpha=row['eventAlpha'+variant],alpha=row.recoveryAlpha;
          const eventMean=(1-eventAlpha)+eventAlpha*1.03125;
          const eventStored=storedHalfRtz(eventMean);
          const eventSecond=(1-eventAlpha)+eventAlpha*(1.03125**2);
          for(let lane=0;lane<3;lane++) require(values[lane]===eventStored,`${row.name}/${mode}/${variant}: exact event radiance ${lane}`);
          require(values[3]===1&&values[6]===eventLength,`${row.name}/${mode}/${variant}: event confidence/length`);
          require(Math.abs(values[4]-eventMean)<=.000002&&Math.abs(values[5]-eventSecond)<=.000002,`${row.name}/${mode}/${variant}: event moments`);
          const expected=(1-alpha)*eventMean+alpha*1.03125,second=(1-alpha)*eventSecond+alpha*(1.03125**2);
          const recoveryStored=storedHalfRtz((1-alpha)*eventStored+alpha*1.03125);
          for(let lane=8;lane<11;lane++)require(values[lane]===recoveryStored,`${row.name}/${mode}/${variant}: exact RTZ recovery radiance ${lane}`);
          require(values[11]===1&&values[14]===row.recovery,`${row.name}/${mode}/${variant}: recovery confidence/length`);
          require(Math.abs(values[12]-expected)<=.000002&&Math.abs(values[13]-second)<=.000002,`${row.name}/${mode}/${variant}: recovery moments`);
          require(Math.abs(values[7])<=.000002&&Math.abs(values[15])<=.000002,`${row.name}/${mode}/${variant}: spatial variance`);
        }
        if(index===0) {
          require(av[0]===1.015625&&bv[0]===1.03125&&av[6]===2&&bv[6]===1,`${row.name}/${mode}: concrete baseline violation or candidate correction missing`);
          require(a.subarray(32).equals(b.subarray(32)),`${row.name}/${mode}: next stable max1 frame changed`);
        } else require(a.equals(b),`${row.name}/${mode}: control not bit-identical`);
      }
    }
    require(buffers.legacy[0].equals(buffers.identity[0])&&buffers.legacy[1].equals(buffers.identity[1]),'Qualified static identity changes finite result');
    report.status='passed';report.checks=checks;
  } catch(error) { report.status='failed';report.checks=checks;report.error=String(error);throw error; }
  finally {
    const after=Object.fromEntries(evidenceNames.map(name=>[name,hash(fs.readFileSync(path.join(directory,name)))]));
    report.originalEvidenceBefore=before;report.originalEvidenceAfter=after;
    report.qualificationScriptSha256=hash(fs.readFileSync(fileURLToPath(import.meta.url)));
    report.originalOracleSha256=hash(fs.readFileSync(path.join(base,'TemporalReactionOracle.mjs')));
    report.originalContractSha256=hash(fs.readFileSync(path.join(base,'contract.txt')));
    if(JSON.stringify(before)!==JSON.stringify(after)){report.status='failed';report.error='Original evidence changed';}
    fs.writeFileSync(path.join(qualificationDirectory,'result.json'),JSON.stringify(report,null,2));
    assert.deepEqual(after,before,'Original evidence bytes retained');
  }
  console.log(JSON.stringify({status:report.status,checks,rows:report.cases.length}));
} else throw new Error('Expected prepare or verify');
