# Finite rectangle color-bounce reference

This is a prospective current-source reference, not a native result or a revival
of the old six-point Monte Carlo reference. It has no imported product RGB,
material-evaluation helper, cache, sampling PDF or ray-hit answer.

## Scene and independent quantity

The only reflecting source is the rectangle `x=0`, `y in [0,2]`, `z in [-2,2]`,
with geometric and shading normals `+x`. Authored vertices are `(0,0,-2)`,
`(0,2,-2)`, `(0,2,2)`, `(0,0,2)`; triangles `012` and `023` have the required
winding. The horizontal receiver is at `y=0`, normal `+y`; use interior floor
pixels on the `+x` side. The receiver floor can span `x in [0,5], z in [-3,3]`.
No additional geometry may intersect the selected upper-hemisphere rays.

One white directional light points toward `+x` from the shading point, intensity
one, shadows off. It produces constant `D_direct=1` on the wall and zero direct
diffuse on the floor. URP-relative lighting units are used; multiplying wall
diffuse by this value needs no additional division by pi.

Use ordinary URP Lit, metallic workflow, metallic zero, no maps or emission,
proxy tint white. Set the wall's renderer MPB `_BaseColor` to shader-space
`(.5,.25,.125,1)`. This intentionally avoids an authoring-color conversion:
MPB values are already shader-linear. Independent source diffuse is
`rho=.96*(1-metallic)*baseColor=(.48,.24,.12)`, below the world's `.98` cap.
These are authored inputs; do not infer them from captured material or GI colors.
Freeze the actual scene/material/MPB/light/settings and source hashes before
native capture. The supplied `source-contract.json` is a proposed contract,
not proof that Unity received it.

Set feedback, guide weight, emissive proposal weight, area emitter count,
screen steps, environment and radiance clamp to zero. The source must use the
exact triangle material path with current bindings; its color cannot be supplied
by the white proxy fallback. This single-bounce diagnostic does not certify the
default combined algorithm.

Compare **CSTrace raw D=E_indirect/pi**, before temporal/filter/composite.
`IndirectOnly` is not this quantity: its composite multiplies receiver diffuse,
AO and intensity. Final also contains native lighting and other composition.

## Closed form and fixed-ray decision

For receiver origin `(d,y0,z0)`, let `a=max(yMin-y0,0)`, `b=yMax-y0`,
`z1=zMin-z0`, `z2=zMax-z0`. If `b<=a`, the source is outside the receiver
hemisphere. Otherwise:

```text
A(h) = [atan(z2/sqrt(d²+h²)) - atan(z1/sqrt(d²+h²))] / sqrt(d²+h²)
F = d/(2*pi) * [A(a)-A(b)]
expected raw D = F * rho * D_direct
```

This integrates the independent area kernel
`d*y/[pi*(d*d+y*y+z*z)^2]`. `reference.py` also evaluates that original two-
dimensional integral by tensor Gauss-Legendre quadrature for a mathematical
cross-check. No stochastic reference paths or empirical confidence intervals
are required. The analytic answer is the infinite-sample mean; it is not a
pass threshold for an individual noisy product frame.

The native decision instead uses a few fixed receiver/frame groups. Export only
their actual biased ray origins and input directions (format in
`ray-input-example.json`, which is explicitly synthetic). Independent ray/plane
and rectangle tests yield an exact finite hit count. With pure cosine sampling,
each ray has weight one: `finiteRawExpected = hitCount/rayCount * wallRadiance`.
Unknown product measurements must not pass as black. Ray/edge classifications
within a fixed float32-derived guard are marked ambiguous; no guessed answer or
post-hoc threshold widening is allowed.

A separate diagnostic compute may reproduce the **input** directions using the
current sampler's unchanged hash/random/cosine functions, same GI pixel, same
actual `Work.frame`, `normal=+y`, and the complete random stream for all samples.
It must not read product RGB/hits/PDF as answers. Under the frozen zero-guide/
zero-emissive inputs there are three RNG draws per direction and no area draws.
`CameraDiagnostics.frame` is incremented after recording, so it is not blindly
interchangeable with `Work.frame`. This route proves transport conditional on
those directions, not the correctness of the sampling distribution. If the
replayed directions cannot be tied to the actual dispatch, report that source
gap instead of treating a color mismatch as an algorithm defect.

