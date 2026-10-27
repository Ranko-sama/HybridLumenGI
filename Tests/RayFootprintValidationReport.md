> 历史专项快照：下文次数与哈希仅属于记录时的来源。当前交付的通过结果以 [统一离线报告](offline-validation-results.json) 和 [证据入口](../Documentation/OfflineValidation.md) 为准；不能把本文旧哈希继承给新源码。

# Ray footprint validation

On 2026-10-27, PowerShell 7 and Windows PowerShell 5.1 each passed **1,530 actual HLSL/WARP cases and 19,891 independent checks**. Maximum relative error was **1.7878753388e-5**, in the explicit angle-to-slope case nearest pi. There was no Unity execution or physical GPU measurement.

Commands: `pwsh -NoProfile -File Tests/Validate-RayFootprint.ps1` and `powershell -NoProfile -ExecutionPolicy Bypass -File Tests/Validate-RayFootprint.ps1`.

Current source identities:

- Runtime helper: `6EA7286E57ABDE318F1E318E17CEC6ED1E1C0E8451DD7E3546FB62977741B1AC`.
- Validation runner: `461F4C2D170E3719EBE0680A41999B68541DD849E046D4CC7BCA671722076353`.

Original reports retain seven before/after source hashes, compiler invocation and listing, DXIL, actual C++ executable, binary inputs and fenced readbacks, double-oracle results, and command logs:

- PowerShell 7: `%TEMP%/hlgi-ray-footprint-warp-32b12890493742c7b7983c91fc5c540e/ray-footprint-results.json`.
- PowerShell 5.1: `%TEMP%/hlgi-ray-footprint-warp-a5f05be8a41742cc9f59305cf543c29a/ray-footprint-results.json`.

Coverage includes split-distance/far-origin propagation, finite/invalid state, signed pixel offsets, full-pixel versus explicitly enlarged spans, random scales/shear, exact odd-size card partitions, off-center anchors, projected ellipse bounds, point-light convergence and directional-light parallel bundles. Card-reference geometry uses independent double Gaussian elimination; the retarget reference samples 8,192 perimeter directions rather than reproducing the shader's eigenvalue calculation.

[The companion README](StandaloneRayFootprint/README.md) specifies all function signatures, world radius versus diameter, radial slope versus angle, actual card coordinate conventions, sources and limitations. The screen/card functions construct only the spatial footprint. **Diffuse BRDF angular broadening remains pending**, and this isolated helper does not establish the complete transport pipeline. In particular, no guessed spread angle, default mip zero, or parallel spatial bundle is described as a finished multiple-bounce filtering model.
