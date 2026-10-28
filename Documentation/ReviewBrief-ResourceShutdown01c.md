# resource-shutdown-01c: completion progress race

Task c2c_a702 execution iteration7, following Pro iteration6 plan. Baseline main@870ba82; this product fix remains uncommitted pending review. The only Runtime delta is CanProgressWithoutMainLoop in HybridLumenGIResourceRetirement.cs. No transport, filter, owner withdrawal, texture/material state-machine, deadline or completion-proof change.

## Deterministic before/after

While iteration6 review was pending, a narrow actual-source reproducer used the existing standalone Unity adapter with a monotonic submitted fence: first query false, second and later true. It registers a shutdown owner whose parent destroy enqueues a child. The actual close path is invoked once, with no extra idle call to rescue it. Baseline source SHA03988194… failed: parent0/child0/owned1/pending0, fence submitted+completed, queryCount2. Preserve LocalComparison/Review/thin-wall-transport-01/retry-v3/progress-race-baseline.log and progress-race-baseline-sources/. This is deterministic source evidence, not a native GPU claim or complete attribution of A's native failure.

The fix removes the extra fence read from the progress predicate. A nonfailed, known-submitted owner with no prerequisite or a satisfied prerequisite can progress: either its fence is still pending, or the next PollOwned will destroy it. Prerequisite exceptions remain not-ready. Actual destruction still independently requires the real fence and prerequisite in PollOwned. Existing eligible pending children keep their own submission path; context/unknown state, shared five-second deadline, admission and reentrancy protections are unchanged.

The exact archived baseline adapter+Program, with only the actual Runtime source changed, now passes: parent1/child1, owned0/pending0, two separately submitted/completed fences, each queryCount2. See resource-shutdown-01c/unit-race-same-input-fixed.log. The integrated Tests/StandaloneDeformedMesh case uses the same deterministic transition and verifies own child submission; false/throwing prerequisites retain ownership without synchronous busy-waiting. The affected actual-source suite passed once, including existing query failure, unknown submission, ambiguous context tail, shared deadline and failed native destroy cases. No unrelated fixture matrix was rerun.

## One natural native confirmation

Exactly one independent12-frame static thinView/exact-software resource probe ran, PID34552, exit0 (exec chunk38a091). It uses ComparisonCapture.Finish→EditorApplication.Exit, with no fixture Dispose, product poll, Feature toggle or extra frame extension. It disables the135-stage thin-wall observer. ResourceProgressEntry's12-frame contract is separate from the unchanged A/B/C120-frame contract.

The new RetirementProgressTrace logs only product-read fence/prerequisite results, never performs its own completion query. Actual stop reasons and shared deadline are recorded. The old ResourceShutdownTrace was not enabled. Exact inserted bytes, helper and installer are archived under resource-shutdown-01c/instrumentation/; original product/capture bytes were restored afterward. See native/progress-timeline.jsonl, native.log, native-analysis.json and execution-receipt.json.

The same runtime domain contains21 tickets with exactly one enqueue, submission, actual passed/ready check, destroy-begin and destroy-returned each. The Feature parent creates7 children; each child has its own submission/completion. Related generic/material/arena/deformation accounting reaches zero. No same-class attributed native leak, unresolved-owner, observer or device-error signature occurs. The generic engine MemoryLeaks aggregate remains preserved. Astra independently inspected the raw timeline and accepted this limited integration gate.

Limits: the real parent fence was already passed on its first query; the deterministic test covers the race window. Actual native prerequisites were empty. This is one Editor exit on Unity6000.0.85f1/URP17.0.4/DX12/RTX2080Ti, not Player, disabled-domain-reload, in-flight worker/readback or device-fault acceptance. Earlier resource01b short-run evidence stays scoped to those runs.

## Deferred thin-wall work completed under the same plan

After the resource gate passed, B and C each ran once with120-frame caps,135/135 stage files, same observer bytes as A, fixed camera/ROI and full native-log gates. No A replay. Actual-source manifest/runtime.diff under thin-wall-transport-01/instrumentation-v4 explicitly records the retirement-only product delta relative to A. B settings differ from A only by feedback0; C retains A's settings and disables only the other original lights. Both exit0 and lack the same failure signatures. See ReviewBrief-ThinWallTransport01-Completed.md.

Please independently review the narrow fix, before/after proof, one native confirmation and bounded B/C results. Decide local commit acceptance, then give the next highest-value bounded work package under the full original plan. There is no proposal to extend tests until incidental success or to call the whole project complete.
