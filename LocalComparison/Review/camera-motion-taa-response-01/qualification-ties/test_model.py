"""Small source/ABI/negative controls; no native files or RGB fitting."""
import copy
import math
import struct
import unittest
import analyze
import model as m

def camera(x):
    eye=[x,3,-3];forward=[-2,-2.6,3]
    def unit(v):
        d=math.sqrt(sum(x*x for x in v));return [x/d for x in v]
    def cross(a,b):return [a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]]
    forward=unit(forward);right=unit(cross([0,1,0],forward));up=cross(forward,right)
    scale=1/math.tan(math.radians(25));n=.05;f=30
    def row(v,k):return [k*a for a in v]+[-k*sum(a*b for a,b in zip(v,eye))]
    rows=[row(right,scale/(640/360)),row(up,-scale),row(forward,-n/(f-n)),row(forward,1)]
    rows[2][3]+=f*n/(f-n)
    vp=[m.f32(v) for v in m.columns(rows)]
    ivp=[m.f32(v) for v in m.columns(m.raster.inverse(vp))]
    return dict(vp=vp,invVP=ivp,unjitteredGpuVP=vp,jitterDelta=[0,0])

def pixel_for(r,target):
    uv,_=m.project(r['vp'],[m.I(v) for v in target])
    return tuple(math.floor(float((a.low+a.high)/2)*s) for a,s in zip(uv,m.SIZE))

def geometry(r,p,owner='floor'):
    a,b,c=m.plane(tuple(r['vp']),owner)
    code={'floor':16775169.,'panel':16777216.}[owner]
    return (*m.RECTS[owner]['oct'],code,m.f32(a*m.F(2*p[0]+1,2)+b*m.F(2*p[1]+1,2)+c))

def synthetic_continued(target=(2.2,0,1),half_pixel_tie=False):
    r=camera(3.075);old=camera(3)
    if half_pixel_tie:
        r=camera(3.6);old=camera(3.6)
        shift=[-1/640,-(2/3)/360]
        original=old['vp']
        old['vp']=[m.f32(v+(shift[row] if row<2 else 0)*original[3+4*col]) for col in range(4) for row,v in enumerate(original[col*4:col*4+4])]
        old['invVP']=[m.f32(v) for v in m.columns(m.raster.inverse(old['vp']))]
        r['jitterDelta']=[m.f32(-.5/640),m.f32((1/3)/360)]
    r.update(previousVP=old['vp'],previousInvVP=old['invVP'])
    p=pixel_for(r,target);g=geometry(r,p)
    position,_,_=m.surface(p,g,r,'floor');pose,w=m.project(old['vp'],position)
    cur,_=m.project(r['unjitteredGpuVP'],position);previous_nojit,_=m.project(old['unjitteredGpuVP'],position)
    middle=lambda v:float((v.low+v.high)/2)
    half=lambda x:struct.unpack('<e',struct.pack('<e',x))[0]
    motion=[0,0] if half_pixel_tie else [half(middle(a-b)) for a,b in zip(cur,previous_nojit)]
    uv=[m.f32(m.f32(m.f32((p[a]+.5)/m.SIZE[a])-motion[a])+r['jitterDelta'][a]) for a in range(2)]
    nearest=tuple(math.floor(m.f32(uv[a]*m.SIZE[a])) for a in range(2))
    lower=tuple(math.floor(m.f32(m.f32(uv[a]*m.SIZE[a])-.5)) for a in range(2))
    addresses=[nearest]+[(lower[0]+x,lower[1]+y) for y in range(2) for x in range(2)]
    node=dict(pixel=p,geometry=g,material=(.96,.96,.96,1),identity=(123,0,1,1),candidate=(1,0,1,3),objectKey=(123,0,1,1),
              transform=[[float(i==j) for j in range(4)] for i in range(4)],motion=motion,motionUV=uv,poseUV=[m.f32(middle(x)) for x in pose],clipW=m.f32(middle(w)),prior=[])
    for slot,pixel in enumerate(addresses):
        node['prior'].append(dict(pixel=pixel,slot=slot,inBounds=1,geometry=geometry(old,pixel),material=(.96,.96,.96,1),identity=(123,0,1,1),confidence=1,rgbFinite=True,moments=(.1,.01,12,0)))
    # A view row supplying the source camera-space distance. The geometry gates
    # use only z; current GPU VP w is the positive forward view distance.
    r['view']=[0.]*16
    for col in range(4):r['view'][2+4*col]=-r['vp'][3+4*col]
    r['view'][15]=1
    return r,old,node

