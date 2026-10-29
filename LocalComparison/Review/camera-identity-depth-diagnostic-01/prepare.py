"""Stage a temporary identity-depth observer; existing camera protocol is reused."""
import hashlib
import importlib.util
import json
from pathlib import Path
import sys

P=Path(__file__).resolve().parent
ROOT=P.parents[2]
BASE=P.parent/'camera-motion-taa-response-02'
PROJECT=Path('I:/Unity test/Project')
OWNED=PROJECT/'Assets/CameraMotionTaa01'
OUT=P/'instrumentation'
HARNESS=ROOT/'LocalComparison/Harness'
HELPER=HARNESS/'prepare-camera-identity-depth-diagnostic.py'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
load=lambda p:json.loads(p.read_text(encoding='utf-8-sig'))


def save(path,value):
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text(json.dumps(value,indent=2)+'\n',encoding='utf-8')


def patcher():
    spec=importlib.util.spec_from_file_location('identity_depth_patch',HELPER)
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
    return module


def prepare():
    assert not OUT.exists() and not OWNED.exists() and not Path(str(OWNED)+'.meta').exists()
    base=load(BASE/'instrumentation/manifest.json')
    current={p.relative_to(ROOT).as_posix():sha(p) for top in ('Runtime','Editor')
             for p in (ROOT/top).rglob('*') if p.is_file() and p.suffix!='.meta'}
    assert current==base['productSourceSha256'],'Product changed since the failed camera capture'
    assert all(sha(PROJECT/'Assets/HybridLumenGI'/rel)==digest for rel,digest in current.items())
    helper=patcher();items=[];unchanged=[];originals={}
    for row in base['files']:
        source=BASE/'instrumentation'/row['prepared'];assert sha(source)==row['sha256']
        data=source.read_bytes();originals[source.relative_to(ROOT).as_posix()]=sha(source)
        if row['path'].endswith('/HybridLumenGIRendererFeature.cs'):data=helper.patch_feature(data)
        elif row['path'].endswith('/CameraMotionTaaScene.cs'):data=helper.patch_host(data)
        else:unchanged.append(row['path'])
        items.append((row['path'],data,source.relative_to(ROOT).as_posix()))
    for name,patch in [('Runtime/HybridLumenGIReceiverIdentityPass.cs',helper.patch_pass),
                       ('Runtime/Resources/HybridLumenGI/HybridLumenGIReceiverIdentity.shader',helper.patch_shader)]:
        items.append(('Assets/HybridLumenGI/'+name,patch((ROOT/name).read_bytes()),name))
    harness_sources={}
    for name in ('CameraIdentityDepthDiagnosticTap.cs','CameraIdentityDepthDiagnostic.hlsl'):
        source=HARNESS/name;items.append(('Assets/CameraMotionTaa01/'+name,source.read_bytes(),source.relative_to(ROOT).as_posix()))
        harness_sources[source.relative_to(ROOT).as_posix()]=sha(source)
    harness_sources[HELPER.relative_to(ROOT).as_posix()]=sha(HELPER)
    assert len(items)==13 and len(unchanged)==7
    rows=[]
    for relative,data,source in items:
        target=PROJECT/relative;original='original/'+relative if target.exists() else None
        if original:
            backup=OUT/original;backup.parent.mkdir(parents=True,exist_ok=True);backup.write_bytes(target.read_bytes())
        staged=OUT/'prepared'/relative;staged.parent.mkdir(parents=True,exist_ok=True);staged.write_bytes(data)
        rows.append(dict(path=relative,source=source,original=original,originalSha256=sha(target) if target.exists() else None,
                         prepared='prepared/'+relative,sha256=sha(staged)))
    save(OUT/'manifest.json',dict(productSourceSha256=current,files=rows,newMetadata=[],excluded=[],
        scope='Unchanged 48-frame camera/TAA scene and protocol; diagnostic pixel-UAV side channel at fixed logical36..43; not a performance or acceptance rerun'))
    save(OUT/'reuse-source.json',dict(originalManifestSha256=sha(BASE/'instrumentation/manifest.json'),sources=originals,
         unchangedPreparedFiles=unchanged,unchangedComputeEntries=18,originalCompileReportSha256=sha(BASE/'compile/report.json')))
    save(OUT/'harness-source.json',harness_sources)
    protected=[]
    for rel in ('ProjectSettings/QualitySettings.asset','ProjectSettings/GraphicsSettings.asset','Assets/RuntimeAudit/Functional.unity'):
        target=PROJECT/rel;backup=OUT/'protected'/rel;backup.parent.mkdir(parents=True,exist_ok=True);backup.write_bytes(target.read_bytes())
        protected.append(dict(path=rel,sha256=sha(target),backup='protected/'+rel))
    save(OUT/'protected.json',protected)
    urp=load(BASE/'instrumentation/urp-source.json')
    assert all(sha(Path(path))==digest for path,digest in urp.items())
    save(OUT/'urp-source.json',urp)
    print(json.dumps(dict(stagedFiles=13,unchangedPreparedFiles=7,productFiles=len(current),newProbeFrames=8,
                         executeMethod='CameraMotionTaaEditor.Run',outputArgument='-cameraMotionTaaOutput')))


