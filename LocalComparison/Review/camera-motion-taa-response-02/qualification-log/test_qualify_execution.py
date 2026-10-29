"""Ensure the one summary exemption cannot hide another log failure."""
import copy
import importlib.util
import json
import unittest
import qualify_execution as q

spec = importlib.util.spec_from_file_location('scanner', q.ROOT / 'LocalComparison/Harness/native_log_check.py')
scanner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(scanner)


class QualificationTests(unittest.TestCase):
    def setUp(self):
        self.lines = (q.PACKAGE / 'unity.log').read_text(encoding='utf-8').splitlines()
        self.result = q.load(q.PACKAGE / 'native/scene-result.json')
        self.hits = scanner.scan(q.PACKAGE / 'unity.log')

    def test_exact_summary(self):
        accepted, remaining = q.qualify_hits(self.hits, self.lines, self.result, scanner.PATTERNS)
        self.assertEqual(len(accepted), 1)
        self.assertEqual(remaining, [])

    def test_separate_shader_error_is_preserved(self):
        extra = dict(category='compile', line=531, text='Shader error: deliberately injected test')
        _, remaining = q.qualify_hits(self.hits + [extra], self.lines, self.result, scanner.PATTERNS)
        self.assertEqual(remaining, [extra])

    def test_result_with_error_cannot_be_qualified(self):
        result = copy.deepcopy(self.result)
        result['error'] = 'readback failed'
        with self.assertRaises(AssertionError):
            q.validate_result(q.PREFIX + json.dumps(result), result, scanner.PATTERNS)

    def test_atomic_readback_unproven_is_rejected(self):
        result = copy.deepcopy(self.result)
        result['diagnostic'] = 'readback completion unproven'
        with self.assertRaises(AssertionError):
            q.validate_result(q.PREFIX + json.dumps(result), result, scanner.PATTERNS)

    def test_changed_same_prefix_is_not_exempted(self):
        changed = dict(self.hits[0])
        changed['text'] += ' Shader error: injected test'
        with self.assertRaises(AssertionError):
            q.qualify_hits([changed], self.lines, self.result, scanner.PATTERNS)


if __name__ == '__main__':
    unittest.main()
