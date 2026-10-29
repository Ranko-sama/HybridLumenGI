"""Finite input-qualified identity-depth diagnosis. No radiance RGB is decoded."""
import argparse
from collections import Counter
import hashlib
import importlib.util
import json
import math
from pathlib import Path
import struct
import sys

P=Path(__file__).resolve().parent
ROOT=P.parents[2]
BASE=P.parent/'camera-motion-taa-response-02'
COUNT=264;OWNERS=3;HEADER=57;VECTORS=2433
IDENTITY=[float(r==c) for c in range(4) for r in range(4)]
NAMES={'ReferenceFloor':'floor','ReferencePanel':'panel','ReferenceWall':'wall'}


def require(ok,message):
    if not ok:raise AssertionError(message)
def load(path):return json.loads(path.read_text(encoding='utf-8-sig'))
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def imported(name,path):
    spec=importlib.util.spec_from_file_location(name,path);module=importlib.util.module_from_spec(spec)
    sys.modules[name]=module;spec.loader.exec_module(module);return module


m=imported('identity_depth_planar_model',BASE/'qualification-ties/model.py')
expression=imported('identity_depth_author_expression',BASE/'target-input-qualification/audit.py')
initialization=imported('identity_depth_initialization',BASE/'initialization-source-qualification/audit.py')


def bits(value):return struct.unpack('<I',struct.pack('<f',value))[0]
def value(word):return struct.unpack('<f',struct.pack('<I',word))[0]
def vec(obj,axes='xyz'):return [obj[k] for k in axes]
def matrix(obj):return [obj[f'e{r}{c}'] for c in range(4) for r in range(4)]
def matrix_rows(words):return m.columns([[value(x) for x in row] for row in words])


def depth_mask(words):
    z,camera,capture=(value(w) for w in words)
    valid=math.isfinite(camera) and math.isfinite(capture) and 0<=camera<=1 and 0<=capture<=1
    return int(valid)|(2 if z==camera else 0)|(4 if camera==capture else 0)


def fragment_result(rows,candidate,identity,owner,geometry_depth_word):
    """Only called after independent visible-source qualification."""
    entry,reached,claimed,reserved=rows[0]
    require(reserved==0 and reached<=entry and claimed==int(reached>0),'Probe counter/claim ABI differs')
    if entry==0:
        require(not any(sum((list(r) for r in rows),[])),'No-entry probe contains payload')
        return dict(classification='visible-no-fragment-entry')
    if reached==0:
        require(not any(rows[1]+rows[2]),'No-depth probe contains payload')
        return dict(classification='visible-rejected-before-depth',entryCount=entry)
    primitive,z,camera,capture=rows[1];gate,source,x,y=rows[2]
    require(gate==depth_mask((z,camera,capture)),'Saved depth mask disagrees with saved scalar bits')
    require(source==owner['owner'] and primitive in (1,2),'Observed source/primitive differs')
    require(math.isfinite(value(z)),'Depth stage passed the earlier finite-position gate with nonfinite z')
    if entry>1 or reached>1:return dict(classification='visible-multiple-fragments-uncovered',entryCount=entry,depthCount=reached)
    require(camera==geometry_depth_word,'Identity camera depth differs from same-frame current geometry depth')
    result=dict(primitivePlus1=primitive,depthWords=[z,camera,capture],depthValues=[value(w) for w in (z,camera,capture)],
                gateMask=gate,zCameraNumericDifference=value(z)-value(camera),cameraCaptureNumericDifference=value(camera)-value(capture),
                zCameraWordDistance=abs(z-camera),cameraCaptureWordDistance=abs(camera-capture),
                candidate=list(candidate),identity=list(identity))
    if gate!=7:
        result['classification']='visible-strict-depth-rejected'
        result['rejectedTerms']=([ 'SVz!=cameraDepth' ] if not gate&2 else [])+([ 'cameraDepth!=captureDepth' ] if not gate&4 else [])+([ 'invalid-depth-range' ] if not gate&1 else [])
        result['candidateContradictsUniqueRejectedFragment']=candidate[0]==owner['owner']
        return result
    if candidate!=(owner['owner'],0,primitive):
        result['classification']='visible-depth-passed-candidate-discrepancy';return result
    expected=(owner['keyLow'],owner['keyHigh'],primitive,1)
    result['classification']='visible-identity-retained' if identity==expected else 'visible-depth-passed-resolve-discrepancy'
    return result


