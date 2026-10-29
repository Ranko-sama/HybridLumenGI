"""Pure, guarded C# patches plus an optional reversible three-file overlay.

No Unity invocation. No shader mutation. Parent packages may directly use
patch_feature(bytes), patch_host(bytes), and PROBE_REL in their own manifest.
"""
import argparse
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
FEATURE_REL = 'Assets/HybridLumenGI/Runtime/HybridLumenGIRendererFeature.cs'
PROBE_REL = 'Assets/HybridLumenGI/Runtime/StartupStageProbe.cs'
PROBE_SOURCE = ROOT / 'LocalComparison/Harness/StartupStageProbe.cs'
CALL = 'global::HybridLumenGI.StartupStageProbe'
sha_bytes = lambda value: hashlib.sha256(value).hexdigest()
sha = lambda path: sha_bytes(path.read_bytes())


def once(text, old, new):
    if text.count(old) != 1:
        raise ValueError(f'Expected one exact anchor ({text.count(old)}): {old[:100]}')
    return text.replace(old, new)


def source(data):
    if b'StartupStageProbe' in data:
        raise ValueError('Already instrumented; never apply the CPU overlay twice')
    # Work in normalized memory, then preserve the input newline convention.
    newline = '\r\n' if b'\r\n' in data else '\n'
    return data.decode('utf-8').replace('\r\n', '\n'), newline


def entry(text, signature, camera, stage, variable):
    anchor = signature + '\n' + (' ' * (len(signature)-len(signature.lstrip()))) + '{'
    return once(text, anchor, anchor + f'\n                using var {variable}={CALL}.Measure({camera},"{stage}");')


def patch_feature(data):
    text, newline = source(data)
    for signature, camera, stage, variable in (
        ('        public override void Create()', 'null', 'Feature.Create', '__startupCreate'),
        ('            public override void RecordRenderGraph(RenderGraph graph,ContextContainer frameData)', 'null', 'Feature.RecordRenderGraph', '__startupGraph'),
        ('            private void PrepareHardwareMaterials(RenderGraph graph,Work d)', 'd.state.camera', 'Feature.Prepare.HitMaterials', '__startupMaterials'),
        ('            private void Execute(Work d,CommandBuffer cmd)', 'd.state.camera', 'Feature.RecordCommands.Transport', '__startupExecute'),
    ):
        text = entry(text, signature, camera, stage, variable)
    text = once(text, '                state.Ensure(w,h,identityEnabled);',
        f'                using({CALL}.Measure(camera,"Feature.Ensure")) state.Ensure(w,h,identityEnabled);')
    start = '                state.scene.Prepare(camera.transform.position,slots,s.nearDistance,Mathf.Max(s.nearDistance,s.farDistance),s.chunkSize,s.proxyUploadsPerFrame);'
    end = '                state.changes.Begin(state.scene,Mathf.Max(s.shadowDistance,s.traceDistance)+Mathf.Max(1,s.traceDistance),'
    text = once(text, start, f'                using({CALL}.Measure(camera,"Feature.Prepare.SceneAndSdf"))\n                {{\n'+start)
    text = once(text, end, '                }\n'+end)
    start = '                state.surfaceCache.Prepare(state.scene,new HybridLumenGISurfaceCache.Config'
    end = '                state.EnsureCache(slots,Mathf.Clamp(s.cachePatchGrid,1,4),state.surfaceCache.CardCount);'
    text = once(text, start, f'                using({CALL}.Measure(camera,"Feature.Prepare.SurfaceAndCache"))\n                {{\n'+start)
    text = once(text, end, end+'\n                }')
    text = once(text, '                bool hardware=s.preferHardwareTracing && state.hardware.Prepare(state.scene,state.scene.Revision,',
        f'                bool hardware;\n                using({CALL}.Measure(camera,"Feature.Prepare.Hardware"))\n                hardware=s.preferHardwareTracing && state.hardware.Prepare(state.scene,state.scene.Revision,')
    # No algorithm change: same evaluation order, arguments, and short-circuiting.
    for kernel in ('"CSUpdateCache"', '"CSTrace"', 'd.useIdentity?"CSTemporalIdentity":"CSTemporal"', '"CSFilter"'):
        old = f'c.FindKernel({kernel})'
        expected = 2 if kernel in ('"CSUpdateCache"', '"CSTrace"') else 1
        if text.count(old) != expected:
            raise ValueError('Unexpected FindKernel call count: '+old)
        text = text.replace(old, f'{CALL}.FindKernel(c,{kernel},state.camera)')
    for phase in ('ReceiverCapture', 'Composite'):
        anchor = f'                        d.frameTiming.Begin(HybridLumenGIGpuFrameTiming.Phase.{phase},ctx.cmd);'
        text = once(text, anchor, f'                        using var __startup{phase}={CALL}.Measure(d.state.camera,"Feature.RecordCommands.{phase}");\n'+anchor)
    anchor = '                using(d.frameTiming.Profile(cmd,"HLGI World material capture")) state.surfaceCache.RecordCapture(cmd,d.viewport);'
    text = once(text, anchor, f'                using({CALL}.Measure(state.camera,"Feature.RecordCommands.WorldMaterialCapture"))\n'+anchor)
    # Cache/gather/temporal/filter commands stay in their existing order and scopes.
    anchor = '                using(d.frameTiming.Profile(cmd,"HLGI World cache"))'
    text = once(text, anchor, f'                using({CALL}.Measure(state.camera,"Feature.RecordCommands.Cache"))\n'+anchor)
    for phase in ('Gather', 'Temporal', 'Atrous'):
        anchor = f'                using(d.frameTiming.Profile(cmd,"HLGI {phase}"))'
        text = once(text, anchor, f'                using({CALL}.Measure(state.camera,"Feature.RecordCommands.{phase}"))\n'+anchor)
    return text.replace('\n', newline).encode('utf-8')


