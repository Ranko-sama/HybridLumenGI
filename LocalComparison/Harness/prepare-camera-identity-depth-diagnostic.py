"""Pure, unique-anchor temporary observer patches; never edits product files."""
from pathlib import Path


def replace_once(data, old, new):
    assert data.count(old) == 1, old.decode(errors='replace')
    return data.replace(old, new)


def nl(data):
    return b'\r\n' if b'\r\n' in data else b'\n'


def patch_feature(data):
    return replace_once(data, b'},frameTiming.Invalidate);', b'},frameTiming.Invalidate,camera);')


def patch_host(data):
    data=replace_once(data, b'CameraMotionTaaTap.Reset(targetCamera,outputDirectory,new[]{wall,floor,panel});',
                      b'CameraMotionTaaTap.Reset(targetCamera,outputDirectory,new[]{wall,floor,panel});'+nl(data)+
                      b'            CameraIdentityDepthDiagnosticTap.Reset(targetCamera,outputDirectory);')
    return replace_once(data,b'CameraMotionTaaTap.Dispose();',b'CameraIdentityDepthDiagnosticTap.DisposeAfterMainTap();')


def patch_pass(data):
    newline=nl(data)
    substitutions=[
        (b'internal HybridLumenGIReceiverIdentityPass Owner;', b'internal HybridLumenGIReceiverIdentityPass Owner;'+newline+b'            internal global::CameraIdentityDepthDiagnosticTap.Probe Probe;'),
        (b'internal BufferHandle Candidates, Objects;',b'internal BufferHandle Candidates, Objects;'+newline+b'            internal BufferHandle ProbeMap, ProbeRows;'),
        (b'Action<CommandBuffer, int, bool> timingBoundary = null, Action timingInvalidated = null)', b'Action<CommandBuffer, int, bool> timingBoundary = null, Action timingInvalidated = null, Camera diagnosticCamera = null)'),
        (b'frame.Rows.CopyTo(state.Rows, 0);', b'frame.Rows.CopyTo(state.Rows, 0);'+newline+b'            state.Probe=global::CameraIdentityDepthDiagnosticTap.Create(diagnosticCamera,frame,gpuViewProjection,fullWidth,fullHeight);'+newline+b'            state.ProbeMap=graph.ImportBuffer(global::CameraIdentityDepthDiagnosticTap.MapBuffer(state.Probe));'+newline+b'            state.ProbeRows=graph.ImportBuffer(global::CameraIdentityDepthDiagnosticTap.RowsBuffer(state.Probe));'),
        (b'builder.UseBuffer(state.Candidates, AccessFlags.Write); builder.UseBuffer(state.Objects, AccessFlags.Write);',
         b'builder.UseBuffer(state.Candidates, AccessFlags.Write); builder.UseBuffer(state.Objects, AccessFlags.Write);'+newline+b'                builder.UseBuffer(state.ProbeMap,state.Probe!=null?AccessFlags.Write:AccessFlags.Read);'+newline+b'                builder.UseBuffer(state.ProbeRows,state.Probe!=null?AccessFlags.Write:AccessFlags.Read);'),
        (b'builder.UseTexture(state.Dummy, AccessFlags.Write);',b'builder.UseTexture(state.Dummy, AccessFlags.Write);'+newline+b'                builder.UseBuffer(state.ProbeMap,AccessFlags.Read); builder.UseBuffer(state.ProbeRows,AccessFlags.ReadWrite);'),
        (b'state.Lease.Blocks[i] = block;', b'global::CameraIdentityDepthDiagnosticTap.Configure(block,state.Probe);'+newline+b'                        state.Lease.Blocks[i] = block;'),
        (b'cmd.SetBufferData((GraphicsBuffer)state.Objects, state.Rows);', b'cmd.SetBufferData((GraphicsBuffer)state.Objects, state.Rows);'+newline+b'                global::CameraIdentityDepthDiagnosticTap.Initialize(cmd,state.Probe);'),
        (b'cmd.SetRandomWriteTarget(1, (GraphicsBuffer)state.Candidates);', b'cmd.SetRandomWriteTarget(1, (GraphicsBuffer)state.Candidates);'+newline+b'                global::CameraIdentityDepthDiagnosticTap.Bind(cmd,state.Probe);'),
        (b'try { cmd.ClearRandomWriteTargets(); }', b'try { cmd.ClearRandomWriteTargets(); global::CameraIdentityDepthDiagnosticTap.Readback(cmd,state.Probe,state.Captured); }')]
    original=data
    for before,after in substitutions:data=replace_once(data,before,after)
    restored=data
    for before,after in reversed(substitutions):restored=replace_once(restored,after,before)
    assert restored==original
    return data


def patch_shader(data):
    newline=nl(data)
    substitutions=[
        (b'RWStructuredBuffer<uint3> _HLGI_IdentityCandidates : register(u1);',
         b'RWStructuredBuffer<uint3> _HLGI_IdentityCandidates : register(u1);'+newline+
         b'        #include "../../../../CameraMotionTaa01/CameraIdentityDepthDiagnostic.hlsl"'),
        (b'        #if defined(DEBUG_DISPLAY)',b'            HLGIIdentityProbeEntry(input.positionCS);'+newline+b'        #if defined(DEBUG_DISPLAY)'),
        (b'float captureDepth=_HLGI_IdentityCaptureDepth.Load(int3(pixel,0));',
         b'float captureDepth=_HLGI_IdentityCaptureDepth.Load(int3(pixel,0));'+newline+
         b'            HLGIIdentityProbeDepth(input.positionCS,primitive,cameraDepth,captureDepth);')]
    original=data
    for before,after in substitutions:data=replace_once(data,before,after)
    restored=data
    for before,after in reversed(substitutions):restored=replace_once(restored,after,before)
    assert restored==original
    # Original vertex remains a contiguous byte-identical substring.
    vertex=original.split(b'IdentityVaryings HLGIIdentityVertex',1)[1].split(b'float4 HLGIIdentityFragment',1)[0]
    assert vertex in data
    return data
