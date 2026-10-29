"""Read the one retained dispatch; qualify exact IEEE +/-zero equivalence.

The original analysis failure is retained. No threshold, input, source, or GPU
result is changed and no second WARP execution is performed.
"""
import hashlib
import json
import math
from pathlib import Path
import struct

HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2];B=HERE/'baseline'
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def save(path,value):
    with path.open('x',encoding='utf8') as stream:json.dump(value,stream,indent=2,allow_nan=False)


def main():
    original=json.loads((B/'source-hashes.json').read_text())
    assert all(sha(ROOT/name)==digest for name,digest in original.items())
    contract=json.loads((B/'contract.json').read_text());assert contract['absoluteGeometryTolerance']==2e-6
    raw=(B/'outputs.bin').read_bytes();cases=json.loads((B/'cases.json').read_text());assert len(raw)==8*368
    rows=[];pairs=[]
    for index,case in enumerate(cases):
        value=struct.unpack_from('<92f',raw,index*368)
        assert all(math.isfinite(v) for k,v in enumerate(value) if k!=7)
        row=dict(case=case['kind'],guideWeight=case['guideWeight'],origin=list(value[:3]),weight=value[3],direction=list(value[4:7]),rng=struct.unpack_from('<I',raw,index*368+28)[0],
                 geometry=list(value[8:12]),positionDepth=list(value[12:16]),shadingNormal=list(value[16:20]),finalNg=list(value[20:24]),screenNg=list(value[24:28]),
                 probeOriginLimit=list(value[28:32]),probeDirection=list(value[32:36]),probeHit=list(value[36:40]),counts=list(value[40:44]),guide=list(value[44:48]))
        assert row['guide']==[0,0,0,0] and row['positionDepth']==[0,0,0,.5]
        assert math.dist(row['shadingNormal'][:3],(0,1,0))<2e-6 and row['direction'][1]>0 and abs(row['weight']-1)<2e-6
        probes=int(bool(case['guideWeight']) and case['kind']!='no-depth-support');matches=probes if case['kind']!='world-miss' else 0
        assert row['counts']==[probes,matches,matches,0]
        rows.append(row)
    for index in range(0,8,2):
        a,b=rows[index:index+2];changed=a['case']=='tilted'
        direction_same=raw[index*368+12:index*368+32]==raw[(index+1)*368+12:(index+1)*368+32]
        origin_bytes_same=raw[index*368:index*368+12]==raw[(index+1)*368:(index+1)*368+12]
        geometry_same=raw[index*368+32:index*368+48]==raw[(index+1)*368+32:(index+1)*368+48]
        origin_values_same=a['origin']==b['origin']
        assert direction_same and origin_values_same!=changed and geometry_same!=changed
        if not changed and not origin_bytes_same:
            assert a['case']=='aligned'
            bits_a=struct.unpack_from('<3I',raw,index*368);bits_b=struct.unpack_from('<3I',raw,(index+1)*368)
            assert all(x==y or ((x&0x7fffffff)==0 and (y&0x7fffffff)==0) for x,y in zip(bits_a,bits_b))
        pairs.append(dict(case=a['case'],sameDirectionWeightRngBytes=direction_same,sameOriginBytes=origin_bytes_same,sameOriginValues=origin_values_same,sameGeometryBytes=geometry_same))
    assert math.dist(rows[0]['screenNg'][:3],(.2/math.sqrt(1.04),1/math.sqrt(1.04),0))<2e-6
    assert math.dist(rows[1]['finalNg'][:3],(0,1,0))<2e-6 and abs(rows[1]['probeHit'][3]-.06)<2e-6
    # An independent visibility consequence of the two already-recorded rays.
    # The finite black rectangle is a mathematical construction, not an actual
    # WARP/DXR intersection observation or a rendered image claim.
    origin_a,origin_b,direction=rows[0]['origin'],rows[1]['origin'],rows[0]['direction']
    length=math.sqrt(sum(v*v for v in direction));axis=[v/length for v in direction]
    delta=[b-a for a,b in zip(origin_a,origin_b)];parallel=sum(x*y for x,y in zip(delta,axis))
    transverse=[d-parallel*n for d,n in zip(delta,axis)];separation=math.sqrt(sum(v*v for v in transverse))
    assert separation>.001
    rectangle=dict(center=[a+d for a,d in zip(origin_a,direction)],normal=[-n for n in axis],
                   halfWidth=separation/4,rayAPlaneT=1,rayBPlaneT=1-parallel/length,rayBTransverseOffset=separation,
                   independentVisibility='Ray A intersects the centered small opaque rectangle; parallel Ray B misses it by four half-widths. This constructed geometry shows potential integrand change; it is not an actual scene radiance measurement.')
    save(B/'first-analysis-failure.json',dict(status='failed',reason='Aligned-control origin compared as raw bytes; only z signed zero differs (-0 versus +0). Original contract separately specifies exact bytes only for direction/weight/RNG; all original input/output/source bytes retained.',
        sourceSha256=sha(B/'run.py'),rawSha256=sha(B/'outputs.bin'),gpuRerun=False))
    result=dict(status='qualified with original analysis failure retained',counterexampleEstablished=True,rows=rows,pairs=pairs,independentVisibilityConstruction=rectangle,
        originalRawSha256=sha(B/'outputs.bin'),inputSha256=sha(B/'inputs.bin'),sourceSha256=sha(ROOT/'Runtime/Resources/HybridLumenGI/HybridLumenGIKernels.hlsl'),
        originalContractSha256=sha(B/'contract.json'),qualifierSha256=sha(Path(__file__)),originalSourcesUnchanged=True,gpuRerun=False,
        scope='Actual source receiver prelude, depth/geometry/world-match gates, sampler and GeometryOut; resource and finite-plane dependency adapters. No physical GPU, Unity scene, DXR traversal or rendered-color conclusion.')
    save(HERE/'qualified-analysis.json',result)
    print(json.dumps({k:v for k,v in result.items() if k not in ('rows','pairs','independentVisibilityConstruction')}))


if __name__=='__main__':main()
