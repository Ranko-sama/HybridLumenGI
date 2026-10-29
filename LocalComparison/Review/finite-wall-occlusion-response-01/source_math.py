"""Source-only plane visibility; no measured radiance, hit or cache answers."""
from fractions import Fraction as F
import hashlib,importlib.util,math,struct
from pathlib import Path
P=Path(__file__).resolve().parent
DYNAMIC=P.parent/'finite-wall-dynamic-response-01'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
assert sha(DYNAMIC/'qualify_history_inputs.py')=='0f323f6488959d682e512a72792e36bed0c1857f0234ab86cf3b3bdb47febce7'
spec=importlib.util.spec_from_file_location('frozen_history_qualification',DYNAMIC/'qualify_history_inputs.py')
qualification=importlib.util.module_from_spec(spec);spec.loader.exec_module(qualification)
old=qualification.original;I=qualification.I;Uncovered=qualification.Uncovered;need=qualification.need
f32=old.f32
PANEL_Y=(F(f32(-.1)),F(f32(2.1)));PANEL_Z=(F(f32(-2.1)),F(f32(2.1)))
def universal_block(origin):
    """Every direction reaching the finite wall crosses the interior black panel."""
    need(len(origin)==3 and all(math.isfinite(v) for v in origin),'origin unavailable')
    return universal_box([I(v) for v in origin])
def universal_box(o):
    need(o[0].low>F(1,4),'receiver is not beyond panel')
    weight=(o[0]-F(1,4))/o[0]
    need(0<weight.low<=weight.high<1,'panel is not strictly between origin and wall')
    wall=[I(0),I(0,2),I(-2,2)]
    hit=[o[i]*(I(1)-weight)+wall[i]*weight for i in range(3)]
    need(PANEL_Y[0]<hit[1].low and hit[1].high<PANEL_Y[1] and PANEL_Z[0]<hit[2].low and hit[2].high<PANEL_Z[1],
         'entire finite wall does not have proven interior panel coverage')
    return dict(y=hit[1].values(),z=hit[2].values(),fraction=weight.values())
def support_block(pixel,node,receipt):
    position=qualification.floor_position(pixel,node[5],receipt)
    # Unknown orientation is not needed: a normalized bias direction has each
    # component <=1. This outward1.00001 covers the existing RSQ float allowance.
    # The whole +/-bias box is deliberately larger than the observed floor Ng.
    qualification.normals(node[5])
    bias=I(f32(.03))*I(-F(100001,100000),F(100001,100000))
    return universal_box([v+bias for v in position])
def wall_direction(origin,direction):
    need(len(direction)==3 and all(math.isfinite(v) for v in direction),'direction unavailable')
    o=[I(v) for v in origin];d=[I(v) for v in direction]
    if d[0].low>=0:return {'classification':'miss'}
    need(d[0].high<0,'wall-parallel branch is ambiguous')
    t=-o[0]/d[0]
    if t.high<=0 or t.low>=20:return {'classification':'miss'}
    need(0<t.low<=t.high<20,'distance boundary is ambiguous')
    q=[o[i]+t*d[i] for i in range(3)]
    if q[1].high<0 or q[1].low>2 or q[2].high<-2 or q[2].low>2:return {'classification':'miss'}
    need(0<q[1].low and q[1].high<2 and -2<q[2].low and q[2].high<2,'finite wall edge is ambiguous')
    tp=(I(F(1,4))-o[0])/d[0];p=[o[i]+tp*d[i] for i in range(3)]
    need(0<tp.low and tp.high<t.low,'panel/wall ordering is not proved')
    need(PANEL_Y[0]<p[1].low and p[1].high<PANEL_Y[1] and PANEL_Z[0]<p[2].low and p[2].high<PANEL_Z[1],
         'sampled wall ray is not strictly blocked by the panel')
    return {'classification':'blocked-wall-direction','wallDistance':t.values(),'panelDistance':tp.values()}
def sampling_receipt(receipt,selection):
    result=dict(receipt,fullWidth=640,fullHeight=360,rays=8,rayBias=f32(.03),groupCount=27,rawFormat='R16G16B16A16_SFloat')
    selected=[]
    for center in selection:
        group,dx,dy=center['id'].replace('receiver','').split('_')
        selected.append(dict(center,authoredTarget=[(.5,1.,2.)[int(group)],0,0],offsetX=int(dx),offsetY=int(dy)))
    result['selection']=selected;return result
