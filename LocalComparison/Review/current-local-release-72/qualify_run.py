"""Read the one finite explicit-request Player attempt; never launch or rerun it."""
import hashlib
import importlib.util
import json
import math
from pathlib import Path
import struct
import traceback

P = Path(__file__).resolve().parent
NATIVE = P / 'native-explicit'
BUILD = Path('I:/Unity test/Comparison/Builds/LocalRelease72')
load = lambda path: json.loads(path.read_text(encoding='utf-8-sig'))
sha = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()


def qualify():
    spec = importlib.util.spec_from_file_location('release72_source_analysis', P.parent / 'current-local-release-67/analyze67.py')
    analysis = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(analysis)
    analysis.PACKAGE, analysis.BUILD = P, BUILD
    shared = analysis.reuse()
    assert shared.existing.smoke.verify_products()
    cube = analysis.check_cube_build(load)
    assert load(P / 'build-analysis.json')['currentSourceBuildVerified']
    assert load(P / 'analysis67-build.json')['passed']
    manifest = load(P / 'instrumentation/manifest.json')
    assert len(manifest['productSourceSha256']) == 112 and len(manifest['files']) == 8
    source = manifest['unchangedRelease71Host']
    assert sha(Path(source['priorPath'])) == source['sha256']
    staged_host = next(row for row in manifest['files'] if row['path'].endswith('/LocalReleaseBootstrap.cs'))
    assert staged_host['sha256'] == source['sha256']
    assert load(P / 'instrumentation/restoration.json')['currentProductRestored']
    assert all(row['restored'] for row in load(P / 'instrumentation/restoration.json')['files'])
    attempt = load(NATIVE / 'attempt.json')
    assert Path(attempt['executable']).resolve() == (BUILD / 'HybridLumenGITest.exe').resolve()
    for flag in ('-batchmode', '-force-d3d12', '-localReleaseFinalImage120', '-localReleaseExplicitRequest'):
        assert attempt['arguments'].count(flag) == 1
    assert attempt['maximumLogicalFrames'] == 120
    exit_receipt = load(NATIVE / 'native-exit.json')
    assert exit_receipt['exitCode'] == 0 and not exit_receipt['watchdogTerminated']
    assert not shared.existing.smoke.hits(NATIVE / 'player.log'), 'Player error log entries'
    run = NATIVE / 'run'
    r = load(run / 'release-result.json')
    assert r['status'] == 'completed-finite-release-check' and r['errors'] == 0
    assert r['actualCameraFrames'] == r['requestedFrames'] == 120
    assert r['explicitRequest'] and r['renderRequestSupported'] and r['cameraDisabledDuringRequests']
    assert r['renderPath'] == 'RenderPipeline.StandardRequest; disabled camera; one request per Update'
    assert all(r[field] == 120 for field in ('requests', 'cameraBegins', 'cameraEnds', 'contextBegins', 'contextEnds'))
    assert not r['debugBuild'] and r['verify120'] and not r['verifySteady300']
    assert r['testCaptureDisabled'] and r['auditProbeDisabled'] and r['featureEnabled']
    assert r['api'] == 'Direct3D12' and r['width'] == 640 and r['height'] == 360
    assert r['lastEngine'] - r['firstRenderEngine'] == 119
    assert r['firstRenderEngine'] - r['startEngine'] <= 120 and r['firstRenderWaitSeconds'] <= 900
    assert r['finalImageMode'] and r['finalImageCaptured'] and r['actualViewMode'] == 'Final' and r['composition'] == 'Additive'
    expected_environment = dict(environmentCubePresent=True, environmentCubeSupported=True, environmentCubeLinear=True,
        environmentCubeName='CurrentRelease67Environment', environmentCubeFormat='RGBAFloat',
        environmentCubeGraphicsFormat=cube['graphicsFormat'], environmentCubeFilterMode='Bilinear', environmentCubeWrapMode='Clamp',
        environmentCubeWidth=2, environmentCubeHeight=2, environmentCubeMipCount=1)
    assert all(r[key] == value for key, value in expected_environment.items()) and r['environmentCubeInstanceId'] != 0
    assert 'Using the constant environment instead' not in (NATIVE / 'player.log').read_text(encoding='utf-8-sig', errors='replace')
    rows = shared.existing.lines(run / 'diagnostics.jsonl')
    assert [row['actualCameraFrames'] for row in rows] == [1, 60, 120]
    assert rows[0]['engine'] == r['firstRenderEngine'] and rows[2]['engine'] == r['lastEngine']
    assert rows[2]['giFrame'] > rows[1]['giFrame'] > 0
    for row in rows[1:]:
        assert row['featureEnabled'] and row['hardwareBackend'] and row['hardwareMeshes'] > 0
        assert row['readyCards'] > 0 and row['publishedInstances'] > 0 and row['hardwareMaterialUnknownRecords'] == 0
        assert row['hardwareMaterialStatus'] == 'Uploads and both consumers bound; GPU completion unproven'
    frame = load(run / 'frame-0119.json')
    assert frame['captured'] and frame['logicalFrame'] == 119 and frame['engineFrame'] == r['lastEngine']
    assert frame['stage'] == 'color-static-final-only'
    raw = (run / frame['raw']).read_bytes()
    assert len(raw) == 640 * 360 * 16
    assert all(math.isfinite(value[0]) for value in struct.iter_unpack('<f', raw))
    png = (run / frame['png']).read_bytes()
    assert png[:8] == b'\x89PNG\r\n\x1a\n' and struct.unpack('>II', png[16:24]) == (640, 360)
    exr = (run / frame['exr']).read_bytes()
    assert len(exr) > 8 and struct.unpack('<I', exr[:4])[0] == 20000630
    assert sorted(path.name for path in run.iterdir()) == sorted(['diagnostics.jsonl', 'release-result.json', 'feature.json',
        'frame-0119.json', 'frame-0119.rgba32f', 'frame-0119.exr', 'frame-0119.png'])
    return dict(explicitRequestFiniteIntegrationVerified=True, productFiles=112, requestCameraContextCount=120,
                sourceCommit=manifest['baseline'], runtime=r, diagnostics=rows, finalFrame=frame,
                fileSha256={path.relative_to(NATIVE).as_posix(): sha(path) for path in NATIVE.rglob('*') if path.is_file()},
                finalHdrDataVerified=True, ordinaryInteractiveRevalidated=False, automaticHiddenRenderingRevalidated=False,
                fullProductionAccepted=False,
                scope='One current-source Release72 DX12 Player, disabled target camera and explicit StandardRequest, 120 consecutive engine frames, Final HDR readback. No OS-keyboard, ordinary automatic rendering, scene-motion or physical-image acceptance.')


if __name__ == '__main__':
    output = NATIVE / 'analysis.json'
    assert not output.exists(), 'Preserve first explicit-request qualification'
    result = dict(explicitRequestFiniteIntegrationVerified=False, fullProductionAccepted=False)
    try:
        result = qualify()
    except Exception:
        result['error'] = traceback.format_exc()
    with output.open('x', encoding='utf-8') as stream:
        json.dump(result, stream, indent=2)
    print(json.dumps({key: value for key, value in result.items() if key not in ('runtime', 'diagnostics', 'finalFrame', 'fileSha256')}))
    raise SystemExit(0 if result['explicitRequestFiniteIntegrationVerified'] else 1)
