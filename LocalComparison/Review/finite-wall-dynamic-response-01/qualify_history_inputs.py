"""Additional input-only coverage qualification; never decodes radiance RGB."""
import argparse
from fractions import Fraction as F
from functools import lru_cache
import hashlib
import importlib.util
import json
import math
from pathlib import Path
import struct

HERE=Path(__file__).resolve().parent
ORIGINAL_SHA='f691fd1385bdb39176fee9dd74a42e6934eeb6cbf5ab76125194c05e5c6d6d9e'
SPEC='https://microsoft.github.io/DirectX-Specs/d3d/archive/D3D11_3_FunctionalSpec.htm'
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
assert sha(HERE/'analyze.py')==ORIGINAL_SHA,'The original analysis must remain frozen'
spec=importlib.util.spec_from_file_location('frozen_dynamic_analysis',HERE/'analyze.py')
original=importlib.util.module_from_spec(spec);spec.loader.exec_module(original)
I=original.qualified.Interval
outward=original.qualified.outward

class Uncovered(Exception):pass
def need(value,reason):
    if not value:raise Uncovered(reason)
def finite(values):return all(math.isfinite(value) for value in values)
def union(a,b):return I(min(a.low,b.low),max(a.high,b.high))
def absolute(a):return I(0 if a.low<=0<=a.high else min(abs(a.low),abs(a.high)),max(abs(a.low),abs(a.high)))
def square(a):
    v=absolute(a);low,high=outward(v.low*v.low,v.high*v.high);return I(max(0,low),high)
def dot(a,b):
    products=[x*y for x,y in zip(a,b)];result=products[0]
    for product in products[1:]:result=result+product
    if len(products)==4:result=union(result,(products[0]+products[1])+(products[2]+products[3]))
    return result
def sqrt_interval(a):
    need(a.high>=0,'negative length-squared enclosure')
    # Outward float32 rounding plus one extra ULP covers the specified sqrt
    # error (D3D11.3 section22.10.21), including double endpoint evaluation.
    # Callers pass a sum of squares. Its exact shader value cannot be negative;
    # only the deliberately outward interval arithmetic may extend below zero.
    low,high=outward(F(math.sqrt(float(max(0,a.low)))),F(math.sqrt(float(a.high))))
    return I(max(0,low),high)
def normalize(a):
    length2=square(a[0])+square(a[1])+square(a[2]);need(length2.low>0,'normal length is not proven positive')
    # rsq permits relative error2^-21 (section22.10.19). The extra outward
    # float32 ULP also encloses Python's double endpoint approximation.
    error=F(1,2**21)
    low=F(1/math.sqrt(float(length2.high)))*(1-error)
    high=F(1/math.sqrt(float(length2.low)))*(1+error)
    reciprocal=I(*outward(low,high));return [v*reciprocal for v in a]
def oct_decode(x,y):
    z=I(1)-absolute(x)-absolute(y);t=I(max(-z.high,0),max(-z.low,0))
    folded=[]
    for component in (x,y):
        folded.append(component-t if component.low>=0 else component+t if component.high<0 else union(component-t,component+t))
    return normalize([*folded,z])
def normals(geometry):
    need(finite(geometry) and all(abs(v)<=1 for v in geometry[:2]),'invalid encoded screen geometry')
    code=geometry[2];need(1<=code<=2**24 and code==math.floor(code),'geometric normal is unknown')
    need(1e-6<geometry[3]<=1,'invalid reversed-Z receiver depth')
    shading=oct_decode(I(geometry[0]),I(geometry[1]));bits=int(code)-1
    factor=I(*outward(F(2,4095),F(2,4095)))
    geometric=oct_decode(I(bits&4095)*factor-1,I(bits>>12)*factor-1)
    return shading,geometric
@lru_cache(maxsize=16)
def floor_plane(vp):return original.qualified.floor_depth_plane(vp,640,360)
def floor_position(pixel,geometry,receipt,previous=False):
    vp=receipt['previousVP' if previous else 'vp'];inv=receipt['previousInvVP' if previous else 'invVP']
    need(len(vp)==len(inv)==16 and finite(vp+inv),'invalid camera matrix input')
    try:
        plane=floor_plane(tuple(vp));return original.floor_input(pixel,geometry,{'invVP':inv},plane)
    except (AssertionError,ArithmeticError,ValueError,StopIteration) as error:raise Uncovered('floor input cannot be proved: '+str(error)) from error
