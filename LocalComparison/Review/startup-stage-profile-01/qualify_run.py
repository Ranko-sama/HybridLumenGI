"""Qualify the sole CPU trace and report intervals without treating them as GPU time."""
import importlib.util
import json
import math
import traceback
from pathlib import Path

P = Path(__file__).resolve().parent
NATIVE = P / 'native-explicit'


def module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    value = importlib.util.module_from_spec(spec); spec.loader.exec_module(value)
    return value


def qualify():
    build = module('startup_build_check', P / 'analyze.py')
    build.products()
    load = build.load
    attempt = load(NATIVE / 'attempt.json')
    assert attempt['maximumLogicalFrames'] == 12
    end = load(NATIVE / 'native-exit.json')
    assert end['exitCode'] == 0 and not end['watchdogTerminated']
    scanner = module('startup_player_log_check', build.ROOT / 'LocalComparison/Harness/native_log_check.py')
    assert not scanner.scan(NATIVE / 'player.log')
    r = load(NATIVE / 'run/release-result.json')
    assert r['mode'] == 'startup-stage-profile-01'
    assert r['status'] == 'completed-finite-release-check' and r['errors'] == 0
    assert r['actualCameraFrames'] == r['requestedFrames'] == 12
    assert all(r[k] == 12 for k in ('requests', 'cameraBegins', 'cameraEnds', 'contextBegins', 'contextEnds'))
    assert r['lastEngine'] - r['firstRenderEngine'] == 11
    assert r['explicitRequest'] and r['renderRequestSupported'] and r['cameraDisabledDuringRequests']
    assert not r['debugBuild'] and not r['finalImageCaptured']
    assert r['api'] == 'Direct3D12' and (r['width'], r['height']) == (640, 360)
    assert r['actualViewMode'] == 'Final' and r['composition'] == 'Additive'
    assert r['environmentCubePresent'] and r['environmentCubeSupported'] and r['environmentCubeLinear']
    assert r['environmentCubeName'] == 'CurrentRelease67Environment'
    assert r['environmentCubeFormat'] == 'RGBAFloat'
    assert (r['environmentCubeWidth'], r['environmentCubeHeight'], r['environmentCubeMipCount']) == (2, 2, 1)
    diagnostics = [json.loads(line) for line in (NATIVE / 'run/diagnostics.jsonl').read_text().splitlines()]
    assert [row['actualCameraFrames'] for row in diagnostics] == [1, 12]
    row = diagnostics[-1]
    assert row['hardwareBackend'] and row['hardwareMeshes'] > 0 and row['readyCards'] > 0
    assert row['publishedInstances'] > 0 and row['hardwareMaterialUnknownRecords'] == 0 and row['giFrame'] > 0
    trace = load(NATIVE / 'run/startup-stage-cpu.json')
    assert trace['schema'] == 'startup-stage-cpu-v1' and trace['status'] == 'collected' and not trace['error']
    assert trace['cpuOnly'] and trace['firstRequestReturned'] and trace['runtimeInitializeObserved']
    assert trace['firstRequestEngineFrame'] == r['firstRenderEngine']
    assert all(trace[k] == 1 for k in ('contextBegins', 'contextEnds', 'cameraBegins', 'cameraEnds'))
    frequency, origin = trace['stopwatchFrequency'], trace['originTimestamp']
    assert frequency > 0
    entries = trace['events']; stack = []; starts = {}; spans = []; markers = []
    previous = origin
    for i, event in enumerate(entries):
        assert event['sequence'] == i and event['timestamp'] >= previous
        previous = event['timestamp']
        expected_ms = (event['timestamp'] - origin) * 1000 / frequency
        assert math.isfinite(event['millisecondsFromOrigin'])
        assert abs(event['millisecondsFromOrigin'] - expected_ms) <= 1e-7
        if event['kind'] == 'begin':
            assert event['scopeId'] not in starts
            starts[event['scopeId']] = event; stack.append(event['scopeId'])
        elif event['kind'] == 'end':
            assert stack and stack.pop() == event['scopeId']
            start = starts[event['scopeId']]
            assert start['stage'] == event['stage'] and start['threadId'] == event['threadId']
            spans.append(dict(stage=event['stage'], milliseconds=(event['timestamp'] - start['timestamp']) * 1000 / frequency,
                beginSequence=start['sequence'], endSequence=i, engineFrame=start['engineFrame'],
                beginTimestamp=start['timestamp'], endTimestamp=event['timestamp']))
        else:
            assert event['kind'] == 'marker'; markers.append(event['stage'])
    assert not stack and len(spans) == len(starts)
    assert len({e['threadId'] for e in entries}) == 1
    for marker in ('RuntimeInitialize.SubsystemRegistration', 'Probe.Configured', 'Callback.beginContextRendering',
                   'Callback.endContextRendering', 'Callback.beginCameraRendering', 'Callback.endCameraRendering', 'Probe.BufferedCaptureEnd'):
        assert markers.count(marker) == 1, marker
    submit = [span for span in spans if span['stage'] == 'Host.SubmitRenderRequest']
    assert len(submit) == 1
    for required in ('Feature.RecordRenderGraph', 'Feature.Ensure', 'Feature.Prepare.SceneAndSdf',
                     'Feature.Prepare.SurfaceAndCache', 'Feature.Prepare.Hardware', 'Feature.RecordCommands.Transport'):
        assert any(span['stage'] == required for span in spans), required
    top = sorted(spans, key=lambda span: span['milliseconds'], reverse=True)
    return dict(passed=True, actualFrames=12, events=len(entries), scopes=len(spans),
        firstRenderWaitSeconds=r['firstRenderWaitSeconds'], submitMilliseconds=submit[0]['milliseconds'],
        largestCpuScopes=top[:16], allCpuScopes=spans, runtime=r, diagnostics=diagnostics,
        timingKind='Nested CPU elapsed wall time; may include synchronous engine/driver waits; not GPU execution time',
        noImageReadback=True, productShaderChanges=False, performanceImprovementEstablished=False,
        fullProductionAccepted=False)


if __name__ == '__main__':
    output = NATIVE / 'analysis-first.json'
    assert not output.exists(), 'Preserve first trace qualification'
    try:
        result = qualify()
    except Exception:
        result = dict(passed=False, error=traceback.format_exc())
    with output.open('x', encoding='utf-8') as f:
        json.dump(result, f, indent=2)
    print(json.dumps({k: v for k, v in result.items() if k not in ('allCpuScopes', 'runtime', 'diagnostics')}, indent=2))
    raise SystemExit(0 if result['passed'] else 1)
