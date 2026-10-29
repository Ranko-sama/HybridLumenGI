# Camera/TAA response 02: observer compile guard

The 01 native attempt failed before camera movement: its observer was included
for ordinary nonidentity compute entries and referenced identity-only globals.
All 01 sources, output and restoration evidence remain unchanged. This package
makes exactly one native-source change: `CameraMotionTaaCopy02.hlsl` wraps the
entire original observer in `#if defined(HLGI_RECEIVER_IDENTITY)`.

The original Editor/Scene/Tap, CPU startup probe, Feature call, three compute
entry pragmas, 48-frame sequence, 264 selected targets, 12+45 buffer ABI and all
response expectations are retained. The temporary asset root deliberately stays
`Assets/CameraMotionTaa01` so those C# sources remain byte-identical; it is fully
removed and restored by the prior failed run before this package can prepare.

`reuse-source.json` pins the six verbatim copies of the qualified 01 math and its
tests/contract addendum, plus original source/failure evidence. The effective
analysis is `qualification-ties/analyze.py` in this package. It uses the same
repository-relative depth and validates the new source/staged manifests as well
as the original proof hashes. No new math tests or output thresholds are added.

Preparation commands (no Unity):

```powershell
& 'C:/Users/Administrator/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' -Xutf8 -B LocalComparison/Review/camera-motion-taa-response-02/prepare.py prepare
& 'C:/Users/Administrator/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' -Xutf8 -B LocalComparison/Review/camera-motion-taa-response-02/prepare.py preflight
& 'C:/Users/Administrator/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' -Xutf8 -B LocalComparison/Review/camera-motion-taa-response-02/compile_observer.py
```

The managed preflight explicitly reuses the successful 01 checks after matching
all five prepared C# files and 112 product sources. Shader preflight newly compiles
all six affected entries in each of three full contexts: CSUpdateCache, CSTrace,
CSTemporal and CSFilter with identity off; CSTemporalIdentity and the observer
with identity on. All 18 checks must pass. No unchanged-C# recompilation or GPU
execution is implied by a reused managed result.

Root alone runs `run.ps1`. The required entry remains `CameraMotionTaaEditor.Run`
and `-cameraMotionTaaOutput`; native output/logs/restoration are new under this 02
package. After restoration, run `verify_execution.py`, then:

```powershell
& 'C:/Users/Administrator/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' -Xutf8 -B LocalComparison/Review/camera-motion-taa-response-02/qualification-ties/analyze.py LocalComparison/Review/camera-motion-taa-response-02 --output LocalComparison/Review/camera-motion-taa-response-02/analysis-first.json
```
