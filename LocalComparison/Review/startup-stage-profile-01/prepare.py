"""One first-render diagnosis, using the existing Release71 scene/build wiring."""
import importlib.util
import json
import sys
from pathlib import Path

P = Path(__file__).resolve().parent
ROOT = P.parents[2]
OUT = P / 'instrumentation'
BUILD = Path('I:/Unity test/Comparison/Builds/StartupStageProbe01')
PROJECT = Path('I:/Unity test/Project')


def module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


release = module('startup_release71', P.parent / 'current-local-release-71/prepare.py')
release.P, release.OUT, release.BUILD = P, OUT, BUILD
release.base.P, release.base.OUT, release.base.BUILD = P, OUT, BUILD
for installer in (release.base.base, release.base.base.base):
    installer.PACKAGE, installer.OUT = P, OUT
sha, load, save = release.sha, release.load, release.save


def replace_once(data, old, new):
    assert data.count(old) == 1, old
    return data.replace(old, new)


def prepare_base():
    assert not (P / 'source').exists() and not OUT.exists()
    prior = P.parent / 'current-local-release-71/source/LocalReleaseBootstrap.cs'
    source = prior.read_text(encoding='utf-8')
    source = replace_once(source, 'mode="ordinary-local-release"', 'mode="startup-stage-profile-01"')
    source = replace_once(source, 'requestedFrames=verify&&!steady?120:0', 'requestedFrames=verify&&!steady?12:0')
    source = replace_once(source, 'frames==1||frames==60||frames==120', 'frames==1||frames==12')
    source = replace_once(source, 'if(steady?elapsed>=60:frames>=60)', 'if(steady?elapsed>=60:frames>=12)')
    source = replace_once(source, 'if(steady?elapsed>=300:frames==120)', 'if(steady?elapsed>=300:frames==12)')
    source = replace_once(source,
        'if(quitPending){finalCapture.CaptureSingleFinalFrame(frames);result.finalImageCaptured=true;}',
        '// This CPU startup diagnosis does not issue an HDR readback.')
    source = replace_once(source,
        'if(finalImage&&!explicitRequest){finalCapture.CaptureSingleFinalFrame(frames);result.finalImageCaptured=true;}',
        '// Final HDR target is unchanged; no image is read back in this diagnosis.')
    source = replace_once(source,
        'complete&&(steady?result.elapsedSeconds>=300:frames==120)&&errors==0&&(!finalImage||result.finalImageCaptured)',
        'complete&&(steady?result.elapsedSeconds>=300:frames==12)&&errors==0')
    source = replace_once(source,
        'Final linear HDR camera target from startup; not ordinary backbuffer pixels. Existing fixed-mapping PNG is preview only.',
        'Unchanged Release71 linear HDR render target; this diagnostic performs no image readback.')
    (P / 'source').mkdir()
    (P / 'source/LocalReleaseBootstrap.cs').write_text(source, encoding='utf-8')
    save(P / 'source-origin.json', dict(source=str(prior), sha256=sha(prior),
        derivedSha256=sha(P / 'source/LocalReleaseBootstrap.cs'), requestedFrames=12,
        imageReadback=False, productionShaderChanges=False))
    release.prepare()
    manifest = load(OUT / 'manifest.json')
    manifest['scope'] = 'Release71 scene/settings/shaders; CPU-only first-render stage diagnosis; 12 explicit requests; no image readback'
    manifest['hostBeforeObserverSha256'] = sha(P / 'source/LocalReleaseBootstrap.cs')
    save(OUT / 'manifest.json', manifest)


def prepare_observer():
    assert not (P / 'observer-preparation.json').exists()
    patcher_path = ROOT / 'LocalComparison/Harness/prepare-startup-stage-probe.py'
    patcher = module('startup_cpu_patcher', patcher_path)
    manifest = load(OUT / 'manifest.json')
    assert len(manifest['files']) == 8
    save(OUT / 'base-manifest.json', manifest)
    host = next(row for row in manifest['files'] if row['path'].endswith('/LocalReleaseBootstrap.cs'))
    path = OUT / host['prepared']
    assert sha(path) == host['sha256']
    path.write_bytes(patcher.patch_host(path.read_bytes()))
    host['sha256'] = sha(path)
    feature = ROOT / 'Runtime/HybridLumenGIRendererFeature.cs'
    inputs = [(patcher.FEATURE_REL, patcher.patch_feature(feature.read_bytes())),
              (patcher.PROBE_REL, patcher.PROBE_SOURCE.read_bytes())]
    for relative, data in inputs:
        target = PROJECT / relative
        original = 'cpu-feature.original' if target.exists() else None
        original_sha = sha(target) if target.exists() else None
        if original is not None:
            assert relative == patcher.FEATURE_REL and original_sha == sha(feature)
            (OUT / original).write_bytes(target.read_bytes())
        else:
            assert relative == patcher.PROBE_REL and not Path(str(target) + '.meta').exists()
        staged = OUT / 'prepared' / relative
        staged.parent.mkdir(parents=True, exist_ok=True)
        staged.write_bytes(data)
        manifest['files'].append(dict(path=relative, original=original, originalSha256=original_sha,
            prepared=staged.relative_to(OUT).as_posix(), sha256=sha(staged)))
        if not Path(str(target) + '.meta').exists():
            manifest['newMetadata'].append(relative + '.meta')
    manifest['temporaryProductChanges'] = [patcher.FEATURE_REL]
    manifest['observerSourceSha256'] = {str(p.resolve()): sha(p) for p in
        (patcher_path, patcher.PROBE_SOURCE, feature, P / 'source/LocalReleaseBootstrap.cs',
         P / 'contract.md', P / 'prepare.py', P / 'build.ps1', P / 'analyze.py',
         P / 'run.ps1', P / 'qualify_run.py')}
    manifest['unchangedShaderSha256'] = patcher.shader_pins(PROJECT)
    save(OUT / 'manifest.json', manifest)
    save(P / 'observer-preparation.json', dict(stagedFiles=len(manifest['files']),
        purePatchFunctions=True, unchangedShaderFiles=len(manifest['unchangedShaderSha256']),
        manifestSha256=sha(OUT / 'manifest.json'), sourceSha256=manifest['observerSourceSha256']))
    print(json.dumps(dict(stagedFiles=len(manifest['files']), shaderChanges=0, cpuObserver=True)))


def verify_prepared():
    receipt = load(P / 'observer-preparation.json')
    assert receipt['manifestSha256'] == sha(OUT / 'manifest.json')
    assert all(sha(Path(k)) == v for k, v in receipt['sourceSha256'].items())
    m = load(OUT / 'manifest.json')
    assert all(sha(ROOT / k) == sha(PROJECT / 'Assets/HybridLumenGI' / k) == v
               for k, v in m['productSourceSha256'].items())
    assert all(sha(OUT / row['prepared']) == row['sha256'] for row in m['files'])


if __name__ == '__main__':
    action = sys.argv[1]
    if action == 'prepare-base':
        prepare_base()
    elif action == 'prepare-observer':
        prepare_observer()
    elif action in ('install', 'restore'):
        if action == 'install':
            verify_prepared()
        getattr(release.base, action)()
    elif action == 'preflight':
        verify_prepared()
        release.preflight()
    else:
        raise ValueError(action)
