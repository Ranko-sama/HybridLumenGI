# Astra result review — snapshot-publication-cleanup-01

Decision: **no blocking finding; the local candidate and bounded evidence are ready for actual Pro review**. The baseline establishes the stated ownership defect. The candidate keeps the failed private snapshot tracked without retrying partial destruction, and allows the later healthy completed job to publish. No additional Unity, Player, GPU, or broader lifecycle experiment is needed for this package.

This review inspected the Runtime/test diff, the three saved execution logs, and the frozen baseline sources. It performed read-only source/hash comparisons, not another test or analyzer run. Only this review document was written.

## Baseline and same-input evidence

The frozen `baseline/HybridLumenGIDeformedMesh.cs.txt` matches the committed `1d1f18ff623f612a596ddd8bf16713635a21865e` component text after newline normalization. The frozen Program and Adapters are byte-identical to the current candidate test inputs. ResourceRetirement and its pump have no candidate diff.

The isolated `HLGI_PUBLICATION_CLEANUP_CASE=1` path completes both real Task-backed jobs before publication. The healthy replacement is captured first and the failing replacement second, so the production reverse traversal encounters the failure before the healthy job. The adapter selects FailSet only for the rejected mesh, avoiding a global fault that would also invalidate the healthy control.

| Observation after the injected publication/cleanup failures | Baseline log | Candidate log |
| --- | --- | --- |
| Independent chart-publication and mesh-destruction exceptions occurred | Yes | Yes |
| Destruction exception escaped the context callback | Yes | No |
| Original failing Job remains enumerable | No | Yes, same object |
| Old mesh/SDF/charts publication is preserved | Yes | Yes |
| Reserved bytes | 154,368 | 154,368 |
| FailedCleanupCount | 0 | 1 |
| Controlled failing-mesh destroy attempts | 1 | 1 |
| Healthy completed job still pending | Yes | No |

The baseline fails the intended ownership/exception-isolation assertion, after both injected failures have occurred. It is not a compilation failure or an unfinished-worker failure. No test code reinserts the lost Job or clears reservations to repair that baseline.

The 154,368-byte intermediate total includes the old/live and replacement snapshots; it is not the failed snapshot's individual size. The later passing candidate assertion requires that, after normal published snapshots retire, only the original failed snapshot's recorded reservation remains, with PublishedSnapshotCount zero. The final individual byte value is asserted through `failedReservation`, rather than printed separately in the saved log.

## Product change

Only `Runtime/HybridLumenGIDeformedMesh.cs` changes product behavior:

- The valid-result publication path no longer removes the Job and disposes its CTS before construction/publication.
- Publication failure restores the previous Published reference as before. Failed-snapshot cleanup has its own catch; if destruction throws, the original Job/snapshot, unresolved reservation and live CTS remain owned, `cleanupFailed` becomes true, both exceptions are logged, and the loop continues.
- The CTS is disposed and the Job removed only after successful publication/ownership transfer or successful private cleanup. There is no unconditional terminal action in a finally block and no artificial reservation decrement.

Keeping the CTS alive matters because RequestCapture, Disable and shutdown still cancel Jobs by owner. The isolated candidate exercises those paths after the failure, including normal context/idle processing and new-session initialization, without ObjectDisposedException or loss of the retained Job. The existing cleanupFailed guards prevent future cleanup/publication attempts for this partial snapshot.

The healthy job's same-context publication demonstrates exception isolation in the completion loop. It does not claim that a permanently retained failure consumes no worker or memory budget: Jobs.Count and the existing conservative admission limits remain unchanged.

## Existing behavior and limits

`existing-suite-command.log` records the unchanged default suite passing: normal atomic publication, publication failure with successful cleanup, old/disabled snapshot retirement, cancellation and admission gates, shutdown/new-session cleanup, detached-pass handling, completion-progress behavior, root-tail behavior, retained destruction failure, and unknown-submission guards. The isolated failure case does not contaminate that separate process's accounting.

The adapter's destruction checks and the explicit cleanupFailed control-flow guard support the no-retry conclusion together. This is actual C# component execution with controlled Unity/destruction adapters and real Task barriers. It is not a real Unity native destruction-failure reproduction, physical-memory measurement, GPU completion experiment, or a revalidation of prior native runs against the new candidate.

The diff does not alter capture algorithms, worker results, resource-page scheduling, GPU completion conditions, shader behavior, or retirement architecture. The intentionally retained failure is an observable unresolved owner, not a recovered allocation. Submit the local repair with that boundary; do not expand this package into generalized failure recovery or another native matrix.

## Reviewed hashes

| Artifact | SHA-256 |
| --- | --- |
| Frozen baseline component | `e25a0aa61937663edef53e39009820f826e1e0ff28f4a4a136cfceb57cb3b7d3` |
| Candidate component | `5f9f384e268136aa21afd1eed095cba0f31e50d4be7258368519ab17f852aca5` |
| Program, baseline and candidate | `1bd6363b9ef411086009be0a46da027ff7bb4d1e2c49766fa2e08d5cbc5206c9` |
| Adapters, baseline and candidate | `103927275ca4b3600694e95224fd336177de0d36f70042709314c9216f3244db` |
| `baseline-command.log` | `ed42e90fbdbd816154bac7bd6f71e05a07bc4af71642d7876d92de795c8fa6dd` |
| `candidate-command.log` | `85aaa213d7f557905f54d308283ee56332ab73ef43bb154045e6b6c2cc718864` |
| `existing-suite-command.log` | `5fe75e0b7f34734518d917ef43df5c33c6b0ec6c2d3ac1dc9c49c736d2bde5e0` |

