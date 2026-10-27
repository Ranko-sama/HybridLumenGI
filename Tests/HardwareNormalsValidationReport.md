> 历史专项快照：下文次数与哈希仅属于记录时的来源。当前交付的通过结果以 [统一离线报告](offline-validation-results.json) 和 [证据入口](../Documentation/OfflineValidation.md) 为准；不能把本文旧哈希继承给新源码。

The hardware hit shading normal now follows URP's operation order: inverse-transpose and normalize each source vertex normal, interpolate the transformed normals with the actual triangle barycentrics, then normalize. Geometric normals, winding/side admission and the 128-byte instance / 80-byte triangle attribute ABI are unchanged. Missing, zero or nonfinite source normals and degenerate interpolation cannot set `HLGI_HIT_SHADING_NORMAL`; the existing raw geometric fallback remains an occluder.

The reference is the fixed Unity Graphics commit [`feb4de2d9a93a4ae10d287d3a6d7003d08ea3e53`](https://github.com/Unity-Technologies/Graphics/blob/feb4de2d9a93a4ae10d287d3a6d7003d08ea3e53/Packages/com.unity.render-pipelines.universal/Shaders/LitForwardPass.hlsl), `LitPassVertex` / `InitializeInputData`, together with [`GetVertexNormalInputs`](https://github.com/Unity-Technologies/Graphics/blob/feb4de2d9a93a4ae10d287d3a6d7003d08ea3e53/Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderVariablesFunctions.hlsl). The runtime helper independently implements that order with finite input checks and common positive rescaling for numerical range.

`Validate-HardwareNormals.ps1` passed under PowerShell 7 and Windows PowerShell 5.1. Both runs compiled the actual runtime HLSL helper with installed DXC, dispatched the resulting DXIL on D3D12 WARP, waited for a GPU fence, and read back 4,183 results. An independent double-precision oracle starts from source object-to-world matrices and reconstructs per-vertex covectors; 16,666 assertions passed. Source contracts additionally check that `HardwareTrace.hlsl` invokes this executed helper and retains its explicit source-normal flag/fallback.

| Measured check | Result |
| --- | --- |
| Previous HLSL order, nonuniform-scale regression | 3.1765854596 degrees error |
| Corrected actual helper, same regression | 0.0000008538 degrees error |
| Maximum component error across valid cases | 8.98388999e-7 |
| Maximum angular error | 5.18768493e-5 degrees |
| Maximum unit-length error | 1.18689849e-7 |
| Actual test input/output DXIL ABI | 144 / 48 bytes |

The original successful reports and their DXIL, listings, native executables, binary inputs/readbacks and command logs are retained under:

- PowerShell 7: `%TEMP%/hlgi-hardware-normals-warp-9cd3c9d53ab34405badc9c3ba67b97b3/hardware-normals-results.json`.
- PowerShell 5.1: `%TEMP%/hlgi-hardware-normals-warp-98a42a002b6748d589f6b58817136590/hardware-normals-results.json`.

Validated runtime helper SHA-256: `419BFF04B6F9B44CFFDA3343AE0DDDDB4B0F3EE185B8DE309404D7475CD22A4B`.
Validated trace SHA-256 at this standalone run: `932249DEFE2F1E301CBEAC373E5F26DA90F637A72254AA8D1A38ACA57097B8A3`.
Runner SHA-256: `3FECE86CA38680E105935EAFE6491FAE7271B582F9DD0488E426042DD4E98A07`.

This is actual shader arithmetic on the WARP software adapter. It does not execute Unity, real RTAS traversal, imported mesh/normal-map bindings, half-precision raster interpolation, arbitrary platform implementations or a physical GPU. It establishes the normal operation order and tested finite range, not bitwise raster parity or complete hit-material evaluation. No integration13 archive was modified.
