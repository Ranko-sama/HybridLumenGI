# Ordinary Surface BRDF workflow selection

Original goals1/4, workstreams2/7. Base5ed8a0b. Astra first independently selected the workflow discrepancy after closing alpha; actualPro51 separately agreed. This continues the same cumulative Surface consistency work, including earlier Receive Shadows/detail and51 alpha; a new directory does not reset investment. It is a conditional source repair, not an attributed native image fault.

Only `HybridLumenGISurface.shader` product code changes: add retained local `_SPECULAR_SETUP` and choose the existing diffuse fraction by keyword. Keep `_WorkflowMode` declaration/CBUFFER, map sampling, formulas, alpha coverage, other material behavior and output layout. The installed URP BRDF/LitInput functions and Lit variant declaration confirm this choice; the two shader-library includes match the existing compiler cache.

The first frozen baseline and first identical-input candidate executed actual Vert/Frag through the existing WARP host:

| Input | Old diffuse RGB | New/reference diffuse RGB |
| --- | --- | --- |
| scalar metallic, opposite numeric workflow | (.125,.25,.375) | (0,0,0) |
| scalar specular, opposite numeric workflow | (0,0,0) | (.125,.25,.375) |
| metallic map, opposite numeric workflow | (.0625,.125,.1875) | (.18,.36,.54) |
| specular map, opposite numeric workflow | (.18,.36,.54) | (.0625,.125,.1875) |

The two numeric/keyword-consistent scalar controls are byte-identical. In every corresponding row, all output bytes outside diffuse RGB remain identical, including retained coverage, AO.5, emission(.125,.25,.5), validity1 and policy(1,1). References use fixed shader-space A=(.25,.5,.75), scalar M1/S(.125,.25,.5) and distinct legal metallic/specular maps; no authoring color conversion or candidate-derived reference. Color bound stays2e-6. Four complete workflow×map pixel variants compile with real clip. Product source still matches the executed candidate; input/runner identities match between stages. No failure/retry or adjustment after the first candidate.

Evidence: [baseline](../LocalComparison/Review/surface-workflow-keyword-parity-01/baseline/analysis.json), [candidate](../LocalComparison/Review/surface-workflow-keyword-parity-01/candidate/analysis.json), [pre-execution contract](Checkpoint-Iteration52.md), [runner](../LocalComparison/Harness/run-surface-workflow-source.py), [actualPro51 plan](../LocalComparison/Review/surface-alpha-keyword-parity-01/gpt6-pro-review-and-next-plan.txt). Both stages retain exact shader/reference/adapter bytes, generated HLSL, fixed inputs, raw outputs, original logs and command/hashes.

Limits: fixed texture/transform/layer adapters and source clip decisions on WARP; no Unity keyword-transfer, native raster/image, AlphaToCoverage, performance or complete material qualification. No new host/framework, Unity/Player, screenshot/timing capture or alpha/detail/shadow matrix. Release49 remains31c9415 and unchanged. [Astra independently accepts finite closure](../LocalComparison/Review/surface-workflow-keyword-parity-01/astra-independent-review-and-next.txt), recommends ending this cumulative Surface sequence, and selects stable emitter area/CDF reuse as the next candidate. [ActualPro52](../LocalComparison/Review/surface-workflow-keyword-parity-01/gpt6-pro-review-and-next-plan.txt) read outputs241/242 and approved local commit and closure, independently selecting the same bounded CPU reuse direction. This does not close all original-plan goals or G0–G5.
