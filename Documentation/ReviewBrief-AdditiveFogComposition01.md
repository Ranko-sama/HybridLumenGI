# Additive fog composition — finite correction

Task c2c_a702 iteration47, base ccecf56. Original goal4/workstream7, ordinary URP Lit composition. Independent Astra selected this defect from current code and the full original plan before reading actualPro46's next plan. Pro agreed; this ends the previous deformation/capture stage and addresses a concrete conditional default-path defect. It is not an explanation of an earlier screenshot.

## Product result

Only `Runtime/Resources/HybridLumenGI/HybridLumenGIComposite.shader` changes,8 added lines. Additive runs after Lit fog but previously added unattenuated G. It now reconstructs the existing full-resolution receiver position, obtains the URP fog coordinate and multiplies G by `MixFogColor(1,0,fogCoord).r`. Pass0 has required fog variants. No fog-color source is added, no texture/channel/resource protocol changes, and no fog enters the world cache or bounce feedback. Replace retains its existing captured signed delta and is not attenuated twice; Debug and invalid/unknown guards retain their prior behavior.

## Decision-changing evidence

The frozen contract is `Documentation/Checkpoint-Iteration47.md`, also archived before execution in both stages. `LocalComparison/Harness/run-additive-fog-source.py` reuses the source-matched existing D3D12 WARP host; no new native runner or Unity instrumentation. One baseline batch precedes the product edit, followed by one same-input candidate batch. Both first executions pass; no failures or retries.

Actual unchanged Composite Frag/Reconstruct bodies execute, along with current URP ComputeClipSpacePosition, ComputeWorldSpacePosition, InitializeInputDataFog, ComputeFogFactorZ0ToFar, ComputeFogIntensity, MixFogColor and IsFogEnabled. Their current Unity package sources and the fixed include cache are byte-identical. Texture Loads and the upstream already-resolved GI are explicit adapters. The adapter supplies depth/matrices/fog parameters, never the Additive transmission. Nonzero camera worldZ8 and near2 make the actual view transform and near subtraction observable. Reversed orthographic near2/far18, depths .875/.625/.375 produce worldZ4/0/-4, eye distances4/8/12 and expected linear fog T1/.5/0.

Known G=(1,.25,.0625) includes actual receiver diffuse, materialAO and intensity exactly once. Nonzero fog color(3,5,7) must remain in original camera color, not be added by Composite.

| Linear transmission | Old actual Frag RGB | Candidate actual Frag RGB |
| --- | --- | --- |
| 1 | (1,.25,.0625) | (1,.25,.0625) |
| .5 | (1,.25,.0625) | (.5,.125,.03125) |
| 0 | (1,.25,.0625) | (0,0,0) |

The same finite inputs also retain Replace signed result(.25,-.125,-.03125), measured-black Replace(-.25,-.25,-.0625), Debug1 unattenuated RGB/alpha1, unknown GI zero, invalid material zero and capture-depth rejection zero. Every unaffected color and every no-fog color is byte-identical to baseline. The predeclared absolute float bound2e-6 was not changed. Actual reconstructed positions, fog coordinates and transmission also match the independent camera/fog reference. Affected full pass vertex and no-fog/linear fragment compile with the fixed current dependencies, all exit0.

## Evidence and limits

`LocalComparison/Review/additive-fog-composition-01/baseline/` and `candidate/` retain frozen runner/contract, exact product and dependency sources, extracted actual compiled HLSL, cases/input/raw output, commands/logs and first analyses. Input SHA256 is a76421448380b35bcdfd4b97e0c0bbf68d93cd83cd75d27f880ad5f7469c3ca6 in both; the runner is byte-identical. Source verification records the sole product difference and local reproducible compiler artifact hashes.

This establishes the conditional source defect and finite corrected shader behavior. It does not execute Unity rasterization, upstream Resolve filtering, RenderGraph, runtime fog variant selection, arbitrary cameras or all fog types. Zero Unity/Player/build/screenshots/timing; existing deployment and Release44 remain5120a8c. Do not upgrade previous native evidence to this candidate.

Review actual outputs and scope, then close this source correction or identify a concrete blocker. Do not expand a fog/material matrix without a new product uncertainty. Independent Astra is selecting a next step from the full original plan before seeing any new Pro/main plan. Full G0–G5 and unanswered production budgets remain open.