def history_present(node,previous=False):
    confidence=node['previousConfidence' if previous else 'outputConfidence'];moments=node['previousMoments' if previous else 'outputMoments']
    need(math.isfinite(confidence) and confidence>0,'previous history confidence invalid' if previous else 'current history confidence invalid')
    need(node['previousRGBFinite' if previous else 'outputRGBFinite'],'previous history RGB has a nonfinite bit pattern' if previous else 'current history RGB has a nonfinite bit pattern')
    need(finite(moments) and moments[2]>0,'previous history moments invalid' if previous else 'current history moments invalid')
def qualify_one(pixel,declared,nodes,receipt,controls,settings,logical):
    result={'qualified':False,'classification':'uncovered','support':[]}
    try:
        need(pixel in nodes,'current sample missing');node=nodes[pixel]
        need(math.isfinite(node['rawConfidence']) and node['rawConfidence']>0,'current raw estimate is unknown')
        need(node['rawRGBFinite'],'current raw RGB has a nonfinite bit pattern')
        history_present(node)
        need(controls[0][0]==1,'global history receipt is invalid; current-only output is allowed')
        need(not settings.get('receiverObjectHistory',False),'identity mode is outside this legacy qualification')
        need(controls[1][2] in (0,1),'invalid motion presence input')
        need(finite(node['motion']),'motion contains nonfinite inputs')
        try:
            support=original.uv_support(pixel,node['geometry'],node['motion'],receipt,bool(controls[1][2]))
        except (AssertionError,ArithmeticError,ValueError,OverflowError) as error:
            raise Uncovered('previous UV/support cannot be proved: '+str(error)) from error
        result['support']=[list(p) for p in sorted(support)]
        need(support<=declared and support<=nodes.keys(),'previous nearest/bilinear support is unavailable')
        position=floor_position(pixel,node['geometry'],receipt);ns,ng=normals(node['geometry'])
        view=receipt['view'];need(len(view)==16 and finite(view),'invalid view matrix')
        view_depth=absolute(dot([I(view[2+4*c]) for c in range(4)],position+[I(1)]))
        threshold=original.f32(settings['relativeDepthThreshold']);normal_threshold=original.f32(settings['normalThreshold'])
        tolerance=I(threshold)*I(max(1,view_depth.low),max(1,view_depth.high))
        need(tolerance.low>0,'depth threshold is not proven positive')
        require_age=2 if logical==32 else 0
        margins={'distance':math.inf,'currentPlane':math.inf,'previousPlane':math.inf,'Ns':math.inf,'Ng':math.inf,'material':math.inf}
        for predecessor in sorted(support):
            old=nodes[predecessor];history_present(old,True)
            need(old['previousMoments'][2]>require_age,'pre-event predecessor does not have established age>2')
            old_position=floor_position(predecessor,old['previousGeometry'],receipt,True);old_ns,old_ng=normals(old['previousGeometry'])
            delta=[a-b for a,b in zip(position,old_position)]
            distance=sqrt_interval(square(delta[0])+square(delta[1])+square(delta[2]))
            current_plane=absolute(dot(delta,ng));previous_plane=absolute(dot(delta,old_ng))
            ns_dot=dot(ns,old_ns);ng_dot=dot(ng,old_ng)
            need(finite(node['material']) and finite(old['previousMaterial']),'material input is nonfinite')
            material=max(float(absolute(I(a)-I(b)).high) for a,b in zip(node['material'][:3],old['previousMaterial'][:3]))
            values={'distance':float(tolerance.low-distance.high),'currentPlane':float(tolerance.low-current_plane.high),
                    'previousPlane':float(tolerance.low-previous_plane.high),'Ns':float(ns_dot.low-F(normal_threshold)),
                    'Ng':float(ng_dot.low-F(original.f32(.85))),'material':original.f32(.1)-material}
            for name,value in values.items():
                margins[name]=min(margins[name],value);need(value>0,'previous support '+name+' gate is not strictly proved')
        if logical==32:need(node['outputMoments'][2]!=1,'current-only reset does not prove reactive reuse')
        result.update(qualified=True,classification='qualified',minimumMargins=margins,
                      currentHistoryConfidence=node['outputConfidence'],currentHistoryAge=node['outputMoments'][2])
    except (Uncovered,ArithmeticError,ValueError,AssertionError) as error:
        result['reason']=str(error)
    return result

