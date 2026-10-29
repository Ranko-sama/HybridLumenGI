"""Independent geometry qualification for the two finite, one-cell charts.

Only geometry, identity, mask and history-count input files are opened here.
The DXR position localization box is an explicit conditional hypothesis, not a
portable RayT error guarantee. Ambiguous lookup decisions reject qualification.
"""
import hashlib
import itertools
import json
import math
from pathlib import Path
import struct

from finite_reference import EPS, dot

LOCALIZATION_ULPS = 64


def require(condition, message):
    if not condition: raise AssertionError(message)


def f32(x): return struct.unpack('<f', struct.pack('<f', x))[0]
def finite(xs): return all(math.isfinite(x) for x in xs)
def normalize(v):
    length=math.sqrt(dot(v,v));require(length>0, 'Zero geometric normal')
    return [x/length for x in v]


def oct_decode(x,y):
    z=1-abs(x)-abs(y)
    if z<0: x,y=(1-abs(y))*(1 if x>=0 else -1),(1-abs(x))*(1 if y>=0 else -1)
    return normalize([x,y,z])


def decode_code(code):
    require(code==int(code) and 1<=code<=1024, 'Invalid source coverage code')
    bits=int(code)-1
    return oct_decode((bits&31)*2/31-1, (bits>>5)*2/31-1)


def project(matrix, position):
    return [sum(matrix[c*4+r]*value for c,value in enumerate([*position,1])) for r in range(3)]


def chunks(data,fmt):
    stride=struct.calcsize(fmt);require(len(data)%stride==0,'Invalid input record length')
    return list(struct.iter_unpack(fmt,data))


def unpack_cards(data):
    rows=[]
    for values in chunks(data,'<24f8I'):
        rows.append(dict(matrix=values[:16],rect=values[16:20],direction=values[20:24],
                         stableId=values[24],revision=values[25],generation=values[26],ready=values[27],
                         ownerSlot=values[28],chartId=values[29],layoutGeneration=values[30],flags=values[31]))
    return rows


