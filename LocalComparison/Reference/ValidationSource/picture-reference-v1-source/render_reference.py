"""Source-only CPU diffuse picture reference, with MC error and explicit model limits."""
from __future__ import annotations
import argparse
import json
import math
import os
import pathlib
import sys
import time

# Optional private CPU dependencies; no install or network operation in the renderer.
bootstrap=argparse.ArgumentParser(add_help=False);bootstrap.add_argument('--dependency-dir')
early,_=bootstrap.parse_known_args()
if early.dependency_dir:sys.path.insert(0,str(pathlib.Path(early.dependency_dir).resolve(strict=True)))
import numpy as np
import numba
from loader import load, parse, digest, InputError
from geometry import Camera, render_primary, RECEIVER
from lighting import Lighting
from materials import texture_bound
from audit_lighting import verify_semantics
from primary import write_json
from mc_kernel import build_bvh,render


def pack(model):
    if model.unsupported:raise InputError('Unsupported lighting: '+';'.join(model.unsupported))
    environment=model.snapshot['environment']
    if (environment.get('ambientMode')!='Flat' or np.any(np.asarray(environment.get('ambientLight',[])[:3])!=0)
        or environment.get('ambientIntensity')!=0 or environment.get('reflectionIntensity')!=0
        or environment.get('fog') is not False or environment.get('lightmaps')!=[] or environment.get('lightProbeCount')!=0
        or np.any(np.asarray(environment.get('hlgiEnvironmentRadiance',[])[:3])!=0)
        or texture_bound(environment.get('hlgiEnvironmentCubemap')) or environment.get('skybox',{}).get('shader')):
        raise InputError('This first picture solver requires the exported black environment, no baked light/fog/skybox')
    scene=model.scene;n=len(scene.records)
    if not n:raise InputError('No world triangles')
    culls=scene.culls.astype(np.int32)
    if np.any(culls!=2):raise InputError('Picture solver currently requires one-sided back-culled source surfaces')
    rho=np.zeros((n,3));emission=np.zeros((n,3));metallic=np.zeros(n);receives=np.zeros(n,np.bool_)
    layers=np.zeros(n,np.int64);gamebits=np.zeros(n,np.int64);castculls=np.full(n,-1,np.int32)
    for index,layer,game,cull in model.caster:castculls[index]=cull
    for index,r in enumerate(scene.records):
        g=model.geometry[scene.objects[r['owner']]['key']];m=model.materials[r['materialKey']]
        if g['shadowCasting']=='ShadowsOnly':raise InputError('ShadowsOnly reflected transport is not in this picture model')
        rho[index]=m['rho'];emission[index]=m['emission'];metallic[index]=m['metallic']
        receives[index]=g['receiveShadows'] and m['receivesShadows'];layers[index]=g['renderingLayerMask'];gamebits[index]=1<<g['layer']
    lights=[]
    for l in model.lights:
        lights.append([{'Directional':0,'Point':1,'Spot':2}[l['kind']],*l['color'],*l['position'],*l['toLight'],l['range'],
                       math.cos(math.radians(l['inner'])/2),math.cos(math.radians(l['outer'])/2),l['strength'],l['cullingMask'],l['receiverLayers'],l['shadowLayers']])
        if l['kind']!='Directional':
            # Reject point-source singularities on an actual source face.
            for triangle in scene.vertices:
                a,b=triangle[1]-triangle[0],triangle[2]-triangle[0];normal=np.cross(a,b);normal/=np.linalg.norm(normal)
                delta=l['position']-triangle[0]
                if abs(delta@normal)<1e-6:
                    uv=np.linalg.lstsq(np.stack((a,b),axis=1),delta,rcond=None)[0]
                    if uv[0]>=0 and uv[1]>=0 and uv.sum()<=1:raise InputError('Punctual source on a source surface')
    emitter_ids=np.where(np.any(emission>0,axis=1))[0].astype(np.int32)
    areas=np.linalg.norm(np.cross(scene.vertices[:,1]-scene.vertices[:,0],scene.vertices[:,2]-scene.vertices[:,0]),axis=1)*.5
    emitter_cdf=np.cumsum(areas[emitter_ids])
    return (scene.vertices,scene.normals,culls,castculls,layers,gamebits,receives,rho,emission,metallic,
            build_bvh(scene.vertices),np.asarray(lights,np.float64).reshape(-1,17),model.use_layers,emitter_ids,emitter_cdf)


