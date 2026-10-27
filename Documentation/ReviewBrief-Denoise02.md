# denoise-02-contracts execution for GPT-6 Pro review

Task c2c_a702, iteration 1. User authorizes continuous local development/review against OriginalDevelopmentPlan.md. This is a bounded package, not completion of the overall task. Baseline is Git main@7d33d02. Runtime diff is uncommitted for review. No friend delivery or remote publication.

## Changes

- Both temporal moments targets are RGBA32F; radiance remains RGBA16F. Base GI allocation is 112 bytes/pixel, with identity 144; the budget oracle uses an itemized inventory.
- Debug enum slot 3 is SpatialVariance, displaying v/(1+v); other numeric slots remain unchanged. Actual composite debug and Final paths have small GPU readbacks.
- Spatial variance cap 65504, plane weights, short-history formula and temporal/transport equations are unchanged. Comments now distinguish the variance hard gate from the filter's soft plane weight.
- Extend the existing GPU harness; the new 11-line DenoiseFixture.compute only uploads integer identity test inputs. It does not implement any runtime predicate or filtering logic.

## Evidence and corrected finding

All evidence is under LocalComparison/Review/denoise-02/. Read validation.json, product.patch, gpu-contracts.json, legacy-regression.json, actual-formats.csv, baseline/storage.csv and the raw-contracts files as necessary. The earlier source-matched run configurations/receipts and selected HDR/history/moments are in prior-runs/ with SHA256 provenance. Current 109 product sources match the deployed Unity package.

**F1 correction:** the actual old-format DX12 baseline stores radiance 1000 but saturates its second moment to 65504. All five baseline frames stayed finite, with history 1→5. Therefore this machine does NOT reproduce the earlier predicted Inf/history-rejection mechanism. It does reproduce incorrect HDR second moments. With RGBA32F, 255/256/1000/65504 constant fields preserve the expected first/second moments and history in both temporal kernels for five frames.

Unity 6000.0.85f1 / DX12 / RTX2080Ti: five legacy cases plus 277 recorded GPU stages pass their declared contracts. **200 of 277 are R1/R2 diagnostic stages**, whose pass conditions are finite output and preserved confidence, not image-quality acceptance. Unknown-center temporal RGBA/moments were also checked from saved raw readbacks after an explicit assertion was added; no full suite rerun was needed for that assertion. VerifyFormats only allocated/query-checked actual history/moments formats, with no scene run.

The existing screen-budget oracle passed 11381 plans / 95211 assertions. Existing 640x360, 0.5 scale, 128MiB budget still selects 320x180 with identity enabled. Additional logical moments storage is 921600 bytes (900KiB), not a measured total VRAM increase.

First fixture attempt failed because an ordinary UInt Texture2D requested unsupported Sample usage. The retry uses UInt RenderTexture with compute upload, as required by runtime Load/Store semantics. Its failure log is retained. The second bounded contract pass added missing all-pixel legacy checks, both-kernel black/unknown filter chains, actual Final output, and raw retention; no repeated scene matrix was run. No remaining F1/F2 integration question justified the optional 420-frame pair.

## Diagnostic results and next decision

R2 is reproducible in the fixed synthetic checker-noise input: filtered center goes from 0.44580078125 at history 3 to 0.2498779296875 at history 4 in both kernels, while temporal input/history remains fixed. The effective sigma field in the report is CPU-derived from actual stored moments and the unchanged formula, not a separate GPU readback. This demonstrates a synthetic threshold discontinuity, not measured real-scene flicker.

R1 remains undecided. The parallel-plane dark-window increment includes same-plane denoising; it must not be called causal cross-plane leakage. A future paired synthetic control should hold geometry/noise fixed and remove only the +3 right-side brightness increment before attributing a cross-plane contribution.

Astra Max independently found no runtime blocker for F1/F2, confirmed scope and key source hashes, and recommends submitting this package now rather than repeating GPU suites. It recommends R2 as the next bounded decision and the matched R1 control if needed. The guard's complete conclusion is in astra-review.txt.

Please independently review the actual diff and evidence, decide whether F1/F2 can be locally committed, and provide the next finite implementation/diagnostic plan (prefer R2 if evidence warrants). Keep all ten workstreams and G0-G5 open where evidence is missing. Do not expand to a new denoising framework or arbitrary quality/performance thresholds.

## Review outcome

GPT-6 Pro approved the F1/F2 local commit. Full response: LocalComparison/Review/denoise-02/gpt6-pro-review-and-next-plan.txt. The report's literal radianceFormat/momentsFormat strings describe expected fixture formats; actual-formats.csv queries actual fixture targets, not a live CameraState. The Final readback exercises Debug=0 in composite pass1, not production additive blending or native replacement. HDR cases in this package verify temporal storage; complete HDR filter guards belong to the next filter change. These distinctions do not block the approved local contract fix.

Next: denoise-03-short-history-transition, one candidate only. Let temporal sigma=max(4*sqrt(Vt),0.05); spatial sigma=max(4*sqrt(max(Vt,4*Vs/max(n,1))),0.05). For n<4 blend temporal→spatial sigma by saturate((4-n)/3); n>=4 keeps temporal sigma. Require first/mature-frame baseline behavior, smaller3→4 AND smaller maximum adjacent-frame change over the entire recovery window, valid output contracts, and report noise/reference/real-detail tradeoffs. R1 gets only a matched brightness control. If synthetic evidence supports retention, one finite real door recovery pair (<=420frames/side) must demonstrate coverage and assess actual artifacts; do not assume the synthetic checker is necessarily noise.
