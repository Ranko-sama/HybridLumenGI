# Iteration19 — user correction and priority change

The user explicitly clarified that the central dark area was a question, not a
reported defect, and said not to waste time if it is not a fault. Independent
decision: no concrete dark-region defect is established, so cancel the proposed
low-light-reconstruction-attribution-01 package. No implementation, observer,
new capture, Unity run or parameter change for that package has been made.
Do not resume it merely because it appears in the archived Pro18 next-plan text.

Iteration18 evidence is committed as9176b0f. Its finite observations/limitations
remain valid; dark-region absolute correctness is unproven, which by itself is not
a reason for another dedicated investigation.

Return to the complete OriginalDevelopmentPlan. Current Runtime/Editor bytes match
the deployed Unity project, but Player build/run evidence remains candidate16 and
hardwarePlayerVerified=false. The current resource-lifecycle and denoising fixes
have not been exercised in the current Player. Priority: reuse existing functional
scene/builder/runner for a bounded current software/DXR Player smoke and normal exit,
without regenerating assets, repeating720frame/off/SDF/streaming matrices or claiming
performance/whole-image acceptance.

Actual revised Pro19 plan is saved in LocalComparison/Review/current-player-smoke-01/
gpt6-pro-plan.txt. c2c_a702 /19 is EXECUTING, no pending Pro response. Astra approved
priority and reviewed the thin builder/entry changes; prebuild source-root omission
was fixed by including actual Pipeline/settings GUID dependencies and metadata.

Unique normal build COMPLETED exit0: Unity PID30536, exec59874 finished. Full
build-unity.log/build-report.json retained; three test-side files/new metadata
restored and110producthashes matched. Build analysis accepted283files/142698822bytes,
manifesthash e1640798217978d0da7a0417bd710499c90574f276618d1c1b67900b200a2f8d.
First analyzer falsely matched a source-list filename UnifiedRayTracingException.cs
as an exception; original source/log/failed JSON retained, regex now requires actual
exception syntax. No native rebuild. Both analysis outcomes recorded.

First software Player PID38036 exited1 after0.048sec/120engineupdates,0camera frames,
0captures. Original software/ retainsFAIL; hardware not started. Executor launch
mistake used-batchmode+Hidden, while I:/Unity test/Comparison/REPRODUCE.txt already
documents no receipts in those modes and requires ordinary window. Old instruction
copy and actual launcher source archived; noGIbugestablished. Astra approves one
explicitly recorded corrected launch beyond originalprocesslimit; full explanation
in launcher-correction.md/astra-launcher-review.md. No rebuild, product/limits same.

Corrected software-windowed Player PID23148 COMPLETED exit0; exec52436 finished.
120frames/5captures/0captureerrors, but normalExitAccepted=false: unresolved2owners,
deformation53760bytes,29D3D12resources and GC buffer-disposal warnings. Route stopped;
hardware never launched. Saved119momentsmax1 is a separate observer overwrite:
first119functionalmax32, second119max1 after capture.Finish restores camera/target.
Do not infer a GI history bug or rewrite originalFAIL. See package result.md.
Both actual outcomes recorded. Next actualPro result review, bounded shutdown and
probe provenance repair in a fresh package, local commit, continue original plan.

Build and corrected software analysis are finished; do not rerun this package.
External full native logs,119history/moments/geometry/material and30/119identity
readbacks are required. Last16frames104–119must use actual requested backend with
prepared geometry/material consumers. hardwareFallbacks is a coverage gauge, not
an event counter. Bothmomentsformat fields are only expected at30/119.

Build output: I:/Unity test/Comparison/Builds/CurrentSource9176b0f/HybridLumenGITest.exe.
One normal build, optionally ONE specific local Playercompile/resourcefix rebuild
if blocked; no Player retries. No dark-region work, off/SDF/Streaming/720/matrix.
After actual results: Astra result node, actualPro review, local commit, continue
next substantive original-plan work.

Useful existing paths:
- I:/Unity test/Project/Assets/RuntimeAudit/Functional.unity and Streaming.unity
- Assets/ComparisonHarness/Editor/RuntimeAuditEditor.cs: Build calls Prepare and
  regenerates assets; avoid blindly using it for a source-fixed smoke.
- Assets/ComparisonHarness/RuntimeAuditEntry.cs: existing Player selects mode and
  scene, but hardcodes720frames. A minimal test-only bounded argument is needed.
- Assets/Editor/LocalTestEnvironment.cs: Build uses current EditorBuildSettings;
  currently points to ComparisonScene/Run/Validation.unity, not functional scene.
- ComparisonCapture supports configurable1..720frame count, limited probes keep
  incomplete-probe status; actual backend diagnostic is not GPU execution proof.
- RuntimeAuditProbe has finite existing identity/history readbacks at30/119 etc;
  retain suitable evidence, do not expand it into a new observer framework.

Full plan, historical source/startup/scratch issues and production limits remain
open. No remote push or friend handoff. Continue meaningful implementation and
finite review loop; no work solely to turn all acceptance fields green.
