# Finite real-geometry cache feedback preparation

This directory prepares the next bounded reference. It has not run Unity, a
Player or a GPU dispatch. Four input-only compute kernels compile with DXC
`cs_6_0 -O3`; their explicit `#pragma use_dxc` is required by the metadata
kernel's nine UAV outputs. It changes no Runtime or
previously frozen reference. The old `cache-energy-decay-reference-01` already
proved an ideal paired-hit operator over 512 rounds. This work does not repeat
that fixture: its prospective inputs are actual directions at two finite,
perpendicular rectangles; intersections and visibility are computed independently.

## Exact quantity, iteration and scattering count

For each surface, the stored cache is indirect incident `C=E_indirect/pi`.
Outgoing light at a hit is `L=rho*(d+beta*C)` here, with unit AO, no emission,
and `d` the ordinary URP-relative direct diffuse quantity. There is no additional
pi division. Cache updates do not multiply the receiving patch's reflectance.

The enabled world path is specifically `CSUpdateCache -> ProxyRadiance ->
HLGICachedSurface`, followed by `CSTrace -> ProxyRadiance -> HLGICachedSurface`.
The `CachedIrradiance` convenience wrapper is used by the screen-hit path;
`screenSteps=0` deliberately excludes that path here. This preparation must not
be reported as native execution of that wrapper simply because both read cached D.

The Feature binds every cache update to the previous buffer, then binds gather
to the completed new buffer. The update is relaxed Jacobi:

```text
estimate_i(k) = mean_over_actual_rays rho_hit * (direct_hit + beta * lookup(C(k-1)))
C_i(k) = (1-alpha_i(k))*C_i(k-1) + alpha_i(k)*estimate_i(k)
samples_i(k) = min(preparedSamples_i(k-1)+1, 32)
alpha_i(k) = max(1/samples_i(k), .1), or 1 for no valid previous measurement
```

Every patch estimate in one round reads `C(k-1)`, including a patch whose peer
was already visited by the CPU reference. Same-frame gather reads `C(k)`.
Changing the program to sequential peer updates would invent a higher scattering
order within one dispatch.

Starting from zero indirect light, count diffuse scatterings before the visible
camera receiver separately from applying that receiver's reflectance:

| Signal | Maximum preceding diffuse scatterings |
| --- | ---: |
| Cache after first positive update | 1 |
| Cache after second positive update | 2 |
| Raw gather after second update | 3 |
| Its contribution after visible receiver rho | 4 |

Thus this is **two cache updates plus one gather**, not a two-bounce result.
History blending retains lower orders; it does not add a scattering event.
The output includes each order separately so a combined sum cannot hide a
wrong order, repeated reflectance or wrong read buffer.

## Known-zero initialization without invented cache colors

Prefer actual zero-light warmup until both active patches have valid measured
black, stable current tags/generations and complete exact geometry. The observer
must verify the initial RGB is exactly zero in a separate observation check.
Those observed values are not operands to the independent reference, which
starts from the authored boundary condition zero. Sample counts and identities
are scalar state metadata, not radiance answers.

Then turn on the one actual directional light, leaving settings and geometry
unchanged. Its first directional-light change should give `globalReactive=1`,
no hard geometry change: old sample counts shorten to one and commit to two,
so `alpha=1/2`. The following unchanged update commits count three and
`alpha=1/3`. Capture the actual global change inputs, region table, masks and
tags; do not assume frame numbers imply those conditions. If startup causes an
epoch/owner reset, reject this prospective sequence instead of silently calling
the invalid entries measured black.

Cold all-zero 80-byte storage has invalid measurement confidence and tags. It
means a zero initial numerical iterate, not measured black. Its first successful
commit has alpha one; the second has alpha one half. The mathematical control
demonstrates that this distinction changes the third-order result by a factor
of three in the synthetic finite fixture.

## Prospective geometry and independent finite operator

- Wall A: `x=0`, `y,z in [0,1]`, normal `+x`.
- Wall B: `z=0`, `x,y in [0,1]`, normal `+z`.
- Interior is `x>0,z>0`; no floor, other geometry, environment or emitters.
- White directional light toward `+x`: A direct quantity one, B zero.
- Shader-linear MPB base colors A `(.5,.25,.125)`, B `(.125,.5,.25)`.
  Metallic-zero Lit gives rho A `(.48,.24,.12)`, B `(.12,.48,.24)`.
- One exact chart per wall, cache grid one, both patches updated, guide zero,
  feedback one, no screen tracing, AO one, no clamp or temporal/filter effects.
- Fixed prospective cache rays 16 per patch per update; gather rays eight.
  These are finite estimator inputs, not samples added to approximate a truth.

