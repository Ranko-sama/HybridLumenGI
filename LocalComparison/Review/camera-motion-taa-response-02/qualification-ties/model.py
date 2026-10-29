"""Input-only correspondence proofs for the fixed camera/TAA experiment.

No current output or radiance RGB enters this module. Raster consistency is
conditional on the declared planar source model, not a universal raster-error
certificate. Boundaries which cannot be separated are deliberately uncovered.
"""
from fractions import Fraction as F
from functools import lru_cache
import math
import itertools
from pathlib import Path
import struct
import sys

ROOT=Path(__file__).resolve().parents[4]
sys.path.insert(0,str(ROOT/'LocalComparison/Reference/ColorBounceRectangle'))
import qualify_native_inputs as raster

SIZE=(640,360)
SNAP=raster.SNAP
RCP=F(1,2**21)
f32=raster.f32

class Uncovered(Exception): pass
def need(value,message):
    if not value: raise Uncovered(message)
def finite(values): return all(math.isfinite(v) for v in values)

class I:
    def __init__(self,low,high=None): self.low,self.high=F(low),F(low if high is None else high)
    def values(self): return [float(self.low),float(self.high)]
    def contains(self,value): return math.isfinite(value) and self.low<=F(value)<=self.high
    @staticmethod
    def of(v): return v if isinstance(v,I) else I(v)
    @staticmethod
    def rounded(low,high): return I(*raster.outward(low,high))
    def __neg__(self): return I(-self.high,-self.low)
    def __add__(self,o):
        o=I.of(o);return I.rounded(self.low+o.low,self.high+o.high)
    __radd__=__add__
    def __sub__(self,o): return self+-I.of(o)
    def __mul__(self,o):
        o=I.of(o);v=[a*b for a in (self.low,self.high) for b in (o.low,o.high)]
        return I.rounded(min(v),max(v))
    __rmul__=__mul__
    def __truediv__(self,o):
        o=I.of(o);need(not o.low<=0<=o.high,'division crosses zero')
        v=[a/b for a in (self.low,self.high) for b in (o.low,o.high)]
        direct=I.rounded(min(v),max(v))
        v=[F(1)/v for v in (o.low,o.high)]
        v=[a*b for a in v for b in (1-RCP,1+RCP)]
        lowered=self*I.rounded(min(v),max(v))
        return union(direct,lowered)

def union(a,b):return I(min(a.low,b.low),max(a.high,b.high))
def absolute(a):return I(0 if a.low<=0<=a.high else min(abs(a.low),abs(a.high)),max(abs(a.low),abs(a.high)))
def square(a):
    a=absolute(a);lo,hi=raster.outward(a.low*a.low,a.high*a.high);return I(max(0,lo),hi)
def dot(a,b):
    p=[I.of(x)*I.of(y) for x,y in zip(a,b)];s=p[0]
    for v in p[1:]:s=s+v
    if len(p)==4:s=union(s,(p[0]+p[1])+(p[2]+p[3]))
    return s
def sqrt(a):
    need(a.high>=0,'negative squared length')
    lo,hi=raster.outward(F(math.sqrt(float(max(0,a.low)))),F(math.sqrt(float(a.high))))
    return I(max(0,lo),hi)
def normalize(a):
    d=square(a[0])+square(a[1])+square(a[2]);need(d.low>0,'nonpositive normal length')
    rsq=I.rounded(F(1/math.sqrt(float(d.high)))*(1-RCP),F(1/math.sqrt(float(d.low)))*(1+RCP))
    return [v*rsq for v in a]
def oct_decode(x,y):
    z=I(1)-absolute(x)-absolute(y);t=I(max(-z.high,0),max(-z.low,0));out=[]
    for v in (x,y):out.append(v-t if v.low>=0 else v+t if v.high<0 else union(v-t,v+t))
    return normalize(out+[z])
def normals(g):
    need(finite(g) and all(abs(v)<=1 for v in g[:2]) and 1e-6<g[3]<=1,'invalid receiver geometry')
    need(1<=g[2]<=2**24 and int(g[2])==g[2],'unknown geometric normal')
    bits=int(g[2])-1;scale=I(f32(2/4095))
    return oct_decode(I(g[0]),I(g[1])),oct_decode(I(bits&4095)*scale-1,I(bits>>12)*scale-1)

