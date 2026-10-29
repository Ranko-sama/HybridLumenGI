# Frozen Surface clamp-order contract

Prepared from HEAD 06d24a6 before either parallel lane changes product code.
Only Runtime/Resources/HybridLumenGI/HybridLumenGISurface.shader belongs to
this product edit. Its exact original bytes and its two local shader headers
are in frozen/. No execution or product edit is authorized by this file.
The root agent will authorize both lanes after the single Pro planning review.

The sole allowed replacement is `saturate(albedo) * diffuseFraction` with
`saturate(albedo * diffuseFraction)`. Keep existing ordinary [0,1] storage,
diffuse split, keywords, coverage, AO, emission, receiver policy and all inputs.
Do not add the world .98 cap, change samples/exposure, or modify Kernels/Feature.

cases.json has exactly three fixed records. All sampled texture values and
material inputs are finite and in [0,1]. BaseMap is white, DetailMask.a is 1,
the compiled color detail mode is _DETAIL_MULX2. Metallic/specular comes from
the declared shader variant, with its numeric workflow property consistent.
AO is .5; emission is (.125,.25,.5); source is opaque and alpha-test is off;
screen validity is +1 and receiver policy is (1,1). Shader-space inputs avoid
authoring gamma ambiguity. These texture/raster dependencies are adapters.

1. Colored counterexample: base 1, detail (.75,.25,.125), metallic .5 gives
   albedo (1.5,.5,.25), diffuse fraction .48. Correct rho=(.72,.24,.12), all
   channels below .98; old result=(.48,.24,.12). Correctness therefore does
   not depend on changing any upper energy limit.
2. Ordinary control: base (.25,.5,.75), neutral detail .5, metallic .5 gives
   (.12,.24,.36). Entire output must remain byte-identical to baseline.
3. Upper-bound control: base 1, detail 1, specular RGB 0 gives final uncapped
   rho 2. Both versions must output exactly (1,1,1), not .98; entire output
   remains byte-identical. This is the existing ordinary storage policy.

Reference uses the independent explicit table above and pinned URP 17.0.4
BRDF.InitializeBRDFData/LitInput.ApplyDetailAlbedo equations. No expected
value or tolerance may be derived from an observed candidate result.
Color absolute bound: 2e-6, inherited from the existing source-level host.
AO/emission/validity/policy and both control records are exact. Baseline must
establish the first mismatch and match its own old-source expected table.
Candidate must match every new-reference row. All bytes outside diffuse RGB
must equal baseline, including the recorded clip decision. The first case's
green and blue diffuse channels must also remain byte-identical.

One baseline invocation and one candidate invocation of run_surface.py;
each invokes existing DXC and the existing source-matched RadianceValidityWarp
host once for metallic (two records) and once for specular (one record).
The helper copies the complete actual Vert and Frag bodies without edits;
clip is recorded using the existing adapter and discarded payload is masked.
No new C++ host/build/framework or implementation-mirroring shader formula.
Candidate additionally compiles four complete real-clip fragment variants:
metal/spec x MulX2/Scaled, retaining actual production includes.

Each stage directory must be new; a failed attempt is preserved and ends this
lane pending root review. No automatic rerun, input adjustment or extra matrix.
The candidate product bytes must equal the frozen baseline with only the one
declared replacement. Pin the lane's local headers, helper sources, ABI/host,
DXC, and installed/reference include files. Do not require unrelated Runtime
or other lane source hashes to stay unchanged. Preserve raw inputs/outputs,
compiler logs, commands and source snapshots. No Unity, Player, screenshots,
UV/parallax extension, sampling changes, performance or whole-image claim.
