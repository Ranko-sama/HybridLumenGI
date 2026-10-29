"""Qualify geometric screen inputs on the two finite vertical source walls.

The byte API accepts only the 96-byte pure-input sampler rows, never transport
RGB, material answers, hit IDs or cache values. The raster interval is an input
consistency certificate, not an exhaustive bound on every legal DXR or forward
raster implementation. Actual directions, positions and origins are preserved.
"""
from fractions import Fraction as F
import hashlib
import json
import math
from pathlib import Path
import struct
import sys

HERE = Path(__file__).resolve().parent
RASTER_ROOT = HERE.parent / 'ColorBounceRectangle'
sys.path.insert(0, str(RASTER_ROOT))
import qualify_native_inputs as raster

RASTER_SHA = '6a2d2bff05edf128545a52d8508291f500349a3544382b3dee9ded57c3f1cc96'
assert hashlib.sha256(Path(raster.__file__).read_bytes()).hexdigest() == RASTER_SHA
I = raster.Interval
EPSILON = 2**-23
TARGETS = {'A': [0, .5, .5], 'B': [.5, .5, 0]}
AXES = {'A': 0, 'B': 2}


def require(value, message):
    if not value:
        raise AssertionError(message)


def finite(values):
    return all(math.isfinite(value) for value in values)


def matrix_vector(matrix, vector):
    return [sum(matrix[row + 4*column]*vector[column] for column in range(4)) for row in range(4)]


def project(matrix, position):
    clip = matrix_vector(matrix, [*position, 1])
    require(finite(clip) and clip[3] > 0, 'Position is behind the receipt camera')
    return [clip[0]/clip[3]*.5+.5, .5-clip[1]/clip[3]*.5]


def plane_depth_coefficients(vp, axis, coordinate, width, height):
    """Exact plane equation in full-pixel coordinates, using Unity column-major VP."""
    require(axis in (0, 2), 'Only the two authored vertical planes are supported')
    inverse = raster.inverse(vp)
    q = [inverse[axis][column]-F(coordinate)*inverse[3][column] for column in range(4)]
    require(q[2] != 0, 'Camera-ray/plane depth is not uniquely defined')
    return (-2*q[0]/(q[2]*width), 2*q[1]/(q[2]*height), (q[0]-q[1]-q[3])/q[2])


def camera_ray_plane_point(inv_vp, uv, axis, coordinate=0):
    # This construction never uses a sampled depth or a product intersection.
    points = []
    for depth in (.25, .75):
        h = matrix_vector(inv_vp, [2*uv[0]-1, 1-2*uv[1], depth, 1])
        require(finite(h) and abs(h[3]) > 1e-12, 'Unbounded camera ray endpoint')
        points.append([value/h[3] for value in h[:3]])
    a, b = points
    require(abs(b[axis]-a[axis]) > 1e-10, 'Camera ray is parallel to the receiver wall')
    t = (coordinate-a[axis])/(b[axis]-a[axis])
    return [a[i]+t*(b[i]-a[i]) for i in range(3)]


def validate_geometry_source(source):
    walls = {wall['id']: wall for wall in source['walls']}
    require(len(source['walls']) == 2 and set(walls) == set(AXES), 'Two authored wall identities are required')
    for owner, axis in AXES.items():
        wall = walls[owner]
        bounds = [[0, 0] if i == axis else [0, 1] for i in range(3)]
        require(wall['axis'] == axis and wall['coordinate'] == 0 and wall['bounds'] == bounds,
                'Authored wall bounds differ')
        require(wall['normal'] == [int(i == axis) for i in range(3)], 'Authored wall normal differs')
    require(abs(source['settings']['rayBias']-.03) < EPSILON, 'Frozen source bias differs')
    return walls


