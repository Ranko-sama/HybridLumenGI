"""Pure-input classification checks; no Unity, native buffers or radiance RGB."""
import copy
import importlib.util
import json
from pathlib import Path
import struct
import unittest

P=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('history_inputs',P/'qualify_history_inputs.py')
q=importlib.util.module_from_spec(spec);spec.loader.exec_module(q)

def fixture():
    pixel=(400,180);coordinates={(x,y) for x in range(398,403) for y in range(178,183)}
    # Orthographic camera coordinates: clip=(world.x,world.z,world.y+.5,1).
    vp=[1,0,0,0, 0,0,1,0, 0,1,0,0, 0,0,.5,1]
    inv=[1,0,0,0, 0,0,1,0, 0,1,0,0, 0,-.5,0,1]
    view=[1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,-10,1]
    receipt=dict(vp=vp,invVP=inv,previousVP=vp,previousInvVP=inv,view=view,jitterDelta=[0,0])
    ng=2048+(4095<<12)+1
    node=dict(rawConfidence=.5,outputConfidence=.5,outputMoments=[0,0,2,0],previousConfidence=.5,previousMoments=[0,0,31,0],
              geometry=[0,1,ng,.5],previousGeometry=[0,1,ng,.5],material=[1,1,1,1],previousMaterial=[1,1,1,1],motion=[0,0])
    nodes={p:copy.deepcopy(node) for p in coordinates};controls=[[1,0,0,1],[.08,32,1,32],[640,360,640,360]]
    settings=dict(relativeDepthThreshold=.015,normalThreshold=.9,receiverObjectHistory=False)
    return dict(pixel=pixel,declared=coordinates,nodes=nodes,receipt=receipt,controls=controls,settings=settings,logical=32)

class QualificationTests(unittest.TestCase):
    def check_uncovered(self,mutate,reason):
        case=fixture();mutate(case);answer=q.qualify_one(**case)
        self.assertFalse(answer['qualified']);self.assertEqual(answer['classification'],'uncovered');self.assertIn(reason,answer['reason'])
    def test_valid_motion_and_matrix_correspondence(self):
        for motion in (False,True):
            case=fixture();case['controls'][1][2]=int(motion);answer=q.qualify_one(**case)
            self.assertTrue(answer['qualified'],answer);self.assertGreater(len(answer['support']),1)
            self.assertTrue(all(value>0 for value in answer['minimumMargins'].values()))
    def test_offscreen_motion_is_uncovered(self):
        self.check_uncovered(lambda c:c['nodes'][c['pixel']].update(motion=[2,0]),'previous UV/support')
    def test_missing_interpolation_support_is_uncovered(self):
        self.check_uncovered(lambda c:c.update(declared={c['pixel']}),'support is unavailable')
    def test_nonpositive_clip_w_is_uncovered(self):
        def change(c):
            c['controls'][1][2]=0;c['receipt']['previousVP']=list(c['receipt']['previousVP']);c['receipt']['previousVP'][15]=-1
        self.check_uncovered(change,'previous UV/support')
    def test_previous_geometry_and_material_are_independent_gates(self):
        self.check_uncovered(lambda c:c['nodes'][c['pixel']].update(previousGeometry=[0,1,0,.5]),'geometric normal')
        self.check_uncovered(lambda c:c['nodes'][c['pixel']].update(previousMaterial=[.5,1,1,1]),'material gate')
    def test_current_and_previous_invalid_history_are_uncovered(self):
        self.check_uncovered(lambda c:c['nodes'][c['pixel']].update(outputConfidence=0),'current history confidence')
        self.check_uncovered(lambda c:c['nodes'][c['pixel']].update(previousConfidence=0),'previous history confidence')
    def test_reset_and_unknown_current_are_uncovered(self):
        self.check_uncovered(lambda c:c['nodes'][c['pixel']].update(outputMoments=[0,0,1,0]),'current-only reset')
        self.check_uncovered(lambda c:c['nodes'][c['pixel']].update(rawConfidence=-1),'current raw estimate is unknown')
    def test_decode_never_reads_radiance_rgb(self):
        data=bytearray((3+10)*16)
        for row in (0,1,3):
            struct.pack_into('<4f',data,(3+row)*16,float('nan'),float('inf'),-1e30,.5)
        _,nodes=q.decode_inputs(bytes(data),1)
        self.assertEqual(nodes[0]['rawConfidence'],.5);self.assertEqual(nodes[0]['outputConfidence'],.5);self.assertEqual(nodes[0]['previousConfidence'],.5)
        self.assertEqual(set(nodes[0]),{'rawConfidence','outputConfidence','outputMoments','previousConfidence','previousMoments','geometry','previousGeometry','material','previousMaterial','motion'})

if __name__=='__main__':unittest.main(verbosity=2)
