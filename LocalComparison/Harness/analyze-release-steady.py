"""One predeclared 300-second public-accounting window; never a total-VRAM oracle."""
import argparse,importlib.util,json,traceback
from pathlib import Path
H=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('release',H/'analyze-local-release.py');release=importlib.util.module_from_spec(spec);spec.loader.exec_module(release)
release.configure_steady();PACKAGE=release.PACKAGE;load=release.load;save=release.save

FIXED=['hardwareMaterialFrameBytes','screenTextureEstimateBytes','worldMaterialBytes','objectSdfBytes','globalSdfBytes','worldCacheBytes',
       'hardwareAttributeBytes','proposalBufferBytes','softwareGeometryBytes','areaEmitterBytes','surfaceTriangleMappingCpuBytes','receiverIdentityBufferBytes','sceneLightingPolicyBytes']
SCENE=['publishedInstances','readyCards','hardwareMeshes','hardwareFallbacks','chartedOwners','approximateOwners','requiredSurfaceCards']
TRANSIENT=['hardwareMaterialGlobalAllocatedBytes','rtasGlobalAccountedBytes','rtasGlobalEstimatedBytes','rtasGlobalRetiredBytes',
           'retirementPending','retirementOwned','deformationReservedBytes','deformationWorkers','deformationSnapshots']
ACTIVITY=['warmingInstances','pendingCapacity','pendingCards','warmupBudgetBlockedCards','globalPendingBricks','globalUpdatedBricks',
          'materialUploadBytesUsed','hardwareSceneRebuilds','hardwareTransformUpdates','hardwareTriangleUploads','rtasBuildsThisFrame','rtasPendingDemands']
FAILURES=['retirementFailed','retirementFailedWithdrawals','deformationFailed']
UNKNOWN=['retirementUnknown','retirementSubmissionUncertain']

def value(row,key):return row[key] if key in row else row['diagnostics'][key]
def bounds(rows,key):
    values=[value(r,key) for r in rows]
    return {'min':min(values),'max':max(values),'first':values[0],'last':values[-1],'distinct':len(set(values)),
            'nondecreasingWithIncrease':values[-1]>values[0] and all(b>=a for a,b in zip(values,values[1:]))}

