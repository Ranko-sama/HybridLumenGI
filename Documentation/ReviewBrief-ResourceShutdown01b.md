# resource-shutdown-01b: owner withdrawal before final teardown rendering

Task c2c_a702, execution iteration 4. Baseline main@4610cc2. Resource candidate remains uncommitted, pending this review. Original four goals and ten workstreams remain active; no production completion or full leak-freedom is claimed.

## Implemented bounded plan

ResourceRetirement closes admission, invokes registered Feature/deformation withdrawal callbacks as one batch, clears reusable texture residency, then advances the existing retirement paths. Withdrawal exceptions have a separate persistent count. The existing actual fence/prerequisite, outside-boundary, unknown-submission and shared deadline rules remain. There is no reclassification of context-required tickets, no accounting reset, and no forced completion. The shutdown loop can advance an eligible child ticket newly created by a completed parent, while callback-dependent prerequisites remain nonblocking.

Feature.Create/AddRenderPasses/RecordRenderGraph reject new work after closing. Withdrawal detaches the entire old pass and composite material into a parent retirement callback. Old passes retain a permanent stopped-admission bit, independent of a later new session. Already-recorded graph callbacks, binding and final seals are unchanged. Parent completion runs the existing Dispose; any resulting child retirement still obtains its own completion evidence. Late Unity Dispose is idempotent.

Deformation withdrawal removes published snapshots, invalidates the generation and cancels workers. Running cancelled jobs retain snapshots and reservation bytes until their actual Task completes. PollShutdownWork continues across a new Play session; cleanup failure preserves the job and accounting and blocks retries. Material batch/texture lease admission is closed, while existing consumers retain their original binding/sealing/retirement paths. HitMaterialPass.PollRetired and RayTexturePool.ClearReusable use existing completion rules; their state machines were not relaxed.

## Directed verification

Five affected actual-source standalone fixtures passed: DeformedMesh/Retirement, HitMaterialBatch, RayTexturePool, HitMaterialPass and HitMaterialLayout. The latter two also verify the new source dependency compiles. Added cases cover close-before-withdraw, no new admission, an existing recorded reader surviving withdrawal, parent-to-child retirement through EndContext and idle, cancellation storage across a new session, no old-result publication, late disable idempotence, and existing batch/lease consumers completing after admission closes. Existing failed fence/prerequisite/unknown-submission checks remain. These are adapters, not engine/GPU proof.

Astra then found a failure path in the ordinary BeginContext cancelled-worker cleanup: it removed the Job before destroying its snapshot. The final source now destroys first and retains cleanupFailed ownership if destruction throws. One targeted actual-source regression verifies the failure is not retried or cleared through idle, normal contexts or new-session initialization. See unit-DeformedMesh-cleanup-failure.log. **This small exception-path correction was made after the real GPU runs below.** Exact executed product source is archived, and analysis.json reports the sole changed source hash. No native run of the final exception-path delta is claimed; it does not change the successful natural shutdown branch, whose jobs count was zero. Please assess this scope explicitly rather than assuming byte-identical native evidence.

## Real Unity evidence

Read LocalComparison/Review/resource-shutdown-01b/test-contract.txt, analysis.json, lifecycle/lifecycle.jsonl, lifecycle/retirement-timeline.jsonl, direct/retirement-timeline.jsonl and the original lifecycle.log/direct.log. Instrumentation and exact executed helpers/product sources are archived under instrumentation/ and executed-product/. Runtime tests used Unity 6000.0.85f1, URP 17.0.4, DX12, RTX 2080 Ti, default domain reload.

- Natural lifecycle: two 12-frame captures, two genuine ExitPlaymode calls and exactly one re-entry. Feature and a published deformation snapshot remained active until the product closed them. No fixture feature toggle, manual Dispose, product polling or resource release. Process exit 0.
- Separate direct EditorApplication.Exit path: one 12-frame capture using the existing RuntimeAuditEditor.Play entry. Process exit 0.
- All 36 natural-lifecycle tickets and 21 direct-exit tickets have one enqueue, one actual submission, one destroy-begin with fence passed, and one destroy-returned within the same recorded domain. Actual-run prerequisites are none; nontrivial prerequisites are unit coverage only. Late Dispose adds no new ticket.
- Each natural exit has the same lifecycle domain identifier before and after ExitPlaymode: old-session pending/owned, material buffers/batches, texture arenas, deformation snapshots/jobs/bytes all reach zero before re-entry. The independent trace also retains per-ticket old-domain completion. These are not zeros inferred from new-domain initialization.
- Each tested shutdown initially has a 77,344-byte reusable texture arena and a 53,760-byte published deformation snapshot. No material batch or deformation worker was pending at that exact close boundary. Thus runtime tests cover the arena/snapshot teardown and actual generic buffers, but do not certify every Recorded/Quarantined/readback-pending/worker-pending shutdown state; those unresolved states retain their existing fail-closed rules.
- No observer failures, MissingReferenceException, attributed native allocation leak report, unresolved-owner warning, compilation error or device-loss marker appears in either run. Unity still prints its licensing token diagnostic, unavailable D3D12 info-queue-interface query, existing obsolete-API warnings, and a general shutdown MemoryLeaks aggregate. These are preserved, not suppressed or reinterpreted as product ownership.

The observer now captures owner descriptions once at enqueue and emits only changed poll states. It does not repeatedly walk destroyed Unity objects. Source instrumentation was restored by SHA256. Deployed product matches current uninstrumented workspace sources, including the post-run failure-retention correction.

Previous failed resource-01 evidence remains unchanged. Its executed lifecycle helper was preserved before editing. The previous failed trace helper's hash exists, but its exact pre-fix body was not archived and a reconstruction did not verify; no reconstructed body is presented as executed evidence. The new runs archive all helper bytes and hashes.

## Requested review and next package

Review current diff, explicit post-run delta, execution outputs and old-domain completion records. Decide retain/revise and whether this bounded local Editor shutdown defect is closed. Do not extrapolate to Player shutdown, disabled-domain-reload modes, faulted device recovery, pending CPU/readback callbacks, long-duration stability or overall production readiness.

If retained, authorize the local commit and select the next smallest substantive implementation/repair package from OriginalDevelopmentPlan.md and remaining acceptance gaps. Avoid repeating unchanged denoise or full-scene matrices. The autonomous implementation → actual GPT-6 Pro review loop continues until the original outcome is met.
