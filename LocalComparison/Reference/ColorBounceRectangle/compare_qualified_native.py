"""Compare through separate raster qualification, retaining frozen first attempt."""
import argparse
import hashlib
import json
import math
from pathlib import Path

import compare_native as original
import qualify_native_inputs as qualifier
import reference


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--native-outputdir', type=Path, required=True)
    args = parser.parse_args()
    native = args.native_outputdir
    rays_path = native/'rays-native-qualified.json'
    source_path = original.HERE/'source-contract.json'
    source, rays = original.load(source_path), original.load(rays_path)
    # The physical oracle and radiance limits are the original frozen functions.
    # They receive actual native input directions/origins, never measured RGB.
    expected = reference.build_reference(source, rays)
    expected.update(sourceSha256=original.sha(source_path), rayInputSha256=original.sha(rays_path),
                    referenceCodeSha256=original.sha(original.HERE/'reference.py'))
    assert len(expected['groups']) == 27 and all(g['qualified'] for g in expected['groups'])
    expected_path = native/'finite-reference-qualified.json'
    with expected_path.open('x', encoding='utf-8') as stream:
        json.dump(expected, stream, indent=2)
    source_closure = original.validate_sources(native.parent)
    receipt = original.load(native/'tap-receipt.json')
    inputs = (native/'sampler-inputs.bin').read_bytes()
    repeated = qualifier.qualify(inputs, receipt)
    assert repeated['groups'] == rays['groups'] and repeated['qualification'] == rays['qualification'], 'Qualified input data changed'
    assert rays['rowSha256'] == hashlib.sha256(inputs).hexdigest() and rays['metadataSha256'] == original.sha(native/'tap-receipt.json')
    assert rays['qualifierSha256'] == original.sha(Path(qualifier.__file__))
    assert rays['originalDecoderSha256'] == original.FROZEN['decode_sampler.py']
    scene_closure = original.validate_scene(original.load(native/'scene-inputs.json'), original.load(native/'scene-result.json'), receipt, source)
    # First product color access is after independent expected/source checks.
    raw_path = native/'raw.rgba32f'
    raw = raw_path.read_bytes()
    rows = original.compare_pixels(source, expected, raw, receipt['width'], receipt['height'])
    positive = next(group for group in expected['groups'] if group['hitCount'] > 0)
    value = positive['finiteRawExpected']
    negatives = dict(extraPiRejected=not reference.compare_raw(source, positive, [original.half(v/math.pi) for v in value]+[1])['passed'],
                     swappedChannelsRejected=not reference.compare_raw(source, positive, [original.half(v) for v in reversed(value)]+[1])['passed'],
                     unknownRejected=not reference.compare_raw(source, positive, [original.half(v) for v in value]+[0])['passed'])
    assert all(negatives.values())
    passed = all(row['passed'] for row in rows)
    result = dict(status='passed' if passed else 'failed', selectedGroups=len(rows), passedGroups=sum(row['passed'] for row in rows),
                  scope='Conditional finite single-bounce E/pi consistency after separate raster-aware input qualification; not default multi-bounce certification.',
                  initialDecoderPassed=False, originalDecoderUnmodified=True, radianceThresholdsUnmodified=True,
                  sourceClosure=source_closure, sceneClosure=scene_closure, inputQualification=rays['qualification'],
                  groups=rows, negativeControls=negatives, expectedSha256=original.sha(expected_path),
                  rawSha256=hashlib.sha256(raw).hexdigest(), inputSha256=original.sha(rays_path),
                  originalComparatorSha256=original.sha(Path(original.__file__)), wrapperSha256=original.sha(Path(__file__)),
                  qualifierSha256=original.sha(Path(qualifier.__file__)), productionAccepted=False)
    output = native/'finite-comparison-qualified.json'
    with output.open('x', encoding='utf-8') as stream:
        json.dump(result, stream, indent=2)
    print(json.dumps(dict(output=str(output), status=result['status'], passedGroups=result['passedGroups'], selectedGroups=len(rows))))
    raise SystemExit(0 if passed else 1)


if __name__ == '__main__':
    main()
