# One final-state recovery comparison

Prospective scope: original G3 requires quantitative response information. There
is no current proven code fault to tune. Astra Max approved one fixed two-history
comparison, with no rerun, control extension or new physical reference after seeing
the outcome. Product source remains Release122. No Feature/compute instrumentation.

Reuse the TimedResponse123 black-environment fixture: white floor/wall, zero native
lights/lightmaps/SH/reflections, sole hidden single-slot analytic emitter. Change
only the sampling dimensions to 960x540, GI 480x270, with released 2 rays/filter4
and requested/observed DXR. First history starts green and switches to blue after
logical119. Control starts blue; after119 it records a marker without changing
input. Control is a longer-blue-history product output, NOT physical truth or a
claim of infinite convergence. Logical/work frames and RNG sequence are paired.

Quantity is linear Final HDR camera radiance at 27 fixed white-floor pixels.
Map each old selected full-pixel center to the new dimensions before observation:
newPixel=floor((oldSampledFullPixel+.5)*1.5), both axes. Preserve top-to-bottom
native row order. Do not reuse old GI integer indices or compare these numbers
against the old filteredD values. No exposure/post/tonemapping changes.

At logical0 only, reuse existing full Capture support and let it drain BEFORE
continuing warmup. An early engine-frame gap from0 to1 is explicitly allowed;
logical1 through119 and the response must have consecutive engine frames, so this
observation does not itself discard mature screen history. Verify support native-before-composite at all 27 points is black within
1e-6/channel, depth unprojects to the source floor (|y|<=1e-3, x in (0,5),
z in (-3,3)). Logical119 additionally gets the same asynchronous Final point read
as response frames, with finite positive mean and only the expected emission channel
within1e-6/channel. The event/marker is written in that SAME engine frame after
render/readback admission; do not await119 completion across engine frames.
Actual source/camera/settings must match and remain static apart from the event.
The static receiver, source inputs and absence of other native illumination make
the paired final-radiance comparison meaningful for this indirect-light response.
Capture wait duration is recorded; it is not response time. This input wiring was
corrected during pre-execution review after identifying the existing f-1 engine-frame
contract; no observation had run and no criterion was changed from an outcome.

Source admission is paced at nominal1/30 second using Time.realtimeSinceStartupAsDouble.
Wait at most one nominal interval INSIDE Update, rather than returning to skip engine
frames; assert consecutive engine IDs from logical1 onward. Every response frame
and logical119 gets one standard
AsyncGPUReadback of the existing Final HDR target; callbacks retain just the fixed
27 RGBA values, source/work/engine IDs and completion time. No synchronous GPU row
reads or per-frame file IO inside the response window. Keep the full first >=2s
and last source images from these same readbacks, write once after drain. Record
actual cadence and pending counts. This still adds readback overhead; no claim of
ordinary Player, Present FPS, GPU timing or zero-cost observation.

Event history ends at its first source at/after2.6s; control is configured before
starting to end at that exact logical frame, and retains its full image at the
event history's first>=2s logical frame. Limits are512 requests, a300s submission
watchdog and8 pending observations; insufficiency does not authorize retry or dropping frames.
All issued observations must complete or be explicitly failed before releasing
their target. A nonterminal drain at300s records a timeout checkpoint and keeps
its owners until real completion; timeout does not authorize forced release or
claim that the process stopped. Source timestamps, not async completion, determine response times.

Frozen analysis:

* Input, all27 finite points and contiguous work-frame pairing are mandatory.
  Missing/failed readbacks remain missing, never zero or a reduced sample domain.
* Finite control sufficiency: across all paired post-marker frames, mean Y>1e-5,
  (maxY-minY)/meanY<=5%, and normalized-mean-RGB L1 distance from its first value
  <=.025. These engineering stability checks do not prove physical/infinite truth.
  If control fails, report insufficient comparison; do not extend its warmup.
* At each paired frame use the full-domain mean RGB and Y (Rec.709 linear weights).
  Recovery is abs(Y_event/Y_control-1)<=10% and L1 between normalized meanRGB<=.05.
  Also report maximum point differences; a mean cannot excuse an obvious local
  artifact in the retained same-exposure images. This is history recovery, not
  absolute GI energy or color accuracy against a physical reference.
* A qualifying recovery window starts at an actual event source time<=2s and
  contains every subsequent admitted source frame through at least+.5s, all
  satisfying recovery. Require observed span>=.5s and no inter-source gap>2/30s
  in either history over that window. Do not bridge gaps, interpolate or infer
  unobserved presentation. Report first observed qualifying start, not an exact
  physical continuous convergence instant. Actual nominal30 cadence remains explicit.
* Old-green residual is meanG divided by pre-event meanG. Report actual samples
  immediately before/after1s and2s, earliest observed qualifying levels and local
  extrema. The project targets remain5% at1s,1% at2s; do not convert frame numbers
  by targetFPS or let late samples prove an earlier strict deadline.

Outcome is satisfy/unsatisfied/insufficient within this one configuration and
quantity, then stop. No full G3, door, physical-reference, Player or perf release
claim. An exceedance triggers source/quantity attribution before any product fix;
it does not automatically authorize parameter tuning or a new reference system.
