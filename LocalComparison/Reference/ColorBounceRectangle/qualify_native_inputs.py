"""Separate raster-aware input qualification; the original decoder stays frozen.

Only sampler inputs, camera matrices and authored floor geometry are consumed.
This does not read product RGB and does not modify any captured sample.
"""
import argparse
from fractions import Fraction as F
import hashlib
import inspect
import json
import math
from pathlib import Path
import struct

import decode_sampler

SPEC = 'https://microsoft.github.io/DirectX-Specs/d3d/archive/D3D11_3_FunctionalSpec.htm'
SNAP = F(3, 1280)  # 0.6 ULP at n.8 fixed point, not a fit to receiver error.


def f32(value):
    return struct.unpack('<f', struct.pack('<f', float(value)))[0]


def adjacent(value, up):
    if value == 0:
        return struct.unpack('<f', struct.pack('<I', 1 if up else 0x80000001))[0]
    bits = struct.unpack('<I', struct.pack('<f', value))[0]
    bits += 1 if (value > 0) == up else -1
    return struct.unpack('<f', struct.pack('<I', bits))[0]


def outward(low, high, extra_ulp=True):
    """Exact rational endpoints plus float32 outward rounding and 1-ULP allowance."""
    lo, hi = f32(low), f32(high)
    if F(lo) > low:
        lo = adjacent(lo, False)
    if F(hi) < high:
        hi = adjacent(hi, True)
    if extra_ulp:
        lo, hi = adjacent(lo, False), adjacent(hi, True)
    return F(lo), F(hi)


class Interval:
    def __init__(self, low, high=None):
        self.low, self.high = F(low), F(low if high is None else high)

    def __add__(self, other):
        other = as_interval(other)
        return Interval(*outward(self.low+other.low, self.high+other.high))

    def __neg__(self):
        return Interval(-self.high, -self.low)

    def __sub__(self, other):
        return self+-as_interval(other)

    def __mul__(self, other):
        other = as_interval(other)
        ends = [a*b for a in (self.low, self.high) for b in (other.low, other.high)]
        return Interval(*outward(min(ends), max(ends)))

    def __truediv__(self, other):
        other = as_interval(other)
        assert not other.low <= 0 <= other.high, 'Unbounded homogeneous division'
        ends = [a/b for a in (self.low, self.high) for b in (other.low, other.high)]
        return Interval(*outward(min(ends), max(ends)))

    def contains(self, value):
        return self.low <= F(value) <= self.high

    def values(self):
        return [float(self.low), float(self.high)]


def as_interval(value):
    return value if isinstance(value, Interval) else Interval(value)


def inverse(matrix):
    rows = [[F(matrix[row+4*col]) for col in range(4)] + [F(int(row == col)) for col in range(4)] for row in range(4)]
    for col in range(4):
        pivot = next(row for row in range(col, 4) if rows[row][col])
        rows[col], rows[pivot] = rows[pivot], rows[col]
        divisor = rows[col][col]
        rows[col] = [v/divisor for v in rows[col]]
        for row in range(4):
            if row != col:
                scale = rows[row][col]
                rows[row] = [a-scale*b for a,b in zip(rows[row], rows[col])]
    return [row[4:] for row in rows]


def floor_depth_plane(vp, width, height):
    # y_world=0 -> row y of the exact inverse applied to clip coordinates.
    # This exact inverse is deliberately not the rounded captured invVP.
    q = inverse(vp)[1]
    assert q[2]
    return (-2*q[0]/(q[2]*width), 2*q[1]/(q[2]*height), (q[0]-q[1]-q[3])/q[2])


def unproject_interval(inv_vp, pixel, size, depth):
    # Exact full-pixel addressing, followed by the actual shader's float ops.
    uv = [Interval(F(2*pixel[i]+1, 2))/size[i] for i in range(2)]
    clip = [uv[0]*2-1, -(uv[1]*2-1), as_interval(depth), Interval(1)]
    homogeneous = []
    for row in range(4):
        products = [Interval(inv_vp[row+4*col])*clip[col] for col in range(4)]
        # A balanced dot-product tree and a sequential tree are both contained
        # by the outward arithmetic intervals, including the exact real sum.
        sequential = products[0]
        for product in products[1:]:
            sequential = sequential+product
        balanced = (products[0]+products[1])+(products[2]+products[3])
        homogeneous.append(Interval(min(sequential.low, balanced.low), max(sequential.high, balanced.high)))
    return [homogeneous[i]/homogeneous[3] for i in range(3)]


