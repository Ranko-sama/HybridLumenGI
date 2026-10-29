"""Close native sources, build an independent finite oracle, then read raw RGB."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import struct

import decode_sampler
import generate_sampler
import reference

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
FROZEN = {
    'source-contract.json': '02466a5289040eff541dabdb85737c6fd6b8d19621012c4f90e3f8986a6efea5',
    'reference.py': '5a31910eb5d8a11289c778b3ffa181acaba4245d229a41855798edc010de7eeb',
    'decode_sampler.py': 'b451adc1b0f105a1a24a1a091e72adcba1fcaf0833da7b39a7b04cfd06fb01fe',
    'generate_sampler.py': '4a8d4b407c44841444ddacb151073ae291c683c59f649a94bbe6285458ef5ef8',
    'generated/manifest.json': '7ea738fcb2ee42b974eef8d902306d581c1fdb086edc12aca679dc9b5c2c87e7',
}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def half(value):
    return struct.unpack('<e', struct.pack('<e', value))[0]


def vector(value, fields='xyz'):
    return [value[field] for field in fields]


def equal(actual, expected, label, tolerance=1e-6):
    if isinstance(expected, (tuple, list)):
        assert len(actual) == len(expected), label
        for a, e in zip(actual, expected):
            equal(a, e, label, tolerance)
    elif isinstance(expected, bool) or isinstance(expected, str):
        assert actual == expected, label
    else:
        assert math.isfinite(actual) and abs(actual-expected) <= tolerance, label


def validate_scene(inputs, result, tap, source):
    reference.validate_source(source)
    geometry = {
        'wall': ([[0,0,-2], [0,2,-2], [0,2,2], [0,0,2]], [1,0,0], [.5,.25,.125,1]),
        'floor': ([[0,0,-3], [0,0,3], [5,0,3], [5,0,-3]], [0,1,0], [1,1,1,1]),
    }
    for name, (vertices, normal, base_color) in geometry.items():
        surface = inputs[name]
        equal(surface['shader'], 'Universal Render Pipeline/Lit', name+' shader')
        equal([vector(v) for v in surface['vertices']], vertices, name+' vertices')
        equal([vector(v) for v in surface['normals']], [normal]*4, name+' normals')
        equal(surface['triangles'], [0,1,2,0,2,3], name+' triangles')
        for row in range(4):
            for column in range(4):
                equal(surface['localToWorld'][f'e{row}{column}'], int(row == column), name+' transform')
        equal(vector(surface['shaderLinearBaseColor'], 'xyzw'), base_color, name+' shader-linear MPB')
        equal(vector(surface['materialBaseColor'], 'rgba'), [1,1,1,1], name+' base material')
        equal(vector(surface['proxyTint'], 'rgb'), [1,1,1], name+' proxy tint')
        for field in ('materialEmission', 'proxyEmission'):
            equal(vector(surface[field], 'rgb'), [0,0,0], name+' '+field)
        equal(surface['metallic'], 0, name+' metallic')
        equal(surface['occlusionStrength'], 1, name+' occlusion')
        for field in ('normalMap', 'baseMap', 'emissionMap', 'occlusionMap', 'emissionKeyword', 'receiveShadows'):
            equal(surface[field], False, name+' '+field)
    light = inputs['light']
    for field, expected in {'type':'Directional', 'shadows':'None', 'intensity':1, 'enabled':True, 'useColorTemperature':False}.items():
        equal(light[field], expected, 'light '+field)
    equal(vector(light['color'], 'rgb'), source['light']['linearRgb'], 'light color')
    equal(vector(light['toLight']), source['light']['toLight'], 'light direction')
    settings = inputs['settings']
    for field, expected in dict(resolutionScale=1, raysPerPixel=8, traceDistance=20, rayBias=.03, screenSteps=0,
                                bounceFeedback=0, guidedSamplingWeight=0, emissiveSamplingWeight=0,
                                maxAreaEmitterTriangles=0, maxEmissiveProposals=0, radianceClamp=0,
                                temporalAccumulation=False, maxHistory=1, filterIterations=0,
                                maxLights=1, spatialLightSelection=False, preferHardwareTracing=True, exactSoftwareTracing=True,
                                globalSdfEnabled=False, adaptiveGpuBudget=False).items():
        equal(settings[field], expected, 'settings '+field)
    equal(vector(settings['environmentRadiance'], 'rgb'), [0,0,0], 'environment')
    cube = settings.get('environmentCubemap')
    assert cube is None or cube == {'instanceID': 0}, 'Environment cubemap is not null'
    equal(tap['rays'], settings['raysPerPixel'], 'tap ray count')
    equal(tap['rayBias'], settings['rayBias'], 'tap ray bias')
    equal(tap['normalsOct'], settings['normalsOctEncoded'], 'tap normal encoding')
    assert result['status'] == 'collected' and not result.get('error') and result['readbacksDrained'], 'Native capture did not complete'
    assert result['api'] == 'Direct3D12' and result['renderRequestSupported'] and result['targetCreated']
    assert not result['cameraEnabled'] and result['cameraActive'] and result['cameraBase']
    assert result['targetWorkFrame'] == tap['workFrame']
    counts = [result[key] for key in ('requests','cameraBegins','cameraEnds','contextBegins','contextEnds')]
    assert len(set(counts)) == 1 and counts[0] >= 2, 'Render request/camera/context closure differs'
    diagnostic = result['selectedDiagnostics']
    assert diagnostic['frame'] == tap['workFrame']+1, 'Post-render diagnostics do not match gather Work.frame'
    assert diagnostic['hardwareBackend'] and diagnostic['hardwareMeshes'] == 2 and diagnostic['hardwareFallbacks'] == 0
    assert diagnostic['hardwareMaterialUnknownRecords'] == 0 and diagnostic['hardwareMaterialStatus'] == 'Uploads and both consumers bound; GPU completion unproven'
    for field, expected in dict(publishedInstances=2, warmingInstances=0, pendingCapacity=0, chartedOwners=2,
                                approximateOwners=0, pendingCards=0, lightSelected=1, lightCapacityOmitted=-1).items():
        assert diagnostic[field] == expected, 'Unqualified native diagnostics: '+field
    assert diagnostic['readyCards'] >= 2
    return dict(geometryMaterialLightSettings=True, actualGatherInputs=True, hardwareReady=True,
                note='GPU readback completion closes the selected command boundary; CPU status text alone does not prove completion.',
                lightSelection='One authored enabled directional light and lightSelected=1; spatial selector is disabled and its capacity-omitted diagnostic is the -1 sentinel.',
                authoredOnlyFields='WorkflowMode=1, smoothness=0, disabled keywords and zero ambient/reflection are fixed in the hash-matched temporary harness source, not separate receipt fields.',
                cameraAspect='Pre-target scene aspect is informational. Actual gather VP/invVP and dimensions define sample geometry.')


def validate_sources(package):
    for name, expected in FROZEN.items():
        assert sha(HERE/name) == expected, 'Prospective reference source changed: '+name
    stage = package/'instrumentation'
    manifest = load(stage/'manifest.json')
    current_paths = {path.relative_to(ROOT).as_posix() for top in ('Runtime','Editor')
                     for path in (ROOT/top).rglob('*') if path.is_file() and path.suffix != '.meta'}
    assert current_paths == set(manifest['productSourceSha256']), 'Product manifest file inventory differs'
    for name, expected in manifest['productSourceSha256'].items():
        assert sha(ROOT/name) == expected, 'Product source differs from executed manifest: '+name
    sampler = load(HERE/'generated/manifest.json')
    for name, expected in sampler['sourceSha256'].items():
        normalized = name.replace('\\', '/')
        assert sha(ROOT/normalized) == expected == manifest['productSourceSha256'][normalized], 'Sampler extraction/product source mismatch: '+name
    for name, expected in sampler['generatedSha256'].items():
        assert sha(HERE/'generated'/name) == expected, 'Generated sampler changed: '+name
    shaders = ROOT/'Runtime/Resources/HybridLumenGI'
    functions = generate_sampler.extract((shaders/'HybridLumenGITransport.hlsl').read_text(encoding='utf-8-sig'),
                                         ['HLGIHash','Random','CosineHemisphere','HLGISampleDirection'])
    functions += generate_sampler.extract((shaders/'HybridLumenGIKernels.hlsl').read_text(encoding='utf-8-sig'),
                                          ['ValidDepth','WorldPosition','NormalAt','HLGIScreenDepthDelta','HLGIScreenDepthDerivative','HLGITryScreenGeometricNormal'])
    assert functions == (HERE/'generated/ReferenceInputFunctions.hlsl').read_text(encoding='utf-8-sig'), 'Extracted input functions differ'
    harness = {'FiniteWallReferenceTap.cs','FiniteWallReferenceScene.cs','FiniteWallReferenceEditor.cs'}
    expected_files = harness | {'HybridLumenGIRendererFeature.cs','FiniteWallReferenceInputs.compute',
                                'ReferenceInputFunctions.hlsl','ReferenceScreenSampling.hlsl','ReferenceHit.hlsl'}
    assert len(manifest['files']) == len(expected_files) and {Path(row['path']).name for row in manifest['files']} == expected_files
    for row in manifest['files']:
        prepared = stage/row['prepared']
        assert sha(prepared) == row['sha256'], 'Prepared observer source changed'
        name = Path(row['path']).name
        if name in harness:
            assert sha(ROOT/'LocalComparison/Harness'/name) == row['sha256'], 'Harness source differs from staged source'
        elif name in sampler['generatedSha256']:
            assert sampler['generatedSha256'][name] == row['sha256'], 'Installed sampler differs'
        elif name == 'HybridLumenGIRendererFeature.cs':
            original = (ROOT/'Runtime'/name).read_bytes()
            instrumented = prepared.read_bytes()
            hook = b'                global::FiniteWallReferenceTap.Record(cmd,((RTHandle)d.raw).rt,((RTHandle)d.geometryWrite).rt,((RTHandle)d.depth).rt,((RTHandle)d.materialWrite).rt,((RTHandle)d.normals).rt,state.camera,d.frame,d.invVP,d.vp,d.view,new Vector2Int((int)d.viewport.width,(int)d.viewport.height),Mathf.Max(0.001f,s.rayBias),Mathf.Clamp(s.raysPerPixel,1,8),s.normalsOctEncoded);'
            newline = b'\r\n' if b'\r\n' in original else b'\n'
            assert instrumented.count(hook) == 1 and instrumented.replace(newline+hook, b'') == original, 'Observer altered product behavior beyond gather tap'
        else:
            raise AssertionError('Unexpected observer file: '+row['path'])
    return dict(productFileCount=len(manifest['productSourceSha256']), observerFileCount=len(manifest['files']),
                instrumentationManifestSha256=sha(stage/'manifest.json'), samplerManifestSha256=sha(HERE/'generated/manifest.json'),
                referenceSources=FROZEN, currentSourceAndExtractionMatched=True)


def compare_pixels(source, expected, data, width, height):
    assert len(data) == width*height*16, 'Raw RGBA32F readback shape differs'
    rows = []
    for group in expected['groups']:
        x, y = group['pixel']
        assert 0 <= x < width and 0 <= y < height and group['qualified']
        rgba = struct.unpack_from('<4f', data, (y*width+x)*16)
        comparison = reference.compare_raw(source, group, rgba)
        rows.append(dict(id=group['id'], pixel=group['pixel'], hitCount=group['hitCount'],
                         finiteRawExpected=group['finiteRawExpected'], **comparison))
    assert any(row['hitCount'] > 0 for row in rows), 'No positive finite transport sample; cannot qualify color energy'
    return rows


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--native-outputdir', type=Path, required=True)
    parser.add_argument('--package', type=Path)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    native, package = args.native_outputdir, args.package or args.native_outputdir.parent
    source_path, rays_path = HERE/'source-contract.json', native/'rays-native.json'
    source, rays = load(source_path), load(rays_path)
    # This independent construction happens before any product RGB is opened.
    expected = reference.build_reference(source, rays)
    expected.update(sourceSha256=sha(source_path), rayInputSha256=sha(rays_path), referenceCodeSha256=sha(HERE/'reference.py'))
    assert len(expected['groups']) == 27 and all(group['qualified'] for group in expected['groups']), 'Finite ray oracle is ambiguous or incomplete'
    expected_path = native/'finite-reference.json'
    if expected_path.exists():
        assert load(expected_path) == expected, 'Prior finite reference differs from freshly computed independent oracle'
    else:
        with expected_path.open('x', encoding='utf-8') as stream:
            json.dump(expected, stream, indent=2)
    source_closure = validate_sources(package)
    tap = load(native/'tap-receipt.json')
    decoded = decode_sampler.decode((native/'sampler-inputs.bin').read_bytes(), decode_sampler.native_metadata(tap))
    assert decoded['groups'] == rays['groups'] and rays['rowSha256'] == sha(native/'sampler-inputs.bin') and rays['metadataSha256'] == sha(native/'tap-receipt.json')
    scene_closure = validate_scene(load(native/'scene-inputs.json'), load(native/'scene-result.json'), tap, source)
    # Read measured transport only after expected radiance and source closure exist.
    data = (native/'raw.rgba32f').read_bytes()
    comparisons = compare_pixels(source, expected, data, tap['width'], tap['height'])
    positive = next(group for group in expected['groups'] if group['hitCount'] > 0)
    value = positive['finiteRawExpected']
    negative_controls = {
        'extraPiRejected': not reference.compare_raw(source, positive, [half(v/math.pi) for v in value]+[1])['passed'],
        'swappedChannelsRejected': not reference.compare_raw(source, positive, [half(v) for v in reversed(value)]+[1])['passed'],
        'unknownRejected': not reference.compare_raw(source, positive, [half(v) for v in value]+[0])['passed'],
    }
    assert all(negative_controls.values()), 'Comparator negative control failed'
    passed = all(row['passed'] for row in comparisons)
    result = dict(status='passed' if passed else 'failed', scope='Finite single-bounce raw E/pi, conditional on current native input directions; not default multi-bounce certification',
                  sourceClosure=source_closure, sceneClosure=scene_closure, negativeControls=negative_controls,
                  selectedGroups=len(comparisons), passedGroups=sum(row['passed'] for row in comparisons), groups=comparisons,
                  expectedSha256=sha(expected_path), rawSha256=hashlib.sha256(data).hexdigest(), comparatorSha256=sha(Path(__file__)),
                  sceneInputsSha256=sha(native/'scene-inputs.json'), sceneResultSha256=sha(native/'scene-result.json'), productionAccepted=False)
    output = args.output or native/'finite-comparison.json'
    with output.open('x', encoding='utf-8') as stream:
        json.dump(result, stream, indent=2)
    print(json.dumps(dict(output=str(output), status=result['status'], groups=len(comparisons), passedGroups=result['passedGroups'])))
    raise SystemExit(0 if passed else 1)


if __name__ == '__main__':
    main()
