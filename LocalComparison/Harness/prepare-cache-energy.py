"""Extract actual update chain and freeze deployed inputs before the single run."""
import argparse,hashlib,json,re,subprocess
from pathlib import Path
root=Path(__file__).resolve().parents[2];assets=Path('I:/Unity test/Project/Assets')
shader=root/'Runtime/Resources/HybridLumenGI';out=root/'LocalComparison/Review/cache-energy-decay-reference-01'
p=argparse.ArgumentParser();p.add_argument('action',choices=['prepare','install']);args=p.parse_args()
assert not (out/'execution.json').exists(),'Do not overwrite completed run'
assert (out/'reference.json').exists(),'Predeclared reference required'
phase=out/'source';phase.mkdir(parents=True,exist_ok=True)
sha=lambda b:hashlib.sha256(b).hexdigest()
head=subprocess.run(['git','rev-parse','HEAD'],capture_output=True,text=True,check=True).stdout.strip()
assert head.startswith('1b8e751'),'Frozen baseline changed'
sources={n:(shader/n).read_text(encoding='utf-8') for n in ['HybridLumenGITransport.hlsl','HybridLumenGISurfaceCache.hlsl']}
def extract(text,pattern,struct=False):
    matches=list(re.finditer(pattern,text,re.M));assert len(matches)==1,(pattern,len(matches))
    start=matches[0].start();opening=text.index('{',start);depth=0
    for end in range(opening,len(text)):
        if text[end]=='{':depth+=1
        elif text[end]=='}':
            depth-=1
            if depth==0:return text[start:end+1]+(';' if struct else '')
    raise AssertionError(pattern)
def replace(text,a,b):
    assert text.count(a)==1,(a,text.count(a));return text.replace(a,b)
structures=[]
for n,src in [('HLGIProxy','Transport'),('HLGILight','Transport'),('HLGICacheEntry','Transport'),('HLGISurfaceCard','SurfaceCache'),('HLGISurfaceSample','SurfaceCache')]:
    structures.append(extract(sources['HybridLumenGI'+src+'.hlsl'],r'^struct '+n+r'\b',True))
sampling=[]
for n in ['HLGIHash','Random','CosineHemisphere','HLGISampleDirection']:
    sampling.append(extract(sources['HybridLumenGITransport.hlsl'],r'^(?:uint|float|float3) '+n+r'\('))
declarations=[('SurfaceCache',n) for n in ['HLGISurfaceAtlasRect','HLGISurfaceOwnerRange','HLGISurfaceCardValid','HLGISurfaceCardUv']]
declarations += [('Transport',n) for n in ['HLGIPointQueryFootprint','HLGIHitOwnerCurrent','HLGICachedSurface',
    'DirectIrradiance','ProxyRadiance','HLGIAreaDirectionEmissionWeight','HLGIAreaMatchedDirectionWeight',
    'HLGIAreaLightContribution','HLGITrySurfacePatchRayFootprint','CSUpdateCache']]