def columns(rows): return [rows[r][c] for c in range(4) for r in range(4)]
def mul(m,p): return [dot([I(m[r+4*c]) for c in range(4)],p) for r in range(4)]
def unproject(m,pixel,depth,spread=F(0)):
    uv=[I(F(2*pixel[a]+1,2)-spread,F(2*pixel[a]+1,2)+spread)/SIZE[a] for a in range(2)]
    p=mul(m,[uv[0]*2-1,-(uv[1]*2-1),I.of(depth),I(1)])
    return [v/p[3] for v in p[:3]]
def project(m,p):
    clip=mul(m,p+[I(1)]);need(clip[3].low>0,'nonpositive projected w')
    return [clip[0]/clip[3]*.5+.5,I(1)-(clip[1]/clip[3]*.5+.5)],clip[3]

# Source rectangles, deliberately independent of sampled texture geometry.
RECTS={
    'floor':dict(axis=1,value=0,normal=(0,1,0),bounds=((0,5),(0,0),(-3,3)),oct=(0,1)),
    'panel':dict(axis=2,value=f32(-.2),normal=(0,0,-1),bounds=((f32(.4),f32(1.8)),(0,f32(1.8)),(f32(-.2),f32(-.2))),oct=(1,1)),
    'wall':dict(axis=0,value=0,normal=(1,0,0),bounds=((0,0),(0,2),(-2,2)),oct=(1,0))}

@lru_cache(maxsize=160)
def plane(vp,owner):
    s=RECTS[owner];inv=raster.inverse(vp)
    q=[inv[s['axis']][c]-F(s['value'])*inv[3][c] for c in range(4)]
    need(q[2]!=0,'projected plane is edge-on')
    return -2*q[0]/(q[2]*SIZE[0]),2*q[1]/(q[2]*SIZE[1]),(q[0]-q[1]-q[3])/q[2]

def surface(pixel,g,r,owner,previous=False):
    vp=r['previousVP' if previous else 'vp'];ivp=r['previousInvVP' if previous else 'invVP']
    s=RECTS[owner];ns,ng=normals(g)
    need(tuple(g[:2])==s['oct'],'shading normal differs from source '+owner)
    a,b,c=plane(tuple(vp),owner);d=a*F(2*pixel[0]+1,2)+b*F(2*pixel[1]+1,2)+c
    snap=(abs(a)+abs(b))*SNAP;enclosure=I.rounded(d-snap,d+snap)
    need(enclosure.contains(g[3]),'depth not in source '+owner+' raster interval')
    p=unproject(ivp,pixel,g[3]);need(dot(ng,[I(x) for x in s['normal']]).low>F(.99),'geometric normal differs from source')
    for axis,(lo,hi) in enumerate(s['bounds']):
        if axis!=s['axis']:need(p[axis].low>lo and p[axis].high<hi,'receiver near finite source edge')
    return p,ns,ng

def ray_owner(pixel,r,previous=False):
    """Closest source rectangle for every ray in a normative snap-width box."""
    ivp=r['previousInvVP' if previous else 'invVP']
    start=unproject(ivp,pixel,1,SNAP);end=unproject(ivp,pixel,0,SNAP);direction=[b-a for a,b in zip(start,end)]
    hits=[]
    for name,s in RECTS.items():
        axis=s['axis']
        if direction[axis].low<=0<=direction[axis].high:raise Uncovered('source ray is parallel/ambiguous')
        t=(I(s['value'])-start[axis])/direction[axis]
        if t.high<=0:continue
        need(t.low>0,'source intersection near clip boundary')
        hit=[a+b*t for a,b in zip(start,direction)]
        outside=False;inside=True
        for j,(lo,hi) in enumerate(s['bounds']):
            if j==axis:continue
            outside|=hit[j].high<lo or hit[j].low>hi
            inside&=hit[j].low>lo and hit[j].high<hi
        if outside:continue
        need(inside,'source rectangle silhouette ambiguous')
        hits.append((name,t))
    need(bool(hits),'no authored surface')
    hits.sort(key=lambda row:row[1].low)
    need(all(hits[0][1].high<t.low for _,t in hits[1:]),'source intersection order ambiguous')
    return hits[0][0]

