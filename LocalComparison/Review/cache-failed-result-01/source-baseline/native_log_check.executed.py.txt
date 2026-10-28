"""Shared native Unity log signatures; generic aggregate statistics are not failures."""
import argparse,json,re
from pathlib import Path
PATTERNS={
 'native-allocation':r'A Native Collection has not been disposed|leaked allocation|leak\(s\) from callstack:|Leak Detected|Found \d+ leak\(s\)',
 'd3d-unreleased':r'Unreleased non-evictable',
 'unresolved-owner':r'retained unresolved retirement|separate owners remain|retirement[^\r\n]*(?:unresolved|timed out|owned=)',
 'device-error':r'DXGI_ERROR_DEVICE_[A-Z_]+|Device (?:removed|lost)',
 'compile':r'error CS\d+|Shader error|Invalid kernel|Kernel at index .* is invalid|Compute shader .* (?:invalid|failed)',
 'runtime-reference':r'NullReferenceException|MissingReferenceException',
 'readback':r'readback (?:failed|shutdown failed)|readback[^\r\n]*(?:mismatch|unproven)',
 'observer':r'RESOURCE_TRACE_WRITE_FAILED|RETIREMENT_PROGRESS_OBSERVER_FAILED|CACHE_FAILED_RESULT_OBSERVER_FAILED|Comparison failed:|Gather (?:observer|stream|event|source|raw)[^\r\n]*(?:failed|mismatch|missing|overflow)',
}
def scan(path):
 hits=[]
 for number,line in enumerate(Path(path).read_text(encoding='utf-8').splitlines(),1):
  for category,pattern in PATTERNS.items():
   if re.search(pattern,line,re.I):hits.append({'category':category,'line':number,'text':line})
 return hits
def self_check(root):
 cases=[('gather-cache-visibility-01/Unity-A.log',False),('thin-wall-transport-01/retry-v4/B-Unity.log',False),
        ('thin-wall-transport-01/retry-v3/A-Unity.log',True),('thin-wall-transport-01/compile-failure/Unity.log',True),
        ('thin-wall-transport-01/observer-failed/Unity.log',True)]
 results=[]
 for relative,expected in cases:
  hits=scan(root/'LocalComparison/Review'/relative)
  results.append({'path':relative,'expectedFailure':expected,'actualFailure':bool(hits),'pass':bool(hits)==expected,'hits':hits})
 # Guards for prior critical spellings absent from an otherwise passing saved log.
 signatures={name:bool(re.search(PATTERNS[category],text,re.I)) for name,category,text in [
  ('d3d-retained','d3d-unreleased','[d3d12] Unreleased non-evictable resource'),
  ('child-owner','unresolved-owner','separate owners remain'),
  ('device-removed','device-error','DXGI_ERROR_DEVICE_REMOVED'),
  ('device-hung','device-error','DXGI_ERROR_DEVICE_HUNG'),
  ('device-reset','device-error','DXGI_ERROR_DEVICE_RESET'),
  ('cache-fixture','observer','CACHE_FAILED_RESULT_OBSERVER_FAILED')]}
 return {'passed':all(v['pass'] for v in results) and all(signatures.values()),'savedLogCases':results,'criticalSpellingGuards':signatures,
   'scope':'Offline scan of existing native logs only; no new Unity execution; no whole-process leak inference.'}
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('log',nargs='?',type=Path);p.add_argument('--self-check',action='store_true');p.add_argument('--output',type=Path,required=True);a=p.parse_args()
 root=Path(__file__).resolve().parents[2]
 result=self_check(root) if a.self_check else {'passed':not (hits:=scan(a.log)),'hits':hits}
 a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(json.dumps(result,indent=2),encoding='utf-8')
 print(json.dumps({'passed':result['passed'],'savedLogs':len(result.get('savedLogCases',[])),'criticalSpellingGuards':result.get('criticalSpellingGuards',{})}));raise SystemExit(0 if result['passed'] else 1)
