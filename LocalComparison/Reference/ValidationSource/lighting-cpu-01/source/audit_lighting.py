"""Audit nominal direct source lighting at triangle centroids; never read image output."""
from __future__ import annotations
import argparse
import json
import pathlib
import sys
import numpy as np
from loader import load, digest, parse, InputError
from geometry import unit
from lighting import Lighting
from primary import write_json


def verify_semantics(inputs, document):
    verified=[]
    for original, expected in document['stockSources'].items():
        matches=[a for a in inputs['source']['assets'] if original in a.get('originalPaths',[])]
        if len(matches)!=1 or matches[0]['sha256']!=expected:
            raise InputError('Missing or unqualified stock semantic source: '+original)
        # The strict source loader already verified the archived bytes, not just this index.
        verified.append(dict(original=original,file=matches[0]['path'],sha256=expected))
    return verified


def json_value(value):
    if isinstance(value,np.ndarray):return value.tolist()
    if isinstance(value,dict):return {k:json_value(v) for k,v in value.items()}
    if isinstance(value,list):return [json_value(v) for v in value]
    return value


def main(argv=None):
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source',required=True);parser.add_argument('--state',required=True)
    parser.add_argument('--input-root');parser.add_argument('--source-sha256');parser.add_argument('--state-sha256')
    parser.add_argument('--output',required=True,help='Fresh directory disjoint from the input package')
    args=parser.parse_args(argv)
    root=pathlib.Path(args.input_root or pathlib.Path(args.source).parent).resolve()
    output=pathlib.Path(args.output).resolve()
    if output.is_relative_to(root) or root.is_relative_to(output):parser.error('Input/output must be disjoint')
    output.mkdir(parents=True,exist_ok=False)
    try:
        inputs=load(args.source,args.state,root,args.source_sha256,args.state_sha256)
        directory=pathlib.Path(__file__).parent
        semantics=parse((directory/'lighting-semantics.json').read_bytes())
        verified=verify_semantics(inputs,semantics)
        model=Lighting(inputs['state']['dynamicState'],inputs['unsupported'])
        triangles=model.scene.vertices
        if len(triangles)==0:raise InputError('No source triangles to audit')
        points=triangles.mean(axis=1)
        normals,_=unit(np.cross(triangles[:,1]-triangles[:,0],triangles[:,2]-triangles[:,0]))
        ids=np.arange(len(triangles),dtype=np.int32)
        result=model.evaluate(points,normals,ids)
        arrays={k:v for k,v in result.items() if isinstance(v,np.ndarray)}
        for key,value in arrays.items():
            if not np.isfinite(value).all():raise InputError('Nonfinite nominal output: '+key)
        with (output/'direct-source.npz').open('xb') as file:
            np.savez_compressed(file,position=points,geometricNormal=normals,triangle=ids,**arrays)
        write_json(output/'source-model.json',json_value(dict(materials=list(model.materials.values()),lights=model.lights,
                   objects=model.scene.objects,triangles=model.scene.records,excluded=model.scene.excluded)))
        write_json(output/'input-accesses.json',inputs['accesses'])
        implementation=[]
        for name in ('loader.py','geometry.py','primary.py','materials.py','lighting.py','audit_lighting.py','lighting-semantics.json'):
            path=directory/name;implementation.append(dict(file=str(path.resolve()),sha256=digest(path.read_bytes())))
        known=result['known'];count=int(known.sum())
        report=dict(schema='validation-source-direct-lighting-v1',status='generated-nominal-source-field',
            qualityVerdict=None,fullIndirectDReference=False,nativeCameraReference=False,certifiedNumericBounds=False,
            sourceSha256=inputs['source_sha256'],stateSha256=inputs['state_sha256'],logicalFrame=inputs['state']['logicalFrame'],
            query='Every source triangle centroid, its geometric normal, and exact source triangle ID. No pixel/output-selected cohort.',
            counts=dict(triangles=len(ids),known=count,unknown=len(ids)-count,materials=len(model.materials),lights=len(model.lights)),
            sourceUnsupported=inputs['unsupported'],modelUnsupported=model.unsupported,
            directDMinKnown=result['directD'][known].min(axis=0).tolist() if count else None,
            directDMaxKnown=result['directD'][known].max(axis=0).tolist() if count else None,
            lightDiagnostics=result['lightDiagnostics'],semanticSources=verified,implementation=implementation,
            transport='URP-relative nominal direct diffuse d; B0=Le+rho*d. Soft authored shadows are ideal geometry hard visibility, not PCF. No environment integral, secondary bounce or full camera composition.',
            unknownEncoding='known=false makes directD/outgoingSource zero placeholders; they are not valid expected black. rho and emission remain source properties.',
            numericScope='float64 nominal evaluation and fixed epsilon contact guards; not an absolute GPU/native error envelope or quality threshold.',
            inputReadCount=len(inputs['accesses']),artifacts=[])
        for name in ('direct-source.npz','source-model.json','input-accesses.json'):
            path=output/name;report['artifacts'].append(dict(file=name,sha256=digest(path.read_bytes()),bytes=path.stat().st_size))
        write_json(output/'report.json',report)
        print(json.dumps(dict(status=report['status'],counts=report['counts'],unsupported=model.unsupported,output=str(output),qualityVerdict=None)))
        return 0
    except Exception as error:
        write_json(output/'failure.json',dict(status='invalid-input-or-tool-failure',error=type(error).__name__+': '+str(error),qualityVerdict=None))
        raise


if __name__=='__main__':sys.exit(main())
