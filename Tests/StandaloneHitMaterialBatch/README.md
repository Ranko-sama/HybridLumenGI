# Hit material batch recording harness

Run `pwsh -NoProfile -File Tests/Validate-HitMaterialBatch.ps1` or the same command under Windows PowerShell 5.1.

The harness compiles these seven actual runtime classes together: `HybridLumenGIHitMaterialBatch`, `HybridLumenGIRayTexturePool`, `HybridLumenGIRayTextureImporter`, `HybridLumenGIRayTextureLayout`, `HybridLumenGIHitMaterialLayout`, `HybridLumenGIHitMaterialData`, and `HybridLumenGIMaterialSource`. Their before/after SHA-256 identities must match. The test does not replace allocation, source equality, encoding, recording, or retirement methods with a reimplementation.

Unity objects, property reads, native buffer allocation/disposal, command recording and fences are explicit CPU adapters. Array uploads are copied when recorded. Commands can fail before or after an append and invoke cancellation callbacks. A fence has manually controlled completion and error observations; this is not a Unity driver or real GPU fence test. The `Color.linear` adapter applies the standard sRGB equation and does not test Unity's native color implementation. Production source generation counters are seeded through reflection only in the overflow test; production has no reset API.

The nine scenarios cover:

- 240-byte records and 32-byte per-instance bindings, full-width source IDs, stable ordinals with unknown holes, and a real unready 80-byte texture-pool dummy for constant-only materials.
- Used-map collection, deduplication by texture reference plus the complete frozen observation, unrelated object hash collisions, NPOT mip allocation, and disabled maps that create no upload dependency.
- Material/MPB changes before recording and during texture upload, per-source read exceptions, read-only originals, and a current-frame RenderTexture snapshot accepted despite being ineligible for historical reuse.
- Exact global material-plus-texture budgets across independent batches and other pools; 4,096 material, 1,024 unique texture and 128 outstanding batch bounds.
- All four buffer allocation failures; failures before and after every real recording and binding command; failed fence emission; quarantine with no time-based release; a later same-command-buffer final fence that permits retirement only.
- Disposal before recording, during source validation, during upload, during binding, after sealing, and during fence emission; native disposal failures with retained byte accounting.
- A transient pool fence-read error followed by completion of the same actual fence, repeated query errors, default fences, and loss of fence support. The coordinator cannot be released while it is still needed to recover an unproven texture lease.
- Hostile source collections, non-wrapping material generations, and 100 deterministic randomized call sequences checked against an independent observable lifecycle/byte-accounting oracle.

The caller must execute the single command buffer once, after texture producers, with all consumers preceding `SealAfterConsumers`. `GetResources` only borrows descriptors for RenderGraph dependencies. Recording or sealing does not prove submission, texture readiness or completion. Unknown command results without a valid final-consumer fence remain strongly referenced and budgeted indefinitely. The actual copy shaders and material shaders have separate GPU tests; this harness does not claim to execute them.
