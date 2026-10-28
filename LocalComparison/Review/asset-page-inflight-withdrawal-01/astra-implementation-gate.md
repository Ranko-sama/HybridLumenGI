# Astra implementation gate — asset-page-inflight-withdrawal-01

Decision: **no remaining static blocker to the one authorized build and visible Player run**. This is an actual pre-build review. On 2026-10-28, before writing this record, both `build-attempt.json` and `native-window/attempt.json` were absent. No Unity, compiler, test, analyzer execution, or product edit was performed by this reviewer. The parent owns execution and the existing one-attempt limits.

Reviewed baseline: `4a04e64`. Repository Runtime has no diff. Review covered the final prepared Streamer/Streaming/Tap/Mode/entry/build sources, the installer and input contract, and the current offline analyzer. The existing `preflight-command-3.log` reports `COMPILER_EXIT=0`; its warnings are preserved. This does not substitute for the real build or native evidence.

## Resolved blocking findings

1. The native pending check now constructs its numeric receipt first, then reads the current `AssetBundleRequest.isDone` once as its final operation. Mode immediately calls the original `RemoveRequests` before any receipt serialization or disk write. The record means a false value observed immediately before withdrawal, not an atomic lock over asynchronous native completion.
2. `Finish` has nested `finally` blocks that attempt camera closure and always call `Application.Quit`, with a failure exit code if saving or closure throws. A write exception can no longer leave `closing=true` and suppress every later quit attempt.
3. Mode is disabled immediately after creation and enabled only after `inputCheck` succeeds. A preparation failure cannot subsequently issue its request through `Start` while Unity processes a delayed quit.
4. The analyzer now requires the unique initialized/request-accepted/closing receipts, paired before/after step tick and engine identities, and agreement between the final step, closing receipt, and result tick. It also links each non-null released asset to its actual load result and the unique explicit `Resources.UnloadAsset` before/returned receipts preceding the successful original release poll.

## Scope and semantics retained

- The controller runs in ordinary `Update` at execution order 30000, after the original default-order page pump. It never drives an additional Step/Pump, acquires a lease, binds a renderer, forces an unload, or injects completion.
- Original Poll still reads `IsDone`, then only on completion reads `Error` and `Result`; the short-circuit and getter counts are retained. Release's side-effecting getter is observed at its original evaluation site. The only extra completion read is the identified native asset-load request used for withdrawal.
- The temporary identity table uses weak keys. Recorded identities do not retain loaded assets, request wrappers, or native operations as test-owned lifetime insurance.
- One SetRequests is issued before the first observed pump; one RemoveRequests either follows a real pending check or occurs at the 64-tick cutoff as explicitly uncovered cleanup. Existing operations and reservations remain under the original scheduler.
- The analyzer follows the same page/operation/generation through withdrawal, late completion, release, and reservation return. Requested/Wanted and dependency reservations are allowed to remain pinned while ownership requires them.
- The frozen six-page closure is admitted with concurrency/start limits of one. The first observable asset can be a dependency-free geometry leaf. No executed parent/dependency edge means `dependencyReleaseOrdered=false` and an explicit coverage gap; it is neither a product failure nor demonstrated parent-release coverage.
- Existing bounds remain: search at most 64 actual pump ticks, drain at most 128 after withdrawal, then eight consecutive zero observations, with a global cap of 256. A missed window, real failure, or unsupported claim does not authorize another run or different assets.
- Native exit is checked separately from logical reservation return. No GPU reader retirement, HLOD, full-process memory, performance, or full-production acceptance follows from this package.

No current static counterexample requires a Runtime fix before this experiment. The native result must still establish coverage and the ownership chain; a managed compile is not that result.

## Reviewed artifact hashes

| Artifact | SHA-256 |
| --- | --- |
| `instrumentation/manifest.json` | `76d68ade711195e04392ca6a06d550c6ee8579edc93488381d4d070ae5fefa95` |
| `input.json` | `cc51185bdc3feb4d44c9773c12e89c0c846c8dc23f647fe5c628870563ffa228` |
| `preflight-command-3.log` | `38f09aebfa02cbb862956ee680b70e58eb0840a3bd7ba10f693e2536fe3044f3` |
| `LocalComparison/Harness/analyze-page-withdrawal.py` | `a7db402c56e51fed0f0643f78d4311cdadbf8ec5b0e02a92845bc038b9be77f1` |

