import json
import math
from pathlib import Path
import struct
import unittest

import compare_native
import reference


class NativeComparisonTests(unittest.TestCase):
    def make_case(self):
        source = json.loads(Path(__file__).with_name('source-contract.json').read_text())
        directions = [[-math.sqrt(.5), math.sqrt(.5), 0], [math.sqrt(.5), math.sqrt(.5), 0]]
        groups = [dict(id='lit', pixel=[1,0], workFrame=59, origin=[1,.03,0], directions=directions),
                  dict(id='black', pixel=[0,1], workFrame=59, origin=[1,.03,0], directions=directions[1:])]
        expected = reference.build_reference(source, dict(schemaVersion=1, groups=groups))
        raw = bytearray(2*2*16)
        for group in expected['groups']:
            x,y = group['pixel']
            struct.pack_into('<4f', raw, (y*2+x)*16, *[compare_native.half(v) for v in group['finiteRawExpected']], 1)
        return source, expected, raw

    def test_pixel_addressed_positive_and_exact_black(self):
        source, expected, raw = self.make_case()
        rows = compare_native.compare_pixels(source, expected, raw, 2, 2)
        self.assertEqual([r['hitCount'] for r in rows], [1,0])
        self.assertTrue(all(r['passed'] for r in rows))

    def test_extra_pi_does_not_pass(self):
        source, expected, raw = self.make_case()
        struct.pack_into('<3f', raw, 16, *[compare_native.half(v/math.pi) for v in expected['groups'][0]['finiteRawExpected']])
        rows = compare_native.compare_pixels(source, expected, raw, 2, 2)
        self.assertFalse(rows[0]['passed'])
        self.assertTrue(rows[1]['passed'])

    def test_unknown_is_not_black(self):
        source, expected, raw = self.make_case()
        struct.pack_into('<f', raw, 2*16+12, -1)
        self.assertFalse(compare_native.compare_pixels(source, expected, raw, 2, 2)[1]['passed'])

    def test_incomplete_raw_is_rejected(self):
        source, expected, raw = self.make_case()
        with self.assertRaisesRegex(AssertionError, 'shape'):
            compare_native.compare_pixels(source, expected, raw[:-1], 2, 2)


if __name__ == '__main__':
    unittest.main(verbosity=2)
