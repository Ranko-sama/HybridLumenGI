# Exact area-emitter sampling and paired MIS

Run `pwsh -NoProfile -File Tests/Validate-AreaEmission.ps1` from the package root. This runs the actual C# distribution builder with explicit Unity/material input adapters, then compiles the actual `HybridLumenGIAreaEmission.hlsl` and executes it on D3D12 WARP. No Unity installation or physical GPU is used. It does not execute an RTAS, the product's visibility query, or Unity source textures.

The immutable 96-byte records reference prepared tracing triangles and the matching material-table generation. The C# checks cover world area, identity, stable primitive indices, mirrored authored normals, source failures, capacity subsets and float32 CDF compaction. The GPU fixtures cover sampling, area-to-solid-angle density, endpoint identity, nearer/mismatching endpoint rejection and stable balance weights. A separate double-precision area quadrature integrates a varying analytic UV emission signal; one direction sample plus one area sample estimates that signal once. This signal tests the estimator, not source-texture evaluation (which belongs to the existing actual hit-material tests).

Latest development run: `C:/Users/Administrator/AppData/Local/Temp/hlgi-area-emission-warp-65c01cccd69a4f8aae1f958d6ab1339b/area-emission-results.json`: 45,641 GPU fixtures, 52,468 oracle checks. The paired estimate was 0.404485247 versus quadrature 0.402625282, with estimated standard error 0.001069467. These statistics are one synthetic scene, not GPU timing or a general variance guarantee. The same run's CPU builder check and exact source hashes are in its logs/report.

The first GPU runs caught a real fast-math edge case: dividing two near-maximum finite PDFs could flush a reciprocal to zero and incorrectly return balance weight zero. Explicitly scaled, `precise` intermediates preserve the ratio; an inverse-PDF result below the smallest normal float can still flush to zero and is disclosed by the extreme fixture. Earlier failed artifacts remain in TEMP.

Integration contract:

- Freeze emitter geometry, CDF and material generation for all consumers of one recorded batch. A stale endpoint is unknown, not a transparent hole.
- Use the full cosine/guide/vMF direction PDF for both techniques. Pair one area draw with every direction draw, including direction samples below the receiver hemisphere. Never normalize by accepted samples.
- Apply the balance weight only to the direction hit's emitted radiance. Reflected/direct/cache radiance keeps its direction estimator. The area term is `Le * receiverCosine / (PI * (pDirection + pArea))`.
- Evaluate the selected endpoint through the actual nearest surface query, source UV material and Cull/coverage rules. Only a proven transparent candidate may be skipped. Matching an owner without a primitive is insufficient.
- Screen gathering must use the same nearest-screen partition for both techniques; a winning screen hit has no exact emitter identity, so its original direction estimate stays unweighted and the area term is suppressed.
- Unknown SDF/analytic identity cannot be assigned a triangle PDF. Complete software NEE requires exact software triangle tracing for admitted emitter owners, not only a triangle table beside an approximate SDF.
- Nonlinear per-technique clamping changes the integrand and breaks paired weights. The active area estimator must use a consistent unclamped integrand or a separately justified common estimator policy.

The runner writes new evidence only in TEMP unless `-ReportPath` is supplied. It does not modify archived deliveries or run the full offline suite.
