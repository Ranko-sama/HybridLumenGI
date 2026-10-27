# resource-shutdown-01: partial execution, normal Play exit failed

Task c2c_a702, iteration 3. Approved denoise-03 is committed as 4610cc2. Resource candidate is uncommitted and has NOT met this package's success criteria. The failed real experiment was stopped; no further GPU matrix is proposed without a revised finite plan.

## Attribution completed

Read LocalComparison/Review/resource-shutdown-01/attribution.json and the preserved on-before/off-before runs, source instrumentation and logs. The two twelve-frame controls exit 0 and both establish the declared scene; enabled diagnostics confirm exact software resources. Enabled run has ten native allocation leak stacks: six backend attribute ComputeBuffers, two CameraState software BVH GraphicsBuffers and two RayTexturePool arena buffers. Disabled run has none of these ten warnings, although its deformation snapshot still enters the generic retirement queue at exit.

At enabled capture completion and Editor.quitting, generic pending/owned counts are zero. Subsequent Feature.Dispose adds seven tickets owning eight buffers / 88,992 logical bytes, followed by a deformation snapshot. No further context submission or destruction occurs. This is attributed late-unsubmitted ownership; it is not inference from equal warning counts. The RayTexturePool allocations are a separate known owner.

## Candidate and directed tests

Actual product diff modifies ResourceRetirement and adds a tiny early Update pump. BeginContext revokes the outside certificate; EndContext never grants it. Only real Mono/Editor Update can grant it after context end. Ordinary idle submission remains asynchronous. Shutdown uses one monotonic five-second total deadline, including late Retire calls, and releases only after the actual fence and prerequisite report completion. Failure keeps ownership/accounting. Submission uncertainty conservatively blocks subsequent unproven tickets, including resources that might have been live in the failed context. Unrelated later context/immediate fences cannot erase that uncertainty. Existing valid completed tickets can still retire.

A ticket added during an ambiguous event tail requires another genuine context submission; it is not retroactively made safe by a later idle callback. This deliberate conservative limitation turned out to affect normal Play exit, not merely an exotic event-callback exit.

Tests/StandaloneDeformedMesh compiles actual retirement source and passes the existing checks plus idle completion, incomplete fence, prerequisite/query failure, two recorded camera readers, ambiguous tail, late/reentrant shutdown, shared deadline, destruction failure, and unknown context submission. The adapter now separates context and immediate queues. Test diagnostic logging records exceptions rather than inventing another exception. Unit output is in unit-reentrancy.log (earlier unit-first/unit-final outputs retained).

The standalone harness replaces the MonoBehaviour pump with an adapter and does not compile UNITY_EDITOR lifecycle branches; those require actual Unity evidence. Astra's independent final review is retained in LocalComparison/Review/resource-shutdown-01/astra-review.txt and agrees this package is partial/failed.

Astra found a reentrancy hole after the first real run had started: DrainShutdown's guard did not cover PollOwned invoked directly by IdleUpdate/EndContext. The current source adds PollOwned's own finally-reset guard and prevents DrainShutdown while polling. A targeted parent-destroy→Retire-child test through ordinary IdleUpdate passes. This guard was added AFTER the failed real run; no new Unity runtime result is claimed for it.

## Real lifecycle result: failed, not accepted

Read lifecycle-failure-analysis.json, lifecycle-failed/lifecycle.jsonl, lifecycle-failed/retirement-timeline.jsonl and lifecycle-failed.log. Initial fixture compilation failed because a runtime-assembly helper referenced RuntimeAuditEditor in the Editor assembly; lifecycle-fixture-compile-failure.log is preserved. The corrected entry compiled and actually ran three owners in one process.

- Cycle 0 establishes exact software resources, disposes while another camera continues rendering, and reaches generic owned=pending=0.
- Cycle 1 establishes again, stops all target rendering, and reaches owned=pending=0; target render count remains 16 during this drain.
- Cycle 2 establishes again, then invokes real EditorApplication.ExitPlaymode with GI active. It fails. Timeline sequence702 has outside=true; sequence703 is ExitingPlayMode. Six existing submitted tickets retire on valid completion. Sequence722 records another end-context event, revoking outside. Sequence723 then begins Feature.Dispose. Seven buffer tickets, then a snapshot, are added with requiresContext while outside=false. After ordinary Play exit, eight pending/owned tickets remain, and the fixture exits 1.

The late final context is concrete evidence that merely initiating shutdown at a known idle point does not prevent another render before owner disposal. The current conservative guard preserves safety but fails the required liveness. Do not “fix” this by relabeling the eight tickets, reusing an unrelated old fence, clearing ownership or extending waits.

The failed run reports sixteen native leak allocations: the same six backend + two BVH + two arena allocations, plus six buffers from three HitMaterialBatch allocations. These are a different lifecycle from the twelve-frame control; do not call the count increase a measured same-scenario regression. It does show other last-consumer queues remain open during this fast final exit.

The observer also had a defect: repeated poll diagnostics inspected already-destroyed Unity object references, generating 1,279 MissingReference warning entries and omitting those particular trace records. Original logs are retained, and the helper now checks Unity's destroyed-object state. Do not use the polluted runtime/log durations as performance evidence or claim the corrected helper has been rerun. Lifecycle counters and the valid enqueue/submission records suffice to identify failure, not full successful attribution of every final ticket.

## State and requested decision

Both attribution and candidate instrumentation were restored by original hashes. Workspace and deployed product use the uninstrumented candidate, including the subsequently unit-checked reentrancy guard. Runtime fixture files remain outside the product package. No resource candidate commit was made. All prior denoise acceptance limits and original-plan gaps remain active.

Please review this failed finite experiment and provide the next smallest implementation/repair plan. In particular, decide how owner withdrawal can precede the final teardown render, or what stronger public lifecycle boundary can safely submit these tail tickets, without a generic resource framework or private Unity reflection. Distinguish generic queue ownership from HitMaterialBatch/RayTexturePool, and require an actual completion proof. Do not ask for repeated denoise or unchanged whole-scene matrices. If this candidate should be reverted or reduced before continuing, say so explicitly.
