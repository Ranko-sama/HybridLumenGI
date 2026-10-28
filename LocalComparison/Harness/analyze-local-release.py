"""Source/build/public-diagnostic qualification only; no new GPU or image oracle."""
import argparse,importlib.util,json,traceback,struct,math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];H=ROOT/'LocalComparison/Harness';PACKAGE=ROOT/'LocalComparison/Review/local-release-baseline-01';BUILD=Path('I:/Unity test/Comparison/Builds/LocalRelease40')
spec=importlib.util.spec_from_file_location('existing',H/'analyze-material-event.py');existing=importlib.util.module_from_spec(spec);spec.loader.exec_module(existing)
existing.PACKAGE=PACKAGE;existing.BUILD=BUILD;existing.smoke.PACKAGE=PACKAGE;existing.smoke.BUILD=BUILD
load=existing.load;save=existing.save

def configure_steady():
    global PACKAGE,BUILD
    PACKAGE=ROOT/'LocalComparison/Review/local-release-steady-use-01';BUILD=Path('I:/Unity test/Comparison/Builds/LocalRelease44')
    existing.PACKAGE=PACKAGE;existing.BUILD=BUILD;existing.smoke.PACKAGE=PACKAGE;existing.smoke.BUILD=BUILD

def configure_integration():
    global PACKAGE,BUILD
    PACKAGE=ROOT/'LocalComparison/Review/current-release-integration-01';BUILD=Path('I:/Unity test/Comparison/Builds/LocalRelease49')
    existing.PACKAGE=PACKAGE;existing.BUILD=BUILD;existing.smoke.PACKAGE=PACKAGE;existing.smoke.BUILD=BUILD
def configure_final_image():
    global PACKAGE,BUILD
    PACKAGE=ROOT/'LocalComparison/Review/current-representative-final-image-01';BUILD=Path('I:/Unity test/Comparison/Builds/LocalRelease54')
    existing.PACKAGE=PACKAGE;existing.BUILD=BUILD;existing.smoke.PACKAGE=PACKAGE;existing.smoke.BUILD=BUILD
def build():
    report=load(PACKAGE/'build-report.json');assert report['configuration']=='Release' and report['requestedOptions']==report['actualOptions']=='None','Actual Release build options differ'
    assert load(PACKAGE/'instrumentation/excluded-restoration.json')['allRestored'],'Historical includes not restored'
    m=load(PACKAGE/'instrumentation/manifest.json');actual={x['path'] for x in report['inputs']};assert not any(row['path'] in actual for row in m['excluded']),'Historical test includes remained in build inputs'
    return existing.build()
def run(final_image=False):
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
        expected=['diagnostics.jsonl','release-result.json']
        if final_image:
            expected+=['feature.json','frame-0119.json','frame-0119.rgba32f','frame-0119.exr','frame-0119.png']
            assert r['finalImageMode'] and r['finalImageCaptured'] and r['actualViewMode']=='Final','Final mode/capture missing'
            f=load(n/'run/frame-0119.json');assert f['captured'] and f['logicalFrame']==119 and f['engineFrame']==r['lastEngine'] and f['stage']=='color-static-final-only','Final frame identity'
            raw=(n/'run'/f['raw']).read_bytes();assert len(raw)==640*360*16,'RGBA32F dimensions'
            values=struct.unpack('<'+'f'*(640*360*4),raw);assert all(math.isfinite(v) for v in values),'Nonfinite final image'
            png=(n/'run'/f['png']).read_bytes();assert png[:8]==b'\x89PNG\r\n\x1a\n' and struct.unpack('>II',png[16:24])==(640,360),'PNG format/dimensions'
            exr=(n/'run'/f['exr']).read_bytes();assert len(exr)>8 and struct.unpack('<I',exr[:4])[0]==20000630,'EXR format'
            report['finalHdrDataVerified']=True;report['visualAssessment']='Required separately by viewing the actual PNG; not an automatic image-quality pass'
            report['finalFrame']=f;report['imageScope']=r['imageScope']
            report['imageFiles']={f[k]:{'bytes':(n/'run'/f[k]).stat().st_size,'sha256':existing.sha(n/'run'/f[k])} for k in ['raw','exr','png']}
        assert sorted(x.name for x in (n/'run').iterdir())==sorted(expected),'Unexpected capture/probe outputs'
        report['ordinaryReleaseVerified']=True
    except Exception as e:report.update(failure=str(e),traceback=traceback.format_exc())
    assert not (n/'analysis.json').exists(),'Preserve first Release analysis';save(n/'analysis.json',report);print(json.dumps(report,indent=2));return report['ordinaryReleaseVerified']
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('action',choices=['build','products','run']);mode=p.add_mutually_exclusive_group();mode.add_argument('--integration',action='store_true');mode.add_argument('--final-image',action='store_true');a=p.parse_args()
    if a.integration:configure_integration()
    if a.final_image:configure_final_image()
    ok=build() if a.action=='build' else existing.smoke.verify_products() if a.action=='products' else run(a.final_image);raise SystemExit(0 if ok else 1)
