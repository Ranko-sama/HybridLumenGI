import copy
import json
import math
from pathlib import Path
import struct
import tempfile
import unittest

import atlas_support as atlas
import compare_native
import numeric_reference as num
from test_finite_reference import SOURCE,fixture


class IdealAtlas:
    def __init__(self,logical):
        data=fixture();self.receipt=dict(logicalFrame=logical,workFrame=logical+30)
        self.owners={p['owner']:{**p,'index':i,'samples':32 if logical<33 else 2,'directions':data['frames'][0]['patchDirections'][p['owner']]*4} for i,p in enumerate(data['patches'])}
    def support(self,hit):return True
    def report(self):return {'synthetic':True}


def layered_fixture():
    groups=[{**group,'pixel':[i,0],'shadingNormal':[1,0,0] if i==0 else [0,0,1],'directions':group['directions']*2} for i,group in enumerate(fixture()['gather'])]
    return num.build(SOURCE,[IdealAtlas(n) for n in (31,32,33)],[groups]*3)


def native_geometry_fixture(directory):
    receipt=dict(logicalFrame=31,workFrame=61,epoch=2,cacheReadIndex=0,proxyCount=2,cardCount=2,changeCount=0,lightCount=0)
    owners=[];cards=[];atlas_rows=[];cache_rows=[];states=[]
    for index,wall in enumerate(SOURCE['walls']):
        name=wall['id'];axis=wall['axis'];normal=wall['normal'];code=544 if name=='A' else 529;ng=atlas.decode_code(code)
        owner=dict(id=name,slot=index,card=index,generation=1,layoutGeneration=1,geometryRevision=1,
                   primitiveCards=[index]*2,primitiveCharts=[1]*2,primitiveLayouts=[1]*2,primitiveGeometry=[1]*2)
        owners.append(owner)
        rows=[[0,0,1,0],[0,1,0,0],[.5,0,0,.5],[0,0,0,1]] if name=='A' else [[1,0,0,0],[0,1,0,0],[0,0,.5,.5],[0,0,0,1]]
        matrix=[rows[r][c] for c in range(4) for r in range(4)]
        cards.append(struct.pack('<24f8I',*matrix,index*.5,0,.5,1,*normal,.6,index+1,1,1,1,index,1,1,5))
        for local in range(1024):
            if local>=4:atlas_rows.append(struct.pack('<12f',*([0]*12)));continue
            u=(local%2+.5)/2;v=(local//2+.5)/2
            position=[0,v,u] if name=='A' else [u,v,0]
            atlas_rows.append(struct.pack('<12f',*position,.5,*normal,1,code,index*2+local%2,local//2,1))
        position=[0,.25,.25] if name=='A' else [.25,.25,0]
        ng=[num.f32(v) for v in ng];origin=[num.f32(position[i]+num.f32(ng[i]*num.f32(.03))) for i in range(3)]
        direction=normal
        oct_x=1 if name=='A' else 1/31;oct_y=1/31
        states.append(struct.pack('<16f',32,0,0,0,index+1,1,2,1,*position,oct_x,*normal,oct_y))
        for sample in range(16):cache_rows.append(struct.pack('<20f12I',*origin,1,*direction,0,*position,0,*normal,0,*ng,0,index,index,0,0,index,61,2,sample,index*2,0,1,1))
    receipt['owners']=owners
    def put(name,data):(directory/('frame-031-'+name+'.bin')).write_bytes(data)
    put('cards',b''.join(cards));put('owner-ranges',struct.pack('<8I',0,1,1,1,1,1,1,1));put('card-indices',struct.pack('<2I',0,1))
    put('anchors',struct.pack('<4i',0,0,2,0));put('mask',struct.pack('<2I',1,1));put('owner-identities',struct.pack('<8f',1,1,0,1,2,1,0,1))
    put('cache-state-inputs',b''.join(states));put('changes',bytes(1088*48))
    put('globals',struct.pack('<8I4f4I4f',61,2,0,31,2,2,1,16,.03,1,0,0,0,0,2,1024,4,2,0,0))
    put('atlas-inputs',b''.join(atlas_rows));put('cache-inputs',b''.join(cache_rows))
    return receipt


class NativeReferenceTests(unittest.TestCase):
    def test_layered_intervals_contain_independent_closed_form(self):
        result=layered_fixture();ra=[.48,.24,.12];rb=[.12,.48,.24]
        first,second=result['frames'][1:]
        self.assertTrue(num.contains(first['cache']['B']['rgbIntervals'],[v/4 for v in ra]))
        self.assertEqual(first['cache']['A']['rgbIntervals'],[[0,0]]*3)
        self.assertTrue(num.contains(second['cache']['A']['rgbIntervals'],[a*b/24 for a,b in zip(ra,rb)]))
        self.assertTrue(num.contains(second['cache']['B']['rgbIntervals'],[a/3 for a in ra]))
        self.assertTrue(num.contains(second['gather'][1]['rgbIntervals'],[a/2+a*a*b/48 for a,b in zip(ra,rb)]))
        self.assertTrue(all(compare_native.negative_controls(result).values()))
        for frame in result['frames'][1:]:
            for row in frame['cache'].values():
                for low,high in row['rgbIntervals']:
                    if low>0:self.assertLess((high-low)/low,2e-4)

    def test_known_black_and_half_rounding_modes(self):
        result=layered_fixture()
        for row in result['frames'][0]['gather']:self.assertEqual(row['storageIntervals'],[[0,0]]*3)
        value=num.I(1.0102,1.01021);lo,hi=num.storage(value)
        for v in (value.low,(value.low+value.high)/2,value.high):
            self.assertTrue(lo<=num.half_rne(v)<=hi and lo<=num.half_rtz(v)<=hi)
        self.assertEqual(num.storage(num.I(0)),[0,0])

    def test_history_counts_are_independent_inputs(self):
        data=[IdealAtlas(n) for n in (31,32,33)];data[-1].owners['A']['samples']=3
        groups=[{**g,'pixel':[i,0],'shadingNormal':SOURCE['walls'][i]['normal']} for i,g in enumerate(fixture()['gather'])]
        with self.assertRaisesRegex(AssertionError,'sample-count Jacobi'):num.build(SOURCE,data,[groups]*3)

    def test_atlas_input_abi_current_identity_and_real_geometry(self):
        with tempfile.TemporaryDirectory() as temporary:
            path=Path(temporary);receipt=native_geometry_fixture(path);frame=atlas.AtlasFrame(path,receipt,SOURCE)
            hit=dict(owner='A',position=[0,.3,.3],distance=.4)
            self.assertTrue(frame.support(hit));self.assertEqual(frame.owners['A']['covered'],4)
            # No cached RGB exists in any fixture input file.
            self.assertFalse(frame.report()['readsProductRGB'])
            changed=copy.deepcopy(receipt);changed['owners'][0]['primitiveGeometry'][1]=2
            with self.assertRaisesRegex(AssertionError,'triangle binding'):atlas.AtlasFrame(path,changed,SOURCE)

    def test_atlas_missing_support_and_ambiguous_neighbor_are_distinct(self):
        with tempfile.TemporaryDirectory() as temporary:
            path=Path(temporary);receipt=native_geometry_fixture(path);frame=atlas.AtlasFrame(path,receipt,SOURCE)
            # Remove a non-anchor texel. A uniformly empty query is a valid zero
            # feedback decision; a straddling valid/empty boundary is rejected.
            row=list(frame.owners['A']['texels'][(1,0)]);row[8]=0;frame.owners['A']['texels'][(1,0)]=row
            self.assertFalse(frame.support(dict(owner='A',position=[0,.3,.7],distance=.4)))
            with self.assertRaisesRegex(AssertionError,'neighboring atlas'):frame.support(dict(owner='A',position=[0,.3,.5],distance=.4))


if __name__=='__main__':unittest.main(verbosity=2)
