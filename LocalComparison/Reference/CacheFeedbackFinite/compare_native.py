"""Construct the independent finite expectation, then open separate observations."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import struct

import atlas_support
import finite_reference
import numeric_reference as numeric
import screen_input_qualification as screen

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]


def load(path):return json.loads(path.read_text(encoding='utf-8-sig'))
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def vector(value,fields='xyz'):return [value[k] for k in fields]
def require(value,message):
    if not value:raise AssertionError(message)


def equal(actual,expected,label):
    if isinstance(expected,(list,tuple)):
        require(len(actual)==len(expected),label)
        for a,e in zip(actual,expected):equal(a,e,label)
    elif isinstance(expected,(bool,str,int)):require(actual==expected,label)
    else:require(math.isfinite(actual) and numeric.f32(actual)==numeric.f32(expected),label)


def validate_scene(inputs,result,receipts,source,frames):
    finite_reference.validate_source(source)
    require(source['light']['warmupEnabled'] is False and source['light']['warmupIntensity']==1,'Source warmup must be disabled, unit intensity')
    geometry={
        'wall':([[0,0,0],[0,1,0],[0,1,1],[0,0,1]],[1,0,0],[.5,.25,.125,1]),
        'floor':([[0,0,0],[1,0,0],[1,1,0],[0,1,0]],[0,0,1],[.125,.5,.25,1])}
    for name,(vertices,normal,color) in geometry.items():
        surface=inputs[name]
        equal(surface['shader'],'Universal Render Pipeline/Lit',name+' shader')
        equal([vector(v) for v in surface['vertices']],vertices,name+' finite vertices')
        equal([vector(v) for v in surface['normals']],[normal]*4,name+' committed constant normals')
        equal(surface['triangles'],[0,1,2,0,2,3],name+' committed winding')
        for row in range(4):
            for col in range(4):equal(surface['localToWorld']['e%d%d'%(row,col)],int(row==col),name+' identity transform')
        equal(vector(surface['shaderLinearBaseColor'],'xyzw'),color,name+' shader-linear MPB')
        equal(vector(surface['materialBaseColor'],'rgba'),[1,1,1,1],name+' material tint')
        equal(vector(surface['proxyTint'],'rgb'),[1,1,1],name+' proxy tint')
        for field in ('materialEmission','proxyEmission'):equal(vector(surface[field],'rgb'),[0,0,0],name+' emission')
        equal(surface['metallic'],0,name+' metallic');equal(surface['occlusionStrength'],1,name+' AO')
        for field in ('normalMap','baseMap','emissionMap','occlusionMap','emissionKeyword','receiveShadows','parallaxMap','detailAlbedoMap','detailNormalMap','detailMask','parallaxKeyword','detailMulKeyword','detailScaledKeyword','normalKeyword','specularKeyword'):
            equal(surface[field],False,name+' '+field)
    light=inputs['light']
    for field,expected in dict(type='Directional',shadows='None',intensity=1,enabled=False,useColorTemperature=False).items():equal(light[field],expected,'light '+field)
    equal(vector(light['color'],'rgb'),[1,1,1],'light white');equal(vector(light['toLight']),[1,0,0],'exact directional vector')
    settings=inputs['settings']
    for key,expected in dict(resolutionScale=1,raysPerPixel=8,traceDistance=20,rayBias=.03,screenSteps=0,
        bounceFeedback=1,cachePatchGrid=1,cacheRaysPerFace=16,surfaceTileResolution=32,cachePatchesPerFrame=256,
        guidedSamplingWeight=0,emissiveSamplingWeight=0,maxAreaEmitterTriangles=0,maxEmissiveProposals=0,
        temporalAccumulation=False,maxHistory=1,filterIterations=0,radianceClamp=0,maxLights=1,spatialLightSelection=False,
        preferHardwareTracing=True,exactSoftwareTracing=True,globalSdfEnabled=False,adaptiveGpuBudget=False).items():equal(settings[key],expected,'settings '+key)
    equal(vector(settings['environmentRadiance'],'rgb'),[0,0,0],'zero environment')
    require(settings.get('environmentCubemap') in (None,{'instanceID':0}),'Unexpected environment cube')
    require(result['status']=='collected' and not result.get('error') and result['readbacksDrained'] and result['lightOnEventApplied'],'Native capture incomplete')
    require(result['api']=='Direct3D12' and result['targetCreated'] and result['renderRequestSupported'],'Wrong native backend')
    require(not result['cameraEnabled'] and result['cameraActive'] and result['cameraBase'],'Wrong capture camera')
    require(all(result[key]==34 for key in ('requests','cameraBegins','cameraEnds','contextBegins','contextEnds')) and result['previewCaptures']==2,'Fixed 32+2 camera schedule differs')
    require(len(frames)==34,'Fixed frame receipts incomplete')
    for logical in (31,32,33):
        frame=frames[logical];receipt=receipts[logical-31];diagnostic=frame['diagnostics']
        require(frame['ready'] and frame['request']==frame['cameraFrames']==logical+1,'Fixed warmup did not qualify')
        require(diagnostic['frame']==receipt['workFrame']+1 and frame['engineFrame']==receipt['engineFrame'],'Actual Work frame correspondence differs')
        require(diagnostic['hardwareBackend'] and diagnostic['hardwareMeshes']==2 and diagnostic['hardwareFallbacks']==0,'Native triangle backend is not complete')
        for key,expected in dict(hardwareMaterialUnknownRecords=0,publishedInstances=2,warmingInstances=0,pendingCapacity=0,chartedOwners=2,approximateOwners=0,readyCards=2,pendingCards=0,cachePatchesScheduled=2,lightSelected=0 if logical==31 else 1,lightCapacityOmitted=-1).items():equal(diagnostic[key],expected,'diagnostic '+key)
        equal(diagnostic['hardwareMaterialStatus'],'Uploads and both consumers bound; GPU completion unproven','hardware identity status')
        equal(receipt['normalsOct'],settings['normalsOctEncoded'],'actual normal decode')
        require(receipt['complete'] and all(receipt[k] for k in ('beforeRecorded','afterRecorded','gatherRecorded')) and not receipt.get('error'),'GPU capture boundary incomplete')
        equal(receipt['rawFormat'],'R16G16B16A16_SFloat','raw half storage')
    require(result['targetWorkFrame']==receipts[-1]['workFrame'] and result['selectedDiagnostics']==frames[-1]['diagnostics'],'Final selected frame differs')
    return dict(actualGeometryMaterialsAndExactLight=True,fixedWarmupFrames=32,positiveUpdates=2,workFrames=[r['workFrame'] for r in receipts],
                missingRuntimeFields='Workflow, smoothness, no extra maps/keywords and zero ambient are fixed by the hash-matched temporary Editor/Host source; actual submitted vertex normals/identity transform and capture sources justify finite constant material inputs.')


def validate_sources(package):
    stage=package/'instrumentation';manifest=load(stage/'manifest.json');frozen=load(stage/'reference-source.json')
    for name,digest in frozen.items():require(sha(ROOT/name)==digest,'Reference changed after pre-native freeze: '+name)
    require((package/'source-contract.json').read_bytes()==(HERE/'source-contract.json').read_bytes(),'Staged reference contract differs')
    inventory={p.relative_to(ROOT).as_posix() for top in ('Runtime','Editor') for p in (ROOT/top).rglob('*') if p.is_file() and p.suffix!='.meta'}
    require(inventory==set(manifest['productSourceSha256']),'Product source inventory differs')
    for name,digest in manifest['productSourceSha256'].items():require(sha(ROOT/name)==digest,'Product changed from native package: '+name)
    generated=load(HERE/'generated/manifest.json')
    for name,digest in generated['sourceSha256'].items():require(sha(ROOT/name)==digest==manifest['productSourceSha256'][name],'Input extractor source differs')
    for name,digest in generated['generatedSha256'].items():require(sha(HERE/'generated'/name)==digest,'Generated sampler changed')
    require(generated['templateSha256']==sha(HERE/'native_sampler.template.compute'),'Sampler template changed')
    require(len(generated['compile'])==4 and all(row['exitCode']==0 for row in generated['compile']),'Input sampler compile incomplete')
    require(b'#pragma use_dxc' in (HERE/'generated/CacheFeedbackFiniteInputs.compute').read_bytes(),'Metadata requires DXC for nine UAVs')
    harness={'CacheFeedbackFiniteScene.cs','CacheFeedbackFiniteTap.cs','CacheFeedbackFiniteEditor.cs'}
    names=harness|{'HybridLumenGIRendererFeature.cs','CacheFeedbackFiniteInputs.compute','ReferenceInputFunctions.hlsl','ReferenceRecords.hlsl','ReferenceHit.hlsl','ReferenceScreenSampling.hlsl'}
    require(len(manifest['files'])==9 and {Path(r['path']).name for r in manifest['files']}==names,'Unexpected instrumentation')
    for row in manifest['files']:
        path=stage/row['prepared'];name=Path(row['path']).name;require(sha(path)==row['sha256'],'Prepared source changed')
        if name in harness:require(sha(ROOT/'LocalComparison/Harness'/name)==row['sha256'],'Harness changed')
        elif name in generated['generatedSha256']:require(generated['generatedSha256'][name]==row['sha256'],'Staged sampler differs')
        else:
            original=(ROOT/'Runtime/HybridLumenGIRendererFeature.cs').read_bytes();modified=path.read_bytes()
            lines=modified.splitlines(keepends=True);hooks=[line for line in lines if b'global::CacheFeedbackFiniteTap.Record' in line]
            require(len(hooks)==3 and all(sum(needle in line for line in hooks)==1 for needle in (b'.RecordBeforeUpdate(',b'.RecordAfterUpdate(',b'.RecordGather(')),'Observer hook boundary count differs')
            require(b''.join(line for line in lines if line not in hooks)==original,'Observer modified product beyond the three capture calls')
    return dict(productFileCount=len(inventory),observerFileCount=9,referenceSourceSha256=frozen,
                manifestSha256=sha(stage/'manifest.json'),samplerManifestSha256=sha(HERE/'generated/manifest.json'))


def cache_entries(data,receipt):
    require(len(data)==receipt['cacheEntryCount']*80,'Cache observation shape differs')
    return list(struct.iter_unpack('<20f',data))


def validate_cache_geometry(entry,patch,receipt):
    require(all(math.isfinite(v) for v in entry),'Nonfinite observed cache or guide')
    identity=patch['identity'];owner=patch['owner']
    require(entry[4:8]==(identity[0],identity[1],receipt['epoch'],owner['generation']),'Observed cache identity differs')
    require(math.dist(entry[8:11],patch['position'])<=8*numeric.EPS and math.dist(entry[12:15],patch['normal'])<=8*numeric.EPS,'Observed cache geometry differs')
    require(math.dist(atlas_support.oct_decode(entry[11],entry[15]),patch['geometricNormal'])<=16*numeric.EPS,'Observed cache Ng differs')
    require(entry[3]>0 and entry[19]>=0,'Observed cache lacks a finite positive-confidence measurement')


def compare_observations(native,receipts,atlas_frames,expected):
    reports=[];previous_new=None;hashes={}
    for receipt,atlas,frame in zip(receipts,atlas_frames,expected['frames']):
        prefix='frame-%03d-'%receipt['logicalFrame']
        def read(suffix):
            data=(native/(prefix+suffix)).read_bytes();hashes[prefix+suffix]=hashlib.sha256(data).hexdigest();return data
        before_data=read('cache-before.bin');old_after_data=read('cache-old-after.bin');new_data=read('cache-new-after.bin')
        require(before_data==old_after_data,'CSUpdateCache mutated its Jacobi read buffer')
        if previous_new is not None:require(before_data==previous_new,'Next actual read buffer differs from preceding write buffer')
        previous_new=new_data
        before=cache_entries(before_data,receipt);new=cache_entries(new_data,receipt);cache_rows=[]
        for owner,patch in atlas.owners.items():
            old,current=before[patch['index']],new[patch['index']];row=frame['cache'][owner]
            validate_cache_geometry(old,patch,receipt);validate_cache_geometry(current,patch,receipt)
            state=atlas.cache_state[patch['index']]
            require((old[3],0,0,0,*old[4:16])==state,'Pure scalar/geometry cache input differs from its separate observation')
            if receipt['logicalFrame']==31:require(old[:3]==(0,0,0) and old[19]==0,'Fixed warmup did not produce known exact black')
            require(current[3]==row['samples'],'Cache update count is not the expected 1/2 then 1/3 recurrence')
            passed=numeric.contains(row['rgbIntervals'],current[:3])
            cache_rows.append(dict(owner=owner,observed=list(current[:4]),expectedIntervals=row['rgbIntervals'],passed=passed))
        raw=read('raw.rgba32f');geometry=read('geometry.rgba32f');material=read('material.rgba32f')
        size=receipt['width']*receipt['height']*16;require(len(raw)==len(geometry)==len(material)==size,'Texture observation shape differs')
        gathers=[]
        for group in frame['gather']:
            x,y=group['pixel'];offset=(y*receipt['width']+x)*16;rgba=struct.unpack_from('<4f',raw,offset)
            geo=struct.unpack_from('<4f',geometry,offset);mat=struct.unpack_from('<4f',material,offset)
            # Auxiliary observations only establish a current receiver; neither
            # material RGB nor raw RGB feeds any expectation construction.
            require(all(math.isfinite(v) for v in geo+mat),'Nonfinite receiver auxiliary observation')
            gathers.append(dict(id=group['id'],pixel=group['pixel'],observed=list(rgba),storageIntervals=group['storageIntervals'],passed=numeric.compare(group['storageIntervals'],rgba)))
        reports.append(dict(logicalFrame=receipt['logicalFrame'],cache=cache_rows,gather=gathers,
                            passed=all(row['passed'] for row in cache_rows+gathers)))
    return reports,hashes


def negative_controls(expected):
    positive=next(g for f in expected['frames'][1:] for g in f['gather'] if all(pair[0]>0 for pair in g['storageIntervals']))
    middle=[(a+b)*.5 for a,b in positive['rgbIntervals']];ranges=positive['storageIntervals']
    first=expected['frames'][2]['cache']['A']['rgbIntervals']
    return dict(extraPiRejected=not numeric.compare(ranges,[numeric.half_rne(v/math.pi) for v in middle]+[1]),
                swappedChannelsRejected=not numeric.compare(ranges,[numeric.half_rne(v) for v in reversed(middle)]+[1]),
                unknownRejected=not numeric.compare(ranges,[numeric.half_rne(v) for v in middle]+[-1]),
                staleZeroCacheRejected=not numeric.contains(first,[0,0,0]))


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--native-outputdir',type=Path,required=True);parser.add_argument('--package',type=Path);parser.add_argument('--output',type=Path);args=parser.parse_args()
    native=args.native_outputdir;package=args.package or native.parent;source=load(HERE/'source-contract.json')
    receipts=[load(native/('frame-%03d.json'%logical)) for logical in (31,32,33)]
    for i,receipt in enumerate(receipts):
        require(receipt['logicalFrame']==31+i and receipt['cacheGrid']==1 and receipt['cacheRays']==16 and receipt['rays']==8,'Capture frame/shape differs')
        if i:require(receipt['workFrame']==receipts[i-1]['workFrame']+1 and receipt['cacheReadIndex']==1-receipts[i-1]['cacheReadIndex'] and receipt['epoch']==receipts[0]['epoch'],'Actual Jacobi frame/buffer sequence differs')
    scene=validate_scene(load(native/'scene-inputs.json'),load(native/'scene-result.json'),receipts,source,[json.loads(line) for line in (native/'frames.jsonl').read_text(encoding='utf-8-sig').splitlines()])
    provenance=validate_sources(package)
    atlas_frames=[atlas_support.AtlasFrame(native,receipt,source) for receipt in receipts]
    for atlas in atlas_frames[1:]:
        for name in ('cards','owner-ranges','card-indices','anchors','mask','owner-identities','atlas-inputs'):
            require(atlas.hashes[name]==atlas_frames[0].hashes[name],'Fixed scene geometry input changed between observation windows: '+name)
    screen_reports=[screen.qualify((native/('frame-%03d-gather-inputs.bin'%r['logicalFrame'])).read_bytes(),r,source) for r in receipts]
    expected=numeric.build(source,atlas_frames,[r['groups'] for r in screen_reports])
    expected.update(sourceSha256=sha(HERE/'source-contract.json'),receiptSha256={str(r['logicalFrame']):sha(native/('frame-%03d.json'%r['logicalFrame'])) for r in receipts},screenInputQualification=screen_reports,referenceCodeSha256={name:sha(HERE/name) for name in ('numeric_reference.py','atlas_support.py','screen_input_qualification.py','compare_native.py')})
    negatives=negative_controls(expected);require(all(negatives.values()),'Prospective negative control failed')
    expected_path=native/'finite-feedback-expected.json'
    if expected_path.exists():require(load(expected_path)==expected,'Previous independent expectation differs')
    else:
        with expected_path.open('x',encoding='utf8') as stream:json.dump(expected,stream,indent=2,allow_nan=False)
    # FIRST observation read occurs here, after source qualification and the
    # complete expectation file exist. No RGB is used to tune any input guard.
    reports,observed_hashes=compare_observations(native,receipts,atlas_frames,expected)
    result=dict(status='passed' if all(r['passed'] for r in reports) else 'failed',passed=all(r['passed'] for r in reports),
        scope='Conditional finite current-input cache feedback consistency. Assumes the predeclared DXR hit localization box and arithmetic implementation class. Not default multi-bounce, steady-state, final-composite or portable DXR precision certification.',
        warmupFrames=32,positiveCacheUpdates=2,maximumScatteringOrders=dict(cache=2,rawGather=3,includingVisibleReceiver=4),
        expectedSha256=sha(expected_path),sourceClosure=scene,sourceProvenance=provenance,negativeControls=negatives,observedSha256=observed_hashes,frames=reports)
    output=args.output or native/'finite-feedback-comparison.json'
    with output.open('x',encoding='utf8') as stream:json.dump(result,stream,indent=2,allow_nan=False)
    print(json.dumps(dict(status=result['status'],cacheComparisons=6,gatherComparisons=54,output=str(output))))
    require(result['passed'],'One or more independently predicted cache/gather values differ')


if __name__=='__main__':main()
