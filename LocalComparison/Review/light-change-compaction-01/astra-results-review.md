# Astra result review — light-change-compaction-01

Decision: **no blocking finding; ready for actual Pro review and a local commit decision**. The saved baseline establishes the index-compaction false positive, and the candidate removes that false positive without altering the effective current lighting table. No additional native run or test matrix is warranted for this change.

The review inspected the Runtime and test diff, both process logs, the frozen sources, source-identity.json and ReviewBrief-LightChangeCompaction01.md. It performed read-only source/hash comparisons and did not rerun tests or launch Unity. Only this review document was written.

## Established counterexample and repair

The actual collector first receives `[P, D]`, then only P is disabled in the same discovery frame. The baseline has already compiled and run the original guards before failing the intended semantic assertion:

- Baseline current table: `[D]`; changes: `[P, D, D]`.
- Candidate current table: `[D]`; changes: `[P]`.

The table assertions establish that the remaining D is the original complete directional record, and that the removed tail entry is cleared. The logged effective-prefix comparisons are identical between baseline and candidate:

| State | Count | Controlled hash | Effective-prefix SHA-256 |
| --- | --- | --- | --- |
| Before P is disabled | 2 | 1993486355 | `9437F3FA4E2C9863547626EAD3597759F91C38D297F2B81647BE46397C07F25F` |
| After P is disabled | 1 | 1803522448 | `61CA164923BC81050839D2535AC2DB2C93676BC91BC3CE344362A5F912C99570` |

These hashes describe the current admitted 80-byte Data records. The fixture's deterministic Vector4 hash was frozen before both executions and is byte-identical between them. It is explicitly a controlled adapter hash, not a claimed native Unity hash value.

The source link to the product effect is direct: RendererFeature.UpdateLights passes changes to AddLightChange; a directional record invokes MarkGlobalLightingChange, which sets globalReactive to 1. Removing the unchanged D entries prevents that particular false global-lighting notification. This is not an executed whole-frame reactive measurement, a geometry invalidation fix, or proof of visible image improvement. Other legitimate changes can still request global reactive.

## Candidate semantics

- Before overwriting destination, previousData copies exactly this caller's previousCount prefix. No previousCount or historical table is carried from a different camera call.
- Current collection order, TryPack, discovery membership, capacity admission, tail clearing and hash accumulation retain their original code/behavior. The 80-byte ABI and complete Data.Equals are unchanged.
- Each old occurrence matches at most one current occurrence through currentMatched. Full record comparison includes all four Vector4 fields and all four uint fields. No hash-only or approximate equality is introduced.
- Only unmatched old records and unmatched current records are reported. Identical lights remain separate contributions in destination; removal of one identical occurrence still reports one removal.
- currentMatched is cleared over the entire current effective prefix on each call, including after smaller/larger camera tables. Unused scratch suffixes are not read. The interleaved A/B case uses distinct table lengths and admission limits and demonstrates independent old/new differences.
- A moved light reports both old and new complete records. Capacity replacement, shrink and growth continue reporting genuinely departing/entering records, including a newly admitted directional light; the fix does not suppress all directional changes.

The admitted feature count is bounded at 32. The straightforward quadratic exact matching is appropriately small here; the patch introduces no new light identity manager, selection policy, scheduling rule, shader path or history owner.

## Evidence and boundary

The candidate process reports 301 assertions passing, covering the existing collector guards and the narrow compaction, duplicate, actual-change, capacity and interleaved-camera additions. The count is a description of the fixture, not a production acceptance metric.

The frozen baseline component matches committed `0994d15fb1d574fa62fa34cb5a37b2c0a2509fd7` text after newline normalization. Frozen baseline Program and UnityStubs match the current candidate inputs byte-for-byte. All five current source hashes in source-identity.json were independently checked against the files, and the Runtime hash printed by the candidate process matches the current candidate.

Only Runtime/HybridLumenGILights.cs changes product behavior. The original Validate-Lighting and C# harness entry points remain unchanged. The adapter hash change is isolated to the test environment. No Unity discovery, rendering, GPU, energy/brightness or performance execution is claimed, and prior native results remain attached to their original source versions.

The brief keeps these distinctions correctly. Submit the bounded repair; there is no reason to revisit lifecycle variations, the dark region, MC, exposure or timing for this package.

## Reviewed source hashes

| Source | SHA-256 |
| --- | --- |
| Runtime/HybridLumenGILights.cs | `296f658dcfb1e41271d4b0d0b9452151517e8df830654311f616b77312e6349c` |
| Tests/StandaloneLighting/Program.cs.txt | `1f7ee0b22ef8087fd247f2bf2d21b1ebe8b81e0be9424b955868d59591a5fe02` |
| Tests/StandaloneLighting/UnityStubs.cs.txt | `be85a3f949c36b725ccf633e9886aaa11c9bb5417529739604ba813a2969d0a9` |
| Tests/Validate-Lighting.ps1 | `0822ab6d007e77720c40f716ef6918af3f9e9818f6a85c3c6e3005492b003d3a` |
| Tests/Invoke-CSharpHarness.ps1 | `461c0eda33ebd408d18a9fdc76e1c944cc7a80bc6d7f3420c59135e6db064ed7` |

