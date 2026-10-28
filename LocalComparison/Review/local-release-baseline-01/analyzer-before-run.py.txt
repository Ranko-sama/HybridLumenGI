"""Source/build/public-diagnostic qualification only; no new GPU or image oracle."""
import argparse,importlib.util,json,traceback
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];H=ROOT/'LocalComparison/Harness';PACKAGE=ROOT/'LocalComparison/Review/local-release-baseline-01';BUILD=Path('I:/Unity test/Comparison/Builds/LocalRelease40')
spec=importlib.util.spec_from_file_location('existing',H/'analyze-material-event.py');existing=importlib.util.module_from_spec(spec);spec.loader.exec_module(existing)
existing.PACKAGE=PACKAGE;existing.BUILD=BUILD;existing.smoke.PACKAGE=PACKAGE;existing.smoke.BUILD=BUILD
load=existing.load;save=existing.save
def build():
    report=load(PACKAGE/'build-report.json');assert report['configuration']=='Release' and report['requestedOptions']==report['actualOptions']=='None','Actual Release build options differ'
    assert load(PACKAGE/'instrumentation/excluded-restoration.json')['allRestored'],'Historical includes not restored'
    m=load(PACKAGE/'instrumentation/manifest.json');actual={x['path'] for x in report['inputs']};assert not any(row['path'] in actual for row in m['excluded']),'Historical test includes remained in build inputs'
    return existing.build()
def run():
    n=PACKAGE/'native-window';report={'ordinaryReleaseVerified':False,'fullProductionAccepted':False,'perRayGpuConsumptionProven':False,'trackedOwnerZeroProven':False}
    try:
        end=load(n/'native-exit.json');r=load(n/'run/release-result.json');rows=existing.lines(n/'run/diagnostics.jsonl');hits=existing.smoke.hits(n/'player.log')
        report.update(nativeExit=end,runtime=r,diagnostics=rows,nativeLogHits=hits)
        assert end['exitCode']==0 and not end['watchdogTerminated'] and not hits,'Native exit/error failure'
        assert r['status']=='completed-finite-release-check' and r['actualCameraFrames']==r['requestedFrames']==120 and r['errors']==0,'Finite run incomplete'
        assert not r['debugBuild'] and r['verify120'] and r['testCaptureDisabled'] and r['auditProbeDisabled'] and r['featureEnabled'],'Actual Release/startup isolation missing'
        assert r['api']=='Direct3D12' and r['width']==640 and r['height']==360 and r['lastEngine']-r['firstRenderEngine']==119,'Actual target-camera frame/window contract'
        assert [x['actualCameraFrames'] for x in rows]==[1,60,120] and rows[2]['giFrame']>rows[1]['giFrame']>0
        for row in rows[1:]:
            assert row['featureEnabled'] and row['hardwareBackend'] and row['hardwareMeshes']>0 and row['readyCards']>0 and row['publishedInstances']>0 and row['hardwareMaterialUnknownRecords']==0
            assert row['hardwareMaterialStatus']=='Uploads and both consumers bound; GPU completion unproven'
        assert sorted(x.name for x in (n/'run').iterdir())==['diagnostics.jsonl','release-result.json'],'Unexpected capture/probe outputs'
        report['ordinaryReleaseVerified']=True
    except Exception as e:report.update(failure=str(e),traceback=traceback.format_exc())
    assert not (n/'analysis.json').exists(),'Preserve first Release analysis';save(n/'analysis.json',report);print(json.dumps(report,indent=2));return report['ordinaryReleaseVerified']
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('action',choices=['build','products','run']);a=p.parse_args();ok=build() if a.action=='build' else existing.smoke.verify_products() if a.action=='products' else run();raise SystemExit(0 if ok else 1)