The shader ray bias moves the floor origin to `y=.03`. Finite comparisons use
that actual origin. `analytic-reference.json` lists both physical `y=0` and
biased `y=.03` results; it never silently compares different geometry. The
trace-distance guard requires the full rectangle to fit within the finite query.

`evaluate_group(source, group)` returns the finite expected RGB without accepting
an observed RGB argument. `compare_raw(source, reference, observedRGBA)` is a
separate subsequent step. It accepts only positive-confidence finite samples and
the predeclared binary32 arithmetic envelope followed by the RNE/RTZ binary16
storage envelope. A separate native temporal check observed RTZ UAV narrowing
before any color run; Python's nearest rounding is not assumed to represent that
write. The lower endpoint truncates the positive arithmetic lower bound; the upper
endpoint rounds its upper bound to nearest. Arithmetic bounds are unchanged.
Exactly zero remains exact zero. A factor-of-pi error or
swapped source channels fails this finite comparison regardless of Monte Carlo
noise; native classification/source closure must pass first.

## Existing checks and integration entry

`test_reference.py` passed eight tests: analytic versus original area kernel at
five origins, symmetry/partition/scale identities, hemisphere and infinite-plane
limit, units/reflectance, fixed-ray colors/black and negative controls, explicit
edge ambiguity, isolation guards and finite-distance coverage. The deterministic
quadrature comparison is a consistency check, not a claimed rigorous quadrature
error certificate. The final output is in `math-validation.log`.

```powershell
python reference.py --source source-contract.json --rays actual-rays.json --output run-reference.json
```

The output records source/ray/reference-code hashes and refuses overwrite.
The main agent owns Unity scene integration and native capture. The scoped native
result below does not establish final-image quality, performance, multi-bounce
convergence or production acceptance.

## Native pure-input sampler interface

`generate_sampler.py --compile` freezes the current source function bodies into
`generated/FiniteWallReferenceInputs.compute`, with three adjacent include files.
The first full `CSReferenceInputs` DXC cs6.0 `-O3` compilation passed; the manifest
records source hashes, generated hashes and the compiler command. The shader
replays actual `NormalAt`, `WorldPosition`, full-resolution sample addressing,
depth-derived unquantized Ng and the disabled-guide cosine RNG path. It reads no
product raw color, material, PDF, cache or intersection output. Do not decode
history Ng for the bias: history uses quantized oct12+12 and is not the original
Ng used by CSTrace.

Bindings:

- Kernel: `CSReferenceInputs`; dispatch `ceil(pixelCount/64),1,1`.
- `StructuredBuffer<uint2> _ReferencePixels`, `_ReferencePixelCount`.
- `RWStructuredBuffer<float4> _ReferenceRows`, capacity `pixelCount*8*6`.
- Full-resolution `_HLGI_Depth` and `_HLGI_Normals` from the actual gather.
- `_HLGI_Size=(giWidth,giHeight,1/giWidth,1/giHeight)`, `_HLGI_FullSize` similarly.
- Actual `_HLGI_InvVP`, `_HLGI_View`, `_HLGI_NormalsOct`, `_HLGI_RayBias`,
  `_HLGI_FrameIndex=Work.frame`, `_HLGI_Rays`, `_HLGI_GuideWeight=0`.

Each selected pixel has eight 96-byte rows; unused rows are zero. Each row is
six float4: origin/valid, direction/zero, receiver/rawDepth, Ns/one, Ng/hasGeometry,
and `asfloat(uint4(pixelX,pixelY,Work.frame,sampleIndex))`. Decode the last row as
four **uint32 bit patterns**, not a numeric float cast.

`decode_sampler.py --native-outputdir CAPTURE_DIR` reads only
`sampler-inputs.bin` and `tap-receipt.json` from the native tap. It creates
`rays-native.json` without opening product color, geometry or material readbacks.
It checks the completed receipt, all 27 target/offset selections, bit-preserved
pixel/frame/sample identities, finite values, unit upper-hemisphere directions,
consistent per-pixel inputs, floor position, Ns near +y, unit floor-facing Ng,
and origin equal to receiver plus Ng times the frozen ray bias.

