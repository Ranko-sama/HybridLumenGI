"""Frozen-source and fixture identity gate; does not invoke Unity or tests."""
import base64,hashlib,json,re
from pathlib import Path
PACKAGE=Path(__file__).resolve().parent;ROOT=PACKAGE.parents[2];OLD=PACKAGE.parent/'world-light-relevance-01'
PROJECT=Path('I:/Unity test/Project')
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
load=lambda p:json.loads(p.read_text(encoding='utf-8-sig'))
old=load(OLD/'instrumentation/manifest.json');new=load(PACKAGE/'instrumentation/manifest.json')
assert old['productSourceSha256'].keys()==new['productSourceSha256'].keys()
differences=[p for p,h in new['productSourceSha256'].items() if h!=old['productSourceSha256'][p]]
assert differences==['Runtime/HybridLumenGILightRelevance.cs'],differences
assert new['productSourceSha256'][differences[0]]=='2b91f9485cf6b08006add5471946d6396a8f08e3a4128274164b7c10339a9cbe'
assert all(sha(ROOT/p)==h and sha(PROJECT/'Assets/HybridLumenGI'/p)==h for p,h in new['productSourceSha256'].items())
assert {f['path']:f['sha256'] for f in old['files']}=={f['path']:f['sha256'] for f in new['files']},'Native fixture or hook changed'
assert all(sha(PACKAGE/'instrumentation'/f['prepared'])==f['sha256'] for f in new['files'])
dependencies=[i for i in load(OLD/'build-report.json')['inputs'] if not i['path'].startswith(('Assets/HybridLumenGI/','Assets/ComparisonHarness/'))]
resolved={};lock=load(PROJECT/'Packages/packages-lock.json')['dependencies']
def resolve(path):
    direct=PROJECT/path
    if direct.is_file():return direct
    parts=Path(path).parts
    assert len(parts)>2 and parts[0]=='Packages','Missing ordinary dependency: '+path
    # Unity presents package aliases in its build receipt. Resolve the real cache,
    # require the locked package identity/version, then still compare exact bytes.
    matches=[]
    for folder in (PROJECT/'Library/PackageCache').glob(parts[1]+'*'):
        manifest=folder/'package.json'
        if manifest.is_file():
            identity=load(manifest)
            if identity.get('name')==parts[1] and identity.get('version')==lock[parts[1]]['version']:matches.append(folder)
    assert len(matches)==1,'Ambiguous/missing locked package: '+path
    actual=matches[0].joinpath(*parts[2:]);assert actual.is_file(),path
    resolved[path]=actual.relative_to(PROJECT).as_posix();return actual
assert all(sha(resolve(i['path']))==i['sha256'] for i in dependencies),'Scene/dependency/settings input drift'
products=load(OLD/'build-products.json');build=Path(products['root'])
assert all(sha(build/f['path'])==f['sha256'] for f in products['files']),'Old failed EXE/product changed'
assert {f['path'] for f in products['files']}=={p.relative_to(build).as_posix() for p in build.rglob('*') if p.is_file()}
saved=PACKAGE/'saved-native-input.json';assert sha(saved)=='97480fce13986d076a3c3ee386ca6c09f333d0ae4005cf3a85db6910c07df0d3'
expected=hashlib.sha256(base64.b64decode(load(saved)['sources'][2]['packedBase64'])).hexdigest()
output=(PACKAGE/'replay-command.log').read_text(encoding='utf-8-sig')
actual=re.search(r'TABLE saved-native-input: count=1; hash=-?\d+; sha256=([0-9A-F]+)',output).group(1).lower()
assert actual==expected,'Actual-source replay active bytes differ from saved native packed record'
assert not (PACKAGE/'build-attempt.json').exists() and not (PACKAGE/'native-window/attempt.json').exists()
sources={p:sha(ROOT/p) for p in ['Tests/StandaloneLighting/Program.cs.txt','Tests/StandaloneLighting/UnityStubs.cs.txt','Tests/Validate-Lighting.ps1','Runtime/HybridLumenGILights.cs','Runtime/HybridLumenGILightRelevance.cs']}
for p in sources:
    target=PACKAGE/'replay-source'/p;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes((ROOT/p).read_bytes())
result={'productDifferencesFromNative01':differences,'productSourceCount':len(new['productSourceSha256']),
    'unchangedPreparedFixtureFiles':len(new['files']),'unchangedDependencyFiles':len(dependencies),
    'oldProductFileCount':len(products['files']),'oldProductSetPreserved':True,'nativeInputSha256':sha(saved),
    'resolvedLockedPackagePaths':resolved,
    'replayActivePrefixSha256':actual,'replaySources':sources,'native02Executed':False,
    'fixtureLabel':'world-light-relevance-01 intentionally unchanged because complete native observer bytes are reused; independent02 package/attempt/build paths identify this execution'}
(PACKAGE/'preflight.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
print(json.dumps(result))
