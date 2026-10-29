"""CPU-only regression-contract checks; no native capture or prior RGB is opened."""
import copy
import hashlib
import importlib.util
import inspect
from pathlib import Path
import struct
import sys
import unittest
import analyze as a


def original():
    sys.modules['model']=a.m
    path=a.BASE/'qualification-ties/analyze.py'
    spec=importlib.util.spec_from_file_location('camera02_frozen_predicates',path)
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module);return module


def sources(generation=3):
    return [dict(name=n,stableId=i,revision=generation,geometryRevision=generation,matrix=list(a.IDENTITY),
                 shaderLinearColor=dict(x=1,y=1,z=1,w=1))
            for i,n in enumerate(('ReferenceWall','ReferenceFloor','FixedBlackPanel'),1)]


def window(changes=None):
    state=None;changes=changes or {}
    for logical in range(48):
        current=sources(3 if logical==0 else 4)
        if logical in changes:changes[logical](current)
        state=a.initialize_source_window(state,current,logical,logical>=2)
    return state


def observed(raw=(1,.5,.25,.5),history=None,age=1):
    data=bytearray(45*16)
    struct.pack_into('<4f',data,5*16,*raw)
    struct.pack_into('<4f',data,6*16,*(raw if history is None else history))
    struct.pack_into('<4f',data,7*16,.5,.25,age,0)
    return data,dict(base=0)


class RegressionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):cls.old=original()

    def test_all_math_output_and_input_decode_predicates_are_original(self):
        for name in ('decode_inputs','established','classify','current_measurement','result_check'):
            self.assertEqual(inspect.getsource(getattr(a,name)),inspect.getsource(getattr(self.old,name)),name)
        self.assertEqual(hashlib.sha256(Path(a.m.__file__).read_bytes()).hexdigest(),
                         '086977019baa6a0e8f475182f1b0486894f1a2bbb67b320974bb9e444d13a26b')

    def test_entire_48_frame_acceptance_loop_keeps_every_original_gate(self):
        old=inspect.getsource(self.old.analyze)
        before="        if frozen_sources is None:frozen_sources=r['sources']\n        require(r['sources']==frozen_sources,'Static geometry/material source changed')"
        after="        frozen_sources=initialize_source_window(frozen_sources,r['sources'],logical,bool(controls[0][0]))"
        self.assertEqual(old.count(before),1)
        self.assertEqual(inspect.getsource(a.analyze),old.replace(before,after))

    def test_physical_scene_predicates_are_original(self):
        def region(fn):return inspect.getsource(fn).split("    settings=source['settings']",1)[1].split('    return dict(',1)[0]
        self.assertEqual(region(a.source_closure),region(self.old.source_closure))

    def test_projection_only_changes_its_prequalified_authored_value(self):
        before="    cohort,target=targets()[index]\n    require(selected['index']==node['index']==index and selected['cohort']==cohort and vec(selected['worldTarget'])==target,'Authored selection order/target differs')"
        self.assertEqual(inspect.getsource(a.selected_source),inspect.getsource(self.old.selected_source).replace(before,'    cohort,target=qualified_author_target(selected,node,index)'))

    def test_typed_source_counterexample_and_adjacent_wrong_value(self):
        selected=dict(index=3,cohort='event',worldTarget=dict(x=struct.unpack('<f',struct.pack('<I',0x3f733333))[0],y=0.,z=.5))
        node=dict(index=3)
        self.assertEqual(a.qualified_author_target(selected,node,3)[1],a.targets()[3][1])
        selected['worldTarget']['x']=struct.unpack('<f',struct.pack('<I',0x3f733334))[0]
        with self.assertRaises(AssertionError):a.qualified_author_target(selected,node,3)

    def test_author_order_and_cohort_remain_exact(self):
        selected=dict(index=0,cohort='continued',worldTarget=dict(zip('xyz',a.targets()[0][1])))
        with self.assertRaises(AssertionError):a.qualified_author_target(selected,dict(index=0),0)
        selected['cohort']='event'
        with self.assertRaises(AssertionError):a.qualified_author_target(selected,dict(index=1),0)

    def test_initialization_only_generation_change_is_allowed(self):
        self.assertEqual(window()['full'],sources(4))

    def test_warmup_physical_change_and_valid_history_generation_change_fail(self):
        with self.assertRaises(AssertionError):window({1:lambda s:s[0]['shaderLinearColor'].update(x=.5)})
        with self.assertRaises(AssertionError):window({20:lambda s:s[0].update(revision=5)})

    def test_predecessor_and_original_bad_frames_are_protected(self):
        for logical in (30,31,38,39,41,42,43,47):
            with self.assertRaises(AssertionError):window({logical:lambda s:s[0].update(revision=5)})

    def test_first_exposure_requires_exact_current_and_age_one(self):
        data,node=observed();self.assertTrue(a.result_check(data,node,'first-exposure')['known'])
        for data,node in (observed(history=(.9,.5,.25,.5)),observed(age=2)):
            with self.assertRaises(AssertionError):a.result_check(data,node,'first-exposure')

    def test_continued_global_reset_or_invalid_history_cannot_pass(self):
        for data,node in (observed(age=1),observed(history=(1,.5,.25,0),age=32)):
            with self.assertRaises(AssertionError):a.result_check(data,node,'continued')
        data,node=observed(age=32);self.assertTrue(a.result_check(data,node,'continued')['known'])

    def test_unknown_and_signed_zero_keep_original_semantics(self):
        data,node=observed(raw=(0,0,0,-1));self.assertFalse(a.result_check(data,node,'first-exposure')['known'])
        data,node=observed(raw=(0,.5,.25,.5),history=(-0.,.5,.25,.5))
        self.assertTrue(a.result_check(data,node,'first-exposure')['known'])


if __name__=='__main__':unittest.main(verbosity=2)
