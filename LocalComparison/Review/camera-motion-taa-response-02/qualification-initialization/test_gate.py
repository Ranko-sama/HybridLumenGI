"""Only source metadata and code identity; no captured BIN/RGB is opened."""
import copy
import inspect
import sys
import unittest
import analyze as q

def sources(generation=3):
    return [dict(name=name,stableId=index+1,revision=generation,geometryRevision=generation,matrix=[1,0,0,1],shaderLinearColor=dict(x=1,y=1,z=1,w=1)) for index,name in enumerate(('wall','floor','panel'))]

def sequence(changes=None):
    changes=changes or {};baseline=None
    for logical in range(48):
        current=sources(3 if logical==0 else 4)
        if logical in changes:changes[logical](current)
        baseline=q.initialization_gate(baseline,current,logical)
    return baseline

class GateTests(unittest.TestCase):
    def test_initial_generation_advance_with_fixed_physical_source(self):
        self.assertEqual(sequence(),sources(4))
    def test_stable_id_change_even_during_warmup_fails(self):
        with self.assertRaises(AssertionError):sequence({1:lambda s:s[0].update(stableId=99)})
    def test_physical_matrix_change_during_warmup_fails(self):
        with self.assertRaises(AssertionError):sequence({10:lambda s:s[0].update(matrix=[2,0,0,1])})
    def test_material_change_during_warmup_fails(self):
        with self.assertRaises(AssertionError):sequence({10:lambda s:s[0]['shaderLinearColor'].update(x=.25)})
    def test_generation_change_at_first_observation_fails(self):
        with self.assertRaises(AssertionError):sequence({31:lambda s:s[0].update(revision=5,geometryRevision=5)})
    def test_generation_change_later_in_observation_fails(self):
        with self.assertRaises(AssertionError):sequence({47:lambda s:s[0].update(revision=5)})
    def test_original_function_only_two_line_gate_is_replaced(self):
        original=q.original_module();function,report=q.adapted_analyze(original)
        self.assertIs(sys.modules[original.__name__],original)
        self.assertEqual(report['replacedOriginalLines'],2)
        original_source=inspect.getsource(original.analyze)
        self.assertEqual(original_source.count(q.ORIGINAL_GATE),1)
        # All other functions, especially output/coverage decisions and the
        # entire mathematical model, remain the original function objects.
        for name in ('result_check','classify','current_measurement','decode_inputs','selected_source','source_closure'):
            self.assertIs(function.__globals__[name],getattr(original,name))
        self.assertIs(function.__globals__['m'],original.m)

if __name__=='__main__':unittest.main(verbosity=2)
