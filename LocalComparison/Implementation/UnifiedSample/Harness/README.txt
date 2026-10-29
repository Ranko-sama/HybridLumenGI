UnifiedSampleHost: bounded same-scene native exercise (draft; no Unity execution by this package)

Editor setup:
  Add UnifiedSampleHost to the saved UnifiedSample variant and call
  Configure(camera, controller, feature, streamer, ownedBindings, outputDirectory).
  ownedBindings is exactly one aggregate/root plus its three authored detail bindings;
  the order is not significant. Configure disables automatic rendering of this camera.
  The ordinary controller/streamer remain active. Root owns generation, deployment,
  source freezing, managed compilation, execution and restoration.

Before any rendering the Host requires empty sample bindings and an unloaded page
driver. SupportsRenderRequest may initialize the pipeline, but no render is submitted
until the exact current pipeline has persisted across two complete Update intervals.
Ordinary asynchronous page IO may start during those intervals; there is no GI warmup.
After admission, a pipeline replacement is an explicit failure.

One StandardRequest is submitted per engine LateUpdate, after the ordinary sample's
LateUpdate complete-detail admission gate. The Host owns a 640x360 linear RGBA16F RT,
MSAA=1. It validates one begin/end context and camera receipt per request. Phase decisions
run only after SubmitRenderRequest returns, not inside endCamera.

Fixed stages:
  00 cold-near-details                  Software; complete three-detail group.
  01 far-aggregate-software             Aggregate published; details detached.
  02 far-aggregate-dxr-reported         Prefer DXR; actual CPU diagnostic hardware=true.
  03 far-aggregate-software-return      Request software; diagnostic hardware=false.
  04 controller-disabled-release       Same in-domain camera; disable only controller.
  05 reenabled-near-details             Re-enable controller; complete detail group again.
  06 leave-release                     Ordinary Leave button path; all owned pages released.

Every stage requires three consecutive complete requests satisfying its condition.
At each draw, the renderer's actual enabled/active/forceRenderingOff states are recorded.
At all times a visible sample set may only be empty, exactly the aggregate, or all three
details. Rendered stages additionally require the expected set BOTH before the draw and
after the endCamera publication switch, complete current HLOD published/target sets,
and the following complete GI recording counter. Thus the first accepted condition is
followed by at least two further matching renders before its image is sampled. Initial
backend/configuration counter resets can warm normally and cannot qualify that frame.

Release stages require every owned binding detached (mesh/material/SDF/charts empty),
no visible sample renderer, all driver's pages Unloaded/unwanted/refcount=0, and zero
bundle/resident/IO bytes, active operations and retiring page leases. The existing real
retirement fence is the sole completion source. The Host does not supply an unload
ticket or require unrelated global GI caches to reach zero.

The entire exercise is limited to 1200 camera requests and 1800 seconds including
startup and readbacks. Unsupported hardware, renderer errors, partial groups, resource
failure or an unmet bound is retained as failed/uncovered; no extension or backend
fallback is silently substituted. Concurrent user gaming/GPU load is recorded, and
elapsed time is not a performance verdict.

Each stage pauses further requests while its own AsyncGPUReadback completes, checks
all 640x360x4 floats finite, and writes rgba32f + EXR + diagnostic tone-mapped PNG and
SHA-256 links. No RGB similarity/integral or per-ray hardware claim is made. Raw memory
row order is deliberately not promoted to an orientation-normalized reference signal.
The images are the final StandardRequest target with the variant's ordinary pipeline
configuration, not the validation v2 pre/post-HLGI physical-reference signals.

Files:
  events.jsonl                  Cold/pipeline/stage entries and every complete request.
  stage-NN-<fixed-stage>.json    Selected frame, full ledger/bindings/publication, hashes.
  stage-NN-<fixed-stage>.rgba32f/.exr/.png
  host-result.json               status=collected|failed, error, renderedFrames,
                                readbacksDrained, completedStages, outputDirectory.
Success means finite integration/readback completion only, never physical-quality PASS.

Normal Finish is deferred to a subsequent Update so URP has restored its target.
The owned target is detached from new readers, then retained by existing resource
retirement and an own-readback prerequisite if needed. No WaitAllRequests or elapsed
time is used as GPU completion proof. Root's Editor finally restores source/assets.
