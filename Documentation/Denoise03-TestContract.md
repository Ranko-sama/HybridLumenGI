# denoise-03: one short-history transition candidate

Baseline 5eb1058, approved by GPT-6 Pro. Only CSFilter's variance-to-sigma section may change. Temporal/history/moments, geometry/material/identity, formats, budgets, filter support and spatial cap remain identical.

Candidate: temporalSigma=max(4*sqrt(Vt),0.05), spatialSigma=max(4*sqrt(max(Vt,4*Vs/max(n,1))),0.05). For n<4 use lerp(temporalSigma,spatialSigma,saturate((4-n)/3)); n>=4 retains temporalSigma. One candidate, no parameter sweep.

## Predeclared synthetic experiment

Use the existing17x17 fixture and actual kernels. Both temporal variants feed filter1/2/4; history feedback remains unfiltered. Same seed, input and setup for baseline/candidate. Record all stages for frames1-8,32,64; temporal accumulation runs every intervening frame. Set maxHistory64 for this experiment so64 is an actual mature-history sample.

- Fixed checker (0.25/0.75): only threshold causality, not an assumption that all high frequency is noise.
- Changing noise: deterministic per-frame pseudorandom ±0.25 around a declared uniform0.5 reference; quantify recovery-window reference RMSE and mean bias.
- Noiseless checker and noiseless illumination edge: reference is the exact input, quantify detail/edge bias separately. The fixed checker readbacks serve both causality and detail interpretations rather than duplicating dispatches.
- Parallel-plane matched pair: identical geometry/noise/history, right side brightness +3 versus +0. Report dark-side difference as sensitivity to the bright-side signal, not automatically physical leakage. Do not change plane weights.
- Black, unknown center, unknown current/validated old history, reset, identity rejection and HDR1000/65504: full filter chain, all components finite, confidence validity and expected constant fields. Reuse storage/budget checks from denoise-02.

Prior format tolerances remain: radiance max(0.001,abs(value)*0.001); moments max(0.001,abs(expected)*0.000003); confidence/history0.001. Unknown output/moments expected zero. Pairwise temporal/history/moments and first/mature filtered stages should be bit-identical given identical inputs; report any difference rather than loosening the tolerance. A reduction in the fixed-checker3→4 maximum RGB change AND maximum adjacent-frame change across1→8 must exceed0.001 (a conservative half-float step in this0..1 signal range). This is a numerical discontinuity criterion, not a production image-quality threshold.

Report whole-image and full-support interior statistics; 1+2+4 sampling radius7 leaves3x3 interior on17x17. Reference error, bias and edge detail must accompany continuity; do not accept a smoother curve that merely relocates a large jump or conceals a material quality tradeoff.

If the unique candidate fails necessary criteria, restore the approved runtime shader and return evidence to Pro. No real-scene run is needed for a failed candidate. If supported, one bounded real door-stop/disocclusion pair must identify actual pixels whose history grows through the transition, with raw/history/moments/final event-window captures; uncovered events are explicitly unverified. Each side<=420frames. No performance claims from capture runs.

## Real event pair fixed before interpreting its output

Synthetic continuity passed; noise RMSE tradeoff is concentrated at frames2(+3.1%) and3(+16.2%), despite the window aggregate+0.70%. Astra allows one real event pair to investigate, without endorsing retention.

Each side runs198 logical frames, with raw/history/moments/geometry/material/final captured every frame176–196. The scene and settings are the existing functional sequence. The original denoise-01 door interior ROI is reused: full pixels x340..399,y144..249 (GI x170..199,y72..124), fixed before inspecting this pair. Door stops at180. Analyze the static180–196 segment, while earlier176–179 establishes recovery context. Select every valid pixel in this ROI whose actual stored history grows1→2→3→4 and whose geometry/material remains stable over that sequence; do not select by apparent improvement. Also report whole-image coverage separately. If no qualifying door pixels exist, mark the target event uncovered.

Check both sides' settings, raw/history/moments, dimensions, logical/GI frame identities and motion/light/camera snapshots before attributing final changes. Capture-only source modifications are identical on both sides and archived with original/instrumented SHA256. The raw readback is enqueued immediately after gather in the same command buffer, with immutable callback metadata; shutdown drains all requests. Restore and hash-check original product Feature and harness files after the pair. No performance or full-product-source-identity claim applies to the instrumented runs.
