# Iteration26: one ordinary readable-mesh deformation

Task c2c_a702; baseline e8e81231ea55434f32653e6e861e1eb69aa9aa6d. Package LocalComparison/Review/deformation-snapshot-propagation-01. The original four goals/ten workstreams remain active; darkness/MC and timing work remain canceled. No Runtime product source change or second native attempt was made.

The narrow mode reuses the existing Functional scene, initial dynamic mesh and ordinary RequestCapture API. At160, local vertices with y>0 move x+=0.8, then bounds/normals update and one capture request is made. Actual saved arrays verify unchanged vertex count, indices/submeshes, UV and tangents; the same visible mesh object remains. Material, transforms, camera, door and budgets stay fixed. There is no test-issued MarkDirty, cache/history clear or forced RTAS build.

Three staged managed compiles passed as the observer was completed. Six shader files, including the identity mapper, copy and original-path recorder, are byte-identical to executed25. Astra's implementation review corrected three observer risks before execution: unknown Ng must not be confused with unknown radiance; every detail frame needs complete receipts or explicit unavailable state;159 admission must reject selected nonfinite values. No new mathematical/IO framework or unrelated test matrix was introduced.

The unique Unity6000.0.85f1 build succeeded, with110 product source files,17 staged files and284 outputs verified. Temporary deployment was restored. The unique visible Windows DX12 / RTX2080Ti Player (PID13544) completed256 logical frames,70 hash-verified payloads, four HDR/PNG captures and zero observer errors. Native exit0, no watchdog or relevant native scan error. All final generic/material/arena/deformation accounting is zero. First render waited2.762s; collection timing is not performance evidence.

## Separate clocks and evidence

| Stage | Logical frame / engine frame | Observed state |
| --- | --- | --- |
| Baseline |159 /160| Visible target GeometryGeneration7, MaterialGeneration8, key8; GI snapshot mesh−238 and proxy/surface/backend geometry revision22 |
| Source edit and capture request |160 /161| Same visible mesh edited; registry GeometryGeneration39, material stays8, key39 and reusable0. New worker captures mesh−422. GI snapshot/backend still use old coherent mesh−238/revision22 |
| Actual CPU publication |161 /162| Mesh−422, SDF, capture mesh and charts are linked to the same complete snapshot. Product PublishedFrame=161 is the **capture engine frame**, not publication engine162 |
| New bound GPU geometry |161 /162 onward| Actual instance4 data advances revision22→23 and backend GeometryVersion2→3. Completed readback of all12 bound triangle positions exactly matches the new immutable float32 snapshot |
| Retirement |161 /162 and final close| Old snapshot withdrawal/retirement is followed by one destruction receipt; new snapshot is withdrawn and destroyed at close. Each53760-byte logical reservation returns to zero |

The numerical version domains are separate. Receiver GeometryGeneration39 is not compared numerically with proxy geometry revision23 or backend GeometryVersion3. Actual arrays and source references join these layers. Saved assets include snapshot mesh arrays, original SDF bytes and chart/capture-mesh associations; no SDF was rebaked for the observer.

GPU detail frames are exactly159,160,161,162,163,164,175,191,223,255: the frozen fixed set plus the publication/first-new-dispatch trigger frame and next3 frames, deduplicated.159 uses full-state candidate/object readback and selection/admission; it has no selected trace. From160, two fixed screen lanes use the checked mapper. All declared stages are complete. No extra158 detail, cache lane, camera, pixel or ray was added.

The target selected point remains covered in this run. At160 its previous key8/current key39 and actual object flags0 accompany known raw and history count1. At161 flags return1 but count remains1; at162 count2,175 count15 and255 count32. We do not equate key stability with an unaffected history. Green-wall source identity remains stable. The analyzer separates receiver validity, known radiance and known Ng, preserving the legitimate single-frame result for unknown Ng.

**Actual target ray-hit coverage remains false.** No recorded selected-path hit proves target intersection. This does not say that every original query missed: unrecorded queries, such as receiver-guide queries, are outside this evidence. The completed instance/triangle-buffer readback proves the new data was bound in the observed command stream; it does not independently prove a ray traversed the new RTAS triangles or establish positive lighting consumption from the deformed target. Displaced-triangle hit coverage also remains false. No extra sampling or rerun was performed to fill this gap.

Four original PNGs at159/160/175/255 were visually inspected. They show the expected upper-half shear with fixed scene/camera. They are display previews, not proof of all dynamic lighting or shadow correctness. The inherited generic incomplete-probe/mixed-motion labels remain unchanged; dedicated deformation receipts establish this event's completion, not the original720-frame mixed sequence.

Current derived flags: eventSourceVerified, coherentPublicationVerified, newGeometryBufferCoverage, targetHistoryResponseVerified, snapshotRetirementVerified and nativeExitAccepted=true; actualNewGeometryHitCoverage, actualDisplacedTriangleHitCoverage and fullProductionAccepted=false. No product counterexample was established. Skinned meshes, cancellation, topology changes, streaming, multi-camera, dynamic image quality, Release timing, peak VRAM and long runs remain open.

Astra independently matched the1324-byte edited/captured/published mesh data (12 of24 vertices changed), the12 bound GPU triangles and separate old/new source clocks. It found no results blocker; the complete review is astra-results-review.md. Actual selected Ng is known throughout this run; the unknown-Ng analyzer correction was checked against source but that branch was not exercised here. History is160=1,161=1,162=2,255=32, not uninterrupted growth starting immediately after160. The two destruction/accounting receipts rely on the existing retirement implementation's completion contract; no new per-ticket fence trace or exhaustive last-reader proof is claimed.

Primary evidence: package contract.md, astra-implementation-gate.md, reused-shaders.json, build-analysis.json, instrumentation/manifest.json and restoration.json, native-window/analysis.json, native-window/player.log, and run20261028-122659-067a28c4d8de4e3b85c50b746429aef8 (geometry-lifecycle.jsonl, mesh/snapshot assets, deformation-frames.jsonl and original GPU payloads).

Review request: verify these finite source/publication/buffer/history conclusions and explicitly retain absent ray-hit coverage. Decide the smallest substantive next development step under the original plan. Do not enlarge this successful source/history event into another geometry-ray matrix, or reopen darkness/MC/timing. No Runtime correction is presumed.
