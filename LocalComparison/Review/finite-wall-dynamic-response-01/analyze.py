"""Independent source-color checks and sufficient zero-input history bounds."""
import argparse
from fractions import Fraction as F
import hashlib
import importlib.util
import itertools
import json
import math
from pathlib import Path
import struct
import sys

P=Path(__file__).resolve().parent
ROOT=P.parents[2]
REFERENCE=ROOT/'LocalComparison/Reference/ColorBounceRectangle'
sys.path.insert(0,str(REFERENCE))
import qualify_native_inputs as qualified
CONTEXT={}

def load(path):return json.loads(path.read_text(encoding='utf-8-sig'))
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def require(value,message):
    if not value:raise AssertionError(message)
def finite(values):return all(math.isfinite(v) for v in values)
def f32(value):return struct.unpack('<f',struct.pack('<f',value))[0]
def ceil_half(value):
    rounded=struct.unpack('<e',struct.pack('<e',value))[0]
    if rounded<value:
        bits=struct.unpack('<H',struct.pack('<e',rounded))[0]+1
        rounded=struct.unpack('<e',struct.pack('<H',bits))[0]
    return rounded
def bounds():
    u=2**-24;gamma=32*u/(1-32*u);result=[ceil_half(.02*(1+gamma))]
    for k in range(1,32):
        alpha=(1-gamma)*max(f32(.08),1/min(k+2,32))
        result.append(ceil_half(result[-1]*(1-alpha)*(1+gamma)+2**-126))
    return result
def vec(value,fields='xyz'):return [value[k] for k in fields]
def known(value):return finite(value) and value[3]>0
def uv_support(pixel,geometry,motion,receipt,has_motion):
    I=qualified.Interval;size=(640,360)
    if has_motion:
        uv=[I(F(2*pixel[i]+1,2))/size[i]-I(motion[i])+I(receipt['jitterDelta'][i]) for i in range(2)]
    else:
        world=qualified.unproject_interval(receipt['invVP'],pixel,size,geometry[3]);world.append(I(1));clip=[]
        for row in range(4):
            products=[world[col]*receipt['previousVP'][row+4*col] for col in range(4)]
            sequential=products[0]
            for product in products[1:]:sequential=sequential+product
            balanced=(products[0]+products[1])+(products[2]+products[3])
            clip.append(I(min(sequential.low,balanced.low),max(sequential.high,balanced.high)))
        require(clip[3].low>0,'Previous clip w is not proven positive')
        uv=[clip[0]/clip[3]*.5+.5,-(clip[1]/clip[3]*.5+.5)+1]
    candidates=[]
    for axis,dimension in enumerate(size):
        require(0<uv[axis].low<=uv[axis].high<1,'Previous UV is outside the screen')
        # Full and low dimensions are equal. The union below contains nearest
        # and both interpolation centers over the entire float-operation interval.
        t=uv[axis]*dimension-.5
        lo=math.floor(t.low);hi=math.ceil(t.high)
        candidates.append(range(lo,hi+1))
    return set(itertools.product(*candidates))
def floor_input(pixel,geometry,receipt,plane):
    require(finite(geometry) and geometry[2]>=1 and geometry[2]<=2**24 and geometry[2]==math.floor(geometry[2]),'Current Ng/receiver unavailable')
    require(abs(geometry[0])<=1e-6 and abs(geometry[1]-1)<=1e-6,'Selected shading normal is not the authored upward floor')
    a,b,c=plane;exact=a*F(2*pixel[0]+1,2)+b*F(2*pixel[1]+1,2)+c
    snap=(abs(a)+abs(b))*qualified.SNAP
    interval=qualified.Interval(*qualified.outward(exact-snap,exact+snap))
    require(interval.contains(geometry[3]),'Depth is outside the independently authored floor raster interval')
    return qualified.unproject_interval(receipt['invVP'],pixel,[640,360],geometry[3])
def change_at(position,controls,regions):
    hard=controls[2]>.5;reactive=controls[1]>.5
    for region in regions:
        minimum,maximum=region[:4],region[4:8]
        low=[];high=[]
        for axis in range(3):
            p=position[axis]
            low.append(max(F(minimum[axis])-p.high,p.low-F(maximum[axis]),F(0)))
            high.append(max(F(minimum[axis])-p.low,p.high-F(maximum[axis]),F(0)))
        dlow=sum(v*v for v in low);dhigh=sum(v*v for v in high)
        if minimum[3]>.5:
            require(not dlow<=F(1e-8)<dhigh,'Hard-change boundary is numerically ambiguous')
            hard|=dhigh<=F(1e-8)
        radius=F(maximum[3])**2
        require(not dlow<=radius<dhigh,'Reactive influence boundary is numerically ambiguous')
        reactive|=dhigh<=radius
    return hard,reactive
