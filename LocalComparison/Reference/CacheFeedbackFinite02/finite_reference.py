"""Finite real-rectangle ray operator and scattering-order cache recurrence.

Does not import production transport helpers or consume product RGB/hit/PDF data.
It prepares conditional expectations; it does not claim native source closure.
"""
import argparse
import copy
import hashlib
import json
import math
from pathlib import Path

EPS = 2**-23
FORBIDDEN = {'hit','hits','hitCount','pdf','weight','weights','sampleWeight','rgb','radiance','cacheRgb','measured','observed','incoming','outgoing'}


def dot(a,b):
    return sum(x*y for x,y in zip(a,b))


def add(a,b):
    return [x+y for x,y in zip(a,b)]


def scale(a,value):
    return [x*value for x in a]


def vector(value):
    return isinstance(value,list) and len(value)==3 and all(math.isfinite(x) for x in value)


def reject_answers(value):
    if isinstance(value,dict):
        assert not FORBIDDEN.intersection(value), 'Product answer field in independent ray inputs'
        for item in value.values(): reject_answers(item)
    elif isinstance(value,list):
        for item in value: reject_answers(item)


def reflectance(source,owner):
    wall = next(w for w in source['walls'] if w['id']==owner)
    return [source['materials']['diffuseShare']*v for v in wall['shaderLinearBaseColor']]


def validate_source(source):
    assert len(source['walls'])==2 and {w['id'] for w in source['walls']}=={'A','B'}
    settings=source['settings']
    assert settings['cacheGrid']==1 and settings['cardsPerOwner']==1 and settings['cacheBudgetCoversBoth']
    assert settings['feedback']==1 and settings['guideWeight']==settings['emissiveWeight']==settings['areaEmitterCount']==settings['screenSteps']==settings['radianceClamp']==0
    assert settings['environment']==[0,0,0] and source['materials']['emission']==[0,0,0]
    assert source['materials']['ao']==1 and source['materials']['metallic']==0 and source['materials']['diffuseShare']==.96
    assert source['materials']['proxyTint']==[1,1,1] and source['materials']['cull']=='Back' and not source['materials']['maps']
    assert source['light']['linearRgb']==[1,1,1] and source['light']['toLight']==[1,0,0] and not source['light']['shadows']
    for wall in source['walls']:
        assert wall['coordinate']==0 and wall['axis'] in (0,2)
        assert all(0 <= v < .98 for v in reflectance(source,wall['id']))
        assert wall['normal']==[int(i==wall['axis']) for i in range(3)]


def trace(source,origin,direction,max_distance):
    """Nearest authored, front-facing rectangle; edge ambiguity is rejected."""
    assert vector(origin) and vector(direction) and abs(dot(direction,direction)-1)<2e-5
    candidates=[]
    for wall in source['walls']:
        axis=wall['axis'];denominator=direction[axis]
        if denominator>=0: continue  # CullBack; parallel/escaping direction.
        t=(wall['coordinate']-origin[axis])/denominator
        if t<=0 or t>max_distance: continue
        position=add(origin,scale(direction,t))
        guard=64*EPS*max(1,abs(t),*(abs(v) for v in position))
        inside=True
        for coordinate,(low,high) in enumerate(wall['bounds']):
            if coordinate==axis: continue
            if position[coordinate]<low-guard or position[coordinate]>high+guard:
                inside=False;break
            assert low+guard < position[coordinate] < high-guard, 'Rectangle edge classification is ambiguous'
        if inside:
            assert abs(t-max_distance)>guard, 'Finite query endpoint is ambiguous'
            candidates.append(dict(owner=wall['id'],position=position,distance=t))
    candidates.sort(key=lambda row:row['distance'])
    if len(candidates)>1:
        assert candidates[1]['distance']-candidates[0]['distance']>64*EPS*max(1,candidates[0]['distance']), 'Nearest surface is ambiguous'
    return candidates[0] if candidates else None


