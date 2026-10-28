# Local light scheduling priority — finite source result

Task c2c_a702 iteration48, base f4c06fa. Original goals2/3, workstreams5/8. Astra independently identified that local light events lose their spatial advantage at the CPU update selector; actualPro47 agreed, while retaining conservative global dirtiness. This is not a global cache-clearing bug and has not been linked to a measured visual delay.

## Product change

Only `HybridLumenGIRendererFeature.cs` and `HybridLumenGICacheScheduler.cs`,23 additions/5 removals. Each camera reuses a List<Bounds>(64), cleared by UpdateLights. The existing max32-light snapshot emits at most64 old/new records. AddLightChange constructs its original local bounds once, makes the unchanged GPU Add call with the original trace influence, then expands a copy for scheduling. Directional events still call MarkGlobalLightingChange and create no local range. Old-position records, including disabled lights, follow the same path.

Scheduler.Prepare accepts an optional IReadOnlyList<Bounds>. Its existing per-owner dirty priority is raised with max to the existing1000 level on intersection. It uses the same world owner bounds already used by geometry priorities. Existing750 global lighting dirtiness, candidate eligibility, content priority and one-quarter oldest-service quota remain. Pending priority lasts until actual service; duplicates cannot add scores. Omitting local ranges preserves the existing behavior. No GPU ABI, history, epoch, radiance, multibounce, readiness or resource ownership change. The expanded AABB is a conservative ranking hint, not a transport cutoff.

## Actual execution and decision

One frozen baseline batch ran before the product edits, then one same-input candidate batch. Both first executions exit0. No failures/retries, Unity/Player/GPU runs or deployment.

Baseline first compiles the complete unchanged production Lights/LightRelevance with the existing explicit Unity light adapters. It actually generates initialX100, movement oldX100/newX300, disabled oldX300 and directional records; candidate reuses exactly this saved input. SHA256 `5af2e6fcb0162c64945f3ccce9a8b3fa26f973cb20cb5a84d2187275a2fe3743`.

Both stages then execute the actual Scene, BVH, HlodReadiness and Scheduler with the existing Unity/proxy/surface adapters. The exact AddLightChange body is extracted into a minimal camera/settings context; its original GPU Add/MarkGlobal receivers record calls. No duplicate test implementation constructs scheduling ranges. With range1/traceDistance2, original GPU bounds size2/influence2 remain exact, while candidate scheduling bounds size6 retain old/new/off centers. Directional remains global only.

Four ready one-patch owners atX0/100/200/300 begin at equal service age after full warmup and consumed scene dirty regions. Budget2, disabled light's oldX300 event:

| Concrete decision | Baseline | Candidate |
| --- | --- | --- |
| Actual selected patches | [0,1] | [0,3] |
| Oldest-service count | 1 | 1 |
| Duplicate event, budget0 pending priorities | [750,750,750,750] | [750,750,750,1000] |
| Following frame, event list cleared | [0,1] | [0,3] |
| Missing target page restored after clearing event list | [0,1] | [0,3] |
| Directional / no-local control | [0,1] | [0,1] |

Four repeated-event candidate frames select[0,3],[1,3],[2,3],[0,3], with budget2/fairness1 throughout and every patch served. This is a bounded no-starvation control, not a general convergence rate. Exact old/new/off bounds, duplicate max, zero budget and list-cleared persistence distinguish the concrete failure modes in the frozen contract. The runner and fixture programs remain byte-identical between stages.

## Sources and limitations

`LocalComparison/Review/local-light-scheduling-priority-01/{baseline,candidate}/` retains full raw product sources, exact compiled C# sources/adapters, actual event JSON, frozen runner/programs/contract, command logs, source manifests and first result/analysis. `source-verification.json` records frozen sources and the two product differences. Only the complete collector is run once; candidate scheduler consumes identical saved records, not regenerated “equivalent” events.

The Feature AddLightChange body executes, but the full Feature/RenderGraph/UpdateLights call path does not run in this fixture. The production diff shows list reuse/clear and the named scheduler argument; this source result does not become native integration evidence. GPU change-domain calls are recorded, not executed. Existing Release44/deployment remains5120a8c. No GPU milliseconds, image quality, production budget or full G0–G5 acceptance.

Review this source closure/local commit or identify a concrete blocker. Following two product nodes (47 fog,48 scheduling), Astra independently reassesses the full original plan and cumulative investment before any new Pro/main plan. Do not add more scheduling cases just to increase coverage counts; choose one next capability, evidenced defect or decision-changing integration gap.
