"""Preserve a reference-input provenance gap without inventing historical assets."""
import argparse,hashlib,json,re,subprocess
from pathlib import Path
import numpy as np

ROOT=Path(__file__).resolve().parents[2]
SOURCE=ROOT/'LocalComparison/Review/scene-lightoff-chain-02'
RUN=SOURCE/'run/20261028-041010-d14728cf2da7410cbc7a56be035c20f6'
PROJECT=Path('I:/Unity test/Project')
sha=lambda data:hashlib.sha256(data).hexdigest()
read=lambda p:json.loads(p.read_text(encoding='utf-8-sig'))

def audit(output):
 if output.exists():raise ValueError('Never overwrite a source audit snapshot')
 output.mkdir(parents=True)
 execution=read(SOURCE/'execution.json');expected=execution['outputSha256'];frozen={}
 def raw(path):
  data=path.read_bytes();key=str(path.relative_to(SOURCE/'run'));actual=sha(data)
  if expected.get(key)!=actual:raise ValueError('Frozen source hash mismatch: '+key)
  frozen[key]=actual;return data
 historical={}
 for name in ['executed-assets/Assets_ThinWallProbe_Static.unity','base-C-contract.json','source-inventory.json']:
  data=raw(SOURCE/'run'/name);destination=output/'frozen'/Path(name).name;destination.parent.mkdir(parents=True,exist_ok=True);destination.write_bytes(data);historical[name]=data
 scene=historical['executed-assets/Assets_ThinWallProbe_Static.unity'].decode('utf-8-sig')
 guids=sorted(set(re.findall(r'fileID: 2100000, guid: ([0-9a-f]{32})',scene)))
 if len(guids)!=6:raise ValueError('Expected six frozen external materials')
 available={}
 for meta in (PROJECT/'Assets/ComparisonScene/Run').glob('*.mat.meta'):
  match=re.search(r'^guid: ([0-9a-f]{32})$',meta.read_text(encoding='utf-8-sig'),re.MULTILINE)
  if match:available[match.group(1)]=meta
 materials=[]
 for guid in guids:
  meta=available.get(guid)
  if meta is None:
   materials.append({'guid':guid,'currentReadable':False,'historicalIdentityProven':False});continue
  material=meta.with_suffix('');data=material.read_bytes();meta_data=meta.read_bytes();text=data.decode('utf-8-sig')
  target=output/'current-only';target.mkdir(exist_ok=True);(target/material.name).write_bytes(data);(target/meta.name).write_bytes(meta_data)
  materials.append({'guid':guid,'currentReadable':True,'projectPath':material.relative_to(PROJECT).as_posix(),'name':material.stem,'sha256':sha(data),'metaSha256':sha(meta_data),'lastWriteTimeUnix':material.stat().st_mtime,'historicalIdentityProven':False,'classification':'current-only; GUID/mtime do not prove historical diffuse values','currentSerializedDiffuseFields':[line.strip() for line in text.splitlines() if re.match(r'\s*- _(BaseColor|Metallic|SpecColor|WorkflowMode):',line)]})
 # Content-hash search is evidence discovery only, never an automatic historical certification.
 patterns=output/'current-material-hashes.txt';patterns.write_text('\n'.join(m['sha256'] for m in materials if m['currentReadable'])+'\n',encoding='utf-8')
 scopes=[{'directory':ROOT/'LocalComparison','globs':['*.json']},{'directory':Path('I:/Unity test/Comparison'),'globs':['*manifest*.json','*receipt*.json','*inventory*.json']}]
 searches=[]
 for scope in scopes:
  command=['rg','-l','-F','-f',str(patterns),'--glob','!**/scene-radiometry-reference-01/**']
  for glob in scope['globs']:command+=['--glob',glob]
  command.append(str(scope['directory']));result=subprocess.run(command,capture_output=True,text=True,encoding='utf-8')
  if result.returncode not in (0,1):raise RuntimeError(result.stderr)
  searches.append({'directory':str(scope['directory']),'includeGlobs':scope['globs'],'exclude':'scene-radiometry-reference-01','exitCode':result.returncode,'contentHashMatches':result.stdout.splitlines(),'scopeNote':'These are the searched local evidence stores, not a claim about all possible backups.'})
 # Export only the observed location/normal/identity, never incoming/cache RGB as solver input.
 schedule=json.loads(raw(RUN/'lightoff-schedule-0119.json'));cache=np.frombuffer(raw(RUN/'lightoff-0119-cache-observed.bin'),dtype='<f4').reshape(4,20,4)
 bits=cache.view('<u4');targets=[]
 for lane,p in enumerate(schedule['patches']):
  if not np.array_equal(bits[lane,18],[p['entry'],119,schedule['giFrame'],0x4c4f3031]):raise ValueError('Target cache header invalid')
  anchor=cache[lane,7];normal=cache[lane,8]
  targets.append({'id':'cache-'+str(p['entry']),'kind':'actual-cache-anchor','observedIdentity':{k:p[k] for k in ['entry','card','slot','stableId','revision','generation','layout','chart','cellX','cellY']},'position':anchor[:3].astype(float).tolist(),'shadingNormal':normal[:3].astype(float).tolist(),'geometricNormalOct':[float(anchor[3]),float(normal[3])],'sourceRecord':{'file':'lightoff-0119-cache-observed.bin','lane':lane,'float4Indices':[7,8]},'triangleCorrespondenceVerified':False})
 stream=np.frombuffer(raw(RUN/'gather-0119-events.bin'),dtype='<u4').reshape(4,256,32);floats=stream.view('<f4')
 for lane in range(4):
  header=stream[lane,0];count=int(header[1])
  if not(2<=count<=256 and np.array_equal(header[:4],[0,count,1,0]) and np.array_equal(header[4:8],[119,schedule['giFrame'],lane,0x47434131]) and stream[lane,count-1,0]==1):raise ValueError('Target receiver stream invalid')
  records=[i for i in range(1,count) if stream[lane,i,0]==10]
  if len(records)!=1:raise ValueError('Missing or duplicate actual receiver')
  index=records[0];v=floats[lane,index,4:].reshape(7,4)
  targets.append({'id':'gi-'+str(lane),'kind':'actual-GI-receiver','giPixel':[[160,45],[100,90],[220,90],[100,30]][lane],'position':v[0,:3].astype(float).tolist(),'shadingNormal':v[1,:3].astype(float).tolist(),'geometricNormal':v[2,:3].astype(float).tolist(),'hasGeometry':bool(v[1,3]),'sourceRecord':{'file':'gather-0119-events.bin','lane':lane,'eventIndex':index,'code':10},'triangleCorrespondenceVerified':False})
 if len(targets)!=6 or not all(np.all(np.isfinite(t['position'])) and np.all(np.isfinite(t['shadingNormal'])) for t in targets):raise ValueError('Six finite targets required')
 (output/'targets.json').write_text(json.dumps({'frame':119,'targets':targets,'purpose':'Locations only; not an independent material/radiance answer.'},indent=2),encoding='utf-8')
 bound_paths=sorted(execution['executedAssetSha256'])
 # The chain02 manifest actually binds scene/settings assets, not these external material files.
 material_bindings=[p for p in bound_paths if p.endswith('.mat')]
 if material_bindings:raise ValueError('Unexpected historical material binding: inspect before classifying gap')
 result={'historicalSourceClosure':False,'integrationExecuted':False,'historicalQuantitativeComparisonPerformed':False,'sixPointReferenceCompleted':False,'runtimeChanged':False,'unityStarted':False,'historicalRun':str(RUN.relative_to(ROOT)),'frozenInputsSha256':frozen,'executedAssetPaths':bound_paths,'currentMaterials':materials,'historicalEvidenceSearch':searches,'targetLocationsExtracted':len(targets),'targetSurfaceCorrespondenceVerified':False,'sourceGaps':[{'kind':'external-historical-material-bytes','guids':guids,'missingFields':['BaseColor source/linearization','metallic/specular workflow inputs','complete material keywords/textures/AO policy'],'evidence':'Frozen scene retains external GUID references; execution asset hashes omit material files; historical inventory does not serialize complete diffuse inputs.'}],'nextStep':'Review source gap, then define a prospective baseline that binds complete input dependencies and matched product observations. No historical quantitative comparison or extra render in this package.','limitations':['Current file bytes/GUID/mtime and matching emission metadata cannot certify old diffuse values.','The old independent mesh export lacks full radiometric material inputs.','Observed target locations do not yet prove source triangle/material correspondence.']}
 (output/'source-audit.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
 (output/'snapshot-sha256.json').write_text(json.dumps({str(p.relative_to(output)):sha(p.read_bytes()) for p in sorted(output.rglob('*')) if p.is_file()},indent=2),encoding='utf-8')
 return result

if __name__=='__main__':
 parser=argparse.ArgumentParser();parser.add_argument('--output',type=Path,required=True);args=parser.parse_args();result=audit(args.output)
 print(json.dumps({k:result[k] for k in ['historicalSourceClosure','integrationExecuted','historicalQuantitativeComparisonPerformed','sixPointReferenceCompleted','unityStarted','targetLocationsExtracted','targetSurfaceCorrespondenceVerified','sourceGaps','historicalEvidenceSearch']}))
 raise SystemExit(2)
