"""A single frozen old control, then one candidate; no native/GPU execution."""
import hashlib,json,re,shutil,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'LocalComparison/Review/surface-cache-failed-render-recovery-01';FROZEN=OUT/'frozen'
PRODUCT=['Runtime/HybridLumenGISurfaceCache.cs','Runtime/HybridLumenGIMaterialSource.cs','Runtime/HybridLumenGIHitMaterialData.cs','Runtime/HybridLumenGIRendererFeature.cs']
COMMON=['Tests/StandaloneSurfaceCache/UnityStubs.cs.txt','Tests/StandaloneSurfaceCache/Program.cs.txt','Tests/StandaloneSurfaceCache/FailureRecovery.cs.txt','Documentation/Checkpoint-Iteration61.md','LocalComparison/Harness/run-surface-cache-recovery.py']
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def save(p,v):p.write_text(json.dumps(v,indent=2)+'\n',encoding='utf-8')
phase=sys.argv[1]
if phase=='freeze':
    FROZEN.mkdir(parents=True,exist_ok=False)
    for rel in COMMON+PRODUCT:
        dest=FROZEN/rel;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(ROOT/rel,dest)
    save(OUT/'manifest.json',{'base':'3f9cd729b9498d83e7671fda989a2286980d0dec','files':{rel:sha(FROZEN/rel) for rel in COMMON+PRODUCT}})
    print('Frozen common inputs and old product before any behavior.');sys.exit(0)
assert phase in ('baseline','candidate')
m=json.loads((OUT/'manifest.json').read_text(encoding='utf-8'))
for rel,digest in m['files'].items():assert sha(FROZEN/rel)==digest,rel
for rel in COMMON+PRODUCT[1:3]:assert sha(ROOT/rel)==m['files'][rel],rel
if phase=='baseline':
    for rel in PRODUCT:assert sha(ROOT/rel)==m['files'][rel],rel
run=OUT/phase;run.mkdir(exist_ok=False);src=run/'source';src.mkdir()
for rel in PRODUCT:shutil.copyfile(ROOT/rel,src/Path(rel).name)
shutil.copyfile(FROZEN/COMMON[0],src/'UnityStubs.cs');shutil.copyfile(FROZEN/COMMON[2],src/'FailureRecovery.cs')
legacy=(FROZEN/COMMON[1]).read_text(encoding='utf-8');assert legacy.count('static int Main()')==1
(src/'Fixtures.cs').write_text(legacy.replace('static int Main()','static int UnusedBroadMatrix()'),encoding='utf-8')
feature=(src/'HybridLumenGIRendererFeature.cs').read_text(encoding='utf-8');method=re.search(r'        internal void InvalidateFailedRender\(\)\s*\{[^{}]*\}',feature).group(0)
(run/'actual-failure-method.txt').write_text(method,encoding='utf-8')
(src/'ActualFailureState.cs').write_text('''using HybridLumenGI;
sealed class SdfCounter { internal int calls; internal void InvalidateAll(){calls++;} }
sealed class ActualFailureState {
 internal readonly HybridLumenGISurfaceCache surfaceCache;
 internal readonly SdfCounter globalSdf=new SdfCounter();
 internal ulong uploadedSoftwareVersion=9;internal int historyCalls,feedbackCalls;
 internal ActualFailureState(HybridLumenGISurfaceCache cache){surfaceCache=cache;}
 internal void InvalidateScreenHistory(){historyCalls++;} internal void InvalidateGpuFeedback(){feedbackCalls++;}
'''+method+'\n}\n',encoding='utf-8')
save(run/'source-manifest.json',{'products':{rel:sha(ROOT/rel) for rel in PRODUCT},'generated':{p.name:sha(p) for p in src.iterdir() if p.is_file()},'fixtureAdaptation':'Only rename the unused broad Main; use its existing private Proxy/Config/Capture helpers via reflection.','failureAdaptation':'Exact common method, with actual SurfaceCache; unrelated SDF/history/feedback counter adapters.'})
(src/'Check.csproj').write_text('<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><OutputType>Exe</OutputType><TargetFramework>net8.0</TargetFramework><ImplicitUsings>disable</ImplicitUsings><Nullable>disable</Nullable><NuGetAudit>false</NuGetAudit></PropertyGroup><ItemGroup><Compile Remove="HybridLumenGIRendererFeature.cs" /></ItemGroup></Project>',encoding='utf-8')
(src/'NuGet.Config').write_text('<configuration><packageSources><clear /></packageSources></configuration>',encoding='utf-8')
command=['dotnet','run','--project',str(src/'Check.csproj'),'--configuration','Release','--verbosity','quiet','--']
if phase=='candidate':command+=['--expect-recovery']
result=subprocess.run(command,cwd=ROOT,capture_output=True,text=True,encoding='utf-8',errors='replace')
(run/'execution.log').write_text(result.stdout+result.stderr,encoding='utf-8');save(run/'execution.json',{'command':command,'exitCode':result.returncode})
print(phase+' actual-source exit='+str(result.returncode))
if result.returncode:print(result.stdout+result.stderr);sys.exit(result.returncode)
rows=[json.loads(line) for line in result.stdout.splitlines() if line.startswith('{"path":')];assert len(rows)==2
save(run/'result.json',rows)
if phase=='candidate':
    baseline=json.loads((OUT/'baseline/result.json').read_text(encoding='utf-8'));assert rows[0]==baseline[0],'Successful branch changed'
    save(run/'qualification.json',{'normalBranchByteIdentical':True,'failureRecaptures':rows[1]['captures'],'nativeGpuExecution':False,'wholeFeatureExecution':False,'commonFailureMethodExtractedVerbatim':True})
print(json.dumps({'branchCaptures':[r['captures'] for r in rows],'oldCounterexample':rows[1]['productCounterexample'],'nativeRuns':0}))
