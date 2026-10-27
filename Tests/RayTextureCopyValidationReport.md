> 历史专项快照：下文次数与哈希仅属于记录时的来源。当前交付的通过结果以 [统一离线报告](offline-validation-results.json) 和 [证据入口](../Documentation/OfflineValidation.md) 为准；不能把本文旧哈希继承给新源码。

`Validate-RayTextureCopy.ps1` passed under PowerShell 7 and Windows PowerShell 5.1: **73 actual D3D12 WARP schedules / 36,099 assertions**, with 45 ready and 28 intentionally unready results. The runner compiled and executed all three runtime kernels and independently checked 9,852 copied texels.

| Actual result | Observed value |
| --- | --- |
| RGBA32F source-to-pool texel difference | 0 |
| Maximum sRGB8 RGB decode error against the double transfer function | 3.0032803422e-7 |
| sRGB alpha | Preserved as linear UNorm alpha |
| Metadata / parameters ABI | 64 / 16 bytes |
| Compiled runtime entries | Begin, CopyMip, Finish — all passed |

Real Texture2D resources and SRVs cover full and truncated chains, rectangular NPOT dimensions, explicit `MostDetailedMip` tails and reduced physical resources matching a later logical tail. Source mips are uploaded through D3D12 copy footprints; all runtime copy dispatches have explicit UAV ordering; readback follows a queue fence. Guard regions around each allocation are checked. This validates shader copy/finalize behavior rather than a CPU reimplementation of it.

The regression suite includes the combined failure discovered during source review: a 16×16 two-mip texture with only half of mip 0 dispatched and mip 1 dispatched three times. Its aggregate count could equal the expected complete-chain count. The corrected per-mip duplicate error rejects this schedule. Missing Begin also remains unready under the explicit copying-state contract. Individual missing/duplicate/partial mip cases, invalid indices/generations/capacities, and nonfinite source values remain unready.

Original reports and retained compiler listings/DXIL, C++ executable, fixtures, readbacks and command logs:

- PowerShell 7: `%TEMP%/hlgi-ray-texture-copy-warp-44c4e9c7da7344a1ac2702b4c639f00c/ray-texture-copy-results.json`.
- PowerShell 5.1: `%TEMP%/hlgi-ray-texture-copy-warp-606f986bb42e4f23914d532709bd2b41/ray-texture-copy-results.json`.

Validated runtime HLSL SHA-256: `227FEDB5EBB628C7954B27EB3D0D0FC0A7B346B3E4FF53F261654768CEDBD272`.
Compute entry wrapper SHA-256: `04AFDD902F8351631495D7AB71A2F1E1ED65BA24E8949D27DA18A85AA1567D87`.
Runner SHA-256: `4EF857A0D3510737CF9DC3C38806F0B0CD622A8076398F183EC165579E452E38`.

This does not establish Unity import/RenderGraph integration, transitions during Unity streaming, reserved/unmapped tiled-resource behavior, arbitrary native producers, DXR alpha material acceptance or physical-GPU performance. `CheckAccessFullyMapped` was executed on committed mapped textures; no unmapped-tile test was fabricated. Integration13 archives were not changed.