def validate_metadata(receipt, source):
    validate_geometry_source(source)
    require(receipt['complete'] is True and not receipt.get('error'), 'Native input tap did not complete cleanly')
    require(receipt['rays'] == 8, 'Frozen native ray count differs')
    require(isinstance(receipt['workFrame'], int) and 0 <= receipt['workFrame'] < 2**32, 'Invalid Work.frame')
    require(abs(receipt['rayBias']-.03) < EPSILON, 'Frozen receipt bias differs')
    width, height, fw, fh = (receipt[key] for key in ('width', 'height', 'fullWidth', 'fullHeight'))
    require(all(isinstance(v, int) for v in (width, height, fw, fh)), 'Noninteger viewport dimensions')
    require(0 < width <= fw <= 16384 and 0 < height <= fh <= 16384, 'Invalid viewport dimensions')
    for key in ('vp', 'invVP', 'view'):
        require(len(receipt[key]) == 16 and finite(receipt[key]), 'Invalid receipt matrix: '+key)
    selection = receipt['selection']
    require(len(selection) == 18 and receipt.get('groupCount', 18) == 18, 'Frozen native selection count differs')
    require(len({(s['x'], s['y']) for s in selection}) == 18, 'Duplicate selected pixel')
    require(all(isinstance(s['id'], str) and s['id'] for s in selection) and len({s['id'] for s in selection}) == 18,
            'Missing or duplicate selected identity')
    expected = {(owner, dx, dy) for owner in AXES for dx in (-2, 0, 2) for dy in (-2, 0, 2)}
    actual = set()
    pixel_guard = 256*EPSILON*max(width, height)  # Retained camera projection closure from the frozen input decoder.
    for selected in selection:
        owner, dx, dy = (selected[key] for key in ('receiverOwner', 'offsetX', 'offsetY'))
        key = (owner, dx, dy)
        require(key in expected and key not in actual, 'Unexpected receiver/offset selection')
        actual.add(key)
        require(selected['authoredTarget'] == TARGETS[owner], 'Unexpected authored target')
        require(isinstance(selected['x'], int) and isinstance(selected['y'], int), 'Noninteger selected pixel')
        require(2 <= selected['x'] < width-2 and 2 <= selected['y'] < height-2, 'Selection leaves the interior viewport')
        projected = project(receipt['vp'], selected['authoredTarget'])
        for axis, size in enumerate((width, height)):
            center = selected[('x', 'y')[axis]]-(dx, dy)[axis]
            require(-pixel_guard <= projected[axis]*size-center <= 1+pixel_guard,
                    'Selected pixel disagrees with authored target projection')
    require(actual == expected, 'Incomplete target footprint')


