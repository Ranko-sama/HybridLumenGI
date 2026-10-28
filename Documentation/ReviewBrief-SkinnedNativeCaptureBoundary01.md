# Iteration46 — native capture premise for unchanged Skinned reuse

Workspace65e2a11. Original goal3/workstream4. ActualPro45 accepted the finite reuse source contract and agreed with independent Astra on one narrower native dependency check. This continues the same cumulative deformation work (propagation, coalesced explicit demand43, unchanged automatic capture45); it does not add a new capability per capture or review.

Zero product modification/deployment. Project and runnable Release44 remain5120a8c. The production SurfaceCharts fingerprint file in the project, repository and frozen candidate dependency is identical: SHA256 `04c1a2ec9468a3524deb845c06f5480346d25e7d97fa0b699422c6eabcdb2e92`. The test calls that production function directly; its loaded runtime assembly hash is recorded. This is not an assertion that candidate DeformedMesh executed natively.

One thin Editor script was staged using existing checked install/restore helpers. It created a temporary preview scene, four vertices/two triangles and two bones, unit transforms/bindposes, one bone of weight1 per vertex. Lower vertices0/1 use bone0; upper2/3 use bone1. Three independent destination meshes used actual BakeMesh(destination,false): A1/A2 unchanged pose; B only upper bone localX+.25. Initial source input, analytic reference relation and absolute1e-6 bound were frozen before execution. No representative scene or project asset rebake, no Player/build/Play mode, no GI rendering or added GPU query.

## First execution

One managed Editor compilation preflight exited0 with the existing obsolete AssetBundle option warning. One Unity6000.0.85f1 Editor process PID21608 then completed the three native captures and exited0; first analysis passed unchanged. No retry, predicate change, normalization or extra capture. Exact staged Editor script SHA256 `e9b0b952615ca037ee573c4140cd3350cf03dbee0007436db1503e3ae3c637ff`; execution sources unchanged after completion.

| Capture | Native positions | Full production fingerprint |
| --- | --- | --- |
| A1, A2 | (-.5,0,0),(.5,0,0),(-.5,1,0),(.5,1,0) | 4B64361759BAA1834A576A71724783990DD28630C4CB2286F17052AA05634A55 |
| B | (-.5,0,0),(.5,0,0),(-.25,1,0),(.75,1,0) | 9D8BA06335AB3EF3FCFC0247E920B0F8226381096C6744F418198BE879D610E3 |

All three have4 readable vertices, expected exact indices/topology and finite declared data. Maximum coordinate error for position, unchanged normals, tangents and UV is0 for each capture (predeclared bound1e-6). Source mesh fingerprint before/after is equal, while only the intended bone pose changes. Same-pose fingerprints match; the changed pose is accepted by analytic geometry and changed fingerprint together.

Native output has two actual streams:160 bytes/stride40 and32 bytes/stride8, plus12-byte UInt16 index data. Thus it is not the prior adapter's one-stream layout. Every raw blob, actual attribute/submesh descriptor, typed data, bounds and bone metadata is retained unmodified. A bounds center(0,.5,0), size(1,1,0); B center(.125,.5,0), size(1.25,1,0), as returned by Unity. No bounds or bytes were replaced to force matching.

Raw `A1/A2/B-capture.json` are written before qualification and deliberately contain qualified=false/error=-1. The original `native-result.json` records the subsequent analytic decisions, qualified=true and measured error0; this is a staged raw/final protocol, not a failed judgment rewritten to pass. All three raw captures exist before qualification. No bone arrays borrowed from native mesh were disposed by the caller.

Private objects/meshes and preview scene were cleaned; temporary Editor source/meta restored. All112 prior deployed product source files and representative scene/settings hashes match their pre-execution state. The generic reused install helper prints historical “test Player wiring” text; the manifest has one Editor script and the only native command is executeMethod SkinnedNativeCaptureBoundary.Run, with no BuildPlayer or Player launch. First native log scan has no error signatures.

## Decision boundary and cumulative value

The specific native premise holds for this simple skeleton: identical captured native contents have stable full fingerprints; the declared bone motion reaches expected vertices and changes the fingerprint. Together with45's actual-component logic evidence, this provides finite usable grounds for the reuse mechanism. It does not certify candidate publication/retirement inside Unity, animation rendering, blend shapes, cloth, all raw layouts, arbitrary transforms or millisecond benefit. Release44 retains its prior source and evidence.

This finishes the proposed native boundary. Further component edge cases or repeats would not change this adoption decision. Full original architecture goals remain; production budgets are unanswered. Review closure/local commit from original outputs and raw evidence, then select one next capability, evidenced defect or decision-changing acceptance gap across OriginalDevelopmentPlan.md. Astra is independently performing this stage reassessment before a new Pro/main plan. Do not reopen closed Release/shape/source checks or expand this capture into an animation/performance project.
