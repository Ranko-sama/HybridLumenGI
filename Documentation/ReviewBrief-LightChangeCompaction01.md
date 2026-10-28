# Pro review brief: light-change-compaction-01

Task c2c_a702, iteration29; baseline0994d15 is the approved snapshot ownership repair. OriginalDevelopmentPlan.md remains the full scope. This package follows Pro28's concrete light-change finding and has zero Unity/Player/GPU runs.

## Actual counterexample and same-input repair

Tests/Validate-Lighting.ps1 compiles the actual Lights.cs against the existing discovery/component adapters. Before the baseline run, the final Program and adapter bytes were frozen together with the unmodified component. The only adapter change makes Vector4.GetHashCode deterministic across processes, enabling a same-adapter before/after comparison; these numeric hashes are not native Unity hash values.

The existing packing/discovery guards execute first. The new case establishes [point P, directional D], disables only P within the same discovery frame, and checks the actual current table and changes. Baseline produces [P,D,D] and fails the intended semantic assertion. It has already compiled and executed the actual Update path. Candidate with identical input produces only [P].

Both before and after table byte SHA256, count and controlled hash are identical between baseline and candidate; source-identity.json records the two comparisons. In particular the remaining directional light is still uploaded. Only the invalidation list changes; this is not a lighting-energy/brightness adjustment or a visual-quality result.

## Product change and bounded validation

Only Runtime/HybridLumenGILights.cs changes product behavior. Reused scratch Data[] copies this caller's previous effective prefix before destination is overwritten. Generation of the new table, capacity admission, 80-byte ABI, hash accumulation and tail clearing retain their original behavior. Reused bool[] marks each current record matched at most once by full Data.Equals. Unmatched old records are reported first, then unmatched new records. There is no approximate/hash-only comparison, deduplication of the GPU table, new identity manager or cross-camera saved history.

Candidate execution passes301 assertions, including the original ABI, shadow/mask/color/bake rules, same-frame activation and discovery, old/new changes and capacity checks. Added cases cover front/middle compaction, identical contribution multiplicity, real movement old/new domains, bounded-set replacement/shrink/growth and two interleaved camera tables with different limits. No extra native/shader matrix is needed. Complexity is quadratic in old/current admitted counts; the feature caps each at32, and scratch storage grows only to the observed prefixes. This does not change the existing 32-light selection policy.

Evidence is in LocalComparison/Review/light-change-compaction-01: baseline-command.log, candidate-command.log, frozen baseline and candidate sources, source-identity.json. Baseline product bytes match committed0994d15 and test/adapter bytes remain identical. The original Tests/Validate-Lighting entry point and C# harness are unchanged. The logs are the actual process outputs; no baseline failure was replaced.

Astra approved the bounded design and final candidate/results with no blocker; its review is saved in the package. Please list/read iteration29 execution outputs, actual diff, frozen input and Astra result. Decide whether to retain this repair and select a substantive next original-plan package, without reopening lifecycle variants or darkness/MC/exposure/timing. Old native evidence is not upgraded: the repository now includes the accepted deformation cleanup change and this pending light change, while the Unity deployment remains its earlier source.

An independent Astra direction check also cautioned against more lifecycle variants. Its two possible functional priorities were stable-topology readable-snapshot deformation correspondence for temporal reuse, and spatially relevant/stable selection under the existing world-light cap. These are suggestions for independent prioritization, not preapproved implementations or evidence of a new image defect. Do not silently broaden this compaction repair to either feature.
