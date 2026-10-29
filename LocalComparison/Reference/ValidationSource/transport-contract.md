# Independent diffuse picture reference

This tool produces an **approximate, independently rendered picture** from the
Validation v2 physical source and frame state. It never opens candidate RGB,
filteredD, masks, support textures or HLGI caches. It is useful for visible color
and temporal-residual comparisons, with the model differences below. It is not a
complete native URP camera renderer or a strict absolute-error certificate.

## Source interpretation

`materials.py` interprets constant, opaque, metallic-workflow stock URP Lit.
Ordinary Material `_BaseColor` uses the standard sRGB transfer function; a recorded
property-block color is already a shader-space vector. HDR `_EmissionColor` is
linear and contributes only when `_EMISSION` is enabled. Unbound textures use the
stock default constant. Bound textures, alpha clipping, normal/parallax/detail
mapping, transparent or nonstandard shaders and specular workflow are unsupported.

The diffuse reflectance is `rho = baseLinear * 0.96 * (1 - metallic)`. Consequently
black and fully metallic surfaces have zero diffuse return, while still occluding
other light. Metal/specular reflection is omitted; it is **not physically black
in full URP**. Emission remains a separate source term. Smoothness is recorded but
does not affect this diffuse model. The source model never reads a candidate
diffuse/material buffer to determine these values.

`lighting.py` uses Linear projects with `lightsUseLinearIntensity=true`.
Directional/point/spot source RGB is `sRGBToLinear(light.color) * intensity`.
The original Unity flags and per-light color-temperature flag are required.
Active color temperature is unsupported: the export does not currently provide
Unity's source-side native CCT linear multiplier. Export that multiplier or an
identity-bound `VisibleLight.finalColor` to extend this case. No guessed Kelvin
formula is substituted. Cookies, mixed/baked lights and nonunit indirect-light
multipliers are unsupported here.

For direction `l` from a surface toward the light, the nominal direct term is:

```
d = sum(lightLinearRGB * max(0, dot(n,l)) * rangeFactor * spotFactor * visibility)
rangeFactor = max(0, 1 - (r² / max(range², 0.0001))²)² / r²
spotFactor = clamp((dot(-forward,l) - cos(outer/2)) /
                   max(0.001, cos(inner/2)-cos(outer/2)), 0, 1)²
B0 = Le + rho * d
```

Directional range/spot factors are one; point spot factor is one. Positions use
the exported metre-space transforms. `d` uses URP's relative diffuse-light
normalization: a unit white directional light at normal incidence gives `d=1`.
This is not a lumen/candela/watt conversion, and no extra `1/pi` or `1/(4*pi)` is
inserted into the stock analytic-light term. The subsequent diffuse transport
integral has its normal Lambertian `cos/pi` factor.

`lighting-semantics.json` pins the actual stock Core/URP source bytes and official
Unity color convention documentation. `audit_lighting.py` checks their archived
hashes through the strict source loader. The prior scalar material-upload receipt
is identified as convention evidence, not candidate radiance or a fitted numeric
bound. No product transport or lighting implementation is imported.

## Geometry and independent integration

`geometry.py` handles the actual mesh triangles, base vertices, submeshes,
transforms and material slots. Vertex normals are transformed and normalized per
vertex before interpolation, following stock URP. Primary `ShadowsOnly` geometry
is excluded, while the direct-shadow world can retain it. An enabled stencil
override or nonstandard `_ZWrite` is unsupported. Source masks, not image values,
determine the primary domain. A half-full-pixel band around source triangle edges
is retained as boundary uncertainty, including hidden edges and coplanar diagonals.

`render_reference.py` uses independent CPU cosine-hemisphere paths and a source
triangle BVH. Analytic direct light is evaluated at bounce hits. Emission uses
explicit uniform-area triangle sampling at every vertex; emission is excluded
from the cosine branch to avoid double counting. The receiver's reflectance is
**not** multiplied into the output: `filteredD` is indirect irradiance divided by
pi. It excludes primary direct lighting and visible primary emission.

