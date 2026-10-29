# Camera motion with actual URP TAA

The prospective scope and exit conditions are in `contract.txt`. This package
observes actual full Feature execution with static source geometry, a moving
camera and URP camera TAA. It does not compute a radiometric reference. The
motion-UV history branch is the only correspondence branch accepted for coverage.

New harness files are `LocalComparison/Harness/CameraMotionTaaEditor.cs`,
`CameraMotionTaaScene.cs`, `CameraMotionTaaTap.cs`, and `CameraMotionTaaCopy.hlsl`.
The temporary project root is exactly `Assets/CameraMotionTaa01`. The Editor
entry is `CameraMotionTaaEditor.Run`, with required new absolute output argument
`-cameraMotionTaaOutput`. The host reuses the finite-scene disabled-camera
`RenderPipeline.StandardRequest` structure and requires 48 consecutive renders.

The preparation tool reads the current deployed product source hashes. Its sole
Feature edit is one observer call immediately after the real temporal dispatch;
each of the three compute assets gains one identity-enabled copy entry. There
is no transport/temporal arithmetic replacement or replay. Twelve GPU control
vectors include actual thresholds and URP non-jittered motion matrices. Each
of 264 source-selected rows contains 45 vectors, including the actual identity
object row and five prior pixel inputs. Compact binary total is 9,133,056 bytes
for all48 frames. Final frames31/39/47 have preview artifacts only for context.

Root owns execution. After all sources and analysis are frozen, the commands are:

```powershell
& 'C:/Users/Administrator/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' -Xutf8 -B LocalComparison/Review/camera-motion-taa-response-01/prepare.py prepare
& 'C:/Users/Administrator/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' -Xutf8 -B LocalComparison/Review/camera-motion-taa-response-01/prepare.py preflight
& 'C:/Users/Administrator/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' -Xutf8 -B LocalComparison/Review/camera-motion-taa-response-01/compile_observer.py
& LocalComparison/Review/camera-motion-taa-response-01/run.ps1
```

`run.ps1` refuses an existing attempt and restores the exact owned project files
in `finally`. Original product/quality/graphics/Functional scene hashes are
recorded and checked. The Editor separately restores the original scene and
pipeline, including a clean empty batch-start scene. First native and analysis
outputs must be preserved. Lack of qualifying first-exposure or continued-history
samples is uncovered coverage; do not extend the path, frame budget or selection.

After restoration, run `verify_execution.py`, then `analyze.py` with this package
directory and `--output` pointing to a new `analysis-first.json`. The independent
analysis finalizes cohorts from input-only data before reading current raw or
history outputs. CPU negative controls are in `test_model.py`.

The already reviewed `StartupStageProbe.cs` and pure patch helper add first-render
CPU timing observations to the staged Feature/host only. They live under the
same owned temporary root. This adds no GPU timing, rendering, frames, or inputs.