def cache_support(source,hit,patch):
    # Conditional grid-one full-chart support: the normalized surviving weight
    # is exactly one. Native card/atlas coverage must be certified separately.
    wall=next(w for w in source['walls'] if w['id']==hit['owner'])
    n=wall['normal'];ng=patch['geometricNormal'];bias=source['settings']['rayBias']
    delta=[a-b for a,b in zip(hit['position'],patch['position'])]
    if dot(n,patch['normal'])<.85 or dot(n,ng)<.85 or abs(dot(delta,ng))>max(bias*2,.03):
        return False
    origin=add(hit['position'],scale(n,bias))
    oriented=ng if dot(ng,n)>=0 else scale(ng,-1)
    target=add(patch['position'],scale(oriented,bias))
    connection=[b-a for a,b in zip(origin,target)]
    length=math.sqrt(dot(connection,connection))
    if length<=.0002: return True
    return trace(source,origin,scale(connection,1/length),length-.0001) is None


def merge_orders(destination,orders,weight=1):
    for order,rgb in orders.items():
        destination[order]=add(destination.get(order,[0,0,0]),scale(rgb,weight))


def outgoing_orders(source,hit,patches,old_cache):
    owner=hit['owner'];rho=reflectance(source,owner)
    wall=next(w for w in source['walls'] if w['id']==owner)
    ndl=max(0,dot(wall['normal'],source['light']['toLight']))
    direct=[r*light*ndl for r,light in zip(rho,source['light']['linearRgb'])]
    orders={1:direct} if any(direct) else {}
    if cache_support(source,hit,patches[owner]):
        for order,rgb in old_cache[owner].items():
            orders[order+1]=[r*v*source['settings']['feedback'] for r,v in zip(rho,rgb)]
    return orders


def incident_orders(source,origin,normal,directions,patches,cache):
    assert 1<=len(directions)<=32
    orders={};intersections=[]
    for direction in directions:
        assert dot(normal,direction)>=0, 'Direction leaves authored sampling hemisphere'
        hit=trace(source,origin,direction,source['settings']['maxDistance']) if dot(normal,direction)>0 else None
        intersections.append(hit)
        if hit is not None:
            merge_orders(orders,outgoing_orders(source,hit,patches,cache),1/len(directions))
    return orders,intersections


def public_orders(orders):
    return {str(order):rgb for order,rgb in sorted(orders.items()) if any(rgb)}


def total(orders):
    return [sum(rgb[channel] for rgb in orders.values()) for channel in range(3)]


