"""Reuse the finite software baseline observer for one explicit DXR request."""
from pathlib import Path

here = Path(__file__).resolve().parent
previous = here.parent / 'release83-local-baseline-01'
root = here.parents[2]

def write(name, value):
    with (here / name).open('x', encoding='utf-8') as f:
        f.write(value)

s = (previous / 'UnifiedSampleGpuCost.cs').read_text(encoding='utf-8-sig')
for before, after in [
    ('settings.measureGpuCost=true;', 'settings.preferHardwareTracing=true;settings.measureGpuCost=true;'),
    ('HybridLumenGIHardwareBackend software;', 'HybridLumenGIHardwareBackend hardwareGeometry;'),
    ('software=(HybridLumenGIHardwareBackend)Field(state,"softwareGeometry")', 'hardwareGeometry=(HybridLumenGIHardwareBackend)Field(state,"hardware")'),
    ('meshes=software.MeshCount,unrepresented=software.FallbackCount', 'meshes=hardwareGeometry.MeshCount,unrepresented=hardwareGeometry.FallbackCount'),
    ('r.native&&!r.hardware&&r.exactSoftware', 'r.native&&r.hardware&&!r.exactSoftware'),
    ('feature.isActive&&!settings.preferHardwareTracing&&settings.exactSoftwareTracing', 'feature.isActive&&settings.preferHardwareTracing&&settings.exactSoftwareTracing')
]:
    if s.count(before) != 1:
        raise ValueError('Observer anchor changed: ' + before)
    s = s.replace(before, after)
s = s.replace('exact-software transport', 'actual DXR required in window')
write('UnifiedSampleGpuCost.cs', s)

s = (previous / 'build.ps1').read_text(encoding='utf-8-sig').replace('LocalRelease83Baseline', 'LocalRelease83DxrCost01').replace('hlgi-release83-baseline-', 'hlgi-release83-dxr-cost-')
write('build.ps1', s)
s = (previous / 'run-player.py').read_text(encoding='utf-8-sig').replace('LocalRelease83Baseline', 'LocalRelease83DxrCost01').replace('Release83LocalBaseline', 'Release83DxrCost01').replace('halfGI/exact software', 'halfGI/DXR requested; actual DXR required in window')
write('run-player.py', s)

s = (root / 'LocalComparison/Implementation/analyze-unified-gpu-cost.py').read_text(encoding='utf-8-sig')
before = 'row.get("exactSoftware") is True and row.get("hardware") is False'
assert s.count(before) == 1
s = s.replace(before, 'row.get("exactSoftware") is False and row.get("hardware") is True').replace('ready NativeDX12 exact software', 'ready NativeDX12 DXR')
write('native-analysis.py', s)
s = (previous / 'analyze.py').read_text(encoding='utf-8-sig')
s = s.replace('ROOT / "LocalComparison/Implementation/analyze-unified-gpu-cost.py"', 'HERE / "native-analysis.py"').replace('Release83LocalBaseline', 'Release83DxrCost01')
s = s.replace('Not set; user requested a local baseline before choosing targets.', 'User target960x540/30FPS; GI-only time and memory limits unset.')
s = s.replace('One current960x540 exact-software static sample. No resolution/backend matrix, images, performance acceptance, old-version speedup or lifetime peak claim.', 'One current960x540 actual-DXR static window. Backend cost/memory decision only; no equal-image speedup, displayed FPS, default change or lifetime peak claim.')
write('analyze.py', s)
print('Prepared existing observer adaptations; no product change, build or Player started.')
