# Iteration 15 — historical radiometry source gate

Baseline main@05d6220. Followed Pro14's source-first and stop-on-gap instruction.
This package stopped before reference integration; the six-point reference is
not completed. No Unity process, Play mode, rendering, solver execution or Runtime
change occurred. No user input is required to choose the next prospective package.

## Concrete gap

The archived C scene references six external material GUIDs: White, Black, Emitter,
Green, Red and Metal. Chain02 execution.json binds eight scene/settings assets;
none is a.mat dependency. Its source inventory stores emission/keyword/environment
fields, not complete BaseColor/Metallic/specular inputs. Thus it cannot establish
historical diffuse inputs independently of the measured GI output.

The six current.mat/.meta pairs were read directly and preserved in
`LocalComparison/Review/scene-radiometry-reference-01/snapshot/current-only` with
hashes. Their current timestamps precede the old run, but timestamps and matching
GUID/emission data do not prove historical byte identity. All have
historicalIdentityProven=false. Searches for the six current content hashes found
no matches in existing workspace LocalComparison JSON evidence or the local test
Comparison manifest/receipt/inventory stores; exact scope is recorded, not a claim
that no backup can exist anywhere.

The audit preserves the original frozen scene, C contract and inventory under
their execution-manifest hashes, plus six measured target positions/normals and
record indices. Targets contain no cache irradiance, incoming radiance, guide or
observed material answer. Actual anchors are approximately(6.543878,0,0) and
(9.456120,0,0), which are not the original world-rule coordinates. Triangle/source
surface correspondence is explicitly unverified; location extraction is not full
reference-input closure.

## Execution and stopping decision

One offline audit8b7489 returned the predeclared source-gate exit2. Output is
source-audit.log and snapshot/source-audit.json. Recorded in c2c iteration15;
the failure status denotes missing reference provenance, not a GI product defect.

- historicalSourceClosure=false
- integrationExecuted=false
- historicalQuantitativeComparisonPerformed=false
- sixPointReferenceCompleted=false
- targetLocationsExtracted=6
- targetSurfaceCorrespondenceVerified=false

Astra agreed before implementation that a new export cannot recreate the missing
historical identity and that no solver/Unity run is needed to demonstrate that
gap. It independently reviewed the final artifact and found no blocker or answer
contamination. Full conclusion is in astra-review.txt. Current-only material data
must not silently be promoted to the historical run's source by a future script.

## Next decision requested

Approve this truthful source-gap checkpoint, then select the smallest prospective
reference baseline that binds complete source inputs and matched product outputs.
Use the frozen scene structure without regeneration; explicitly establish a new
baseline for current material dependencies. Prefer one bounded static on-state
comparison with a clear warmup/capture contract over another360-frame off sequence.
The independent six-point CPU solver, locked URP units/material rules and bounded
sampling remain the intended substantive work. Source closure and actual triangle
correspondence must precede integration; do not compare new source inputs to old
GPU results as if they were matched. No old failure or acceptance state is changed.