def same_primitive(a,b):return a[3]==b[3]==1 and a[2]>0 and any(a[:2]) and a[:3]==b[:3]
def source_primitive(owner,p):
    # All authored meshes use [0,1,2,0,2,3], hence primitive+1 is fixed by
    # which side of diagonal 0->2 contains the independent world position.
    if owner=='floor':u=p[0]/5;v=(p[2]+3)/6
    elif owner=='panel':u=(p[0]-f32(.4))/I(f32(1.8)-f32(.4));v=p[1]/f32(1.8)
    else:u=(p[2]+2)/4;v=p[1]/2
    difference=v-u
    need(difference.low>0 or difference.high<0,'source primitive diagonal ambiguous')
    return 1 if difference.low>0 else 2
def identity(node):
    key=node['identity'];c=node['candidate'];row=node['objectKey']
    need(key[3]==1 and key[2]>0 and any(key[:2]),'current identity invalid')
    need(0<c[0]<=c[3]==3 and c[1]==0 and c[2]==key[2] and row[:2]==key[:2] and row[2]&1,'candidate/source row is not valid')
    need(node['transform']==[[float(i==j) for j in range(4)] for i in range(4)],'static receiver currentToPrevious is not identity')

def support(pixel,node,r):
    p,ns,ng=surface(pixel,node['geometry'],r,'floor');identity(node)
    need(node['identity'][2]==source_primitive('floor',p),'current identity primitive differs from authored triangle')
    # Actual identity shader multiplies by the verified identity matrix first.
    expected=mul(columns(node['transform']),p+[I(1)])[:3]
    pose,w=project(r['previousVP'],expected)
    motion=[I(F(2*pixel[a]+1,2))/SIZE[a]-I(node['motion'][a])+I(r['jitterDelta'][a]) for a in range(2)]
    need(all(pose[a].contains(node['poseUV'][a]) for a in range(2)) and w.contains(node['clipW']),'observer static-pose projection not enclosed')
    need(all(motion[a].contains(node['motionUV'][a]) for a in range(2)),'observer motion UV not enclosed')
    need(all(absolute(motion[a]-pose[a]).high*SIZE[a]<1 for a in range(2)),'identity motion branch not strictly proved')
    nearest_axes=[];lower=[]
    for axis,uv in enumerate(motion):
        need(0<uv.low<=uv.high<1,'reprojected UV outside image')
        t=uv*SIZE[axis]
        # Preserve every possible nearest address, including rounded-distance
        # ties. Actual ClosestGiPixel prefers the smaller index at equality;
        # the observer's floor hint is not that rule. A candidate can win only
        # if its distance lower bound is <= every competitor's upper bound.
        candidates=range(max(0,math.floor(t.low)-1),min(SIZE[axis]-1,math.floor(t.high)+1)+1)
        distances={i:absolute(I(F(2*i+1,2))-t) for i in candidates}
        best_upper=min(d.high for d in distances.values())
        possible=[i for i,d in distances.items() if d.low<=best_upper]
        need(bool(possible) and len(possible)<=2,'nearest candidate set is too wide')
        nearest_axes.append(possible)
        lower_axis=t-.5;llo,lhi=math.floor(lower_axis.low),math.floor(lower_axis.high)
        need(llo==lhi and lower_axis.low>llo and lower_axis.high<llo+1,'bilinear footprint boundary is ambiguous')
        lower.append(llo)
    nearest=set(itertools.product(*nearest_axes))
    addresses=[(lower[0]+x,lower[1]+y) for y in range(2) for x in range(2)]
    for slot,(address,old) in enumerate(zip(addresses,node['prior'][1:]),1):
        need(old['pixel']==address and old['slot']==slot and old['inBounds']==1,'copied bilinear address differs')
    hint=node['prior'][0]
    need(hint['slot']==0 and hint['inBounds']==1,'floor-address observation is invalid')
    # Check the observer's stated address against its own observed UV, without
    # substituting that UV for the independently enclosed temporal expression.
    hint_axes=[]
    for axis in range(2):
        t=I(node['motionUV'][axis])*SIZE[axis]
        hint_axes.append(range(math.floor(t.low),math.floor(t.high)+1))
    need(hint['pixel'] in set(itertools.product(*hint_axes)),'floor hint is inconsistent with observer UV')
    covered={old['pixel'] for old in node['prior']}
    need(nearest<=covered,'not every possible product nearest input was captured')
    aliases={}
    for old in node['prior']:
        value={key:value for key,value in old.items() if key!='slot'}
        need(old['pixel'] not in aliases or aliases[old['pixel']]==value,'duplicated prior input aliases disagree')
        aliases[old['pixel']]=value
    return dict(position=p,ns=normalize(ns),ng=normalize(ng),addresses=[hint['pixel']]+addresses,
                nearest=sorted(nearest),motion=motion,pose=pose)