def patch_host(data):
    text, newline = source(data)
    if 'public sealed class LocalReleaseBootstrap' in text:
        text = entry(text, '    public static bool TryStart()', 'null', 'Host.TryStart', '__startupStart')
        text = entry(text, '    void Initialize(ComparisonCapture capture)', 'target', 'Host.Initialize', '__startupInitialize')
        text = once(text, 'Directory.CreateDirectory(folder);', f'Directory.CreateDirectory(folder);{CALL}.Configure(target,folder);')
        text = once(text, 'RenderPipeline.SubmitRenderRequest(target,request)', f'{CALL}.Submit(target,request)')
        text = entry(text, '    void Finish(bool complete)', 'target', 'Host.Finish', '__startupFinish')
        text = once(text, '        if(finished)return;finished=true;RemoveExplicitCallbacks();',
            f'        if(finished)return;{CALL}.Stop(target);finished=true;RemoveExplicitCallbacks();')
        text = once(text, '    void OnApplicationQuit()\n    {',
            f'    void OnApplicationQuit()\n    {{\n        {CALL}.Stop(target);')
    else:
        # The finite-wall hosts share this explicit request lifecycle.
        text = entry(text, '    void Start()', 'targetCamera', 'Host.Start', '__startupStart')
        text = once(text, '            Require(Path.IsPathRooted(outputDirectory)&&Directory.Exists(outputDirectory),"Prepared absolute output directory required");',
            f'            {CALL}.Configure(targetCamera,outputDirectory);\n            Require(Path.IsPathRooted(outputDirectory)&&Directory.Exists(outputDirectory),"Prepared absolute output directory required");')
        text = once(text, 'RenderPipeline.SubmitRenderRequest(targetCamera,request)', f'{CALL}.Submit(targetCamera,request)')
        text = once(text, '    void Cleanup()\n    {', f'    void Cleanup()\n    {{\n        {CALL}.Stop(targetCamera);')
    return text.replace('\n', newline).encode('utf-8')


def safe_relative(value):
    p = Path(value)
    if p.is_absolute() or '..' in p.parts or not p.parts or p.parts[0] != 'Assets':
        raise ValueError('Expected project-relative Assets path: '+value)
    return p


def save(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2)+'\n', encoding='utf-8')


def shader_pins(project):
    files = sorted(p for p in (ROOT/'Runtime').rglob('*') if p.suffix in ('.compute','.hlsl','.shader'))
    pins = {p.relative_to(ROOT).as_posix(): sha(p) for p in files}
    transport = {'Runtime/Resources/HybridLumenGI/'+name for name in
                 ('HybridLumenGI.compute','HybridLumenGIHardware.compute','HybridLumenGIExactSoftware.compute')}
    if not transport.issubset(pins):
        raise ValueError('Missing one of the three product transport compute entries')
    for rel, digest in pins.items():
        if sha(project/'Assets/HybridLumenGI'/rel) != digest:
            raise ValueError('Product shader differs before CPU overlay: '+rel)
    return pins


def verify_shaders(project, pins):
    if shader_pins(project) != pins:
        raise ValueError('Product shader source set or bytes changed')