def run():
    n=PACKAGE/'native-window';report={'status':'unresolved','finiteSustainedUseAccepted':False,'fullProductionAccepted':False,
        'totalVramStableProven':False,'trackedOwnerZeroProven':False,'newApiNativeCoverageProven':False,
        'windowContract':{'totalSeconds':300,'initializationSeconds':60,'sampleSeconds':5,'comparisonSeconds':[180,240],'finalSeconds':[240,300]},'unresolved':[]}
    try:
        report['buildProductsManifestSha256']=release.existing.smoke.verify_products()
        end=load(n/'native-exit.json');r=load(n/'run/release-result.json');rows=release.existing.lines(n/'run/diagnostics.jsonl');hits=release.existing.smoke.hits(n/'player.log')
        report.update(nativeExit=end,runtime=r,nativeLogHits=hits,sampleCount=len(rows))
        assert end['exitCode']==0 and not end['watchdogTerminated'] and not hits,'Native exit/error failure'
        assert r['status']=='completed-finite-release-check' and r['errors']==0 and r['elapsedSeconds']>=300,'Fixed run incomplete'
        assert not r['debugBuild'] and r['verifySteady300'] and not r['verify120'] and r['testCaptureDisabled'] and r['auditProbeDisabled'] and r['featureEnabled'],'Release isolation missing'
        assert (r['requestedSeconds'],r['initializationSeconds'],r['sampleIntervalSeconds'])==(300,60,5),'Window configuration changed'
        assert r['api']=='Direct3D12' and (r['width'],r['height'])==(640,360),'Actual backend/window configuration changed'
        assert r['lastEngine']-r['firstRenderEngine']==r['actualCameraFrames']-1,'Target-camera receipt discontinuity'
        assert sorted(p.name for p in (n/'run').iterdir())==['diagnostics.jsonl','release-result.json'],'Unexpected probe output'
        if [x['sampleSlot'] for x in rows]!=list(range(61)):report['unresolved'].append('Missing fixed 5-second sample slot; no interpolation or rerun')
        observed=[x for x in rows if x['sampleSlot']>=12];prior=[x for x in rows if 36<=x['sampleSlot']<48];final=[x for x in rows if 48<=x['sampleSlot']<=60]
        assert observed and prior and final,'Required predeclared windows absent'
        assert all(b['giFrame']>a['giFrame'] and b['actualCameraFrames']>a['actualCameraFrames'] for a,b in zip(observed,observed[1:])),'GI did not actually advance'
        for row in observed:
            assert row['featureEnabled'] and row['hardwareBackend'] and row['hardwareMeshes']>0 and row['readyCards']>0 and row['publishedInstances']>0 and row['hardwareMaterialUnknownRecords']==0,'Prepared backend not sustained'
            assert row['hardwareMaterialStatus']=='Uploads and both consumers bound; GPU completion unproven','Binding status changed'
            assert not row['retirementAdmissionClosed'] and not any(value(row,k) for k in FAILURES),'Recorded resource failure/admission closure'
            assert not row['diagnostics']['gpuFeedbackActive'] and row['diagnostics']['gpuAcceptedObservations']==0,'Timing or feedback unexpectedly active'
        if any(value(row,k) for row in final for k in UNKNOWN):report['unresolved'].append('Unknown submission remains in final window')
        report['scene']={k:bounds(observed,k) for k in SCENE}
        report['fixedStorage']={k:bounds(observed,k) for k in FIXED}
        report['transientAccounting']={k:{'observed':bounds(observed,k),'prior':bounds(prior,k),'final':bounds(final,k)} for k in TRANSIENT}
        report['activity']={k:{'observed':bounds(observed,k),'final':bounds(final,k)} for k in ACTIVITY}
        report['rtasMeasuredHighWater']={'meaning':'High-water estimate/measurement, not current active bytes','observed':bounds(observed,'rtasGlobalMeasuredHighWaterBytes')}
        for k,v in {**report['scene'],**report['fixedStorage']}.items():
            if v['distinct']!=1:report['unresolved'].append(k+': scene/fixed storage still changes after initialization')
        for k,v in report['transientAccounting'].items():
            # Exact empirical envelope, not a percentage tolerance or a leak threshold.
            # Lower minima allow draining. A new final-window high is unresolved, not called a leak.
            if v['final']['max']>v['prior']['max']:report['unresolved'].append(k+': final-window high exceeds the predeclared preceding window; growth not attributed')
        for k in ['warmingInstances','pendingCapacity','pendingCards','warmupBudgetBlockedCards','globalPendingBricks']:
            if report['activity'][k]['final']['max']!=0:report['unresolved'].append(k+': initialization/preparation remains open in final window')
        report['giFrames']={'firstObserved':observed[0]['giFrame'],'last':observed[-1]['giFrame']}
        report['status']='resource-trend-unresolved' if report['unresolved'] else 'finite-sustained-use-established'
        report['finiteSustainedUseAccepted']=not report['unresolved']
    except Exception as e:report.update(status='concrete-blocker',failure=str(e),traceback=traceback.format_exc())
    assert not (n/'analysis.json').exists(),'Preserve first sustained-use analysis'
    save(n/'analysis.json',report)
    print(json.dumps({k:v for k,v in report.items() if k not in ['scene','fixedStorage','transientAccounting','activity']},indent=2))
    return report['status']!='concrete-blocker'

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('action',choices=['build','products','run']);a=p.parse_args()
    ok=release.build() if a.action=='build' else release.existing.smoke.verify_products() if a.action=='products' else run()
    raise SystemExit(0 if ok else 1)