With one valid cache entry in a chart, bilinear tap weights normalize to exactly
one. For chart UV in `[0,1]^2`, its surviving weight is
`(1-abs(u-.5))*(1-abs(v-.5))`, between one quarter and one, so the normalization
is well conditioned and above the existing tiny-support gate. Its unnormalized
value need not be exported as an answer. The reference
uses independent rectangle intersections and connection visibility, then its own
cache recurrence. It does not accept product hit IDs, PDFs, weights, incoming
radiance, measured RGB, or cache RGB as oracle inputs.

Actual capture anchor position, Ns and decoded Ng must be retained. The surface
atlas geometric normal is quantized; it is not automatically identical to an
axis-aligned mesh normal. The one-unit wall size keeps a useful margin in the
same-plane cache gate for these coarse normals, but the actual input gate still
has to be checked. Actual biased origins, not ideal anchor centers, define the
independent rays.

The `finite_reference.py` tool supports the two-step mathematical operator and
its scattering-order decomposition. It explicitly keeps native acceptance false:
geometric card/atlas support, execution identity and the float32/storage error
budget must be closed before comparing native output. It is not a physical
steady-state solver or a new broad Monte Carlo package.

## Smallest useful capture interface

Use temporary test-project observers around the real Feature's Execute boundary;
do not edit product shaders to export hits or radiance answers for the oracle.
Record exactly the first two positive-source updates after the known-black
bootstrap, with the actual `Work.frame`, `Work.cacheRead` and epoch. The CPU
state's cache index has already advanced during graph recording, so it is not
an interchangeable substitute for the Work snapshot.

1. After material capture and scheduler preparation, before `CSUpdateCache`,
   dispatch a geometry/input-only diagnostic. Reuse unchanged hash/random/cosine
   functions and actual anchor selection/addressing. Guide zero removes the need
   to read guide RGB. Preserve all three RNG draws per sample and the cache RNG
   domain `0xA511E9B3`; gather uses `0x63D83595`.
2. After `CSUpdateCache`, read back its actual old and new 80-byte entries, with
   physical buffer labels. These are separate observations for comparison and
   continuity, not input to expected RGB. The next round's old bytes must equal
   the previous round's new bytes, and the old buffer must remain unchanged
   during the simultaneous update.
3. After the second gather, reuse the existing geometry-only screen sampler and
   raw E/pi tap. Choose fixed receiver pixels on both walls from actual VP.
   The previous floor-specific decoder cannot be reused unchanged for these
   vertical receivers. Native depth/position qualification must be source-based.

Suggested cache diagnostic layout: eight float4 per ray (128 bytes):

| Row | Contents |
| --- | --- |
| 0 | actual biased origin.xyz, input-valid marker |
| 1 | direction.xyz, zero; no product weight/PDF |
| 2 | actual surface anchor.xyz, zero |
| 3 | actual Ns.xyz, zero |
| 4 | decoded surface Ng.xyz, zero |
| 5 | raw uint bits: entry, card, cellX, cellY |
| 6 | raw uint bits: ownerSlot, Work.frame, epoch, ray index |
| 7 | raw uint bits: atlasPixelX, atlasPixelY, generation, update mask |

Both walls at 16 rays use only 4096 bytes per update. Read-only metadata also
needs old sample count, tags, stored anchor/normal, card 128-byte records,
owner/primitive-to-chart identities, global reactive/hard-change scalars and
region table. Old cache RGB is forbidden in the generator's input schema.

One static geometry-only atlas snapshot is sufficient if two-frame hashes prove
it is unchanged: each active card's position/depth, Ns, emission-alpha geometric
normal/coverage code, world-to-card matrix, atlas rectangle and tolerance.
No diffuse or emission RGB is needed as an oracle value. At tile resolution 32,
two 30x30 interiors with three geometry float4 rows are about 86 KiB. This lets an
independent lookup certify that each geometric ray endpoint resolves the intended
card/texel, with correct geometric layer and anchor visibility. Reading the
product's `materialResolved`, cache-use boolean, hit record or normalized weight
would not substitute for this support certificate.

The public `surfaceCache.BindCompute` method already binds these inputs to a
diagnostic shader; card metadata/anchors are private C# buffers but public shader
inputs, so no persistent API or product buffer format needs to change. A helper
may read emission **alpha only** for its geometric code; it must not output RGB.
Keep a clear split between geometric input snapshots and 80-byte cache output
observations. Source constant materials and committed triangle records still
need the ordinary source-hash/identity closure used by the first finite reference.

## Preparation checks

Five pure CPU tests pass: real rectangle hit/miss geometry, exact two-step
coefficients and scattering parity, cold versus measured-zero history, rejection
of answer fields, and same-buffer/edge-ambiguity negatives. A synthetic four-ray
fixture is included only to make the coefficients readable; it is not a native
capture and does not redefine the prospective 16/8 ray configuration.

For its half-hit geometry and measured-black sequence:

```text
C_B(1) = rho_A/4; C_A(1)=0
C_A(2) = rho_A*rho_B/24; C_B(2)=rho_A/3
gather_B = rho_A/2 + rho_A^2*rho_B/48  [orders 1 and 3]
gather_A = rho_A*rho_B/6              [order 2]
```

