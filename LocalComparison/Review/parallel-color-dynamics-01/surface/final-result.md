# A lane: first executed baseline and candidate pass

Current disposition: retain the sole Surface.shader expression change for
the root agent's combined review. Product source now clamps after the diffuse
BRDF split: `saturate(albedo * diffuseFraction)`. No other product file was
changed by this lane, and no commit was made.

The initial `py -3` launcher failure is preserved in baseline-command.json,
baseline-command.log, launch-failure-state.json and the historical result.md.
It occurred before Python, DXC or WARP started. The root explicitly authorized
only an interpreter-path correction to the configured bundled Python, with
the exact frozen script, contract, cases and tolerances unchanged. This is
recorded separately in launcher-corrected-command.json/log. The first actually
executed baseline passed exit0; the only candidate passed exit0. There was no
shader/host failure, input adjustment or behavior rerun.

| Frozen case | Actual old diffuse RGB | Actual candidate diffuse RGB | Result |
| --- | --- | --- | --- |
| Legal colored MulX2 detail; metallic .5 | (.4799999893,.2399999946,.1199999973) | (.7199999690,.2399999946,.1199999973) | Matches independent (.72,.24,.12) within 2e-6 |
| Bounded albedo control | (.1199999973,.2399999946,.3599999845) | Same full record bytes | Preserved |
| Specular zero; detail brightening exceeds output cap | (1,1,1) | Same full record bytes | Existing cap1 preserved |

The colored case's green/blue bytes and all three cases' bytes outside
diffuse RGB are unchanged. AO=.5, emission=(.125,.25,.5), validity1,
coverage and receiver policy(1,1) remain exact. Baseline and candidate
inputs are byte-identical. The sole candidate additionally passed four
complete real-clip fragment compilations: metal/spec x MulX2/Scaled.
All eight candidate subcommands are individually recorded in
candidate/commands.json: two compute compilations, two host runs and four
full-fragment compilations.

Execution consumes the full extracted production Vert/Frag with unchanged
function bodies, existing fixed shader-space texture/transform/policy/clip
adapters, and the existing source-matched WARP host. It does not execute
Unity keyword transfer, native raster/UNorm attachment storage, GI geometry,
whole images, performance, or physical GPU rendering. The four full fragments
use actual includes and real clip. Local headers, helpers, ABI, pinned
reference/include bytes, DXC and host identity were checked; unrelated
concurrent Kernels changes are outside this lane's source contract.

Product baseline SHA256:
`b8e529a4cb019896ce03f77e852a582aff8071d766d555bca34fbdae6d68c961`.
Candidate SHA256:
`1db0d9a01bd1abf55e1e9c8d1164441fe721ad78c733082ac89cff9833edd8db`.
Candidate product bytes equal the frozen source with only the authorized
expression replacement, preserving all original line endings. See
completion-state.json, product.patch, baseline/analysis.json and
candidate/analysis.json for exact identities and raw-result links.

This continues cumulative Surface work36/51/52. It establishes one color
reflectance arithmetic repair, not a diagnosis of old screenshots or complete
material/visual acceptance. No Unity, Player, deployment or shared-runner
change occurred. Original four goals and ten workflows remain open.
