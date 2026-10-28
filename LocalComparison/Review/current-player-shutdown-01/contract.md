# Iteration20 — conservative final-render boundary and unique probe evidence

Baseline d8eb7be retains all iteration19 build success and actual Player failure.
Actual Pro19 review is in current-player-smoke-01/gpt6-pro-review-and-next-plan.txt.
Original four goals/ten workstreams continue. Dark attribution stays canceled.

Executor decision after independent Astra review: first evaluate a smaller safe
candidate than Pro's explicit RequestPlayerQuit API. Append one owned callback to
the current PlayerLoop root tail, preserving other systems; reuse the existing
IdleUpdate completion logic after synchronous final render dispatch returns.
The normal Application.Quit call and exit code remain unchanged; no cancel/reissue,
no test-side manual drain, no forced render, no new host integration requirement.
BeginContext still invalidates the certificate, unknown submission remains locked,
ordinary requiresContext tickets are not promoted. A boundary only permits fence
submission; destruction still requires actual completion/prerequisites.

The public API does not guarantee final quit checks occur after this callback.
This is an explicitly unverified candidate. If the one fresh Player disproves its
ordering/effectiveness, preserve failure, stop this package and reassess Pro's
controlled-entry alternative; do not relax guards or rerun to get a pass.
Development-only shutdown logs report existing state at withdrawal/submission/
actual destruction/drain, without extra fence reads. No general observer framework.

Probe repair: capture-open gate for Update/Rendered, close event before camera
restoration, unique logical/engine receipt, and non-overwrite files. Saved119
history statistics must be derived from the exact same completed moments payload
whose frame, engine frame, GI frame, read index, dimensions, format and SHA256 are
saved. Analyzer rejects duplicate/mismatched evidence. Preserve old failed files.

Only targeted existing-source tests plus one new Development/Mono/DX12 build and
one ordinary visible software Player120frames. Same functional scene/events,
30/119readbacks and five captures. No new runtime trials if validation fails.
No hardware Player in this package; defer to reviewed software success. No dark,
Editor/off/SDF/Streaming/720frame/performance matrix. External complete native logs
must also reject GC cleanup of ComputeBuffer/GraphicsBuffer. Report collection,
data/HDR, backend and native shutdown separately; fullProductionAccepted=false.

Keep all emitted build products hashed and matched to deployed/current source;
restore temporary test wiring. Product fixes remain deployed for local development.
After finite result: Astra, actualPro review, local commit, continue original plan.