The executable native preparation below fills the source-support gap under an
explicit limited geometry/precision contract. No actual product defect was
established by this source audit, and no new GPU run has been started by this lane.

## Executable native preparation

`generate_native_sampler.py` freezes the actual hash/RNG/cosine functions and
actual screen position/normal decode functions into four input-only kernels.
`CacheFeedbackFiniteTap.cs` records three separate command boundaries at logical
frames 31, 32 and 33. Black warmup is exactly 32 actual gathers with the light
disabled and intensity one; frame 32 enables the light normally, frame 33 is the
next update. If fixed warmup is not ready/known black, collection fails. There is
no adaptive warmup or RGB-based frame selection.

The receipt is `frame-NNN.json`. Geometry/scalar files are
`frame-NNN-{cards,owner-ranges,card-indices,anchors,mask,owner-identities,cache-state-inputs,globals,changes,cache-inputs,atlas-inputs,gather-inputs}.bin`.
The separate observations are `cache-before.bin`, `cache-old-after.bin`,
`cache-new-after.bin` and `raw/geometry/material.rgba32f`, with the same frame
prefix. Metadata is 128 bytes per card, 64 bytes per cache scalar/geometry entry,
128 bytes per cache ray, and 96 bytes per gather ray. The source atlas contains
position/depth, normal and emission **alpha** only. Cache scalar inputs contain
sample count, tag, anchor and normal, never irradiance or guide RGB.

The two reference receiver centers are A `(0,.5,.5)` and B `(.5,.5,0)`.
Actual VP projects each center and picks a 3x3 offset set `(-2,0,2)` pixels on
both axes, giving 18 groups of eight directions. The GPU diagnostic uses the
actual Work frame, depth, normals, view/inverse VP and resolution. No measured
hit, PDF, contribution, normalized weight or cache-use flag is exported.

`atlas_support.py` verifies CPU triangle-to-card upload bindings against GPU
cards/current owner identities, masks, covered anchor geometry, actual stored
octahedral anchor Ng, coverage/depth and all potentially addressed neighboring
atlas texels. It independently tests geometric lookup support and proves cache
connection visibility from the convex positive-x/z region. Uniform absent
support contributes zero feedback; mixed or near-threshold support fails
qualification. This is not direct observation of each RayQuery committed binding.
Finite diffuse/emission values follow from constant materials, the captured
geometry and hash-matched capture source; their RGB is not an oracle input.

`screen_input_qualification.py` checks the 96-byte inputs against each authored
vertical plane, actual matrices and the D3D raster snap interval. It preserves
actual input origins and directions. `numeric_reference.py` then applies the
independent finite-rectangle intersections and qualified atlas support to three
windows, starting from authored exact zero. Every cache step reads the complete
old expected vector; gather reads the newly calculated expected vector.

The arithmetic contract is described in `numeric-contract.json`: source
`float32(.96)` reflectance, constant-axis normal budget, explicit reciprocal
error, correlated one-cell `e*w/w`, 16 ray accumulations, sample alpha and lerp,
eight gather accumulations, then the predeclared RTZ/RNE binary16 envelope.
The old one-bounce `gamma32` envelope is not reused for the whole chain.
Black remains exactly zero. The observed old/new cache RGB never enters this DAG.

Run after the parent freezes the reference and completes the native package:

```powershell
& 'C:\Users\Administrator\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' -B LocalComparison/Reference/CacheFeedbackFinite/compare_native.py --native-outputdir <absolute-native-output> --package LocalComparison/Review/cache-feedback-finite-01
```

The comparator first closes the frozen Runtime/observer/reference source hashes,
actual scene/material/light/settings and pure input metadata, then writes
`finite-feedback-expected.json`. Only afterward does it open cache/raw RGB. It
compares six updated cache entries and 54 receiver groups, validates full
old-buffer immutability and cross-frame read/write equality, checks measured
black, finite guides, tags and counts 2/3, and rejects extra pi, swapped channels,
unknown output and a stale-zero second-order cache. Seventeen CPU tests cover the
mathematics, atlas ABI/identity/coverage decisions, full screen input ABI and these
numerical/storage negatives. Commands and output are archived in
`native-preparation-validation.log`.

The native result is intentionally conditional: each independent rectangle hit
uses a predeclared position box of `64*2^-23*max(1,idealRayT,abs(world))` per axis.
There is no portable DXR `CommittedRayT` localization theorem establishing that
box. Neighboring-texel consistency and generous geometric margins test this
implementation class; they do not turn the assumption into a hardware guarantee.
The planar screen qualifier likewise checks source consistency, not every
possible forward-raster arithmetic implementation. A pass would establish the
finite current-input feedback chain (cache orders up to 2, raw gather up to 3,
visible receiver up to 4), not default-feature multibounce accuracy or steady state.