def decode_inputs(data,count):
    if len(data)!=(3+10*count)*16:raise ValueError('compact ABI size differs')
    controls=[struct.unpack_from('<4f',data,i*16) for i in range(3)];nodes=[]
    for index in range(count):
        base=(3+10*index)*16
        # Deliberately never unpack RGB in rows0/1/3: only confidence is read.
        vector=lambda row:struct.unpack_from('<4f',data,base+row*16)
        alpha=lambda row:struct.unpack_from('<f',data,base+row*16+12)[0]
        finite_bits=lambda row:all(bits&0x7f800000!=0x7f800000 for bits in struct.unpack_from('<3I',data,base+row*16))
        nodes.append(dict(rawConfidence=alpha(0),outputConfidence=alpha(1),outputMoments=vector(2),previousConfidence=alpha(3),previousMoments=vector(4),
                          rawRGBFinite=finite_bits(0),outputRGBFinite=finite_bits(1),previousRGBFinite=finite_bits(3),
                          geometry=vector(5),previousGeometry=vector(6),material=vector(7),previousMaterial=vector(8),motion=vector(9)[:2]))
    return controls,nodes
def qualify_package(package,original_report):
    native=package/'native';selection=original.load(native/'selection.json');settings=original.load(native/'scene-inputs.json')['settings']
    coordinates=[(v['x'],v['y']) for v in selection['coordinates']]
    if len(set(coordinates))!=len(coordinates) or len(selection['selection'])!=27:raise ValueError('selection ABI differs')
    original_result=original.load(original_report)
    if original.f32(settings['relativeDepthThreshold'])!=original.f32(.015) or original.f32(settings['normalThreshold'])!=original.f32(.9):raise ValueError('Frozen geometry thresholds differ')
    if original_result.get('upperBounds')!=original.bounds():raise ValueError('Original response bounds differ')
    report=dict(qualified=False,combinedAccepted=False,radianceRGBDecoded=False,radianceRGBFiniteBitsChecked=True,
        originalAnalysisSha256=sha(HERE/'analyze.py'),originalReportSha256=sha(original_report),originalPassed=original_result.get('passed',False),
        originalAnalysisSourceManifestSha256=sha(package/'instrumentation/analysis-source.json'),
        unchangedUpperBounds=original.bounds(),sourceSpecification=SPEC,qualifiedSamples=0,uncoveredSamples=0,frames=[])
    for logical in [32,*range(64,96)]:
        stem=native/f'frame-{logical:03d}';receipt=original.load(stem.with_suffix('.json'))
        if not receipt['complete'] or receipt.get('error') or receipt['logicalFrame']!=logical:raise ValueError('native input receipt incomplete')
        analyzed=original_result['frames'][logical]
        if analyzed['logical']!=logical or any(sha(stem.with_suffix(extension))!=analyzed['sha256'][extension] for extension in ('.json','.bin','.changes')):raise ValueError('Inputs differ from the original analyzed observation')
        controls,values=decode_inputs(stem.with_suffix('.bin').read_bytes(),len(coordinates));nodes=dict(zip(coordinates,values))
        frame={'logical':logical,'inputReceiptSha256':sha(stem.with_suffix('.json')),'inputBufferSha256':sha(stem.with_suffix('.bin')),'samples':[]}
        for selected in selection['selection']:
            pixel=(selected['x'],selected['y']);declared={coordinates[index] for index in selected['rows']}
            result=qualify_one(pixel,declared,nodes,receipt,controls,settings,logical);result['id']=selected['id'];result['pixel']=list(pixel)
            frame['samples'].append(result);report['qualifiedSamples' if result['qualified'] else 'uncoveredSamples']+=1
        report['frames'].append(frame)
    report['qualified']=report['qualifiedSamples']==891 and report['uncoveredSamples']==0
    report['combinedAccepted']=report['qualified'] and report['originalPassed']
    report['scope']='Additional coverage gates only; unprovable correspondence/invalid history is uncovered. Original physical color and temporal bounds are unchanged.'
    return report

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('package',type=Path);parser.add_argument('--original-analysis',type=Path,required=True);parser.add_argument('--output',type=Path,required=True);args=parser.parse_args()
    if args.output.exists():raise ValueError('Preserve the first qualification result')
    try:result=qualify_package(args.package,args.original_analysis)
    except Exception as error:result={'qualified':False,'combinedAccepted':False,'error':str(error),'radianceRGBDecoded':False}
    args.output.parent.mkdir(parents=True,exist_ok=True);args.output.write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({key:result.get(key) for key in ('qualified','combinedAccepted','qualifiedSamples','uncoveredSamples','error')}))
    raise SystemExit(0 if result['combinedAccepted'] else 1)
