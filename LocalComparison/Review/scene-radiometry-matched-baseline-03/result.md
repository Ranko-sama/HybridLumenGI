# Iteration 18 — matched native capture and independent integral completed

This is the first successful prospective C baseline, after the separately retained
iteration 16 and 17 exporter failures. No Runtime behavior was changed. The full
original development plan remains open; this package is not production acceptance.

## Native evidence

One Unity process, PID 19364, exited 0. Run
`20261028-064814-54d9083b29e448d59def1b2db59821ed` contains all 120 requested camera
frames, two PNG/HDR captures at 104 and 119, and zero capture errors. The generic
run status remains `incomplete-probe` because that older status expects the full
720-frame suite; this explicitly bounded 120-frame experiment completed. Do not
rewrite that raw status or treat it as full-suite acceptance.

The pre-integration gate passed source selection/archive byte and hash closure,
frame 103/119 source receipts, unique cache identities and target provenance,
readback coverage, finite values, normal exit and shared native-log scanning.
All 42 deployment entries and 96 Runtime source hashes were restored. The scene
hash is 36d430a676715b0d5c05610d44b3f88bd6ad7ad83c081b23d3984b6ed324076e;
target hash is 8bcec88dd9e3912775b7db8aefd0e8f0c14d8059a7c090d3e75159af7cbcd273.
Independent source-triangle correspondence subsequently passed for all six points.
The gate's earlier `targetSurfaceCorrespondenceVerified=false` is its pre-solver
state, not a failed correspondence check. Preserve that chronological distinction.

## Independent integration and retained failure

The first solver entry failed during correspondence JSON serialization because
a NumPy float32 tolerance was not JSON serializable. It failed before integrate(),
and produced zero batches/paths. Its log, original solver source and started marker
are retained in `reference-serialization-failure.log`,
`reference-before-serialization-repair.py.txt`, and
`reference-failed-before-integration/`. The only repair casts the two serialized
tolerance/originOffset scalars to Python float; it changes no numeric value, seed,
input or sampling configuration. Astra reviewed this boundary.

The first actual integration then completed six targets × eight batches × 4096
paths = 48 batches / 196608 paths, at most 64 diffuse vertices. No extra sampling
or second Unity run occurred. Its input is only the new frozen source and target
positions/identities. Product RGB is read only afterward by the comparison.
`reference/reference.json` retains all batches, bounce contributions and termination
counts; `reference/correspondence.json` identifies the actual source triangles.

Finite estimates exist, but the frozen strict precision rule does not pass:
simultaneous sampling half-width 1.3085425509592417 and nonnegative tail bound
9.578521861569207 are much larger than the estimates. Approximate batch t intervals
are descriptive only. `referenceEstimateQualified=false` and
`comparisonConclusive=false` remain false; no threshold/seed/sample changes.

## Six-point comparison and the central dark region

All six direct-light reference contributions are zero. The only point light is
behind the thin wall and front receiver, with ambient/sky disabled. This explains
why darkening is plausible, but does not validate the amount of indirect light.

| Target | Source surface | CPU finite64 RGB | Product frame119 raw/cache RGB |
|---|---|---|---|
| cache-0 | Thin-wall floor | .000611, .003159, .000631 | .0000756, .002588, .0000957 |
| cache-1 | Thin-wall floor | .003941, .004471, .003945 | .004341, .004740, .004344 |
| gi-0 | Thin-wall receiver | .000242, .000541, .000244 | .000643, .000772, .000644 |
| gi-1 | Thin wall 3cm | .000133, .001043, .000140 | 0, 0, 0 |
| gi-2 | Thin wall 3cm | .001259, .001501, .001261 | 0, 0, 0 |
| gi-3 | Thin wall 3cm | .000237, .001068, .000243 | .0000178, .000608, .0000225 |

These compare C = indirect incident E/pi, without multiplying target reflectance.
They are not final displayed RGB. All 16 observations per point are available;
zero raw samples are valid measurements, not unknown/missing results. The two
cache lanes each committed 19 times overall and three times in the 16-frame window.
Identity/position stayed stable. GI raw zero counts in that window are 6, 3, 4, 2.
Two rays per pixel and correlated finite histories do not provide independent
steady-state GPU samples or a valid GPU confidence interval.

Frame119 filtered RGB is nonzero for all four GI points:

| Target | History RGB | Filtered RGB |
|---|---|---|
| gi-0 | .0003264, .0004425, .0003273 | .0003102, .0005288, .0003119 |
| gi-1 | .0002511, .0010586, .0002573 | .0002525, .0013390, .0002611 |
| gi-2 | .0027218, .0028896, .0027237 | .0019817, .0023708, .0019855 |
| gi-3 | .0000207, .0015516, .0000328 | .0000553, .0013599, .0000657 |

This does not show a blanket filter-to-zero failure. Numeric distances alone do
not establish a deterministic defect, convergence, or correct brightness. In the
actual PNG the region still appears nearly black; the image has been inspected.
Do not increase exposure or tune gains to make it look acceptable.

The earlier chain02 frame119 PNG exactly equals its vertically flipped raw HDR
after the capture's Reinhard plus sRGB conversion (mean absolute byte error 0;
unflipped error 8.714384). Thus earlier rough HDR row-region labels must not be
read as corresponding PNG screen coordinates. Both sampled HDR regions were
nonzero, but precise point claims here use world/source correspondence instead.

## Remaining limits

Historical chain02 material source closure remains false. The two prior exporter
failures and frozen startup-event failure remain retained. This clean normal exit
does not resolve the previous exceptional 1 MiB D3D12 scratch allocation report.
Whole-image/dynamic quality, current Player/DXR, GPU p95/p99, peak VRAM and long-run
acceptance remain open. No performance claim uses this instrumented run's times.

Actual GPT-6 Pro18 approved this finite evidence commit. Its full response is in
gpt6-pro-review-and-next-plan.txt. Next: low-light-reconstruction-attribution-01,
one bounded actual-neighborhood capture and filter/composite attribution; no new
CPU integral or brightness tuning. Continue the full original development loop.
