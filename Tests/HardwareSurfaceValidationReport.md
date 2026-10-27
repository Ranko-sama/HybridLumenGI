> 历史专项快照：下文次数与哈希仅属于记录时的来源。当前交付的通过结果以 [统一离线报告](offline-validation-results.json) 和 [证据入口](../Documentation/OfflineValidation.md) 为准；不能把本文旧哈希继承给新源码。

# Hardware surface geometry validation

The 2026-10-27 PowerShell 7 and Windows PowerShell 5.1 runs both passed **790 actual WARP cases / 18,173 assertions**. The fixture accepts 781 valid material frames and 783 valid texture footprints. Maximum component error against the double reference is `2.3572738050425812e-7`; maximum LOD error is `1.7940513581393702e-6`.

The actual HLSL computes per-vertex transformed normal/tangent interpolation, normal-map world normals, URP's per-vertex tangent-space parallax-view interpolation and triangle UV ray-cone footprints. The CPU oracle independently projects disks and solves triangle barycentrics for the footprint. [The fixture README](StandaloneHardwareSurface/README.md) explains coverage, operation order and the corrected earlier oracle limitation.

Reproduce with `Tests/Validate-HardwareSurface.ps1`. No Unity installation is required. The report explicitly sets Unity and physical GPU execution to false. Runtime helper SHA256 is `A87C4778D7E14D5D236D5B0E351AA2766C33767440084DE0A3AA18A032F19164`; runner SHA256 is `724ED93921B7B19F3180BDBE3805B9A173D9A739F556985C15419E4201E59326`.

Raw report locations on the validation machine:

- PowerShell 7: `%TEMP%/hlgi-hardware-surface-warp-f1e1af2562284cf5afca13eb5405c01b/hardware-surface-results.json`, SHA256 `6C5003FDF9C5E7C63ECF48E7AEEF0394BC5537187763A1D326C5C754259A6F4A`.
- PowerShell 5.1: `%TEMP%/hlgi-hardware-surface-warp-829e91c636f545e38368c446924efcf4/hardware-surface-results.json`.

Earlier 788-case reports used an incorrect parallax interpolation assumption in both helper and reference. Independent review produced a counterexample, and the implementation and fixture were corrected. Those historical passing reports are not evidence of URP parity. The current regression returns `(0.5773502588, 0.5773502588, 0.5773502588)`, agreeing with the vertex-stage contract.

These results do not validate Unity imports, DXR candidate traversal, complete ray-cone propagation, rendered images, physical GPU performance or production readiness. Integration-13's frozen main report remains unchanged and does not cover this new module.
