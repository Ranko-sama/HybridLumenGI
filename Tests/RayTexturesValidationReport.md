> 历史专项快照：下文次数与哈希仅属于记录时的来源。当前交付的通过结果以 [统一离线报告](offline-validation-results.json) 和 [证据入口](../Documentation/OfflineValidation.md) 为准；不能把本文旧哈希继承给新源码。

`Validate-RayTextures.ps1` passed under PowerShell 7 and Windows PowerShell 5.1: **36,214 actual WARP cases / 108,642 assertions**, including 36,163 known samples and 51 rejected unknown inputs. Maximum component error relative to `max(1, abs(reference))` was **1.2344518979e-5** against the independent double-precision periodic-image oracle. The test compiles and executes the runtime HLSL; it does not replace it with CPU sampling code.

`HLGISampleRayTexture(uint2 handle, float2 uv, float explicitAbsoluteLod, out float4 rgba)` reads the 64-byte metadata and original tightly packed mip texels. Handle generation, ready state, dimensions, mip-chain length, full stored count, buffer capacity, reserved fields, sampler fields and finite data are checked before returning known. False means unknown, not transparent. Source RGB is already decoded before entering this sampler; no gamma operation is performed here.

The contract uses explicit isotropic LOD plus bias, clamped to the stored resident tail. Point and bilinear choose nearest mip with ties rounded upward; trilinear interpolates two adjacent mips. Integer texel wrapping implements Repeat/Clamp/Mirror/MirrorOnce, with bounded coordinate reduction before conversion so huge finite UVs cannot overflow an integer. Anisotropy remains metadata for future work and is not implemented by this test.

Current reports and their DXIL, compiler listings, executable, inputs, readbacks and invocation logs:

- PowerShell 7: `%TEMP%/hlgi-ray-textures-warp-448d9dfaf13f4f2797a4d05b3ad7b031/ray-textures-results.json`.
- PowerShell 5.1: `%TEMP%/hlgi-ray-textures-warp-8b308557e9be404aaf26eae08052a5a8/ray-textures-results.json`.

Runtime sampler SHA-256: `30D523BF57D1A357F3D4C7A27FAA602228726D18CFB195D3D4044236E73D3BCD`.
Runner SHA-256: `7BA3F1293A8AA3148A0CC4BE57E0ADF143FD87B1DE39CBCEEBB50530EA451429`.

An additional material integration test exposed a failure in optimized DXC/WARP execution when the previous dynamic mip-validation loop with early return was nested in a material-map loop. The standalone sampler results above did not expose that failure. The same material test passed with `-Od` and with an equivalent fixed 15-term mip sum. Production now uses the fixed sum: validated dimensions of at most 16384 by 16384 bound the complete mip chain to 357,913,941 texels, so the sum cannot overflow `uint`; exact stored-count equality remains mandatory. The material test's controls and regression evidence are preserved under `%TEMP%/hlgi-hit-material-od-18dc1c8211d9455ab85bbbe608ff7cd8` and `%TEMP%/hlgi-hit-material-fixed-mips-bf6907e1c356478cbc39542af597d8d4`. This does not isolate whether the defect lies in optimized DXIL generation or WARP execution. The prior sampler reports (`adb08602bbcb4be982547c4fc428941f` / `1b7317b1246c4e7198290f05a9ed2b37`) remain unchanged and refer to the earlier source hash.

These are shader arithmetic and descriptor-bound buffer tests on a D3D12 software adapter. They do not execute Unity texture import/copy, streaming changes, native sampler precision, DXR candidate alpha, or a physical GPU. The original-texel pool is a new implementation path; this report does not claim it is already connected to the production GI path. Integration13 archives remain unchanged.
