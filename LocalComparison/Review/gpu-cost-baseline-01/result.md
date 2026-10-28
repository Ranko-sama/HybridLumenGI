# gpu-cost-baseline-01 — finite physical-GPU result

Source commit: **e1aa6356c373c2feef169df3c54cc746fc3ade90**. One Development/Mono/DX12 build, 110 product sources and 284 product files verified. Native DLL SHA256 `4d94afc2769208cd1da72ec7cda0f29b31fc42dd71febd86a3b9238b391d6431` matches the existing native source/build report; no native rebuild or WARP rerun.

One visible Player, PID 14960, run `20261028-092239-d8444fc0bc184fdca5486c30f63c0585`. Unity 6000.0.85f1 / URP 17.0.4 / RTX 2080 Ti / Windows DX12. Existing Functional scene and GI settings; 640×360 target, 320×180 GI. Automatic events and capture probes disabled; initial deformation snapshot preserved. No images, texture readbacks or per-frame disk output during the window.

144 target-camera warmup frames, then the preselected **512 source frames 145–656**, then 32 drain frames: **688 frames total**. NativeDX12 completed every selected source exactly once, preserving token/owner/configuration/device epoch/frequency/ticks. Frame identity, prepared DXR/material/identity state and static patch/capture/brick quotas **256/24/16** remained fixed. Feedback disabled, Scale 1, target 0. Initial readiness includes global SDF completion; all 2048 bricks ready and zero dirty updates during the selected window.

| Native scope | Median ms | Observed p95 ms | Observed p99 ms | Max ms |
| --- | ---: | ---: | ---: | ---: |
| ReceiverCapture, including identity | 0.120800 | 0.129973 | 0.135453 | 0.137152 |
| Transport | 19.694368 | 21.328670 | 21.978162 | 22.780896 |
| Composite | 0.038656 | 0.042976 | 0.043008 | 0.044544 |
| Per-source sum of the three scopes | 19.853424 | 21.483394 | 22.137856 | 22.944800 |

Sum is formed before percentile; interpolation uses `(N−1)×q`. These are descriptive statistics of this finite static window. They exclude CPU preparation, uploads outside the scopes, other RenderGraph work and whole-app GPU time. Queue intervals can include barriers/waits. Six ticks do not identify individual Transport kernels. No target FPS/VRAM threshold was invented and no quality or ray budget was reduced.

681 total validated completions were exported across warmup/window/drain, with zero invalid, zero unexported and zero timeout. Five cancellations were confined to explicit startup invalidations; two pending submissions at final observation were outside the selected source window. The original newest-only feedback policy remains, and disabled budget rejection counts are not bad native timestamp counts.

Player exited 0 without watchdog intervention. Full native log has no matched allocation, unreleased D3D resource, GC buffer disposal, device, compile or runtime failure. Existing shutdown receipts show a legal boundary, owner withdrawal, separate parent/child fence submissions and all recorded final owner counters zero. Generic Unity UTP aggregate statistics remain in the raw log; this does not prove total RTAS/driver/VRAM zero or all failure-path safety.

## Importer deviation and local correction

The actual built importer set Any Platform off, Windows Editor x64 and Win64 on, Win32 off, but retained Linux64 and OSXUniversal on. This violated the exclusive-platform installation contract. The Windows DLL and inclusion used by this run were valid; it does not change the Windows interval results. `native/PluginImporter.meta` and build input hash retain the actual build setting. Only the local post-run metadata flags were changed to off; `PluginImporter.local-corrected.meta` and `importer-correction.json` record the correction. The future builder now explicitly disables both platforms. No second build/run or retrospective replacement of the original metadata occurred; Unity reimport of the corrected metadata is not claimed.

## Validation and next decision

Actual-source checks passed: native completion bridge 3596 assertions, frame timing 1048 assertions, unchanged budget controller 13 scenarios. The initial test-extension compile failure (C# short-circuit out-variable assignment) and its corrected pass are both retained. These checks use existing recording/fake ABI substitutes and do not replace the actual Player evidence above.

Actual GPT 6 Pro22 accepted the finite Windows measurement, Runtime changes and explicitly labeled importer correction; complete reply is in `gpt6-pro-review-and-next-plan.txt`. Next is one bounded Transport attribution and at most one conditional receiver-depth-derivative reuse candidate. Do not label Gather or cache tracing as the measured bottleneck yet. Dynamic/material/streaming and production gates remain open.
