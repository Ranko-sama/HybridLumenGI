"""Independent finite diffuse reference. Inputs: frozen scene and position-only targets.

No product radiance, BVH, SDF, cache, screen rays or product lighting evaluator is
read. NumPy double triangle tests use independent per-mesh bounding boxes only.
The comparator is a separate program and cannot steer this solver's samples.
"""
import argparse, hashlib, json, math, time
from pathlib import Path
import numpy as np

BATCHES, PATHS, DEPTH = 8, 4096, 64
SEED_ROOT = 0xC0012026
EPS = np.finfo(np.float64).eps
FLOAT_EPS = np.finfo(np.float32).eps


def vector(value, keys='xyz'):
    return np.array([value[k] for k in keys], dtype=np.float64)


def normalize(v):
    return v / np.linalg.norm(v, axis=-1, keepdims=True)


def srgb(v):
    return np.where(v <= .04045, v / 12.92, ((v + .055) / 1.055) ** 2.4)


def encoded_cache_normal(normal):
    # Representation correspondence only: independently encode a SOURCE normal
    # into the documented 5+5 bit oct grid, then decode it. It is not a tracer.
    octa=normal/np.sum(np.abs(normal));xy=octa[:2].copy()
    if octa[2]<0:xy=(1-np.abs(xy[::-1]))*np.where(xy>=0,1,-1)
    xy=np.rint((xy+1)*.5*31)*(2/31)-1
    decoded=np.array([xy[0],xy[1],1-np.sum(np.abs(xy))])
    if decoded[2]<0:decoded[:2]=(1-np.abs(xy[::-1]))*np.where(xy>=0,1,-1)
    return normalize(decoded)


def closest_triangle(p, a, b, c):
    # Plane projection inside face; otherwise closest among three closed edges.
    ab, ac = b-a, c-a
    n = normalize(np.cross(ab, ac))
    projection = p - np.dot(p-a, n)*n
    v0, v1, v2 = ab, ac, projection-a
    d00, d01, d11 = v0@v0, v0@v1, v1@v1
    den = d00*d11-d01*d01
    u = (d11*(v2@v0)-d01*(v2@v1))/den
    v = (d00*(v2@v1)-d01*(v2@v0))/den
    if u >= 0 and v >= 0 and u+v <= 1:
        return projection
    candidates = [x+np.clip((p-x)@(y-x)/((y-x)@(y-x)), 0, 1)*(y-x) for x,y in [(a,b),(b,c),(c,a)]]
    return min(candidates, key=lambda q: float((p-q)@(p-q)))