def prepare(args):
    out, project = args.out.resolve(), args.project.resolve()
    if out.exists():
        raise ValueError('Use a new overlay directory; prior evidence is immutable')
    inputs = [(FEATURE_REL, args.feature_source, args.feature_sha256, patch_feature),
              (safe_relative(args.host_target).as_posix(), args.host_source, args.host_sha256, patch_host)]
    if len({rel for rel, *_ in inputs} | {PROBE_REL}) != 3 or not args.host_target.endswith('.cs'):
        raise ValueError('Host must be a distinct C# file')
    rows=[]; pins=shader_pins(project)
    for rel, path, digest, patch in inputs:
        data=path.read_bytes()
        if sha_bytes(data)!=digest:
            raise ValueError('Explicit source hash mismatch: '+str(path))
        rows.append((rel,data,patch(data),str(path.resolve())))
    if (project/PROBE_REL).exists() or Path(str(project/PROBE_REL)+'.meta').exists():
        raise ValueError('Probe deployment path is already owned')
    rows.append((PROBE_REL,None,PROBE_SOURCE.read_bytes(),str(PROBE_SOURCE)))
    manifest=dict(schema='startup-stage-overlay-v1',project=str(project),shaderSha256=pins,files=[])
    for rel, original, prepared, source_path in rows:
        target=out/'prepared'/rel;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(prepared)
        original_rel='original/'+rel if original is not None else None
        if original is not None:
            path=out/original_rel;path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(original)
        manifest['files'].append(dict(path=rel,source=source_path,sourceSha256=sha(Path(source_path)),
            original=original_rel,originalSha256=sha_bytes(original) if original is not None else None,
            prepared='prepared/'+rel,sha256=sha_bytes(prepared)))
    save(out/'manifest.json',manifest)
    print(json.dumps(dict(files=len(rows),productShaders=len(pins),probePath=PROBE_REL)))


def deploy(args, restore=False):
    out=args.out.resolve();manifest=json.loads((out/'manifest.json').read_text(encoding='utf-8'))
    project=Path(manifest['project']).resolve();verify_shaders(project,manifest['shaderSha256'])
    marker=out/('restored.json' if restore else 'installed.json')
    if marker.exists():raise ValueError('Operation already recorded')
    if restore and not (out/'installed.json').exists():raise ValueError('Overlay was not installed')
    # Verify every path and every byte before performing any mutation.
    for row in manifest['files']:
        target=(project/safe_relative(row['path'])).resolve()
        if not target.is_relative_to(project):raise ValueError('Escaping deployment target')
        original=out/row['original'] if row['original'] else None
        if original is not None and sha(original)!=row['originalSha256']:raise ValueError('Backup changed')
        if sha(out/row['prepared'])!=row['sha256']:raise ValueError('Prepared source changed')
        actual=sha(target) if target.exists() else None
        accepted=(row['sha256'],row['originalSha256']) if restore else (row['originalSha256'],)
        if actual not in accepted:raise ValueError('Deployment differs from owned bytes: '+row['path'])
        if not restore and sha(Path(row['source']))!=row['sourceSha256']:raise ValueError('Source changed after preparation')
    # Journal before writing; restore also accepts originals after partial install.
    if not restore:save(marker,dict(started=True,complete=False))
    for row in manifest['files']:
        target=project/row['path']
        if restore:
            if target.exists():
                archive=out/'post-run'/row['path'];archive.parent.mkdir(parents=True,exist_ok=True);archive.write_bytes(target.read_bytes())
            if row['original']:target.write_bytes((out/row['original']).read_bytes())
            elif target.exists():target.unlink()
            if row['path']==PROBE_REL:
                meta=Path(str(target)+'.meta')
                if meta.exists():
                    archive=out/'post-run'/(row['path']+'.meta');archive.parent.mkdir(parents=True,exist_ok=True);archive.write_bytes(meta.read_bytes());meta.unlink()
        else:
            target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes((out/row['prepared']).read_bytes())
    verify_shaders(project,manifest['shaderSha256'])
    save(marker,dict(complete=True,productShadersUnchanged=True))


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action',choices=('prepare','install','restore'))
    parser.add_argument('--out',type=Path,required=True)
    parser.add_argument('--project',type=Path,default=Path('I:/Unity test/Project'))
    for name in ('feature-source','host-source'):parser.add_argument('--'+name,type=Path)
    for name in ('feature-sha256','host-sha256','host-target'):parser.add_argument('--'+name)
    args=parser.parse_args()
    if args.action=='prepare':
        if not all((args.feature_source,args.host_source,args.feature_sha256,args.host_sha256,args.host_target)):
            parser.error('prepare requires both source files, their explicit SHA256, and host-target')
        prepare(args)
    else:deploy(args,restore=args.action=='restore')


if __name__=='__main__':main()
