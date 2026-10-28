# thin-wall-transport-01: observer failed; no product conclusion

Task c2c_a702 iteration5. Baseline main@870ba82; approved resource code is bd5a7d2. Runtime product sources are unchanged. This experiment has stopped at its declared observer-failure boundary; B and C were not run. No thin-wall image-quality, energy, visibility or cache conclusion is supported by the invalid first capture.

## Preparation and failures

The fixed contract is ThinWallTransport01-TestContract.md: three configurations maximum,120 logical frames each, nine predeclared stage samples, static original thinView and exact software path. A is normal; B only sets cache feedback0; C retains the one original point light and two analytically blocked/clear floor connections. Four selected camera rays are receiver-identity probes, not actual gather rays; A-B cannot prove identical sampling or an exact multiple-bounce component. C does not cover actual cache tap/anchor visibility. Actual GPU light/scene/policy/cache buffers are included in the proposed readbacks, rather than substituting inspector values.

1. C# fixture import failed at Light.renderingLayerMask int→uint conversion. Exit1, no capture frames. Fixed with the explicit unchecked cast preserving all bits. Original log and helper/manifest are under LocalComparison/Review/thin-wall-transport-01/compile-failure/.
2. The next A attempt entered Play and rendered exactly one invalid frame, then the existing capture error gate exited1. Newly added ThinWallQuery.hlsl used `point` as a struct member, which is an HLSL keyword. Because the diagnostic include was unconditional, its parse failure also invalidated the original compute entries. This is an observer-induced shader failure, not evidence of a product rendering defect. Independently, direct AsyncGPUReadback of the depth texture failed. The manifest reports99 cascading errors, and14/15 stage copies are not valid GI evidence. Preserve observer-failed/Unity.log, observer-failed/A/, all executed source bytes and manifests. The log also has unresolved retirement warnings after this failed render; these faulted/invalid-shader conditions were not part of the approved normal-shutdown acceptance. They are retained, not suppressed or called a same-scenario regression.

## Corrected observer, not yet dispatched

Current helpers rename the field receiverPoint and put the extra include behind HLGI_THIN_WALL_QUERY, defined only by the new probe kernel's pragma. The original compute entries no longer parse the diagnostic body. Depth is copied with exact Texture2D.Load into an explicitly imported, private float buffer; no linearization or row flip is applied. The buffer has graph write dependency and remains owned until the ordered readback completes. Other stage/query behavior and all product inputs remain unchanged.

The corrected fixture passed one zero-capture Unity import/setup invocation, exit0. See v2-import.log and execution-receipts.json. This proves C# import/setup only. There was no Play, no new dispatch, no complete kernel executability or readback-lifetime proof; HasKernel and absence of error logs do not establish these. Proposed/exact prepared source is under instrumentation-v2/. The old executed observer remains separately preserved.

Both versions' product Feature, material pass, exact-software wrapper and capture instrumentation were restored by original SHA256. Prepared helper assets remain inert in the test project; the ordinary product sources in the workspace remain at the approved baseline. All changes in this package are test/contract/evidence files and are uncommitted.

## Independent guard and requested next plan

Astra recommends respecting the stop boundary and returning this failure to Pro before more captures. It confirms the raw depth copy/ownership and kernel-isolation direction, but does not certify the unexecuted observer. No product algorithm fix is justified. See astra-stop-review.txt.

Please independently review the failure and corrected observer. Give a minimal bounded retry plan, preferably one A→B→C attempt with unchanged120-frame caps and a stop on any new observer/coverage failure; alternatively reduce the observer if it is unnecessarily complex. Do not add an exploratory parameter/seed/scenario matrix, tune the image, or treat the failed frame as data. The full original development goal remains active; this is an explicit failed subpackage, not a final stop.
