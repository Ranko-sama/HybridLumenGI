"""Small independent analytic controls; no candidate or native renderer input."""
import copy
import math
import unittest
import numpy as np
from test_primary import snapshot
from materials import interpret, UnsupportedInput
from lighting import Lighting, interpret_light, distance_attenuation, spot_attenuation


def source():
    s=snapshot()
    s['rendering'].update(colorSpace='Linear',lightsUseLinearIntensity=True,lightsUseColorTemperature=True)
    s['rendering']['urp']['pipeline']=[dict(name='useRenderingLayers',value='false')]
    for g in s['geometry']:g.update(renderingLayerMask=1,receiveShadows=True)
    for m in s['materials']:
        m['passes'].append('ShadowCaster');m['passEnabled'].append(True)
        m['properties'] += [dict(name=n,value=[v]) for n,v in [('_WorkflowMode',1),('_Metallic',0),('_Smoothness',.5)]]
        m['properties'] += [dict(name='_BaseColor',value=[.5,.5,.5,1],flags='MainColor',origin='material'),
                            dict(name='_EmissionColor',value=[5,3,1.5,1],flags='HDR',origin='material')]
    return s


def light(kind='Directional'):
    # Rotation columns: +x,-y,-z, hence -forward = +z.
    return dict(key='light',name='analytic',type=kind,bakeType='Realtime',enabled=True,active=True,
                color=[1,1,1,1],intensity=1,useColorTemperature=False,range=10,spotAngle=60,innerSpotAngle=30,
                bounceIntensity=1,cookie=None,localToWorld=[1,0,0,0,0,-1,0,0,0,0,-1,0,0,0,0,1],
                toLight=[0,0,1],shadows='Hard',shadowStrength=1,cullingMask=-1,renderingLayerMask=1,
                additional=dict(renderingLayers=1,shadowRenderingLayers=1,customShadowLayers=False))


def query(model):
    p=model.scene.vertices[0].mean(axis=0)[None]
    return model.evaluate(p,np.array([[0.,0.,1.]]),np.array([0]))


class Tests(unittest.TestCase):
    def test_constant_material_color_metal_black_emission(self):
        m=source()['materials'][0]
        expected=((.5+.055)/1.055)**2.4*.96
        np.testing.assert_allclose(interpret(m)['rho'],[expected]*3,atol=1e-15,rtol=0)
        p={x['name']:x for x in m['properties']};p['_BaseColor']['origin']='property-block-material-slot'
        np.testing.assert_allclose(interpret(m)['rho'],[.48]*3,atol=1e-15)
        p['_Metallic']['value']=[1];np.testing.assert_array_equal(interpret(m)['rho'],[0,0,0])
        p['_Metallic']['value']=[0];p['_BaseColor']['value']=[0,0,0,1]
        np.testing.assert_array_equal(interpret(m)['rho'],[0,0,0])
        np.testing.assert_array_equal(interpret(m)['emission'],[0,0,0])
        m['keywords']=['_EMISSION'];np.testing.assert_array_equal(interpret(m)['emission'],[5,3,1.5])

    def test_directional_additivity_and_units(self):
        s=source();s['lights']=[light()];model=Lighting(s);r=query(model)
        self.assertEqual(model.unsupported,[]);self.assertTrue(r['known'][0])
        np.testing.assert_array_equal(r['directD'],[[1,1,1]])
        s['lights'].append(dict(light(),key='second'));r=query(Lighting(s))
        np.testing.assert_array_equal(r['directD'],[[2,2,2]])
        np.testing.assert_allclose(r['outgoingSource'],2*r['rho'],atol=1e-15)

    def test_punctual_range_spot_and_no_4pi(self):
        expected=(1-(4/100)**2)**2/4
        self.assertAlmostEqual(float(distance_attenuation(4,10)),expected,15)
        self.assertEqual(float(distance_attenuation(100,10)),0)
        inner,outer=math.cos(math.radians(15)),math.cos(math.radians(30))
        np.testing.assert_allclose(spot_attenuation([1,outer,(inner+outer)/2],30,60),[1,0,.25],atol=1e-15)
        s=source();point=light('Point');point['localToWorld'][3:12:4]=[2/3,-2/3,0]
        s['lights']=[point];r=query(Lighting(s));self.assertTrue(r['known'][0])
        np.testing.assert_allclose(r['directD'],[[expected]*3],atol=1e-15,rtol=0)
        point['type']='Spot';np.testing.assert_allclose(query(Lighting(s))['directD'],r['directD'],atol=1e-15)

    def test_source_hard_shadow_cull_and_shadow_only(self):
        s=source();s['lights']=[light()]
        g=copy.deepcopy(s['geometry'][0]);g['key']='blocker';g['name']='blocker';g['localToWorld'][11]=-1;g['shadowCasting']='ShadowsOnly'
        s['geometry'].append(g);model=Lighting(s);r=query(model)
        self.assertTrue(r['known'][0]);np.testing.assert_array_equal(r['directD'],[[0,0,0]])
        g['shadowCasting']='Off';r=query(Lighting(s));self.assertTrue(r['known'][0]);np.testing.assert_array_equal(r['directD'],[[1,1,1]])
        g['shadowCasting']='On';g['mesh']['submeshes'][0]['indices']=[0,2,1];g['mesh']['submeshes'][1]['indices']=[0,2,1]
        r=query(Lighting(s));np.testing.assert_array_equal(r['directD'],[[1,1,1]])
        g['shadowCasting']='TwoSided';r=query(Lighting(s));np.testing.assert_array_equal(r['directD'],[[0,0,0]])

    def test_contacts_and_light_singularity_remain_unknown(self):
        s=source();s['lights']=[light()];g=copy.deepcopy(s['geometry'][0]);g['key']='contact';g['shadowCasting']='TwoSided';s['geometry'].append(g)
        r=query(Lighting(s));self.assertFalse(r['known'][0]);np.testing.assert_array_equal(r['directD'],[[0,0,0]])
        s=source();point=light('Point');point['localToWorld'][3:12:4]=[2/3,-2/3,-2];s['lights']=[point]
        r=query(Lighting(s));self.assertFalse(r['known'][0]);self.assertTrue(np.isfinite(r['directD']).all())

    def test_missing_semantics_are_unsupported(self):
        s=source();l=light();l['useColorTemperature']=True
        with self.assertRaisesRegex(UnsupportedInput,'CCT'):interpret_light(l,s['rendering'],False)
        l['useColorTemperature']=False;s['rendering']['lightsUseLinearIntensity']=False
        with self.assertRaisesRegex(UnsupportedInput,'linear'):interpret_light(l,s['rendering'],False)
        m=source()['materials'][0];m['properties'].append(dict(name='_BumpMap',type='Texture',texture=dict(name='bound')))
        with self.assertRaisesRegex(UnsupportedInput,'texture'):interpret(m)


if __name__=='__main__':unittest.main()