class SourceTests(unittest.TestCase):
    def test_rectangle_visibility_and_camera_translation(self):
        old=camera(3);new=camera(3.6);target=[1.2,0,1]
        self.assertEqual(m.ray_owner(pixel_for(old,target),old),'panel')
        self.assertEqual(m.ray_owner(pixel_for(new,target),new),'floor')
        for r in (old,new):self.assertEqual(m.ray_owner(pixel_for(r,[2.2,0,1]),r),'floor')

    def test_each_authored_movement_has_analytic_new_visibility(self):
        counts=[]
        for k in range(8):
            count=0
            for cohort,(x,_,z) in analyze.targets():
                if cohort!='event':continue
                old=1.8+(1.8-(3+.075*k))*(z+.2)/2.8
                new=1.8+(1.8-(3+.075*(k+1)))*(z+.2)/2.8
                count+=new<x<old
            self.assertGreater(count,0);counts.append(count)
        self.assertGreaterEqual(sum(counts),8)

    def test_floor_depth_source_and_normal(self):
        r=camera(3.6);p=pixel_for(r,[2.2,0,1]);a,b,c=m.plane(tuple(r['vp']),'floor')
        g=(0.,1.,16775169.,m.f32(a*m.F(2*p[0]+1,2)+b*m.F(2*p[1]+1,2)+c))
        position,ns,ng=m.surface(p,g,r,'floor')
        self.assertTrue(position[1].contains(0))
        self.assertGreater(float(ns[1].low),.99);self.assertGreater(float(ng[1].low),.99)
        with self.assertRaises(m.Uncovered):m.surface(p,g[:3]+(g[3]+.01,),r,'floor')

    def test_signed_half_modes_are_enclosed(self):
        for value in (.000135,-.000135,0,1.0004,-1.0004):
            b=m.half_enclosure(m.I(value))
            rne=struct.unpack('<e',struct.pack('<e',value))[0]
            self.assertTrue(b.contains(rne));self.assertTrue(b.low<=b.high)
        self.assertEqual(m.half_enclosure(m.I(0)).values(),[0,0])

    def test_divide_includes_reciprocal_multiply(self):
        a=m.I(7)/m.I(13)
        for sign in (-1,1):self.assertTrue(a.contains(m.f32(7*(1/13)*(1+sign*2**-21))))

    def test_actual_jitter_difference_once(self):
        a=camera(3);b=copy.deepcopy(a)
        dx=2*.2/640;dy=-2*.3/360
        b['vp']=[m.f32(v+(dx if row==0 else dy if row==1 else 0)*a['vp'][3+4*col]) for col in range(4) for row,v in enumerate(a['vp'][col*4:col*4+4])]
        b['jitterDelta']=[m.f32(-.2/640),m.f32(-.3/360)]
        m.jitter(b,a)
        b['jitterDelta']=[2*v for v in b['jitterDelta']]
        with self.assertRaises(m.Uncovered):m.jitter(b,a)

    def test_complete_continued_input_and_identity_negative(self):
        r,old,node=synthetic_continued()
        proof=m.support(node['pixel'],node,r)
        m.motion_source(node,proof,r['vp'],old['vp'])
        margins=m.continued_geometry(node,r,proof,m.f32(.015),m.f32(.9))
        self.assertTrue(all(value>0 for value in margins.values()))
        node['prior'][2]['identity']=(123,0,2,1)
        with self.assertRaises(m.Uncovered):m.continued_geometry(node,r,proof,m.f32(.015),m.f32(.9))

    def test_complete_first_exposure_input(self):
        r,old,node=synthetic_continued((1.27,0,1))
        prior=node['prior'][0]
        self.assertEqual(m.ray_owner(node['pixel'],r),'floor')
        self.assertEqual(m.ray_owner(prior['pixel'],r,True),'panel')
        for prior in node['prior']:
            if m.ray_owner(prior['pixel'],r,True)=='panel':
                prior['geometry']=geometry(old,prior['pixel'],'panel');prior['identity']=(456,0,2,1)
        controls=[(1,0,0,0),(.08,32,1,32),(640,360,640,360),(m.f32(.015),m.f32(.9),m.f32(.03),3)]
        proof=analyze.classify(node,r,controls,'event',r['vp'],old['vp'])
        self.assertEqual(proof['classification'],'first-exposure')

    def test_half_pixel_tie_preserves_both_possible_nearest(self):
        r,old,node=synthetic_continued(half_pixel_tie=True)
        proof=m.support(node['pixel'],node,r)
        self.assertEqual(len(proof['nearest']),2)
        self.assertEqual(len({p[0] for p in proof['nearest']}),2)
        self.assertTrue(set(proof['nearest'])<={p['pixel'] for p in node['prior'][1:]})
        m.motion_source(node,proof,r['unjitteredGpuVP'],old['unjitteredGpuVP'])
        m.continued_geometry(node,r,proof,m.f32(.015),m.f32(.9))
        # Corrupt the alternative nearest, never the observer's preferred hint.
        # Every alias is changed consistently so this exercises the geometric
        # all-candidate rule rather than only duplicate consistency bookkeeping.
        alternate=next(p for p in proof['nearest'] if p!=node['prior'][0]['pixel'])
        for prior in node['prior']:
            if prior['pixel']==alternate:prior['identity']=(999,0,1,1)
        with self.assertRaises(m.Uncovered):m.continued_geometry(node,r,proof,m.f32(.015),m.f32(.9))

    def test_duplicate_previous_alias_must_not_pick_a_favorable_row(self):
        r,old,node=synthetic_continued(half_pixel_tie=True)
        duplicate=next(p for p in node['prior'][1:] if p['pixel']==node['prior'][0]['pixel'])
        duplicate['moments']=(.1,.01,2,0)
        with self.assertRaises(m.Uncovered):m.support(node['pixel'],node,r)

