"""Small source/ABI negatives for the vertical-wall input qualifier; no GPU/RGB."""
import copy
import json
import math
from pathlib import Path
import struct
import unittest

import screen_input_qualification as q

SOURCE = json.loads(Path(__file__).with_name('source-contract.json').read_text(encoding='utf-8'))


def column_major(rows):
    return [rows[row][column] for column in range(4) for row in range(4)]


def fixture():
    # Orthographic camera facing both walls: x_clip=z-x, y_clip=2*y-1,
    # depth=.75-.25*(x+z). It has different visible pixels on A and B.
    vp = column_major([[-1, 0, 1, 0], [0, 2, 0, -1], [-.25, 0, -.25, .75], [0, 0, 0, 1]])
    inv = column_major([[-.5, 0, -2, 1.5], [0, .5, 0, .5], [.5, 0, -2, 1.5], [0, 0, 0, 1]])
    view = column_major([[1, 0, 0, 0], [0, 1, 0, 0], [0, 0, 1, -4], [0, 0, 0, 1]])
    receipt = dict(complete=True, error=None, rays=8, groupCount=18, workFrame=32, logicalFrame=32,
                   width=640, height=360, fullWidth=640, fullHeight=360, rayBias=q.raster.f32(.03),
                   vp=vp, invVP=inv, view=view, normalsOct=False, selection=[])
    for owner, target in q.TARGETS.items():
        projected = q.project(vp, target)
        center = [math.floor(projected[0]*640), math.floor(projected[1]*360)]
        for dy in (-2, 0, 2):
            for dx in (-2, 0, 2):
                receipt['selection'].append(dict(id=f'{owner}_{dx}_{dy}', receiverOwner=owner, x=center[0]+dx,
                                                y=center[1]+dy, offsetX=dx, offsetY=dy, authoredTarget=list(target)))
    return bytearray(build_rows(receipt)), receipt


def group_values(receipt, selected, depth_shift=0):
    pixel = [selected['x'], selected['y']]
    axis = q.AXES[selected['receiverOwner']]
    a, b, c = q.plane_depth_coefficients(receipt['vp'], axis, 0, 640, 360)
    depth = q.raster.f32(float(a*q.F(2*pixel[0]+1, 2)+b*q.F(2*pixel[1]+1, 2)+c)+depth_shift)
    f = q.raster.f32
    uv = [f((pixel[i]+.5)/(640, 360)[i]) for i in range(2)]
    clip = [f(f(uv[0]*2)-1), -f(f(uv[1]*2)-1), depth, 1]
    h = []
    for row in range(4):
        products = [f(receipt['invVP'][row+4*column]*clip[column]) for column in range(4)]
        total = products[0]
        for value in products[1:]:
            total = f(total+value)
        h.append(total)
    position = [f(value/h[3]) for value in h[:3]]
    normal = [float(i == axis) for i in range(3)]
    origin = [f(position[i]+f(normal[i]*receipt['rayBias'])) for i in range(3)]
    return [*origin, 1, *normal, 0, *position, depth, *normal, 1, *normal, 1]


def build_rows(receipt, depth_shift=0):
    data = bytearray()
    for selected in receipt['selection']:
        values = group_values(receipt, selected, depth_shift)
        for sample in range(8):
            data.extend(struct.pack('<20f4I', *values, selected['x'], selected['y'], receipt['workFrame'], sample))
    return data


class ScreenInputQualificationTests(unittest.TestCase):
    def test_both_vertical_walls_and_complete_native_abi(self):
        data, receipt = fixture()
        result = q.qualify(data, receipt, SOURCE)
        self.assertEqual(len(result['groups']), 18)
        self.assertFalse(result['radianceRGBRead'])
        self.assertEqual({g['receiverOwner'] for g in result['groups']}, {'A', 'B'})
        self.assertTrue(all(g['sourceClosure']['qualified'] for g in result['groups']))
        for g in result['groups']:
            self.assertEqual(g['directions'][0], [float(i == q.AXES[g['receiverOwner']]) for i in range(3)])

    def test_planar_snap_interval_accepts_source_consistent_nonzero_plane_residual(self):
        _, receipt = fixture()
        data = build_rows(receipt, depth_shift=5e-7)
        result = q.qualify(data, receipt, SOURCE)
        self.assertTrue(any(abs(g['receiver'][q.AXES[g['receiverOwner']]]) > 0 for g in result['groups']))

    def test_wrong_depth_or_other_wall_is_rejected(self):
        _, receipt = fixture()
        with self.assertRaisesRegex(AssertionError, 'raster interval'):
            q.qualify(build_rows(receipt, depth_shift=.001), receipt, SOURCE)
        data, receipt = fixture()
        receipt['selection'][0]['receiverOwner'] = 'B'
        with self.assertRaisesRegex(AssertionError, 'target|selection'):
            q.qualify(data, receipt, SOURCE)

    def test_origin_offset_is_checked_against_actual_float_operations(self):
        data, receipt = fixture()
        for sample in range(8):
            offset = sample*96
            value = struct.unpack_from('<f', data, offset)[0]
            struct.pack_into('<f', data, offset, value+.001)
        with self.assertRaisesRegex(AssertionError, 'Biased origin'):
            q.qualify(data, receipt, SOURCE)

    def test_identity_group_consistency_and_shape_negatives(self):
        data, receipt = fixture()
        bad = bytearray(data)
        struct.pack_into('<I', bad, 80+8, receipt['workFrame']+1)
        with self.assertRaisesRegex(AssertionError, 'identity'):
            q.qualify(bad, receipt, SOURCE)
        bad = bytearray(data)
        struct.pack_into('<f', bad, 96, .25)
        with self.assertRaisesRegex(AssertionError, 'vary'):
            q.qualify(bad, receipt, SOURCE)
        with self.assertRaisesRegex(AssertionError, 'byte count'):
            q.qualify(data[:-96], receipt, SOURCE)

    def test_normal_direction_and_nonfinite_negatives(self):
        data, receipt = fixture()
        for at, value, reason in ((4*4, -1, 'hemisphere'), (16*4, 0, 'normal'), (8*4, float('nan'), 'Nonfinite')):
            bad = bytearray(data)
            for sample in range(8):
                struct.pack_into('<f', bad, sample*96+at, value)
            with self.assertRaisesRegex(AssertionError, reason):
                q.qualify(bad, receipt, SOURCE)

    def test_wrong_pixel_target_matrix_and_source_geometry_are_rejected(self):
        data, receipt = fixture()
        shifted = copy.deepcopy(receipt)
        shifted['selection'][0]['x'] += 10
        with self.assertRaisesRegex(AssertionError, 'projection'):
            q.qualify(data, shifted, SOURCE)
        wrong_matrix = copy.deepcopy(receipt)
        wrong_matrix['invVP'] = receipt['vp']
        with self.assertRaises(AssertionError):
            q.qualify(data, wrong_matrix, SOURCE)
        source = copy.deepcopy(SOURCE)
        source['walls'][0]['coordinate'] = 1
        with self.assertRaisesRegex(AssertionError, 'bounds'):
            q.qualify(data, receipt, source)


if __name__ == '__main__':
    unittest.main(verbosity=2)
