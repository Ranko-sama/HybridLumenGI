> 历史专项快照：下文次数与哈希仅属于记录时的来源。当前交付的通过结果以 [统一离线报告](offline-validation-results.json) 和 [证据入口](../Documentation/OfflineValidation.md) 为准；不能把本文旧哈希继承给新源码。

# Surface cache managed contract validation

Run `powershell -NoProfile -ExecutionPolicy Bypass -File Tests/Validate-SurfaceCache.ps1` with .NET 8 available.

The test compiles the complete, unchanged `Runtime/HybridLumenGISurfaceCache.cs` against recording Unity substitutes. **19,968 assertions in 11 scenarios pass**, for runtime source SHA256 `A85A0F0F2A8000AEC81299AF7FF078ED88AFEF8AC410859A39F61E5A51E4D439`. These include independent sparse tuple-key mapping fixtures and recorded commands, not rendered pixels.

Coverage:

- Actual `Prepare`, retirement, allocation, range rebuilding, capture recording, binding and disposal methods run. Owners with 1, 3 and 7 required charts use the explicit owner ranges and indirect physical-card indices. Nonordinal chart stable IDs are retained.
- Pool retirement and reuse produce noncontiguous physical sets without affecting retained owners. Reuse advances layout/page generations and clears readiness. Simultaneous 1/7 to 7/1 resizing succeeds with exactly 8 resident pages because all obsolete layouts retire before allocation.
- Admission rejects an oversized required set atomically. Warming sets cannot evict published sets. Invalid chart assets and unsupported required materials cannot become partially ready. The unbaked six-view fallback retains its separate approximate flag.
- Each real chart draws only its chart submesh of `CaptureMesh`, using the material and property-block overrides of the original source submesh. Disabled/hidden static renderers remain capturable by explicit mesh draws.
- Every chart draw precedes its anchor dispatch, and all dispatches precede the final ready metadata upload. Recording adapters snapshot every uploaded struct and parameter dictionary at call time, preventing later mutations from hiding publication-order defects. Prepare alone and skipped captures cannot publish readiness.
- Capture and draw budgets include the per-tile clear. Partial capture does not satisfy a complete required chart set. Changing the patch grid releases old resources, advances atlas generation and forces capture with the new anchor grid.
- Buffer strides are 128/16/4/8/32 bytes for cards/ranges/indices/anchors/emissive descriptors. The actual private card/range structs marshal to 128/16 bytes. Anchor storage covers physical-card capacity times grid squared and starts at (-1, -1). Emissive descriptor allocation, initialization, capture binding/padding, byte-budget accounting and release are checked separately.
- Source fingerprint verification is cached across rigid and material revisions. Geometry-content revision or mesh-reference changes force verification. Publication guards reject stale geometry without consuming domains or changing generations. A matching replacement mesh updates cached identity and does not rehash forever.
- Consumers bind the four required buffers and physical capacity. Disposal releases every atlas and buffer and clears readiness; reuse advances atlas generation.
- Original submesh/primitive lookup uses a bounded CPU table, including unmapped degenerate ordinals. An independent tuple-key oracle checks 80 sparse layouts against the actual lookup. Stable source/owner/geometry/layout/card identities are required even before a page is ready; late changes and reuse reject old bindings. Owner range.w is the current geometry revision, and its change is uploaded.
- The CPU table accounts for 4-byte primitive entries and outer references under a 16 MiB cap per camera, reuses stable tables, and releases them on retirement/disposal. It does not retain another vertex/index copy or read source triangle data on each query.
- Effective original-submesh material constants remain available without card residency. Tests cover distinct submesh colors, MPB replacement precedence, Cull modes, HDR values, nonfinite rejection and unsupported sources. The recording adapter's color semantics do not establish Unity's actual material/MPB upload convention; the engine color probe remains required.
- Capture recording supplies a chart's raw geometry direction separately from its Cull-adjusted capture direction and supplies an explicit determinant sign for fallback. Numerical/source shader tests cover reversed Ns and raster-contract assumptions separately; these command checks do not execute the fragment shader.

The recording fixture permits a content-matching replacement source mesh and verifies that its cached identity is updated without repeated hashing. The implementation explicitly treats source mesh identity changes as layout changes. The real chart asset additionally requires source-reference identity and a rebake when its source changes; the fixture is not proof of a reproduced Unity failure.

These are managed state and command-recording tests, **not Unity rendering or GPU evidence**. The substitutes do not execute rasterization, anchor compute, native material color encoding, driver commands, fences or readbacks. Chart asset validation is an API substitute here; baker/fingerprint correctness requires its separate tests. Matrix arithmetic uses System.Numerics and validates managed control flow only. No Unity installation or native runtime execution is claimed.

Related independent checks are `node Tests/Validate-SurfaceAnchors.mjs` (partition/coverage/emissive-reduction references and source contracts), `Tests/Validate-SurfaceCards.ps1` (13 selected native-DXC shader checks), and `Tests/ValidateShaders.ps1` (44 core native-DXC checks). DXC adapter compilation does not establish Unity shader import or image correctness.
