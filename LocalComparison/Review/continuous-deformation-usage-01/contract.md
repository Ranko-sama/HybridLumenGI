# Continuous deformation: frozen finite contract

This is the independent reference for Pro69. It supersedes the earlier preparation
note's suggestion of two different visible poses: logical 159 and 255 have the same
visible final geometry, observed at motion-ending and settled times respectively.
The images are for interpretability, not radiometric truth or dynamic-quality approval.

The existing `Audit deforming occluder` retains its object transform and scene setup.
Its readable original mesh is frozen before motion. The existing SDF resolution 16,
capture interval 12, shared budgets, material, lights, camera, Final/Additive settings
and static Release67 Cube are retained. The checker owns no Unity mesh or binding.

## Fixed commands and independent geometry

At target-camera end callbacks, observe logical frames 0 through 255 once each and
record the corresponding engine frame and commanded time. Frames 0–31 are paused.
Before rendering each frame 32–159, the same ordinary example receives one
`Advance(1f/60f)` while running. At 160 it receives `SetRunning(false)`; no further
producer writes occur. Time is double accumulation of the float step, so the final
independent time is `128 * (double)(1f/60f)`, not an assumed exact rational 128/60.

Starting from each original local position `(x,y,z)`, compute in the reference:

- `k(t) = 0.4 sin(2 pi t / 4)`; position `(x + k*y, y, z)`.
- Normal: normalize `(nx, ny - k*nx, nz)` (inverse transpose).
- Tangent xyz: normalize `(tx + k*ty, ty, tz)`; retain tangent w.
- Retain all UVs, submesh count/topology and logical `GetIndices(submesh, true)`.

The reference uses its own scalar double arithmetic, then float output; it does not
read the example's coefficient or transformed arrays as an oracle. Compare every
float component with absolute tolerance 2e-6, rejecting nonfinite values. Compare
array lengths, topology and indices exactly. Ignore the raw UInt16/UInt32 index
storage format. At t=0 the unchanged original arrays are the reference. Full original,
final producer, final published and final expected arrays are retained as JSON.

## Publication and stopping criteria

`PublishedFrame` is the capture engine frame, not the observation/publication frame.
For each new published source identity or captured frame, look up that engine frame's
recorded command and compare all logical streams with its independently reconstructed
pose. The constructor records its initial paused engine/time as well, covering a
capture before the first camera callback. No unrecorded frame/time is inferred.

Every observed publication must have `HasSnapshot(renderer)`, and one identical
source object across `GetSourceMesh(renderer)`, `Proxy.SourceMesh`,
`Proxy.MeshSdf.SourceMesh` and `Proxy.SurfaceCharts.SourceMesh`. SDF and charts must
be valid. The visible MeshFilter must continue to reference the producer clone.
Before the first publication, absence is allowed; disappearance after publication is
a failure. Only changes produce snapshot rows, with observation/capture identities,
command time, reference error and complete position arrays.

During logical 32–159, observe at least two distinct published capture frames also
inside 32–159, with vertex contents differing by more than 2e-6 in at least one scalar.
Requests, PendingFrame, identity changes alone or publications first seen in the
stopped tail do not establish this motion-window progress.

At logical 255, require the latest tuple to agree with both the complete
final producer and independent final reference. Its capture frame must be no earlier
than the engine frame that applied the final pose (logical 159). Do not require a new
PublishedFrame throughout the paused tail or a capture at logical 255. Finish
aggregates the persisted result without repeating the final mesh comparison.

Only at logical 159 and 255, query the existing public camera diagnostics: require an
active Feature, positive GI frame/published-instance/ready-card counts, active hardware
backend with hardware meshes, and zero hardware material unknown records. The second
GI frame must advance. These receipts and the CPU tuple do not prove target-ray GPU
consumption, GPU completion, lighting convergence or per-frame snapshot freshness.

## Finite execution and failure

The root owns one managed preflight, one Release/None build, one DX12 Player and the
two existing HDR/PNG captures. The checker is a disposable non-Mono class using public
APIs only. Its first failure writes `check-result.json` with the reason and throws;
there is no retry, extended frame window, budget increase or new observer framework.
`Dispose` only closes its writer. `Finish` decides the finite CPU checks and closes
the writer. The root separately verifies images, normal exit, source identity and
temporary project restoration before adoption.
