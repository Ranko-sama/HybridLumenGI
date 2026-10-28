# GPT-6 Astra Max design review

The independent guard accepted a 32-entry per-owner completion ring as bounded export storage, not another GPU query system.

- Separate timing, adaptive feedback, and export enablement. Default off allocates no export buffer and probes no DLL; measure-only with target zero preserves configured quotas.
- Export after full validation and before feedback's old-result filter. Valid late completions remain measurements; feedback still chooses newest. Do not classify all feedback rejections as invalid measurements.
- Preserve original token/owner/generation/device epoch/source frame/frequency/ticks; record read frame separately.
- Overflow preserves buffered entries and counts drops. Disable, invalidate and dispose count discarded records. Dequeue never polls native/fences.
- Accept the exact preselected 512-source set, not 512 successful survivors. Continue timing during drain. Distinguish warmup/window/drain/exit cancellations.
- Reuse the matching DLL, six timestamps and limited affected tests. No ABI/query-pool/plugin matrix expansion.
