"""Fixed material formula and cross-format capture check; no image oracle."""
import argparse,hashlib,importlib.util,json,math,re,struct,traceback
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];H=ROOT/'LocalComparison/Harness'
PACKAGE=ROOT/'LocalComparison/Review/surface-detail-albedo-01';BUILD=Path('I:/Unity test/Comparison/Builds/SurfaceDetailAlbedo36')
spec=importlib.util.spec_from_file_location('existing',H/'analyze-material-event.py');existing=importlib.util.module_from_spec(spec);spec.loader.exec_module(existing)
existing.PACKAGE=PACKAGE;existing.BUILD=BUILD;existing.smoke.PACKAGE=PACKAGE;existing.smoke.BUILD=BUILD
load=existing.load;save=existing.save;smoke=existing.smoke
def run(linear_authoring=False):
    native=PACKAGE/'native-window';result={'captureVerified':False,'fullProductionAccepted':False,'scope':'Two real source detail variants through original ordinary/native capture; finite color contract only','samples':[],'bounds':{'ordinary':1/255+.0005,'native':.001,'crossMode':1/255+.0015}}
    destination=native/('analysis-linear-authoring.json' if linear_authoring else 'analysis.json')
    assert not destination.exists(),'Preserve every prior analysis result'
    corrected_base=None
    if linear_authoring:
        frozen=load(PACKAGE/'first-evidence-frozen.json')
        assert all(hashlib.sha256((ROOT/p).read_bytes()).hexdigest()==h for p,h in frozen['files'].items()),'Original evidence changed'
        source=(PACKAGE/'instrumentation/prepared/Assets/ComparisonHarness/SurfaceDetailAlbedoMode.cs').read_text()
        # Read the authoring inputs from the executed source, before inspecting outputs.
        def color(pattern):return [float(x.strip().removesuffix('f')) for x in re.search(pattern,source)[1].split(',')][:3]
        authored=color(r'm.SetColor\("_BaseColor",new Color\(([^)]+)\)')
        texture=color(r'var baseMap=Texture\(new Color\(([^)]+)\)')
        assert authored==[.5,.375,.25] and texture==[.5,.75,.25]
        # Pre-existing Material-origin/non-HDR ShaderColor contract. Linear textures
        # and HDR emission stay unchanged. The pinned Core Color.hlsl SRGBToLinear
        # supplies this standard transfer function; no output-derived coefficient.
        linear=[c/12.92 if c<=.04045 else ((c+.055)/1.055)**2.4 for c in authored]
        corrected_base=[a*b for a,b in zip(texture,linear)]
        result['supplement']={'onlyOracleChange':'Convert authored non-HDR Material BaseColor to linear before the unchanged detail formula',
            'authoredBaseColor':authored,'linearBaseColor':linear,'linearBaseTexture':texture,'baseProduct':corrected_base,
            'basis':'Existing HitMaterialLayout.ShaderColor and pinned Core Color.hlsl SRGBToLinear; executed Material.SetColor and RGBAFloat linear=true textures',
            'originalFailurePreserved':True,'originalFailureSha256':frozen['files'][(native/'analysis.json').relative_to(ROOT).as_posix()],
            'originalBoundsUnchanged':True,'newUnityRuns':0,'newBuilds':0,'newGpuRuns':0}
    try:
        result['buildProductsManifestSha256']=smoke.verify_products();result['exit']=load(native/'native-exit.json');result['nativeLogHits']=smoke.hits(native/'player.log')
        paths=list((native/'run').glob('*/run.json'));assert len(paths)==1;folder=paths[0].parent;meta=load(paths[0]);frames=smoke.lines(folder/'frames.jsonl');result['run']=meta;result['runId']=folder.name
        assert meta['api']=='Direct3D12' and meta['renderedFrames']==meta['requestedFrames']==64 and meta['captures']==0
        assert [f['logicalFrame'] for f in frames]==list(range(64))
        receipt=load(folder/'detail-result.json');result['receipt']=receipt
        for frame in [31,63]:
            binding=load(folder/f'binding-{frame}.json');data=(folder/f'probe-{frame}.bin').read_bytes();assert len(data)==128
            assert binding['hardware'] and binding['native']==(frame==63) and binding['mulKeyword'] and binding['scaledKeyword']
            assert binding['engine']==frames[frame]['engineFrame'] and json.loads(frames[frame]['diagnosticsJson'])['hardwareBackend']
            for lane in range(2):
                v=lambda slot:list(struct.unpack_from('<4f',data,lane*64+slot*16))
                marker,diffuse,emission,metadata=v(0),v(1),v(2),v(3)
                base=corrected_base if linear_authoring else [.25,.28125,.0625];detail=[.75,.25,.625];factor=[2*d if lane==0 else 2*d*.5-.5+1 for d in detail]
                expected=[b*(1+.75*(f-1))*.96 for b,f in zip(base,factor)];bound=result['bounds']['native' if frame==63 else 'ordinary']
                sample={'frame':frame,'lane':lane,'marker':marker,'diffuse':diffuse,'emission':emission,'metadata':metadata,'expected':expected,'bound':bound};result['samples'].append(sample)
                sample['checks']={'invocation':marker==[12345,1,int(frame==63),lane],
                    'detailColor':all(math.isfinite(d) and abs(d-e)<=bound for d,e in zip(diffuse[:3],expected)),
                    'ao':diffuse[3]==metadata[2]==1,'validity':metadata[3]==1 and emission[3]==(2 if frame==63 else 1),
                    'emission':emission[:3]==[.125,.25,.5]}
                assert all(sample['checks'].values()),f'First capture mismatch at frame{frame}/lane{lane}'
        for lane in range(2):
            ordinary=result['samples'][lane]['diffuse'];nativeValue=result['samples'][lane+2]['diffuse']
            assert max(abs(a-b) for a,b in zip(ordinary[:3],nativeValue[:3]))<=result['bounds']['crossMode'],'Cross-format detail mismatch'
        assert result['exit']['exitCode']==0 and not result['exit']['watchdogTerminated'] and not result['nativeLogHits'] and meta['errors']==0
        assert receipt['completed']==2 and receipt['receipts']==64 and receipt['pending']==0 and not receipt.get('failure')
        result['captureVerified']=True
    except Exception as e:result.update(failure=str(e),traceback=traceback.format_exc())
    if linear_authoring:
        assert all(hashlib.sha256((ROOT/p).read_bytes()).hexdigest()==h for p,h in frozen['files'].items()),'Original evidence changed during interpretation'
    save(destination,result);print(json.dumps(result));return result['captureVerified']
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('action',choices=['build','products','run','reinterpret']);a=p.parse_args()
    ok=existing.build() if a.action=='build' else smoke.verify_products() if a.action=='products' else run(a.action=='reinterpret');raise SystemExit(0 if ok else 1)
