import copy
import math
import struct
import unittest
import decode_sampler


class SamplerDecodeTests(unittest.TestCase):
    def make_input(self):
        metadata = dict(pixelCount=1, pixels=[[8, 12]], raysPerPixel=2, workFrame=59, giSize=[32, 24])
        rows = bytearray(8 * 96)
        directions = [(-1/math.sqrt(2), 1/math.sqrt(2), 0), (1/math.sqrt(2), 1/math.sqrt(2), 0)]
        for index, direction in enumerate(directions):
            struct.pack_into('<20f4I', rows, index*96, 1,.03,0,1, *direction,0,
                             1,0,0,.5, 0,1,0,1, 0,1,0,1, 8,12,59,index)
        return rows, metadata

    def test_identity_input_and_unused_capacity(self):
        rows, metadata = self.make_input()
        result = decode_sampler.decode(rows, metadata)
        self.assertEqual(len(result['groups']), 1)
        self.assertEqual(result['groups'][0]['workFrame'], 59)
        self.assertEqual(result['groups'][0]['receiver'], [1, 0, 0])
        self.assertEqual(len(result['groups'][0]['directions']), 2)

    def test_frame_mismatch_is_rejected(self):
        rows, metadata = self.make_input()
        metadata['workFrame'] = 60
        with self.assertRaises(AssertionError):
            decode_sampler.decode(rows, metadata)

    def test_off_floor_selection_is_rejected(self):
        rows, metadata = self.make_input()
        struct.pack_into('<f', rows, 36, .5)
        with self.assertRaises(AssertionError):
            decode_sampler.decode(rows, metadata)

    def make_native_input(self):
        # Independent orthographic camera: clip=(.4*x-1,z/3,.5-.1*y,1).
        receipt = dict(complete=True, error='', rays=8, groupCount=27, workFrame=59,
                       width=200, height=200, fullWidth=400, fullHeight=400, rayBias=.03,
                       rawFormat='R16G16B16A16_SFloat',
                       vp=[.4,0,0,0, 0,0,-.1,0, 0,1/3,0,0, -1,0,.5,1],
                       invVP=[2.5,0,0,0, 0,0,3,0, 0,-10,0,0, 2.5,5,0,1],
                       view=[1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1], selection=[])
        rows = bytearray(27*8*96)
        for target_index, distance in enumerate((.5, 1., 2.)):
            target_uv = decode_sampler.project(receipt['vp'], [distance, 0, 0])
            center = [math.floor(v*200) for v in target_uv]
            for dy in (-2, 0, 2):
                for dx in (-2, 0, 2):
                    group = len(receipt['selection'])
                    x, y = center[0]+dx, center[1]+dy
                    receipt['selection'].append(dict(id=f'receiver{target_index}_{dx}_{dy}', x=x, y=y,
                                                       offsetX=dx, offsetY=dy, authoredTarget=[distance,0,0]))
                    # Native addressing at a 2:1 full/GI ratio: fullPixel=2*p+1.
                    uv = [(2*x+1.5)/400, (2*y+1.5)/400]
                    position = [5*uv[0], 0, 3-6*uv[1]]
                    for sample in range(8):
                        struct.pack_into('<20f4I', rows, (group*8+sample)*96,
                                         position[0],.03,position[2],1, -math.sqrt(.5),math.sqrt(.5),0,0,
                                         *position,.5, 0,1,0,1, 0,1,0,1, x,y,59,sample)
        return rows, receipt

    def test_native_receipt_camera_and_target_closure(self):
        rows, receipt = self.make_native_input()
        result = decode_sampler.decode(rows, decode_sampler.native_metadata(receipt))
        self.assertEqual(len(result['groups']), 27)
        for group in result['groups']:
            self.assertEqual(len(group['directions']), 8)
            closure = group['sourceClosure']
            self.assertLessEqual(closure['targetWorldDistance'], closure['targetPixelFootprintWorldRadius'])
            self.assertLess(closure['receiverWorldError'], 1e-6)

    def test_native_wrong_projection_selection_is_rejected(self):
        _, receipt = self.make_native_input()
        receipt['selection'][0]['x'] += 10
        with self.assertRaisesRegex(AssertionError, 'projection'):
            decode_sampler.native_metadata(receipt)

    def test_native_unrelated_floor_receiver_is_rejected(self):
        rows, receipt = self.make_native_input()
        # Keep a valid on-floor receiver, but detach it from its input pixel.
        for sample in range(8):
            struct.pack_into('<f', rows, sample*96, 4.)
            struct.pack_into('<f', rows, sample*96+32, 4.)
        with self.assertRaisesRegex(AssertionError, 'project'):
            decode_sampler.decode(rows, decode_sampler.native_metadata(receipt))

    def test_native_wrong_bias_is_rejected(self):
        rows, receipt = self.make_native_input()
        for sample in range(8):
            struct.pack_into('<f', rows, sample*96+4, .04)
        with self.assertRaisesRegex(AssertionError, 'Biased origin'):
            decode_sampler.decode(rows, decode_sampler.native_metadata(receipt))

    def test_native_incomplete_capture_is_rejected(self):
        _, receipt = self.make_native_input()
        receipt['complete'] = False
        with self.assertRaisesRegex(AssertionError, 'did not complete'):
            decode_sampler.native_metadata(receipt)


if __name__ == '__main__':
    unittest.main(verbosity=2)
