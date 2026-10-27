# denoise-03-short-history-transition: review decision requested

Task c2c_a702, iteration 2. Baseline main@5eb1058 is the approved denoise-02 commit. The only product candidate is the CSFilter sigma blend specified by Pro; it remains uncommitted. No parameter sweep, new denoising framework or unrelated runtime change was made. Full original plan remains active.

## Actual execution and scope

Evidence root: LocalComparison/Review/denoise-03/. Read product.patch, paired-synthetic.json, paired-scene.json, whole-final-pair.json and the predeclared Documentation/Denoise03-TestContract.md. The two synthetic GPU runs each record 468 stages, both temporal entry points, actual filter steps 1/2/4, continuous history through 64 and full HDR/validity guards. Both exit 0. The two real scene runs each collect 198 logical frames, 29 final HDR captures and 21 consecutive raw/history/moments/geometry/material captures, with zero capture errors; both exit 0. Their `incomplete-probe` status correctly means the full 720-frame scenario was not run.

Test-only source instrumentation enqueued raw readback immediately after gather, in the same command buffer, with immutable frame/camera/format metadata. Original and instrumented sources/hashes are retained. All three instrumented project files are restored to their original hashes. Current 109 product files match the deployed project; deployment-restoration.json records this. Instrumented runs do not claim unmodified whole-product source identity.

## Synthetic findings, including the tradeoff

Both kernels give identical conclusions. Recorded temporal outputs, all moments and confidence match exactly between variants. First-frame and mature-history filter outputs match exactly. The fixed checker all-image maximum 3→4 change, and maximum adjacent change over 1→8, both fall from 0.195922852 to 0.115478516. The worst jump stays at 3→4; it is reduced rather than relocated. Necessary numerical continuity conditions pass.

The fixed checker is also a legitimate noiseless detail signal: its window reference RMSE improves 0.126609→0.109188, and the noiseless illumination edge improves 0.237593→0.201691. These are separate interpretations, not a claim that a checker must be noise.

There is a noise cost. Against uniform 0.5 truth, changing-noise window RMSE rises 0.0520988→0.0524622 (+0.70%). This aggregate hides the concentration: frame 2 rises 0.0351689→0.0362689 (+3.1%) and frame 3 rises 0.0253387→0.0294524 (+16.2%). Frame 1 and frames 4+ are unchanged. The candidate is not an unconditional noise improvement.

The R1 matched brightness control holds geometry/noise/history fixed. Dark-side response to +3 brightness exists in short history, and decreases with this candidate. It measures sensitivity to the bright signal, not physical light leakage; no plane weight changed.

## Real event coverage and result

The predeclared raw-array ROI is full x340..399,y144..249 (GI x170..199,y72..124). Every valid stable-geometry/material pixel with history 1→2→3→4 is retained. There are 1,230 qualifying door-ROI pixels, starting at logical frame 179; whole-image qualifying count is 2,957. Frame 179 already reaches the final door pose and provides the history-1 context, followed by static 180–196. Raw gather, temporal history, moments, geometry and material are bit-identical across the entire image for every frame 176–196. Settings, light/camera/door states and logical/engine/GI identities match.

At the qualifying GI source pixel centers in the final full-resolution image, actual 3→4 RGB RMS falls 0.0154021→0.0124830 (about 19%); maximum absolute RGB falls 0.0738511→0.0685815 (about 7.1%). The latter also remains the maximum adjacent change over the first eight recovery frames. Final cohort differences are exactly zero at frame 179 and every frame 182–196. Differences are confined to history 2 and 3 in this cohort. This rules out persistent candidate-versus-baseline residue here, not absolute ghosting in either algorithm.

Astra's independent check adds a material qualification: the maximum adjacent-frame **RMS** over the whole 1→8 window changes only 0.0154021→0.0153543 (-0.31%), and its location moves to 179→180. The first two adjacent RMS values increase about 2.3% and 7.4%. Therefore the 19% improvement describes only 3→4, not the full recovery-window RMS. The predeclared pointwise maximum still improves, but there is no basis to claim a 19% overall flicker reduction. Astra verified that the selected mask is GI x170..199,y72..112, corresponding to PNG x341..399,y134..214 on the door; the background portion of the larger initial ROI is excluded by the stated history/geometry predicates.

The real scene has no reference truth. Spatial high-frequency residual rises at history 2 (0.00200870→0.00216979) and 3 (0.00141005→0.00176235), consistent with less smoothing; it must not be called measured reference noise. The final previews were inspected and raw all-image differences are retained. Whole-image output is not identical at frame 4 of the selected cohort because other pixels can still have short histories.

## Evidence corrections and remaining boundaries

- The first analyzer run incorrectly equated pre-increment Work.frame with post-increment diagnostics state.frame. RendererFeature captures Work.frame before incrementing state.frame. The corrected relation is raw receipt GI frame +1 = diagnostics frame, verified on every captured frame; baseline/candidate raw GI frame values also match. The failed analysis log is retained as analysis-frame-contract-correction.log. No GPU rerun or data repair was performed.
- The old run manifest says PNG has no row flip. Actual EncodeArrayToPNG output is vertically flipped relative to the raw array: raw-derived sRGB with reversed rows matches within 1/255, while unreversed rows differ up to 235/255. PNG181 pair max difference is only 4/255. See png-orientation-check.json. Numeric analysis uses raw coordinates throughout; the stated raw ROI corresponds to PNG y110..215. Original manifests are retained unchanged, and this correction takes precedence.
- Shutdown Persistent/native-buffer warnings remain. These runs do not certify resource teardown, GPU timing, total VRAM, current Player/DXR, arbitrary dynamic scenes or production quality. No new quality threshold was invented to accept the tradeoff.

Please independently decide whether to retain this single candidate as a bounded transition correction with its noise limitation, or restore 5eb1058. No further seed/parameter matrix is proposed. Then provide the next finite development/fix plan; resource retirement at shutdown is a concrete existing defect candidate, while thin-wall transport correctness and all other original-plan acceptance gaps remain open.

## Review outcome

GPT-6 Pro decided RETAIN and approved local commit as a bounded short-history transition correction, with the measured noise tradeoff. Full response: LocalComparison/Review/denoise-03/gpt6-pro-review-and-next-plan.txt. This is not acceptance of overall dynamic image quality. In addition, reactive history is capped at 2 and maxHistory=2/3 can retain the changed behavior indefinitely; the measured cost must not be described as universally lasting only two engine frames. Sustained-reactive noise quality remains an explicit dynamic-validation gap.

Next package is resource-shutdown-01: first attribute the warning with one short feature-on/off control and allocation/retirement timelines; then repair only a proven owner/lifecycle gap, preserve completion safety, extend the existing StandaloneDeformedMesh tests, and perform bounded in-process lifecycle checks. No further denoise matrix is required for this commit.
