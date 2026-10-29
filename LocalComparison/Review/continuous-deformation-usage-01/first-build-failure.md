# First69 build invocation stopped before BuildPipeline

The unique Runtime+Editor managed preflight passed, both exit0. The unique Unity
invocation then exited1 in the reused67 `SetupCurrentRelease67Cube` guard:
`Release67 Cube asset path must be absent; do not replace an existing input`.
There is no69 build-report, executable or native Player run. This is not a GI
runtime failure. No retry, asset deletion, cache clearing or source change followed.

Evidence: build-unity.log371–378, build-exit.json, preflight/exit.json,
asset-state.json, asset-restoration.json, instrumentation/restoration.json and
excluded-restoration.json. The unique target asset and meta were absent at prepare
and installation. Finally archived only Renderer.asset/meta; neither Cube file was
found. All temporary files/assets restored. Current accepted product50b63c3 remains
deployed (only Scene differed from2fefc09). Release67 is unchanged.

The guard combines file/meta/directory existence, LoadMainAssetAtPath and the default
AssetPathToGUID result; it did not record which disjunct fired. Therefore exact Unity
database state is not proven. A documented likely explanation is the default GUID
query includes recently deleted assets. Unity6 explicitly provides OnlyExistingAssets
for disk-existence semantics:
https://docs.unity3d.com/cn/6000.0/ScriptReference/AssetPathToGUIDOptions.html
https://docs.unity3d.com/ja/current/ScriptReference/AssetDatabase.AssetPathToGUID.html

Proposed minimal correction for review: use AssetPathToGUID(...,
AssetPathToGUIDOptions.OnlyExistingAssets) only in the collision guard, retaining
disk/meta/directory and LoadMainAssetAtPath protections. Preserve this first attempt
and all runtime/sample/check bytes. One fresh correction attempt may then complete
the already-requested example; the unused256-frame Player allowance stays unchanged.
Do not rename the feature/package to reset cumulative effort, introduce an observer,
clear Library, weaken real-asset collision checks or claim the first build passed.
