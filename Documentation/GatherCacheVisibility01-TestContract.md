# gather-cache-visibility-01 — frozen observer contract

Baseline: `1647a88`. GPT-6 Pro iteration 7 authorizes one A configuration, at most 120 logical frames, with no algorithm change. Original full development scope remains open.

## Fixed observation

- A scene, five lights, static thinView, 640×360 full / 320×180 GI, feedback 1, original source and settings.
- GI pixels (160,45), (100,90), (220,90), (100,30); logical frames 0,1,3,7,15,31,63,95,119.
- Only the existing exact-software `CSTrace` call chain is instrumented. No new random draws, geometry/cache queries, alternate estimator, changed material bindings, seals, or source product parameters.
- Per selected thread, a private fixed 256-record stream (128 bytes/record), header count, logical/GI frame stamps, completion and overflow flag. Four lanes, no shared atomics. Other kernels compile no-op macros. No rerun for branch coverage.
- Record receiver position/Ng/Ns, actual direction/weight, world candidate and screen endpoint, winner, radiance/confidence, area sampling and suppression, accumulation boundaries, pre-half raw output and actual raw texture values.
- Cache contexts distinguish receiver guiding, direction-screen radiance, world radiance, and area-screen support suppression. Sequential call IDs identify each four-tap lookup. Record card/generation/owner identity, UV/base cell/fraction, entry/tag/anchor/normal/guide/irradiance, rejection stage, visibility inputs/result, bilinear weight and normalized result.
- Capture original scene meshes/submeshes/transform and Cull/alpha material support, current owner IDs/readiness and required surface-card metadata. Treat missing identity/material coverage as uncovered.

## Independent checks

- Reconstruct tap membership, tag/generation checks, orientation/plane rejection, bilinear weights and normalized cache value from records. Reconstruct returned endpoint radiance and gather sum including area contribution/suppression; receiver guide-only or rejected screen candidates do not count as radiance contribution.
- Use double arithmetic on recorded float inputs. Arithmetic tolerance is absolute 2e-6 plus relative 5e-5 for vectors/scalars, accommodating bounded float32 dot products, normalization, multiply-add and two-ray accumulation. Threshold decisions within 2e-6 of their boundary are reported as numerically ambiguous, not silently passed.
- Compare raw pre-half output to texture within one binary16 ULP (plus 1e-7 for subnormals); report measured error. No photometric or performance acceptance follows from this arithmetic tolerance.
- Independently intersect actual transformed triangles in double precision, respecting original material Cull and supported opaque coverage. Ng uses inverse-transpose source winding (including mirrored transforms). Compare both unshifted endpoint segment and the actual biased/shortened segment; only the latter checks implementation visibility. Distance tolerance absolute 2e-5 plus relative 2e-5; triangle-edge/segment-boundary ambiguity within 2e-5 is reported. Unsupported alpha/materials or geometry are uncovered, never assumed opaque. Short segments with no product query are explicitly skipped.
- Separate valid radiance (finite RGB and positive known/confidence according to product predicate), measured black, unknown (-1 raw alpha), and no receiver. Nonzero alpha is not validity.
- At least one cache lookup must actually enter a winning endpoint radiance computation. Otherwise report insufficient branch coverage without moving pixels or adding rays.
- Final consumption additionally requires a valid terminal pixel (a later unknown ray/area draw can discard all earlier sums), positive sample weight and nonzero material/AO/feedback coefficient. A known black cache still counts as consumed. Record ignored cache-return booleans and the actual returned structure: `HLGICachedSurface` may return false with a partial structure when totalWeight is tiny; ProxyRadiance and receiver guiding presently ignore its boolean. The observer must preserve that behavior.
- IDs, tags, generations, flags, stamps, discrete decisions away from an explicitly reported numerical boundary, and record counts are compared exactly. Arithmetic tolerances never apply to identity.

## Lifecycle and stop conditions

Archive exact original/instrumented bytes and source/settings hashes. Snapshot and restore the four test assets. Readbacks are command-ordered, retained until completion, admission closes before release. Observe the complete native post-exit log independently of process exit code.

Stop on observer compilation/dispatch/overflow/missing frame or stamp, nonfinite valid fields, fallback backend, or shutdown error. Preserve all evidence and return to GPT-6 Pro iteration 8; do not retry/tune the experiment or fix transport without a counterexample and review. No additional A/B/C matrices or 135-stage copies.
