# Current Player result — failed normal exit, hardware not covered

Current-source build succeeded (source9176b0f,110 Runtime/Editor files matched,
283 emitted files hashed). Product manifest SHA256:
e1640798217978d0da7a0417bd710499c90574f276618d1c1b67900b200a2f8d.
All temporary build wiring was restored. No product Runtime changes in this package.

Original software/ PID38036 is a retained FAIL with zero camera frames. Executor
mistakenly used batchmode/Hidden despite the existing reproduction instructions.
launcher-correction.md explicitly records one scope correction; Astra reviewed it.
software-windowed/ is a separate corrected visible launch of the same283files.
No further Player launch or rebuild is permitted in this package.

Corrected PID23148 exited0 without watchdog termination. Run
20261028-074825-b81d0cbb4eb744bd934b2c4d5a2118f3 collected120 logical frames,
5 captures,0 capture errors. The intentional120frame limit reports incomplete-probe,
not full720sequence success. First-frame wait108.7615767seconds. Final16 diagnostics
select exact software geometry, prepared material consumers and a stable zero
unrepresented-instance gauge. Actual30/first119 readbacks show history maxima28/32,
historyFraction .8064236 and46840 valid identity pixels; both moments formats are
R32G32B32A32_SFloat. These are finite execution observations, not image acceptance.

Two distinct failures must remain separate:

1. Actual native shutdown reports owned=2,pending=2,outsideRenderLoop=False,
   deformationBytes53760, GC buffer disposal and29 D3D12 unreleased resources.
   native exit0 is not accepted cleanup. Runtime retirement currently waits until
   Application.quitting, after the final render has invalidated its early Update
   outside certificate. It cannot submit the final retirement tickets then.
2. The analysis stops at saved119 moments.z maximum1. This is a test capture
   provenance defect: RuntimeAuditProbe remains subscribed after capture.Finish
   restores camera/target and closes capture. A second endCameraRendering callback
   writes the same119 payload filenames. functional.jsonl preserves both119 rows:
   first max32/fraction.8064, second max1/fraction0. Analyzer selects the first row
   but reads the overwritten second payload. This does not establish lost history
   during the intended120frame capture. Keep the FAIL; fix the probe gate and
   no-overwrite semantics before a fresh future run, not by changing this report.

currentSourceBuildVerified=true; softwarePlayerSmokeVerified=false;
softwareNormalExitAccepted=false; hardwarePlayerSmokeVerified=false;
hardwareNotCoveredReason=software normal-exit/readback gates failed;
fullProductionAccepted=false. Hardware was never launched. Existing analysis and
native logs are immutable evidence; HDR loop checks were not reached after the
moments assertion, so five collected captures are not asserted fully validated.

Next: actual GPT6 Pro review and a bounded Runtime shutdown fix plus narrow probe
provenance repair, with a fresh separately named verification package. Avoid a new
retirement test framework or repeated parameter launches. No dark-region work.
