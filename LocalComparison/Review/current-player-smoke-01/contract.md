# Current-source Player smoke — fixed scope before execution

User correction cancels low-light attribution. No dark-region defect is established;
do not resume that investigation. Actual revised Pro19 plan: gpt6-pro-plan.txt.

Baseline9176b0f. Runtime/Editor deployment must match current source. One Windows
x64 Development/Mono/DX12/Linear build of existing Functional.unity, explicit scene
list; no Prepare/generator/rebake/Streaming. Source manifest records actual scene
dependencies, Runtime/harness, renderer/settings and package lock. Build product
manifest hashes ALL emitted files, including managed assemblies and resource data,
before first Player execution; same product checked before hardware run.

Test-side changes only: thin existing-scene builder; explicit -auditSmoke requires
-auditFrames120, functional scene, mode final/hardware (invalid input exits1);
existing RuntimeAuditProbe records both moments formats. Original720 default stays.
No product Runtime edits or extra GPU observers. Reuse the probe's history/identity
completion readbacks and -auditDenoiseReadback119 history/moments/geometry/material.

Build once normally. Only a specific local Player compile/resource blocker can
justify one minimal repair and at most one new build, preserving the first failure.
Software Player runs ONCE for120frames. Only accepted software collection/backend/
readback/normal-exit and reported inline capability allow hardware Player ONCE for
120frames using the SAME build. No -nographics. Keep startup900seconds/120engineframe
limits, normal capture Update→Finish→Application.Quit, no owner disabling/manual
Dispose/drain/extra render/forcedGC. An external1200second process watchdog is a
failure limit, never an extension of the in-app first-frame limit.

Fixed stable window104–119: requested backend actually reported, valid prepared
geometry/material path and nonzero published geometry; record all fallback/reason
fields and represented-instance coverage gauge range. hardwareFallbacks is a
recomputed instance count, not a cumulative backend-switch counter. Startup
fallback is separate; unexplained new stable window fallback fails. Readbacks
at30/119 must complete, valid history and integer
identity coverage must exist, both moments allocations R32G32B32A32_SFloat. Saved119
GI payloads and HDR must have expected size and finite components. Alpha classifies
valid measured black separately from unknown/absent; no RGB-nonzero acceptance gate.
No claim that diagnostic flags alone prove GPU execution; combine actual binding
states, completed readbacks and source call path for this limited Player smoke.

Reuse existing five captures0/30/60/90/119. Existing initial deformation and camera
motion60–99 remain; this is not dynamic image-quality acceptance. No reference
integral or software/DXR image-quality threshold. No Editor/off/SDF/720frame/
streaming/performance/VRAM/retirement fixture matrix.

Full external native logs must pass shared native_log_check plus scratch and
uncaught-exception/missing-resource checks. Capture closes its log subscription
before Application.Quit; run.json/exit0 alone cannot validate cleanup. Preserve
first failure and stop that route without retrying a Player. Archive final state.

Report build/software/hardware/each normal exit separately. Normal success does
not close historical exceptional1MiB scratch, long-run growth, peakVRAM, other
platform/build variants or fullProductionAccepted (alwaysfalse in this package).
Restore test wiring and verify product/deployment hashes after build. Keep actual
build and run evidence, Astra guard and actualPro result review; continue original
development priorities after this finite package.
