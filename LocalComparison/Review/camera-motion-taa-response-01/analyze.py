"""Prospective camera/TAA correspondence analysis; cohorts precede output reads."""
import argparse
from collections import Counter
import hashlib
import json
import math
from pathlib import Path
import struct
import sys
import model as m

P=Path(__file__).resolve().parent
ROOT=P.parents[2]
CONTEXT={}
def require(value,message):
    if not value:raise AssertionError(message)
def load(path):return json.loads(path.read_text(encoding='utf-8-sig'))
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def vec(value,fields='xyz'):return [value[k] for k in fields]
def finite(values):return all(math.isfinite(v) for v in values)
def matrix(value):return [value[f'e{r}{c}'] for c in range(4) for r in range(4)]
IDENTITY=[float(r==c) for c in range(4) for r in range(4)]

def source_closure(package,source):
    manifest=load(package/'instrumentation/manifest.json')
    for rel,digest in manifest['productSourceSha256'].items():require(sha(ROOT/rel)==digest,'Current product source differs: '+rel)
    for row in manifest['files']:require(sha(package/'instrumentation'/row['prepared'])==row['sha256'],'Staged source differs: '+row['path'])
    for name,digest in load(package/'instrumentation/harness-source.json').items():require(sha(ROOT/'LocalComparison/Harness'/name)==digest,'Harness source differs: '+name)
    for name,digest in load(package/'instrumentation/analysis-source.json').items():require(sha(ROOT/name)==digest,'Frozen analysis source differs: '+name)
    for path,digest in load(package/'instrumentation/urp-source.json').items():
        require(sha(Path(path))==digest,'URP motion source differs: '+path)
    settings=source['settings']
    expected=dict(resolutionScale=1,raysPerPixel=8,screenSteps=0,traceDistance=20,rayBias=.03,bounceFeedback=0,guidedSamplingWeight=0,
                  emissiveSamplingWeight=0,maxEmissiveProposals=0,maxAreaEmitterTriangles=0,radianceClamp=0,filterIterations=0,
                  temporalAccumulation=True,maxHistory=32,temporalCurrentWeight=.08,relativeDepthThreshold=.015,normalThreshold=.9,
                  maxLights=1,spatialLightSelection=False,globalSdfEnabled=False,preferHardwareTracing=True,
                  receiverSourceTracking=True,receiverObjectHistory=True)
    for name,value in expected.items():require(m.f32(settings[name])==m.f32(value),'Frozen setting differs: '+name)
    require(vec(settings['environmentRadiance'],'rgb')==[0,0,0] and settings.get('environmentCubemap') in (None,{'instanceID':0}),'Environment differs')
    shapes=dict(wall=[[0,0,-2],[0,2,-2],[0,2,2],[0,0,2]],floor=[[0,0,-3],[0,0,3],[5,0,3],[5,0,-3]],
                panel=[[.4,0,-.2],[.4,1.8,-.2],[1.8,1.8,-.2],[1.8,0,-.2]])
    colors=dict(wall=[.5,.25,.125,1],floor=[1,1,1,1],panel=[0,0,0,1])
    for name,vertices in shapes.items():
        s=source[name]
        require([[m.f32(v) for v in vec(p)] for p in s['vertices']]==[[m.f32(v) for v in p] for p in vertices],'Authored '+name+' rectangle differs')
        require([vec(n) for n in s['normals']]==[list(m.RECTS[name]['normal'])]*4 and s['triangles']==[0,1,2,0,2,3],'Source normals/triangles differ')
        require(matrix(s['localToWorld'])==IDENTITY and vec(s['shaderLinearBaseColor'],'xyzw')==colors[name],'Source pose/color differs')
        require(s['shader']=='Universal Render Pipeline/Lit' and s['metallic']==0 and s['occlusionStrength']==1,'Source material differs')
        require(vec(s['proxyTint'],'rgb')==[1,1,1] and vec(s['materialEmission'],'rgb')==vec(s['proxyEmission'],'rgb')==[0,0,0],'Source tint/emission differs')
        require(not any(s[k] for k in ('normalMap','baseMap','emissionMap','occlusionMap','emissionKeyword','receiveShadows')),'Source map/shadow differs')
    light=source['light']
    require(light['type']=='Directional' and light['shadows']=='None' and light['enabled'] and light['intensity']==1 and vec(light['color'],'rgb')==[1,1,1] and vec(light['toLight'])==[1,0,0],'Frozen light differs')
    require(vec(source['cameraPosition'])==[3,3,-3] and source['cameraFieldOfView']==50 and m.f32(source['cameraNear'])==m.f32(.05) and source['cameraFar']==30,'Initial camera differs')
    require(source['antialiasing']=='TemporalAntiAliasing' and source['postProcessing'] and source['jitterScale']==1 and source['taaQuality']=='High','TAA settings differ')
    return dict(productFiles=len(manifest['productSourceSha256']),manifestSha256=sha(package/'instrumentation/manifest.json'),
                analysisManifestSha256=sha(package/'instrumentation/analysis-source.json'),urpManifestSha256=sha(package/'instrumentation/urp-source.json'))

