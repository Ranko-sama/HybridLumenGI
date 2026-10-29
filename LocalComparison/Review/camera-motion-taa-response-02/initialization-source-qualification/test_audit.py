import copy
import unittest
from audit import qualify


def fixture():
    sources=[dict(name=n,stableId=i,revision=3,geometryRevision=3,matrix=list(range(16)),
                  shaderLinearColor=dict(x=1,y=1,z=1,w=1)) for i,n in enumerate(('wall','floor','panel'),1)]
    records=[];controls=[]
    for i in range(48):
        s=copy.deepcopy(sources)
        if i:
            for row in s:row.update(revision=4,geometryRevision=4)
        records.append(dict(logicalFrame=i,complete=True,error='',sources=s,engineFrame=i+1,workFrame=max(0,i-1),
                            historyValid=i>=2,changeCount=6 if i<2 else 0,vp=[i],invVP=[-i],previousVP=[i-1],previousInvVP=[1-i]))
        controls.append((0.,1.,0.,6.) if i<2 else (1.,0.,0.,0.))
    return records,controls


class QualificationTests(unittest.TestCase):
    def reject(self, mutation):
        records,controls=fixture();mutation(records,controls)
        with self.assertRaises(AssertionError):qualify(records,controls)

    def test_warmup_invalidation_is_distinct_from_physical_change(self):
        self.assertTrue(qualify(*fixture())['sourceWindowQualified'])

    def test_physical_change_in_warmup_rejected(self):
        self.reject(lambda r,c:r[1]['sources'][0]['shaderLinearColor'].update(x=.5))

    def test_generation_change_at_first_observation_rejected(self):
        self.reject(lambda r,c:r[31]['sources'][0].update(revision=5))

    def test_predecessor_is_protected(self):
        self.reject(lambda r,c:r[30]['sources'][0].update(revision=5))

    def test_valid_history_at_generation_transition_rejected(self):
        def change(r,c):r[1]['historyValid']=True;c[1]=(1.,1.,0.,6.)
        self.reject(change)

    def test_window_reactivity_rejected(self):
        self.reject(lambda r,c:c.__setitem__(32,(1.,1.,0.,0.)))

    def test_previous_matrix_mismatch_rejected(self):
        self.reject(lambda r,c:r[31].update(previousVP=[99]))

    def test_new_record_field_cannot_be_silently_exempted(self):
        self.reject(lambda r,c:r[0]['sources'][0].update(newPhysicalField=True))


if __name__=='__main__':unittest.main()
