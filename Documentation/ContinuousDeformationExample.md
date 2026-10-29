# Continuous deformation example

The ordinary local Release uses the existing Functional scene's red/green patterned
`Audit deforming occluder`. Space starts or pauses its deformation. It starts paused;
pausing preserves the visible shape while the GI snapshot catches up. WASD/QE and
arrow-key camera navigation remain available; R resets only the camera and Esc exits.

`LocalComparison/Harness/ContinuousDeformationExample.cs` owns one readable clone
of the existing cube mesh. It computes a local shear from the original streams:
`x' = x + k*y`, `k = 0.4*sin(2*pi*t/4)`. Normals use the inverse transpose and
tangents use the linear transform, followed by normalization. UVs, submeshes,
indices and object transform remain unchanged. This is a renderer/GI example;
it does not deform the scene's physics collider.

Each completed main-thread update calls `RequestCoalescedCapture`. The source is
borrowed until the actual capture copies its arrays, so the clone stays alive while
paused. The existing 12-frame capture interval, SDF resolution16, worker and memory
budgets remain in force. Visible animation can therefore precede GI snapshots.

Closing the example withdraws its deformation component, restores the original
MeshFilter source, then retires only the owned clone through the existing GPU
retirement mechanism. Private published Mesh/SDF/charts remain system-owned. Closing
does not restart capture; removing this demo also disables its deformation producer.

The explicit `-localContinuousDeformation256` mode uses the same start/stop and
advance methods. It holds for32 target-camera frames, advances128 frames using a
fixed1/60 second step, then holds96 frames. Logical159 and255 are the same visible
pose at motion-ending and settled states. Existing HDR/PNG capture is reused.
This finite mode does not revalidate OS keyboard delivery or prove target-ray GPU
consumption, radiometric correctness, ghosting quality, performance or production
support. Source consistency and the image assessment are reported separately.

The local build and results belong in
`LocalComparison/Review/continuous-deformation-usage-01`; Release67 remains separate.