def decode_inputs(data,count=264):
    require(len(data)==(12+count*45)*16,'12-control/45-row compact ABI differs')
    headers=[struct.unpack_from('<4f',data,16*i) for i in range(12)];nodes=[]
    for index in range(count):
        base=(12+index*45)*16
        v=lambda row:struct.unpack_from('<4f',data,base+row*16)
        u=lambda row:struct.unpack_from('<4I',data,base+row*16)
        finitebits=lambda row:all(bits&0x7f800000!=0x7f800000 for bits in struct.unpack_from('<3I',data,base+row*16))
        alpha=lambda row:struct.unpack_from('<f',data,base+row*16+12)[0]
        meta=u(0);motion=v(1);pose=v(2)
        node=dict(pixel=meta[:2],index=meta[2],motion=motion[:2],motionUV=motion[2:],poseUV=pose[:2],clipW=pose[2],
                  geometry=v(3),material=v(4),identity=u(8),candidate=u(9),transform=[list(v(row)) for row in range(10,14)],objectKey=u(14),prior=[],base=base)
        for slot in range(5):
            row=15+slot*6;meta=u(row)
            node['prior'].append(dict(pixel=meta[:2],slot=meta[2],inBounds=meta[3],geometry=v(row+1),material=v(row+2),identity=u(row+3),
                                      confidence=alpha(row+4),rgbFinite=finitebits(row+4),moments=v(row+5)))
        # Rows5/6/7 (current raw, output history and output moments) are not
        # decoded here. Even output confidence/age cannot select a cohort.
        nodes.append(node)
    return headers,nodes

def established(old):
    m.need(old['rgbFinite'] and math.isfinite(old['confidence']) and old['confidence']>0,'prior history is not finite/known')
    m.need(finite(old['moments']) and old['moments'][2]>1,'prior history is not established age>1')

def targets():
    result=[]
    for group in range(2):
        for j in range(11):
            for i in range(21 if group==0 else 3):
                x=m.f32(m.f32(.8)+m.f32(m.f32(.05)*i)) if group==0 else m.f32(2+m.f32(m.f32(.2)*i))
                z=m.f32(m.f32(.5)+m.f32(m.f32(.1)*j))
                result.append(('event' if group==0 else 'continued',[x,0,z]))
    return result

def selected_source(selected,node,r,index):
    cohort,target=targets()[index]
    require(selected['index']==node['index']==index and selected['cohort']==cohort and vec(selected['worldTarget'])==target,'Authored selection order/target differs')
    if not selected['projected']:
        require(node['pixel']==(2**32-1,2**32-1),'Unprojected sentinel differs');raise m.Uncovered('target is outside image')
    require(node['pixel']==(selected['x'],selected['y']),'Selection/upload pixel differs')
    projected,_=m.project(r['vp'],[m.I(v) for v in target])
    for a in range(2):
        pixel_range=projected[a]*m.SIZE[a]
        # CPU System.Numerics/Unity scalar rounding can choose either adjacent
        # integer at an enclosed boundary. The actual pixel must be inside this
        # source projection enclosure, never chosen by an output measurement.
        require(math.floor(pixel_range.low)<=node['pixel'][a]<=math.floor(pixel_range.high),'Pixel is outside authored projection enclosure')
    return cohort

def classify(node,r,controls,cohort,no_jitter,previous_no_jitter):
    pixel=node['pixel']
    if m.ray_owner(pixel,r)!='floor':return dict(classification='not-current-floor')
    proof=m.support(pixel,node,r)
    motion=m.motion_source(node,proof,no_jitter,previous_no_jitter)
    m.need(controls[0][0]==1,'global history is invalid')
    if cohort=='event':
        old=node['prior'][0]
        if m.ray_owner(old['pixel'],r,True)!='panel':return dict(classification='not-first-exposure')
        panel_position,_,_=m.surface(old['pixel'],old['geometry'],r,'panel',True)
        m.need(old['identity'][2]==m.source_primitive('panel',panel_position),'prior panel identity primitive differs from authored triangle')
        m.need(old['identity'][3]==1 and old['identity'][2]>0 and any(old['identity'][:2]),'prior panel identity invalid')
        m.need(not m.same_primitive(node['identity'],old['identity']),'independent panel and floor have same identity')
        established(old)
        return dict(classification='first-exposure',nearest=list(old['pixel']),motionEnclosure=motion)
    margins=m.continued_geometry(node,r,proof,controls[3][0],controls[3][1])
    for old in node['prior']:established(old)
    return dict(classification='continued',support=[list(p) for p in proof['addresses']],minimumMargins=margins,motionEnclosure=motion)