def build(source,inputs):
    validate_source(source);reject_answers(inputs)
    assert inputs['schemaVersion']==1 and len(inputs['frames'])==2
    patches={p['owner']:p for p in inputs['patches']}
    assert set(patches)=={'A','B'}
    for owner,patch in patches.items():
        wall=next(w for w in source['walls'] if w['id']==owner)
        for key in ('position','normal','geometricNormal','origin'): assert vector(patch[key])
        assert patch['normal']==wall['normal'] and abs(dot(patch['geometricNormal'],patch['geometricNormal'])-1)<2e-5
        assert abs(patch['position'][wall['axis']]-wall['coordinate'])<=64*EPS
        for axis,(low,high) in enumerate(wall['bounds']):
            if axis!=wall['axis']: assert low<patch['position'][axis]<high
        toward=patch['geometricNormal'] if dot(patch['geometricNormal'],patch['normal'])>=0 else scale(patch['geometricNormal'],-1)
        predicted=add(patch['position'],scale(toward,source['settings']['rayBias']))
        assert math.dist(predicted,patch['origin'])<=64*EPS, 'Native biased patch origin mismatch'
    samples=copy.deepcopy(inputs['initialSampleCounts'])
    assert set(samples)==set(patches) and all(isinstance(v,int) and 0<=v<=32 for v in samples.values())
    mode=inputs['initialState']
    assert mode in ('measuredBlack','coldZeroStorage')
    assert all(v>=1 if mode=='measuredBlack' else v==0 for v in samples.values())
    cache={owner:{} for owner in patches};frames=[]
    for index,frame in enumerate(inputs['frames']):
        assert frame['globalGeometryChange']==0 and frame['globalReactive'] in (0,1)
        assert set(frame['patchDirections'])==set(patches)
        old=copy.deepcopy(cache);old_samples=copy.deepcopy(samples);next_cache={};records={}
        for owner,patch in patches.items():
            prepared=min(old_samples[owner],1) if frame['globalReactive'] else old_samples[owner]
            count=min(prepared+1,32);alpha=max(1/count,.1) if prepared>0 else 1
            estimate,hits=incident_orders(source,patch['origin'],patch['normal'],frame['patchDirections'][owner],patches,old)
            updated={};merge_orders(updated,old[owner],1-alpha);merge_orders(updated,estimate,alpha)
            next_cache[owner]=updated;samples[owner]=count
            records[owner]=dict(oldSamples=old_samples[owner],preparedSamples=prepared,samples=count,alpha=alpha,
                                old=total(old[owner]),estimate=total(estimate),new=total(updated),
                                byScatteringOrder=public_orders(updated),independentIntersections=hits)
        cache=next_cache
        frames.append(dict(positiveUpdate=index+1,workFrame=frame['workFrame'],readBuffer=frame['readBuffer'],writeBuffer=frame['writeBuffer'],patches=records))
        assert frame['readBuffer']!=frame['writeBuffer']
        if index: assert frame['readBuffer']==inputs['frames'][index-1]['writeBuffer'] and frame['writeBuffer']==inputs['frames'][index-1]['readBuffer']
    gathers=[]
    for group in inputs['gather']:
        assert group['workFrame']==inputs['frames'][-1]['workFrame']
        owner=group['receiverOwner'];normal=next(w['normal'] for w in source['walls'] if w['id']==owner)
        orders,hits=incident_orders(source,group['origin'],normal,group['directions'],patches,cache)
        rho=reflectance(source,owner)
        visible={order+1:[r*v for r,v in zip(rho,rgb)] for order,rgb in orders.items()}
        gathers.append(dict(id=group['id'],rawExpected=total(orders),rawByScatteringOrder=public_orders(orders),
                            receiverDiffuseOnlyExpected=total(visible),receiverDiffuseOnlyByScatteringOrder=public_orders(visible),
                            independentIntersections=hits))
    return dict(schemaVersion=1,status='conditional independent finite oracle; no native execution or source closure',
                signal=source['signal'],initialState=mode,frames=frames,gather=gathers,
                maximumPreReceiverScatteringOrders=dict(cacheAfterFirst=1,cacheAfterSecond=2,gatherAfterSecond=3),
                maximumIncludingVisibleReceiver=4,
                pendingNativePrerequisites=['Source atlas geometric/card support independently certified','Initial measured RGB separately verified exactly black','actual masks, tags, generations, epoch, global changes and two-buffer order proven','floating-point/storage comparison bound frozen before native colors'],
                nativeAccepted=False)


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--source',type=Path,default=Path(__file__).with_name('source-contract.json'))
    parser.add_argument('--inputs',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args()
    source_bytes,input_bytes=args.source.read_bytes(),args.inputs.read_bytes()
    result=build(json.loads(source_bytes),json.loads(input_bytes))
    result.update(sourceSha256=hashlib.sha256(source_bytes).hexdigest(),inputSha256=hashlib.sha256(input_bytes).hexdigest(),referenceSha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest())
    with args.output.open('x',encoding='utf8') as stream: json.dump(result,stream,indent=2)
    print(json.dumps(dict(output=str(args.output),updates=len(result['frames']),gathers=len(result['gather']),nativeAccepted=False)))


if __name__=='__main__': main()
