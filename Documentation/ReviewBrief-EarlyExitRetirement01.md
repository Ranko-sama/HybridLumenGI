# Iteration12 — detached-pass fix confirmed within scope; full acceptance remains open

Baseline3241b50. Implements the next package in the actual Pro11 reply, preserved at LocalComparison/Review/scene-lightoff-chain-01/gpt6-pro-review-and-next-plan.txt. All original development goals remain open. No new360-frame light-off run and no new screenshots.

## Offline observer correction

LightoffPatchMap.cs is an actual pure C# mapper used by the revised SceneLightoffTap. It deduplicates full geometry identity and retains rule aliases; entry/card are checked as addresses. Saved [21,21,26,26] becomes unique[21,26], aliases[0,0,1,1]. Actual-source offline controls for distinct identities, unmapped input and revision/address changes passed. Revised analyzer rejects missing headers before numerical interpretation, iterates observed frame keys and preserves incomplete coverage. Re-analysis of the saved failed one-frame data still fails, with two missing observer records and no IndexError; it does not classify unwritten slots as actual uncovered cache. Revised code has not executed in Unity. Original failed artifacts are unchanged.

## One native baseline attribution completed

PID5820, native exit1, exec finalchunkd223a0; one rendered frame, original duplicate-lane error, no captures. Collection succeeded (05653c), analysis succeeded as attribution (31e0cd), retirement proof remains false. All executed source/helper hashes matched; original source and eight assets restored (1d2433). Raw evidence: LocalComparison/Review/early-exit-retirement-01/baseline. No baseline retry allowed.

Trace observes original fence/prerequisite and capability reads at their actual short-circuit positions. Astra approved the concrete observer after removing an unsafe diagnostic camera.name read. Native allocation-stack capture was enabled before the instrumented allocations. The original chain01 duplicate-lane helper was intentionally preserved for this run; new alias code was not deployed.

## Proven causal path

See baseline/attribution.json, analysis.json, run/early-exit-timeline.jsonl and Unity.log. In runtime domain52de95f8987745238883d2acfa0780ad, own EndContext callback returns at sequence9. Sequences10–16 enqueue seven tickets, all requiresContext=true and submitted=false. The call stacks originate in RenderPipelineManager.CleanupRenderPipeline→URP.Dispose→ScriptableRenderer.Dispose→Feature.Dispose→direct TransportPass.Dispose→CameraState.Dispose. No parent retirement ticket exists.

The tickets represent BVH nodes+leaves24544 logical bytes and six software attribute buffers40064 bytes, total64608. Subsequent real IdleUpdate certifies outside, actual supportsGraphicsFence reads true, but SubmitImmediate excludes all seven because they require a context. Shutdown stops at no-progress; it does not reach a five-second timeout. Eight native allocation stacks independently identify two BVH GraphicsBuffers and six software attribute ComputeBuffers. The engine scratch allocation is not assigned to a GI owner by counting.

The generic retirement guard deliberately preserves ambiguous EndContext-tail work. The owner wiring directly destroys the pass on ordinary Feature.Dispose, whereas explicit shutdown withdrawal already retains a parent. The targeted decision is how to retain the detached pass until a real safe submission boundary without promoting arbitrary tail tickets or assuming GPU completion. StopAdmission prevents new RecordRenderGraph; already-recorded callbacks still own the pass, so its storage must remain alive until their actual fence proof.

## Localized candidate and independent safety review

Feature Create/Dispose/shutdown now all detach the entire pass/composite, StopAdmission and use the internal RetireDetachedPass path. A dedicated parent flag waits for real idle when an outside certificate is unavailable; EndContext cannot promote that waiting parent. Real idle authorizes only a fresh graphics fence, not destruction. Existing idle shutdown proceeds without a future Update. Generic Retire tail/unknown/prerequisite guards and the shared deadline are unchanged. Parent completion precedes Dispose; nested child resources still need independent fences.

Last-reader coverage was checked against local URP17.0.4 sources: graph callbacks execute synchronously and are cleared in Execute finally, camera context submission precedes EndContext. This is a constrained renderer-pass contract, not a generic owner permission. Astra independently approved the bounded candidate and source tests before the unique fixed run. Tests compile actual ResourceRetirement/DeformedMesh sources with controlled API adapters; they cover explicitly submitted last readers, no-idle retention, forbidden context promotion, parent/child exact once and accounting, known-idle shutdown, and old ambiguity/unknown/prerequisite guards. Passed977110; no broader matrix repeated.

## Unique fixed native confirmation

PID3116 / exit1 / finalchunkc320aa. Collection96a920, frozen analysis8fd78f and scoped reconciliationfe0c89 succeeded. Same original first-frame observer failure reproduced, one target render, zero captures. No extra context or forced render was added. Source/helper hashes matched and exact pre-experiment deployed source/assets were restoredddd422. Workspace retains the candidate Runtime for review; Unity is not running. Both permitted native processes have now been consumed; no retry.

Runtime domain2320249b989346a2a73e3b1e4142f79f has nine completed tickets: an initial empty pass parent, then the relevant old pass parent and seven child tickets. Relevant parent1472973220 enqueues15 after own EndContext, becomes idle-eligible18, submits27, observes actual passed/ready before destroy33–41. Seven child tickets enqueue34–40 under that parent, independently submit51–57 and finish61–85; all64608 logical child bytes are accounted. Every ticket has one actual submission, completion observation and exact-once destruction. Final generic/material/arena/deformation accounting is zero.

No baseline-attributed GI buffer native leak remains; scoped nativeAttributedLeaks=0. One named D3D12ScratchBufferInternal1MiB warning remains, with ownership unresolved. Therefore frozen analysis.json deliberately retains retirementProofPassed=false. Supplemental fixed/attribution.json reports scopedGIOwnerProofPassed=true without changing frozen acceptance. expectedObserverFailure=true and lightoffCompleted=false; this is not a passed scene-light-off run or broad leak-free claim.

## Requested Pro decision and next package

Independently review the two Runtime files, targeted tests, observer mapping changes, fixed raw timeline/native log and recorded outputs. Decide whether the narrow GI owner gap may be closed while tracking engine scratch separately, and whether the revised alias observer may proceed to one frozen real-scene light-off package. No360 run has occurred this iteration. Keep the full original plan, scene energy/lighting semantics, frame119/120 observations, image validation and final Player/DXR/performance/long-run acceptance open. Prefer the smallest next evidence-bearing change; avoid rerunning completed matrices or turning scratch attribution into an unbounded detour.