def source_closure(package,source):
    manifest=load(package/'instrumentation/manifest.json')
    for rel,digest in manifest['productSourceSha256'].items():require(sha(ROOT/rel)==digest,'Product source changed: '+rel)
    for row in manifest['files']:require(sha(package/'instrumentation'/row['prepared'])==row['sha256'],'Staged source changed')
    frozen=load(package/'instrumentation/harness-source.json')
    for name,digest in frozen.items():require(sha(ROOT/'LocalComparison/Harness'/name)==digest,'Harness source changed: '+name)
    for name,digest in load(package/'instrumentation/analysis-source.json').items():require(sha(ROOT/name)==digest,'Analysis dependency changed: '+name)
    settings=source['settings']
    expected=dict(resolutionScale=1,raysPerPixel=8,screenSteps=0,traceDistance=20,rayBias=.03,bounceFeedback=0,guidedSamplingWeight=0,
        emissiveSamplingWeight=0,maxEmissiveProposals=0,maxAreaEmitterTriangles=0,radianceClamp=0,filterIterations=0,temporalAccumulation=True,
        maxHistory=32,temporalCurrentWeight=.08,maxLights=1,spatialLightSelection=False,globalSdfEnabled=False,preferHardwareTracing=True)
    for name,value in expected.items():require(abs(settings[name]-value)<1e-7,'Unexpected setting: '+name)
    require(vec(settings['environmentRadiance'],'rgb')==[0,0,0],'Nonzero environment')
    require(settings.get('environmentCubemap') in (None,{'instanceID':0}),'Environment cube present')
    for name,color in [('wall',[.5,.25,.125,1]),('floor',[1,1,1,1])]:
        surface=source[name]
        vertices=([[0,0,-2],[0,2,-2],[0,2,2],[0,0,2]] if name=='wall' else [[0,0,-3],[0,0,3],[5,0,3],[5,0,-3]])
        normal=[1,0,0] if name=='wall' else [0,1,0]
        require([vec(v) for v in surface['vertices']]==vertices and [vec(v) for v in surface['normals']]==[normal]*4 and surface['triangles']==[0,1,2,0,2,3],'Actual source mesh differs')
        require(all(surface['localToWorld'][f'e{r}{c}']==int(r==c) for r in range(4) for c in range(4)),'Source transform differs')
        require(vec(surface['shaderLinearBaseColor'],'xyzw')==color,'Initial source color differs')
        require(surface['shader']=='Universal Render Pipeline/Lit' and surface['metallic']==0 and surface['occlusionStrength']==1,'Source material differs')
        require(vec(surface['proxyTint'],'rgb')==[1,1,1],'Proxy tint differs')
        require(vec(surface['materialEmission'],'rgb')==vec(surface['proxyEmission'],'rgb')==[0,0,0],'Emission differs')
        require(not any(surface[k] for k in ('normalMap','baseMap','emissionMap','occlusionMap','emissionKeyword')),'A source texture or emission keyword is enabled')
    light=source['light'];require(light['type']=='Directional' and light['shadows']=='None' and light['enabled'] and light['intensity']==1,'Light source differs')
    require(vec(light['color'],'rgb')==[1,1,1] and max(abs(a-b) for a,b in zip(vec(light['toLight']),[1,0,0]))<1e-6,'White +X light differs')
    require(abs(source['cameraAspect']-640/360)<1e-6,'Capture aspect differs')
    return {'manifestSha256':sha(package/'instrumentation/manifest.json'),'analysisDependenciesFrozen':True}
