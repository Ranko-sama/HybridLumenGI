"""Read-only diagnosis of the preserved failed camera/TAA experiment.

This is not another acceptance analysis. It decodes observed output solely to
trace the already failed input identity/history chain. No new cohort or PASS.
"""
import argparse
from collections import Counter, defaultdict
import hashlib
import json
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[4]
PACKAGE = Path(__file__).resolve().parent.parent
NATIVE = PACKAGE / 'native'
FAILURE = PACKAGE / 'analysis-source-expression-qualified.json'
ABI_SIZE = (12 + 264 * 45) * 16


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def counts(values):
    return [dict(value=value, count=count) for value, count in sorted(Counter(values).items())]


def decode(data):
    assert len(data) == ABI_SIZE
    rows = []
    for index in range(264):
        start = (12 + index * 45) * 16
        chunk = lambda row: data[start + row * 16:start + (row + 1) * 16]
        f = lambda row: struct.unpack('<4f', chunk(row))
        u = lambda row: struct.unpack('<4I', chunk(row))
        assert u(0)[2:] == (index, 0)
        prior = []
        for slot in range(5):
            row = 15 + slot * 6
            meta = u(row)
            assert meta[2] == slot
            prior.append(dict(pixel=meta[:2], slot=slot, inBounds=meta[3],
                              geometry=f(row+1), identity=u(row+3), age=f(row+5)[2],
                              payload=b''.join(chunk(row+j) for j in (1, 2, 3, 4, 5))))
        rows.append(dict(index=index, pixel=u(0)[:2], geometry=f(3), identity=u(8),
                         candidate=u(9), objectKey=u(14), transform=[f(r) for r in range(10, 14)],
                         raw=f(5), history=f(6), moments=f(7), rawBits=u(5), historyBits=u(6),
                         age=f(7)[2], prior=prior,
                         payload=b''.join(chunk(r) for r in (3, 4, 8, 6, 7))))
    return [struct.unpack_from('<4f', data, r*16) for r in range(12)], rows


def observed_label(node):
    # Observed normal labels aid diagnosis only; they are not source proofs.
    return {(0., 1.): 'floor-normal', (1., 1.): 'panel-normal'}.get(node['geometry'][:2], 'other-normal')


def brief(node):
    return {k: v for k, v in node.items() if k not in ('payload', 'prior')} | {
        'prior': [{k: v for k, v in old.items() if k != 'payload'} for old in node['prior']]}


