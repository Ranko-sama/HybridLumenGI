# Result: Gather dominates; the one reuse candidate was reverted

Both permitted instrumented Unity DXR runs completed. Each used 144 warmup frames, preselected sources 145–208 (64), and 32 drain frames: 240 total, below the 352 cap. All selected formal/diagnostic completion pairs are unique, source-matched and nested correctly. Quotas remain 256/24/16; feedback is off and target is zero. Diagnostic source wiring is byte-identical, and the only changed build input is the candidate Kernels file.

| Queue interval | Locator median ms | Candidate median ms |
| --- | ---: | ---: |
| WorldCache | 2.341952 | 2.361568 |
| Gather | 16.907376 | 16.879520 |
| Reconstruction | 0.073200 | 0.072912 |
| Formal Transport | 19.626784 | 19.610416 |
| Per-source formal three-scope sum | 19.784896 | 19.770336 |

Gather dominates. Its candidate median saving is only **0.027856 ms (0.165%)**, below the locator's block-median range of 0.269056 ms and the candidate's 1.138176 ms. The candidate's four consecutive block medians are 16.824192, 16.847696, 16.738000 and 17.876176 ms. The last block is retained, not discarded. No clear speedup is established. The frozen retention gate therefore rejects the candidate without adding frames, runs or another optimization.

The candidate did satisfy its finite computation checks: old/candidate actual extracted HLSL produced bitwise-identical complete outputs for 30 cases / 60 directions, including archived full-resolution Unity depth neighborhoods. All three affected CSTrace entries compiled. Optimized DXC inspection shows receiver depth load sites moved out of the ray loop; this is not GPU machine-code register evidence or full-image equivalence. Details and source/newline mapping remain in `contract.md`, `receiver-contract/`, `compiler/` and `source-newline-normalization.json`.

`candidate-product.patch` and compiler snapshots retain the attempted source. `rollback.json` verifies that all 110 product sources in both the repository and deployed Unity project match the locator baseline again. No Runtime optimization remains. Temporary timing instrumentation was restored after each build and is absent from the product tree.

Locator build PID 15388 produced 284 files; candidate build PID 35484 produced 283. Each frozen product set is internally verified; the identical build-input set differs only in Kernels. Locator Player PID 15208 and candidate PID 13268 both exited 0 without watchdog termination or new recorded resource/backend failure signatures. Recorded project owner accounting drains to zero. The two out-of-window pending diagnostic submissions are canceled by Stop; this does not prove every native timing query slot was explicitly released before shutdown.

Both necessary builds verify the corrected exclusive Windows importer. Historical iteration 22 metadata remains unchanged and explicitly non-exclusive at its build time.

These are two finite Development Mono / Windows DX12 / RTX2080Ti instrumented windows. They do not certify whole-application cost, dynamic/Release tails, total VRAM, long-term resources or production image quality. No new screenshot/reference, dark-region investigation or Monte Carlo expansion was performed. Actual GPT 6 Pro23 approved the evidence commit and rollback. Next is material-mpb-propagation-01: one slot-0 BaseColor MPB event at logical160 in a fixed256-frame DXR run, with no manual invalidation. See gpt6-pro-review-and-next-plan.txt.
