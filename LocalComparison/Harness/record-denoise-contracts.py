"""Archive the finite GPU package and derive diagnostics from actual readbacks."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import numpy as np

root = Path(__file__).resolve().parents[2]
source = Path('I:/Unity test/Comparison/Evidence/local-denoise-02')
output = root/'LocalComparison/Review/denoise-02'
load = lambda p: json.loads(p.read_text(encoding='utf-8-sig'))
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
report = load(source/'gpu-contracts.json')
assert report['passed'], report['error']
assert all(r['passed'] for r in report['cases'])
for name in ['gpu-contracts.json', 'legacy-regression.json']:
    shutil.copy2(source/name, output/name)
shutil.copy2(source/'actual-formats.csv', output/'actual-formats.csv')
for kernel in ['CSTemporal', 'CSTemporalIdentity']:
    for channel in ['output', 'moments']:
        a=np.fromfile(source/'raw-contracts'/f'{kernel}-unknown-center-1-temporal-{channel}.rgba32f',dtype='<f4').reshape(17,17,4)
        assert np.all(a[8,8]==0), (kernel,channel)
for name in ['baseline', 'raw-contracts']:
    shutil.copytree(source/name, output/name, dirs_exist_ok=True)
for stem in ['Denoise02-baseline-retry', 'Denoise02-contracts-final', 'Denoise02-formats']:
    shutil.copy2(Path('I:/Unity test/Logs')/(stem+'.log'), output/(stem+'.log'))
product = []
for item in load(root/'Tests/runtime-validation-results.json')['productSources']:
    path = item['file']
    digest = sha(root/path)
    assert digest == sha(Path('I:/Unity test/Project/Assets/HybridLumenGI')/path), path
    product.append({'file':path,'sha256':digest})
patch = subprocess.run(['git','diff','--','Runtime','Tests/StandaloneScreenBudget/Program.cs.txt','Documentation/ValidationSequence.md'], cwd=root,check=True,capture_output=True).stdout
(output/'product.patch').write_bytes(patch)
diagnostics = {}
baseline_values=[]
for frame in range(1,6):
    h=np.fromfile(source/'baseline'/f'frame-{frame}-history.rgba32f',dtype='<f4').reshape(17,17,4)
    m=np.fromfile(source/'baseline'/f'frame-{frame}-moments.rgba32f',dtype='<f4').reshape(17,17,4)
    baseline_values.append({'frame':frame,'allFinite':bool(np.isfinite(h).all() and np.isfinite(m).all()),
        'radianceMin':float(h[:,:,:3].min()),'radianceMax':float(h[:,:,:3].max()),
        'secondMomentMin':float(m[:,:,1].min()),'secondMomentMax':float(m[:,:,1].max()),
        'historyMin':float(m[:,:,2].min()),'historyMax':float(m[:,:,2].max()),'expectedSecondMoment':1000000})
for kernel in ['CSTemporal','CSTemporalIdentity']:
    diagnostics[kernel] = {}
    for boundary in ['noise','coplanar-edge','parallel-plane','material-edge','normal-edge']:
        values = []
        for frame in range(1,6):
            rows = [r for r in report['cases'] if r['kernel']==kernel and r['name']==boundary and r['frame']==frame]
            data = {}
            for row in rows:
                a=np.fromfile(source/'raw-contracts'/(row['rawOutput']+'-output.rgba32f'),dtype='<f4').reshape(17,17,4)
                m=np.fromfile(source/'raw-contracts'/(row['rawOutput']+'-moments.rgba32f'),dtype='<f4').reshape(17,17,4)
                assert np.isfinite(a).all() and np.isfinite(m).all()
                # This center window is inside the full 1+2+4 support. x=8 is
                # the last dark-side sample; x=9 starts the synthetic boundary.
                roi=a[7:10,7:9,0].astype('float64')
                data[row['stage']]={'center':row['center'][0], 'darkWindowMean':float(roi.mean()),
                    'darkWindowResidualRms':float(np.sqrt(np.mean((roi-roi.mean())**2))),
                    'history':row['centerMoments'][2], 'temporalVariance':row['temporalVariance'],
                    'spatialVariance':row['spatialVariance'], 'sigma':row['effectiveSigma']}
            data['darkWindowFilterIncrement']=data['filter-4']['darkWindowMean']-data['temporal']['darkWindowMean']
            values.append(data)
        diagnostics[kernel][boundary]={'frames1to5':values,
            'centerFilterChange3to4':values[3]['filter-4']['center']-values[2]['filter-4']['center']}
summary={'revision':'local-development-denoise-02-contracts','baselineCommit':'7d33d02',
    'contractRows':len(report['cases']), 'legacyCases':len(load(source/'legacy-regression.json')['cases']),
    'baselineActualReadbacks':baseline_values,
    'harnessSource':{'file':'LocalComparison/Harness/DenoiseRegressionEditor.cs','sha256':sha(root/'LocalComparison/Harness/DenoiseRegressionEditor.cs'),
        'note':'Final source compiled by VerifyFormats. After277-stage run only explicit zero assertion (also checked against saved data) and allocation-only format probe were added.'},
    'sigmaMeaning':'CPU-derived from actual stored center moments, not separately read from GPU',
    'allPassed':report['passed'],'actualRuntime':{k:report[k] for k in ['unity','gpu','api']},
    'baselineObservation':'DX12 half UAV stores L=1000 but saturates E[L^2]=1000000 to65504. No nonfinite output or history rejection observed in this five-frame baseline.',
    'budget':'ScreenBudget PASS: 11381 plans,95211 assertions. +16 bytes/GI pixel;640x360 full/320x180 GI at128MiB unchanged; +921600 bytes.',
    'runtimeProductSources':product,'productPatchSha256':sha(output/'product.patch'),
    'diagnostics':diagnostics,'sceneRerun':False,
    'limits':['Synthetic filter discontinuities are not real-scene flicker or physical-reference acceptance.',
              'No full Player/DXR/long-run/GPU-time/VRAM certification. The previous runs remain historical.',
              'The first baseline fixture failed because ordinary Texture2D UInt Sample usage is unsupported; fixed with UInt RenderTexture and input-only compute upload. Failure log retained.',
              'A second bounded run added missing legacy full-texture finite checks, both-kernel black/unknown filter checks, Final composite readback and raw readback retention.']}
(output/'validation.json').write_text(json.dumps(summary,indent=2),encoding='utf-8')
print(json.dumps({'rows':summary['contractRows'],'legacyCases':summary['legacyCases'],'allPassed':True,
    'R2':{k:v['noise']['centerFilterChange3to4'] for k,v in diagnostics.items()},
    'parallelPlaneDarkWindowChangeNotCausalLeakMeasure':{k:v['parallel-plane']['frames1to5'][0]['darkWindowFilterIncrement'] for k,v in diagnostics.items()},
    'syncedProductSources':len(product)},indent=2))
