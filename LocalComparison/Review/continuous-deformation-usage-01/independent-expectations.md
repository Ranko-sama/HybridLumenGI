# Independent expectations before implementation

temporal_lane read actual public APIs. HasSnapshot checks the CPU Published map;
GetSourceMesh alone is insufficient because absent publication falls back to the
renderer mesh. PublishedFrame is job.capture frame, not publication wall time.

At useful observation points, record observation engine frame and captured frame.
Require HasSnapshot plus one identical source reference across GetSourceMesh,
Proxy.SourceMesh, Proxy.MeshSdf.SourceMesh and Proxy.SurfaceCharts.SourceMesh, with
valid SDF/charts. This is atomic CPU-source consistency, not GPU consumption.

During the fixed motion window, observe at least two distinct captured frames from
inside that window whose immutable vertices match the predeclared producer pose
and differ from each other. New instance IDs or pending jobs alone are insufficient.
During a finite settled tail, require the same complete source tuple to match the
final producer geometry. Its captured frame must be no earlier than the frame that
actually first applied that final pose. Identical-content reuse may preserve an old
PublishedFrame; do not require continuing growth after convergence.

Use the existing target camera callback and public feature diagnostics for actual
same-scene rendering association. Do not inspect private GPU buffers or restore26's
tap. Two fixed same-configuration images (a motion pose and a distinct settled pose)
can establish interpretability. They do not quantify ghosting/radiometry or prove
target-ray GPU use. Capture times must not be selected after observing publication.
