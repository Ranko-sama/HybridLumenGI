"""Layered, prospectively bounded finite cache/gather arithmetic.

Intervals follow the arithmetic DAG; measured cache RGB is never an operand.
The tolerance is an explicit arithmetic contract, not a fitted image threshold.
"""
import math
import struct
from finite_reference import trace, dot, reflectance

EPS=2**-23
NORMAL_OPS=32
WEIGHT_OPS=8
CACHE_RATIO_OPS=8
RCP_RELATIVE=2**-21


def f32(x):return struct.unpack('<f',struct.pack('<f',x))[0]


def next32(value,direction):
    value=f32(value)
    if value==0:return direction*2**-149
    bits=struct.unpack('<I',struct.pack('<f',value))[0]
    bits+=1 if (value>0)==(direction>0) else -1
    return struct.unpack('<f',struct.pack('<I',bits))[0]


class I:
    def __init__(self,low,high=None):self.low=float(low);self.high=float(low if high is None else high)
    def values(self):return [self.low,self.high]
    def contains(self,value):return math.isfinite(value) and self.low<=value<=self.high
    def zero(self):return self.low==self.high==0
    def exact(self,value):return self.low==self.high==value
    @staticmethod
    def of(value):return value if isinstance(value,I) else I(value)
    @staticmethod
    def rounded(low,high):
        if low==high==0:return I(0)
        # Adjacent values around RN endpoints cover a full allowed binary32 ULP
        # and endpoint conversion; our finite positive normal values never FTZ.
        return I(next32(f32(low),-1),next32(f32(high),1))
    def __add__(self,other):
        other=I.of(other)
        if self.zero():return other
        if other.zero():return self
        return I.rounded(self.low+other.low,self.high+other.high)
    __radd__=__add__
    def __neg__(self):return I(-self.high,-self.low)
    def __sub__(self,other):return self+-I.of(other)
    def __mul__(self,other):
        other=I.of(other)
        if self.zero() or other.zero():return I(0)
        if self.exact(1):return other
        if other.exact(1):return self
        values=[x*y for x in (self.low,self.high) for y in (other.low,other.high)]
        return I.rounded(min(values),max(values))
    __rmul__=__mul__
    def __truediv__(self,other):
        other=I.of(other);assert other.low>0
        if self.zero():return I(0)
        if other.exact(1):return self
        values=[x/y for x in (self.low,self.high) for y in (other.low,other.high)]
        direct=I.rounded(min(values),max(values))
        # D3D division can lower to reciprocal followed by multiply. The
        # instruction reciprocal's published 2^-21 relative error is included
        # explicitly; it is not silently borrowed from an upstream allowance.
        reciprocal=I((1/other.high)*(1-RCP_RELATIVE),(1/other.low)*(1+RCP_RELATIVE))
        lowered=self*reciprocal
        return I(min(direct.low,lowered.low),max(direct.high,lowered.high))
    def nonnegative(self):return I(max(0,self.low),max(0,self.high))


def gamma(n):return n*EPS/(1-n*EPS)
def factor(n):return I(1-gamma(n),1+gamma(n))


def blend(old,estimate,alpha):
    # DXC may form either lerp expression, optionally FMA. Both evaluate the
    # same real expression. Include both uncontracted envelopes, which include
    # the fused result by retaining the exact expression at each operation.
    a=old+(estimate-old)*alpha
    b=old*(I(1)-alpha)+estimate*alpha
    return I(max(0,min(a.low,b.low)),max(a.high,b.high))


def half_rne(x):return struct.unpack('<e',struct.pack('<e',x))[0]


def half_rtz(x):
    assert x>=0
    nearest=half_rne(x)
    if nearest<=x:return nearest
    bits=struct.unpack('<H',struct.pack('<e',nearest))[0]
    return struct.unpack('<e',struct.pack('<H',bits-1))[0]


def storage(interval):
    assert interval.low>=0 and interval.high<65504
    if interval.zero():return [0,0]
    return [half_rtz(interval.low),half_rne(interval.high)]


def rho(source,owner):
    wall=next(w for w in source['walls'] if w['id']==owner)
    return [I(f32(.96))*I(v) for v in wall['shaderLinearBaseColor']]


def outgoing(source,hit,atlas,cache,light_on):
    owner=hit['owner'];support=atlas.support(hit)
    # Constant axis normals, identical source vertex normals and identity
    # transforms: transverse components remain exactly zero. The lit axis may
    # incur barycentric / normalization error (32 first-order operations).
    direct=I(1-gamma(NORMAL_OPS),1) if light_on and owner=='A' else I(0)
    cached=[value*factor(CACHE_RATIO_OPS) if support else I(0) for value in cache[owner]]
    value=[r*(direct+c) for r,c in zip(rho(source,owner),cached)]
    return value,support