class AtlasFrame:
    def __init__(self,directory,receipt,source):
        self.receipt=receipt;self.source=source;self.hashes={};self.owners={};self.queries=[]
        prefix='frame-%03d-'%receipt['logicalFrame'];directory=Path(directory)
        def read(name):
            data=(directory/(prefix+name+'.bin')).read_bytes()
            self.hashes[name]=hashlib.sha256(data).hexdigest();return data
        self.cards=unpack_cards(read('cards'))
        ranges=chunks(read('owner-ranges'),'<4I');indices=chunks(read('card-indices'),'<I')
        anchors=chunks(read('anchors'),'<2i');mask=chunks(read('mask'),'<I')
        identities=chunks(read('owner-identities'),'<4f');self.cache_state=chunks(read('cache-state-inputs'),'<16f')
        globals_data=read('globals');require(len(globals_data)==80,'Globals shape')
        global_uint=chunks(globals_data,'<4I');global_float=chunks(globals_data,'<4f')
        require(global_uint[0]==(receipt['workFrame'],receipt['epoch'],receipt['cacheReadIndex'],receipt['logicalFrame']),'Actual dispatch identity differs')
        require(global_uint[1]==(receipt['proxyCount'],receipt['cardCount'],1,16),'Actual cache dimensions differ')
        require(global_uint[3]==(receipt['changeCount'],receipt['lightCount'],2,1024),'Actual source metadata differs')
        self.global_reactive=global_float[2][2];self.global_geometry=global_float[2][3]
        require(global_float[2][:2]==(f32(.03),1) and self.global_geometry==0,'Cache settings/geometry changed')
        require(self.global_reactive==(1 if receipt['logicalFrame']==32 else 0),'Fixed light change schedule differs')
        require(receipt['lightCount']==(0 if receipt['logicalFrame']==31 else 1),'Fixed source enable schedule differs')
        dimensions=global_float[4][:2]
        require(all(v==int(v) and 1<=v<=32768 for v in dimensions),'Atlas dimensions invalid')
        require(len(self.cards)==len(anchors)==len(mask)==len(self.cache_state)==receipt['cardCount'],'Card input capacity differs')
        require(len(ranges)==len(identities)==receipt['proxyCount'],'Owner input capacity differs')
        self.changes=chunks(read('changes'),'<12f')
        require(len(self.changes)==1088 and 0<=receipt['changeCount']<=1088,'Change capacity differs')
        require(all(all(v==0 for v in row) for row in self.changes[receipt['changeCount']:]),'Unused change input is nonzero')
        atlas=chunks(read('atlas-inputs'),'<12f');require(len(atlas)==2048,'Atlas geometry row count')
        cache_rays=read('cache-inputs');require(len(cache_rays)==2*16*128,'Cache input row count')
        require([owner['id'] for owner in receipt['owners']]==['A','B'],'Authored owner ordering differs')
        for active,owner in enumerate(receipt['owners']):
            name=owner['id'];wall=next(w for w in source['walls'] if w['id']==name)
            slot,index=owner['slot'],owner['card'];card=self.cards[index];identity=identities[slot];rng=ranges[slot]
            require(finite(identity) and identity[3]==1 and identity[0]>0 and identity[1]>0,'Owner is not a published triangle source')
            require(rng[1:]==(1,owner['layoutGeneration'],owner['geometryRevision']) and indices[rng[0]][0]==index,'One real chart range differs')
            require(card['ownerSlot']==slot and card['stableId']==identity[0] and card['revision']==identity[1] and card['ready']==1,'Current card identity differs')
            require(card['generation']==owner['generation']>0 and card['layoutGeneration']==owner['layoutGeneration']>0,'Card generation differs')
            require(card['flags']&1 and ((card['flags']>>1)&3)==2,'Real CullBack chart required')
            for key,value in [('primitiveCards',index),('primitiveCharts',card['chartId']),('primitiveLayouts',card['layoutGeneration']),('primitiveGeometry',owner['geometryRevision'])]:
                require(owner[key]==[value,value],'Actual committed triangle binding differs: '+key)
            require(finite(card['matrix']+card['rect']+card['direction']),'Nonfinite chart geometry')
            minimum=[round(card['rect'][i]*dimensions[i]) for i in range(2)]
            count=[round(card['rect'][i+2]*dimensions[i]) for i in range(2)]
            require(all(0<=minimum[i]<minimum[i]+count[i]<=dimensions[i] for i in range(2)) and count[0]*count[1]<=1024,'Atlas rectangle invalid')
            require(dot(card['direction'][:3],wall['normal'])>.9,'Card faces a different authored plane')
            texels={};covered=0
            for k,row in enumerate(atlas[active*1024:(active+1)*1024]):
                if k>=count[0]*count[1]:
                    require(all(v==0 for v in row),'Unused atlas geometry rows must be zero');continue
                pixel=(minimum[0]+k%count[0],minimum[1]+k//count[0])
                require(row[9:]==(*pixel,1) and finite(row),'Atlas texel identity/finite data differs')
                texels[pixel]=row
                if row[8]==0: continue
                ng=decode_code(row[8]);covered+=1
                require(abs(row[wall['axis']])<=8*EPS and 0<=row[3]<=1,'Captured position is not on authored plane')
                require(math.dist(row[4:7],wall['normal'])<=8*EPS and dot(ng,wall['normal'])>.99,'Captured normals differ from constant source')
                require(all(-8*EPS<=row[i]<=1+8*EPS for i in range(3) if i!=wall['axis']),'Captured position outside finite wall')
                uv=project(card['matrix'],row[:3])
                # Orthographic card coordinates may flip one raster dimension.
                # Validate depth/plane independently, and nearest lookup per query below.
                require(all(-16*EPS<=v<=1+16*EPS for v in uv) and abs(uv[2]-row[3])<=64*EPS,'Captured card coordinate/depth differs')
            anchor=anchors[index];require(anchor in texels and texels[anchor][8]>0 and mask[index][0]==1,'No known covered scheduled patch')
            first=None;directions=[]
            for sample in range(16):
                offset=(active*16+sample)*128;values=struct.unpack_from('<20f',cache_rays,offset)
                meta=struct.unpack_from('<12I',cache_rays,offset+80)
                require(meta==(index,index,0,0,slot,receipt['workFrame'],receipt['epoch'],sample,*anchor,owner['generation'],1),'Cache ray identity differs')
                require(finite(values) and values[3]==1 and values[7]==values[11]==values[15]==values[19]==0,'Invalid cache ray input')
                require(abs(dot(values[4:7],values[4:7])-1)<2e-5 and dot(values[12:15],values[4:7])>1e-8,'Cache sampler not positive cosine domain')
                if first is None:first=values
                else:require(values[:4]==first[:4] and values[8:20]==first[8:20],'One patch input changes within its ray set')
                directions.append(list(values[4:7]))
            row=texels[anchor];require(first[8:11]==row[:3] and math.dist(first[12:15],wall['normal'])<8*EPS and math.dist(first[16:19],decode_code(row[8]))<8*EPS,'Patch input differs from geometry atlas anchor')
            predicted=[first[8+i]+first[16+i]*f32(.03) for i in range(3)]
            require(math.dist(first[:3],predicted)<8*EPS,'Patch bias origin differs')
            state=self.cache_state[index];require(finite(state) and 1<=state[0]<=32 and state[1:4]==(0,0,0),'Old cache input lacks a measured history')
            require(state[4:8]==(identity[0],identity[1],receipt['epoch'],owner['generation']),'Old cache scalar identity is stale')
            require(math.dist(state[8:11],row[:3])<8*EPS and math.dist(state[12:15],wall['normal'])<8*EPS,'Stored cache geometry differs from anchor')
            stored_ng=oct_decode(state[11],state[15])
            require(math.dist(stored_ng,first[16:19])<16*EPS,'Stored packed cache Ng differs from the atlas Ng')
            # Changes are independent scalar metadata; no radiance is read.
            reactive=self.global_reactive
            for change in self.changes[:receipt['changeCount']]:
                require(finite(change),'Nonfinite change region')
                outside=[max(change[i]-row[i],row[i]-change[4+i],0) for i in range(3)]
                distance=dot(outside,outside)
                require(not(change[3]>.5 and distance<=1e-8),'Geometry/material change invalidates the fixed patch')
                if distance<=change[7]**2:reactive=max(reactive,1)
            require(reactive==(1 if receipt['logicalFrame']==32 else 0),'Patch change history differs from fixed source event')
            self.owners[name]=dict(owner=owner,card=card,identity=identity,minimum=minimum,count=count,texels=texels,covered=covered,
                position=list(first[8:11]),normal=list(first[12:15]),geometricNormal=list(first[16:19]),storedGeometricNormal=stored_ng,
                origin=list(first[:3]),directions=directions,samples=state[0],index=index,anchor=list(anchor))

    def support(self,hit):
        """Certify a uniform support decision over the declared position box."""
        patch=self.owners[hit['owner']];card=patch['card'];wall=next(w for w in self.source['walls'] if w['id']==hit['owner'])
        position=hit['position'];radius=LOCALIZATION_ULPS*EPS*max(1,hit['distance'],*(abs(x) for x in position))
        projected=project(card['matrix'],position)
        errors=[sum(abs(card['matrix'][c*4+r])*radius for c in range(3))+8*EPS*sum(abs(card['matrix'][c*4+r]*v) for c,v in enumerate([*position,1])) for r in range(3)]
        require(all(0<projected[i]-errors[i]<=projected[i]+errors[i]<1 for i in range(3)),'Query card boundary is ambiguous')
        candidates=[]
        for j in range(2):
            low=math.floor((projected[j]-errors[j])*patch['count'][j]);high=math.floor((projected[j]+errors[j])*patch['count'][j])
            candidates.append(range(low+patch['minimum'][j],high+patch['minimum'][j]+1))
        tolerance=max(card['direction'][3],.002);depth_scale=max(math.sqrt(sum(card['matrix'][c*4+2]**2 for c in range(3))),1e-8)
        outcomes=[];minimum_margin=math.inf
        for pixel in itertools.product(*candidates):
            row=patch['texels'][pixel]
            if row[8]==0:outcomes.append(False);continue
            delta=[row[i]-position[i] for i in range(3)]
            # Lipschitz bounds cover all position-box corners plus dot arithmetic.
            geometric_error=math.sqrt(3)*radius+32*EPS*max(1,tolerance)
            margins=[tolerance-math.sqrt(dot(delta,delta)),max(.002,tolerance*.3)-abs(delta[wall['axis']]),
                     tolerance-abs(row[3]-projected[2])/depth_scale]
            errors_by_gate=[geometric_error,radius+32*EPS,errors[2]/depth_scale+32*EPS]
            decisions=[]
            for margin,error in zip(margins,errors_by_gate):
                require(abs(margin)>error,'Atlas geometric lookup threshold is ambiguous')
                decisions.append(margin>0);minimum_margin=min(minimum_margin,abs(margin)-error)
            outcomes.append(all(decisions))
        require(len(set(outcomes))==1,'Possible neighboring atlas texels disagree on support')
        supported=outcomes[0]
        if supported:
            ng=patch['storedGeometricNormal'];delta=[position[i]-patch['position'][i] for i in range(3)]
            margin=max(f32(.03)*2,.03)-abs(dot(delta,ng))
            require(abs(margin)>math.sqrt(3)*radius+32*EPS,'Cached anchor plane threshold is ambiguous')
            supported=margin>0
            require(dot(wall['normal'],ng)>.85+32*EPS and dot(wall['normal'],patch['normal'])>.85+32*EPS,'Cache normal support differs')
            if supported:
                origin=[position[i]+wall['normal'][i]*f32(.03) for i in range(3)]
                target=[patch['position'][i]+ng[i]*f32(.03) for i in range(3)]
                # Both endpoints strictly in x,z>0 proves the full segment cannot
                # cross either finite source wall. No product visibility answer.
                require(all(min(origin[i],target[i])>radius+32*EPS for i in (0,2)),'Cache connection lacks an interior convex-quadrant certificate')
        record=dict(owner=hit['owner'],position=position,localizationRadius=radius,candidateTexels=[list(v) for v in itertools.product(*candidates)],
                    supported=supported,minimumAtlasGateMargin=None if minimum_margin==math.inf else minimum_margin)
        self.queries.append(record);return supported

    def report(self):
        return dict(inputSha256=self.hashes,patches={name:{k:p[k] for k in ('index','anchor','position','normal','geometricNormal','storedGeometricNormal','samples','covered')} for name,p in self.owners.items()},
                    queries=self.queries,localizationHypothesis='Actual DXR hit point lies within 64 binary32 epsilon times max(1, ideal RayT, abs(world)) on each coordinate of the independent rectangle point. This is a predeclared source-consistency hypothesis, NOT a cross-hardware DXR error theorem.',
                    finiteMaterialQualification='Hash-matched constant Lit material, identity geometry and capture shader prove finite diffuse/emission values; these RGB values are not read by the geometry observer.',readsProductRGB=False)