All image data stay in the recorded GPU projection and raw row order. A grid
sample uses `fullPixel=floor((2*gridPixel+1)*fullSize/(2*gridSize))`, then the full
pixel center and the exact exported view/projection. Negative projection `m11`
does not silently change `rowOrder`. Two diagnostic previews are emitted:
`preview-raw.png`, and a separately named vertical display flip for human viewing.
HDR bytes are identical regardless of preview choice.

The first picture scope is the actual 09 scene: static opaque back-culled
untextured boxes, black environment, no baked lighting/fog/transparent media, and
the recorded realtime lights and area emission. Physical source changes between
selected frames are respected. Coincident punctual sources on a source face are
rejected. No pixel cohort is selected from candidate colors or validity masks.

## Uncertainty and use

The default fixed run is 320×180, 256 samples per source receiver, eight diffuse
segments, four independent 64-sample batches, with recorded seeds. Each pixel has
a sample standard error; this describes sampling noise only. Rare unobserved
events can have underestimated finite-sample variance. There is no fabricated
absolute error bound, automatic quality threshold, or adaptive rerun until a
desired result appears.

Material model, finite bounce depth, float64 geometry, ray minimum
`1e-6*max(1,maxAbsOrigin)` metres, and source-camera/raster differences are separate
from Monte Carlo error. Authored Soft shadows are replaced by geometric hard
visibility; native PCF, shadowmap bias/cascades and screen filtering are absent.
`metalHitFraction` identifies sampled metal-path involvement, but zero does not
prove absence of omitted glossy influence. `maxDepthReachedFraction` reports
sampled truncation, not a tail certificate. These fields are diagnostics, not a
permission to drop inconvenient comparison pixels.

Reference `validity.u8=0` means source sky, source boundary or unsupported input.
The corresponding RGB zero is a placeholder, not expected black. Unknown
candidate pixels remain a separate missing-measurement count. Comparisons must
report both coverage and model limitations; a covered-subset score is not full
image acceptance. The existing strict reference adapter is not given a fake
`errorBound=0`: this approximate-picture report is consumed by the separate
diagnostic comparison workflow.

## Commands and artifacts

```powershell
python -B audit_lighting.py --source C:/run/source.json --state C:/run/states/frame-0119.json --output C:/new-direct-audit
python -B render_reference.py --dependency-dir C:/private/cpu-deps --source C:/run/source.json --state C:/run/states/frame-0299.json --output C:/new-reference --spp 256 --max-depth 8
```

Use the actual Python executable/environment. CPU dependencies are NumPy and
Numba; Pillow is optional for PNG. The implementation never installs packages.
Each output directory must be new and disjoint from the source root. Reports bind
the full source/state SHA, exact camera, accessed source assets, stock semantics,
implementation hashes, sample settings and emitted artifact hashes.

`filteredD.rgba32f` is tightly packed little-endian RGBA float32 (alpha is source
validity). `validity.u8` is one byte per pixel. `primary.npz` contains H×W source
geometry/domain arrays. `statistics.npz` contains row-major flattened standard
error RGB, metal-path fraction and truncation fraction. Raw color statistics are
scene linear; previews use fixed exposure, Reinhard and sRGB only for display.

## Preservation of the first domain result

The original six-test geometry tool, source hashes and frame119 domain report are
preserved in `source-domain-v1-original/`. Its five source files match the earlier
`validation-summary.json` exactly. Two edited files were reconstructed by reversing
the unexecuted working patch and verified against those existing hashes before
snapshot creation; this is recorded, not described as a pre-edit backup.

The later normalization/ShadowsOnly/stencil/ZWrite guards address general inputs.
09 uses constant face normals, shadow casting On, default stencil and `_ZWrite=1`,
so these corrections do not change the scope of the prior 09 domain result. The
old external report is not overwritten or relabeled as a later execution.
