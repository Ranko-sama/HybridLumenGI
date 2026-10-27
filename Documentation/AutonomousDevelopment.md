# Continuous local development

User authorization (2026-10-28): continue the entire OriginalDevelopmentPlan locally, following Occam's razor. After each bounded implementation and meaningful validation, obtain GPT-6 Pro review and its next plan in the existing ChatGPT conversation; execute and repeat. Use an independent GPT-6 Astra Max reviewer at critical decisions to prevent drift and redundant testing. No friend delivery is required.

Git baseline: main, 7d33d02 (local-development-denoise-01). Preserve existing evidence and caches. Commit reviewed increments locally; no remote publication.

## Current work package

Completed bounded reviews: denoise-02 contracts (5eb1058) and denoise-03 short-history transition. Pro retained the latter with explicit early-noise cost; see Documentation/ReviewBrief-Denoise03.md and its full review. Sustained reactive/maxHistory2/3 quality remains open, as do the other original-plan gates.

Current package: resource-shutdown-01. First attribute the exit warnings with allocation stacks, minimal resource retirement timelines and one short feature-on/off control. Then repair only a proven lifecycle gap, extending actual-source StandaloneDeformedMesh tests and finite in-process lifecycle checks. Handle both submitted-but-unpolled and after-final-context-unsubmitted tickets. Never replace GPU completion proof with elapsed frames, GC, cleared lists or zeroed accounting. Astra reviews the design and results at critical nodes. Full Pro plan is in LocalComparison/Review/denoise-03/gpt6-pro-review-and-next-plan.txt.

## Progress and stopping rule

Track implementation, current-version limited measurements, and production acceptance separately for all ten original workstreams. A package DONE is not overall DONE. Next priorities after contracts: transport/geometry/thin-wall correctness, dynamic behavior, resource lifetime/backends/scale, then release acceptance. Follow findings rather than build an unrelated framework.

Stop a failing experiment and retain its minimal reproduction on nonfinite values, erroneous history reuse, invented measurement validity, provenance/configuration mismatch, unexpected fallback or capture failure. Fix the blocker; this does not end the overall task.

Overall completion requires the promised support scope to satisfy G0-G5 in ProductionPlan.md with no known blocking defects, current-source Player and reference-image evidence, quantified dynamics, credible GPU p95/p99, peak VRAM and long-duration resource checks. Do not invent missing performance targets or call prior implementation checklists production acceptance. Continue correctness work and collect measurements while targets/reference availability remain open.
