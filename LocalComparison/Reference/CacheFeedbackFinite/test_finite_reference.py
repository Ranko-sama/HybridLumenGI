import copy
import json
import math
from pathlib import Path
import unittest

import finite_reference as ref

SOURCE=json.loads(Path(__file__).with_name('source-contract.json').read_text())


def fixture(mode='measuredBlack'):
    d=1/math.sqrt(2)
    patch_a=dict(owner='A',position=[0,.5,.5],normal=[1,0,0],geometricNormal=[1,0,0],origin=[.03,.5,.5])
    patch_b=dict(owner='B',position=[.5,.5,0],normal=[0,0,1],geometricNormal=[0,0,1],origin=[.5,.5,.03])
    a=[[d,0,-d],[1,0,0],[d,0,-d],[1,0,0]]
    b=[[-d,0,d],[0,0,1],[-d,0,d],[0,0,1]]
    return dict(schemaVersion=1,provenance='synthetic authored directions; not a native execution',initialState=mode,
                initialSampleCounts={'A':7,'B':9} if mode=='measuredBlack' else {'A':0,'B':0},patches=[patch_a,patch_b],
                frames=[dict(workFrame=61,readBuffer='cache0',writeBuffer='cache1',globalReactive=1,globalGeometryChange=0,patchDirections={'A':a,'B':b}),
                        dict(workFrame=62,readBuffer='cache1',writeBuffer='cache0',globalReactive=0,globalGeometryChange=0,patchDirections={'A':a,'B':b})],
                gather=[dict(id='visible-A',receiverOwner='A',workFrame=62,origin=patch_a['origin'],directions=a),
                        dict(id='visible-B',receiverOwner='B',workFrame=62,origin=patch_b['origin'],directions=b)])


class FiniteCacheReferenceTests(unittest.TestCase):
    def test_measured_black_jacobi_scattering_orders(self):
        result=ref.build(SOURCE,fixture())
        rho_a,rho_b=ref.reflectance(SOURCE,'A'),ref.reflectance(SOURCE,'B')
        first,second=result['frames']
        self.assertEqual(first['patches']['A']['alpha'],.5)
        self.assertEqual(second['patches']['A']['alpha'],1/3)
        self.assertEqual(first['patches']['A']['new'],[0,0,0])
        for c in range(3):
            self.assertAlmostEqual(first['patches']['B']['new'][c],rho_a[c]/4,delta=1e-16)
            self.assertAlmostEqual(second['patches']['A']['new'][c],rho_a[c]*rho_b[c]/24,delta=1e-16)
            self.assertAlmostEqual(second['patches']['B']['new'][c],rho_a[c]/3,delta=1e-16)
            self.assertAlmostEqual(result['gather'][1]['rawByScatteringOrder']['3'][c],rho_a[c]**2*rho_b[c]/48,delta=1e-16)
        self.assertEqual(set(result['gather'][0]['rawByScatteringOrder']),{'2'})
        self.assertEqual(set(result['gather'][1]['rawByScatteringOrder']),{'1','3'})
        self.assertEqual(set(result['gather'][1]['receiverDiffuseOnlyByScatteringOrder']),{'2','4'})
        self.assertNotIn('3',second['patches']['B']['byScatteringOrder'])  # Gauss-Seidel would create it prematurely.

    def test_cold_zero_is_not_a_measured_black_sample(self):
        cold=ref.build(SOURCE,fixture('coldZeroStorage'))
        warm=ref.build(SOURCE,fixture())
        self.assertEqual(cold['frames'][0]['patches']['B']['alpha'],1)
        self.assertEqual(cold['frames'][1]['patches']['B']['alpha'],.5)
        for c in range(3):
            self.assertAlmostEqual(cold['gather'][1]['rawByScatteringOrder']['3'][c],3*warm['gather'][1]['rawByScatteringOrder']['3'][c],delta=1e-16)

    def test_real_rectangles_can_miss(self):
        hit=ref.trace(SOURCE,[.5,.5,.03],[-1/math.sqrt(2),0,1/math.sqrt(2)],20)
        self.assertEqual(hit['owner'],'A')
        self.assertIsNone(ref.trace(SOURCE,[.5,.5,.03],[0,0,1],20))
        self.assertIsNone(ref.trace(SOURCE,[2,.5,.03],[0,0,1],20))

    def test_product_answers_are_rejected(self):
        for forbidden in ('hit','pdf','weights','cacheRgb'):
            inputs=fixture();inputs['frames'][0][forbidden]=[0,0,0]
            with self.assertRaisesRegex(AssertionError,'Product answer'):
                ref.build(SOURCE,inputs)

    def test_same_buffer_and_edge_ambiguity_are_rejected(self):
        inputs=fixture();inputs['frames'][0]['writeBuffer']='cache0'
        with self.assertRaises(AssertionError):ref.build(SOURCE,inputs)
        with self.assertRaisesRegex(AssertionError,'edge classification'):
            ref.trace(SOURCE,[.5,0,.03],[-1/math.sqrt(2),0,1/math.sqrt(2)],20)


if __name__=='__main__':unittest.main(verbosity=2)