def analyze(package):
    native=package/'native';upper=bounds()
    # Construct the expected zero-response table before any GPU value is read.
    report={'passed':False,'upperBounds':upper,'checks':0,'unknown':[],'uncovered':[],'frames':[]}
    report['sources']=source_closure(package,load(native/'scene-inputs.json'))
    selection=load(native/'selection.json');centers=selection['selection'];coordinates=[(p['x'],p['y']) for p in selection['coordinates']]
    require(len(centers)==27 and len({(p['x'],p['y']) for p in centers})==27,'Frozen center count differs')
    index={p:i for i,p in enumerate(coordinates)};require(len(index)==len(coordinates),'Duplicate compact coordinates')
    require(selection['rowVectors']==10 and selection['controlVectors']==3,'Compact ABI differs')
    recovery={phase:{center['id']:{'firstKnownOffset':None,'firstKnownPositiveOffset':None,'unknownCount':0,'endpointKnown':False} for center in centers} for phase in ('old-color','new-color','light-off')}
    result=load(native/'scene-result.json');require(result['status']=='collected' and result['readbacksDrained'],'Native sequence failed')
    for name in ('requests','cameraBegins','cameraEnds','contextBegins','contextEnds'):require(result[name]==96,'Sequence callback count differs')
    require(result['mpbEventApplied'] and result['lightOffEventApplied'] and result['previewCaptures']==3,'Events or representative images missing')
    mpb=load(native/'mpb-event.json');off=load(native/'light-off-event.json')
    require(mpb['beforeLogicalFrame']==32 and vec(mpb['before'],'xyzw')==[.5,.25,.125,1] and vec(mpb['after'],'xyzw')==[.125,.25,.5,1],'Ordinary MPB event differs')
    require(off['beforeLogicalFrame']==64 and off['lightEnabled'] is False,'Ordinary light event differs')
    positive=[0,0];prior_engine=None;off_known_closure=True
    for logical in range(96):
        CONTEXT.clear();CONTEXT['logicalFrame']=logical
        stem=native/f'frame-{logical:03d}';receipt=load(stem.with_suffix('.json'))
        require(receipt['complete'] and not receipt.get('error') and receipt['logicalFrame']==logical,'Incomplete compact receipt')
        require(receipt['lightCount']==(1 if logical<64 else 0),'Actual uploaded light count differs from event phase')
        require(prior_engine is None or receipt['engineFrame']==prior_engine+1,'Engine-frame history chain skipped');prior_engine=receipt['engineFrame']
        if logical==32:require(mpb['engineFrame']==prior_engine,'MPB was not applied before this actual render')
        if logical==64:require(off['engineFrame']==prior_engine,'Light-off was not applied before this actual render')
        data=stem.with_suffix('.bin').read_bytes();require(len(data)==(3+10*len(coordinates))*16,'Compact payload length differs')
        values=list(struct.iter_unpack('<4f',data));controls=values[:3];nodes=[values[3+i*10:3+(i+1)*10] for i in range(len(coordinates))]
        if logical>=64 and not all(known(node[0]) for node in nodes):
            # A retained value after an unknown input is permitted. Do not turn
            # missing zero-input premises into a false product counterexample.
            off_known_closure=False
            report['uncovered'].append({'frame':logical,'reason':'compact off-phase support contains unknown current radiance; subsequent global envelope attribution unavailable'})
        require(controls[2]==(640,360,640,360),'Unexpected full/low dimensions')
        require(controls[1][0]==f32(.08) and controls[1][1]==32 and controls[1][3]==receipt['workFrame'],'Actual bound controls differ')
        require(bool(controls[0][0])==receipt['historyValid'] and bool(controls[1][2])==receipt['hasMotion'],'Actual parameter/CPU receipt differs')
        change_bytes=stem.with_suffix('.changes').read_bytes();require(len(change_bytes)==receipt['changeCount']*48 and controls[0][3]==receipt['changeCount'],'Actual change input count differs')
        regions=list(struct.iter_unpack('<12f',change_bytes));require(all(finite(r) for r in regions),'Nonfinite change inputs')
        plane=qualified.floor_depth_plane(receipt['vp'],640,360);frame={'logical':logical,'workFrame':receipt['workFrame'],'known':0,'unknown':0,'maxHistoryRGB':0,'reactive':0,'historyAgeMinimum':math.inf,'historyAgeMaximum':0}
        for center in centers:
            CONTEXT.update(id=center['id'],pixel=[center['x'],center['y']],workFrame=receipt['workFrame'])
            pixel=(center['x'],center['y']);node=nodes[index[pixel]];raw,hist,mom=node[:3]
            require(finite(raw),'Nonfinite current raw observation')
            position=floor_input(pixel,node[5],receipt,plane);hard,reactive=change_at(position,controls[0],regions)
            frame['reactive']+=int(reactive)
            require(finite(hist+mom),'Nonfinite actual history/moments')
            frame['maxHistoryRGB']=max(frame['maxHistoryRGB'],*hist[:3])
            frame['historyAgeMinimum']=min(frame['historyAgeMinimum'],mom[2]);frame['historyAgeMaximum']=max(frame['historyAgeMaximum'],mom[2])
            response=recovery[('old-color','new-color','light-off')[logical//32]][center['id']]
            if known(raw):
                frame['known']+=1
                if response['firstKnownOffset'] is None:response['firstKnownOffset']=logical%32
                if max(raw[:3])>0 and response['firstKnownPositiveOffset'] is None:response['firstKnownPositiveOffset']=logical%32
                if logical%32==31:response['endpointKnown']=True
                require(min(raw[:3])>=0,'Negative known raw')
                if logical<32:require(raw[0]==2*raw[1] and raw[0]==4*raw[2],'Old source ratio differs')
                elif logical<64:require(raw[2]==2*raw[1] and raw[2]==4*raw[0],'Known post-MPB raw contains stale/wrong source color')
                else:require(raw[:3]==(0,0,0),'Known post-light-off raw is not black')
                if logical<64 and max(raw[:3])>0:positive[logical//32]+=1
            else:
                frame['unknown']+=1;report['unknown'].append({'frame':logical,'id':center['id'],'confidence':raw[3]})
                response['unknownCount']+=1
                if logical in (31,63,95):report['uncovered'].append({'frame':logical,'id':center['id'],'reason':'phase endpoint has no known current estimate'})
            if logical==31:
                if not known(hist) or mom[2]<=2:report['uncovered'].append({'frame':logical,'id':center['id'],'reason':'no established pre-event history age>2'})
            if logical==32:
                require(not hard and reactive,'MPB did not produce the predicted non-geometric floor influence')
                if known(raw) and controls[0][0] and known(node[3]) and node[4][2]>2:
                    if mom[2]==1:report['uncovered'].append({'frame':logical,'id':center['id'],'reason':'history was reset rather than exercising reactive reuse'})
                    else:require(mom[2]==2,'Known valid MPB receiver history was not shortened to2')
                else:report['uncovered'].append({'frame':logical,'id':center['id'],'reason':'MPB reactive-history branch lacks admitted current/previous support'})
            if logical>=64 and known(raw):
                k=logical-64
                if k==0:require(controls[0][1]==1 and not hard,'Directional removal was not globally reactive')
                support=uv_support(pixel,node[5],node[9],receipt,bool(controls[1][2]));declared={coordinates[i] for i in center['rows']}
                require(support<=declared,'Actual nearest/bilinear support leaves the frozen compact footprint')
                closed=True
                for dx,dy in itertools.product((-1,0,1),repeat=2):
                    neighbor=nodes[index[(pixel[0]+dx,pixel[1]+dy)]][0]
                    if not known(neighbor) or neighbor[:3]!=(0,0,0):
                        closed=False;report['uncovered'].append({'frame':logical,'id':center['id'],'reason':'black-current neighborhood lacks complete known support'})
                if k>0 and off_known_closure:
                    for predecessor in support:
                        old,old_mom=nodes[index[predecessor]][3:5]
                        if not known(old) or not finite(old_mom) or old_mom[2]<=0:
                            closed=False;report['uncovered'].append({'frame':logical,'id':center['id'],'reason':'previous interpolation support is not admitted'});continue
                        require(min(old[:3])>=0 and max(old[:3])<=upper[k-1],'Previous support exceeds independent decay envelope')
                        require(old_mom[2]<=min(k+1,32),'Previous support age exceeds the post-reactive horizon')
                if closed and off_known_closure:
                    require(min(hist[:3])>=0 and max(hist[:3])<=upper[k],'History exceeds independent light-off decay envelope')
                    require(0<mom[2]<=min(k+2,32),'Output history age exceeds post-reactive horizon')
            report['checks']+=1
        frame['sha256']={extension:sha(stem.with_suffix(extension)) for extension in ('.json','.bin','.changes')}
        report['frames'].append(frame)
    require(all(v>0 for v in positive),'Lit phases have no positive changed-source consumption coverage')
    report['positiveKnownSamples']=positive
    report['currentResponse']=recovery
    report['passed']=not report['uncovered']
    report['scope']='Finite real floor source response and sufficient permitted temporal decay; not whole-scene quality or performance'
    return report

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('package',type=Path);parser.add_argument('--output',type=Path,required=True);args=parser.parse_args()
    require(not args.output.exists(),'Preserve the first analysis result')
    try:result=analyze(args.package)
    except Exception as error:result={'passed':False,'error':str(error),'context':CONTEXT,'upperBounds':bounds()}
    args.output.write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({'passed':result['passed'],'error':result.get('error'),'checks':result.get('checks')}))
    sys.exit(0 if result['passed'] else 1)
