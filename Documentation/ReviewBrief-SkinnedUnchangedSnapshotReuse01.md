# Iteration45 — unchanged automatic Skinned captures reuse successful Published

Base2007409; current deployed/Release44 product5120a8c remains unchanged. Original goals2/3, workstreams4/5/8. Plan-aware Astra selected this direction independently; actualPro44 agreed. Cumulative deformation work includes earlier source propagation, explicit coalesced demand43 and this automatic same-content reuse, not a reset of investment by package name.

The baseline confirms a concrete redundancy, not a measured native bottleneck: one actual Skinned component captures identical contents twice, starts two real Task.Run jobs and publishes/marks dirty twice. The two independent captured meshes have identical results from the actual full production fingerprint. Existing temporary and retired ownership is preserved. First baseline command exit0.

Only product change is HybridLumenGIDeformedMesh.cs,36 added lines/2 removed. Snapshot carries capture-time fingerprint, effective SDF size and frozen chart settings. True BakeMesh captures compute the existing SurfaceCharts.ComputeContentFingerprint; only automatic capture with no explicit demand can compare against current same-owner Published. Comparison covers the full fingerprint and all five raw frozen chart fields plus effective size. In-flight metadata cannot authorize reuse because lookup uses Published only. The production baker does not mutate the supplied settings object.

Matching keeps the exact Published object, PublishedFrame and dirty/version state; it destroys only the new private unsubmitted capture. Original capture interval, vertex/worker/memory/upload gates are still applied before capture. No extra snapshot queue, pool, scheduler, Runtime state outside this component or caller migration. No claim that BakeMesh or fingerprinting is free, or that CPU/GPU milliseconds improved.

If private destruction fails, the branch stores the same snapshot/reservation in the existing cleanupFailed Job mechanism with a completed null-result Task and original cancellable CTS, then continues without reaching the outer destroy catch. It is failed retained ownership, not an active worker; its entry still occupies existing Jobs capacity. No repeated destroy, premature refund or hidden failure reset. Original strong/coalesced explicit requests, invalidation, upload, atomic publication and retirement are unchanged.

## Actual execution and boundaries

One candidate invocation exit0, no failure/retry, no Unity/Player/GPU. Seven exact compiled inputs are frozen for baseline/candidate; only DeformedMesh differs. Actual full fingerprint method, fingerprint version and three Write helpers are extracted unchanged from the full frozen SurfaceCharts source and compiled with the actual component/retirement/pump. The SHA256/content comparison is executed, not an adapter returning an equality boolean. Source-verification.json confirms extraction, all current compiled inputs, scripts and original fingerprint source match.

MeshData/raw byte APIs and BakeMesh remain explicit adapters: one represented vertex stream contains actual positions/normals/tangents/UV0 bytes, plus index bytes, submesh descriptors and bounds; bone/blend-shape channels are empty in these inputs. Mesh attribute get/set adapters now copy arrays like the existing positions adapter, so editing producer UV does not silently mutate captured content. Numeric SDF/chart outputs and fences remain prior stubs; this does not execute Unity native skinning, native raw layouts or numerical bake correctness.

First candidate checks the decisions relevant to this branch:

- Identical automatic capture executes BakeMesh but starts no second worker, retains exact Published/PublishedFrame/dirty count, destroys temporary mesh and refunds its reservation. Vertex quota and capture interval still gate it.
- Same vertex/index counts and bounds with only UV bytes changed produces a different actual fingerprint and enters real component rebuild. An injected publication failure rolls back to old successful Published; the same new contents are then rebuilt again, proving a failed candidate did not seed reuse.
- Resolution16→17 rebuilds. Chart padding .125 captured before a live edit to .25 causes the later automatic request to rebuild again, proving captured parameter identity is frozen.
- Same-content strong and coalesced explicit requests still rebuild/publish. Final automatic unchanged capture skips; mesh/SDF/charts identities stay unified. Success-path retired snapshots return their reservations only through recorded completion.
- At the end, with existing intentional failure/unknown-retirement cases still retained, injected private-capture destruction failure is counted once, retains its added reservation/current Published, has completed placeholder work, starts no bake and survives disable/new session without a second destroy. This is not a global end-of-process zero-resource claim.
- Original component cancellation, upload, rollback, failed capture, shutdown and retirement guards pass in the same command. No unrelated native matrix is repeated.

Raw baseline/candidate stdout, source manifests, exact sources, scripts and pre-execution contract are under `LocalComparison/Review/skinned-unchanged-snapshot-reuse-01/`. Source-only consumer-routing contracts remain labeled source-only. Existing deployed bytes/Release44 do not include this candidate.

Request independent finite closure/local-commit decision, then one next valuable direction from the complete original plan. Astra is independently reviewing raw45 before a new Pro/main proposal. Do not extend this into animation/performance tests or reopen closed checks; production budgets remain unanswered and all unclosed original goals retained.
