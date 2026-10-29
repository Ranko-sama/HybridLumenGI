"""One-frame observer of the existing temporal validity chain; no product edit."""
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
source = (ROOT / "Runtime/Resources/HybridLumenGI/HybridLumenGIKernels.hlsl").read_text(encoding="utf-8-sig")
start = source.index("    int2 pixel=id.xy;", source.index("void CSTemporalIdentity"))
end = source.index("[numthreads(8,8,1)]\nvoid CSFilter", start)
body = source[start:end]


def replace(old, new):
    global body
    if body.count(old) != 1:
        raise RuntimeError("Ambiguous observer anchor: " + old)
    body = body.replace(old, new)


# Low bits record existing state, not newly evaluated copies of the gate.
# Bits 6..10 are the validity chain AFTER each existing assignment. A zero
# after an earlier zero is not evidence that the later predicate failed.
replace("    int2 pixel=id.xy;", "    int2 pixel=id.xy;\n    uint observedGates=239u<<16;")
replace("    bool currentKnown=", "    observedGates|=1u;\n    bool currentKnown=")
replace("    // A valid receiver with unknown Ng", "    observedGates|=(uint)hasGeometry<<1;\n    observedGates|=(uint)currentKnown<<2;\n    // A valid receiver with unknown Ng")
replace("    uint4 identity=_HLGI_IdentityCurrent.Load(int3(pixel,0));", "    uint4 identity=_HLGI_IdentityCurrent.Load(int3(pixel,0));\n    observedGates|=1u<<13;\n    observedGates|=(identity.w&3u)<<14;")
replace("        HLGIReceiverIdentityObject row=_HLGI_IdentityObjects[candidate.x-1u];", "        observedGates|=1u<<3;\n        HLGIReceiverIdentityObject row=_HLGI_IdentityObjects[candidate.x-1u];\n        observedGates|=(row.flags&1u)<<4;")
replace("    float2 prevUV=ProjectUV(expectedP,_HLGI_PreviousVP,w);", "    observedGates|=(uint)identityValid<<5;\n    observedGates|=(uint)_HLGI_HistoryValid<<12;\n    float2 prevUV=ProjectUV(expectedP,_HLGI_PreviousVP,w);")
replace("    // Never cast a nonfinite UV", "    observedGates|=(uint)valid<<6;\n    // Never cast a nonfinite UV")
replace("    valid=valid && HLGISameReceiverPrimitive(identity,_HLGI_IdentityPrevious.Load(int3(previousPixel,0)));", "    valid=valid && HLGISameReceiverPrimitive(identity,_HLGI_IdentityPrevious.Load(int3(previousPixel,0)));\n    observedGates|=(uint)valid<<7;")
replace("    valid=valid && HLGITemporalTapMatches(previousPixel,expectedP,expectedNs,expectedNg,rho,tolerance);", "    valid=valid && HLGITemporalTapMatches(previousPixel,expectedP,expectedNs,expectedNg,rho,tolerance);\n    observedGates|=(uint)valid<<8;")
replace("    valid=valid && change.x<0.5;", "    valid=valid && change.x<0.5;\n    observedGates|=(uint)valid<<9;")
replace("    valid=valid && HLGIHasTemporalHistory(history,moments);", "    valid=valid && HLGIHasTemporalHistory(history,moments);\n    observedGates|=(uint)valid<<10;")
replace("    if(_HLGI_GlobalReactive>0.5) valid=false;", "    if(_HLGI_GlobalReactive>0.5) { observedGates|=1u<<11; valid=false; }")

# Preserve XYZ. Only work frame239 replaces the existing spatial variance.
# Stamping every exit lets the readback distinguish the observer from variance.
import re
body, writes = re.subn(r"_HLGI_MomentsOut\[pixel\]=([^;]+);", lambda m:
    "_HLGI_MomentsOut[pixel]=" + m[1] + "; if(_HLGI_FrameIndex==239) _HLGI_MomentsOut[pixel].w=(float)observedGates;", body)
if writes != 6:
    raise RuntimeError(f"Unexpected temporal output sites: {writes}")
(HERE / "ObservedKernels.hlsl").write_text(source[:start] + body + source[end:], encoding="utf-8")

run = (HERE.parent / "stationary-history-01/run.ps1").read_text(encoding="utf-8-sig")
run = run.replace("StationaryHistory01", "DoorHistoryGate01").replace("hlgi-stationary-history-", "hlgi-door-history-gate-")
run = run.replace("../../../Runtime/Resources/HybridLumenGI/HybridLumenGIKernels.hlsl", "ObservedKernels.hlsl")
run = run.replace("RenderedFrames >= 300", "RenderedFrames >= 240")
run = run.replace("(frame == 119 || frame == 239 || frame == 240 || frame == 270 || frame == 299)", "frame == 239")
run = run.replace("logicalFrame != 119 && logicalFrame != 239 && logicalFrame != 240 && logicalFrame != 270 && logicalFrame != 299", "logicalFrame != 239")
run = run.replace("stationary-history-candidate-incomplete-prefix", "door-history-gate-diagnostic-incomplete-prefix")
run = run.replace("bb6a9f8 plus stationary-history candidate; only Kernels product change; existing Capture API and temporary ordinary capture selection", "97111ca / product 5e714f6; temporary frame239 moments.w observer only; not a product candidate")
run = run.replace("frames=@(119,239,240,270,299)", "frames=@(239)")
run = run.replace("Existing API filteredD and validity; ordinary IndirectOnly output separately retained", "Existing moments.w encodes actual temporal validity chain at workFrame239; diagnostic images are not quality evidence")
run = run.replace("300-frame", "240-frame").replace("scene0-299", "scene0-239")
run = run.replace("# The product candidate is staged separately and restored on exit. Only the existing ordinary image selection changes here. The original 720-frame", "# The temporary observer is restored on exit. The original 720-frame")
(HERE / "run.ps1").write_text(run, encoding="utf-8")
print("Prepared one-frame observer and existing-run adaptation; Unity not started.")
