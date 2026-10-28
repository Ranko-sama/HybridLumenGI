# Offline qualification and cache response — iteration 14

Scope fixed before response execution: existing chain02 run only, 360 schedules,
720 observed patch records, nine saved gather/HDR times. Zero Unity/GPU launches;
no Runtime change or parameter remix. Original analysis, summary and executed
contract remain byte-identical and false acceptance is preserved.

The lifecycle qualifier uses combined empty-old-light, unchanged packed current
source/controller, initial counters/buffer and full-zero observed cache evidence.
Its initialization phase cannot reopen after continuous propagation. Six semantic
negative data copies exercise changed source, late resets, extra event, missing
receipt and missing removal; they do not merely fail input hashes.

Response starts at the actual frame119 measurement for each fixed patch. Maintain
double-precision A=1 and B=0, then reconstruct C=A*C119+B. At an actual valid
commit use the actual estimateSum/rayCount and alpha=max(1/min(preparedSamples+1,32),0.1),
or alpha=1 when preparedSamples=0. B is independently accumulated from these
inputs, never obtained by subtracting observed C. Unscheduled and attempted-unknown
records remain distinct. A hard identity/epoch/generation or geometric invalidation
ends the segment; it cannot be counted as decay. Reactive sample shortening is
recorded even without a commit, and changes subsequent alpha.

The existing arithmetic contract uses gamma32=32u/(1-32u), u=2^-24.
For each committed channel, propagate E_next=abs(1-alpha)*E_previous +
gamma32*(abs(predicted_previous)+E_previous+abs(actualEstimate))+2^-120.
The local term conservatively covers float division/alpha/lerp operations from
the recorded float operands; the prior error bound is propagated, not reset at
each commit. Uncommitted holds preserve E. Base C119 is an exact decoded float.
Reject nonfinite inputs. No tolerances are fitted after observing residuals.

Read every raw record and schedule with the committed execution manifest hashes.
Cross-check raw cache fields against the frozen decoded analysis. Reuse its
already-reviewed actual-consumption decoder for nine saved times, cross-linking
raw/history/filtered and full HDR from original bytes. Do not interpolate missing
gather times. Recheck actual mask, service clocks, oldest quota and stable-identity
age bound for all schedules; service delay is in scheduler ticks, not GPU time.

A*C119 is only this patch's directly retained initial history. B includes incoming
estimates that may themselves contain other surfaces' old cache energy. Neither
is a whole-scene physical reference or a counterfactual. Preserve all increases,
observed source inventory, unknowns and unproven feedback origins. A schedule
service receipt does not prove a valid committed estimate. Report absent coverage
instead of launching another scene. Next priority is an independent actual-scene
radiometric reference and an improvement supported by a concrete discrepancy.
