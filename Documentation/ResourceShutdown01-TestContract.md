# resource-shutdown-01 bounded attribution and fix

Baseline 4610cc2, following Pro's denoise-03 review. Do not change rendering/transport/noise behavior for this package. Stage A changes only archived test-project diagnostic callbacks; product workspace sources remain unchanged until ownership evidence identifies the fix.

## Stage A control

Use existing RuntimeAuditEditor.Play / Functional scene, DX12, same capture exit path, twelve logical frames per side. One feature-on and one feature-off run; no denoise event-window flags. Existing startup guard remains 120 engine frames / 900 seconds. Environment UNITY_JOBS_NATIVE_LEAK_DETECTION_MODE=2 enables the installed Unity Collections allocation-stack diagnostic. Preserve logs, raw outputs and source hashes. This control ends through the existing direct EditorApplication.Exit path; it does not certify ordinary Play-mode exit.

ResourceShutdownTrace is a test-project-only helper. Archived instrumentation records enqueue, final-context submission, polling, destruction attempts/results, feature disposal and editor/application lifecycle markers. Records include captured callback/owner, directly owned buffer types/counts/strides/logical bytes, prerequisite type and observed fence state. Last-observed camera metadata is a diagnostic timestamp, not proof that all GPU readers have completed. The helper does not submit a fence, invoke retirement polling, release an object or change accounting. Callback exceptions are reported and do not modify release decisions. Enqueue stacks and Unity leak stacks provide provenance; equal counts alone do not establish common ownership.

At capture-finish, actual diagnostic state must show that the enabled side established exact software geometry and associated allocations. If it did not, mark coverage missing. A disabled-feature control is not an empty-scene control; RuntimeAuditProbe and deformation continue to exist on both sides.

Restore instrumented Retirement/Feature/Capture files by their original hashes before product implementation. Preserve unknown/failed ticket states. Distinguish submitted-but-unpolled from after-final-context-unsubmitted tickets, and native managed-allocation warnings from driver resource warnings.

## Stage B/C limits

Only repair an attributed owner/lifecycle gap. Withdraw future readers, order after existing readers, prove actual completion, then destroy and reduce accounting. No frame-count grace, forced GC, static-list purge, suppressed warning, unconditional readback-based completion assumption or unbounded shutdown wait.

Extend Tests/StandaloneDeformedMesh using the actual retirement source: incomplete/failed fences, prerequisites, idle progress, late enqueue, exact-once destruction, destroy exception and active shared-reader boundaries. Reuse unrelated math/denoise checks rather than repeating them.

Then execute three bounded in-process establish/stop/destroy cycles, covering another rendering camera and no subsequent target rendering, followed by ordinary process exit. Record attributable count/bytes before/after and native evidence. Fixed cycle count is an observation window, never a completion criterion. Device errors, hangs, premature/double release, provenance mismatch or inability to prove final completion stop that experiment and preserve evidence for Pro.
