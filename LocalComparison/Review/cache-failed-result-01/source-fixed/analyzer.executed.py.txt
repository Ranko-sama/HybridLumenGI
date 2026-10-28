"""Fixed six-case cache contract oracle. Baseline intentionally exits 1 on the contract counterexample."""
import argparse,json,hashlib,math
from pathlib import Path
import numpy as np
from native_log_check import scan
p=argparse.ArgumentParser();p.add_argument('phase',choices=['baseline','fixed']);p.add_argument('--output',type=Path,required=True);args=p.parse_args()
root=Path(__file__).resolve().parents[2];package=root/'LocalComparison/Review/cache-failed-result-01';directory=package/args.phase
report=json.loads((directory/'collection.json').read_text(encoding='utf-8'));receipt=json.loads((package/(args.phase+'-execution.json')).read_text(encoding='utf-8'))
log=package/(args.phase+'-Unity.log');native_hits=scan(log)
native_ok=receipt['exitCode']==0 and hashlib.sha256(log.read_bytes()).hexdigest()==receipt['nativeLogSha256'] and not native_hits
errors=[];contract=[];rows=[]
def check(yes,label,case=None):
 if not bool(yes):errors.append({'case':case,'check':label})
def near(actual,expected,label,case):
 a=np.asarray(actual,dtype=np.float64);e=np.asarray(expected,dtype=np.float64)
 check(np.all(np.isfinite(a)) and np.all(np.abs(a-e)<=2e-7+1e-6*np.abs(e)),label,case)
def exact(actual,expected,label,case):check(np.array_equal(actual,expected),label,case)
def vector(v):return np.array([v[k] for k in ['x','y','z','w']],dtype=np.float64)
check(report['collectionComplete'] and report['cases']==6 and report['pending']==0 and report['error']=='','complete six-case collection')
check(native_ok,'complete native exit without failure signatures')
if args.phase=='fixed':
 baseline_report=json.loads((package/'baseline/collection.json').read_text(encoding='utf-8'))
 check(report['inputs']==baseline_report['inputs'],'identical fixture inputs')
 for name in ['CacheFailedResult.compute','CacheFailedResultEditor.cs']:
  check((package/'source-baseline'/name).read_bytes()==(package/'source-fixed'/name).read_bytes(),'identical helper '+name)
for index,case in enumerate(report['inputs']):
 name=case['name'];data=(directory/(name+'.bin')).read_bytes();v=np.frombuffer(data,dtype='<f4').astype(np.float64).reshape(14,4)
 check(len(data)==224 and np.all(np.isfinite(v)),'finite 224-byte output',name)
 exact(v[7,2:],[index,314159],'case/write stamp',name)
 tiny=index==0;success=index in [1,5];accepted=tiny or success
 weight=2.0**(-18 if tiny else -16);expected_total=weight if accepted else 0.
 exact(v[5],[int(success),expected_total,expected_total,3 if success else 2],'actual lookup branch/weight/total',name)
 exact(v[6],[0,0,weight,0],'actual base cell/fraction',name)
 exact(v[7,:2],[int(accepted),int(accepted)],'accepted tap/visibility count',name)
 irradiance=vector(case['cache'][1]['irradiance']);guide=vector(case['cache'][1]['guide'])
 base=vector(case['emission'])[:3]+vector(case['diffuse'])[:3]*vector(case['direct'])[:3]
 coefficient=vector(case['diffuse'])[:3]*case['diffuse']['w']
 residual=tiny and args.phase=='baseline'
 expected_cache=irradiance if success else irradiance*weight if residual else np.zeros(4)
 expected_guide=guide if success else guide*weight if residual else np.zeros(4)
 exact(v[0],expected_cache,'actual low-level irradiance',name);exact(v[1:4],np.zeros((3,4)),'cache non-accumulator fields',name);exact(v[4],expected_guide,'actual low-level guide',name)
 exact(v[8,:3],irradiance[:3] if success else np.zeros(3),'actual screen wrapper cache',name)
 expected_world=base+coefficient*np.maximum(expected_cache[:3],0)
 exact(v[9,:3],expected_world,'actual world radiance with direct/emission preserved',name);exact(v[9,3],1,'world remains known',name)
 exact(v[10],expected_cache,'actual receiver irradiance without bool override',name);exact(v[11],expected_guide,'actual receiver guide without bool override',name)
 exact(v[12],[int(success),expected_total,3 if success else 2,int(accepted)],'receiver lookup state',name)
 # Independent original guide eligibility; low-weight unit-vector residue is not eligible.
 eligible=expected_guide[3]>1e-6 and float(np.dot(expected_guide[:3],expected_guide[:3]))>.5
 expected_pdf=(.5 if eligible else 1.)/math.pi
 near(v[13,:2],[expected_pdf,1/math.pi],'actual direction PDF and zero-guide control',name);exact(v[13,2:],np.zeros(2),'actual zero proposal header and disabled branch',name)
 desired_zero=not success
 if desired_zero and data[:80]!=bytes(80):contract.append({'case':name,'check':'false lookup must return whole zero 80-byte cache structure'})
 if desired_zero and not np.array_equal(v[9,:3],base):contract.append({'case':name,'check':'failed cache must not add a world cache term'})
 if desired_zero and (np.any(v[10]) or np.any(v[11])):contract.append({'case':name,'check':'failed receiver lookup must not expose partial result'})
 if args.phase=='fixed' and index!=0:
  check(data==(package/'baseline'/(name+'.bin')).read_bytes(),'successful/black/stale control byte-for-byte unchanged',name)
 rows.append({'name':name,'lookupBool':bool(v[5,0]),'actualWeight':float(v[5,1]),'actualTotal':float(v[5,2]),'exitReason':int(v[5,3]),
  'lookupIrradiance':v[0].tolist(),'lookupGuide':v[4].tolist(),'fullFailedStructureZero':data[:80]==bytes(80),'screenCache':v[8,:3].tolist(),
  'worldRadiance':v[9].tolist(),'worldWithoutCache':base.tolist(),'worldCacheIncrement':(v[9,:3]-base).tolist(),
  'receiverIrradiance':v[10].tolist(),'receiverGuide':v[11].tolist(),'actualPdf':float(v[13,0]),'zeroGuidePdf':float(v[13,1]),'guideEligible':bool(eligible)})
fixture_valid=not errors;controls_passed=not any(e['case'] not in [None,'tiny-positive'] for e in errors) and not any(e['case']!='tiny-positive' for e in contract)
counterexample=args.phase=='baseline' and fixture_valid and controls_passed and len(contract)==3 and rows[0]['exitReason']==2
result={'phase':args.phase,'fixtureValid':fixture_valid,'controlsPassed':controls_passed,'nativeExitPassed':native_ok,'counterexampleConfirmed':counterexample,
 'contractPassed':fixture_valid and not contract,'fixtureErrors':errors,'contractFailures':contract,'nativeSignatures':native_hits,'cases':rows,
 'scope':'Actual source cache/consumer/PDF function contract with explicit fixed dependency adapters. Not atlas capture, geometry traversal, actual sampled directions, visible leak, whole-image or production acceptance.'}
args.output.write_text(json.dumps(result,indent=2),encoding='utf-8')
print(json.dumps({k:result[k] for k in ['phase','fixtureValid','controlsPassed','nativeExitPassed','counterexampleConfirmed','contractPassed','fixtureErrors','contractFailures']}))
raise SystemExit(0 if result['contractPassed'] else 1)