def freeze():
    # Called only after all owners finish their prospective code/contracts.
    assert not (P/'source-freeze.json').exists()
    required=('analyze.py','test_analyze.py','input-model.txt','run.ps1','run-environment.json','verify_execution.py','compile_probe.py','compile_probe_dxc.py','compile_probe_codegen.py')
    assert all((P/name).is_file() for name in required),'Wait for all independent source owners'
    source_paths=[p for p in P.iterdir() if p.is_file() and p.suffix in ('.py','.txt','.json','.ps1','.md')]
    source_paths += [ROOT/name for name in load(OUT/'harness-source.json')]
    source_paths += [BASE/'qualification-ties/model.py',BASE/'qualification-ties/analyze.py']
    source_paths += [BASE/'target-input-qualification/audit.py',BASE/'initialization-source-qualification/audit.py']
    source_paths += [P.parent/'current-local-release-67/preflight67.py',P.parent/'static-hdr-environment-cubemap-01/prepare.py']
    source_paths += [ROOT/'Tests/Validate-ReceiverIdentityShaders.ps1']
    source_paths += [ROOT/'LocalComparison/Reference/ColorBounceRectangle'/name for name in
                     ('qualify_native_inputs.py','decode_sampler.py','generate_sampler.py')]
    sources={p.relative_to(ROOT).as_posix():sha(p) for p in source_paths}
    save(OUT/'analysis-source.json',sources)
    evidence={p.relative_to(ROOT).as_posix():sha(p) for p in
              (OUT/'manifest.json',OUT/'reuse-source.json',OUT/'harness-source.json',OUT/'analysis-source.json',OUT/'protected.json',OUT/'urp-source.json',
               P/'preflight/exit.json',P/'preflight/identity.json',P/'preflight/commands.json',P/'compile-probe/report.json',P/'compile-probe-02/report.json',
               P/'compile-probe-02/include-sources.json',P/'compile-probe-03/report.json',BASE/'compile/report.json')}
    assert load(P/'preflight/exit.json')['exitCode']==0
    assert load(P/'compile-probe/report.json')['passed'] is False and load(P/'compile-probe-02/report.json')['passed'] is False
    assert load(P/'compile-probe-03/report.json')['passed'] is True
    # The corrected compile pins installed headers as well as the local mirror;
    # carry those exact sources and compiler include/dependency traces into the
    # pre-native freeze instead of trusting an unbound "passed" field.
    for attempt in ('compile-probe','compile-probe-02','compile-probe-03'):
        for path,digest in load(P/attempt/'report.json')['sources'].items():
            source=Path(path).resolve();assert sha(source)==digest
            key=source.relative_to(ROOT).as_posix() if source.is_relative_to(ROOT) else source.as_posix()
            evidence[key]=digest
        for source in (P/attempt).iterdir():
            if source.is_file():evidence[source.relative_to(ROOT).as_posix()]=sha(source)
    save(P/'source-freeze.json',dict(schema='camera-identity-depth-diagnostic-v1',sources=sources,evidence=evidence))
    print(json.dumps(dict(sourceFiles=len(sources),sourceFreezeSha256=sha(P/'source-freeze.json'))))


