> 历史专项快照：下文次数与哈希仅属于记录时的来源。当前交付的通过结果以 [统一离线报告](offline-validation-results.json) 和 [证据入口](../Documentation/OfflineValidation.md) 为准；不能把本文旧哈希继承给新源码。

# Hit material batch validation

2026-10-27: PowerShell 7 and Windows PowerShell 5.1 each compiled the seven actual runtime classes and passed **5,309 assertions in 9 scenarios** using recording/fence adapters. No Unity editor/player, RTAS, GPU submission or physical GPU execution occurred in this test.

Command: `pwsh -NoProfile -File Tests/Validate-HitMaterialBatch.ps1` (also executed with `powershell -NoProfile -ExecutionPolicy Bypass -File Tests/Validate-HitMaterialBatch.ps1`). The runner rejects runtime source changes during its execution.

The material table has a 240-byte record and a separate 32-byte instance binding. Source identity is `(stableId, ownerRevision, geometryRevision, submesh)` and material generation is independent of texture generation. Zero bindings represent unknown material; rejected sources retain their original instance ordinal. Snapshot equality is checked again before commands and after the texture uploader, without replacing frozen values with live data. RenderTexture's historical reuse rejection is not misused to reject its ordered current-frame copy.

Resources are accounted globally: all outstanding material/binding bytes plus all texture-pool bytes. A partial/unknown command result prohibits consumption and remains budgeted. The same command buffer may append a final-consumer fence later, including after disposal, solely to permit retirement. A completed actual fence can recover a pool-only transient read failure; subsequent failures remain quarantined. There is no age timeout, CPU-frame completion inference or synthetic completion boolean.

Validation details and adapter limits are in [StandaloneHitMaterialBatch/README.md](StandaloneHitMaterialBatch/README.md). The randomized oracle tests public observable use/retirement rules; source and GPU classes are compiled directly rather than mirrored in the fixture.

| Actual runtime source | SHA-256 |
|---|---|
| HybridLumenGIHitMaterialBatch.cs | `72236C23D2567C0970136EF852B119761DAD1A05887F9FDB39126D0ED513EAA9` |
| HybridLumenGIRayTexturePool.cs | `F2E447CE8E0177E82B25BAA3E13E6CF7D8B32C43E179F5403FEE558D286F54C3` |
| HybridLumenGIRayTextureImporter.cs | `2DEEB3555624741ECAAD2AECC22292159CCF7AFF956E223A6F30131EE119EF73` |
| HybridLumenGIRayTextureLayout.cs | `0AEF25B97AB2643C36B429FF7CA5D3DD565537C978AD5463F7FA290431139A6B` |
| HybridLumenGIHitMaterialLayout.cs | `17786C8CA01FB97F539757AB1BF9855C68D5A02E6E2075012F9006FC66A23075` |
| HybridLumenGIHitMaterialData.cs | `5EB8CFF0CE5A8418D3DC81CA3FFFE49C0B588CD863C4E844A4C5195736F33689` |
| HybridLumenGIMaterialSource.cs | `26B45B372A6FCAB865E24FFBAABE56CEB1DD1FAFE12DC33BFFD990C02F9F58D3` |

This validates the coordinator and its CPU/native API boundary contract. It does not establish correct integration ordering in a running Unity RenderGraph, producer synchronization, final-consumer fence behavior on the real device, or readiness of a source texture whose external producer changed without an observable version update.