original=[];observed=[]
for src,n in declarations:
    pattern=r'^(?:bool|void|float3|HLGIRayFootprint) '+n+r'\('
    if n=='DirectIrradiance':pattern+=r'float3 p,float3 n,float3 biasNormal,uint2 receiverLayers,bool receivesShadows,\s*$'
    if n=='ProxyRadiance':pattern+=r'HLGIHit hit,float3 incomingDirection,HLGIRayFootprint hitFootprint,float emissionWeight,'
    body=extract(sources['HybridLumenGI'+src+'.hlsl'],pattern);original.append(body)
    if n=='ProxyRadiance':
        body=replace(body,'        HLGICachedSurface((int)hit.ownerSlot,hit.position,queryNg,shadingNormal,surface,cached);',
            '        bool lookupKnown=HLGICachedSurface((int)hit.ownerSlot,hit.position,queryNg,shadingNormal,surface,cached);\n        observed.lookupIrradiance=cached.irradiance;observed.lookupGuide=cached.guide;\n        observed.lookupState=float4(lookupKnown,hit.ownerSlot,hit.stableId,surface.generation);')
        body=replace(body,'    if(!directKnown ||', '    observed.direct=float4(direct,directKnown);\n    if(!directKnown ||')
    if n=='CSUpdateCache':
        body=replace(body,'    uint card=id.x/patches,local=id.x%patches;',
            '    observed=(EnergyObservation)0;activeNode=id.x;\n    observed.dispatch=float4(_HLGI_FrameIndex,id.x,_ReadIdentity,_WriteIdentity);\n    observed.source=_HLGI_Lights[0].color;observed.configuration.xyz=float3(_HLGI_GuideWeight,_HLGI_EmissiveWeight,_HLGI_AreaEmitterCount);\n    uint card=id.x/patches,local=id.x%patches;')
        body=replace(body,'    if(!covered) { _HLGI_CacheWrite[id.x]=(HLGICacheEntry)0;return; }',
            '    observed.status.w=covered;\n    if(!covered) { _HLGI_CacheWrite[id.x]=(HLGICacheEntry)0;_EnergyOutput[id.x]=observed;return; }')
        body=replace(body,'    HLGICacheEntry e=_HLGI_CacheRead[id.x];','    HLGICacheEntry e=_HLGI_CacheRead[id.x];observed.oldEntry=e;')
        body=replace(body,'    float2 change=HLGIChangeAt(surface.position);','    float2 change=HLGIChangeAt(surface.position);observed.change=float4(change,_HLGI_GlobalGeometryChange,_HLGI_ChangeCount);')
        body=replace(body,'    if(_HLGI_CacheUpdateMask[id.x]!=0)',
            '    observed.preparedIrradiance=e.irradiance;observed.preparedGuide=e.guide;observed.status.z=_HLGI_CacheUpdateMask[id.x];\n    if(_HLGI_CacheUpdateMask[id.x]!=0)')
        body=replace(body,'            if(!HLGIAreaMatchedDirectionWeight', '            observed.directionWeight=float4(direction,weight);\n            if(!HLGIAreaMatchedDirectionWeight')
        body=replace(body,'            if(!HLGIAccumulateRadianceSample(incoming,materialConfidence,weight,sum))',
            '            observed.incoming=float4(incoming,materialConfidence);\n            if(!HLGIAccumulateRadianceSample(incoming,materialConfidence,weight,sum))')
        body=replace(body,'        HLGICommitCacheEstimate(estimateKnown,sum,guide,guidePower,_HLGI_CacheRays,n,e.irradiance,e.guide);',
            '        observed.status.x=estimateKnown;observed.estimate=float4(sum,guidePower);\n        HLGICommitCacheEstimate(estimateKnown,sum,guide,guidePower,_HLGI_CacheRays,n,e.irradiance,e.guide);')
        body=replace(body,'    _HLGI_CacheWrite[id.x]=e;',
            '    _HLGI_CacheWrite[id.x]=e;observed.newEntry=e;observed.status.y=HLGIHasCacheMeasurement(e.irradiance,e.guide);_EnergyOutput[id.x]=observed;')
        body='[numthreads(64,1,1)]\n'+body
    observed.append(body)
generated={'CacheEnergyStructs.hlsl':'\n\n'.join(structures)+'\n','CacheEnergySampling.hlsl':'\n\n'.join(sampling)+'\n',
    'CacheEnergyActualFunctions.hlsl':'\n\n'.join(observed)+'\n'}
(phase/'functions.original.hlsl').write_text('\n\n'.join(original)+'\n',encoding='utf-8')
for name,text in generated.items():(phase/name).write_text(text,encoding='utf-8')
product={}
for source in (root/'Runtime').rglob('*'):
    if source.suffix not in ['.cs','.hlsl','.compute','.shader']:continue
    relative=source.relative_to(root);assert source.read_bytes()==(assets/'HybridLumenGI'/relative).read_bytes(),str(relative)
    product[str(relative)]=sha(source.read_bytes())
for source in shader.glob('*.hlsl'):(phase/source.name).write_bytes(source.read_bytes())
helpers={'CacheEnergyDecay.compute':'ComparisonHarness/Resources/CacheEnergyDecay.compute','CacheEnergyDecayEditor.cs':'ComparisonHarness/Editor/CacheEnergyDecayEditor.cs'}
helper_hashes={}
for name,destination in helpers.items():
    data=(root/'LocalComparison/Harness'/name).read_bytes();helper_hashes[name]=sha(data);(phase/name).write_bytes(data)
    if args.action=='install':(assets/destination).write_bytes(data)
if args.action=='install':
    for name in generated:(assets/'ComparisonHarness/Resources'/name).write_bytes((phase/name).read_bytes())
manifest={'baseline':head,'referenceSha256':sha((out/'reference.json').read_bytes()),'productSourceSha256':product,
    'helperSha256':helper_hashes,'generatedSha256':{name:sha((phase/name).read_bytes()) for name in generated},
    'extractedFunctions':declarations,'samplingFunctions':['HLGIHash','Random','CosineHemisphere','HLGISampleDirection'],
    'includedActualHeaders':['Core','Hit','RadianceValidity','RayFootprint','LightingPolicy','Changes','EmissiveSampling','AreaEmission'],
    'adapters':['fixed two-patch material','every positive cosine sample maps to paired hit','zero-length anchor visibility unreachable','zero shadow-strength visibility unreachable'],
    'scope':'Actual CSUpdateCache/update/lookup/direct/feedback/mix/changes with ideal environment; no real geometry or atlas capture.'}
(phase/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
(phase/'installer.executed.py.txt').write_bytes(Path(__file__).read_bytes())
print(json.dumps({'action':args.action,'actualExtractedFunctions':len(declarations)+len(sampling),'productFiles':len(product),'referenceSha256':manifest['referenceSha256']}))
