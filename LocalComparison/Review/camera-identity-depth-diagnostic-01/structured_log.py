"""Prospective structured-result parsing; keep the existing plain-log rules."""
import json
import re

PREFIX = 'CAMERA_MOTION_TAA_RESULT '


def unique_object(pairs):
    value = {}
    for key, item in pairs:
        if key in value:
            raise ValueError('Duplicate structured log key: ' + key)
        value[key] = item
    return value


def reject_constant(value):
    raise ValueError('Nonfinite structured log value: ' + value)


def atoms(value):
    if isinstance(value, str):
        yield value
    elif isinstance(value, dict):
        for key, child in value.items():
            yield key
            yield from atoms(child)
    elif isinstance(value, list):
        for child in value:
            yield from atoms(child)


def qualify_structured_summary(lines, hits, scene, patterns):
    """Only the one exact separately saved result may use field-aware matching.

    Shader/errors elsewhere remain untouched. Even on this result line, any
    original error signature within a JSON key or value remains an error.
    No line number or observed regex endpoint is fitted after execution.
    """
    summaries = [(i + 1, line) for i, line in enumerate(lines) if line.startswith(PREFIX)]
    assert len(summaries) == 1, 'Exactly one structured scene result required'
    number, text = summaries[0]
    parsed = json.loads(text[len(PREFIX):], object_pairs_hook=unique_object,
                        parse_constant=reject_constant)
    assert parsed == scene, 'Log summary differs from separate scene receipt'
    assert parsed.get('status') == 'collected' and parsed.get('error') == '', 'Scene result failed'
    remaining, qualified = [], []
    for hit in hits:
        if hit['line'] != number or hit['text'] != text:
            remaining.append(hit)
            continue
        pattern = patterns[hit['category']]
        if any(re.search(pattern, atom, re.I) for atom in atoms(parsed)):
            remaining.append(hit)
        else:
            qualified.append(dict(line=number, category=hit['category'],
                                  reason='Original regex matches only across structured JSON fields'))
    return remaining, qualified
