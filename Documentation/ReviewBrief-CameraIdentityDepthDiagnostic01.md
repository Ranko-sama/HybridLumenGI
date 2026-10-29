# Camera identity depth rejection: finite native diagnosis

The original 48-frame camera/TAA capture remains a coverage failure. This follow-up identifies why identity disappears in that sequence; it does not accept the original temporal-quality gate.

The same scene, camera path, 264 predeclared world points and source `13f31ec` ran for 48 consecutive DX12 frames. An additive observer recorded identity-fragment inputs only on logical frames 36–43. The 112 product sources were unchanged. All 13 temporary files and three protected files were restored; the isolated observer directory and its metadata were removed.

Of 2,112 geometrically qualified point observations, 275 reproduced the original identity loss: 69 panel points at frame 37 and 206 floor points at frame 41. Each has exactly one fragment and the same strict rejection: `SV_Position.z != cameraDepth`, while `cameraDepth == captureDepth`. The other 1,837 observations retain identity. No coverage failures, early-discard, multiple-fragment, candidate-write or resolve anomalies were found in this finite set.

The observed actual URP object matrices and custom object matrices are bit-identical. Actual URP VP and the CPU-composed custom VP differ in bits, including element m10 on both failing frames. Other successful frames also have VP differences, so matrix inequality alone is not a sufficient failure predicate. This evidence supports aligning identity vertex transformation with the actual URP matrix source while retaining the strict depth gate. It does not identify a particular JIT or compiler optimization.

The first analysis failed because its owner-name lookup expected `ReferencePanel`; the frozen Editor actually creates `FixedBlackPanel`. The original failure is preserved. A separate same-data qualification changes only that name lookup, verifies the frozen Editor and all eight source tables, then executes every original geometry, coverage and classification gate. No pixel selection or depth tolerance changed.

Evidence: [package](../LocalComparison/Review/camera-identity-depth-diagnostic-01/), [execution](../LocalComparison/Review/camera-identity-depth-diagnostic-01/execution-receipt.json), [first analysis](../LocalComparison/Review/camera-identity-depth-diagnostic-01/analysis-first.json), [qualified analysis](../LocalComparison/Review/camera-identity-depth-diagnostic-01/analysis-owner-name-qualified.json). Source freeze: `26542da74d01e3fb1685feaf80960c2c2365ebb1de1a4026900d17afc18afd40`.

The user was concurrently gaming. This is correctness evidence, with no performance comparison. A product fix and the original temporal acceptance rerun are still required.
