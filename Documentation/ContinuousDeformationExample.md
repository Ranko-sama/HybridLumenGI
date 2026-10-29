# Continuous deformation example

## Current unified sample source

The unified sample uses the same existing door and ordinary interaction controls.
**Space** starts or pauses deformation; **K** switches its source between
**Readable Mesh** and **Skin**. Readable Mesh is the default. Camera navigation,
door movement and the other sample controls remain available. The current packaged
entry is [Release79](<I:/Unity test/Comparison/Builds/LocalRelease79/Start-LocalRelease.cmd>).
The [finite Unity usage and build result](../LocalComparison/Review/skinned-unified-usage-01/result.md)
covers this source integration; the new Player was not separately launched.

Readable Mesh retains the existing owned-mesh deformation path. Skin creates an
owned child with a real `SkinnedMeshRenderer`, a readable clone of the same door
mesh and two private bones. Vertex weights vary linearly along local Y. The upper
bone bends around local Z within **±20°**; a fixed conservative local bound covers
that motion. The child keeps the source layer, materials, renderer property blocks
and rendering policies.

In Skin mode, `HybridLumenGIDeformedMesh` automatically captures the source using
`BakeMesh`; the interaction does not supply an explicit mesh override. Pausing
keeps the visible pose, and automatic capture remains available for the stopped
pose while asynchronous mesh/SDF/chart publication and GI catch up. Existing
capture, worker, upload and residency budgets still apply, so visible animation
can lead the GI snapshot.

Switching withdraws the previous capture/source before activating the replacement.
The interaction owns the original renderer's enable state and Proxy source binding.
The skin helper starts with its renderer disabled and, when disposed, disables it
before retiring only its owned hierarchy and mesh through the existing GPU-safe
retirement mechanism. Authoring meshes, materials and the original door are retained.

This is a bounded door renderer/GI example. It **does not deform the physics
collider**, create a character controller, build an automatic rig or add a general
animation/source-switching framework. Dynamic lighting quality, ghosting and the
delay between visible skinning and GI publication remain subject to their recorded
scope; the presence of a real Skinned source does not establish those results.
See [deformation snapshot contracts](DeformedGeometry.md) and
[current development progress](DevelopmentProgress.md).

## Historical Release69 harness

The following describes the earlier Release69 harness and its fixed run. It is
retained as historical evidence, not the current unified-sample entry or a validation
of the new Skin mode. See the [Release69 result and scope](ReviewBrief-ContinuousDeformationUsage01.md).

That local Release used the Functional scene's red/green patterned
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

The Release69 build and results remain in
`LocalComparison/Review/continuous-deformation-usage-01`. Their source and finite-run
scope are separate from later unified-sample changes; Release67 also retains its
own historical results.
