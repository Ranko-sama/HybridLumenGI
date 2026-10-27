# Continuous local development

User authorization (2026-10-28): continue the entire OriginalDevelopmentPlan locally, following Occam's razor. After each bounded implementation and meaningful validation, obtain GPT-6 Pro review and its next plan in the existing ChatGPT conversation; execute and repeat. Use an independent GPT-6 Astra Max reviewer at critical decisions to prevent drift and redundant testing. No friend delivery is required.

Git baseline: main, 7d33d02 (local-development-denoise-01). Preserve existing evidence and caches. Commit reviewed increments locally; no remote publication.

## Current work package

denoise-02-contracts, following GPT6ProReview-Denoise01.md: correct HDR temporal moments storage and memory accounting (F1), and debug slot 3 semantics (F2). Retain the existing spatial variance cap as a filter scale limit to isolate this change. Reuse the existing GPU harness for actual half-radiance/float-moments ping-pong, both temporal kernels and genuine identity resources, unknown/invalid history and reset contracts. Diagnose R1/R2 using a 17x17 temporal/filter 1/2/4 chain without speculative algorithm changes. At most one 420-frame before/after pair if it answers a remaining concrete question; do not rerun old matrices without cause.

Astra independently endorsed this scope. Its explicit warning: old 3x3 tests and center-only checks cannot prove full filter-chain or HDR storage correctness. Check all pixels/channels; use format-based tolerances.

## Progress and stopping rule

Track implementation, current-version limited measurements, and production acceptance separately for all ten original workstreams. A package DONE is not overall DONE. Next priorities after contracts: transport/geometry/thin-wall correctness, dynamic behavior, resource lifetime/backends/scale, then release acceptance. Follow findings rather than build an unrelated framework.

Stop a failing experiment and retain its minimal reproduction on nonfinite values, erroneous history reuse, invented measurement validity, provenance/configuration mismatch, unexpected fallback or capture failure. Fix the blocker; this does not end the overall task.

Overall completion requires the promised support scope to satisfy G0-G5 in ProductionPlan.md with no known blocking defects, current-source Player and reference-image evidence, quantified dynamics, credible GPU p95/p99, peak VRAM and long-duration resource checks. Do not invent missing performance targets or call prior implementation checklists production acceptance. Continue correctness work and collect measurements while targets/reference availability remain open.
