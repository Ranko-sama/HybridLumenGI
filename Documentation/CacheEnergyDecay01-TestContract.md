# cache-energy-decay-reference-01 — frozen before GPU execution

Baseline `1b8e751`. Implements actual Pro iteration 9 next plan. No Runtime edits and no scene/renderer changes. Exactly one Unity compute batch, 256 source-on updates followed by 256 source-off updates, both nodes updated every round. These are controlled iterations, not rendered frames or real-time convergence measurements.

## Independent problem

Cache C is indirect incident E/pi; outgoing L = rho * (d + C). Two ideal nodes have the operator C_A = L_B and C_B = L_A, no emission/environment, AO=feedback=1. rho_A=(1/2,1/4,1/2), rho_B=(1/4,1/2,1/2); d_A=(1,1/2,1/4), d_B=0. On-state closed form: L_A=(4/7,1/7,1/6), L_B=(1/7,1/14,1/12); C_A=L_B, C_B=L_A. Off-state physical equilibrium is zero; finite cache persistence is estimator history.

Each round uses two distinct GPU buffers with Jacobi read/write swapping. Empty starting buffers are initialized once. At zero-based round 256 the directional light's actual color is set to zero and one lighting-only region encloses both nodes. Geometry global change stays zero. No cache clearing, epoch/generation change or input fitting. Samples shorten from 32 to 1, then the real commit advances them to 2. Source lookup still reads the old buffer, including its old sample count.

CPU finite reference uses C_i'=(1-alpha_i)*C_i + alpha_i*rho_j*(d_j+C_j), samples=min(preparedSamples+1,32), alpha=max(1/samples,0.1); first valid estimate has alpha=1. The generator does not read GPU files. reference.json contains all 512 double-precision steps and is hashed into the installed source manifest before the run.

## Float32 bound, fixed in advance

u=2^-24, gamma32=32u/(1-32u). Per channel, e_i' <= (1-alpha_i)e_i + alpha_i*rho_j*e_j + (gamma32+gamma8_double)*(abs(C_i)+e_i+abs(L_j)+rho_j*e_j)+2^-120. The double term bounds reference arithmetic. The conservative 32-operation allowance covers lookup sum/normalize, direct injection, endpoint multiply/add, weight division/multiply, accumulation and alpha/lerp. Inputs and all nonzero interpolation weights are exact binary values; one ray means division by 1. Guide/emissive fractions are zero; mathematical cosine weight is cosine/cosine=1, so trigonometric approximation does not change the exact energy operator. Before GPU execution the float-division observability gate is fixed at abs(weight-1)<=gamma4=4u/(1-4u), allowing reciprocal/multiply rounding within the already frozen gamma32 energy bound. A weight outside that bound or an unknown result fails the fixture rather than expanding tolerance. The per-step scale shrinks after source removal; it is not an absolute tolerance fitted to GPU residuals. Independent finite residual plus propagated rounding bound gives the on/off final equilibrium error bounds. reference.json and its generator snapshot remain unchanged by this preflight clarification.

## Actual chain and environment boundary

Mechanically extracted actual CSUpdateCache, HLGICachedSurface, ProxyRadiance, DirectIrradiance, hash/real cosine direction sampler, card validation/UV/footprint and area-matching functions; actual included CommitCacheEstimate, measurement semantics, change-domain, lighting-policy, emissive and area libraries. Observations only copy values and outcomes, without altering random draws or scheduling. A legal directional HLGILight affects only A via masks. Both normals are +Z. Direct color and Lambert cosine are exact. Shadow strength is zero.

Adapters supply two fixed valid patch/material records and map each valid positive-cosine direction to the paired node's hit. This ideal operator is deliberately not a physical geometric scene. Adapters never return cache estimates or endpoint radiance. Ordinary anchor visibility is zero length and shadow visibility disabled; calls to either are failures. Dummy legal buffers bind the disabled emitter libraries. Atlas raster capture, Euclidean visibility, scene light-change detection, screen gather, MIS, real room energy and Player/DXR are outside this reference.

## Recorded checks and stopping

Each round preserves actual old/new cache entries, prepared samples, actual change response, sampled direction/weight, actual endpoint/direct/cache values, confidence, execution/mask flags, source state and physical buffer labels. Both the private observation and the actual cache-write buffer are read back, retained until completion; previous cache bytes must equal the next round's old bytes. Exactly 512 rounds; no extra seeds, reflectance scans or extended iterations. Numerical comparisons use the frozen reference; on/off final bounds are checked separately from round matching.

Identity/generation/mask/buffer schedules and sample counts are exact. The first A cache is measured black, first B equals rho_A*d_A, both are valid. First source-off update preserves old estimates with shortened history. All later outputs remain finite, valid and within their predeclared round bounds. Failure archives the earliest divergence and actual inputs. Compile, wrong coverage/target path, nonfinite, unknown, readback or native-exit failure stops the package; no runtime repair or repeat is authorized by this plan alone. Before execution Astra checks source/adapters and the frozen reference. After execution it reviews results, then the same GPT-6 Pro conversation decides the next package.
