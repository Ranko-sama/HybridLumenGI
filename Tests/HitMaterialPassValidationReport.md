> 历史专项快照：下文次数与哈希仅属于记录时的来源。当前交付的通过结果以 [统一离线报告](offline-validation-results.json) 和 [证据入口](../Documentation/OfflineValidation.md) 为准；不能把本文旧哈希继承给新源码。

# Hit material pass validation

2026-10-27: PowerShell 7 and Windows PowerShell 5.1 each compiled eight actual runtime classes and passed **828 assertions in 9 scenarios**. The runner checks the before/after identities of all eight runtime sources. This is a CPU recording/RenderGraph adapter test, not Unity or GPU execution.

Commands:

```powershell
pwsh -NoProfile -File Tests/Validate-HitMaterialPass.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File Tests/Validate-HitMaterialPass.ps1
```

The test confirms import ownership and keyword-dependent source dependencies, complete two-kernel binding before consumption, exact source/reference comparisons, final-consumer fence ordering, failure quarantine, and explicit owner cancellation of never-executed graphs. The detailed scope and adapters are in [StandaloneHitMaterialPass/README.md](StandaloneHitMaterialPass/README.md).

A compile-time issue found during review was corrected by the runtime owner: frozen snapshot reference checks use the real `SourceRenderer` and `SourceMaterial` properties. No additional runtime blocker was found by this harness. A failed one-shot Finish can retain resources indefinitely; the harness does not present its test-only reflection cleanup as a production recovery API.

Read-only Feature review found the same pass instance copied into Work, all four buffers declared ReadWrite, used source textures declared Read, geometry/material sources revalidated before recording, software fallback on preparation/record/binding rejection, and Finish in the transport finally after the consumers. These observations are source review, not execution of Feature or Unity RenderGraph. The hardware backend separately validates the renderer/mesh/pose/geometry identities before producing the source tuple compared by this pass.

| Actual runtime source | SHA-256 |
|---|---|
| HybridLumenGIHitMaterialPass.cs | `E0F92793119410BBEE972E1847AA7014C5A2BB0A56863A12469B2B4E0E97F93B` |
| HybridLumenGIHitMaterialBatch.cs | `72236C23D2567C0970136EF852B119761DAD1A05887F9FDB39126D0ED513EAA9` |
| HybridLumenGIRayTexturePool.cs | `F2E447CE8E0177E82B25BAA3E13E6CF7D8B32C43E179F5403FEE558D286F54C3` |
| HybridLumenGIRayTextureImporter.cs | `2DEEB3555624741ECAAD2AECC22292159CCF7AFF956E223A6F30131EE119EF73` |
| HybridLumenGIRayTextureLayout.cs | `0AEF25B97AB2643C36B429FF7CA5D3DD565537C978AD5463F7FA290431139A6B` |
| HybridLumenGIHitMaterialLayout.cs | `17786C8CA01FB97F539757AB1BF9855C68D5A02E6E2075012F9006FC66A23075` |
| HybridLumenGIHitMaterialData.cs | `5EB8CFF0CE5A8418D3DC81CA3FFFE49C0B588CD863C4E844A4C5195736F33689` |
| HybridLumenGIMaterialSource.cs | `26B45B372A6FCAB865E24FFBAABE56CEB1DD1FAFE12DC33BFFD990C02F9F58D3` |

Actual Unity producer synchronization, SRV residency, GraphicsFence/device behavior and execution of the imported resources remain unverified by this test. An imported handle is not sufficient evidence of synchronization with an external producer using a different handle.

Preserved local command logs (both exit 0) are `%TEMP%/hlgi-hit-material-pass-ps7-e3498e54031046c383fe55fb27ec8172/validation.log` and `%TEMP%/hlgi-hit-material-pass-ps5-ec9e269907dc4b52805e481596f8e0d8/validation.log`. Both contain identical result/source identities and have SHA-256 `E358EBD4E15C5570FF5824976311ECF77D42D553F7B8E44F9680D264BC3476AC`. The test script SHA-256 is `5FAC2378C8C3BC92D91396B0EC2C5911DE180DB2F38E1BACDECC0B798657D589`.
