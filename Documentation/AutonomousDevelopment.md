# Continuous local development

## Current continuation (2026-10-29)

The current user asked to take over this workspace, explicitly requested a subagent to verify prior conversations, and explicitly disabled Codex with ChatGPT for this chat. Do not run its session/doctor/recovery flow or send work to ChatGPT in this chat. Earlier external-review instructions below are historical, not a current approval gate. This is a chat-specific override, not a workspace-wide disconnect.

At takeover, the conversation audit and repository inspection agreed on main at `78618e1`, the completed continuous-deformation example and Release69 evidence, with a clean worktree. Release69's product-source baseline is `50b63c33683ba533f01c7119f6320ad80b4f2ec6`; its example/build wiring has a separate frozen manifest. At that point HEAD had no Runtime/Editor/Shaders changes relative to that product baseline. The takeover read-only hash check matched all 112 product-source files in both the repository and `I:/Unity test/Project/Assets/HybridLumenGI` (224 file checks), and all 189 listed Release69 products. Later source changes do not update that executable automatically.

Release69 is closed: the recorded DX12 run completed 256 target-camera frames, observed 11 differing motion-window publications, reached the final complete producer mesh and exited normally. The original preparation failure and corrected build remain preserved. There is no pending implementation, build retry or unfinished native run to resume. See [the finite result and limitations](ReviewBrief-ContinuousDeformationUsage01.md) and [takeover record](LocalDevelopment.md).

Continue the four goals and ten workflows in [OriginalDevelopmentPlan](OriginalDevelopmentPlan.md), prioritizing the user's latest choice: credible color bounce and stable dynamic changes. The user also requested parallel progress; independent implementation/reference work may run in parallel when useful, with one owner for shared deployment, Unity execution and integration. The next increment identified and repaired two concrete conditional defects: [unknown cache visibility and the reactive history limit](ReviewBrief-ColorBounceDynamicLimits01.md). Its finite WARP evidence is separate from Release69, which was not rebuilt or redeployed. Future increments should likewise identify a concrete current-source defect or useful missing behavior, define the smallest change and its adoption criteria, then implement and validate it. An unchecked acceptance label alone is not a product defect or a reason to rerun completed matrices.

The later native integration completed 168 actual texture dispatches and built Release70; its two hidden automatic-camera runs failed with zero camera callbacks and remain failed. The finite wall reference then captured the complete Feature through explicit StandardRequest rendering: 27 selected pixels matched an independent 216-ray single-bounce oracle. Its initial input floor heuristic failure and separate raster-aware source qualification remain preserved; RGB limits and GPU data were unchanged. See [native integration](ReviewBrief-CurrentColorDynamicsIntegration01.md) and [finite wall evidence](ReviewBrief-FiniteWallColorReference02.md). Release71 subsequently passed 120 explicit-request Player frames and Final HDR validation, while first-render latency was 99.24 seconds; see ReviewBrief-CurrentLocalRelease71.md. The subsequent actual source-color/light-off sequence passed 2,592 receiver checks and 891 separately frozen input-support qualifications over 96 frames; see ReviewBrief-FiniteWallDynamicResponse01.md. Its 141.34-second first-render latency remains a limitation. Continue the independent finite cache-feedback reference and concrete motion/occlusion source audits. Do not stop for approval at each completed increment.

Broader color/energy reference quality, overall temporal quality, broader deformation/material and software/DXR behavior, streaming scale, GPU tail latency, total VRAM and long-duration acceptance remain open. Resolution/FPS/GI-time/VRAM targets are still unspecified. Historical percentage estimates are not a measured acceptance result. Preserve source-bound evidence and caches; local development continues without friend delivery or remote publication.

## Historical execution policy (2026-10-28)

The earlier user authorization was to continue the entire OriginalDevelopmentPlan locally, following Occam's razor, with GPT-6 Pro review after bounded increments and independent Astra review at critical decisions. That external-review loop does not apply to this chat under the explicit current instruction above.

The historical starting baseline was main, `7d33d02` (local-development-denoise-01). The following package pointer is retained for provenance and must not be resumed as current work.

## Historical work-package pointer (superseded)

Completed bounded reviews: denoise-02 contracts (5eb1058) and denoise-03 short-history transition. Pro retained the latter with explicit early-noise cost; see Documentation/ReviewBrief-Denoise03.md and its full review. Sustained reactive/maxHistory2/3 quality remains open, as do the other original-plan gates.

At that time the package was resource-shutdown-01: attribute the exit warnings with allocation stacks, minimal resource retirement timelines and one short feature-on/off control, then repair only a proven lifecycle gap. Its original plan is in LocalComparison/Review/denoise-03/gpt6-pro-review-and-next-plan.txt. Later source-bound results and subsequent work are recorded in [DevelopmentProgress](DevelopmentProgress.md); this old plan does not describe the current stopping point.

## Progress and stopping rule

Track implementation, current-version limited measurements, and production acceptance separately for all ten original workstreams. A package DONE is not overall DONE. Next priorities after contracts: transport/geometry/thin-wall correctness, dynamic behavior, resource lifetime/backends/scale, then release acceptance. Follow findings rather than build an unrelated framework.

Stop a failing experiment and retain its minimal reproduction on nonfinite values, erroneous history reuse, invented measurement validity, provenance/configuration mismatch, unexpected fallback or capture failure. Fix the blocker; this does not end the overall task.

Never replace GPU completion proof with elapsed frames, GC, cleared lists or zeroed accounting. Both submitted-but-unpolled and after-final-context-unsubmitted retirement tickets retain their actual completion requirements.

Overall completion requires the promised support scope to satisfy G0-G5 in ProductionPlan.md with no known blocking defects, current-source Player and reference-image evidence, quantified dynamics, credible GPU p95/p99, peak VRAM and long-duration resource checks. Do not invent missing performance targets or call prior implementation checklists production acceptance. Continue correctness work and collect measurements while targets/reference availability remain open.
