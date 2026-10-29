"""Mathematical checks independent of native runs or observed product color."""
import copy
import json
import math
from pathlib import Path
import struct
import unittest
import reference

SOURCE = json.loads(Path(__file__).with_name('source-contract.json').read_text())
RECTANGLE = SOURCE['rectangle']


class RectangleReferenceTests(unittest.TestCase):
    def test_closed_form_against_original_area_kernel(self):
        for origin in ([.5, 0, 0], [1, 0, 0], [2, .03, 0], [1, .3, .75], [1, -.25, -.5]):
            with self.subTest(origin=origin):
                analytic = reference.form_factor(RECTANGLE, origin)
                area = reference.deterministic_area_integral(RECTANGLE, origin)
                self.assertAlmostEqual(analytic, area, delta=2e-11)

    def test_symmetry_partition_scaling(self):
        origin = [1, .03, .6]
        value = reference.form_factor(RECTANGLE, origin)
        self.assertAlmostEqual(value, reference.form_factor(RECTANGLE, [1, .03, -.6]), delta=1e-15)
        left, right = copy.deepcopy(RECTANGLE), copy.deepcopy(RECTANGLE)
        left['zMax'] = right['zMin'] = .25
        self.assertAlmostEqual(value, reference.form_factor(left, origin) + reference.form_factor(right, origin), delta=1e-15)
        scaled = {key: entry * 3 for key, entry in RECTANGLE.items()}
        self.assertAlmostEqual(value, reference.form_factor(scaled, [v * 3 for v in origin]), delta=1e-15)

    def test_hemisphere_and_limits(self):
        self.assertEqual(reference.form_factor(RECTANGLE, [1, 2, 0]), 0)
        huge = dict(x=0, yMin=0, yMax=1e8, zMin=-1e8, zMax=1e8)
        self.assertAlmostEqual(reference.form_factor(huge, [1, 0, 0]), .5, delta=1e-8)
        self.assertGreater(reference.form_factor(RECTANGLE, [.5, 0, 0]), reference.form_factor(RECTANGLE, [2, 0, 0]))

    def test_urp_units_and_single_source_reflectance(self):
        reference.validate_source(SOURCE)
        self.assertEqual(reference.wall_radiance(SOURCE), [.48, .24, .12])
        brighter = copy.deepcopy(SOURCE)
        brighter['light']['intensity'] = 2
        self.assertEqual(reference.wall_radiance(brighter), [.96, .48, .24])

    def test_finite_ray_truth_and_exact_black(self):
        normalize = lambda v: [entry / math.sqrt(sum(x*x for x in v)) for entry in v]
        # Two known hits and two known misses; their RGB answer is independent of
        # the product sampler, material capture and any observed raw texture.
        group = dict(id='fixed-rays', origin=[1, .03, 0], directions=[
            normalize([-1, 1, 0]), normalize([-1, .5, .5]),
            normalize([1, 1, 0]), normalize([-1, 4, 0])])
        result = reference.evaluate_group(SOURCE, group)
        self.assertTrue(result['qualified'])
        self.assertEqual(result['hitCount'], 2)
        self.assertEqual(result['finiteRawExpected'], [.24, .12, .06])
        rounded = [struct.unpack('<e', struct.pack('<e', value))[0] for value in result['finiteRawExpected']]
        self.assertTrue(reference.compare_raw(SOURCE, result, rounded + [.65])['passed'])
        truncated = []
        for expected, rounded_value in zip(result['finiteRawExpected'], rounded):
            bits = struct.unpack('<H', struct.pack('<e', rounded_value))[0]
            truncated.append(struct.unpack('<e', struct.pack('<H', bits - int(rounded_value > expected)))[0])
        self.assertTrue(reference.compare_raw(SOURCE, result, truncated + [.65])['passed'])
        self.assertFalse(reference.compare_raw(SOURCE, result, [value / math.pi for value in rounded] + [.65])['passed'])
        self.assertFalse(reference.compare_raw(SOURCE, result, [rounded[2], rounded[1], rounded[0], .65])['passed'])
        self.assertFalse(reference.compare_raw(SOURCE, result, rounded + [-1])['passed'])
        group['directions'] = [normalize([1, 1, 0])]
        self.assertEqual(reference.evaluate_group(SOURCE, group)['finiteRawExpected'], [0, 0, 0])

    def test_edge_ambiguity_is_not_a_forced_answer(self):
        length = math.hypot(1, 1.97)
        result = reference.evaluate_group(SOURCE, dict(id='edge', origin=[1, .03, 0], directions=[[-1/length, 1.97/length, 0]]))
        self.assertFalse(result['qualified'])
        self.assertIsNone(result['finiteRawExpected'])

    def test_source_contract_rejects_additional_transport(self):
        for key in ('bounceFeedback', 'guideWeight', 'emissiveWeight', 'screenSteps', 'areaEmitterCount'):
            changed = copy.deepcopy(SOURCE)
            changed['settings'][key] = 1
            with self.subTest(key=key), self.assertRaises(AssertionError):
                reference.validate_source(changed)

    def test_distance_limit_must_cover_the_rectangle(self):
        with self.assertRaises(AssertionError):
            reference.require_complete_distance(RECTANGLE, [1, .03, 0], 2)


if __name__ == '__main__':
    unittest.main(verbosity=2)