def current_measurement(raw):
    if not finite(raw) or raw[3]<=0:return False
    lum=sum(v*w for v,w in zip(raw[:3],(.2126,.7152,.0722)))
    return all(math.isfinite(v) and abs(v)<3.4028234e38 for v in [lum,lum*lum,*[v*v for v in raw[:3]]])

def result_check(data,node,classification):
    raw=struct.unpack_from('<4f',data,node['base']+5*16)
    history=struct.unpack_from('<4f',data,node['base']+6*16)
    moments=struct.unpack_from('<4f',data,node['base']+7*16)
    if not current_measurement(raw):return dict(known=False,confidence=raw[3])
    require(finite(history+moments) and history[3]>0,'Qualified known current produced invalid history')
    if classification=='first-exposure':
        # Observed formats are both RGBA16F promoted to float32. Equality of
        # finite numeric values permits only the declared IEEE signed-zero case.
        require(history==raw,'First-exposure history retained another surface instead of copying current raw')
        require(moments[2]==1,'First-exposure age is not one')
    else:require(moments[2]>1,'Continued visible receiver lost its established history')
    return dict(known=True,age=moments[2],confidence=history[3])

def analyze(package):
    native=package/'native';source=load(native/'scene-inputs.json')
    report=dict(passed=False,sourceClosure=source_closure(package,source),frames=[],unknown=[],violations=[],coverageFailures=[],inputQualificationFailures=[],
                cohortsUseOutput=False,scope='Finite static scene and prescribed camera/TAA path; conditional planar source input consistency and actual temporal history response, not arbitrary motion or radiance integration')
    result=load(native/'scene-result.json')
    require(result['status']=='collected' and result['readbacksDrained'] and all(result[n]==48 for n in ('requests','cameraBegins','cameraEnds','contextBegins','contextEnds')),'48 complete drained renders required')
    require(result['previewCaptures']==3 and result['api']=='Direct3D12','Preview/API receipt differs')
    previous_r=None;previous_nojit=None;frozen_sources=None;previous_engine=None;jitter_frames=0;events=set();counts=Counter()
    for logical in range(48):
        CONTEXT.clear();CONTEXT['logicalFrame']=logical
        stem=native/f'frame-{logical:03d}';r=load(stem.with_suffix('.json'));data=stem.with_suffix('.bin').read_bytes();controls,nodes=decode_inputs(data)
        require(r['complete'] and not r.get('error') and r['logicalFrame']==logical and r['pixels']==264 and r['controlVectors']==12 and r['rowVectors']==45,'Frame receipt incomplete')
        require(r['width']==640 and r['height']==360 and r['lightCount']==1 and r['instanceCount']==3 and r['triangleCount']==6,'Frame scope differs')
        require(r['useIdentity'] and r['hasMotion'] and r['postProcessing'] and r['antialiasing']=='TemporalAntiAliasing' and r['jitterScale']==1 and r['taaQuality']=='High','Actual TAA/identity/motion inputs unavailable')
        require(r['motionFormat']=='R16G16_SFloat','Motion storage differs from declared binary16')
        require(previous_engine is None or r['engineFrame']==previous_engine+1,'Nonconsecutive engine frames');previous_engine=r['engineFrame']
        require(controls[2]==(640,360,640,360) and controls[1]==(m.f32(.08),32,1,r['workFrame']),'Actual temporal controls differ')
        require(controls[3]==(m.f32(.015),m.f32(.9),m.f32(.03),3),'Actual geometry controls differ')
        require(bool(controls[0][0])==r['historyValid'] and controls[0][3]==r['changeCount'],'Receipt/GPU control mismatch')
        nojit=m.columns(controls[4:8]);prevnojit=m.columns(controls[8:12])
        require(finite(nojit+prevnojit),'Nonfinite motion source matrices')
        # CPU and GPU current matrices are captured independently from their
        # actual producers; exact equality avoids inferring source from motion.
        require(nojit==r['unjitteredGpuVP'],'GPU/CPU nonjittered matrix source differs')
        x=m.f32(3+m.f32(m.f32(.075)*min(max(logical-31,0),8)))
        require(vec(r['cameraPosition'])==[x,3,-3] and r['cameraRotation']==source['cameraRotation'],'Frozen camera path/rotation differs')
        require(len(r['sources'])==3,'Source count changed')
        if frozen_sources is None:frozen_sources=r['sources']
        require(r['sources']==frozen_sources,'Static geometry/material source changed')
        for entry,name in zip(r['sources'],('wall','floor','panel')):
            require(entry['matrix']==IDENTITY and vec(entry['shaderLinearColor'],'xyzw')==vec(source[name]['shaderLinearBaseColor'],'xyzw'),'Frame source pose/color differs')
        frame=dict(logicalFrame=logical,workFrame=r['workFrame'],qualifiedEvents=0,qualifiedContinued=0,uncoveredReasons={},samples=[],
                   inputSha256=sha(stem.with_suffix('.bin')),receiptSha256=sha(stem.with_suffix('.json')))
        require(len(r['selection'])==264,'Frozen selection length differs')
        if logical>=31:
            require(previous_r is not None and r['previousVP']==previous_r['vp'] and r['previousInvVP']==previous_r['invVP'],'GI f-1 matrix ownership differs')
            require(prevnojit==previous_nojit,'URP f-1 nonjittered motion ownership differs')
            require(controls[0]==(1,0,0,0),'Camera-only motion unexpectedly reset/reactivated global history or change regions')
            frame['jitterIntervals']=m.jitter(r,previous_r)
            if any(v!=0 for v in r['jitterDelta']):jitter_frames+=1
            seen=set();proofs=[];reasons=Counter()
            for index,(selected,node) in enumerate(zip(r['selection'],nodes)):
                CONTEXT.update(sampleIndex=index,pixel=list(node['pixel']))
                try:
                    cohort=selected_source(selected,node,r,index)
                    if node['pixel'] in seen:continue
                    seen.add(node['pixel'])
                    if cohort=='event' and logical not in range(32,40):continue
                    proof=classify(node,r,controls,cohort,nojit,prevnojit)
                    if proof['classification'] in ('first-exposure','continued'):proofs.append((node,proof))
                    else:reasons[proof['classification']]+=1
                except m.Uncovered as error:reasons[str(error)]+=1
            # All input eligibility decisions finish before any current raw or
            # current output RGB/confidence/age row is decoded for this frame.
            frame['qualifiedBeforeOutput']=len(proofs)
            for node,proof in proofs:
                item=dict(index=node['index'],pixel=list(node['pixel']),**proof)
                try:
                    observation=result_check(data,node,proof['classification']);item['observation']=observation
                    if not observation['known']:
                        report['unknown'].append(dict(frame=logical,index=node['index'],pixel=list(node['pixel']),confidence=observation['confidence']));continue
                    if proof['classification']=='first-exposure':frame['qualifiedEvents']+=1;events.add((logical,*node['pixel']))
                    else:frame['qualifiedContinued']+=1
                except AssertionError as error:report['violations'].append(dict(frame=logical,index=node['index'],pixel=list(node['pixel']),reason=str(error)))
                frame['samples'].append(item)
            frame['uncoveredReasons']=dict(reasons);counts.update(reasons)
            if frame['qualifiedContinued']<8:report['coverageFailures'].append(dict(frame=logical,reason='fewer than eight qualified known continued pixels'))
            if logical in range(32,40):
                if frame['qualifiedEvents']<1:report['coverageFailures'].append(dict(frame=logical,reason='no qualified known first-exposure pixel'))
                moving=[node for node,proof in proofs if proof['classification']=='continued' and any(v!=0 for v in node['motion'])]
                if not moving:report['coverageFailures'].append(dict(frame=logical,reason='no nonzero motion among qualified continued inputs'))
        report['frames'].append(frame);previous_r=r;previous_nojit=nojit
    report.update(distinctEvents=len(events),nonzeroJitterFrames=jitter_frames,uncoveredReasons=dict(counts))
    if len(events)<8:report['coverageFailures'].append(dict(reason='fewer than eight distinct frame/pixel first-exposure events'))
    if jitter_frames<8:report['coverageFailures'].append(dict(reason='fewer than eight observed nonzero jitter deltas'))
    report['passed']=not report['violations'] and not report['coverageFailures'] and not report['inputQualificationFailures']
    return report

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('package',type=Path);parser.add_argument('--output',type=Path,required=True);args=parser.parse_args()
    require(not args.output.exists(),'Preserve first result')
    try:report=analyze(args.package)
    except Exception as error:report=dict(passed=False,executionOrSourceFailure=str(error),context=CONTEXT)
    with args.output.open('x',encoding='utf-8') as stream:json.dump(report,stream,indent=2);stream.write('\n')
    print(json.dumps({k:report.get(k) for k in ('passed','distinctEvents','nonzeroJitterFrames','executionOrSourceFailure')}))
    sys.exit(0 if report['passed'] else 1)
