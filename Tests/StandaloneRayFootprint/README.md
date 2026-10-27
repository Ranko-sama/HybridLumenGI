# Ray footprint geometry and propagation

Run `pwsh -NoProfile -File Tests/Validate-RayFootprint.ps1` or Windows PowerShell 5.1 with the same script. The runner uses the existing Windows x64 DXC/VS2022/CMake/Node installation, creates a fresh TEMP directory and installs nothing. Exit 2 denotes unavailable D3D12 WARP, never success.

The actual runtime `HybridLumenGIRayFootprint.hlsl` is compiled to DXIL and dispatched on WARP. The host uploads 192-byte test inputs and reads 48-byte results only after a real D3D12 fence. The independent double oracle solves a three-equation plane system for card geometry, traces 8,192 boundary directions for retargeted ellipses, and evaluates corner/point-light geometry. It does not reproduce the shader's inverse-Gram or eigenvalue implementations. Source identities before/after, executable, DXIL/listing, binary inputs/readbacks, oracle and command logs are retained in the report's artifact directory.

## Explicit contract

`HLGIRayFootprint { float radius; float slope; uint valid; }` stores a nonnegative radius measured in world units perpendicular to the ray, and a radial slope `dr / d(distance)`. Slope is not an angle. Texture lookup uses the diameter `2 * radius`; it must not use the radius as width. Invalid input returns false and a zeroed, invalid record. A valid radius zero remains distinguishable from unknown.

| Function | Meaning |
|---|---|
| `HLGITryMakeRayFootprint(radius, slope, out fp)` | Explicit finite parameter construction; permits negative slope for converging connections. |
| `HLGIAdvanceRayFootprint(fp, distance, out advanced)` | Advances by world distance, with `r' = r + slope * distance`; negative distance, nonfinite or negative resulting radius is unknown. |
| `HLGITryAngleSpread(fullAngle, out slope)` | Converts an explicitly supplied full angle using `tan(fullAngle / 2)`; rejects angles outside `[0, pi)`. It does not choose a diffuse angle. |
| `HLGITryScreenFootprint(p, pX, pY, neighborPixelDelta, representedFullPixelSpan, rayDirection, out fp)` | Derives two world half-edges from actual accepted same-surface neighbors and signed pixel offsets. Current selected-full-pixel semantics use represented span `(1,1)`, regardless of GI stride. |
| `HLGITryCardPatchFootprint(worldToCard, anchor, Ng, cardPixelCount, cell, gridSize, rayDirection, out fp)` | Uses the card's `[0,1]` coordinates, exact integer pixel partition and actual off-center anchor. Inverts the two projected coordinate gradients in the actual geometric tangent plane. |
| `HLGITryRetargetFootprint(incoming, incomingDirection, Ng, outgoingDirection, out fp)` | Projects an incoming ray-normal disk onto the tangent plane, then onto the outgoing ray-normal plane; bounds the resulting ellipse by its largest singular value. |
| `HLGITryDirectionalShadowFootprint(surface, out shadow)` | Parallel connection bundle: retains the already shadow-direction-projected spatial radius, with zero slope. |
| `HLGITryPointShadowFootprint(surface, lightDistance, out shadow)` | Point/spot connection bundle: starts at the projected surface radius and converges on the light, with slope `-radius / lightDistance`. Valid tracing stops at the light. |

Surface spatial constructors bound all four projected corners; they do not assume a patch anchor is its center. A card tile with an odd pixel count follows `begin = cell * count / grid`, `end = (cell + 1) * count / grid`, exactly as the anchor scanner. `worldToCard` is affine and maps directly to `[0,1]`; it is not clip space. Empty, singular or invalid cells are unknown. A nearly grazing incoming disk cannot be reliably projected onto the tangent plane and is rejected. The tangent-plane approximation does not establish curvature or coverage beyond the caller's validated local surface.

For a forward near/far origin shift of `s`, first advance the footprint by `s`; then advance only by the new ray's local hit distance. Restarting the radius at the new origin loses already accumulated width. Geometric normal-bias offsets are not automatically interpreted as additional optical path length. Point-light rays use `r(t) = r0 * (1 - t/L)` on `0 <= t <= L`. The helper stores the equivalent slope, rejects negative radii beyond convergence, and may conservatively return unknown at numerically ill-conditioned focus boundaries. Directional lights instead have parallel rays and retain a nonzero receiver footprint. Neither construction models an area-light penumbra.

Screen/card constructors return the spatial component as a parallel bundle. **This is not a completed diffuse scattering or multiple-bounce cone model.** The caller must provide verified neighbor geometry; a depth discontinuity, missing neighbor or unknown identity must not be replaced with a guessed zero footprint. No main transport, kernel or Feature file is modified by this standalone helper.

## Primary references and the unresolved diffuse model

- Akenine-Möller et al., [Texture Level of Detail Strategies for Real-Time Ray Tracing (2019)](https://research.nvidia.com/publication/2019-03_texture-level-detail-strategies-real-time-ray-tracing), establishes ray-cone width/spread propagation and contrasts it with ray differentials.
- Akenine-Möller et al., [Improved Shader and Texture Level of Detail Using Ray Cones (2021), sections 4–5](https://www.jcgt.org/published/0010/01/01/paper-lowres.pdf), discusses approximate BRDF broadening and projection to a surface footprint. The [authors' errata](https://research.nvidia.com/publication/2021-04_improved-shader-and-texture-level-detail-using-ray-cones) explicitly correct `r = t tan(alpha/2)` and the doubled gradients used by `SampleGrad`.
- The paper's GGX variance approximation is `sigma² = alpha² / (2(1-alpha²))`; its proposed Lambertian endpoint `alpha=1` is singular. The publicly linked Falcor implementation, fixed at [`759aad033ff610fb0d82c74f7e0a508d0096d5f2`, `WhittedRayTracer.rt.slang`, `roughnessToSpread`, lines 106–111](https://github.com/NVIDIAGameWorks/Falcor/blob/759aad033ff610fb0d82c74f7e0a508d0096d5f2/Source/RenderPasses/WhittedRayTracer/WhittedRayTracer.rt.slang#L106), clamps its denominator. That finite engineering clamp does not establish a calibrated diffuse spread for this package's cosine/guide/emitter mixture, cache accumulation and filtering. That angular model remains pending.

Only formulas and contracts were studied. No external implementation was copied into this helper. Geometric projection/shadow formulas above are explicit local constructions, not claims to reproduce the paper's complete BRDF, curvature, refraction or anisotropic filtering system.

The test does not execute Unity, full GI transport, camera/geometry validation, DXR alpha decisions or a physical GPU. It does not show image quality, performance, unbiased filtering or a completed diffuse-cone propagation chain.
