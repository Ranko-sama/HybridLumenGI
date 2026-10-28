# Iteration21 — same-product DXR Player

ActualPro20 accepted3088d41 minimal root-tail fix and finite software normal exit;
full review saved in current-player-shutdown-01/gpt6-pro-review-and-next-plan.txt.
Software evidence/docs committed5eb17af; current product binaries still3088d41,
all283products manifest bbda6cbb087d6944cf1ef0210c978806455a12923539073f3d180a8ea5197ef4.
ActualPro21 review received/archived: RETAIN, approves local evidence commit and
next gpu-cost-baseline-01. No pending Pro response; proceed iteration22, no resend.
No dark investigation.

Package current-player-dxr-smoke-01. New external run-current-hardware-smoke.ps1 and
current-hardware-smoke.py reuse same exact build/source and software capability
proof. Analyzer only changed mode scope string and rejects any nonzero stable
hardware unrepresented-instance gauge. No build/deploy/Runtime changes, no source
tests/software rerun. Sole visible hardware120frame Player has been launched;
read hardware-command.log and hardware-windowed/attempt.json/native-exit.json for
current process. PID17240 / exec37808 COMPLETED nativeexit0/watchdogfalse.
All independent analysis stagesPASS:120unique/5HDR,stableactualhardware22meshes/
0unrepresented,119hash/identity/statmax32,nativeorderedcleanup/recordedowners0.
Both native and analysis outcomes recorded. DO NOT relaunch. See result.md.

When process finishes: record full native log and run
python LocalComparison/Harness/current-hardware-smoke.py analyze
once, saving stdout/stderr to package hardware-analysis.log. This rechecks every
output file and independent collection/backend/GI/HDR/native stages. Record both
native and analysis outcomes with c2c. Software native2parents7children is not a
fixed expected hardware count; genericzero does not prove totalRTAS/VRAMzero.

Astra result review accepted finite DXR result and favors one credible fixed-work
cost baseline before selecting a hotspot; actualPro21 review is generating. Existing
product timing is coupled to adaptive budget (RendererFeature around310); never
enable adaptation merely to measure. Diagnostic HLGI marker scopes remain available
with feedback disabled (GpuFrameTiming.Profile). Build contains no native timing DLL;
do not expand to native-plugin validation first. No new measurement run yet.

After actualPro21 review choose the concrete original-plan gap,
local commit. Scope remains finite Win6000.0.85f1/Mono/DX12. Full quality/dynamics,
longrun,peakVRAM,p95/p99 and historical exceptional scratch remain open.
