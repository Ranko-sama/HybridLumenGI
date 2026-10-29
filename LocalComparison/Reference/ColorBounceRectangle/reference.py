"""Independent one-bounce rectangle radiometry; no product code or measured RGB imports.

The source is x=constant, normal +x; the receiver hemisphere has normal +y.
Cosine sampling has unit transport weight for D=E/pi. Geometry, source diffuse,
and light units come only from an authored source contract. Optional ray directions
are sampling inputs, not product intersections/radiance or reference answers.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import struct

FLOAT_EPSILON = 2.0 ** -23


def finite_vector(value, length=3):
    return isinstance(value, (list, tuple)) and len(value) == length and all(math.isfinite(v) for v in value)


def validate_source(source):
    rectangle = source['rectangle']
    assert all(math.isfinite(rectangle[key]) for key in ('x', 'yMin', 'yMax', 'zMin', 'zMax'))
    assert rectangle['yMin'] < rectangle['yMax'] and rectangle['zMin'] < rectangle['zMax']
    material = source['wallMaterial']
    assert material['shader'] == 'Universal Render Pipeline/Lit' and material['workflow'] == 'metallic'
    assert material['baseColorOrigin'] == 'shader-linear-mpb'
    assert finite_vector(material['baseColor']) and all(0 <= value <= 1 for value in material['baseColor'])
    assert material['metallic'] == 0 and material['proxyTintLinear'] == [1, 1, 1]
    assert material['emission'] == [0, 0, 0] and material['ao'] == 1
    assert not material['textured'] and not material['normalMapped']
    light = source['light']
    assert light['type'] == 'Directional' and light['toLight'] == [1, 0, 0] and not light['shadows']
    assert finite_vector(light['linearRgb']) and all(value >= 0 for value in light['linearRgb'])
    assert math.isfinite(light['intensity']) and light['intensity'] > 0
    settings = source['settings']
    for field in ('bounceFeedback', 'guideWeight', 'emissiveWeight', 'areaEmitterCount', 'screenSteps', 'radianceClamp'):
        assert settings[field] == 0, field + ' violates the single-bounce contract'
    assert settings['environmentRgb'] == [0, 0, 0]
    assert math.isfinite(settings['rayBias']) and settings['rayBias'] >= 0
    assert math.isfinite(settings['maxDistance']) and settings['maxDistance'] > 0


def wall_radiance(source):
    """URP-relative Lo=rho*D_direct. No receiver rho and no extra 1/pi."""
    material, light = source['wallMaterial'], source['light']
    rho = [0.96 * (1 - material['metallic']) * base * tint
           for base, tint in zip(material['baseColor'], material['proxyTintLinear'])]
    assert all(0 <= value < 0.98 for value in rho), 'Reference avoids the transport energy cap'
    return [reflectance * channel * light['intensity'] for reflectance, channel in zip(rho, light['linearRgb'])]


def form_factor(rectangle, origin):
    """Exact cosine-weighted solid-angle fraction of a perpendicular rectangle.

    Integrate d*v/[pi*(d*d+v*v+w*w)^2] dv dw. The hemisphere excludes v<0.
    The v antiderivative is -d/[2*pi*(d*d+v*v+w*w)]. Integrating w yields atan.
    """
    assert finite_vector(origin)
    distance = origin[0] - rectangle['x']
    assert distance > 0, 'Receiver must be on the +x side of the source'
    low = max(0.0, rectangle['yMin'] - origin[1])
    high = rectangle['yMax'] - origin[1]
    if high <= low:
        return 0.0
    z_low, z_high = rectangle['zMin'] - origin[2], rectangle['zMax'] - origin[2]

    def integral_at(height):
        radius = math.hypot(distance, height)
        return (math.atan2(z_high, radius) - math.atan2(z_low, radius)) / radius

    result = distance * (integral_at(low) - integral_at(high)) / (2 * math.pi)
    assert math.isfinite(result) and -1e-15 <= result <= 0.5 + 1e-15
    return max(0.0, result)


def deterministic_area_integral(rectangle, origin, order=64):
    """Independent tensor Gauss-Legendre integration of the original area kernel.

    Used to check the closed form, never as a stochastic reference or an asserted
    rigorous quadrature error bound. Nodes/weights are generated from Legendre P_n.
    """
    assert 2 <= order <= 256 and finite_vector(origin)
    distance = origin[0] - rectangle['x']
    assert distance > 0
    y_low, y_high = max(rectangle['yMin'], origin[1]), rectangle['yMax']
    if y_high <= y_low:
        return 0.0
    z_low, z_high = rectangle['zMin'], rectangle['zMax']
    nodes = []
    for index in range(1, order + 1):
        root = math.cos(math.pi * (index - .25) / (order + .5))
        for _ in range(32):
            previous, polynomial = 1.0, root
            for degree in range(2, order + 1):
                previous, polynomial = polynomial, ((2 * degree - 1) * root * polynomial - (degree - 1) * previous) / degree
            derivative = order * (root * polynomial - previous) / (root * root - 1)
            updated = root - polynomial / derivative
            if abs(updated - root) < 2e-16:
                root = updated
                break
            root = updated
        else:
            raise ArithmeticError('Gauss-Legendre root did not converge')
        # Recompute the derivative at the final node for the quadrature weight.
        previous, polynomial = 1.0, root
        for degree in range(2, order + 1):
            previous, polynomial = polynomial, ((2 * degree - 1) * root * polynomial - (degree - 1) * previous) / degree
        derivative = order * (root * polynomial - previous) / (root * root - 1)
        nodes.append((root, 2 / ((1 - root * root) * derivative * derivative)))
    terms = []
    for yn, yw in nodes:
        y = (y_low + y_high + yn * (y_high - y_low)) / 2 - origin[1]
        for zn, zw in nodes:
            z = (z_low + z_high + zn * (z_high - z_low)) / 2 - origin[2]
            radius_squared = distance * distance + y * y + z * z
            terms.append(yw * zw * distance * y / (math.pi * radius_squared * radius_squared))
    return math.fsum(terms) * (y_high - y_low) * (z_high - z_low) / 4


def classify_ray(rectangle, origin, direction, max_distance):
    """Independent geometric intersection; report near-edge ambiguity explicitly."""
    assert finite_vector(origin) and finite_vector(direction)
    assert origin[0] > rectangle['x'] and direction[1] >= 0
    assert abs(math.fsum(v*v for v in direction) - 1) <= 2e-5, 'Expected unit cosine-sampled direction'
    if direction[0] >= 0:
        return {'hit': False, 'ambiguous': False, 'reason': 'points-away'}
    parameter = (rectangle['x'] - origin[0]) / direction[0]
    if parameter <= 0 or parameter >= max_distance:
        return {'hit': False, 'ambiguous': False, 'reason': 'outside-trace-interval'}
    y = origin[1] + parameter * direction[1]
    z = origin[2] + parameter * direction[2]
    scale = max(1.0, abs(parameter), *(abs(v) for v in origin), abs(y), abs(z))
    guard = 64 * FLOAT_EPSILON * scale
    edge_distance = min(abs(y - rectangle['yMin']), abs(y - rectangle['yMax']),
                        abs(z - rectangle['zMin']), abs(z - rectangle['zMax']))
    interval_distance = abs(parameter - max_distance)
    inside = rectangle['yMin'] <= y <= rectangle['yMax'] and rectangle['zMin'] <= z <= rectangle['zMax']
    return dict(hit=inside, ambiguous=edge_distance <= guard or interval_distance <= guard,
                parameter=parameter, point=[rectangle['x'], y, z], edgeDistance=edge_distance, guard=guard)


def require_complete_distance(rectangle, origin, max_distance):
    farthest = max(math.dist(origin, [rectangle['x'], y, z])
                   for y in (rectangle['yMin'], rectangle['yMax'])
                   for z in (rectangle['zMin'], rectangle['zMax']))
    assert max_distance > farthest * (1 + 64 * FLOAT_EPSILON), 'Trace distance clips the analytic rectangle'


def raw_storage_intervals(source, expected):
    """Predeclared binary32 envelope followed by binary16 RNE/RTZ storage envelope.

    The fixed no-texture/no-normal-map scene has at most eight ray sums; gamma32
    covers its constant diffuse/direct products and averaging. The guard addresses
    arithmetic, not a free image-error tolerance. A separate native temporal check
    observed RTZ UAV narrowing before this color run, so include both RNE and RTZ
    without assuming Python's RNE matches the graphics write. Exactly zero has no
    contributing samples and stays exact zero. Geometry uncertainty is separate.
    """
    unit_roundoff = 2.0 ** -24
    gamma32 = 32 * unit_roundoff / (1 - 32 * unit_roundoff)
    half = lambda value: struct.unpack('<e', struct.pack('<e', value))[0]

    def half_toward_zero(value):
        assert value >= 0
        bits = struct.unpack('<H', struct.pack('<e', value))[0]
        nearest = struct.unpack('<e', struct.pack('<H', bits))[0]
        if nearest > value:
            bits -= 1
        return struct.unpack('<e', struct.pack('<H', bits))[0]

    intervals = []
    for value, maximum in zip(expected, wall_radiance(source)):
        if value == 0:
            intervals.append([0.0, 0.0])
        else:
            budget = gamma32 * maximum
            intervals.append([half_toward_zero(max(0.0, value - budget)), half(value + budget)])
    return intervals


def compare_raw(source, group_reference, observed_rgba):
    """Comparison is deliberately separate from building the expected answer."""
    assert group_reference['qualified'], 'Ambiguous input rays cannot authorize a numeric comparison'
    assert finite_vector(observed_rgba, 4), 'Missing/nonfinite raw readback'
    intervals = raw_storage_intervals(source, group_reference['finiteRawExpected'])
    channel_matches = [low <= observed <= high for observed, (low, high) in zip(observed_rgba[:3], intervals)]
    return dict(passed=observed_rgba[3] > 0 and all(channel_matches),
                knownMeasurement=observed_rgba[3] > 0, channelMatches=channel_matches,
                rgba16fIntervals=intervals, observed=list(observed_rgba))


def evaluate_group(source, group):
    """Return finite expected raw D for input rays, with no observed RGB argument."""
    origin, directions = group['origin'], group['directions']
    assert finite_vector(origin) and 1 <= len(directions) <= 8
    require_complete_distance(source['rectangle'], origin, source['settings']['maxDistance'])
    classifications = [classify_ray(source['rectangle'], origin, direction, source['settings']['maxDistance'])
                       for direction in directions]
    qualified = not any(row['ambiguous'] for row in classifications)
    hits = sum(row['hit'] for row in classifications)
    radiance = wall_radiance(source)
    expectation = [value * hits / len(directions) for value in radiance] if qualified else None
    factor = form_factor(source['rectangle'], origin)
    return dict(id=group['id'], pixel=group.get('pixel'), workFrame=group.get('workFrame'),
                origin=origin, rayCount=len(directions), hitCount=hits, qualified=qualified,
                finiteRawExpected=expectation, classifications=classifications,
                rgba16fIntervals=raw_storage_intervals(source, expectation) if qualified else None,
                analyticFactor=factor, analyticInfiniteSampleExpected=[factor * v for v in radiance],
                signal='CSTrace raw D=E/pi; no receiver rho/AO, intensity, temporal or display transform')


def build_reference(source, ray_input=None):
    validate_source(source)
    radiance = wall_radiance(source)
    receivers = []
    for receiver in source.get('referenceReceivers', []):
        position = receiver['position']
        biased = [position[0], position[1] + source['settings']['rayBias'], position[2]]
        require_complete_distance(source['rectangle'], biased, source['settings']['maxDistance'])
        physical_factor = form_factor(source['rectangle'], position)
        biased_factor = form_factor(source['rectangle'], biased)
        receivers.append(dict(id=receiver['id'], position=position, biasedOrigin=biased,
                              physicalFactor=physical_factor, biasedFactor=biased_factor,
                              physicalRawExpected=[physical_factor * value for value in radiance],
                              biasedRawExpected=[biased_factor * value for value in radiance]))
    result = dict(schemaVersion=1, sourceStatus=source['status'], wallRadiance=radiance,
                  receivers=receivers, groups=[], nativeExecuted=False, productionAccepted=False,
                  meaning='Independent deterministic reference only. Analytic expectation is not a finite-frame pass threshold.')
    if ray_input is not None:
        assert ray_input['schemaVersion'] == 1 and isinstance(ray_input['groups'], list)
        result['groups'] = [evaluate_group(source, group) for group in ray_input['groups']]
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--source', type=Path, default=Path(__file__).with_name('source-contract.json'))
    parser.add_argument('--rays', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    source_bytes = args.source.read_bytes()
    ray_bytes = args.rays.read_bytes() if args.rays else None
    result = build_reference(json.loads(source_bytes), json.loads(ray_bytes) if ray_bytes else None)
    result['sourceSha256'] = hashlib.sha256(source_bytes).hexdigest()
    result['rayInputSha256'] = hashlib.sha256(ray_bytes).hexdigest() if ray_bytes else None
    result['referenceCodeSha256'] = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
    with args.output.open('x', encoding='utf-8') as stream:
        json.dump(result, stream, indent=2)
    print(json.dumps({'output': str(args.output), 'receivers': len(result['receivers']), 'groups': len(result['groups'])}))


if __name__ == '__main__':
    main()
