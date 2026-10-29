Prepared only; no Unity, deployment or native GPU execution by the author agent.
Root owns all execution and may combine this package with current product work.

Single entry: FiniteWallOcclusionEditor.Run
Required argument: -finiteWallOcclusionOutput <new absolute native directory>
Owned temporary project folder: Assets/FiniteWallOcclusion01
Fixed limit:56 consecutive whole-URP StandardRequests,300seconds wall time.
Source panel x20 -> .25 before32 ->20 before44; no other physical source event.

Python executable on this machine:
C:/Users/Administrator/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe
From the repository root, use that executable with -B -Xutf8:
  LocalComparison/Review/finite-wall-occlusion-response-01/prepare.py prepare
  LocalComparison/Review/finite-wall-occlusion-response-01/prepare.py preflight
Then inspect the staged full shaders and compile both new kernels as appropriate.
The existing root-owned run.ps1 stages,launches once,archives and restores in
finally. It rejects an existing attempt. The author did not run any of these.

After root has closed execution/restoration provenance, analyze exactly once:
  LocalComparison/Review/finite-wall-occlusion-response-01/analyze.py
  LocalComparison/Review/finite-wall-occlusion-response-01
  --output LocalComparison/Review/finite-wall-occlusion-response-01/analysis-first.json
(The three lines above form one command after the Python executable/flags.)

Physical math and classifications are contract.txt,contract-freeze.json and
input-classification.txt. CPU-only11test log/result preserved; independent
reviewer checked ABI128/64/96, sampler valid marker,source/pose distinctions,
actual-motion/previous geometry qualification and known-black premises.
source-freeze.json records the prepared files before root preparation/native.

No per-ray actual-hit receipt is captured. Input rays,actual instance transforms,
black-source response and RTAS counters must not be described as a recorded
winning blocker ray. A late GPU pose does not exempt known stale physical color.
Three representative final images31/43/55 only; compact input and history data
every frame. Native exit0 alone is not acceptance. No thresholds were fitted to
new native output, and there is no new native output at author handoff.
