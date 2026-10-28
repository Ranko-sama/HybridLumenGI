# Astra native result review — world-light-relevance-01

Reviewed on 2026-10-28. This review read the sole native attempt, saved source-test results, executed source/manifest and the subsequent small correction. It parsed existing receipts and compared the saved active GPU bytes. It did not run Unity, another build/Player, any test fixture, or the full analyzer.

**Decision: the native admission qualification failed and must remain failed. Retain the minimal alias correction as a source-tested candidate for Pro30 review; do not describe the corrected capability as native-verified.** There was one build and one Player attempt. No retry, warmup extension, tolerance change, camera-domain loosening or new observation matrix is needed to explain this failure.

The sole build verified 111 product sources and five temporary files, produced 284 inventoried files, and restored all temporary wiring. Its executed LightRelevance helper hash was `A632ACE4E095FAF069A9AA16304CD4B772FA3A78182ADC09EB07D820F9A8349E`.

The sole Player, PID 38132, returned native exit 0 without watchdog termination. Run `20261028-142717-9dd55ff5859144559f49f2de674a9c00` contains exactly 64 target receipts, logical 0–63 / engine 1–64, zero captures and zero harness errors. The upload observer completed once with pending zero. These facts establish collection completion, not successful spatial selection.

At logical 63 / engine 64 / GI frame 63:

- The post-fallback hardware flag was true. Across the 64 saved diagnostics, 61 frames reported the hardware backend; this is not a claim that every startup frame used DXR.
- `domainValid=false`, reason `Prepared world traversal bounds are unknown`, status `Unknown domain; legacy admission`.
- The valid/outside/selected/omitted counts were `3 / 0 / 2 / 1`, and the actual C# `_HLGI_LightCount` binding argument was two. The observer does not claim GPU constant-buffer readback.
- The completed 2560-byte light-buffer readback has SHA256 `A0252ADD557A663D23F6B05A7B20C0D985A0CDB37E664F7600EF578489AE06BD`. Its first two 80-byte records separately match the recorded native packed bytes for the two distant lights at X=10,000,000 and X=20,000,000. Thus the GPU table really retained the legacy prefix; the relevant third light was not admitted. The unused tail is not evaluated.
- There were 22 recorded published world slots with six cards each. Slot zero's traversal bounds were finite and ordered, approximately `[-4.571529,-0.321529,-4.571529]` to `[4.571529,0.021529,4.571529]`; its prepared capture bounds were also finite. No frame recorded a valid relevance domain.

The failure is a product-side value-type alias bug, not evidence that these source bounds are invalid. The executed RendererFeature invokes `combined.TryInclude(..., out combined)` for both traversal and capture unions. In the executed helper, `TryInclude` first writes `result=default` and then reads `IsValid` from its receiver. The instance receiver and the `out` argument refer to the same local struct storage, so that write clears the receiver before it is inspected. `readonly struct` does not prevent mutation through an aliased `out` argument. The first nonempty world union therefore returns false and takes the deliberately conservative legacy fallback.

The reason string narrows this path: screen qualification and screen-domain creation had already succeeded before that reason was assigned. The prepared Scene getter uses the same published/warming eligibility as its immediately enclosing loop. The preserved actual-source reproducer independently confirms the alias mechanism: `domain-alias-baseline.log` compiled and reached the new in-place union assertion, then failed there. It was not a compiler/importer failure.

The minimum correction is appropriate. `TryInclude` now reads and validates its receiver and input first. Only its failure branch clears the result. Its successful branch evaluates both Vector3 union arguments by value before the static TryCreate call writes the output. This fixes both current call sites without changing the floating-point margins, supported projections, domain components, light packing, selection order or fallback policy.

The saved baseline/candidate Program bytes match exactly: SHA256 `80A2A8E7FE8DBD5472A891B9698B99F81F02C020B35D732DCF414CD3F192BAB2`. With that same Program, the old helper failed and the corrected actual helper passed 693 checks in `domain-alias-candidate.log`. The corrected helper hash is `2B91F9485CF6B08006ADD5471946D6396A8F08E3A4128274164B7C10339A9CBE`. The explicit `corrected-deployment.json` correctly distinguishes these bytes from the native build and records `correctedSourceNativeVerified=false`. The successful pre-correction build/restoration report must not be reinterpreted as evidence for this later source.

I missed the in-place alias semantics in both earlier Astra gates. Those files remain intact as the actual pre-run reviews; this result supersedes their no-blocker assessment for this defect. The original 691-check lighting fixture used separate output locals for the union cases and therefore did not exercise the Feature's in-place call shape. The added source case closes that specific omission; it is not a reason to expand the test framework or claim the old gate was sufficient.

The existing shutdown sequence reached generic drain complete with generic/material/arena/deformation/worker/failed/unknown counters zero, and the saved native scan reported no attributable warning hits. The generic UTP aggregate is retained without opening a new leak investigation. This limited normal-exit evidence is separable from the failed admission result.

Pro30 can review the concrete source correction and decide the next bounded integration step. The current package can preserve the new capability code plus the correction locally as an explicitly qualified candidate, but cannot close its native admission/upload requirement or replace the original failed analysis with a passing result. No image, radiometry, performance, warming-native, Release or broader production acceptance follows.

Selected evidence SHA256:

| Artifact | SHA256 |
|---|---|
| native-window/analysis.json | 8C134058A2D57A0B750E2BE66127126052412F7CF046DE21CC82A285036590CC |
| binding.json | 97480FCE13986D076A3C3EE386CA6C09F333D0AE4005CF3A85DB6910C07DF0D3 |
| upload.json | 3E7254CD5040BC32C477DC27B612FFBA67756417C56B2DAD97848FFAB5D599CC |
| domain-alias-baseline.log | 19F96B11FAB12A20810BD5C9113350C77B768AA372B74300438AAFFFBA138C51 |
| domain-alias-candidate.log | 1C4D5CDF48D4988641BE8D669C3A2EFE18F2D6DF72EC05E26A841E2C4CB51C63 |
