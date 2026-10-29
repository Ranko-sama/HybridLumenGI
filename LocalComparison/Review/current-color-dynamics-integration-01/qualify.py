"""Read retained native evidence and source identities without launching Unity."""
import hashlib
import json
import struct
from pathlib import Path

P=Path(__file__).resolve().parent
ROOT=P.parents[2]
PROJECT=Path('I:/Unity test/Project')
load=lambda p:json.loads(p.read_text(encoding='utf-8-sig'))
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
manifest=load(P/'instrumentation/manifest.json')
report=load(P/'native-temporal-report.json')
assert report['passed'] and report['actualTemporalDispatches']==168 and len(report['cases'])==28
assert report['api']=='Direct3D12'
assert report['historyFormat']=='R16G16B16A16_SFloat' and report['momentsFormat']=='R32G32B32A32_SFloat'
assert report['identityFormat']=='R32G32B32A32_UInt'
assert report['kernelsSha256']==sha(ROOT/'Runtime/Resources/HybridLumenGI/HybridLumenGIKernels.hlsl')
checked=0
for row in report['cases']:
    assert row['passed']
    for suffix in ('history','moments'):
        path=P/'reactive-history-limit-raw'/(row['raw']+'-'+suffix+'.rgba32f')
        data=struct.unpack('<1156f',path.read_bytes())
        assert list(data[(8*17+8)*4:(8*17+8)*4+4])==row['center' if suffix=='history' else 'centerMoments']
        if row['name']=='max1-reactive-known':
            expected=(1.03125,1.03125,1.03125,1) if suffix=='history' else (1.03125,1.0634765625,1,0)
            if suffix=='history':
                assert all(tuple(data[i:i+4])==expected for i in range(0,len(data),4))
            else:
                assert all(abs(data[i]-expected[0])<=.000002 and abs(data[i+1]-expected[1])<=.000002
                           and data[i+2]==1 and abs(data[i+3])<=.000002 for i in range(0,len(data),4))
        checked+=1
assert all(sha(ROOT/rel)==value and sha(PROJECT/'Assets/HybridLumenGI'/rel)==value
           for rel,value in manifest['productSourceSha256'].items())
assert load(P/'build-analysis.json')['currentSourceBuildVerified']
assert load(P/'asset-restoration.json')['allRestored']
assert load(P/'instrumentation/restoration.json')['currentProductRestored']
failed=[]
for name in ('native-window','native-batch'):
    result=load(P/name/'run/release-result.json')
    native=load(P/name/'native-exit.json')
    assert result['status']=='failed' and result['actualCameraFrames']==0 and native['exitCode']==1
    failed.append(dict(path=name,error=result['error'],actualCameraFrames=0,exitCode=1))
summary=dict(nativeTemporalPassed=True,nativeDispatches=168,assertionRows=28,rawFilesChecked=checked,
             productSourcesMatched=112,sourceCommit=manifest['baseline'],release70BuildVerified=True,
             release70RenderedRunVerified=False,retainedPlayerFailures=failed,
             fullProductionAccepted=False,
             scope='Actual Unity DX12 texture history contract passed; Release70 built from current source. Two hidden-player routes produced no camera frames and remain failed. No scene-motion or whole-image acceptance.')
(P/'qualification.json').write_text(json.dumps(summary,indent=2)+'\n',encoding='utf-8')
print(json.dumps(summary))
