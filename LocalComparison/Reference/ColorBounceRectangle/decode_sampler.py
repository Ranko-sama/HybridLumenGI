"""Decode pure-input diagnostic rows. Product RGB/material/hit outputs are not read."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import struct


EPSILON = 2**-23


def matrix_vector(matrix, vector):
    """Unity Matrix4x4's indexed receipt is column-major, m[row + 4*column]."""
    return [sum(matrix[row + 4*column] * vector[column] for column in range(4)) for row in range(4)]


def project(matrix, position):
    clip = matrix_vector(matrix, [*position, 1])
    assert clip[3] > 0, 'Input position is behind the receipt camera'
    return [clip[0]/clip[3]*.5+.5, .5-clip[1]/clip[3]*.5]


def floor_point(inv_vp, uv):
    # Any two finite depths define the same camera ray. Avoid the infinite far
    # plane and do not use a measured RGB, material, hit, or receiver depth.
    points = []
    for depth in (.25, .75):
        homogeneous = matrix_vector(inv_vp, [2*uv[0]-1, 1-2*uv[1], depth, 1])
        assert abs(homogeneous[3]) > 1e-12, 'Unbounded camera ray endpoint'
        points.append([value/homogeneous[3] for value in homogeneous[:3]])
    a, b = points
    assert abs(b[1]-a[1]) > 1e-10, 'Selected camera ray is parallel to floor'
    t = -a[1]/(b[1]-a[1])
    return [a[i]+t*(b[i]-a[i]) for i in range(3)]


def native_metadata(receipt):
    assert receipt['complete'] is True and not receipt.get('error'), 'Native tap did not complete cleanly'
    assert receipt['rays'] == 8 and receipt['groupCount'] == 27, 'Frozen native sample layout differs'
    assert abs(receipt['rayBias']-.03) < EPSILON, 'Frozen ray bias differs'
    assert receipt['rawFormat'] == 'R16G16B16A16_SFloat', 'Unexpected raw storage contract'
    assert 0 <= receipt['workFrame'] < 2**32
    width, height = receipt['width'], receipt['height']
    full_width, full_height = receipt['fullWidth'], receipt['fullHeight']
    assert 0 < width <= full_width <= 16384 and 0 < height <= full_height <= 16384
    for name in ('vp', 'invVP', 'view'):
        assert len(receipt[name]) == 16 and all(math.isfinite(v) for v in receipt[name]), 'Invalid receipt matrix: '+name
    selection = receipt['selection']
    assert len(selection) == 27 and len({(s['x'], s['y']) for s in selection}) == 27, 'Duplicate or missing native selection'
    expected = {(target, dx, dy) for target in (.5, 1., 2.) for dx in (-2, 0, 2) for dy in (-2, 0, 2)}
    actual = set()
    pixel_guard = 256*EPSILON*max(width, height)
    for selected in selection:
        target = selected['authoredTarget']
        assert len(target) == 3 and target[1:] == [0, 0], 'Unexpected authored receiver target'
        dx, dy = selected['offsetX'], selected['offsetY']
        key = (target[0], dx, dy)
        assert key in expected and key not in actual, 'Unexpected target or offset selection'
        actual.add(key)
        target_index = (.5, 1., 2.).index(target[0])
        assert selected['id'] == f'receiver{target_index}_{dx}_{dy}', 'Selection id differs from target/offset'
        projected = project(receipt['vp'], target)
        for axis, dimension in enumerate((width, height)):
            center = selected[('x', 'y')[axis]] - (dx, dy)[axis]
            # Unity evaluates VP multiplication in float32. A projection on an
            # integer boundary may select either adjacent pixel; record and
            # check that bounded ambiguity without guessing its CPU FMA order.
            assert -pixel_guard <= projected[axis]*dimension-center <= 1+pixel_guard, 'Target projection and selected pixel disagree'
        assert 2 <= selected['x'] < width-2 and 2 <= selected['y'] < height-2, 'Selection is outside interior viewport'
    assert actual == expected
    return dict(pixelCount=27, pixels=[[s['x'], s['y']] for s in selection], raysPerPixel=8,
                workFrame=receipt['workFrame'], giSize=[width, height], nativeReceipt=receipt)


