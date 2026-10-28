# Astra independent results review — deformation-snapshot-propagation-01

2026-10-28. Independent bounded review of saved source arrays, lifecycle receipts, GPU buffer bytes, selected samples, original-path records and native exit. No Unity, test fixture, additional sampling or product edit was performed. Existing artifacts were parsed directly; the full analyzer was not rerun. Only these requested review documents were written.

## Decision

No blocker to submitting the limited results to actual GPT-6 Pro26. The evidence supports the requested visible-mesh edit, coherent CPU snapshot publication, completed readback of newly bound geometry, the covered receiver-history response and observed snapshot cleanup. No product counterexample was established.

New-geometry ray-hit coverage remains false. Binding and completed attribute-buffer readback do not independently prove that a ray intersected the changed geometry. Preserve this gap and do not add another run, ray, viewpoint or target selection to fill it. Full production acceptance remains false.

The sole run is `20261028-122659-067a28c4d8de4e3b85c50b746429aef8`, PID13544, native exit0 without watchdog. It contains256 target-camera frames, four images and70 payloads; no violations or native failure signatures were reported. The ten detailed frames are159–164,175,191,223,255, matching the fixed frames and overlapping publication/dispatch windows.

## Input and publication clocks

Direct checks of the saved1324-byte mesh payloads verified their receipt hashes. Initial and before-event payloads are byte-identical. After-event, capture-5 and publish-6 payloads are byte-identical, despite the visible mesh and immutable snapshot having distinct Unity identities.

Exactly12 of24 vertices changed. Only vertices with y=0.5 moved: x=-0.5 became0.30000001192092896, and x=0.5 became1.2999999523162842. UVs, tangents, topology and indices remain unchanged. Normals were recalculated and the resulting arrays were preserved through capture and publication.

The receipts distinguish the following times:

| Transition | Logical frame | Engine frame | Evidence |
| --- | ---: | ---: | --- |
| Event request and actual capture |160|161|request generation3 and job generation3; new snapshot mesh-422 copied from visible mesh-94|
| CPU publication |161|162|published mesh switches from-238 to-422; SDF/charts/capture links refer to the new snapshot|
| First new-geometry dispatch recording |161|162|actual bound backend mesh-422, target instance4, geometry revision23|

The product's `PublishedFrame=161` is the capture engine frame. It is not the publication engine frame162. These observations do not establish a general one-frame asynchronous latency or a performance guarantee; collection overhead and this finite workload remain part of the experiment.

Both saved publications have coherent mesh/SDF/chart/capture references and nonempty source fingerprints. Their16³ SDF payloads are16384 bytes with matching hashes; capture-mesh hashes also match. Chart count changes6→8. This is source/publication coherence evidence, not a new independent SDF-distance or chart-baking accuracy proof.

## Actual bound GPU geometry

I checked receipt hashes and parsed instance/surface bytes at159,160,161 and255. Target instance4 has geometry tuple `(slot4, normalOffset48, triangleCount12, submesh0)`.

- At159 and160, instance identity is `(stableId4, ownerRevision22, geometryRevision22, cull2)` and all12 triangles match the old snapshot exactly.
- At161 and255, instance identity is `(4,23,23,2)` and all12 triangles match the new snapshot exactly. Each comparison covers the three float3 positions per triangle; maximum component difference is0.

Thus160 correctly records a changed visible source while the GI consumer still uses the declared old snapshot. At161 the published snapshot, surface geometry and bound backend agree on the new source. Registry GeometryGeneration39 and proxy/backend geometry revision23 are different identity domains; the review does not compare them as a shared counter.

The recorded build/bind operations plus completed GPU readback prove the observed bound data. They do not replace a ray-hit result. The decoder's `targetHits=[]` is consistent with an additional direct scan of existing hit codes21,31,45 and200: none contains the target stable ID in either selected lane. Other unrecorded queries, including any receiver-guide query without a hit record, are outside this negative statement. Say “no recorded target hit proves the new geometry,” not “all original queries missed the target.”

## Receiver history and unknown semantics

At160 the selected target remains covered, its identity key changes8→39, its actual object reusable flag is0, and known raw equals the new history with count1. The visible receiver GeometryGeneration changes7→39 while MaterialGeneration stays8. This precedes CPU snapshot publication and therefore must not be described as a GPU-publication-triggered identity change.

At161 the key remains39 and reusable flag returns1, but history count is still1. At162 it is2, then it increases through later sampled frames and reaches32 at255. The report should not describe uninterrupted growth starting at160. The161 zero RGB has positive measurement alpha and is measured black, not missing radiance.

The startup correction separating radianceKnown, receiverValid and hasNg is consistent with the product contract. All recorded selected-target samples in this run have known Ng; the run adds no empirical coverage of the unknown-Ng branch. There is no basis to turn this experiment into a darkness investigation.

## Retirement and exit

After sequence6 replaces the published snapshot, lifecycle sequence7 requests retirement of the old snapshot. Sequence8 records the hook after the original Destroy calls and reservation decrement. Both occur at logical161/engine162. Its reservation becomes0 and total reserved bytes fall107520→53760. At shutdown, sequence9 withdraws the new snapshot and sequence10 records the corresponding destruction hook; total reserved bytes become0. Each published snapshot has one later destruction receipt.

These receipts establish execution of the cleanup calls and accounting return for the two observed snapshots; they do not timestamp Unity's eventual physical release of each native object. This package did not add per-ticket fence tracing, so it relies on the existing retirement implementation for the completion-before-destruction contract rather than claiming a new exhaustive last-reader proof.

No lifecycle-observer error file exists. The native log's final generic drain reports owned/pending/unknown/failed/failedWithdrawals and material/arena/deformation/job accounting all zero. The ordinary UTP MemoryLeaks aggregate remains in the log and is not classified as an attributed GI leak. The inherited `incomplete-probe` label remains unchanged; the dedicated event receipts establish this256-frame package, not the old720-frame sequence.

Build analysis records110 product sources,17 temporary files and284 products. The restoration report marks all17 files restored and product restoration true. Runtime and previous package evidence were not changed by this review.

## Next action

Submit these finite layers and the explicit ray-hit gap to Pro. Close this run without extending it. No Runtime repair, additional geometry test matrix, timing pass or dark-region investigation is justified by the evidence collected here.
