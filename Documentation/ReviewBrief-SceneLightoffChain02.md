# Iteration13 — complete360-frame observation, frozen analysis retains one startup failure

Baseline c50ec78 contains Pro12-approved detached-pass retirement and alias observation changes. Full original development loop remains active. Runtime diff is empty. Executed actual Pro12 plan with exactly one new Unity process, no settings/points/seeds/backend changes and no retirement rerun. Package: LocalComparison/Review/scene-lightoff-chain-02.

## Execution and acceptance remain separate

PID15304 / nativeexit0 / finalchunk6fcfb4. Unity6000.0.85f1 / URP17.0.4 / DX12 / RTX2080Ti. All360 target-camera logical frames, nine HDR/EXR/PNG captures and zero runtime/observer errors completed. Both observers report passed, no missing records or pending requests. Collectionf87f98 verifies source hashes and eight actual serialized assets; shared native scanner finds no failure signatures, including no scratch warning in this run. Exact restore05bfce and96source workspace/deployment auditb93f24 matchc50ec78. No Unity process remains.

Frozen analyzer1b7f50 returns exit1 with exactly one failure: no other source event at logical1. Preserve analysis.json and original contract unchanged. summary.json separates observationComplete=true, lightChangeChainPassed=false, nativeResourceAccepted=true, overallAccepted=false. Scoped GI owner proof references iteration12, not a new per-ticket claim here. Absence of scratch in this normal completion does not resolve its earlier exceptional-exit ownership.

run.json labels status=incomplete-probe and fullSequenceCompleted=false because generic ComparisonCapture reserves completed for720frames. Its own collected/errors/renderedFrames check returned native0. This is the completed bounded360-frame observation, not the historical720suite; source snippet is preserved in instrumentation/capture.original.txt.

## Only frozen failure: startup lifecycle assumption

| Logical frame | GI frame | scheduler tick | cache read | before count | after count | change count | floor revision |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 0 | 0 | 1 | 0 | 0 | 1 | 1 | 12 |
| 1 | 0 | 1 | 0 | 0 | 1 | 1 | 13 |
| 2 | 1 | 2 | 1 | 1 | 1 | 0 | 13 |
| 119 | 118 | 119 | 0 | 1 | 1 | 0 | 13 |
| 120 | 119 | 120 | 1 | 1 | 0 | 1 | 13 |

The actual Light instance31606 and packed source are unchanged at0/1; both selected patches' old80bytes are zero at both frames. Actual after-update nonempty changes occur only at0,1,120. Runtime HybridLumenGILights.Update clears changes then adds a current Light when count>=previousCount; previousCount0 therefore correctly represents first discovery. CameraState.frame only increments in the inspected feature source. These facts support renewed state initialization rather than repeated change against an established snapshot. Exact Feature/CameraState creation identity and caller were not observed in this run; do not borrow the earlier attribution stack as proof. Astra independently checked this limited inference. No product fix, tolerance relaxation or rerun has been made.

Astra additionally checked all20owner revisions increase by1 at0→1, both full GPU light buffers match byte-for-byte, and every subsequent binding follows giFrame=max(0,logicalFrame−1) with no further reset. All2547 light-off receipts are unique and complete. These are saved-data facts; a future rule must distinguish a fresh snapshot from a physical Light change, not merely ignore frame1 by number.

See summary.json startupEvidence, actual lightoff-lights.jsonl and lightoff-schedule-0000/0001/0002/0119/0120.json, actual cache-observed bytes, Runtime/HybridLumenGILights.cs:51 and RendererFeature GetCameraState/UpdateLights. Request independent judgment on the lifecycle-aware offline rule needed to classify this startup without ignoring arbitrary later source events. Original FAIL must remain immutable.

## Valid observed event chain and residuals

The119 readiness gate passed. At120 the same Light.enabled changes false before target preparation, CPU previouscount1→effective0; the old packed record appears once as removal. One correct local point-light domain is uploaded, globalGeometry/globalLighting stay0. Effective shader count0 is observed; unused Light buffer bytes are not interpreted. No repeated post120 source event or geometry invalidation occurs. Actual proposal header and area count remain0; source inventory and evaluated screen/world emission remain available, without inferring global zero-source solely from CPU properties.

Both unique patches retain full identity/aliases after119. The budget remains256, queueFrames360; actual masks/service clocks and oldest quota checks pass. Across720 patch-frame records:106 committed estimates,614 not scheduled,713 valid nonblack and7 valid black. No known data are relabeled from missing observer slots. Committed irradiance maximum arithmetic error2.33e-10; guide error1.34e-7, within frozen arithmetic tolerance.

Gather analysis validates34 final cache consumptions,20 linked to a selected patch;23 raw tap byte links are counted separately. Twenty-nine world and five screen direct-off observations plus345 known cache-update direct calls satisfy zero direct terms after real removal. Raw/history/filtered and matching final2x2 footprints are saved at the original nine samples. Max raw reconstruction error0 for observed records; no claim of independent whole-scene energy truth.

At119 selected cache irradiance is approximately(0.0000756,0.002588,0.0000957) and(0.004341,0.004740,0.004344). At359 it is(0.0000222,0.000203,0.0000235) and(0.000294,0.000351,0.000295). These are nonzero residuals, not convergence certification. Some individual channels increase transiently; no monotonic acceptance criterion was imposed. Full-image mean RGB falls from(0.01361,0.02145,0.01365) to(0.0000332,0.0000605,0.0000334), final maximum around0.000404. PNG appears nearly black at359 but actual HDR remains nonzero.

Actual screenshots were visually inspected and shown to the user: run/20261028-041010-d14728cf2da7410cbc7a56be035c20f6/frame-0119.png and frame-0359.png. They depict this fixed C single-light scene, not broad visual-quality acceptance.

## Preflight changes and boundaries

Current-source installer includes LightoffPatchMap, uses new outputs/label and no first-frame cap. Astra requested and verified explicit first-frame4rules/2uniqueentries/[0,0,1,1] gate plus invalid-gather-header rejection. Changed CSUpdateCache compiled76a4b9; unchanged CSTrace compilation reused only after effective-source/compiler/include matching. New consumption decoder had a saved-data mismatch965432 (stale last call ID on a no-cache endpoint); same-context guard fixed it, all36 saved A streams/26 previous consumption identities matchce5773. Both logs retained. This was offline decoder wiring, not a second native process or repeated product matrix.

## Requested next decision

Review current helper diff, frozen contract, all recorded success/failure outputs, startup evidence and actual119/120/cache/gather/image data. Decide local evidence commit status and the smallest offline correction/qualification for the initialization boundary, then the next substantive development package under the original four goals/ten workstreams. Prefer reusing this complete run over rerunning360frames. Keep scratch exceptional-exit attribution, independent whole-scene reference, Player/DXR, dynamic quality, GPU p95/p99, VRAM and long-run acceptance open. Do not infer physical correctness from a dark PNG or indefinitely expand startup/resource tests.