class SeparationTests(unittest.TestCase):
    def test_input_decode_does_not_read_current_result(self):
        data=bytearray((12+264*45)*16)
        _,a=analyze.decode_inputs(data)
        for row in (5,6,7):struct.pack_into('<4I',data,(12+row)*16,*([0x7fc00000]*4))
        _,b=analyze.decode_inputs(data)
        self.assertEqual(a,b)

    def fixture(self,raw=(.5,.25,.125,1),history=None,age=1):
        data=bytearray(45*16)
        struct.pack_into('<4f',data,5*16,*raw)
        struct.pack_into('<4f',data,6*16,*(raw if history is None else history))
        struct.pack_into('<4f',data,7*16,0,0,age,0)
        return data,dict(base=0)

    def test_first_exposure_reset_and_stale_history_negative(self):
        data,node=self.fixture();self.assertTrue(analyze.result_check(data,node,'first-exposure')['known'])
        data,node=self.fixture(history=(.6,.25,.125,1))
        with self.assertRaises(AssertionError):analyze.result_check(data,node,'first-exposure')
        data,node=self.fixture(age=2)
        with self.assertRaises(AssertionError):analyze.result_check(data,node,'first-exposure')

    def test_continued_control_rejects_global_reset(self):
        data,node=self.fixture(age=12);self.assertTrue(analyze.result_check(data,node,'continued')['known'])
        data,node=self.fixture(age=1)
        with self.assertRaises(AssertionError):analyze.result_check(data,node,'continued')

    def test_unknown_is_not_known_black(self):
        data,node=self.fixture(raw=(0,0,0,-1),history=(1,1,1,1),age=32)
        self.assertFalse(analyze.result_check(data,node,'first-exposure')['known'])

if __name__=='__main__':unittest.main(verbosity=2)
