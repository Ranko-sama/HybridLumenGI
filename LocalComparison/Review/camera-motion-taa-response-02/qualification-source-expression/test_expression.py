"""Actual source counterexample and wrong-input controls; no native data."""
import struct
import unittest
import analyze as q

class ExpressionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):cls.init,cls.old,cls.function,_,_,cls.qualifier=q.prepare_adapter()
    def row(self,index,bits):
        value=struct.unpack('<f',struct.pack('<I',bits))[0]
        return dict(index=index,cohort='event',worldTarget=dict(x=value,y=0.,z=.5)),dict(index=index)
    def test_real_source_counterexamples(self):
        for index,bits in ((3,0x3f733333),(5,0x3f866667)):
            selected,node=self.row(index,bits);_,target=type(self).qualifier(selected,node,index)
            self.assertEqual(struct.unpack('<I',struct.pack('<f',target[0]))[0],bits)
            self.assertNotEqual(target,self.old.targets()[index][1])
    def test_adjacent_but_wrong_authored_value_is_rejected(self):
        selected,node=self.row(3,0x3f733334)
        with self.assertRaises(AssertionError):type(self).qualifier(selected,node,3)
    def test_index_and_cohort_remain_exact(self):
        selected,node=self.row(3,0x3f733333);selected['cohort']='continued'
        with self.assertRaises(AssertionError):type(self).qualifier(selected,node,3)
        selected,node=self.row(3,0x3f733333);node['index']=4
        with self.assertRaises(AssertionError):type(self).qualifier(selected,node,3)
    def test_math_outputs_coverage_and_projection_remain_original(self):
        for name in ('result_check','classify','current_measurement','decode_inputs','source_closure'):
            self.assertIs(self.function.__globals__[name],getattr(self.old,name))
        self.assertIs(self.function.__globals__['m'],self.old.m)
        selected=self.function.__globals__['selected_source']
        self.assertIs(selected.__globals__['m'].project,self.old.m.project)
        self.assertIs(self.function.__globals__['initialization_gate'],self.init.initialization_gate)

if __name__=='__main__':unittest.main(verbosity=2)
