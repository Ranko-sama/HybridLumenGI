"""Reuse build identity/Cube checks; inspect the unique finite example result and original images."""
import importlib.util,json,math,struct,sys,traceback
from pathlib import Path
P=Path(__file__).resolve().parent;ROOT=P.parents[2];BUILD=Path('I:/Unity test/Comparison/Builds/LocalRelease69')
spec=importlib.util.spec_from_file_location('analysis67reuse',P.parent/'current-local-release-67/analyze67.py')
base=importlib.util.module_from_spec(spec);spec.loader.exec_module(base);base.PACKAGE=P;base.BUILD=BUILD
m=base.reuse();load=m.load

def main(action):
    if action=='products':print(m.existing.smoke.verify_products());return 0
    dest=P/('analysis69-'+action+'.json');assert not dest.exists(),'Preserve first analysis'
    r=dict(passed=False,fullProductionAccepted=False,perRayGpuConsumptionProven=False)
    try:
        base.check_cube_build(load)
        if action=='build':assert m.build(),'Existing build qualification failed'
        else:
            r['products']=m.existing.smoke.verify_products();n=P/'native-window';run=n/'run'
            e=load(n/'native-exit.json');v=load(run/'continuous-result.json');hits=m.existing.smoke.hits(n/'player.log')
            r.update(native=e,runtime=v,nativeLogHits=hits)
            assert e['exitCode']==0 and not e['watchdogTerminated'] and not hits,'Native failure'
            assert v['status']=='collected' and v['actualCameraFrames']==v['requestedFrames']==256 and v['captures']==2 and v['errors']==0
            assert v['normalQuitObserved'] and v['sourceClosed'] and v['testCaptureDisabled'] and v['auditProbeDisabled'] and not v['debugBuild']
            assert v['api']=='Direct3D12' and v['view']=='Final' and v['composition']=='Additive' and v['environmentCubeName']=='CurrentRelease67Environment'
            assert v['lastEngine']-v['firstEngine']==255
            check=load(run/'check-result.json')
            assert check['status']=='passed' and check['observations']==256 and check['motionPublications']>=2 and check['differingMotionContents'] and check['finalAgrees']
            assert check['finalProducerError']<=2e-6 and check['finalReferenceError']<=2e-6
            r['sourceCheck']={key:check[key] for key in ['status','snapshotChanges','motionPublications','differingMotionContents','finalPublishedFrame','finalProducerError','finalReferenceError','scope']}
            assert 'Using the constant environment instead' not in (n/'player.log').read_text(encoding='utf-8-sig',errors='replace')
            r['images']=[]
            for frame in [159,255]:
                f=load(run/f'frame-{frame:04}.json');assert f['captured'] and f['logicalFrame']==frame and f['engineFrame']==v['firstEngine']+frame
                raw=(run/f['raw']).read_bytes();assert len(raw)==640*360*16 and all(math.isfinite(x[0]) for x in struct.iter_unpack('<f',raw))
                png=(run/f['png']).read_bytes();assert png[:8]==b'\x89PNG\r\n\x1a\n' and struct.unpack('>II',png[16:24])==(640,360)
                assert struct.unpack('<I',(run/f['exr']).read_bytes()[:4])[0]==20000630
                r['images'].append(dict(logical=frame,stage=f['stage'],files={f[k]:m.existing.sha(run/f[k]) for k in ['raw','png','exr']}))
            r['visualAssessment']='Actual PNG viewing required separately; images do not establish dynamic GI truth'
        r['passed']=True
    except Exception:r['error']=traceback.format_exc()
    dest.write_text(json.dumps(r,indent=2)+'\n',encoding='utf-8');print(json.dumps(r,indent=2));return 0 if r['passed'] else 1

if __name__=='__main__':
    action=sys.argv[1];assert action in ['build','products','run'];raise SystemExit(main(action))
