"""Finite capture/consumption oracle; reuse existing build/product/log checks."""
import argparse,importlib.util,json,math,struct,traceback
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];H=ROOT/'LocalComparison/Harness';PACKAGE=ROOT/'LocalComparison/Review/screen-receive-shadows-01';BUILD=Path('I:/Unity test/Comparison/Builds/ScreenReceiveShadows32')
spec=importlib.util.spec_from_file_location('existing',H/'analyze-material-event.py');existing=importlib.util.module_from_spec(spec);spec.loader.exec_module(existing)
existing.PACKAGE=PACKAGE;existing.BUILD=BUILD;existing.smoke.PACKAGE=PACKAGE;existing.smoke.BUILD=BUILD
load=existing.load;save=existing.save;smoke=existing.smoke
def run():
    native=PACKAGE/'native-window';result={'captureConsumptionVerified':False,'fullProductionAccepted':False,'scope':'Two source keywords, both capture entries, deterministic actual screen transport; no full material/image/performance acceptance','samples':[]}
    try:
        result['buildProductsManifestSha256']=smoke.verify_products();result['exit']=load(native/'native-exit.json');result['nativeLogHits']=smoke.hits(native/'player.log')
        candidates=list((native/'run').glob('*/run.json'));assert len(candidates)==1;folder=candidates[0].parent;run=load(candidates[0]);frames=smoke.lines(folder/'frames.jsonl')
        result['run']=run
        assert run['api']=='Direct3D12' and run['renderedFrames']==run['requestedFrames']==64 and run['captures']==0
        assert [f['logicalFrame'] for f in frames]==list(range(64));result['runId']=folder.name
        receipt=load(folder/'shadow-result.json');result['receipt']=receipt;result['missingFrames']=[]
        for frame in [31,63]:
            if not (folder/f'binding-{frame}.json').exists() or not (folder/f'probe-{frame}.bin').exists():
                result['missingFrames'].append(frame);continue
            binding=load(folder/f'binding-{frame}.json');data=(folder/f'probe-{frame}.bin').read_bytes();assert len(data)==512
            assert binding['hardware'] and binding['native']==(frame==63) and not binding['onKeyword'] and binding['offKeyword']
            assert binding['engine']==frames[frame]['engineFrame'];diag=json.loads(frames[frame]['diagnosticsJson']);assert diag['hardwareBackend']
            for lane in range(2):
                offset=lane*256;v=lambda slot:list(struct.unpack_from('<4f',data,offset+slot*16));u=lambda slot:list(struct.unpack_from('<4I',data,offset+slot*16))
                marker,emission,diffuse,direct,unshadowed,policy,ao,radiance,hit=v(0),v(1),v(2),v(3),v(4),u(5),v(6),v(7),v(8)
                sample=dict(frame=frame,lane=lane,marker=marker,emission=emission,diffuse=diffuse,direct=direct,unshadowed=unshadowed,policy=policy,ao=ao,radiance=radiance,hit=hit,position=v(9),normal=v(10));result['samples'].append(sample)
                expected_alpha=(2 if frame==63 else 1)*(1 if lane==0 else -1)
                checks={'invocation':marker==[12345,1,int(frame==63),lane],'screenHit':radiance[3]==hit[0]==1,
                    'captureKeyword':emission[3]==expected_alpha,'emission':emission[:3]==[0,1,0],
                    'validityPolicy':policy==[1,1,1,1-lane],'materialAO':ao[0]==1 and diffuse[3]==1,
                    'knownDirect':direct[3]==unshadowed[3]==1,'incidentLight':all(math.isfinite(x) and x>0 for x in unshadowed[:3]),
                    'shadowRule':direct[:3]==([0,0,0] if lane==0 else unshadowed[:3]),
                    'consumption':all(abs(radiance[i]-(emission[i]+diffuse[i]*direct[i]))<1e-6 for i in range(3))}
                sample['checks']=checks
        result['partialSamplesVerified']=bool(result['samples']) and all(all(s['checks'].values()) for s in result['samples'])
        assert result['exit']['exitCode']==0 and not result['exit']['watchdogTerminated'] and not result['nativeLogHits'] and run['errors']==0,'Native run failed; partial rows are evidence only'
        assert receipt['completed']==2 and receipt['receipts']==64 and receipt['pending']==0 and not receipt.get('failure') and not result['missingFrames'],'Both capture entries required'
        result['captureConsumptionVerified']=len(result['samples'])==4 and result['partialSamplesVerified'];assert result['captureConsumptionVerified'],'Capture or actual direct consumption mismatch'
    except Exception as e:result.update(failure=str(e),traceback=traceback.format_exc())
    save(native/'analysis.json',result);print(json.dumps(result));return result['captureConsumptionVerified']
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('action',choices=['build','products','run']);a=p.parse_args()
    ok=existing.build() if a.action=='build' else smoke.verify_products() if a.action=='products' else run();raise SystemExit(0 if ok else 1)
