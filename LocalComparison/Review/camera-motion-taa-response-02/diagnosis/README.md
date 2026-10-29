# Identity dropout diagnosis of the preserved FAIL

`identity-dropout-complete.json` is diagnostic evidence, not a revised acceptance
result. The existing `analysis-source-expression-qualified.json` remains FAIL.
No source, native output, qualification, cohort, threshold or coverage was changed.

Observed chain:

| Logical frame | Sampled surface | Candidate / identity | Continued output age |
|---|---|---|---|
| 37 | All 69 panel-normal samples | Both zero; 195 floor samples remain valid | Floor controls 32 |
| 38 | Panel identity recovers | Seven newly exposed floor samples observe prior panel identity zero and prior age 1 | Floor controls 32 |
| 39 | Panel identity remains valid | Seven newly exposed floor samples observe valid prior panel identity but prior age 1 | Floor controls 32 |
| 40 | All 33 floor controls | `(2,0,1)` / `(4,0,1,1)` | 32 |
| 41 | All 206 floor-normal samples | Both zero; 58 panel samples remain valid | All 33 controls 1 |
| 42 | All 33 floor controls | Identity restored, prior identity zero | All 33 controls 1 |
| 43 | All 33 floor controls | Identity valid, prior age 1 | All 33 controls 2 |
| 44 | All 33 floor controls | Identity valid, prior age 2 | All 33 controls 3 |

These normal labels summarize recorded geometry and are not replacement source
proofs. The original independent source/coverage result is retained as-is.

Across every captured same-pixel predecessor from frames 2–47, the previous
geometry, material, identity, history and moments are byte-identical to the prior
frame's current observation (80 bytes per match). There are no same-pixel alias
disagreements. The only 328 cross-frame disagreements are at frame 1, whose
initialization history reset was already separately documented. In the focused
chain, frames 38/39 have 329/357 matching records and frames 41/42/43 have
360/387/349, with zero disagreements. This materially reduces the hypothesis of a
misbound observer history or asynchronous frame overwrite at the failing frames;
it proves only the sparse overlapping addresses actually captured.

CPU diagnostics still report three identity draws, three tracked sources,
published sources, no unknown rectangles and identity resolve recorded. Global
history remains valid. Candidate `.y` is zero, so this is not overlap rejection.
Copied object rows are zero when candidate `.x` is zero because the observer
never reads the object buffer in that case; this is not evidence of zero CPU/GPU
object rows. Raw and output history are bit-identical at all 33 controls in both
frames 41 and 42, consistent with current-frame fallback and age 1.

The capture shader's exact depth gate is a concrete next diagnostic target:
`input.positionCS.z == cameraDepth == captureDepth`. The frozen observation did
not record fragment depth, the capture depth attachment, or capture-time actual
`UNITY_MATRIX_VP`. It therefore cannot distinguish a transformed/rasterized depth
mismatch from another per-draw fragment rejection and does not establish the
root cause. No epsilon or Runtime change follows from this diagnosis.

Execution (Python dependency runtime, `-B`):

```
identity_dropout.py --output C:/Users/Administrator/Desktop/test/HybridLumenGI/LocalComparison/Review/camera-motion-taa-response-02/diagnosis/identity-dropout-complete.json
```

Exit 0. The script pins all 48 JSON/BIN pairs, original FAIL, CPU diagnostics and
the five relevant product sources, checking every input hash again before writing.
The preceding invocation used a relative output path and produced the complete
`identity-dropout-report.json`, then exited 1 only while formatting its console
path with `relative_to`. That first output is preserved; the successful invocation
uses the same unchanged script and an absolute output path. Neither invocation
reran the original acceptance analyzer or any GPU work.

Canonical report SHA-256:
`3864783fad240c54e25fd462c77d88124879aedf83fd9d8fc75bd418d20eb7a3`.