def qualify_receiver(owner, pixel, depth, position, normal, geometric_normal, origin, receipt, source):
    walls = validate_geometry_source(source)
    require(owner in walls, 'Unknown receiver owner')
    wall, axis = walls[owner], AXES[owner]
    require(all(len(v) == 3 and finite(v) for v in (position, normal, geometric_normal, origin)), 'Nonfinite receiver geometry')
    require(math.isfinite(depth) and 1e-6 < depth <= 1, 'Invalid reversed-Z receiver depth')
    require(max(abs(normal[i]-wall['normal'][i]) for i in range(3)) <= 2e-5, 'Receiver shading normal differs from authored wall')
    require(abs(sum(v*v for v in geometric_normal)-1) <= 2e-5 and geometric_normal[axis] > .99,
            'Receiver geometric normal is not a unit wall-facing normal')
    require(sum(a*b for a, b in zip(normal, geometric_normal)) > 0, 'Bias normal orientation is not proved')
    width, height, fw, fh = (receipt[key] for key in ('width', 'height', 'fullWidth', 'fullHeight'))
    require(len(pixel) == 2 and all(isinstance(v, int) for v in pixel) and 0 <= pixel[0] < width and 0 <= pixel[1] < height,
            'Invalid receiver pixel')
    full = [((2*pixel[0]+1)*fw)//(2*width), ((2*pixel[1]+1)*fh)//(2*height)]
    uv = [(full[0]+.5)/fw, (full[1]+.5)/fh]
    a, b, c = plane_depth_coefficients(receipt['vp'], axis, wall['coordinate'], fw, fh)
    exact_depth = a*F(2*full[0]+1, 2)+b*F(2*full[1]+1, 2)+c
    snap_depth = (abs(a)+abs(b))*raster.SNAP
    depth_interval = I(*raster.outward(exact_depth-snap_depth, exact_depth+snap_depth))
    require(depth_interval.contains(depth), 'Depth is inconsistent with the authored wall raster interval')
    reconstructed = raster.unproject_interval(receipt['invVP'], full, [fw, fh], depth)
    require(all(interval.contains(value) for interval, value in zip(reconstructed, position)),
            'Receiver is outside actual-matrix float32 reconstruction enclosure')
    source_world = raster.unproject_interval(receipt['invVP'], full, [fw, fh], depth_interval)
    require(all(interval.contains(value) for interval, value in zip(source_world, position)),
            'Receiver is outside the wall source enclosure')
    for coordinate in range(3):
        if coordinate != axis:
            lo, hi = wall['bounds'][coordinate]
            require(lo < source_world[coordinate].low <= source_world[coordinate].high < hi,
                    'Receiver support is not strictly inside the finite wall')
    # A second matrix/ray check retains the established camera closure without
    # reinstating the rejected fixed world-coordinate plane-distance heuristic.
    projected = project(receipt['vp'], position)
    projection_error = [abs(projected[i]-uv[i])*dimension for i, dimension in enumerate((fw, fh))]
    require(max(projection_error) <= 256*EPSILON*max(fw, fh), 'Receiver does not project to the selected full pixel')
    ray_point = camera_ray_plane_point(receipt['invVP'], uv, axis, wall['coordinate'])
    world_guard = 256*EPSILON*max(1, *(abs(v) for v in ray_point))
    require(math.dist(position, ray_point) <= world_guard, 'Receiver differs from the independent camera-ray/wall intersection')
    bias = raster.f32(receipt['rayBias'])
    biased = [I(position[i])+I(geometric_normal[i])*bias for i in range(3)]
    require(all(interval.contains(value) for interval, value in zip(biased, origin)), 'Biased origin differs from receiver plus oriented Ng times bias')
    return dict(qualified=True, receiverOwner=owner, fullPixel=full, fullSampleUv=uv,
                idealPlaneDepth=float(exact_depth), depthInterval=depth_interval.values(), snapPixelBound=float(raster.SNAP),
                depthSlopePerFullPixel=[float(a), float(b)], snapDepthBound=float(snap_depth),
                actualDepthReconstructionIntervals=[v.values() for v in reconstructed], rasterSourceWorldIntervals=[v.values() for v in source_world],
                originIntervals=[v.values() for v in biased], projectionErrorPixels=projection_error,
                independentPlanePoint=ray_point, receiverWorldError=math.dist(position, ray_point), receiverWorldGuard=world_guard,
                precisionScope='Source consistency under planar raster snapping and outward float32 reconstruction; not an exhaustive forward-raster or DXR precision certificate.')


def decode_groups(data, receipt, source):
    validate_metadata(receipt, source)
    require(len(data) == 18*8*96, 'Sampler input row byte count differs')
    groups = []
    for group_index, selected in enumerate(receipt['selection']):
        pixel, owner = [selected['x'], selected['y']], selected['receiverOwner']
        first, directions = None, []
        for sample in range(8):
            offset = (group_index*8+sample)*96
            values = struct.unpack_from('<20f', data, offset)
            identity = struct.unpack_from('<4I', data, offset+80)
            require(identity == (pixel[0], pixel[1], receipt['workFrame'], sample), 'Pixel/frame/sample identity differs')
            require(finite(values), 'Nonfinite sampler input')
            require(values[3] == 1 and values[7] == 0 and values[15] == 1 and values[19] == 1,
                    'Input replay or geometric support is unavailable')
            direction = values[4:7]
            require(abs(sum(v*v for v in direction)-1) <= 2e-5 and direction[AXES[owner]] >= 0,
                    'Invalid authored-hemisphere direction')
            require(sum(a*b for a, b in zip(direction, values[12:15])) >= 0, 'Direction leaves actual shading hemisphere')
            if first is None:
                first = values
            else:
                require(values[:4] == first[:4] and values[8:20] == first[8:20], 'Receiver inputs vary within one sample group')
            directions.append(list(direction))
        closure = qualify_receiver(owner, pixel, first[11], first[8:11], first[12:15], first[16:19], first[:3], receipt, source)
        center = [pixel[0]-selected['offsetX'], pixel[1]-selected['offsetY']]
        corners = [camera_ray_plane_point(receipt['invVP'], [(center[0]+dx)/receipt['width'], (center[1]+dy)/receipt['height']], AXES[owner])
                   for dx in (-3, 3) for dy in (-3, 3)]
        radius = max(math.dist(selected['authoredTarget'], corner) for corner in corners)+closure['receiverWorldGuard']
        distance = math.dist(selected['authoredTarget'], first[8:11])
        require(distance <= radius, 'Receiver leaves the declared target pixel footprint')
        closure.update(targetPixelFootprintWorldRadius=radius, targetWorldDistance=distance)
        groups.append(dict(id=selected['id'], pixel=pixel, receiverOwner=owner, workFrame=receipt['workFrame'],
                           authoredTarget=selected['authoredTarget'], selectionOffset=[selected['offsetX'], selected['offsetY']],
                           origin=list(first[:3]), receiver=list(first[8:11]), shadingNormal=list(first[12:15]),
                           geometricNormal=list(first[16:19]), rawDepth=first[11], directions=directions, sourceClosure=closure))
    return groups


def qualify(data, receipt, source=None):
    if source is None:
        source = json.loads((HERE/'source-contract.json').read_text(encoding='utf-8'))
    return dict(schemaVersion=1, status='qualified pure geometric screen input consistency; transport/source dispatch closure remains separate',
                groups=decode_groups(data, receipt, source), rowSha256=hashlib.sha256(data).hexdigest(),
                qualifierSha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(), rasterDependencySha256=RASTER_SHA,
                sourceSpecification=raster.SPEC, radianceRGBRead=False)
