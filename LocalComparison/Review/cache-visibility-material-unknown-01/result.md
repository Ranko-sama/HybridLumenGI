# Cache visibility with unknown material coverage

The current cache interpolation could discard a positive-weight tap behind a
triangle whose alpha/coverage was unknown, then normalize the remaining taps into
trusted colored light. `TraceSceneVisibilityHit` requests coverage only
(`resolveMaterial=false`); its committed `MATERIAL_UNKNOWN` is not proof of
occlusion. The old check only rejected `QUERY_UNRESOLVED`.

The product change replaces that condition with `!HLGIHitMaterialKnown(blocker)`.
The existing failure branch clears the entire cache entry and returns
`known=false`. The existing numeric consumers then reject the uncertain estimate.
Known occlusion still excludes a tap; a zero-weight tap still makes no query.
There are no new resources, thresholds, lighting gains or material changes.

One baseline and one candidate compilation/dispatch used the existing
source-matched `RadianceValidityWarp.exe`. Both commands exited 0. The shader runs
the extracted production cache interpolation, cache wrappers, `ProxyRadiance`,
the actual hit predicates and committed-material classification. Only external
card coordinates, decoded normals, scene connectivity, material bridge responses
and direct light are fixed dependency adapters. The committed classifier is called
with `resolveMaterial=false`, matching ordinary visibility queries.

| Fixed input | Old result | Candidate result |
| --- | --- | --- |
| First positive-weight tap has unknown coverage | Known blue cache `(0,0,2)` | Unknown; complete entry zero |
| Unknown coverage after an accumulated red tap | Known red cache `(4,0,0)` | Unknown; complete entry zero |
| All taps have unknown coverage | Known absent cache; direct/emission accepted | Unknown; numeric consumer confidence zero |
| Clear red/blue taps | Known `(2,0,1)` | Identical full output bytes |
| Proven right-side occlusion | Known red `(4,0,0)` | Identical full output bytes |
| All taps proven occluded | Known absent cache | Identical full output bytes |
| Unresolved SDF connection after a red tap | Unknown | Identical full output bytes |
| Unknown coverage belongs only to zero-weight taps | Known red `(4,0,0)` | Identical full output bytes |

All eight cases matched the frozen expectations exactly. The three changed cases
also checked the complete 80-byte cache structure, `CachedIrradiance` known flag
and `ProxyRadiance` confidence. Five controls matched all 368 output bytes.
The paired input SHA256 is
`a60e9b798f307456afd6490630fdaa7d5aaa723611718336b1538bcc6af4bfea`.

Baseline Transport SHA256:
`a48a5fe0620999d54e51ef62b9bd396b57d43713f2f5bc6888f8a910c31c1221`.
Candidate Transport SHA256:
`1621a7688f9157c1169016d259168c4c7462c6695522bea1c9d0ba57b7fe2255`.

Sources, pre-execution contract, cases, commands, logs and raw output are preserved
in `baseline/` and `candidate/`; each `analysis.json` records the host/compiler
identity and exact judgments. The paired runner is
`Tests/Validate-CacheVisibilityMaterial.py`; it intentionally refuses to overwrite
an existing stage. The main agent owns integrated full-entry compilation.

This establishes the finite material-uncertainty repair on D3D12 WARP. It is not
full traversal, Unity/Player, physical-GPU, image-quality, color-bounce energy or
performance acceptance. No Unity deployment or Release69 artifact was changed.
