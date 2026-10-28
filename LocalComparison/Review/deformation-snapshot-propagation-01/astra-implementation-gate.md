# Astra implementation gate — deformation-snapshot-propagation-01

Provenance note: this file is a retrospective transcription of the pre-native review already delivered in the agent conversation. The file itself was written on2026-10-28 during the subsequent results review, after the sole Player run. It must not be presented as an artifact that existed before execution. The gate decision below is not derived from the successful run.

The pre-native conversation found no remaining implementation blocker after these narrow corrections:

- Separate a known radiance measurement from a receiver with unknown Ng. The product permits a valid receiver with unknown Ng to preserve a known single-frame sample; it must not be reported as promotion of unknown radiance.
- Every declared detail frame must contain its exact expected payload stages or an explicit backend/identity-unavailable status. An available consumer with an omitted detail hook is an observer failure, not an unrequested frame.
- Explicitly check finite raw, history, moments, material and geometry at the two159 admission points before testing positive alpha/history length. NaN must not pass a comparison written only as `value<=0`.
- Skip recorder binding for an uninstrumented software fallback. Normal asynchronous readiness gaps remain distinct from native/backend failures.

The reviewed design uses159 full state to select and admit two fixed pixels; it does not require selected traces before those coordinates exist. From160, mask3 activates only the two screen lanes. Publication and first-new-geometry binding triggers are evaluated before the original dispatch/detail decision. All windows remain inside255 and introduce no additional rays or worker wait.

The static review checked the current candidate/object mapping, instance128B, triangle-surface96B, object-to-world64B and recorded barycentric offsets. It also checked the existing Update-boundary close, observer buffer retirement and nonthrowing capture/publication hooks. Content reads occur at capture/publication; later destruction receipts read managed metadata/object IDs and do not introduce a new disposal or polling mechanism.

The parent subsequently reported the third managed preflight passing with prepare-3 matching the current helper bytes. Existing shader/mapper evidence was reused; this reviewer did not run a compiler, fixture, Unity or Player. The gate authorized only the already agreed single build and single bounded run, with first-failure preservation and no automatic retry.
