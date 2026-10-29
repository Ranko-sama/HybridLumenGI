import json
import unittest
from structured_log import PREFIX, qualify_structured_summary


class StructuredSummaryTests(unittest.TestCase):
    patterns = {'readback': r'readback[^\r\n]*(?:mismatch|unproven)', 'shader': r'Shader error'}

    def fixture(self, **extra):
        result = dict(status='collected', error='', readbacksDrained=True,
                      materialStatus='Uploads and both consumers bound; GPU completion unproven', **extra)
        text = PREFIX + json.dumps(result)
        hit = dict(line=1, category='readback', text=text)
        return result, text, hit

    def test_cross_field_match_only(self):
        scene, text, hit = self.fixture()
        remaining, qualified = qualify_structured_summary([text], [hit], scene, self.patterns)
        self.assertEqual(remaining, [])
        self.assertEqual(len(qualified), 1)

    def test_real_atomic_error_retained(self):
        scene, text, hit = self.fixture(detail='readback completion unproven')
        remaining, qualified = qualify_structured_summary([text], [hit], scene, self.patterns)
        self.assertEqual(remaining, [hit])
        self.assertEqual(qualified, [])

    def test_other_line_retained(self):
        scene, text, hit = self.fixture()
        fault = dict(line=2, category='shader', text='Shader error in identity')
        remaining, _ = qualify_structured_summary([text, fault['text']], [hit, fault], scene, self.patterns)
        self.assertEqual(remaining, [fault])

    def test_mismatched_or_failed_receipt_rejected(self):
        scene, text, hit = self.fixture()
        with self.assertRaises(AssertionError):
            qualify_structured_summary([text], [hit], dict(scene, error='failure'), self.patterns)
        failed = dict(scene, error='failure')
        failed_text = PREFIX + json.dumps(failed)
        with self.assertRaises(AssertionError):
            qualify_structured_summary([failed_text], [], failed, self.patterns)

    def test_duplicate_key_rejected(self):
        scene, text, _ = self.fixture()
        duplicate = text[:-1] + ', "status": "collected"}'
        with self.assertRaises(ValueError):
            qualify_structured_summary([duplicate], [], scene, self.patterns)


if __name__ == '__main__':
    unittest.main()
