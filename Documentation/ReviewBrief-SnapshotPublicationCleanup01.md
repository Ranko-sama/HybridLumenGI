# Pro review brief: snapshot-publication-cleanup-01

Task c2c_a702, iteration28; baseline1d1f18f accepted asset-page withdrawal evidence. Pro27 selected the completed-job publication rollback ownership gap. Original four goals/ten workstreams remain in OriginalDevelopmentPlan.md. This package has zero Unity/Player/GPU runs and no new observer. Do not rerun previous geometry/page/native tests or reopen darkness/MC/timing.

## Actual-source baseline counterexample

The existing Validate-DeformedMesh.ps1 compiles the real DeformedMesh, ResourceRetirement and pump with the established deterministic Unity/SDF/chart adapters. The new case runs in its own process with HLGI_PUBLICATION_CLEANUP_CASE=1 because its failed snapshot is deliberately retained. Normal invocation retains the existing complete guard suite.

The case establishes two published owners. It captures a healthy replacement first, then the failure-target replacement; the existing reverse job loop therefore processes the failing job first. Both actual Task.Run workers are completed through existing barriers before the publication frame. Existing FailSet is scoped to the target publishing mesh, while FailDestroy targets that private snapshot's mesh. New adapter fields only record the two exception objects and the current SetBakedData source; no new fault system or job-list repair.

Before triggering, the case saves old Published mesh/SDF/charts, the real job and snapshot references, and reservation. The baseline archived in LocalComparison/Review/snapshot-publication-cleanup-01/baseline matches HEAD product bytes; test/adapter bytes are identical between baseline and candidate (source-identity.json).

baseline-command.log records both controlled exceptions, then a failure at the intended ownership/isolation assertion:

- cleanup exception escaped BeginContext;
- original job no longer enumerable, FailedCleanupCount0;
- old Published remains valid, failed private mesh not destroyed;
- reserved154368 bytes unchanged;
- healthy completed job still pending because processing was interrupted.

This is an executed C# control-flow counterexample with explicit adapters, not an actual Unity native destruction fault or a regression in successful native iterations26/27.

## Minimal product change

Only Runtime/HybridLumenGIDeformedMesh.cs changes product behavior. Remove the early job removal/CTS disposal. After successful publication/ownership transfer, or after rollback and successful private cleanup, dispose CTS and remove the job once. If rollback cleanup throws, set cleanupFailed, retain the same job/snapshot/reservation and live CTS, append a clear retained-cleanup status, log both original exceptions and continue to the next completed job.

No unconditional finally disposal, no retry of a partially destroyed snapshot, no reservation reset, no failed-job exclusion from worker capacity, no change to fences, resource pages, shaders, capture/worker or GPU completion contracts. Retained failures continue to count in the existing Jobs/budget semantics.

## Candidate evidence

candidate-command.log, with the exact same input, passes:

- no escaped exception; same tracked job and snapshot; old mesh/SDF/charts unchanged;
- failed cleanup count1, destruction attempted once, full154368 bytes initially held;
- healthy completed job publishes in the same callback;
- RequestCapture, subsequent context/idle, shutdown, Disable and new-session initialization neither retry partial destruction nor touch a disposed CTS;
- normal published/retiring snapshots finish through original recorded fences; only the failed snapshot's38592-byte logical reservation remains, no published snapshot remains.

existing-suite-command.log separately passes the existing actual-source publication, successful rollback, cancellation, budget, parent/child retirement, shutdown, failed cleanup and unknown-submission guards. Consumer-routing regex checks remain source-only. No changed numeric SDF/chart algorithm, physical GPU result or native-fault reproduction is claimed.

The repository candidate now differs from the last Unity deployment/Player by this one product source file. Earlier native evidence remains tied to its prior source identity; do not claim the new candidate has been built or run in Unity. No deployment edit was needed for these actual-source tests.

Please list/read available iteration28 execution output, inspect the small product diff and saved counterexample/candidate sources, then decide whether to retain this repair and choose the next concrete original-plan work. Do not expand this conditional exception case into a generic lifetime framework. Astra completed the candidate/source/log review with no blocking finding; see LocalComparison/Review/snapshot-publication-cleanup-01/astra-results-review.md. It recommends no additional native run or broader lifetime refactor.