def continued_geometry(node,r,proof,threshold,normal_threshold):
    p=proof['position'];ns=proof['ns'];ng=proof['ng']
    v=absolute(dot([I(r['view'][2+4*c]) for c in range(4)],p+[I(1)]))
    tolerance=I(threshold)*I(max(1,v.low),max(1,v.high));margins={}
    for old in node['prior']:
        need(ray_owner(old['pixel'],r,True)=='floor','prior ray does not hit floor')
        op,ons,ong=surface(old['pixel'],old['geometry'],r,'floor',True)
        need(old['identity'][2]==source_primitive('floor',op),'prior identity primitive differs from authored triangle')
        need(same_primitive(node['identity'],old['identity']),'prior primitive differs')
        delta=[a-b for a,b in zip(p,op)]
        checks={'distance':tolerance.low-sqrt(sum((square(v) for v in delta),I(0))).high,
                'currentPlane':tolerance.low-absolute(dot(delta,ng)).high,'previousPlane':tolerance.low-absolute(dot(delta,ong)).high,
                'Ns':dot(ns,ons).low-F(normal_threshold),'Ng':absolute(dot(ng,ong)).low-F(f32(.85)),
                'material':F(f32(.1))-max(absolute(I(a)-I(b)).high for a,b in zip(node['material'][:3],old['material'][:3]))}
        for key,value in checks.items():
            need(value>0,'continued support '+key+' not strictly proved')
            margins[key]=min(margins.get(key,math.inf),float(value))
    return margins

def jitter(r,previous_r):
    # A jittered projection is an NDC XY translation of its nonjittered VP.
    def translation(frame):
        vp=frame['vp'];unj=frame['unjitteredGpuVP'];pivot=max(range(4),key=lambda c:abs(unj[3+4*c]))
        need(unj[3+4*pivot]!=0,'zero homogeneous source row')
        # Solving for the tiny jitter translation must include the rounding of
        # the already stored VP component. A subtraction ULP on the tiny
        # difference alone does not cover cancellation of the two large matrix
        # entries. This is the declared one-ULP source consistency allowance.
        deltas=[(I.rounded(F(vp[a+4*pivot]),F(vp[a+4*pivot]))-I(unj[a+4*pivot]))/I(unj[3+4*pivot]) for a in range(2)]
        for row in range(4):
            for col in range(4):
                predicted=I(unj[row+4*col])+(deltas[row]*I(unj[3+4*col]) if row<2 else I(0))
                need(predicted.contains(vp[row+4*col]),'jitter VP is not a pure XY translation')
        return [deltas[0]*.5,deltas[1]*(-.5)]
    now,old=translation(r),translation(previous_r)
    need(all((old[a]-now[a]).contains(r['jitterDelta'][a]) for a in range(2)),'uploaded jitter delta differs from actual projection change')
    return [v.values() for v in now]

def half_enclosure(v):
    # Signed RTZ/RNE envelope, including negative velocities and exact zero.
    def rne(x):return struct.unpack('<e',struct.pack('<e',float(x)))[0]
    def rtz(x):
        sign=-1 if x<0 else 1;x=abs(x);n=rne(x)
        if n>x:n=struct.unpack('<e',struct.pack('<H',struct.unpack('<H',struct.pack('<e',n))[0]-1))[0]
        return sign*n
    return I(min(rne(v.low),rtz(v.low)),max(rne(v.high),rtz(v.high)))

def motion_source(node,proof,current_nojit,previous_nojit):
    # Independent static-world velocity. This is a source-consistency enclosure
    # for camera/object motion, not an exhaustive varying interpolation proof.
    p=proof['position'];cur,_=project(current_nojit,p);old,_=project(previous_nojit,p)
    enclosure=[half_enclosure(a-b) for a,b in zip(cur,old)]
    need(all(bound.contains(value) for bound,value in zip(enclosure,node['motion'])),'motion inconsistent with static nonjittered matrices / binary16 storage')
    return [v.values() for v in enclosure]