def source_closure(package):
    frozen=load(package/'source-freeze.json')
    require(frozen['schema']=='camera-identity-depth-diagnostic-v1','Unexpected diagnostic source schema')
    required=[P/name for name in ('analyze.py','test_analyze.py','input-model.txt')]
    required += [BASE/'qualification-ties/model.py',BASE/'target-input-qualification/audit.py',BASE/'initialization-source-qualification/audit.py']
    required += [ROOT/'LocalComparison/Reference/ColorBounceRectangle'/name for name in ('qualify_native_inputs.py','decode_sampler.py','generate_sampler.py')]
    require(all(path.relative_to(ROOT).as_posix() in frozen['sources'] for path in required),'Required diagnostic/math source missing from freeze')
    for group in ('sources','evidence'):
        for name,digest in frozen[group].items():require(sha(ROOT/name)==digest,'Frozen source/evidence changed: '+name)
    manifest=load(package/'instrumentation/manifest.json')
    for rel,digest in manifest['productSourceSha256'].items():require(sha(ROOT/rel)==digest,'Base product changed: '+rel)
    for row in manifest['files']:require(sha(package/'instrumentation'/row['prepared'])==row['sha256'],'Prepared input changed: '+row['path'])
    for path,digest in load(package/'instrumentation/urp-source.json').items():require(sha(Path(path))==digest,'URP input changed: '+path)
    execution=load(package/'execution-receipt.json')
    require(execution.get('passed') is True and execution.get('sourceAndRestorationVerified') is True and
            execution.get('actualConsecutiveFrames')==48 and execution.get('diagnosticFrames')==list(range(36,44)),
            'Independent native execution/source/restoration audit must pass first')
    for logical in range(48):
        for suffix in ('.json','.bin'):
            path=package/'native'/f'frame-{logical:03}{suffix}'
            require(execution['inputSha256'].get(str(path.resolve()))==sha(path),'Main input differs from execution audit')
    return dict(sourceFreezeSha256=sha(package/'source-freeze.json'),instrumentationManifestSha256=sha(package/'instrumentation/manifest.json'),
                executionReceiptSha256=sha(package/'execution-receipt.json'))


def probe_result(summary,records):
    require(summary['complete'] is True and summary.get('failure') in (None,''),'Probe cleanup/result failed')
    require(summary['framesExpected']==summary['framesCreated']==summary['framesCompleted']==8 and summary['pendingReadbacks']==0,'Probe readback lifecycle incomplete')
    links=summary['frameLinks']
    require([row['logicalFrame'] for row in links]==list(range(36,44)),'Probe result fixed window differs')
    for row in links:
        peer=records[row['logicalFrame']]
        require(row['engineFrame']==peer['engineFrame'] and row['workFrame']==peer['workFrame'] and row['bytes']==VECTORS*16,'Probe result main-frame linkage differs')


