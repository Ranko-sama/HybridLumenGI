# Radiance validity execution test

Run `Tests/Validate-RadianceValidity.ps1` with the existing Windows x64 VS2022,
Windows SDK DXC and Node toolchain. All generated C++, DXIL, binaries, input and
output buffers, logs and the result JSON stay in a new TEMP directory. A missing
WARP device is unavailable, never a pass. No tool installation is attempted.

The HLSL harness directly includes the production `HybridLumenGIRadianceValidity`,
`HybridLumenGIHit` and `HybridLumenGIRayFootprint` helpers. The runner extracts 13
original bodies: committed-material publication, point-query footprint, the
spatial `TraceShadow` primary and two compatibility wrappers, owner validation,
the spatial `DirectIrradiance` primary and three wrappers, the spatial
`ProxyRadiance` primary and its wrapper, and `TraceScreen`. It executes their
compiled DXIL without rewriting their logic. A deterministic nearest-hit and captured-texture
adapter supplies dependencies. It does not simulate real triangle traversal or
the texture pool, and a passing result is not an alpha texture integration claim.

The independent JavaScript oracle checks known black, zero-weight unknown data,
nearest unknown as a blocker, shadow-to-radiance unknown propagation, a screen
hit remaining a hit despite unknown illumination, the resulting cache commit,
invalid/nonfinite inputs, exact history retention and hard-rejection inputs,
sample-count preservation, and deterministic randomized combinations. A failed
positive-weight sample does not renormalize the estimate over remaining samples.

The actual ProxyRadiance body also receives a deliberately conflicting card
material and committed triangle payload. It must retain the payload's diffuse,
emission, normal, and occlusion while using only the card's incoming irradiance.
Missing triangle payload remains unknown. Shadow-receiving on/off and excluded
receiver policies are tested independently, including invalid shadow strength
which is irrelevant when shadow receiving is disabled. The actual coverage
decision helper keeps unknown candidates blocking and skips known transparency.
Supplementary source guards bind that helper to the sole hardware candidate
commit path after cull/light-policy checks, and require committed unknown flags
and known-payload publication. They do not execute DXR traversal.

The cache commit and unknown-history helpers are actual production HLSL. Their
caller supplies already-validated identity/epoch/geometry/change-region state.
Small supplementary source checks verify those call sites remain ordered after
invalidation and that statistics/filtering use the shared measurement predicate.
They do not prove the full temporal reprojection kernel, RenderGraph barriers,
Unity rendering, raster ownership, actual DXR candidate traversal, sampler/mip
behavior or physical GPU performance. Existing reprojection and full-shader
compile checks remain separate requirements.

Raw current estimates use confidence -1 for unknown; temporal output uses zero
when no validated history survives. Only finite values with confidence greater
than zero are measurements. Therefore measured black remains valid while an
unknown or uninitialized value cannot become black convergence evidence.

The runner also extracts the original committed-material publication helper.
An explicit bridge call spy supplies independent coverage-known, covered and
full-material-known states. The cross-product checks both shadow policy and
material purpose, including invalid footprints and a valid converging footprint.
A coverage-only query never calls full evaluation or publishes a UV material;
unknown coverage still marks the retained hit unknown. A full-material failure
cannot contaminate ordinary visibility because that dependency was not requested.
Source guards retain candidate Cull/alpha ordering and near/far visibility routing.
This spy is not a RayQuery implementation or the real material evaluator.

The spatial extension retains the original 2,526 cases and adds eight targeted
directional/point-light fixtures. The query spy records the original functions'
biased origin, direction, maximum distance, radius/slope/validity and material
observer. An independent double-precision oracle intersects an 8,192-angle
circle with the surface plane and projects its boundary onto the shadow-ray
plane; it does not copy the shader's singular-value formula. The point-light
cases require the biased connection to focus on the actual light, while direct
attenuation and N.L remain evaluated at the surface point. Zero and invalid
spatial support remain distinct. The old entry points execute as well, with
their declared point-query behavior. A NaN material observer does not by itself
poison committed coverage: the bridge spy represents a material without view
dependencies, whereas the real material bridge has its own separate tests.

The current binary harness uses 208-byte inputs and 368-byte outputs. The limited
pwsh run passed 2,534 cases and 293,944 checks with the original bodies and actual
footprint helpers on software WARP. Its screen footprint/world-match providers
are explicitly same-plane/no-match adapters, not production depth reconstruction.
This does not prove complete BRDF angular filtering, real GPU texture residency,
Unity/DXR integration, or physical GPU performance. The actual run's source
hashes, tool commands and readback artifacts reside in its generated report;
the unified runner must validate the final candidate's matching sources.
