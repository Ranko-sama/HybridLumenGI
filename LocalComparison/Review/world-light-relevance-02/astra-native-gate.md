# Astra pre-native gate — world-light-relevance-02

Reviewed on 2026-10-28 against candidate commit `12e50473d417d621686ecd726ef298d79ea1b169`, before this package's installation, build or Player attempt. This is the narrow review requested by Pro30: saved-input replay, path wrappers and source identity. No test, preflight program, compiler, Unity, Player or full analyzer was executed during this review; existing results and relevant file hashes were read.

**Decision: no new prebuild blocker found. Proceed with this package's one authorized build and, only after its build/source acceptance, one visible DXR Player with exactly 64 target-camera frames.** The original 01 native admission failure remains unchanged. This gate does not grant another attempt if package 02 fails.

The replay satisfies the specific prebuild requirement. The new `HLGI_LIGHT_NATIVE_REPLAY` branch returns before the ordinary Lighting suite. It reads the saved native float inverse matrix with `GetSingle`, calls the actual corrected TryScreenDomain, then performs the same traversal-followed-by-capture in-place unions as Feature. The existing log reports 455 checks and 44 successful sequential unions over the 22 saved groups. Direct comparisons require the final domain to contain every input endpoint; independently evaluated double reconstruction samples corroborate the screen range.

The three saved 80-byte records are decoded, reconstructed as the fixed ordinary light inputs, and required to match the actual packer before the actual collector runs. The expected related light is taken from the saved third record, not from the candidate exclusion boolean. The independent distance checks support the two remote exclusions and the remaining range intersection. The observed single active-prefix SHA256 is `C48AFC0FEAC973E740E287D0F5B56D4D8E696991CD45A6E8B5C654F9D6DA3803`, matching the saved third native packed record. The broad replay domain is intentional; no margin, frustum, light position or expected output was tightened to obtain this result.

The replay-source archive hashes match the current five replay input files, including actual helper `2B91F9485CF6B08006ADD5471946D6396A8F08E3A4128274164B7C10339A9CBE`. The saved input hash remains `97480FCE13986D076A3C3EE386CA6C09F333D0AE4005CF3A85DB6910C07DF0D3`, identical to the original 01 binding receipt. The existing 693-check and 19,995-assertion results were reused; their suites were not silently run by this replay branch. This replay still does not execute native Feature camera qualification or a GPU upload.

The path wrappers keep the execution contract intact:

- Preparation changes the new package/OUT globals, including the underlying installer globals, and archives the wrapper alongside the reused installer. The five actual prepared C# files are byte-identical to 01 and match their new manifest hashes.
- The analyzer wrapper redirects its own module, inherited build verifier and shared product verifier to package 02 / `WorldLightRelevance31`. It reuses the original run assertions without weakening domain, count or active-prefix acceptance.
- The PowerShell diffs change package, installer/analyzer path, output directory and build-log names only. The visible-window arguments, fixed 64-frame Mode, attempt guards, watchdog and restoration remain unchanged. `WorldLightRelevance30` is not selected as the new executable.
- The internal fixture label remains `world-light-relevance-01` because the entire observer is deliberately reused byte-for-byte. `preflight.json` discloses this. The independent package, attempt, source manifest, build output and new run ID establish the new execution identity; the reused label alone must not be used to identify its result.

The new and old product manifests have the same 111 source paths; the only product byte difference is the approved LightRelevance alias fix. The new manifest baseline is the committed candidate. At this review, all five prepared files and all replay source snapshots matched their recorded bytes. `instrumentation/installed.json`, `build-attempt.json` and `native-window/attempt.json` were absent.

The saved preflight reports 435 unchanged non-product/non-harness build-input files and preserves the old complete 284-file product set. I inspected the preflight's comparisons and its first failure. The first program attempted to open Unity's virtual Packages path directly through Python and failed before acceptance. The corrected resolver accepts exactly one PackageCache folder whose package name and version match the lock, then still requires the selected file's SHA256 to equal the old build receipt. Ordinary missing paths and ambiguous package matches remain errors. This is a path-resolution correction, not skipping a dependency, substituting changed bytes or relaxing an assertion. The first script and failure log remain available.

No full implementation rereview or additional test matrix is requested. Native success still requires the new build's final hardware receipt, valid complete recorded domain, `3/2/1/0` admission, actual C# binding count one, completed GPU active-prefix byte equality and the existing exit/restoration checks. C# count remains distinct from GPU constant readback, and upload remains distinct from radiance/quality acceptance. If any gate fails, preserve the first evidence and return to Pro review.

Read artifact SHA256 values:

| Artifact | SHA256 |
|---|---|
| instrumentation/manifest.json | 247BCC3E7E0751BEAD13E5AA72A5FAA2B45C26CB85BDEA02F6761CAC58F7495C |
| replay-command.log | 6901746CBD17C4C5B318A8989F64081F528F244880C3A5CFF5CDF9A5C67AF3CC |
| preflight.py | 1BF5D3DA04D6F7AEB0968ADD7793E7760D6546AE0491ED4AD8813E9E6B48E43B |
| preflight.json | BB9B3BA7440348963B91F2DBB04087F292E7395E0E3653E43A3AE0EA323274FD |
| preflight-first.py.txt | D193B05A8EBFDFEE6408534DD5920B29C09119A6F7DB0275C8BA56D6DFB5FA0F |
