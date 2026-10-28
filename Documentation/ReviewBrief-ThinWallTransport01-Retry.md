# thin-wall-transport-01 v3: valid A collection, new shutdown failure

Task c2c_a702 iteration6. Runtime remains main@870ba82, resource product code bd5a7d2. Followed iteration5's one bounded retry; no further zero-capture import. B/C have not run. No product algorithm changes or image tuning.

## Observer and provenance

v3 closes all new observations with the same finished flag, separates the exact frame×stage set from query coverage, validates structured layouts and mixed float/uint fields, and adds per-GI-frame write markers to private query/depth output. The depth-only texture is bound explicitly with RenderTextureSubElement.Depth and copied by Load; the private trailing marker is not included in the image file. The six query records remain160 bytes each; receiverPoint.w carries the marker. Original kernels do not parse the diagnostic body. Finish errors are caught separately so original capture cleanup continues; private observer buffers release only after all accepted readbacks complete. Diagnostic material binding failure throws an observer error rather than changing the product backend.

Astra's static gate found and corrected cleanup exception isolation, diagnostic binding/fallback coupling, vacuous target-owner coverage, and missing known/triangle checks. v1 failed sources and v2 import-only sources remain archived separately. v3 exact executed helpers/product instrumentation and baseline SHA256 are under LocalComparison/Review/thin-wall-transport-01/instrumentation-v3/. Installer and prepared analyzer are also saved. The final analyzer adds C's independent packed-light reference and stage ROI summaries; its executed bytes are retry-v3/analyzer.executed.py.txt.

## A data acquired

PID34664; native process exit0 (actual exec completion chunk2176d6), 120 logical frames, capture errors0. Nine predeclared samples produced135/135 stage files, no duplicate/missing stage, no skipped query, pending0/errors0. Exact software path was retained. Selected receiver directions/identities/triangle flags/material-known state and t values match the independent box geometry; raw depth reconstructs the same receiver points within the predeclared tolerance. Necessary owners are present, published and ready. All2750 interior and4200+4200 wall pixels match their predetermined surface identities. See retry-v3/A-analysis.json and complete source data under retry-v3/A/.

The final PNG is vertically flipped relative to raw rows: byte error4.34e-6 for flipped orientation versus40.275 for unchanged orientation, consistent with the previously documented capture metadata error. Numerical analysis uses raw rows. Stage/ROI values are descriptive, not a correctness reference; no A−B or C conclusions exist yet. The image shows a lit receiver and wall, not a proved leak or a proved correct dark side.

## New exit failure — cannot accept this run overall

Despite the successful capture and process exit0, A-Unity.log reports:

`owned=1, pending=0, unknownSubmission=0, failed=0, failedWithdrawals=0, outsideRenderLoop=True`

followed by `Persistent allocates29 individual allocations`, product-owned allocation callstacks (SDF atlas, geometry, surface/cache buffers and others), and D3D12 unreleased buffers. This is materially different from the generic MemoryLeaks aggregate preserved in earlier successful tests. The current collection gate does not inspect native teardown; its true result must not be relabeled as overall success. No ThinWallTap allocation stack appears in the retained leak records, but the precise owning retirement ticket was not instrumented in this run and causation remains under review.

B/C were suspended immediately after inspecting the complete exit log. No extra native run was launched. Product instrumentation was restored byte-for-byte by its archived hashes; four prior A configuration assets were restored by SHA256, with post-A copies preserved. Helpers remain inert in the test project. See retry-v3/execution-receipt.json and settings-restored.json.

One static hypothesis to review, not yet proved as this run's cause: DrainShutdown calls PollOwned and then CanProgressWithoutMainLoop. The latter polls ticket.IsComplete again and only returns true for an incomplete submitted ticket. A fence that becomes complete between those reads may cause an early break while its destroy callback remains pending, especially for the parent Feature owner. A targeted actual-source scheduling test could distinguish this from deadline/prerequisite or observer effects without rerunning the entire matrix. No product correction has been made.

Please review the valid A observation and new teardown failure, then give the smallest repair/investigation plan. Preserve prior resource-shutdown-01b's limited short-run evidence without claiming all shutdowns are solved. Prefer one directed actual-source counterexample and one natural bounded native confirmation if needed, then continue the deferred B/C only when justified. Do not repeat successful A image collection merely to increase test count; do not discard failure evidence. Full original goal remains active.
