"""Mechanically extract actual production functions for one fixed Unity fixture."""
import argparse,hashlib,json,re,shutil,subprocess
from pathlib import Path
root=Path(__file__).resolve().parents[2];assets=Path('I:/Unity test/Project/Assets')
shader=root/'Runtime/Resources/HybridLumenGI';out=root/'LocalComparison/Review/cache-failed-result-01'
parser=argparse.ArgumentParser();parser.add_argument('action',choices=['prepare','install','apply-fix']);parser.add_argument('--phase',choices=['baseline','fixed'],default='baseline');args=parser.parse_args()
sha=lambda b:hashlib.sha256(b).hexdigest()
transport=shader/'HybridLumenGITransport.hlsl'
old=b'if(totalWeight<=1e-5) return false;';new=b'if(totalWeight<=1e-5) { result=(HLGICacheEntry)0;return false; }'
if args.action=='apply-fix':
 proof=json.loads((out/'baseline-analysis.json').read_text(encoding='utf-8'))
 assert proof['counterexampleConfirmed'] and proof['fixtureValid'] and proof['controlsPassed'] and proof['nativeExitPassed'],'Actual source counterexample/controls/exit required before fix'
 original=(out/'source-baseline/HybridLumenGITransport.hlsl').read_bytes()
 assert transport.read_bytes()==original and original.count(old)==1
 candidate=original.replace(old,new)
 deployed=assets/'HybridLumenGI/Runtime/Resources/HybridLumenGI/HybridLumenGITransport.hlsl'
 assert deployed.read_bytes()==original,'Do not overwrite other deployed source'
 transport.write_bytes(candidate);deployed.write_bytes(candidate);print('Applied only failed cache output clear, retaining original source bytes elsewhere');raise SystemExit

def extract(text,pattern,struct=False):
 matches=list(re.finditer(pattern,text,re.M));assert len(matches)==1,(pattern,len(matches))
 start=matches[0].start();opening=text.index('{',start);depth=0
 for end in range(opening,len(text)):
  if text[end]=='{':depth+=1
  elif text[end]=='}':
   depth-=1
   if depth==0:return text[start:end+1]+(';' if struct else '')
 raise AssertionError('Unterminated source declaration')
def replace(text,a,b):
 assert text.count(a)==1,(a,text.count(a));return text.replace(a,b)

assert not (out/args.phase/'collection.json').exists(),'This phase already executed; do not overwrite or rerun saved evidence'
phase=out/('source-'+args.phase);phase.mkdir(parents=True,exist_ok=True)
head=subprocess.run(['git','rev-parse','HEAD'],capture_output=True,text=True,check=True).stdout.strip()
assert head.startswith('507e52d'),'Frozen baseline changed'
sources={name:(shader/name).read_text(encoding='utf-8') for name in ['HybridLumenGITransport.hlsl','HybridLumenGISurfaceCache.hlsl','HybridLumenGIEmissiveSampling.hlsl']}
if args.phase=='fixed':
 original=(out/'source-baseline/HybridLumenGITransport.hlsl').read_bytes()
 assert transport.read_bytes()==original.replace(old,new),'Unexpected Runtime edit beyond clear-on-false'
product_hashes={}
for source in (root/'Runtime').rglob('*'):
 if source.suffix not in ['.cs','.hlsl','.compute','.shader']:continue
 relative=source.relative_to(root);deployed=assets/'HybridLumenGI'/relative
 assert source.read_bytes()==deployed.read_bytes(),('Deployment mismatch',relative)
 product_hashes[str(relative)]=sha(source.read_bytes())
for name in sources:(phase/name).write_bytes((shader/name).read_bytes())
structures=[]
for name,source_name in [('HLGIProxy','HybridLumenGITransport.hlsl'),('HLGICacheEntry','HybridLumenGITransport.hlsl'),('HLGISurfaceCard','HybridLumenGISurfaceCache.hlsl'),('HLGISurfaceSample','HybridLumenGISurfaceCache.hlsl')]:
 structures.append(extract(sources[source_name],r'^struct '+name+r'\b',True))