def primary_queries(primary):
    return (primary['position'].reshape(-1,3),primary['shadingNormal'].reshape(-1,3),
            primary['triangle'].reshape(-1), (primary['classification']==RECEIVER).reshape(-1))


def main(argv=None):
    parser=argparse.ArgumentParser(description=__doc__,parents=[bootstrap])
    parser.add_argument('--source',required=True);parser.add_argument('--state',required=True);parser.add_argument('--input-root')
    parser.add_argument('--source-sha256');parser.add_argument('--state-sha256');parser.add_argument('--output',required=True)
    parser.add_argument('--width',type=int,default=320);parser.add_argument('--height',type=int,default=180)
    parser.add_argument('--spp',type=int,default=256);parser.add_argument('--batch-spp',type=int,default=64)
    parser.add_argument('--max-depth',type=int,default=8);parser.add_argument('--seed',type=int,default=20261030)
    parser.add_argument('--threads',type=int,default=min(8,os.cpu_count() or 1));parser.add_argument('--preview-exposure',type=float,default=1.)
    args=parser.parse_args(argv)
    if args.spp<2 or args.batch_spp<2 or args.spp%args.batch_spp or not 1<=args.max_depth<=32 or not 0<args.seed<2**63:parser.error('Positive fixed sample/batch/depth contract')
    if not math.isfinite(args.preview_exposure) or args.preview_exposure<=0:parser.error('Positive finite preview exposure')
    output=pathlib.Path(args.output).resolve();root=pathlib.Path(args.input_root or pathlib.Path(args.source).parent).resolve()
    if output.is_relative_to(root) or root.is_relative_to(output):parser.error('Input/output must be disjoint')
    output.mkdir(parents=True,exist_ok=False);start=time.perf_counter()
    try:
        inputs=load(args.source,args.state,root,args.source_sha256,args.state_sha256);directory=pathlib.Path(__file__).parent
        semantic_sources=verify_semantics(inputs,parse((directory/'lighting-semantics.json').read_bytes()))
        model=Lighting(inputs['state']['dynamicState'],inputs['unsupported']);packed=pack(model)
        camera=Camera(inputs['state']['camera'])
        primary=render_primary(model.scene,camera,args.width,args.height,inputs['unsupported'])
        positions,normals,primary_ids,valid=primary_queries(primary)
        n=len(valid);mean=np.zeros((n,3));m2=np.zeros((n,3));metal=np.zeros(n);truncated=np.zeros(n)
        with (output/'primary.npz').open('xb') as file:np.savez_compressed(file,**primary)
        write_json(output/'geometry-index.json',dict(objects=model.scene.objects,triangles=model.scene.records))
        write_json(output/'input-accesses.json',inputs['accesses'])
        numba.set_num_threads(args.threads)
        count=0;batch_records=[]
        for batch in range(args.spp//args.batch_spp):
            before=time.perf_counter();seed=args.seed+batch*1000003
            result=render(positions,normals,primary_ids,valid,args.batch_spp,args.max_depth,seed,*packed)
            bmean,bse,bmetal,btruncated=result;bcount=args.batch_spp;total=count+bcount
            delta=bmean-mean;m2+=bse*bse*(bcount*(bcount-1))+delta*delta*(count*bcount/total);mean+=delta*(bcount/total)
            metal+=bmetal*bcount;truncated+=btruncated*bcount;count=total
            record=dict(batch=batch,spp=count,seed=seed,cpuSeconds=time.perf_counter()-before);batch_records.append(record);print(json.dumps(record),flush=True)
        stderr=np.sqrt(np.maximum(0,m2)/(count*(count-1)));metal/=count;truncated/=count
        if not np.isfinite(mean).all() or not np.isfinite(stderr).all():raise InputError('Nonfinite CPU estimator')
        rgba=np.c_[mean,valid.astype(float)].astype('<f4');(output/'filteredD.rgba32f').write_bytes(rgba.tobytes())
        (output/'validity.u8').write_bytes(valid.astype('u1').tobytes())
        with (output/'statistics.npz').open('xb') as file:np.savez_compressed(file,standardErrorRgb=stderr,metalHitFraction=metal,maxDepthReachedFraction=truncated)
        preview=[]
        try:
            from PIL import Image
            rgb=np.maximum(0,mean*args.preview_exposure);rgb=rgb/(1+rgb);rgb=np.where(rgb<=.0031308,12.92*rgb,1.055*rgb**(1/2.4)-.055)
            pixels=np.round(np.clip(rgb,0,1)*255).astype('u1').reshape(args.height,args.width,3)
            Image.fromarray(pixels).save(output/'preview-raw.png');preview.append('preview-raw.png')
            Image.fromarray(pixels[::-1]).save(output/'preview-flipped-display.png');preview.append('preview-flipped-display.png')
        except ImportError:pass
        implementation=[]
        for name in ('loader.py','geometry.py','primary.py','materials.py','lighting.py','audit_lighting.py','lighting-semantics.json','mc_kernel.py','render_reference.py'):
            path=directory/name;implementation.append(dict(file=str(path.resolve()),sha256=digest(path.read_bytes())))
        report=dict(schema='validation-source-monte-carlo-picture-v1',status='independent-approximate-picture-generated',qualityVerdict=None,
            strictAbsoluteErrorCertificate=False,sourceSha256=inputs['source_sha256'],stateSha256=inputs['state_sha256'],logicalFrame=inputs['state']['logicalFrame'],
            physicalStateFingerprint=digest(json.dumps(dict(camera=inputs['state']['camera'],dynamicState=inputs['state']['dynamicState']),sort_keys=True,separators=(',',':'),ensure_ascii=False).encode()),
            camera=inputs['state']['camera'],signal='filteredD',quantity='indirect-irradiance-over-pi',units='scene-linear-radiance',width=args.width,height=args.height,
            rowOrder=camera.descriptor['rowOrder'],sampledFullPixel='floor((2*gridPixel+1)*fullSize/(2*gridSize)); exact GPU projection; no raw flip',
            method='CPU cosine path tracing, explicit analytic lights at bounce hits, explicit uniform-area emission sampling at each vertex; source-only BVH; receiver reflectance not multiplied',
            spp=args.spp,maxDepth=args.max_depth,seed=args.seed,batches=batch_records,threads=args.threads,
            domainCounts={name:int(np.sum(primary['classification']==i)) for i,name in enumerate(['sky','receiver','boundary','unsupported'])},
            validPixels=int(valid.sum()),meanRgb=mean[valid].mean(axis=0).tolist(),meanStandardErrorRgb=stderr[valid].mean(axis=0).tolist(),
            maxStandardErrorRgb=stderr[valid].max(axis=0).tolist(),meanMetalHitFraction=float(metal[valid].mean()),meanMaxDepthReachedFraction=float(truncated[valid].mean()),
            modelDifferences=['Authored Soft shadows use ideal source-triangle hard visibility, not URP PCF/bias/cascades.',
              'Only metallic-Lit diffuse rho and source emission transport; metal/glossy specular paths are omitted. metalHitFraction is sampled evidence, zero does not prove no specular influence.',
              'Finite path depth truncates remaining diffuse transport; maxDepthReachedFraction describes sampling, not a bias bound.',
              'Black environment only; no baked GI, texture, transparency, participating medium, temporal filter or product cache.',
              'Source float64 pinhole geometry with boundary exclusion; not GPU raster/depth-equivalent. Ray minimum 1e-6*max(1,maxAbsOrigin) metres; finite-precision/model bias is not in Monte Carlo standard error.'],
            uncertainty='Per-pixel sample standard error only; finite-sample rare events and all model differences remain. No fabricated absolute bound or default quality threshold.',
            coverage='Mask zero denotes source sky/boundary/unsupported; candidate masks/RGB never select rays or reference validity. No complete-image acceptance from covered subset.',
            preview=dict(exposure=args.preview_exposure,tonemap='Reinhard then sRGB; diagnostic only',raw='preview-raw.png',optionalDisplay='preview-flipped-display.png; vertical display transform only, raw data and rowOrder unchanged'),
            sourceUnsupported=inputs['unsupported'],modelUnsupported=model.unsupported,semanticSources=semantic_sources,implementation=implementation,
            dependencies=dict(python=sys.version,numpy=np.__version__,numba=numba.__version__),cpuElapsedSeconds=time.perf_counter()-start,artifacts=[])
        for name in ['filteredD.rgba32f','validity.u8','primary.npz','statistics.npz','geometry-index.json','input-accesses.json']+preview:
            path=output/name;report['artifacts'].append(dict(file=name,sha256=digest(path.read_bytes()),bytes=path.stat().st_size))
        write_json(output/'report.json',report);print(json.dumps(dict(status=report['status'],output=str(output),validPixels=report['validPixels'],qualityVerdict=None)),flush=True)
        return 0
    except Exception as error:
        write_json(output/'failure.json',dict(status='reference-generation-failed',error=type(error).__name__+': '+str(error),qualityVerdict=None));raise


if __name__=='__main__':sys.exit(main())
