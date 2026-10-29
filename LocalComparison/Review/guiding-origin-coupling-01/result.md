# Guide setting changed receiver geometry without an active guide

The current `CSTrace` prefix performs receiver world matching and replaces the
depth-derived geometric normal only when `_HLGI_GuideWeight>0`. Consequently an
empty guide still lets the setting change the bias origin and encoded history
geometry. The direction sampler has mixture zero in both cases, so this changes
the traced integrand independently of sampling probability.

The baseline executes the actual `CSTrace` entry prefix through GeometryOut and
its actual origin/sampling expressions. Actual production `WorldPosition`,
`NormalAt`, depth derivative/normal reconstruction, screen footprint,
`HLGITryScreenWorldMatch`, geometry encoding and the complete transport sampler
execute unchanged. Depth/material resource storage is adapted to immutable input
arrays; world visibility independently intersects an opaque finite y=0 patch;
cache lookup is an explicit absent-guide dependency. This is not a complete
scene, physical GPU, DXR/atlas consumer or image-quality test.

Eight inputs were fixed before the first dispatch: tilted depth neighborhood,
aligned neighborhood, world-query miss and unreliable depth support, each with
guide weight zero and default 0.35. The center belongs to the actual horizontal
patch while the tilted neighboring samples follow y=-0.2x. Their linear depth
predictions are valid, and the finite plane intersection satisfies the actual
world-match distance and normal-agreement gates.

| Target | Guide 0 | Guide 0.35 |
| --- | --- | --- |
| Actual ray origin | (0.005883496, 0.029417420, -0) | (0, 0.029999999, 0) |
| Encoded geometric-normal code | 15378774 | 16775169 |
| World-match/cache queries | 0 / 0 | 1 / 1 |
| Guide returned | zero | zero |

The actual direction, weight and final RNG bits match in every pair. World-miss
and unreliable-depth controls preserve origin/GeometryOut bytes. An independent
small-rectangle construction using the measured input rays demonstrates that
the differing origins can change visibility; it is deliberately not reported as
a product RGB result.

The first post-dispatch analysis failed because the aligned control compared
origin bytes and encountered z=-0 versus z=+0. Its script, raw bytes and failure
record remain under `baseline`. `analyze_signed_zero.py` qualified the same data
using exact IEEE numerical equality only for that signed-zero coordinate;
GeometryOut and all direction/weight/RNG byte comparisons remain unchanged.
It does not claim signed zero is interchangeable in every subsequent operation.
No WARP rerun or tolerance change was used for this qualification.

Before that dispatch, one preparation failure exposed the reused extractor's
missing `void` support; one compile failure exposed an unadapted uniform storage
declaration. Both snapshots remain in `preparation-failed-01` and
`compile-failed-01`. Neither reached GPU execution.

The temporary candidate changes only two gate lines in a copied
`HybridLumenGIKernels.hlsl`: receiver world matching depends on `hasGeometry`,
and cache-guide lookup alone retains the `_HLGI_GuideWeight>0` gate. Its one WARP
dispatch consumes the exact same input bytes. All four default-0.35 complete
368-byte output records remain byte-identical to baseline. Every paired origin,
weight, direction, RNG and encoded geometry now matches byte-for-byte; guide-zero
cache queries remain zero. World-miss geometric results are unchanged, and the
unreliable-depth complete records are unchanged.

This retains the matched actual surface normal, which is correct for the center
patch in the counterexample. Forcing both modes to retain the neighboring
screen-derived tilt would instead change existing default behavior and diverge
from `TraceScreen`, which already refines reliable geometry independently of
guide weight. The candidate adds one short visibility query and its footprint
per valid GI receiver with reliable depth geometry when guide weight is zero;
it adds no guide-cache lookup and no per-ray matching loop. No GPU-time claim is
made, and no new native scene run is required to establish this input-coupling
repair.

The source-matched WARP host is reused unchanged. Candidate
`analysis.json` records all controls and hashes. Baseline raw SHA256 is
`713d2d0cbe7cc97cbbd9033112c1f81c9473d4f3676ebcfea0b172e09ef6bb95`;
candidate raw is
`5a9daacb13048541953f8f3a0c7814793a149913a32578b99a19fda9ee0c0fa9`.
The unchanged input hash is
`c5b4c600583d78da73f7506e834affeaea72632d4a251a594aca412fbc5c07a8`.
The candidate product-file hash is
`68bdfe49b2c8b09a52722bc5ba7dcb7045be016359d6682e380269116df67455`.

Repository Runtime was not edited by this lane. Parent integration and full-entry
compilation remain separate. Retention is justified by the concrete original
coupling, same-input correction, default-path bit preservation and explicit
zero-guide query cost. It does not establish default guided-image accuracy or
overall dynamic stability, and does not replace the frozen finite-feedback
reference with new expected values.
