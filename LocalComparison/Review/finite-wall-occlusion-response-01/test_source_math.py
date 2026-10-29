"""Synthetic input cases only; no native output or radiance expected-value fitting."""
import math,unittest
from source_math import universal_block,wall_direction,matrix_x,physical_raw,Uncovered
class PlaneContract(unittest.TestCase):
    def test_all_authored_origins(self):
        for x in (.45,.5,1,2,2.1):
            for z in (-.1,0,.1):universal_block([x,.03,z])
    def test_blocked_wall_direction(self):
        result=wall_direction([1,.03,0],[-1,1,0]);self.assertEqual(result['classification'],'blocked-wall-direction')
    def test_black_environment_directions(self):
        self.assertEqual(wall_direction([1,.03,0],[1,1,0])['classification'],'miss')
        self.assertEqual(wall_direction([1,.03,0],[-1,3,0])['classification'],'miss')
    def test_origin_on_wrong_side(self):
        with self.assertRaises(Uncovered):universal_block([.2,.03,0])
    def test_panel_does_not_cover_whole_wall(self):
        with self.assertRaises(Uncovered):universal_block([.3,.03,20])
    def test_boundary_is_uncovered(self):
        with self.assertRaises(Uncovered):wall_direction([1,0,0],[-1,0,0])
    def test_nan_input_is_uncovered(self):
        with self.assertRaises(Uncovered):universal_block([1,math.nan,0])
    def test_exact_pose_contract(self):
        m=[float(i%5==0) for i in range(16)];m[12]=.25
        self.assertTrue(matrix_x(m,.25));self.assertFalse(matrix_x(m,20));m[4]=.001;self.assertFalse(matrix_x(m,.25))
    def test_known_stale_color_cannot_be_excused(self):
        with self.assertRaises(AssertionError):physical_raw([.04,.02,.01,.3],True)
    def test_unknown_is_not_black_success(self):
        self.assertEqual(physical_raw([0,0,0,-1],True),'unknown')
    def test_known_black_and_restored_color(self):
        self.assertEqual(physical_raw([0,0,0,.25],True),'known-black')
        self.assertEqual(physical_raw([.04,.02,.01,.3],False),'known-positive')
if __name__=='__main__':unittest.main()
