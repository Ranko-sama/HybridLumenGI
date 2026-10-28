# Scene radiometry reference01 — source gate before integration

Baseline05d6220; actual Pro14 next plan is archived in the preceding package.
The intended independent CPU reference has six fixed targets: two actual cache
anchors and four actual GI receivers at119. Maximum8 independent batches of4096
paths per target,64 diffuse vertices; no product cache/incoming/guiding functions
as reference input. C is indirect incident E/pi; explicit direct d is separate.
Statistical uncertainty and truncation tails are not GPU acceptance tolerances.
No rendering sequence or Runtime tuning is authorized within this package.

Before any integration, require historical raw geometry/material/light identity
and all material dependencies. GUIDs, names, current timestamps, current API values
or matching emission fields alone cannot establish historical diffuse properties.
Opening a frozen scene with current external dependencies is a current export,
not a recovered historical snapshot. Do not regenerate the scene.

The initial read-only audit found six external material GUIDs in the archived
scene, while execution.json binds only eight executed scene/settings assets and
the source inventory stores emission-oriented fields. The current six materials
exist, but no historical BaseColor/Metallic source has yet been established.

Deliver a bounded filesystem snapshot/audit first. Preserve frozen scene/contract/
inventory and actual target input hashes; preserve current six.mat/.meta bytes
with explicit current-only status. Search the existing relevant evidence manifests
for their content hashes, recording search scope. Target-position extraction and
surface/triangle correspondence are separate statuses. Do not use observed material
or incoming illumination to manufacture missing independent material inputs.

If historical closure is absent, report historicalSourceClosure=false,
integrationExecuted=false and historicalQuantitativeComparisonPerformed=false.
Exit2 denotes this expected source gate stop, not a product rendering failure.
Do not start Unity or implement/run a solver on unproven historical inputs merely
to reach a numerical result. Return the exact missing dependencies to Pro for the
smallest forward baseline with matching inputs. This is not six-point completion;
the full plan and reference implementation remain open.