class Scene:
    def __init__(self, source):
        self.source = source
        assert source['linear'] and source['lightsUseLinearIntensity'] and not source['skybox'] and not source['fog']
        self.materials = {}
        for m in source['materials']:
            assert m['surface']==0 and m['alphaClip']==0 and not m['emissionEnabled']
            assert not any(t['assigned'] for t in m['textures'])
            assert m['cull']==2, 'Reference supports front-facing opaque closed surfaces only'
            assert not set(m['keywords'])-{'_SPECULAR_SETUP','_RECEIVE_SHADOWS_OFF','_SPECULARHIGHLIGHTS_OFF','_ENVIRONMENTREFLECTIONS_OFF'}
            albedo = srgb(vector(m['baseColor']['srgb'], 'rgb'))
            spec = srgb(vector(m['specularColor']['srgb'], 'rgb'))
            rho = albedo * (1-max(spec) if m['specularSetup'] else .96*(1-m['metallic']))
            assert np.all(rho >= 0) and np.all(rho < 1)
            self.materials[m['key']] = {'source':m,'rho':rho,'emission':np.zeros(3)}
        self.vertices=[];self.normals=[];self.tri_meta=[];self.groups=[];self.rhos=[];self.emissions=[]
        for mesh in source['meshes']:
            transform = np.array([[mesh['localToWorld'][f'e{i}{j}'] for j in range(4)] for i in range(4)])
            assert np.linalg.det(transform[:3,:3])>0, 'Mirrored source needs an explicit winding contract'
            vertices = np.array([vector(v) for v in mesh['vertices']])
            world = vertices@transform[:3,:3].T+transform[:3,3]
            normals = normalize(np.array([vector(n) for n in mesh['normals']])@np.linalg.inv(transform[:3,:3]))
            first=len(self.vertices)
            for sub in mesh['submeshes']:
                assert sub['topology']=='Triangles'
                material=self.materials[sub['material']]
                for tri,indices in enumerate(np.array(sub['indices']).reshape(-1,3)):
                    p=world[indices].copy();ns=normals[indices].copy()
                    assert np.max(np.linalg.norm(ns-ns[0],axis=1))<1e-6, 'This baseline requires flat source faces'
                    ng=normalize(np.cross(p[1]-p[0],p[2]-p[0]))
                    # Never repair source winding to make a reference pass. This
                    # fixed cube baseline has consistent winding and flat normals.
                    assert np.linalg.norm(ng-ns[0])<1e-6, 'Source winding disagrees with outward flat normal'
                    self.vertices.append(p);self.normals.append(ng);self.rhos.append(material['rho']);self.emissions.append(material['emission'])
                    self.tri_meta.append({'mesh':mesh['key'],'name':mesh['name'],'submesh':sub['index'],'triangle':tri,'material':sub['material'],
                                         'sourceWindingReversed':False,'layer':mesh['layer'],'renderingLayers':mesh['renderingLayers'],
                                         'castsShadow':mesh['shadowCastingMode']!=0,'twoSidedShadow':mesh['shadowCastingMode']==2,
                                         'receiveShadows':mesh['receiveShadows'] and material['source']['receiveShadows']})
            self.groups.append((first,len(self.vertices),world.min(0),world.max(0)))
        self.vertices=np.array(self.vertices);self.normals=np.array(self.normals);self.rhos=np.array(self.rhos);self.emissions=np.array(self.emissions)
        self.e1=self.vertices[:,1]-self.vertices[:,0];self.e2=self.vertices[:,2]-self.vertices[:,0]
        self.scale=max(1.,float(np.max(np.abs(self.vertices))))
        self.offset=64*EPS*self.scale
        active=[l for l in source['lights'] if l['enabled']];assert len(active)==1
        self.light=active[0];assert self.light['type']=='Point' and self.light['cookie']=='none' and self.light['bakeType']=='Realtime'
        assert not self.light['useTemperature'], 'Baseline has no temperature source; reject rather than approximate'
        self.lightpos=vector(self.light['position'])
        self.light_rgb=srgb(vector(self.light['color']['srgb'],'rgb'))*self.light['intensity']
        # The fixed source is white and uses the explicitly checked linear-intensity policy.
        assert np.array_equal(vector(self.light['color']['srgb'],'rgb'),np.ones(3))
        self.range2=self.light['range']**2
        self.dmin=min(np.linalg.norm(self.lightpos-closest_triangle(self.lightpos,*tri)) for tri in self.vertices)
        assert self.dmin>self.offset, 'No bounded source when point light lies on a surface'
        self.rmax=float(self.rhos.max());self.direct_max=float(self.light_rgb.max()/self.dmin**2)
        self.lo_max=self.rmax*self.direct_max/(1-self.rmax)
        self.tail_bound=self.rmax**DEPTH*self.lo_max

    def intersect(self, origin, direction, limit=None, shadow=False):
        n=len(origin);best=np.full(n,np.inf) if limit is None else np.array(limit,copy=True)
        hit=np.full(n,-1,dtype=np.int64)
        for first,end,minimum,maximum in self.groups:
            # Independent slab rejection; parallel axes are handled without 0*infinity.
            parallel=np.abs(direction)<EPS
            safe=np.where(parallel,1,direction)
            lo=(minimum-origin)/safe;hi=(maximum-origin)/safe
            near=np.minimum(lo,hi);far=np.maximum(lo,hi)
            outside=parallel&((origin<minimum-self.offset)|(origin>maximum+self.offset))
            near=np.where(parallel,-np.inf,near);far=np.where(parallel,np.inf,far)
            indices=np.flatnonzero(~np.any(outside,axis=1)&(np.max(near,axis=1)<=np.minimum(np.min(far,axis=1),best))&(np.min(far,axis=1)>0))
            if not len(indices):continue
            ids=np.arange(first,end)
            if shadow:
                ids=np.array([i for i in ids if self.tri_meta[i]['castsShadow'] and
                    ((self.light['cullingMask'] & (1<<self.tri_meta[i]['layer']))!=0) and
                    (not self.source['lightLayers'] or (self.light['shadowLayers']&self.tri_meta[i]['renderingLayers'])!=0)])
                if not len(ids):continue
            o=origin[indices,None,:];d=direction[indices,None,:]
            pvec=np.cross(d,self.e2[ids]);det=np.einsum('rtj,tj->rt',pvec,self.e1[ids])
            area=np.linalg.norm(np.cross(self.e1[ids],self.e2[ids]),axis=1)
            determinant_eps=32*EPS*area
            valid=det>determinant_eps
            if shadow:
                both=np.array([self.tri_meta[i]['twoSidedShadow'] for i in ids]);valid=np.where(both,np.abs(det)>determinant_eps,valid)
            inv=np.divide(1.,det,out=np.zeros_like(det),where=valid)
            tvec=o-self.vertices[ids,0];u=np.einsum('rtj,rtj->rt',tvec,pvec)*inv
            qvec=np.cross(tvec,self.e1[ids]);v=np.einsum('rtj,rtj->rt',d,qvec)*inv
            distance=np.einsum('rtj,tj->rt',qvec,self.e2[ids])*inv
            valid &= (u>=-32*EPS)&(v>=-32*EPS)&(u+v<=1+32*EPS)&(distance>self.offset)&(distance<best[indices,None])
            candidate=np.where(valid,distance,np.inf);which=np.argmin(candidate,axis=1);values=candidate[np.arange(len(indices)),which]
            update=np.isfinite(values);selected=indices[update];best[selected]=values[update];hit[selected]=ids[which[update]]
        return best,hit

    def direct(self, positions, normals, surfaces, offsets):
        delta=self.lightpos-positions;distance2=np.einsum('ij,ij->i',delta,delta);distance=np.sqrt(distance2);directions=delta/distance[:,None]
        cosine=np.maximum(0,np.einsum('ij,ij->i',normals,directions))
        attenuation=np.maximum(0,1-(distance2/self.range2)**2)**2/distance2
        allowed=np.array([(self.light['cullingMask']&(1<<self.tri_meta[int(t)]['layer']))!=0 and
            (not self.source['lightLayers'] or (self.light['renderingLayers']&self.tri_meta[int(t)]['renderingLayers'])!=0) for t in surfaces])
        visibility=np.ones(len(positions))
        receive=np.array([self.tri_meta[int(t)]['receiveShadows'] for t in surfaces])
        if self.light['shadows']!=0:
            selected=np.flatnonzero((cosine>0)&allowed&receive)
            if len(selected):
                origins=positions[selected]+normals[selected]*np.asarray(offsets)[selected,None]
                to_light=self.lightpos-origins;length=np.linalg.norm(to_light,axis=1);d=to_light/length[:,None]
                _,obstacle=self.intersect(origins,d,length-self.offset,shadow=True)
                visibility[selected]=np.where(obstacle>=0,1-self.light['shadowStrength'],1)
        return self.light_rgb*(cosine*attenuation*visibility*allowed)[:,None]

    def correspondence(self, target):
        p=vector(target['position']);ns=normalize(vector(target['normal']));ng=normalize(vector(target['geometricNormal']))
        tolerance=16*FLOAT_EPS*max(1,float(np.max(np.abs(p))))
        candidates=[]
        for index,tri in enumerate(self.vertices):
            closest=closest_triangle(p,*tri);error=float(np.linalg.norm(p-closest))
            expected=encoded_cache_normal(self.normals[index]) if target['kind']=='cache' else self.normals[index]
            normal_tolerance=.002 if target['kind']=='cache' else .02
            if error<=tolerance and np.linalg.norm(ng-expected)<=normal_tolerance and np.linalg.norm(ns-self.normals[index])<=.02:
                candidates.append({'index':index,'distance':error,'geometricNormalSource':self.normals[index].tolist(),
                    'geometricNormalRepresentationExpected':expected.tolist(),'geometricNormalRawDistance':float(np.linalg.norm(ng-self.normals[index])),
                    'geometricNormalRepresentationDistance':float(np.linalg.norm(ng-expected)),**self.tri_meta[index]})
        assert candidates, ('No source surface for target',target['id'],tolerance)
        first=candidates[0]
        # Coplanar triangulation alternatives on the SAME renderer/material are equivalent.
        assert all(c['mesh']==first['mesh'] and c['material']==first['material'] and
                   np.linalg.norm(self.normals[c['index']]-self.normals[first['index']])<1e-8 and
                   abs((self.vertices[c['index'],0]-self.vertices[first['index'],0])@self.normals[first['index']])<64*EPS*self.scale for c in candidates), ('Ambiguous source surface',target['id'],candidates)
        if target['kind']=='cache':assert first['name']=='Thin-wall floor'
        return {'id':target['id'],'position':p.tolist(),'normal':ns.tolist(),'geometricNormal':ng.tolist(),'positionTolerance':float(tolerance),
                'shadingNormalVectorTolerance':.02,'geometricNormalRepresentationTolerance':.002 if target['kind']=='cache' else .02,
                'originOffset':float(tolerance),'snapped':False,'sourceTriangle':first['index'],'candidates':candidates}


