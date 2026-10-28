# GPT-6 Astra Max prebuild review

The independent guard found no Runtime regression blocker in full-validation export, newest-only feedback, bounded overflow or discard accounting. Actual-source checks do not establish Unity integration.

Two concrete harness issues were identified and corrected before the build:

1. The product intentionally invalidates its timing ticket during initial DXR/backend and material-readiness transitions. Warmup now permits only an absent ticket with the explicit native `Invalidated` status, resets readiness, and requires real native availability. All selected source/drain frames still require valid matching submissions. DLL failure, Recorder fallback, arbitrary sequence failures or wrong source frames are not waived.
2. Target cleanup has its own catch before writing the outcome; `Application.Quit` is in the final block, so cleanup failure cannot silently strand a finished observer until the watchdog.

The settings JSON comparison matches the production serialization. Exported means delivered to the harness, timeout is a subset of cancellation, and disabled-budget rejection counters are not invalid native timestamps. No additional test framework was requested.