def install():
    assert not OWNED.exists() and not Path(str(OWNED)+'.meta').exists() and not (OUT/'installed.json').exists()
    frozen=load(P/'source-freeze.json')
    for mapping in ('sources','evidence'):
        for rel,digest in frozen[mapping].items():assert sha(ROOT/rel)==digest,rel
    for path,digest in load(OUT/'urp-source.json').items():assert sha(Path(path))==digest,path
    manifest=load(OUT/'manifest.json')
    for rel,digest in manifest['productSourceSha256'].items():assert sha(PROJECT/'Assets/HybridLumenGI'/rel)==sha(ROOT/rel)==digest,rel
    for row in load(OUT/'protected.json'):
        assert sha(PROJECT/row['path'])==row['sha256'],row['path']
        assert sha(OUT/row['backup'])==row['sha256'],row['backup']
    for row in manifest['files']:
        target=PROJECT/row['path'];assert (sha(target) if target.exists() else None)==row['originalSha256']
        assert sha(OUT/row['prepared'])==row['sha256']
    save(OUT/'installed.json',dict(installed=True,sourceFreezeSha256=sha(P/'source-freeze.json')))
    for row in manifest['files']:
        target=PROJECT/row['path'];target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes((OUT/row['prepared']).read_bytes())


def restore():
    manifest=load(OUT/'manifest.json');archive=OUT/'post-run'
    owned=OWNED.resolve();assert owned==Path('I:/Unity test/Project/Assets/CameraMotionTaa01').resolve()
    # Validate the whole recovery set before deleting or overwriting anything.
    # A failed or partial installation may leave a mixture of original/staged.
    for row in manifest['files']:
        target=PROJECT/row['path']
        if row['original']:
            backup=OUT/row['original'];assert sha(backup)==row['originalSha256']
            assert target.is_file() and sha(target) in (row['originalSha256'],row['sha256']),row['path']
        elif target.exists():
            assert target.is_file() and sha(target)==row['sha256'],row['path']
    for row in load(OUT/'protected.json'):
        assert sha(OUT/row['backup'])==row['sha256']
        assert (PROJECT/row['path']).is_file()
        assert sha(PROJECT/row['path'])==row['sha256'] or row['path']=='ProjectSettings/QualitySettings.asset','Unexpected protected source change'
    if owned.exists():
        for path in owned.rglob('*'):
            if path.is_file():
                destination=archive/path.relative_to(PROJECT);destination.parent.mkdir(parents=True,exist_ok=True);destination.write_bytes(path.read_bytes())
        for path in sorted(owned.rglob('*'),key=lambda p:len(p.parts),reverse=True):
            if path.is_file():path.unlink()
            elif path.is_dir():path.rmdir()
        owned.rmdir()
    metadata=Path(str(owned)+'.meta')
    if metadata.exists():
        destination=archive/metadata.relative_to(PROJECT);destination.parent.mkdir(parents=True,exist_ok=True);destination.write_bytes(metadata.read_bytes());metadata.unlink()
    for row in manifest['files']:
        if row['original']:
            backup=OUT/row['original'];assert sha(backup)==row['originalSha256']
            target=PROJECT/row['path']
            if sha(target)==row['sha256']:
                destination=archive/row['path'];destination.parent.mkdir(parents=True,exist_ok=True);destination.write_bytes(target.read_bytes())
                target.write_bytes(backup.read_bytes())
    matched=all(sha(PROJECT/'Assets/HybridLumenGI'/rel)==digest for rel,digest in manifest['productSourceSha256'].items())
    protected=[]
    for row in load(OUT/'protected.json'):
        target=PROJECT/row['path'];unchanged=sha(target)==row['sha256']
        if not unchanged:
            assert row['path']=='ProjectSettings/QualitySettings.asset','Unexpected protected source change'
            destination=archive/row['path'];destination.parent.mkdir(parents=True,exist_ok=True);destination.write_bytes(target.read_bytes())
            backup=OUT/row['backup'];assert sha(backup)==row['sha256'];target.write_bytes(backup.read_bytes())
        protected.append(dict(path=row['path'],unchanged=unchanged,restored=sha(target)==row['sha256']))
    save(OUT/'restoration.json',dict(currentProductRestored=matched,ownedRootRemoved=not owned.exists(),protected=protected))
    assert matched and not owned.exists() and all(row['restored'] for row in protected)


def preflight():
    path=P.parent/'current-local-release-67/preflight67.py'
    spec=importlib.util.spec_from_file_location('identity_depth_managed',path)
    check=importlib.util.module_from_spec(spec);spec.loader.exec_module(check)
    check.PACKAGE=P;check.STAGE=OUT;check.DEST=P/'preflight';check.main()


if __name__=='__main__':
    action=sys.argv[1] if len(sys.argv)>1 else 'prepare'
    assert action in ('prepare','preflight','freeze','install','restore')
    globals()[action]()
