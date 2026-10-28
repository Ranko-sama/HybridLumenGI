"""Freeze the existing detail group; no export, engine launch or asset substitution."""
import hashlib,json,re,shutil
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]; PROJECT=Path('I:/Unity test/Project')
PACKAGE=ROOT/'LocalComparison/Review/asset-page-inflight-withdrawal-01'
manifest=PROJECT/'Assets/HybridLumenGIAssetPages/e69c995bf3214dfa9ab611e9dd9b20a3/Manifest.asset'
scene=PROJECT/'Assets/RuntimeAudit/Streaming.unity'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def field(s,k):return re.search(r'^\s+'+k+r': (.+)$',s,re.M).group(1).strip()
text=manifest.read_text(encoding='utf-8'); platform=field(text,'targetPlatform');relative=field(text,'relativeRoot')
assert platform=='StandaloneWindows64'
pages=[]
for chunk in text.split('  - id: ')[1:]:
    page={'id':chunk.splitlines()[0]}
    for k in ['bundlePath','assetName']:page[k]=field(chunk,k)
    for k in ['kind','crc','fileBytes','residentBytes','uploadBytes']:page[k]=int(field(chunk,k))
    page['dependencies']=re.findall(r'^    - (.+)$',chunk,re.M);pages.append(page)
scenetext=scene.read_text(encoding='utf-8');block=re.search(r'--- !u!114 &132881543\n(.*?)(?=--- !u!)',scenetext,re.S).group(1)
group=[field(block,k) for k in ['geometryPage','sdfPage','chartPage']]+re.findall(r'^  - (material-.+)$',block,re.M)
byid={p['id']:p for p in pages};closure=set()
def visit(id):
    assert id in byid
    if id in closure:return
    closure.add(id)
    for dependency in byid[id]['dependencies']:visit(dependency)
for id in group:visit(id)
assert len(pages)==len(closure)==6 and len(group)==4
budget={'ioBytesPerStep':max(p['fileBytes'] for p in pages),'maxIoBytesInFlight':max(p['fileBytes'] for p in pages),
        'maxBundleBytes':sum(p['fileBytes'] for p in pages),'maxResidentBytes':sum(p['residentBytes'] for p in pages),
        'uploadBytesPerStep':max(p['uploadBytes'] for p in pages),'concurrentOperations':1,'startsPerStep':1}
assert not (PACKAGE/'input.json').exists(),'Inputs already frozen'
PACKAGE.mkdir(parents=True,exist_ok=True); files=[]
for path in [manifest,scene]+[PROJECT/'Assets/StreamingAssets'/relative/p['bundlePath'] for p in pages]:
    rel=path.relative_to(PROJECT).as_posix();dest=PACKAGE/'input'/rel;dest.parent.mkdir(parents=True,exist_ok=True)
    shutil.copyfile(path,dest);files.append({'path':rel,'archive':dest.relative_to(PACKAGE).as_posix(),'bytes':path.stat().st_size,'sha256':sha(path)})
for p in pages:
    path=PROJECT/'Assets/StreamingAssets'/relative/p['bundlePath'];assert path.stat().st_size==p['fileBytes'];p['sha256']=sha(path)
result={'scene':scene.relative_to(PROJECT).as_posix(),'detailFileId':132881543,'manifest':manifest.relative_to(PROJECT).as_posix(),
        'platform':platform,'relativeRoot':relative,'groupIds':group,'pages':pages,'budgets':budget,'files':files,
        'crcValidation':'Manifest CRC frozen; actual BuildPipeline CRC verification occurs in the unique build; runtime passes CRC to LoadFromFileAsync.'}
(PACKAGE/'input.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'inputClosureVerified':True,'pages':len(pages),'budgets':budget,'files':len(files)}))
