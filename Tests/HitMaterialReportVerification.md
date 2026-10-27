# Material-chain report verification

The new offline runner registers **70 stages**: the previous 56 plus four actual C# stages (`RayTexturePool`, `HitMaterialLayout`, `HitMaterialBatch`, `HitMaterialPass`), the nine GPU stages below, and `CaptureComparator` (`node Tests/compare-validation-captures.mjs --self-test`). The comparator stage checks synthetic capture inputs/arithmetic; it does not supply Unity captures or reference images. This describes registration and validation requirements, **not a completed unified run**. Existing integration13 archives and 56-stage reports are unchanged. The new verifier deliberately rejects those old reports as evidence for the expanded candidate.

`Verify-HitMaterialReports.ps1` is called by `Verify-OfflineReport.ps1` with its complete default nine-stage set. A subset parameter exists only to test authentic standalone artifacts while other modules are changing; the aggregate verifier never selects a subset.

| Stage | Actual HLSL execution coverage required | Sources before/after | Artifact files |
|---|---|---:|---:|
| HardwareNormals | One cs_6_0 helper; 4,183 cases / 16,666 oracle checks | 8 | 7 |
| HardwareSurface | One cs_6_0 surface/TBN/LOD helper; 790 / 18,173 | 8 | 7 |
| HardwareMaterials | Nine entries: RGorAG/RGB/AG × full/coverage/shadow; 248/149/152 cases per encoding, 28 checks per case | 12 | 55, plus extracted type file |
| HitMaterials | Three normal encodings; 3,150 / 75,600 each | 8 | 19 |
| RayTextures | One helper; 36,214 / 108,642 | 7 | 7 |
| RayTextureCopy | Begin, CopyMip and Finish kernels; 73 / 36,099 | 7 | 11 |
| RayFootprint | One geometry footprint helper; 1,530 / 19,891 | 7 | 7 |
| RadianceValidity | Actual footprint/validity helpers and 13 extracted primary/compatibility functions; 2,534 / 293,944, input/output stride 208/368 | 12 | 8 |
| RayQueryPropagation | Actual primary TraceSceneQuery and footprint helper, with explicit geometry adapters; 1,676 / 154,192, input/output stride 160/368 | 9 | 8 |

The nine runners use schema version 1 and kind `<Stage>ActualWarpValidation`. Required fields are `status`, `startedUtc`, `completedUtc`, `artifactDirectory`, `sources`, `sourcesAfter`, `checks`, `tools`, `artifacts`, `oracle`, and explicit boolean `warpExecuted=true`, `unityExecuted=false`, `physicalGpuExecuted=false`. Missing fields, error/source-change evidence, string replacements for booleans, failed stages or incomplete coverage are rejected. The new GPU stages require 21 selected DXC entries; together with the previous 126 entries the declared total is 147. The aggregate output sums actual verified compiler-entry lists, excluding compiler-version commands. HardwareMaterials additionally requires `selectedDxcEntries=9` and `softwareFenceWaitLimitMs=180000`; this software wait limit is not a GPU timing result.

Each aggregate envelope records `stage`, the unique `<runDirectory>/<Stage>-results.json` path, its exact SHA-256 and its parsed report. The helper rereads that file, checks its bytes/hash and exact embedded contents, and binds its timestamps and path to the corresponding suite invocation and `-ReportPath` argument. A previous standalone result is not accepted merely because its status says passed.

Source sets are exact and duplicate-free. Both before and after sets must match the package source hashes, including the specific runtime helpers, test HLSL, oracle, native host source, CMake file, runner and shared process runner. The copied C++ and CMake inputs used by the host build are also reread and hashed. Hardware type extraction and radiance function extraction are compared against their actual source bodies.

RayQueryPropagation additionally checks every actual compiler snapshot path/hash and the exact primary `TraceSceneQuery` body with explicit footprint/view parameters. Aggregate acceptance requires both the entire before/after Transport source and the extracted body to match. A development runner report that tolerates edits outside the extracted function cannot bypass that aggregate requirement. The source snapshot is evidence of what was compiled, not permission to accept stale current package sources.

