"""Bounded CPU integration controls for the independent picture solver."""
import copy
import math
import unittest
import numpy as np
import numba
from test_lighting import source,light
from lighting import Lighting
from render_reference import pack,primary_queries
from test_primary import camera
from geometry import render_primary,Camera
from mc_kernel import render


def environment():
    return dict(ambientMode='Flat',ambientLight=[0,0,0,1],ambientIntensity=0,reflectionIntensity=0,
                fog=False,lightmaps=[],lightProbeCount=0,hlgiEnvironmentRadiance=[0,0,0,1],hlgiEnvironmentCubemap=None,skybox={})


class Tests(unittest.TestCase):
    def test_actual_primary_grid_interface(self):
        s=source();s['environment']=environment();model=Lighting(s)
        primary=render_primary(model.scene,Camera(camera()),8,8);queries=primary_queries(primary)
        self.assertEqual([q.shape for q in queries],[(64,3),(64,3),(64,),(64,)])
        result=render(*queries,2,1,123,*pack(model))
        self.assertEqual(result[0].shape,(64,3));np.testing.assert_array_equal(result[0],np.zeros((64,3)))

    def test_primary_direct_light_is_not_indirect_D(self):
        s=source();s['environment']=environment();s['lights']=[light()];model=Lighting(s);numba.set_num_threads(2)
        result=render(np.array([[0.,0.,-2.]]),np.array([[0.,0.,1.]]),np.array([0],np.int32),np.array([True]),64,4,123,*pack(model))
        np.testing.assert_array_equal(result[0],[[0,0,0]])
        np.testing.assert_array_equal(result[1],[[0,0,0]])

    def test_area_emitter_against_independent_rectangle_integral(self):
        s=source();s['environment']=environment();s['geometry'][0]['materialKeys']=['m0','m0']
        emitter=copy.deepcopy(s['geometry'][0]);emitter['key']='emitter';emitter['name']='emitter';emitter['localToWorld'][11]=-1
        emitter['materialKeys']=['em','em'];emitter['mesh']['normals']=[dict(x=0,y=0,z=-1)]*6
        for sub in emitter['mesh']['submeshes']:sub['indices']=[0,2,1]
        material=copy.deepcopy(s['materials'][0]);material['key']='em';material['keywords']=['_EMISSION']
        props={p['name']:p for p in material['properties']};props['_BaseColor']['value']=[0,0,0,1];props['_EmissionColor']['value']=[1,1,1,1]
        s['materials'].append(material);s['geometry'].append(emitter);model=Lighting(s)
        numba.set_num_threads(2)
        result=render(np.array([[0.,0.,-2.]]),np.array([[0.,0.,1.]]),np.array([0],np.int32),np.array([True]),32768,1,456,*pack(model))
        expected=4/math.pi*(2/math.sqrt(5))*math.atan(2/math.sqrt(5))
        # Fixed-seed MC algorithm self-test, not an image acceptance threshold.
        self.assertLess(abs(result[0][0,0]-expected),5*result[1][0,0])
        self.assertGreater(result[0][0,0],.8);self.assertLess(result[0][0,0],.86)
        np.testing.assert_array_equal(result[0][0],np.repeat(result[0][0,0],3))
        self.assertEqual(result[3][0],0) # emitter diffuse rho=0 terminates any cosine hit


if __name__=='__main__':unittest.main()