def qualify_directions(data,receipt,selection):
    # Reuse the unchanged raster-aware source reconstruction and sampler ABI.
    qualified=old.qualified.qualify(data,sampling_receipt(receipt,selection))
    result=[]
    for group in qualified['groups']:
        universal=universal_block(group['origin'])
        rays=[wall_direction(group['origin'],d) for d in group['directions']]
        result.append(dict(id=group['id'],pixel=group['pixel'],origin=group['origin'],depth=group['rawDepth'],
            universal=universal,wallDirections=sum(r['classification']=='blocked-wall-direction' for r in rays),rays=rays))
    return result
def matrix_x(values,x):
    return len(values)==16 and all(v==f32(x if i==12 else 1 if i%5==0 else 0) for i,v in enumerate(values))
def physical_raw(raw,covered):
    old.require(old.finite(raw),'Nonfinite current raw')
    if not old.known(raw):return 'unknown'
    old.require(min(raw[:3])>=0,'Negative known raw')
    if covered:old.require(tuple(raw[:3])==(0,0,0),'Known raw remains nonblack after authored panel entry (GPU pose currency is not an exemption)')
    else:old.require(raw[0]==2*raw[1] and raw[0]==4*raw[2],'Known raw source ratio differs')
    return 'known-black' if max(raw[:3])==0 else 'known-positive'
def qualify_geometry(receipt,instances,poses,triangles,logical):
    """Close source arrays to actual bound instance/pose/triangle data, not RTAS hits."""
    old.require(len(instances)==3*128 and len(poses)==3*64 and len(triangles)==6*96,'Exact geometry payload ABI differs')
    sources={s['stableId']:s for s in receipt['sources']};old.require(len(sources)==3,'Source owner IDs differ')
    x=.25 if 32<=logical<44 else 20
    expected={'ReferenceWall':(0,[.5,.25,.125,1],[[0,0,-2],[0,2,-2],[0,2,2],[0,0,2]]),
              'ReferenceFloor':(0,[1,1,1,1],[[0,0,-3],[0,0,3],[5,0,3],[5,0,-3]]),
              'MovingBlackPanel':(x,[0,0,0,1],[[0,-.1,-2.1],[0,2.1,-2.1],[0,2.1,2.1],[0,-.1,2.1]])}
    seen=set();panel=None
    for i in range(3):
        offset=i*128;slot,first,count,submesh,stable,revision,geometry,cull=struct.unpack_from('<8I',instances,offset+64)
        old.require(stable in sources and stable not in seen,'Instance source identity missing/duplicate');seen.add(stable);s=sources[stable]
        old.require(s['name'] in expected,'Unexpected source renderer');tx,color,vertices=expected[s['name']]
        old.require(matrix_x(s['matrix'],tx),'Actual CPU source transform differs from the event')
        gpu_pose=struct.unpack_from('<16f',poses,i*64)
        current_pose=matrix_x(gpu_pose,tx)
        old.require(current_pose or s['name']=='MovingBlackPanel' and (matrix_x(gpu_pose,20) or matrix_x(gpu_pose,.25)),
                    'Bound source pose is neither the current nor previous authored panel pose')
        old.require(old.vec(s['shaderLinearColor'],'xyzw')==color,'Unrequested source MPB change')
        current_generation=revision==s['revision'] and geometry==s['geometryRevision']
        old.require(submesh==0 and count==2 and cull==2 and first+count<=6,'Instance topology/cull differs')
        for j,indices in enumerate(((0,1,2),(0,2,3))):
            for k,index in enumerate(indices):
                actual=struct.unpack_from('<4f',triangles,(first+j)*96+k*16)
                old.require(actual==tuple([*[f32(v) for v in vertices[index]],1]),'Bound triangle source differs')
        if s['name']=='MovingBlackPanel':panel=dict(stableId=stable,revision=revision,geometryRevision=geometry,slot=slot,x=gpu_pose[12],sourceX=tx,current=current_pose and current_generation)
        else:old.require(current_generation,'Unchanged wall/floor source generation differs')
    old.require(panel is not None,'Panel has no bound instance')
    return panel
