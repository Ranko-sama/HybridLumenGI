"""Package routing and Cube qualification around the unchanged Release analyzer."""
import argparse, importlib.util, json, sys, traceback
from pathlib import Path

PACKAGE=Path(__file__).resolve().parent
ROOT=PACKAGE.parents[2]
H=ROOT/'LocalComparison/Harness'
BUILD=Path('I:/Unity test/Comparison/Builds/LocalRelease67')
RENDERER='Assets/Comparison/Renderer.asset'
CUBE='Assets/Comparison/CurrentRelease67Environment.asset'


def reuse():
    sys.path.insert(0,str(H))
    spec=importlib.util.spec_from_file_location('release67_analyzer_reuse',H/'analyze-local-release.py')
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
    for item in [module,module.existing,module.existing.smoke]:
        item.PACKAGE=PACKAGE;item.BUILD=BUILD
    return module


def check_cube_build(load):
    receipt=load(PACKAGE/'cube-setup-receipt.json')
    assert receipt['status']=='saved-and-bound','Cube setup did not finish'
    assert receipt['featureAssetPath']==RENDERER and receipt['cubeAssetPath']==CUBE
    assert receipt['featureGuid']=='1346d23e59037cd489d53c8e5b594ba4' and receipt['featureLocalId']==5043623260922118210
    assert receipt['bindingDependencyPresent'] and receipt['allStoredTexelsMatch'] and receipt['linear']
    assert receipt['format']=='RGBAFloat' and (receipt['width'],receipt['height'],receipt['mipCount'])==(2,2,1)
    assert receipt['filterMode']=='Bilinear' and receipt['wrapMode']=='Clamp'
    files=receipt['files'];assert len(files)==4
    assert {item['path'] for item in files}=={RENDERER,RENDERER+'.meta',CUBE,CUBE+'.meta'}
    actual={item['path']:item for item in load(PACKAGE/'build-report.json')['inputs']}
    for item in files:
        assert item['existsAfter'] and item['sha256After']
        assert actual[item['path']]['sha256']==item['sha256After'],'Cube/Renderer build input differs: '+item['path']
        assert actual[item['path']]['bytes']==item['bytesAfter']
    assert load(PACKAGE/'asset-restoration.json')['allRestored'] is True,'Temporary assets not restored'
    return receipt


def check_runtime_environment(load,cube):
    result=load(PACKAGE/'native-window/run/release-result.json')
    expected=dict(environmentCubePresent=True,environmentCubeSupported=True,environmentCubeLinear=True,
        environmentCubeName='CurrentRelease67Environment',environmentCubeFormat='RGBAFloat',
        environmentCubeGraphicsFormat=cube['graphicsFormat'],environmentCubeFilterMode='Bilinear',
        environmentCubeWrapMode='Clamp',environmentCubeWidth=2,environmentCubeHeight=2,environmentCubeMipCount=1)
    for field,value in expected.items():assert result[field]==value,'Runtime Cube field differs: '+field
    assert result['environmentCubeInstanceId']!=0 and result['composition']=='Additive'
    log=(PACKAGE/'native-window/player.log').read_text(encoding='utf-8-sig',errors='replace')
    assert 'Using the constant environment instead' not in log,'Runtime fell back to the constant environment'
    return {field:result[field] for field in [*expected,'environmentCubeInstanceId','composition']}


def main(action):
    module=reuse()
    if action=='products':
        print(module.existing.smoke.verify_products());return 0
    output=PACKAGE/('analysis67-'+action+'.json')
    assert not output.exists(),'Preserve first qualification'
    result=dict(action=action,passed=False,fullProductionAccepted=False)
    try:
        cube=check_cube_build(module.load)
        result['cubeBuildAndRestorationVerified']=True
        if action=='build':
            assert module.build(),'Existing Release build analysis failed'
        else:
            assert module.run(final_image=True),'Existing Final HDR analysis failed'
            result['runtimeEnvironment']=check_runtime_environment(module.load,cube)
        result['passed']=True
    except Exception:
        result['error']=traceback.format_exc()
    output.write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(result,indent=2));return 0 if result['passed'] else 1


if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('action',choices=['build','products','run'])
    raise SystemExit(main(parser.parse_args().action))
