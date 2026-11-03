# One current-quality all-source-off observation

Scope fixed before execution: original G1/G3 require light-off decay. Reuse the
existing black-environment floor/wall/hidden-emitter fixture at Release122 quality.
Do not repeat old WARP known-zero semantics or call the 126 green-to-blue result
a light-off result. Astra Max approved this single fixed event; no parameter
tuning, reference expansion, extra scene, automatic retry or new observer system.

One lane, GreenToOff. At source119, after recording its normal render and point
readbacks, set the sole bounded emitter MPB emission to black in that SAME engine
frame. Classify this as a local bounded-source edit, as in126: 1s old component
mean<=5%, 2s<=1%. Although this fixture then has no continuing source, the edit is
not a global environment change and does not get the5s global allowance.

Inputs: nonzero-reflectance white floor/wall, sole hidden unreadable analytic green
emitter; no native lights, baked lightmaps, SH, native reflection, other emitters
or environment Cube/constant radiance. Renderer settings remain960x540, GI480x270,
2rays/filter4/temporal and recursive feedback, observed floor/wall DXR plus the
existing analytic panel fallback. Full source GPU emissions must be zero at the
last recorded source; verify after drain without submitting another camera render.
The physical final source term is zero; no Monte Carlo/reference renderer is needed
to define that target. A finite-time estimate need not become bitwise zero.

Use the same27 predetermined regions. Map old sampledFull pixel centers to960x540
as126, then align each mapped point to its current GI full-resolution sample center:
full=2*floor(mappedFull/2)+1; gi=(full-1)/2. This is fixed before observation, never
selected from measured validity/color. Record old/mapped/full/gi coordinates.
Native top-to-bottom row order, linear FinalHDR and temporal RGBA are distinct
quantities. Do not mix these values directly with old126 differently aligned points.

Reuse full Capture at source0 and drain before further warmup; 0->1 preparation gap
is explicit. Sources1..119 and all response sources require consecutive engine IDs.
Nominal1/30s pacing waits<=34ms inside the same Update, not by skipping engine frames.
The event clock starts after source119 in that engine frame. Keep the existing
actual source timestamp/engine/work receipts, no Present/FPS or zero-overhead claim.

At119 and every response source, standard AsyncGPUReadback reads the existing Final
target and the camera's persistent history[readIndex].rt after its successful render.
Record returned temporal texture identity/index/size and bind both completions to
that same source receipt. No synchronous GPU source read or file IO in the response
window. Two requests per source, maximum8 outstanding; excess fails rather than
pausing or dropping observations. Do not destroy the borrowed history texture.

IMPORTANT validity meaning: finite history RGBA with alpha>0 proves a valid stored
temporal measurement, which MAY be retained old history. It cannot prove current
raw rays were fresh/known, physical correctness, or every filtered output's validity.
CSFilter retains center alpha on successful output but may reject geometry/results.
Therefore independently request the existing Capture on the terminal source, at the
same logical/work/engine frame, and inspect actual filteredD RGBA and its validity.
Terminal capture copies/writes and drain do not count as earlier source cadence.
Do not infer filtered validity at unobserved intermediate frames from history alpha.

End at the first source elapsed>=2.6s, before any source>3s. Keep512 source requests,
300s submission watchdog, real pending/readback drain, once-only timeout checkpoint
and ownership retention from126. Save full Final images at first>=2s and terminal
using the already-issued readbacks, write only after submission stops. On failure,
preserve actual output and insufficiency. No unapproved second observation.

Analysis:

* Full Capture0 must place all fixed full pixels inside the actual source floor
  (|y|<=1e-3, x in(0,5), z in(-3,3)), white diffuse within2/255 of.96, native-before
  RGB zero within1e-6. Source119 Final is finite positive green with other channels
  <=1e-6. All27 stay in the denominator; missing/nonfinite measurements are unknown.
* Report Final meanG/pre119meanG, each point's ratio to its own119G, luminance and
  other-channel values at actual times. For nearzero target, never divide by target
  zero or invent chromaticity/DeltaE. Do not call a held temporal estimate fresh.
* Record every temporal valid/invalid point separately; an invalid black cannot
  count as successful decay. Report the nearest observed samples before/after1s
  and2s. Late samples do not prove a prior strict deadline. Use source time, not
  callback completion or targetFPS conversion.
* A <=1% residual observation window may be reported only if it begins at a source
  time<=2s, spans>=.5s, includes every admitted source, has valid temporal data for
  all27 and no gap>2/30s. This is stored-temporal qualification, not all-frame filtered
  or current-raw-known proof. Apply the same distinction to any deadline claim.
* At the terminal source, actual filteredD and mask must be finite/valid at all27
  matching GI pixels. Report RGB and unknown count; do not replace invalid zeros or
  remove points. Compare its frame receipt with terminal Final/history, and confirm
  the last-source GPU scene emissions are all zero. No claim of bitwise physical
  convergence, unobserved presentation, or validity of intermediate filtered outputs.

Adoption closes only this fixed all-source-off observation: actual Final old-light
decay plus explicitly scoped temporal/terminal-filtered validity. If input, cadence,
source pairing, temporal or terminal validity is insufficient, retain insufficient.
No fullG1/G3, all lights/caches, ordinaryPlayer, motion or performance guarantee.
