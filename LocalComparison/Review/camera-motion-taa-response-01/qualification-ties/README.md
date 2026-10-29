# Pre-native nearest-candidate qualification

The effective analysis is this directory's `analyze.py`; the parent files and
first preparation/compilation evidence are preserved. See
`pre-native-addendum.txt` for the source-derived half-pixel tie correction.

The installer wrapper validates every original staged file against the first
manifest and compiled source, then uses the original reversible installer.
Only the new independent proof sources are added. Root's commands are:

```powershell
& 'C:/Users/Administrator/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' -Xutf8 -B LocalComparison/Review/camera-motion-taa-response-01/qualification-ties/prepare.py verify
& LocalComparison/Review/camera-motion-taa-response-01/qualification-ties/run.ps1
& 'C:/Users/Administrator/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' -Xutf8 -B LocalComparison/Review/camera-motion-taa-response-01/verify_execution.py
& 'C:/Users/Administrator/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' -Xutf8 -B LocalComparison/Review/camera-motion-taa-response-01/qualification-ties/analyze.py LocalComparison/Review/camera-motion-taa-response-01 --output LocalComparison/Review/camera-motion-taa-response-01/analysis-first.json
```

No install or native run has occurred during preparation. The run keeps its
native output, attempt, logs and restoration under the original parent package,
with `Assets/CameraMotionTaa01` as the exact owned temporary project root.