def main(output):
    assert not output.exists(), 'Preserve the first diagnostic result'
    inputs = [FAILURE, PACKAGE/'instrumentation/manifest.json', NATIVE/'frames.jsonl']
    inputs += [NATIVE/f'frame-{frame:03}.{ext}' for frame in range(48) for ext in ('json', 'bin')]
    input_hashes = {p.relative_to(ROOT).as_posix(): sha(p) for p in inputs}
    failure = json.loads(FAILURE.read_text())
    assert failure['passed'] is False
    source_manifest = json.loads((PACKAGE/'instrumentation/manifest.json').read_text())
    sources = ['Runtime/Resources/HybridLumenGI/HybridLumenGIReceiverIdentity.shader',
               'Runtime/Resources/HybridLumenGI/HybridLumenGIReceiverIdentity.compute',
               'Runtime/HybridLumenGIReceiverIdentityPass.cs', 'Runtime/HybridLumenGIReceiverIdentityFrame.cs',
               'Runtime/HybridLumenGIRendererFeature.cs']
    for name in sources:
        assert sha(ROOT/name) == source_manifest['productSourceSha256'][name], name
    frames = []
    decoded = []
    receipts = []
    for logical in range(48):
        receipt = json.loads((NATIVE/f'frame-{logical:03}.json').read_text())
        header, nodes = decode((NATIVE/f'frame-{logical:03}.bin').read_bytes())
        assert receipt['logicalFrame'] == logical
        assert int(header[1][3]) == receipt['workFrame']
        assert all(node['pixel'] == (selected['x'], selected['y'])
                   for node, selected in zip(nodes, receipt['selection']))
        controls = nodes[231:]
        frames.append(dict(logicalFrame=logical, workFrame=receipt['workFrame'], engineFrame=receipt['engineFrame'],
                           cameraPosition=receipt['cameraPosition'], jitterDelta=receipt['jitterDelta'],
                           controls=header[:4], normalCandidateIdentity=counts((observed_label(n), n['candidate'][:3], n['identity']) for n in nodes),
                           continuedIdentities=counts(n['identity'] for n in controls),
                           continuedCandidates=counts(n['candidate'] for n in controls),
                           continuedAges=counts(n['age'] for n in controls),
                           continuedPriorAgesAllFiveSlots=counts(o['age'] for n in controls for o in n['prior']),
                           continuedRawEqualsHistoryBits=sum(n['rawBits'] == n['historyBits'] for n in controls)))
        decoded.append(nodes)
        receipts.append(receipt)

    aliases = []
    addresses = []
    for logical, nodes in enumerate(decoded):
        same_pixel = defaultdict(list)
        for node in nodes:
            same_pixel[node['pixel']].append(node)
        alias_mismatches = [pixel for pixel, values in same_pixel.items()
                            if any(n['payload'] != values[0]['payload'] for n in values[1:])]
        aliases.append(dict(logicalFrame=logical, distinctPixels=len(same_pixel), mismatches=alias_mismatches))
        addresses.append(same_pixel)
    # Compare only actual identical addresses present in the sparse capture.
    # No interpolation, reprojection tolerance, or source-identity inference.
    chains = []
    examples = []
    for logical in range(1, 48):
        matches = []
        mismatches = []
        distinct = set()
        for node in decoded[logical]:
            for old in node['prior']:
                if old['pixel'] not in addresses[logical-1]:
                    continue
                previous = addresses[logical-1][old['pixel']][0]
                equal = previous['payload'] == old['payload']
                entry = dict(currentIndex=node['index'], slot=old['slot'], previousIndex=previous['index'],
                             pixel=old['pixel'], identity=old['identity'], age=old['age'])
                (matches if equal else mismatches).append(entry)
                distinct.add(old['pixel'])
                if equal and logical in (38, 39, 42, 43) and len(examples) < 40 and (
                        not any(old['identity']) or old['age'] == 1):
                    examples.append(dict(logicalFrame=logical, **entry))
        chains.append(dict(logicalFrame=logical, exactPayloadMatches=len(matches), distinctPreviousPixels=len(distinct),
                           mismatches=mismatches, comparedBytesPerMatch=80))

    # This names the already reported missing cohorts, never reclassifies them.
    event_context = {}
    for logical in (38, 39):
        event_context[str(logical)] = [brief(node) for node in decoded[logical][:231]
                                      if observed_label(node) == 'floor-normal'
                                      and node['prior'][0]['geometry'][:2] == (1., 1.)]
    diagnostics = [json.loads(line) for line in (NATIVE/'frames.jsonl').read_text().splitlines() if line.strip()]
    keys = ('frame', 'receiverTrackedSubmeshes', 'receiverSourcesPublished', 'receiverIdentityEnabled',
            'receiverIdentityStatus', 'receiverIdentityDraws', 'receiverUnknownRectangles',
            'receiverIdentityBufferBytes', 'publishedInstances', 'readyCards')
    cpu = []
    for logical in range(31, 48):
        engine = receipts[logical]['engineFrame']
        candidates = [row for row in diagnostics if row['engineFrame'] == engine]
        assert len(candidates) == 1
        cpu.append(dict(logicalFrame=logical, engineFrame=engine, ready=candidates[0]['ready'],
                        diagnostics={key: candidates[0]['diagnostics'][key] for key in keys}))

    report = dict(scope='Diagnosis of preserved FAIL, no revised acceptance or selection',
                  originalAnalysisAccepted=False, originalFailureSha256=sha(FAILURE),
                  originalFailureSummary={key: failure[key] for key in ('passed', 'distinctEvents', 'nonzeroJitterFrames', 'unknown', 'violations', 'coverageFailures')},
                  inputFiles=input_hashes, sourceFiles={name: sha(ROOT/name) for name in sources},
                  diagnosticScriptSha256=sha(Path(__file__)),
                  decodedCurrentRgbForDiagnosis=True, nativeRerun=False,
                  frames=frames, aliasContent=aliases, sameAddressCrossFrame=chains, dropoutChainExamples=examples,
                  eventFloorWithPanelHint=event_context,
                  continuedSampleRows={str(f): [brief(n) for n in decoded[f][231:]] for f in range(40,45)},
                  cpuDiagnostics=cpu,
                  limits=['Normal names in this report are observed labels, not replacement independent source qualification.',
                          'Sparse same-address closure proves only captured overlapping addresses.',
                          'Object rows are copied only for candidate.x>0; zero copied row is not evidence the real object buffer is zero.',
                          'No fragment z, capture depth or capture-time actual UNITY_MATRIX_VP was recorded; root cause is not yet established.'])
    assert all(sha(ROOT/name) == value for name, value in input_hashes.items()), 'A frozen input changed'
    with output.open('x', encoding='utf-8') as stream:
        json.dump(report, stream, indent=2)
        stream.write('\n')
    print(json.dumps(dict(report=output.relative_to(ROOT).as_posix(), reportSha256=sha(output),
                          aliasMismatches=sum(len(x['mismatches']) for x in aliases),
                          crossFrameMismatches=sum(len(x['mismatches']) for x in chains),
                          focusChains=[x for x in chains if x['logicalFrame'] in (38,39,41,42,43)],
                          originalAnalysisAccepted=False), indent=2))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, required=True)
    main(parser.parse_args().output)