def scene_inputs(source):
    settings=source['settings']
    expected=dict(resolutionScale=1,raysPerPixel=8,screenSteps=0,traceDistance=20,rayBias=.03,bounceFeedback=0,guidedSamplingWeight=0,
                  emissiveSamplingWeight=0,maxEmissiveProposals=0,maxAreaEmitterTriangles=0,radianceClamp=0,filterIterations=0,
                  temporalAccumulation=True,maxHistory=32,temporalCurrentWeight=.08,relativeDepthThreshold=.015,normalThreshold=.9,
                  maxLights=1,spatialLightSelection=False,globalSdfEnabled=False,preferHardwareTracing=True,
                  receiverSourceTracking=True,receiverObjectHistory=True)
    for name,v in expected.items():require(m.f32(settings[name])==m.f32(v),'Frozen setting changed: '+name)
    require(vec(settings['environmentRadiance'],'rgb')==[0,0,0] and settings.get('environmentCubemap') in (None,{'instanceID':0}),'Environment changed')
    shapes=dict(wall=[[0,0,-2],[0,2,-2],[0,2,2],[0,0,2]],floor=[[0,0,-3],[0,0,3],[5,0,3],[5,0,-3]],
                panel=[[.4,0,-.2],[.4,1.8,-.2],[1.8,1.8,-.2],[1.8,0,-.2]])
    colors=dict(wall=[.5,.25,.125,1],floor=[1,1,1,1],panel=[0,0,0,1])
    for name,vertices in shapes.items():
        s=source[name]
        require([vec(p) for p in s['vertices']]==[[m.f32(v) for v in p] for p in vertices],'Source vertices changed')
        require([vec(n) for n in s['normals']]==[list(m.RECTS[name]['normal'])]*4 and s['triangles']==[0,1,2,0,2,3],'Source normals/triangles changed')
        require(matrix(s['localToWorld'])==IDENTITY and vec(s['shaderLinearBaseColor'],'xyzw')==colors[name],'Source pose/color changed')
        require(s['shader']=='Universal Render Pipeline/Lit' and s['metallic']==0 and s['occlusionStrength']==1,'Source material changed')
        require(not any(s[k] for k in ('normalMap','baseMap','emissionMap','occlusionMap','emissionKeyword','receiveShadows')),'Source maps/shadows changed')
    light=source['light']
    require(light['type']=='Directional' and light['shadows']=='None' and light['enabled'] and light['intensity']==1 and vec(light['color'],'rgb')==[1,1,1] and vec(light['toLight'])==[1,0,0],'Source light changed')
    require(vec(source['cameraPosition'])==[3,3,-3] and source['cameraFieldOfView']==50 and m.f32(source['cameraNear'])==m.f32(.05) and
            source['cameraFar']==30 and m.f32(source['cameraAspect'])==m.f32(640/360),'Initial camera changed')