def cosine_directions(rng,normals):
    random=rng.random((len(normals),2));radius=np.sqrt(random[:,0]);phi=2*math.pi*random[:,1]
    helper=np.zeros_like(normals);helper[:,2]=1;near=np.abs(normals[:,2])>.9;helper[near]=[1,0,0]
    tangent=normalize(np.cross(helper,normals));bitangent=np.cross(normals,tangent)
    return tangent*(radius*np.cos(phi))[:,None]+bitangent*(radius*np.sin(phi))[:,None]+normals*np.sqrt(1-random[:,0])[:,None]


def integrate(scene,target,index):
    p=np.array(target['position']);normal=np.array(target['geometricNormal']);ns=np.array(target['normal'])
    direct=scene.direct(p[None,:],ns[None,:],np.array([target['sourceTriangle']]),np.array([target['originOffset']]))[0]
    batches=[]
    for batch in range(BATCHES):
        seed=[SEED_ROOT,index,batch];rng=np.random.Generator(np.random.PCG64(np.random.SeedSequence(seed)))
        origins=np.tile(p+normal*target['originOffset'],(PATHS,1));directions=cosine_directions(rng,np.tile(ns,(PATHS,1)))
        beta=np.ones((PATHS,3));contributions=np.zeros((DEPTH,3));termination=np.zeros(DEPTH+2,dtype=np.int64)
        for depth in range(DEPTH):
            distance,surface=scene.intersect(origins,directions)
            found=surface>=0;termination[depth]+=int((~found).sum())
            if not found.any():break
            origins=origins[found]+directions[found]*distance[found,None];surface=surface[found];beta=beta[found];ng=scene.normals[surface]
            d=scene.direct(origins,ng,surface,np.full(len(origins),scene.offset))
            lo=scene.emissions[surface]+scene.rhos[surface]*d
            contributions[depth]=(beta*lo).sum(0)/PATHS
            beta*=scene.rhos[surface]
            live=np.any(beta>0,axis=1);termination[depth+1]+=int((~live).sum())
            origins=origins[live];beta=beta[live];ng=ng[live]
            if not live.any():break
            if depth==DEPTH-1:termination[-1]+=len(origins);break
            origins=origins+ng*scene.offset;directions=cosine_directions(rng,ng)
        assert termination.sum()==PATHS
        batches.append({'seed':seed,'mean':contributions.sum(0).tolist(),'bounceContributions':contributions.tolist(),'terminationDepthCounts':termination.tolist()})
        print(json.dumps({'target':target['id'],'batch':batch,'paths':PATHS,'mean':batches[-1]['mean']}),flush=True)
    values=np.array([b['mean'] for b in batches]);mean=values.mean(0);se=values.std(0,ddof=1)/math.sqrt(BATCHES)
    # Approximate Student-t interval is descriptive, not a guaranteed path-integral bound.
    half=2.364624251*se
    # A simultaneous bound across 6 targets * 3 channels, independent bounded paths.
    strict_half=scene.lo_max*math.sqrt(math.log(2*18/.05)/(2*BATCHES*PATHS))
    precision_budget=1e-4+.1*np.abs(mean)  # reference precision only; never a GPU acceptance threshold
    qualified=bool(np.all(strict_half+scene.tail_bound<=precision_budget))
    return {'id':target['id'],'quantity':'C = indirect incident diffuse E/pi; target rho not multiplied',
            'directSeparate':direct.tolist(),'meanFinite64':mean.tolist(),'batchStandardError':se.tolist(),
            'approximateT95HalfWidth':half.tolist(),'strictSimultaneous95HalfWidth':strict_half,'strictNonnegativeTailBound':scene.tail_bound,
            'referencePrecisionBudget':precision_budget.tolist(),'referenceEstimateQualified':qualified,'batches':batches}


