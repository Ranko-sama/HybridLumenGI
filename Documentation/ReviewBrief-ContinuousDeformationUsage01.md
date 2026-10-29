# Continuous deformation: usable local example

The ordinary Release69 now offers Space start/pause on the existing Functional
red/green patterned occluder. Pausing keeps its shape while the existing coalesced
capture path catches up. Camera navigation remains. The finite run invokes the same
SetRunning/Advance methods; OS keyboard input was not repeated in this round.
See [usage and ownership](ContinuousDeformationExample.md).

Product source is50b63c33683ba533f01c7119f6320ad80b4f2ec6 (112 files). Deployment
changed only HybridLumenGIScene.cs from Release67's2fefc09, bringing accepted68 into
the current build. The new example/check/bootstrap sources are separately frozen
in the staged build manifest. No new Runtime algorithm or resource manager change.
Release67 remains intact. Astra and actual GPT-6 Pro accepted the finite result,
viewed both original PNGs, approved local commit and closed this item without more
runs. The full original plan remains open; no new package was justified by this run.

## Actual execution and preserved first failure

Package: `LocalComparison/Review/continuous-deformation-usage-01`.

- One managed Runtime+Editor preflight passed. The first Unity invocation exited1
  at the reused Cube collision guard, before Cube creation and BuildPipeline.
  There was no build report, executable or Player run from that attempt.
- Pro approved one same-function correction. Only the collision GUID query changed
  to OnlyExistingAssets; file/meta/directory/loaded-object protections remain. The
  precise first triggering disjunct was not recorded, so it is not retroactively
  proven. First attempt sources/logs/manifests remain intact.
- `build-correction/` freshly verified restored project inputs, retained all runtime
  and independent-check bytes, and ran one corrected Unity Release/None build.
  Build succeeded with0 errors/23 warnings;112 product files,8 staged files and189
  output products matched. The same67 static RGBAFloat Cube definition and actual
  Renderer dependency qualified. Temporary wiring/assets/includes restored.
- One visible DX12/RTX2080Ti Player completed256 target-camera frames, two original
  HDR/EXR/PNG captures, native exit0, no watchdog termination, no classified native
  error and observed normal quit. The example withdrew its source and restored the
  original MeshFilter before retiring its own clone.

These are one functional effort: one initial preflight, one failed Unity preparation,
one approved correction build and one first native run. They are not extra features
or evidence of overall percentage progress.

## What the real run establishes

Logical0–31 paused,32–159 advanced the same producer using1/60f per frame,160–255
paused. Original scene SDF16, interval12 and all shared budgets stayed unchanged.

The run observed13 snapshot changes, including11 captures published during motion
with different contents. Each changed snapshot matched its independently calculated
captured pose, and the actual published Mesh/SDF/charts source references agreed.
The final snapshot was captured at engine165 and first observed at engine167
(logical166). The final visible pose was first applied at engine160; these are
distinct capture/observation clocks, not a universal latency measurement.

At255 the complete published positions, normals, tangents, UV and logical indices
matched the producer exactly; maximum scalar difference from the independent
double reference was5.960464477539063e-8 against the predeclared2e-6 tolerance.
Original mesh content remained unchanged. Public Feature receipts progressed
GI160→256 with hardware tracing active,22 published instances/meshes,132→136 ready
cards and0 material unknown records. This proves public CPU-source consistency in
the running scene, not target-ray GPU consumption or light-transport convergence.

Root viewed both original PNGs. The patterned thin object, colored walls, front
pillar and background geometry remain readable; no apparent shape explosion or
broken texture mapping in these two views. Logical159 and255 deliberately retain
the same final visible pose. Grain/stepped edges and dark rear objects remain; two
stills do not qualify motion stability or classify darkness as a defect.

- [Motion-ending image](../LocalComparison/Review/continuous-deformation-usage-01/build-correction/native-window/run/frame-0159.png)
- [Settled image](../LocalComparison/Review/continuous-deformation-usage-01/build-correction/native-window/run/frame-0255.png)
- [Qualified native result](../LocalComparison/Review/continuous-deformation-usage-01/build-correction/analysis69-run.json)
- [Frozen contract](../LocalComparison/Review/continuous-deformation-usage-01/contract.md)

This run recorded2.9383 seconds to the first camera callback. Release67's101.249
seconds remains historical evidence; different runs/cache conditions are not a
controlled startup-speed comparison. No timing investigation or optimization claim.

The full four goals/ten workflows, color-bounce truth, dynamic image quality,
software/DXR parity, target scale, GPU/VRAM budgets and production gates remain open.