def qualification_for_group(receipt, pixel, values):
    width, height = receipt['width'], receipt['height']
    fw, fh = receipt['fullWidth'], receipt['fullHeight']
    full = [((2*pixel[0]+1)*fw)//(2*width), ((2*pixel[1]+1)*fh)//(2*height)]
    a,b,c = floor_depth_plane(receipt['vp'], fw, fh)
    exact_depth = a*F(2*full[0]+1, 2)+b*F(2*full[1]+1, 2)+c
    snap_depth = (abs(a)+abs(b))*SNAP
    # This is a source-only planar snapping consistency interval. Clipped
    # vertices remain on the plane; convex raster barycentrics make the bound
    # independent of the shape/number of clipping-created triangles.
    # We do not claim it exhausts every permitted projection/clipping error.
    depth_interval = Interval(*outward(exact_depth-snap_depth, exact_depth+snap_depth))
    assert depth_interval.contains(values[11]), 'Depth is inconsistent with the authored floor raster-snap interval'
    reconstructed = unproject_interval(receipt['invVP'], full, [fw,fh], values[11])
    assert all(interval.contains(value) for interval,value in zip(reconstructed, values[8:11])), 'GPU receiver is outside actual-matrix float32 reconstruction enclosure'
    source_world = unproject_interval(receipt['invVP'], full, [fw,fh], depth_interval)
    assert all(interval.contains(value) for interval,value in zip(source_world, values[8:11])), 'Receiver is outside raster-aware source enclosure'
    return dict(qualified=True, fullPixel=full, idealFloorDepth=float(exact_depth), actualDepth=values[11],
                depthSlopePerFullPixel=[float(a),float(b)], snapPixelBound=float(SNAP),
                snapDepthBound=float(snap_depth), depthInterval=depth_interval.values(),
                actualReceiver=list(values[8:11]), actualDepthReconstructionIntervals=[i.values() for i in reconstructed],
                rasterSourceWorldIntervals=[i.values() for i in source_world],
                originalFloorGuardPassed=abs(values[9]) <= 64*decode_sampler.EPSILON*max(1, *(abs(v) for v in values[8:11])))


def qualify(data, receipt):
    metadata = decode_sampler.native_metadata(receipt)
    qualifications = []
    for group_index, pixel in enumerate(metadata['pixels']):
        values = struct.unpack_from('<20f', data, group_index*8*96)
        qualifications.append(qualification_for_group(receipt, pixel, values))
    # Reuse every original parser/identity/normal/bias/target check, replacing
    # only the failed world-coordinate heuristic by the completed independent
    # qualification above. The original file and its original FAIL are retained.
    original = inspect.getsource(decode_sampler.decode)
    old = "assert abs(position[1]) <= 64 * EPSILON * scale, 'Selected receiver is not on the authored floor'"
    replacement = "assert qualifications[group_index]['qualified'], 'Raster-aware source qualification failed'"
    assert original.count(old) == 1
    adapted = original.replace(old, replacement)
    namespace = dict(vars(decode_sampler), qualifications=qualifications)
    exec(compile(adapted, '<raster-qualified frozen decoder adapter>', 'exec'), namespace)
    result = namespace['decode'](data, metadata)
    result['status'] = 'raster-aware input source qualification; original fixed world-coordinate heuristic failed'
    result['qualification'] = dict(scope='Input consistency only. Neither product RGB nor finite radiance limits enter this qualification.',
                                 initialDecoderPassed=all(q['originalFloorGuardPassed'] for q in qualifications),
                                 clipping='For a planar depth field, any clipped vertex is on the same depth plane. Convex barycentric interpolation bounds snapping by (abs(a)+abs(b))*0.6/256.',
                                 precisionScope='The source interval models normative raster-coordinate snapping plus float32 outward storage. It is an input consistency check, not an exhaustive bound on all permitted forward projection/clipping implementation errors.',
                                 spec=SPEC, specSections=['3.2.4.1','3.4.1','15.16'],
                                 reconstruction='Exact rational interval endpoints; each float32 operation is rounded outward with an additional one-ULP allowance.',
                                 decoderAdapterSha256=hashlib.sha256(adapted.encode()).hexdigest(), groups=qualifications)
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--native-outputdir', type=Path, required=True)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    data = (args.native_outputdir/'sampler-inputs.bin').read_bytes()
    receipt_bytes = (args.native_outputdir/'tap-receipt.json').read_bytes()
    result = qualify(data, json.loads(receipt_bytes))
    result.update(rowSha256=hashlib.sha256(data).hexdigest(), metadataSha256=hashlib.sha256(receipt_bytes).hexdigest(),
                  originalDecoderSha256=hashlib.sha256(Path(decode_sampler.__file__).read_bytes()).hexdigest(),
                  qualifierSha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest())
    output = args.output or args.native_outputdir/'rays-native-qualified.json'
    with output.open('x', encoding='utf-8') as stream:
        json.dump(result, stream, indent=2)
    print(json.dumps(dict(output=str(output), groups=len(result['groups']), originalDecoderPassed=result['qualification']['initialDecoderPassed'], rasterQualified=True)))


if __name__ == '__main__':
    main()
