# Astra result review — asset-page-inflight-withdrawal-01

Decision: **no blocking finding; ready for the actual Pro review as bounded evidence**. The observed pending asset request survived demand withdrawal, its late result was received and explicitly released, and its logical reservations were returned after successful release completion. There is no demonstrated product counterexample and no reason to extend this package or rerun it.

This review read the saved raw events/result, native log, final executed hook sources, build/restoration records and existing analysis. It did not run Unity, a compiler, a test, or the full analyzer. Only this review document was written.

## Source and execution identity

- Baseline `4a04e646e2a2fb6bc7e4fae718a3c830ced3e9e6`; no repository Runtime diff.
- The seven prepared inputs match their manifest hashes and the recorded actual build inputs. The manifest hash is unchanged from the pre-build Astra gate. The build reports 110 product sources, 285 output files and success; restoration records all seven temporary inputs restored and the product source restored.
- The existing six-page input and four direct group IDs were reused. The build CRC receipt verifies the frozen bundle CRCs. Input closure is distinct from the set of pages that actually loaded.
- Single recorded Player: PID 7584, Unity 6000.0.85f1, Direct3D12, native exit 0, no watchdog termination. Run: `20261028-125539-a2af94495903480aaf31e0293474f7fd`.
- The result records one request and one withdrawal, 12 actual pump ticks, and eight final zero ticks. These are pump observations, not a rendering or performance sample count.

## Raw ownership chain

All event references below are `native-window/run/20261028-125539-a2af94495903480aaf31e0293474f7fd/events.jsonl` sequence numbers. The file contains 188 sequential records.

| Tick | Raw evidence | Interpretation |
| --- | --- | --- |
| 0 | seq 1 initialized; seq 2 request accepted | Initial zero ownership and the sole group request precede normal pumping. |
| 1 | seq 16 bundle operation 1 / native 2; seq 17 | The geometry leaf reserves 4,190 bundle/IO bytes. Other pages remain unloaded at generation zero. |
| 2 | seq 21 bundle result 3; seq 33 asset operation 4 / native 5 | Bundle IO completes; 4,304 resident bytes are reserved for the actual asset load. |
| 2 | seq 35 native check: `done=false`, generation 1; seq 36 withdrawal | The final executed hook reads the identified native request once and immediately invokes the original RemoveRequests before writing these receipts. Operation 4 and both reservations are retained. |
| 3 | seq 37–40 | The next Drive propagates requested=false. Original Poll completes the same operation 4 and returns asset identity 6, with the same page generation. |
| 3 | seq 41 Ready; seq 52 release operation 7; seq 53 | The late result enters release without acquiring a consumer lease. Bundle 4,190 and resident 4,304 remain reserved. |
| 4 | seq 56 unload operation 8; seq 57 `done=false`; seq 70 | The original release getter starts `UnloadAsync(false)` and retains the page while native unload is incomplete. |
| 5 | seq 73 `done=true`; seq 74/75 explicit asset unload before/returned; seq 77 successful release result | The same asset 6 is passed to `Resources.UnloadAsset` exactly once and its call returns before the successful original release Poll. |
| 5 | seq 78 Unloaded; seq 89 | Reservations are cleared only after that release completion. |
| 5–12 | step-after seq 89, 103, 117, 131, 145, 159, 173, 187; closing seq 188 | Eight consecutive observations show all six pages Unloaded, no operations, leases or pins, and zero IO/bundle/resident reservations. |

The recorded intermediate Wanted values are correct ownership behavior, not a contradiction: immediately after RemoveRequests, the page's cached requested/Wanted fields still reflect the preceding Drive (seq 36); requested becomes false in the next Drive (seq 37). At tick 4, Wanted becomes true again because the pending release operation pins its owner. It clears after release completion. The observation and analyzer correctly avoid treating either interval as a leak.

## Native exit and limits

`player.log:255` reports the existing generic shutdown drain complete with owned/pending/unknown/failed/failedWithdrawals, material/arena/deformation bytes and deformation jobs all zero. The reviewed log contains no attributable native allocation leak, retained unresolved owner, GC buffer disposal, unreleased D3D buffer or scratch warning. The generic UTP `MemoryLeaks` aggregate with allocatedMemory 100552 remains raw diagnostic output; it is not promoted to a resource leak finding or a whole-process no-leak proof.

Only `geometry-74ab8faeaec044bb9ea93b4b59255665` actually loaded. It has no dependencies, and no reserved parent/dependency release edge occurred. Therefore `dependencyReleaseOrdered=false`, `observedDependencyEdges=[]` and the explicit coverage gap are necessary. The successful leaf path must not be described as validation of dependency-release ordering across the full closure.

This package proves the observed unbound native asset-load withdrawal/late-completion path and its logical accounting. It does not establish GPU consumer retirement, HLOD publication, normal streaming quality, all page kinds, release-failure behavior, physical memory bounds, long-duration behavior, or full production acceptance. The loaded asset's explicit unload call and successful return are observed; precise physical reclamation timing is not measured.

Submit this result with those limits. No new test, asset substitution, later trigger, or second native run is warranted to manufacture the missing dependency edge.

## Reviewed evidence hashes

| Artifact | SHA-256 |
| --- | --- |
| `events.jsonl` for the run above | `a9af5a1677fa96ec529299091da237de9d50b292a8a4800cf812e97ba711ddec` |
| `native-window/analysis.json` | `382a73b418810eaf65bac3c1aec8c28aedbca1a6c1ab0428a29638064a5652fa` |
| `native-window/player.log` | `dd97e0323893ece019374bd817a04dca1a90e4212262f9efae17c1349ffd8337` |
| `build-products.json` | `1145c3107444a9b25d210fcc7c76b79a9c48fa6d0f5519e3407c7962563cd080` |
| Unchanged analyzer | `a7db402c56e51fed0f0643f78d4311cdadbf8ec5b0e02a92845bc038b9be77f1` |

