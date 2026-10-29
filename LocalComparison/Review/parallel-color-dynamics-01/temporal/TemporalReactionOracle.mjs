import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
const base=path.dirname(fileURLToPath(import.meta.url));
const [action,directory,candidatePath]=process.argv.slice(2);
const hash=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const fixed=[
  {name:'reactive-unknown',reactive:1,length:32,alphaOld:.08,alphaNew:1/3,eventOld:32,eventNew:2,recoveryOld:32,recoveryNew:3},
  {name:'nonreactive-unknown',reactive:0,length:32,alphaOld:.08,alphaNew:.08,eventOld:32,eventNew:32,recoveryOld:32,recoveryNew:32},
  {name:'invalid-old',reactive:1,length:32,invalid:true,alphaOld:1,alphaNew:1,eventOld:0,eventNew:0,recoveryOld:1,recoveryNew:1},
  {name:'short-old',reactive:1,length:1,alphaOld:.5,alphaNew:.5,eventOld:1,eventNew:1,recoveryOld:2,recoveryNew:2},
  {name:'known-reactive',reactive:1,length:32,known:true,alphaOld:1/3,alphaNew:1/3,eventOld:2,eventNew:2,recoveryOld:3,recoveryNew:3},
  {name:'hard-rejected',reactive:1,length:32,hard:true,alphaOld:1,alphaNew:1,eventOld:0,eventNew:0,recoveryOld:1,recoveryNew:1}
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
  assert.ok(path.isAbsolute(directory)&&path.isAbsolute(candidatePath),'Absolute paths required');
  const oldBytes=fs.readFileSync(path.join(base,'frozen/HybridLumenGIKernels.hlsl'));
  const newBytes=fs.readFileSync(candidatePath);
  const oldText=oldBytes.toString('utf8').replaceAll('\r\n','\n');
  const newText=newBytes.toString('utf8').replaceAll('\r\n','\n');
  const line='        HLGIResolveUnknownHistory(valid,history,moments,retained,retainedMoments);\n';
  assert.equal(oldText.split(line).length-1,2,'Expected exactly two old retention calls');
  const expected=oldText.replaceAll(line,line+'        if(change.y>0.5) retainedMoments.z=min(retainedMoments.z,2);\n');
  assert.equal(newText,expected,'Candidate must contain only the two declared cap lines');
  for(const [label,text] of [['baseline',oldText],['candidate',newText]]) {
    fs.mkdirSync(path.join(directory,label));
    fs.writeFileSync(path.join(directory,label,'ActualTemporalBody.hlsl'),actualBody(text));
  }
  const input=Buffer.alloc(4+176*fixed.length);input.writeUInt32LE(fixed.length);
  fixed.forEach((row,index)=>{
    const values=[1,1,1,row.invalid?0:1,1,1,row.length,0,
      ...(row.known?[1,1,1,1]:[0,0,0,-1]),1.03125,1.03125,1.03125,1,
      row.reactive,row.hard?1:0,1,0,...Array(24).fill(0)];
    assert.equal(values.length,44);values.forEach((value,lane)=>input.writeFloatLE(value,4+index*176+lane*4));
  });
  fs.writeFileSync(path.join(directory,'inputs.bin'),input);
  fs.writeFileSync(path.join(directory,'oracle.json'),JSON.stringify({cases:fixed,inputStride:176,outputStride:64,
    sourceHashes:{baseline:hash(oldBytes),candidate:hash(newBytes)},
    scope:'Actual temporal body with explicit fixed dependency/half-rounding adapters; not real texture-format or scene evidence'},null,2));
  console.log('Prepared six fixed rows, two dependent calls per actual temporal variant; no GPU executed by prepare.');
} else if(action==='verify') {
  const report={status:'running',cases:[],scope:'Finite actual-body WARP consumer comparison; no Unity/physical GPU/real texture-format proof'};
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
          const eventLength=row['event'+variant],length=row['recovery'+variant],alpha=row['alpha'+variant];
          const eventValid=eventLength>0;
          const eventExpected=eventValid?[1,1,1,1,1,1,eventLength,0]:Array(8).fill(0);
          for(let lane=0;lane<8;lane++) require(values[lane]===eventExpected[lane],`${row.name}/${mode}/${variant}: event lane ${lane}`);
          const expected=(1-alpha)+alpha*1.03125,second=(1-alpha)+alpha*(1.03125**2);
          for(let lane=8;lane<11;lane++)require(Math.abs(values[lane]-expected)<=.0009,`${row.name}/${mode}/${variant}: recovery radiance ${lane}`);
          require(values[11]===1&&values[14]===length,`${row.name}/${mode}/${variant}: recovery confidence/length`);
          require(Math.abs(values[12]-expected)<=.000002&&Math.abs(values[13]-second)<=.000002,`${row.name}/${mode}/${variant}: recovery moments`);
          require(Math.abs(values[15])<=.000002,`${row.name}/${mode}/${variant}: spatial variance`);
        }
        if(index===0) {
          for(const lane of [0,1,2,3,4,5,7])require(a.readUInt32LE(lane*4)===b.readUInt32LE(lane*4),`${row.name}/${mode}: changed retained lane ${lane}`);
          require(bv[8]-av[8]>.004,`${row.name}/${mode}: lost recovery effect/no-op`);
        } else require(a.equals(b),`${row.name}/${mode}: control not bit-identical`);
      }
    }
    require(buffers.legacy[0].equals(buffers.identity[0])&&buffers.legacy[1].equals(buffers.identity[1]),'Qualified static identity changes finite result');
    report.status='passed';report.checks=checks;
  } catch(error) { report.status='failed';report.checks=checks;report.error=String(error);throw error; }
  finally {fs.writeFileSync(path.join(directory,'oracle-results.json'),JSON.stringify(report,null,2));}
  console.log(JSON.stringify({status:report.status,checks,rows:report.cases.length}));
} else throw new Error('Expected prepare or verify');
