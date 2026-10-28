# Iteration17 — second distinct exporter failure, still before Play

Actual Pro16 authorized one NEW attempt in this separate package. Unity PID19516
exited1 before source freeze or EnterPlaymode. The prior project-manifest resolver
failure was bypassed; the exporter enumerated dependencies and copied607 files,
then Mono File.WriteAllBytes failed on a262-character destination:

Packages/com.unity.render-pipelines.core/Editor/Settings/PropertyDrawers/RenderPipelineGraphicsSettingsContainerPropertyDrawer.cs.meta

The destination parent exists; the final file does not. Previously copied paths
reach257 characters. The log's DirectoryNotFoundException points at the archive
write in the actual prepared exporter. This is consistent with the Windows/Mono
path limit. It is not a GI rendering defect. There were0 target frames,0 new
captures, no source-freeze, no119 targets and no CPU integration. No second process
was started in this package. The failed16 package was never overwritten.

All42 deployment entries and96Runtime source hashes are restored. New metadata is
preserved under instrumentation/post-run and removed from the deployment. No Unity
process remains. Partial source/assets are diagnostics only, never paired with old
or future target positions/radiance. Source closure and all rendering/reference
acceptance flags remain false. Original full plan and exceptional scratch remain open.

Implemented before native: qualify-radiometry.py uses the existing shared native
scanner plus narrow supplements and validates sources, exact receipt-stage coverage,
actual GI frames, target provenance, finite data, native exit and restoration before
CPU admission. The comparator reuses that same function and gate input hashes.
Astra reviewed this wiring without a new fixture matrix. Native never reached a
state where qualification or integration could run, so this wiring has no new
successful native evidence yet.

Minimal post-failure candidate: export to source-assets/<sha256>.bin while keeping
every original path, hash, byte count and archive path in the manifest. Duplicate
content must match exactly; no failed/missing dependency is ignored. Freeze is
still written only after all archives succeed. The actual Archive/Resolve/Hash
methods were compiled and run once via Unity's bundled Mono using the precise
native-failing source file: write/readback bytes and hash matched, path207 chars in
the isolated probe directory (196 under the actual run root). Original607 archived
files were not changed. This repair is NOT installed or Unity-native validated.

Additional source-closure issue identified statically: Dependencies ended with
Where(File.Exists), intended to exclude virtual resources but able to silently omit
a missing real selected file. Astra recommended the narrow repair now: record
Unity-confirmed folders and only the exactly observed Library/unity default resources
path whose actual mesh arrays are exported; throw on every other missing selected
file. The candidate now records dependency-selection.json and exclusions in freeze.
Unknown paths are not guessed to be virtual. This guard change has not been native
validated; no missing-source success is claimed. It does not shrink the source list
to avoid the long destination path or create a general exporter framework.

User central-dark-region question remains open quantitatively: old119 HDR has small
nonzero values, and the configured geometry blocks direct light. The existing six
reference targets cover the wall/block; no new points or retuning were introduced.
