# Iteration11 — failed first-frame scene observation; no light-off claim

Baseline3093a22. The original four goals and ten workstreams in OriginalDevelopmentPlan.md remain open. This was the single real C-scene source-removal run requested by Pro10, not a new quality matrix. No workspace Runtime change. The run stopped after one rendered frame, before the119 coverage gate, before lamp removal and before any of the nine screenshots. Do not report the360 sequence or real-scene decay as passed.

## Evidence and exact outcome

- LocalComparison/Review/scene-lightoff-chain-01/frozen.json and instrumentation/*.frozen.txt preserve the contract, helper and analyzer before Unity. Initial DXC preflight failed on reserved word `point`; renamed `surfacePoint`, then both full instrumented CSUpdateCache/CSTrace entries passed (compile-fixed/report.json; wrapper0, chunk3beb46). The initial failure is retained, both recorded.
- Native Unity6000.0.85f1, DX12, RTX2080Ti, C/thinView/640x360, PID33648. One process only; exit1, final exec chunkf21745. Complete original Unity.log and execution.json are archived. Run directory: run/20261028-025041-7bd5177131a44762818963a6f19c445b. renderedFrames1, captures0, errors3.
- Executed serialized assets were archived before Play (eight assets), separately from original backups. All source/helper hashes at execution matched; collector nevertheless correctly exited1 on the native failure (chunk57e03c). The frozen analyzer exited1 (chunkb70c58), reported incomplete coverage and then IndexError at absent frame1. This is a partial-run handling limitation of the analyzer, not additional product evidence. Do not fix it and silently replace this result.
- instrumentation/restoration.json proves restoration of five sources and eight assets; product-restored.json verifies96 workspace/deployed Runtime source files exactly at baseline. Existing helpers were also restored. No physical rerun was performed.

## First-frame counterexample

See first-frame-forensics.json and lightoff-schedule-0000.json. Fixed world rules P0/P1 both project to card1/entry21, P2/P3 both project to card1/entry26. The rotated card projection makes four world positions only two cache cells. This is geometry-driven and was not chosen after observing brightness.

The temporary LOBegin loop assigns loLane for every matching entry and retains only the final match. Thus entry21 writes lane1, entry26 writes lane3; lanes0/2 remain the seeded zero record. Per-frame validation rejects their missing header. Actual written cache readbacks exist. This establishes an observer/selection-contract defect, not a product cache-frame mismatch. Even without this early rejection, the four-distinct119 gate could not have passed. Do not move points, loosen119 or extend warmup within the same run. A future plan should use explicit distinct cache identities and aliases or another fixed geometry-only rule, rather than requiring distinct world points to imply distinct patches.

The two populated observations have actual LightCount1, epoch4, logical/GI frame0 and actual product sampling frame0. They cannot establish source removal, decay, gather consumption or final-image quality.

## Separate abnormal-exit defect evidence

Unity.log:682 reports actual product retirement `owned=7, pending=7, unknownSubmission=0, failed=0, failedWithdrawals=0, outsideRenderLoop=True` at DrainShutdown invoked from EditorApplication.Exit/ComparisonCapture.Finish. Lines706–716 report Persistent8 and nine D3D unreleased resources, including a scratch buffer. This must stay failed. It is not proven that every native allocation belongs to those seven tickets, and the current uninstrumented retirement log does not prove their individual completion states. The earlier progress-race fix does not certify this early-failure shutdown path.

## Source inventory nuance

Ambient, skybox and feature environmentRadiance are zero. The material named Emitter retains emission color(5,3,1.5), but its _EMISSION keyword is false and no property block is present; proxy emission override is zero. Thus the existence of an emission color must not be equated to an effective active emitter. The full executed inventory and actual proposal buffers are available. This run never reached lights-off; no zero-equilibrium or residual-source conclusion is needed.

## Requested review / smallest next development plan

Independently inspect this failure, executed source, real first-frame data, original logs and restoration. Decide whether abnormal-exit retirement requires a targeted product fix first, and define the smallest valid replacement for the duplicate-selection observer. Do not repeat successful ideal-node, visibility or sampling matrices; do not turn this into a new generalized test framework. Keep the actual real-scene source-removal objective and the full original implementation/acceptance plan. Primary execution ownership remains Codex; Astra preflight summary is in the package, with model-capacity limitations explicitly stated.