For each stage, required command names are exact: tool discovery/version checks, oracle preparation, DXC compilation, CMake configure/build, WARP execution and oracle verification. Variants require separate compile/execute/oracle steps. Each step must have exit 0, a valid time interval, a real matching log and the expected arguments. The verifier checks shader entry/profile/optimization/definitions/include roots, compiler output paths, the x64 Release host target, the actual host executable used by WARP, every supplied DXIL/input/output path, and oracle script/source identity. It does not recompile or rerun GPU work.

Every required DXIL, listing, host executable, binary input/output and oracle JSON must exist with its recorded byte length and SHA-256. Duplicate/extra/omitted entries are rejected. The host must be an x64 PE, DXIL must have its container signature, the entry must appear in its listing, input case counts and output strides must agree, and the report's oracle summary must equal the actual oracle-results JSON. RayTextureCopy additionally requires its three explicit compiler entries. The material evaluators require pinned Graphics revision `feb4de2d9a93a4ae10d287d3a6d7003d08ea3e53`, all actual copied include identities, required Core/Packing/CommonMaterial/Common file pins, and consistency with the aggregate core include table when present.

These checks require the original TEMP evidence files to remain available on the verification machine. A report copied by itself is insufficient for this stricter verification. A friend receiving only the source archive must rerun the supported checks or receive the separately preserved evidence directory; the package does not silently treat absent local artifacts as passed. These are integrity and linkage checks against an already executed test, not signatures proving an adversary did not fabricate an entire report and every referenced file.

## Verifier regression harness

`Validate-HitMaterialReports.ps1 -EvidenceManifestPath <manifest.json>` accepts an array of `{ "stage": "RayFootprint", "path": "C:/absolute/real-passed-report.json" }` entries. At least RayFootprint, RayTextureCopy and HitMaterials are required. Every positive control uses unchanged byte copies of actual passed standalone reports and validates them against current source hashes and actual files. Parent invocation envelopes are explicitly marked verifier-only fixtures, not unified suite results.

Negative cases are stored in a fresh TEMP directory with each fixture, actual rejection message and expected reason. They cover missing/duplicate reports, old report paths, hashes and embedded mismatches, schema/boolean errors, sources and scripts before/after, compiler steps and arguments, missing or replaced binary bytes, log mismatch, oracle counts, copy kernel coverage and normal encoding/include mismatches. Twelve deliberately incomplete aggregate fixtures each omit one new stage and must be rejected before source/artifact evaluation. Those fixtures are explicitly not test-execution evidence. When supplied, HardwareMaterials and RadianceValidity add their extraction/purpose-specific cases. The harness checks all original inputs again after both positive controls, records an input-file audit, and does not edit old reports or rerun shaders/WARP.

No unified 70-stage success or production validation is established by this regression harness. Unity import/type checking, RenderGraph, native driver behavior, real RTAS traversal, physical-GPU visual output and target-device performance remain outside this evidence.

## Recorded verifier regression

On 2026-10-27, PowerShell 7 and Windows PowerShell 5.1 each passed **76 rejection cases and two positive controls**. The controls read six authentic reports: HardwareSurface, HitMaterials, RayTextures, RayTextureCopy, RayFootprint and the nine-entry HardwareMaterials report. They checked 18 selected DXC entries and 106 actual binary/input/output artifacts. The complete input audit additionally covered source files, logs, copied includes and the verifier scripts: **400 original files**, unchanged before/after the tests.

HardwareMaterials used the separately preserved, hash-verified B8D132/D423 source snapshot. This historical standalone result is not presented as validation of later workspace changes. An earlier test also validated the 2,526-case RadianceValidity report, but new footprint/view propagation changes require a new source-bound report and extraction contract. HardwareNormals' old report likewise cannot substitute for a new report with the current HardwareTrace identity. The complete aggregate verifier retains both as mandatory stages.

Preserved final evidence:

