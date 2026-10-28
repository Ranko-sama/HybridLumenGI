# Iteration 22 — gpu-cost-baseline-01

Task c2c_a702, iteration 22 accepted by actual GPT 6 Pro. Original four goals and ten workflows remain open; canceled dark-region investigation stays canceled.

Product commit e1aa6356 separates default-off measurement from adaptive feedback and exports validated native completions through a 32-entry per-owner ring. Targeted actual-source NativeTimingBridge (3596 assertions), GpuFrameTiming (1048), and unchanged budget controller (13 scenarios) passed. Initial new-test definite-assignment compile failure is preserved; no product failure was hidden.

One new Development Mono/DX12 build (PID 17232, 284 products) and one visible DXR run (PID 14960) completed. 144 warmup + fixed 512 sources (145–656) + 32 drain = 688 target frames. All 512 source completions unique/valid; no invalid/drop/timeout. Static quotas 256/24/16, feedback off, target zero. Transport median 19.694368 ms; three-scope per-source sum median 19.853424, p95 21.4833936 ms. Normal exit 0, no resource signatures; recorded owner accounting drained to zero. This is finite fixed-scene cost evidence, not full-app/production performance or total VRAM certification.

Actual built importer accidentally retained Linux/macOS flags. Original metadata and hash retained; only local post-run flags corrected and future builder fixed, without another build/run. Windows binary/settings and measured timings unchanged. Pro22 accepted this explicitly bounded treatment; exclusive-platform import was not retrospectively marked passed.

Next iteration 23: transport-hotspot-and-reuse-01. One temporary diagnostic owner reusing the existing native bridge/pool measures World cache, Gather and Reconstruction nested inside formal Transport. Fixed64-source window, at most256warmup+32drain. Only if Gather dominates and compiled code retains repeated receiver-depth derivatives, attempt one computation-preserving reuse candidate with targeted contracts and at most one matching candidate run. No new ABI/pool, repeated512 baseline, quality reduction or unconstrained profiling.
