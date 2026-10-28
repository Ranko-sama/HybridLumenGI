# Ordinary Surface alpha coverage

Original goals1/4, workstream7. Base2b2b36c. The single product change makes ordinary Surface coverage follow `_ALPHATEST_ON` and `_SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A`, matching the installed URP17.0.4 Lit keyword contract. Numeric properties remain declared for material compatibility. Existing scalar `clip`, color outputs, receiver policy, depth/Cull, other material paths and AlphaToCoverage behavior are unchanged. This fixes a conditional source discrepancy, not an already attributed native image defect.

The first actual-function baseline established the discrepancies; the first candidate used identical inputs and the same WARP host/adapters:

| Input | Old keep | New keep | Contract |
| --- | --- | --- | --- |
| alpha-test keyword off, numeric clip on | false | true | retain |
| alpha-test keyword on, numeric clip off | true | false | discard |
| smoothness keyword off, numeric channel on, alpha test on | true | false | discard |
| smoothness keyword on, numeric channel off, alpha test on | false | true | retain |

BaseMap alpha0.25, BaseColor alpha1, cutoff0.5 are fixed. Three keyword/property-consistent controls retained byte-identical results. The adapter executes the actual Vert/Frag bodies, records negative clip arguments and masks all discarded payload; colors computed after a recorded discard are never accepted as valid capture. The retain/discard expectation is exact. Retained color has the previous fixed2e-6 float bound; it is not a clipping tolerance. All four directly affected complete pixel variants compiled successfully with real `clip` and the existing include cache. Current installed SurfaceInput/ShaderVariablesFunctions match that cache; installed Lit declarations are archived separately.

Evidence: [baseline](../LocalComparison/Review/surface-alpha-keyword-parity-01/baseline/analysis.json), [candidate](../LocalComparison/Review/surface-alpha-keyword-parity-01/candidate/analysis.json), [frozen execution contract](Checkpoint-Iteration51.md), [runner](../LocalComparison/Harness/run-surface-alpha-source.py). Each stage preserves exact product/helper/reference sources, generated HLSL, fixed cases, binary inputs/outputs, command logs and hashes. Product shader still equals the executed candidate; runner, contract, reference files and input bytes were identical between stages. The baseline's `oldCounterexamplesEstablished=true` and candidate's false field describe their roles; both commands passed on the first attempt.

Scope: source clip decisions through WARP plus complete fragment compilation. No Unity, Player, native raster coverage, keyword-transfer qualification, AlphaToCoverage extension, additional scene capture, host rebuild or broad material suite. Release49 remains frozen at product31c9415. This finite fix does not close all material consistency, native coverage quality or G0–G5. Astra independently accepts finite closure and identifies the numeric/keyword BRDF-workflow difference as the next candidate, ahead of its earlier CDF-reuse alternative; see the [independent verdict and comparison](../LocalComparison/Review/surface-alpha-keyword-parity-01/astra-independent-review-and-next.txt). ActualPro51 review is pending. No further alpha cases are planned; any later Surface work counts toward the same cumulative function investment.

ActualPro51 has now read outputs239/240 and approved local commit and finite closure. Its [full response](../LocalComparison/Review/surface-alpha-keyword-parity-01/gpt6-pro-review-and-next-plan.txt) independently agrees with Astra on the single remaining Surface workflow-selection candidate; no alpha extension or native run is requested.
