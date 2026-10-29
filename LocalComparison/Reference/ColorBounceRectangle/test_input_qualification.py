from fractions import Fraction
import struct
import unittest

import qualify_native_inputs as qualifier
from test_sampler_decode import SamplerDecodeTests


class InputQualificationTests(unittest.TestCase):
    def test_raster_snap_formula_for_affine_depth_plane(self):
        # At an interior point, arbitrary convex weights and vertex displacements
        # must satisfy the clipping-independent planar snapping error bound.
        a,b = Fraction(1,1000), Fraction(-1,3000)
        weights = [Fraction(1,6), Fraction(1,3), Fraction(1,2)]
        shifts = [(qualifier.SNAP,-qualifier.SNAP), (-qualifier.SNAP,qualifier.SNAP), (0,qualifier.SNAP)]
        error = sum(w*(a*dx+b*dy) for w,(dx,dy) in zip(weights, shifts))
        self.assertLessEqual(abs(error), (abs(a)+abs(b))*qualifier.SNAP)

    def test_interval_reconstruction_orthographic_inputs(self):
        data,receipt = SamplerDecodeTests().make_native_input()
        result = qualifier.qualify(data, receipt)
        self.assertEqual(len(result['groups']), 27)
        self.assertTrue(result['qualification']['initialDecoderPassed'])
        self.assertTrue(all(row['qualified'] for row in result['qualification']['groups']))

    def test_wrong_depth_is_rejected_without_world_tolerance(self):
        data,receipt = SamplerDecodeTests().make_native_input()
        struct.pack_into('<f', data, 44, .5001)
        with self.assertRaisesRegex(AssertionError, 'Depth is inconsistent'):
            qualifier.qualify(data, receipt)

    def test_wrong_reconstruction_is_rejected(self):
        data,receipt = SamplerDecodeTests().make_native_input()
        struct.pack_into('<f', data, 36, .001)
        with self.assertRaisesRegex(AssertionError, 'reconstruction enclosure'):
            qualifier.qualify(data, receipt)


if __name__ == '__main__':
    unittest.main(verbosity=2)