declarations=[
 ('HybridLumenGITransport.hlsl',r'^HLGIRayFootprint HLGIPointQueryFootprint\('),
 ('HybridLumenGISurfaceCache.hlsl',r'^bool HLGISurfaceOwnerRange\('),
 ('HybridLumenGISurfaceCache.hlsl',r'^bool HLGISurfaceCardValid\('),
 ('HybridLumenGISurfaceCache.hlsl',r'^bool HLGISurfaceCardUv\('),
 ('HybridLumenGITransport.hlsl',r'^bool HLGIHitOwnerCurrent\('),
 ('HybridLumenGITransport.hlsl',r'^bool HLGICachedSurface\('),
 ('HybridLumenGITransport.hlsl',r'^bool HLGICachedSample\('),
 ('HybridLumenGITransport.hlsl',r'^float3 CachedIrradiance\('),
 ('HybridLumenGITransport.hlsl',r'^float3 ProxyRadiance\(HLGIHit hit,float3 incomingDirection,HLGIRayFootprint hitFootprint,float emissionWeight,'),
 ('HybridLumenGIEmissiveSampling.hlsl',r'^uint HLGIEmissiveProposalCount\('),
 ('HybridLumenGIEmissiveSampling.hlsl',r'^float HLGITransportDirectionPdf\(')]
original_functions=[];observed_functions=[]
for name,pattern in declarations:
 body=extract(sources[name],pattern);original_functions.append(body)
 if pattern==r'^bool HLGICachedSurface\(':
  body=replace(body,'    result=(HLGICacheEntry)0;','    observedWeight=observedTotal=0;observedAccepted=observedExit=observedQueries=0;observedCellFraction=0;\n    result=(HLGICacheEntry)0;')
  body=replace(body,'if(!HLGISurfaceCardUv(surface.cardIndex,position,uv)) return false;',
    'if(!HLGISurfaceCardUv(surface.cardIndex,position,uv)) { observedExit=1;return false; }')
  body=replace(body,'    float2 fraction=frac(patchPosition); float totalWeight=0;',
    '    float2 fraction=frac(patchPosition); float totalWeight=0;\n    observedCellFraction=float4(baseCell,fraction);')
  body=replace(body,'        totalWeight+=weight;result.irradiance+=e.irradiance*weight;result.guide+=e.guide*weight;',
    '        totalWeight+=weight;result.irradiance+=e.irradiance*weight;result.guide+=e.guide*weight;\n        observedWeight=weight;observedTotal=totalWeight;observedAccepted++;')
  target=old.decode() if args.phase=='baseline' else new.decode()
  # Keep the low-weight condition and source result assignment verbatim inside the observed branch.
  observed='if(totalWeight<=1e-5) { observedExit=2;'+(' result=(HLGICacheEntry)0;' if args.phase=='fixed' else '')+'return false; }'
  body=replace(body,target,observed);body=replace(body,'    return true;','    observedExit=3;return true;')
 observed_functions.append(body)
generated={'CacheFailedStructs.hlsl':'\n\n'.join(structures)+'\n','CacheFailedActualFunctions.hlsl':'\n\n'.join(observed_functions)+'\n'}
(phase/'functions.original.hlsl').write_text('\n\n'.join(original_functions)+'\n',encoding='utf-8')
for name,text in generated.items():(phase/name).write_text(text,encoding='utf-8')
helpers={'CacheFailedResult.compute':'ComparisonHarness/Resources/CacheFailedResult.compute','CacheFailedResultEditor.cs':'ComparisonHarness/Editor/CacheFailedResultEditor.cs'}
helper_hashes={}
for name,destination in helpers.items():
 data=(root/'LocalComparison/Harness'/name).read_bytes();helper_hashes[name]=sha(data)
 if args.phase=='fixed':assert data==(out/'source-baseline'/name).read_bytes(),('Helper inputs/adapter changed',name)
 (phase/name).write_bytes(data)
 if args.action=='install':
  target=assets/destination;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(data)
for name in generated:
 if args.action=='install':(assets/'ComparisonHarness/Resources'/name).write_bytes((phase/name).read_bytes())
manifest={'baseline':head,'phase':args.phase,'productSourceSha256':product_hashes,'helperSha256':helper_hashes,'generatedSha256':{name:sha((phase/name).read_bytes()) for name in generated},
 'actualFunctions':[pattern for _,pattern in declarations],'scope':'Actual-source functions; explicit material, clear visibility, direct-light and disabled-emissive dependency adapters. Unity function contract test, not traversal/atlas/whole-image acceptance.'}
(phase/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
(phase/'installer.executed.py.txt').write_bytes(Path(__file__).read_bytes())
print(json.dumps({'action':args.action,'phase':args.phase,'actualFunctions':len(declarations),'productFiles':len(product_hashes),'RuntimeCandidate':args.phase=='fixed'}))