- PS7: `%TEMP%/hlgi-hit-material-report-negative-90c9b9571dca474aa327d3cbb6574303/verifier-results.json`, SHA-256 `70CB4DFD22CFAFF7DC54845510DA86CC8ED4BCA98842F1231361B28D6649E7E8`. Its 400-file audit is beside it, SHA-256 `6FEB4E56E317DFCF88FF2EC3A37C21BD1688AA1CF2E52519BFFB6842B34B11D0`.
- PS5: `%TEMP%/hlgi-hit-material-report-negative-b6d4b0c79da64c4e840c518f689e21f2/verifier-results.json`, SHA-256 `813B40239CDEF73902E019CC91B9C25DC8AD0A49CB4F367B4C5E44541A76DD7B`. Its audit SHA-256 is `A21FF0E25BDA79117EB93BFE5179DF34346E462D1EDF300E26CA96FDAAA2176C`.
- Source snapshot and manifest: `%TEMP%/hlgi-material-verifier-frozen-e457f3f739484ccca8bf876e65277d0f/`, containing `evidence-manifest.json`. Each copied source was checked against the authentic report hash before the fixture was created.

Reproduction uses either PowerShell host with `Tests/Validate-HitMaterialReports.ps1 -EvidenceManifestPath <snapshot>/evidence-manifest.json -SourceRoot <snapshot>`. The verifier script at this result has SHA-256 `2E04454C7E886890B758CE79228A796B9813771772684E7920D33E4F7119B0AF`; its negative runner has SHA-256 `EE20B8233BAD7FAC89EC480135437965EA68FBFB24DAFE90DB6199F81D5FFD8B`. These results do not execute the 68-stage runner, rebuild a native host or rerun any shader/WARP test.

## Limited 69-stage integration check

The existing 76-case regression matrix was rerun without expansion after registering RayQueryPropagation: PS7 and PS5 each passed 76 rejections and two controls, with 400 original files unchanged. These controls still use the six historical source-bound reports described above. Their new evidence is `%TEMP%/hlgi-hit-material-report-negative-46760b93b17141c4840c8d2a5f1c3c04/verifier-results.json` (PS7, SHA-256 `B9C4872B0D906299AED59FF4217357232776F8E214AD5605CAB78F33BA3EFEEE`) and `%TEMP%/hlgi-hit-material-report-negative-8a2e6d211f5344cc8b6005f62534bebc/verifier-results.json` (PS5, `3DCF4C42F76570AE849269DE69E9B4C8BCD08BB859AE8AC5FF984F7026BCA326`).

Separately, both shells verified the authentic RayQueryPropagation report against its complete source snapshot and actual artifacts; evidence is in `%TEMP%/hlgi-ray-query-report-proof-0f763b14b43c463eb0b59ebe5ba2d1f4/`. Its older whole-Transport snapshot is not substituted for current package validation.

The final RadianceValidity contract includes 13 exact source bodies: committed-material publication, point footprint, primary TraceShadow plus two compatibility wrappers, owner validity, primary DirectIrradiance plus three wrappers, primary ProxyRadiance plus its wrapper, and TraceScreen. It also binds the actual RayFootprint header. The new authentic report `%TEMP%/hlgi-radiance-validity-warp-20a418b41f1148a4849a042d1004d4ec/radiance-validity-results.json` (SHA-256 `09B4CFC9FEBF2DD59E1C812550AC7A92A0DBD0936BDC58D6270F6AC128C85482`) passed the updated proof in both shells, followed by the existing missing-extracted-functions rejection. Those verification-only fixtures/logs are in `%TEMP%/hlgi-radiance-report-proof-53b61f71e8f246f4a9e41d96e8326f06/`. No GPU execution was repeated by these proof checks.

All four modified PowerShell scripts passed AST parsing. No 69-stage unified run was started. When the runtime and test sources are frozen, the complete command is `powershell -NoProfile -ExecutionPolicy Bypass -File Tests/Validate-Offline.ps1 -ReportPath <new-absolute-report-path>`; its final step invokes the same aggregate artifact verifier. Preserve the resulting run directory and referenced evidence files for subsequent verification.
