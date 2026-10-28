# Astra independent results review — material-mpb-propagation-02

2026-10-28. Read-only review of the saved run, executed shader instrumentation and offline decoder. No Unity run, test, additional sampling or product edit was performed for this review. Original01 evidence and its failed review gate remain unchanged.

## Decision

No blocker to submitting this limited successful experiment to actual GPT-6 Pro25. The evidence supports automatic slot0 MPB discovery, the observed source/upload and receiver-history response, and one recorded positive target-material contribution to a selected gather estimate. It does not establish full-image material correctness, slot1 screen-history coverage, image equivalence or production acceptance. No product defect requiring a Runtime change was established.

The actual report is `native-window/analysis.json`, with run `20261028-114647-90789262463c44e18c024ae22929e98e`. It records 256 target-camera frames, four image captures, 92 payloads and one MPB event. The Player exited0 without a watchdog; mapping/source-upload/history/native layers passed, with no mapping, source or history violations. `slot1ScreenHistoryCovered=false` and `fullProductionAccepted=false` are appropriate.

## Independently checked positive consumption

The saved frame172 `actual-paths` bytes match their payload receipt hash. In control screen lane1, context111, call2:

- Code23 selects the world winner. Code200 identifies the actual target binding source `[18,3,3,0]` (stable ID, owner revision, geometry revision, submesh), primitive3, hardware instance9.
- Code201 records diffuse `(0,0,0.0029296875)`, zero emission and valid material confidence. Code202 returns radiance `(0,0,0.004768542014062405)` with confidence1.
- Code24 carries exactly that incoming radiance, sample confidence approximately0.65 and actual weight `0.06810857355594635`.
- Code25 changes the blue accumulator from `0.0000834529782878235` to `0.00040823157178238034`. The observed increment is `0.00032477859349455684`; the independent double product of recorded radiance and weight is `0.00032477859451938984`. This is actual positive accumulation, not merely a hit or material evaluation.
- Subsequent recorded area contribution is zero. The known terminal divides the accumulated sum by two rays and records blue `0.00020411578589119017`. The actual samples-buffer raw blue is `0.0002040863037109375`, exactly the binary16 representation of that terminal value.

The executed instrumentation places these records around the original ProxyRadiance return, original accumulator call and final gather write. This closes the recorded path through the gather raw output. It does not isolate the event's counterfactual contribution to final display brightness.

The decoder reports 22 target evaluations and one qualified nonzero path. Raw spot checks of target-screen evaluations at160 and172 show actual zero weights, winner code4 and no accumulator increase. Excluding those evaluations from consumption is correct; their nonzero evaluated radiance alone proves no contribution. The selected cache's surface-input records are also separate from proof that another path consumed its irradiance.

## Identity and history scope

Saved samples show target identity key30 at159, key39 at160 with actual object flags0, then flags1 at161. Target history length changes32→1→2 and later returns to32. Frame160 known raw equals the new history sample, consistent with rejection of the old material identity.

Green wall's source/key36 and reusable flag1 remain unchanged, but its history length changes32→2 at160. Therefore the result must not say that the control point's history was unaffected. This is distinct from a source-identity rejection or a slot1 material-source leak; no new product defect follows from that count alone. Slot1 remains a CPU source/upload and owner-card control, not a screen-history observation.

## Decoder wording and native exit

`material_event_paths.py` originally labels presence of code202 as `materialResolved`. That is completion of the recorded radiance evaluation, not a direct observation of ProxyRadiance's local `materialResolved` boolean. Rename it to `radianceEvaluationCompleted` or explicitly qualify its meaning, retaining the initial derived report. This wording correction does not change the positive consumption proof and needs no GPU rerun.

The native log ends with generic retirement owned/pending/unknown/failed/failedWithdrawals and material/arena/deformation/job accounting all zero. No attributed retirement, GC buffer-disposal, unreleased D3D or scratch warning was found in the checked log. The ordinary UTP MemoryLeaks aggregate is retained and is not classified as a new GI leak. Build analysis reports110 product sources and284 outputs; restoration reports the product sources restored. Neither Runtime nor original01 has a review-induced change.

## Next bounded priority

Close this MPB observation package after Pro review; do not add target rays, alternate views, another material run, darkness attribution or timing work. A useful next distinct gap is one normal update of the existing deforming mesh: verify publication of the new geometry, its actual consumer identity and rejection of ineligible old-source history. Reuse the existing scene and finite observation machinery; change Runtime only if that event yields a concrete product counterexample. The detailed next contract remains Pro's planning decision.