def estimate(source,atlas,origin,normal,directions,cache,light_on):
    total=[I(0),I(0),I(0)];nominal=[0.,0.,0.];records=[]
    for direction in directions:
        assert dot(normal,direction)>1e-8,'Cosine denominator floor would change the estimator'
        hit=trace(source,origin,direction,source['settings']['maxDistance'])
        if hit:
            value,support=outgoing(source,hit,atlas,cache,light_on)
            total=[a+b*factor(WEIGHT_OPS) for a,b in zip(total,value)]
            records.append(dict(owner=hit['owner'],position=hit['position'],distance=hit['distance'],cacheSupported=support))
        else:records.append(None)
    divisor=len(directions)
    return [x/divisor for x in total],records


def build(source,atlas_frames,gather_frames):
    cache={'A':[I(0)]*3,'B':[I(0)]*3};frames=[];samples=None
    for atlas,groups in zip(atlas_frames,gather_frames):
        logical=atlas.receipt['logicalFrame'];assert logical in (31,32,33)
        if samples is None:samples={name:p['samples'] for name,p in atlas.owners.items()}
        old=cache;next_cache={};cache_rows={}
        for owner,patch in atlas.owners.items():
            assert patch['samples']==samples[owner],'Input sample-count Jacobi chain differs'
            prepared=min(samples[owner],1) if logical==32 else samples[owner]
            count=min(prepared+1,32);alpha=I(1)/count
            if alpha.low<f32(.1):alpha=I(f32(.1),max(f32(.1),alpha.high))
            incoming,hits=estimate(source,atlas,patch['origin'],patch['normal'],patch['directions'],old,logical>31)
            updated=[blend(a,b,alpha) for a,b in zip(old[owner],incoming)]
            next_cache[owner]=updated;samples[owner]=count
            cache_rows[owner]=dict(card=patch['index'],oldSamples=patch['samples'],preparedSamples=prepared,samples=count,alphaInterval=alpha.values(),
                                   estimateIntervals=[i.values() for i in incoming],rgbIntervals=[i.values() for i in updated],independentIntersections=hits)
        cache=next_cache;gathers=[]
        for group in groups:
            value,hits=estimate(source,atlas,group['origin'],group['shadingNormal'],group['directions'],cache,logical>31)
            gathers.append(dict(id=group['id'],pixel=group['pixel'],receiverOwner=group['receiverOwner'],
                                rgbIntervals=[i.values() for i in value],storageIntervals=[storage(i) for i in value],independentIntersections=hits))
        frames.append(dict(logicalFrame=logical,workFrame=atlas.receipt['workFrame'],cache=cache_rows,gather=gathers,atlasQualification=atlas.report()))
    # The fixture must exercise both feedback orders, rather than pass on black
    # or direct-only data. This is decided before any observed RGB is opened.
    assert any(row['rgbIntervals'][0][0]>0 for owner,row in frames[2]['cache'].items() if owner=='A'),'No second-order cache path in frozen directions'
    b_groups=[g for g in frames[2]['gather'] if g['receiverOwner']=='B']
    assert any(any(h and h['owner']=='A' and h['cacheSupported'] for h in g['independentIntersections']) for g in b_groups),'No third-order receiver path in frozen directions'
    return dict(schemaVersion=1,signal=source['signal'],frames=frames,
                arithmeticContract=dict(binary32BasicOperations='Every nontrivial interval operation encloses adjacent float32 values around RN endpoints (one-ULP operation allowance); zero-preserving operations stay exact zero.',
                    sourceRho='float32(0.96) multiplied by shader-linear dyadic base color, unit tint; no receiver rho inside raw D',
                    normalNormalizationOperations=NORMAL_OPS,samplingWeightOperations=WEIGHT_OPS,correlatedSingleCellMultiplyDivideOperations=CACHE_RATIO_OPS,
                    reciprocalRelativeError=RCP_RELATIVE,division='Union of directly rounded division and reciprocal (2^-21 relative) followed by rounded multiply. Weight gamma8 encloses reciprocal plus multiply; grid-one ratio gamma8 encloses first multiply, reciprocal and last multiply.',
                    accumulation='16 ray multiply/adds and division for each cache estimate; actual alpha=min/max sample recurrence and both lerp forms; 8 ray multiply/adds and division for gather',
                    storage='positive finite final binary16 interval [RTZ(lower), RNE(upper)]; exact black remains [0,0]',
                    scope='Conditional finite input/DXR geometric classification and stated arithmetic implementation class; not a universal hardware error theorem'),
                expectedConstructedWithoutProductRGB=True,nativeAccepted=False)


def contains(ranges,values):
    return len(values)==len(ranges) and all(math.isfinite(v) and low<=v<=high for (low,high),v in zip(ranges,values))


def compare(ranges,rgba):return len(rgba)==4 and math.isfinite(rgba[3]) and rgba[3]>0 and contains(ranges,rgba[:3])