def analyze(package):
    require(package.resolve()==P.resolve(),'Diagnostic must use its frozen native package')
    closure=source_closure(package);native=package/'native';source=load(native/'scene-inputs.json');scene_inputs(source)
    expected_targets,expected_paths=expression.expected_inputs()
    records=[];controls=[];receipt_pins={};header_pins={};previous_nojit=None;nonzero_jitter=0
    for logical in range(48):
        receipt=native/f'frame-{logical:03}.json';binary=receipt.with_suffix('.bin');r=load(receipt)
        require(binary.stat().st_size==(12+COUNT*45)*16,'Main observer ABI changed')
        with binary.open('rb') as stream:header=stream.read(192)
        c=struct.unpack('<48f',header);records.append(r);controls.append(c[:4])
        require(c[8:12]==(640,360,640,360) and c[4:8]==(m.f32(.08),32,1,r['workFrame']) and
                c[12:16]==(m.f32(.015),m.f32(.9),m.f32(.03),3),'Actual bound main observer controls changed')
        nojit=m.columns([c[i:i+4] for i in range(16,32,4)]);prevnojit=m.columns([c[i:i+4] for i in range(32,48,4)])
        require(nojit==r['unjitteredGpuVP'],'CPU/GPU current nonjittered matrix differs')
        if logical>=31:
            require(prevnojit==previous_nojit,'Actual URP previous nonjittered ownership differs')
            m.jitter(r,records[-2])
            if any(v!=0 for v in r['jitterDelta']):nonzero_jitter+=1
        previous_nojit=nojit
        receipt_pins[receipt.name]=sha(receipt);header_pins[binary.name]=hashlib.sha256(header).hexdigest()
        require(r['pixels']==COUNT and r['width']==640 and r['height']==360 and r['useIdentity'] and r['hasMotion'],'Main camera scope changed')
        require(r['antialiasing']=='TemporalAntiAliasing' and r['postProcessing'] and r['taaQuality']=='High' and r['jitterScale']==1,'Real TAA configuration changed')
        require(vec(r['cameraPosition'])==[float(expression.fraction_from_bits(v)) for v in expected_paths[logical]['wide']] and r['cameraRotation']==source['cameraRotation'],'Authored camera path changed')
        require(len(r['selection'])==COUNT,'Author sample count changed')
        for selected,target in zip(r['selection'],expected_targets):
            require(selected['index']==target['index'] and selected['cohort']==target['cohort'] and vec(selected['worldTarget'])==[float(expression.fraction_from_bits(v)) for v in target['wide']],'Authored sample order/target changed')
    init=initialization.qualify(records,controls)
    require(nonzero_jitter>=8,'Original actual nonzero TAA jitter coverage is absent')
    expected_probe_json={f'probe-{f:03}.json' for f in range(36,44)}
    require({p.name for p in native.glob('probe-*.json')}==expected_probe_json|{'probe-result.json'},'Only eight fixed frame receipts plus the lifecycle result are allowed')
    require({p.name for p in native.glob('probe-*.bin')}=={f'probe-{f:03}.bin' for f in range(36,44)},'Only eight fixed probe buffers are allowed')
    probe_result(load(native/'probe-result.json'),records)
    report=dict(diagnosticComplete=False,scope='Only finite identity-fragment input diagnosis; no original temporal-quality acceptance',
                originalQualityAccepted=False,currentRadianceRgbDecoded=False,additionalDiagnosticFrames=8,
                sourceClosure=closure,initializationSourceQualification=init,frames=[],coverageFailures=[],uncovered=[],receiptSha256=receipt_pins,
                mainInputHeaderSha256=header_pins,probeResultSha256=sha(native/'probe-result.json'),nonzeroJitterFrames=nonzero_jitter)
    total=Counter();dropouts=0;frozen_rows=None
    for logical in range(36,44):
        receipt=native/f'probe-{logical:03}.json';binary=receipt.with_suffix('.bin');q=load(receipt);r=records[logical]
        require(q['complete'] and q['captureRecorded'] and not q['error'] and q['logicalFrame']==logical and q['engineFrame']==r['engineFrame'],'Probe frame/source correspondence failed')
        require((q['width'],q['height'],q['points'],q['owners'],q['rowVectors'])==(640,360,264,3,VECTORS),'Probe ABI differs')
        require(q['customVP']==r['vp'] and len(q['selection'])==COUNT and len(q['sourceRows'])==OWNERS,'Probe VP/selection/source count differs')
        data=binary.read_bytes();require(len(data)==VECTORS*16,'Probe byte size differs');words=list(struct.iter_unpack('<4I',data))
        main=(native/f'frame-{logical:03}.bin').read_bytes()
        u=lambda index,row:struct.unpack_from('<4I',main,(12+index*45+row)*16)
        v=lambda index,row:struct.unpack_from('<4f',main,(12+index*45+row)*16)
        # Main rows5/6/7 (current radiance/history/moments) are never decoded.
        first_by_pixel={};canonical=[]
        for index,(selected,old) in enumerate(zip(q['selection'],r['selection'])):
            require({k:v for k,v in selected.items() if k!='canonicalIndex'}==old,'Probe and original author selections differ')
            pixel=(selected['x'],selected['y']);expected=first_by_pixel.setdefault(pixel,index) if selected['projected'] else -1
            require(selected['canonicalIndex']==expected,'Canonical selection map differs')
            require(u(index,0)==(pixel[0]&0xffffffff,pixel[1]&0xffffffff,index,0),'Main uploaded coordinate differs')
            if expected==index:canonical.append(index)
            else:require(not any(x for row in words[HEADER+index*9:HEADER+(index+1)*9] for x in row),'Unused alias probe body is not zero')
        require(q['canonicalPixels']==len(canonical),'Canonical pixel count differs')
        require({row['renderer'] for row in q['sourceRows']}==set(NAMES),'Source owner mapping differs')
        owners={};matrices=[]
        for owner_index,owner in enumerate(q['sourceRows']):
            require(owner['owner']==owner_index+1 and owner['rowIndex']==owner_index and owner['submesh']==0 and owner['token']>0 and owner['geometryGeneration']>0 and owner['materialGeneration']>0 and (owner['keyLow'] or owner['keyHigh']),'Source row identity invalid')
            require(owner['localToWorld']==owner['currentToPrevious']==IDENTITY,'Static source transforms changed')
            owners[NAMES[owner['renderer']]]=owner
            h=words[owner_index*19:(owner_index+1)*19]
            if h[0][0]==0:
                require(not any(x for row in h for x in row),'Unclaimed header contains payload');continue
            require(h[0][0]==1 and h[0][3]==owner_index+1 and h[10][0] in (0,1) and not any(h[10][1:]),'Header claim/variant differs')
            actual_vp=matrix_rows(h[1:5]);custom_vp=matrix_rows(h[5:9]);actual_m=matrix_rows(h[11:15]);custom_m=matrix_rows(h[15:19])
            require(all(math.isfinite(x) for x in actual_vp+custom_vp+actual_m+custom_m),'Observed matrices are not finite')
            require(custom_vp==q['customVP'] and custom_m==owner['localToWorld'],'Observed custom constants differ from frozen draw source')
            matrices.append(dict(owner=owner_index+1,renderer=owner['renderer'],actualVP=actual_vp,customVP=custom_vp,actualM=actual_m,customM=custom_m,
                                 vpBitDifferences=[i for i,(a,b) in enumerate(zip(sum(h[1:5],()),sum(h[5:9],()))) if a!=b],
                                 vpNumericEqual=actual_vp==custom_vp,mBitDifferences=[i for i,(a,b) in enumerate(zip(sum(h[11:15],()),sum(h[15:19],()))) if a!=b],mNumericEqual=actual_m==custom_m,
                                 alphaToMask=value(h[0][1]),hasBaseMap=value(h[0][2]),alphaParameters=[value(x) for x in h[9]],debugVariant=h[10][0]))
        if frozen_rows is None:frozen_rows=q['sourceRows']
        require(q['sourceRows']==frozen_rows,'Identity source generations/rows changed in diagnostic window')
        frame=dict(logicalFrame=logical,engineFrame=r['engineFrame'],workFrame=r['workFrame'],matrices=matrices,samples=[],qualifiedBySource={},classifications={},probeReceiptSha256=sha(receipt),probeInputSha256=sha(binary),mainInputSha256=sha(native/f'frame-{logical:03}.bin'))
        qualified=Counter();classified=Counter()
        for index in canonical:
            pixel=(q['selection'][index]['x'],q['selection'][index]['y'])
            try:
                visible=m.ray_owner(pixel,r);m.surface(pixel,v(index,3),r,visible)
            except m.Uncovered as error:report['uncovered'].append(dict(frame=logical,index=index,pixel=list(pixel),reason=str(error)));continue
            qualified[visible]+=1;owner=owners[visible];start=HEADER+(index*OWNERS+owner['rowIndex'])*3;group=words[start:start+3]
            if group[0][0]:require(words[owner['rowIndex']*19][0]==1,'Mapped fragment has no claimed owner constants')
            if group[0][1]:require(group[2][2:]==pixel,'Fragment payload pixel differs')
            item=fragment_result(group,u(index,9)[:3],u(index,8),owner,u(index,3)[3])
            item.update(index=index,pixel=list(pixel),visibleSource=visible,owner=owner['owner'])
            invalid=u(index,8)[3]!=1 or not any(u(index,8)[:2])
            item['currentIdentityInvalid']=invalid
            if invalid:dropouts+=1
            classified[item['classification']]+=1;frame['samples'].append(item)
        for name in ('floor','panel'):
            if qualified[name]<8:report['coverageFailures'].append(dict(frame=logical,source=name,qualified=qualified[name],required=8))
        frame['qualifiedBySource']=dict(qualified);frame['classifications']=dict(classified);total.update(classified);report['frames'].append(frame)
    report.update(diagnosticComplete=True,reproducedVisibleIdentityDropout=dropouts>0,visibleIdentityDropoutPixels=dropouts,classifications=dict(total))
    report['status']='inconclusive-no-reproduced-dropout' if not dropouts else 'observed-dropout-diagnostic-evidence'
    if report['coverageFailures']:report['status']='inconclusive-geometric-coverage'
    return report


if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('package',type=Path);parser.add_argument('--output',type=Path,required=True);args=parser.parse_args()
    require(not args.output.exists(),'Preserve all prior results')
    try:result=analyze(args.package)
    except Exception as error:result=dict(diagnosticComplete=False,status='source-or-observation-failure',error=str(error),originalQualityAccepted=False)
    with args.output.open('x',encoding='utf-8') as stream:json.dump(result,stream,indent=2);stream.write('\n')
    print(json.dumps({k:result.get(k) for k in ('diagnosticComplete','status','visibleIdentityDropoutPixels','error')}))
    sys.exit(0 if result['diagnosticComplete'] else 1)
