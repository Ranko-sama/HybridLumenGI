"""Pure CPU classification tests. No native package or capture data is opened."""
import unittest
import analyze as a


OWNER=dict(owner=2,keyLow=4,keyHigh=0)
CAMERA=a.bits(.5)
def rows(z=.5,camera=.5,capture=.5,entry=1,reached=1):
    depths=[a.bits(v) for v in (z,camera,capture)]
    return [(entry,reached,int(reached>0),0),(1,*depths),(a.depth_mask(depths),2,100,100)]


class DiagnosticTests(unittest.TestCase):
    def result(self,group,candidate=(2,0,1),identity=(4,0,1,1),depth=CAMERA):
        return a.fragment_result(group,candidate,identity,OWNER,depth)

    def test_retained_identity_control(self):
        self.assertEqual(self.result(rows())['classification'],'visible-identity-retained')

    def test_single_ulp_identity_fragment_mismatch_is_observed_not_tolerated(self):
        group=rows(z=a.value(CAMERA+1))
        result=self.result(group,(0,0,0),(0,0,0,0))
        self.assertEqual(result['classification'],'visible-strict-depth-rejected')
        self.assertEqual(result['rejectedTerms'],['SVz!=cameraDepth'])
        self.assertEqual(result['zCameraWordDistance'],1)

    def test_capture_depth_difference_is_separate(self):
        result=self.result(rows(capture=a.value(CAMERA+1)),(0,0,0),(0,0,0,0))
        self.assertEqual(result['rejectedTerms'],['cameraDepth!=captureDepth'])

    def test_no_entry_and_early_rejection_are_not_depth_failures(self):
        self.assertEqual(self.result([(0,0,0,0),(0,0,0,0),(0,0,0,0)])['classification'],'visible-no-fragment-entry')
        self.assertEqual(self.result([(1,0,0,0),(0,0,0,0),(0,0,0,0)])['classification'],'visible-rejected-before-depth')

    def test_multiple_fragments_cannot_inherit_first_failure_reason(self):
        result=self.result(rows(z=a.value(CAMERA+1),entry=2,reached=2),(0,0,0),(0,0,0,0))
        self.assertEqual(result['classification'],'visible-multiple-fragments-uncovered')
        self.assertNotIn('rejectedTerms',result)

    def test_candidate_and_resolve_discrepancies_are_distinct(self):
        self.assertEqual(self.result(rows(),(0,0,0),(0,0,0,0))['classification'],'visible-depth-passed-candidate-discrepancy')
        self.assertEqual(self.result(rows(),identity=(0,0,0,0))['classification'],'visible-depth-passed-resolve-discrepancy')

    def test_numeric_signed_zero_matches_original_equality(self):
        self.assertEqual(a.depth_mask([0x80000000,0,0]),7)

    def test_saved_mask_and_camera_depth_link_cannot_be_forged(self):
        group=rows();group[2]=(3,2,100,100)
        with self.assertRaises(AssertionError):self.result(group)
        with self.assertRaises(AssertionError):self.result(rows(),depth=CAMERA+1)

    def test_lifecycle_summary_has_eight_exact_frame_links(self):
        records=[dict(engineFrame=i+1,workFrame=i) for i in range(48)]
        summary=dict(complete=True,failure=None,framesExpected=8,framesCreated=8,framesCompleted=8,pendingReadbacks=0,
                     frameLinks=[dict(logicalFrame=i,engineFrame=i+1,workFrame=i,bytes=38928) for i in range(36,44)])
        a.probe_result(summary,records)
        summary['frameLinks'][3]['workFrame']+=1
        with self.assertRaises(AssertionError):a.probe_result(summary,records)


if __name__=='__main__':unittest.main(verbosity=2)