def main():
    p=argparse.ArgumentParser();p.add_argument('--scene',type=Path,required=True);p.add_argument('--targets',type=Path,required=True);p.add_argument('--out',type=Path,required=True);args=p.parse_args()
    args.out.mkdir(parents=True,exist_ok=True)
    assert not (args.out/'started.json').exists(), 'Fixed reference batches may only run once for this package'
    raw=args.scene.read_bytes();target_raw=args.targets.read_bytes()
    inputs={'sceneSha256':hashlib.sha256(raw).hexdigest(),'targetsSha256':hashlib.sha256(target_raw).hexdigest(),
            'solverSha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'batches':BATCHES,'pathsPerBatch':PATHS,'maxDiffuseVertices':DEPTH,'seedRoot':SEED_ROOT}
    (args.out/'started.json').write_text(json.dumps(inputs,indent=2),encoding='utf-8')
    scene=Scene(json.loads(raw));targets=json.loads(target_raw)['targets'];assert len(targets)==6
    correspondence=[scene.correspondence(t) for t in targets]
    (args.out/'correspondence.json').write_text(json.dumps({'verified':True,'targets':correspondence},indent=2),encoding='utf-8')
    results=[];start=time.monotonic()
    for index,target in enumerate(correspondence):
        result=integrate(scene,target,index);results.append(result)
        (args.out/(target['id']+'.json')).write_text(json.dumps(result,indent=2),encoding='utf-8')
    result={**inputs,'historicalSourceClosure':False,'targetSurfaceCorrespondenceVerified':True,'integrationExecuted':True,
            'referenceEstimateQualified':all(r['referenceEstimateQualified'] for r in results),'elapsedSeconds':time.monotonic()-start,
            'sourceBounds':{'maxDiffuseReflectance':scene.rmax,'minimumPointLightSurfaceDistance':scene.dmin,'maxDirect':scene.direct_max,'maxLo':scene.lo_max,'tail64':scene.tail_bound},
            'sourceMaterials':{key:{'rho':m['rho'].tolist(),'emission':m['emission'].tolist()} for key,m in scene.materials.items()},'results':results}
    (args.out/'reference.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
    print(json.dumps({'integrationExecuted':True,'targetCount':len(results),'referenceEstimateQualified':result['referenceEstimateQualified'],'elapsedSeconds':result['elapsedSeconds']}))


if __name__=='__main__':main()