def close_native_group(group, selected, receipt):
    width, height = receipt['width'], receipt['height']
    full_width, full_height = receipt['fullWidth'], receipt['fullHeight']
    x, y = group['pixel']
    full_pixel = [((2*x+1)*full_width)//(2*width), ((2*y+1)*full_height)//(2*height)]
    uv = [(full_pixel[0]+.5)/full_width, (full_pixel[1]+.5)/full_height]
    projected = project(receipt['vp'], group['receiver'])
    projection_error = [abs(projected[i]-uv[i])*dimension for i, dimension in enumerate((full_width, full_height))]
    assert max(projection_error) <= 256*EPSILON*max(full_width, full_height), 'Receiver does not project to selected full-resolution sample'
    expected_position = floor_point(receipt['invVP'], uv)
    world_guard = 256*EPSILON*max(1, *(abs(v) for v in expected_position))
    world_error = math.dist(expected_position, group['receiver'])
    assert world_error <= world_guard, 'Receiver differs from independent camera-ray/floor intersection'
    expected_origin = [group['receiver'][i]+receipt['rayBias']*group['geometricNormal'][i] for i in range(3)]
    assert math.dist(group['origin'], expected_origin) <= 64*EPSILON*max(1, *(abs(v) for v in expected_origin)), 'Biased origin differs from receiver + oriented Ng*bias'
    target = selected['authoredTarget']
    # Bound the whole declared +/-2 GI footprint by its +/-3 pixel outer edge.
    # This verifies a physical neighborhood without a fitted world-distance cap.
    center_x, center_y = x-selected['offsetX'], y-selected['offsetY']
    corners = [floor_point(receipt['invVP'], [(center_x+dx)/width, (center_y+dy)/height])
               for dx in (-3, 3) for dy in (-3, 3)]
    world_radius = max(math.dist(target, corner) for corner in corners)+world_guard
    target_distance = math.dist(target, group['receiver'])
    assert target_distance <= world_radius, 'Receiver lies outside target pixel-footprint neighborhood'
    group.update(id=selected['id'], authoredTarget=target, selectionOffset=[selected['offsetX'], selected['offsetY']],
                 sourceClosure=dict(fullPixel=full_pixel, fullSampleUv=uv, projectionErrorPixels=projection_error,
                                    independentFloorPoint=expected_position, receiverWorldError=world_error,
                                    receiverWorldGuard=world_guard, targetWorldDistance=target_distance,
                                    targetPixelFootprintWorldRadius=world_radius))


def decode(data, metadata):
    pixels = metadata['pixels']
    count, rays, frame = len(pixels), metadata['raysPerPixel'], metadata['workFrame']
    width, height = metadata['giSize']
    assert metadata['pixelCount'] == count and count > 0 and 1 <= rays <= 8
    assert len(data) == count * 8 * 96, 'Sampler row byte count differs'
    groups = []
    for group_index, pixel in enumerate(pixels):
        assert len(pixel) == 2 and 0 <= pixel[0] < width and 0 <= pixel[1] < height
        directions = []
        first = None
        for sample in range(8):
            offset = (group_index * 8 + sample) * 96
            row = data[offset:offset+96]
            if sample >= rays:
                assert not any(row), 'Unused fixed-capacity ray row is not zero'
                continue
            values = struct.unpack_from('<20f', row)
            identity = struct.unpack_from('<4I', row, 80)
            assert identity == (pixel[0], pixel[1], frame, sample), 'Pixel/frame/sample receipt mismatch'
            assert all(math.isfinite(value) for value in values), 'Nonfinite sampler input'
            assert values[3] == 1 and values[7] == 0 and values[15] == 1 and values[19] == 1, 'Input replay or geometric support unavailable'
            direction = values[4:7]
            assert abs(sum(v*v for v in direction)-1) <= 2e-5 and direction[1] >= 0, 'Invalid hemisphere direction'
            position, normal, geometric = values[8:11], values[12:15], values[16:19]
            scale = max(1, *(abs(value) for value in position))
            assert 1e-6 < values[11] <= 1, 'Invalid reversed-Z receiver depth'
            assert abs(position[1]) <= 64 * EPSILON * scale, 'Selected receiver is not on the authored floor'
            assert 0 < position[0] < 5 and -3 < position[2] < 3, 'Selected receiver is outside authored floor interior'
            assert max(abs(normal[i] - (1 if i == 1 else 0)) for i in range(3)) <= 2e-5, 'Selected receiver Ns differs from +y'
            assert abs(sum(v*v for v in geometric)-1) <= 2e-5 and geometric[1] > .99, 'Receiver Ng is not a unit floor-facing normal'
            if first is None:
                first = values
            else:
                assert values[:4] == first[:4] and values[8:20] == first[8:20], 'Receiver inputs vary within one sample group'
            directions.append(list(direction))
        group = dict(id='pixel-'+str(group_index)+'-frame-'+str(frame), pixel=pixel, workFrame=frame,
                     origin=list(first[:3]), receiver=list(first[8:11]), shadingNormal=list(first[12:15]),
                     geometricNormal=list(first[16:19]), rawDepth=first[11], directions=directions)
        if 'nativeReceipt' in metadata:
            close_native_group(group, metadata['nativeReceipt']['selection'][group_index], metadata['nativeReceipt'])
        groups.append(group)
    return dict(schemaVersion=1, status='decoded pure-input replay; native dispatch/source closure is checked separately', groups=groups)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--native-outputdir', type=Path)
    parser.add_argument('--rows', type=Path)
    parser.add_argument('--metadata', type=Path)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    if args.native_outputdir:
        assert args.rows is None and args.metadata is None
        args.rows = args.native_outputdir/'sampler-inputs.bin'
        args.metadata = args.native_outputdir/'tap-receipt.json'
        args.output = args.output or args.native_outputdir/'rays-native.json'
    else:
        assert args.rows and args.metadata and args.output, 'Supply native-outputdir or rows/metadata/output'
    data, metadata_bytes = args.rows.read_bytes(), args.metadata.read_bytes()
    metadata = json.loads(metadata_bytes)
    result = decode(data, native_metadata(metadata) if args.native_outputdir else metadata)
    result['rowSha256'] = hashlib.sha256(data).hexdigest()
    result['metadataSha256'] = hashlib.sha256(metadata_bytes).hexdigest()
    result['decoderSha256'] = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
    with args.output.open('x', encoding='utf-8') as stream:
        json.dump(result, stream, indent=2)
    print(json.dumps(dict(output=str(args.output), groups=len(result['groups']))))


if __name__ == '__main__':
    main()
