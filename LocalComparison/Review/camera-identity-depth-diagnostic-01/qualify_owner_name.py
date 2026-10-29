"""Correct one author-name typo; preserve the first diagnostic result and all gates."""
import hashlib
import importlib.util
import json
from pathlib import Path
import sys

P = Path(__file__).resolve().parent
load = lambda path: json.loads(path.read_text(encoding='utf-8-sig'))
sha = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()


if __name__ == '__main__':
    output = P / 'analysis-owner-name-qualified.json'
    assert not output.exists(), 'Preserve the first name-qualified result'
    failure = load(P / 'analysis-first.json')
    assert failure['diagnosticComplete'] is False and failure['error'] == 'Source owner mapping differs'
    assert load(P / 'execution-receipt.json')['passed'] is True
    manifest = load(P / 'instrumentation/manifest.json')
    row = next(row for row in manifest['files'] if row['path'].endswith('/Editor/CameraMotionTaaEditor.cs'))
    editor = P / 'instrumentation' / row['prepared']
    assert sha(editor) == row['sha256']
    source = editor.read_text()
    assert source.count('var panel=Surface("FixedBlackPanel",') == 1
    assert 'Surface("ReferencePanel",' not in source
    spec = importlib.util.spec_from_file_location('frozen_identity_diagnosis', P / 'analyze.py')
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    assert module.NAMES == {'ReferenceFloor': 'floor', 'ReferencePanel': 'panel', 'ReferenceWall': 'wall'}
    module.NAMES = {'ReferenceFloor': 'floor', 'FixedBlackPanel': 'panel', 'ReferenceWall': 'wall'}
    pins = {str(path): sha(path) for path in (Path(__file__), P / 'analysis-first.json',
            P / 'analyze.py', P / 'execution-receipt.json', editor)}
    try:
        result = module.analyze(P)
    except Exception as error:
        result = dict(diagnosticComplete=False, status='source-or-observation-failure',
                      error=str(error), originalQualityAccepted=False)
    assert all(sha(Path(path)) == digest for path, digest in pins.items())
    result['ownerNameQualification'] = dict(sourceSha256=pins, original='ReferencePanel',
        authored='FixedBlackPanel', scope='Only the author-name lookup changes; source, geometry, depth, counters and coverage predicates remain original')
    with output.open('x', encoding='utf-8') as stream:
        json.dump(result, stream, indent=2)
        stream.write('\n')
    print(json.dumps({k: result.get(k) for k in ('diagnosticComplete', 'status', 'visibleIdentityDropoutPixels', 'error')}))
    raise SystemExit(0 if result['diagnosticComplete'] else 1)
