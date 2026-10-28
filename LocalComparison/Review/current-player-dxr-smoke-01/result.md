# Iteration21 — same-build finite DXR Player passed

No product/build/deployment changes. Reused candidate3088d41 at CurrentShutdown20,
283files/142703354bytes; full file set/size/hash identical before and after run.
Manifest bbda6cbb087d6944cf1ef0210c978806455a12923539073f3d180a8ea5197ef4.
110 current and deployed product source files match upstream built inputs.
Software evidence is referenced from current-player-shutdown-01; no software rerun.

Exactly one visible hardware Player PID17240, nativeexit0/watchdogfalse, run
20261028-083814-37360b267abb431e9a5584db817cf5aa.120frames/5captures/0errors;
first render wait99.2123232seconds (within frozen limit; not a timing benchmark).
Native status incomplete-probe correctly denotes the bounded120frame capture.

All independent analysis stages passed. Last16frames use actual hardware backend,
22hardware meshes/22published instances,55232attribute bytes,83600material frame
bytes and132ready cards at final diagnostics. Unrepresented-instance gauge0.
120unique functional receipts,119payload logical/engine/GIframe/readindex identities
match, four SHA256 receipts verified against actual binary. Moments allocation is
RGBA32F, maxhistory32 andfraction.8064236111 agree with the same saved payload.
History/material original texture formats remainRGBA16F/RGBA8 despite float readback.
Five HDR payloads have expected size and finite values.

Native log shows real outside/contextEnded boundary, owner withdrawal, parent
fence/destruction, separate child fence/destruction and final zero recorded generic,
material/arena/deformation/job/failed/unknown counters. No unresolved-retirement,
GC-buffer, D3D-unreleased, device or readback errors detected. Observed2parents and
7children match software this time, but were never a fixed acceptance requirement.
This is not a measurement of total RTAS/driver memory or peakVRAM.

Unity ##utp exit summary remains (allocatedMemory122097, same general categories as
software); do not attribute it to GI or infer total process leak-free. Historical
exceptional scratch and longrun memory remain unverified.

currentSourceBuildVerified=true (upstream); softwarePlayerSmokeVerified=true
(upstream); hardwarePlayerSmokeVerified=true; softwareNormalExitAccepted=true
(upstream); hardwareNormalExitAccepted=true; fullProductionAccepted=false.
This closes finite same-build software/DXR Player coverage, not image equivalence,
dynamic/whole-image correctness, performance or production acceptance.

Next independent review should select the next substantive original-plan gap.
Both existing runs have gpuTimingStatus/nativeGpuTimingStatus Disabled and
gpuFeedbackActive=false: these captures cannot yield attributable GI GPU p95/p99.
A bounded credible cost baseline before targeted GPU optimization is one candidate;
dynamic correctness is another. Do not repeat equivalent Player matrices, chase the
canceled dark region or create another observer framework just to turn fields green.
