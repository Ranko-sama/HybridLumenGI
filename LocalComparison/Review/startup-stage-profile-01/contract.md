# First-render CPU stage diagnosis

This is one diagnostic Release/None Player build and one fixed 12-request DX12 run, derived from Release71. It does not replace the ordinary Release71 entry.

The existing Functional scene, GI settings, 640×360 HDR camera target, static environment cube and product shader bytes remain the same as Release71. The temporary C# observer buffers monotonic CPU timestamps and writes them after the first explicit request returns. The host retains request/camera/context closure checks; final HDR readback is disabled. The frame count changes from 120 to 12 solely to bound this diagnosis.

Acceptance requires exact staged/build source hashes, unchanged product shader inputs, 12 consecutive complete requests, no native errors, internally consistent ordered timestamps, and restoration of all deployed source/assets. The diagnostic must retain failed/partial data. If the long wait does not recur, report non-reproduction; do not append another run to obtain a preferred outcome.

Intervals measure elapsed CPU wall time, including any synchronous engine/driver waits within the measured call. They do not measure GPU execution time and do not distinguish engine shader creation from driver compilation without additional evidence. No first-frame GPU ticket or physical image result is claimed. Absolute startup performance, steady-state p95/p99, production FPS and VRAM acceptance remain open.

The no-observer shader requirement is checked before staging, before install, in build inputs and after restoration. Startup observer code and its patcher are pinned separately from the unchanged product baseline.