Camera closure uses the receipt's actual matrices: project each receiver to its
exact full-resolution depth-sample center, and independently intersect a camera
ray with the authored floor. Projection uncertainty is fixed before native
execution at `256*float32_epsilon*max(textureDimension)` pixels; world intersection
uncertainty is `256*float32_epsilon*max(1,worldCoordinateMagnitude)`. This guards
float32 matrix arithmetic, not radiance comparison. Each receiver's world
distance from its authored target is recorded and bounded by the declared +/-2
GI neighborhood's +/-3-pixel outer footprint. The shader's actual reconstructed
inputs still determine finite ray hits; these CPU calculations only check their
provenance. Unity's indexed Matrix4x4 receipt is column-major and the frozen DX12
projection has top-origin UV. Eight decoder tests include unrelated valid-floor
positions, wrong pixels, wrong ray bias and incomplete receipt negatives.

The generic `--rows`, `--metadata`, `--output` route remains available for explicit
synthetic fixtures (`pixelCount`, `pixels`, `raysPerPixel`, `workFrame`, `giSize`).
After native decoding, generate the reference separately:

```powershell
python reference.py --rays CAPTURE_DIR/rays-native.json --output CAPTURE_DIR/finite-reference.json
```

Both commands refuse to overwrite their output. Product source/dispatch closure,
frozen scene settings and active exact backend qualification remain the main
harness's responsibility.

`compare_native.py --native-outputdir CAPTURE_DIR` first rebuilds and saves the
finite reference from `rays-native.json`, with no observed-color argument. It then
checks the scene's actual mesh vertices, transforms, normals, MPB colors, light,
settings and completed hardware-ready receipt; checks the complete current
product inventory against the instrumentation manifest; checks the input sampler
against both its original extraction manifest and current function bodies; and
checks the temporary feature differs only by its gather observer call. Only then
does it open `raw.rgba32f` and compare the 27 selected pixels using the already
frozen storage intervals. It writes `finite-comparison.json`, including per-pixel
finite hit counts, expected/observed RGB, source hashes and negative controls.
The disabled spatial-light selector's `lightCapacityOmitted=-1` is a diagnostic
sentinel; the one actual enabled directional source and `lightSelected=1` close
this scene's light count. A failed pre-capture readiness observer is not a native
color failure.

## Current native result and retained qualification failure

`finite-wall-color-reference-01` completed 180 explicit camera/context requests
but did not select a raw capture: its observer incorrectly required the disabled
spatial selector's diagnostic to equal zero. That infrastructure failure and the
empty-scene restoration issue are retained in the first attempt. The next native
attempt changed those observer details without changing product transport,
physical source inputs, sampler, or radiance thresholds.

`finite-wall-color-reference-02` captured one complete current-source DX12 gather
with 27 selected pixels and eight directions each. The original frozen decoder
then failed its `64*epsilon*worldScale` floor-height heuristic for 18 pixels.
Those failures and the original files remain unchanged. The independent analysis
and API-based raster snapping argument are recorded in
[input-qualification-notes.md](../../Review/finite-wall-color-reference-02/input-qualification-notes.md).

The separate `qualify_native_inputs.py` uses the actual VP and authored floor to
derive a planar depth interval from the specified eight-bit raster coordinate
snapping rule. It also checks the actual invVP reconstruction through outward
float32 arithmetic intervals. All 27 inputs pass that explicit source-consistency
qualification with their original depth, origin and directions. The result does
not claim to bound every permitted forward-projection/clipping implementation.
No GPU run was added and no product RGB was used to derive the input interval.

`compare_qualified_native.py` then builds the independent finite expected values,
closes the actual scene and 112 product/eight observer source files, and only then
reads raw RGB. All **27/27 groups pass** the unchanged radiance/storage intervals.
The 216 directions contain 47 rectangle hits, with group counts zero through
four. Extra pi division, swapped channels and unknown-measurement controls fail
as intended. The original decoder, reference and comparator hashes remain fixed.
This proves conditional current-origin/direction, single-bounce raw `E/pi`
consistency. It is not a claim about default multi-bounce or final-image quality.

Reproduce the separate qualification/comparison on a new output destination:

```powershell
python qualify_native_inputs.py --native-outputdir CAPTURE_DIR
python compare_qualified_native.py --native-outputdir CAPTURE_DIR
```

The outputs refuse overwrite. Existing evidence is
`finite-wall-color-reference-02/native/rays-native-qualified.json`,
`finite-reference-qualified.json`, and `finite-comparison-qualified.json`.
`execution-receipt.json` archives commands, outcomes and source hashes; individual
test logs retain the mathematical, decoder, comparator and qualification checks.
